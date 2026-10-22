#!/bin/sh
# scripts/pipeline.sh — the single entry point of the U2 translator pipeline.
#
# Usage:
#   sh scripts/pipeline.sh [--data-root PATH] [--out PATH] [--vendor PATH] [--stage STAGE]
#
# Six stages, fixed order, and the only legal `stage=` values in the log:
#
#     unpack -> generate -> translate -> fmt -> check -> golden
#
# --stage semantics: `--stage=<s>` runs every stage up to and including `<s>`
#     (so --stage=unpack runs unpack only, --stage=golden runs all six).
#     Without --stage the whole chain runs.  --stage is a dry-run / batching
#     aid only; CI and the final acceptance always use the no-argument form.
#
# Log: .planning/logs/u2/T2-entry.log — one field per line.  The field
#     vocabulary is stage=, lang=, file=, line=, exit=, elapsed=, plus the
#     resolved-root lines "data_root=<abs> source=<flag|env|default>" and the
#     host line "host=<git-bash|wsl>".  A stage opens with "stage=<name>"
#     and closes with "stage=<name> exit=<code>".  No ANSI escape sequence
#     is ever written, and stdin is never read.
#
# Exit codes:
#     0  every selected stage succeeded (not reachable in Task 2 — the stage
#        bodies are still honest-red)
#     2  usage error (unknown flag, unknown --stage value) or a stage body
#        that is not implemented yet
#     3  toolchain preflight failed (python / moon / gzip missing)
#     4  path resolution failed (a flag or env var named a missing path)
#     5  the wslpath round-trip probe failed
#     other  the exit code of the first failing stage.  The run is fail-fast:
#        a later stage is never entered after a failure.
#
# Host detection (prototype defect P1): the pipeline runs inside WSL iff
#     `uname -s` contains Linux AND WSL_DISTRO_NAME is non-empty.  Only from
#     the host is WSL entered, and then only as `wsl -e bash -lc '...'` with
#     `cd "$(wslpath -a -u .)"` inside.  Inside WSL this script never calls
#     `wsl` again — that self-nesting is what produced exit 127.
#
# Paths: every root is derived from the module root
#     (cd "$(dirname "$0")/.." && pwd -P); no absolute path is hard-coded here.
#     Precedence: explicit flag > SNOWBALL_DATA_ROOT (corpus root only) >
#     module-relative default (.planning/data/sd, build/gen, tools/vendor).
#     A relative flag or env value is resolved against the current working
#     directory; the default roots are resolved against the module root.
#     A flag or env var that names a path which does not exist is an error
#     (exit 4).  Nothing is created on disk by this script: the default
#     output root build/gen is reported, not made.
#
# The printed roots are absolute in the running shell's own namespace: the
#     POSIX form under Git-Bash, the WSL mount form inside WSL.  A stage that
#     hands a root to a native Windows binary must convert it first (cygpath
#     -w under Git-Bash) or run inside WSL.

set -u

MODULE_ROOT=$(cd "$(dirname "$0")/.." && pwd -P) || exit 4

LOG_ROOT="$MODULE_ROOT/.planning/logs/u2"
PIPELINE_LOG="$LOG_ROOT/T2-entry.log"
PROBE_LOG="$LOG_ROOT/T2-wslpath-probe.log"

STAGES="unpack generate translate fmt check golden"

EXIT_USAGE=2
EXIT_TOOLCHAIN=3
EXIT_PATH=4
EXIT_PROBE=5

mkdir -p "$LOG_ROOT" 2>/dev/null || true
# The run log is append-only: every run appends its own banner, probe result
# and stage lines, so the evidence of both the host run and the WSL run
# stays in one file.  It is gitignored (.planning/logs/).

# ---------------------------------------------------------------------------
# Log helpers — the only fields the pipeline is allowed to write.
# ---------------------------------------------------------------------------

# log_line <text> — one line to stdout and to the run log.
log_line() {
    printf '%s\n' "$*"
    printf '%s\n' "$*" >>"$PIPELINE_LOG" 2>/dev/null || true
}

