#!/bin/sh
# scripts/pipeline.sh — the single entry point of the U2 translator pipeline.
#
# Usage:
#   sh scripts/pipeline.sh [--data-root PATH] [--out PATH] [--vendor PATH]
#                          [--sb-root PATH] [--stage STAGE | --only STAGE]
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
# --only semantics: `--only=<s>` runs exactly that one stage.  It exists
#     because a stage that is wired may still be preceded by a stage that is
#     honestly red: --only lets a single stage be exercised without touching
#     the other five.  --stage and --only are mutually exclusive.
#
# The generate stage (Task 3) runs the upstream Snowball 3.2.0 compiler.
# The compiler is a Linux ELF, so the generation always happens inside WSL:
# from the host the stage enters WSL exactly once per generation
# (`wsl -e bash -lc '...'`, every path conversion done by wslpath); inside
# WSL the stage calls tools/gen_all.sh directly and never calls wsl again.
# It produces three directories — the deliverable output (out_root), plus
# .planning/logs/u2/gen1 and .planning/logs/u2/gen2 — and then proves the
# two claims the pipeline is allowed to make:
#
#     generated 11/11          gen1 and gen2 are byte-identical (the eleven
#                              upstream languages, porter included)
#     py32 covered 10/10 SAME  the ten vendored py32 stemmers are unchanged
#
# porter has no vendored py32 counterpart: its baseline is gen1 == gen2
# only, and that is what the pipeline states.  The generation count never
# includes the porter311 translation — that is a later task, and its number
# is never written here.
#
# Log: .planning/logs/u2/T2-entry.log — one field per line.  The field
#     vocabulary is stage=, lang=, file=, line=, exit=, elapsed=, cmd=, plus
#     the resolved-root lines "data_root=<abs> source=<flag|env|default>" and
#     the host line "host=<git-bash|wsl>".  A stage opens with "stage=<name>"
#     and closes with "stage=<name> exit=<code>".  No ANSI escape sequence
#     is ever written, and stdin is never read.
#
# The generate stage keeps its own detail log in
# .planning/logs/u2/T3-generate.log (truncated at the start of every
# generate run, so it always describes the most recent run): the
# per-language command lines and the two parity claims live there.  The
# raw transcript of every generation is appended to T3-generate-raw.log.
#
# The translate stage keeps its own detail log in
# .planning/logs/u2/T4-translate.log (truncated at the start of every
# translate run): one line per language with the input file, the written
# file, its raw line count and the elapsed seconds, plus the residue and
# raise-count assertions that follow the translations.
#
# Exit codes:
#     0  every selected stage succeeded
#     2  usage error (unknown flag, unknown --stage/--only value) or a stage
#        body that is not implemented yet
#     3  toolchain preflight failed (python / moon / gzip missing)
#     4  path resolution failed (a flag or env var named a missing path)
#     5  the wslpath round-trip probe failed
#     6  the generate stage failed (compiler missing, WSL unreachable, a
#        generation error, or a parity mismatch)
#     7  the translate stage failed (an input file is missing, the
#        translator refused a construct, or a residue/raise-count
#        assertion did not hold)
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
# POSIX form under Git-Bash, the WSL mount form inside WSL.  A root that
# crosses the host -> WSL boundary must be converted with `wslpath -a -u`
# (the host prints /f/..., WSL expects /mnt/f/...): the host->WSL
# conversion is wslpath, never a hand-written prefix swap.

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
EXIT_GENERATE=6
EXIT_TRANSLATE=7


# The generate stage (Task 3) has its own log: the per-language command
# lines and the two parity claims live there.  It is truncated at the start
# of every generate run, so it always describes the most recent run; the
# raw transcript of every generation is appended to GENERATE_RAW_LOG.
GENERATE_LOG="$LOG_ROOT/T3-generate.log"
GENERATE_RAW_LOG="$LOG_ROOT/T3-generate-raw.log"

# The translate stage (Task 4) keeps its own detail log, truncated at the
# start of every translate run: one line per language plus the residue and
# raise-count assertions that follow the translations.
TRANSLATE_LOG="$LOG_ROOT/T4-translate.log"

