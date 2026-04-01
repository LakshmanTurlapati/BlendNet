# Feature Landscape: Blender Web (WASM/WebGPU Port)

**Domain:** Full-featured 3D creation suite ported to the web browser
**Researched:** 2026-04-01
**Overall Confidence:** MEDIUM -- based on WebGPU spec, Emscripten docs, Pyodide docs, and community reports

---

## Table Stakes

Features users expect from a usable 3D editor in the browser. Missing any of these and the product is not "Blender in a browser" -- it is a toy demo.

### 1. 3D Viewport with Navigation

| Attribute | Detail |
|-----------|--------|
| **Portability** | Moderate |
| **Complexity** | Moderate |
| **Browser APIs** | WebGPU (primary), WebGL2 (fallback), PointerLock API, Wheel events |
| **Key Challenge** | Blender's viewport uses the Draw Manager (`source/blender/draw`) with OpenGL/Vulkan/Metal backends. Entire GPU backend must be replaced with WebGPU via emdawnwebgpu or a custom webgpu.h implementation. The Draw Manager issues thousands of draw calls per frame with complex state management. |
| **Dependencies** | GPU abstraction layer (`source/blender/gpu`), Draw Manager, GHOST replacement for input |
| **Assessment** | The viewport is the single most critical feature. Blender's `gpu` module already has a backend abstraction (OpenGL, Vulkan, Metal) -- adding a WebGPU backend follows the same pattern. Orbit/pan/zoom are pure math + input events, straightforward to map. The hard part is shader translation: all GLSL shaders must be converted to WGSL, and WebGPU's binding model (4 bind groups max, 16 sampled textures per stage) is more restrictive than desktop OpenGL. |

### 2. Mesh Modeling (Edit Mode)

| Attribute | Detail |
|-----------|--------|
| **Portability** | Easy-Moderate |
| **Complexity** | Low-Moderate |
| **Browser APIs** | SharedArrayBuffer (threading for large meshes), WebGPU (GPU overlay drawing) |
| **Key Challenge** | BMesh (`source/blender/bmesh`) is pure C with no platform dependencies -- it will compile to WASM cleanly. The operators in `source/blender/editors/mesh` are CPU-bound and portable. Memory pressure is the concern: editing high-poly meshes in the 4GB WASM address space. |
| **Dependencies** | BMesh, blenkernel, GPU overlays for selection display |
| **Assessment** | Core modeling is one of the most portable features. BMesh is a self-contained topology library. Edit mode tools (extrude, bevel, knife, loop cut) are CPU math. Memory64 (available in Chrome 133+, Firefox 134+, not Safari) extends to 16GB but with a 10-100% performance penalty. For MVP, target 4GB with aggressive mesh LOD. |

### 3. Modifier Stack

| Attribute | Detail |
|-----------|--------|
| **Portability** | Moderate |
| **Complexity** | Moderate |
| **Browser APIs** | SharedArrayBuffer (parallel modifier evaluation), WASM SIMD |
| **Key Challenge** | Most modifiers are CPU-based C code and will compile to WASM. Exceptions: Boolean modifier uses GMP (GNU Multiple Precision) for exact arithmetic -- GMP has Emscripten compatibility issues due to assembly optimizations. Subdivision Surface uses OpenSubdiv which has GPU compute paths that need WebGPU adaptation. |
| **Dependencies** | blenkernel modifier system, OpenSubdiv (subdivision), GMP/Manifold (booleans), depsgraph |
| **Assessment** | The modifier stack is Blender's backbone. ~80% of modifiers are pure CPU math (Array, Mirror, Solidify, Decimate, Smooth, etc.) and port cleanly. OpenSubdiv's CPU evaluator works; its GPU evaluator needs a WebGPU compute path. The Manifold library (fast robust booleans, replacing GMP) is pure C++ without assembly -- prefer it over GMP for the web build. |

### 4. Material and Shader System (Node Editor)

| Attribute | Detail |
|-----------|--------|
| **Portability** | Hard |
| **Complexity** | High |
| **Browser APIs** | WebGPU (shader compilation), WebGPU compute (texture baking) |
| **Key Challenge** | Blender's shader node system compiles node graphs to GLSL/MSL/HLSL at render time. For web, it must compile to WGSL. WGSL has no preprocessor, no recursion, requires explicit typing, and has a monolithic shader model (no module linking -- see gpuweb issue #5456). Blender's shader compiler generates very complex shaders that may exceed WebGPU implementation limits. |
| **Dependencies** | Node system (`source/blender/nodes`), GPU shader compilation, EEVEE/Cycles material pipelines |
| **Assessment** | The node editor UI itself is portable (it is a standard Blender editor widget). The challenge is the shader compilation backend. Every Blender shader node type needs a WGSL code generation path. WGSL's 16-texture-per-stage limit and 4-bind-group limit will require texture atlasing and bindless workarounds. Expect significant engineering effort but no fundamental blockers. |

### 5. EEVEE Real-Time Renderer

