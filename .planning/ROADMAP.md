# Roadmap: Blender Web

## Overview

This roadmap transforms Blender's 4.4M+ line C/C++ codebase into a fully functional browser application through a strict dependency-driven build order. Each phase produces a testable, observable milestone -- starting from a headless WASM compilation, progressing through browser integration and GPU rendering, then layering on editing tools, rendering engines, and scripting. The dependency chain is non-negotiable: nothing renders without GPU, nothing displays without GHOST, nothing compiles without the build system.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Headless WASM Build** - Blender core compiles to WebAssembly with threading, memory management, and SIMD enabled
- [ ] **Phase 2: Browser Platform Integration** - GHOST browser backend provides windowing, input, and lifecycle management in a canvas
- [ ] **Phase 3: WebGPU Viewport Backend** - GPUBackendWebGPU implements Blender's GPU abstraction with shader translation and WebGL2 fallback
- [ ] **Phase 4: Viewport & Core UI** - 3D viewport renders with navigation, selection, and gizmos; full editor layout system works
- [ ] **Phase 5: EEVEE Rendering & Materials** - Real-time PBR rendering with screen-space effects and node-based material system
- [ ] **Phase 6: Modeling, Sculpting & Geometry Nodes** - Complete mesh editing, sculpt tools, and procedural geometry system
- [ ] **Phase 7: Animation & Rigging** - Full animation system with armatures, IK, NLA, shape keys, drivers, and Grease Pencil
- [ ] **Phase 8: Cycles Path Tracer** - Production path tracing via WebGPU compute shaders with CPU fallback
- [ ] **Phase 9: Python Scripting & File I/O** - Python runtime with bpy access, addon support, and persistent file storage via OPFS
- [ ] **Phase 10: Simulation, Compositing, VSE & Polish** - Physics, node compositing, video editing, and remaining production features

## Phase Details

### Phase 1: Headless WASM Build
**Goal**: Blender's core engine compiles to WebAssembly and can load/query scene data without any display
**Depends on**: Nothing (first phase)
**Requirements**: BUILD-01, BUILD-02, BUILD-03, BUILD-04, BUILD-05, BUILD-06, BUILD-07, BUILD-08
**Success Criteria** (what must be TRUE):
  1. Running the WASM binary in a browser tab with COOP/COEP headers produces no compilation or linking errors
  2. A .blend file loaded from Emscripten MEMFS can be queried for scene objects, meshes, and materials via DNA/RNA API
  3. Web Workers spawn successfully with SharedArrayBuffer, confirming pthreads are operational
  4. Memory allocation via MEM_guarded_alloc stays within 4GB ceiling and reports accurate usage statistics
  5. WASM binary size is under 30MB compressed (Brotli) with lazy loading configured for optional modules
**Plans:** 3 plans

Plans:
- [x] 01-01-PLAN.md -- Build system foundation: Dockerfile, CMake Emscripten config, host tools, dependencies
- [x] 01-02-PLAN.md -- Dev server with COOP/COEP headers, test HTML page, Node.js validation scripts
- [ ] 01-03-PLAN.md -- Custom headless entry point, WASM compilation, threading/memory/main loop validation

### Phase 2: Browser Platform Integration
**Goal**: Blender's window manager runs in a browser canvas with full input handling and lifecycle management
**Depends on**: Phase 1
**Requirements**: GHOST-01, GHOST-02, GHOST-03, GHOST-04, GHOST-05, GHOST-06, GHOST-07, GHOST-08
**Success Criteria** (what must be TRUE):
  1. A browser canvas displays Blender's UI chrome (menu bar, status bar, editor area outlines) using the Dummy GPU backend
  2. Keyboard shortcuts (e.g., Tab for mode switch, G/R/S for transforms) are captured correctly without browser default interference
  3. Mouse click, drag, scroll, and right-click context menus work within the canvas without triggering browser menus
  4. Switching away from the browser tab and returning restores the application state without data loss
  5. The canvas resizes fluidly with the browser window, including fullscreen toggle
**Plans**: TBD
**UI hint**: yes

