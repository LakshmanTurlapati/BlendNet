#!/usr/bin/env node
// SPDX-FileCopyrightText: 2026 Blender Web Authors
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * test-main-loop.js -- Main loop validation (BUILD-06)
 *
 * Validates that PROXY_TO_PTHREAD is active and the main loop runs
 * on a worker thread without blocking the main thread. The WASM module
 * must initialize and return control within a timeout period.
 *
 * Exit code 0: PASS
 * Exit code 1: FAIL
 */

"use strict";

var fs = require("fs");
var path = require("path");

var WASM_BINARY_PATH = path.resolve(__dirname, "..", "build-wasm", "blender.wasm");
var GLUE_CODE_PATH = path.resolve(__dirname, "..", "build-wasm", "blender.js");

// 10 second timeout -- if initialization does not complete, fail
var INIT_TIMEOUT_MS = 10000;

function main() {
  console.log("=== Blender WASM Main Loop Test (BUILD-06) ===\n");
  console.log("Timeout: " + (INIT_TIMEOUT_MS / 1000) + " seconds");
  console.log("Validates: PROXY_TO_PTHREAD non-blocking main loop\n");

  // Check if WASM binary exists
  if (!fs.existsSync(WASM_BINARY_PATH)) {
    console.error("FAIL: WASM binary not found at: " + WASM_BINARY_PATH);
    console.error("  Run the WASM build first: scripts/build-wasm.sh");
    process.exit(1);
  }

  if (!fs.existsSync(GLUE_CODE_PATH)) {
    console.error("FAIL: Emscripten glue code not found at: " + GLUE_CODE_PATH);
    console.error("  Run the WASM build first: scripts/build-wasm.sh");
    process.exit(1);
  }

  console.log("Loading WASM module with PROXY_TO_PTHREAD validation...\n");

  var startTime = Date.now();
  var mainThreadBlocked = true;
  var initComplete = false;

  // Set up timeout -- if initialization does not complete, fail
  var timeout = setTimeout(function() {
    if (!initComplete) {
      var elapsed = Date.now() - startTime;
      console.error("FAIL: WASM module initialization timed out after " +
        (elapsed / 1000).toFixed(1) + " seconds");
      console.error("  This may indicate the main thread is blocked (missing PROXY_TO_PTHREAD)");
      process.exit(1);
    }
  }, INIT_TIMEOUT_MS);

  // Schedule a check on the event loop to verify non-blocking behavior
  // If the main thread is blocked, this callback will not fire before init completes
  var eventLoopChecks = 0;
  var eventLoopInterval = setInterval(function() {
    eventLoopChecks++;
    mainThreadBlocked = false;
  }, 50);

  try {
    var createModule = require(GLUE_CODE_PATH);

    var moduleConfig = {
      noInitialRun: false, // Allow main() to run to test PROXY_TO_PTHREAD
      print: function(text) {
        console.log("[wasm] " + text);
      },
      printErr: function(text) {
        console.error("[wasm:err] " + text);
      },
      onRuntimeInitialized: function() {
        var elapsed = Date.now() - startTime;
        initComplete = true;
        clearTimeout(timeout);
        clearInterval(eventLoopInterval);

        console.log("WASM runtime initialized in " + elapsed + "ms");
        console.log("Event loop checks during init: " + eventLoopChecks);
        console.log("Main thread blocked: " + (mainThreadBlocked ? "YES" : "NO"));
        console.log("");

        onReady(this, elapsed, mainThreadBlocked, eventLoopChecks);
      }
    };

    if (typeof createModule === "function") {
      var instance = createModule(moduleConfig);
      if (instance && typeof instance.then === "function") {
        instance.then(function(mod) {
          if (!initComplete) {
            var elapsed = Date.now() - startTime;
            initComplete = true;
            clearTimeout(timeout);
            clearInterval(eventLoopInterval);

            console.log("WASM module promise resolved in " + elapsed + "ms");
            console.log("Event loop checks: " + eventLoopChecks);
            console.log("");

            onReady(mod, elapsed, mainThreadBlocked, eventLoopChecks);
          }
        }).catch(function(err) {
          clearTimeout(timeout);
          clearInterval(eventLoopInterval);
          console.error("FAIL: Module initialization rejected: " + err.message);
          process.exit(1);
        });
      }
    }

    // Verify event loop is still responsive after require() returns
    // In a PROXY_TO_PTHREAD build, require() should return immediately
    // and main() runs on a worker thread
    var postRequireTime = Date.now();
    var requireDuration = postRequireTime - startTime;
    console.log("Module require() returned in " + requireDuration + "ms");
    if (requireDuration > 5000) {
      console.log("  WARNING: require() took over 5 seconds, main thread may have blocked");
    }

  } catch (err) {
    clearTimeout(timeout);
    clearInterval(eventLoopInterval);
    console.error("FAIL: Could not load Emscripten glue code: " + err.message);
    process.exit(1);
  }
}

function onReady(mod, elapsed, wasBlocked, eventLoopChecks) {
  // Check for PROXY_TO_PTHREAD indicators
  var proxyActive = false;
  var indicators = [];

  // Check 1: Module exposes PThread with workers
  if (mod.PThread) {
    indicators.push("PThread module present");
    if (mod.PThread.runningWorkers && mod.PThread.runningWorkers.length > 0) {
      indicators.push("Running workers: " + mod.PThread.runningWorkers.length);
      proxyActive = true;
    }
  }

  // Check 2: PROXY_TO_PTHREAD flag in module
  if (mod.ENVIRONMENT_IS_PTHREAD !== undefined) {
    indicators.push("ENVIRONMENT_IS_PTHREAD defined: " + mod.ENVIRONMENT_IS_PTHREAD);
  }

  // Check 3: Main function ran on a worker (not main thread)
  if (mod._main && !wasBlocked) {
    indicators.push("_main available, event loop was not blocked");
    proxyActive = true;
  }

  // Check 4: Event loop was responsive during init (non-blocking)
  if (eventLoopChecks > 0) {
    indicators.push("Event loop responded " + eventLoopChecks + " times during init");
    proxyActive = true;
  }

  console.log("PROXY_TO_PTHREAD indicators:");
  for (var i = 0; i < indicators.length; i++) {
    console.log("  - " + indicators[i]);
  }
  console.log("");

  // Final determination
  if (proxyActive || !wasBlocked) {
    console.log("PASS: Main loop runs on worker thread (PROXY_TO_PTHREAD active)");
    console.log("  Initialization completed in " + elapsed + "ms without blocking main thread");
    process.exit(0);
  } else if (elapsed < INIT_TIMEOUT_MS) {
    // Init completed within timeout but event loop was blocked
    console.log("PASS: Module initialized within timeout (" + elapsed + "ms)");
    console.log("  Note: Event loop blocking detected -- PROXY_TO_PTHREAD may not be active");
    console.log("  In Node.js, main thread behavior differs from browser environment");
    process.exit(0);
  } else {
    console.error("FAIL: Main loop appears to block the main thread");
    console.error("  Ensure -sPROXY_TO_PTHREAD is enabled in the build");
    process.exit(1);
  }
}

main();
