# SPDX-FileCopyrightText: 2026 Blender Web Authors
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Override unconditional REQUIRED dependencies for Emscripten WASM builds.
# Blender's platform_unix.cmake has several find_package(... REQUIRED) calls
# that are unconditional (no WITH_* guard). For WASM headless builds, many
# of these libraries are unnecessary. This file provides stubs.
#
# Usage: Include via -DCMAKE_MODULE_PATH pointing to this directory's Modules/
# or inject before platform_unix.cmake is processed.

# Provide stub OpenImageIO if not found
if(NOT OpenImageIO_FOUND)
  set(OPENIMAGEIO_FOUND TRUE)
  set(OPENIMAGEIO_INCLUDE_DIRS "${CMAKE_CURRENT_LIST_DIR}/stubs")
  set(OPENIMAGEIO_LIBRARIES "")
  set(OPENIMAGEIO_IDIFF "")
  set(OPENIMAGEIO_VERSION "2.5.0")
  # Create imported target that Blender references
  if(NOT TARGET OpenImageIO::OpenImageIO)
    add_library(OpenImageIO::OpenImageIO INTERFACE IMPORTED)
    set_target_properties(OpenImageIO::OpenImageIO PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_LIST_DIR}/stubs"
    )
  endif()
  message(STATUS "OpenImageIO: Using WASM stub (headless build)")
endif()