# Where the translate stage snapshots an existing deliverable directory
# before overwriting it.  Outside the module by default so a copy can never
# land inside the tree it is copying; SNOWBALL_T4_SNAPSHOT_ROOT relocates it.
TRANSLATE_RAW_LOG="$LOG_ROOT/T4-translate-raw.log"
TR_SNAPSHOT_ROOT="${SNOWBALL_T4_SNAPSHOT_ROOT:-$LOG_ROOT/snapshot}"


# The two parity directories and the snapshot area.  The snapshot area
# lives under .planning/logs/ (gitignored) and is *outside* every directory
# the stage overwrites, so a copy can never end up inside a deliverable.
# SNOWBALL_SNAPSHOT_ROOT relocates it (e.g. to a scratch drive); the copy
# then lands in <root>/u2-t3-snapshot-<date>/<dir>.
GEN1_ROOT="$LOG_ROOT/gen1"
GEN2_ROOT="$LOG_ROOT/gen2"
SNAPSHOT_ROOT="$LOG_ROOT/snapshot"

# The eleven upstream languages (porter included) and the ten of them that
# have a vendored py32 counterpart under tools/vendor/py32/.
GEN_LANGS="arabic dutch english french german italian porter portuguese russian spanish turkish"
PY32_LANGS="arabic dutch english french german italian portuguese russian spanish turkish"

# The translate stage's inputs and the module name written into each
# <lang>/moon.pkg import.  The input list is the eleven deliverables (the
# same eleven the generate stage produces; porter311 is not a deliverable),
# and the module name is read from moon.mod, never hard-coded.
TR_LANGS="$GEN_LANGS"
TR_MODULE_NAME=$(sed -n 's/^[[:space:]]*name[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' "$MODULE_ROOT/moon.mod" | sed -n 1p)
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
    emit_root sb_root "$SB_ROOT_ABS" "$SB_SRC"
}

# gen_log <text> — one line to the generate stage's own log.
gen_log() {
    printf '%s\n' "$*" >>"$GENERATE_LOG" 2>/dev/null || true
}

# gen_emit <text> — one line to stdout and to the generate stage's log.
gen_emit() {
    printf '%s\n' "$*"
    gen_log "$*"
}

# gen_fail <text> — one line to stderr, the run log and the generate log.
gen_fail() {
    log_err "$*"
    gen_log "$*"
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
    printf '%s\n' "usage: sh scripts/pipeline.sh [--data-root PATH] [--out PATH] [--vendor PATH] [--sb-root PATH] [--stage STAGE | --only STAGE]"
    printf '%s\n' "stages: $STAGES"
    printf '%s\n' "  --stage=<s> runs the stages up to and including <s> (default: all six)"
    printf '%s\n' "  --only=<s>  runs exactly that one stage (mutually exclusive with --stage)"
    printf '%s\n' "  --sb-root=<p> directory of the upstream Snowball compiler (default: .probe/ctc/sbtest)"
}

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------

DATA_ROOT_ARG=""
OUT_ROOT_ARG=""
VENDOR_ROOT_ARG=""
SB_ROOT_ARG=""
STAGE_ARG=""
ONLY_ARG=""

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
        --sb-root=*) SB_ROOT_ARG="${1#--sb-root=}" ;;
        --sb-root)
            shift
            [ "$#" -gt 0 ] || { log_err "--sb-root needs a value"; exit "$EXIT_USAGE"; }
            SB_ROOT_ARG="$1"
            ;;
        --only=*) ONLY_ARG="${1#--only=}" ;;
        --only)
            shift
            [ "$#" -gt 0 ] || { log_err "--only needs a value"; exit "$EXIT_USAGE"; }
            ONLY_ARG="$1"
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

if [ -n "$STAGE_ARG" ] && [ -n "$ONLY_ARG" ]; then
    log_err "--stage and --only are mutually exclusive"
    exit "$EXIT_USAGE"
fi

if [ -n "$ONLY_ARG" ]; then
    _found=0
    for _s in $STAGES; do
        if [ "$_s" = "$ONLY_ARG" ]; then
            _found=1
            break
        fi
    done
    if [ "$_found" -ne 1 ]; then
        log_err "unknown stage: $ONLY_ARG (expected one of: $STAGES)"
        exit "$EXIT_USAGE"
    fi
    RUN_STAGES="$ONLY_ARG"
