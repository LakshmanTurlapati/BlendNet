#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Blender Web Authors
#
# SPDX-License-Identifier: GPL-2.0-or-later

# Patch build.ninja to replace WASM host tool references with native executables.
#
# This solves the cross-compilation chicken-and-egg problem where makesdna,
# makesrna, datatoc, and shader_tool are compiled to WASM (.js) by emcmake
# but must run natively on the build host to generate source files.
#
# Strategy:
#   - makesdna, datatoc, shader_tool: Replace with native executables built by GCC-14
#   - makesrna: Prepend "node" to run the WASM .js via Node.js (too complex to build natively)
#   - Replace CXX_EXECUTABLE_LINKER rules with phony targets pointing to native executables
#
# Usage:
#   ./scripts/patch-ninja-host-tools.sh <BUILD_DIR> <NATIVE_DIR>
#
# Example:
#   ./scripts/patch-ninja-host-tools.sh /src/build-wasm /src/build-native

set -euo pipefail

BUILD_DIR="${1:?Usage: patch-ninja-host-tools.sh <BUILD_DIR> <NATIVE_DIR>}"
NATIVE_DIR="${2:?Usage: patch-ninja-host-tools.sh <BUILD_DIR> <NATIVE_DIR>}"
NINJA_FILE="${BUILD_DIR}/build.ninja"

echo "[patch-ninja] Patching build.ninja for host tool cross-compilation"
echo "[patch-ninja] Build dir: ${BUILD_DIR}"
echo "[patch-ninja] Native dir: ${NATIVE_DIR}"

# Verify inputs
if [ ! -f "${NINJA_FILE}" ]; then
    echo "[patch-ninja] ERROR: build.ninja not found at ${NINJA_FILE}" >&2
    exit 1
fi

if [ ! -d "${NATIVE_DIR}" ]; then
    echo "[patch-ninja] ERROR: Native tools directory not found at ${NATIVE_DIR}" >&2
    exit 1
fi

# Verify native executables exist
NATIVE_TOOLS_OK=true
for tool in makesdna datatoc shader_tool; do
    if [ ! -x "${NATIVE_DIR}/${tool}" ]; then
        echo "[patch-ninja] WARNING: Native ${tool} not found at ${NATIVE_DIR}/${tool}"
        NATIVE_TOOLS_OK=false
    else
        echo "[patch-ninja] FOUND: ${NATIVE_DIR}/${tool}"
    fi
done

# Create a backup (only if one does not already exist -- idempotent)
if [ ! -f "${NINJA_FILE}.orig" ]; then
    cp "${NINJA_FILE}" "${NINJA_FILE}.orig"
    echo "[patch-ninja] Created backup: ${NINJA_FILE}.orig"
else
    echo "[patch-ninja] Backup already exists, skipping"
fi

# === Step 1: Replace COMMAND references to WASM host tools with native ones ===
echo "[patch-ninja] Step 1: Replacing COMMAND references..."

# makesdna: replace WASM .js with native executable
sed -i "s|${BUILD_DIR}/bin/makesdna\.js|${NATIVE_DIR}/makesdna|g" "${NINJA_FILE}"
echo "[patch-ninja]   - makesdna COMMAND references replaced"

# datatoc: replace WASM .js with native executable
sed -i "s|${BUILD_DIR}/bin/datatoc\.js|${NATIVE_DIR}/datatoc|g" "${NINJA_FILE}"
echo "[patch-ninja]   - datatoc COMMAND references replaced"

# shader_tool: replace WASM .js with native executable
sed -i "s|${BUILD_DIR}/bin/shader_tool\.js|${NATIVE_DIR}/shader_tool|g" "${NINJA_FILE}"
echo "[patch-ninja]   - shader_tool COMMAND references replaced"

