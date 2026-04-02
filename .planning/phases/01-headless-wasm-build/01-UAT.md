---
status: diagnosed
phase: 01-headless-wasm-build
source:
  - 01-05-SUMMARY.md
  - 01-06-SUMMARY.md
started: 2026-04-02T17:33:28Z
updated: 2026-04-02T17:33:28Z
---

## Current Test

[testing complete]

## Tests

### 1. Node Runtime Initialization
expected: `build-wasm/blender.{js,wasm}` load successfully in Node and `wasm_init()` returns `0`
result: pass

### 2. Browser Runtime Initialization
expected: `web/index.html` shows COOP/COEP isolation, glue load, runtime initialization, and successful exported calls in Chromium
result: pass

### 3. Real `.blend` Load And Scene Query
expected: A real `.blend` file loads through MEMFS, `wasm_load_blend()` returns a non-negative object count, and `wasm_query_scene()` returns scene JSON
result: issue
reported: "Automated run against https://download.blender.org/demo/Blender-282.blend trapped with `RuntimeError: null function or function signature mismatch` inside `wasm_load_blend()`."
severity: blocker

## Summary

total: 3
passed: 2
issues: 1
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "A real `.blend` file can be loaded and queried through `wasm_load_blend()` and `wasm_query_scene()`"
  status: failed
  reason: "Automated verification against the official sample at https://download.blender.org/demo/Blender-282.blend triggers `RuntimeError: null function or function signature mismatch` during `wasm_load_blend()`."
  severity: blocker
  test: 3
  root_cause: "Blend-file loading reaches a null or mismatched indirect call inside the current WASM runtime while parsing a valid sample file. The exact callee is not yet symbolized in the release build."
  artifacts:
    - path: "source/wasm_headless_main.cc"
      issue: "`wasm_load_blend()` reproduces the trap when `BLO_read_from_file()` processes a real sample `.blend`"
    - path: "build-wasm/blender.js"
      issue: "Release/minified output obscures the failing internal call site"
  missing:
    - "Produce a symbolized/assertions-enabled reproduction of the trap"
    - "Map the failing indirect call to the responsible loader/versioning subsystem"
    - "Patch the runtime so a real `.blend` returns scene JSON"
  debug_session: ""
