#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Blender Web Authors
#
# SPDX-License-Identifier: GPL-2.0-or-later

# Fix build.ninja host tool execution for cross-compilation.
#
# Hybrid approach:
#   - datatoc + shader_tool: Replace with native executables (architecture-independent
#     output -- they generate C arrays and shader metadata, not DNA structs)
#   - makesdna + makesrna: Keep as WASM .js running via Node.js (they generate
#     architecture-specific struct layouts and MUST produce WASM32 output)
#
# For datatoc/shader_tool, the WASM .js linker rules are replaced with phony
# rules pointing to the native executables. For makesdna/makesrna, CMake already
# sets CMAKE_CROSSCOMPILING_EMULATOR=node to prepend "node" to COMMAND lines,
# but may double it. We fix the "node node" -> "node" issue.
#
# Usage:
#   ./scripts/patch-ninja-host-tools.sh <BUILD_DIR> <NATIVE_DIR>

set -euo pipefail

BUILD_DIR="${1:?Usage: patch-ninja-host-tools.sh <BUILD_DIR> <NATIVE_DIR>}"
NATIVE_DIR="${2:?Usage: patch-ninja-host-tools.sh <BUILD_DIR> <NATIVE_DIR>}"
NINJA_FILE="${BUILD_DIR}/build.ninja"

echo "[patch-ninja] Patching build.ninja for hybrid host tool execution"
echo "[patch-ninja] Build dir: ${BUILD_DIR}"
echo "[patch-ninja] Native dir: ${NATIVE_DIR}"

if [ ! -f "${NINJA_FILE}" ]; then
    echo "[patch-ninja] ERROR: build.ninja not found" >&2
    exit 1
fi

# Create backup
if [ ! -f "${NINJA_FILE}.orig" ]; then
    cp "${NINJA_FILE}" "${NINJA_FILE}.orig"
    echo "[patch-ninja] Created backup"
else
    cp "${NINJA_FILE}.orig" "${NINJA_FILE}"
    echo "[patch-ninja] Restored from backup"
fi

# === Fix 1: Fix doubled "node node" -> "node" ===
DOUBLE_COUNT=$(grep -c "node node " "${NINJA_FILE}" 2>/dev/null || true)
if [ "${DOUBLE_COUNT}" -gt 0 ]; then
    sed -i 's|node node |node |g' "${NINJA_FILE}"
    echo "[patch-ninja] Fixed ${DOUBLE_COUNT} doubled 'node node' references"
fi

# === Fix 2: Replace datatoc and shader_tool with native executables ===
# These tools produce architecture-independent output (C data arrays, shader metadata)
for tool in datatoc shader_tool; do
    NATIVE_PATH="${NATIVE_DIR}/${tool}"
    if [ ! -x "${NATIVE_PATH}" ]; then
        echo "[patch-ninja] WARNING: Native ${tool} not found at ${NATIVE_PATH}"
        continue
    fi

    # Replace all references to the WASM .js path with the native executable path
    # This covers COMMAND lines, build dependencies, etc.
    # Use the full path pattern to avoid false matches
    JS_PATH="${BUILD_DIR}/bin/${tool}.js"

    # In COMMAND lines, replace "node path/bin/tool.js" with "native/tool"
    # (remove the "node" prefix since native executables don't need it)
    sed -i "s|node ${JS_PATH}|${NATIVE_PATH}|g" "${NINJA_FILE}"
    # Also handle cases without node prefix
    sed -i "s|${JS_PATH}|${NATIVE_PATH}|g" "${NINJA_FILE}"

    # Replace linker rule with phony rule
    sed -i "/^build bin\/${tool}\.js: CXX_EXECUTABLE_LINKER/c\\build bin/${tool}.js: phony ${NATIVE_PATH}" "${NINJA_FILE}"

    echo "[patch-ninja] ${tool}: replaced with native executable at ${NATIVE_PATH}"
done

# === Fix 3: Validate makesdna and makesrna have node prefix ===
# These MUST run as WASM via node to produce correct 32-bit struct layouts
for tool in makesdna makesrna; do
    CMD_TOTAL=$(grep "COMMAND = " "${NINJA_FILE}" | grep -c "bin/${tool}\.js" 2>/dev/null || true)
    CMD_NODE=$(grep "COMMAND = " "${NINJA_FILE}" | grep -c "node.*bin/${tool}\.js" 2>/dev/null || true)
    if [ "${CMD_TOTAL}" -gt 0 ]; then
        echo "[patch-ninja] ${tool}: ${CMD_NODE}/${CMD_TOTAL} COMMAND refs have node prefix (WASM via node)"
    fi
done

# === Validation ===
echo "[patch-ninja] Validating..."

REMAINING_DOUBLE=$(grep -c "node node " "${NINJA_FILE}" 2>/dev/null || true)
if [ "${REMAINING_DOUBLE}" -gt 0 ]; then
    echo "[patch-ninja] WARNING: ${REMAINING_DOUBLE} remaining 'node node' patterns"
fi

for tool in datatoc shader_tool; do
    if grep -q "^build bin/${tool}.js: phony" "${NINJA_FILE}"; then
        echo "[patch-ninja] PASS: ${tool} phony rule exists"
    fi
done

echo "[patch-ninja] Patching complete."