# log_err <text> — one line to stderr and to the run log.
log_err() {
    printf '%s\n' "$*" >&2
    printf '%s\n' "$*" >>"$PIPELINE_LOG" 2>/dev/null || true
}

# emit_field <key> <value> — `key=value`.
emit_field() {
    log_line "$1=$2"
}

# emit_root <name> <abs path> <source> — the resolved-root line.
emit_root() {
    log_line "$1=$2 source=$3"
}

# emit_header — host identity and every resolved root, as absolute paths.
emit_header() {
    emit_field host "$HOST"
    emit_root data_root "$DATA_ROOT_ABS" "$DATA_SRC"
    emit_root out_root "$OUT_ROOT_ABS" "$OUT_SRC"
    emit_root vendor_root "$VENDOR_ROOT_ABS" "$VENDOR_SRC"
}

# ---------------------------------------------------------------------------
# Small path helpers
# ---------------------------------------------------------------------------

# abs_of <path> — absolute form of <path>, even when it does not exist.
abs_of() {
    _p="$1"
    case "$_p" in
        */) _p="${_p%/}" ;;
    esac
    [ -n "$_p" ] || _p="/"
    _dir=$(dirname "$_p")
    _base=$(basename "$_p")
    _adir=$(cd "$_dir" 2>/dev/null && pwd -P) || _adir=""
    if [ -z "$_adir" ]; then
        printf '%s\n' "$_p"
    elif [ "$_adir" = "/" ]; then
        printf '%s\n' "$_adir$_base"
    else
        printf '%s\n' "$_adir/$_base"
    fi
}

# require_existing <param label> <path> — hard gate for flag/env roots.
# The message names the parameter and the resolved absolute path.
require_existing() {
    if [ ! -e "$2" ]; then
        log_err "$1 does not exist: $2 (resolved: $(abs_of "$2"))"
        emit_header
        exit "$EXIT_PATH"
    fi
    if [ ! -d "$2" ]; then
        log_err "$1 is not a directory: $2 (resolved: $(abs_of "$2"))"
        emit_header
        exit "$EXIT_PATH"
    fi
}

usage() {
    printf '%s\n' "usage: sh scripts/pipeline.sh [--data-root PATH] [--out PATH] [--vendor PATH] [--stage STAGE]"
    printf '%s\n' "stages: $STAGES"
    printf '%s\n' "  --stage=<s> runs the stages up to and including <s> (default: all six)"
}

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------

DATA_ROOT_ARG=""
OUT_ROOT_ARG=""
VENDOR_ROOT_ARG=""
STAGE_ARG=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --data-root=*) DATA_ROOT_ARG="${1#--data-root=}" ;;
        --data-root)
            shift
            [ "$#" -gt 0 ] || { log_err "--data-root needs a value"; exit "$EXIT_USAGE"; }
            DATA_ROOT_ARG="$1"
            ;;
        --out=*) OUT_ROOT_ARG="${1#--out=}" ;;
        --out)
            shift
            [ "$#" -gt 0 ] || { log_err "--out needs a value"; exit "$EXIT_USAGE"; }
            OUT_ROOT_ARG="$1"
            ;;
        --vendor=*) VENDOR_ROOT_ARG="${1#--vendor=}" ;;
        --vendor)
            shift
            [ "$#" -gt 0 ] || { log_err "--vendor needs a value"; exit "$EXIT_USAGE"; }
            VENDOR_ROOT_ARG="$1"
            ;;
        --stage=*) STAGE_ARG="${1#--stage=}" ;;
        --stage)
            shift
            [ "$#" -gt 0 ] || { log_err "--stage needs a value"; exit "$EXIT_USAGE"; }
            STAGE_ARG="$1"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            log_err "unknown argument: $1"
            usage >&2
            exit "$EXIT_USAGE"
            ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# Stage selection — the six stage names are the single source of truth.
# ---------------------------------------------------------------------------

