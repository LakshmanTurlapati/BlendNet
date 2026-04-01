# Requirements: Blender Web

**Defined:** 2026-04-01
**Core Value:** Blender's complete 3D creation suite running natively in a web browser with no installation required

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Build System & Core

- [ ] **BUILD-01**: Blender C/C++ source compiles to WebAssembly via Emscripten 5.0.4+
- [ ] **BUILD-02**: All required third-party dependencies compile to WASM (or have WASM-compatible replacements)
- [ ] **BUILD-03**: Threading works via Emscripten pthreads mapped to Web Workers with SharedArrayBuffer
- [ ] **BUILD-04**: Memory allocation works within WASM32 4GB address space with MEM_guarded_alloc
- [ ] **BUILD-05**: COOP/COEP headers configured for cross-origin isolation
- [ ] **BUILD-06**: Main loop converted to non-blocking via emscripten_set_main_loop or PROXY_TO_PTHREAD
- [ ] **BUILD-07**: WASM binary is served compressed (Brotli/gzip), with lazy loading for large modules
- [ ] **BUILD-08**: WASM SIMD enabled for math-heavy operations

### Platform Abstraction (GHOST)

- [ ] **GHOST-01**: GHOST_SystemSDL backend works in browser via Emscripten SDL2
- [ ] **GHOST-02**: Browser canvas integration for Blender's main window
- [ ] **GHOST-03**: Keyboard input maps correctly to Blender keybindings
- [ ] **GHOST-04**: Mouse input (click, drag, scroll) works for 3D navigation and UI
- [ ] **GHOST-05**: Touch input support for mobile/tablet browsers
- [ ] **GHOST-06**: Browser tab lifecycle handled (suspend/resume without data loss)
- [ ] **GHOST-07**: Clipboard integration via browser Clipboard API
- [ ] **GHOST-08**: Window resize/fullscreen handled via browser resize events

### GPU Backend

- [ ] **GPU-01**: GPUBackendWebGPU implements Blender's GPUBackend abstract interface
- [ ] **GPU-02**: Texture creation, upload, and sampling work on WebGPU
- [ ] **GPU-03**: Vertex/index/uniform buffer management on WebGPU
- [ ] **GPU-04**: Framebuffer/render pass management on WebGPU
- [ ] **GPU-05**: All Blender GLSL shaders translated to WGSL (763+ shaders)
- [ ] **GPU-06**: Shader compilation pipeline produces WGSL from Blender's shader sources
- [ ] **GPU-07**: Bind group layout matches WebGPU's 4-group limit
- [ ] **GPU-08**: Async pipeline creation handles WebGPU's async shader compilation
- [ ] **GPU-09**: WebGL2 fallback provides basic viewport when WebGPU unavailable

### Viewport & Navigation

- [ ] **VIEW-01**: 3D viewport renders via WebGPU with Workbench shading
- [ ] **VIEW-02**: Orbit, pan, zoom navigation works in viewport
- [ ] **VIEW-03**: Object selection (click, box select, lasso)
- [ ] **VIEW-04**: Gizmos render and respond to input (move, rotate, scale)
- [ ] **VIEW-05**: Viewport overlays (grid, axes, wireframe, normals)
- [ ] **VIEW-06**: Multiple viewport layouts (quad view, split editors)
- [ ] **VIEW-07**: Viewport shading modes (solid, wireframe, material preview, rendered)

### Rendering - EEVEE

- [ ] **EEVEE-01**: EEVEE real-time renderer works on WebGPU
- [ ] **EEVEE-02**: PBR materials render correctly (metallic, roughness, normal maps)
- [ ] **EEVEE-03**: Screen-space reflections
- [ ] **EEVEE-04**: Ambient occlusion
- [ ] **EEVEE-05**: Shadow mapping (cascaded shadow maps, contact shadows)
- [ ] **EEVEE-06**: Bloom and volumetric effects
- [ ] **EEVEE-07**: Final render output to image

### Rendering - Cycles

