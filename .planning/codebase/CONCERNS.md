# Codebase Concerns

**Analysis Date:** 2026-04-01

## Overview

This is the Blender 3D creation suite codebase, a large C++ project with ~2.4 million lines of code across the source directory. The analysis identified 5,670+ TODO/FIXME/HACK comments indicating widespread technical debt across multiple subsystems.

## Tech Debt

**Interface Handlers Event System:**
- Issue: Large monolithic event handling file (12,926 lines) with fragile feature flags rather than proper refactoring
- Files: `source/blender/editors/interface/interface_handlers.cc`
- Impact: Difficult to maintain, test, and extend UI interaction logic; increased risk of regression when modifying input handling
- Fix approach: Refactor into smaller, composable handler modules; replace feature defines with proper abstraction layers
- Context: Code comment at line 93 explicitly states "Ideally the code would be refactored to support this functionality in a less fragile way"

**Mesh Data Update Memory Leak:**
- Issue: Potential memory leak and assertion failures in mesh evaluation workflow
- Files: `source/blender/blenkernel/intern/mesh_data_update.cc` (lines 1165, 1224)
- Impact: Object evaluation may leak memory or crash when modifiers are applied; data corruption possible
- Fix approach: Refactor object evaluation to properly manage ownership of evaluated mesh data; audit all paths where `BKE_object_eval_assign_data` is called
- Symptom: The block runs `BKE_object_eval_assign_data` within a context that may invalidate previous data without proper cleanup

**File Reader Include Complexity:**
- Issue: GPU and context includes create problematic dependencies
- Files: `source/blender/gpu/intern/gpu_vertex_buffer.cc`, `source/blender/gpu/opengl/gl_context.cc`, `source/blender/gpu/opengl/gl_texture.cc`
- Impact: Build coupling, circular dependencies possible, harder to isolate GPU subsystem
- Fix approach: Create proper abstraction layer for context access; remove private header includes from public interfaces

**Asset Catalog Multi-File Support:**
- Issue: Asset system designed for single catalog definition file (CDF), but infrastructure incomplete for multiple CDFs
- Files: `source/blender/asset_system/intern/asset_catalog.cc` (15+ TODO comments)
- Impact: Cannot manage complex asset libraries with multiple catalog sources; limits enterprise usage
- Fix approach: Implement proper multi-CDF architecture before expanding asset system features; audit all single-CDF assumptions

## Known Bugs

**Freestyle BBox Computation:**
- Issue: Bbox update computation is incomplete or incorrect
- Files: `source/blender/freestyle/intern/application/Controller.cpp` (line 271)
- Trigger: Rendering with Freestyle enabled produces incorrect bounding box calculations
- Workaround: Manual bbox computation or disabling certain Freestyle features
- Impact: Incorrect culling and rendering optimization may occur

**Outliner Tool Checks:**
- Issue: Selection/checking logic appears broken, possibly unimplemented
- Files: `source/blender/editors/space_outliner/outliner_tools.cc` (multiple locations)
- Symptoms: Outliner operations behave inconsistently; unclear selection state
- Impact: User confusion and inability to perform reliable outliner operations

**Deprecated Format Handling:**
- Issue: GPU vertex format has hardcoded workaround for deprecated formats
- Files: `source/blender/gpu/intern/gpu_vertex_format.cc`
- Impact: Emits compiler warnings; masks underlying deprecation issues

**NURBS Cyclic Curve Data Loss:**
- Issue: Custom primvars cannot be read/written for cyclic NURBS curves in USD/Alembic I/O
- Files: `source/blender/io/usd/intern/usd_reader_nurbs.cc`, `source/blender/io/usd/intern/usd_writer_curves.cc`, `source/blender/io/alembic/intern/abc_util.cc`
- Impact: Data loss when importing/exporting cyclic NURBS curves from other applications
- Fix approach: Extend I/O plugins to handle cyclic NURBS primvar serialization

## Performance Bottlenecks

**Dependency Graph Component Lookup:**
- Problem: Component lookup is "somewhat slow"
- Files: `source/blender/depsgraph/intern/node/deg_node_component.cc`
- Cause: Linear search or inefficient hash table usage in depsgraph traversal
- Improvement path: Profile and optimize component lookup using better data structures; cache frequently accessed components
- Impact: High on complex scenes with many dependencies

