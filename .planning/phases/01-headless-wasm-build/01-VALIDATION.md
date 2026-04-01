---
phase: 1
slug: headless-wasm-build
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-01
---

# Phase 1 -- Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Emscripten build system + Node.js for WASM validation |
| **Config file** | CMakeLists.txt (Emscripten toolchain) |
| **Quick run command** | `node test-wasm-load.js` |
| **Full suite command** | `emcmake cmake --build build-wasm && node test-wasm-load.js` |
| **Estimated runtime** | ~300 seconds (build) / ~5 seconds (validation) |

---

## Sampling Rate

- **After every task commit:** Run `node test-wasm-load.js` (if binary exists)
- **After every plan wave:** Run full build + validation
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds (validation only)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 1 | BUILD-01 | build | `emcmake cmake .. && cmake --build .` | -- W0 | pending |
| 1-01-02 | 01 | 1 | BUILD-02 | build | `cmake --build . 2>&1 \| grep -v error` | -- W0 | pending |
| 1-02-01 | 02 | 1 | BUILD-03 | runtime | `node test-threading.js` | -- W0 | pending |
| 1-02-02 | 02 | 1 | BUILD-04 | runtime | `node test-memory.js` | -- W0 | pending |
| 1-03-01 | 03 | 2 | BUILD-05 | config | `grep -q "Cross-Origin" server.js` | -- W0 | pending |
| 1-03-02 | 03 | 2 | BUILD-06 | runtime | `node test-main-loop.js` | -- W0 | pending |
| 1-04-01 | 04 | 2 | BUILD-07 | build | `ls -la build-wasm/*.wasm.br` | -- W0 | pending |
| 1-04-02 | 04 | 2 | BUILD-08 | build | `grep -q "SIMD" build-wasm/CMakeCache.txt` | -- W0 | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] Install Emscripten SDK 5.0.4 (or use Docker emscripten/emsdk:5.0.4)
- [ ] Create build-wasm/ directory with Emscripten toolchain
- [ ] Build native host tools (makesdna, makesrna, datatoc) first
- [ ] Create test-wasm-load.js -- validates WASM loads and initializes

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| WASM runs in browser tab | BUILD-01 | Requires browser environment | Open test.html in Chrome with DevTools, verify no errors |
| SharedArrayBuffer works | BUILD-03 | Requires COOP/COEP headers | Serve with proper headers, check Worker spawning in DevTools |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
