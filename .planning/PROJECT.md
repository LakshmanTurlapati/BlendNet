# Blender Web

## What This Is

A full-featured port of Blender 3D to the web browser, compiled from the existing Blender C/C++ source code to WebAssembly via Emscripten. The goal is 1:1 feature parity with desktop Blender -- modeling, sculpting, animation, physics simulation, rendering (Cycles/EEVEE), video editing, compositing, and scripting -- running entirely client-side in the browser with WebGPU acceleration.

## Core Value

Blender's complete 3D creation suite running natively in a web browser with no installation required, using WebGPU for GPU-accelerated rendering and gracefully degrading when WebGPU is unavailable.

## Requirements

### Validated

(None yet -- ship to validate)

### Active

- [ ] Blender C/C++ codebase compiles to WebAssembly via Emscripten
- [ ] WebGPU backend for GPU-accelerated viewport and rendering
- [ ] Fallback rendering path (WebGL2/software) when WebGPU is unavailable
- [ ] Blender UI renders correctly in browser (window manager, editors, panels)
- [ ] 3D viewport with navigation (orbit, pan, zoom)
- [ ] Mesh modeling tools (edit mode, modifiers, BMesh operations)
- [ ] Sculpting tools
- [ ] Material and shader system (node editor)
- [ ] Animation system (keyframes, timeline, graph editor, NLA)
- [ ] Physics simulation (rigid body, cloth, fluid via Mantaflow)
- [ ] Cycles path-tracing renderer (WebGPU compute)
- [ ] EEVEE real-time renderer
- [ ] Compositing node system
- [ ] Video sequence editor
- [ ] Python scripting via Pyodide/CPython-WASM
- [ ] File I/O (.blend read/write via browser filesystem APIs)
- [ ] Add-on support
- [ ] Geometry Nodes system
- [ ] Grease Pencil 2D animation
- [ ] Asset browser (with local/browser storage)

### Out of Scope

- Native OS integrations (system tray, file associations) -- browser sandbox prevents this
- Hardware-specific drivers (CUDA, OptiX, HIP) -- WebGPU abstracts GPU access
- Multi-process architecture -- browsers restrict process spawning
- Network rendering / render farm integration -- desktop-only workflow
- Direct USB/peripheral device access beyond standard browser APIs

## Context

**Source codebase:** This directory contains the full Blender source (~4.4M+ lines of C/C++/Python). The architecture is a layered modular monolith:
- Foundation: blenlib (data structures, math, memory)
- Data layer: makesdna/makesrna (file format types, reflection/Python API)
- Kernel: blenkernel (core 3D operations, scene management)
- Geometry: bmesh, geometry nodes
- Rendering: Cycles (path tracer), EEVEE (realtime), draw manager
- UI: windowmanager, editors (30+ editor types)
- GPU abstraction: `source/blender/gpu` with OpenGL/Vulkan/Metal backends

**Technical approach:** Compile the existing C/C++ to WASM using Emscripten. This maximizes code reuse. Key challenges:
- GPU backend: Replace OpenGL/Vulkan/Metal backends with WebGPU (via Dawn or wgpu)
- Threading: Map pthreads to Web Workers / SharedArrayBuffer
- File system: Emscripten virtual FS + IndexedDB for persistence
- Python: Port CPython or use Pyodide for scripting support
- Memory: WASM 4GB address space limit (Blender can use much more)

**Known challenges from codebase analysis:**
- 5,670+ TODO/FIXME comments indicating existing technical debt
- 12,926-line monolithic event handling file (wm_event_system.cc)
- Heavy use of platform-specific APIs (GHOST layer) that need browser equivalents
- Cycles renderer has CUDA/OptiX/HIP/Metal device backends that won't port directly

## Constraints

- **Platform**: Must run in modern browsers (Chrome 113+, Firefox 120+, Safari 17.4+) with WebGPU support
- **GPU API**: WebGPU is the primary GPU backend; WebGL2 as fallback for basic viewport only
- **Memory**: WASM 4GB limit requires careful memory management for complex scenes
- **Threading**: SharedArrayBuffer + Web Workers for parallelism (requires COOP/COEP headers)
- **Build toolchain**: Emscripten for C/C++ to WASM compilation
- **Storage**: Browser storage APIs (IndexedDB, OPFS) for file persistence
- **No native addons**: C-extension Python packages won't be available; pure-Python addons only

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Compile to WASM via Emscripten (not rewrite) | Maximizes code reuse from 4M+ line codebase; keeps feature parity realistic | -- Pending |
| WebGPU as primary GPU backend | Modern, performant, cross-browser GPU API designed for this use case | -- Pending |
| Graceful degradation without WebGPU | Broader browser compatibility; limited viewport-only mode acceptable | -- Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check -- still the right priority?
3. Audit Out of Scope -- reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-01 after initialization*
