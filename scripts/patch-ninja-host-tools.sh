#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Blender Web Authors
#
# SPDX-License-Identifier: GPL-2.0-or-later

# Fix build.ninja host tool execution for cross-compilation.
#
# Strategy:
# - makesdna + makesrna: keep the WASM executables and force them through node so
#   they generate wasm32-correct DNA/RNA artifacts.
# - datatoc + shader_tool: replace with native executables built by GCC-14.
#
# Usage:
#   ./scripts/patch-ninja-host-tools.sh <BUILD_DIR> <NATIVE_DIR>

set -euo pipefail

BUILD_DIR_INPUT="${1:?Usage: patch-ninja-host-tools.sh <BUILD_DIR> <NATIVE_DIR>}"
NATIVE_DIR_INPUT="${2:?Usage: patch-ninja-host-tools.sh <BUILD_DIR> <NATIVE_DIR>}"
BUILD_DIR="$(cd "${BUILD_DIR_INPUT}" && pwd)"
NATIVE_DIR="$(cd "${NATIVE_DIR_INPUT}" && pwd)"
PROJECT_ROOT="$(cd "${BUILD_DIR}/.." && pwd)"
NINJA_FILE="${BUILD_DIR}/build.ninja"
NINJA_BACKUP="${NINJA_FILE}.orig"
WASM_GENERATOR_WRAPPER="${PROJECT_ROOT}/scripts/run-wasm-generator.sh"
FREETYPE_PORT_LIB="/emsdk/upstream/emscripten/cache/sysroot/lib/wasm32-emscripten/libfreetype.a"
FREETYPE_PORT_WASM_SJLJ_LIB="/emsdk/upstream/emscripten/cache/sysroot/lib/wasm32-emscripten/libfreetype-legacysjlj.a"
WASM_COMPILE_PATCH_FLAGS="-pthread -msimd128 -mrelaxed-simd -fwasm-exceptions -DEMSCRIPTEN_HAS_UNBOUND_TYPE_NAMES=0 -DFE_DIVBYZERO=0 -DFE_INVALID=0 -O3"
WASM_LINK_PATCH_FLAGS="-pthread -sPROXY_TO_PTHREAD -sALLOW_BLOCKING_ON_MAIN_THREAD=0 -sPTHREAD_POOL_SIZE=navigator.hardwareConcurrency -sPTHREAD_POOL_SIZE_STRICT=0 -sALLOW_MEMORY_GROWTH=1 -sINITIAL_MEMORY=256MB -sMAXIMUM_MEMORY=4GB -sMALLOC=mimalloc -sSTACK_SIZE=2MB -fwasm-exceptions -sENVIRONMENT=web,worker,node -sEXPORTED_FUNCTIONS=_main,_wasm_init,_wasm_load_blend,_wasm_query_scene,_wasm_memory_usage -sEXPORTED_RUNTIME_METHODS=ccall,cwrap,FS,MEMFS -O3 --closure 1"
WASM_GENERATOR_NODEFS_FLAG="-sNODERAWFS=1"

sed_in_place() {
    local expr="${1:?missing sed expression}"
    local file="${2:?missing sed file}"

    if sed --version >/dev/null 2>&1; then
        sed -i "${expr}" "${file}"
    else
        sed -i '' "${expr}" "${file}"
    fi
}

echo "[patch-ninja] Patching build.ninja for native host tool execution"
echo "[patch-ninja] Build dir: ${BUILD_DIR}"
echo "[patch-ninja] Native dir: ${NATIVE_DIR}"

if [ ! -f "${NINJA_FILE}" ]; then
    echo "[patch-ninja] ERROR: build.ninja not found" >&2
    exit 1
fi

if [ ! -x "${WASM_GENERATOR_WRAPPER}" ]; then
    echo "[patch-ninja] ERROR: missing executable generator wrapper at ${WASM_GENERATOR_WRAPPER}" >&2
    exit 1
fi

# Create/restore backup for idempotent patching.
# build-wasm-full.sh deletes the backup after a fresh CMake reconfigure so this
# script can always restore a clean generator output before patching.
if [ ! -f "${NINJA_BACKUP}" ]; then
    cp "${NINJA_FILE}" "${NINJA_BACKUP}"
    echo "[patch-ninja] Created backup"
else
    cp "${NINJA_BACKUP}" "${NINJA_FILE}"
    echo "[patch-ninja] Restored from backup"
fi

# === Step 1: Replace host tool references ===
echo "[patch-ninja] Step 1: Replacing host tool references..."

