# Phase 1: Headless WASM Build - Research

**Researched:** 2026-04-01
**Domain:** C/C++ to WebAssembly cross-compilation via Emscripten; headless 3D engine build system
**Confidence:** MEDIUM-HIGH -- Emscripten toolchain is well-documented and the Blender build system is thoroughly understood from source analysis, but no prior full Blender WASM build exists as reference.

## Summary

Phase 1 establishes the foundation for the entire Blender Web project: getting Blender's 4.4M+ lines of C/C++ to compile to WebAssembly via Emscripten and produce a headless binary that can load .blend files and query scene data. This is purely a build system and compilation phase -- no rendering, no UI, no user interaction.

The Blender source has a clean layered architecture with well-defined CMake feature flags (`WITH_*` options, 150+). The headless build strategy disables all platform-specific and rendering code, uses the existing `GHOST_SystemHeadless` backend and `gpu/dummy/` GPU backend, and focuses on the "pure C/C++" core: blenlib, makesdna/makesrna, blenkernel, depsgraph, bmesh, geometry, nodes, functions, blenloader. These modules have VERY LOW to LOW portability risk as they are pure computation with no platform dependencies.

**Primary recommendation:** Use Emscripten 5.0.4+ with `-sPROXY_TO_PTHREAD`, `-sMALLOC=mimalloc`, `-pthread`, `-msimd128`, `-fwasm-exceptions`, `-sALLOW_MEMORY_GROWTH=1`, and `-sMAXIMUM_MEMORY=4GB`. Build in a Docker container (`emscripten/emsdk`) for reproducibility. Solve the three-stage cross-compilation problem (native host tools -> WASM dependencies -> WASM Blender) first.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
None -- all implementation choices at Claude's discretion for this infrastructure phase.

### Claude's Discretion
All implementation choices are at Claude's discretion -- pure infrastructure phase. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions. Key technical references:
- Research: .planning/research/STACK.md (Emscripten 5.0.4, emdawnwebgpu, PROXY_TO_PTHREAD)
- Research: .planning/research/ARCHITECTURE.md (build order, dependency chain)
- Research: .planning/research/PITFALLS.md (main thread blocking, Asyncify avoidance, dependency failures)

### Deferred Ideas (OUT OF SCOPE)
None -- infrastructure phase.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BUILD-01 | Blender C/C++ source compiles to WebAssembly via Emscripten 5.0.4+ | Core finding: CMake + `emcmake` toolchain integration, WITH_* flag strategy for disabling unsupported features, three-stage build for host tools |
| BUILD-02 | All required third-party dependencies compile to WASM (or have WASM-compatible replacements) | Dependency matrix: Emscripten ports (zlib, libpng, FreeType, Bullet), cross-compilation candidates (Eigen, OpenEXR, OpenColorIO), and stubs/disables (TBB, USD, OpenXR) |
| BUILD-03 | Threading works via Emscripten pthreads mapped to Web Workers with SharedArrayBuffer | Emscripten pthreads docs verified: `-pthread`, `-sPTHREAD_POOL_SIZE`, COOP/COEP headers required |
| BUILD-04 | Memory allocation works within WASM32 4GB address space with MEM_guarded_alloc | MEM_guarded_alloc analysis: delegates to system malloc, compatible with mimalloc via `-sMALLOC=mimalloc`, needs `-sALLOW_MEMORY_GROWTH=1 -sMAXIMUM_MEMORY=4GB` |
| BUILD-05 | COOP/COEP headers configured for cross-origin isolation | Dev server must serve `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` |
| BUILD-06 | Main loop converted to non-blocking via emscripten_set_main_loop or PROXY_TO_PTHREAD | Source analysis: `WM_main()` in `wm.cc:596` is a simple `while(true)` with 4 calls -- use `-sPROXY_TO_PTHREAD` to avoid refactoring |
| BUILD-07 | WASM binary is served compressed (Brotli/gzip), with lazy loading for large modules | Emscripten wasm-split for module splitting, Brotli compression, `WebAssembly.compileStreaming()` for streaming compilation |
| BUILD-08 | WASM SIMD enabled for math-heavy operations | `-msimd128` for WASM SIMD 128-bit, `-mrelaxed-simd` for relaxed SIMD (FMA, etc.) |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Never run applications automatically; only when explicitly asked
- Never use emojis in terminal logs, readme files, or anywhere unless explicitly asked
- Never use emojis in markdown files or logging

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Emscripten (emsdk) | 5.0.4 (stable, March 2026) | C/C++ to WASM compiler | Only production-grade C/C++ to WASM toolchain. Provides CMake integration via `emcmake`, POSIX emulation, pthreads-to-Workers mapping. Blender uses CMake already. |
| Binaryen (wasm-opt) | Bundled with Emscripten 5.0.4 | WASM binary optimizer | 20-50% code size reduction via dead code elimination, inlining. Use `--converge` for maximum optimization. |
| LLVM/Clang | 19.x (bundled with Emscripten 5.0.4) | C/C++ frontend compiler | Emscripten bundles its own LLVM. Blender requires Clang 17+, compatible. |
| Docker (emscripten/emsdk) | Latest matching 5.0.4 | Reproducible build environment | Pre-configured Emscripten SDK in container. Eliminates "works on my machine" issues for a complex cross-compilation setup. |
| CMake | 3.10+ (4.0.0 available locally) | Build system | Blender's existing build system. Emscripten provides CMake toolchain file. |
| Ninja | Latest | Build executor | Faster incremental builds than Make. Critical for developer productivity on 4.4M line codebase. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ccache / sccache | Latest | Compilation caching | Always -- essential for reducing rebuild times from hours to minutes |
| Node.js | 18+ (25.6 available locally) | Emscripten runtime dependency | Required by Emscripten for JS code generation and testing |
| Python 3 | 3.13+ (3.14 available locally) | Build scripts, test infrastructure | Blender's build system uses Python for scripting |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Emscripten 5.0.4 | Cheerp (Leaning Technologies) | Less mature, smaller community, no equivalent ports system |
| Docker builds | Local emsdk install | Less reproducible, version drift across machines |
| Ninja | Make | Make is available but 5-10x slower incremental builds |
| mimalloc (`-sMALLOC=mimalloc`) | dlmalloc (default) | dlmalloc has single global lock, severe contention under Blender's multi-threaded workloads. mimalloc adds size but scales properly. |

