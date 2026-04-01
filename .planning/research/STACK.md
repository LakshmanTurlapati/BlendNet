# Technology Stack: Blender WebAssembly/WebGPU Port

**Project:** Blender Web
**Researched:** 2026-04-01
**Overall Confidence:** MEDIUM -- The individual toolchain components are well-documented and verified, but no one has publicly shipped a project of this scale (4M+ lines C/C++) with this exact combination. The integration points carry risk.

---

## Recommended Stack

### 1. Compiler Toolchain

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Emscripten (emsdk) | 5.0.4 (stable, March 2026) | C/C++ to WebAssembly compiler | The only production-grade C/C++ to WASM toolchain. Based on LLVM/Clang, provides POSIX emulation layer, CMake toolchain file, and comprehensive API for browser integration. Blender uses CMake already, making Emscripten's CMake integration the natural fit. | HIGH |
| Binaryen (wasm-opt) | Bundled with Emscripten 5.0.4 | WASM binary optimizer | Post-compilation pass that achieves 20-50% code size reduction through dead code elimination, function inlining, and WASM-specific minification. Critical for a 4M+ line codebase. Use `--converge` flag for maximum optimization. | HIGH |
| LLVM/Clang | 19.x (bundled with Emscripten 5.0.4) | C/C++ frontend | Emscripten bundles its own LLVM. Blender already requires Clang 17+, so compatibility is not a concern. | HIGH |

**Key Emscripten compilation flags for this project:**

```bash
# Core compilation
emcmake cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DWITH_GHOST_SDL=ON \
  -DWITH_HEADLESS=OFF

# Emscripten-specific link flags
-pthread                        # Enable pthreads -> Web Workers
-msimd128                       # Enable WASM SIMD (128-bit)
-mrelaxed-simd                  # Enable relaxed SIMD for better perf
-fwasm-exceptions               # Native WASM exception handling
-sALLOW_MEMORY_GROWTH=1         # Dynamic memory growth
-sMAXIMUM_MEMORY=4GB            # 4GB cap (32-bit mode)
-sMALLOC=mimalloc               # Per-thread allocator for threading perf
-sPTHREAD_POOL_SIZE=navigator.hardwareConcurrency
--use-port=emdawnwebgpu          # WebGPU bindings (NOT -sUSE_WEBGPU)
```

### 2. GPU / Graphics

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| WebGPU (browser API) | W3C CR (shipped in all major browsers Nov 2025) | GPU-accelerated rendering, compute | WebGPU is the only modern GPU API available in browsers. It provides both rendering and compute shader capabilities needed for Cycles and EEVEE. Shipped in Chrome 113+, Firefox 141+, Safari 26+, Edge 113+. | HIGH |
| emdawnwebgpu | Latest from Dawn repo (tracks Chromium releases) | C/C++ WebGPU bindings for Emscripten | Dawn's maintained fork of Emscripten's WebGPU bindings. The old `-sUSE_WEBGPU` flag is deprecated and will be removed. Emdawnwebgpu provides up-to-date `webgpu.h` header matching the standardized API, plus `webgpu_cpp.h` C++ wrappers. Single flag change: `--use-port=emdawnwebgpu`. | HIGH |
| WGSL | W3C Standard | GPU shader language | The ONLY shader language accepted by WebGPU. All Blender GLSL shaders must be translated to WGSL. No browser accepts SPIR-V or GLSL directly in WebGPU. | HIGH |
| Tint (build-time only) | From Dawn repo | SPIR-V/GLSL to WGSL shader transpiler | Google's shader compiler used by Chromium. Use at build time to convert Blender's existing GLSL shaders to WGSL, then hand-optimize critical paths. Alternatively, Naga (Rust, used by Firefox) can also transpile SPIR-V to WGSL. | MEDIUM |
| WebGL2 (fallback) | Browser native | Fallback rendering for non-WebGPU browsers | For basic viewport rendering only when WebGPU is unavailable. Emscripten provides direct WebGL2 mapping via OpenGL ES 3.0 emulation. NOT for Cycles or EEVEE -- those require compute shaders. | HIGH |