**Image Texture Acquisition in Paint Operations:**
- Problem: `BKE_image_acquire_ibuf` is marked as potentially slow in texture painting
- Files: `source/blender/editors/sculpt_paint/mesh/paint_image_proj.cc`
- Cause: Texture buffer allocation/loading on every acquisition
- Improvement path: Implement lazy loading and caching of image buffers; pre-allocate in modal operator initialization
- Impact: Noticeable lag in image paint mode on large textures

**Mesh Extractors GPU Performance:**
- Problem: HORRENDOUS performance in normal and paint overlay flag extraction
- Files: `source/blender/draw/intern/mesh_extractors/extract_mesh_vbo_lnor.cc`, `source/blender/draw/intern/mesh_extractors/extract_mesh_vbo_paint_overlay_flag.cc`
- Cause: CPU-side buffer clearing instead of device-side clears; inefficient data transfer
- Improvement path: Use GPU compute shaders or device memory clears for buffer initialization
- Impact: Slow viewport performance on high-poly meshes

**Outline Pass Performance:**
- Problem: Outline pass performance degradation with certain object counts
- Files: `source/blender/draw/engines/overlay/overlay_instance.cc`
- Cause: Inefficient pass splitting when outline is computed
- Impact: Real-time viewport becomes choppy with moderate polycount scenes

**Sculpt Boundary Smooth Performance:**
- Problem: Boundary smoothing cannot use multi-threading due to internal threading conflicts
- Files: `source/blender/editors/sculpt_paint/mesh/sculpt_boundary.cc`
- Cause: Nested threading in sculpt system
- Fix approach: Refactor to use thread-pool groups instead of internal threading

**Memory Consumption Tracking:**
- Problem: Sculpt undo memory calculation is not entirely accurate
- Files: `source/blender/editors/sculpt_paint/mesh/sculpt_undo.cc`
- Cause: Incomplete accounting of all memory consumers in undo stack
- Impact: Unreliable memory warnings and potential out-of-memory crashes

## Security Considerations

**Unsafe Casts:**
- Risk: 9,492 unsafe casts (const_cast, reinterpret_cast) throughout codebase
- Files: Widespread across all modules
- Current mitigation: Type system provides some compile-time safety
- Recommendations: Audit all const_cast usage for legitimacy; consider using wrapper types instead of reinterpret_cast

**Remote Asset Library Type Casting:**
- Risk: Casting away const in context handling for remote asset libraries
- Files: `source/blender/asset_system/intern/library_types/remote_library.cc`
- Impact: Potential thread safety issues; const correctness violations
- Recommendations: Pass context copies instead of casting; implement proper const-safe context API

**Incomplete Error Handling in Asset System:**
- Risk: Multiple locations silently ignore errors or have incomplete error reporting
- Files: `source/blender/asset_system/intern/asset_catalog.cc`, `source/blender/asset_system/intern/asset_catalog_definition_file.cc`
- Impact: Asset loading failures propagate silently to UI
- Recommendations: Implement comprehensive error reporting; add user-visible diagnostics

## Fragile Areas

**Blender File Format Versioning:**
- Files: `source/blender/blenloader/intern/versioning_*.cc` (multiple versions: 250, 270, 420, 450, 500, 520)
- Why fragile: Complex interdependencies between version upgrade paths; manual data migration code scattered across files
- Safe modification: Document all assumptions before modifying version checks; add test cases for upgrade paths
- Test coverage: Limited test coverage for edge cases in old file format handling

