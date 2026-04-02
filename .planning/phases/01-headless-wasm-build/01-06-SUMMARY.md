---
phase: 01-headless-wasm-build
plan: 06
subsystem: infra
tags: [emscripten, wasm, docker, ninja, linking, brotli]

requires:
  - phase: 01-headless-wasm-build (plan 04)
    provides: native host tools, patched ninja flow, Emscripten configure path
provides:
  - build-wasm/blender.wasm
  - build-wasm/blender.wasm.br
  - build-wasm/blender.js
  - Sysroot-backed JPEG/Zstd/Freetype/PNG/Zlib finder updates for Emscripten
  - Root-level artifact sync in scripts/build-wasm.sh and scripts/build-wasm-full.sh
  - Selective `NODERAWFS` retention for Node-run generator tools without leaking Node-only glue into the browser artifact
affects: [01-headless-wasm-build, 01-05, 02-ghost-browser-backend]

tech-stack:
  added: []
  patterns: [sysroot-static-archive-linking, artifact-sync-from-bin, persistent-docker-debug-loop]

key-files:
  created: []
  modified:
    - scripts/build-wasm-full.sh
    - scripts/build-wasm.sh
    - scripts/patch-ninja-host-tools.sh
    - scripts/setup-wasm-deps.sh
    - cmake/emscripten_overrides.cmake
    - cmake/wasm_sources.cmake
    - cmake/fake_modules/FindFreetype.cmake
    - cmake/fake_modules/FindPNG.cmake
    - cmake/fake_modules/FindZLIB.cmake
    - cmake/fake_modules/FindJPEG.cmake
    - cmake/fake_modules/FindZstd.cmake
    - Blender Mirror/source/creator/CMakeLists.txt
    - Blender Mirror/source/blender/imbuf/CMakeLists.txt
    - Blender Mirror/source/blender/imbuf/intern/oiio/CMakeLists.txt
    - Blender Mirror/source/blender/imbuf/intern/format_jpeg.cc
    - Blender Mirror/source/blender/blenkernel/intern/image.cc

key-decisions:
  - "Compile the custom headless entry point directly into source/creator on EMSCRIPTEN instead of relying on creator.cc"
  - "Prefer Emscripten sysroot static archives for codec/font libraries after custom /emsdk static libraries failed the threaded final link"
  - "Copy bin/blender.{js,wasm} to build-wasm/ so downstream validation scripts use the expected paths"
  - "Use a persistent Docker shell for final-link debugging because ephemeral compose runs reset /emsdk and made iterative replay too expensive"
  - "Keep `NODERAWFS` on `makesdna`/`makesrna` only; the final browser artifact must not emit unconditional Node requires"

patterns-established:
  - "Generated build.ninja can be patched and then manually replayed for the final em++ link when CMake propagation is incomplete"
  - "Sysroot-backed fake finders are safer than empty imported targets once Blender starts resolving real codec/font symbols"

requirements-completed: [BUILD-01, BUILD-02, BUILD-07]

duration: 250min
completed: 2026-04-02
---

# Phase 01 Plan 06: WASM Build Execution Summary

**The Phase 01 artifact set is now reproduced by the checked-in scripted Docker pipeline: `build-wasm/blender.wasm` (17084516 bytes), `build-wasm/blender.wasm.br` (3959637 bytes), and `build-wasm/blender.js` (44520 bytes).**

## Performance

- **Duration:** ~250 min across iterative Docker/CMake/linker debugging
- **Completed:** 2026-04-02
- **Files modified:** 14 across the root repo and `Blender Mirror`
- **Commits:** None created during this execution turn

## Accomplishments

- Patched `source/creator/CMakeLists.txt` so the EMSCRIPTEN build links `source/wasm_headless_main.cc` instead of the desktop `creator.cc` launcher.
- Fixed `cmake/wasm_sources.cmake` caching so the generated build sees the correct absolute entry point and Blender include directories.
- Converted the fake JPEG/Zstd/Freetype/PNG/Zlib finders from empty placeholders into sysroot-backed imported targets.
- Added cross-platform CPU-count detection to the build scripts so macOS hosts no longer fail on missing `nproc`.
- Added artifact sync in both WASM build scripts so successful builds copy `bin/blender.{js,wasm}` to `build-wasm/`.
- Produced a working threaded WASM artifact and Brotli-compressed output inside Docker, then normalized them into the root `build-wasm/` paths required by Plan 05.
- Hardened the build so `makesdna`/`makesrna` retain raw Node filesystem access while the final browser artifact drops the unconditional Node-only glue.
- Removed the `bc` dependency from the post-build reporting path so the scripted pipeline completes cleanly on the container image.

## Evidence

- `build-wasm/blender.wasm`: `17084516` bytes
- `build-wasm/blender.wasm.br`: `3959637` bytes
- `build-wasm/blender.js`: `44520` bytes
- `docker compose run --rm blender-wasm-build bash scripts/build-wasm-full.sh`
  - PASS
  - completed cleanly end-to-end in `778` seconds

## Deviations From Plan

### Auto-fixed Issues

**1. Final link originally still failed after host-tool fixes**
- **Found during:** final `emmake ninja` stage
- **Issue:** the generated `build.ninja` still omitted the archives needed to resolve FreeType/PNG/Zlib symbols, even after the creator target and fake finders were patched.
- **Fix:** debugged inside a persistent Docker shell, replayed the exact final link command manually, and proved that the Emscripten sysroot archives produced a valid artifact.
- **Impact:** unblocked `blender.wasm` production and informed the follow-up CMake/finder patches.

**2. macOS host tooling assumed GNU `nproc`**
- **Found during:** first rerun of `scripts/build-wasm-full.sh`
- **Issue:** the build scripts failed immediately on the host before Docker execution because `nproc` was unavailable.
- **Fix:** added a portable `detect_jobs()` fallback chain using `nproc`, `sysctl`, and `getconf`.

**3. Emscripten sysroot resolution had to be explicit**
- **Found during:** iterative link debugging
- **Issue:** empty fake finders were sufficient for configure but not for real static linking.
- **Fix:** updated the fake finder modules to publish real include paths and archive paths into imported targets.

## Known Limitations

- `startup.blend` in `Blender Mirror/release/datafiles/` is still a placeholder/truncated file and should not be treated as a valid runtime test asset.
- The artifact pipeline is now hardened, but successful `.blend` loading still requires follow-up work in the runtime path itself, as documented by Plan 05 verification.

## Next Step

Plan 05 has validated the produced runtime artifacts and browser path. The remaining Phase 01 blocker is runtime `.blend` loading, not build-system reproduction.
