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
#     An empty `--only=` is a usage error (exit 2), never "all six".
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
# FR-04 degrade (no WSL): when the host is not WSL and no working `wsl`
# exists, the upstream compiler cannot run at all.  The generate stage then
# takes its vendored branch: the ten tools/vendor/py32 stemmers are the
# generation result (they are byte-identical to the compiler output), the
# vendored porter311 input is verified exactly as [2b] does, and porter
# (the 3.2.0 algorithm, which has no vendored counterpart) is reused from
# out_root when a previous WSL run left it there.  With no cached porter the
# branch refuses (exit 6) instead of shipping a partial set, and an
# incomplete vendored directory is refused the same way (FE3).  The first
# line of such a run is
#     generate=skipped reason=no-wsl using=vendored
# followed by the vendored directory's absolute path; the wslpath probe is
# reported as skipped, and everything after generate is unchanged.
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
#    10  the check stage failed (moon check non-zero or not success, a
#        non-zero error/warning count, the 15-package assertion, moon info
#        failing, a `.mbti` count, a D-1 verdict, or a dialect retrieval hit)
#    11  the golden stage failed (a corpus file is missing, a voc/output line
#        count differs, a per-line mismatch, a row count other than 12, a
#        `checked` value other than the declared one, or a non-zero driver
#        exit - the tri-state gate scripts/gate.sh decides)
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
#
# FR-22 (no absolute paths in the delivered scripts) is audited by
# `sh scripts/pipeline.sh --audit-paths`, which runs tools/audit_paths.py over
# scripts/, tools/ and cmd/golden/.  The three patterns are assembled inside
# that helper, so this comment cannot match its own audit.  The audit MUST
# exclude __pycache__ (a plain directory walk is not enough): running any
# python helper writes .pyc files there that embed the absolute source path,
# so a naive grep reports build residue as if it were source.  .gitignore
# ignores *.pyc, but the audit walks the working tree and does not consult it.
# The helper takes `--root DIR`, which is how the same audit is proved not
# accidentally green against a renamed copy of the tree.

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
EXIT_CHECK=10
EXIT_GOLDEN=11

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

# The translate stage's raw transcript (its detail log is TRANSLATE_LOG).
TRANSLATE_RAW_LOG="$LOG_ROOT/T4-translate-raw.log"

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

# The check stage (Task 6) writes three evidence files.  CHECK_LOG is the raw
# `moon check --json` transcript (the brief's T6-check.json), CHECK_MBTI_LOG
# holds every `.mbti` count taken AFTER `moon info` (D-8), and
# CHECK_DIALECT_LOG holds the D-1 per-package verdicts, the two fail-closed
# cases and the D-2..D-6 / D-14 retrieval counts.  D-12 is not a retrieval:
# it checks the driver's entry point for an explicit non-zero exit path
# (`fn main` raises, or main wraps a raising function and calls native_exit).
# CHECK_LOG_TXT is the
# human-readable transcript of the assertion run; it is copied into the run log
# line by line and is not itself a deliverable.
CHECK_LOG="$LOG_ROOT/T6-check.json"
CHECK_MBTI_LOG="$LOG_ROOT/T6-mbti.log"
CHECK_DIALECT_LOG="$LOG_ROOT/T6-dialect.log"
CHECK_LOG_TXT="$LOG_ROOT/T6-check-assert.log"

# The python interpreter is a Windows build under Git-Bash: it cannot open a
# POSIX path such as /f/... .  Every path handed to python is therefore given
# relative to the module root (the subprocess runs with that cwd), which is
# valid in both namespaces; only the shell's own redirects use the absolute
# POSIX form above.
CHECK_LOG_REL=".planning/logs/u2/T6-check.json"
CHECK_MBTI_REL=".planning/logs/u2/T6-mbti.log"
CHECK_DIALECT_REL=".planning/logs/u2/T6-dialect.log"

# (The fmt stage snapshots through the shared snapshot_root helper below.)

# The unpack stage (Task 8) materialises the arabic golden corpus.  Its detail
# log is appended to by tools/unpack_arabic.sh, so one file holds the evidence
# of every run; the corpus log records the acquisition decision (reused root
# vs. clone).  The decompressed cache lives under build/ (gitignored) and the
# corpus root is the pipeline's resolved data_root, never a hard-coded path.
UNPACK_LOG="$LOG_ROOT/T8-unpack.log"
CORPUS_LOG="$LOG_ROOT/T8-corpus.log"
# The golden stage (Task 7) writes the driver transcript to T7-golden.log and
# the tri-state gate verdict to T7-gate.log.  The gate is scripts/gate.sh —
# the very script the negative tests invoke — so the stage and the tests can
# never disagree about what a healthy run looks like.
GOLDEN_LOG="$LOG_ROOT/T7-golden.log"
GOLDEN_GATE_LOG="$LOG_ROOT/T7-gate.log"
GOLDEN_GATE="$MODULE_ROOT/scripts/gate.sh"
UNPACK_SCRIPT="$MODULE_ROOT/tools/unpack_arabic.sh"
UNPACK_DST="$MODULE_ROOT/build/data/arabic"

# The eleven delivery inputs (brief Step 0c).  dutch_porter is optional: it is
# not a delivered stemmer (design NG-08), so its absence is recorded, never
# fatal.  arabic is the only language allowed to ship gzipped.
CORPUS_LANGS="english porter french german spanish italian portuguese dutch russian arabic turkish"
CORPUS_OPTIONAL="dutch_porter"
CORPUS_URL="${SNOWBALL_CORPUS_URL:-https://github.com/snowballstem/snowball-data}"


# The two parity directories.  Snapshots go through the shared
# snapshot_root helper below, which resolves
# ${SNOWBALL_SNAPSHOT_ROOT:-$LOG_ROOT/snapshot} for every stage (T3, T4, T5,
# T8).  The default is inside the module but under .planning/logs/, which is
# gitignored; set SNOWBALL_SNAPSHOT_ROOT to relocate it outside the tree.
GEN1_ROOT="$LOG_ROOT/gen1"
GEN2_ROOT="$LOG_ROOT/gen2"
SNAPSHOT_BASE="${SNOWBALL_SNAPSHOT_ROOT:-$LOG_ROOT/snapshot}"

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

