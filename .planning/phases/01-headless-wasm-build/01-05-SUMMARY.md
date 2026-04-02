---
phase: 01-headless-wasm-build
plan: 05
subsystem: validation
tags: [node, wasm, pthreads, memory, coop, coep, runtime]

requires:
  - phase: 01-headless-wasm-build (plan 06)
    provides: build-wasm/blender.wasm, build-wasm/blender.wasm.br, build-wasm/blender.js
provides:
  - Passing Node.js validation scripts for load, threading, memory, and main-loop checks
  - Updated test harnesses compatible with non-modularized Emscripten glue output
  - Automated COOP/COEP header verification for the dev server
  - Headless Chromium verification for browser-side runtime initialization
  - Diagnosed runtime gap for real `.blend` file loading using an official sample
affects: [01-headless-wasm-build, 02-ghost-browser-backend]

tech-stack:
  added: []
  patterns: [global-module-bootstrap-for-emscripten, glue-introspection-fallbacks, bounded-http-header-probing]

key-files:
  created: []
  modified:
    - scripts/test-wasm-load.js
    - scripts/test-threading.js
    - scripts/test-memory.js
    - scripts/test-main-loop.js
    - web/index.html
    - cmake/emscripten_overrides.cmake
    - scripts/patch-ninja-host-tools.sh

key-decisions:
  - "Bootstrap validation scripts through global.Module because the generated blender.js is a non-modularized auto-running Emscripten output"
  - "Parse INITIAL_MEMORY from the generated glue when the runtime does not expose HEAP8 or wasmMemory on Module"
  - "Treat Node main-loop timing as an automated proxy only; headless Chromium is the stronger proof for PROXY_TO_PTHREAD"
  - "Keep `-sNODERAWFS=1` only on the Node-run generator tools and remove it from the final browser artifact"
  - "Validate blend loading against an official external sample rather than claiming a pass from local LFS pointers or placeholders"

patterns-established:
  - "Validation harnesses should support both modularized factory exports and legacy/non-modularized `global.Module` glue"
  - "Memory tests for minified Emscripten output may need to inspect configured memory rather than exported heap views"

requirements-completed: [BUILD-01, BUILD-03, BUILD-04, BUILD-05, BUILD-06, BUILD-07]

duration: 45min
completed: 2026-04-02
---

# Phase 01 Plan 05: Runtime Validation Summary

**All four automated Node.js validation scripts now pass, the browser runtime initializes successfully in headless Chromium, and the remaining gap is narrowed to a real `.blend` loading trap inside `wasm_load_blend()`.**

## Performance

- **Duration:** ~45 min
- **Completed:** 2026-04-02
- **Files modified:** 4
- **Commits:** None created during this execution turn

## Automated Validation Results

### Node.js runtime checks

- `node scripts/test-wasm-load.js`
  - PASS
  - `wasm_init()` returned `0`
- `node scripts/test-threading.js`
  - PASS
  - `SharedArrayBuffer` and `Atomics` are available
- `node scripts/test-memory.js`
  - PASS
  - configured initial heap resolves to `256 MB`
  - `wasm_memory_usage()` reported `1620` bytes after init
- `node scripts/test-main-loop.js`
  - PASS
  - initialization completed within the timeout window
  - Node-side event-loop evidence is variable, so browser verification is still the stronger runtime proof

### Dev server checks

- `curl --max-time 5 -D - -o /dev/null http://localhost:8080/web/index.html`
  - returned `Cross-Origin-Opener-Policy: same-origin`
  - returned `Cross-Origin-Embedder-Policy: require-corp`
- `curl --max-time 5 -D - -o /dev/null http://localhost:8080/build-wasm/blender.wasm.br`
  - returned `Content-Type: application/wasm`
  - returned `Content-Encoding: br`

### Browser runtime check

- Headless Chromium against `http://localhost:8080/web/index.html`
  - PASS
  - `Cross-Origin Isolation`: `ENABLED`
  - `SharedArrayBuffer`: `AVAILABLE`
  - `WASM Module`: `READY`
  - `WASM Runtime`: `INITIALIZED`
  - `wasm_init()`: `Returned: 0 (success)`
  - `wasm_memory_usage()`: `0.00 MB (1620 bytes)`
  - no page errors, and the earlier `require is not defined` regression is gone

## Deviations From Plan

### Auto-fixed Issues

**1. Validation scripts assumed modularized Emscripten output**
- **Found during:** first `test-wasm-load.js` execution
- **Issue:** `build-wasm/blender.js` exports a non-modularized `Module` object and auto-runs immediately, so the original harness never received `onRuntimeInitialized`.
- **Fix:** updated all four validation scripts to seed `global.Module` before `require()` and to handle both modularized and non-modularized outputs.

**2. Memory test assumed `HEAP8` was exported on `Module`**
- **Found during:** first `test-memory.js` execution
- **Issue:** this glue does not expose `HEAP8` or `wasmMemory`, causing a false failure despite a working runtime.
- **Fix:** added a fallback that reads `INITIAL_MEMORY` from the generated glue and reports that source explicitly.

## Runtime Gap

The exported C API path is callable, and browser verification now passes. The remaining failure is specific to real `.blend` loading:

- An official sample file was downloaded from `https://download.blender.org/demo/Blender-282.blend`.
- That file was copied into MEMFS and passed to `wasm_load_blend("/data/Blender-282.blend")`.
- The call trapped with `RuntimeError: null function or function signature mismatch` before returning an object count or scene JSON.

## Next Step

The next engineering step is not manual browser work. It is targeted diagnosis of the `wasm_load_blend()` runtime trap so real scene loading can succeed.
