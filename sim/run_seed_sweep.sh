#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="${ROOT_DIR}/sim/run_regression.sh"
LOG_DIR="${SEED_LOG_DIR:-${ROOT_DIR}/sim/regression_runs}"
SEED_LIST="${SEEDS:-1 2 3}"
UCDB_DIR="${SEED_UCDB_DIR:-}"
mkdir -p "$LOG_DIR"
if [[ -n "$UCDB_DIR" ]]; then mkdir -p "$UCDB_DIR"; fi
SUMMARY_PATH="${LOG_DIR}/seed_sweep_summary.txt"
: > "$SUMMARY_PATH"

for seed_value in $SEED_LIST; do
    [[ "$seed_value" =~ ^[0-9]+$ ]] || {
        echo "Invalid seed: ${seed_value}" | tee -a "$SUMMARY_PATH"
        exit 2
    }
    log_path="${LOG_DIR}/seed_${seed_value}.log"
    echo "Running seed ${seed_value}" | tee -a "$SUMMARY_PATH"
    if [[ -n "$UCDB_DIR" ]]; then
        if ! SEED="$seed_value" LOG_FILE="$log_path" \
            UCDB_FILE="${UCDB_DIR}/seed_${seed_value}.ucdb" "$RUNNER"; then
            echo "FAIL seed=${seed_value} log=${log_path}" | tee -a "$SUMMARY_PATH"
            exit 1
        fi
    elif ! SEED="$seed_value" LOG_FILE="$log_path" "$RUNNER"; then
        echo "FAIL seed=${seed_value} log=${log_path}" | tee -a "$SUMMARY_PATH"
        exit 1
    fi
    source_hash="$(sed -n 's/^SOURCE_SET_SHA256=//p' "$log_path" | tail -n 1)"
    echo "PASS seed=${seed_value} source_sha256=${source_hash} log=${log_path}" | tee -a "$SUMMARY_PATH"
done

echo "Seed sweep PASS: ${SEED_LIST}" | tee -a "$SUMMARY_PATH"
