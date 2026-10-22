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
# only, and that is what the pipeline states.
#
# [2b] vendored-in (Task 10): the twelfth registered input, porter311, is
# never generated.  Its input is the vendored snowballstemmer-3.1.1
# porter_stemmer.py, taken as-is, so the stage only checks that the file
# exists and that its md5 still equals the registered value; it logs
# `stage=generate lang=porter311 source=vendored-3.1.1 md5=<value>` and no
# command line (there is no upstream command).  The generation counts above
# stay 11/11 + 10/10; the vendored file is a separate 1/1 claim.
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
# The fmt stage keeps its own detail log in .planning/logs/u2/T5-fmt.log
# (truncated at the start of every fmt run): the moon fmt command line, one
# line per deliverable with its post-fmt line count and md5, and the
# idempotence assertion (a second moon fmt changes no byte).  The two md5
# baselines land in T5-md5-a.txt / T5-md5-b.txt and the two line-count
# baselines in T5-lines-a.txt / T5-lines-b.txt.
#
# The unpack stage (Task 8) resolves the corpus root, reuses it when the
# eleven delivery inputs are already complete (`corpus=reused`, nothing is
# cloned), and otherwise fetches it with a partial clone + sparse-checkout.
# It then snapshots build/data/arabic and hands the decompression to
# tools/unpack_arabic.sh, which verifies an existing artifact by line count
# AND content hash rather than trusting non-emptiness.  Its evidence is in
# .planning/logs/u2/T8-unpack.log (append-only, written by the script) and
# .planning/logs/u2/T8-corpus.log (acquisition decision, per run).
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
#     8  the fmt stage failed (a deliverable is missing, moon fmt returned
#        non-zero, or a second pass changed a byte)
#     9  the unpack stage failed (the corpus is incomplete after the fetch,
#        git is missing, the clone failed, or the arabic artifact did not
#        verify)
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
EXIT_FMT=8
EXIT_UNPACK=9


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

# The fmt stage (Task 5) keeps its own detail log, truncated at the start of
# every fmt run: the command line, one line per deliverable (file, post-fmt
# line count, md5) and the idempotence assertion.  T5-md5-a/-b and
# T5-lines-a/-b are the two baselines the brief's acceptance command compares;
# the stage writes them itself so a run always leaves the same evidence.
FMT_LOG="$LOG_ROOT/T5-fmt.log"
FMT_MD5_A="$LOG_ROOT/T5-md5-a.txt"
FMT_MD5_B="$LOG_ROOT/T5-md5-b.txt"
FMT_LINES_A="$LOG_ROOT/T5-lines-a.txt"
FMT_LINES_B="$LOG_ROOT/T5-lines-b.txt"

# Where the fmt stage snapshots the deliverables before rewriting them.
# Outside the module by default (under the gitignored log root);
# SNOWBALL_T5_SNAPSHOT_ROOT relocates it, e.g. to F:/Temp.
T5_SNAPSHOT_ROOT="${SNOWBALL_T5_SNAPSHOT_ROOT:-$LOG_ROOT/snapshot}"

# The unpack stage (Task 8) materialises the arabic golden corpus.  Its detail
# log is appended to by tools/unpack_arabic.sh, so one file holds the evidence
# of every run; the corpus log records the acquisition decision (reused root
# vs. clone).  The decompressed cache lives under build/ (gitignored) and the
# corpus root is the pipeline's resolved data_root, never a hard-coded path.
UNPACK_LOG="$LOG_ROOT/T8-unpack.log"
CORPUS_LOG="$LOG_ROOT/T8-corpus.log"
UNPACK_SCRIPT="$MODULE_ROOT/tools/unpack_arabic.sh"
UNPACK_DST="$MODULE_ROOT/build/data/arabic"

# The eleven delivery inputs (brief Step 0c).  dutch_porter is optional: it is
# not a delivered stemmer (design NG-08), so its absence is recorded, never
# fatal.  arabic is the only language allowed to ship gzipped.
CORPUS_LANGS="english porter french german spanish italian portuguese dutch russian arabic turkish"
CORPUS_OPTIONAL="dutch_porter"
CORPUS_URL="${SNOWBALL_CORPUS_URL:-https://github.com/snowballstem/snowball-data}"


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