# makesrna: prepend "node" before the .js path in COMMAND lines
# The COMMAND lines look like:
#   COMMAND = cd ... && /usr/bin/cmake -E env ... /src/build-wasm/bin/makesrna.js <args>
# We need to change the makesrna.js invocation to: node /src/build-wasm/bin/makesrna.js <args>
# But since we are replacing in COMMAND contexts, we need to be careful not to double-prepend.
# Strategy: replace "path/bin/makesrna.js" with "node path/bin/makesrna.js" only in COMMAND lines
# First check if node is already prepended (idempotent)
if grep -q "node ${BUILD_DIR}/bin/makesrna" "${NINJA_FILE}" 2>/dev/null; then
    echo "[patch-ninja]   - makesrna already has node prefix, skipping"
else
    sed -i "s|${BUILD_DIR}/bin/makesrna\.js|node ${BUILD_DIR}/bin/makesrna.js|g" "${NINJA_FILE}"
    echo "[patch-ninja]   - makesrna COMMAND references prefixed with node"
fi

# === Step 2: Replace linker rules with phony targets ===
echo "[patch-ninja] Step 2: Replacing linker rules with phony targets..."

# Replace "build bin/makesdna.js: CXX_EXECUTABLE_LINKER__makesdna_Release ..."
# with "build bin/makesdna.js: phony /src/build-native/makesdna"
sed -i "/^build bin\/makesdna\.js: CXX_EXECUTABLE_LINKER/c\\build bin/makesdna.js: phony ${NATIVE_DIR}/makesdna" "${NINJA_FILE}"
echo "[patch-ninja]   - makesdna linker rule -> phony"

# Replace "build bin/datatoc.js: CXX_EXECUTABLE_LINKER__datatoc_Release ..."
sed -i "/^build bin\/datatoc\.js: CXX_EXECUTABLE_LINKER/c\\build bin/datatoc.js: phony ${NATIVE_DIR}/datatoc" "${NINJA_FILE}"
echo "[patch-ninja]   - datatoc linker rule -> phony"

# Replace "build bin/shader_tool.js: CXX_EXECUTABLE_LINKER__shader_tool_Release ..."
sed -i "/^build bin\/shader_tool\.js: CXX_EXECUTABLE_LINKER/c\\build bin/shader_tool.js: phony ${NATIVE_DIR}/shader_tool" "${NINJA_FILE}"
echo "[patch-ninja]   - shader_tool linker rule -> phony"

# For makesrna, we let it link as WASM (it runs via node), so we do NOT replace its linker rule.
# However, if makesrna.js fails to link, we may need to add a phony rule for it too.
# For now, leave makesrna's linker rule intact.
echo "[patch-ninja]   - makesrna linker rule kept (runs via node as WASM)"

# === Step 3: Validation ===
echo "[patch-ninja] Step 3: Validating patches..."

# Check for any remaining .js references to host tools in COMMAND lines
REMAINING=$(grep -c "bin/makesdna\.js\|bin/datatoc\.js\|bin/shader_tool\.js" "${NINJA_FILE}" 2>/dev/null || true)
if [ "${REMAINING}" -gt 0 ]; then
    echo "[patch-ninja] WARNING: ${REMAINING} remaining .js references found for makesdna/datatoc/shader_tool"
    grep -n "bin/makesdna\.js\|bin/datatoc\.js\|bin/shader_tool\.js" "${NINJA_FILE}" | head -5
else
    echo "[patch-ninja] PASS: No remaining .js references for makesdna/datatoc/shader_tool"
fi

# Check makesrna references have node prefix
MAKESRNA_REFS=$(grep -c "bin/makesrna\.js" "${NINJA_FILE}" 2>/dev/null || true)
MAKESRNA_NODE=$(grep -c "node.*bin/makesrna\.js" "${NINJA_FILE}" 2>/dev/null || true)
echo "[patch-ninja] makesrna references: ${MAKESRNA_REFS} total, ${MAKESRNA_NODE} with node prefix"

echo "[patch-ninja] Patching complete."
