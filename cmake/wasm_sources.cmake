# SPDX-FileCopyrightText: 2026 Blender Web Authors
#
# SPDX-License-Identifier: GPL-2.0-or-later

# CMake configuration for the custom WASM headless entry point.
#
# This file defines the source files and include paths required to compile
# source/wasm_headless_main.cc alongside Blender's core libraries. It is
# included during the WASM build's CMake configuration step.
#
# The custom entry point replaces Blender's standard creator.cc and provides
# exported C functions (wasm_init, wasm_load_blend, wasm_query_scene,
# wasm_memory_usage) callable from JavaScript.
#
# Depends on: cmake/emscripten_overrides.cmake (compile/link flags)

# =============================================================================
# Include WASM compile and link flags
# =============================================================================

include("${CMAKE_CURRENT_LIST_DIR}/emscripten_overrides.cmake")

# =============================================================================
# Custom Entry Point Source
# =============================================================================

# Path to the project root (one level above cmake/)
get_filename_component(BLENDER_WEB_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

set(WASM_ENTRY_POINT_SRC
  "${BLENDER_WEB_ROOT}/source/wasm_headless_main.cc"
)

# =============================================================================
# Include Paths for Blender Headers
# =============================================================================

# These paths are relative to the Blender source tree and provide access to
# the headers needed by the custom entry point:
#   - blenkernel: BKE_blendfile.hh, BKE_main.hh, BKE_global.hh, BKE_blender.hh
#   - blenlib:    BLI_listbase.h, BLI_compiler_attrs.h, BLI_sys_types.h
#   - makesdna:   DNA_scene_types.h, DNA_object_types.h, DNA_ID.h, DNA_listBase.h
#   - makesrna:   RNA type definitions (future use)
#   - blenloader: BLO_readfile.hh (blend-file loading API)
#   - guardedalloc: MEM_guardedalloc.h (memory tracking)
#   - clog:       CLG_log.h (logging)

set(WASM_BLENDER_INCLUDE_DIRS
  # Core kernel
  "${BLENDER_SRC}/source/blender/blenkernel"

  # Utility library
  "${BLENDER_SRC}/source/blender/blenlib"

  # DNA type definitions (file format structs)
  "${BLENDER_SRC}/source/blender/makesdna"

  # RNA reflection/scripting interface
  "${BLENDER_SRC}/source/blender/makesrna"

  # Blend-file loader
  "${BLENDER_SRC}/source/blender/blenloader"

  # Guarded memory allocator
  "${BLENDER_SRC}/intern/guardedalloc"

  # Logging
  "${BLENDER_SRC}/intern/clog"
)

message(STATUS "[wasm_sources] Custom entry point: ${WASM_ENTRY_POINT_SRC}")
message(STATUS "[wasm_sources] Blender include dirs: ${WASM_BLENDER_INCLUDE_DIRS}")