### Phase 3: WebGPU Viewport Backend
**Goal**: A new GPUBackendWebGPU renders geometry through Blender's GPU abstraction layer with shader translation from GLSL to WGSL
**Depends on**: Phase 2
**Requirements**: GPU-01, GPU-02, GPU-03, GPU-04, GPU-05, GPU-06, GPU-07, GPU-08, GPU-09
**Success Criteria** (what must be TRUE):
  1. WebGPU device and adapter initialization succeeds on Chrome, Firefox, and Safari with proper feature detection
  2. A test triangle renders through the full pipeline: vertex buffer creation, WGSL shader compilation, render pass execution, framebuffer display
  3. The GLSL-to-SPIR-V-to-WGSL shader translation pipeline compiles Workbench shaders without errors
  4. Async pipeline creation handles shader compilation without blocking the main thread or causing visual artifacts
  5. When WebGPU is unavailable, a WebGL2 fallback provides a basic solid-shaded viewport
**Plans**: TBD

### Phase 4: Viewport & Core UI
**Goal**: Users see and interact with 3D scenes through a fully functional viewport with Blender's complete editor layout
**Depends on**: Phase 3
**Requirements**: VIEW-01, VIEW-02, VIEW-03, VIEW-04, VIEW-05, VIEW-06, VIEW-07, UI-01, UI-02, UI-03, UI-04, UI-05
**Success Criteria** (what must be TRUE):
  1. The default cube scene renders with Workbench solid shading, grid floor, and axis indicator in the 3D viewport
  2. Orbit, pan, and zoom navigation responds to middle-mouse-drag, Shift+middle-drag, and scroll wheel respectively
  3. Clicking an object selects it (highlighted outline), box select and lasso select work, and gizmos (move/rotate/scale) respond to drag
  4. The Properties panel, Outliner, Timeline, and all standard editors load and display correct content
  5. Undo/redo (Ctrl+Z / Ctrl+Shift+Z) works across object operations, and F3 operator search finds and executes operators
**Plans**: TBD
**UI hint**: yes

### Phase 5: EEVEE Rendering & Materials
**Goal**: Users see PBR-shaded scenes in real time with full material and shader node support
**Depends on**: Phase 4
**Requirements**: EEVEE-01, EEVEE-02, EEVEE-03, EEVEE-04, EEVEE-05, EEVEE-06, EEVEE-07, MAT-01, MAT-02, MAT-03, MAT-04, MAT-05
**Success Criteria** (what must be TRUE):
  1. Switching viewport shading to Material Preview or Rendered mode displays EEVEE-lit scenes with correct PBR materials (metallic, roughness, normal maps)
  2. The Shader Editor opens and users can connect nodes (Principled BSDF, Image Texture, Noise, etc.) with live viewport preview updates
  3. Screen-space reflections, ambient occlusion, shadows (cascaded + contact), and bloom are visually correct
  4. Pressing F12 (Render Image) produces a final EEVEE render output that can be saved as an image file
  5. Procedural textures (Noise, Voronoi, Wave, Musgrave) generate correct patterns in both viewport and final render
**Plans**: TBD
**UI hint**: yes

### Phase 6: Modeling, Sculpting & Geometry Nodes
**Goal**: Users can create and edit 3D geometry through mesh tools, sculpting brushes, and procedural geometry nodes
**Depends on**: Phase 4
**Requirements**: MODEL-01, MODEL-02, MODEL-03, MODEL-04, MODEL-05, MODEL-06, MODEL-07, SCULPT-01, SCULPT-02, SCULPT-03, SCULPT-04, SCULPT-05, GEONODE-01, GEONODE-02, GEONODE-03, GEONODE-04, GEONODE-05
**Success Criteria** (what must be TRUE):
  1. Object mode transforms (G/R/S), Edit mode vertex/edge/face selection, and tools (extrude, bevel, loop cut, knife) work on mesh objects
  2. The modifier stack applies correctly -- adding Subdivision Surface, Mirror, Boolean, and Array modifiers produces expected geometry
  3. Sculpt mode activates with brush tools (Draw, Clay, Smooth, Grab, Inflate) responding to pointer input with pressure sensitivity
  4. Dynamic topology sculpting adds detail where the brush touches, and multires sculpting works on subdivided meshes
  5. The Geometry Nodes editor opens, core node types create/transform geometry, and the Geometry Nodes modifier produces output in the viewport
**Plans**: TBD
**UI hint**: yes

### Phase 7: Animation & Rigging
**Goal**: Users can animate objects and characters with keyframes, armatures, constraints, and 2D Grease Pencil tools
**Depends on**: Phase 4
**Requirements**: ANIM-01, ANIM-02, ANIM-03, ANIM-04, ANIM-05, ANIM-06, ANIM-07, ANIM-08, ANIM-09, ANIM-10, GP-01, GP-02, GP-03, GP-04
**Success Criteria** (what must be TRUE):
  1. Inserting keyframes (I key), playing back on the Timeline, and editing F-curves in the Graph Editor all work correctly
  2. Armatures can be created, bones posed in Pose Mode, and IK constraints solve correctly for character rigs
  3. The NLA Editor combines animation strips, the Dope Sheet shows keyframe overview, and drivers link properties across objects
  4. Grease Pencil objects can be drawn with stroke tools, edited, and animated with onion skinning visible
  5. Shape key animation interpolates between mesh states and can be driven by bones or custom properties
