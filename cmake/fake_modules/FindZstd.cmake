# Fake Zstd finder for Emscripten WASM builds
set(Zstd_FOUND TRUE)
set(ZSTD_FOUND TRUE)
set(ZSTD_INCLUDE_DIRS "")
set(ZSTD_LIBRARIES "")
set(ZSTD_LIBRARY "")
if(NOT TARGET zstd::zstd)
  add_library(zstd::zstd INTERFACE IMPORTED)
endif()
