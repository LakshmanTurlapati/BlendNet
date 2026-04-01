# Fake JPEG finder for Emscripten WASM builds
set(JPEG_FOUND TRUE)
set(JPEG_INCLUDE_DIRS "")
set(JPEG_LIBRARIES "")
set(JPEG_LIBRARY "")
set(JPEG_INCLUDE_DIR "")
if(NOT TARGET JPEG::JPEG)
  add_library(JPEG::JPEG INTERFACE IMPORTED)
endif()
