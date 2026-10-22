#!/bin/sh
# Reproducible upstream Python generation for the eleven upstream languages.
#
# The snowball 3.2.0 compiler is a Linux ELF that lives outside the delivery
# tree, so run this script inside WSL and pass its directory as SB_ROOT.  All
# paths below are relative to the module root:
#
#   wsl -e bash -lc 'cd "$(wslpath -a -u .)" && \
#       sh tools/gen_all.sh .probe/ctc/sbtest .planning/logs/u2/gen1'
#
# Usage:
#   sh tools/gen_all.sh [SB_ROOT] [OUT_DIR]   generate the eleven stemmers
#   sh tools/gen_all.sh --preflight SB_ROOT   check the toolchain and the
#                                             compiler, generate nothing
#
#   SB_ROOT  directory containing ./snowball, algorithms/ and python/create_init.py
#            (default: ../.probe/ctc/sbtest relative to this script)
#   OUT_DIR  output directory (default: ./gen)
#
# The eleven languages are the ten libstemmer languages plus porter:
# arabic dutch english french german italian porter portuguese russian
# spanish turkish.  Ten of them have a vendored py32 counterpart under
# tools/vendor/py32/; porter has none (its baseline is this run against
# itself, see the report).
#
# Every language is generated with the fixed argument pair -python -eprefix _
# (F-U2-09: without -eprefix _ the generated class has no _stem method).
#
# The number of .py files in an output directory is 12: the eleven upstream
# language stemmers plus the __init__.py that the upstream create_init.py
# writes.  The claim the pipeline is allowed to make is "11/11" — eleven
# upstream languages — never "12/12".

set -e
HERE=$(cd "$(dirname "$0")" && pwd)
SB="${1:-$HERE/../.probe/ctc/sbtest}"
OUT="${2:-$HERE/gen}"

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

if [ "$SB" = "--preflight" ]; then
    SB="$2"
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

LANGS="arabic dutch english french german italian porter portuguese russian spanish turkish"
for L in $LANGS; do
    echo "stage=generate lang=$L cmd=$SB/snowball $SB/algorithms/$L.sbl -python -eprefix _ -o $OUT/${L}_stemmer.py"
    "$SB/snowball" "$SB/algorithms/$L.sbl" -python -eprefix _ -o "$OUT/${L}_stemmer.py"
done

# porter.sbl ships with the compiler but is not one of the libstemmer
# languages, so create_init.py does not list it; generate it separately.
python3 "$SB/python/create_init.py" "$OUT"
echo "gen_all: wrote the 11 upstream language stemmers and the upstream __init__.py to $OUT"
