#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEED_VALUE="${SEED:-1}"
TC_VALUE="${TC:-}"
SEQ_MODE_VALUE="${SEQ_MODE:-}"
NUM_RAND_VALUE="${NUM_RAND:-}"
WDOG_MS_VALUE="${WDOG_MS:-}"
LOG_PATH="${LOG_FILE:-${ROOT_DIR}/sim/regression.log}"
FILELIST_PATH="${COMPILE_FILELIST:-${ROOT_DIR}/compile.f}"
UCDB_PATH="${UCDB_FILE:-}"
CODE_COVERAGE="${CODE_COVERAGE:-0}"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sha256-questa.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

if [[ "$CODE_COVERAGE" == "1" && -z "$UCDB_PATH" ]]; then
    echo "ERROR: CODE_COVERAGE=1 requires UCDB_FILE=/path/to/file.ucdb" >&2
    exit 2
fi

mkdir -p "$(dirname "$LOG_PATH")"
: > "$LOG_PATH"

SIM_VERSION="$(vsim -version 2>&1 | head -n 1)"
echo "RUN_SEED=${SEED_VALUE}" | tee -a "$LOG_PATH"
echo "SIMULATOR=${SIM_VERSION}" | tee -a "$LOG_PATH"
MANIFEST_PATH="${BUILD_DIR}/source.sha256"
(
    cd "$ROOT_DIR"
    sha256sum compile.f sim/run_regression.sh sim/run_seed_sweep.sh
    find rtl tb verification -type f \( -name '*.sv' -o -name '*.svh' -o -name '*.py' -o -name '*.json' \) -print0 \
        | sort -z | xargs -0 -r sha256sum
) > "$MANIFEST_PATH"
cat "$MANIFEST_PATH" | tee -a "$LOG_PATH"
SOURCE_HASH="$(sha256sum "$MANIFEST_PATH" | awk '{print $1}')"
echo "SOURCE_SET_SHA256=${SOURCE_HASH}" | tee -a "$LOG_PATH"

