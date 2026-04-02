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
  CACHE FILEPATH "Custom headless WASM entry point source"
  FORCE
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

set(_WASM_BLENDER_INCLUDE_DIRS
  # Core kernel
  "${BLENDER_WEB_ROOT}/Blender Mirror/source/blender/blenkernel"

  # Utility library
  "${BLENDER_WEB_ROOT}/Blender Mirror/source/blender/blenlib"

  # DNA type definitions (file format structs)
  "${BLENDER_WEB_ROOT}/Blender Mirror/source/blender/makesdna"

  # RNA reflection/scripting interface
  "${BLENDER_WEB_ROOT}/Blender Mirror/source/blender/makesrna"

  # Blend-file loader
  "${BLENDER_WEB_ROOT}/Blender Mirror/source/blender/blenloader"

  # Font system
  "${BLENDER_WEB_ROOT}/Blender Mirror/source/blender/blenfont"

  # Depsgraph public headers
  "${BLENDER_WEB_ROOT}/Blender Mirror/source/blender/depsgraph"

  # Editor public headers (datatoc font declarations)
  "${BLENDER_WEB_ROOT}/Blender Mirror/source/blender/editors/include"

  # Guarded memory allocator
  "${BLENDER_WEB_ROOT}/Blender Mirror/intern/guardedalloc"

  # ImBuf
  "${BLENDER_WEB_ROOT}/Blender Mirror/source/blender/imbuf"

  # Logging
  "${BLENDER_WEB_ROOT}/Blender Mirror/intern/clog"

  # Sequencer public headers
  "${BLENDER_WEB_ROOT}/Blender Mirror/source/blender/sequencer"

  # Window-manager internals used for the dummy runtime
  "${BLENDER_WEB_ROOT}/Blender Mirror/source/blender/windowmanager"
)

set(WASM_BLENDER_INCLUDE_DIRS
  "${_WASM_BLENDER_INCLUDE_DIRS}"
  CACHE STRING "Blender include paths for the custom WASM entry point"
  FORCE
)
unset(_WASM_BLENDER_INCLUDE_DIRS)

message(STATUS "[wasm_sources] Custom entry point: ${WASM_ENTRY_POINT_SRC}")
message(STATUS "[wasm_sources] Blender include dirs: ${WASM_BLENDER_INCLUDE_DIRS}")
