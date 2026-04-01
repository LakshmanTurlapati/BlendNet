# Codebase Structure

**Analysis Date:** 2026-04-01

## Directory Layout

```
Blender Mirror/
├── source/
│   ├── blender/                # Main Blender application
│   │   ├── makesdna/           # Binary file format + in-memory data structure definitions
│   │   ├── makesrna/           # RNA (reflection API) + Python bindings generation
│   │   ├── blenlib/            # Low-level utilities (data structures, math, strings)
│   │   ├── blenkernel/         # Core engine (objects, animation, physics, modifiers)
│   │   ├── depsgraph/          # Dependency tracking and evaluation scheduling
│   │   ├── windowmanager/      # Event system, window management, operator dispatch
│   │   ├── editors/            # 40+ sub-editors (3D view, shader, geometry nodes, etc.)
│   │   ├── gpu/                # GPU abstraction (OpenGL, Vulkan, Metal, WebGPU)
│   │   ├── draw/               # Viewport rendering engine (EEVEE, Workbench overlays)
│   │   ├── render/             # Final render engine (Cycles integration)
│   │   ├── bmesh/              # Polygon mesh topology and editing operations
│   │   ├── geometry/           # Geometry operations (curves, points, volumes)
│   │   ├── compositor/         # Node-based compositing and post-processing
│   │   ├── sequencer/          # Video timeline and editing
│   │   ├── io/                 # Format importers/exporters (FBX, USD, OBJ, STL, PLY)
│   │   ├── blenloader/         # .blend file I/O and versioning
│   │   ├── blenloader_core/    # Core loader logic (internal implementation)
│   │   ├── nodes/              # Node system (shader, geometry, composite node types)
│   │   ├── functions/          # Function graph system (underlying procedural framework)
│   │   ├── modifiers/          # Modifier system (Subdivision, Boolean, Array, etc.)
│   │   ├── animrig/            # Animation rigging (IK, armatures, constraints)
│   │   ├── python/             # Python API bindings (bpy module)
│   │   ├── asset_system/       # Asset library management
│   │   ├── blenfont/           # Font and text rendering
│   │   ├── blentranslation/    # Internationalization
│   │   ├── imbuf/              # Image buffer operations and format codecs
│   │   ├── freestyle/          # NPR line rendering
│   │   ├── simulation/         # Particle, cloth, rigid body simulation
│   │   ├── shader_fx/          # Shader effects (grease pencil specific)
│   │   ├── ikplugin/           # IK solver plugins
│   │   ├── cpucheck/           # CPU capability detection
│   │   └── datatoc/            # Build tool for embedding data files
│   └── creator/                # Application entry point
├── intern/                     # Internal libraries (not exposed as API)
│   ├── cycles/                 # Cycles render engine (ray tracing, volumetrics)
│   ├── ghost/                  # Platform abstraction (window, input, events)
│   ├── guardedalloc/           # Guarded memory allocator
│   ├── memutil/                # Memory utilities
│   ├── clog/                   # Logging system
│   ├── iksolver/               # Inverse kinematics solver
│   ├── itasc/                  # IK animation system
│   ├── libmv/                  # Motion tracking
│   ├── bullet2/                # Bullet physics engine integration
│   ├── mantaflow/              # Fluid dynamics solver
│   ├── opensubdiv/             # Subdivision surface
│   ├── openvdb/                # Volumetric data structures
│   ├── quadriflow/             # Quad mesh generation
│   ├── eigen/                  # Linear algebra (included)
│   ├── atomic/                 # Atomic operations
│   ├── utfconv/                # UTF string conversion
│   ├── uriconvert/             # URI/path utilities
│   ├── dualcon/                # Dual contouring
│   ├── sky/                    # Sky simulation
│   ├── slim/                   # SLIM deformation
│   ├── wayland_dynload/        # Wayland dynamic loading
│   └── ...other libs
├── extern/                     # External vendored dependencies
│   ├── audaspace/              # Audio library
│   ├── draco/                  # Mesh compression
│   ├── gtest/gmock/            # Testing frameworks
│   ├── json/                   # JSON parsing
│   ├── tinygltf/               # glTF support
│   ├── nanosvg/                # SVG rendering
│   ├── bullet2/                # Physics (also in intern)
│   └── ...others
├── scripts/                    # Python scripts and addons
│   ├── startup/                # Startup scripts (UI initialization)
│   ├── modules/                # Built-in Python modules
│   ├── addons_core/            # Core addons (modeling tools, rigging, etc.)
│   ├── presets/                # UI/tool presets
│   ├── freestyle/              # Freestyle NPR scripts
│   └── templates_py/           # Python script templates
├── build_files/                # Build system configuration
│   ├── cmake/                  # CMake modules and platform detection
│   ├── build_environment/      # Build dependency compilation
│   ├── buildbot/               # CI/CD configuration
│   └── utils/                  # Build helper scripts
├── tests/                      # Test suite
│   ├── gtests/                 # Google Test unit tests (C++)
│   ├── python/                 # Python pytest tests
│   ├── performance/            # Performance benchmarks
│   ├── blender_as_python_module/ # Python module tests
│   └── files/                  # Test data files (.blend, images, etc.)
├── release/                    # Release configuration and packaging
│   ├── datafiles/              # Default scenes, brushes, themes
│   ├── bin/                    # Bundled runtime files
│   ├── windows/linux/darwin/   # Platform-specific packaging scripts
│   ├── license/                # License files
│   └── pypi/                   # Python package configuration
├── tools/                      # Development tools
│   ├── git/                    # Git utilities
│   ├── utils/                  # General utilities
│   ├── check_source/           # Source validation (formatting, etc.)
│   ├── debug/                  # Debugging tools (GDB, LLDB config)
│   ├── utils_build/            # Build utilities
│   └── utils_doc/              # Documentation generation
├── doc/                        # Documentation
│   ├── python_api/             # Python API documentation source
│   ├── doxygen/                # C++ API documentation config
│   └── guides/                 # Developer guides
├── locale/                     # Internationalization (translation files)
├── lib/                        # Pre-built third-party libraries
│   ├── linux_x64/
│   ├── macos_arm64/
│   ├── windows_x64/
│   └── windows_arm64/
├── assets/                     # Built-in assets
│   ├── brushes/                # Sculpting/painting brush definitions
│   └── nodes/                  # Node tree presets
├── CMakeLists.txt              # Top-level build configuration
├── pyproject.toml              # Python project metadata
├── GNUmakefile                 # Simple make wrapper for convenience
└── .clang-format/.editorconfig # Code style configuration
```

