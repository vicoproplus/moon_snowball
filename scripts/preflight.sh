#!/bin/sh
# scripts/preflight.sh — the four-line pre-release gate (Task 6 / release spec §2.3, §4.7).
#
# Contract (exactly one line each, on stdout, in this order):
#   metadata=<ok|fail>
#   license=<ok|fail>
#   example=<ok|fail>
#   golden=<ok|fail>
# Any `fail` -> exit 1; all four `ok` -> exit 0.  Diagnostics go to stderr and
# never look like a contract line, so `grep -cE '^<name>=(ok|fail)$'` on the
# combined log counts exactly one line per check.
#
# The four checks:
#
#   metadata=  `moon.mod` carries the six required fields — name, version,
#              readme, license, repository, and the keywords+description pair —
#              with name in the form <author>/<module>, that author equal to the
#              `moon whoami` output, version matching ^0\.[0-9]+\.[0-9]+$, and
#              the `moon publish --dry-run` log carrying
#              `Dry run completed successfully` exactly once and zero
#              `field is not set or empty` warnings.  Success is judged on the
#              log string only: the dry-run exits non-zero even when it succeeds
#              (255/127 on the reference toolchain), so its exit code is
#              reported but never used as the verdict.
#              `moon whoami` needs a logged-in, credited account; an
#              unauthenticated runner fails this check by design (a CI runner
#              must inject the credential — see the release notes).
#
#   license=   `LICENSE` starts with `MIT License` and carries the MIT grant,
#              the notice-retention sentence and the AS-IS paragraph;
#              `LICENSE-SNOWBALL` carries the four upstream copyright lines and
#              the three BSD-3-Clause clauses.
#
#   example=   The first ```moonbit block of README.md is written into a scratch
#              executable package (stray/u5-preflight-example, git-ignored) with
#              the two imports the README names in prose, compiled and run with
#              `moon run --target native`, and its stdout compared byte-for-byte
#              with the first ```text block after the `期望输出` marker, after
#              stripping CR line ends (native `println` is CRLF on Windows).
#              The scratch package is removed by a trap on success and failure
#              (it must not survive: `moon check` would see a 16th package).
#              The scratch path is under stray/ rather than a dot-directory
#              because `moon` does not discover packages under a dot-directory.
#
#   golden=    Delegates to the pipeline's own golden stage:
#                  sh scripts/pipeline.sh --only=golden > log 2>&1; rc=$?
#              The pipeline resolves the corpus ladder itself (flag >
#              SNOWBALL_DATA_ROOT > module-relative default), forwards its own
#              unpacked arabic directory to the driver instead of letting the
#              driver fall back to `<cwd>/build/data/arabic`, normalises the
#              driver transcript, and calls scripts/gate.sh — the single judge
#              of the 12 rows, the registry `checked` values and `mismatch=0`.
#              preflight re-implements none of that: it asserts rc=0 AND that
#              the pipeline's log carries its `GATE OK` line.
#              The transcript captured here is the pipeline's already-normalised
#              one (the stage strips CR before the gate reads it), so nothing
#              strips CR a second time.
#              The stage needs the unpacked arabic artifact at build/data/arabic
#              (git-ignored): the CI job runs the full pipeline — which unpacks —
#              before preflight, and the local tree has it.  A clean tree without
#              the artifact fails with the pipeline's own message ("golden
#              failed: ... missing .../arabic"); the remedy is to run the full
#              pipeline once (or `--stage=unpack`) rather than to bypass this
#              check.
#
# Internal test hooks — a normal invocation ignores both:
#   PREFLIGHT_ONLY=<metadata|license|example|golden>
#       Run only that one check and print only its contract line.  Used for the
#       A9 smoke probe (example= alone) and for fast targeted re-runs.
#   PREFLIGHT_MOON_MOD=<path>
#       Alternate manifest for the static part of metadata=.  A relative path
#       resolves against the module root.  The dry-run assertion still validates
#       the manifest at the module root, because `moon publish` has no
#       manifest-path flag.  Used to prove metadata= fails on a broken copy of
#       moon.mod without touching the real tree.
#
# Run from anywhere inside the module; every path is derived from this script's
# location, so there is no machine-bound absolute path.  Requires POSIX sh
# (dash on Ubuntu, Git Bash on Windows).
#
# Logs (all git-ignored).  The operator's capture of this script's own stdout
# is .planning/logs/u5/preflight.log (the brief's acceptance command); a copy
# is kept as .planning/logs/u5/task6.log so the task's run log exists even when
# the redirect target is only one of the two names.  Per-check evidence:
# preflight-dryrun.log, preflight-example.{out,err}, preflight-example.
# {expected,actual}.txt, and preflight-golden.log — the last is the
# `scripts/pipeline.sh --only=golden` transcript, not a bare driver log.
#
# Known limits (documented, not fixed):
#   - The scratch path and the log names are fixed, so two concurrent runs in
#     one working tree would overwrite each other; run preflight serially.
#   - No timeout wraps the network steps (`moon whoami`, `moon publish
#     --dry-run`); a hung registry blocks the gate until the caller's own CI
#     timeout fires.
#   - `metadata=` requires exactly one `Dry run completed successfully` line:
#     zero is a registry/manifest failure, two would mean a merged log.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 2
MODULE_ROOT=$(cd "$SCRIPT_DIR/.." && pwd -P) || exit 2