**Critical GPU architecture decision:**

Blender's existing GPU module (`source/blender/gpu/`) has a clean backend abstraction via the `GPUBackend` virtual class (`gpu_backend.hh`). Current backends: OpenGL, Vulkan, Metal, and a Dummy backend. The approach is to implement a new `GPUBackendWebGPU` class that implements the same interface:

```
GPUBackend (abstract)
  |-- GPUBackendOpenGL (existing)
  |-- GPUBackendVulkan (existing)
  |-- GPUBackendMetal (existing)
  |-- GPUBackendDummy (existing)
  |-- GPUBackendWebGPU (NEW -- to be created)
```

The backend must implement: `context_alloc`, `batch_alloc`, `shader_alloc`, `texture_alloc`, `framebuffer_alloc`, `compute_dispatch`, `storagebuf_alloc`, etc. This is the single largest piece of new code in the project.

### 3. Shader Translation Strategy

| Approach | Recommendation | Rationale |
|----------|----------------|-----------|
| Blender GLSL shaders to WGSL | **Offline transpilation + manual fixup** | Blender uses a custom GLSL cross-compilation system (`GPUShaderCreateInfo`) that generates platform-specific shader code. For WebGPU, add a WGSL code generation path to this existing system. This is better than runtime transpilation because it avoids shipping a transpiler and allows hand-optimization. |
| Cycles GPU kernels | **Rewrite critical kernels in WGSL compute shaders** | Cycles currently targets CUDA/OptiX/HIP/Metal/oneAPI. These are not transpilable to WGSL. The path-tracing kernels must be rewritten as WebGPU compute shaders in WGSL. This is the highest-risk, highest-effort item. |
| EEVEE shaders | **Transpile from Vulkan GLSL path** | EEVEE's Vulkan backend GLSL is closest to what WGSL can express. Use Tint or Naga to transpile, then iterate on correctness. |

### 4. Threading & Parallelism

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Emscripten pthreads | Built into Emscripten 5.0.4 | Map C pthreads to Web Workers | Emscripten's pthread implementation maps to Web Workers + SharedArrayBuffer. This is how Blender's existing threading code (task scheduler, Cycles tile rendering, physics sim) runs in the browser. Compile with `-pthread` flag. | HIGH |
| SharedArrayBuffer | Browser native | Shared memory between workers | Required by Emscripten pthreads. All modern browsers support this but require Cross-Origin Isolation headers (COOP + COEP). | HIGH |
| mimalloc | Bundled with Emscripten | Thread-safe memory allocator | Emscripten's default dlmalloc has a single global lock causing contention. Use `-sMALLOC=mimalloc` for per-thread allocation contexts. Critical for Blender's heavy multi-threaded operations. | HIGH |
| wasmtbb (for TBB replacement) | Experimental | Intel TBB port to WASM | Blender optionally uses Intel TBB (`WITH_TBB`). A partial WASM port exists (hpcwasm/wasmtbb). However, recommendation is to **disable TBB** (`-DWITH_TBB=OFF`) and rely on Emscripten pthreads directly. TBB's task scheduler can be replaced by Blender's own task system or a simpler work-stealing implementation over pthreads. | MEDIUM |