**Installation:**
```bash
# Docker-based (recommended for reproducibility)
docker pull emscripten/emsdk:5.0.4

# Local install (development convenience)
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk && ./emsdk install 5.0.4 && ./emsdk activate 5.0.4
source ./emsdk_env.sh
```

## Architecture Patterns

### Recommended Project Structure

```
Blender Web/
  Blender Mirror/            # Blender source (read-only reference)
  build-native/              # Native host tools build (makesdna, makesrna, datatoc)
  build-wasm/                # Emscripten WASM build
  wasm-deps/                 # Pre-compiled WASM dependencies
  web/                       # Web serving infrastructure
    index.html               # Minimal test page
    serve.py                 # Dev server with COOP/COEP headers
  cmake/
    emscripten_overrides.cmake  # WASM-specific CMake configuration
    wasm_toolchain.cmake        # Emscripten toolchain customizations
  patches/                   # Minimal patches to Blender source for WASM compat
  scripts/
    build-host-tools.sh      # Stage 1: native host tools
    build-wasm-deps.sh       # Stage 2: cross-compile dependencies
    build-wasm.sh            # Stage 3: cross-compile Blender
    test-headless.js         # Node.js test harness for headless WASM
  Dockerfile                 # Reproducible build container
  docker-compose.yml         # Build orchestration
```

### Pattern 1: Three-Stage Cross-Compilation Build

**What:** Blender's build system uses host-side code generation tools (`makesdna`, `makesrna`, `datatoc`) that must run natively during the build. When cross-compiling with Emscripten, these tools cannot be WASM -- they must be native executables. This requires a three-stage build:

**Stage 1 -- Native Host Tools:**
```bash
mkdir build-native && cd build-native
cmake ../Blender\ Mirror \
  -DCMAKE_BUILD_TYPE=Release \
  -DWITH_BLENDER=OFF \
  -DWITH_CYCLES=OFF
make makesdna makesrna datatoc -j$(nproc)
```

**Stage 2 -- Cross-Compile Dependencies:**
```bash
# Dependencies available as Emscripten ports (use -sUSE_* flags):
# zlib, libpng, FreeType, Bullet, libjpeg-turbo
# Dependencies requiring manual cross-compilation:
# Eigen (header-only, no compilation needed)
# OpenEXR, OpenColorIO, OpenSubdiv (need emcmake)
```

**Stage 3 -- Cross-Compile Blender:**
```bash
mkdir build-wasm && cd build-wasm
emcmake cmake ../Blender\ Mirror \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CROSSCOMPILING_EMULATOR=node \
  -DWITH_HEADLESS=ON \
  -DWITH_GPU_BACKEND=DUMMY \
  ... # (full flags below)
emmake make -j$(nproc)
```

**When to use:** Always -- this is the only way to cross-compile Blender to WASM.

### Pattern 2: Aggressive Feature Disabling via CMake WITH_* Flags

**What:** Blender has 150+ `WITH_*` CMake options. For the headless WASM build, most features are disabled to minimize binary size and dependency complexity. The core data pipeline (load .blend, query scene) requires only a subset.

