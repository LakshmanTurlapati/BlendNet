# Fake Freetype finder for Emscripten WASM builds
# Emscripten provides freetype via -sUSE_FREETYPE=1
set(Freetype_FOUND TRUE)
set(FREETYPE_FOUND TRUE)
set(FREETYPE_INCLUDE_DIRS "/tmp/emsdk/upstream/emscripten/cache/sysroot/include/freetype2")
set(FREETYPE_LIBRARIES "")
set(FREETYPE_LIBRARY "freetype")
set(FREETYPE_VERSION_STRING "2.13.0")
# Skip brotli check
function(check_freetype_for_brotli)
endfunction()
if(NOT TARGET Freetype::Freetype)
  add_library(Freetype::Freetype INTERFACE IMPORTED)
endif()
