#!/bin/sh
# scripts/gate.sh — the tri-state gate of the golden stage (Task 7 / FR-21).
#
# Usage:
#   sh scripts/gate.sh <golden-log> [driver-exit]
#
# <golden-log> is the file `moon run cmd/golden` wrote (stdout+stderr merged);
# [driver-exit] is the exit code of that run, captured as `$?` right after the
# command (never through a pipe).  When the argument is omitted it defaults to
# 0, so a caller that only has the log still gets the row/checked/mismatch
# assertions.
#
# The gate is the ONLY judge of the golden run.  It reads the log structurally
# — every `lang=<n> checked=<N> mismatch=<M> ms=<t>` row is parsed into
# fields — and it never treats "no failing grep hit" as success (prototype
# defect P3: `grep -qv` on an empty log passed).  The declared `checked`
# values come from `lang_registry.mbt` (one source of truth; porter311's
# declared value is porter's, contract §3.4).
#
# Tri-state outcome:
#   healthy   exactly 12 rows, the language set is the expected 12, every
#             `checked` equals its declared value, every `mismatch` is 0 and
#             the driver exited 0        -> prints `GATE OK`, exit 0
#   degraded  0 rows / fewer than 12 rows / an unexpected language / a
#             `checked` that does not match  -> `expected 12 rows, got <n>`
#             (plus the missing names) or `checked mismatch <lang> want=<N>
#             got=<M>`, exit 1
#   failed    a non-zero `mismatch`, or a non-zero driver exit ->
#             `FAIL: mismatch != 0` (up to 5 `MISMATCH` detail lines) or
#             `driver exit=<rc> rows=<n>`, exit 1
#
# Exit codes: 0 pass, 1 any assertion failed, 2 usage error (missing log
# argument, too many arguments, a non-numeric driver exit).

set -u

usage() {
    printf 'usage: sh scripts/gate.sh <golden-log> [driver-exit]\n' >&2
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
    exit 2
fi

GATE_LOG=$1
DRIVER_RC=${2:-0}

case "$DRIVER_RC" in
    '' | *[!0-9]*)
        printf 'gate: driver exit is not a number: %s\n' "$DRIVER_RC" >&2
        exit 2
        ;;
esac

if [ ! -f "$GATE_LOG" ]; then
    printf 'gate: log file is missing: %s\n' "$GATE_LOG" >&2
    exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 2
MODULE_ROOT=$(cd "$SCRIPT_DIR/.." && pwd -P) || exit 2
REGISTRY="$MODULE_ROOT/lang_registry.mbt"

if [ ! -f "$REGISTRY" ]; then
    printf 'gate: cannot read the language registry: %s\n' "$REGISTRY" >&2
    exit 1
fi

# One awk pass, three assertion groups:
#   BEGIN  read the registry into want[name] and order[1..12]
#   rows   parse every comparison row into names[]/got_checked[]/got_mismatch[]
#   END    judge the four conditions and print every violation it finds
# A missing language, a wrong `checked`, a non-zero `mismatch` and a non-zero
# driver exit are all reported in the same run: the gate names everything that
# is wrong, not only the first thing.
awk -v driver_rc="$DRIVER_RC" -v regf="$REGISTRY" '
BEGIN {
    nreg = 0
    cur = ""
    while ((getline line < regf) > 0) {
        if (line ~ /^[ \t]*name[ \t]*:[ \t]*"/) {
            s = line
            sub(/^[^"]*"/, "", s)
            sub(/".*$/, "", s)
            cur = s
        } else if (cur != "" && line ~ /^[ \t]*lines[ \t]*:[ \t]*[0-9]+/) {
            s = line
            sub(/^[^0-9]*/, "", s)
            sub(/[^0-9].*$/, "", s)
            want[cur] = s + 0
            order[++nreg] = cur
            cur = ""
        }
    }
    close(regf)
    if (nreg != 11 || !("porter" in want)) {
        printf "gate: cannot read the registry: %s (%d entries)\n", regf, nreg
        fatal = 1
    } else {
        # The control row declares the porter value (contract §3.4).
        want["porter311"] = want["porter"]
        order[++nreg] = "porter311"
    }
    nrows = 0
    ndet = 0
}

# Only the comparison rows carry ` checked=`; the `lang=<n> lines=<M>` rows
# and the `case=`/`data_root=` lines do not match this shape.
/^lang=[^ ]+ checked=[0-9]+ mismatch=[0-9]+ ms=/ {
    split($0, f, " ")
    lang = f[1]
    sub(/^lang=/, "", lang)
    ck = f[2]
    sub(/^checked=/, "", ck)
    mm = f[3]
    sub(/^mismatch=/, "", mm)
    nrows++
    names[nrows] = lang
    got_checked[lang] = ck + 0
    got_mismatch[lang] = mm + 0
}

# The driver prints at most five detail lines; the gate forwards at most five.
/^MISMATCH / {
    if (ndet < 5) {
        det[++ndet] = $0
    }
}

END {
    if (fatal) {
        exit 1
    }
    bad = 0

    # 1. the driver must have exited 0.
    if (driver_rc != 0) {
        printf "driver exit=%d rows=%d\n", driver_rc, nrows
        bad = 1
    }

    # 2. exactly 12 rows, and the language set must be the expected one.
    if (nrows != 12) {
        printf "expected 12 rows, got %d\n", nrows
        bad = 1
    }
    for (i = 1; i <= nreg; i++) {
        if (!(order[i] in got_checked)) {
            printf "missing lang=%s\n", order[i]
            bad = 1
        }
    }
    for (i = 1; i <= nrows; i++) {
        if (!(names[i] in want)) {
            printf "unexpected lang=%s\n", names[i]
            bad = 1
        }
    }

    # 3. every row checked value equals the declared one.
    for (i = 1; i <= nrows; i++) {
        lang = names[i]
        if ((lang in want) && got_checked[lang] != want[lang]) {
            printf "checked mismatch %s want=%d got=%d\n", lang, want[lang], got_checked[lang]
            bad = 1
        }
    }

    # 4. every row reports zero mismatch.
    for (i = 1; i <= nrows; i++) {
        if (got_mismatch[names[i]] != 0) {
            printf "FAIL: mismatch != 0\n"
            for (j = 1; j <= ndet; j++) {
                print det[j]
            }
            bad = 1
            break
        }
    }

    if (bad) {
        exit 1
    }
    print "GATE OK"
    exit 0
}
' "$GATE_LOG"