## Directory Purposes

**source/blender/makesdna:**
- Purpose: Define binary file format (DNA = "Data in Neutral Architecture")
- Contains: 96+ `DNA_*.h` files defining all serializable structures
- Key files: `DNA_ID.h` (base object type), `DNA_scene_types.h`, `DNA_object_types.h`
- Files follow `DNA_<category>_types.h` naming pattern
- Generated from these: Data versioning, pointer remapping, file I/O

**source/blender/makesrna:**
- Purpose: Runtime reflection and Python API generation
- Contains: C structures that wrap DNA types with property definitions
- Key files: Located in `intern/`, generates `rna_*.c` files at build time
- Consumes: makesdna header files
- Produces: Python API (bpy module), introspection, property system

**source/blender/blenlib:**
- Purpose: Generic low-level utilities
- Contains: 250+ header files
- Key patterns: `BLI_*.h` (list operations, hash tables, vectors, math)
- Examples: `BLI_linklist.h` (linked lists), `BLI_string.h` (string ops), `BLI_math_*.h` (vector math)
- No Blender-specific dependencies; reusable in other projects

**source/blender/blenkernel:**
- Purpose: Core domain logic for 3D operations
- Contains: 230+ implementation files (`.c`) in `intern/` subdirectory
- Key subsystems: Object lifecycle, Scene management, Material/texture, Animation, Physics
- Header prefix: `BKE_*.h` (e.g., `BKE_object.h`, `BKE_mesh.h`)
- Largest module; central to all features

**source/blender/depsgraph:**
- Purpose: Dependency graph and evaluation scheduling
- Contains: Graph builder, evaluator, debug tools
- Key headers: `DEG_depsgraph.hh`, `DEG_depsgraph_build.hh`
- Language: C++ (`.cc` files in `intern/`)
- Drives: When/how objects update after changes

**source/blender/windowmanager:**
- Purpose: Application event loop and operator system
- Contains: Event handling, window state, operator registration/dispatch
- Key headers: `WM_api.hh`, `wm_event_system.hh`, `WM_types.hh`
- Depends on: `intern/ghost` (platform abstraction)
- Critical: Entry point for all user interaction

**source/blender/editors/space_\*:**
- Purpose: Individual editor UI (each space type)
- Examples: `space_view3d/` (3D viewport), `space_node/` (shader/geometry nodes), `space_image/` (UV/image editor)
- Contains: ~50 subdirectories, each self-contained
- Pattern: Usually `draw.c`, `ops.c` (operators), `header.c` (toolbar)
- Depends on: Common editor utilities, specific domain layers

