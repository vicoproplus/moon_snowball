#!/bin/sh
# tools/unpack_arabic.sh — materialise the arabic golden corpus and verify it.
#
# Usage:
#   sh tools/unpack_arabic.sh <src_dir> <dst_dir>
#
# <src_dir>  corpus directory holding voc.txt.gz / output.txt.gz (arabic ships
#            gzipped) or plain voc.txt / output.txt (the other ten languages).
#            Relative paths resolve against the current directory; no module
#            root is assumed and no path is hard-coded.
# <dst_dir>  decompression cache, usually build/data/arabic.  Created when
#            absent.
#
# Integrity semantics — the fix for prototype defect P5 ("non-empty => trust"
# is not verification):
#
#   * a destination file is REUSED only when its line count equals the declared
#     count (9,196,214) AND its md5 equals the md5 of the source stream
#     (`gzip -dc <src>` for a .gz source, `md5sum <src>` for a plain one).
#     Only then does the script print `keep (verified)`.
#   * otherwise the file is decompressed again and the printed reason says why
#     (`line-count mismatch` / `content-hash mismatch`).
#   * a gzip that cannot be decoded (truncated / corrupt) stops the script
#     before the destination is replaced: gzip's own first stderr line — which
#     names gzip and the absolute source path — is the first stderr line, and no
#     per-line loop is ever entered.
#   * voc.txt and output.txt must end up with the same line count; a mismatch
#     prints both counts and fails.
#
# The decompression is installed atomically: gzip writes <dst>.part inside the
# destination directory, the line count is verified, and only then is the file
# renamed over the destination.  A failed run therefore never leaves a
# half-written corpus behind.
#
# Logging: every line is printed and appended to
#   <module-root>/.planning/logs/u2/T8-unpack.log
# (SNOWBALL_UNPACK_LOG overrides the path, e.g. for a scratch run).  The final
# line of a successful run is
#   stage=unpack lang=arabic source=voc.txt.gz lines=<n>
#
# The script is idempotent, reads nothing outside <src_dir>, and needs only
# POSIX sh plus gzip / wc / md5sum / awk / sed / cp / mv.
set -u

DECLARED_LINES=9196214

# to_posix <path> — a POSIX absolute path, whatever form the shell reports.
# Under Git-Bash `pwd -P` returns the extended Windows form `\\?\F:\dir` (and
# `$PWD` the plain `F:\dir`); inside WSL the path already is `/mnt/f/dir` and
# is returned untouched.  cygpath does the conversion when it exists, with a
# sed/awk fallback so the script also runs where cygpath is absent.
to_posix() {
    case "$1" in
        *\\*) ;;
        *) printf '%s\n' "$1"; return 0 ;;
    esac
    _tp=$(printf '%s\n' "$1" | sed -e 's|^\\\\?\\||')
    if command -v cygpath >/dev/null 2>&1; then
        _tp=$(cygpath -u "$_tp" 2>/dev/null) && [ -n "$_tp" ] && { printf '%s\n' "$_tp"; return 0; }
    fi
    printf '%s\n' "$_tp" | sed -e 's|\\|/|g' | awk '
        NR == 1 && /^[A-Za-z]:\// { printf "/%s%s\n", tolower(substr($0, 1, 1)), substr($0, 3); next }
        { print }'
}

HERE=$(cd "$(dirname "$0")" && pwd -P) || exit 4
HERE=$(to_posix "$HERE")
MODULE_ROOT=$(cd "$HERE/.." && pwd -P) || exit 4
MODULE_ROOT=$(to_posix "$MODULE_ROOT")
UNPACK_LOG=${SNOWBALL_UNPACK_LOG:-$MODULE_ROOT/.planning/logs/u2/T8-unpack.log}
PWD_POSIX=$(to_posix "$PWD") || PWD_POSIX=""
mkdir -p "$(dirname "$UNPACK_LOG")" 2>/dev/null || true

# u_log <text> — one line to stdout and to the unpack log.
u_log() {
    printf '%s\n' "$*"
    printf '%s\n' "$*" >>"$UNPACK_LOG" 2>/dev/null || true
}