**Depsgraph Query and Evaluation:**
- Files: `source/blender/depsgraph/intern/depsgraph_query.cc`, `source/blender/depsgraph/intern/depsgraph_tag.cc`, `source/blender/depsgraph/intern/builder/deg_builder_relations.cc`
- Why fragile: Multiple TODO comments about missing data-block handling (images don't use copy-on-eval); incomplete tracing
- Safe modification: Add extensive testing before changing evaluation order; document all assumptions about COW behavior
- Test coverage: Limited coverage of complex dependency scenarios

**Edit Mesh Cache System:**
- Problem: Multiple code paths depend on edit mesh state synchronization
- Files: All files using `BKE_editmesh.hh` and `BKE_editmesh_cache.hh`
- Risk: Stale cache causes rendering and edit operation failures
- Recommendations: Add cache validation assertions; implement automatic cache invalidation

**GPU Shader Compilation and Linting:**
- Files: `source/blender/gpu/shader_tool/processor.cc`
- Fragility: Shader linting has known false positives and cannot detect vector/matrix type safety issues
- Impact: Subtle GPU shader bugs may not be caught until runtime
- Fix approach: Improve shader linter with vector/matrix type awareness

**Import/Export Format Handling:**
- Files: `source/blender/io/usd/`, `source/blender/io/alembic/`, `source/blender/io/common/`
- Why fragile: Multiple TODO items about incomplete feature support and workarounds
- Examples: Cyclic NURBS curves, cyclic UV reading, material export in-memory textures
- Test coverage: Test files exist but may not cover all edge cases

## Scaling Limits

**Animation Frame Caching:**
- Current capacity: Designed for typical animation clips
- Limit: NLA strip time evaluation "could get quite slow for doing this on many strips"
- Files: `source/blender/blenkernel/intern/nla.cc`
- Scaling path: Implement frame result caching; optimize strip time lookup with binary search or interval trees

**Sequencer Performance:**
- Limit: Internal use of `startdisp` causes poor performance with complex sequences
- Files: `source/blender/editors/space_sequencer/sequencer_edit.cc`
- Current workaround: Disabled for performance, but original issue remains
- Scaling path: Refactor internal sequencer representation to avoid linear searches

**Viewport Object Count:**
- Limit: Outline rendering performance degrades with moderate object counts
- Threshold: Not explicitly documented; appears to be around 1000+ objects
- Scaling path: Implement hierarchical culling; batch outline computation

**Mesh Subdivision Surface:**
- Current limitation: "Allocate memory for loose elements" TODO suggests incomplete support
- Files: `source/blender/blenkernel/intern/subdiv_ccg.cc`
- Impact: High-poly subdivision may not handle all topology correctly
- Fix approach: Complete loose element handling

## Dependencies at Risk

**OpenGL Context Management:**
- Risk: GPU backend has multiple include-based dependencies on private context implementation
- Files: `source/blender/gpu/opengl/gl_*.cc` (multiple files)
- Impact: Difficult to switch GPU backends; tight coupling to OpenGL
- Migration plan: Implement complete abstraction layer for GPU context; remove private include dependencies

**Asset Library Multi-File Support (Feature Risk):**
- Risk: Asset system APIs assume single catalog file; multi-file support is incomplete
- Files: Core asset system modules
- Migration plan: Before full multi-file support, architect proper multi-CDF API; version asset system API

## Missing Critical Features

**Asset Library Remote Sync:**
- Problem: Remote asset libraries have incomplete error communication to UI
- Blocks: Cannot reliably manage assets from network storage
- Files: `source/blender/asset_system/intern/library_types/remote_library.cc`
- Recommendation: Implement robust error reporting and retry logic

**Geometry Nodes List Support:**
- Problem: List type support incomplete; placeholder code blocks execution
- Blocks: Cannot use geometry node lists fully
- Files: `source/blender/blenkernel/intern/node_socket_value.cc`
- Status: Waiting for `use_geometry_nodes_lists` feature gate removal

**Data-block Copy-on-Write (COW) Completeness:**
- Problem: Image data-blocks do not use COW, causing incomplete depsgraph detection
- Files: `source/blender/depsgraph/intern/eval/deg_eval_flush.cc`
- Impact: Image changes may not properly invalidate downstream nodes
- Recommendation: Implement COW for image data-blocks or document why it's not needed

## Test Coverage Gaps

**Event Handler Coverage:**
- What's not tested: Complex input event sequences, modal operator state transitions
- Files: `source/blender/editors/interface/interface_handlers.cc`
- Risk: Regression in UI interaction could go undetected
- Priority: High (affects user experience directly)

**Depsgraph Edge Cases:**
- What's not tested: Circular dependency detection, complex override scenarios
- Files: `source/blender/depsgraph/intern/`
- Risk: File loading could fail silently with complex linked data
- Priority: High (data loss potential)

**Versioning Edge Cases:**
- What's not tested: Upgrade paths for rarely-used features, file format combinations
- Files: `source/blender/blenloader/intern/versioning_*.cc`
- Risk: Old files may not load correctly in new versions
- Priority: Medium (affects legacy file support)

**UV Packing with Degenerate Input:**
- What's not tested: Degenerate triangles and edge cases in UV layout
- Files: `source/blender/geometry/intern/uv_pack.cc`
- Risk: Poor performance or incorrect packing with malformed input
- Priority: Medium (can be worked around by fixing models)

**Mesh Validation:**
- What's not tested: Full validation enabled (uses debug flag `USE_MODIFIER_VALIDATE`)
- Files: `source/blender/blenkernel/intern/mesh_data_update.cc` (line 56)
- Risk: Mesh corruption undetected in production builds
- Priority: Medium-High (data integrity)

---

*Concerns audit: 2026-04-01*