- [ ] **CYCLES-01**: Cycles path tracer runs via WebGPU compute shaders
- [ ] **CYCLES-02**: BVH traversal implemented in WGSL compute kernels
- [ ] **CYCLES-03**: Material evaluation (principled BSDF) in compute shaders
- [ ] **CYCLES-04**: Progressive rendering with viewport preview
- [ ] **CYCLES-05**: Cycles CPU fallback when WebGPU compute unavailable
- [ ] **CYCLES-06**: Final render output to image

### Modeling & Editing

- [ ] **MODEL-01**: Object mode transforms (grab, rotate, scale)
- [ ] **MODEL-02**: Edit mode with BMesh vertex/edge/face operations
- [ ] **MODEL-03**: Extrude, inset, bevel, loop cut, knife tool
- [ ] **MODEL-04**: Modifier stack applies correctly (subdivision, mirror, boolean, array, solidify, etc.)
- [ ] **MODEL-05**: UV editing (UV editor, unwrap, seam marking)
- [ ] **MODEL-06**: Curve and surface editing
- [ ] **MODEL-07**: Object duplication, linking, parenting

### Sculpting

- [ ] **SCULPT-01**: Sculpt mode with brush-based operations
- [ ] **SCULPT-02**: Standard brushes (draw, clay, smooth, grab, inflate)
- [ ] **SCULPT-03**: Dynamic topology (dyntopo) remeshing
- [ ] **SCULPT-04**: Multires sculpting
- [ ] **SCULPT-05**: Mask and face set painting

### Materials & Shaders

- [ ] **MAT-01**: Shader node editor functional
- [ ] **MAT-02**: Principled BSDF and core shader nodes
- [ ] **MAT-03**: Image texture nodes with texture loading
- [ ] **MAT-04**: Procedural texture nodes (noise, voronoi, wave, etc.)
- [ ] **MAT-05**: Material preview in viewport

### Geometry Nodes

- [ ] **GEONODE-01**: Geometry Nodes editor functional
- [ ] **GEONODE-02**: Core geometry node types (mesh primitives, transforms, instances)
- [ ] **GEONODE-03**: Attribute system works (named attributes, fields)
- [ ] **GEONODE-04**: Math, vector, and utility nodes
- [ ] **GEONODE-05**: Geometry nodes modifier applies correctly

### Animation

- [ ] **ANIM-01**: Keyframe insertion and editing
- [ ] **ANIM-02**: Timeline editor with playback controls
- [ ] **ANIM-03**: Graph editor for F-curve editing
- [ ] **ANIM-04**: Dope sheet editor
- [ ] **ANIM-05**: Armature/bone creation and editing
- [ ] **ANIM-06**: Pose mode and bone constraints
- [ ] **ANIM-07**: Inverse kinematics (IK) solver
- [ ] **ANIM-08**: NLA editor for non-linear animation
- [ ] **ANIM-09**: Shape key animation
- [ ] **ANIM-10**: Driver system

### Grease Pencil

- [ ] **GP-01**: Grease Pencil object creation and drawing
- [ ] **GP-02**: Stroke editing and sculpting
- [ ] **GP-03**: Grease Pencil materials and layers
- [ ] **GP-04**: Grease Pencil animation (onion skinning)

### Physics & Simulation

- [ ] **PHYS-01**: Rigid body simulation (Bullet physics engine compiled to WASM)
- [ ] **PHYS-02**: Cloth simulation
- [ ] **PHYS-03**: Fluid simulation (Mantaflow compiled to WASM -- may require stubs if blocked)
- [ ] **PHYS-04**: Particle system (basic emitter and hair)
- [ ] **PHYS-05**: Soft body simulation

### Compositing

- [ ] **COMP-01**: Node-based compositing editor
- [ ] **COMP-02**: Core compositor nodes (color correction, blur, mix, alpha)
- [ ] **COMP-03**: Render layer input from Cycles/EEVEE
- [ ] **COMP-04**: Viewer node for preview
- [ ] **COMP-05**: Composite output to image

### Video Sequence Editor