**Critical CMake configuration for headless WASM:**
```cmake
# ---- ENABLE ----
-DWITH_HEADLESS=ON            # No graphical UI
-DWITH_BULLET=ON              # Physics engine (compiles to WASM)
-DWITH_IK_SOLVER=ON           # IK (pure C)
-DWITH_IK_ITASC=ON            # iTaSC IK (pure C++)
-DWITH_MOD_FLUID=OFF          # Mantaflow -- defer (risky)
-DWITH_MOD_REMESH=ON          # Remesher (pure C++)
-DWITH_INTERNATIONAL=OFF      # i18n -- defer

# ---- DISABLE ----
-DWITH_PYTHON=OFF             # Python scripting -- Phase 9
-DWITH_CYCLES=OFF             # Rendering -- Phase 5+
-DWITH_GHOST_SDL=OFF          # SDL -- Phase 2
-DWITH_GHOST_X11=OFF          # X11 -- not applicable
-DWITH_GHOST_WAYLAND=OFF      # Wayland -- not applicable
-DWITH_OPENGL_BACKEND=OFF     # OpenGL -- not applicable
-DWITH_VULKAN_BACKEND=OFF     # Vulkan -- not applicable
-DWITH_OPENCOLORIO=OFF        # Color mgmt -- defer
-DWITH_OPENSUBDIV=OFF         # Subdivision -- defer
-DWITH_OPENVDB=OFF            # Volumes -- defer
-DWITH_OPENIMAGEDENOISE=OFF   # Denoiser -- defer
-DWITH_AUDASPACE=OFF          # Audio -- defer
-DWITH_FFTW3=OFF              # FFT -- defer
-DWITH_XR_OPENXR=OFF          # VR -- out of scope
-DWITH_TBB=OFF                # Intel TBB -- use pthreads instead
-DWITH_GMP=OFF                # Exact booleans -- defer
-DWITH_FREESTYLE=OFF          # NPR rendering -- defer
-DWITH_POTRACE=OFF            # Bitmap to vector -- defer
-DWITH_HARU=OFF               # PDF export -- defer
-DWITH_IMAGE_OPENEXR=OFF      # OpenEXR -- defer
-DWITH_CODEC_FFMPEG=OFF       # FFmpeg -- defer
-DWITH_USD=OFF                # Universal Scene Description -- defer
-DWITH_ALEMBIC=OFF            # Alembic -- defer
```

### Pattern 3: PROXY_TO_PTHREAD for Main Thread Safety

**What:** Use Emscripten's `-sPROXY_TO_PTHREAD` flag to move Blender's `main()` function to a Web Worker, leaving the browser main thread free for proxied operations.

**Why critical:** Blender's `WM_main()` (source: `source/blender/windowmanager/intern/wm.cc:596`) is a blocking `while(true)` loop. The browser main thread cannot block. PROXY_TO_PTHREAD solves this without requiring main loop refactoring.

```
// Blender's actual main loop (wm.cc:596-616):
void WM_main(bContext *C)
{
  wm_event_do_refresh_wm_and_depsgraph(C);
  while (true) {
    wm_window_events_process(C);
    wm_event_do_handlers(C);
    wm_event_do_notifiers(C);
    wm_draw_update(C);
  }
}
```

With `-sPROXY_TO_PTHREAD`, this entire loop runs on a Web Worker. For Phase 1 (headless), we do not even enter `WM_main()` -- we write a custom entry point that initializes the core engine, loads a .blend file, and queries data.

**Emscripten link flags:**
```
-sPROXY_TO_PTHREAD
-sALLOW_BLOCKING_ON_MAIN_THREAD=0
-pthread
-sPTHREAD_POOL_SIZE=navigator.hardwareConcurrency
-sPTHREAD_POOL_SIZE_STRICT=0
```

### Pattern 4: Custom Headless Entry Point for Phase 1

**What:** Instead of using Blender's full `main()` -> `WM_main()` flow, create a minimal custom entry point that only initializes the data pipeline and provides a test harness.

```cpp
// wasm_headless_main.cc -- Phase 1 entry point
#include "BKE_blendfile.hh"
#include "BKE_main.hh"
#include "BKE_scene.hh"
#include "DNA_scene_types.h"
#include "MEM_guardedalloc.h"

#include <emscripten.h>
#include <stdio.h>

extern "C" {

EMSCRIPTEN_KEEPALIVE
int wasm_init() {
  // Initialize memory allocator (MEM_guarded_alloc)
  // Initialize DNA/RNA
  // Return success/failure
}

EMSCRIPTEN_KEEPALIVE
int wasm_load_blend(const char *path) {
  // Load .blend from Emscripten MEMFS
  // Return number of objects in scene
}

EMSCRIPTEN_KEEPALIVE
const char* wasm_query_scene() {
  // Return JSON with scene objects, meshes, materials
}

EMSCRIPTEN_KEEPALIVE
size_t wasm_memory_usage() {
  // Return MEM_guarded_alloc tracked usage
}

} // extern "C"
```

### Anti-Patterns to Avoid

