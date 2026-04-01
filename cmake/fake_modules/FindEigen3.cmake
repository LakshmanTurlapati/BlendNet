# Fake Eigen3 finder for Emscripten WASM builds
# Eigen is header-only
set(Eigen3_FOUND TRUE)
set(EIGEN3_FOUND TRUE)
set(EIGEN3_INCLUDE_DIRS "")
set(EIGEN3_VERSION "3.4.0")
if(NOT TARGET Eigen3::Eigen)
  add_library(Eigen3::Eigen INTERFACE IMPORTED)
endif()
