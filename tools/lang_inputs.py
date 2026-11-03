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
    deliverable   True  -> shipped language package (one of the 36)
                  False -> control entry only (porter311); NOT in lang_registry.mbt

`--check-registry <path>` mode validates that a generated `lang_registry.mbt`
declares exactly the deliverable names, in table order.  It exits non-zero when
the file is missing, unreadable, or disagrees with the table.
"""
import re
import sys

# Deliverable languages, in the order the golden driver and the gate log report
# them (lang_registry.mbt order).  `porter` is the upstream compiler's own
# porter.sbl algorithm (Snowball 3.2.0), i.e. a deliverable; it is NOT the
# same thing as the vendored snowballstemmer-3.1.1 `porter311` control entry
# at the end of the table.
LANG_INPUTS = [
    {"name": "arabic", "struct": "Arabic",
     "source": "upstream-generated", "golden_dir": "arabic", "deliverable": True},
    {"name": "armenian", "struct": "Armenian",
     "source": "upstream-generated", "golden_dir": "armenian", "deliverable": True},
    {"name": "basque", "struct": "Basque",
     "source": "upstream-generated", "golden_dir": "basque", "deliverable": True},
    {"name": "catalan", "struct": "Catalan",
     "source": "upstream-generated", "golden_dir": "catalan", "deliverable": True},
    {"name": "czech", "struct": "Czech",
     "source": "upstream-generated", "golden_dir": "czech", "deliverable": True},
    {"name": "danish", "struct": "Danish",
     "source": "upstream-generated", "golden_dir": "danish", "deliverable": True},
    {"name": "dutch", "struct": "Dutch",
     "source": "upstream-generated", "golden_dir": "dutch", "deliverable": True},
    {"name": "dutch_porter", "struct": "DutchPorter",
     "source": "upstream-generated", "golden_dir": "dutch_porter", "deliverable": True},
    {"name": "english", "struct": "English",
     "source": "upstream-generated", "golden_dir": "english", "deliverable": True},
    {"name": "esperanto", "struct": "Esperanto",
     "source": "upstream-generated", "golden_dir": "esperanto", "deliverable": True},
    {"name": "estonian", "struct": "Estonian",
     "source": "upstream-generated", "golden_dir": "estonian", "deliverable": True},
    {"name": "finnish", "struct": "Finnish",
     "source": "upstream-generated", "golden_dir": "finnish", "deliverable": True},
    {"name": "french", "struct": "French",
     "source": "upstream-generated", "golden_dir": "french", "deliverable": True},
    {"name": "german", "struct": "German",
     "source": "upstream-generated", "golden_dir": "german", "deliverable": True},
    {"name": "greek", "struct": "Greek",
     "source": "upstream-generated", "golden_dir": "greek", "deliverable": True},
    {"name": "hindi", "struct": "Hindi",
     "source": "upstream-generated", "golden_dir": "hindi", "deliverable": True},
    {"name": "hungarian", "struct": "Hungarian",
     "source": "upstream-generated", "golden_dir": "hungarian", "deliverable": True},
    {"name": "indonesian", "struct": "Indonesian",
     "source": "upstream-generated", "golden_dir": "indonesian", "deliverable": True},
    {"name": "irish", "struct": "Irish",
     "source": "upstream-generated", "golden_dir": "irish", "deliverable": True},
    {"name": "italian", "struct": "Italian",
     "source": "upstream-generated", "golden_dir": "italian", "deliverable": True},
    {"name": "lithuanian", "struct": "Lithuanian",
     "source": "upstream-generated", "golden_dir": "lithuanian", "deliverable": True},
    {"name": "nepali", "struct": "Nepali",
     "source": "upstream-generated", "golden_dir": "nepali", "deliverable": True},
    {"name": "norwegian", "struct": "Norwegian",
     "source": "upstream-generated", "golden_dir": "norwegian", "deliverable": True},
    {"name": "persian", "struct": "Persian",
     "source": "upstream-generated", "golden_dir": "persian", "deliverable": True},
    {"name": "polish", "struct": "Polish",
     "source": "upstream-generated", "golden_dir": "polish", "deliverable": True},
    {"name": "porter", "struct": "Porter",
     "source": "upstream-generated", "golden_dir": "porter", "deliverable": True},
    {"name": "portuguese", "struct": "Portuguese",
     "source": "upstream-generated", "golden_dir": "portuguese", "deliverable": True},
    {"name": "romanian", "struct": "Romanian",
     "source": "upstream-generated", "golden_dir": "romanian", "deliverable": True},
    {"name": "russian", "struct": "Russian",
     "source": "upstream-generated", "golden_dir": "russian", "deliverable": True},
    {"name": "serbian", "struct": "Serbian",
     "source": "upstream-generated", "golden_dir": "serbian", "deliverable": True},
    {"name": "sesotho", "struct": "Sesotho",
     "source": "upstream-generated", "golden_dir": "sesotho", "deliverable": True},
    {"name": "spanish", "struct": "Spanish",
     "source": "upstream-generated", "golden_dir": "spanish", "deliverable": True},
    {"name": "swedish", "struct": "Swedish",
     "source": "upstream-generated", "golden_dir": "swedish", "deliverable": True},
    {"name": "tamil", "struct": "Tamil",
     "source": "upstream-generated", "golden_dir": "tamil", "deliverable": True},
    {"name": "turkish", "struct": "Turkish",
     "source": "upstream-generated", "golden_dir": "turkish", "deliverable": True},
    {"name": "yiddish", "struct": "Yiddish",
     "source": "upstream-generated", "golden_dir": "yiddish", "deliverable": True},
    # Control entry: vendored snowballstemmer-3.1.1 porter stemmer, translated
    # as `Porter311` purely as a 37th gate row.  Not a deliverable, not in the
    # registry (AD2-6), no package of its own in the shipped sub-packages.
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
    """The 36 registry names, in table order."""
    return [e["name"] for e in LANG_INPUTS if e["deliverable"]]


def all_names():
    """Every input name, deliverables first, control entry last."""
    return [e["name"] for e in LANG_INPUTS]


def by_name(name):
    for e in LANG_INPUTS:
        if e["name"] == name:
            return e
    raise KeyError(name)


def py_input(entry):
    if entry["name"] in PY_INPUT:
        return PY_INPUT[entry["name"]]
    return "%s_stemmer.py" % entry["name"]


def check_registry(path):
    text = open(path, encoding="utf-8").read()
    names = re.findall(r'name\s*:\s*"([^"]+)"', text)
    if names != deliverable_names():
        sys.stderr.write("registry mismatch: %r != %r\n" % (names, deliverable_names()))
        return 1
    return 0


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--check-registry":
        sys.exit(check_registry(sys.argv[2]))
    print("%d inputs (%d deliverable + 1 control)" % (len(LANG_INPUTS), len(deliverable_names())))