elif [ -n "$STAGE_ARG" ]; then
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

# stage_selected <name> — is <name> one of the stages this run enters?
stage_selected() {
    for _s in $RUN_STAGES; do
        if [ "$_s" = "$1" ]; then
            return 0
        fi
    done
    return 1
}

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

# The upstream Snowball compiler directory: flag > env > module-relative
# default (.probe/ctc/sbtest).  The default is resolved against the module
# root, so the same three-way precedence as the other roots holds.
if [ -n "$SB_ROOT_ARG" ]; then
    SB_SRC=flag
    SB_VAL="$SB_ROOT_ARG"
elif [ -n "${SNOWBALL_SB_ROOT:-}" ]; then
    SB_SRC=env
    SB_VAL="$SNOWBALL_SB_ROOT"
else
    SB_SRC=default
    SB_VAL="$MODULE_ROOT/.probe/ctc/sbtest"
fi

DATA_ROOT_ABS=$(abs_of "$DATA_VAL")
OUT_ROOT_ABS=$(abs_of "$OUT_VAL")
VENDOR_ROOT_ABS=$(abs_of "$VENDOR_VAL")
SB_ROOT_ABS=$(abs_of "$SB_VAL")

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

case "$SB_SRC" in
    flag) require_existing "sb_root (--sb-root)" "$SB_VAL" ;;
    env) require_existing "sb_root (SNOWBALL_SB_ROOT)" "$SB_VAL" ;;
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
    # ------------------------------------------------------------------
    # Task 3 - the Snowball generator.
    #
    # Three generations, one per target directory:
    #
    #     gen1  -> $GEN1_ROOT     parity baseline A
    #     gen2  -> $GEN2_ROOT     parity baseline B
    #     out   -> $OUT_ROOT_ABS  the deliverable copy
    #
    # and the two claims the pipeline is allowed to make afterwards:
    #
    #     generated 11/11          gen1 and gen2 are byte-identical
    #     py32 covered 10/10 SAME  the ten vendored py32 stemmers are
    #                               byte-identical to gen1
    #
    # porter has no vendored py32 counterpart: its baseline is gen1 vs
    # gen2 only, and that is what the log says.
    #
    # The upstream compiler is a Linux ELF, so every generation happens
    # inside WSL: from the host the stage enters WSL exactly once per
    # generation (wsl -e bash -lc '...'), inside WSL it calls
    # tools/gen_all.sh directly and never calls wsl again.
    # ------------------------------------------------------------------

    # The detail log describes the most recent run only.
    : > "$GENERATE_LOG" 2>/dev/null || true

    GEN_SNAPSHOT_DATE=$(date +%Y%m%d-%H%M%S)

    # -- 1. snapshot (the destructive-op precondition) ------------------
    # Every directory the stage overwrites is copied into the snapshot
    # area first, and the copy is confirmed before anything is written.
    # The snapshot area lives outside every directory the stage writes,
    # so a copy can never end up inside a deliverable.
    _gen_preserved=0
    for _gen_pair in "out_root=$OUT_ROOT_ABS" "gen1=$GEN1_ROOT" "gen2=$GEN2_ROOT"; do
        _gen_tag=${_gen_pair%%=*}
        _gen_dir=${_gen_pair#*=}
        [ -d "$_gen_dir" ] || continue
        _gen_snap="$SNAPSHOT_ROOT/$_gen_tag-$GEN_SNAPSHOT_DATE"
        mkdir -p "$SNAPSHOT_ROOT" 2>/dev/null || true
        if ! cp -r "$_gen_dir" "$_gen_snap" 2>/dev/null; then
            gen_fail "generate failed: cannot snapshot $_gen_dir into $_gen_snap"
            return "$EXIT_GENERATE"
        fi
        if [ ! -d "$_gen_snap" ]; then
            gen_fail "generate failed: the snapshot copy $_gen_snap does not exist"
            return "$EXIT_GENERATE"
        fi
        log_line "snapshot: preserved $_gen_dir -> $_gen_snap"
        _gen_preserved=1
    done
    if [ "$_gen_preserved" -eq 0 ]; then
        log_line "snapshot: nothing to preserve"
    fi

    # -- 2. path conversion --------------------------------------------
    # The four roots as WSL paths.  From the host the conversion runs
    # inside WSL (wslpath is not on the host PATH): cygpath gives the
    # Windows side, wslpath -a -u the Unix side.  A host-namespace
    # /f/... path is never handed to WSL.  Inside WSL the roots already
    # are WSL paths, so wslpath is not called again.
    if [ "$HOST" != wsl ] && ! command -v cygpath >/dev/null 2>&1; then
        gen_fail "generate failed: cannot convert the roots to WSL paths: no cygpath on the host (gcc/make hint: the upstream compiler is a Linux ELF and must be built/run inside WSL)"
        return "$EXIT_GENERATE"
    fi
    if [ "$HOST" = wsl ]; then
        _gen_paths="$SB_ROOT_ABS
$OUT_ROOT_ABS
$GEN1_ROOT
$GEN2_ROOT"
    else
        _gen_paths=$(
            for _gen_p in "$SB_ROOT_ABS" "$OUT_ROOT_ABS" "$GEN1_ROOT" "$GEN2_ROOT"; do
                _gen_win=$(cygpath -w "$_gen_p" 2>/dev/null) || _gen_win=""
                printf '%s\n' "$_gen_win"
            done | wsl -e bash -lc 'while IFS= read -r p; do u=$(wslpath -a -u "$p" 2>/dev/null) || u=""; printf "%s\n" "$u"; done' | tr -d "\r"
        )
    fi
    _gen_sb_unix=$(printf '%s\n' "$_gen_paths" | sed -n 1p)
    _gen_out_unix=$(printf '%s\n' "$_gen_paths" | sed -n 2p)
    _gen_gen1_unix=$(printf '%s\n' "$_gen_paths" | sed -n 3p)
    _gen_gen2_unix=$(printf '%s\n' "$_gen_paths" | sed -n 4p)
    for _gen_check in "sb_root=$_gen_sb_unix" "out_root=$_gen_out_unix" "gen1_root=$_gen_gen1_unix" "gen2_root=$_gen_gen2_unix"; do
        _gen_label=${_gen_check%%=*}
        _gen_value=${_gen_check#*=}
        case "$_gen_value" in
            /*) : ;;
            *)
                gen_fail "generate failed: cannot convert $_gen_label to a WSL path (gcc/make hint: the upstream compiler is a Linux ELF and must be built/run inside WSL)"
                return "$EXIT_GENERATE"
                ;;
        esac
    done

    # -- 3. the three generations ---------------------------------------
    # The generation runs inside WSL.  From the host the stage enters
    # WSL exactly once per generation; inside WSL it calls
    # tools/gen_all.sh directly and never calls wsl again (that
    # self-nesting is what produced exit 127).
    gen_exec() {
        if [ "$HOST" = wsl ]; then
            ( cd "$MODULE_ROOT" && sh "$MODULE_ROOT/tools/gen_all.sh" "$_gen_sb_unix" "$1" )
        else
            # MSYS_NO_PATHCONV=1: the MSYS runtime would otherwise rewrite
            # the /mnt/... arguments into a Windows path (that is what
            # produced "D:/Program Files/Git/mnt/f/..."), and the WSL
            # side must see the Unix path verbatim.  MSYS2_ARG_CONV_EXCL
            # is the same switch for the MSYS2 runtime.
            ( cd "$MODULE_ROOT" && MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' wsl -e bash -lc 'cd "$(wslpath -a -u .)" && sh tools/gen_all.sh "$1" "$2"' _ "$_gen_sb_unix" "$1" )
        fi
    }
    : > "$GENERATE_RAW_LOG" 2>/dev/null || true
    for _gen_target in "gen1=$_gen_gen1_unix" "gen2=$_gen_gen2_unix" "out=$_gen_out_unix"; do
        _gen_tag=${_gen_target%%=*}
        _gen_dest=${_gen_target#*=}
        printf '=== generation %s -> %s\n' "$_gen_tag" "$_gen_dest" >> "$GENERATE_RAW_LOG" 2>/dev/null || true
        gen_exec "$_gen_dest" >> "$GENERATE_RAW_LOG" 2>&1
        _gen_rc=$?
        if [ "$_gen_rc" -ne 0 ]; then
            gen_fail "generate failed: the $_gen_tag generation failed (exit=$_gen_rc) (gcc/make hint: the upstream Snowball compiler is a Linux ELF, it must be built and run inside WSL - wsl/gcc/make)"
            tail -n 20 "$GENERATE_RAW_LOG" 2>/dev/null
            return "$EXIT_GENERATE"
        fi
        if [ "$_gen_tag" = "gen1" ]; then
            # The per-language command lines, derived from the very same
            # variables the generator was called with, so they cannot
            # drift from what actually ran.
            for _gen_lang in $GEN_LANGS; do
                gen_emit "stage=generate lang=$_gen_lang cmd=$_gen_sb_unix/snowball $_gen_sb_unix/algorithms/$_gen_lang.sbl -python -eprefix _ -o $_gen_gen1_unix/${_gen_lang}_stemmer.py"
            done
        fi
    done

    # -- 4. parity ------------------------------------------------------
    # gen1 against gen2 for the eleven upstream languages, and gen1
    # against the vendored py32 stemmers for the ten that have one.
    _gen_same=0
    for _gen_lang in $GEN_LANGS; do
        if cmp -s "$GEN1_ROOT/${_gen_lang}_stemmer.py" "$GEN2_ROOT/${_gen_lang}_stemmer.py"; then
            _gen_same=$((_gen_same + 1))
        else
            gen_fail "generate failed: $_gen_lang differs (gen1 vs gen2)"
            gen_fail "generate failed: differing files: $GEN1_ROOT/${_gen_lang}_stemmer.py $GEN2_ROOT/${_gen_lang}_stemmer.py"
            return "$EXIT_GENERATE"
        fi
    done
    if [ "$_gen_same" -eq 11 ]; then
        gen_emit "generated $_gen_same/11"
    fi
    _gen_py32=0
    for _gen_lang in $PY32_LANGS; do
        if cmp -s "$GEN1_ROOT/${_gen_lang}_stemmer.py" "$VENDOR_ROOT_ABS/py32/${_gen_lang}_stemmer.py"; then
            _gen_py32=$((_gen_py32 + 1))
        else
            gen_fail "generate failed: $_gen_lang differs (gen1 vs the vendored py32 stemmer)"
            gen_fail "generate failed: differing files: $GEN1_ROOT/${_gen_lang}_stemmer.py $VENDOR_ROOT_ABS/py32/${_gen_lang}_stemmer.py"
            return "$EXIT_GENERATE"
        fi
    done
    if [ "$_gen_py32" -eq 10 ]; then
        gen_emit "py32 covered $_gen_py32/10 SAME"
    fi
    gen_emit "porter: no vendored py32 counterpart; its baseline is gen1 vs gen2 only (it is part of the 11/11 claim, never of the py32 count)"
    return 0
}

stage_translate() {
    # ------------------------------------------------------------------
    # Task 4 - the translator segment.
    #
    # Input:  $OUT_ROOT_ABS, the pipeline's resolved out_root (default
    #         build/gen), holding the eleven generated
    #         <lang>_stemmer.py files.  The default input list is the
    #         eleven deliverables of tools/lang_inputs.py; porter311 is
    #         NOT among them (it needs --include-control, which is Task
    #         10's business and is never passed here).
    # Output: <module-root>/<lang>/<lang>_gen.mbt (raw translator output)
    #         + <module-root>/<lang>/moon.pkg, one package per language.
    # Refusal: tools/translate.py writes only after a full AST rewrite, so
    #          a refusal leaves no file behind; the stage propagates the
    #          exit code and no later stage is entered.
    #
    # The detail log describes the most recent run only.
    # ------------------------------------------------------------------

    # tr_log <text> — one line to the translate stage's own log.
    tr_log() {
        printf '%s\n' "$*" >>"$TRANSLATE_LOG" 2>/dev/null || true
    }

    # tr_emit <text> — one line to stdout and to the translate log.
    tr_emit() {
        printf '%s\n' "$*"
        tr_log "$*"
    }

    # tr_fail <text> — one line to stderr, the run log and the translate log.
    tr_fail() {
        log_err "$*"
        tr_log "$*"
    }

    # tr_fatal <text> — a failure that ends the stage with $EXIT_TRANSLATE.
    tr_fatal() {
        tr_fail "$*"
        return "$EXIT_TRANSLATE"
    }

    : > "$TRANSLATE_LOG" 2>/dev/null || true

    # -- 1. snapshot (the destructive-op precondition) ------------------
    # Every deliverable the stage overwrites is copied out of the module
    # first, and the copy is confirmed before anything is written.  The
    # snapshot area lives outside the module, so a copy can never end up
    # inside a deliverable.
    TR_SNAPSHOT_DATE=$(date +%Y%m%d-%H%M%S)
    TR_SNAPSHOT_DIR="$TR_SNAPSHOT_ROOT/u2-t4-snapshot-$TR_SNAPSHOT_DATE"
    _tr_need_snapshot=0
    for _tr_lang in $TR_LANGS; do
        if [ -e "$MODULE_ROOT/$_tr_lang/${_tr_lang}_gen.mbt" ]; then
            _tr_need_snapshot=1
            break
        fi
    done
    if [ "$_tr_need_snapshot" -eq 1 ]; then
        if ! mkdir -p "$TR_SNAPSHOT_DIR" 2>/dev/null; then
            tr_fail "translate failed: cannot create the snapshot directory $TR_SNAPSHOT_DIR"
            return "$EXIT_TRANSLATE"
        fi
        for _tr_lang in $TR_LANGS; do
            [ -d "$MODULE_ROOT/$_tr_lang" ] || continue
            if ! cp -r "$MODULE_ROOT/$_tr_lang" "$TR_SNAPSHOT_DIR/" 2>/dev/null; then
                tr_fail "translate failed: cannot snapshot $MODULE_ROOT/$_tr_lang into $TR_SNAPSHOT_DIR"
                return "$EXIT_TRANSLATE"
            fi
            if [ ! -d "$TR_SNAPSHOT_DIR/$_tr_lang" ]; then
                tr_fail "translate failed: the snapshot copy $TR_SNAPSHOT_DIR/$_tr_lang does not exist"
                return "$EXIT_TRANSLATE"
            fi
        done
        tr_emit "snapshot: preserved the 11 language directories -> $TR_SNAPSHOT_DIR"
    else
        tr_emit "snapshot: nothing to preserve"
    fi

    # -- 2. inputs -------------------------------------------------------
    # The eleven generated Python stemmers.  A missing input names the
    # parameter it came from and the file that is absent; nothing has been
    # written at that point.
    if [ ! -d "$OUT_ROOT_ABS" ]; then
        tr_fatal "translate failed: out_root ($OUT_SRC --out) does not exist: $OUT_ROOT_ABS"
        return "$EXIT_TRANSLATE"
    fi
    for _tr_lang in $TR_LANGS; do
        if [ ! -f "$OUT_ROOT_ABS/${_tr_lang}_stemmer.py" ]; then
            tr_fatal "translate failed: missing input file: $OUT_ROOT_ABS/${_tr_lang}_stemmer.py (out_root, $OUT_SRC --out: $OUT_ROOT_ABS)"
            return "$EXIT_TRANSLATE"
        fi
    done

    # -- 3. the eleven translations --------------------------------------
    # tools/translate_all.py writes <lang>/<lang>_gen.mbt and, when absent,
    # <lang>/moon.pkg.  The eleven deliverables are its default selection;
    # --include-control (porter311) is never passed here.
    : > "$TRANSLATE_RAW_LOG" 2>/dev/null || true
    TR_CMD="$PYTHON_BIN tools/translate_all.py --gen-dir $OUT_ROOT_ABS --out-root $MODULE_ROOT --module $TR_MODULE_NAME"
    tr_log "cmd=$TR_CMD"
    ( cd "$MODULE_ROOT" && $PYTHON_BIN tools/translate_all.py \
        --gen-dir "$OUT_ROOT_ABS" \
        --out-root "$MODULE_ROOT" \
        --module "$TR_MODULE_NAME" ) >>"$TRANSLATE_RAW_LOG" 2>&1
    _tr_rc=$?
    tr_log "$(cat "$TRANSLATE_RAW_LOG" 2>/dev/null)"
    if [ "$_tr_rc" -ne 0 ]; then
        tr_fail "translate failed: tools/translate_all.py failed (exit=$_tr_rc) cmd=$TR_CMD"
        tail -n 20 "$TRANSLATE_RAW_LOG" 2>/dev/null >&2
        return "$EXIT_TRANSLATE"
    fi

    # Per-language lines: file, out, raw line count, elapsed seconds.  The
    # counts are the translator's raw output; the post-moon fmt counts are
    # Task 5's business.
    _tr_total=0
    _tr_start=$(date +%s)
    for _tr_lang in $TR_LANGS; do
        _tr_py="$OUT_ROOT_ABS/${_tr_lang}_stemmer.py"
        _tr_mbt="$MODULE_ROOT/$_tr_lang/${_tr_lang}_gen.mbt"
        if [ ! -f "$_tr_mbt" ]; then
            tr_fail "translate failed: expected output missing: $_tr_mbt"
            return "$EXIT_TRANSLATE"
        fi
        _tr_lines=$(wc -l <"$_tr_mbt" | tr -d ' ')
        _tr_total=$((_tr_total + _tr_lines))
        _tr_now=$(date +%s)
        tr_emit "stage=translate lang=$_tr_lang file=$_tr_py out=$_tr_mbt lines=$_tr_lines elapsed=$((_tr_now - _tr_start))"
        _tr_start=$_tr_now
    done

    # -- 4. residue assertions -------------------------------------------
    # AD1-3 (`self.`), AD1-4 (`@rt::`) and AD1-5 (` in range(`) must be
    # absent from every generated file.  Each assertion runs separately so
    # a failure names the residue that fired.
    _tr_residues=0
    for _tr_res in 'self\.' '@rt::' ' in range('; do
        _tr_hits=$(grep -rn -- "$_tr_res" "$MODULE_ROOT"/*/[a-z]*_gen.mbt 2>/dev/null | wc -l)
        tr_emit "residue '$_tr_res' hits=$_tr_hits"
        if [ "$_tr_hits" -ne 0 ]; then
            _tr_residues=$((_tr_residues + _tr_hits))
            tr_fail "translate failed: residue '$_tr_res' found in the generated files ($_tr_hits hit(s))"
            tr_log "$(grep -rn -- "$_tr_res" "$MODULE_ROOT"/*/[a-z]*_gen.mbt 2>/dev/null | head -n 20)"
        fi
    done
    if [ "$_tr_residues" -ne 0 ]; then
        return "$EXIT_TRANSLATE"
    fi

    # -- 5. raise-count parity (AD1-1) -----------------------------------
    # One `raise labN` in Python must produce exactly one `raise @rt.LabN`
    # in MoonBit, per language.
    for _tr_lang in $TR_LANGS; do
        _tr_py="$OUT_ROOT_ABS/${_tr_lang}_stemmer.py"
        _tr_mbt="$MODULE_ROOT/$_tr_lang/${_tr_lang}_gen.mbt"
        _tr_a=$(grep -o "raise lab[0-4]" "$_tr_py" 2>/dev/null | wc -l)
        _tr_b=$(grep -o "raise @rt.Lab[0-4]" "$_tr_mbt" 2>/dev/null | wc -l)
        tr_emit "stage=translate lang=$_tr_lang raise_py=$_tr_a raise_mbt=$_tr_b"
        if [ "$_tr_a" != "$_tr_b" ]; then
            tr_fail "translate failed: $_tr_lang raise count differs (py=$_tr_a mbt=$_tr_b)"
            return "$EXIT_TRANSLATE"
        fi
    done

    tr_emit "translated 11/11 raw_lines=$_tr_total residues=0 raise-parity=11/11"
    return 0
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