# Resolve compile.f entries against the project root, so the source list can
# stay relative and the runner works from any current directory or checkout.
if [[ "$FILELIST_PATH" != /* ]]; then
    FILELIST_PATH="$(cd "$(dirname "$FILELIST_PATH")" && pwd)/$(basename "$FILELIST_PATH")"
fi
if [[ ! -f "$FILELIST_PATH" ]]; then
    echo "ERROR: compile filelist not found: ${FILELIST_PATH}" | tee -a "$LOG_PATH"
    exit 2
fi
NORMALIZED_FILELIST="${BUILD_DIR}/compile.f"
while IFS= read -r file_entry || [[ -n "$file_entry" ]]; do
    if [[ -z "${file_entry//[[:space:]]/}" || "$file_entry" =~ ^[[:space:]]*// ]]; then
        printf '%s\n' "$file_entry" >> "$NORMALIZED_FILELIST"
    elif [[ "$file_entry" == /* ]]; then
        printf '%s\n' "$file_entry" >> "$NORMALIZED_FILELIST"
    else
        printf '%s/%s\n' "$ROOT_DIR" "$file_entry" >> "$NORMALIZED_FILELIST"
    fi
done < "$FILELIST_PATH"

if ! command -v vlib >/dev/null 2>&1 || ! command -v vlog >/dev/null 2>&1 || ! command -v vsim >/dev/null 2>&1; then
    echo "ERROR: QuestaSim vlib/vlog/vsim must be available on PATH" | tee -a "$LOG_PATH"
    exit 127
fi

cd "$BUILD_DIR"
if ! vlib work 2>&1 | tee -a "$LOG_PATH"; then
    echo "ERROR: vlib failed" | tee -a "$LOG_PATH"
    exit 1
fi
VLOG_ARGS=(-work work "+incdir+${ROOT_DIR}/rtl" "+incdir+${ROOT_DIR}/tb")
if [[ "$CODE_COVERAGE" == "1" ]]; then
    RTL_FILELIST="${BUILD_DIR}/coverage_rtl.f"
    TB_FILELIST="${BUILD_DIR}/coverage_tb.f"
    awk '/\/rtl\// { print }' "$NORMALIZED_FILELIST" > "$RTL_FILELIST"
    awk '/\/tb\// { print }' "$NORMALIZED_FILELIST" > "$TB_FILELIST"
    if ! vlog "${VLOG_ARGS[@]}" +cover=bcesft -f "$RTL_FILELIST" 2>&1 | tee -a "$LOG_PATH"; then
        echo "ERROR: RTL vlog compilation with code coverage failed" | tee -a "$LOG_PATH"
        exit 1
    fi
    if ! vlog "${VLOG_ARGS[@]}" -f "$TB_FILELIST" 2>&1 | tee -a "$LOG_PATH"; then
        echo "ERROR: testbench vlog compilation failed" | tee -a "$LOG_PATH"
        exit 1
    fi
else
    if ! vlog "${VLOG_ARGS[@]}" -f "$NORMALIZED_FILELIST" 2>&1 | tee -a "$LOG_PATH"; then
        echo "ERROR: vlog compilation failed" | tee -a "$LOG_PATH"
        exit 1
    fi
fi

SIM_ARGS=()
if [[ -n "$TC_VALUE" ]]; then
    SIM_ARGS+=("+TC=${TC_VALUE}")
fi
if [[ -n "$SEQ_MODE_VALUE" ]]; then
    SIM_ARGS+=("+SEQ_MODE=${SEQ_MODE_VALUE}")
fi
if [[ -n "$NUM_RAND_VALUE" ]]; then
    SIM_ARGS+=("+NUM_RAND=${NUM_RAND_VALUE}")
fi
if [[ -n "$WDOG_MS_VALUE" ]]; then
    SIM_ARGS+=("+WDOG_MS=${WDOG_MS_VALUE}")
fi
DO_COMMAND='run -all; quit -f'
if [[ -n "$UCDB_PATH" ]]; then
    mkdir -p "$(dirname "$UCDB_PATH")"
    # Save both functional and instrumented code coverage in the UCDB.
    DO_COMMAND="coverage save -onexit \"${UCDB_PATH}\"; run -all; quit -f"
fi
VSIM_ARGS=()
# Questa only persists functional covergroup data when coverage is enabled at
# simulation time. UCDB runs need this even when RTL code coverage is disabled.
if [[ "$CODE_COVERAGE" == "1" || -n "$UCDB_PATH" ]]; then
    VSIM_ARGS+=(-coverage)
fi

set +e
vsim "${VSIM_ARGS[@]}" -c -lib work tb_sha256 -sv_seed "$SEED_VALUE" "${SIM_ARGS[@]}" \
    -do "$DO_COMMAND" 2>&1 | tee -a "$LOG_PATH"
SIM_STATUS=${PIPESTATUS[0]}
set -e

if (( SIM_STATUS != 0 )); then
    echo "ERROR: vsim exited with status ${SIM_STATUS}" | tee -a "$LOG_PATH"
    exit "$SIM_STATUS"
fi

# Questa can return zero after UVM errors or $fatal when the do-file uses quit -f.
# Treat the transcript as part of the regression result.
if grep -Eq '(\*\* (Fatal|Error):|UVM_(ERROR|FATAL) .*@|^#? Errors: [1-9])' "$LOG_PATH"; then
    echo "ERROR: simulation transcript contains a fatal/error; regression failed" | tee -a "$LOG_PATH"
    exit 1
fi
if ! grep -Fq '*** TEST PASSED ***' "$LOG_PATH"; then
    echo "ERROR: scoreboard PASS marker is missing" | tee -a "$LOG_PATH"
    exit 1
fi
if ! grep -Fq 'INTERNAL CHECKER PASS:' "$LOG_PATH"; then
    echo "ERROR: internal checker PASS marker is missing" | tee -a "$LOG_PATH"
    exit 1
fi
if grep -Fq 'INTERNAL CHECKER PASS: jobs=0 ' "$LOG_PATH"; then
    echo "ERROR: internal checker completed without checking a compression job" | tee -a "$LOG_PATH"
    exit 1
fi

echo "Regression PASS (seed=${SEED_VALUE})" | tee -a "$LOG_PATH"

if [[ "$CODE_COVERAGE" == "1" ]]; then
    SUMMARY_PATH="${UCDB_PATH%.ucdb}_summary.txt"
    DETAIL_PATH="${UCDB_PATH%.ucdb}_detail.txt"
    if ! vcover report -summary -codeAll \
        -output "$SUMMARY_PATH" "$UCDB_PATH" 2>&1 | tee -a "$LOG_PATH"; then
        echo "ERROR: failed to generate code coverage summary" | tee -a "$LOG_PATH"
        exit 1
    fi
    if ! vcover report -zeros -details -codeAll \
        -output "$DETAIL_PATH" "$UCDB_PATH" 2>&1 | tee -a "$LOG_PATH"; then
        echo "ERROR: failed to generate detailed code coverage report" | tee -a "$LOG_PATH"
        exit 1
    fi
    echo "CODE_COVERAGE_SUMMARY=${SUMMARY_PATH}" | tee -a "$LOG_PATH"
    echo "CODE_COVERAGE_DETAIL=${DETAIL_PATH}" | tee -a "$LOG_PATH"
fi

if [[ -n "$UCDB_PATH" ]]; then
    FCOV_DETAIL="${UCDB_PATH%.ucdb}_functional_detail.txt"
    FCOV_HTML="${UCDB_PATH%.ucdb}_functional_html"
    if ! vcover report -cvg -details -zeros -all -nocompactcrossbins -output "$FCOV_DETAIL" "$UCDB_PATH" 2>&1 | tee -a "$LOG_PATH"; then
        echo "ERROR: failed to generate functional coverage bin report" | tee -a "$LOG_PATH"
        exit 1
    fi
    if ! vcover report -cvg -details -zeros -nocompactcrossbins -html -output "$FCOV_HTML" "$UCDB_PATH" 2>&1 | tee -a "$LOG_PATH"; then
        echo "ERROR: failed to generate functional coverage HTML report" | tee -a "$LOG_PATH"
        exit 1
    fi
    echo "FUNCTIONAL_COVERAGE_DETAIL=${FCOV_DETAIL}" | tee -a "$LOG_PATH"
    echo "FUNCTIONAL_COVERAGE_HTML=${FCOV_HTML}" | tee -a "$LOG_PATH"
fi