# The twelfth registered input: porter311.  It is not a deliverable and not
# in lang_registry.mbt, and it never reaches the upstream compiler — [2b]
# takes the vendored snowballstemmer-3.1.1 Python as-is.  The registered md5
# is the contract value (shared-interface §3.4); a different value is fatal,
# and the pipeline never rebuilds the file itself (that is U1-a's copy
# contract, so a missing file is reported, never silently repaired).
TR_CONTROL_LANGS="porter311"
VENDORED_PORTER311_REL="snowballstemmer-3.1.1/porter_stemmer.py"
VENDORED_PORTER311_MD5="50a9ce301dc157b611c8d3272eab4b28"

# The fmt stage's inputs: the same eleven deliverable packages the translate
# stage writes, plus the porter311 control package (12th gate row).  The
# formatter is named package by package, so the module root, runtime/ and
# cmd/golden/ are never rewritten by this stage.
FMT_LANGS="$GEN_LANGS"
FMT_CONTROL_LANGS="$TR_CONTROL_LANGS"

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
    # ------------------------------------------------------------------
    # Task 8 - the arabic unpack segment (corpus acquisition + verification).
    #
    # Step 0a: resolve the corpus root (DATA_ROOT_ABS, already resolved as
    #          flag > SNOWBALL_DATA_ROOT > module-relative default) and check
    #          the eleven delivery inputs BEFORE anything is fetched.  A
    #          complete corpus is used as-is: `corpus=reused`, nothing is
    #          cloned, whatever the source of the root.
    # Step 0b: only when an input is missing, fetch with the two-stage form
    #          (partial clone + sparse-checkout) that is the only shape that
    #          worked on this network; git < 2.19 (no --filter=blob:none)
    #          degrades to a plain --depth 1 clone.
    # Step 0c: assert the eleven inputs again (hard: any missing is fatal) and
    #          record dutch_porter, which is optional and never fatal.
    # Step 0d: a failed fetch exits non-zero with `corpus-clone-failed` on
    #          stderr and names SNOWBALL_DATA_ROOT as the escape hatch.  It
    #          never pretends to pass.
    #
    # Then: snapshot build/data/arabic (the destructive-op precondition) and
    # hand the decompression to tools/unpack_arabic.sh, which verifies an
    # existing artifact by line count AND content hash instead of trusting
    # non-emptiness (prototype defect P5).
    # ------------------------------------------------------------------

    # up_log <text> — one line to the corpus-acquisition log.
    up_log() {
        printf '%s\n' "$*" >>"$CORPUS_LOG" 2>/dev/null || true
    }

    # up_emit <text> — one line to stdout and to the corpus log.
    up_emit() {
        printf '%s\n' "$*"
        up_log "$*"
    }

    # up_fail <text> — one line to stderr, the run log and the corpus log.
    up_fail() {
        log_err "$*"
        up_log "$*"
    }

    # corpus_complete — every delivery input has a voc and an output side,
    # plain or gzipped (arabic is the only language shipped gzipped).
    corpus_complete() {
        for _cc_lang in $CORPUS_LANGS; do
            if [ ! -f "$DATA_ROOT_ABS/$_cc_lang/voc.txt" ] && [ ! -f "$DATA_ROOT_ABS/$_cc_lang/voc.txt.gz" ]; then
                return 1
            fi
            if [ ! -f "$DATA_ROOT_ABS/$_cc_lang/output.txt" ] && [ ! -f "$DATA_ROOT_ABS/$_cc_lang/output.txt.gz" ]; then
                return 1
            fi
        done
        return 0
    }

    # The corpus log describes the most recent run only (the unpack log is
    # append-only: tools/unpack_arabic.sh owns it).
    : > "$CORPUS_LOG" 2>/dev/null || true
    up_emit "corpus_root=$DATA_ROOT_ABS source=$DATA_SRC"
    up_emit "corpus_url=$CORPUS_URL"

    # -- 0a. resolve, then decide: reuse or fetch ----------------------
    if corpus_complete; then
        up_emit "corpus=reused root=$DATA_ROOT_ABS source=$DATA_SRC"
    else
        up_emit "corpus=missing root=$DATA_ROOT_ABS source=$DATA_SRC"

        # -- 0b. fetch (partial clone + sparse-checkout) ---------------
        if ! command -v git >/dev/null 2>&1; then
            up_fail "corpus-clone-failed: git is not on PATH; set SNOWBALL_DATA_ROOT to an existing corpus copy"
            return "$EXIT_UNPACK"
        fi
        _up_git_version=$(git --version 2>/dev/null | sed -n 's/.* \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | sed -n 1p)
        _up_git_major=${_up_git_version%%.*}
        _up_git_minor=${_up_git_version#*.}
        [ -n "$_up_git_version" ] || { _up_git_major=0; _up_git_minor=0; }
        up_emit "corpus_git_version=${_up_git_version:-unknown}"

        # git refuses to clone into a non-empty directory, so a root that
        # exists without being a clone cannot be fetched into: say so
        # instead of failing obscurely.
        _up_parent=$(dirname "$DATA_ROOT_ABS")
        mkdir -p "$_up_parent" 2>/dev/null || true
        if [ -d "$DATA_ROOT_ABS" ] && [ ! -d "$DATA_ROOT_ABS/.git" ]; then
            up_fail "corpus-clone-failed: $DATA_ROOT_ABS exists but is not a git clone and does not hold a complete corpus; move it away or set SNOWBALL_DATA_ROOT to a complete copy"
            return "$EXIT_UNPACK"
        fi

        if [ "$_up_git_major" -gt 2 ] || { [ "$_up_git_major" -eq 2 ] && [ "$_up_git_minor" -ge 19 ]; }; then
            up_emit "corpus_fetch=partial-clone filter=blob:none sparse=1"
            if ! git clone --depth 1 --filter=blob:none --sparse "$CORPUS_URL" "$DATA_ROOT_ABS" >>"$CORPUS_LOG" 2>&1; then
                up_fail "corpus-clone-failed: git clone --filter=blob:none --sparse $CORPUS_URL $DATA_ROOT_ABS failed; if this machine already has the corpus, set SNOWBALL_DATA_ROOT to point at it, or set SNOWBALL_CORPUS_URL to a reachable mirror"
                return "$EXIT_UNPACK"
            fi
        else
            up_emit "corpus_fetch=depth-1-clone filter=none (git $_up_git_version < 2.19, --filter unsupported)"
            if ! git clone --depth 1 "$CORPUS_URL" "$DATA_ROOT_ABS" >>"$CORPUS_LOG" 2>&1; then
                up_fail "corpus-clone-failed: git clone --depth 1 $CORPUS_URL $DATA_ROOT_ABS failed; if this machine already has the corpus, set SNOWBALL_DATA_ROOT to point at it, or set SNOWBALL_CORPUS_URL to a reachable mirror"
                return "$EXIT_UNPACK"
            fi
        fi

        # The sparse set is re-entrant: re-running the stage resumes it.
        if ! ( cd "$DATA_ROOT_ABS" && git sparse-checkout set english porter french german spanish italian portuguese dutch dutch_porter russian arabic turkish ) >>"$CORPUS_LOG" 2>&1; then
            up_fail "corpus-clone-failed: git sparse-checkout set failed in $DATA_ROOT_ABS; re-run the stage (it is re-entrant) or set SNOWBALL_DATA_ROOT to an existing corpus copy"
            return "$EXIT_UNPACK"
        fi
        up_emit "corpus=fetched root=$DATA_ROOT_ABS"
    fi

    # -- 0c. completeness assertion ------------------------------------
    if ! corpus_complete; then
        _up_missing=""
        for _up_lang in $CORPUS_LANGS; do
            if [ ! -f "$DATA_ROOT_ABS/$_up_lang/voc.txt" ] && [ ! -f "$DATA_ROOT_ABS/$_up_lang/voc.txt.gz" ]; then
                _up_missing="$_up_missing $_up_lang(voc)"
            elif [ ! -f "$DATA_ROOT_ABS/$_up_lang/output.txt" ] && [ ! -f "$DATA_ROOT_ABS/$_up_lang/output.txt.gz" ]; then
                _up_missing="$_up_missing $_up_lang(output)"
            fi
        done
        up_fail "MISSING corpus after fetch:$_up_missing (root=$DATA_ROOT_ABS); set SNOWBALL_DATA_ROOT to an existing corpus copy"
        return "$EXIT_UNPACK"
    fi
    up_emit "corpus_complete 11/11 root=$DATA_ROOT_ABS"
    if [ -d "$DATA_ROOT_ABS/$CORPUS_OPTIONAL" ]; then
        up_emit "optional $CORPUS_OPTIONAL present"
    else
        up_emit "optional $CORPUS_OPTIONAL absent (N/A)"
    fi
    _up_du=$(du -sh "$DATA_ROOT_ABS" 2>/dev/null | awk '{print $1}')
    up_emit "corpus_du=${_up_du:-unknown}"

    # -- 1. snapshot (the destructive-op precondition) ------------------
    UP_SNAPSHOT_DATE=$(date +%Y%m%d-%H%M%S)
    if [ -d "$UNPACK_DST" ]; then
        _up_snap="$SNAPSHOT_ROOT/u2-t8-$UP_SNAPSHOT_DATE"
        mkdir -p "$SNAPSHOT_ROOT" 2>/dev/null || true
        if ! cp -r "$UNPACK_DST" "$_up_snap" 2>/dev/null || [ ! -d "$_up_snap" ]; then
            up_fail "unpack failed: cannot snapshot $UNPACK_DST into $_up_snap"
            return "$EXIT_UNPACK"
        fi
        log_line "snapshot: preserved $UNPACK_DST -> $_up_snap"
        up_emit "snapshot=$_up_snap"
    else
        log_line "snapshot: nothing to preserve ($UNPACK_DST does not exist)"
        up_emit "snapshot=none ($UNPACK_DST absent)"
    fi

    # -- 2. the arabic corpus ------------------------------------------
    if [ ! -f "$UNPACK_SCRIPT" ]; then
        up_fail "unpack failed: the unpack script is missing: $UNPACK_SCRIPT"
        return "$EXIT_UNPACK"
    fi
    if [ ! -d "$DATA_ROOT_ABS/arabic" ]; then
        up_fail "unpack failed: missing $DATA_ROOT_ABS/arabic (absolute: $DATA_ROOT_ABS/arabic)"
        return "$EXIT_UNPACK"
    fi
    # tools/unpack_arabic.sh appends its own evidence to $UNPACK_LOG and
    # prints the same lines, so nothing is redirected here (a redirect would
    # duplicate every line and hide the failure text from the operator).
    SNOWBALL_UNPACK_LOG="$UNPACK_LOG" sh "$UNPACK_SCRIPT" "$DATA_ROOT_ABS/arabic" "$UNPACK_DST"
    _up_rc=$?
    if [ "$_up_rc" -ne 0 ]; then
        up_fail "unpack failed: tools/unpack_arabic.sh $DATA_ROOT_ABS/arabic $UNPACK_DST exited $_up_rc"
        return "$EXIT_UNPACK"
    fi


    return 0
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
    # [2b] vendored-in (Task 10): the twelfth registered input, porter311,
    # is not generated at all.  Its input is the vendored snowballstemmer
    # 3.1.1 porter_stemmer.py, taken as-is, so the stage only verifies that
    # the file exists and that its md5 still equals the registered value and
    # logs `stage=generate lang=porter311 source=vendored-3.1.1 md5=<value>`
    # with NO command line (there is no upstream compiler invocation).  The
    # check runs before the generations: a missing or changed vendored file
    # stops the stage, and no `.mbt` is ever written for it here.
    #
    # The upstream compiler is a Linux ELF, so every generation happens
    # inside WSL: from the host the stage enters WSL exactly once per
    # generation (wsl -e bash -lc '...'), inside WSL it calls
    # tools/gen_all.sh directly and never calls wsl again.
    # ------------------------------------------------------------------

    # The detail log describes the most recent run only.
    : > "$GENERATE_LOG" 2>/dev/null || true

    # -- 0. [2b] vendored-in: the porter311 control input ---------------
    # Not a generation: the twelfth registered input is the vendored
    # snowballstemmer-3.1.1 porter_stemmer.py, so all the stage can do is
    # verify it is still the registered bytes.  The check runs first, before
    # any snapshot or compiler invocation, so a broken vendored input fails
    # the stage immediately and no `.mbt` is ever written for it.
    #
    #     missing        stderr names the absolute path and `vendor missing`;
    #                    the recovery is U1-a's copy contract, so the
    #                    pipeline never rebuilds the file itself.
    #     md5 drift      stderr names the actual and the registered value.
    _gen_vend="$VENDOR_ROOT_ABS/$VENDORED_PORTER311_REL"
    if [ ! -f "$_gen_vend" ]; then
        gen_fail "generate failed: vendor missing: $_gen_vend (the vendored snowballstemmer-3.1.1 porter stemmer, registered as input 12; restore it by the U1-a copy contract from .planning/data/py-pkg/snowballstemmer/porter_stemmer.py and re-run)"
        return "$EXIT_GENERATE"
    fi
    _gen_vend_md5=$(md5sum "$_gen_vend" 2>/dev/null | cut -d' ' -f1)
    if [ "$_gen_vend_md5" != "$VENDORED_PORTER311_MD5" ]; then
        gen_fail "generate failed: vendored input md5 drift: $_gen_vend (actual=$_gen_vend_md5 registered=$VENDORED_PORTER311_MD5)"
        return "$EXIT_GENERATE"
    fi
    gen_emit "stage=generate lang=porter311 source=vendored-3.1.1 file=$_gen_vend md5=$_gen_vend_md5"
    gen_emit "vendored input 1/1 md5 unchanged"

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
    #         <lang>_stemmer.py files, plus the vendored snowballstemmer
    #         3.1.1 porter_stemmer.py of the twelfth input (porter311).
    #         The first invocation selects the eleven deliverables (the
    #         default of tools/lang_inputs.py); a second invocation selects
    #         porter311 with --lang porter311 --include-control, the only way
    #         a non-deliverable control entry is translated.
    # Output: <module-root>/<lang>/<lang>_gen.mbt (raw translator output)
    #         + <module-root>/<lang>/moon.pkg, one package per input: the
    #         eleven deliverables and porter311 (the 12th gate row, never a
    #         deliverable and never a lang_registry.mbt entry).
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
    _tr_all_langs="$TR_LANGS $TR_CONTROL_LANGS"
    _tr_vend="$VENDOR_ROOT_ABS/$VENDORED_PORTER311_REL"

    # -- 1. snapshot (the destructive-op precondition) ------------------
    # Every input the stage overwrites is copied out of the module first,
    # and the copy is confirmed before anything is written.  The snapshot
    # area lives outside the module, so a copy can never end up inside a
    # deliverable.
    TR_SNAPSHOT_DATE=$(date +%Y%m%d-%H%M%S)
    TR_SNAPSHOT_DIR="$TR_SNAPSHOT_ROOT/u2-t4-snapshot-$TR_SNAPSHOT_DATE"
    _tr_need_snapshot=0
    for _tr_lang in $_tr_all_langs; do
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
        for _tr_lang in $_tr_all_langs; do
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
        tr_emit "snapshot: preserved the 12 language directories -> $TR_SNAPSHOT_DIR"
    else
        tr_emit "snapshot: nothing to preserve"
    fi

    # -- 2. inputs -------------------------------------------------------
    # The eleven generated Python stemmers plus the one vendored file.  A
    # missing input names the parameter it came from and the file that is
    # absent; nothing has been written at that point.  porter311's absence is
    # reported as `vendor missing`, exactly as the generate stage does.
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
    if [ ! -f "$_tr_vend" ]; then
        tr_fatal "translate failed: vendor missing: $_tr_vend (the vendored snowballstemmer-3.1.1 porter stemmer, registered as input 12; restore it by the U1-a copy contract from .planning/data/py-pkg/snowballstemmer/porter_stemmer.py and re-run)"
        return "$EXIT_TRANSLATE"
    fi
    _tr_vend_md5=$(md5sum "$_tr_vend" 2>/dev/null | cut -d' ' -f1)
    if [ "$_tr_vend_md5" != "$VENDORED_PORTER311_MD5" ]; then
        tr_fatal "translate failed: vendored input md5 drift: $_tr_vend (actual=$_tr_vend_md5 registered=$VENDORED_PORTER311_MD5)"
        return "$EXIT_TRANSLATE"
    fi

    # -- 3. the twelve translations --------------------------------------
    # tools/translate_all.py writes <lang>/<lang>_gen.mbt and, when absent,
    # <lang>/moon.pkg.  Two invocations: the eleven deliverables (the
    # script's default selection) and then the porter311 control entry, which
    # needs --include-control.  Each is logged with its own command.
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
    TR_CTRL_CMD="$PYTHON_BIN tools/translate_all.py --gen-dir $OUT_ROOT_ABS --out-root $MODULE_ROOT --module $TR_MODULE_NAME --lang $TR_CONTROL_LANGS --include-control"
    tr_log "cmd=$TR_CTRL_CMD"
    ( cd "$MODULE_ROOT" && $PYTHON_BIN tools/translate_all.py \
        --gen-dir "$OUT_ROOT_ABS" \
        --out-root "$MODULE_ROOT" \
        --module "$TR_MODULE_NAME" \
        --lang "$TR_CONTROL_LANGS" \
        --include-control ) >>"$TRANSLATE_RAW_LOG" 2>&1
    _tr_rc=$?
    tr_log "$(cat "$TRANSLATE_RAW_LOG" 2>/dev/null)"
    if [ "$_tr_rc" -ne 0 ]; then
        tr_fail "translate failed: tools/translate_all.py failed (exit=$_tr_rc) cmd=$TR_CTRL_CMD"
        tail -n 20 "$TRANSLATE_RAW_LOG" 2>/dev/null >&2
        return "$EXIT_TRANSLATE"
    fi

    # Per-language lines: file, out, raw line count, elapsed seconds.  The
    # counts are the translator's raw output; the post-moon fmt counts are
    # Task 5's business.  porter311's `file=` is the vendored Python: it has
    # no out_root copy, because [2b] never generates it.
    _tr_total=0
    _tr_start=$(date +%s)
    for _tr_lang in $_tr_all_langs; do
        _tr_py="$OUT_ROOT_ABS/${_tr_lang}_stemmer.py"
        if [ "$_tr_lang" = "$TR_CONTROL_LANGS" ]; then
            _tr_py="$_tr_vend"
        fi
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
    for _tr_lang in $_tr_all_langs; do
        _tr_py="$OUT_ROOT_ABS/${_tr_lang}_stemmer.py"
        if [ "$_tr_lang" = "$TR_CONTROL_LANGS" ]; then
            _tr_py="$_tr_vend"
        fi
        _tr_mbt="$MODULE_ROOT/$_tr_lang/${_tr_lang}_gen.mbt"
        _tr_a=$(grep -o "raise lab[0-4]" "$_tr_py" 2>/dev/null | wc -l)
        _tr_b=$(grep -o "raise @rt.Lab[0-4]" "$_tr_mbt" 2>/dev/null | wc -l)
        tr_emit "stage=translate lang=$_tr_lang raise_py=$_tr_a raise_mbt=$_tr_b"
        if [ "$_tr_a" != "$_tr_b" ]; then
            tr_fail "translate failed: $_tr_lang raise count differs (py=$_tr_a mbt=$_tr_b)"
            return "$EXIT_TRANSLATE"
        fi
    done

    tr_emit "translated 12/12 raw_lines=$_tr_total residues=0 raise-parity=12/12"
    return 0
}

stage_fmt() {
    # ------------------------------------------------------------------
    # Task 5 - the formatter segment (prototype defect P2).
    #
    # Input:  <module-root>/<lang>/<lang>_gen.mbt, the raw translator
    #         output the translate stage wrote.
    # Output: the same eleven files in their post-`moon fmt` form, which is
    #         the form the repository commits (R9: the deliverable is the
    #         raw output *after* normalisation, never a hand edit).
    #
    # `moon fmt` is invoked plainly, never with --check: on this machine
    # --check shells out to `git --no-pager diff` and dies with
    # `failed to execute git` (D-15).  The plain form is also what makes
    # the rewrite happen at all; idempotence is proved separately by
    # running the formatter a second time and comparing the md5 baselines.
    #
    # The formatter is run once over the twelve input packages by name, not
    # over the whole module: `moon fmt` with no path also rewrites runtime/,
    # cmd/golden/ and the root moon.pkg, and those are not this stage's
    # deliverables.  Naming the packages keeps the stage's write set exactly
    # the twelve *_gen.mbt files (the eleven deliverables + porter311).
    # The count claims keep the two populations apart: 11 deliverables =
    # 10,837 lines, and with the porter311 control row = 11,407 lines.
    #
    # The detail log describes the most recent run only.
    # ------------------------------------------------------------------

    # fmt_log <text> — one line to the fmt stage's own log.
    fmt_log() {
        printf '%s\n' "$*" >>"$FMT_LOG" 2>/dev/null || true
    }

    # fmt_emit <text> — one line to stdout and to the fmt log.
    fmt_emit() {
        printf '%s\n' "$*"
        fmt_log "$*"
    }

    # fmt_fail <text> — one line to stderr, the run log and the fmt log.
    fmt_fail() {
        log_err "$*"
        fmt_log "$*"
    }

    : > "$FMT_LOG" 2>/dev/null || true

    _fmt_start=$(date +%s)
    _fmt_all_langs="$FMT_LANGS $FMT_CONTROL_LANGS"

    # -- 1. inputs -------------------------------------------------------
    # Every input must exist before the formatter is allowed to run; a
    # missing one is a broken translate stage, not a fmt problem.  The
    # deliverables and the porter311 control row are counted apart.
    _fmt_files=0
    for _fmt_lang in $FMT_LANGS; do
        if [ ! -f "$MODULE_ROOT/$_fmt_lang/${_fmt_lang}_gen.mbt" ]; then
            fmt_fail "fmt failed: missing deliverable: $MODULE_ROOT/$_fmt_lang/${_fmt_lang}_gen.mbt (translate stage did not write it)"
            return "$EXIT_FMT"
        fi
        _fmt_files=$((_fmt_files + 1))
    done
    _fmt_ctrl=0
    for _fmt_lang in $FMT_CONTROL_LANGS; do
        if [ ! -f "$MODULE_ROOT/$_fmt_lang/${_fmt_lang}_gen.mbt" ]; then
            fmt_fail "fmt failed: missing control input: $MODULE_ROOT/$_fmt_lang/${_fmt_lang}_gen.mbt (translate stage did not write it)"
            return "$EXIT_FMT"
        fi
        _fmt_ctrl=$((_fmt_ctrl + 1))
    done
    fmt_emit "input: $_fmt_files/11 deliverable *_gen.mbt + $_fmt_ctrl/1 porter311 present (raw translator output)"

    # -- 2. snapshot (the destructive-op precondition) ------------------
    # `moon fmt` rewrites every selected .mbt in place, so the raw form is
    # copied out of the module first and the copy is confirmed before
    # anything is written.
    FMT_SNAPSHOT_DATE=$(date +%Y%m%d-%H%M%S)
    FMT_SNAPSHOT_DIR="$T5_SNAPSHOT_ROOT/u2-t5-snapshot-$FMT_SNAPSHOT_DATE"
    if ! mkdir -p "$FMT_SNAPSHOT_DIR" 2>/dev/null; then
        fmt_fail "fmt failed: cannot create the snapshot directory $FMT_SNAPSHOT_DIR"
        return "$EXIT_FMT"
    fi
    for _fmt_lang in $_fmt_all_langs; do
        if ! cp "$MODULE_ROOT/$_fmt_lang/${_fmt_lang}_gen.mbt" "$FMT_SNAPSHOT_DIR/" 2>/dev/null; then
            fmt_fail "fmt failed: cannot snapshot $_fmt_lang/${_fmt_lang}_gen.mbt into $FMT_SNAPSHOT_DIR"
            return "$EXIT_FMT"
        fi
        if [ ! -f "$FMT_SNAPSHOT_DIR/${_fmt_lang}_gen.mbt" ]; then
            fmt_fail "fmt failed: the snapshot copy $FMT_SNAPSHOT_DIR/${_fmt_lang}_gen.mbt does not exist"
            return "$EXIT_FMT"
        fi
    done
    fmt_emit "snapshot: preserved the 12 *_gen.mbt (raw form) -> $FMT_SNAPSHOT_DIR"

    # -- 3. the formatter ------------------------------------------------
    # One invocation, in the module root, over the twelve packages.  The
    # transcript goes to the fmt log, never through tee: the exit code
    # tested is moon's own.
    FMT_CMD="moon fmt $_fmt_all_langs"
    fmt_log "cmd=$FMT_CMD"
    ( cd "$MODULE_ROOT" && moon fmt $_fmt_all_langs ) >>"$FMT_LOG" 2>&1
    _fmt_rc=$?
    if [ "$_fmt_rc" -ne 0 ]; then
        fmt_fail "fmt failed: $FMT_CMD failed (exit=$_fmt_rc)"
        tail -n 20 "$FMT_LOG" 2>/dev/null >&2
        return "$EXIT_FMT"
    fi

    # -- 4. baseline A: the post-fmt form --------------------------------
    # md5 + line count per input.  The line counts are the spec's F-U2-21
    # table (10,837 lines over the eleven deliverables; porter311 adds its
    # own 570, for 11,407 over the twelve rows).
    ( cd "$MODULE_ROOT" && md5sum */[a-z]*_gen.mbt ) >"$FMT_MD5_A" 2>/dev/null
    if [ $? -ne 0 ]; then
        fmt_fail "fmt failed: cannot write the md5 baseline $FMT_MD5_A"
        return "$EXIT_FMT"
    fi
    ( cd "$MODULE_ROOT" && wc -l */[a-z]*_gen.mbt ) >"$FMT_LINES_A" 2>/dev/null
    if [ $? -ne 0 ]; then
        fmt_fail "fmt failed: cannot write the line-count baseline $FMT_LINES_A"
        return "$EXIT_FMT"
    fi
    _fmt_total=0
    _fmt_ctrl_total=0
    for _fmt_lang in $_fmt_all_langs; do
        _fmt_n=$(wc -l <"$MODULE_ROOT/$_fmt_lang/${_fmt_lang}_gen.mbt" 2>/dev/null | tr -d ' ')
        _fmt_md5=$(md5sum "$MODULE_ROOT/$_fmt_lang/${_fmt_lang}_gen.mbt" 2>/dev/null | cut -d' ' -f1)
        case " $FMT_LANGS " in
            *" $_fmt_lang "*) _fmt_total=$((_fmt_total + ${_fmt_n:-0})) ;;
            *) _fmt_ctrl_total=$((_fmt_ctrl_total + ${_fmt_n:-0})) ;;
        esac
        fmt_emit "stage=fmt lang=$_fmt_lang file=$_fmt_lang/${_fmt_lang}_gen.mbt lines=$_fmt_n md5=$_fmt_md5"
    done
    fmt_emit "formatted $_fmt_files/11 lines=$_fmt_total (post-moon fmt form)"
    fmt_emit "formatted porter311/1 lines=$_fmt_ctrl_total (control row; 12 inputs = $((_fmt_total + _fmt_ctrl_total)) lines)"

    # -- 5. idempotence: a second pass must not change a byte ------------
    ( cd "$MODULE_ROOT" && moon fmt $_fmt_all_langs ) >>"$FMT_LOG" 2>&1
    _fmt_rc2=$?
    if [ "$_fmt_rc2" -ne 0 ]; then
        fmt_fail "fmt failed: the idempotence re-run of $FMT_CMD failed (exit=$_fmt_rc2)"
        return "$EXIT_FMT"
    fi
    ( cd "$MODULE_ROOT" && md5sum */[a-z]*_gen.mbt ) >"$FMT_MD5_B" 2>/dev/null
    if [ $? -ne 0 ]; then
        fmt_fail "fmt failed: cannot write the md5 baseline $FMT_MD5_B"
        return "$EXIT_FMT"
    fi
    ( cd "$MODULE_ROOT" && wc -l */[a-z]*_gen.mbt ) >"$FMT_LINES_B" 2>/dev/null
    if ! cmp -s "$FMT_MD5_A" "$FMT_MD5_B"; then
        fmt_fail "fmt failed: moon fmt is not idempotent (md5 baseline A != B); version: $(moon version 2>/dev/null | sed -n 1p)"
        diff "$FMT_MD5_A" "$FMT_MD5_B" 2>/dev/null >&2
        return "$EXIT_FMT"
    fi
    if ! cmp -s "$FMT_LINES_A" "$FMT_LINES_B"; then
        fmt_fail "fmt failed: moon fmt is not idempotent (line-count baseline A != B)"
        return "$EXIT_FMT"
    fi
    fmt_emit "idempotent: second moon fmt left md5 and line counts unchanged"

    _fmt_now=$(date +%s)
    fmt_emit "stage=fmt files=$_fmt_files elapsed=$((_fmt_now - _fmt_start))"
    return 0
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