- **Global Asyncify:** Do NOT use `-sASYNCIFY` on the entire codebase. On 4.4M lines with extensive function pointers, this would double binary size, add 50% performance overhead, and cause hours-long link times. Use `-sPROXY_TO_PTHREAD` instead.
- **Building everything at once:** Do NOT try to compile all of Blender with all features enabled. Start with the minimal headless core and enable features incrementally.
- **Patching Blender source directly:** Minimize patches to the Blender Mirror source. Use CMake overrides, compiler defines, and wrapper files instead. This makes it easier to rebase when Blender releases new versions.
- **Using Make instead of Ninja:** Make 3.81 (available locally) is extremely slow for 4.4M lines. Ninja provides 5-10x faster incremental builds.
- **dlmalloc (default allocator):** Single global lock causes severe contention. Always use `-sMALLOC=mimalloc`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP headers for COOP/COEP | Custom server | Python `http.server` wrapper or `npx serve` with config | Headers must be exact; misconfiguration silently breaks threading |
| WASM dependency compilation | Manual Makefiles per lib | Emscripten ports system (`-sUSE_ZLIB=1`, `-sUSE_LIBPNG=1`, etc.) | Emscripten ports handle cross-compilation flags, include paths, linking automatically |
| Memory allocator | Custom allocator for WASM | `-sMALLOC=mimalloc` | Microsoft mimalloc has per-thread allocation contexts, proven in WASM multi-threaded scenarios |
| Build caching | Manual dependency tracking | ccache/sccache | Compilation caching is a solved problem; saves hours on 4.4M line builds |
| Docker build image | Custom Dockerfile from scratch | `emscripten/emsdk:5.0.4` as base | Official image with correct LLVM, Node.js, and emsdk preinstalled |

**Key insight:** Emscripten has already solved most of the low-level WASM compilation challenges. The work is in configuring Blender's build system correctly, not in building new infrastructure.

## Common Pitfalls

### Pitfall 1: Host Tool Cross-Compilation Failure

**What goes wrong:** `makesdna`, `makesrna`, and `datatoc` are build-time code generators that must run on the host machine (not in WASM). When using `emcmake cmake`, CMake tries to compile these with Emscripten, producing WASM executables that cannot run during the build step.
**Why it happens:** CMake's `add_executable(makesdna ...)` does not distinguish between host and target executables in a cross-compilation setup unless explicitly handled.
**How to avoid:** Two-stage build: first build host tools natively with regular cmake, then cross-compile Blender with `emcmake cmake` and point it at the pre-built host tools via `-DMAKESDNA_CMD=<path>` or CMake's `CMAKE_CROSSCOMPILING_EMULATOR` mechanism.
**Warning signs:** Build fails at the step where `makesdna` is invoked to generate `dna.cc`, with "exec format error" or "cannot execute binary file."

### Pitfall 2: COOP/COEP Headers Missing in Dev Server

**What goes wrong:** SharedArrayBuffer (required for pthreads) is unavailable, causing the entire threading system to silently fall back to single-threaded mode. Blender then performs catastrophically (single-threaded depsgraph evaluation, no parallel rendering).
**Why it happens:** Browsers require Cross-Origin Isolation headers after Spectre mitigation. `python3 -m http.server` and many other dev servers do not set these by default.
**How to avoid:** Configure dev server from day one:
```python
# serve.py
from http.server import HTTPServer, SimpleHTTPRequestHandler
class CORPHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()
HTTPServer(("", 8080), CORPHandler).serve_forever()
```
**Warning signs:** `self.crossOriginIsolated` returns `false` in browser console. `SharedArrayBuffer is not defined` errors.

### Pitfall 3: Memory Growth Overhead and Fragmentation

**What goes wrong:** WASM linear memory can only grow, never shrink. `-sALLOW_MEMORY_GROWTH=1` enables dynamic growth but each growth operation copies the entire heap. If initial memory is too small, frequent growth events cause stalls.
**Why it happens:** WASM's linear memory model has no virtual memory, no mmap/munmap, no way to return freed memory to the OS.
**How to avoid:** Set reasonable initial memory (`-sINITIAL_MEMORY=256MB`) and maximum (`-sMAXIMUM_MEMORY=4GB`). Monitor `MEM_guarded_alloc` usage statistics. Blender's `MEM_get_memory_in_use()` and `MEM_get_totals_memory()` work unchanged in WASM.
**Warning signs:** `memory.grow()` calls increasing in frequency; long pauses during allocation.

### Pitfall 4: Build Time Explosion

**What goes wrong:** Clean build of 4.4M lines through Emscripten takes 2-4 hours. Developers stop testing WASM builds, bugs accumulate.
**Why it happens:** Emscripten's link step involves LLVM bitcode linking, Binaryen wasm-opt optimization (whole-program), and JS glue code generation.
**How to avoid:**
1. Use Ninja (not Make) for build executor
2. Use ccache/sccache for compilation caching
3. Use `-O0` for the link step during development (`-O2` only for release)
4. Disable wasm-opt during development (`--no-wasm-opt`)
5. Only build the headless subset (most of Blender is disabled via WITH_* flags)
**Warning signs:** Full build > 1 hour; developers skipping WASM testing.

### Pitfall 5: extern/ Library Compilation Failures

