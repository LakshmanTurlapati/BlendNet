# Architecture Patterns: Blender Web (WASM/WebGPU Port)

**Domain:** Large native C/C++ 3D application ported to browser via WebAssembly
**Researched:** 2026-04-01
**Confidence:** MEDIUM -- based on Blender source code analysis, Emscripten/WebGPU documentation, and prior art from large WASM ports (Godot, Unity). No prior full Blender WASM port exists as reference.

---

## Executive Summary

Porting Blender to the browser requires surgical changes at well-defined abstraction boundaries rather than a rewrite. The existing codebase has a layered modular monolith architecture with clear separation between platform-specific code (GHOST, GPU backends, Cycles device backends) and the core engine (blenkernel, depsgraph, editors). The port strategy targets these abstraction seams:

1. **GHOST layer** -- Replace with a browser-native GHOST_SystemWeb implementation (canvas events, requestAnimationFrame loop)
2. **GPU backend** -- Add a WebGPU backend (`source/blender/gpu/webgpu/`) implementing the existing `GPUBackend` abstract interface
3. **Cycles device** -- Add a WebGPU compute device (`intern/cycles/device/webgpu/`) alongside existing CPU/CUDA/Metal/HIP devices
4. **Threading** -- Emscripten pthreads maps to Web Workers with SharedArrayBuffer; requires COOP/COEP headers
5. **File I/O** -- Emscripten virtual filesystem with OPFS persistence backend
6. **Python** -- Pyodide integration for bpy scripting (pure-Python addons only)

The core engine (blenlib, makesdna/makesrna, blenkernel, depsgraph, bmesh, geometry, editors, nodes, functions, animrig) ports unchanged -- this is the bulk of Blender's 4M+ lines.

---

## Recommended Architecture

### High-Level Port Topology

```
+------------------------------------------------------------------+
|                        Browser Tab                                |
|                                                                   |
|  +------------------+  +-----------+  +-----------+               |
|  | HTML Canvas      |  | IndexedDB |  | OPFS      |              |
|  | (WebGPU surface) |  | (persist) |  | (files)   |              |
|  +--------+---------+  +-----+-----+  +-----+-----+              |
|           |                  |               |                    |
|  +--------v------------------v---------------v-----------+        |
|  |              Emscripten Runtime Layer                  |        |
|  |  +------------+  +-----------+  +------------------+  |        |
|  |  | pthreads   |  | MEMFS +   |  | Emscripten       | |        |
|  |  | (Workers + |  | IDBFS +   |  | GL/WebGPU        | |        |
|  |  |  SAB)      |  | OPFS      |  | bindings         | |        |
|  |  +------+-----+  +-----+-----+  +--------+---------+ |        |
|  +---------|---------------|-----------------|------------+        |
|            |               |                 |                    |
|  +---------v---------------v-----------------v-----------+        |
|  |              Blender WASM Binary                       |        |
|  |                                                        |        |
|  |  +---------------------------------------------+      |        |
|  |  | GHOST_SystemWeb (new)                        |      |        |
|  |  | Canvas events -> GHOST events                |      |        |
|  |  | requestAnimationFrame -> processEvents loop  |      |        |
|  |  +----------------------+----------------------+      |        |
|  |                         |                              |        |
|  |  +----------------------v----------------------+      |        |
|  |  | Window Manager                              |      |        |
|  |  | (wm_event_system, operators, context)        |      |        |
|  |  +----------------------+----------------------+      |        |
|  |                         |                              |        |
|  |  +-------+  +-----------v---------+  +----------+     |        |
|  |  | DNA/  |  | BlenKernel          |  | DepGraph |     |        |
|  |  | RNA   |  | (scene, objects,    |  | (eval    |     |        |
|  |  |       |  |  modifiers, anim)   |  |  order)  |     |        |
|  |  +-------+  +----+-------+--------+  +----------+     |        |
|  |                   |       |                            |        |
|  |  +----------------v-+  +--v-----------------+         |        |
|  |  | BMesh/Geometry   |  | Nodes/Functions    |         |        |
|  |  +------------------+  +--------------------+         |        |
|  |                                                        |        |
|  |  +---------------------------------------------+      |        |
|  |  | GPU Module (source/blender/gpu/)             |      |        |
|  |  | +-------------------+  +-------------------+ |      |        |
|  |  | | WebGPU Backend    |  | Dummy Backend     | |      |        |
|  |  | | (wgpu_backend.cc) |  | (fallback)        | |      |        |
|  |  | +-------------------+  +-------------------+ |      |        |
|  |  | Shader lang: GLSL -> WGSL via Tint/Naga     |      |        |
|  |  +---------------------------------------------+      |        |
|  |                                                        |        |
|  |  +---------------------------------------------+      |        |
|  |  | Draw Manager + Engines                       |      |        |
|  |  | EEVEE | Workbench | Overlay                  |      |        |
|  |  +---------------------------------------------+      |        |
|  |                                                        |        |
|  |  +---------------------------------------------+      |        |
|  |  | Cycles Renderer                              |      |        |
|  |  | +-------------------+  +-------------------+ |      |        |
|  |  | | CPU Device (WASM) |  | WebGPU Compute    | |      |        |
|  |  | | (fallback)        |  | Device (new)      | |      |        |
|  |  | +-------------------+  +-------------------+ |      |        |
|  |  +---------------------------------------------+      |        |
|  |                                                        |        |
|  |  +---------------------------------------------+      |        |
|  |  | Python (Pyodide)                             |      |        |
|  |  | bpy module -> RNA -> Blender internals       |      |        |
|  |  +---------------------------------------------+      |        |
|  +--------------------------------------------------------+        |
+------------------------------------------------------------------+
```