if ! cd "$MODULE_ROOT"; then
    printf 'preflight: cannot cd to the module root: %s\n' "$MODULE_ROOT" >&2
    exit 2
fi

LOG_DIR=$MODULE_ROOT/.planning/logs/u5
SCRATCH_REL=stray/u5-preflight-example
SCRATCH=$MODULE_ROOT/$SCRATCH_REL

if ! mkdir -p "$LOG_DIR"; then
    printf 'preflight: cannot create the log directory: %s\n' "$LOG_DIR" >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# Diagnostics (stderr only — stdout is reserved for the four contract lines).
# ---------------------------------------------------------------------------
note() {
    printf '%s\n' "$*" >&2
}

# ---------------------------------------------------------------------------
# Scratch-package cleanup.  Runs on every exit path, including the signal
# traps below, so a failing `example=` never leaves a stray package behind.
# ---------------------------------------------------------------------------
SCRATCH_ACTIVE=0

cleanup() {
    if [ "$SCRATCH_ACTIVE" = 1 ]; then
        rm -rf "$SCRATCH" 2>/dev/null ||
            printf 'preflight: could not remove the scratch package: %s\n' "$SCRATCH" >&2
        SCRATCH_ACTIVE=0
    fi
    # Drop stray/ itself when this run created it and nothing else lives there.
    rmdir "$MODULE_ROOT/stray" 2>/dev/null || true
}

trap 'cleanup' EXIT
trap 'cleanup; exit 130' HUP INT TERM

# ---------------------------------------------------------------------------
# moon.mod helpers.
# ---------------------------------------------------------------------------
# field_str KEY FILE -> the first `KEY = "value"` string value, or empty.
field_str() {
    awk -v k="$1" '
        $0 ~ "^[ \t]*" k "[ \t]*=" {
            line = $0
            i = index(line, "\"")
            if (i == 0) next
            rest = substr(line, i + 1)
            j = index(rest, "\"")
            if (j > 0) { print substr(rest, 1, j - 1); exit }
        }
    ' "$2"
}

# field_count KEY FILE -> number of "..." items on the KEY line (0 if absent).
field_count() {
    awk -v k="$1" '
        $0 ~ "^[ \t]*" k "[ \t]*=" {
            line = $0
            n = gsub(/"[^"]*"/, "&", line)
            print n + 0
            exit
        }
        END { if (n == "") print 0 }
    ' "$2"
}