**Required HTTP headers for threading:**
```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Without these headers, SharedArrayBuffer is unavailable and the application will be **single-threaded only**, which is unacceptable for Blender.

### 5. Memory Management

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| WASM32 (default mode) | WebAssembly 2.0 | 32-bit address space, 4GB max | Start here. Most Blender workflows fit within 4GB. 32-bit pointers are smaller and faster. WASM32 is universally supported and has zero performance penalty. | HIGH |
| WASM Memory64 | WebAssembly 3.0 (Sept 2025) | 64-bit address space, up to 16GB in browsers | Available in Chrome 133+ and Firefox 134+ (early 2025). Enables >4GB memory. BUT incurs 10-100% performance penalty compared to 32-bit. Use only if the 4GB limit becomes a blocker for complex scenes. Compile with `-sMEMORY64` flag. | MEDIUM |
| `-sALLOW_MEMORY_GROWTH=1` | Emscripten flag | Dynamic memory growth | Allows the WASM heap to grow at runtime instead of pre-allocating. Small overhead on memory access but necessary since Blender's memory usage is scene-dependent. | HIGH |
| `-sMAXIMUM_MEMORY=4GB` | Emscripten flag | Cap at 4GB for 32-bit mode | Set explicit maximum to avoid browser tab crashes from runaway allocation. | HIGH |

**Strategy:** Build for WASM32 (4GB limit). Implement memory budgeting in the scene manager to warn users before hitting the limit. Plan for WASM Memory64 as an optional build target once performance penalties decrease (expected improvement through 2026-2027 as engines optimize).

### 6. File System & Storage

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Emscripten Virtual FS (MEMFS) | Built into Emscripten | In-memory filesystem | Default Emscripten FS. Fast, but ephemeral -- data lost on page reload. Use for temp files, caches, and working data. | HIGH |
| WasmFS + OPFS backend | Emscripten WasmFS | Persistent file storage | WasmFS is Emscripten's newer, higher-performance C++ filesystem implementation. Mount OPFS (Origin Private File System) at a directory like `/persistent/`. OPFS provides synchronous file access via SyncAccessHandle -- critical for Blender's C-level fopen/fread patterns. Supported in Chrome 108+, Safari 16.4+, Firefox 111+. | HIGH |
| IndexedDB backend | Emscripten WasmFS | Persistent fallback | For browsers without OPFS or for asset library storage. Higher latency than OPFS but unlimited storage (with user permission). | MEDIUM |
| File System Access API | Browser native | Open/save files from disk | For "File > Open" and "File > Save As" operations. Lets users pick files from their local filesystem. Falls back to download/upload pattern on browsers without this API. | MEDIUM |

**File system mount strategy:**
```
/                    -> MEMFS (in-memory, fast, ephemeral)
/tmp/                -> MEMFS (temp files, caches)
/persistent/         -> OPFS (saved .blend files, preferences)
/assets/             -> IndexedDB (asset library, downloaded textures)
```

### 7. Python Scripting

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Pyodide | 0.29.3 (July 2025) | CPython in WebAssembly | Pyodide is CPython compiled to WASM via Emscripten. It includes Python 3.13.2, supports NumPy, and has JSPI for async/await. Blender's Python API (bpy module) can bridge to this. | MEDIUM |
| CPython (Emscripten tier 3) | 3.14+ | Alternative: direct CPython WASM build | As of Python 3.14, Emscripten is a tier 3 target (PEP 776). Could build CPython directly as part of Blender's build rather than using Pyodide. More control, but more integration work. | LOW |

**Recommendation:** Use Pyodide 0.29.x initially because it handles the CPython WASM build, provides package management (micropip), and has solved many integration challenges. The `bpy` module would need to be compiled as a Pyodide-loadable native extension. This is a significant integration challenge -- Python support should be a later phase, not a blocker for initial viewport rendering.

**Limitations:**
- No C-extension packages unless pre-compiled for Pyodide (NumPy works, but many Blender addons with native code will not)
- Performance is 60-95% of native depending on workload
- Memory overhead: Pyodide itself adds ~20-30MB to the WASM binary

### 8. Platform Abstraction (GHOST Layer)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| GHOST_SystemSDL (existing) | In Blender source | Window/input abstraction for SDL-based platforms | Blender ALREADY has a `GHOST_SystemSDL` backend. Emscripten provides an SDL2 implementation that maps to browser Canvas/DOM events. Build with `-DWITH_GHOST_SDL=ON` and Emscripten will use its SDL port. This is the lowest-effort path for getting Blender's event loop running in the browser. | HIGH |
| Emscripten SDL2 port | Built into Emscripten (`-sUSE_SDL=2`) | SDL2 implementation for browsers | Maps SDL2 calls to Canvas events (keyboard, mouse, touch, resize). Well-tested, maintained. Provides the bridge between Blender's C event handling and browser DOM events. | HIGH |
| Emscripten html5.h (supplemental) | Built into Emscripten | Direct HTML5 API access | For browser-specific features SDL doesn't cover: fullscreen API, clipboard, file drag-and-drop, pointer lock, touch gestures. Use alongside SDL, not instead of it. | HIGH |

**Key insight:** The `WITH_GHOST_SDL` CMake option already exists in Blender's build system. This means the GHOST layer integration path is already partially paved. Emscripten's SDL2 port will handle the heavy lifting of translating browser events to SDL events, which GHOST_SystemSDL already knows how to process.

### 9. Build System Integration

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| CMake | 3.20+ | Build system | Blender uses CMake. Emscripten provides a CMake toolchain file. Use `emcmake cmake` to configure. | HIGH |
| Docker | Latest | Reproducible build environment | Build environment with Emscripten SDK pre-installed. Ensures consistent builds across developer machines. Models after ffmpeg.wasm's Docker-based build pipeline. | MEDIUM |
| Conan 2.x | 2.26+ | Dependency management | For cross-compiling Blender's many C/C++ dependencies to WASM. Conan has documented Emscripten cross-compilation support with profile files. | MEDIUM |

**CMake integration approach:**

```bash
# Step 1: Install emsdk
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk && ./emsdk install 5.0.4 && ./emsdk activate 5.0.4

