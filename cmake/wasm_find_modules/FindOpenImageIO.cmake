# Stub FindOpenImageIO for WASM headless builds.
# OpenImageIO is unconditionally REQUIRED in platform_unix.cmake but
# not needed for headless WASM builds with WITH_OPENIMAGEIO=OFF.

set(OPENIMAGEIO_FOUND TRUE)
set(OpenImageIO_FOUND TRUE)
set(OPENIMAGEIO_INCLUDE_DIRS "${CMAKE_CURRENT_LIST_DIR}/../stubs")
set(OPENIMAGEIO_LIBRARIES "")
set(OPENIMAGEIO_PUGIXML_FOUND FALSE)
set(OPENIMAGEIO_IDIFF "")
set(OPENIMAGEIO_VERSION "2.5.0")

if(NOT TARGET OpenImageIO::OpenImageIO)
  add_library(OpenImageIO::OpenImageIO INTERFACE IMPORTED)
  set_target_properties(OpenImageIO::OpenImageIO PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_LIST_DIR}/../stubs"
  )
endif()

if(NOT TARGET OpenImageIO::oiiotool)
  add_library(OpenImageIO::oiiotool INTERFACE IMPORTED)
  set_target_properties(OpenImageIO::oiiotool PROPERTIES
    IMPORTED_LOCATION "/usr/bin/true"
  )
  set(OPENIMAGEIO_TOOL "/usr/bin/true")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(OpenImageIO DEFAULT_MSG OPENIMAGEIO_INCLUDE_DIRS)
