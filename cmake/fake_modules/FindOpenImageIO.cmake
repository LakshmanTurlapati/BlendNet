# Fake OpenImageIO finder for Emscripten WASM builds
set(OpenImageIO_FOUND TRUE)
set(OPENIMAGEIO_FOUND TRUE)
# Use stub headers from cmake/stubs/
get_filename_component(_STUB_DIR "${CMAKE_CURRENT_LIST_DIR}/../stubs" ABSOLUTE)
set(OPENIMAGEIO_INCLUDE_DIRS "${_STUB_DIR}")
set(OPENIMAGEIO_LIBRARIES "")
set(OPENIMAGEIO_LIBRARY "")
set(OPENIMAGEIO_PUGIXML_FOUND TRUE)
set(OpenImageIO_VERSION "2.5.0")
set(OIIO_HAS_OPENEXR_CORE TRUE)
if(NOT TARGET OpenImageIO::OpenImageIO)
  add_library(OpenImageIO::OpenImageIO INTERFACE IMPORTED)
  set_target_properties(OpenImageIO::OpenImageIO PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${_STUB_DIR}"
  )
endif()
if(NOT TARGET OpenImageIO::oiiotool)
  add_library(OpenImageIO::oiiotool INTERFACE IMPORTED)
  set_target_properties(OpenImageIO::oiiotool PROPERTIES
    IMPORTED_LOCATION "oiiotool_stub"
  )
endif()
if(NOT TARGET OpenImageIO::OpenImageIO_Util)
  add_library(OpenImageIO::OpenImageIO_Util INTERFACE IMPORTED)
endif()