# ---------------------------------------------------------------------------
# metadata=
# ---------------------------------------------------------------------------
run_metadata() {
    mod=${PREFLIGHT_MOON_MOD:-moon.mod}
    case "$mod" in
        /* | [A-Za-z]:[\\/]*) ;;
        *) mod=$MODULE_ROOT/$mod ;;
    esac

    if [ ! -f "$mod" ]; then
        note "metadata: manifest not found: $mod"
        return 1
    fi

    bad=0

    # 1. the six required fields (keywords/description count as one pair).
    missing=
    for key in name version readme license repository description; do
        val=$(field_str "$key" "$mod")
        if [ -z "$val" ]; then
            missing="$missing $key"
            bad=1
        fi
    done
    kw=$(field_count keywords "$mod")
    if [ "${kw:-0}" -lt 1 ]; then
        missing="$missing keywords"
        bad=1
    fi
    if [ -n "$missing" ]; then
        note "metadata: missing or empty required field(s):$missing"
    fi

    # 2. name is <author>/<module>, and the author is the logged-in account.
    name=$(field_str name "$mod")
    author=
    case "$name" in
        */*/* | /* | */)
            note "metadata: name is not <author>/<module>: $name"
            bad=1
            ;;
        */*)
            author=${name%%/*}
            ;;
        *)
            note "metadata: name has no author prefix: $name"
            bad=1
            ;;
    esac

    # Two different failures, two different messages: a missing toolchain is
    # not a credential problem, and telling the operator to log in when `moon`
    # is simply absent sends them to the wrong fix.
    if ! command -v moon >/dev/null 2>&1; then
        note "metadata: 'moon' is not on PATH (toolchain absent), so the author cannot be verified; install the MoonBit toolchain — this is not a credential problem"
        bad=1
    else
        who_raw=$(moon whoami 2>/dev/null)
        who_rc=$?
        who=$(printf '%s\n' "$who_raw" | tr -d '\r' |
            sed -n 's/^Logged in as[[:space:]]*//p' | head -n 1)
        if [ "$who_rc" -ne 0 ] || [ -z "$who" ]; then
            note "metadata: 'moon whoami' failed (rc=$who_rc): publish needs a logged-in, credited runner (CI must inject the credential; see the release notes)"
            bad=1
        elif [ -n "$author" ] && [ "$author" != "$who" ]; then
            note "metadata: name author '$author' != 'moon whoami' output '$who'"
            bad=1
        fi
    fi

    # 3. version is 0.x.y.
    version=$(field_str version "$mod")
    if ! printf '%s\n' "$version" | grep -Eq '^0\.[0-9]+\.[0-9]+$'; then
        note "metadata: version '$version' does not match ^0\.[0-9]+\.[0-9]+$"
        bad=1
    fi

    # 4. readme points at a file that exists.
    readme=$(field_str readme "$mod")
    if [ -n "$readme" ] && [ ! -f "$MODULE_ROOT/$readme" ]; then
        note "metadata: readme field points to a missing file: $readme"
        bad=1
    fi

    if [ "$bad" -ne 0 ]; then
        # The static part already fails; the dry-run would only restate it.
        return 1
    fi

    # 5. the dry-run log.  Its exit status is non-zero on success (255/127 on
    # the reference toolchain), so only the log strings are asserted.
    dry_log=$LOG_DIR/preflight-dryrun.log
    note "metadata: running 'moon publish --dry-run' (log: $dry_log)"
    moon publish --dry-run > "$dry_log" 2>&1
    drc=$?
    n_ok=$(grep -c -- 'Dry run completed successfully' "$dry_log" 2>/dev/null)
    n_ok=${n_ok:-0}
    n_empty=$(grep -c -- 'field is not set or empty' "$dry_log" 2>/dev/null)
    n_empty=${n_empty:-0}

    note "metadata: dry-run exit=$drc (non-zero success is expected; only the log string is judged)"
    if [ "$n_ok" != "1" ]; then
        note "metadata: dry-run log has $n_ok line(s) with 'Dry run completed successfully' (expected 1)"
        # Quote the registry's own status line when the failure came from the
        # server rather than from the manifest: a transient outage is still a
        # fail (the success string is the criterion), but the operator should
        # not go hunting in moon.mod for it.
        grep -- 'Server status:' "$dry_log" 2>/dev/null |
            head -n 3 | sed 's/^/metadata:   /' >&2
        bad=1
    fi
    if [ "$n_empty" != "0" ]; then
        note "metadata: dry-run log has $n_empty 'field is not set or empty' warning line(s)"
        grep -n -- 'field is not set or empty' "$dry_log" 2>/dev/null |
            head -n 5 | sed 's/^/metadata:   /' >&2
        bad=1
    fi

    [ "$bad" -eq 0 ]
}