**source/blender/io/:**
- Purpose: Import/export formats
- Contains: Subdirectory per format
- Examples: `fbx/`, `usd/`, `wavefront_obj/`, `ply/`, `stl/`
- Each format: Reader/writer, UI operators, tests

**source/blender/gpu/:**
- Purpose: Render hardware abstraction
- Contains: Backend implementations (opengl, vulkan, metal, dummy)
- Key API: `GPU_*.h` headers
- Abstracts: Shaders, buffers, textures, pipeline state
- Used by: draw, compositor, render engines

**source/blender/draw/:**
- Purpose: Viewport rendering pipeline
- Contains: Draw manager, EEVEE engine, Workbench engine, overlay system
- Key files: `draw_manager.c`, `engines/eevee/`, `engines/workbench/`
- Responsibility: What appears in 3D viewport in real-time

**source/blender/render/:**
- Purpose: Final rendering (offline)
- Contains: Render pass system, image composition, Cycles integration
- Key pattern: Render engine plugins (cycles_render.c, etc.)

**source/blender/nodes/:**
- Purpose: Node system (shader, geometry, composite nodes)
- Contains: `composite/`, `shader/`, `geometry/`, `function/`, `texture/`
- Each node: `.c` file with declaration, execute logic
- Pattern: `node_*.c` files, registered at startup

**source/blender/python/:**
- Purpose: Python bindings and scripting API
- Contains: `intern/` (core binding generation), `generic/` (shared utilities), `bmesh/`, `gpu/`, `mathutils/`
- Key module: `bpy` (main application API)
- Generated: Python module stubs at build time from RNA

**source/blender/animrig/:**
- Purpose: Animation and rigging systems
- Contains: Armature evaluation, constraint solving, NLA (non-linear animation)
- Key dependency: `intern/iksolver`, `intern/itasc`

**source/blender/compositor/:**
- Purpose: Compositing node execution
- Contains: `algorithms/` (blur, color correction), `cached_resources/`, `intern/`, `shaders/`
- Pattern: Each compositor node has GPU shader code

**source/blender/geometry/:**
- Purpose: Geometry operations (curves, points, implicit surfaces)
- Contains: Curve evaluation, bounding box operations
- Separate from bmesh (which is for polygonal meshes)

**intern/cycles/:**
- Purpose: Cycles render engine (path tracing)
- Contains: Kernel (rendering math), integrators, scene representation
- Language: CUDA/HIP/OptiX kernels, C++ host code
- Dependency: External Cycles library (git submodule or vendored)

**intern/ghost/:**
- Purpose: Platform abstraction for window system
- Contains: Window creation, input events, clipboard, timers
- Implementations: `ghost_window_win32.c`, `ghost_window_x11.c`, `ghost_window_cocoa.mm`
- Critical: Isolates platform-specific code

**tests/gtests/:**
- Purpose: C++ unit tests (Google Test framework)
- Contains: Test binaries alongside source (e.g., `blender/blenlib/tests/`)
- Naming: `*_test.cc` files
- Run: `ctest` or individual test executable

**tests/python/:**
- Purpose: Python integration tests (pytest)
- Contains: Test scripts alongside modules they test
- Examples: `test_bpy_*.py`, `test_bmesh_*.py`

**scripts/startup/:**
- Purpose: Initialize Blender UI and register default tools
- Contains: Python scripts loaded on application start
- Key files: `bl_ui/` (UI panels and menus)

**release/datafiles/:**
- Purpose: Default startup data
- Contains: Default scene, brushes, materials, color palettes
- Format: `.blend` files and other data
- Bundled: Into final executable/package

## Key File Locations

**Entry Points:**
- `source/creator/buildinfo.c` - Build information constants
- `source/blender/windowmanager/wm.hh` - Window manager main header
- `intern/ghost/GHOST_Window.h` - Platform window interface

**Configuration:**
- `CMakeLists.txt` - Build configuration (defines all modules, options)
- `pyproject.toml` - Python package metadata
- `.clang-format` - Code style for C/C++
- `.editorconfig` - IDE settings

**Core Logic:**
- `source/blender/blenkernel/intern/` - All blenkernel implementation
- `source/blender/depsgraph/intern/` - Depsgraph evaluation engine
- `source/blender/python/intern/bpy_interface.c` - Python initialization

**Testing:**
- `tests/gtests/` - C++ tests
- `tests/python/` - Python tests
- `CMakeLists.txt` in test directories register tests with ctest

**Build Tools:**
- `build_files/cmake/Modules/` - CMake utilities
- `build_files/cmake/platform/` - Platform-specific settings

## Naming Conventions