**What goes wrong:** Third-party libraries in `extern/` (xxhash, json, tinygltf, fast_float, etc.) and `intern/` (guardedalloc, eigen, mikktspace, etc.) may use platform-specific features that fail under Emscripten.
**Why it happens:** Some libraries use inline assembly, platform-specific headers, or compiler intrinsics not available in Emscripten's Clang.
**How to avoid:** Compile libraries individually first, fix issues one by one. Most of the `extern/` libraries already have `__EMSCRIPTEN__` guards (confirmed: xxhash.h, ufbx.c, tiny_gltf.h, fast_float.h, json.hpp all reference `__EMSCRIPTEN__` or `EMSCRIPTEN`).
**Warning signs:** Compilation errors referencing missing headers (`<sys/mman.h>`, `<dlfcn.h>`, platform-specific syscalls).

## Code Examples

### CMake Emscripten Configuration (Full)

```cmake
# cmake/emscripten_overrides.cmake
# Applied after standard Blender CMake configuration

# Emscripten-specific compile flags
set(WASM_COMPILE_FLAGS
  -pthread
  -msimd128
  -mrelaxed-simd
  -fwasm-exceptions
  -DEMSCRIPTEN_HAS_UNBOUND_TYPE_NAMES=0  # Reduce binary size
)

# Emscripten-specific link flags
set(WASM_LINK_FLAGS
  -pthread
  -sPROXY_TO_PTHREAD
  -sALLOW_BLOCKING_ON_MAIN_THREAD=0
  -sALLOW_MEMORY_GROWTH=1
  -sINITIAL_MEMORY=256MB
  -sMAXIMUM_MEMORY=4GB
  -sMALLOC=mimalloc
  -sPTHREAD_POOL_SIZE=navigator.hardwareConcurrency
  -sPTHREAD_POOL_SIZE_STRICT=0
  -fwasm-exceptions
  -sEXPORT_ES6=0
  -sENVIRONMENT=web,worker
  -sEXPORTED_FUNCTIONS=_main,_wasm_init,_wasm_load_blend,_wasm_query_scene,_wasm_memory_usage
  -sEXPORTED_RUNTIME_METHODS=ccall,cwrap,FS,MEMFS
  -sSTACK_SIZE=2MB
)

# For release builds, add:
# -O3 (optimization)
# --closure 1 (JS minification)
# Brotli compression is handled at serving layer

# For debug builds:
# -sASSERTIONS=2
# -g (DWARF debug info for Chrome DevTools)
# -gsource-map (source maps)
```

### Dev Server with COOP/COEP Headers

```python
#!/usr/bin/env python3
"""Development server with Cross-Origin Isolation headers for SharedArrayBuffer."""

import http.server
import sys

class COIHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def guess_type(self, path):
        if path.endswith(".wasm"):
            return "application/wasm"
        return super().guess_type(path)

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    server = http.server.HTTPServer(("", port), COIHandler)
    print(f"Serving on http://localhost:{port} with COOP/COEP headers")
    server.serve_forever()
```

### Minimal Test HTML for WASM Binary

```html
<!DOCTYPE html>
<html>
<head><title>Blender WASM Headless Test</title></head>
<body>
<h1>Blender WASM Headless Test</h1>
<pre id="output">Loading...</pre>
<script>
  const output = document.getElementById('output');
  function log(msg) {
    output.textContent += msg + '\n';
    console.log(msg);
  }

  var Module = {
    onRuntimeInitialized: function() {
      log('WASM runtime initialized');
      log('crossOriginIsolated: ' + self.crossOriginIsolated);
      log('SharedArrayBuffer: ' + (typeof SharedArrayBuffer !== 'undefined'));

      // Test memory tracking
      const memUsage = Module.ccall('wasm_memory_usage', 'number', [], []);
      log('Memory usage: ' + memUsage + ' bytes');

      // Test .blend loading (file must be preloaded to MEMFS)
      const result = Module.ccall('wasm_init', 'number', [], []);
      log('Init result: ' + result);
    },
    print: function(text) { log('[stdout] ' + text); },
    printErr: function(text) { log('[stderr] ' + text); }
  };
</script>
<script src="blender_headless.js"></script>
</body>
</html>
```

### Dockerfile for Reproducible Build

```dockerfile
FROM emscripten/emsdk:5.0.4

# Install additional build tools
RUN apt-get update && apt-get install -y \
    ninja-build \
    ccache \
    && rm -rf /var/lib/apt/lists/*

# Set up ccache
ENV CCACHE_DIR=/cache/ccache
ENV PATH="/usr/lib/ccache:${PATH}"

WORKDIR /src

# Stage 1: Build native host tools
COPY Blender\ Mirror/ /src/blender/
RUN mkdir /src/build-native && cd /src/build-native && \
    cmake /src/blender \
      -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DWITH_BLENDER=OFF \
      -DWITH_CYCLES=OFF && \
    ninja makesdna makesrna datatoc

# Stage 2: Build WASM dependencies (handled by Emscripten ports)

# Stage 3: Cross-compile Blender headless
RUN mkdir /src/build-wasm && cd /src/build-wasm && \
    emcmake cmake /src/blender \
      -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DWITH_HEADLESS=ON \
      # ... (full WITH_* flags) ... \
      && \
    emmake ninja -j$(nproc)
```