# u_err <text> — one line to stderr and to the unpack log.
u_err() {
    printf '%s\n' "$*" >&2
    printf '%s\n' "$*" >>"$UNPACK_LOG" 2>/dev/null || true
}

u_usage() {
    printf 'usage: sh tools/unpack_arabic.sh <src_dir> <dst_dir>\n' >&2
    exit 2
}

# abspath <path> — POSIX absolute form of <path>, whether or not it exists.
# Relative paths resolve against the invocation directory.  A relative path
# with no POSIX form for the invocation directory (PWD_POSIX empty) cannot be
# resolved: say so and fail, never print a bare "/<relative>".

abspath() {
    case "$1" in
        /*) _ap=$1 ;;
        *)
            if [ -z "$PWD_POSIX" ]; then
                u_err "unpack failed: cannot resolve the relative path '$1': the invocation directory has no POSIX form (PWD=$PWD)"
                exit 4
            fi
            _ap=$PWD_POSIX/$1
            ;;
    esac
    _ad=$(cd "$(dirname "$_ap")" 2>/dev/null && pwd -P) || _ad=""
    _ad=$(to_posix "$_ad")
    _ab=$(basename "$_ap")
    if [ -z "$_ad" ]; then
        printf '%s\n' "$_ap"
    elif [ "$_ad" = "/" ]; then
        printf '/%s\n' "$_ab"
    else
        printf '%s/%s\n' "$_ad" "$_ab"
    fi
}


# count_lines <file> — the line count, no padding, no carriage returns.
count_lines() {
    wc -l <"$1" 2>/dev/null | tr -d ' \t\r'
}

# md5_of <file> — the digest alone.  The digest is read from stdin because
# GNU md5sum prefixes the line with a backslash when the file name contains a
# backslash (every Git-Bash Windows path does), which would corrupt the field.
md5_of() {
    md5sum <"$1" 2>/dev/null | awk '{print $1}'
}

[ "$#" -eq 2 ] || u_usage

# abspath runs in a command substitution, so its exit code does not end this
# shell: an unresolvable path yields an empty value and the guard below is
# what makes the run fail (non-zero) with the diagnostic already printed.
SRC=$(abspath "$1") || exit 4
[ -n "$SRC" ] || exit 4
DST=$(abspath "$2") || exit 4
[ -n "$DST" ] || exit 4

if [ ! -d "$SRC" ]; then
    u_err "unpack failed: missing $SRC (the corpus directory does not exist; absolute: $SRC)"
    exit 1
fi
if ! mkdir -p "$DST" 2>/dev/null; then
    u_err "unpack failed: cannot create the destination directory $DST (absolute: $DST)"
    exit 1
fi

TMPD="$DST/.unpack.$$"
rm -rf "$TMPD" 2>/dev/null || true
if ! mkdir -p "$TMPD" 2>/dev/null; then
    u_err "unpack failed: cannot create the scratch directory $TMPD"
    exit 1
fi
# INT/TERM clean the scratch dir and then leave: without the exit an
# interrupted run would carry on with a half-cleaned state.
trap 'rm -rf "$TMPD" 2>/dev/null || true' EXIT
trap 'rm -rf "$TMPD" 2>/dev/null || true; u_err "unpack interrupted"; exit 130' INT
trap 'rm -rf "$TMPD" 2>/dev/null || true; u_err "unpack terminated"; exit 143' TERM

# gz_error <errfile> <src> <dst> — print gzip's own first stderr line (it names
# gzip and the absolute source path), then the failure line naming both paths.
# The caller has already refused to touch <dst>; the caller treats the result
# as fatal.
gz_error() {
    # gzip emits a bare newline (a progress carriage return) before its
    # diagnostic, so the first NON-EMPTY line is the one to keep.
    _first=$(sed -n '/./{p;q;}' "$1" 2>/dev/null)
    [ -n "$_first" ] || _first="gzip: $2: cannot decode (absolute: $2)"
    u_err "$_first"
    u_err "unpack failed: gzip could not decode $2 (absolute: $2); $3 was not replaced"
    return 1
}

_lines_voc=""
_lines_output=""
_source_label=""
_fail=0

for _f in voc output; do
    _gz="$SRC/$_f.txt.gz"
    _txt="$SRC/$_f.txt"
    _dst="$DST/$_f.txt"

    if [ -f "$_gz" ]; then
        _mode=gz
        _src="$_gz"
    elif [ -f "$_txt" ]; then
        _mode=txt
        _src="$_txt"
    else
        u_err "unpack failed: missing corpus input for $_f: neither $_gz nor $_txt exists (absolute: $_gz; absolute: $_txt)"
        _fail=1
        break
    fi

    # -- reuse path: verify, never trust non-emptiness ----------------------
    _reason=""
    if [ -f "$_dst" ]; then
        _have_lines=$(count_lines "$_dst")
        _have_md5=$(md5_of "$_dst")
        if [ "$_mode" = gz ]; then
            _want_md5=$(gzip -dc "$_src" 2>/dev/null | md5sum | awk '{print $1}')
        else
            _want_md5=$(md5_of "$_src")
        fi
        if [ "$_have_lines" = "$DECLARED_LINES" ] && [ -n "$_have_md5" ] && [ "$_have_md5" = "$_want_md5" ]; then
            u_log "keep (verified) $_dst lines=$_have_lines md5=$_have_md5"
            case "$_f" in
                voc) _lines_voc=$_have_lines ;;
                output) _lines_output=$_have_lines ;;
            esac
            if [ "$_f" = voc ]; then
                _source_label=$(basename "$_src")
            fi
            continue
        fi
        if [ "$_have_lines" != "$DECLARED_LINES" ]; then
            _reason="line-count mismatch (found $_have_lines, declared $DECLARED_LINES)"
        else
            _reason="content-hash mismatch (found $_have_md5, stream $_want_md5)"
        fi
    fi

    # -- decompress (or copy) into a scratch file inside the destination ----
    _part="$TMPD/$_f.txt.part"
    rm -f "$_part" 2>/dev/null || true
    if [ "$_mode" = gz ]; then
        _gerr="$TMPD/$_f.gzip.err"
        if ! gzip -dc "$_src" >"$_part" 2>"$_gerr"; then
            gz_error "$_gerr" "$_src" "$_dst"
            _fail=1
            break
        fi
    else
        if ! cp "$_src" "$_part" 2>/dev/null; then
            u_err "unpack failed: cannot copy $_src to $_part"
            _fail=1
            break
        fi
    fi

    _new_lines=$(count_lines "$_part")
    if [ "$_new_lines" != "$DECLARED_LINES" ]; then
        u_err "unpack failed: $_src decompressed to ${_new_lines:-0} lines, declared $DECLARED_LINES (truncated or wrong corpus); $_dst was not replaced"
        _fail=1
        break
    fi
    if ! mv -f "$_part" "$_dst" 2>/dev/null; then
        u_err "unpack failed: cannot install $_dst from $_part"
        _fail=1
        break
    fi

    _new_md5=$(md5_of "$_dst")
    if [ -n "$_reason" ]; then
        u_log "reuse rejected ($_reason): re-decompressed $_dst from $_src lines=$_new_lines md5=$_new_md5"
    else
        u_log "unpacked $_dst from $_src lines=$_new_lines bytes=$(wc -c <"$_dst" | tr -d ' \t\r') md5=$_new_md5"
    fi
    case "$_f" in
        voc)
            _lines_voc=$_new_lines
            _source_label=$(basename "$_src")
            ;;
        output) _lines_output=$_new_lines ;;
    esac
done

if [ "$_fail" -ne 0 ]; then
    u_err "stage=unpack lang=arabic exit=1"
    exit 1
fi

# -- voc and output must agree ---------------------------------------------
if [ "$_lines_voc" != "$_lines_output" ]; then
    u_err "unpack failed: voc.txt has $_lines_voc lines but output.txt has $_lines_output lines"
    u_err "stage=unpack lang=arabic exit=1"
    exit 1
fi

u_log "stage=unpack lang=arabic source=$_source_label lines=$_lines_voc"
exit 0