- [ ] **VSE-01**: Video sequence editor timeline
- [ ] **VSE-02**: Strip types (image, movie, scene, sound, effect)
- [ ] **VSE-03**: Basic video editing (cut, trim, move strips)
- [ ] **VSE-04**: Transitions and effects
- [ ] **VSE-05**: Audio playback via Web Audio API

### Python Scripting

- [ ] **PY-01**: Python runtime embedded via Pyodide/CPython-WASM
- [ ] **PY-02**: bpy module accessible from Python console
- [ ] **PY-03**: Python console editor functional
- [ ] **PY-04**: Text editor with script execution
- [ ] **PY-05**: Pure-Python add-on loading and execution
- [ ] **PY-06**: Operator registration from Python scripts

### File I/O & Storage

- [ ] **FILE-01**: .blend file reading (open existing files)
- [ ] **FILE-02**: .blend file writing (save projects)
- [ ] **FILE-03**: WasmFS + OPFS for persistent browser storage
- [ ] **FILE-04**: Auto-save at configurable intervals to prevent data loss
- [ ] **FILE-05**: File browser UI for local file selection (File System Access API)
- [ ] **FILE-06**: Import/export common formats (OBJ, FBX, glTF, STL)
- [ ] **FILE-07**: Image file loading for textures (PNG, JPG, EXR, HDR)
- [ ] **FILE-08**: Asset browser with browser-local storage

### UI & Editors

- [ ] **UI-01**: Blender's full editor layout system renders in browser
- [ ] **UI-02**: All standard editors load (3D Viewport, Properties, Outliner, Timeline, etc.)
- [ ] **UI-03**: Preferences editor functional
- [ ] **UI-04**: Undo/redo system works
- [ ] **UI-05**: Context menus and operator search (F3)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Advanced Features

- **V2-01**: Multi-window support (browser popup windows)
- **V2-02**: Collaborative editing (real-time multi-user via WebRTC/WebSocket)
- **V2-03**: Cloud render offloading (send Cycles jobs to remote GPU)
- **V2-04**: Progressive WASM loading (load features on demand)
- **V2-05**: Service Worker for offline support
- **V2-06**: WebXR integration for VR viewport

## Out of Scope