if [ -n "$STAGE_ARG" ]; then
    RUN_STAGES=""
    _found=0
    for _s in $STAGES; do
        RUN_STAGES="$RUN_STAGES $_s"
        if [ "$_s" = "$STAGE_ARG" ]; then
            _found=1
            break
        fi
    done
    if [ "$_found" -ne 1 ]; then
        log_err "unknown stage: $STAGE_ARG (expected one of: $STAGES)"
        exit "$EXIT_USAGE"
    fi
else
    RUN_STAGES="$STAGES"
fi

# ---------------------------------------------------------------------------
# Host detection — inside WSL never call `wsl` again (prototype defect P1).
# ---------------------------------------------------------------------------

HOST=git-bash
if case "$(uname -s)" in *Linux*) true ;; *) false ;; esac && [ -n "${WSL_DISTRO_NAME:-}" ]; then
    HOST=wsl
fi

# ---------------------------------------------------------------------------
# Path resolution — flag > env (corpus root only) > module-relative default.
# ---------------------------------------------------------------------------

if [ -n "$DATA_ROOT_ARG" ]; then
    DATA_SRC=flag
    DATA_VAL="$DATA_ROOT_ARG"
elif [ -n "${SNOWBALL_DATA_ROOT:-}" ]; then
    DATA_SRC=env
    DATA_VAL="$SNOWBALL_DATA_ROOT"
else
    DATA_SRC=default
    DATA_VAL="$MODULE_ROOT/.planning/data/sd"
fi

if [ -n "$OUT_ROOT_ARG" ]; then
    OUT_SRC=flag
    OUT_VAL="$OUT_ROOT_ARG"
else
    OUT_SRC=default
    OUT_VAL="$MODULE_ROOT/build/gen"
fi

if [ -n "$VENDOR_ROOT_ARG" ]; then
    VENDOR_SRC=flag
    VENDOR_VAL="$VENDOR_ROOT_ARG"
else
    VENDOR_SRC=default
    VENDOR_VAL="$MODULE_ROOT/tools/vendor"
fi

DATA_ROOT_ABS=$(abs_of "$DATA_VAL")
OUT_ROOT_ABS=$(abs_of "$OUT_VAL")
VENDOR_ROOT_ABS=$(abs_of "$VENDOR_VAL")

# A flag or env var that names a path which does not exist is fatal.
case "$DATA_SRC" in
    flag) require_existing "data_root (--data-root)" "$DATA_VAL" ;;
    env) require_existing "data_root (SNOWBALL_DATA_ROOT)" "$DATA_VAL" ;;
esac

case "$OUT_SRC" in
    flag) require_existing "out_root (--out)" "$OUT_VAL" ;;
esac

case "$VENDOR_SRC" in
    flag) require_existing "vendor_root (--vendor)" "$VENDOR_VAL" ;;
esac

# ---------------------------------------------------------------------------
# Toolchain preflight — before stage=unpack.  A missing tool is the very
# first line of the run.
# ---------------------------------------------------------------------------

# The moon toolchain lives in $HOME/.moon/bin but is not always on PATH.
if [ -d "$HOME/.moon/bin" ]; then
    PATH="$HOME/.moon/bin:$PATH"
    export PATH
fi

MISSING=""
PYTHON_BIN=""
if command -v python >/dev/null 2>&1; then
    PYTHON_BIN=python
elif command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN=python3
else
    MISSING="$MISSING python"
fi
command -v moon >/dev/null 2>&1 || MISSING="$MISSING moon"
command -v gzip >/dev/null 2>&1 || MISSING="$MISSING gzip"

if [ -n "$MISSING" ]; then
    for _m in $MISSING; do
        log_err "$_m not found"
    done
    emit_header
    exit "$EXIT_TOOLCHAIN"
fi

# ---------------------------------------------------------------------------
# Startup banner — the resolved absolute roots plus the host identity.
# ---------------------------------------------------------------------------

emit_header

