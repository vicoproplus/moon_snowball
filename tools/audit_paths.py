#!/usr/bin/env python3
"""FR-22 / P4 mechanical audit — no absolute Windows path in the delivered scripts.

Run from the module root (or pass --root DIR):

    python tools/audit_paths.py [--root DIR] [--quiet]

The three patterns are the ones the plan's S1-a block spells: a forward-slash
`F:` root, the same root in backslash form, and a bare `C:` drive prefix.
They are assembled at run time so this file never contains a contiguous hit of
its own (the same reason scripts/pipeline.sh's header comment spells none).

Scope: scripts/, tools/ and cmd/golden/ under <root>.  `__pycache__`,
`_build` and `.mooncakes` are excluded at any depth: running a python helper
writes .pyc files that embed the absolute source path, so a naive walk reports
build residue as if it were source (see the pipeline.sh header).

Every hit is printed as `<path>:<line>:<text>`.  Exit 0 only when there is no
hit at all; 1 otherwise (2 on a usage error).
"""

import argparse
import pathlib
import sys

# Assembled, never literal: see the module docstring.
_PATTERNS = [
    "F" + ":/moonbit",
    "F" + ":\\moonbit",
    "C" + ":/",
]

_SCOPES = ["scripts", "tools", "cmd/golden"]
_EXCLUDE_DIRS = {"__pycache__", "_build", ".mooncakes"}


def scan(root):
    """Yield (relative path, line number, line text) for every pattern hit."""
    for scope in _SCOPES:
        base = root / scope
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file():
                continue
            if _EXCLUDE_DIRS & set(path.relative_to(root).parts):
                continue
            try:
                text = path.read_text(encoding="utf-8", errors="replace")
            except OSError as exc:
                print("audit: cannot read %s: %s" % (path, exc), file=sys.stderr)
                continue
            rel = path.relative_to(root).as_posix()
            for n, line in enumerate(text.splitlines(), 1):
                for pat in _PATTERNS:
                    if pat in line:
                        yield rel, n, line.strip()
                        break


def main():
    ap = argparse.ArgumentParser(description="FR-22 absolute-path audit")
    ap.add_argument("--root", default=None,
                    help="tree to scan (default: the current directory)")
    ap.add_argument("--quiet", action="store_true",
                    help="print only the summary line")
    args = ap.parse_args()

    root = pathlib.Path(args.root).resolve() if args.root else pathlib.Path.cwd().resolve()
    if not root.is_dir():
        print("audit: not a directory: %s" % root, file=sys.stderr)
        return 2

    hits = list(scan(root))
    if not args.quiet:
        for rel, n, line in hits:
            print("%s:%d:%s" % (rel, n, line))
    print("audit root=%s scopes=%s hits=%d %s"
          % (root.as_posix(), ",".join(_SCOPES), len(hits),
             "OK" if not hits else "FAIL"))
    return 0 if not hits else 1


if __name__ == "__main__":
    sys.exit(main())