# ---------------------------------------------------------------------------
# license=
# ---------------------------------------------------------------------------
run_license() {
    bad=0

    if [ ! -f LICENSE ]; then
        note "license: missing file: LICENSE"
        bad=1
    else
        if ! head -n 1 LICENSE | grep -q 'MIT License'; then
            note "license: LICENSE first line does not contain 'MIT License'"
            bad=1
        fi
        for marker in \
            'Permission is hereby granted, free of charge, to any person obtaining a copy' \
            'The above copyright notice and this permission notice shall be included in all' \
            'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR'
        do
            if ! grep -F -q -- "$marker" LICENSE; then
                note "license: LICENSE lacks the MIT line: $marker"
                bad=1
            fi
        done
    fi

    if [ ! -f LICENSE-SNOWBALL ]; then
        note "license: missing file: LICENSE-SNOWBALL"
        bad=1
    else
        for holder in \
            'Copyright (c) 2001, Dr Martin Porter' \
            'Copyright (c) 2004,2005, Richard Boulton' \
            'Copyright (c) 2013, Yoshiki Shibukawa' \
            'Copyright (c) 2006-2025, Olly Betts'
        do
            if ! grep -F -q -- "$holder" LICENSE-SNOWBALL; then
                note "license: LICENSE-SNOWBALL lacks the upstream copyright line: $holder"
                bad=1
            fi
        done
        for clause in \
            '1. Redistributions of source code must retain the above copyright notice,' \
            '2. Redistributions in binary form must reproduce the above copyright notice,' \
            '3. Neither the name of the Snowball project nor the names of its contributors'
        do
            if ! grep -F -q -- "$clause" LICENSE-SNOWBALL; then
                note "license: LICENSE-SNOWBALL lacks BSD clause: $clause"
                bad=1
            fi
        done
    fi

    [ "$bad" -eq 0 ]
}

# ---------------------------------------------------------------------------
# example=
# ---------------------------------------------------------------------------
run_example() {
    readme=README.md
    if [ ! -f "$readme" ]; then
        note "example: missing file: $readme"
        return 1
    fi

    # The runnable program = the first ```moonbit fence.
    program=$(awk '
        /^```/ {
            if (open) {
                if (grab) exit
                open = 0
                next
            }
            open = 1
            grab = ($0 == "```moonbit")
            next
        }
        grab { print }
    ' "$readme")

    # The expected output = the first ```text fence after the 期望输出 marker.
    # Trailing blank lines are dropped (they only pad the fence).
    expected=$(awk '
        /期望输出/ { seen = 1 }
        /^```/ {
            if (open) {
                if (grab) exit
                open = 0
                next
            }
            if (seen) {
                open = 1
                grab = ($0 == "```text")
            }
            next
        }
        grab { n++; line[n] = $0 }
        END {
            while (n > 0 && line[n] == "") n--
            for (i = 1; i <= n; i++) print line[i]
        }
    ' "$readme")

    if [ -z "$program" ]; then
        note "example: $readme has no \`\`\`moonbit block"
        return 1
    fi
    if [ -z "$expected" ]; then
        note "example: $readme has no \`\`\`text block after the 期望输出 marker"
        return 1
    fi

    # A leftover scratch from an interrupted run would make example= judge the
    # wrong tree (and moon would see 16 packages); always start clean.
    rm -rf "$SCRATCH" 2>/dev/null
    if ! mkdir -p "$SCRATCH"; then
        note "example: cannot create the scratch package: $SCRATCH"
        return 1
    fi
    SCRATCH_ACTIVE=1

    if ! printf '%s\n' "$program" > "$SCRATCH/main.mbt"; then
        note "example: cannot write $SCRATCH/main.mbt"
        return 1
    fi

    # The imports live in the README prose, not in the fence; the module name is
    # the one moon.mod declares (author-prefixed), never hard-coded here, so a
    # rename cannot leave the scratch package importing a stale path.
    mod_name=$(grep '^name' moon.mod 2>/dev/null | cut -d'"' -f2)
    if [ -z "$mod_name" ]; then
        note "example: cannot read the module name from moon.mod (expected a 'name = \"<author>/<module>\"' line)"
        return 1
    fi
    if ! {
        printf 'pkgtype(kind: "executable")\n\n'
        printf 'import {\n'
        printf '  "%s/english" @english,\n' "$mod_name"
        printf '  "%s/runtime" @runtime,\n' "$mod_name"
        printf '}\n'
    } > "$SCRATCH/moon.pkg"; then
        note "example: cannot write $SCRATCH/moon.pkg"
        return 1
    fi

    out=$LOG_DIR/preflight-example.out
    err=$LOG_DIR/preflight-example.err
    note "example: running 'moon run --target native $SCRATCH_REL' (scratch removed on exit)"
    moon run --target native "$SCRATCH_REL" > "$out" 2> "$err"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        note "example: 'moon run --target native $SCRATCH_REL' exited $rc"
        tail -n 10 "$err" 2>/dev/null | sed 's/^/example:   /' >&2
        return 1
    fi

    expected_file=$LOG_DIR/preflight-example.expected.txt
    actual_file=$LOG_DIR/preflight-example.actual.txt
    printf '%s\n' "$expected" > "$expected_file"
    tr -d '\r' < "$out" > "$actual_file"

    if cmp -s "$expected_file" "$actual_file"; then
        note "example: README program printed the expected output byte-for-byte after CR strip"
        return 0
    fi

    note "example: 期望 vs 实际 differ"
    note "example: 期望: [$expected]"
    note "example: 实际: [$(tr -d '\r' < "$out")]"
    od -c "$out" 2>/dev/null | head -n 5 | sed 's/^/example: raw /' >&2
    return 1
}