### Component Boundaries

| Component | Responsibility | Communicates With | Port Status |
|-----------|---------------|-------------------|-------------|
| **GHOST_SystemWeb** (new) | Browser window/input abstraction | Window Manager, GPU context | NEW: must implement |
| **GPU WebGPU Backend** (new) | WebGPU rendering via webgpu.h/emdawnwebgpu | Draw Manager, EEVEE, Workbench, Compositor | NEW: must implement |
| **Cycles WebGPU Device** (new) | Path tracing via WebGPU compute shaders | Cycles integrator, scene graph | NEW: must implement |
| **Emscripten FS Layer** | Virtual filesystem + persistence | blenloader, asset_system, io/* | CONFIG: Emscripten provides; configure OPFS mount |
| **Pyodide Bridge** (new) | Python scripting in browser | source/blender/python/* (bpy module) | NEW: integration layer |
| blenlib | Low-level utilities, math | All modules | UNCHANGED: pure C/C++, compiles as-is |
| makesdna/makesrna | Data types, reflection, Python API | blenkernel, editors, python | UNCHANGED: compiles as-is |
| blenkernel | Core engine (objects, animation, physics) | Everything | UNCHANGED: mostly pure C/C++ |
| depsgraph | Dependency tracking, evaluation | blenkernel, editors, render | UNCHANGED: pure C++ |
| bmesh | Mesh topology operations | blenkernel, editors, geometry | UNCHANGED: pure C |
| geometry | Curves, points, volumes | blenkernel, nodes | UNCHANGED: pure C++ |
| editors/* | 40+ editor UIs | windowmanager, blenkernel, gpu | UNCHANGED: use GPU abstraction |
| windowmanager | Event loop, operators, context | GHOST, editors, depsgraph | MINOR CHANGES: event loop must yield to browser |
| draw/ | Viewport rendering (EEVEE, Workbench) | GPU backend, blenkernel | UNCHANGED: uses GPU abstraction |
| nodes/functions | Geometry/shader nodes | blenkernel, geometry | UNCHANGED: pure C++ |
| compositor | Node-based compositing | GPU backend, draw | UNCHANGED: uses GPU abstraction |
| sequencer | Video editing | blenkernel, imbuf | UNCHANGED: pure C++ |
| blenloader | .blend file I/O | Emscripten FS, makesdna | UNCHANGED: reads from virtual FS |
| io/* (FBX, USD, OBJ...) | Import/export formats | Emscripten FS, blenkernel | UNCHANGED: reads from virtual FS |
| animrig | Animation, IK, armatures | blenkernel, iksolver, itasc | UNCHANGED: pure C/C++ |
| asset_system | Asset library management | Emscripten FS, blenkernel | MINOR: storage backend adaptation |
| simulation | Particles, cloth, rigid body | blenkernel, bullet, mantaflow | UNCHANGED: pure C/C++ |
| intern/guardedalloc | Memory allocator | All modules | UNCHANGED: compiles with Emscripten |
| intern/bullet2 | Physics engine | simulation, blenkernel | UNCHANGED: C/C++, known to compile to WASM |
| intern/mantaflow | Fluid dynamics | simulation | RISKY: large C++ library, needs testing |
| intern/opensubdiv | Subdivision surfaces | blenkernel, modifiers | RISKY: has GPU acceleration code |
| imbuf | Image buffer/format codecs | All image operations | MINOR: codec dependencies need Emscripten ports |
| blenfont | Font rendering | editors, UI | MINOR: FreeType dependency needs Emscripten port |
| blentranslation | i18n | editors | UNCHANGED: pure C |

---

## Platform Abstraction Layer: GHOST -> Browser Events

### Current GHOST Architecture

GHOST (Generic Handy Operating System Toolkit) is Blender's platform abstraction layer at `intern/ghost/`. It provides:

- `GHOST_ISystem` -- abstract interface for system operations (events, windows, display)
- `GHOST_IWindow` -- abstract window interface
- `GHOST_IContext` -- abstract GPU context interface

Existing implementations:
- `GHOST_SystemWin32` -- Windows
- `GHOST_SystemCocoa` -- macOS
- `GHOST_SystemX11` -- Linux X11
- `GHOST_SystemWayland` -- Linux Wayland
- `GHOST_SystemSDL` -- SDL2 fallback (closest analog to browser)
- `GHOST_SystemHeadless` -- No-display mode (reference for minimal implementation)

### GHOST_SystemWeb Strategy

Create `GHOST_SystemWeb` modeled after `GHOST_SystemSDL` (which is already an abstraction over an event library) and `GHOST_SystemHeadless` (which shows the minimal interface). The SDL backend at `intern/ghost/intern/GHOST_SystemSDL.hh` is 91 lines -- the interface is well-defined.

**Key mappings:**

| GHOST Concept | Browser Equivalent |
|---------------|-------------------|
| `createWindow()` | Create/configure `<canvas>` element |
| `processEvents()` | Drain queued DOM events (addEventListener on canvas) |
| `getMilliSeconds()` | `performance.now()` via Emscripten |
| `getCursorPosition()` | MouseEvent.clientX/Y relative to canvas |
| `setCursorPosition()` | Pointer Lock API (limited browser support) |
| `getModifierKeys()` | KeyboardEvent.ctrlKey/shiftKey/altKey state tracking |
| `getButtons()` | MouseEvent.buttons bitmask state tracking |
| `getClipboard()` | Clipboard API (navigator.clipboard.readText) |
| `putClipboard()` | Clipboard API (navigator.clipboard.writeText) |
| `getMainDisplayDimensions()` | `window.innerWidth/Height` or canvas dimensions |
| Timer events | `setTimeout`/`setInterval` via Emscripten |
| GPU context creation | WebGPU `navigator.gpu.requestAdapter()` |

**Critical event loop change:** Desktop Blender runs a blocking event loop (`while (running) { processEvents(); draw(); }`). Browsers require yielding to the event loop. The window manager's main loop in `source/blender/windowmanager/` must be restructured to use `emscripten_set_main_loop()` or `emscripten_request_animation_frame()`, making each iteration a callback. This is one of the most invasive changes to the core codebase.

**Implementation priority:**
1. Window creation (canvas setup)
2. Mouse events (click, move, scroll, drag)
3. Keyboard events (keydown/keyup with modifier tracking)
4. Timer system (for continuous animation playback)
5. Cursor shape changes (CSS cursor property)
6. Clipboard (async Clipboard API)
7. Drag-and-drop (file drops onto canvas)

---

## GPU Backend Architecture: WebGPU

### Current GPU Module Structure

Blender's GPU module at `source/blender/gpu/` has a clean backend abstraction:

```
gpu/
  GPU_*.hh          -- Public API headers (37 files)
  intern/           -- Backend-agnostic implementation
    gpu_backend.hh  -- Abstract GPUBackend base class
  opengl/           -- OpenGL backend (42 files)
  vulkan/           -- Vulkan backend (91 files, newest)
  metal/            -- Metal backend (52 files)
  dummy/            -- Null/dummy backend (5 files)
  shaders/          -- GLSL shaders (102 files) + BSL shaders (31 .bsl.hh files)
  shader_tool/      -- Shader preprocessing/cross-compilation tool
```

The `GPUBackend` abstract class (`gpu_backend.hh`) requires implementing ~20 virtual methods:
- `context_alloc()` -- GPU context from GHOST window/context
- `batch_alloc()`, `vertbuf_alloc()`, `indexbuf_alloc()` -- Geometry allocation
- `shader_alloc()` -- Shader compilation
- `texture_alloc()`, `framebuffer_alloc()` -- Render targets
- `uniformbuf_alloc()`, `storagebuf_alloc()` -- Buffer allocation
- `compute_dispatch()`, `compute_dispatch_indirect()` -- Compute shaders
- `render_begin()`, `render_end()`, `render_step()` -- Frame coordination

The `GPU_BACKEND_*` enum in `GPU_platform_backend_enum.h` currently has: NONE, OPENGL, METAL, VULKAN. A `GPU_BACKEND_WEBGPU` value must be added.

### WebGPU Backend Implementation Plan

Create `source/blender/gpu/webgpu/` following the Vulkan backend pattern (it is the newest and closest in API style to WebGPU):

| Vulkan File | WebGPU Equivalent | Purpose |
|-------------|-------------------|---------|
| `vk_backend.hh/cc` | `wgpu_backend.hh/cc` | Backend singleton, device init |
| `vk_context.hh/cc` | `wgpu_context.hh/cc` | Per-window GPU context |
| `vk_device.hh/cc` | `wgpu_device.hh/cc` | Device/adapter management |
| `vk_shader.hh/cc` | `wgpu_shader.hh/cc` | Shader module creation |
| `vk_texture.hh/cc` | `wgpu_texture.hh/cc` | Texture management |
| `vk_framebuffer.hh/cc` | `wgpu_framebuffer.hh/cc` | Render targets |
| `vk_buffer.hh/cc` | `wgpu_buffer.hh/cc` | GPU buffers |
| `vk_batch.hh/cc` | `wgpu_batch.hh/cc` | Draw call batching |
| `vk_pipeline_pool.hh/cc` | `wgpu_pipeline_pool.hh/cc` | Pipeline state caching |
| `vk_descriptor_set.hh/cc` | `wgpu_bind_group.hh/cc` | Resource binding (bind groups in WebGPU) |

**API layer:** Use emdawnwebgpu (Dawn's Emscripten WebGPU bindings) which provides `webgpu.h` and `webgpu_cpp.h`. This gives a C/C++ API that maps to the browser's WebGPU JavaScript API. emdawnwebgpu works in any browser supporting WebGPU, not just Chrome.

### Shader Translation Strategy

Blender currently has:
- **763 GLSL shader files** across the codebase
- **31 BSL (Blender Shader Language) files** -- a newer C++-like shader language with `[[attribute]]` annotations
- A **shader_tool** for preprocessing shaders

WebGPU uses WGSL (WebGPU Shading Language), not GLSL. Three options for translation:

1. **Tint (recommended):** Google's shader compiler (part of Dawn) can transpile SPIR-V to WGSL. The Vulkan backend already compiles GLSL to SPIR-V via glslang. Chain: GLSL -> SPIR-V (existing) -> WGSL (via Tint). This reuses the Vulkan shader compilation pipeline.

2. **Naga:** Mozilla's shader compiler (part of wgpu) can also transpile SPIR-V to WGSL. Alternative if Tint integration is problematic.

3. **BSL to WGSL direct:** Blender's new BSL shaders use C++ attributes (`[[compute]]`, `[[shared]]`, `[[push_constant]]`, `[[image]]`) that are already backend-agnostic. The shader_tool could be extended with a WGSL code generation backend. This is the long-term path but covers only 31/763+ shader files today.

**Recommendation:** Use SPIR-V -> WGSL via Tint for initial port (leverages existing Vulkan SPIR-V compilation). Extend BSL to WGSL for new shaders going forward.

### WebGPU Limitations to Address

| WebGPU Limit | Impact | Mitigation |
|-------------|--------|------------|
| Max storage buffer binding: 128MB default | Large scenes may exceed | Split large buffers, use multiple bind groups |
| Max binding groups: 4 | Fewer than Vulkan's typical 4-8 descriptor sets | Careful resource layout planning |
| Max compute invocations per workgroup: 256 | Affects compute shader design | Use workgroup size 64 (GPU-efficient default) |
| Max dispatch dimensions: 65535 per axis | Affects large compute dispatches | Tile/chunk large dispatches |
| No SPIR-V direct execution | Cannot use Vulkan shaders directly | Must transpile to WGSL |
| No ray tracing extensions (yet) | Cycles hardware RT unavailable | Software BVH traversal in compute shaders |

---

## Threading Model: pthreads -> Web Workers

### Current Threading in Blender

Blender uses pthreads extensively for:
- **Depsgraph evaluation** -- parallel evaluation of independent nodes
- **Modifier execution** -- multithreaded mesh operations
- **Cycles rendering** -- tile-based parallel rendering
- **UI responsiveness** -- background tasks on separate threads
- **Physics simulation** -- parallel constraint solving

### Emscripten pthreads Mapping

Emscripten maps pthreads to Web Workers using SharedArrayBuffer for shared memory. This is a stable, well-tested feature. Key requirements:

**Server headers required:**
```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

**Build flags:**
```
-pthread                          # Enable pthreads
-sPTHREAD_POOL_SIZE=N            # Pre-spawn N workers
-sPTHREAD_POOL_SIZE_STRICT=0     # Allow dynamic growth
-sALLOW_BLOCKING_ON_MAIN_THREAD=0  # Prevent main thread blocking
```

**Critical architectural constraint:** The main browser thread MUST NOT block (no `pthread_join()` from main, no blocking mutexes on main). Blender's event loop currently blocks waiting for events in some code paths. All blocking calls on the main thread must be converted to async patterns or moved to workers.

**Threading architecture for Blender Web:**

```
Main Thread (browser UI thread):
  - GHOST_SystemWeb event processing
  - Window Manager event dispatch
  - UI drawing (requestAnimationFrame callback)
  - MUST NEVER BLOCK

Worker Pool (Emscripten pthread pool):
  - Depsgraph evaluation
  - Modifier execution
  - Cycles tile rendering
  - Physics simulation
  - File I/O operations
  - Python script execution
```

**Worker pool sizing:** Pre-spawn 4-8 workers (`-sPTHREAD_POOL_SIZE=8`). Dynamic worker creation has ~100ms latency (worker script must load). For Cycles rendering, a larger pool improves throughput but increases memory.

**Synchronization:** All pthread primitives (mutex, condition variable, barrier, semaphore) map to `Atomics.wait()` / `Atomics.notify()` backed by SharedArrayBuffer. This is transparent to existing Blender code.

---

## Data Flow: .blend Files Through Browser Storage

### File System Architecture

```
User drops/selects file
        |
        v
Browser File API (File/Blob)
        |
        v
JavaScript bridge copies to Emscripten VFS
        |
        v
MEMFS (in-memory virtual filesystem)
        |
        v
blenloader reads via standard fopen/fread
        |
        v
DNA deserialization -> in-memory scene graph
        |
        v
Depsgraph built, viewport refreshes
        |
        v
[On save: MEMFS -> OPFS/IndexedDB persistence]
```

### Storage Backend Strategy

**Primary: MEMFS (Emscripten's in-memory FS)**
- All .blend file operations happen in memory
- Standard POSIX file API works transparently
- No latency for reads/writes once loaded

**Persistence: OPFS (Origin Private File System)**
- Provides actual file-like storage in the browser
- WasmFS supports OPFS as a mountable directory
- Synchronous access available via `createSyncAccessHandle()` in dedicated workers
- Performance: ~4ms latency per operation from worker threads

**Fallback: IDBFS (IndexedDB-backed FS)**
- For browsers without OPFS support
- Requires explicit `FS.syncfs()` calls to flush
- Higher latency but wider browser support

**Large file considerations:**
- .blend files can be multi-gigabyte
- WASM 32-bit address space limits total memory to 4GB
- With Memory64 (WASM 3.0, stable in Chrome 133+, Firefox 134+): theoretically unlimited but significant performance overhead (10-100% slower)
- **Recommendation:** Target WASM32 initially with 4GB limit. Accept that very large scenes (>2GB .blend) are out of scope for initial release. Evaluate Memory64 once performance stabilizes.

### Import/Export Flow

File import/export formats (FBX, USD, OBJ, STL, PLY, glTF) all go through `source/blender/io/` which uses standard file I/O. These work unchanged on the Emscripten virtual FS. The browser-side needs:

1. **File input:** `<input type="file">` or drag-and-drop -> copy to MEMFS
2. **File export:** MEMFS -> create Blob -> `URL.createObjectURL()` -> trigger download
3. **Project persistence:** Mount working directory on OPFS for auto-save

---

## Cycles Path Tracer: WebGPU Compute Device

### Current Cycles Device Architecture

Cycles at `intern/cycles/` has a pluggable device system:

```
intern/cycles/device/
  device.h     -- DeviceType enum, DeviceInfo, Device base class
  cpu/         -- CPU rendering (SSE/AVX, always available)
  cuda/        -- NVIDIA CUDA
  optix/       -- NVIDIA OptiX (hardware RT)
  hip/         -- AMD HIP
  hiprt/       -- AMD HIPRT (hardware RT)
  metal/       -- Apple Metal
  oneapi/      -- Intel oneAPI
  multi/       -- Multi-device orchestration
  dummy/       -- Null device
```

Each device implements:
- Memory allocation/transfer
- Kernel compilation/dispatch
- Queue management
- BVH construction

### WebGPU Compute Device Plan

Add `intern/cycles/device/webgpu/` implementing `Device` for WebGPU compute:

**What works:**
- WebGPU compute shaders for ray intersection, shading, integration
- Storage buffers for scene data (geometry, BVH, materials)
- Workgroup shared memory for tile-local accumulation

**What does not work:**
- No hardware ray tracing API in WebGPU (no equivalent of OptiX/MetalRT)
- Limited buffer sizes (128MB per binding by default)
- No native CUDA/HIP kernel execution

**Strategy:**
1. **Phase 1:** CPU-only Cycles rendering via WASM. The CPU device compiles to WASM and works (verified by other projects). Performance will be 3-10x slower than native but functional.
2. **Phase 2:** WebGPU compute shaders for Cycles kernels. Port the kernel code (in `intern/cycles/kernel/`) to WGSL compute shaders. This is a massive effort -- the kernel directory has hundreds of files of path tracing math.
3. **Phase 3:** Optimize with tile-based rendering, progressive display, and adaptive sampling tuned for WebGPU dispatch limits.

**Cycles kernel porting approach:**
- Cycles kernels are written in a subset of C++ that is already cross-compiled to CUDA/HIP/Metal
- They use a "mega-kernel" or "wavefront" approach depending on the device
- For WebGPU: use the wavefront approach (separate compute shaders for ray generation, intersection, shading, etc.)
- WGSL does not support recursion -- Cycles already uses iterative loops for this reason (GPU compatibility)

---

## Module-by-Module Portability Assessment

### Tier 1: Zero Changes Required (Pure C/C++)

These modules contain no platform-specific code and compile to WASM with Emscripten as-is:

| Module | Lines (approx) | Risk | Notes |
|--------|----------------|------|-------|
| blenlib | 50K+ | VERY LOW | Pure utilities, math, data structures |
| makesdna | 20K+ | VERY LOW | Type definitions, code generation tool |
| makesrna | 60K+ | VERY LOW | Reflection/API generation |
| blenkernel | 230K+ | LOW | Core engine; some thread-related code needs testing |
| depsgraph | 25K+ | LOW | Pure C++ graph algorithms |
| bmesh | 40K+ | VERY LOW | Mesh topology, pure C |
| geometry | 20K+ | VERY LOW | Geometry algorithms |
| nodes/functions | 50K+ | VERY LOW | Node evaluation, pure C++ |
| animrig | 15K+ | VERY LOW | Animation algorithms |
| modifiers | 30K+ | LOW | Procedural geometry; some use multithreading |
| blenloader/blenloader_core | 40K+ | LOW | File I/O via stdio; works on Emscripten VFS |
| sequencer | 15K+ | LOW | Timeline evaluation |
| simulation | 10K+ | LOW | Physics wrappers |
| blentranslation | 5K+ | VERY LOW | i18n strings |
| asset_system | 10K+ | LOW | File paths need virtual FS awareness |

### Tier 2: Minor Adaptation Required

| Module | Changes Needed | Risk |
|--------|---------------|------|
| windowmanager | Event loop must yield to browser (emscripten_set_main_loop). Blocking waits converted to async. | MEDIUM |
| editors/* | No direct changes, but event handling flow changes impact all editors | LOW-MEDIUM |
| compositor | Uses GPU backend; works if WebGPU backend is correct | LOW |
| draw/ (EEVEE, Workbench) | Uses GPU abstraction; no direct changes but shader availability matters | LOW |
| render/ | Integrates Cycles; CPU path works, WebGPU path new | MEDIUM |
| imbuf | Image format codecs (PNG, JPEG, EXR) need Emscripten-compiled libraries | MEDIUM |
| blenfont | FreeType dependency needs Emscripten port (available as emscripten-port) | LOW |
| io/* | Standard file I/O works; external library dependencies need checking | LOW-MEDIUM |

### Tier 3: Significant New Code Required

| Module | Work Required | Risk |
|--------|--------------|------|
| intern/ghost (GHOST_SystemWeb) | New 1000-2000 line GHOST implementation for browser | MEDIUM |
| source/blender/gpu/webgpu/ | New WebGPU backend (est. 15,000-25,000 lines based on Vulkan backend size) | HIGH |
| intern/cycles/device/webgpu/ | New Cycles WebGPU compute device + kernel WGSL translation | VERY HIGH |
| Python integration | Pyodide bridge for bpy module | HIGH |

### Tier 4: Requires External Library Porting/Assessment

| Library | Location | WASM Status | Risk |
|---------|----------|-------------|------|
| Bullet Physics | intern/bullet2, extern/bullet2 | Known to work with Emscripten | LOW |
| Mantaflow | intern/mantaflow | Large C++ library, untested in WASM | HIGH |
| OpenSubdiv | intern/opensubdiv | Has GPU code paths; CPU path should work | MEDIUM |
| OpenVDB | intern/openvdb | Very large C++ library; needs testing | HIGH |
| LibMV | intern/libmv | Motion tracking algorithms; should be pure C++ | MEDIUM |
| Eigen | intern/eigen | Header-only linear algebra; works with Emscripten | VERY LOW |
| Audaspace | extern/audaspace | Audio library; Web Audio API integration needed | HIGH |
| FFmpeg | (external dep) | Emscripten port exists but video codecs are limited | HIGH |
| OpenEXR | (external dep) | Emscripten port exists | MEDIUM |
| OpenImageIO | (external dep) | Complex dependency chain | HIGH |

---

## Suggested Build Order (Dependency Chain)

The port should proceed bottom-up through the dependency layers, with each phase producing a testable milestone:

### Phase 1: Foundation (Headless WASM Build)

**Goal:** Compile Blender core to WASM, verify it links and basic data structures work.

```
Build order:
1. blenlib (zero dependencies)
2. guardedalloc, memutil, clog (internal utilities)
3. makesdna + DNA code generation tool
4. makesrna (depends on makesdna, blenlib)
5. blenkernel (depends on all above + external libs)
6. depsgraph
7. bmesh, geometry
8. nodes, functions
9. modifiers, animrig
10. blenloader, blenloader_core
```

**External libs needed:** Compile Eigen, zlib, PNG, JPEG with Emscripten. Use CMake Emscripten toolchain file.

**Test:** Load a .blend file from MEMFS, query scene data via DNA API, verify data integrity.

### Phase 2: GHOST_SystemWeb + Dummy GPU (UI Frame Renders)

**Goal:** Blender window manager runs in browser, UI elements visible (even if viewport is blank).

```
Build order:
1. GHOST_SystemWeb implementation
2. GPU dummy backend adaptation for browser
3. windowmanager (with emscripten_set_main_loop)
4. editors/* (space_view3d, space_outliner, space_properties minimum)
5. blenfont (with FreeType Emscripten port)
6. imbuf (basic image format support)
```

**Test:** Blender UI renders in canvas. Panels, headers, buttons visible. Mouse/keyboard events processed. Viewport is empty (dummy GPU).

### Phase 3: WebGPU Backend (3D Viewport)

**Goal:** 3D viewport renders geometry with Workbench/solid shading.

```
Build order:
1. WebGPU backend core (device, context, buffers)
2. Shader translation pipeline (GLSL -> SPIR-V -> WGSL)
3. Texture, framebuffer, render target support
4. Draw manager integration
5. Workbench engine (simplest viewport engine)
6. Overlay engine (selection, wireframe, gizmos)
```

**Test:** Default cube visible in 3D viewport. Object selection works. Gizmos render.

### Phase 4: EEVEE + Core Editing

**Goal:** Real-time shaded viewport, basic modeling tools work.

```
Build order:
1. EEVEE engine with WebGPU backend
2. Material/shader node compilation to WGSL
3. Transform operators
4. Edit mode (mesh editing)
5. Modifier stack evaluation in viewport
```

**Test:** Materials display in viewport. Subdivision surface modifier works. User can model.

### Phase 5: Cycles (CPU-first) + Python

**Goal:** Final rendering works (CPU), scripting available.

```
Build order:
1. Cycles CPU device (compiles to WASM)
2. Pyodide integration for bpy
3. Python script execution
4. Pure-Python addon loading
```

**Test:** F12 render produces an image. Basic Python scripts execute.

### Phase 6: Advanced Features + Optimization

**Goal:** Full feature parity approach.

```
Build order:
1. Cycles WebGPU compute device
2. Physics simulation (Bullet, Mantaflow)
3. Compositor
4. Video sequencer
5. Geometry Nodes
6. Asset browser with OPFS storage
7. Memory optimization, progressive loading
8. Performance tuning
```

---

## Patterns to Follow

### Pattern 1: Backend Factory with Compile-Time Selection

**What:** Use `#ifdef __EMSCRIPTEN__` to select WebGPU backend at compile time, matching how Blender already selects backends.

**When:** GPU backend initialization, GHOST system creation, Cycles device registration.

**Example:**
```cpp
// In GPU_platform_backend_enum.h
enum GPUBackendType {
  GPU_BACKEND_NONE = 0,
  GPU_BACKEND_OPENGL = 1 << 0,
  GPU_BACKEND_METAL = 1 << 1,
  GPU_BACKEND_VULKAN = 1 << 3,
  GPU_BACKEND_WEBGPU = 1 << 4,  // NEW
  GPU_BACKEND_ANY = 0xFFFFFFFFu
};
```

### Pattern 2: Async Main Loop with emscripten_set_main_loop

**What:** Replace blocking event loop with callback-driven loop.

**When:** Window manager initialization.

**Example:**
```cpp
// Instead of:
// while (running) { wm_event_do_handlers(); wm_draw_update(); }
// Use:
#ifdef __EMSCRIPTEN__
emscripten_set_main_loop_arg(wm_main_loop_iteration, wm_context, 0, true);
#else
while (running) { wm_main_loop_iteration(wm_context); }
#endif
```

### Pattern 3: File Bridge via Emscripten FS Mount

**What:** Mount OPFS at `/persistent/` in the Emscripten virtual filesystem. Use MEMFS for working files, sync to OPFS on save.

**When:** Application startup, file save/load operations.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Trying to Run OpenGL via Emscripten's GL Emulation

**What:** Emscripten can translate OpenGL ES 2.0/3.0 to WebGL, which might seem like a shortcut.

**Why bad:** Blender uses OpenGL 3.3+ core profile features extensively. Emscripten's GL emulation targets ES 2.0/3.0 only. Desktop OpenGL features (geometry shaders, tessellation, compute shaders, SSBO, multi-draw indirect) are not available via WebGL 2. Early attempts at Blender WASM confirmed this: "The GFX stack in blender is highly reliant on OpenGL 3.x, the browser offers only OpenGL ES." This path leads to a dead end.

**Instead:** Implement a proper WebGPU backend. WebGPU provides compute shaders, storage buffers, and modern GPU features that Blender needs.

### Anti-Pattern 2: Blocking the Main Thread

**What:** Calling `pthread_join()`, blocking mutex locks, or synchronous file I/O on the browser's main thread.

**Why bad:** The browser will freeze. The page becomes unresponsive. Chrome may show "page unresponsive" dialog.

**Instead:** Use `-sALLOW_BLOCKING_ON_MAIN_THREAD=0` build flag. Move all blocking operations to worker threads. Use `Atomics.waitAsync()` for main-thread synchronization.

### Anti-Pattern 3: Assuming 4GB Is Enough

**What:** Proceeding without a memory management strategy because "4GB should be enough."

**Why bad:** Blender complex scenes regularly exceed 4GB. Undo history, evaluated geometry caches, texture data, and render buffers consume memory rapidly. The WASM32 4GB hard limit will be hit.

**Instead:** Implement aggressive memory management from the start: LRU caches for textures, streaming geometry evaluation, compressed undo (delta-based), and texture LOD. Consider Memory64 as a future option but accept the 10-100% performance penalty.

### Anti-Pattern 4: Porting All Shaders at Once

**What:** Attempting to translate all 763 GLSL shaders to WGSL before any rendering works.

**Why bad:** Months of work before any visual feedback. High risk of subtle translation bugs that are hard to debug without a working viewport.

**Instead:** Port shaders incrementally: Workbench solid shading first (~30 shaders), then overlays, then EEVEE. Use the SPIR-V -> WGSL pipeline (via Tint) to automate most translation. Fix shader-specific issues as they appear in the viewport.

---

## Scalability Considerations

| Concern | Light Usage (Simple Scenes) | Medium Usage (Standard Scenes) | Heavy Usage (Complex Scenes) |
|---------|----------------------------|-------------------------------|------------------------------|
| Memory | <500MB WASM heap; comfortable | 1-2GB; monitor carefully | >2GB; approaching 4GB WASM32 limit |
| GPU Memory | Browser manages; ~256MB textures | ~1GB textures + framebuffers | May exceed WebGPU adapter limits |
| Thread Count | 4 workers sufficient | 8 workers optimal | 8-16 workers; diminishing returns |
| .blend File Size | <50MB; instant load to MEMFS | 50-500MB; few seconds to copy | >500MB; needs progress indicator, streaming |
| Shader Compilation | Cached after first compile | May stall on first scene load | Hundreds of shader variants; needs async compilation |
| Render Time (Cycles CPU) | 3-10x slower than native | Significant wait; progressive display essential | May be impractical; WebGPU compute mandatory |

---

## Sources

### Official Documentation (HIGH confidence)
- [Emscripten pthreads documentation](https://emscripten.org/docs/porting/pthreads.html)
- [Emscripten File System API](https://emscripten.org/docs/api_reference/Filesystem-API.html)
- [Emscripten OpenGL support](https://emscripten.org/docs/porting/multimedia_and_graphics/OpenGL-support.html)
- [emdawnwebgpu README](https://dawn.googlesource.com/dawn/+/refs/heads/main/src/emdawnwebgpu/pkg/README.md)
- [webgpu-native/webgpu-headers](https://github.com/webgpu-native/webgpu-headers)
- [WebGPU W3C Spec](https://www.w3.org/TR/webgpu/)
- [Pyodide WASM constraints](https://pyodide.org/en/stable/usage/wasm-constraints.html)

### Technical References (MEDIUM confidence)
- [Chrome WebGPU Build an App guide](https://developer.chrome.com/docs/web-platform/webgpu/build-app)
- [Blender Vulkan Backend Developer Documentation](https://developer.blender.org/docs/features/gpu/vulkan/)
- [Wasm64 announcement](https://unlimited3d.wordpress.com/2025/02/07/wasm64-is-here/)
- [Wasm 3.0 completion (Memory64 finalized)](https://webassembly.org/news/2025-09-17-wasm-3.0/)
- [WebGPU shader limits](https://hugodaniel.com/posts/webgpu-shader-limits/)
- [WebGPU compute shader basics](https://webgpufundamentals.org/webgpu/lessons/webgpu-compute-shaders.html)

### Community/Prior Art (LOW-MEDIUM confidence)
- [Blender DevTalk: Building headless blender to WebAssembly](https://devtalk.blender.org/t/building-headless-blender-to-webassembly/18381)
- [Godot Web export documentation](https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_web.html)
- [WebGPU path tracer projects](https://github.com/gnikoloff/webgpu-raytracer)
- [Learn WebGPU for C++](https://eliemichel.github.io/LearnWebGPU/getting-started/hello-webgpu.html)
- [SDL Emscripten multiple windows PR](https://github.com/libsdl-org/SDL/pull/12575)
- [wasm_webgpu Emscripten bindings](https://github.com/juj/wasm_webgpu)

### Blender Source Analysis (HIGH confidence)
- `source/blender/gpu/intern/gpu_backend.hh` -- GPUBackend abstract interface
- `source/blender/gpu/GPU_platform_backend_enum.h` -- Backend type enum
- `source/blender/gpu/vulkan/vk_backend.hh` -- Reference Vulkan implementation
- `intern/ghost/intern/GHOST_System.hh` -- GHOST base class
- `intern/ghost/intern/GHOST_SystemSDL.hh` -- SDL backend (closest analog)
- `intern/ghost/intern/GHOST_SystemHeadless.hh` -- Headless backend (minimal reference)
- `intern/cycles/device/device.h` -- Cycles device type system

---

*Architecture analysis: 2026-04-01*