**Files:**
- C source: `*.c`
- C++ source: `*.cc` or `*.cpp`
- Headers: `*.h` for C, `.hh` for C++
- Blender kernel APIs: `BKE_*.h` (e.g., `BKE_object.h`)
- Blender lib APIs: `BLI_*.h` (e.g., `BLI_math_vector.h`)
- Window manager: `WM_*.hh`, `wm_*.hh`
- GPU: `GPU_*.h`
- DNA types: `DNA_*_types.h`
- RNA: `RNA_*.h`
- RNA internal: Generated `rna_*.c` files
- Tests: `*_test.cc` (C++) or `test_*.py` (Python)

**Directories:**
- Domain modules: lowercase with underscores (e.g., `space_view3d`, `asset_system`)
- Internal implementation: `intern/` subdirectory
- Public headers: Directly in module root
- Tests: `tests/` subdirectory (or alongside implementation)
- Shaders: `*.glsl` or `*.hlsl` in `shaders/` subdirectories

**Functions (C):**
- Public kernel functions: `BKE_<domain>_<operation>` e.g., `BKE_mesh_deform()`
- Public lib functions: `BLI_<operation>` e.g., `BLI_linklist_prepend()`
- Internal: Prefix with module context, suffix `_internal()`
- Callback functions: Prefix `wm_` for window manager, editor-specific prefix otherwise

**Struct Names:**
- DNA (file format): `<Category>` (e.g., `Object`, `Mesh`, `Armature`)
- RNA wrappers: `PointerRNA`, `PropertyRNA`, `FunctionRNA`
- Lists: `ListBase` (generic linked list)
- IDs: Prefixed `ID_` enum constants (`ID_OB`, `ID_ME`, `ID_MA`)

## Where to Add New Code

**New Feature in Existing System:**
- Primary code: Subdirectory of relevant module (e.g., new modifier → `source/blender/modifiers/`)
- Headers: Place in module root with `BKE_`, `GPU_`, etc. prefix as appropriate
- Tests: `source/blender/<module>/tests/<feature>_test.cc`
- Python bindings: RNA definitions in makesrna, generates automatically

**New Editor/Workspace:**
- Implementation: Create `source/blender/editors/space_<name>/`
- Structure: Typical structure is `draw.c`, `ops.c` (operators), `header.c` (UI toolbar)
- Register: Add to `source/blender/editors/CMakeLists.txt`
- Python API: Add RNA type definitions

**New Geometry Operation (non-modifier):**
- If procedural node: `source/blender/nodes/geometry/`
- If core geometry utility: `source/blender/geometry/intern/`
- If mesh-specific: `source/blender/bmesh/operators/`

**New Import/Export Format:**
- Create: `source/blender/io/<format_name>/`
- Implement: Reader/writer, operator, tests
- Register: Add to `source/blender/io/CMakeLists.txt`

**Utilities/Libraries:**
- Generic reusable code: `source/blender/blenlib/`
- Domain-specific: Appropriate module (e.g., animation util in `blenkernel`)

**Python Scripts/Addons:**
- Built-in addons: `scripts/addons_core/<addon_name>/`
- Startup UI: `scripts/startup/bl_ui/`

## Special Directories

**source/blender/makesdna/intern/:**
- Purpose: DNA parsing and versioning
- Generated: `dna.c` is generated at build time from DNA header files
- Not edited manually: DNA structure definitions are the single source of truth

**source/blender/makesrna/intern/:**
- Purpose: RNA binding generation
- Generated: Multiple `rna_*.c` files generated at build time
- Process: makesrna tool parses makesdna and makesrna definitions, generates Python bindings
- Committed: Build artifacts NOT committed (generated at build)

**source/blender/draw/engines/:**
- Purpose: Separate render engines that implement draw interface
- Examples: `eevee/` (real-time), `workbench/` (viewport), `gpencil/` (draw)
- Independent: Each engine can be enabled/disabled at build time

**intern/cycles/ and other intern/ modules:**
- Purpose: Not part of public API; internal only
- Build: Some are git submodules (cycles, mantaflow) pulled during build
- Not committed to this repo: Actual code in external repos or submodules

**tests/ directory structure:**
- Purpose: Mirrors source/ structure for organization
- Co-located: Test files often live next to code they test (e.g., `blenlib/intern/*_test.cc`)
- Run: CMake registers all *_test.cc files; executed by ctest

**release/datafiles/:**
- Purpose: Bundled default content
- Generated: Embedded into executable via datatoc tool
- File reference: Accessed in code via STRINGIFY() macro on generated .c files

**build/:**
- Purpose: Created at build time, not committed
- Contents: CMake-generated files, object files, executables
- Pattern: Out-of-source builds enforce `cmake ..` from separate directory

---

*Structure analysis: 2026-04-01*
