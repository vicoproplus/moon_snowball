#!/usr/bin/env python3
"""Translate Snowball-generated Python stemmers into MoonBit packages.

The input list is not written here: it comes from `tools/lang_inputs.py`, the
canonical table of pipeline inputs (the 11 upstream-generated deliverables plus
the `porter311` vendored control entry).  Every count below is derived from that
table, so adding or retiring an input never touches this driver.

Usage:
    python tools/translate_all.py --gen-dir <dir> --out-root <dir> \
        --module <module-name> [--vendor-dir <dir>] [--lang <name> ...] \
        [--include-control]

    --gen-dir        directory holding the generated `<lang>_stemmer.py` files
                     (output of tools/gen_all.sh)
    --out-root       module root that receives `<lang>/<lang>_gen.mbt`
    --module         MoonBit module name, used verbatim in each `moon.pkg`
                     import (`"<module>/runtime" @rt`)
    --vendor-dir     directory holding vendored Python sources; default is
                     `<module-root>/tools/vendor`, where the module root is the
                     parent of this script's directory
    --lang           translate only the named table entries (repeatable);
                     default is every deliverable entry
    --include-control
                     also translate non-deliverable control entries
                     (currently `porter311`); needed for the 12th gate row

Exit codes: 0 = every selected input translated; 2 = usage / missing input
(nothing written); non-zero from translate.py = translator refusal.
"""
import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lang_inputs  # noqa: E402

MOON_PKG_TEMPLATE = 'import {{\n  "{module}/runtime" @rt,\n}}\n'


def select_entries(names, include_control):
    """Resolve the CLI selection against the canonical table."""
    if names:
        known = lang_inputs.all_names()
        unknown = [n for n in names if n not in known]
        if unknown:
            raise SystemExit(f"unknown language input: {', '.join(unknown)} "
                             f"(known: {', '.join(known)})")
        entries = [lang_inputs.by_name(n) for n in names]
    else:
        entries = [e for e in lang_inputs.LANG_INPUTS
                   if e["deliverable"] or include_control]
    if not entries:
        raise SystemExit("no input selected")
    return entries


def resolve_py(entry, gen_dir, vendor_dir):
    """Absolute path of the Python source for one table entry."""
    rel = lang_inputs.py_input(entry)
    prefix = "tools/vendor/"
    if rel.startswith(prefix):
        return os.path.join(vendor_dir, rel[len(prefix):])
    return os.path.join(gen_dir, os.path.basename(rel))


def main(argv):
    parser = argparse.ArgumentParser(
        description="Translate pipeline inputs declared in tools/lang_inputs.py")
    parser.add_argument("--gen-dir", required=True)
    parser.add_argument("--out-root", required=True)
    parser.add_argument("--module", required=True)
    parser.add_argument("--vendor-dir", default=os.path.join(HERE, "vendor"))
    parser.add_argument("--lang", action="append", default=[])
    parser.add_argument("--include-control", action="store_true")
    args = parser.parse_args(argv[1:])

    entries = select_entries(args.lang, args.include_control)
    gen_dir = os.path.abspath(args.gen_dir)
    out_root = os.path.abspath(args.out_root)
    vendor_dir = os.path.abspath(args.vendor_dir)

    # Preflight: refuse before writing anything if a source file is absent.
    missing = [p for p in (resolve_py(e, gen_dir, vendor_dir) for e in entries)
               if not os.path.isfile(p)]
    if missing:
        for path in missing:
            print(f"input missing: {path}", file=sys.stderr)
        return 2

    translator = os.path.join(HERE, "translate.py")
    for entry in entries:
        name = entry["name"]
        pkg = os.path.join(out_root, name)
        os.makedirs(pkg, exist_ok=True)
        pkg_file = os.path.join(pkg, "moon.pkg")
        if not os.path.exists(pkg_file):
            with open(pkg_file, "w", encoding="utf-8", newline="\n") as f:
                f.write(MOON_PKG_TEMPLATE.format(module=args.module))
        src = resolve_py(entry, gen_dir, vendor_dir)
        dst = os.path.join(pkg, f"{name}_gen.mbt")
        subprocess.run([sys.executable, translator, src, dst,
                        entry["struct"], "rt"], check=True)

    print(f"translated {len(entries)} input(s) into {out_root}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