| Feature | Reason |
|---------|--------|
| CUDA/OptiX/HIP GPU backends | Hardware-specific; WebGPU is the browser GPU API |
| Native file associations | Browser sandbox prevents OS integration |
| Multi-process rendering | Browsers restrict process spawning |
| Render farm integration | Desktop-only network workflow |
| C-extension Python packages | WASM cannot load native .so/.dll extensions |
| Direct USB/peripheral access | Beyond standard browser APIs |
| System notifications | Browser notification API is limited and different from OS-level |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUILD-01 | TBD | Pending |
| BUILD-02 | TBD | Pending |
| BUILD-03 | TBD | Pending |
| BUILD-04 | TBD | Pending |
| BUILD-05 | TBD | Pending |
| BUILD-06 | TBD | Pending |
| BUILD-07 | TBD | Pending |
| BUILD-08 | TBD | Pending |
| GHOST-01 | TBD | Pending |
| GHOST-02 | TBD | Pending |
| GHOST-03 | TBD | Pending |
| GHOST-04 | TBD | Pending |
| GHOST-05 | TBD | Pending |
| GHOST-06 | TBD | Pending |
| GHOST-07 | TBD | Pending |
| GHOST-08 | TBD | Pending |
| GPU-01 | TBD | Pending |
| GPU-02 | TBD | Pending |
| GPU-03 | TBD | Pending |
| GPU-04 | TBD | Pending |
| GPU-05 | TBD | Pending |
| GPU-06 | TBD | Pending |
| GPU-07 | TBD | Pending |
| GPU-08 | TBD | Pending |
| GPU-09 | TBD | Pending |
| VIEW-01 | TBD | Pending |
| VIEW-02 | TBD | Pending |
| VIEW-03 | TBD | Pending |
| VIEW-04 | TBD | Pending |
| VIEW-05 | TBD | Pending |
| VIEW-06 | TBD | Pending |
| VIEW-07 | TBD | Pending |
| EEVEE-01 | TBD | Pending |
| EEVEE-02 | TBD | Pending |
| EEVEE-03 | TBD | Pending |
| EEVEE-04 | TBD | Pending |
| EEVEE-05 | TBD | Pending |
| EEVEE-06 | TBD | Pending |
| EEVEE-07 | TBD | Pending |
| CYCLES-01 | TBD | Pending |
| CYCLES-02 | TBD | Pending |
| CYCLES-03 | TBD | Pending |
| CYCLES-04 | TBD | Pending |
| CYCLES-05 | TBD | Pending |
| CYCLES-06 | TBD | Pending |
| MODEL-01 | TBD | Pending |
| MODEL-02 | TBD | Pending |
| MODEL-03 | TBD | Pending |
| MODEL-04 | TBD | Pending |
| MODEL-05 | TBD | Pending |
| MODEL-06 | TBD | Pending |
| MODEL-07 | TBD | Pending |
| SCULPT-01 | TBD | Pending |
| SCULPT-02 | TBD | Pending |
| SCULPT-03 | TBD | Pending |
| SCULPT-04 | TBD | Pending |
| SCULPT-05 | TBD | Pending |
| MAT-01 | TBD | Pending |
| MAT-02 | TBD | Pending |
| MAT-03 | TBD | Pending |
| MAT-04 | TBD | Pending |
| MAT-05 | TBD | Pending |
| GEONODE-01 | TBD | Pending |
| GEONODE-02 | TBD | Pending |
| GEONODE-03 | TBD | Pending |
| GEONODE-04 | TBD | Pending |
| GEONODE-05 | TBD | Pending |
| ANIM-01 | TBD | Pending |
| ANIM-02 | TBD | Pending |
| ANIM-03 | TBD | Pending |
| ANIM-04 | TBD | Pending |
| ANIM-05 | TBD | Pending |
| ANIM-06 | TBD | Pending |
| ANIM-07 | TBD | Pending |
| ANIM-08 | TBD | Pending |
| ANIM-09 | TBD | Pending |
| ANIM-10 | TBD | Pending |
| GP-01 | TBD | Pending |
| GP-02 | TBD | Pending |
| GP-03 | TBD | Pending |
| GP-04 | TBD | Pending |
| PHYS-01 | TBD | Pending |
| PHYS-02 | TBD | Pending |
| PHYS-03 | TBD | Pending |
| PHYS-04 | TBD | Pending |
| PHYS-05 | TBD | Pending |
| COMP-01 | TBD | Pending |
| COMP-02 | TBD | Pending |
| COMP-03 | TBD | Pending |
| COMP-04 | TBD | Pending |
| COMP-05 | TBD | Pending |
| VSE-01 | TBD | Pending |
| VSE-02 | TBD | Pending |
| VSE-03 | TBD | Pending |
| VSE-04 | TBD | Pending |
| VSE-05 | TBD | Pending |
| PY-01 | TBD | Pending |
| PY-02 | TBD | Pending |
| PY-03 | TBD | Pending |
| PY-04 | TBD | Pending |
| PY-05 | TBD | Pending |
| PY-06 | TBD | Pending |
| FILE-01 | TBD | Pending |
| FILE-02 | TBD | Pending |
| FILE-03 | TBD | Pending |
| FILE-04 | TBD | Pending |
| FILE-05 | TBD | Pending |
| FILE-06 | TBD | Pending |
| FILE-07 | TBD | Pending |
| FILE-08 | TBD | Pending |
| UI-01 | TBD | Pending |
| UI-02 | TBD | Pending |
| UI-03 | TBD | Pending |
| UI-04 | TBD | Pending |
| UI-05 | TBD | Pending |

**Coverage:**
- v1 requirements: 97 total
- Mapped to phases: 0
- Unmapped: 97

---
*Requirements defined: 2026-04-01*
*Last updated: 2026-04-01 after initial definition*
