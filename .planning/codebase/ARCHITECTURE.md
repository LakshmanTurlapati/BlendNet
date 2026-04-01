# Architecture

**Analysis Date:** 2026-04-01

## Pattern Overview

**Overall:** Layered modular monolith with strict separation of concerns across functional domains (DNA, kernel, rendering, UI, editors).

**Key Characteristics:**
- Clear layering from low-level utilities (blenlib) to application layer (editors/windowmanager)
- Domain-driven organization by 3D operation type (modeling, animation, simulation, rendering, compositing)
- Centralized data model through makesdna/makesrna (DNA = Blender File Format Types)
- Dependency graph (depsgraph) for tracking relationships and driving computation
- Plugin architecture for modifiers, operators, and rendering engines

## Layers

**Foundation Layer (Utilities):**
- Purpose: Provide low-level data structures, memory management, and algorithms
- Location: `source/blender/blenlib`, `intern/guardedalloc`, `intern/memutil`
- Contains: Generic containers (linked lists, hash tables), math utilities, memory allocation, string operations, file I/O
- Depends on: C standard library, optional external libs (zlib, etc.)
- Used by: All higher layers

**Data Definition Layer (DNA/RNA):**
- Purpose: Define persistent file format and in-memory object types; provide reflection/scripting interface
- Location: `source/blender/makesdna`, `source/blender/makesrna`
- Contains: 96+ type definition files (DNA_*.h), RNA binding code
- Depends on: blenlib
- Used by: Kernel, editors, loaders, all domain layers
- DNA = serializable structure definitions; RNA = runtime reflection/Python API

**Kernel Layer (Core Engine):**
- Purpose: Implement core 3D operations (object creation, material handling, physics, animation)
- Location: `source/blender/blenkernel`
- Contains: Object lifecycle, scene management, animation system, physics simulation, constraint solving, modifiers
- Depends on: blenlib, makesdna, intern libraries (cycles, bullet, mantaflow, etc.)
- Used by: Editors, modifiers, rendering, simulation

**Geometry & Modeling Layer:**
- Purpose: Provide mesh operations, parametric geometry, and B-Mesh (mesh topology editor)
- Location: `source/blender/bmesh`, `source/blender/geometry`
- Contains: B-Mesh topology system, mesh evaluation, curve operations, point cloud/volume handling
- Depends on: blenkernel, blenlib, geometry algorithms
- Used by: Editors (mesh/curve/object), modifiers, rendering

**Rendering Pipeline:**
- Purpose: Render 3D scenes through multiple render engines
- Location: `source/blender/render`, `source/blender/draw`, `intern/cycles`
- Contains: EEVEE (real-time), Cycles (path tracer), Workbench (viewport), GPU abstraction
- Depends on: blenkernel, geometry, gpu, imbuf, external render libraries
- Used by: Viewport, final render, compositor

**Viewport/Drawing:**
- Purpose: Real-time viewport rendering and overlay UI
- Location: `source/blender/draw`, `source/blender/gpu`
- Contains: Draw manager, shader system, engine-specific code (OpenGL, Vulkan, Metal), GPU memory management
- Depends on: render, geometry, blenkernel
- Used by: Window manager, editors

**Compositor & Post-Processing:**
- Purpose: Node-based image processing and video composition
- Location: `source/blender/compositor`
- Contains: Compositor node execution, GPU scheduling, shader code generation, caching
- Depends on: gpu, imbuf, draw, blenkernel
- Used by: Render pipeline, sequencer

**Effects & Simulation:**
- Purpose: Particle systems, fluid dynamics, smoke, cloth, rigid body
- Location: `source/blender/simulation`, `intern/mantaflow`, `intern/cycles` (volume kernels)
- Contains: Particle engine, fluid solver interface, cloth constraints
- Depends on: blenkernel, geometry, external solvers
- Used by: Kernel, modifiers, rendering

**Sequencer & Video:**
- Purpose: Video editing timeline and sequencing
- Location: `source/blender/sequencer`
- Contains: Strip management, timeline evaluation, video/audio playback coordination
- Depends on: blenkernel, render, imbuf
- Used by: Editors

