#!/usr/bin/env node
// SPDX-FileCopyrightText: 2026 Blender Web Authors
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * test-blend-query.js -- Real .blend load and scene-query validation (BUILD-02)
 *
 * Loads the produced Blender WASM runtime, copies a real .blend file into
 * MEMFS, calls wasm_load_blend(), and validates wasm_query_scene().
 *
 * Environment:
 *   BLEND_SAMPLE_PATH  Optional local path to a .blend file.
 *   BLEND_SAMPLE_URL   Optional override for the sample download URL.
 *
 * Exit code 0: PASS
 * Exit code 1: FAIL
 */

"use strict";

var fs = require("fs");
var path = require("path");
var https = require("https");
var http = require("http");
var zlib = require("zlib");

var WASM_DIR = path.resolve(__dirname, "..", "build-wasm");
var WASM_BINARY_PATH = path.join(WASM_DIR, "blender.wasm");
var GLUE_CODE_PATH = path.join(WASM_DIR, "blender.js");
var BLEND_SAMPLE_PATH = process.env.BLEND_SAMPLE_PATH || "/tmp/Blender-282.blend";
var BLEND_SAMPLE_URL = process.env.BLEND_SAMPLE_URL || "https://download.blender.org/demo/Blender-282.blend";
var MEMFS_BLEND_PATH = "/data/" + path.basename(BLEND_SAMPLE_PATH);

function fail(message, details) {
  console.error("FAIL: " + message);
  if (details) {
    console.error(details);
  }
  process.exit(1);
}

function formatBytes(bytes) {
  var mb = (bytes / (1024 * 1024)).toFixed(2);
  return bytes + " bytes (" + mb + " MB)";
}

function parseBlendVersion(buffer) {
  var candidate = buffer;

  if (!candidate || candidate.length < 12) {
    return "unknown";
  }

  if (candidate[0] === 0x1f && candidate[1] === 0x8b) {
    try {
      candidate = zlib.gunzipSync(candidate);
    } catch (err) {
      return "gzip-but-unreadable";
    }
  }

  var signature = candidate.slice(0, 7).toString("ascii");
  if (signature !== "BLENDER") {
    return "not-a-blend";
  }

  return candidate.slice(9, 12).toString("ascii");
}

function download(url, destination, redirectCount) {
  redirectCount = redirectCount || 0;
  if (redirectCount > 5) {
    return Promise.reject(new Error("too many redirects"));
  }

  return new Promise(function(resolve, reject) {
    var transport = url.indexOf("https://") === 0 ? https : http;
    var request = transport.get(url, function(response) {
      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
        response.resume();
        resolve(download(response.headers.location, destination, redirectCount + 1));
        return;
      }

      if (response.statusCode !== 200) {
        reject(new Error("HTTP " + response.statusCode + " while downloading " + url));
        return;
      }

      var file = fs.createWriteStream(destination);
      response.pipe(file);

      file.on("finish", function() {
        file.close(resolve);
      });

      file.on("error", function(err) {
        reject(err);
      });
    });

    request.on("error", reject);
  });
}

function ensureBlendSample() {
  if (fs.existsSync(BLEND_SAMPLE_PATH)) {
    return Promise.resolve();
  }

  console.log("Sample .blend missing, downloading:");
  console.log("  " + BLEND_SAMPLE_URL);

  return download(BLEND_SAMPLE_URL, BLEND_SAMPLE_PATH).then(function() {
    console.log("Downloaded sample to: " + BLEND_SAMPLE_PATH);
  });
}

function makeModuleConfig() {
  var ready = false;
  var timeout = setTimeout(function() {
    fail("WASM module initialization timed out after 30 seconds");
  }, 30000);

  function onReady(mod) {
    if (ready) {
      return;
    }
    ready = true;
    clearTimeout(timeout);
    runBlendQuery(mod);
  }

  return {
    noInitialRun: true,
    locateFile: function(fileName) {
      return path.join(WASM_DIR, fileName);
    },
    print: function(text) {
      console.log("[wasm] " + text);
    },
    printErr: function(text) {
      console.error("[wasm:err] " + text);
    },
    onRuntimeInitialized: function() {
      onReady(global.Module || this);
    },
    __onReady: onReady
  };
}

