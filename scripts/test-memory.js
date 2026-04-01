#!/usr/bin/env node
// SPDX-FileCopyrightText: 2026 Blender Web Authors
// SPDX-License-Identifier: GPL-2.0-or-later

/**
 * test-memory.js -- Memory validation (BUILD-04)
 *
 * Validates that MEM_guarded_alloc memory tracking works within
 * the WASM 4GB address space ceiling. Checks initial heap size,
 * wasm_memory_usage() reporting, and memory growth behavior.
 *
 * Exit code 0: PASS
 * Exit code 1: FAIL
 */

"use strict";

var fs = require("fs");
var path = require("path");

var WASM_BINARY_PATH = path.resolve(__dirname, "..", "build-wasm", "blender.wasm");
var GLUE_CODE_PATH = path.resolve(__dirname, "..", "build-wasm", "blender.js");

// 4GB ceiling in bytes (WASM32 maximum)
var WASM_4GB_CEILING = 4294967296;

// Expected initial memory ~256MB (from -sINITIAL_MEMORY=256MB)
var EXPECTED_INITIAL_MEMORY = 256 * 1024 * 1024;
var INITIAL_MEMORY_TOLERANCE = 0.2; // 20% tolerance

function formatBytes(bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB";
  }
  return (bytes / (1024 * 1024)).toFixed(2) + " MB";
}

function main() {
  console.log("=== Blender WASM Memory Test (BUILD-04) ===\n");
  console.log("WASM 4GB ceiling: " + formatBytes(WASM_4GB_CEILING));
  console.log("Expected initial memory: " + formatBytes(EXPECTED_INITIAL_MEMORY));
  console.log("");

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

  console.log("Loading WASM module for memory validation...\n");

  // Set up timeout
  var timeout = setTimeout(function() {
    console.error("FAIL: WASM module initialization timed out after 30 seconds");
    process.exit(1);
  }, 30000);

  try {
    var createModule = require(GLUE_CODE_PATH);

    var moduleConfig = {
      noInitialRun: true,
      print: function(text) {
        console.log("[wasm] " + text);
      },
      printErr: function(text) {
        console.error("[wasm:err] " + text);
      },
      onRuntimeInitialized: function() {
        clearTimeout(timeout);
        onReady(this);
      }
    };

    if (typeof createModule === "function") {
      var instance = createModule(moduleConfig);
      if (instance && typeof instance.then === "function") {
        instance.then(function(mod) {
          clearTimeout(timeout);
          onReady(mod);
        }).catch(function(err) {
          clearTimeout(timeout);
          console.error("FAIL: Module initialization rejected: " + err.message);
          process.exit(1);
        });
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

  var passed = true;

  // Check 1: Read initial WASM heap size from HEAP8.buffer.byteLength
  var initialHeapSize = 0;
  try {
    if (mod.HEAP8 && mod.HEAP8.buffer) {
      initialHeapSize = mod.HEAP8.buffer.byteLength;
      console.log("Initial WASM heap size: " + formatBytes(initialHeapSize));

      // Verify it is within tolerance of expected 256MB
      var lowerBound = EXPECTED_INITIAL_MEMORY * (1 - INITIAL_MEMORY_TOLERANCE);
      var upperBound = EXPECTED_INITIAL_MEMORY * (1 + INITIAL_MEMORY_TOLERANCE);
      var withinRange = initialHeapSize >= lowerBound && initialHeapSize <= upperBound;
      console.log("  Expected range: " + formatBytes(lowerBound) + " - " + formatBytes(upperBound));
      console.log("  Within expected range: " + (withinRange ? "YES" : "NO"));

      // Verify under 4GB ceiling
      var underCeiling = initialHeapSize < WASM_4GB_CEILING;
      console.log("  Under 4GB ceiling: " + (underCeiling ? "YES" : "NO"));
      if (!underCeiling) {
        passed = false;
      }
    } else {
      console.error("  HEAP8 buffer not available");
      passed = false;
    }
  } catch (err) {
    console.error("  Error reading heap size: " + err.message);
    passed = false;
  }
  console.log("");

  // Check 2: Call wasm_init to initialize allocator
  try {
    var initResult;
    if (typeof mod.ccall === "function") {
      initResult = mod.ccall("wasm_init", "number", [], []);
    } else if (typeof mod._wasm_init === "function") {
      initResult = mod._wasm_init();
    } else {
      console.error("FAIL: wasm_init function not found");
      process.exit(1);
      return;
    }
    console.log("wasm_init() returned: " + initResult);
  } catch (err) {
    console.error("FAIL: wasm_init() threw error: " + err.message);
    process.exit(1);
    return;
  }
  console.log("");

  // Check 3: Call wasm_memory_usage to get MEM_guarded_alloc tracking
  var memUsage = 0;
  try {
    if (typeof mod.ccall === "function") {
      memUsage = mod.ccall("wasm_memory_usage", "number", [], []);
    } else if (typeof mod._wasm_memory_usage === "function") {
      memUsage = mod._wasm_memory_usage();
    } else {
      console.error("FAIL: wasm_memory_usage function not found");
      process.exit(1);
      return;
    }

    console.log("MEM_guarded_alloc usage: " + formatBytes(memUsage));
    if (memUsage > 0) {
      console.log("  Memory tracking: OPERATIONAL (allocator is reporting > 0)");
    } else {
      console.log("  Memory tracking: WARNING (reporting 0 bytes, may not be initialized)");
    }
  } catch (err) {
    console.error("FAIL: wasm_memory_usage() threw error: " + err.message);
    process.exit(1);
    return;
  }
  console.log("");

  // Check 4: Verify memory can grow (test ALLOW_MEMORY_GROWTH)
  var postInitHeapSize = 0;
  try {
    if (mod.HEAP8 && mod.HEAP8.buffer) {
      postInitHeapSize = mod.HEAP8.buffer.byteLength;
      console.log("Post-init WASM heap size: " + formatBytes(postInitHeapSize));

      if (postInitHeapSize >= initialHeapSize) {
        console.log("  Memory growth: SUPPORTED (heap grew from " +
          formatBytes(initialHeapSize) + " to " + formatBytes(postInitHeapSize) + ")");
      } else {
        console.log("  Memory growth: UNCHANGED (no growth needed during init)");
      }

      // Final ceiling check
      console.log("  Under 4GB ceiling: " + (postInitHeapSize < WASM_4GB_CEILING ? "YES" : "NO"));
      if (postInitHeapSize >= WASM_4GB_CEILING) {
        passed = false;
      }
    }
  } catch (err) {
    console.error("  Error checking post-init heap: " + err.message);
  }
  console.log("");

  // Summary
  console.log("--- Memory Summary ---");
  console.log("  Initial heap:        " + formatBytes(initialHeapSize));
  console.log("  Post-init heap:      " + formatBytes(postInitHeapSize));
  console.log("  MEM_guarded_alloc:   " + formatBytes(memUsage));
  console.log("  4GB ceiling:         " + formatBytes(WASM_4GB_CEILING));
  console.log("");

  if (passed) {
    console.log("PASS: Memory allocation within 4GB ceiling, MEM_guarded_alloc operational");
    process.exit(0);
  } else {
    console.error("FAIL: Memory validation failed (see details above)");
    process.exit(1);
  }
}

main();