# ---------------------------------------------------------------------------
# golden=
# ---------------------------------------------------------------------------
run_golden() {
    golden_log=$LOG_DIR/preflight-golden.log
    # The pipeline, not the bare driver: it owns the corpus ladder and the
    # arabic forwarding, and it is the only caller of scripts/gate.sh here.
    # `rc=$?` is taken right after the command, never through a pipe.
    note "golden: running 'sh scripts/pipeline.sh --only=golden' (the pipeline resolves the corpus ladder and calls scripts/gate.sh; about 3.5 min; log: $golden_log)"
    sh "$SCRIPT_DIR/pipeline.sh" --only=golden > "$golden_log" 2>&1
    rc=$?

    if [ "$rc" -ne 0 ]; then
        note "golden: 'scripts/pipeline.sh --only=golden' exited $rc (details also in .planning/logs/u2/T7-golden.log); last lines:"
        tail -n 12 "$golden_log" 2>/dev/null | sed 's/^/golden:   /' >&2
        return 1
    fi

    # Exit 0 alone is not the whole verdict: the pipeline prints `GATE OK` only
    # after scripts/gate.sh accepted the normalised transcript, so assert both.
    # The captured transcript is the pipeline's already-normalised one; no CR
    # stripping happens again here (the driver's raw log is
    # .planning/logs/u2/T7-golden.log, which the stage normalises in place).
    if ! grep -q '^GATE OK$' "$golden_log" 2>/dev/null; then
        note "golden: the pipeline exited 0 but its log carries no 'GATE OK' line; last lines:"
        tail -n 12 "$golden_log" 2>/dev/null | sed 's/^/golden:   /' >&2
        return 1
    fi

    note "golden: pipeline exit=0 and its log carries GATE OK"
    return 0
}

# ---------------------------------------------------------------------------
# Dispatch.
# ---------------------------------------------------------------------------
only=${PREFLIGHT_ONLY:-}
case "$only" in
    '' | metadata | license | example | golden) ;;
    *)
        note "preflight: unknown PREFLIGHT_ONLY=$only (want metadata|license|example|golden)"
        exit 2
        ;;
esac

want() {
    [ -z "$only" ] || [ "$only" = "$1" ]
}

status=0

if want metadata; then
    if run_metadata; then printf 'metadata=ok\n'; else printf 'metadata=fail\n'; status=1; fi
fi
if want license; then
    if run_license; then printf 'license=ok\n'; else printf 'license=fail\n'; status=1; fi
fi
if want example; then
    if run_example; then printf 'example=ok\n'; else printf 'example=fail\n'; status=1; fi
fi
if want golden; then
    if run_golden; then printf 'golden=ok\n'; else printf 'golden=fail\n'; status=1; fi
fi

if [ "$status" -eq 0 ]; then
    note "preflight: all requested checks passed"
else
    note "preflight: at least one check failed"
fi

exit "$status"
