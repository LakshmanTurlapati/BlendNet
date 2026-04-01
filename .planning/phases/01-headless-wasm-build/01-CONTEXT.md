# Phase 1: Headless WASM Build - Context

**Gathered:** 2026-04-01
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase -- discuss skipped)

<domain>
## Phase Boundary

Blender's core engine compiles to WebAssembly and can load/query scene data without any display. This phase establishes the build system foundation: Emscripten toolchain integration with Blender's CMake build, dependency compilation/stubbing, threading via pthreads/Web Workers, memory management within WASM32 4GB, SIMD enablement, non-blocking main loop conversion, and compressed binary serving.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion -- pure infrastructure phase. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions. Key technical references:
- Research: .planning/research/STACK.md (Emscripten 5.0.4, emdawnwebgpu, PROXY_TO_PTHREAD)
- Research: .planning/research/ARCHITECTURE.md (build order, dependency chain)
- Research: .planning/research/PITFALLS.md (main thread blocking, Asyncify avoidance, dependency failures)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CMakeLists.txt` at project root -- existing CMake build system
- `source/blender/gpu/dummy/` -- Dummy GPU backend (use for headless build)
- `intern/ghost/intern/GHOST_SystemHeadless.*` -- Headless GHOST backend
- `GNUmakefile` and `make.bat` -- Alternative build entry points

### Established Patterns
- CMake-based build with `WITH_*` feature flags for conditional compilation
- Layered architecture: blenlib -> makesdna -> blenkernel -> editors -> windowmanager
- MEM_guarded_alloc for memory tracking

### Integration Points
- Emscripten toolchain file replaces native compiler via `emcmake cmake`
- GHOST_SystemSDL may serve as browser platform backend (Phase 2)
- Dummy GPU backend disables all rendering (appropriate for headless build)

</code_context>

<specifics>
## Specific Ideas

No specific requirements -- infrastructure phase. Refer to ROADMAP phase description and success criteria.

</specifics>

<deferred>
## Deferred Ideas

None -- infrastructure phase.

</deferred>