**Import/Export & File I/O:**
- Purpose: Load/save Blender files and import/export external formats
- Location: `source/blender/blenloader`, `source/blender/io`, `source/blender/blenloader_core`
- Contains: File versioning, format readers (FBX, USD, OBJ, PLY, STL, Alembic), save/load pipeline
- Depends on: makesdna, blenkernel, external format libraries
- Used by: File operations, command-line tools

**Dependency Graph:**
- Purpose: Track data dependencies and drive computation order (evaluation)
- Location: `source/blender/depsgraph`
- Contains: Dependency building, cycle detection, evaluation scheduling
- Depends on: blenkernel, makesdna
- Used by: Kernel (evaluation), viewport updates, rendering

**Python Integration:**
- Purpose: Expose Blender functionality to Python scripts and addons
- Location: `source/blender/python`, `source/blender/python/intern`, `source/blender/python/bmesh`, `source/blender/python/generic`
- Contains: Python API bindings, bpy module, bmesh API, math utilities module
- Depends on: makesrna, blenkernel, all functional layers
- Used by: Addons, scripts, REPL, operator system

**User Interface & Editors:**
- Purpose: User-facing editing interface and tools
- Location: `source/blender/editors` (40+ submodules), `source/blender/windowmanager`
- Contains: Individual editor implementations (3D viewport, shader editor, geometry nodes, etc.), operator system, undo/redo
- Depends on: All lower layers
- Used by: Application (window manager provides event loop)

**Window Manager & Application:**
- Purpose: Event loop, window management, application lifecycle, workspace management
- Location: `source/blender/windowmanager`
- Contains: Event system, window/context management, operator dispatch, gizmo system, XR support
- Depends on: editors, depsgraph, blenkernel, all functional layers, ghost (platform abstraction)
- Used by: Application entry point

**Application Entry Point:**
- Purpose: Initialize and start application
- Location: `source/creator`, `intern/ghost` (platform-specific window/input abstraction)
- Contains: Main function, initialization sequence, command-line parsing
- Depends on: Window manager, all systems via dependency injection
- Used by: OS launch

**Procedural/Nodes:**
- Purpose: Geometry nodes and shader nodes evaluation
- Location: `source/blender/nodes`, `source/blender/functions`
- Contains: Node type registry, function graphs, geometry node operations
- Depends on: blenkernel, geometry, functions framework
- Used by: Modifiers, materials, rendering

**Asset System:**
- Purpose: Asset management and library organization
- Location: `source/blender/asset_system`
- Contains: Asset metadata, catalog system, library browsing
- Depends on: blenkernel, blenlib
- Used by: Editors, file browser

**Animation System:**
- Purpose: Character animation, armatures, rigging, NLA editor
- Location: `source/blender/animrig`, `source/blender/blenkernel/intern` (nla, action, fcurve)
- Contains: IK solver, armature evaluation, action/strip evaluation
- Depends on: blenkernel, geometry, intern/iksolver, intern/itasc
- Used by: Depsgraph, editors

## Data Flow

**Initialization:**

1. `main()` in source/creator → calls windowmanager initialization
2. Window manager loads configuration (DNA_workspace_types, DNA_userdef_types)
3. Depsgraph system initialized with empty scene
4. GPU system initialized (OpenGL/Vulkan context creation)
5. Python interpreter initialized if scripting enabled

**File Loading:**

1. Operator: `WM_OT_open_mainfile` (source/blender/editors/io)
2. Calls blenloader `BLO_read_from_file()` (source/blender/blenloader_core/intern)
3. DNA structures deserialized from .blend file
4. Makesrna processes loaded data → updates pointers, runs versioning
5. Depsgraph built from loaded scene data
6. Python scripts/addons initialized
7. Viewport refreshes with loaded content

**Editing Operation (e.g., move object):**

1. Window manager receives mouse/keyboard event
2. Active operator receives event (e.g., transform operator)
3. Operator modifies object data (DNA_object_types.Location)
4. Depsgraph tagged as dirty (DEG_id_tag_update)
5. On next evaluation cycle:
   - Depsgraph walks dependency graph
   - Modifiers execute (geometry modified)
   - Drivers/constraints evaluate
   - Animation data applied
6. Render engines notified of changes
7. Viewport redraws with new geometry
8. Optional: Write to undo stack (DNA_userdef_types.undo settings)

**Rendering Pipeline (Viewport → Final):**

