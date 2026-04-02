---
phase: 01-headless-wasm-build
verified: 2026-04-02T17:33:28Z
status: gaps_found
score: 4/5 must-haves verified
gaps:
  - truth: "A real .blend file can be loaded at runtime and queried via wasm_query_scene()"
    status: failed
    reason: "A valid official sample `.blend` file now reaches `wasm_load_blend()`, but the runtime traps with `RuntimeError: null function or function signature mismatch` while parsing it."
    artifacts:
      - path: "/tmp/Blender-282.blend"
        issue: "Official sample file downloaded from https://download.blender.org/demo/Blender-282.blend reproduces the runtime trap"
      - path: "source/wasm_headless_main.cc"
        issue: "`wasm_load_blend()` reaches a null indirect call during `BLO_read_from_file()` processing"
      - path: "build-wasm/blender.js"
        issue: "Release build is minified, so the failing call site is not yet mapped to a concrete Blender subsystem"
    missing:
      - "Produce a symbolized/assertions-enabled reproduction for the `wasm_load_blend()` trap"
      - "Map the failing indirect call to the responsible loader/versioning subsystem"
      - "Patch the runtime so a real `.blend` returns a non-negative object count and scene JSON"
human_verification: []
---

# Phase 01: Headless WASM Build Verification Report

**Phase Goal:** Blender's core engine compiles to WebAssembly and can load/query scene data without any display  
**Verified:** 2026-04-02T17:33:28Z  
**Status:** gaps_found

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | The WASM binary can be produced and loaded without export or link errors | VERIFIED | `build-wasm/blender.wasm`, `build-wasm/blender.wasm.br`, and `build-wasm/blender.js` now exist. `node scripts/test-wasm-load.js` passes and `wasm_init()` returns `0`. |
| 2 | A `.blend` file can be loaded and queried through the exported C API | FAILED | An official sample file at `https://download.blender.org/demo/Blender-282.blend` was copied into MEMFS and passed to `wasm_load_blend()`, which trapped with `RuntimeError: null function or function signature mismatch`. |
| 3 | Threading and worker prerequisites are operational | VERIFIED | `scripts/test-threading.js` passes, `SharedArrayBuffer` works in Node.js, and a headless Chromium run confirms COOP/COEP isolation plus a successful browser-side runtime initialization. |
| 4 | Memory stays within the configured 4 GB ceiling and reports allocator usage | VERIFIED | `scripts/test-memory.js` passes, resolves the configured `256 MB` initial heap, and `wasm_memory_usage()` reports `1620` bytes after init. |
| 5 | The compressed WASM artifact is under 30 MB and server-ready | VERIFIED | `build-wasm/blender.wasm.br` is `3962205` bytes and `web/serve.py` serves `.wasm.br` with `Content-Encoding: br` and `Content-Type: application/wasm`. |

## Current Artifact State

| Artifact | Status | Evidence |
|----------|--------|----------|
| `build-wasm/blender.wasm` | VERIFIED | `17084516` bytes |
| `build-wasm/blender.wasm.br` | VERIFIED | `3959637` bytes |
| `build-wasm/blender.js` | VERIFIED | `44520` bytes |
| `scripts/test-wasm-load.js` | VERIFIED | Passes against the produced binary |
| `scripts/test-threading.js` | VERIFIED | Passes against the produced binary |
| `scripts/test-memory.js` | VERIFIED | Passes against the produced binary |
| `scripts/test-main-loop.js` | VERIFIED | Passes against the produced binary |
| `web/serve.py` | VERIFIED | Curl confirms COOP/COEP and Brotli WASM headers |
| `web/index.html` | VERIFIED | Headless Chromium reports `WASM Runtime INITIALIZED`, `wasm_init() Returned: 0 (success)`, and `wasm_memory_usage() 1620 bytes` |

## Requirements Coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| BUILD-01 | SATISFIED | `test-wasm-load.js` passes |
| BUILD-02 | SATISFIED | The produced module initializes and exports the required C API without runtime link failures |
| BUILD-03 | SATISFIED | Node and browser both confirm SharedArrayBuffer-capable threaded runtime prerequisites |
| BUILD-04 | SATISFIED | Memory validation passes and allocator usage is reported |
| BUILD-05 | SATISFIED | `web/serve.py` emits the required COOP/COEP headers |
| BUILD-06 | SATISFIED | `test-main-loop.js` passes and headless Chromium reaches browser-side runtime initialization without blocking or script errors |
| BUILD-07 | SATISFIED | Brotli artifact exists and is served with correct headers |
| BUILD-08 | SATISFIED | The module builds and runs with the configured SIMD flags |

**Coverage summary:** 8/8 satisfied, 0/8 partial, 0/8 missing infrastructure.

## Key Findings

- Phase 01 now has a clean scripted Docker build, passing Node.js validation, and a passing browser-side runtime verification in headless Chromium.
- The remaining blocker is no longer missing test data or manual browser work.
- A real official `.blend` sample reproduces a runtime trap inside `wasm_load_blend()`, which narrows the gap to the Blender file-loading path itself.

## Remaining Gap

1. Produce a symbolized/assertions-enabled reproduction of the `wasm_load_blend()` trap so the failing indirect call can be mapped to a concrete subsystem.
2. Patch the loader/runtime path so `wasm_load_blend()` returns a non-negative object count for a real `.blend`.
3. Re-run `wasm_query_scene()` against that successful load and confirm scene JSON is returned.

---

_Verified: 2026-04-02T17:33:28Z_  
_Verifier: Codex_