for tool in makesdna makesrna datatoc shader_tool; do
    NATIVE_PATH="${NATIVE_DIR}/${tool}"
    JS_PATH="${BUILD_DIR}/bin/${tool}.js"
    JS_PATTERN="[^ ]*/bin/${tool}\\.js"
    NODE_JS_PATH="node ${JS_PATH}"

    if [ "${tool}" = "makesdna" ] || [ "${tool}" = "makesrna" ]; then
        # Keep the wasm32 generator executables for DNA/RNA correctness, but
        # route them through a wrapper so we can detect stabilized output files
        # and terminate lingering node runtimes that do not exit cleanly.
        sed_in_place "s|/emsdk/node/[^ ]*/node \\(${JS_PATTERN}\\)|bash ${WASM_GENERATOR_WRAPPER} \\1|g" "${NINJA_FILE}"
        sed_in_place "s|node \\(${JS_PATTERN}\\)|bash ${WASM_GENERATOR_WRAPPER} \\1|g" "${NINJA_FILE}"
        if ! grep -q "COMMAND = .* bash ${WASM_GENERATOR_WRAPPER} ${JS_PATTERN}" "${NINJA_FILE}"; then
            sed_in_place "s|COMMAND = \\(.*\\) \\(${JS_PATTERN}\\)\\( .*\\)|COMMAND = \\1 bash ${WASM_GENERATOR_WRAPPER} \\2\\3|g" "${NINJA_FILE}"
        fi
        echo "[patch-ninja]   ${tool}: -> bash ${WASM_GENERATOR_WRAPPER} ${JS_PATH}"
        continue
    fi

    if [ ! -x "${NATIVE_PATH}" ]; then
        echo "[patch-ninja] SKIP: ${tool} -- native executable not found at ${NATIVE_PATH}"
        continue
    fi

    # Replace "node path/bin/tool.js" with "native/tool" in COMMAND lines
    sed_in_place "s|node ${JS_PATTERN}|${NATIVE_PATH}|g" "${NINJA_FILE}"
    # Also handle cases with the full node path
    sed_in_place "s|/emsdk/node/[^ ]*/node ${JS_PATTERN}|${NATIVE_PATH}|g" "${NINJA_FILE}"
    # Handle any remaining direct .js references
    sed_in_place "s|${JS_PATTERN}|${NATIVE_PATH}|g" "${NINJA_FILE}"

    # Replace linker rule with phony rule pointing to native executable
    sed_in_place $'/^build bin\\/'"${tool}"$'\\.js: CXX_EXECUTABLE_LINKER/c\\\n''build bin/'"${tool}"$'.js: phony '"${NATIVE_PATH}" "${NINJA_FILE}"

    echo "[patch-ninja]   ${tool}: -> ${NATIVE_PATH}"
done

# === Step 1b: Inject missing global WASM flags ===
# Blender's generated ninja file currently drops the Emscripten cache flags.
# Patch the emitted compile and link flag blocks directly so the actual
# compiler/linker invocations match the intended WASM configuration.
echo "[patch-ninja] Step 1b: Injecting WASM compile/link flags..."
if grep -q "FLAGS = .*FE_DIVBYZERO=0" "${NINJA_FILE}"; then
    echo "[patch-ninja]   compile flags already include FE overrides"
else
    sed_in_place "s|^  FLAGS = \\(.*\\)$|  FLAGS = \\1 ${WASM_COMPILE_PATCH_FLAGS}|g" "${NINJA_FILE}"
fi

if grep -q "LINK_FLAGS = .*PTHREAD_POOL_SIZE" "${NINJA_FILE}" && \
    grep -q "LINK_FLAGS = .*EXPORTED_FUNCTIONS" "${NINJA_FILE}"; then
    echo "[patch-ninja]   link flags already include WASM runtime settings"
else
    sed_in_place "s|^  LINK_FLAGS = \\(.*\\)$|  LINK_FLAGS = \\1 ${WASM_LINK_PATCH_FLAGS}|g" "${NINJA_FILE}"
fi

# The default Emscripten freetype port archive is built with the incompatible
# JS-based longjmp mode. Our Wasm-exception build needs the legacy-SjLj
# compatible variant instead.
if grep -q "${FREETYPE_PORT_LIB}" "${NINJA_FILE}"; then
    sed_in_place "s|${FREETYPE_PORT_LIB}|${FREETYPE_PORT_WASM_SJLJ_LIB}|g" "${NINJA_FILE}"
    echo "[patch-ninja]   freetype archive rewritten to legacy-SjLj variant"
else
    echo "[patch-ninja]   freetype archive already rewritten or not present"
fi

# === Step 2: Validate WASM generator wiring ===
echo "[patch-ninja] Step 2: Validating WASM generator wiring..."
for tool in makesdna makesrna; do
    TOOL_BUILD_LINE="$(grep -n "^build bin/${tool}\\.js:" "${NINJA_FILE}" | cut -d: -f1 | head -1 || true)"
    if [ -z "${TOOL_BUILD_LINE}" ]; then
        echo "[patch-ninja] WARNING: ${tool} link block not found"
        continue
    fi

    TOOL_LINK_FLAGS_LINE=$((TOOL_BUILD_LINE + 2))
    sed_in_place "${TOOL_LINK_FLAGS_LINE}s| -sEXPORTED_FUNCTIONS=[^ ]*||g" "${NINJA_FILE}"
    sed_in_place "${TOOL_LINK_FLAGS_LINE}s| -sEXPORTED_RUNTIME_METHODS=[^ ]*||g" "${NINJA_FILE}"
    if sed -n "${TOOL_LINK_FLAGS_LINE}p" "${NINJA_FILE}" | grep -q -- "${WASM_GENERATOR_NODEFS_FLAG}"; then
        echo "[patch-ninja]   ${tool} link flags already include ${WASM_GENERATOR_NODEFS_FLAG}"
    else
        sed_in_place "${TOOL_LINK_FLAGS_LINE}s|$| ${WASM_GENERATOR_NODEFS_FLAG}|g" "${NINJA_FILE}"
        echo "[patch-ninja]   ${tool} link flags restored ${WASM_GENERATOR_NODEFS_FLAG} for Node filesystem access"
    fi
    echo "[patch-ninja]   ${tool} link flags stripped of final runtime exports"
