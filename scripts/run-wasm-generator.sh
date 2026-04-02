#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Blender Web Authors
#
# SPDX-License-Identifier: GPL-2.0-or-later

# Emscripten-built generator tools can finish writing their outputs but keep the
# Node.js process alive because they inherit the main app's long-lived runtime
# flags. Treat stabilized output files as success so ninja can continue.

set -euo pipefail

TOOL_JS="${1:?Usage: run-wasm-generator.sh <tool.js> [tool-args...]}"
shift

TOOL_NAME="$(basename "${TOOL_JS}" .js)"
POLL_INTERVAL_SECONDS="${WASM_GENERATOR_POLL_INTERVAL_SECONDS:-1}"
STABLE_POLLS_REQUIRED="${WASM_GENERATOR_STABLE_POLLS_REQUIRED:-3}"
TIMEOUT_SECONDS="${WASM_GENERATOR_TIMEOUT_SECONDS:-300}"

declare -a OUTPUT_PATHS=()
WATCH_DIR=""
WATCH_ROOT=""

reset_outputs() {
    case "${TOOL_NAME}" in
        makesdna)
            local path
            for path in "${OUTPUT_PATHS[@]}"; do
                rm -f "${path}"
            done
            ;;
        makesrna)
            if [ -n "${WATCH_DIR}" ]; then
                find "${WATCH_DIR}" -maxdepth 1 -type f \
                    \( -name 'rna_*_gen.cc' -o -name 'rna_*_gen.hh' -o -name 'rna_prototypes_gen.hh' \) \
                    -delete 2>/dev/null || true
            fi
            if [ -n "${WATCH_ROOT}" ]; then
                rm -f "${WATCH_ROOT%/}/RNA_prototypes.hh"
            fi
            ;;
    esac
}

snapshot_outputs() {
    case "${TOOL_NAME}" in
        makesdna)
            local path
            for path in "${OUTPUT_PATHS[@]}"; do
                if [ -f "${path}" ]; then
                    stat -c '%n %s %Y' "${path}"
                else
                    echo "${path} MISSING"
                fi
            done
            ;;
        makesrna)
            if [ -n "${WATCH_DIR}" ]; then
                find "${WATCH_DIR}" -maxdepth 1 -type f \
                    \( -name 'rna_*_gen.cc' -o -name 'rna_*_gen.hh' -o -name 'rna_prototypes_gen.hh' \) \
                    -printf '%p %s %T@\n' 2>/dev/null | sort
            fi
            if [ -n "${WATCH_ROOT}" ]; then
                local proto="${WATCH_ROOT%/}/RNA_prototypes.hh"
                if [ -f "${proto}" ]; then
                    stat -c '%n %s %Y' "${proto}"
                else
                    echo "${proto} MISSING"
                fi
            fi
            ;;
        *)
            echo "[run-wasm-generator] ERROR: unsupported tool ${TOOL_NAME}" >&2
            return 1
            ;;
    esac
}

validate_outputs() {
    case "${TOOL_NAME}" in
        makesdna)
            local path
            for path in "${OUTPUT_PATHS[@]}"; do
                if [ ! -s "${path}" ]; then
                    echo "[run-wasm-generator] ERROR: ${TOOL_NAME} output missing or empty: ${path}" >&2
                    return 1
                fi
            done
            ;;
        makesrna)
            local gen_count=0
            if [ -n "${WATCH_DIR}" ]; then
                gen_count="$(find "${WATCH_DIR}" -maxdepth 1 -type f -name 'rna_*_gen.cc' | wc -l | tr -d ' ')"
            fi
            if [ "${gen_count}" -eq 0 ]; then
                echo "[run-wasm-generator] ERROR: ${TOOL_NAME} did not generate any rna_*_gen.cc files" >&2
                return 1
            fi
            if [ ! -s "${WATCH_ROOT%/}/RNA_prototypes.hh" ]; then
                echo "[run-wasm-generator] ERROR: ${TOOL_NAME} did not produce RNA_prototypes.hh" >&2
                return 1
            fi
            ;;
    esac
}

terminate_lingering_process() {
    local pid="${1:?missing pid}"

    if kill -0 "${pid}" 2>/dev/null; then
        kill -TERM "${pid}" 2>/dev/null || true
        sleep 2
    fi
    if kill -0 "${pid}" 2>/dev/null; then
        kill -KILL "${pid}" 2>/dev/null || true
    fi
    wait "${pid}" || true
}

case "${TOOL_NAME}" in
    makesdna)
        if [ "$#" -lt 2 ]; then
            echo "[run-wasm-generator] ERROR: makesdna expects output paths plus source directory" >&2
            exit 1
        fi
        OUTPUT_PATHS=("${@:1:$(($# - 1))}")
        ;;
    makesrna)
        WATCH_DIR="${1:?makesrna requires an output directory}"
        WATCH_ROOT="${2:?makesrna requires a root output directory}"
        ;;
    *)
        echo "[run-wasm-generator] ERROR: unsupported tool ${TOOL_NAME}" >&2
        exit 1
        ;;
esac

reset_outputs
BASELINE_SNAPSHOT="$(snapshot_outputs)"
LAST_SNAPSHOT="${BASELINE_SNAPSHOT}"
CHANGED_OUTPUTS=0
STABLE_POLLS=0
START_TIME="${SECONDS}"

node "${TOOL_JS}" "$@" &
NODE_PID=$!
trap 'terminate_lingering_process "${NODE_PID}"' EXIT

while kill -0 "${NODE_PID}" 2>/dev/null; do
    CURRENT_SNAPSHOT="$(snapshot_outputs)"

    if [ "${CURRENT_SNAPSHOT}" != "${BASELINE_SNAPSHOT}" ]; then
        CHANGED_OUTPUTS=1
    fi

    if [ "${CHANGED_OUTPUTS}" -eq 1 ] && [ "${CURRENT_SNAPSHOT}" = "${LAST_SNAPSHOT}" ]; then
        STABLE_POLLS=$((STABLE_POLLS + 1))
    else
        STABLE_POLLS=0
    fi

    LAST_SNAPSHOT="${CURRENT_SNAPSHOT}"

    if [ "${CHANGED_OUTPUTS}" -eq 1 ] && [ "${STABLE_POLLS}" -ge "${STABLE_POLLS_REQUIRED}" ]; then
        echo "[run-wasm-generator] ${TOOL_NAME}: outputs stabilized; stopping lingering node runtime"
        terminate_lingering_process "${NODE_PID}"
        trap - EXIT
        validate_outputs
        echo "[run-wasm-generator] ${TOOL_NAME}: completed via stabilized-output fallback"
        exit 0
    fi

    if [ $((SECONDS - START_TIME)) -ge "${TIMEOUT_SECONDS}" ]; then
        echo "[run-wasm-generator] ERROR: ${TOOL_NAME} timed out after ${TIMEOUT_SECONDS}s" >&2
        terminate_lingering_process "${NODE_PID}"
        trap - EXIT
        exit 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
done

wait "${NODE_PID}"
NODE_STATUS=$?
trap - EXIT

if [ "${NODE_STATUS}" -ne 0 ]; then
    echo "[run-wasm-generator] ERROR: ${TOOL_NAME} exited with status ${NODE_STATUS}" >&2
    exit "${NODE_STATUS}"
fi

validate_outputs
echo "[run-wasm-generator] ${TOOL_NAME}: exited cleanly"