if [ "$DATA_SRC" = default ] && [ ! -d "$DATA_ROOT_ABS" ]; then
    log_err "warning: default data_root does not exist: $DATA_ROOT_ABS"
fi
if [ "$OUT_SRC" = default ] && [ ! -d "$OUT_ROOT_ABS" ]; then
    log_err "warning: default out_root does not exist: $OUT_ROOT_ABS (the generate stage creates it)"
fi
if [ "$VENDOR_SRC" = default ] && [ ! -d "$VENDOR_ROOT_ABS" ]; then
    log_err "warning: default vendor_root does not exist: $VENDOR_ROOT_ABS"
fi

emit_field python "$PYTHON_BIN"
emit_field moon "$(command -v moon)"
emit_field gzip "$(command -v gzip)"

# ---------------------------------------------------------------------------
# A9 probe — wslpath round-trip over a path that carries Chinese characters
# and a space.  It runs before anything is wired; a failure stops the run.
#
# The round-trip is windows -> unix -> windows: the two sides must be equal.
# The probe segment is spelled with octal escapes so that no non-ASCII byte
# ever has to cross the Windows/WSL argument boundary.
#
# The probe result belongs to the dedicated probe log; only a failure is
# echoed into the run log.
# ---------------------------------------------------------------------------

PROBE_ZH=$(printf '\346\216\242\351\222\210')
PROBE_REL="probe dir $PROBE_ZH/probe file.txt"

PROBE_WINDOWS=""
PROBE_UNIX=""
PROBE_WINDOWS2=""

# probe_note <text> — one line to the dedicated probe log.
probe_note() {
    printf '%s\n' "$*" >>"$PROBE_LOG" 2>/dev/null || true
}

# probe_local — the pipeline runs inside WSL: wslpath is already there.
#
# The assertion has two halves: the round trip must be stable
# (windows -> unix -> windows returns the same windows path) and the unix
# side must be the path we started from.  The second half catches a
# wslpath that answers with something else entirely.
probe_local() {
    _p="$MODULE_ROOT/$PROBE_REL"
    _expect_unix="$_p"
    PROBE_WINDOWS=$(wslpath -a -w "$_p" 2>/dev/null) || return 1
    PROBE_UNIX=$(wslpath -a -u "$PROBE_WINDOWS" 2>/dev/null) || return 1
    PROBE_WINDOWS2=$(wslpath -a -w "$PROBE_UNIX" 2>/dev/null) || return 1
    probe_note "host=$HOST"
    probe_note "probe_path_windows=$PROBE_WINDOWS"
    probe_note "probe_path_unix=$PROBE_UNIX"
    probe_note "probe_path_windows_roundtrip=$PROBE_WINDOWS2"
    probe_note "probe_path_unix_expected=$_expect_unix"
    probe_note "module_root_unix=$MODULE_ROOT"
    [ "$PROBE_WINDOWS" = "$PROBE_WINDOWS2" ] || return 1
    [ "$PROBE_UNIX" = "$_expect_unix" ] || return 1
    probe_note "probe_result=RT_OK"
    return 0
}