done

# === Step 3: Validation ===
echo "[patch-ninja] Step 3: Validating..."

for tool in datatoc shader_tool; do
    if grep -q "^build bin/${tool}.js: phony" "${NINJA_FILE}"; then
        echo "[patch-ninja] PASS: ${tool} phony rule exists"
    fi
done

# Check for remaining native-tool COMMAND references to .js wrappers.
NATIVE_CMD_JS=$(grep "COMMAND = " "${NINJA_FILE}" | grep -c "bin/\(datatoc\|shader_tool\)\.js" 2>/dev/null || true)
if [ "${NATIVE_CMD_JS}" -gt 0 ]; then
    echo "[patch-ninja] WARNING: ${NATIVE_CMD_JS} native host tool COMMAND references still point to .js"
else
    echo "[patch-ninja] PASS: native host tool COMMAND references use native binaries"
fi

MAKESDNA_WRAPPED=$(grep "COMMAND = " "${NINJA_FILE}" | grep -c "run-wasm-generator\\.sh .*bin/makesdna\\.js" 2>/dev/null || true)
if [ "${MAKESDNA_WRAPPED}" -gt 0 ]; then
    echo "[patch-ninja] PASS: makesdna COMMAND uses generator wrapper"
fi

MAKESRNA_WRAPPED=$(grep "COMMAND = " "${NINJA_FILE}" | grep -c "run-wasm-generator\\.sh .*bin/makesrna\\.js" 2>/dev/null || true)
if [ "${MAKESRNA_WRAPPED}" -gt 0 ]; then
    echo "[patch-ninja] PASS: makesrna COMMAND uses generator wrapper"
fi

if grep -A 2 "^build bin/makesdna\\.js:" "${NINJA_FILE}" | grep -q "EXPORTED_FUNCTIONS"; then
    echo "[patch-ninja] WARNING: makesdna still exports final runtime symbols"
else
    echo "[patch-ninja] PASS: makesdna link flags only contain auxiliary runtime settings"
fi

if grep -A 2 "^build bin/makesrna\\.js:" "${NINJA_FILE}" | grep -q "EXPORTED_FUNCTIONS"; then
    echo "[patch-ninja] WARNING: makesrna still exports final runtime symbols"
else
    echo "[patch-ninja] PASS: makesrna link flags only contain auxiliary runtime settings"
fi

if grep -A 2 "^build bin/makesdna\\.js:" "${NINJA_FILE}" | grep -q -- "${WASM_GENERATOR_NODEFS_FLAG}"; then
    echo "[patch-ninja] PASS: makesdna link flags include ${WASM_GENERATOR_NODEFS_FLAG}"
else
    echo "[patch-ninja] WARNING: makesdna link flags are missing ${WASM_GENERATOR_NODEFS_FLAG}"
fi

if grep -A 2 "^build bin/makesrna\\.js:" "${NINJA_FILE}" | grep -q -- "${WASM_GENERATOR_NODEFS_FLAG}"; then
    echo "[patch-ninja] PASS: makesrna link flags include ${WASM_GENERATOR_NODEFS_FLAG}"
else
    echo "[patch-ninja] WARNING: makesrna link flags are missing ${WASM_GENERATOR_NODEFS_FLAG}"
fi

if grep -q "FLAGS = .*FE_DIVBYZERO=0" "${NINJA_FILE}" && \
    grep -q "FLAGS = .*msimd128" "${NINJA_FILE}"; then
    echo "[patch-ninja] PASS: compile flags include Emscripten overrides"
else
    echo "[patch-ninja] WARNING: compile flag injection missing expected overrides"
fi

if grep -q "LINK_FLAGS = .*PTHREAD_POOL_SIZE" "${NINJA_FILE}" && \
    grep -q "LINK_FLAGS = .*EXPORTED_FUNCTIONS" "${NINJA_FILE}"; then
    echo "[patch-ninja] PASS: link flags include Emscripten runtime settings"
else
    echo "[patch-ninja] WARNING: link flag injection missing expected overrides"
fi

if grep -q "${FREETYPE_PORT_WASM_SJLJ_LIB}" "${NINJA_FILE}"; then
    echo "[patch-ninja] PASS: freetype archive points to legacy-SjLj variant"
else
    echo "[patch-ninja] WARNING: freetype archive still points to the default port library"
fi

echo "[patch-ninja] Patching complete."
