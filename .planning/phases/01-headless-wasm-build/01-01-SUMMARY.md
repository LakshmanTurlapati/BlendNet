---
phase: 01-headless-wasm-build
plan: 01
subsystem: infra
tags: [emscripten, wasm, cmake, docker, cross-compilation, simd, pthreads, mimalloc]

# Dependency graph
requires: []
provides:
  - "Dockerfile with emscripten/emsdk:5.0.4 reproducible build environment"
  - "CMake Emscripten override file with all WASM compile/link flags"
  - "Three-stage build scripts (host tools, deps, WASM compilation)"
  - "Docker Compose configuration for mounted Blender source builds"
affects: [01-02, 01-03, 02-ghost-sdl-browser-backend]

# Tech tracking
tech-stack:
  added: [emscripten-5.0.4, ninja-build, ccache, brotli, mimalloc, docker]
  patterns: [three-stage-cross-compilation, section-marker-extension-points, emscripten-ports]

key-files:
  created:
    - Dockerfile
    - .dockerignore
    - .gitignore
    - docker-compose.yml
    - cmake/emscripten_overrides.cmake
    - cmake/wasm_toolchain.cmake
    - scripts/build-host-tools.sh
    - scripts/build-wasm.sh
    - scripts/build-wasm-deps.sh
  modified: []

key-decisions:
  - "Used -C flag (initial cache) to load emscripten_overrides.cmake rather than toolchain file augmentation"
  - "35 WITH_* flags configured (exceeding 25+ minimum) for comprehensive headless mode"
  - "Section markers (SECTION: Environment Setup, CMake Configuration, Compilation, Post-Build) for Plan 03 extension"
  - "Emscripten ports for zlib, libpng, FreeType, Bullet; SDL explicitly disabled"

patterns-established:
  - "Three-stage build: native host tools -> WASM deps -> WASM Blender"
  - "Section comment markers in scripts for cross-plan extension points"
  - "SPDX headers on all files per Blender conventions"
  - "set -euo pipefail in all shell scripts"

requirements-completed: [BUILD-01, BUILD-02, BUILD-08]

# Metrics
duration: 3min
completed: 2026-04-01
---

# Phase 01 Plan 01: Build Infrastructure Summary

**Three-stage Emscripten 5.0.4 cross-compilation pipeline with Docker, CMake WASM overrides (SIMD, pthreads, PROXY_TO_PTHREAD, mimalloc), and 35 WITH_* flags for headless Blender**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-01T11:54:38Z
- **Completed:** 2026-04-01T11:58:03Z
- **Tasks:** 2
- **Files created:** 9

## Accomplishments

- Dockerfile with emscripten/emsdk:5.0.4 base image providing reproducible build environment with ninja-build, ccache, python3, and brotli
- CMake Emscripten override file containing all 11+ required WASM link flags (SIMD, threading, memory, PROXY_TO_PTHREAD, mimalloc, wasm-exceptions) and conditional debug/release configurations
- Native host tools build script (Stage 1) targeting makesdna, makesrna, datatoc with minimal CMake configuration
- WASM build script (Stage 3) with 35 WITH_* flags, emcmake configuration, and clearly marked section comments for Plan 03 to extend
- Dependency verification script (Stage 2) documenting and pre-fetching Emscripten ports (zlib, libpng, FreeType, Bullet)

## Task Commits

Each task was committed atomically:

1. **Task 1: Project scaffolding, Dockerfile, and native host tools build** - `08bffa9` (feat)
2. **Task 2: CMake Emscripten configuration and WASM build script** - `55f9c27` (feat)

## Files Created/Modified

- `Dockerfile` - Reproducible Emscripten 5.0.4 build environment with ninja, ccache, python3, brotli
- `.dockerignore` - Excludes build output, .git, .planning, node_modules from Docker context
- `.gitignore` - Excludes build-native/, build-wasm/, Blender Mirror/, .ccache/ from version control
- `docker-compose.yml` - Build service with Blender Mirror mounted read-only, build output volumes, ccache
- `cmake/emscripten_overrides.cmake` - Central WASM compile/link flags (SIMD, pthreads, memory, PROXY_TO_PTHREAD, exports)
- `cmake/wasm_toolchain.cmake` - Toolchain overrides with Node.js cross-compilation emulator and platform detection
- `scripts/build-host-tools.sh` - Stage 1: native cmake build of makesdna, makesrna, datatoc
- `scripts/build-wasm.sh` - Stage 3: emcmake cmake with 35 WITH_* flags and section markers
- `scripts/build-wasm-deps.sh` - Stage 2: Emscripten port verification (USE_ZLIB, USE_LIBPNG, USE_FREETYPE, USE_BULLET)

## Decisions Made

- Used `-C` flag (CMake initial cache) to load emscripten_overrides.cmake during build configuration, keeping flags centralized in one file rather than scattered across command-line arguments
- Configured 35 WITH_* flags (exceeding the 25+ minimum) to comprehensively disable all unsupported features for headless WASM mode while enabling Bullet physics, IK solvers, and remesh modifier
- Established section comment markers (SECTION: Environment Setup, CMake Configuration, Compilation, Post-Build) as a cross-plan interface contract so Plan 03 can locate and extend the right sections
- Used Emscripten ports for zlib, libpng, FreeType, and Bullet; explicitly disabled SDL (USE_SDL=0) for headless mode
- Set PROXY_TO_PTHREAD with ALLOW_BLOCKING_ON_MAIN_THREAD=0 and PTHREAD_POOL_SIZE=navigator.hardwareConcurrency for non-blocking browser main thread

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added .gitignore for build output directories**
- **Found during:** Task 1
- **Issue:** Plan did not specify a .gitignore file, but build-native/ and build-wasm/ directories would pollute the repository when builds are run
- **Fix:** Created .gitignore excluding build-native/, build-wasm/, wasm-deps/, .ccache/, Blender Mirror/, and common editor/OS files
- **Files modified:** .gitignore
- **Verification:** git status no longer shows Blender Mirror as untracked
- **Committed in:** 08bffa9 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Essential for repository hygiene. No scope creep.

## Issues Encountered

None

## Known Stubs

None - all files contain complete implementations for the build infrastructure scope.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Build infrastructure is ready for Plan 02 (headless entry point and .blend file loading)
- Plan 03 can extend build-wasm.sh via the section markers (SECTION: CMake Configuration, SECTION: Post-Build)
- Docker environment can be built with `docker-compose build` when Emscripten builds are needed
- Host tools script can be tested locally with `./scripts/build-host-tools.sh` (requires CMake and Ninja)

## Self-Check: PASSED

All 9 created files verified present on disk. Both task commits (08bffa9, 55f9c27) verified in git log.

---
*Phase: 01-headless-wasm-build*
*Completed: 2026-04-01*
