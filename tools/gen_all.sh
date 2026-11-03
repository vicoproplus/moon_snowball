#!/bin/sh
# Reproducible upstream Python generation for the 36 upstream languages.
#
# The snowball 3.2.0 compiler is a Linux ELF that lives outside the delivery
# tree, so run this script inside WSL and pass its directory as SB_ROOT.  All
# paths below are relative to the module root:
#
#   wsl -e bash -lc 'cd "$(wslpath -a -u .)" && \
#       sh tools/gen_all.sh .probe/ctc/sbtest .planning/logs/u2/gen1'
#
# Usage:
#   sh tools/gen_all.sh [SB_ROOT] [OUT_DIR]   generate the 36 stemmers
#   sh tools/gen_all.sh --preflight SB_ROOT   check the toolchain and the
#                                             compiler, generate nothing
#
#   SB_ROOT  directory containing ./snowball, algorithms/ and python/create_init.py
#            (default: ../.probe/ctc/sbtest relative to this script)
#   OUT_DIR  output directory (default: ./gen)
#
# The 36 languages are the `$GEN_LANGS` population of scripts/pipeline.sh
# (the default LANGS below): the original ten libstemmer languages plus
# porter, the three callback languages (finnish, hindi, polish), the 14
# latin/germanic additions and the 7 non-latin additions, plus dutch_porter.
# earlymodernenglish and ukrainian are deferred (DEL-1/DEL-2: 3.2.0-only
# algorithms absent from PyPI 3.1.1).  Ten of them have a vendored py32
# counterpart under tools/vendor/py32/ -- a CROSS-CHECK SUBSET, not the
# generation population; porter has none (its baseline is this run against
# itself, see the report).
#
# Every language is generated with the fixed argument pair -python -eprefix _
# (F-U2-09: without -eprefix _ the generated class has no _stem method).
#
# The number of .py files in an output directory is therefore 37: the 36
# upstream language stemmers plus the __init__.py that create_init.py writes
# by scanning that directory.  That __init__.py lists an entry per generated
# stemmer and has no vendored baseline of its own; the claim the pipeline is
# allowed to make is "36/36" -- 36 upstream languages -- never the raw .py
# file count.

set -e
HERE=$(cd "$(dirname "$0")" && pwd)

SB=""
OUT=""
LANGS_OVERRIDE=""
PREFLIGHT=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --preflight)
            PREFLIGHT=1
            shift
            ;;
        --langs)
            if [ "$#" -lt 2 ]; then
                echo "gen_all: --langs needs a value" >&2
                exit 2
            fi
            LANGS_OVERRIDE="$2"
            shift 2
            ;;
        --langs=*)
            LANGS_OVERRIDE="${1#--langs=}"
            shift
            ;;
        *)
            if [ -z "$SB" ]; then
                SB="$1"
            elif [ -z "$OUT" ]; then
                OUT="$1"
            else
                echo "gen_all: unexpected argument: $1" >&2
                exit 2
            fi
            shift
            ;;
    esac
done

SB="${SB:-$HERE/../.probe/ctc/sbtest}"
OUT="${OUT:-$HERE/gen}"

# The toolchain the upstream build needs: the compiler itself is a Linux ELF,
# and the degrade path (Task 11) rebuilds it from source with gcc and make.
# python3 is what the upstream create_init.py runs under.
preflight() {
    if [ ! -d "$1" ]; then
        echo "sb_root is not a directory: $1" >&2
        return 1
    fi
    if [ ! -f "$1/snowball" ]; then
        echo "no compiler at $1/snowball" >&2
        return 1
    fi
    if [ ! -x "$1/snowball" ]; then
        echo "no executable $1/snowball" >&2
        return 1
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        echo "python3 not found" >&2
        return 1
    fi
    if ! command -v gcc >/dev/null 2>&1; then
        echo "gcc not found" >&2
        return 1
    fi
    if ! command -v make >/dev/null 2>&1; then
        echo "make not found" >&2
        return 1
    fi
    return 0
}

if [ "$PREFLIGHT" -eq 1 ]; then
    if ! preflight "$SB"; then
        exit 1
    fi
    echo "preflight=OK"
    exit 0
fi

if ! preflight "$SB"; then
    exit 1
fi
mkdir -p "$OUT"

# A dropped language or a short run must not leave old bytes behind: the
# caller compares this directory against a fresh copy.  The clear is name-
# based, so it removes every *_stemmer.py and __init__.py in $OUT — including
# a hand-written sibling such as mine_stemmer.py; nothing else in $OUT is
# touched, and the 36 generated names are rewritten by the loop below.
rm -f "$OUT"/*_stemmer.py "$OUT/__init__.py"

if [ -n "$LANGS_OVERRIDE" ]; then
    LANGS="$LANGS_OVERRIDE"
else
    LANGS="arabic armenian basque catalan czech danish dutch dutch_porter english esperanto estonian finnish french german greek hindi hungarian indonesian irish italian lithuanian nepali norwegian persian polish porter portuguese romanian russian serbian sesotho spanish swedish tamil turkish yiddish"
fi
for L in $LANGS; do
    printf '%s\n' "stage=generate lang=$L cmd=$SB/snowball $SB/algorithms/$L.sbl -python -eprefix _ -o $OUT/${L}_stemmer.py"
    "$SB/snowball" "$SB/algorithms/$L.sbl" -python -eprefix _ -o "$OUT/${L}_stemmer.py"
done

# porter.sbl ships with the compiler but is not one of the libstemmer
# languages, so create_init.py does not list it explicitly; it is generated
# in the loop above and then appears in the generated __init__.py because
# create_init.py scans the directory.  There is no vendored baseline for
# either file: the pipeline's own gen1 == gen2 comparison is the control.
python3 "$SB/python/create_init.py" "$OUT"
printf '%s\n' "gen_all: wrote $(printf '%s' "$LANGS" | wc -w) upstream language stemmers and the generated __init__.py to $OUT"
