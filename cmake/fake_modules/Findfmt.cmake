# Fake fmt finder for Emscripten WASM builds
# fmt is header-only, so we just need the include path
set(fmt_FOUND TRUE)
set(fmt_VERSION "10.0.0")
set(fmt_INCLUDE_DIRS "/opt/homebrew/opt/fmt/include")
if(NOT TARGET fmt::fmt)
  add_library(fmt::fmt INTERFACE IMPORTED)
  set_target_properties(fmt::fmt PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "/opt/homebrew/opt/fmt/include"
  )
endif()
if(NOT TARGET fmt::fmt-header-only)
  add_library(fmt::fmt-header-only INTERFACE IMPORTED)
  set_target_properties(fmt::fmt-header-only PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "/opt/homebrew/opt/fmt/include"
    INTERFACE_COMPILE_DEFINITIONS "FMT_HEADER_ONLY=1"
  )
endif()
