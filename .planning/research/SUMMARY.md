# Research Summary: Blender WebAssembly/WebGPU Port

**Domain:** Large-scale C/C++ desktop application to browser port
**Researched:** 2026-04-01
**Overall confidence:** MEDIUM

## Executive Summary

The 2026 toolchain for compiling Blender (4.4M+ lines of C/C++) to WebAssembly with WebGPU rendering is mature at the individual component level but unprecedented at this integration scale. Emscripten 5.0.4 (stable March 2026) provides the C/C++ to WASM compiler with CMake toolchain support, pthreads-to-Web-Workers mapping, and the new emdawnwebgpu bindings for WebGPU access. WebGPU itself shipped in all major browsers as of November 2025, making it a viable GPU target. WebAssembly 3.0 (September 2025) adds Memory64 for projects needing more than 4GB, though with performance penalties.

The critical technical challenge is not the compilation itself but the GPU backend. Blender's GPU module has a clean abstraction layer (`GPUBackend` virtual class) with existing OpenGL, Vulkan, Metal, and Dummy backends. A new `GPUBackendWebGPU` must be implemented. This requires writing WGSL shaders (the ONLY shader language WebGPU accepts) to replace Blender's GLSL, which is the single largest work item. Cycles path-tracing GPU kernels (currently CUDA/OptiX/HIP/Metal) must be rewritten as WebGPU compute shaders in WGSL -- there is no transpilation path for these.

A key advantage is that Blender already has a `GHOST_SystemSDL` backend for its window/input abstraction. Since Emscripten provides an SDL2 implementation mapped to browser events, the GHOST layer can work with minimal changes by enabling `-DWITH_GHOST_SDL=ON`. This eliminates the need for a custom platform abstraction layer from scratch.

The recommended approach is: compile with WASM32 (4GB limit) using mimalloc for thread-safe allocation, enable SIMD and native WASM exceptions, use WasmFS with OPFS for persistent file storage, and defer Python scripting support to a later phase. The estimated output binary will be 50-150MB pre-compression, requiring server-side gzip/brotli.

## Key Findings

**Stack:** Emscripten 5.0.4 + emdawnwebgpu + WGSL shaders + WASM32 with pthreads/SharedArrayBuffer
**Architecture:** New GPUBackendWebGPU implementing Blender's existing `GPUBackend` abstract class, GHOST_SystemSDL for browser event handling
**Critical pitfall:** Cycles GPU kernels cannot be transpiled from CUDA/HIP/Metal to WGSL -- they must be rewritten. This is months of work.

## Implications for Roadmap

Based on research, suggested phase structure:

1. **Headless WASM Build** - Get Blender compiling to WASM with all GPU/rendering disabled, using the Dummy GPU backend
   - Addresses: Build system integration, dependency compilation, linker issues
   - Avoids: Premature GPU work before build stability

2. **GHOST/SDL Browser Integration** - Get Blender's window manager running in a browser canvas with event handling
   - Addresses: Input handling, window lifecycle, canvas integration
   - Avoids: Custom platform abstraction (reuses existing GHOST_SystemSDL)

3. **WebGPU Backend (Viewport)** - Implement GPUBackendWebGPU for basic 3D viewport rendering
   - Addresses: Texture, buffer, shader, framebuffer allocation; basic draw calls
   - Avoids: Full Cycles/EEVEE (too complex for initial GPU work)

4. **EEVEE on WebGPU** - Port EEVEE real-time renderer to use WebGPU backend
   - Addresses: Shader translation (GLSL to WGSL), render pipeline, material system
   - Avoids: Compute-heavy path tracing (Cycles)

5. **Cycles on WebGPU Compute** - Rewrite Cycles GPU kernels as WGSL compute shaders
   - Addresses: Path tracing, BVH traversal, shader evaluation in compute
   - Avoids: Trying to port CUDA/OptiX directly (impossible)

6. **Python Scripting** - Integrate Pyodide for bpy module support
   - Addresses: Scripting, addon support, user customization
   - Avoids: Blocking earlier phases on Python readiness

7. **File I/O & Persistence** - WasmFS + OPFS for .blend file save/load
   - Addresses: Persistent storage, file browser, import/export

**Phase ordering rationale:**
- Build system must work before anything else (Phase 1)
- GHOST/SDL is independent of GPU and can validate event handling (Phase 2)
- WebGPU viewport is prerequisite for both EEVEE and Cycles (Phase 3)
- EEVEE before Cycles because EEVEE is simpler (no compute shaders) and provides immediate visual feedback (Phase 4 before 5)
- Python is decoupled from rendering and should not block visual progress (Phase 6)

**Research flags for phases:**
- Phase 1: Likely needs deeper research on which of Blender's 30+ dependencies fail to compile under Emscripten
- Phase 3: Needs detailed investigation of GPUBackend interface requirements and WGSL shader generation
- Phase 5: Highest risk -- Cycles kernel rewrite needs dedicated feasibility study before committing

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack (Emscripten + emdawnwebgpu) | HIGH | Verified versions, active development, official documentation confirms approach |
| GPU Backend Strategy | MEDIUM | GPUBackend abstraction is clean, but no public precedent for WebGPU backend of this complexity |
| Shader Translation | MEDIUM | WGSL is the only option (verified), but the effort to translate Blender's shader corpus is uncertain |
| Threading Model | HIGH | Emscripten pthreads well-documented, COOP/COEP requirements well-understood |
| Memory Strategy | HIGH | WASM32 4GB is standard; Memory64 exists as escape valve |
| File System | HIGH | WasmFS + OPFS is the documented approach, browser support is universal |
| Python Integration | LOW | Pyodide exists and works, but bridging bpy module is uncharted territory |
| Dependency Compilation | LOW | Each of 30+ libraries is a potential blocker; no comprehensive precedent |

## Gaps to Address

- Exact list of which Blender dependencies fail under Emscripten (needs empirical testing in Phase 1)
- GPUBackendWebGPU detailed design (needs Phase 3 specific research)
- Cycles WGSL compute shader feasibility (needs dedicated study before Phase 5)
- Blender's GLSL shader corpus analysis -- how many shaders, how complex, how translatable to WGSL
- Performance benchmarks for Emscripten pthreads under heavy contention (Blender's task scheduler)
- Audio output strategy (Web Audio API bridge for Audaspace)
- Total output binary size estimation after all features enabled

---

*Summary: 2026-04-01*
