<!-- GSD:project-start source:PROJECT.md -->
## Project

**Blender Web**

A full-featured port of Blender 3D to the web browser, compiled from the existing Blender C/C++ source code to WebAssembly via Emscripten. The goal is 1:1 feature parity with desktop Blender -- modeling, sculpting, animation, physics simulation, rendering (Cycles/EEVEE), video editing, compositing, and scripting -- running entirely client-side in the browser with WebGPU acceleration.

**Core Value:** Blender's complete 3D creation suite running natively in a web browser with no installation required, using WebGPU for GPU-accelerated rendering and gracefully degrading when WebGPU is unavailable.

### Constraints

- **Platform**: Must run in modern browsers (Chrome 113+, Firefox 120+, Safari 17.4+) with WebGPU support
- **GPU API**: WebGPU is the primary GPU backend; WebGL2 as fallback for basic viewport only
- **Memory**: WASM 4GB limit requires careful memory management for complex scenes
- **Threading**: SharedArrayBuffer + Web Workers for parallelism (requires COOP/COEP headers)
- **Build toolchain**: Emscripten for C/C++ to WASM compilation
- **Storage**: Browser storage APIs (IndexedDB, OPFS) for file persistence
- **No native addons**: C-extension Python packages won't be available; pure-Python addons only
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- C++ - Core engine, rendering system (Cycles), geometry processing
- C - Foundational systems, GPU drivers, external libraries
- Python 3.13+ - Scripting API, build tools, add-ons system, automation
- JavaScript (Vanilla) - Documentation UI and version switcher (`doc/python_api/static/js/version_switch.js`)
- HTML/CSS - Web documentation and API reference pages
- CMake - Build system configuration
## Runtime
- CMake 3.10+ - Build configuration and compilation management
- CMake-based build pipeline - Cross-platform compilation for Windows, macOS, Linux
- GNUmakefile - Alternative make-based build system (`GNUmakefile`)
- Batch scripts (Windows) - `make.bat` for Windows builds
- GCC 14.0.0+ or Clang 17.0+ (LLVM) - Linux/Unix builds
- MSVC 2019 (16.9.16+) - Windows builds
- Apple Clang - macOS builds
## Frameworks
- Cycles - Physically-based path tracing render engine
- bpy Module - Python API for Blender scripting and automation
- OpenGL - Graphics backend (when enabled with `WITH_OPENGL_BACKEND`)
- Vulkan - Alternative graphics backend (with `WITH_VULKAN_BACKEND`)
- Metal - Apple platform graphics support (Cycles Metal device)
- Bullet Physics Engine - Rigid body dynamics and collision detection
- Mantaflow - Fluid simulation framework (`extern/mantaflow/`)
- Ocean Modifier - Ocean wave simulation
- GTest - Unit testing framework (`extern/gtest/`, `extern/gmock/`)
- Clang-Tidy - Code analysis tool (optional, `WITH_CLANG_TIDY`)
## Key Dependencies
- NumPy - Python array processing (used by Audaspace and Mantaflow)
- Requests - Python HTTP library (for release tools and API access)
- OpenColorIO - Color management and LUT support
- OpenImageDenoise (OIDN) - AI-based compositing denoiser
- OpenEXR - High dynamic range image format support
- OpenJPEG - JPEG2000 image support
- CUDA - NVIDIA GPU compute (optional, `WITH_CYCLES_DEVICE_CUDA`)
- OptiX - NVIDIA ray tracing (optional, `WITH_CYCLES_DEVICE_OPTIX`)
- HIP - AMD GPU compute (optional, `WITH_CYCLES_DEVICE_HIP`)
- oneAPI - Intel GPU compute (optional, `WITH_CYCLES_DEVICE_ONEAPI`)
- GMP - GNU Multiple Precision Arithmetic (exact boolean operations)
- Manifold - Fast robust boolean geometry operations
- OpenSubdiv - Catmull-Clark surface subdivision
- Potrace - Bitmap to vector conversion
- OpenVDB - Volumetric data structures
- NanoVDB - GPU-optimized volumetric data
- Draco - 3D mesh compression
- Quadriflow - Automatic quadrilateral mesh generation
- FFmpeg - Video and audio codec support
- Alembic - Animation exchange format support
- USD (Universal Scene Description) - Scene interchange format
- MaterialX - Material interchange format
- glTF/tinygltf - glTF 3D model format support
- UFBX - FBX format support
- libsndfile - Audio file I/O
- WebP - Modern image format support
- Audaspace - Audio processing and playback
- Rubber Band - Time-stretching and pitch-scaling
- FFTW3 - Fast Fourier Transform for audio/simulation effects
- xxHash - Fast hashing algorithm (`extern/xxhash/`)
- curve_fit_nd - Spline curve fitting (`extern/curve_fit_nd/`)
- fast_float - Fast float conversion (`extern/fast_float/`)
- wcwidth - Unicode character width (`extern/wcwidth/`)
- rangetree - Range tree data structure (`extern/rangetree/`)
- NanoSVG - SVG parsing and rasterization
- PugiXML - XML parsing (used by OpenImageIO)
- JSON library - JSON parsing and serialization (`extern/json/`)
- Binreloc - Binary relocation library (Linux)
- Intel TBB - Task-based parallelism (optional, `WITH_TBB`)
- OpenXR - Extended Reality support specification
- FreeType - Font rendering and i18n support
- International Components for Unicode (ICU) - Text processing
- Google Test - Unit testing (`extern/gtest/`, `extern/gmock/`)
## Configuration
- Configurable via CMake options (boolean flags for 150+ feature toggles)
- Platform-specific settings for Windows, macOS, Linux
- GPU compute device selection (CUDA, OptiX, HIP, Metal, oneAPI)
- Feature modules can be enabled/disabled at build time
- Primary config: `CMakeLists.txt` - 2000+ lines of configuration
- CMake modules: `build_files/cmake/Modules/` - FindPythonLibsUnix.cmake, etc.
- Platform-specific modules: `build_files/cmake/platform/`
- Build environment scripts: `build_files/build_environment/cmake/`
- `CMakeLists.txt` - Root build configuration
- `pyproject.toml` - Python tool configurations (autopep8, black formatters)
- `.clang-format` - Code formatting rules
- `.clang-tidy` - Static analysis configuration
- `.editorconfig` - Cross-editor configuration
- `build_files/cmake/macros.cmake` - CMake macro definitions
- `GNUmakefile` - Alternative make-based build interface
## Platform Requirements
- CMake 3.10 or newer
- Compiler: GCC 14+, Clang 17+, MSVC 2019+, or Apple Clang
- Python 3.13+ (for building and scripting)
- Git with LFS (Large File Storage) for binary assets
- Platform-specific libraries (X11/Wayland on Linux, Cocoa on macOS, Windows SDK on Windows)
- CUDA Toolkit (for NVIDIA GPU compilation)
- OptiX SDK (for NVIDIA ray tracing)
- Intel GPGPU support libraries (for oneAPI compilation)
- Linux (X11, Wayland support), Windows, macOS (10.9+)
- Modern GPU preferred for rendering (NVIDIA, AMD, Intel, Apple Metal)
- 2GB+ RAM recommended (more for complex scenes)
- CPU rendering via Cycles
- GPU rendering via CUDA, OptiX, HIP, Metal, oneAPI
- Headless rendering mode available for server/batch use
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- C/C++ files: snake_case (e.g., `asset_catalog.cc`, `asset_catalog.hh`, `creator.cc`)
- Python files: snake_case (e.g., `_bpy_restrict_state.py`, `_console_shell.py`, `make_test.py`)
- Header files: `.h` extension for C, `.hh` extension for C++
- Test files in C++: suffix with `_test.cc` (e.g., `asset_catalog_path_test.cc`, `asset_library_service_test.cc`)
- Test files in Python: prefix or suffix with test (e.g., `io_obj_import_test.py`, `bl_blendfile_header.py`)
- Private/internal modules in Python: prefix with underscore (e.g., `_bpy_types.py`, `_console_python.py`, `_rna_info.py`)
- C/C++ functions: snake_case with descriptive verb-first names
- Python functions: snake_case, lowercase with underscores
- Class methods in Python: snake_case (e.g., `setUpClass`, `setUp`, `test_import_obj`)
- Private functions: prefix with underscore in Python
- Local variables: snake_case
- Class attributes in C++: suffix with underscore (e.g., `_real_data`, `_real_pref`)
- Constants: UPPER_SNAKE_CASE
- Private class members: prefix with underscore
- C++ classes: CamelCase (e.g., `AssetCatalogPath`, `RestrictBlend`, `_RestrictContext`)
- C structs: CamelCase with leading letter (e.g., `BlendFileHeader`)
- Python classes: CamelCase (e.g., `BlendFileHeaderTest`, `OBJImportTest`, `Popover`)
- Enums and type definitions: CamelCase
## Code Style
- Tool: clang-format (C/C++) configured in `.clang-format`
- autopep8 (Python) configured in `pyproject.toml`
- Max line length: 99 characters for C/C++, 120 characters for Python
- Indentation: 2 spaces for C/C++, 4 spaces for Python and shell scripts
- Line ending: Unix-style with final newline required
- AlignAfterOpenBracket: parameters align to opening brace
- AllowShortBlocksOnASingleLine: false (no single-line blocks)
- BinPackArguments: false (stack parameters on separate lines)
- BinPackParameters: false (stack parameters on separate lines)
- ConstructorInitializerAllOnOnePerLine: true (one initializer per line)
- Function calls and definitions have parameters stacked when exceeding line limit
- Line length: maximum 120 characters
- Aggressive autopep8 level: 2
- Skip string normalization in black configuration
- Do not modify: E721 (type comparisons), E722 (bare except), E402 (module imports not at top)
- C/C++: clang-tidy configured in `.clang-tidy`
- Python: autopep8 as primary formatter
- File configuration in `.editorconfig` specifies per-language rules
## EditorConfig Standards
- Charset: UTF-8
- Trim trailing whitespace: yes
- Insert final newline: yes
- Indent: 2 spaces
- Max line: 99 characters
- Charset: UTF-8
- Trim trailing whitespace: yes
- Insert final newline: yes
- Indent: 4 spaces
- Max line: 120 characters
- Charset: UTF-8
- Indent: 2 spaces
- Max line: 99 characters
## Import Organization
- C++ uses `.hh` for header files
- C uses `.h` for header files
- Prefix system includes with `<>` for standard library
- Prefix local includes with `""` for project files
- Group related includes with comments (e.g., `/* Mostly initialization functions. */`)
## Error Handling
- Returns status codes or boolean values for success/failure
- Null pointer checks before dereferencing
- Context manager pattern in C++ classes (constructor/destructor for RAII)
- CMake test parameters include `--debug-exit-on-error` and `--python-exit-code 1`
- Bare except blocks used where appropriate (E722 disabled for compatibility)
- Try-except blocks in utility functions
- Return dictionaries with status strings (e.g., `{'FINISHED'}`, `{'CANCELLED'}`)
- Global variables for test state (e.g., `args = None`) initialized at module level
- TODO comments for incomplete features (e.g., `# TODO` in shell.py)
- FIXME comments for known issues
- Comments explaining why certain linting rules are disabled
## Logging
- C/C++: CLG_log (from `#include "CLG_log.h"`)
- Python: bpy.ops system and custom scrollback handling
- Shell/interactive: custom scrollback implementation via `add_scrollback()` function
- Console output styling in Python: 'OUTPUT', 'ERROR', 'INPUT' types
- Scrollback append for text rendering in interactive contexts
- Command output capture via subprocess.getstatusoutput()
## Comments
- Explain non-obvious logic or workarounds
- Clarify disabled linting rules with justification
- Document special cases or exceptions
- Explain test expectations and assertions
- C/C++ uses `/** \file` style documentation
- Python docstrings for modules (e.g., `"""This module contains RestrictBlend context manager."""`)
- Comments use SPDX license identifiers at file top
- `\ingroup` and `\file` tags in C/C++ for Doxygen compatibility
- All files start with SPDX-FileCopyrightText and SPDX-License-Identifier
- Format: `# SPDX-FileCopyrightText: YYYY-YYYY Blender Authors`
- Format: `# SPDX-License-Identifier: GPL-2.0-or-later`
- C/C++ uses `/* */` style, Python uses `#` style
## Function Design
- Functions kept reasonably small for testability
- Complex logic broken into helper functions
- Methods like `test_*` in test classes dedicated to single test scenario
- C/C++: parameters stacked on separate lines when exceeding line limit
- Python: positional and keyword arguments used naturally
- Test methods accept `self` only (test data comes from `setUpClass`/`setUp`)
- Unused parameters prefixed with underscore (e.g., `_is_interactive`, `_type`, `_value`, `_traceback`)
- C/C++: void functions for side effects, return status/values for results
- Python test methods: return nothing (side effects via assertions)
- Utility functions: return data structures or status dictionaries
## Module Design
- Python modules use `__all__` tuple to define public API (e.g., from `_bpy_restrict_state.py`: `__all__ = ("RestrictBlend",)`)
- C/C++: header files define public API, implementation in .c or .cc files
- Private modules in Python use leading underscore prefix
- Not commonly used in this project
- Imports are explicit and direct to source modules
- C++ uses nested namespaces for organization (e.g., `blender::asset_system::tests`)
- Python uses module structure for organization
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Clear layering from low-level utilities (blenlib) to application layer (editors/windowmanager)
- Domain-driven organization by 3D operation type (modeling, animation, simulation, rendering, compositing)
- Centralized data model through makesdna/makesrna (DNA = Blender File Format Types)
- Dependency graph (depsgraph) for tracking relationships and driving computation
- Plugin architecture for modifiers, operators, and rendering engines
## Layers
- Purpose: Provide low-level data structures, memory management, and algorithms
- Location: `source/blender/blenlib`, `intern/guardedalloc`, `intern/memutil`
- Contains: Generic containers (linked lists, hash tables), math utilities, memory allocation, string operations, file I/O
- Depends on: C standard library, optional external libs (zlib, etc.)
- Used by: All higher layers
- Purpose: Define persistent file format and in-memory object types; provide reflection/scripting interface
- Location: `source/blender/makesdna`, `source/blender/makesrna`
- Contains: 96+ type definition files (DNA_*.h), RNA binding code
- Depends on: blenlib
- Used by: Kernel, editors, loaders, all domain layers
- DNA = serializable structure definitions; RNA = runtime reflection/Python API
- Purpose: Implement core 3D operations (object creation, material handling, physics, animation)
- Location: `source/blender/blenkernel`
- Contains: Object lifecycle, scene management, animation system, physics simulation, constraint solving, modifiers
- Depends on: blenlib, makesdna, intern libraries (cycles, bullet, mantaflow, etc.)
- Used by: Editors, modifiers, rendering, simulation
- Purpose: Provide mesh operations, parametric geometry, and B-Mesh (mesh topology editor)
- Location: `source/blender/bmesh`, `source/blender/geometry`
- Contains: B-Mesh topology system, mesh evaluation, curve operations, point cloud/volume handling
- Depends on: blenkernel, blenlib, geometry algorithms
- Used by: Editors (mesh/curve/object), modifiers, rendering
- Purpose: Render 3D scenes through multiple render engines
- Location: `source/blender/render`, `source/blender/draw`, `intern/cycles`
- Contains: EEVEE (real-time), Cycles (path tracer), Workbench (viewport), GPU abstraction
- Depends on: blenkernel, geometry, gpu, imbuf, external render libraries
- Used by: Viewport, final render, compositor
- Purpose: Real-time viewport rendering and overlay UI
- Location: `source/blender/draw`, `source/blender/gpu`
- Contains: Draw manager, shader system, engine-specific code (OpenGL, Vulkan, Metal), GPU memory management
- Depends on: render, geometry, blenkernel
- Used by: Window manager, editors
- Purpose: Node-based image processing and video composition
- Location: `source/blender/compositor`
- Contains: Compositor node execution, GPU scheduling, shader code generation, caching
- Depends on: gpu, imbuf, draw, blenkernel
- Used by: Render pipeline, sequencer
- Purpose: Particle systems, fluid dynamics, smoke, cloth, rigid body
- Location: `source/blender/simulation`, `intern/mantaflow`, `intern/cycles` (volume kernels)
- Contains: Particle engine, fluid solver interface, cloth constraints
- Depends on: blenkernel, geometry, external solvers
- Used by: Kernel, modifiers, rendering
- Purpose: Video editing timeline and sequencing
- Location: `source/blender/sequencer`
- Contains: Strip management, timeline evaluation, video/audio playback coordination
- Depends on: blenkernel, render, imbuf
- Used by: Editors
- Purpose: Load/save Blender files and import/export external formats
- Location: `source/blender/blenloader`, `source/blender/io`, `source/blender/blenloader_core`
- Contains: File versioning, format readers (FBX, USD, OBJ, PLY, STL, Alembic), save/load pipeline
- Depends on: makesdna, blenkernel, external format libraries
- Used by: File operations, command-line tools
- Purpose: Track data dependencies and drive computation order (evaluation)
- Location: `source/blender/depsgraph`
- Contains: Dependency building, cycle detection, evaluation scheduling
- Depends on: blenkernel, makesdna
- Used by: Kernel (evaluation), viewport updates, rendering
- Purpose: Expose Blender functionality to Python scripts and addons
- Location: `source/blender/python`, `source/blender/python/intern`, `source/blender/python/bmesh`, `source/blender/python/generic`
- Contains: Python API bindings, bpy module, bmesh API, math utilities module
- Depends on: makesrna, blenkernel, all functional layers
- Used by: Addons, scripts, REPL, operator system
- Purpose: User-facing editing interface and tools
- Location: `source/blender/editors` (40+ submodules), `source/blender/windowmanager`
- Contains: Individual editor implementations (3D viewport, shader editor, geometry nodes, etc.), operator system, undo/redo
- Depends on: All lower layers
- Used by: Application (window manager provides event loop)
- Purpose: Event loop, window management, application lifecycle, workspace management
- Location: `source/blender/windowmanager`
- Contains: Event system, window/context management, operator dispatch, gizmo system, XR support
- Depends on: editors, depsgraph, blenkernel, all functional layers, ghost (platform abstraction)
- Used by: Application entry point
- Purpose: Initialize and start application
- Location: `source/creator`, `intern/ghost` (platform-specific window/input abstraction)
- Contains: Main function, initialization sequence, command-line parsing
- Depends on: Window manager, all systems via dependency injection
- Used by: OS launch
- Purpose: Geometry nodes and shader nodes evaluation
- Location: `source/blender/nodes`, `source/blender/functions`
- Contains: Node type registry, function graphs, geometry node operations
- Depends on: blenkernel, geometry, functions framework
- Used by: Modifiers, materials, rendering
- Purpose: Asset management and library organization
- Location: `source/blender/asset_system`
- Contains: Asset metadata, catalog system, library browsing
- Depends on: blenkernel, blenlib
- Used by: Editors, file browser
- Purpose: Character animation, armatures, rigging, NLA editor
- Location: `source/blender/animrig`, `source/blender/blenkernel/intern` (nla, action, fcurve)
- Contains: IK solver, armature evaluation, action/strip evaluation
- Depends on: blenkernel, geometry, intern/iksolver, intern/itasc
- Used by: Depsgraph, editors
## Data Flow
- **Persistent**: DNA structures in memory mirror .blend file format
- **Transient**: Depsgraph, evaluated geometry caches, viewport state
- **Undo Stack**: blenkernel maintains edit history (source/blender/editors/undo)
- **Context**: Window manager tracks current scene/object/tool (DNA_screen_types)
## Key Abstractions
- Purpose: Base object for all serializable data
- Examples: `ID_OB` (Object), `ID_MA` (Material), `ID_SCE` (Scene), `ID_ME` (Mesh)
- Pattern: Reference counted, can be linked between files, versioned
- Purpose: User-invocable action (modeling tool, transform, file save)
- Examples: `MESH_OT_subdivide`, `TRANSFORM_OT_translate`, `FILE_OT_save`
- Pattern: Operator class with poll (can-execute check), execute, modal (interactive) callbacks
- Purpose: Track dependencies between data objects
- Examples: Object → Geometry → Modifier → Material
- Pattern: Directed acyclic graph, topologically sorted for evaluation
- Purpose: Procedural geometry operation
- Examples: Subdivision Surface, Boolean, Array, Geometry Nodes
- Pattern: Execute-on-demand, caching of results, deformation vs. geometry generation
- Purpose: Surface appearance definition
- Examples: BSDF nodes, texture slots
- Pattern: Node graph compiled to GPU shader at render time
- Purpose: Procedural geometry definition as node graph
- Examples: Instance on Points, Subdivide, Distribute Points on Faces
- Pattern: Lazy evaluation, cached results, Python callable interface
## Entry Points
- Location: `source/creator/blender_launcher_win32.c` or platform equivalents
- Triggers: OS launch
- Responsibilities: Parse command-line args, initialize engines, start window manager event loop
- Location: `source/blender/windowmanager/intern/wm_operators.c`
- Triggers: User action (hotkey, menu, tool), or script call
- Responsibilities: Check poll, create context, execute operator, update viewport
- Location: `source/blender/editors/io/file_ops.c`
- Triggers: File menu → Open, drag-drop file, or command-line argument
- Responsibilities: Call blenloader, versioning, addon initialization
- Location: `source/blender/render` or `intern/cycles/src/integrator.cpp`
- Triggers: Viewport draw (continuous), F12 (final render), or batch render
- Responsibilities: Build scene, compile shaders, execute render passes, composite
- Location: `source/blender/python/intern/bpy_interface.c`
- Triggers: Python REPL, addon load, or `bpy.app.handlers`
- Responsibilities: Execute Python code in Blender context, expose API
## Error Handling
- File I/O: Validation on load; version mismatch triggers auto-upgrade
- GPU: Fallback to dummy driver or Workbench if specialized driver fails
- Operators: Poll prevents execution; undo reverts on error
- Python: Exceptions caught, logged, but don't crash application
- Modifiers: If modifier fails, geometry falls back to input mesh
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