| Attribute | Detail |
|-----------|--------|
| **Portability** | Hard |
| **Complexity** | High |
| **Browser APIs** | WebGPU (render pipelines, compute shaders), WebGPU texture formats (Tier 1/2) |
| **Key Challenge** | EEVEE Next (Blender 4.x) is a full deferred renderer with screen-space effects (SSR, SSAO, volumetrics, motion blur). It uses compute shaders extensively. All rendering passes must work within WebGPU's constraints: max 8192x8192 textures, limited read-write storage textures, no async compute, 4 bind groups per pipeline. |
| **Dependencies** | Draw Manager, GPU abstraction, shader compilation to WGSL, material system |
| **Assessment** | EEVEE is the primary viewport renderer and non-negotiable for a usable product. The good news: WebGPU was designed for this class of rendering. The challenge is scale -- EEVEE has dozens of render passes, hundreds of shaders, and complex GPU memory management. This is the single largest engineering effort in the port but is architecturally feasible. No fundamental WebGPU limitation blocks EEVEE -- just volume of work. |

### 6. Basic Animation System

| Attribute | Detail |
|-----------|--------|
| **Portability** | Easy |
| **Complexity** | Low |
| **Browser APIs** | requestAnimationFrame (playback timing), SharedArrayBuffer (parallel evaluation) |
| **Key Challenge** | Keyframes, F-curves, timeline, and graph editor are CPU-based C code with no platform dependencies. Dope Sheet and Graph Editor are standard Blender editor widgets. The evaluation pipeline runs through depsgraph which is also pure C/C++. |
| **Dependencies** | blenkernel animation, depsgraph, editor widgets |
| **Assessment** | Animation data structures and evaluation are among the most portable parts of Blender. The timeline, dope sheet, and graph editor are standard 2D widgets that render through the GPU abstraction layer. Playback timing needs careful mapping to browser's requestAnimationFrame but this is a solved problem. |

### 7. Armatures and Rigging (IK/FK)

| Attribute | Detail |
|-----------|--------|
| **Portability** | Easy-Moderate |
| **Complexity** | Low-Moderate |
| **Browser APIs** | WASM SIMD (matrix math acceleration) |
| **Key Challenge** | IK solvers (`intern/iksolver`, `intern/itasc`) are pure C/C++ math. Armature evaluation in blenkernel is CPU-bound. The iTaSC solver uses Eigen-like linear algebra -- portable. Constraint system is also pure C. |
| **Dependencies** | blenkernel armature, IK solvers, constraint system, depsgraph |
| **Assessment** | Rigging and armatures are fully portable. The math-heavy IK solvers benefit from WASM SIMD instructions. No GPU or platform API dependencies. |

### 8. Undo/Redo System

| Attribute | Detail |
|-----------|--------|
| **Portability** | Easy |
| **Complexity** | Low |
| **Browser APIs** | None (pure memory operations) |
| **Key Challenge** | Blender's undo system stores full DNA state snapshots. In a 4GB WASM environment, undo history will consume significant memory. May need to limit undo steps or implement differential undo. |
| **Dependencies** | blenkernel undo, DNA serialization |
| **Assessment** | Fully portable but memory-constrained. The undo system works by memcpy of data blocks -- no platform dependencies. Memory pressure is the only concern. |

### 9. File I/O (.blend Read/Write)

| Attribute | Detail |
|-----------|--------|
| **Portability** | Moderate |
| **Complexity** | Moderate |
| **Browser APIs** | OPFS (Origin Private File System), File System Access API, IndexedDB, Emscripten VFS |
| **Key Challenge** | Blender's .blend reader/writer (`source/blender/blenloader`) uses direct file I/O (fopen/fread/fwrite). Emscripten's VFS (MEMFS, IDBFS) maps these calls. The real challenge is persistence: OPFS supports large files (300MB+, 3-4x faster than IndexedDB) but synchronous access requires Web Workers. Complex .blend files can exceed available storage quotas. |
| **Dependencies** | blenloader, Emscripten VFS, browser storage APIs |
| **Assessment** | The .blend format itself is self-contained and portable. File I/O maps cleanly to Emscripten's virtual filesystem. For user-facing open/save, use the File System Access API (Chrome/Edge) or fallback to download/upload. OPFS provides persistent project storage. Large files (500MB+) need chunked read/write strategies. |

### 10. UI Framework (Window Manager, Editors, Panels)

| Attribute | Detail |
|-----------|--------|
| **Portability** | Moderate |
| **Complexity** | High |
| **Browser APIs** | Canvas API, PointerLock, Clipboard API, Drag and Drop API, keyboard/mouse events |
| **Key Challenge** | Blender renders its own UI entirely through its GPU abstraction layer -- it does NOT use native OS widgets. This is actually an advantage for web porting: the UI renders the same way as the 3D viewport. The GHOST layer (`intern/ghost`) provides platform abstraction for window management, input, and clipboard -- this needs a complete browser implementation. The 12,926-line `wm_event_system.cc` is a complexity hotspot. |
| **Dependencies** | GHOST (needs browser backend), windowmanager, all editor implementations, GPU drawing |
| **Assessment** | Blender's self-drawn UI is a major advantage -- no native widget translation needed. The GHOST layer is the primary abstraction point: replace GHOST's X11/Cocoa/Win32 backends with a browser backend using Canvas + DOM events. Input mapping (mouse, keyboard, tablet pressure via Pointer Events) is straightforward. Multi-window support is blocked (browsers cannot spawn OS windows) but workspaces within a single canvas work. |