## Dependency Matrix

### Libraries That Must Compile for Headless Build

| Library | Location | Strategy | Risk | Notes |
|---------|----------|----------|------|-------|
| guardedalloc | `intern/guardedalloc/` | Compile directly | VERY LOW | Pure C/C++, memory allocator wrapper |
| memutil | `intern/memutil/` | Compile directly | VERY LOW | Memory utilities |
| clog | `intern/clog/` | Compile directly | VERY LOW | Logging |
| atomic | `intern/atomic/` | Compile directly | VERY LOW | Atomic operations |
| eigen | `intern/eigen/` | Header-only, no compile | VERY LOW | Linear algebra |
| mikktspace | `intern/mikktspace/` | Compile directly | VERY LOW | Tangent space generation |
| sky | `intern/sky/` | Compile directly | VERY LOW | Sky model |
| iksolver | `intern/iksolver/` | Compile directly | VERY LOW | IK solver, pure C |
| itasc | `intern/itasc/` | Compile directly | LOW | iTaSC IK, pure C++ with Eigen dependency |
| rigidbody | `intern/rigidbody/` | Compile directly | LOW | Bullet wrapper |
| Bullet | `extern/bullet2/` | Compile directly or Emscripten port | LOW | Known to work with Emscripten (ammo.js) |
| xxhash | `extern/xxhash/` | Compile directly | VERY LOW | Has `__EMSCRIPTEN__` guards already |
| json | `extern/json/` | Header-only | VERY LOW | Has Emscripten awareness |
| fast_float | `extern/fast_float/` | Header-only | VERY LOW | Has `__EMSCRIPTEN__` guards |
| rangetree | `extern/rangetree/` | Compile directly | VERY LOW | Pure C |
| curve_fit_nd | `extern/curve_fit_nd/` | Compile directly | VERY LOW | Pure C |
| wcwidth | `extern/wcwidth/` | Compile directly | VERY LOW | Pure C |
| nanosvg | `extern/nanosvg/` | Compile directly | VERY LOW | Pure C |
| tinygltf | `extern/tinygltf/` | Header-only | VERY LOW | Has `__EMSCRIPTEN__` guards |
| ufbx | `extern/ufbx/` | Compile directly | VERY LOW | Has `EMSCRIPTEN` guards |

### Libraries Disabled for Phase 1

| Library | CMake Flag | Reason |
|---------|-----------|--------|
| TBB | `-DWITH_TBB=OFF` | Use Emscripten pthreads instead |
| Python | `-DWITH_PYTHON=OFF` | Phase 9 |
| Cycles | `-DWITH_CYCLES=OFF` | Phase 5+ |
| OpenColorIO | `-DWITH_OPENCOLORIO=OFF` | Not needed for headless data query |
| OpenSubdiv | `-DWITH_OPENSUBDIV=OFF` | GPU evaluator incompatible; CPU path deferred |
| OpenVDB | `-DWITH_OPENVDB=OFF` | Complex C++ library, not needed for Phase 1 |
| OpenImageDenoise | `-DWITH_OPENIMAGEDENOISE=OFF` | Uses oneDNN/SYCL, deferred |
| FFmpeg | `-DWITH_CODEC_FFMPEG=OFF` | Not needed for headless |
| Audaspace | `-DWITH_AUDASPACE=OFF` | Audio not needed for headless |
| Mantaflow | `-DWITH_MOD_FLUID=OFF` | Risky, large C++ library |
| OpenEXR | `-DWITH_IMAGE_OPENEXR=OFF` | Image format, not needed for headless core |
| USD | Implicitly off | Massive dependency tree |
| Alembic | Implicitly off | Not critical for Phase 1 |
| FreeType | Disabled with headless | Font rendering not needed |
| OpenXR | `-DWITH_XR_OPENXR=OFF` | Out of scope |
| GMP | `-DWITH_GMP=OFF` | Exact booleans, hard to cross-compile |

## Blender Modules Required for Phase 1 (Build Order)

The dependency chain from the Architecture research, validated against actual `CMakeLists.txt`:

```
1. intern/guardedalloc       (memory allocator - no dependencies)
2. intern/memutil            (memory utilities)
3. intern/clog               (logging)
4. intern/atomic             (atomic operations)
5. source/blender/blenlib    (utilities, math, containers)
6. intern/eigen              (header-only linear algebra)
7. source/blender/makesdna   (DNA type definitions + code generator)
   [Requires HOST makesdna tool to generate dna.cc]
8. source/blender/makesrna   (RNA reflection system)
   [Requires HOST makesrna tool to generate rna_*.cc]
9. source/blender/blenkernel (core engine)
10. source/blender/depsgraph  (dependency graph)
11. source/blender/bmesh      (mesh topology)
12. source/blender/geometry   (geometry algorithms)
13. source/blender/nodes      (node evaluation)
14. source/blender/functions  (function framework)
15. source/blender/modifiers  (modifier stack)
16. source/blender/animrig    (animation)
17. source/blender/simulation (physics wrappers)
18. source/blender/blenloader (file I/O)
19. source/blender/blenloader_core (file I/O core)
20. intern/ghost              (headless backend only)
21. source/blender/gpu/dummy  (dummy GPU backend)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `-sUSE_WEBGPU` (old Emscripten flag) | `--use-port=emdawnwebgpu` | Emscripten 4.0.10+ (2025) | Old flag deprecated, will be removed. Not relevant for Phase 1 (headless/dummy GPU) but matters for Phase 3. |
| Asyncify for async/sync bridge | PROXY_TO_PTHREAD + JSPI | 2024-2025 | Asyncify has ~50% overhead on large codebases. PROXY_TO_PTHREAD avoids the need entirely for main loop. JSPI is the future replacement. |
| dlmalloc (default) | mimalloc (-sMALLOC=mimalloc) | Available since Emscripten ~3.1.50 | Nearly 2x speedup in single-threaded, scales properly with multi-threading |
| `-sUSE_PTHREADS` (old flag) | `-pthread` | Emscripten ~3.1.x | Old flag still works but `-pthread` is standard |
| JavaScript exceptions | `-fwasm-exceptions` | Chrome 95+, Firefox 100+, Safari 15.2+ | Native WASM exceptions are smaller and faster than JS-based exception handling |

**Deprecated/outdated:**
- `-sUSE_WEBGPU`: Deprecated, unmaintained, will be removed. Use `--use-port=emdawnwebgpu`.
- Asyncify for main loop: Avoid on Blender's codebase. Use PROXY_TO_PTHREAD.
- dlmalloc: Single global lock makes it unsuitable for multi-threaded Blender.

## Open Questions

1. **makesdna/makesrna Cross-Compilation Mechanism**
   - What we know: These are HOST executables that must run during the build. CMake has mechanisms for this (`CMAKE_CROSSCOMPILING_EMULATOR`, `import()` for host targets).
   - What's unclear: The exact CMake incantation to pass pre-built host tools to the Emscripten build. Blender's CMakeLists.txt references `$<TARGET_FILE:makesdna>` which expects a build target.
   - Recommendation: Investigate `CMAKE_CROSSCOMPILING_EMULATOR=node` (which would run WASM makesdna via Node.js) or a two-build approach with `-DIMPORT_EXECUTABLES=<path-to-native-build>/CMakeCache.txt`.

2. **Exact Binary Size for Headless Core**
   - What we know: Full Blender native binary is ~150MB. Headless WASM with most features disabled should be much smaller.
   - What's unclear: Actual compressed size. Target is <30MB Brotli-compressed.
   - Recommendation: Build and measure. If over target, identify largest contributing modules and consider further disabling.

3. **blenkernel External Library Dependencies**
   - What we know: blenkernel links against many optional libraries (OpenColorIO, OpenVDB, etc.) with `#ifdef` guards.
   - What's unclear: Whether disabling all optional features via `WITH_*=OFF` cleanly compiles blenkernel without undefined symbol errors.
   - Recommendation: Compile incrementally, fix linker errors as they appear. Most optional dependencies are cleanly guarded.

4. **Emscripten Version Stability**
   - What we know: STACK.md specifies Emscripten 5.0.4 (March 2026). The documentation shows 5.0.5-git as dev.
   - What's unclear: Whether 5.0.4 is the actual latest stable or if a newer version has been released.
   - Recommendation: Pin to 5.0.4 in Dockerfile. Use `emsdk install 5.0.4` explicitly, not `latest`.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Emscripten (emsdk) | BUILD-01 (WASM compilation) | NO | -- | Install via emsdk or Docker |
| CMake | Build system | YES | 4.0.0 | -- |
| Node.js | Emscripten runtime | YES | 25.6.1 | -- |
| Python 3 | Build scripts | YES | 3.14.2 | -- |
| Ninja | Build executor | NO | -- | Install via `brew install ninja` or use Make (slower) |
| ccache | Compilation caching | NO | -- | Install via `brew install ccache` (recommended) |
| Docker | Reproducible builds | YES | 28.2.2 | -- |
| Make | Build executor fallback | YES | 3.81 | -- |
| Git | Source control | YES | 2.50.1 | -- |

**Missing dependencies with no fallback:**
- Emscripten (emsdk) -- must be installed. Docker approach (`emscripten/emsdk:5.0.4`) or local emsdk install.

