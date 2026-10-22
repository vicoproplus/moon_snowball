#!/bin/sh
# Reproducible upstream Python generation for the ten libstemmer languages.
#
# The snowball 3.2.0 compiler is a Linux ELF that lives outside the delivery
# tree, so run this script inside WSL and pass its directory as SB_ROOT.  All
# paths below are relative to the module root:
#
#   wsl -e bash -lc 'cd "$(wslpath -a -u .)" && \
#       sh tools/gen_all.sh .probe/ctc/sbtest .planning/logs/u2/gen1'
#
# Usage: sh gen_all.sh [SB_ROOT] [OUT_DIR]
#   SB_ROOT  directory containing ./snowball, algorithms/ and python/create_init.py
#            (default: ../ctc/sbtest relative to this script)
#   OUT_DIR  output directory (default: ./gen)
#
# Output is byte-identical to .planning/data/py32/*_stemmer.py.

set -e
HERE=$(cd "$(dirname "$0")" && pwd)
SB="${1:-$HERE/../ctc/sbtest}"
OUT="${2:-$HERE/gen}"

test -x "$SB/snowball" || { echo "no executable $SB/snowball" >&2; exit 1; }
mkdir -p "$OUT"

LANGS="arabic dutch english french german italian portuguese russian spanish turkish"
for L in $LANGS; do
    "$SB/snowball" "$SB/algorithms/$L.sbl" -python -eprefix _ -o "$OUT/${L}_stemmer.py"
done

# porter.sbl ships with the compiler but is not one of the libstemmer
# languages, so create_init.py does not list it; generate it separately.
"$SB/snowball" "$SB/algorithms/porter.sbl" -python -eprefix _ \
    -o "$OUT/porter_stemmer.py"

python3 "$SB/python/create_init.py" "$OUT"
echo "generated $(ls "$OUT"/*.py | wc -l) files in $OUT"
