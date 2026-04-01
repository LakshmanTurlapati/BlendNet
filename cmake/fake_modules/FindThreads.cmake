# Fake Threads finder for Emscripten WASM builds
# Emscripten provides pthreads via -pthread flag
set(Threads_FOUND TRUE)
set(CMAKE_THREAD_LIBS_INIT "-pthread")
set(CMAKE_USE_PTHREADS_INIT TRUE)
set(Threads_FOUND TRUE)
if(NOT TARGET Threads::Threads)
  add_library(Threads::Threads INTERFACE IMPORTED)
  set_target_properties(Threads::Threads PROPERTIES
    INTERFACE_COMPILE_OPTIONS "-pthread"
    INTERFACE_LINK_OPTIONS "-pthread"
  )
endif()