**Missing dependencies with fallback:**
- Ninja -- `brew install ninja` recommended, but Make 3.81 works (much slower for incremental builds)
- ccache -- `brew install ccache` recommended, but builds work without it (just slower)

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Custom Node.js test harness + browser manual test |
| Config file | None -- Wave 0 must create `scripts/test-headless.js` |
| Quick run command | `node scripts/test-headless.js` |
| Full suite command | `node scripts/test-headless.js --full` |

Note: Blender uses GTest for C++ unit tests (`extern/gtest/`), but GTest tests compile to native executables. For WASM validation, we need a JavaScript/Node.js harness that loads the WASM binary and calls exported functions. Browser-based tests also need the dev server running with COOP/COEP headers.

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BUILD-01 | WASM binary compiles and links without errors | build | `emmake ninja -j$(nproc) 2>&1; echo $?` | -- (build system) |
| BUILD-02 | Dependencies compile to WASM | build | `emmake ninja -j$(nproc) 2>&1; echo $?` | -- (build system) |
| BUILD-03 | pthreads/Web Workers work | smoke | `node --experimental-wasm-threads scripts/test-headless.js --test-threading` | NO -- Wave 0 |
| BUILD-04 | Memory within 4GB, MEM_guarded_alloc reports | smoke | `node scripts/test-headless.js --test-memory` | NO -- Wave 0 |
| BUILD-05 | COOP/COEP headers in dev server | smoke | `curl -sI http://localhost:8080 \| grep -i cross-origin` | NO -- Wave 0 |
| BUILD-06 | Non-blocking main loop / PROXY_TO_PTHREAD | smoke | Browser console: `self.crossOriginIsolated === true` | manual-only (browser check) |
| BUILD-07 | Compressed binary <30MB, lazy loading | measurement | `stat -f%z build-wasm/blender_headless.wasm; brotli --best build-wasm/blender_headless.wasm -o /tmp/test.br; stat -f%z /tmp/test.br` | NO -- Wave 0 |
| BUILD-08 | SIMD enabled | smoke | `wasm-dis build-wasm/blender_headless.wasm \| grep -c 'v128'` or Node.js feature detection | NO -- Wave 0 |

### Sampling Rate
- **Per task commit:** Build succeeds (`emmake ninja`)
- **Per wave merge:** Full test suite (`node scripts/test-headless.js --full`)
- **Phase gate:** All 8 BUILD requirements pass before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `scripts/test-headless.js` -- Node.js test harness for WASM binary validation
- [ ] `web/serve.py` -- Dev server with COOP/COEP headers
- [ ] `web/index.html` -- Minimal browser test page
- [ ] Ninja installation: `brew install ninja`
- [ ] ccache installation: `brew install ccache`
- [ ] Emscripten installation: Docker or local emsdk

## Sources

### Primary (HIGH confidence)
- Blender source code analysis -- `CMakeLists.txt`, `intern/ghost/intern/GHOST_SystemHeadless.hh`, `source/blender/windowmanager/intern/wm.cc`, `source/blender/makesdna/intern/CMakeLists.txt`, `source/blender/gpu/dummy/`
- [Emscripten Pthreads Documentation](https://emscripten.org/docs/porting/pthreads.html) -- PROXY_TO_PTHREAD, SharedArrayBuffer requirements, blocking constraints
- [Emscripten Module Splitting](https://emscripten.org/docs/optimizing/Module-Splitting.html) -- wasm-split, SPLIT_MODULE
- [Emscripten Compiler Settings](https://emscripten.org/docs/tools_reference/settings_reference.html) -- Full flag reference
- [mimalloc for WASM multithreading](https://web.dev/articles/scaling-multithreaded-webassembly-applications) -- Performance benchmarks, 2x improvement over dlmalloc

### Secondary (MEDIUM confidence)
- [emdawnwebgpu README](https://dawn.googlesource.com/dawn/+/refs/heads/main/src/emdawnwebgpu/pkg/README.md) -- WebGPU bindings for Emscripten (relevant for future phases)
- [emscripten/emsdk Docker Hub](https://hub.docker.com/r/emscripten/emsdk) -- Official Docker image
- [Emscripten GitHub Releases](https://github.com/emscripten-core/emscripten/releases) -- Version tracking

### Tertiary (LOW confidence)
- Emscripten 5.0.4 exact version verification -- could not confirm via GitHub API; relying on STACK.md research

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- Emscripten is the only viable toolchain, well-documented, version pinned
- Architecture: HIGH -- Blender's build system thoroughly analyzed from source, CMake flags well-understood
- Build order: HIGH -- Dependency chain validated against actual CMakeLists.txt files
- Host tools problem: HIGH -- makesdna/makesrna/datatoc confirmed as host executables from CMakeLists.txt analysis
- Dependency compilation: MEDIUM -- Individual library WASM compatibility assessed from prior art and `__EMSCRIPTEN__` guards, but empirical testing needed
- Binary size: LOW -- No measurement data; estimate based on feature disabling and compression ratios

**Research date:** 2026-04-01
**Valid until:** 2026-05-01 (Emscripten releases monthly; pin version to maintain validity)