---

## Differentiators

Features that make this "Blender in a browser" rather than "a web-based 3D editor." Not expected from a generic web 3D tool, but expected from Blender specifically.

### 11. Cycles Path-Tracing Renderer

| Attribute | Detail |
|-----------|--------|
| **Portability** | Very Hard |
| **Complexity** | Very High |
| **Browser APIs** | WebGPU compute shaders (mandatory), Memory64 (for large scenes), SharedArrayBuffer |
| **Key Challenge** | Cycles is a production path tracer with CUDA/OptiX/HIP/Metal/oneAPI device backends. None of these are available in browsers. Cycles must use a **WebGPU compute shader backend**. There is no official WebGPU ray tracing extension -- hardware RT acceleration is not available (gpuweb issue #535 remains open with no timeline). Cycles would run as a **software path tracer on GPU compute shaders** using BVH traversal in WGSL. This is fundamentally slower than hardware RT but feasible. |
| **Dependencies** | Cycles kernel, WebGPU compute, WGSL shader compilation, scene data transfer to GPU |
| **Assessment** | The Cycles kernel is a self-contained ray tracing engine with existing abstraction for multiple backends. Adding a WebGPU compute backend follows the pattern of existing backends. The core challenge is performance: without hardware RT (OptiX/DXR), Cycles must do BVH traversal in software via compute shaders. Expect 5-20x slower than native GPU rendering. Viable for preview rendering; final production renders will be slow but functional. NanoVDB for volumetrics has been partially prototyped on WebGPU but WGSL's lack of 64-bit types complicates it. |

### 12. Geometry Nodes

| Attribute | Detail |
|-----------|--------|
| **Portability** | Moderate |
| **Complexity** | Moderate-High |
| **Browser APIs** | SharedArrayBuffer (parallel node evaluation), WASM SIMD, WebGPU compute (future) |
| **Key Challenge** | Geometry Nodes (`source/blender/nodes`) evaluates procedural geometry through a lazy evaluation system. The node evaluation is CPU-based C++ using the functions framework (`source/blender/functions`). Most node types are pure math/geometry operations. Memory is the primary constraint: complex Geometry Nodes setups generate massive intermediate geometry data. |
| **Dependencies** | Node system, functions framework, geometry module, depsgraph, modifier stack |
| **Assessment** | Geometry Nodes is one of Blender's most powerful differentiators. The evaluation engine is pure C++ and compiles to WASM cleanly. Individual node implementations are CPU math. The challenge is memory and performance: complex node trees in WASM will be slower than native and memory-constrained. Optimization: consider WebGPU compute acceleration for heavy nodes (distribute points, mesh booleans) in a later phase. |

### 13. Sculpting Tools

| Attribute | Detail |
|-----------|--------|
| **Portability** | Moderate |
| **Complexity** | Moderate |
| **Browser APIs** | Pointer Events (pressure sensitivity), SharedArrayBuffer (multimesh updates), WebGPU (GPU-accelerated sculpt display) |
| **Key Challenge** | Sculpting (`source/blender/editors/sculpt_paint`) is CPU-intensive, operating on millions of vertices in real-time. Blender uses PBVH (Paint/Sculpt BVH) for spatial partitioning. The sculpt tools themselves are portable C++ but rely heavily on threading for performance. Tablet pressure support maps to Pointer Events' pressure property. |
| **Dependencies** | BMesh/PBVH, editors/sculpt_paint, threading (pthreads via Emscripten), GPU overlay |
| **Assessment** | Sculpting at desktop-quality resolution requires aggressive multithreading and SIMD optimization. With Emscripten pthreads mapped to Web Workers, basic sculpting is feasible. High-res sculpting (1M+ vertices) will be noticeably slower due to WASM overhead and memory constraints. Dynamic topology (dyntopo) sculpting adds memory pressure. Target 500K-1M polys for comfortable interactive sculpting vs. 10M+ on desktop. |

### 14. Python Scripting (bpy)

| Attribute | Detail |
|-----------|--------|
| **Portability** | Hard |
| **Complexity** | High |
| **Browser APIs** | None directly (Pyodide/CPython-WASM is the bridge) |
| **Key Challenge** | Blender's Python API (`bpy`) is deeply integrated -- it powers addons, operators, the RNA system, and user automation. Pyodide (CPython compiled to WASM) is the most viable approach. Critical limitations: (1) Pyodide does NOT support threading or multiprocessing -- the threading and multiprocessing modules are non-functional. (2) C-extension packages (NumPy compiled for native) won't work; must use Pyodide's pre-compiled packages. (3) `bpy` itself is a C extension that needs compilation against the WASM Blender build. (4) Initial load time for Pyodide is 5-15 seconds. |
| **Dependencies** | Pyodide or CPython-WASM, makesrna (Python API bindings), all bpy submodules |
| **Assessment** | Python scripting is central to Blender's identity. The approach: compile CPython alongside Blender via Emscripten (as Pyodide does) and link bpy as a native WASM module. Pure-Python addons will work. C-extension addons will NOT work unless pre-compiled for WASM. NumPy is available via Pyodide's pre-built wheels. The lack of threading means background scripts cannot run in parallel with the UI -- all Python execution blocks. This is a significant behavioral change from desktop Blender. |

### 15. Full Modifier Stack (Advanced Modifiers)

| Attribute | Detail |
|-----------|--------|
| **Portability** | Moderate-Hard |
| **Complexity** | Moderate-High |
| **Browser APIs** | WebGPU compute (OpenSubdiv GPU), SharedArrayBuffer |
| **Key Challenge** | Beyond basic modifiers (covered in Table Stakes), advanced modifiers have specific dependencies: Subdivision Surface needs OpenSubdiv (CPU evaluator ports, GPU evaluator needs WebGPU compute). Ocean modifier uses FFTW3 which is pure C and should compile. Fluid/cloth/softbody modifiers depend on simulation systems (see Physics below). Particle system modifier is legacy but CPU-portable. |
| **Dependencies** | OpenSubdiv, GMP/Manifold, simulation systems, geometry nodes (for GN modifier) |
| **Assessment** | Each modifier has individual portability characteristics. Create a modifier compatibility matrix during implementation. Priority: Subdivision Surface, Array, Mirror, Boolean, Solidify, Bevel, Decimate -- these cover 90% of production use. |

### 16. Compositing Node System

| Attribute | Detail |
|-----------|--------|
| **Portability** | Moderate |
| **Complexity** | Moderate |
| **Browser APIs** | WebGPU compute (GPU compositing), SharedArrayBuffer |
| **Key Challenge** | Blender's compositor (`source/blender/compositor`) has both CPU and GPU execution paths. The GPU compositor generates shader code and executes through the GPU abstraction. For web: the CPU path compiles to WASM directly; the GPU path needs WGSL shader generation. Image buffers for compositing can be large (4K+ renders = 32MB+ per buffer). |
| **Dependencies** | Compositor nodes, GPU abstraction, imbuf (image buffer), render pipeline |
| **Assessment** | The compositor is architecturally well-suited for porting. The CPU path is portable. The GPU path follows the same WGSL conversion pattern as EEVEE shaders. Memory management of large image buffers within WASM is the practical concern. |

### 17. NLA (Non-Linear Animation) Editor

| Attribute | Detail |
|-----------|--------|
| **Portability** | Easy |
| **Complexity** | Low |
| **Browser APIs** | None beyond viewport rendering |
| **Key Challenge** | NLA evaluation is pure C in blenkernel. The editor UI is a standard Blender widget. No platform dependencies. |
| **Dependencies** | blenkernel NLA, animation system, depsgraph |
| **Assessment** | Fully portable, minimal effort. |

### 18. Grease Pencil (2D Animation)

| Attribute | Detail |
|-----------|--------|
| **Portability** | Moderate |
| **Complexity** | Moderate |
| **Browser APIs** | Pointer Events (pressure, tilt for drawing), WebGPU (stroke rendering) |
| **Key Challenge** | Grease Pencil v3 (Blender 4.x) stores strokes as geometry. The drawing tools need pressure/tilt from Pointer Events. Stroke rendering uses custom GPU shaders that need WGSL conversion. The onion skinning system (showing previous/next frames) is GPU-intensive. |
| **Dependencies** | Grease Pencil data, editors/gpencil, GPU shader compilation, Pointer Events |
| **Assessment** | Grease Pencil is a strong differentiator -- few web 3D editors offer 2D animation tools. The data model is portable. Drawing input maps well to Pointer Events. Shader conversion is the primary technical task. |

### 19. Asset Browser

| Attribute | Detail |
|-----------|--------|
| **Portability** | Moderate |
| **Complexity** | Moderate |
| **Browser APIs** | OPFS, IndexedDB, File System Access API, potentially Fetch API for remote assets |
| **Key Challenge** | Blender's asset system (`source/blender/asset_system`) manages catalogs and metadata for reusable assets. On desktop it reads from local directories. On web, it needs browser storage backends. A significant opportunity: connect to cloud asset libraries via Fetch API, which desktop Blender cannot do natively. |
| **Dependencies** | Asset system, blenloader (for reading asset .blend files), file browser, storage APIs |
| **Assessment** | The asset browser is an area where the web version can actually **improve** on desktop. Cloud-hosted asset libraries, shared team catalogs via URLs, and drag-and-drop from web sources are natural web advantages. The core asset metadata system is portable C++. |

---

## Features Requiring Significant Adaptation

These features are portable in principle but need substantial rearchitecting to work within browser constraints.

### 20. Physics Simulation (Rigid Body, Cloth, Fluid)

| Attribute | Detail |
|-----------|--------|
| **Portability** | Moderate-Hard |
| **Complexity** | High |
| **Browser APIs** | SharedArrayBuffer (parallel simulation), WebGPU compute (future GPU solver) |
| **Key Challenge** | Three distinct simulation systems: (1) **Rigid Body** uses Bullet Physics -- already proven portable via ammo.js (Emscripten port). Optimized WASM Bullet achieves up to 9.88x speedup over ammo.js per IEEE research (2025). (2) **Cloth/Softbody** -- CPU-based solver in blenkernel, portable but slow without threading. (3) **Fluid (Mantaflow)** -- C++ framework with Python scene interface. Mantaflow is the hardest: it is memory-intensive, uses deep Python integration, and produces large cache files. Fluid baking could consume entire 4GB WASM address space for moderate resolution. |
| **Dependencies** | Bullet (`extern/bullet2`), Mantaflow (`extern/mantaflow`), blenkernel physics |
| **Assessment** | Rigid body: feasible, proven via ammo.js. Cloth: feasible but slower. Fluid (Mantaflow): feasible to compile but severely memory-limited. Recommend limiting fluid resolution in web builds. Simulation baking (pre-computing frames) needs OPFS for cache storage. Real-time fluid preview at desktop quality is unlikely -- lower resolution is acceptable for web. |

### 21. Video Sequence Editor (VSE)

| Attribute | Detail |
|-----------|--------|
| **Portability** | Hard |
| **Complexity** | High |
| **Browser APIs** | WebCodecs API (hardware video decode/encode), ffmpeg.wasm, Web Audio API, OPFS |
| **Key Challenge** | Blender's VSE depends on FFmpeg for all video codec support. FFmpeg has been ported to WASM (ffmpeg.wasm) but with limitations: single-threaded performance is poor for real-time playback; multi-threaded ffmpeg.wasm helps. WebCodecs API provides hardware-accelerated decode/encode but only for specific codecs (H.264, VP9, AV1). The VSE also uses Audaspace for audio, which depends on libsndfile and optionally FFTW3. |
| **Dependencies** | FFmpeg/ffmpeg.wasm or WebCodecs, Audaspace, sequencer module, render pipeline |
| **Assessment** | A hybrid approach is needed: use WebCodecs for hardware-accelerated H.264/VP9 decode (near-native performance), fall back to ffmpeg.wasm for exotic formats. Encoding final output: WebCodecs for H.264/VP9, ffmpeg.wasm for ProRes/DNxHD. Audio processing via Web Audio API has limitations (no SharedArrayBuffer, Float32 only, no Worker support for AudioContext). This is a "works but compromised" feature area. |

### 22. Import/Export Formats

| Attribute | Detail |
|-----------|--------|
| **Portability** | Moderate |
| **Complexity** | Moderate |
| **Browser APIs** | File System Access API (user file selection), OPFS (temp storage), Fetch API (URL imports) |
| **Key Challenge** | Blender supports many formats via `source/blender/io`: OBJ, PLY, STL, glTF, FBX (via ufbx), USD, Alembic. Most format readers/writers are C/C++ and compile to WASM. The external libraries (tinygltf, ufbx, Alembic, USD) vary in portability. USD is the most complex -- it has deep dependencies on TBB, Boost, and other heavy C++ libraries. |
| **Dependencies** | io module, format-specific libraries, file system access |
| **Assessment** | Priority formats for web: glTF (web-native, tinygltf is portable), OBJ/PLY/STL (simple C parsers, trivially portable), FBX (ufbx is single-header C, portable). USD and Alembic are lower priority due to dependency complexity. A web-specific advantage: direct glTF import from URLs, drag-and-drop from web pages. |

### 23. Texture Painting

| Attribute | Detail |
|-----------|--------|
| **Portability** | Moderate |
| **Complexity** | Moderate |
| **Browser APIs** | Pointer Events (pressure), WebGPU (texture updates), OPFS (texture storage) |
| **Key Challenge** | Texture painting operates on image buffers. Blender's image editor and texture paint mode are CPU-based with GPU display. The painting itself is portable. Large textures (4K, 8K) consume significant memory. WebGPU's max 2D texture dimension of 8192 matches common production needs. |
| **Dependencies** | imbuf (image buffers), editors/sculpt_paint, GPU texture upload |
| **Assessment** | Texture painting is feasible within WebGPU's texture limits. 8K textures (8192x8192) are supported by WebGPU's default limits. Memory for multiple texture layers in the 4GB space is the practical constraint. |

---

## Blocked or Severely Limited Features

Features that cannot work at all or are so degraded as to be impractical due to fundamental browser sandbox restrictions.

### 24. CUDA/OptiX/HIP/Metal/oneAPI GPU Backends

| Attribute | Detail |
|-----------|--------|
| **Status** | BLOCKED |
| **Reason** | Browser sandbox provides NO access to vendor-specific GPU APIs. WebGPU is the only GPU API available. |
| **Impact** | Cycles cannot use hardware ray tracing (OptiX/DXR). All GPU rendering must go through WebGPU compute shaders. This means software BVH traversal instead of hardware RT cores. |
| **Mitigation** | WebGPU compute shader path for Cycles. Accept 5-20x slower rendering than native OptiX. When/if WebGPU ray tracing extension ships, it could close this gap significantly -- but no timeline exists (gpuweb issue #535). |

### 25. Multi-Process Architecture

| Attribute | Detail |
|-----------|--------|
| **Status** | BLOCKED |
| **Reason** | Browsers cannot spawn OS processes. Web Workers are threads, not processes. |
| **Impact** | Blender's background rendering (separate process) is not possible. Crash recovery via separate watchdog process is not possible. |
| **Mitigation** | Use Web Workers for background tasks (rendering in a worker thread). Implement periodic auto-save to OPFS for crash recovery. Service Workers for offline support. |

### 26. Native File System Access (Direct Read/Write)

| Attribute | Detail |
|-----------|--------|
| **Status** | SEVERELY LIMITED |
| **Reason** | Browser sandbox prevents direct filesystem access. File System Access API provides user-gated access in Chrome/Edge but not Firefox/Safari. |
| **Impact** | Cannot browse local directories, auto-discover textures by relative path, or maintain persistent file references across sessions. Linked library workflows broken. |
| **Mitigation** | OPFS for project storage (up to several GB, 3-4x faster than IndexedDB). File System Access API where available. Upload/download fallback everywhere. "Import project" workflow that bundles all assets into OPFS. |

### 27. Multi-Window Support

| Attribute | Detail |
|-----------|--------|
| **Status** | BLOCKED |
| **Reason** | Browsers cannot create additional OS-level windows programmatically (popup blockers, sandbox). |
| **Impact** | Blender's ability to tear off editors into separate windows is not available. |
| **Mitigation** | Blender's workspace system (tabs) already provides single-window multi-layout. This is the primary navigation mode for most users. Not a critical loss. |

### 28. USB/Peripheral Device Access

| Attribute | Detail |
|-----------|--------|
| **Status** | SEVERELY LIMITED |
| **Reason** | WebHID and WebUSB exist but are Chrome-only, require explicit user permission, and do not cover 3D mice (SpaceMouse) or custom input devices. |
| **Impact** | No SpaceMouse support. No custom peripheral support. |
| **Mitigation** | Standard mouse/keyboard/tablet work via Pointer Events. Gamepad API could provide some 3D navigation. This is a niche feature loss. |

### 29. Network Rendering / Render Farms

| Attribute | Detail |
|-----------|--------|
| **Status** | BLOCKED |
| **Reason** | Browser sandbox prevents acting as a network render node. No socket server capability. |
| **Impact** | Cannot distribute rendering across machines from the browser. |
| **Mitigation** | Out of scope per PROJECT.md. If needed later, implement as a cloud service that the web client submits jobs to -- but this is a different product architecture. |

### 30. OpenImageDenoise (OIDN) AI Denoiser

| Attribute | Detail |
|-----------|--------|
| **Status** | SEVERELY LIMITED |
| **Reason** | OIDN uses Intel's neural network inference engine (oneDNN) with CPU-specific optimizations (AVX-512, SSE4). The WASM version would lose all SIMD optimization advantages. WebNN (Web Neural Network API) is emerging but not widely supported. |
| **Impact** | AI denoising for Cycles renders would be extremely slow or unavailable. |
| **Mitigation** | WebGPU compute-based denoiser (simpler algorithm, not AI-based). Or wait for WebNN maturity and port OIDN to use it. Alternatively, a simple bilateral/NLM denoiser in WGSL compute shaders as a stopgap. |

### 31. VR/XR Support (OpenXR)

| Attribute | Detail |
|-----------|--------|
| **Status** | LIMITED (WebXR available but different API) |
| **Reason** | Blender uses OpenXR. Browsers use WebXR. The APIs are different but serve the same purpose. WebXR has reached cross-browser support as of late 2025. |
| **Impact** | Blender's OpenXR code cannot be reused directly. A WebXR integration layer is needed. |
| **Mitigation** | Replace Blender's OpenXR backend with WebXR. WebXR supports immersive-vr and immersive-ar modes. Meta Quest Browser has full WebXR support. This is a niche feature -- defer to later phases. |

### 32. C-Extension Python Addons

| Attribute | Detail |
|-----------|--------|
| **Status** | BLOCKED (per addon) |
| **Reason** | Pyodide cannot load arbitrary C extensions compiled for native CPython. Each C extension must be separately compiled to WASM. |
| **Impact** | Popular addons with C dependencies (e.g., addons using scipy, PIL with native backends, custom C modules) will not work. |
| **Mitigation** | Pure-Python addons work. NumPy is available via Pyodide. For critical C-extension addons, pre-compile them for WASM and bundle. Maintain a "web-compatible addons" registry. |

---

## Feature Dependencies Map

```
GPU Abstraction (WebGPU backend)
  |
  +---> Viewport Navigation
  |       |
  |       +---> All editors (visual rendering)
  |
  +---> EEVEE Renderer
  |       |
  |       +---> Material/Shader System
  |       |       |
  |       |       +---> Shader Nodes (WGSL compilation)
  |       |
  |       +---> Compositing (GPU path)
  |
  +---> Cycles Renderer (WebGPU compute)
  |       |
  |       +---> NanoVDB (volumetrics)
  |       |
  |       +---> Denoiser (WebGPU compute fallback)
  |
  +---> Draw Manager (overlays, gizmos, selection)

GHOST Browser Backend (input/window)
  |
  +---> Window Manager (events, context)
  |       |
  |       +---> All editors (input handling)
  |       |
  |       +---> Operator System (tools, transforms)
  |
  +---> Pointer Events --> Sculpting, Texture Paint, Grease Pencil

Emscripten Core (WASM compilation)
  |
  +---> blenlib, blenkernel, makesdna/rna (foundation)
  |       |
  |       +---> BMesh (modeling)
  |       +---> Modifier Stack
  |       +---> Animation / Armatures
  |       +---> Geometry Nodes
  |       +---> Depsgraph
  |
  +---> File I/O (Emscripten VFS + OPFS)
  |
  +---> Python/Pyodide (scripting)

SharedArrayBuffer + Web Workers (threading)
  |
  +---> Parallel modifier evaluation
  +---> Sculpting (PBVH updates)
  +---> Physics simulation
  +---> Cycles rendering (multi-tile)
  +---> Geometry Nodes (parallel evaluation)
```

---

## Browser API Requirements Matrix

| Browser API | Required For | Chrome | Firefox | Safari | Criticality |
|-------------|-------------|--------|---------|--------|-------------|
| **WebGPU** | Viewport, EEVEE, Cycles, all rendering | 113+ | 120+ | 17.4+ | CRITICAL -- no product without it |
| **SharedArrayBuffer** | Threading (pthreads via Emscripten) | Yes (COOP/COEP) | Yes (COOP/COEP) | Yes (COOP/COEP) | CRITICAL -- needed for usable performance |
| **WASM SIMD** | Math acceleration (transforms, mesh ops) | Yes | Yes | Yes | HIGH -- significant perf impact |
| **OPFS** | File persistence, project storage | Yes | Yes | Yes | HIGH -- needed for save/load |
| **WebGL2** | Fallback renderer (no WebGPU) | Yes | Yes | Yes | MEDIUM -- graceful degradation |
| **Memory64** | Large scenes (>4GB) | 133+ | 134+ | NO | MEDIUM -- needed for complex scenes |
| **Pointer Events** | Tablet pressure, tilt | Yes | Yes | Yes | MEDIUM -- needed for sculpting/drawing |
| **File System Access API** | Native-like open/save | Yes | NO | NO | LOW -- nice-to-have, fallback exists |
| **WebCodecs** | Hardware video decode/encode (VSE) | Yes | Yes | Partial | LOW -- needed for VSE only |
| **WebXR** | VR/AR support | Yes | Yes | Partial | LOW -- niche feature |
| **WebNN** | AI denoising (OIDN replacement) | Emerging | NO | NO | FUTURE -- not ready yet |
| **COOP/COEP headers** | Required for SharedArrayBuffer | Mandatory | Mandatory | Mandatory | CRITICAL -- deployment requirement |

---

## Anti-Features

Features to explicitly NOT build or attempt in the initial port.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Full FFmpeg codec support** | Binary size explosion (100MB+), most codecs unused | Support H.264/VP9/AV1 via WebCodecs, bundle minimal ffmpeg.wasm for specific needs |
| **Desktop-identical memory usage** | WASM 4GB limit makes this impossible | Implement memory budgets, LOD systems, aggressive garbage collection |
| **Full USD/Alembic support** | Massive dependency trees (TBB, Boost, etc.) | Defer to later phases; prioritize glTF/FBX/OBJ for web |
| **Background process rendering** | No process spawning in browsers | Render in Web Worker, show progress in UI |
| **Automatic addon installation from URLs** | Security risk in browser context | Curated addon catalog with pre-vetted WASM-compatible addons |
| **Native GPU profiling** | No access to vendor GPU profilers | Use WebGPU's timestamp queries and browser DevTools |
| **Splash screen with system info** | Irrelevant in browser context | Replace with project picker / recent files from OPFS |

---

## MVP Recommendation

### Phase 1 Priority: Core Viewport + Basic Editing

Must-have for a functional demo:

1. **GPU Abstraction Layer (WebGPU backend)** -- unlocks everything visual
2. **GHOST Browser Backend** -- unlocks all input handling
3. **3D Viewport with navigation** -- the product's foundation
4. **Basic UI rendering** -- panels, editors, menus functional
5. **Mesh modeling (Edit Mode)** -- first interactive capability
6. **Basic modifier stack** (Mirror, Subdivision Surface, Array) -- productive modeling
7. **File I/O** (.blend save/load via OPFS) -- session persistence
8. **Undo/Redo** -- required for any editor

### Phase 2 Priority: Rendering + Materials

9. **EEVEE renderer** -- viewport shading beyond wireframe
10. **Material/Shader node system** -- visual quality
11. **Basic animation** (keyframes, timeline, playback)

### Phase 3 Priority: Blender Identity Features

12. **Cycles renderer** (WebGPU compute, accept slower performance)
13. **Geometry Nodes**
14. **Sculpting tools**
15. **Python scripting** (Pyodide integration)

### Defer to Later Phases

- Physics simulation (fluid especially)
- Video Sequence Editor
- Compositing
- Grease Pencil
- VR/XR
- Full import/export format support
- Advanced addons

**Ordering rationale:** The dependency chain is strict -- nothing visual works without the GPU backend, nothing interactive works without GHOST, nothing productive works without edit mode + save/load. EEVEE must precede Cycles because EEVEE is the viewport renderer. Python can be deferred because the core editor is functional without scripting (operators work natively in C++). Physics and VSE are the most "independent" systems with the highest adaptation cost.

---

## Sources

### Official Documentation (HIGH confidence)
- [WebGPU W3C Specification](https://www.w3.org/TR/webgpu/)
- [WGSL Specification](https://www.w3.org/TR/WGSL/)
- [Emscripten Porting Guide](https://emscripten.org/docs/porting/index.html)
- [Emscripten Pthreads Support](https://emscripten.org/docs/porting/pthreads.html)
- [Emscripten OpenGL Support](https://emscripten.org/docs/porting/multimedia_and_graphics/OpenGL-support.html)
- [Pyodide WASM Constraints](https://pyodide.org/en/stable/usage/wasm-constraints.html)
- [MDN: Origin Private File System](https://developer.mozilla.org/en-US/docs/Web/API/File_System_API/Origin_private_file_system)
- [MDN: WebGPU API](https://developer.mozilla.org/en-US/docs/Web/API/WebGPU_API)
- [MDN: SharedArrayBuffer](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/SharedArrayBuffer)
- [MDN: WebCodecs API](https://developer.mozilla.org/en-US/docs/Web/API/WebCodecs_API)

### Technical References (MEDIUM confidence)
- [V8 Blog: 4GB WASM Memory](https://v8.dev/blog/4gb-wasm-memory)
- [WASM 3.0 Memory64 Release](https://progosling.com/en/dev-digest/2025-09/wasm-3-0-released)
- [SpiderMonkey: Is Memory64 Worth Using?](https://spidermonkey.dev/blog/2025/01/15/is-memory64-actually-worth-using.html)
- [WebGPU Shader Limits](https://hugodaniel.com/posts/webgpu-shader-limits/)
- [WebGPU Optional Features and Limits](https://webgpufundamentals.org/webgpu/lessons/webgpu-limits-and-features.html)
- [Unity WebGPU Limitations](https://docs.unity3d.com/6000.3/Documentation/Manual/WebGPU-limitations.html)
- [Dawn Emscripten Integration](https://deepwiki.com/google/dawn/8-emscripten-integration)
- [emdawnwebgpu README](https://dawn.googlesource.com/dawn/+/refs/heads/main/src/emdawnwebgpu/pkg/README.md)
- [NanoVDB on WebGPU Discussion](https://github.com/AcademySoftwareFoundation/openvdb/discussions/1625)
- [ammo.js (Bullet WASM)](https://github.com/kripken/ammo.js/)
- [ffmpeg.wasm](https://github.com/ffmpegwasm/ffmpeg.wasm)
- [WebGPU Ray Tracing Extension Issue](https://github.com/gpuweb/gpuweb/issues/535)

### Community / Research (LOW confidence -- needs validation)
- [Blender DevTalk: Building Headless Blender to WASM](https://devtalk.blender.org/t/building-headless-blender-to-webassembly/18381)
- [IEEE: Enhancing Browser Physics Simulations](https://ieeexplore.ieee.org/document/11071666/)
- [Porting C++ Game Engine to WASM](https://polymonster.co.uk/blog/porting-to-wasm-with-emscripten)
- [WebGPU Hits Critical Mass](https://www.webgpu.com/news/webgpu-hits-critical-mass-all-major-browsers/)
- [Web Audio API Limitations](https://rye.company/blog/web-audio-api-design-philosophy-and-reality/)
- [WebAssembly Limitations (qouteall)](https://qouteall.fun/qouteall-blog/2025/WebAsembly%20Limitations)

---

*Feature landscape analysis: 2026-04-01*
