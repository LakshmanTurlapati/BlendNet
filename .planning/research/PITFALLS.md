# Domain Pitfalls: Porting Blender to WebAssembly/WebGPU

**Domain:** Large C/C++ 3D application (4.4M+ lines) with GPU rendering, compiled to WASM via Emscripten with WebGPU acceleration
**Researched:** 2026-04-01
**Overall Confidence:** HIGH (based on official Emscripten docs, WebGPU spec, and precedent from Figma/AutoCAD/Google Earth ports)

---

## Critical Pitfalls

Mistakes that cause rewrites, project-blocking delays, or fundamental architectural failures.

---

### Pitfall 1: WASM 4GB Memory Ceiling vs Blender's Unbounded Memory Model

**What goes wrong:** Blender's desktop version routinely exceeds 4GB for complex scenes -- a high-poly sculpt (10M+ faces), large texture sets, or fluid simulations can consume 8-16GB+. The WASM32 linear memory model is hard-capped at 4GB. Even approaching the ceiling causes fragmentation-related OOM crashes well before 4GB is reached because WASM cannot return freed memory to the OS, cannot use mmap/munmap, and cannot defragment its linear memory.

**Why it happens:** WASM's linear memory is a single contiguous growable buffer. Unlike native applications with virtual memory and mmap, WASM has:
- No virtual memory abstraction (all allocated pages are committed)
- No ability to shrink memory (memory.grow only grows, never shrinks)
- No mmap/munmap for memory-mapped files
- Fragmentation accumulates permanently across the session lifetime

Figma encountered this directly -- they limit allocations to 4GB minus one page to avoid Chrome bugs at the boundary. AutoCAD had to implement a custom virtual memory manager for their web port.

**Consequences:**
- Complex scenes silently crash the browser tab
- Long editing sessions accumulate fragmentation until OOM
- Mobile browsers (Safari, Chrome Android) kill WASM tabs aggressively at much lower thresholds (300-500MB on some devices)
- Users lose work with no recovery mechanism

**Prevention:**
1. Implement a tiered memory management system from day one:
   - Scene data budget: 1.5GB hard ceiling for scene graph
   - Texture streaming: Load/unload textures on demand, never hold full-res in WASM memory
   - Geometry LOD: Reduce mesh density in viewport, only load full-res for active editing
   - Undo stack compression: Blender's undo holds full scene snapshots -- compress or limit depth
2. Use memory64/wasm64 (now stable in Chrome 133+ and Firefox 134+) for large scenes, accepting that:
   - Safari support is still experimental
   - Pointer size doubles (8 bytes vs 4), increasing baseline memory ~30%
   - Many third-party libraries need recompilation
3. Implement an explicit "scene complexity" budget meter in the UI
4. Use IndexedDB/OPFS as overflow storage for inactive scene data

**Detection (warning signs):**
- `memory.grow()` calls increasing in frequency during profiling
- Blender's `MEM_guarded_alloc` tracking shows > 2GB in-session
- Sculpt undo memory (already known to be inaccurate per CONCERNS.md) triggers OOM

**Real-world precedent:** Figma limits to ~4GB minus one page. Google Earth streams data rather than loading full datasets. AutoCAD implemented custom VMM. Unity WebGL builds commonly crash on complex scenes due to identical memory constraints.

**Phase relevance:** Must be addressed in Phase 1 (build system / minimal viable compilation). Memory architecture decisions made here propagate through every subsequent phase.

---

### Pitfall 2: Synchronous Main Thread Blocking Causes Deadlocks and UI Freezes

**What goes wrong:** Blender's architecture is deeply synchronous. File loading (`BLO_read_from_file`), operator execution, modifier evaluation, and the entire depsgraph evaluation cycle assume synchronous execution. In browsers, the main thread CANNOT block -- `Atomics.wait()` is forbidden on the main thread. Any code path that blocks the main thread causes either a deadlock (if a worker needs to proxy back to main) or a permanent UI freeze.

**Why it happens:** Blender was written as a desktop application where the main thread can block freely. Specific problem areas:
- `pthread_join()` on main thread: busy-waits, consuming CPU and blocking event processing
- `pthread_mutex_lock()` on main thread: if a worker holds the lock and needs to proxy to main, instant deadlock
- File I/O: Blender's file reader is synchronous, reads .blend files sequentially
- Modal operators: Many tools (transform, sculpt) run synchronous modal loops
- Depsgraph evaluation: `DEG_evaluate_on_framechange` blocks until complete
- The window manager event loop (`wm_event_system.cc` -- 12,926 lines, already flagged as fragile) assumes synchronous event processing

**Consequences:**
- Hard deadlocks that require killing the browser tab
- UI becomes unresponsive during any heavy operation
- File loading appears to hang indefinitely
- Modifier stack evaluation freezes the viewport