**Plans**: TBD
**UI hint**: yes

### Phase 8: Cycles Path Tracer
**Goal**: Users can produce path-traced renders via WebGPU compute shaders with a CPU fallback for browsers without compute support
**Depends on**: Phase 5
**Requirements**: CYCLES-01, CYCLES-02, CYCLES-03, CYCLES-04, CYCLES-05, CYCLES-06
**Success Criteria** (what must be TRUE):
  1. Selecting Cycles as the render engine and pressing F12 produces a progressive path-traced image that converges over time
  2. BVH acceleration structure builds correctly and ray-scene intersection produces accurate geometry visibility
  3. Principled BSDF materials render with correct diffuse, glossy, glass, and emission behavior in Cycles output
  4. The viewport shows a live progressive Cycles preview when Rendered shading mode is selected
  5. When WebGPU compute is unavailable, Cycles falls back to CPU rendering (slower but functional)
**Plans**: TBD

### Phase 9: Python Scripting & File I/O
**Goal**: Users can run Python scripts, load addons, and save/load .blend files persistently in the browser
**Depends on**: Phase 4
**Requirements**: PY-01, PY-02, PY-03, PY-04, PY-05, PY-06, FILE-01, FILE-02, FILE-03, FILE-04, FILE-05, FILE-06, FILE-07, FILE-08
**Success Criteria** (what must be TRUE):
  1. The Python Console editor accepts bpy commands (e.g., bpy.ops.mesh.primitive_cube_add()) and they execute correctly
  2. Pure-Python addons can be loaded from browser storage and register operators/panels that appear in the UI
  3. Opening a .blend file (via file picker or drag-and-drop) loads the scene correctly, and saving writes back to browser storage
  4. Auto-save triggers at configurable intervals and recovers the last session after a tab crash or closure
  5. Import/export of OBJ, FBX, glTF, and STL formats works through the File menu with browser file picker integration
**Plans**: TBD
**UI hint**: yes

### Phase 10: Simulation, Compositing, VSE & Polish
**Goal**: Remaining production features -- physics simulation, node compositing, video editing, and asset management -- reach functional parity
**Depends on**: Phase 5, Phase 6
**Requirements**: PHYS-01, PHYS-02, PHYS-03, PHYS-04, PHYS-05, COMP-01, COMP-02, COMP-03, COMP-04, COMP-05, VSE-01, VSE-02, VSE-03, VSE-04, VSE-05
**Success Criteria** (what must be TRUE):
  1. Rigid body simulation runs on a scene with colliding objects and produces physically plausible results; cloth drapes on a mesh
  2. The Compositor editor opens, render layers from EEVEE/Cycles feed into node chains, and the Viewer node shows processed output
  3. The Video Sequence Editor loads image/video/sound strips, plays back in the preview window, and audio outputs through Web Audio API
  4. Particle emitters spawn and simulate particles, and fluid simulation (Mantaflow) runs at reduced resolution within WASM memory constraints
  5. Composite output renders to a final image combining render layers with color correction, blur, and alpha operations

**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10
Note: Phases 6, 7, and 9 depend on Phase 4 (not each other) and can potentially execute in parallel after Phase 4 completes.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Headless WASM Build | 0/3 | Planning complete | - |
| 2. Browser Platform Integration | 0/TBD | Not started | - |
| 3. WebGPU Viewport Backend | 0/TBD | Not started | - |
| 4. Viewport & Core UI | 0/TBD | Not started | - |
| 5. EEVEE Rendering & Materials | 0/TBD | Not started | - |
| 6. Modeling, Sculpting & Geometry Nodes | 0/TBD | Not started | - |
| 7. Animation & Rigging | 0/TBD | Not started | - |
| 8. Cycles Path Tracer | 0/TBD | Not started | - |
| 9. Python Scripting & File I/O | 0/TBD | Not started | - |
| 10. Simulation, Compositing, VSE & Polish | 0/TBD | Not started | - |

---
*Roadmap created: 2026-04-01*
*Last updated: 2026-04-01*