# probe_via_wsl — the pipeline runs on the host: WSL is entered exactly once,
# as `wsl -e bash -lc '...'` with `cd "$(wslpath -a -u .)"` inside.
probe_via_wsl() {
    if ! command -v wsl >/dev/null 2>&1; then
        probe_note "host=$HOST"
        probe_note "probe_result=NO_WSL"
        return 2
    fi
    _out=$(wsl -e bash -lc '
        cd "$(wslpath -a -u .)" || exit 90
        zh=$(printf "\346\216\242\351\222\210")
        p="$PWD/probe dir $zh/probe file.txt"
        win=$(wslpath -a -w "$p") || exit 91
        unix=$(wslpath -a -u "$win") || exit 92
        win2=$(wslpath -a -w "$unix") || exit 93
        printf "probe_path_windows=%s\n" "$win"
        printf "probe_path_unix=%s\n" "$unix"
        printf "probe_path_windows_roundtrip=%s\n" "$win2"
        printf "probe_path_unix_expected=%s\n" "$p"
        printf "module_root_unix=%s\n" "$PWD"
        if [ "$win" != "$win2" ]; then printf "probe_result=RT_FAIL\n"; exit 1; fi
        if [ "$unix" != "$p" ]; then printf "probe_result=RT_FAIL\n"; exit 1; fi
        printf "probe_result=RT_OK\n"
        exit 0
    ' 2>&1 </dev/null)
    _rc=$?
    probe_note "host=$HOST"
    printf '%s\n' "$_out" | while IFS= read -r _l; do probe_note "$_l"; done
    PROBE_WINDOWS=$(printf '%s\n' "$_out" | sed -n 's/^probe_path_windows=//p')
    PROBE_UNIX=$(printf '%s\n' "$_out" | sed -n 's/^probe_path_unix=//p')
    PROBE_WINDOWS2=$(printf '%s\n' "$_out" | sed -n 's/^probe_path_windows_roundtrip=//p')
    return "$_rc"
}

PROBE_T0=$(date +%s)
if [ "$HOST" = wsl ]; then
    probe_local
    PROBE_RC=$?
else
    probe_via_wsl
    PROBE_RC=$?
fi
PROBE_T1=$(date +%s)

if [ "$PROBE_RC" -ne 0 ]; then
    log_err "wslpath round-trip probe failed (host=$HOST)"
    log_err "probe windows side: $PROBE_WINDOWS"
    log_err "probe unix side: $PROBE_UNIX"
    log_err "probe windows side after round trip: $PROBE_WINDOWS2"
    emit_field elapsed "$((PROBE_T1 - PROBE_T0))"
    exit "$EXIT_PROBE"
fi

emit_field wslpath_probe "RT_OK"

# ---------------------------------------------------------------------------
# The six stages.  Until their own tasks land the bodies are honest-red:
# they never pretend to succeed.
# ---------------------------------------------------------------------------

stage_unpack() {
    log_err "unpack is not implemented: tools/unpack_arabic.sh still carries the prototype's stale path arithmetic (it resolves data/arabic against the wrong root), so running it now would write the decompressed corpus to the wrong place. Task 8 rewrites that script; until then this stage refuses to run."
    return 2
}

stage_generate() {
    log_err "generate is not implemented: Task 3 wires the Snowball generator (tools/gen_all.sh)."
    return 2
}

stage_translate() {
    log_err "translate is not implemented: Task 4 wires tools/translate_all.py."
    return 2
}

stage_fmt() {
    log_err "fmt is not implemented: Task 5 wires the moon fmt normalisation pass."
    return 2
}

stage_check() {
    log_err "check is not implemented: Task 6 wires the moon check gate."
    return 2
}

stage_golden() {
    log_err "golden is not implemented: Task 7 wires cmd/golden."
    return 2
}

# run_stage <name> — dispatch one stage, return its exit code.
run_stage() {
    case "$1" in
        unpack) stage_unpack ;;
        generate) stage_generate ;;
        translate) stage_translate ;;
        fmt) stage_fmt ;;
        check) stage_check ;;
        golden) stage_golden ;;
        *)
            log_err "unknown stage: $1 (expected one of: $STAGES)"
            return "$EXIT_USAGE"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Dispatcher — fail-fast, a later stage is never entered after a failure.
# ---------------------------------------------------------------------------

for _stage in $RUN_STAGES; do
    STAGE_START=$(date +%s)
    emit_field stage "$_stage"
    emit_field elapsed 0
    run_stage "$_stage"
    _rc=$?
    _now=$(date +%s)
    emit_field stage "$_stage"
    emit_field exit "$_rc"
    emit_field elapsed "$((_now - STAGE_START))"
    if [ "$_rc" -ne 0 ]; then
        log_err "stage=$_stage exit=$_rc (fail-fast: no later stage is entered)"
        exit "$_rc"
    fi
done

emit_field exit 0
exit 0