1. Draw manager called (draw_engine_viewport_select or draw_engine_eevee)
2. Mesh data prepared: evaluated geometry from depsgraph
3. Material setup: texture loading, shader compilation
4. Draw calls issued to GPU through GPU abstraction layer
5. EEVEE or Cycles executes based on render engine selection
6. For final render: Compositor applied post-processing
7. Sequencer timeline may integrate multi-shot output
8. Image exported or saved

**State Management:**

- **Persistent**: DNA structures in memory mirror .blend file format
- **Transient**: Depsgraph, evaluated geometry caches, viewport state
- **Undo Stack**: blenkernel maintains edit history (source/blender/editors/undo)
- **Context**: Window manager tracks current scene/object/tool (DNA_screen_types)

## Key Abstractions

**Data-ID (blenkernel/BKE_lib_id.h pattern):**
- Purpose: Base object for all serializable data
- Examples: `ID_OB` (Object), `ID_MA` (Material), `ID_SCE` (Scene), `ID_ME` (Mesh)
- Pattern: Reference counted, can be linked between files, versioned

**Operator (windowmanager/WM_types.hh):**
- Purpose: User-invocable action (modeling tool, transform, file save)
- Examples: `MESH_OT_subdivide`, `TRANSFORM_OT_translate`, `FILE_OT_save`
- Pattern: Operator class with poll (can-execute check), execute, modal (interactive) callbacks

**Depsgraph Node/Relation:**
- Purpose: Track dependencies between data objects
- Examples: Object → Geometry → Modifier → Material
- Pattern: Directed acyclic graph, topologically sorted for evaluation

**Modifier (blenkernel/BKE_modifier.h):**
- Purpose: Procedural geometry operation
- Examples: Subdivision Surface, Boolean, Array, Geometry Nodes
- Pattern: Execute-on-demand, caching of results, deformation vs. geometry generation

**Shader/Material (blenkernel/BKE_material.h):**
- Purpose: Surface appearance definition
- Examples: BSDF nodes, texture slots
- Pattern: Node graph compiled to GPU shader at render time

**Geometry Nodes (nodes/function):**
- Purpose: Procedural geometry definition as node graph
- Examples: Instance on Points, Subdivide, Distribute Points on Faces
- Pattern: Lazy evaluation, cached results, Python callable interface

## Entry Points

**Application Start:**
- Location: `source/creator/blender_launcher_win32.c` or platform equivalents
- Triggers: OS launch
- Responsibilities: Parse command-line args, initialize engines, start window manager event loop

**Operator Execution:**
- Location: `source/blender/windowmanager/intern/wm_operators.c`
- Triggers: User action (hotkey, menu, tool), or script call
- Responsibilities: Check poll, create context, execute operator, update viewport

**File Open:**
- Location: `source/blender/editors/io/file_ops.c`
- Triggers: File menu → Open, drag-drop file, or command-line argument
- Responsibilities: Call blenloader, versioning, addon initialization

**Rendering:**
- Location: `source/blender/render` or `intern/cycles/src/integrator.cpp`
- Triggers: Viewport draw (continuous), F12 (final render), or batch render
- Responsibilities: Build scene, compile shaders, execute render passes, composite

**Script Execution:**
- Location: `source/blender/python/intern/bpy_interface.c`
- Triggers: Python REPL, addon load, or `bpy.app.handlers`
- Responsibilities: Execute Python code in Blender context, expose API

## Error Handling

**Strategy:** Fail-safe with logging; preserve data integrity.

**Patterns:**
- File I/O: Validation on load; version mismatch triggers auto-upgrade
- GPU: Fallback to dummy driver or Workbench if specialized driver fails
- Operators: Poll prevents execution; undo reverts on error
- Python: Exceptions caught, logged, but don't crash application
- Modifiers: If modifier fails, geometry falls back to input mesh

## Cross-Cutting Concerns

**Logging:** `intern/clog` provides simple debug/warning/error logging with channels per module. Runtime visible in console.

**Validation:** Data integrity checked at load time (makesrna versioning), and operators validate input before execution.

**Authentication:** None (desktop application). File access controlled by OS permissions.

**Undo/Redo:** Centralized stack in blenkernel; operators must implement undo by marking modified IDs.

**Notifications:** Depsgraph tagging system notifies dependent systems of changes without tight coupling.

---

*Architecture analysis: 2026-04-01*