**Prevention:**
1. Use `-sPROXY_TO_PTHREAD` to move `main()` off the browser main thread entirely. This is the single most important Emscripten flag for this project. It moves the entire Blender event loop to a Web Worker, leaving the browser main thread free for proxied operations.
2. Identify and catalog every blocking call path in the window manager and operator system
3. Replace synchronous file I/O with Emscripten's async file system or OPFS:
   - `BLO_read_from_file()` must become async or run on worker thread
   - Use Emscripten `ASYNCIFY` only for isolated code paths, not globally (see Pitfall 5)
4. Implement a loading screen / progress indicator that runs on the browser main thread while WASM worker thread processes
5. Audit all `pthread_mutex_lock` usage for main-thread safety

**Detection (warning signs):**
- Browser DevTools showing "Page Unresponsive" dialogs
- `Atomics.wait` console errors on main thread
- Emscripten runtime warnings about blocking on main thread
- Workers stuck in "waiting" state in DevTools

**Real-world precedent:** AutoCAD Web uses a dual-thread architecture specifically to avoid main thread blocking. Google Earth encountered threading issues where some browsers lacked multi-threading, causing dramatic performance degradation.

**Phase relevance:** Phase 1 (core compilation). The `-sPROXY_TO_PTHREAD` decision and main loop refactoring must happen before any subsystem porting.

---

### Pitfall 3: WebGPU Shader Translation -- GLSL/SPIR-V to WGSL is Not a Simple Transpile

**What goes wrong:** Blender has hundreds of GPU shaders across EEVEE, Cycles, the draw manager, and compositing -- written in GLSL and compiled to SPIR-V for Vulkan/Metal backends. WebGPU requires WGSL. The translation is NOT a mechanical transpile because:

1. **Combined image samplers** do not exist in WebGPU (OpenGL/Vulkan use them extensively; Blender's GPU module uses them)
2. **WGSL lacks `isnan`/`isinf`** -- these must be replaced with IEEE-754 bit manipulation
3. **Bind group layout differences**: WebGPU has only 4 bind groups by default (vs effectively unlimited descriptor sets in Vulkan)
4. **Storage buffer limits**: 8 per shader stage default in WebGPU vs much higher in Vulkan/Metal
5. **Uniform buffer size**: 64KB max in WebGPU vs 64KB minimum in Vulkan (but Blender shaders may assume larger)
6. **Coordinate system differences**: WebGPU uses different clip space conventions than OpenGL (-1 to 1 depth vs 0 to 1)
7. **No geometry shaders** in WebGPU (Blender uses these in some overlay drawing)
8. **Shader validation strictness**: WGSL is far stricter than GLSL; implicit conversions that work in GLSL fail in WGSL

**Why it happens:** Blender's GPU abstraction (`source/blender/gpu`) has backends for OpenGL, Vulkan, and Metal, but these share assumptions (combined samplers, generous resource limits, geometry shaders) that WebGPU deliberately excludes for portability and security reasons.

**Consequences:**
- Months of shader-by-shader debugging and rewriting
- Runtime failures on specific GPUs due to browser shader translation bugs (Tint/Naga have known translation errors discovered by fuzzing)
- Performance regressions from workarounds (splitting bind groups, restructuring data layouts)
- Blender's shader linting tool (already flagged as fragile in CONCERNS.md -- "cannot detect vector/matrix type safety issues") will miss WebGPU-specific problems

**Prevention:**
1. Build the WebGPU backend as a new backend in `source/blender/gpu/` (like the existing Vulkan backend), NOT as a wrapper around the OpenGL backend
2. Use Google's Tint library (part of Dawn) for SPIR-V to WGSL translation as a starting point, but expect manual shader rewrites for:
   - Any shader using combined image samplers (split into separate texture + sampler bindings)
   - Geometry shader usage (convert to compute + vertex shaders)
   - Shaders exceeding 4 bind groups (restructure resource layouts)
3. Implement a shader validation CI pipeline that tests every shader on Chrome (Tint/Dawn), Firefox (Naga/wgpu), and Safari (Metal backend)
4. Design bind group layouts to fit within WebGPU's 4-group default from the start -- do not assume higher limits
5. Handle the async nature of WebGPU pipeline creation (unlike OpenGL's synchronous shader compilation)

**Detection (warning signs):**
- Shader compilation errors that only appear on specific browsers
- Visual artifacts (incorrect normals, lighting) after shader conversion
- Performance profiling showing excessive draw calls from bind group splitting

**Real-world precedent:** Figma built a custom GLSL-to-WGSL shader processor and had to maintain both GLSL and WGSL codepaths simultaneously. They documented "many differences between WebGL and WebGPU that had to be accounted for," including coordinate systems, error handling, and sync/async readback.

**Phase relevance:** Phases 2-3 (GPU backend and viewport rendering). Shader translation is the longest single work item for the GPU backend.

---

### Pitfall 4: Cross-Origin Isolation (COOP/COEP) Breaks Third-Party Embeds and Standard Web Patterns

**What goes wrong:** SharedArrayBuffer (required for pthreads/multi-threading) is gated behind Cross-Origin Opener Policy (COOP) and Cross-Origin Embedder Policy (COEP) headers. Setting these headers has cascading effects:
- All cross-origin resources must be served with `Cross-Origin-Resource-Policy: cross-origin` or loaded via CORS
- Third-party iframes and scripts that don't support CORS will break
- OAuth popup flows may break (COOP isolates window references)
- CDN-hosted assets need CORS headers
- Browser extensions may malfunction

**Why it happens:** After the Spectre vulnerability, browsers require cross-origin isolation before exposing SharedArrayBuffer. Without SharedArrayBuffer, Emscripten pthreads cannot function, reducing Blender to single-threaded execution -- which is unacceptable for a 3D application (Cycles rendering, physics simulation, and depsgraph evaluation all rely heavily on threads).

**Consequences:**
- Without COOP/COEP: no threading, catastrophically slow performance
- With COOP/COEP: deployment complexity, broken integrations, cannot be embedded in other sites without those sites also setting isolation headers
- AutoCAD Web specifically had to work with the Chrome team to find alternatives after SharedArrayBuffer was gated

**Prevention:**
1. Set COOP/COEP headers from day one in the development server:
   ```
   Cross-Origin-Opener-Policy: same-origin
   Cross-Origin-Embedder-Policy: require-corp
   ```
2. Serve ALL assets (WASM binary, JS glue, textures, fonts) from the same origin or with proper CORS headers
3. If embedding in other sites is a requirement, investigate `crossOriginIsolated` credentialless mode (newer alternative)
4. Test deployment on all target hosting platforms (static hosting, CDNs) early -- many CDNs don't send correct CORS headers by default
5. Design the authentication/OAuth flow to work within COOP constraints (use `postMessage` instead of window references)

**Detection (warning signs):**
- `self.crossOriginIsolated` returns `false` in browser console
- `SharedArrayBuffer is not defined` errors
- Emscripten pthreads falling back to single-threaded mode silently
- Third-party resources failing to load with CORS errors

**Real-world precedent:** AutoCAD Web encountered this directly when browsers began gating SharedArrayBuffer. Google Earth initially only worked in Chrome due to varying browser support for required threading primitives.

**Phase relevance:** Phase 1 (deployment infrastructure). Headers must be configured before any multi-threaded testing can begin.

---

### Pitfall 5: Asyncify Overhead Explodes on a 4.4M-Line Codebase

**What goes wrong:** Emscripten's Asyncify feature (which allows synchronous C/C++ code to yield to the browser's event loop) works by instrumenting the call graph to support unwinding and rewinding. On a 4.4M+ line codebase:
- Code size increases ~50% or more
- Link time increases dramatically (Asyncify performs whole-program analysis)
- Performance degrades ~50% on instrumented code paths
- Indirect function calls (extremely common in Blender's operator system, modifier callbacks, and node evaluation) force Asyncify to instrument conservatively because it cannot determine their targets

**Why it happens:** Asyncify traces the entire call graph from every async entry point. Blender's heavy use of function pointers (operators, modifiers, callbacks, Python bindings) means Asyncify cannot narrow the instrumented set, leading to near-whole-program instrumentation.

**Consequences:**
- WASM binary size could double (from already-large 50-100MB+ to 100-200MB+)
- Build times become hours instead of minutes
- Runtime performance drops by half in affected code paths
- Memory usage increases from the shadow stack and auxiliary data

**Prevention:**
1. Do NOT use global Asyncify. Instead:
   - Use `-sPROXY_TO_PTHREAD` (moves main() to worker, avoiding need for main thread async)
   - Use JSPI (JavaScript Promise Integration) where available -- it achieves the same effect with zero WASM transformation, zero code size overhead, and zero link-time cost. Available in Chrome behind a flag, progressing toward standard.
   - For the small number of remaining async boundaries, use `ASYNCIFY_ONLY` to whitelist specific functions rather than instrumenting the whole program
2. If Asyncify is absolutely required for specific code paths, use `ASYNCIFY_ONLY=[list]` and `ASYNCIFY_REMOVE=[list]` to precisely control which functions are instrumented
3. Measure build time and binary size with Asyncify early -- if either is unacceptable, it is a signal to refactor the async boundary rather than expanding Asyncify scope

**Detection (warning signs):**
- Link step taking > 10 minutes
- WASM binary > 100MB after Asyncify
- Runtime profiling showing Asyncify overhead in hot paths (render loop, event processing)

**Real-world precedent:** The Emscripten team explicitly warns about Asyncify overhead on large codebases and recommends JSPI as the successor technology. Kripken's blog post on Asyncify documents the ~50% overhead.

**Phase relevance:** Phase 1 (build system design). This is an architectural decision that must be made before porting subsystems.

---

### Pitfall 6: Cycles Path Tracer Cannot Use Hardware Ray Tracing on WebGPU

**What goes wrong:** Blender's Cycles renderer uses hardware-accelerated ray tracing via CUDA/OptiX (NVIDIA), HIP (AMD), and Metal (Apple). WebGPU has NO hardware ray tracing extension -- not in the spec, not standardized, no timeline for inclusion. Cycles must fall back to compute-shader-based software ray tracing, which is dramatically slower.

**Why it happens:** The WebGPU working group is focused on stabilizing the core 1.0 spec. Hardware ray tracing (equivalent to VK_KHR_ray_tracing) exists only as unofficial community experiments (dawn-ray-tracing) requiring custom browser builds. There is an open issue (#535) on the WebGPU spec for ray tracing extensions, but no published timeline.

Additionally, WebGPU compute shaders have significant limitations compared to CUDA:
- No device-scoped barriers (single-pass prefix sum impossible)
- No subgroup operations (cross-lane communication requires shared memory)
- No real pointers (buffer-index-only memory model)
- Max 8 storage buffers per shader stage (BVH traversal may need more)
- Max 16KB workgroup shared memory (vs 48KB+ on CUDA)
- Storage texture reads hidden behind feature flags

**Consequences:**
- Cycles WebGPU compute path will be 5-15x slower than native hardware RT
- Complex scenes that render in minutes on desktop could take hours in browser
- Users expecting "Blender in the browser" will be disappointed by rendering speed
- The Cycles kernel is complex (uses CUDA-specific intrinsics, wavefront path tracing)

**Prevention:**
1. Accept that Cycles in the browser will be a "preview" renderer, not production-quality
2. Prioritize EEVEE (real-time rasterization) as the primary web renderer -- it maps much better to WebGPU's rendering pipeline
3. For Cycles, implement a simplified compute-shader kernel:
   - Start with basic path tracing (diffuse, glossy) without advanced features (volumes, subsurface)
   - Use a tiled rendering approach to work within workgroup memory limits
   - Restructure BVH traversal to fit within 8 storage buffer binding limit
4. Consider cloud rendering for production Cycles output (render on server, stream result to browser)
5. Monitor WebGPU ray tracing extension progress; design the compute path so it can optionally use HW RT when available

**Detection (warning signs):**
- Compute shader hitting storage buffer limits during BVH traversal implementation
- Workgroup shared memory exceeded during shader integration
- Render times 10x+ slower than EEVEE for equivalent scenes

**Real-world precedent:** Community WebGPU path tracers exist but are limited to simple scenes. No production-quality path tracer runs on WebGPU today. Blender's own Cycles CUDA/OptiX backend took years to optimize and relies on hardware-specific features unavailable in WebGPU.

**Phase relevance:** Phases 4-5 (rendering engines). EEVEE should be ported first; Cycles as a later, separate milestone with managed expectations.

---

## Moderate Pitfalls

Mistakes that cause significant delays or degraded quality, but are recoverable.

---

### Pitfall 7: Build Time Explosion -- Hours-Long Compile/Link Cycles

**What goes wrong:** Compiling 4.4M lines of C/C++ through Emscripten is dramatically slower than native compilation. Emscripten uses Clang for compilation (similar speed) but the link step involves:
- LLVM bitcode linking
- Binaryen wasm-opt optimization (whole-program)
- JavaScript glue code generation
- Asyncify instrumentation (if enabled, see Pitfall 5)
- wasm-split for code splitting (if used)

For a codebase of Blender's size, a clean build could take 2-4 hours; even incremental builds can take 30-60 minutes.

**Prevention:**
1. Use incremental compilation with Ninja build system (not Make)
2. Split the project into separately compiled modules using Emscripten side modules (dynamic linking) where possible
3. Use `-O0` for the link step during development, even when compiling sources at `-O2`
4. Use `ccache` or `sccache` for compilation caching
5. Set up CI with build caching (cache compiled object files between runs)
6. Consider Emscripten's `-sSPLIT_MODULE` for splitting the output and improving incremental link times
7. Disable Asyncify and wasm-opt during development builds (`-O0 --no-entry` for fastest iteration)

**Detection (warning signs):**
- Developer productivity drops because of long feedback loops
- CI builds timing out
- Developers skipping WASM builds and only testing native

**Phase relevance:** Phase 1 (build system). Invest heavily in build infrastructure before porting subsystems.

---

### Pitfall 8: WASM Binary Size Makes Initial Load Unacceptable

**What goes wrong:** A full Blender WASM binary could easily be 100-200MB+ (before compression). Blender's native binary is already ~150MB with all features. WASM binaries tend to be larger than native binaries due to:
- All code compiled to a single module by default
- No dynamic linking of system libraries (everything statically linked)
- DWARF debug info if not stripped
- Asyncify instrumentation overhead

A 100MB+ download before the application is usable makes the "no installation" value proposition meaningless.

**Prevention:**
1. Aggressive feature gating at compile time using Blender's 150+ CMake toggles:
   - Phase 1: Core only (blenlib, makesdna, blenkernel, gpu, windowing) -- target < 30MB compressed
   - Phase 2: Add viewport and basic editing -- target < 50MB compressed
   - Phase 3+: Add rendering, simulation, etc. as lazy-loaded side modules
2. Use Emscripten's `wasm-split` (profile-guided module splitting) to split into:
   - Primary module: startup code + frequently used paths (~20-30MB compressed)
   - Secondary modules: lazy-loaded on first use
3. Apply Brotli compression (browsers decompress natively) -- typically 60-70% reduction
4. Use streaming compilation (`WebAssembly.compileStreaming`) so compilation starts during download
5. Implement a loading progress indicator showing meaningful stages (downloading, compiling, initializing)
6. Set `Content-Type: application/wasm` header for proper streaming compilation
7. Note: Chrome blocks synchronous compilation of WASM modules > 8MB on the main thread; always use async instantiation

**Detection (warning signs):**
- Compressed WASM binary > 30MB for Phase 1
- Time-to-interactive > 10 seconds on broadband
- Users abandoning before load completes (analytics)

**Real-world precedent:** AutoCAD Web uses profile-guided optimization and module splitting. Figma's WASM binary is carefully size-optimized. Google Earth streams data progressively rather than loading everything upfront.

**Phase relevance:** Phase 1 (build system). Module splitting architecture must be designed before subsystems are compiled.

---

### Pitfall 9: Python/Pyodide Integration is a Second Application Inside Your Application

**What goes wrong:** Blender's Python scripting (bpy module, addons, automation) requires a full CPython interpreter. Pyodide (CPython compiled to WASM) adds:
- ~15-30MB additional download for the Python runtime + stdlib
- Significant initialization time (seconds)
- Only pure-Python packages and pre-compiled WASM packages work
- C-extension packages (many Blender addons use them) will not work
- Memory usage for Python runtime + Blender's Python API bindings
- Two separate WASM memory spaces (Pyodide's and Blender's) unless carefully shared

**Why it happens:** Blender's `makesrna` layer exposes the entire data model to Python. The `bpy` module is deeply integrated -- operators, UI definitions, addons, and even some core features are implemented in Python. Removing Python support breaks fundamental Blender functionality.

**Consequences:**
- Load time doubles if Python is loaded at startup
- Many popular addons won't work (anything using numpy C extensions, or C-extension based packages)
- Memory budget consumed by two separate runtimes
- Complex interop layer between Blender's WASM memory and Pyodide's WASM memory

**Prevention:**
1. Make Python support optional and lazy-loaded:
   - Core Blender starts without Python
   - Python loads on first scripting/addon use
   - Show "Loading Python runtime..." indicator
2. Pre-compile the `bpy` module as part of the Emscripten build (not as a separate Pyodide package)
3. Use a shared memory approach if possible (both runtimes in the same WASM memory space)
4. Curate a "web-compatible addons" list -- only pure-Python addons that don't import C extensions
5. Consider a "headless Python" mode that runs frequently-needed Python code (UI definitions) as pre-generated C code instead

**Detection (warning signs):**
- Time-to-interactive > 15 seconds with Python enabled
- Memory usage > 500MB before any scene is loaded
- Addon error rate > 50% for community addons

**Phase relevance:** Late phase (Phase 5+). Python scripting should be one of the last features ported; core Blender should work without it.

---

### Pitfall 10: GHOST Platform Layer Requires Complete Reimplementation for Browser

**What goes wrong:** Blender's platform abstraction layer (GHOST -- General Handy Operating System Toolkit) handles windowing, input, cursors, clipboard, drag-and-drop, and system integration. It has backends for X11, Wayland, Win32, and Cocoa. None of these map to the browser. Every function in GHOST must be reimplemented using:
- Canvas API for window surface
- DOM events for input (keyboard, mouse, touch, pointer)
- Clipboard API (async, permission-gated)
- Drag-and-drop via HTML5 drag events
- No system file dialogs (must use `<input type="file">` and File System Access API)
- No system cursors beyond CSS cursor property
- No raw input / pointer lock beyond `requestPointerLock()`
- No multi-window support (browser tabs are independent)

**Why it happens:** GHOST was designed for desktop operating systems. The browser's security sandbox intentionally restricts many of the capabilities GHOST assumes (multi-window, system clipboard, raw input, file system access).

**Consequences:**
- Multi-window workflows (common in Blender: detached editors, render preview windows) are impossible
- Clipboard operations are async and permission-gated (breaks Blender's synchronous clipboard API)
- File open/save requires completely different UX (no native file dialogs)
- Input handling differences (browser keyboard events have different key codes, no raw HID access)
- Tablet pressure sensitivity requires Pointer Events API (different from Blender's Wacom tablet support)

**Prevention:**
1. Implement `GHOST_SystemWeb` as a new GHOST backend (follow the pattern of existing backends in `intern/ghost/`)
2. Single-window mode only -- all Blender editors in one canvas/container
3. Map browser events to GHOST events using a translation layer
4. Implement clipboard via async Clipboard API with fallback to `document.execCommand`
5. File I/O via:
   - File System Access API (Chrome, Edge) for native-like file picking
   - `<input type="file">` as universal fallback
   - OPFS (Origin Private File System) for workspace persistence
6. Pointer Lock API for viewport navigation (orbit, pan in 3D view)
7. Accept that some input features (Wacom tilt, multi-button mouse) will be degraded

**Detection (warning signs):**
- Input lag or missed events in the 3D viewport
- Copy/paste not working or requiring multiple user confirmations
- File open/save workflow confusing users
- Touch/stylus input not registering pressure

**Phase relevance:** Phase 1-2 (GHOST reimplementation is on the critical path -- nothing renders without windowing and input).

---

### Pitfall 11: WebGPU Async Pipeline Creation vs Blender's Synchronous Shader Compilation

**What goes wrong:** In OpenGL (and partly Vulkan), shader compilation and pipeline creation can be done synchronously -- compile a shader, get a program object, draw immediately. WebGPU pipeline creation is fundamentally asynchronous (`device.createRenderPipelineAsync()`, `device.createComputePipelineAsync()`). Blender's draw manager and material system assume shaders are available immediately after compilation.

Additionally, WebGPU readback is async-only. There is no `glReadPixels` equivalent that returns data synchronously. Figma specifically documented this as a major challenge -- async readback could add "hundreds of milliseconds" to operations that were previously instant.

**Consequences:**
- First frame after material change shows black/fallback until pipeline compiles
- Selection/picking (which reads back the GPU buffer) becomes async
- Any code path that compiles a shader and immediately draws with it will fail
- Shader compilation stalls cause visible frame drops

**Prevention:**
1. Implement a pipeline cache with pre-compilation of common shader variants at startup
2. Use synchronous `createRenderPipeline()` / `createComputePipeline()` (exists but may cause jank) for critical-path shaders, async for the rest
3. Design a "shader warming" system that pre-compiles shaders during load screen
4. For readback (selection picking, color sampling), implement a one-frame-delay readback pattern:
   - Frame N: issue readback request
   - Frame N+1: results available
   - Use CPU-side picking as fallback during async gap
5. Implement fallback materials (solid color) shown while real materials compile

**Detection (warning signs):**
- Black flickering when changing materials or entering edit mode
- Selection clicks not registering (async readback delay)
- Viewport freezing during first draw after shader changes

**Real-world precedent:** Figma had to redesign their readback pipeline for WebGPU. The one-frame delay pattern is standard in WebGPU applications.

**Phase relevance:** Phase 2-3 (GPU backend). Must be designed into the WebGPU backend architecture, not bolted on later.

---

### Pitfall 12: Browser Tab Lifecycle -- Losing State on Suspend/Discard

**What goes wrong:** Browsers aggressively manage memory by suspending or discarding background tabs. When a tab running Blender is discarded:
- All WASM memory is lost
- All Web Worker threads are terminated
- GPU context is destroyed
- IndexedDB transactions may be interrupted
- There is NO way to serialize and restore arbitrary WASM state

On mobile browsers, this happens frequently -- switching to another app for 30 seconds can trigger tab discard on memory-constrained devices.

**Consequences:**
- Users lose unsaved work when switching tabs or apps
- No warning before discard on most browsers
- "Tab crashed" with no recovery path
- Mobile usage is essentially broken without auto-save

**Prevention:**
1. Implement aggressive auto-save to OPFS/IndexedDB:
   - Save on every significant operation (not just on explicit save)
   - Save incrementally (diff-based) to minimize I/O
   - Save on `visibilitychange` event (fires when tab goes to background)
   - Save on `beforeunload` event (last chance before tab close)
2. Implement session recovery:
   - On startup, check for auto-save data
   - Offer "Recover last session" like desktop Blender
3. Use the `Page Lifecycle API` to detect freeze/discard transitions where available
4. Display a "Save your work" warning when memory pressure is detected
5. Keep auto-save files small by saving only diffs, not full .blend snapshots

**Detection (warning signs):**
- User reports of lost work after tab switching
- High frequency of "tab crash" reports
- `performance.memory` (Chrome) showing JS heap approaching limits

**Phase relevance:** Phase 2+ (once editing is functional). Auto-save infrastructure should be built before alpha testing.

---

## Minor Pitfalls

Issues that cause friction, bugs, or developer confusion, but have known workarounds.

---

### Pitfall 13: Thread Count Limitations and Worker Pool Sizing

**What goes wrong:** Firefox limits Web Workers to 20 per domain by default. Blender's thread pool (used for Cycles rendering, physics simulation, geometry nodes evaluation) typically sizes to CPU core count, which can be 8-32+ on modern machines. Over-creating workers causes silent failures or performance degradation.

**Prevention:**
- Query `navigator.hardwareConcurrency` but cap at a reasonable maximum (8-12 workers)
- Use `-sPTHREAD_POOL_SIZE=N` to pre-create a fixed worker pool
- Implement work-stealing rather than thread-per-task for better resource usage
- Workers consume memory (~1-2MB each for stack + TLS); budget this against the 4GB ceiling

**Phase relevance:** Phase 1 (threading architecture).

---

### Pitfall 14: Dynamic Linking Limitations Break Addon Architecture

**What goes wrong:** Blender's addon system and some internal modules use dynamic library patterns. Emscripten's dynamic linking (dlopen/dlsym) has significant limitations:
- Chrome blocks synchronous compilation of WASM side modules > 8MB on main thread
- C++ symbol mangling makes dlsym unreliable for C++ symbols
- Dynamic linking + pthreads is "still experimental" (Emscripten docs)
- Nested dynamic libraries have unresolved bugs (as of late 2025)
- Function table synchronization across threads when loading new modules requires expensive global coordination

**Prevention:**
- Statically link all core Blender modules
- Design addon loading to use `emscripten_dlopen()` (async) instead of `dlopen()` (sync)
- Limit dynamic modules to pure-C interfaces (no C++ symbols via dlsym)
- Test dynamic linking thoroughly with pthreads enabled before relying on it

**Phase relevance:** Late phase (addon system). Not critical for MVP.

---

### Pitfall 15: Emscripten Memory Allocator Contention Under Multi-Threading

**What goes wrong:** Emscripten's default `dlmalloc` has a single global lock. Blender is heavily multi-threaded (Cycles rendering, physics, geometry nodes, depsgraph evaluation). Every `malloc`/`free` from any thread contends on one lock, causing severe throughput degradation.

**Prevention:**
- Use `-sMALLOC=mimalloc` for better multi-threaded allocation performance
- Accept the tradeoff: mimalloc increases code size and base memory usage
- Blender already uses `MEM_guarded_alloc` for tracked allocations -- ensure this delegates to mimalloc
- Profile allocation hotspots and use arena/pool allocators for high-frequency paths (mesh buffers, node evaluation temporaries)

**Phase relevance:** Phase 1 (build configuration). Set the allocator early; changing later requires retesting everything.

---

### Pitfall 16: WebGPU Device Loss and Recovery

**What goes wrong:** WebGPU devices can be "lost" at any time -- GPU driver crash, system sleep/wake, GPU resource exhaustion, or browser deciding to reclaim GPU resources. When the device is lost, ALL GPU state is invalidated: buffers, textures, pipelines, everything. Unlike desktop OpenGL/Vulkan where GPU crashes often mean application crash, WebGPU exposes this as a recoverable event.

**Prevention:**
- Implement `device.lost` promise handler from day one
- Design all GPU resource management to support re-creation:
   - Maintain a CPU-side copy of critical GPU data (or the ability to regenerate it)
   - Use a resource manager that can re-upload all buffers/textures on device recovery
- Test device loss explicitly (Chrome DevTools can simulate this)
- Show a "GPU connection lost, recovering..." message rather than crashing

**Phase relevance:** Phase 2-3 (GPU backend). Design the resource manager to handle this from the start.

---

### Pitfall 17: WebGPU Texture and Buffer Limits Impact Real Workflows

**What goes wrong:** WebGPU default guaranteed limits are significantly lower than desktop GPU capabilities:

| Resource | WebGPU Default | Typical Desktop |
|----------|---------------|-----------------|
| Max 2D texture size | 8192x8192 | 16384x16384+ |
| Max 3D texture size | 2048^3 | 8192+ |
| Max buffer size | 256MB | 2GB+ (VRAM limited) |
| Max storage buffer binding | 128MB | 2GB+ |
| Max bind groups | 4 | 8+ (Vulkan) |
| Max storage buffers/stage | 8 | 16+ |
| Max uniform buffer binding | 64KB | 64KB+ |
| Workgroup shared memory | 16KB | 48KB+ (CUDA) |

For Blender workflows: 4K texture painting needs 16384x16384 (not guaranteed). Sculpting high-poly meshes may exceed 256MB buffer limits. Cycles BVH may need more than 8 storage buffers.

**Prevention:**
- Request higher limits via `adapter.requestDevice({ requiredLimits })` but handle rejection gracefully
- Implement texture tiling for textures > 8192 (split into multiple tiles)
- Chunk large buffers into multiple 256MB segments
- Design Cycles compute shaders to work within 8 storage buffers (pack multiple data streams into fewer buffers)
- Note: browsers report tiered values for fingerprinting protection, so actual available limits may be higher but not queryable precisely

**Phase relevance:** Phase 2+ (GPU backend, rendering). Budget resources within default limits first; request higher limits as optional enhancements.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Phase 1: Build System & Core Compilation | Build times > 2 hours; binary > 100MB; memory architecture wrong | Invest in build caching, module splitting, `-sPROXY_TO_PTHREAD`, mimalloc, memory budgeting |
| Phase 1: COOP/COEP Headers | No threading without correct headers; discovered late in deployment | Configure headers in dev server from day one; test on actual hosting platform |
| Phase 2: GHOST/Windowing | Missing browser APIs; input handling bugs; no multi-window | New GHOST_SystemWeb backend; accept single-window; use Pointer Events + requestPointerLock |
| Phase 2-3: GPU Backend | Shader translation failures; async pipeline stalls; device loss | New WebGPU backend (not wrapper); pipeline caching; shader warming; device loss handler |
| Phase 3: Viewport & Drawing | Frame drops from shader compilation; readback latency for picking | Pre-compile common shaders; one-frame-delay readback; CPU fallback picking |
| Phase 4: EEVEE Renderer | Bind group limits; uniform buffer size; no geometry shaders | Restructure resource layouts; convert geometry shaders to compute; respect 4-group limit |
| Phase 5: Cycles Renderer | No HW ray tracing; compute limits; hours-long renders | Accept preview quality; simplified kernel; tiled rendering; consider cloud rendering |
| Phase 5+: Python Scripting | Load time; memory; C-extension incompatibility | Lazy load; pre-compile bpy; curate web-safe addons list |
| Phase 6+: Simulation (Mantaflow, Bullet) | Memory explosion; threading contention; WASM 4GB limit | Reduced resolution defaults; memory budgets; progressive simulation |
| All Phases: Tab Lifecycle | Data loss on tab discard/suspend | Auto-save to OPFS on every operation; session recovery on reload |
| All Phases: Mobile | 300-500MB OOM kills; no keyboard; small screen | Treat mobile as reduced-feature mode; aggressive memory limits; touch-optimized UI |

---

## Sources

### Official Documentation
- [Emscripten Portability Guidelines](https://emscripten.org/docs/porting/guidelines/portability_guidelines.html) -- HIGH confidence
- [Emscripten Pthreads Support](https://emscripten.org/docs/porting/pthreads.html) -- HIGH confidence
- [Emscripten Dynamic Linking](https://emscripten.org/docs/compiling/Dynamic-Linking.html) -- HIGH confidence
- [Emscripten Asyncify](https://emscripten.org/docs/porting/asyncify.html) -- HIGH confidence
- [Emscripten OpenGL Support](https://emscripten.org/docs/porting/multimedia_and_graphics/OpenGL-support.html) -- HIGH confidence
- [Emscripten Module Splitting](https://emscripten.org/docs/optimizing/Module-Splitting.html) -- HIGH confidence
- [WebGPU Specification (W3C)](https://www.w3.org/TR/webgpu/) -- HIGH confidence
- [WebGPU GPUSupportedLimits (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/GPUSupportedLimits) -- HIGH confidence
- [V8 Blog: 4GB WASM Memory](https://v8.dev/blog/4gb-wasm-memory) -- HIGH confidence
- [Pyodide WASM Constraints](https://pyodide.org/en/stable/usage/wasm-constraints.html) -- HIGH confidence

### Real-World Precedent
- [Figma: WebAssembly Cut Load Time 3x](https://www.figma.com/blog/webassembly-cut-figmas-load-time-by-3x/) -- HIGH confidence
- [Figma: Rendering Powered by WebGPU](https://www.figma.com/blog/figma-rendering-powered-by-webgpu/) -- HIGH confidence
- [AutoCAD & WebAssembly: Moving 30 Year Codebase to Web (QCon)](https://qconnewyork.com/ny2018/ny2018/presentation/web-assembly-autodesk.html) -- MEDIUM confidence
- [Google Earth: How We're Bringing Earth to the Web](https://web.dev/earth-webassembly/index.html) -- MEDIUM confidence
- [Google Earth: Road to Cross Browser](https://medium.com/google-earth/earth-on-web-the-road-to-cross-browser-7338e0f46278) -- MEDIUM confidence

### WebAssembly Design Issues
- [WASM Memory Management Issue #1397](https://github.com/WebAssembly/design/issues/1397) -- HIGH confidence
- [Breaking Up Large WASM Binaries #1166](https://github.com/WebAssembly/design/issues/1166) -- MEDIUM confidence
- [WebGPU Ray Tracing Extension #535](https://github.com/gpuweb/gpuweb/issues/535) -- MEDIUM confidence
- [WASM Memory64 Spec](https://github.com/WebAssembly/spec/issues/1892) -- HIGH confidence

### WebGPU Compute Limitations
- [ONNX Runtime WebGPU vs CUDA Performance](https://github.com/microsoft/onnxruntime/discussions/20177) -- MEDIUM confidence
- [WebGPU is Not a Replacement for Vulkan (yet)](https://medium.com/@spencerkohan/webgpu-is-not-a-replacement-for-vulkan-yet-233ba1bb7829) -- MEDIUM confidence
- [DarthShader: Fuzzing WebGPU Shader Translators](https://arxiv.org/html/2409.01824v1) -- HIGH confidence
- [Unity WebGPU Limitations](https://docs.unity3d.com/6000.3/Documentation/Manual/WebGPU-limitations.html) -- HIGH confidence

### Shader Translation
- [WGSL/SPIR-V Combined Image Samplers Issue](https://github.com/gpuweb/gpuweb/issues/44) -- HIGH confidence
- [Naga Shader Translation Benchmark](http://kvark.github.io/naga/shader/2022/02/17/shader-translation-benchmark.html) -- MEDIUM confidence

### Memory64 / wasm64
- [Wasm64 is Here! (2025)](https://unlimited3d.wordpress.com/2025/02/07/wasm64-is-here/comment-page-1/) -- MEDIUM confidence

---

*Pitfalls audit: 2026-04-01*
