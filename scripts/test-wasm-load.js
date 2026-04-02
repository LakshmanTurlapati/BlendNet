#!/usr/bin/env node
// SPDX-FileCopyrightText: 2026 Blender Web Authors
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * test-wasm-load.js -- Primary WASM load validation (BUILD-01, BUILD-02)
 *
 * Validates that the Blender WASM binary loads and initializes correctly.
 * Checks file existence, file size, and calls wasm_init() via Emscripten glue.
 *
 * Exit code 0: PASS
 * Exit code 1: FAIL
 */

"use strict";

var fs = require("fs");
var path = require("path");

var WASM_BINARY_PATH = path.resolve(__dirname, "..", "build-wasm", "blender.wasm");
var GLUE_CODE_PATH = path.resolve(__dirname, "..", "build-wasm", "blender.js");

function formatBytes(bytes) {
  var mb = (bytes / (1024 * 1024)).toFixed(2);
  return bytes + " bytes (" + mb + " MB)";
}

function main() {
  console.log("=== Blender WASM Load Test (BUILD-01, BUILD-02) ===\n");

  // Check if WASM binary exists
  if (!fs.existsSync(WASM_BINARY_PATH)) {
    console.error("FAIL: WASM binary not found at: " + WASM_BINARY_PATH);
    console.error("  Run the WASM build first: scripts/build-wasm.sh");
    process.exit(1);
  }

  // Report file size
  var stats = fs.statSync(WASM_BINARY_PATH);
  console.log("WASM binary: " + WASM_BINARY_PATH);
  console.log("WASM binary size: " + formatBytes(stats.size));
  console.log("");

  // Check if glue code exists
  if (!fs.existsSync(GLUE_CODE_PATH)) {
    console.error("FAIL: Emscripten glue code not found at: " + GLUE_CODE_PATH);
    console.error("  Run the WASM build first: scripts/build-wasm.sh");
    process.exit(1);
  }

  console.log("Emscripten glue: " + GLUE_CODE_PATH);
  console.log("Loading WASM module...\n");

  // Set up timeout for initialization
  var timeout = setTimeout(function() {
    console.error("FAIL: WASM module initialization timed out after 30 seconds");
    process.exit(1);
  }, 30000);

  // Load the Emscripten glue code
  try {
    // Emscripten modules may export a factory function or set global Module
    var ready = false;
    var moduleConfig = {
      noInitialRun: true,
      print: function(text) {
        console.log("[wasm] " + text);
      },
      printErr: function(text) {
        console.error("[wasm:err] " + text);
      },
      onRuntimeInitialized: function() {
        if (ready) {
          return;
        }
        ready = true;
        clearTimeout(timeout);
        onReady(global.Module || this);
      }
    };

    global.Module = Object.assign({}, global.Module || {}, moduleConfig);
    var createModule = require(GLUE_CODE_PATH);

    if (typeof createModule === "function") {
      var instance = createModule(moduleConfig);
      // Some Emscripten builds return a promise
      if (instance && typeof instance.then === "function") {
        instance.then(function(mod) {
          if (ready) {
            return;
          }
          ready = true;
          clearTimeout(timeout);
          onReady(mod);
        }).catch(function(err) {
          clearTimeout(timeout);
          console.error("FAIL: Module initialization rejected: " + err.message);
          process.exit(1);
        });
      }
    } else if (createModule && createModule.calledRun) {
      if (ready) {
        return;
      }
      ready = true;
      clearTimeout(timeout);
      onReady(createModule);
    } else {
      // Module might already be initialized via global
      if (typeof global.Module !== "undefined" && global.Module._wasm_init) {
        if (ready) {
          return;
        }
        ready = true;
        clearTimeout(timeout);
        onReady(global.Module);
      }
    }
  } catch (err) {
    clearTimeout(timeout);
    console.error("FAIL: Could not load Emscripten glue code: " + err.message);
    process.exit(1);
  }
}

function onReady(mod) {
  console.log("WASM runtime initialized.\n");

  // Call wasm_init and verify return value
  try {
    var initResult;
    if (typeof mod.ccall === "function") {
      initResult = mod.ccall("wasm_init", "number", [], []);
    } else if (typeof mod._wasm_init === "function") {
      initResult = mod._wasm_init();
    } else {
      console.error("FAIL: wasm_init function not found in module exports");
      process.exit(1);
      return;
    }

    console.log("wasm_init() returned: " + initResult);

    if (initResult === 0) {
      console.log("\nPASS: WASM binary loads and initializes successfully");
      process.exit(0);
    } else {
      console.error("\nFAIL: wasm_init() returned non-zero: " + initResult);
      process.exit(1);
    }
  } catch (err) {
    console.error("FAIL: wasm_init() threw an error: " + err.message);
    process.exit(1);
  }
}

main();