# Step 2: Configure Blender with Emscripten toolchain
cd blender && mkdir build-wasm && cd build-wasm
emcmake cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DWITH_GHOST_SDL=ON \
  -DWITH_PYTHON=OFF \              # Disable initially
  -DWITH_TBB=OFF \                 # Disable TBB, use pthreads
  -DWITH_OPENGL_BACKEND=OFF \      # Disable native OpenGL
  -DWITH_VULKAN_BACKEND=OFF \      # Disable native Vulkan
  -DWITH_CYCLES_DEVICE_CUDA=OFF \  # No CUDA in browser
  -DWITH_CYCLES_DEVICE_OPTIX=OFF \ # No OptiX in browser
  -DWITH_CYCLES_DEVICE_HIP=OFF \   # No HIP in browser
  -DWITH_CYCLES_DEVICE_ONEAPI=OFF \# No oneAPI in browser
  -DWITH_CYCLES_DEVICE_METAL=OFF \ # No Metal in browser
  -DWITH_XR_OPENXR=OFF             # Disable for now

# Step 3: Build
emmake make -j$(nproc)
```

### 10. External Library Strategy

Blender has 30+ external dependencies. Each must be handled for WASM compilation.

| Library | Strategy | Difficulty | Notes |
|---------|----------|------------|-------|
| Bullet Physics | Use `-sUSE_BULLET=1` Emscripten port, or compile from source | Low | Already ported as ammo.js; Emscripten has a built-in port |
| FFmpeg | Use ffmpeg.wasm approach (custom WASM build) | High | Needs custom compilation with many features disabled. Single-threaded initially. |
| OpenEXR | Cross-compile with Emscripten | Medium | Has been done (Disney Research). Pure C/C++, no OS deps. |
| OpenColorIO | Cross-compile with Emscripten | Medium | Pure C++, should compile. May need stubs for GPU path. |
| OpenSubdiv | Cross-compile with Emscripten | Medium | Pure C++, CPU evaluator only (GPU evaluator needs WebGPU port). |
| OpenImageDenoise (OIDN) | Cross-compile or replace | High | Uses oneDNN/SYCL for GPU. CPU path may compile but will be slow. Consider WebGPU compute replacement. |
| OpenVDB / NanoVDB | Cross-compile with Emscripten | High | Large, complex C++. NanoVDB (header-only) is easier. OpenVDB full is hard. |
| FreeType | Use Emscripten port (`-sUSE_FREETYPE=1`) | Low | Emscripten has a built-in FreeType port |
| zlib | Use Emscripten port (`-sUSE_ZLIB=1`) | Low | Emscripten has a built-in port |
| libpng | Use Emscripten port (`-sUSE_LIBPNG=1`) | Low | Emscripten has a built-in port |
| libjpeg | Use Emscripten port | Low | Available as Emscripten port |
| GMP | Cross-compile or use mini-gmp | Medium | Full GMP is hard to cross-compile. mini-gmp (subset) may suffice for exact boolean ops. |
| Intel TBB | **SKIP** -- disable with `-DWITH_TBB=OFF` | N/A | Use Emscripten pthreads instead |
| Mantaflow | Cross-compile (part of Blender source) | Medium | In `extern/mantaflow/`. Pure C++, should be compilable. Fluid sim will be slow. |
| Audaspace | Cross-compile or stub out | Medium | Audio in browser needs Web Audio API bridge |
| USD | **DEFER** -- disable initially | High | Massive dependency tree. Not needed for MVP. |
| Alembic | Cross-compile or defer | Medium | Simpler than USD but not critical for MVP |

### 11. WebAssembly Features to Enable

| Feature | Flag/Method | Browser Support | Purpose |
|---------|-------------|----------------|---------|
| SIMD (128-bit) | `-msimd128` | All major browsers | Math-heavy operations (mesh transforms, physics, BVH). 2-4x speedup for vector operations. |
| Relaxed SIMD | `-mrelaxed-simd` | Chrome 114+, Firefox 122+ | Allows FMA and other relaxed operations. Better perf for float-heavy code. |
| Exception Handling | `-fwasm-exceptions` | Chrome 95+, Firefox 100+, Safari 15.2+ | Native WASM exceptions. Smaller and faster than JS-based exception handling. Blender's C++ uses exceptions in some paths. |
| Tail Calls | Compiler support | Chrome 112+, Firefox 121+ | Reduces stack overflow risk for recursive algorithms (e.g., BVH traversal in Cycles). |
| Threads | `-pthread` | All major browsers (with COOP/COEP) | Multi-threading via Web Workers + SharedArrayBuffer. |
| Bulk Memory | Default in Emscripten | All major browsers | Faster memcpy/memset operations. |
| Multi-value | Default in Emscripten | All major browsers | Functions returning multiple values. Minor optimization. |

### 12. Development & Debug Tools

| Tool | Purpose | Why |
|------|---------|-----|
| Chrome DevTools WASM debugging | Source-level debugging of C++ in browser | Chrome supports DWARF debug info in WASM. Compile with `-g` for debug builds. |
| Emscripten ASSERTIONS | Runtime validation | `-sASSERTIONS=2` in dev builds to catch memory errors, null pointers, stack overflow. |
| AddressSanitizer | Memory error detection | Emscripten supports ASan via `-fsanitize=address`. Essential for catching memory bugs during porting. |
| WebGPU Inspector (Firefox) | GPU debugging | Inspect WebGPU API calls, shader compilation errors, buffer contents. |
| PIX / RenderDoc (via Dawn native) | GPU debugging on native | Debug the WebGPU backend natively using Dawn before deploying to browser. |

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Compiler | Emscripten 5.0.4 | Cheerp (Leaning Technologies) | Cheerp is less mature, smaller community, fewer ported libraries, no equivalent to Emscripten ports system |
| Compiler | Emscripten 5.0.4 | Rust + wasm-bindgen | Would require rewriting Blender -- defeats the purpose of porting existing C/C++ |
| GPU API | WebGPU | WebGL2 only | WebGL2 lacks compute shaders (needed for Cycles) and has lower performance ceiling. No path to EEVEE or Cycles GPU rendering. |
| GPU Bindings | emdawnwebgpu | `-sUSE_WEBGPU` (old) | Deprecated by Emscripten. Unmaintained. API substantially out of date vs standard. Will be removed. |
| GPU Bindings | emdawnwebgpu | wgpu-native | wgpu-native does not yet implement the stable webgpu.h standard. Dawn's implementation is further along and is what Chromium uses. |
| Shader Language | WGSL (with offline transpilation) | SPIR-V in browser | WebGPU does NOT accept SPIR-V. WGSL is the only option. Period. |
| Threading | Emscripten pthreads | Wasm Workers API | Wasm Workers are lighter but incompatible with pthreads semantics. Blender's codebase is built on pthreads. Rewriting threading would be enormous. |
| Memory mode | WASM32 (4GB) | WASM Memory64 (16GB) | 10-100% performance penalty in 64-bit mode. Not worth it unless 4GB is proven insufficient. |
| Python | Pyodide 0.29 | MicroPython | MicroPython lacks CPython compatibility needed for Blender's Python API (bpy, RNA). |
| File Storage | WasmFS + OPFS | IndexedDB only | OPFS provides synchronous access (SyncAccessHandle) matching C file I/O patterns. IndexedDB is async-only, requiring complex adapters. |
| Build deps | Conan 2.x | vcpkg | Conan has better documented Emscripten cross-compilation. vcpkg and Emscripten both use CMAKE_TOOLCHAIN_FILE causing conflicts. |

---

## What NOT to Use

| Technology | Why NOT |
|------------|---------|
| `-sUSE_WEBGPU` (old Emscripten flag) | Deprecated. Unmaintained. Will be removed. Use `--use-port=emdawnwebgpu` instead. |
| CUDA / OptiX / HIP / Metal / oneAPI device backends | These are native GPU compute APIs that do not exist in browsers. Must be replaced by WebGPU compute shaders. |
| Intel TBB | Partial WASM port exists but unstable. Blender's own task system over pthreads is sufficient. Disable with `-DWITH_TBB=OFF`. |
| OpenXR | VR in browser is a separate concern. Disable initially. WebXR support could be added later. |
| Native file I/O (open/fwrite with OS paths) | Browser sandbox prevents this. All file I/O must go through Emscripten's virtual FS or browser File System Access API. |
| `dlmalloc` (Emscripten default allocator) | Has a single global lock. Under multi-threaded Blender workloads this becomes a bottleneck. Use `-sMALLOC=mimalloc`. |
| WASM Memory64 as default | The performance penalty (10-100%) is too high for an interactive 3D application. Use WASM32 unless 4GB is proven insufficient. |

---

## Installation / Setup

```bash
# 1. Install Emscripten SDK
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install 5.0.4
./emsdk activate 5.0.4
source ./emsdk_env.sh