function loadModule(moduleConfig) {
  global.Module = Object.assign({}, global.Module || {}, moduleConfig);

  try {
    var createModule = require(GLUE_CODE_PATH);

    if (typeof createModule === "function") {
      var instance = createModule(moduleConfig);
      if (instance && typeof instance.then === "function") {
        instance.then(function(mod) {
          moduleConfig.__onReady(mod);
        }).catch(function(err) {
          fail("Module initialization rejected", err && err.stack ? err.stack : String(err));
        });
      }
      return;
    }

    if (createModule && createModule.calledRun) {
      moduleConfig.__onReady(createModule);
      return;
    }
  } catch (err) {
    fail("Could not load Emscripten glue code", err && err.stack ? err.stack : String(err));
  }
}

function runBlendQuery(mod) {
  var bytes = fs.readFileSync(BLEND_SAMPLE_PATH);
  var blendVersion = parseBlendVersion(bytes);

  console.log("Sample file: " + BLEND_SAMPLE_PATH);
  console.log("Sample size: " + formatBytes(bytes.length));
  console.log("Sample version: " + blendVersion);
  console.log("");

  try {
    mod.FS.mkdir("/data");
  } catch (err) {
    if (!/File exists/i.test(String(err))) {
      fail("Could not prepare /data in MEMFS", err && err.stack ? err.stack : String(err));
    }
  }

  try {
    mod.FS.unlink(MEMFS_BLEND_PATH);
  } catch (err) {
    // Ignore missing files in MEMFS.
  }

  try {
    mod.FS.writeFile(MEMFS_BLEND_PATH, bytes);
  } catch (err) {
    fail("Could not copy sample into MEMFS", err && err.stack ? err.stack : String(err));
  }

  console.log("MEMFS path: " + MEMFS_BLEND_PATH);

  try {
    var initResult = mod.ccall("wasm_init", "number", [], []);
    console.log("wasm_init() returned: " + initResult);
  } catch (err) {
    fail("wasm_init() threw an error", err && err.stack ? err.stack : String(err));
  }

  try {
    console.log("Calling wasm_load_blend()...");
    var objectCount = mod.ccall("wasm_load_blend", "number", ["string"], [MEMFS_BLEND_PATH]);
    console.log("wasm_load_blend() returned: " + objectCount);

    if (objectCount < 0) {
      fail("wasm_load_blend() returned a negative object count");
    }

    var sceneJson = mod.ccall("wasm_query_scene", "string", [], []);
    console.log("wasm_query_scene() returned: " + sceneJson);

    var parsed = JSON.parse(sceneJson);
    if (!parsed || !Object.prototype.hasOwnProperty.call(parsed, "objects")) {
      fail("Scene JSON is missing the objects array");
    }

    console.log("Scene objects in JSON: " + parsed.objects.length);
    console.log("");
    console.log("PASS: Real .blend load and scene query succeeded");
    process.exit(0);
  } catch (err) {
    var detail = err && err.stack ? err.stack : String(err);
    if (/null function|signature mismatch/i.test(detail)) {
      console.error("Observed a WASM indirect-call signature mismatch while loading the blend file.");
      console.error("This commonly points to a function-pointer cast issue inside the loader/versioning path.");
    }
    fail("Real .blend load and scene query failed", detail);
  }
}

function main() {
  console.log("=== Blender WASM Real Blend Query Test (BUILD-02) ===\n");

  if (!fs.existsSync(WASM_BINARY_PATH)) {
    fail("WASM binary not found at: " + WASM_BINARY_PATH);
  }

  if (!fs.existsSync(GLUE_CODE_PATH)) {
    fail("Emscripten glue code not found at: " + GLUE_CODE_PATH);
  }

  ensureBlendSample()
    .then(function() {
      loadModule(makeModuleConfig());
    })
    .catch(function(err) {
      fail("Could not prepare the sample .blend file", err && err.stack ? err.stack : String(err));
    });
}

main();
