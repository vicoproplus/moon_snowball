#!/bin/sh
# scripts/pipeline.sh — SKELETON ONLY (Task 1 of the U2 translator pipeline).
#
# Task 2 wires the six stages.  Their order is fixed by the global constraints:
#
#     unpack -> generate -> translate -> fmt -> check -> golden
#
# Every log line emitted by the finished pipeline uses only those six `stage=`
# values.  Until Task 2 lands, each stage body fails loudly instead of
# pretending to succeed, so a half-wired pipeline can never look green.
#
# No absolute path appears in this file: every root is resolved from this
# script's own directory, and the resolved absolute path is printed once at
# start.  This script never invokes `wsl`; the host/WSL probe belongs to Task 2
# (global constraint R6 forbids calling `wsl` from inside WSL).

set -u

# ---------------------------------------------------------------------------
# Shared paths and log helpers (consumed by every stage once Task 2 lands them)
# ---------------------------------------------------------------------------

MODULE_ROOT=$(cd "$(dirname "$0")/.." && pwd)
LOG_ROOT="$MODULE_ROOT/.planning/logs/u2"
PIPELINE_LOG="$LOG_ROOT/pipeline.log"

mkdir -p "$LOG_ROOT" 2>/dev/null || true

# emit <line> — write one line to stdout and to the pipeline log.
emit() {
    printf '%s\n' "$*"
    printf '%s\n' "$*" >>"$PIPELINE_LOG" 2>/dev/null || true
}

# emit_field <key> <value> — `key=value`, the log field format used by the gate.
emit_field() {
    emit "$1=$2"
}

# stage_begin <stage> — open one of the six stages and start its clock.
stage_begin() {
    STAGE_NAME="$1"
    STAGE_START=$(date +%s)
    emit_field stage "$STAGE_NAME"
}

# stage_end <stage> <code> — close a stage with exit code and elapsed seconds,
# then return that code so callers can propagate it.
stage_end() {
    _code="$2"
    _now=$(date +%s)
    elapsed=$((_now - STAGE_START))
    emit_field stage "$1"
    emit_field exit "$_code"
    emit_field elapsed "$elapsed"
    return "$_code"
}

# stage_not_implemented <stage> — the Task 1 body of every stage.
stage_not_implemented() {
    stage_begin "$1"
    emit "$1 not implemented (Task 2 wires the six stages)" >&2
    stage_end "$1" 2 || true
    return 2
}

# ---------------------------------------------------------------------------
# Body
# ---------------------------------------------------------------------------

STAGES="unpack generate translate fmt check golden"

emit_field host "$(uname -s)"
emit_field module_root "$MODULE_ROOT"
emit_field log "$PIPELINE_LOG"

SELECTED=all
for arg in "$@"; do
    case "$arg" in
        --stage=*)
            SELECTED="${arg#--stage=}"
            ;;
        -h|--help)
            emit "usage: sh scripts/pipeline.sh [--stage=<unpack|generate|translate|fmt|check|golden>]"
            exit 0
            ;;
        *)
            emit "unknown argument: $arg" >&2
            exit 2
            ;;
    esac
done

case "$SELECTED" in
    all)
        for s in $STAGES; do
            stage_not_implemented "$s" || exit $?
        done
        ;;
    unpack|generate|translate|fmt|check|golden)
        stage_not_implemented "$SELECTED" || exit $?
        ;;
    *)
        emit "unknown stage: $SELECTED (expected one of: $STAGES)" >&2
        exit 2
        ;;
esac

emit "pipeline not implemented (Task 2 wires the six stages)" >&2
exit 2