# emit_regenerated <abs path> — FR-08's marker: one line per artifact a stage
# rewrote in this run.  It is NOT a `stage=` line and never replaces one; it
# exists so a hand edit that a re-run wipes out is visible in the run log.
emit_regenerated() {
    log_line "regenerated $1"
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
# Snapshot area — one resolution rule for every stage that copies a directory
# out of the way before rewriting it.
# ---------------------------------------------------------------------------

# snapshot_root <tag> — the directory this run snapshots into, as an absolute
# path: ${SNOWBALL_SNAPSHOT_ROOT:-$LOG_ROOT/snapshot}/<tag>-<date>.  The tag
# carries the stage (u2-t3, u2-t4, u2-t5, u2-t8).  A same-second re-run would
# otherwise nest the new copy inside the previous one, so an existing target
# gets a numeric suffix.  The directory is NOT created here: the caller makes
# it and reports the failure if it cannot.
snapshot_root() {
    _sr_tag="$1"
    _sr_base="$SNAPSHOT_BASE"
    case "$_sr_base" in
        /*) ;;
        *) _sr_base=$(abs_of "$_sr_base" "SNOWBALL_SNAPSHOT_ROOT") || return 1 ;;
    esac
    _sr_dir="$_sr_base/$_sr_tag-$(date +%Y%m%d-%H%M%S)"
    _sr_n=1
    while [ -e "$_sr_dir" ]; do
        _sr_dir="$_sr_base/$_sr_tag-$(date +%Y%m%d-%H%M%S)-$_sr_n"
        _sr_n=$((_sr_n + 1))
    done
    printf '%s\n' "$_sr_dir"
}

# ---------------------------------------------------------------------------
# Small path helpers
# ---------------------------------------------------------------------------

# The invocation directory in POSIX form.  `$PWD` is not reliable for this:
# under Git-Bash it can carry the Windows form (F:\...) while `pwd -P`
# returns the POSIX form (/f/...).  Every relative input is resolved against
# this value, so a printed result is absolute in the running namespace.
CWD_POSIX=$(pwd -P 2>/dev/null) || CWD_POSIX=""
case "$CWD_POSIX" in
    /*) ;;
    *) CWD_POSIX="" ;;
esac

# abs_of <path> <label> — absolute POSIX form of <path>, even when it does
# not exist.  The result ALWAYS starts with "/":
#
#   * a Windows drive path (X:\... or X:/...) is converted with cygpath -u
#     when cygpath is available, and refused with a message naming <label>
#     when it is not (the shell cannot address it otherwise);
#   * a path that is not absolute is prefixed with the POSIX invocation
#     directory, so a diagnostic never prints a bare relative path;
#   * the longest existing prefix is canonicalised with pwd -P.
#
# A leading "~" is NOT expanded: POSIX sh performs tilde expansion on words
# only, never on the contents of a variable, so "~/x" is the literal name
# "~/x" here and is resolved as a relative path.
#
# Failure (unconvertible drive path, no POSIX invocation directory) prints one
# diagnostic to stderr naming <label> and returns 1 with nothing on stdout.
abs_of() {
    _p="$1"
    _label="${2:-path}"
    # A drive root (X:, X:/, X:\) is recognised BEFORE the trailing separator
    # is stripped: stripping turns "F:/" into "F:", which then falls through
    # to the relative branch and resolves to "<cwd>/./F:".  Normalising it to
    # "X:/" keeps the drive test below matching, and cygpath -u then yields
    # the drive root "/x/".
    case "$_p" in
        [A-Za-z]:|[A-Za-z]:\\|[A-Za-z]:/) _p="${_p%:*}:/" ;;
        */) _p="${_p%/}" ;;
    esac
    [ -n "$_p" ] || _p="/"
    case "$_p" in
        [A-Za-z]:\\*|[A-Za-z]:/*)
            if command -v cygpath >/dev/null 2>&1; then
                _conv=$(cygpath -u "$_p" 2>/dev/null) || _conv=""
                if [ -z "$_conv" ]; then
                    log_err "$_label: cannot convert the Windows path to a POSIX path: $_p"
                    return 1
                fi
                _p="$_conv"
            else
                log_err "$_label: the Windows path cannot be used in this shell and cygpath is not available to convert it: $_p"
                return 1
            fi
            ;;
    esac
    case "$_p" in
        /*) ;;
        *)
            if [ -z "$CWD_POSIX" ]; then
                log_err "$_label: cannot resolve the relative path $_p (the invocation directory has no POSIX form)"
                return 1
            fi
            _p="$CWD_POSIX/$_p"
            ;;
    esac
    _dir=$(dirname "$_p")
    _base=$(basename "$_p")
    _adir=$(cd "$_dir" 2>/dev/null && pwd -P) || _adir=""
    if [ -z "$_adir" ]; then
        # The parent does not exist yet, but the value is still absolute.
        printf '%s\n' "$_p"
    elif [ "$_adir" = "/" ]; then
        printf '/%s\n' "$_base"
    else
        printf '%s/%s\n' "$_adir" "$_base"
    fi
}

# require_existing <param label> <path> — hard gate for flag/env roots.
# The message names the parameter and the resolved absolute path; the value
# printed is the already-resolved $..._ABS, which always starts with "/".
require_existing() {
    _re_abs=$(abs_of "$2" "$1") || _re_abs="$2"
    if [ ! -e "$2" ]; then
        log_err "$1 does not exist: $2 (resolved: $_re_abs)"
        emit_header
        exit "$EXIT_PATH"
    fi
    if [ ! -d "$2" ]; then
        log_err "$1 is not a directory: $2 (resolved: $_re_abs)"
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
    printf '%s\n' "  --audit-paths run only the FR-22 absolute-path audit and exit"
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
ONLY_SET=0
AUDIT_PATHS=0

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
        --only=*)
            ONLY_SET=1
            ONLY_ARG="${1#--only=}"
            ;;
        --only)
            shift
            [ "$#" -gt 0 ] || { log_err "--only needs a value"; exit "$EXIT_USAGE"; }
            ONLY_SET=1
            ONLY_ARG="$1"
            ;;
        --stage=*) STAGE_ARG="${1#--stage=}" ;;
        --stage)
            shift
            [ "$#" -gt 0 ] || { log_err "--stage needs a value"; exit "$EXIT_USAGE"; }
            STAGE_ARG="$1"
            ;;
        --audit-paths) AUDIT_PATHS=1 ;;
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
# FR-22 audit mode — `--audit-paths` runs tools/audit_paths.py and exits with
# its verdict (0 = no Windows absolute path in scripts/, tools/, cmd/golden/).
# It is a mode of its own: combining it with a stage selector would have to
# pick one silently.  The __pycache__/_build/.mooncakes exclusions live in the
# helper, next to the patterns they protect.
# ---------------------------------------------------------------------------

if [ "$AUDIT_PATHS" -eq 1 ]; then
    if [ -n "$STAGE_ARG" ] || [ "$ONLY_SET" -eq 1 ]; then
        log_err "--audit-paths is a mode of its own (not combinable with --stage/--only)"
        exit "$EXIT_USAGE"
    fi
    _ap_py=$(command -v python 2>/dev/null) || _ap_py=$(command -v python3 2>/dev/null) || _ap_py=""
    if [ -z "$_ap_py" ]; then
        log_err "audit-paths: python not found"
        exit "$EXIT_TOOLCHAIN"
    fi
    ( cd "$MODULE_ROOT" && "$_ap_py" tools/audit_paths.py )
    exit $?
fi

# ---------------------------------------------------------------------------
# Stage selection — the six stage names are the single source of truth.
# ---------------------------------------------------------------------------

# An empty --only value is a usage error, not "all six": it is almost always
# a shell-variable typo, and silently running everything hides it.
if [ "$ONLY_SET" -eq 1 ] && [ -z "$ONLY_ARG" ]; then
    log_err "--only needs a stage name (expected one of: $STAGES)"
    exit "$EXIT_USAGE"
fi

# --stage and --only are mutually exclusive: --stage means "everything up to
# <s>", --only means "exactly <s>".  Accepting both would have to pick one
# silently, so it is a usage error.
if [ -n "$STAGE_ARG" ] && [ "$ONLY_SET" -eq 1 ]; then
    log_err "--stage and --only are mutually exclusive"
    exit "$EXIT_USAGE"
fi

if [ "$ONLY_SET" -eq 1 ]; then
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

# (The old stage_selected() helper was dead: every stage is entered only from
# the dispatcher loop over $RUN_STAGES, so it was removed rather than left as
# a second, unenforced source of truth.)

# ---------------------------------------------------------------------------
# Host detection — inside WSL never call `wsl` again (prototype defect P1).
# ---------------------------------------------------------------------------

HOST=git-bash
if case "$(uname -s)" in *Linux*) true ;; *) false ;; esac && [ -n "${WSL_DISTRO_NAME:-}" ]; then
    HOST=wsl
fi

# ---------------------------------------------------------------------------
# FR-04 degrade detection (no WSL).
#
# From the host, the upstream Snowball compiler (a Linux ELF) can only run
# inside WSL.  When `wsl` is absent from PATH, or `wsl -l -v` fails (no
# distribution installed / the subsystem is unavailable), the generate stage
# cannot run at all and switches to the vendored branch instead of failing.
# Inside WSL the compiler is local, so the mode is never degraded there.
# ---------------------------------------------------------------------------

GENERATE_MODE=upstream
if [ "$HOST" != wsl ]; then
    if ! command -v wsl >/dev/null 2>&1 || ! wsl -l -v >/dev/null 2>&1 </dev/null; then
        GENERATE_MODE=vendored
    fi
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

# Each root is resolved with its parameter named, so a path this shell cannot
# address (an unconvertible Windows path) fails with exit 4 naming the
# parameter instead of printing a relative or Windows-form value.
case "$DATA_SRC" in
    flag) _root_label="data_root (--data-root)" ;;
    env) _root_label="data_root (SNOWBALL_DATA_ROOT)" ;;
    *) _root_label="data_root" ;;
esac
DATA_ROOT_ABS=$(abs_of "$DATA_VAL" "$_root_label") || exit "$EXIT_PATH"
case "$OUT_SRC" in
    flag) _root_label="out_root (--out)" ;;
    *) _root_label="out_root" ;;
esac
OUT_ROOT_ABS=$(abs_of "$OUT_VAL" "$_root_label") || exit "$EXIT_PATH"
case "$VENDOR_SRC" in
    flag) _root_label="vendor_root (--vendor)" ;;
    *) _root_label="vendor_root" ;;
esac
VENDOR_ROOT_ABS=$(abs_of "$VENDOR_VAL" "$_root_label") || exit "$EXIT_PATH"
case "$SB_SRC" in
    flag) _root_label="sb_root (--sb-root)" ;;
    env) _root_label="sb_root (SNOWBALL_SB_ROOT)" ;;
    *) _root_label="sb_root" ;;
esac
SB_ROOT_ABS=$(abs_of "$SB_VAL" "$_root_label") || exit "$EXIT_PATH"

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
# Degraded-run banner (FR-04).  On the no-WSL path the generate stage cannot
# run at all, so the run says so on its very FIRST line - before the startup
# banner - and names the vendored directory it reads instead.  The line is
# emitted only when the generate stage is part of this run's selection.
# ---------------------------------------------------------------------------
if [ "$GENERATE_MODE" = vendored ]; then
    for _dn_stage in $RUN_STAGES; do
        if [ "$_dn_stage" = generate ]; then
            log_line "generate=skipped reason=no-wsl using=vendored"
            log_line "vendored_dir=$VENDOR_ROOT_ABS"
            break
        fi
    done
fi

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
    # Narrow fallback: on a Windows host python is often registered with the
    # `py` launcher without being on PATH.  The fallback is used only when
    # neither `python` nor `python3` resolves, never preferred over them, and
    # a launcher that names no runnable interpreter still ends in the exit-3
    # preflight.  The concrete interpreter is resolved (never the launcher
    # itself, which needs an extra -V argument) and converted to the POSIX
    # form the shell can execute.  The launcher path comes from the
    # environment, never from a hard-coded drive letter (FR-22).
    _pf_launcher=""
    for _pf_cand in "${SYSTEMROOT:-}/py.exe" "${WINDIR:-}/py.exe"; do
        case "$_pf_cand" in
            /py.exe) continue ;;
        esac
        if [ -f "$_pf_cand" ] && [ -x "$_pf_cand" ]; then
            _pf_launcher="$_pf_cand"
            break
        fi
    done
    if [ -n "$_pf_launcher" ] && command -v cygpath >/dev/null 2>&1; then
        _pf_py_win=$("$_pf_launcher" -0p 2>/dev/null | sed -n 's/.*[[:space:]]\([A-Za-z]:[\\/][^[:space:]]*[Pp]ython[0-9.]*\.exe\)[[:space:]]*$/\1/p')
        for _pf_py in $_pf_py_win; do
            _pf_py_u=$(cygpath -u "$_pf_py" 2>/dev/null) || continue
            [ -x "$_pf_py_u" ] || continue
            if "$_pf_py_u" -c "" >/dev/null 2>&1; then
                PYTHON_BIN="$_pf_py_u"
                break
            fi
        done
    fi
    if [ -z "$PYTHON_BIN" ]; then
        MISSING="$MISSING python"
    fi
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
if [ "$GENERATE_MODE" = vendored ]; then
    # FR-04: there is no WSL to probe.  The round-trip assertion exists to
    # protect the host -> WSL path conversion; on the vendored path no path
    # ever crosses that boundary, so the probe is reported as skipped and the
    # run continues.  It is never silently green: the field says why.
    probe_note "host=$HOST"
    probe_note "probe_result=SKIPPED_NO_WSL"
    PROBE_RC=0
elif [ "$HOST" = wsl ]; then
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

if [ "$GENERATE_MODE" = vendored ]; then
    emit_field wslpath_probe "skipped reason=no-wsl"
else
    emit_field wslpath_probe "RT_OK"
fi

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

    # corpus_complete — every delivery input has a voc and an output side.
    # Only arabic may be gzipped: for the other ten the gzipped name is not
    # accepted, so a plain-looking root with a stray .gz cannot pass as
    # complete.
    corpus_complete() {
        for _cc_lang in $CORPUS_LANGS; do
            if [ "$_cc_lang" = arabic ]; then
                if [ ! -f "$DATA_ROOT_ABS/$_cc_lang/voc.txt" ] && [ ! -f "$DATA_ROOT_ABS/$_cc_lang/voc.txt.gz" ]; then
                    return 1
                fi
                if [ ! -f "$DATA_ROOT_ABS/$_cc_lang/output.txt" ] && [ ! -f "$DATA_ROOT_ABS/$_cc_lang/output.txt.gz" ]; then
                    return 1
                fi
            else
                if [ ! -f "$DATA_ROOT_ABS/$_cc_lang/voc.txt" ]; then
                    return 1
                fi
                if [ ! -f "$DATA_ROOT_ABS/$_cc_lang/output.txt" ]; then
                    return 1
                fi
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

        # git refuses to clone into a non-empty directory.  A root that is
        # already a clone is therefore resumed rather than re-cloned: the
        # clone step is skipped and only the sparse set is re-applied, so an
        # interrupted fetch continues where it stopped (0b is re-entrant).
        _up_parent=$(dirname "$DATA_ROOT_ABS")
        mkdir -p "$_up_parent" 2>/dev/null || true
        if [ -d "$DATA_ROOT_ABS/.git" ]; then
            up_emit "corpus_fetch=resumed root=$DATA_ROOT_ABS"
        else
            if [ -d "$DATA_ROOT_ABS" ]; then
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
            _up_voc_ok=0
            _up_out_ok=0
            if [ "$_up_lang" = arabic ]; then
                { [ -f "$DATA_ROOT_ABS/$_up_lang/voc.txt" ] || [ -f "$DATA_ROOT_ABS/$_up_lang/voc.txt.gz" ]; } && _up_voc_ok=1
                { [ -f "$DATA_ROOT_ABS/$_up_lang/output.txt" ] || [ -f "$DATA_ROOT_ABS/$_up_lang/output.txt.gz" ]; } && _up_out_ok=1
            else
                [ -f "$DATA_ROOT_ABS/$_up_lang/voc.txt" ] && _up_voc_ok=1
                [ -f "$DATA_ROOT_ABS/$_up_lang/output.txt" ] && _up_out_ok=1
            fi
            [ "$_up_voc_ok" -eq 1 ] || _up_missing="$_up_missing $_up_lang(voc)"
            [ "$_up_out_ok" -eq 1 ] || _up_missing="$_up_missing $_up_lang(output)"
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
    # Same resolution rule as the other stages: SNOWBALL_SNAPSHOT_ROOT is
    # honoured here too, and the u2-t8-* snapshots are pruned to the two most
    # recent so a repeated run cannot fill the snapshot area with copies of
    # the same decompressed corpus.
    if [ -d "$UNPACK_DST" ]; then
        _up_snap=$(snapshot_root "u2-t8") || {
            up_fail "unpack failed: cannot resolve the snapshot directory (SNOWBALL_SNAPSHOT_ROOT=$SNAPSHOT_BASE)"
            return "$EXIT_UNPACK"
        }
        # The base the helper actually resolved.  The prune below must use this
        # value, never the raw $SNAPSHOT_BASE: a relative or drive-form
        # SNOWBALL_SNAPSHOT_ROOT resolves to a different absolute path, and
        # pruning the unresolved one removes nothing (or the wrong tree).
        SNAPSHOT_RESOLVED=$(dirname "$_up_snap")
        mkdir -p "$_up_snap" 2>/dev/null || true
        if ! cp -r "$UNPACK_DST" "$_up_snap" 2>/dev/null || [ ! -d "$_up_snap" ]; then
            up_fail "unpack failed: cannot snapshot $UNPACK_DST into $_up_snap"
            return "$EXIT_UNPACK"
        fi
        log_line "snapshot: preserved $UNPACK_DST -> $_up_snap"
        up_emit "snapshot=$_up_snap"
        # Keep the two most recent u2-t8-* snapshots, drop the older ones.
        # The prune works on the RESOLVED snapshot root and on shell globs
        # only: a `$(ls ...)` list would word-split on the spaces a root such
        # as "F:/Temp/pr/a b" contains and `rm -rf` would then remove an
        # unrelated directory while the real snapshots survived.  A glob is
        # never word-split; when nothing matches it expands to the literal
        # pattern, which the `[ -d ]` guard rejects.
        _up_keep1=""
        _up_keep2=""
        for _up_old in "$SNAPSHOT_RESOLVED"/u2-t8-*; do
            [ -d "$_up_old" ] || continue
            if [ -z "$_up_keep1" ] || [ "$_up_old" -nt "$_up_keep1" ]; then
                _up_keep2="$_up_keep1"
                _up_keep1="$_up_old"
            elif [ -z "$_up_keep2" ] || [ "$_up_old" -nt "$_up_keep2" ]; then
                _up_keep2="$_up_old"
            fi
        done
        _up_removed=0
        for _up_old in "$SNAPSHOT_RESOLVED"/u2-t8-*; do
            [ -d "$_up_old" ] || continue
            [ "$_up_old" = "$_up_keep1" ] && continue
            [ "$_up_old" = "$_up_keep2" ] && continue
            rm -rf -- "$_up_old" 2>/dev/null || true
            _up_removed=$((_up_removed + 1))
        done
        _up_kept=0
        for _up_old in "$SNAPSHOT_RESOLVED"/u2-t8-*; do
            [ -d "$_up_old" ] || continue
            _up_kept=$((_up_kept + 1))
        done
        up_emit "snapshot_prune=keep-2 kept=$_up_kept removed=$_up_removed root=$SNAPSHOT_RESOLVED"
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

    # -- 1. snapshot (the destructive-op precondition) ------------------
    # Every directory the stage overwrites is copied into the snapshot
    # area first, and the copy is confirmed before anything is written.
    # The snapshot area is resolved by snapshot_root (SNOWBALL_SNAPSHOT_ROOT
    # honoured for this stage too) and is never inside a directory the stage
    # writes, so a copy can never end up inside a deliverable.
    _gen_preserved=0
    for _gen_pair in "out_root=$OUT_ROOT_ABS" "gen1=$GEN1_ROOT" "gen2=$GEN2_ROOT"; do
        _gen_tag=${_gen_pair%%=*}
        _gen_dir=${_gen_pair#*=}
        [ -d "$_gen_dir" ] || continue
        _gen_snap=$(snapshot_root "u2-t3-$_gen_tag") || {
            gen_fail "generate failed: cannot resolve the snapshot directory for $_gen_dir (SNOWBALL_SNAPSHOT_ROOT=$SNAPSHOT_BASE)"
            return "$EXIT_GENERATE"
        }
        mkdir -p "$_gen_snap" 2>/dev/null || true
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

    # -- 2. FR-04 vendored branch (no WSL) ------------------------------
    # Without WSL the upstream compiler cannot run at all, so the generation
    # is skipped and the vendored inputs take its place.  The ten vendored
    # py32 stemmers ARE the compiler's output (that is the equivalence T3
    # proved), so they are copied into out_root - the translator's only
    # input directory - and the three main-path parity claims are replaced
    # by the claims that can actually be checked here:
    #
    #     vendored py32 10/10 present      a missing file is fatal (FE3)
    #     equivalent py32 10/10 SAME       bytes vs the gen1 baseline, when
    #                                      a real generation left one; a
    #                                      difference means the vendored
    #                                      copy is stale (AD1-8) and is fatal
    #     porter=cached | missing          porter has no vendored
    #                                      counterpart, so a previous WSL
    #                                      generation in out_root is the only
    #                                      honest source; absent -> refuse
    #
    # Nothing is fabricated: an incomplete vendored set and a missing porter
    # both exit 6, and the conservative choice is refusal (FE3), never an
    # empty run.
    if [ "$GENERATE_MODE" = vendored ]; then
        _vg_dir="$VENDOR_ROOT_ABS/py32"
        gen_emit "stage=generate branch=vendored reason=no-wsl"
        gen_emit "vendored_dir=$_vg_dir"
        if [ ! -d "$_vg_dir" ]; then
            gen_fail "generate failed: vendored input directory missing: $_vg_dir (FE3: the vendored set is incomplete; restore it by the U1-a copy contract and re-run)"
            return "$EXIT_GENERATE"
        fi
        _vg_present=0
        _vg_missing=""
        for _gen_lang in $PY32_LANGS; do
            if [ -f "$_vg_dir/${_gen_lang}_stemmer.py" ]; then
                _vg_present=$((_vg_present + 1))
            else
                _vg_missing="$_vg_missing $_vg_dir/${_gen_lang}_stemmer.py"
            fi
        done
        if [ "$_vg_present" -ne 10 ]; then
            for _vg_f in $_vg_missing; do
                gen_fail "generate failed: vendored input missing: $_vg_f"
            done
            gen_fail "generate failed: vendored py32 coverage $_vg_present/10 (FE3: an incomplete vendored set is refused, never run empty)"
            return "$EXIT_GENERATE"
        fi
        gen_emit "vendored py32 $_vg_present/10 present"

        _vg_porter="$OUT_ROOT_ABS/porter_stemmer.py"
        if [ -f "$_vg_porter" ]; then
            _vg_porter_md5=$(md5sum "$_vg_porter" 2>/dev/null | cut -d' ' -f1)
            gen_emit "porter=cached file=$_vg_porter md5=$_vg_porter_md5"
        else
            gen_fail "generate failed: porter=cached missing: $_vg_porter (porter has no vendored counterpart and no earlier WSL generation is cached there; run the pipeline once with WSL available, or restore the file)"
            return "$EXIT_GENERATE"
        fi

        if [ -f "$GEN1_ROOT/english_stemmer.py" ]; then
            _vg_same=0
            for _gen_lang in $PY32_LANGS; do
                if cmp -s "$GEN1_ROOT/${_gen_lang}_stemmer.py" "$_vg_dir/${_gen_lang}_stemmer.py"; then
                    _vg_same=$((_vg_same + 1))
                else
                    gen_fail "generate failed: $_gen_lang differs (the gen1 baseline of a real generation vs the vendored py32 stemmer: the vendored copy is stale)"
                    gen_fail "generate failed: differing files: $GEN1_ROOT/${_gen_lang}_stemmer.py $_vg_dir/${_gen_lang}_stemmer.py"
                    return "$EXIT_GENERATE"
                fi
            done
            gen_emit "equivalent py32 $_vg_same/10 SAME (gen1 baseline vs vendored)"
        else
            gen_emit "equivalent py32 na/10 (no gen1 baseline in $GEN1_ROOT; nothing to compare against)"
        fi

        for _gen_lang in $PY32_LANGS; do
            if ! cp "$_vg_dir/${_gen_lang}_stemmer.py" "$OUT_ROOT_ABS/${_gen_lang}_stemmer.py" 2>/dev/null; then
                gen_fail "generate failed: cannot copy the vendored input $_vg_dir/${_gen_lang}_stemmer.py into $OUT_ROOT_ABS"
                return "$EXIT_GENERATE"
            fi
        done
        _vg_out=0
        for _gen_lang in $GEN_LANGS; do
            if [ -f "$OUT_ROOT_ABS/${_gen_lang}_stemmer.py" ]; then
                _vg_out=$((_vg_out + 1))
            fi
        done
        if [ "$_vg_out" -ne 11 ]; then
            gen_fail "generate failed: out_root $_vg_out/11 inputs after the vendored materialisation (10 vendored + porter cached expected)"
            return "$EXIT_GENERATE"
        fi
        gen_emit "out_root $_vg_out/11 inputs (10 vendored py32 + porter cached)"
        # FR-08: one marker per artifact this stage established in out_root.
        # porter311 is vendored, never generated, so it is not one of them.
        for _gen_lang in $GEN_LANGS; do
            emit_regenerated "$OUT_ROOT_ABS/${_gen_lang}_stemmer.py"
        done
        return 0
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
            # Single source of truth for the cmd= lines: tools/gen_all.sh
            # wrote one `stage=generate lang=<n> cmd=...` line per language
            # into the raw transcript, and exactly those lines are copied
            # here, verbatim.  Reconstructing them from the stage's own
            # variables would be a second, drifting copy of what ran.
            _gen_cmd_n=$(grep -c '^stage=generate lang=.* cmd=' "$GENERATE_RAW_LOG" 2>/dev/null)
            [ -n "$_gen_cmd_n" ] || _gen_cmd_n=0
            if [ "$_gen_cmd_n" -lt 11 ]; then
                gen_fail "generate failed: the gen1 transcript holds $_gen_cmd_n/11 stage=generate cmd= lines (one per upstream language expected)"
                return "$EXIT_GENERATE"
            fi
            grep '^stage=generate lang=.* cmd=' "$GENERATE_RAW_LOG" 2>/dev/null | tr -d '\r' | while IFS= read -r _gen_cmdline; do
                gen_log "$_gen_cmdline"
                printf '%s\n' "$_gen_cmdline"
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
    if [ "$_gen_same" -ne 11 ]; then
        gen_fail "generate failed: parity $_gen_same/11"
        return "$EXIT_GENERATE"
    fi
    gen_emit "generated $_gen_same/11"
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
    if [ "$_gen_py32" -ne 10 ]; then
        gen_fail "generate failed: parity $_gen_py32/10"
        return "$EXIT_GENERATE"
    fi
    gen_emit "py32 covered $_gen_py32/10 SAME"
    gen_emit "porter: no vendored py32 counterpart; its baseline is gen1 vs gen2 only (it is part of the 11/11 claim, never of the py32 count)"

    # -- 5. out_root against gen1 ---------------------------------------
    # The deliverable directory is compared byte for byte against the gen1
    # baseline: without it the stage could report 11/11 while the files it
    # hands to the translator are stale leftovers of an earlier run
    # (tools/gen_all.sh clears the files it owns; this is the second gate).
    _gen_out_same=0
    for _gen_lang in $GEN_LANGS; do
        if cmp -s "$OUT_ROOT_ABS/${_gen_lang}_stemmer.py" "$GEN1_ROOT/${_gen_lang}_stemmer.py"; then
            _gen_out_same=$((_gen_out_same + 1))
        else
            gen_fail "generate failed: out_root/${_gen_lang}_stemmer.py differs from the gen1 baseline (stale or missing deliverable)"
            gen_fail "generate failed: differing files: $OUT_ROOT_ABS/${_gen_lang}_stemmer.py $GEN1_ROOT/${_gen_lang}_stemmer.py"
            return "$EXIT_GENERATE"
        fi
    done
    if [ "$_gen_out_same" -ne 11 ]; then
        gen_fail "generate failed: out_root parity $_gen_out_same/11"
        return "$EXIT_GENERATE"
    fi
    gen_emit "out_root $_gen_out_same/11 identical to gen1"
    # FR-08: every deliverable input this stage wrote into out_root.  The two
    # parity directories are reconsidered baselines, not artifacts handed on,
    # and porter311 is vendored: none of them is marked here.
    for _gen_lang in $GEN_LANGS; do
        emit_regenerated "$OUT_ROOT_ABS/${_gen_lang}_stemmer.py"
    done
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
    # Refusal: each language is written per language, so a refusal at
    #          language N leaves the files of languages 1..N-1 on disk (the
    #          refusing language itself leaves none: tools/translate.py only
    #          writes after the whole file has been rewritten).  The stage is
    #          fail-fast, so the non-zero exit stops the run here and no later
    #          stage ever consumes the partial set.  The next translate run
    #          snapshots and overwrites all twelve packages again.
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

    # The module name comes from moon.mod and is written verbatim into each
    # `<lang>/moon.pkg` import.  An empty name would emit `"/runtime" @rt`,
    # so it is refused here, before anything is snapshotted or written.
    if [ -z "$TR_MODULE_NAME" ]; then
        tr_fatal "translate failed: the module name resolved empty (moon.mod: $MODULE_ROOT/moon.mod has no top-level name = \"...\"); each moon.pkg would import \"/runtime\" @rt"
        return "$EXIT_TRANSLATE"
    fi

    # -- 1. snapshot (the destructive-op precondition) ------------------
    # Every input the stage overwrites is copied out of the module first,
    # and the copy is confirmed before anything is written.  The snapshot
    # area is resolved by snapshot_root, so SNOWBALL_SNAPSHOT_ROOT applies
    # here as it does to every other stage; the default is inside the module
    # but under the gitignored .planning/logs/, never inside a deliverable.
    _tr_need_snapshot=0
    for _tr_lang in $_tr_all_langs; do
        if [ -e "$MODULE_ROOT/$_tr_lang/${_tr_lang}_gen.mbt" ]; then
            _tr_need_snapshot=1
            break
        fi
    done
    if [ "$_tr_need_snapshot" -eq 1 ]; then
        TR_SNAPSHOT_DIR=$(snapshot_root "u2-t4-snapshot") || {
            tr_fail "translate failed: cannot resolve the snapshot directory (SNOWBALL_SNAPSHOT_ROOT=$SNAPSHOT_BASE)"
            return "$EXIT_TRANSLATE"
        }
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
        # FR-08: the translator rewrote this artifact in this run.
        emit_regenerated "$_tr_mbt"
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
    # anything is written.  snapshot_root applies the same
    # SNOWBALL_SNAPSHOT_ROOT rule as the other stages.
    FMT_SNAPSHOT_DIR=$(snapshot_root "u2-t5-snapshot") || {
        fmt_fail "fmt failed: cannot resolve the snapshot directory (SNOWBALL_SNAPSHOT_ROOT=$SNAPSHOT_BASE)"
        return "$EXIT_FMT"
    }
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
        # FR-08: `moon fmt` rewrote this deliverable in this run.
        emit_regenerated "$MODULE_ROOT/$_fmt_lang/${_fmt_lang}_gen.mbt"
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
    # ------------------------------------------------------------------
    # Task 6 - the compile gate.
    #
    # `moon check` is the gate, never `moon build`: a bare build only
    # compiles the executable closure, so an unreferenced package (porter311,
    # for instance) is never type-checked.  The negative proof is in the T6
    # report; the rule it establishes is D-7, and this stage is where D-7 is
    # enforced.
    #
    # Four claims, in this order:
    #   1. `moon check --json` says success with 0 errors and 0 warnings
    #      (the JSON is kept verbatim as T6-check.json).
    #   2. the module has exactly 15 packages - the 14 sub-packages plus the
    #      empty-rel root package that carries lang_registry.mbt (N8).
    #   3. `moon info` runs BEFORE any `.mbti` assertion (D-8), and then the
    #      AD2-1..AD2-5 / AD2-2 / AD2-8 counts hold (T6-mbti.log).
    #   4. the dialect red lines hold: D-1 by semantic check per package
    #      (never with the repository root as scope: B7), the two
    #      fail-closed cases, the D-2..D-6 / D-14 retrievals, and D-12: the
    #      driver entry point has an explicit non-zero exit path
    #      (T6-dialect.log).
    #
    # Exit codes are taken from the command itself, never through tee.
    # ------------------------------------------------------------------

    _ck_start=$(date +%s)

    # -- 1. moon check ---------------------------------------------------
    # The JSON goes to its own log; stdout/stderr of the run are appended to
    # it so a diagnostic that the toolchain prints outside the JSON (the
    # `[4014]` block, for example) is preserved next to it.
    ( cd "$MODULE_ROOT" && moon check --json ) >"$CHECK_LOG" 2>&1
    _ck_rc=$?
    if [ "$_ck_rc" -ne 0 ]; then
        log_err "check failed: moon check --json exited $_ck_rc"
        tail -n 20 "$CHECK_LOG" 2>/dev/null >&2
        log_err "stage=check exit=$EXIT_CHECK"
        return "$EXIT_CHECK"
    fi

    # The three fields are asserted in one pass so a failure names every
    # field that is wrong, not just the first one.
    _ck_json=$( cd "$MODULE_ROOT" && "$PYTHON_BIN" - "$CHECK_LOG_REL" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception as exc:
    print('BAD_JSON %s' % exc)
    sys.exit(1)
summary = d.get('summary') or {}
bad = []
if d.get('status') != 'success':
    bad.append('status=%r (want success)' % d.get('status'))
if summary.get('moon_errors') != 0:
    bad.append('moon_errors=%r (want 0)' % summary.get('moon_errors'))
if summary.get('moon_warnings') != 0:
    bad.append('moon_warnings=%r (want 0)' % summary.get('moon_warnings'))
print('%s %s %s' % (d.get('status'), summary.get('moon_errors'),
                    summary.get('moon_warnings')))
if bad:
    print('FAIL ' + '; '.join(bad))
    sys.exit(1)
sys.exit(0)
PY
    )
    _ck_json_rc=$?
    if [ "$_ck_json_rc" -ne 0 ]; then
        log_err "check failed: moon check --json assertion: $(printf '%s' "$_ck_json" | tail -n 1)"
        log_err "stage=check exit=$EXIT_CHECK"
        return "$EXIT_CHECK"
    fi

    # -- 2. the 15 packages (N8) ----------------------------------------
    # Counted from all_pkgs.json, never hard-coded: the count and the rel-set
    # are both read back from what the toolchain actually planned.  A
    # mismatch prints the set difference.
    _ck_pkgs=$( cd "$MODULE_ROOT" && "$PYTHON_BIN" - <<'PY'
import json, pathlib, re, sys
root = pathlib.Path.cwd()
m = re.search(r'^\s*name\s*=\s*"([^"]+)"',
              (root / 'moon.mod').read_text(encoding='utf-8'), re.M)
if not m:
    print('0')
    print('FAIL no module name in moon.mod')
    sys.exit(1)
mod = m.group(1)
p = root / '_build/native/debug/check/all_pkgs.json'
if not p.is_file():
    print('0')
    print('FAIL %s missing' % p)
    sys.exit(1)
data = json.loads(p.read_text(encoding='utf-8'))
rels = sorted({x.get('rel', '') for x in data.get('packages', [])
               if x.get('root') == mod})
want = {'', 'runtime', 'cmd/golden', 'arabic', 'dutch', 'english', 'french',
        'german', 'italian', 'porter', 'porter311', 'portuguese', 'russian',
        'spanish', 'turkish'}
print(len(rels))
missing = sorted(want - set(rels))
extra = sorted(set(rels) - want)
if len(rels) != 15 or missing or extra:
    print('FAIL count=%d want=15 missing=%s extra=%s' % (len(rels), missing, extra))
    sys.exit(1)
print('OK ' + ' '.join('<' + r + '>' if r == '' else r for r in rels))
sys.exit(0)
PY
    )
    _ck_pkgs_rc=$?
    _ck_n=$(printf '%s\n' "$_ck_pkgs" | sed -n 1p)
    if [ "$_ck_pkgs_rc" -ne 0 ]; then
        log_err "check failed: package assertion: $(printf '%s\n' "$_ck_pkgs" | sed -n 2p)"
        log_err "stage=check exit=$EXIT_CHECK"
        return "$EXIT_CHECK"
    fi

    # -- 3. refresh the interface files BEFORE asserting on them ---------
    # D-8: a `.mbti` left over from an older source can be false-green (a
    # removed `pub fn` still counts) or false-red (a new one is missing).
    # `moon info` is the refresh; it is never skipped and never run after
    # the assertions.
    : >"$CHECK_MBTI_LOG" 2>/dev/null || true
    ( cd "$MODULE_ROOT" && moon info ) >>"$CHECK_MBTI_LOG" 2>&1
    _ck_info_rc=$?
    if [ "$_ck_info_rc" -ne 0 ]; then
        log_err "check failed: moon info exited $_ck_info_rc (the .mbti assertions cannot be trusted without it)"
        tail -n 20 "$CHECK_MBTI_LOG" 2>/dev/null >&2
        log_err "stage=check exit=$EXIT_CHECK"
        return "$EXIT_CHECK"
    fi

    # -- 4. the assertions -------------------------------------------------
    # One helper does the rest (AD2 counts, D-1 per package, the two
    # fail-closed cases, the D-2..D-6/D-14 retrievals and the D-12 exit-path
    # check) and writes the two evidence logs.  Its stdout is copied into the
    # run so every count is visible in the pipeline transcript as well.
    ( cd "$MODULE_ROOT" && "$PYTHON_BIN" tools/check_gate.py \
        --json "$CHECK_LOG_REL" \
        --mbti-log "$CHECK_MBTI_REL" \
        --dialect-log "$CHECK_DIALECT_REL" ) >"$CHECK_LOG_TXT" 2>&1
    _ck_gate_rc=$?
    while IFS= read -r _ck_line; do
        log_line "$_ck_line"
    done <"$CHECK_LOG_TXT"
    if [ "$_ck_gate_rc" -ne 0 ]; then
        log_err "check failed: tools/check_gate.py exited $_ck_gate_rc"
        log_err "stage=check exit=$EXIT_CHECK"
        return "$EXIT_CHECK"
    fi

    _ck_now=$(date +%s)
    log_line "stage=check packages=$_ck_n errors=0 warnings=0 elapsed=$((_ck_now - _ck_start))"
    return 0
}

stage_golden() {
    # ------------------------------------------------------------------
    # Task 7 - the golden segment (FR-12/FR-13/FR-14/FR-21; prototype
    # defects P3 and P4).
    #
    # Two commands, in this order:
    #   1. the driver: `moon run cmd/golden`, twelve `lang=... checked=...
    #      mismatch=...` rows plus twelve `lang=<n> lines=<M>` rows.  Its
    #      exit code is taken from the command itself:
    #          moon run cmd/golden > log 2>&1; rc=$?
    #      never through `| tee`, whose exit code is tee's, not the driver's.
    #   2. the gate: scripts/gate.sh <log> <rc>, the same script the negative
    #      tests call.  It re-reads the log structurally and is the only
    #      thing that may say `GATE OK`.
    #
    # Paths: the driver resolves its own data root (`--data-root` >
    # SNOWBALL_DATA_ROOT > `.planning/data/sd`) and its own arabic plain-text
    # directory (`--arabic-dir` > `<root>/arabic` > `build/data/arabic`).
    # The stage only forwards an explicitly requested root, so the default
    # run exercises exactly the driver's own resolution.  A forwarded path is
    # converted to the form the native executable can open (`cygpath -w`
    # under Git-Bash); nothing is hard-coded.
    # ------------------------------------------------------------------

    _g_start=$(date +%s)
    : > "$GOLDEN_LOG" 2>/dev/null || true
    : > "$GOLDEN_GATE_LOG" 2>/dev/null || true

    if [ ! -f "$GOLDEN_GATE" ]; then
        log_err "golden failed: the gate script is missing: $GOLDEN_GATE"
        log_err "stage=golden exit=$EXIT_GOLDEN"
        return "$EXIT_GOLDEN"
    fi

    # -- 1. the driver ---------------------------------------------------
    if [ "$DATA_SRC" = default ]; then
        ( cd "$MODULE_ROOT" && moon run cmd/golden ) >"$GOLDEN_LOG" 2>&1
    else
        _g_data="$DATA_ROOT_ABS"
        if [ "$HOST" = git-bash ] && command -v cygpath >/dev/null 2>&1; then
            _g_data=$(cygpath -w "$DATA_ROOT_ABS")
        fi
        ( cd "$MODULE_ROOT" && moon run cmd/golden --data-root "$_g_data" ) \
            >"$GOLDEN_LOG" 2>&1
    fi
    _g_rc=$?

    # The native driver's stdout carries CRLF on Windows; normalise the
    # transcript to LF so a `$`-anchored grep (the brief's step-4 acceptance)
    # and the gate see one line-ending convention.  Content is otherwise
    # untouched; the exit code was captured above and is unaffected.
    _g_norm="$GOLDEN_LOG.norm.$$"
    if tr -d '\r' <"$GOLDEN_LOG" >"$_g_norm" 2>/dev/null; then
        mv -f "$_g_norm" "$GOLDEN_LOG"
    else
        rm -f "$_g_norm"
    fi
    if [ "$_g_rc" -ne 0 ]; then
        # The first stderr line is the driver's own diagnostic (absolute path
        # + `missing`, a line-count mismatch, or a mismatch summary).
        _g_first=$(sed -n 1p "$GOLDEN_LOG" 2>/dev/null)
        log_err "golden failed: moon run cmd/golden exited $_g_rc: $_g_first"
    fi

    # -- 2. the gate -----------------------------------------------------
    sh "$GOLDEN_GATE" "$GOLDEN_LOG" "$_g_rc" >"$GOLDEN_GATE_LOG" 2>&1
    _g_gate_rc=$?
    while IFS= read -r _g_line; do
        log_line "gate: $_g_line"
    done <"$GOLDEN_GATE_LOG"
    if [ "$_g_gate_rc" -ne 0 ]; then
        log_err "golden failed: scripts/gate.sh exited $_g_gate_rc (driver exit=$_g_rc)"
        log_err "stage=golden exit=$EXIT_GOLDEN"
        return "$EXIT_GOLDEN"
    fi

    # Task 12 (FR-20): the twelve `lang=<n> lines=<M>` rows and the
    # `line-count drift: <k>/12` summary must both be present.  A warned row
    # (` WARN line-count drift`) is NOT a gate failure — drift is a warning by
    # design — but a missing row set is: the driver would have stopped emitting
    # the baseline block.  Both facts are logged so the transcript carries them.
    _g_line_rows=$(grep -cE '^lang=.* lines=' "$GOLDEN_LOG" 2>/dev/null)
    _g_drift=$(grep -oE 'line-count drift: [0-9]+/12' "$GOLDEN_LOG" 2>/dev/null)
    _g_warns=$(grep -cE '^lang=.* lines=.* WARN line-count drift$' "$GOLDEN_LOG" 2>/dev/null)
    if [ "$_g_line_rows" -ne 12 ]; then
        log_err "golden failed: expected 12 lines= rows, got ${_g_line_rows:-0}"
        log_err "stage=golden exit=$EXIT_GOLDEN"
        return "$EXIT_GOLDEN"
    fi
    if [ -z "$_g_drift" ]; then
        log_err "golden failed: the 'line-count drift: <k>/12' summary is missing"
        log_err "stage=golden exit=$EXIT_GOLDEN"
        return "$EXIT_GOLDEN"
    fi

    # The twelve `lang=<n> checked=<N> mismatch=<M>` rows are copied into the
    # run log verbatim, one per line, so the acceptance transcript proves the
    # 12-row claim without having to open T7-golden.log.  The rows come from
    # the driver's own log and the verdict above is the gate's: the two are
    # not a second assertion, only a copy of what the gate already accepted.

    while IFS= read -r _g_row; do
        case "$_g_row" in
            lang=*) log_line "$_g_row" ;;
            *) : ;;
        esac
    done <"$GOLDEN_LOG"

    _g_rows=$(grep -cE '^lang=[^ ]+ checked=[0-9]+ mismatch=0 ' "$GOLDEN_LOG" 2>/dev/null)
    _g_now=$(date +%s)
    log_line "stage=golden rows=$_g_rows mismatch=0 elapsed=$((_g_now - _g_start))"
    log_line "golden lines=$_g_line_rows drift=$_g_drift warned=$_g_warns"
    log_line "GATE OK"
    return 0
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

# FR-17's clock: `total=` measures the six-stage chain, so it starts here and
# not at process start - the preflight/probe seconds are not stage time, and
# counting them would make `total` and `stage_sum` two different quantities.
RUN_T0=$(date +%s)
STAGE_SUM=0

for _stage in $RUN_STAGES; do
    STAGE_START=$(date +%s)
    emit_field stage "$_stage"
    emit_field elapsed 0
    run_stage "$_stage"
    _rc=$?
    _now=$(date +%s)
    emit_field stage "$_stage"
    emit_field exit "$_rc"
    STAGE_SUM=$((STAGE_SUM + (_now - STAGE_START)))
    emit_field elapsed "$((_now - STAGE_START))"
    if [ "$_rc" -ne 0 ]; then
        log_err "stage=$_stage exit=$_rc (fail-fast: no later stage is entered)"
        exit "$_rc"
    fi
done

# FR-17: the run's total wall-clock seconds against the sum of the six stage
# elapsed values.  A gap above 1 s means the seconds spent outside the six
# stages (preflight, the wslpath probe, the run's own setup) is large enough
# to matter; it is diagnostic only, so a gap is warned about and never fails.
# Only a full run is totalled: a `--only`/`--stage` selection covers fewer
# than six stages, and a six-stage total would then be a lie.
_stages_n=0
for _s in $RUN_STAGES; do
    _stages_n=$((_stages_n + 1))
done
if [ "$_stages_n" -eq 6 ]; then
    _total=$((_now - RUN_T0))
    emit_field total "$_total"
    emit_field stages "$(printf '%s' "$RUN_STAGES" | tr ' ' ',')"
    emit_field stage_sum "$STAGE_SUM"
    _delta=$((_total - STAGE_SUM))
    if [ "$_delta" -lt 0 ]; then
        _delta=$((0 - _delta))
    fi
    if [ "$_delta" -gt 1 ]; then
        log_line "WARN total-vs-sum delta=$_delta"
    fi
fi

emit_field exit 0
exit 0