# 2. Verify installation
emcc --version  # Should show 5.0.4
node --version  # Node.js required by Emscripten

# 3. Clone Blender source (already present)
# The Blender source is at: Blender Mirror/

# 4. Cross-compile dependencies (example: Bullet)
# Many deps are available as Emscripten ports:
emcc -sUSE_BULLET=1 -sUSE_FREETYPE=1 -sUSE_ZLIB=1 -sUSE_LIBPNG=1

# 5. Configure Blender build
mkdir build-wasm && cd build-wasm
emcmake cmake ../Blender\ Mirror \
  -DCMAKE_BUILD_TYPE=Release \
  -DWITH_GHOST_SDL=ON \
  -DWITH_SDL=ON

# 6. Build
emmake make -j$(nproc)

# 7. Serve with required headers
# Any web server, but MUST include:
#   Cross-Origin-Opener-Policy: same-origin
#   Cross-Origin-Embedder-Policy: require-corp
npx serve --cors -l 8080  # Or custom server with headers
```

---

## Hosting / Serving Requirements

The compiled output will include:
- `blender.wasm` -- Main WASM binary (estimated 50-150MB pre-gzip, 15-40MB gzipped)
- `blender.js` -- Emscripten glue code
- `blender.worker.js` -- Web Worker entry point (for pthreads)
- `blender.data` -- Preloaded data files (UI resources, fonts, default scenes)

**Server requirements:**
- HTTPS (required for SharedArrayBuffer)
- COOP/COEP headers (required for SharedArrayBuffer/threading)
- Gzip or Brotli compression (critical for large WASM binaries)
- `application/wasm` MIME type for `.wasm` files
- Service Worker for offline caching (optional but recommended)

---

## Version Compatibility Matrix

| Component | Minimum Version | Recommended | Notes |
|-----------|----------------|-------------|-------|
| Chrome | 113 | 133+ | 133 adds Memory64; 113 is minimum for WebGPU |
| Firefox | 141 | 145+ | 141 adds WebGPU on Windows; 145 adds macOS |
| Safari | 26.0 | 26.0+ | First Safari version with WebGPU |
| Edge | 113 | 133+ | Chromium-based, tracks Chrome |
| Emscripten | 4.0.0 | 5.0.4 | 5.x is current stable line |
| WebGPU | W3C CR | -- | Finalized standard, shipped everywhere |
| WASM | 2.0 (W3C Dec 2024) | 3.0 (Sept 2025) | 3.0 adds Memory64, multi-memory |

---

## Sources

**Emscripten:**
- [Emscripten Documentation](https://emscripten.org/) -- version 5.0.5-git (dev) docs
- [Emscripten GitHub Releases](https://github.com/emscripten-core/emscripten/releases)
- [Emscripten ChangeLog](https://github.com/emscripten-core/emscripten/blob/main/ChangeLog.md) -- confirms 5.0.4 released 2026-03-23
- [Emscripten Pthreads Documentation](https://emscripten.org/docs/porting/pthreads.html)
- [Emscripten C++ Exceptions](https://emscripten.org/docs/porting/exceptions.html)
- [Emscripten SIMD](https://emscripten.org/docs/porting/simd.html)
- [Emscripten File System API](https://emscripten.org/docs/api_reference/Filesystem-API.html)

**WebGPU:**
- [WebGPU Browser Support - web.dev](https://web.dev/blog/webgpu-supported-major-browsers)
- [WebGPU Implementation Status](https://github.com/gpuweb/gpuweb/wiki/Implementation-Status)
- [Can I Use WebGPU](https://caniuse.com/webgpu)
- [webgpu-native/webgpu-headers](https://github.com/webgpu-native/webgpu-headers) -- standardized C header
- [emdawnwebgpu README](https://dawn.googlesource.com/dawn/+/refs/heads/main/src/emdawnwebgpu/pkg/README.md)
- [Deprecate -sUSE_WEBGPU PR](https://github.com/emscripten-core/emscripten/pull/24220)
- [Dawn WebGPU Implementation](https://dawn.googlesource.com/dawn)

**WebAssembly Standards:**
- [WASM Memory64 Proposal](https://github.com/WebAssembly/memory64)
- [WASM 3.0 Specification](https://github.com/WebAssembly/spec/blob/wasm-3.0/proposals/memory64/Overview.md)
- [Memory64 Performance Analysis (SpiderMonkey)](https://spidermonkey.dev/blog/2025/01/15/is-memory64-actually-worth-using.html)
- [SharedArrayBuffer and COOP/COEP](https://web.dev/articles/coop-coep)

**Shader Translation:**
- [WGSL Specification (W3C)](https://www.w3.org/TR/WGSL/)
- [Tint (Google Shader Compiler)](https://dawn.googlesource.com/dawn) -- part of Dawn
- [Naga (Rust Shader Compiler)](https://github.com/gfx-rs/naga)

**Python/Pyodide:**
- [Pyodide 0.29.3](https://pyodide.org/)
- [Pyodide Changelog](https://pyodide.org/en/stable/project/changelog.html)

**Blender GPU Module:**
- [GPU Module Overview](https://developer.blender.org/docs/features/gpu/overview/)
- [Vulkan Backend Documentation](https://developer.blender.org/docs/features/gpu/vulkan/)

**File System:**
- [WasmFS Documentation](https://deepwiki.com/emscripten-core/emscripten/3.4-wasmfs)
- [Origin Private File System (web.dev)](https://web.dev/articles/origin-private-file-system)

**Dependencies:**
- [ammo.js (Bullet WASM)](https://github.com/kripken/ammo.js/)
- [ffmpeg.wasm](https://github.com/ffmpegwasm/ffmpeg.wasm)
- [Binaryen/wasm-opt](https://github.com/WebAssembly/binaryen)

---

*Stack research: 2026-04-01*
