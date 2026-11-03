#!/bin/sh
# scripts/gate.sh — the tri-state gate of the golden stage (Task 7 / FR-21).
#
# Usage:
#   sh scripts/gate.sh <golden-log> <driver-exit>
#
# <golden-log> is the file `moon run cmd/golden` wrote (stdout+stderr merged);
# <driver-exit> is the exit code of that run, captured as `$?` right after the
# command (never through a pipe).  The second argument is MANDATORY: a
# default of 0 would let a one-argument caller pass a log whose driver
# actually failed, so an omitted value is a usage error (exit 2).
#
# The gate is the ONLY judge of the golden run.  It reads the log structurally
# — every `lang=<n> checked=<N> mismatch=<M> ms=<t>` row is parsed into
# fields — and it never treats "no failing grep hit" as success (prototype
# defect P3: `grep -qv` on an empty log passed).  The declared `checked`
# values come from `lang_registry.mbt` (one source of truth; porter311's
# declared value is porter's, contract §3.4).
#
# Tri-state outcome:
#   healthy   exactly 37 rows, the language set is the expected 37, every
#             `checked` equals its declared value, every `mismatch` is 0 and
#             the driver exited 0        -> prints `GATE OK`, exit 0
#   degraded  0 rows / fewer than 37 rows / an unexpected language / a
#             `checked` that does not match  -> `expected 37 rows, got <n>`
#             (plus the missing names) or `checked mismatch <lang> want=<N>
#             got=<M>`, exit 1
#   failed    a non-zero `mismatch`, a non-zero driver exit, any collected
#             `MISMATCH` detail line, a missing `golden: 37/37 mismatch=0`
#             summary or a missing `case=` boundary line ->
#             `FAIL: mismatch != 0` (up to 5 `MISMATCH` detail lines),
#             `driver exit=<rc> rows=<n>`, `FAIL: <n> MISMATCH detail line(s)
#             present`, `FAIL: missing driver summary 'golden: 37/37
#             mismatch=0'` or `FAIL: missing driver boundary line 'case='`,
#             exit 1
#
# Exit codes: 0 pass, 1 any assertion failed, 2 usage error (missing log
# argument or driver exit, too many arguments, a non-numeric driver exit).

set -u

usage() {
    printf 'usage: sh scripts/gate.sh <golden-log> <driver-exit>\n' >&2
}

if [ "$#" -lt 2 ] || [ "$#" -gt 2 ]; then
    usage
    exit 2
fi

GATE_LOG=$1
DRIVER_RC=$2

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
#   BEGIN  read the registry into want[name] and order[1..37] (36 registry
#          languages + the porter311 control row appended below)
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
    if (nreg != 36 || !("porter" in want)) {
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
# A collected detail line is evidence in its own right: a healthy run never
# emits one, so its presence is asserted below, not merely printed.
/^MISMATCH / {
    if (ndet < 5) {
        det[++ndet] = $0
    }
}

# The summary line the driver prints (`golden: <ok>/<rows> mismatch=<sum>`)
# and its boundary assertion (`case=...`) are the two lines the row checks
# imply: a truncated transcript could satisfy the 37 rows and still have
# neither.
/^golden: / {
    if ($0 == "golden: 37/37 mismatch=0") {
        nsum++
    }
}
/^case=/ {
    ncase++
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

    # 2. exactly 37 rows (36 registry languages + the porter311 control row),
    #    and the language set must be the expected one.
    if (nrows != 37) {
        printf "expected 37 rows, got %d\n", nrows
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
    det_printed = 0
    for (i = 1; i <= nrows; i++) {
        if (got_mismatch[names[i]] != 0) {
            printf "FAIL: mismatch != 0\n"
            for (j = 1; j <= ndet; j++) {
                print det[j]
            }
            det_printed = 1
            bad = 1
            break
        }
    }

    # 5. a collected MISMATCH detail line is itself a failure.  The rows and
    #    the details can disagree (a driver that printed a detail line and
    #    then summarised mismatch=0), and the detail is the stronger evidence:
    #    it is never ignored because the 37 rows happen to look clean.
    if (ndet > 0) {
        printf "FAIL: %d MISMATCH detail line(s) present\n", ndet
        if (!det_printed) {
            for (j = 1; j <= ndet; j++) {
                print det[j]
            }
        }
        bad = 1
    }

    # 6. the driver summary line must be present and must be the healthy one.
    if (nsum < 1) {
        printf "FAIL: missing driver summary '\''golden: 37/37 mismatch=0'\''\n"
        bad = 1
    }

    # 7. the driver boundary assertion line must be present.
    if (ncase < 1) {
        printf "FAIL: missing driver boundary line '\''case='\''\n"
        bad = 1
    }

    if (bad) {
        exit 1
    }
    print "GATE OK"
    exit 0
}
' "$GATE_LOG"
