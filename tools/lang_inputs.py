#!/usr/bin/env python3
"""Canonical declarative table of the U2 pipeline's translator inputs.

Single source of truth for "what gets translated".  `tools/translate_all.py`
imports `LANG_INPUTS` from here and derives every count from the table, so the
number of inputs is never a magic literal in a loop bound.

Table shape (see R-A of task-1-brief.md):

    name          language key used for directory / file naming
    struct        MoonBit struct name emitted by translate.py
    source        `upstream-generated` (snowball compiler, gen_all.sh)
                  or `vendored-3.1.1` (pypi snowballstemmer 3.1.1 tree)
    golden_dir    sub-directory of the golden corpus root that holds this
                  input's voc/output pair
    deliverable   True  -> shipped language package (one of the 11)
                  False -> control entry only (porter311); NOT in lang_registry.mbt

`--check-registry <path>` mode validates that a generated `lang_registry.mbt`
declares exactly the deliverable names, in table order.  It exits non-zero when
the file is missing, unreadable, or disagrees with the table.
"""
import re
import sys

# Deliverable languages, in the order the golden driver and the gate log report
# them.  `porter` is the upstream compiler's own porter.sbl algorithm (Snowball
# 3.2.0), i.e. a deliverable; it is NOT the same thing as the vendored
# snowballstemmer-3.1.1 `porter311` control entry at the end of the table.
LANG_INPUTS = [
    {"name": "arabic", "struct": "Arabic",
     "source": "upstream-generated", "golden_dir": "arabic", "deliverable": True},
    {"name": "dutch", "struct": "Dutch",
     "source": "upstream-generated", "golden_dir": "dutch", "deliverable": True},
    {"name": "english", "struct": "English",
     "source": "upstream-generated", "golden_dir": "english", "deliverable": True},
    {"name": "french", "struct": "French",
     "source": "upstream-generated", "golden_dir": "french", "deliverable": True},
    {"name": "german", "struct": "German",
     "source": "upstream-generated", "golden_dir": "german", "deliverable": True},
    {"name": "italian", "struct": "Italian",
     "source": "upstream-generated", "golden_dir": "italian", "deliverable": True},
    {"name": "porter", "struct": "Porter",
     "source": "upstream-generated", "golden_dir": "porter", "deliverable": True},
    {"name": "portuguese", "struct": "Portuguese",
     "source": "upstream-generated", "golden_dir": "portuguese", "deliverable": True},
    {"name": "russian", "struct": "Russian",
     "source": "upstream-generated", "golden_dir": "russian", "deliverable": True},
    {"name": "spanish", "struct": "Spanish",
     "source": "upstream-generated", "golden_dir": "spanish", "deliverable": True},
    {"name": "turkish", "struct": "Turkish",
     "source": "upstream-generated", "golden_dir": "turkish", "deliverable": True},
    # Control entry: vendored snowballstemmer-3.1.1 porter stemmer, translated
    # as `Porter311` purely as a 12th gate row.  Not a deliverable, not in the
    # registry (AD2-6), no package of its own in the 14 shipped sub-packages.
    {"name": "porter311", "struct": "Porter311",
     "source": "vendored-3.1.1", "golden_dir": "porter", "deliverable": False},
]

VENDORED_PORTER311 = "tools/vendor/snowballstemmer-3.1.1/porter_stemmer.py"

# Python source for entries whose file does not come from `gen_all.sh`.
# Upstream-generated entries are implied: `<name>_stemmer.py` inside the
# generated-Python directory given to translate_all.py.
PY_INPUT = {
    "porter311": VENDORED_PORTER311,
}


def deliverable_names():
    """The 11 registry names, in table order."""
    return [e["name"] for e in LANG_INPUTS if e["deliverable"]]


def all_names():
    """Every input name, deliverables first, control entry last."""
    return [e["name"] for e in LANG_INPUTS]


def by_name(name):
    for entry in LANG_INPUTS:
        if entry["name"] == name:
            return entry
    raise KeyError(f"unknown language input: {name}")


def py_input(entry):
    """Python source path for `entry`.

    Upstream-generated entries are bare filenames resolved against the
    generated-Python directory; vendored entries are repository-relative.
    """
    return PY_INPUT.get(entry["name"], f"{entry['name']}_stemmer.py")


NAME_RE = re.compile(r'name\s*:\s*"([^"]+)"')


def registry_names(path):
    """Extract every `name : "<x>"` value from a lang_registry.mbt file."""
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    return NAME_RE.findall(text)


def check_registry(path):
    """Return a list of human-readable problems (empty = the registry matches)."""
    expected = deliverable_names()
    problems = []
    try:
        found = registry_names(path)
    except FileNotFoundError:
        return [f"registry file not found: {path} "
                "(Task 6A creates lang_registry.mbt; run this check after it)"]
    except OSError as exc:
        return [f"registry file unreadable: {path}: {exc}"]
    if len(found) != len(expected):
        problems.append(f"registry declares {len(found)} name(s), expected "
                        f"{len(expected)}: found={found}")
    if found != expected:
        problems.append(f"registry name list mismatch\n  expected {expected}\n"
                        f"  found    {found}")
    return problems


def main(argv):
    args = argv[1:]
    if args and args[0] == "--check-registry":
        if len(args) != 2:
            print("usage: lang_inputs.py --check-registry <path-to-lang_registry.mbt>")
            return 2
        problems = check_registry(args[1])
        if problems:
            for line in problems:
                print(f"REGISTRY CHECK FAIL: {line}")
            print(f"REGISTRY CHECK FAIL: {args[1]}")
            return 1
        print(f"REGISTRY CHECK OK: {len(deliverable_names())} names in table "
              f"order -> {args[1]}")
        return 0
    if args:
        print("usage: lang_inputs.py [--check-registry <path>]")
        return 2
    for entry in LANG_INPUTS:
        print(f"{entry['name']:<10} struct={entry['struct']:<10} "
              f"source={entry['source']:<18} golden_dir={entry['golden_dir']:<10} "
              f"deliverable={str(entry['deliverable']).lower():<5} "
              f"py={py_input(entry)}")
    print(f"total inputs: {len(LANG_INPUTS)} "
          f"(deliverable: {len(deliverable_names())}, "
          f"control: {len(LANG_INPUTS) - len(deliverable_names())})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
