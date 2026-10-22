#!/bin/sh
# Decompress the arabic golden corpus (.planning/data/sd/arabic/*.txt.gz) into
# data/arabic/*.txt, because moonbitlang/x/fs has no gzip reader and the golden
# driver reads plain text (see translator-probe.md (d3)).
#
#   sh unpack_arabic.sh
#
# Idempotent: reuses existing plain files. ~240 MB on disk, 9,196,214 lines each.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
SRC="$HERE/../../.planning/data/sd/arabic"
DST="$HERE/data/arabic"
mkdir -p "$DST"
for f in voc output; do
    if [ -s "$DST/$f.txt" ]; then
        echo "keep $DST/$f.txt ($(wc -l < "$DST/$f.txt") lines)"
    else
        gzip -dc "$SRC/$f.txt.gz" > "$DST/$f.txt"
        echo "unpacked $DST/$f.txt ($(wc -l < "$DST/$f.txt") lines, $(wc -c < "$DST/$f.txt") bytes)"
    fi
done
