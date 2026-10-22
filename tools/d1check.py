#!/usr/bin/env python3
"""D-1 semantic checker for the MoonBit dialect red line.

Rule (D-1): a `while true` loop whose body contains `break`/`continue` MUST NOT
carry a `nobreak` block; a `while true` WITHOUT `break`/`continue` MAY use
`nobreak` to yield a value.

The check is purely SEMANTIC: for every `nobreak` occurrence, locate the `}`
that closes the loop (the brace immediately before `nobreak`), match it to its
opening `{`, then inspect that loop's body for `break`/`continue`. Line numbers
are never compared against a hard-coded allow-list, so an upstream edit that
shifts lines cannot turn a correct tree red.

FAIL-CLOSED: a missing root directory or a tree with zero `.mbt` files is an
error, never a pass.

Usage:
    python d1check.py <module-root> [--list]     # --list may appear before or after the root

Exit codes:
    0 = pass (every `nobreak` hit is legal)
    1 = at least one violation
    2 = root missing / no root argument / root is not a directory
    3 = root exists but no `.mbt` file was scanned
"""

# N7 (port note): the prototype-era `d1shift.py` — a line-number helper that
# compared generated line numbers against a hard-coded allow-list — is retired
# and is deliberately NOT ported here.  D-1 is decided semantically by this
# file alone, so an upstream edit that shifts lines cannot flip the verdict.

import re
import sys
import pathlib

BREAK_RE = re.compile(r'\bbreak\b')
CONT_RE = re.compile(r'\bcontinue\b')
KEY = 'nobreak'


def iter_mbt(root):
    for p in sorted(root.rglob('*.mbt')):
        if '_build' in p.parts or '.mooncakes' in p.parts:
            continue
        yield p


def mask(text):
    """Blank out comments and string/char literals, preserving offsets and newlines.

    Handles: `// line comment`, `"string"`, `'char'`, and MoonBit multiline
    string lines that start with `#|`.
    """
    out = list(text)
    i, n = 0, len(text)

    def blank(a, b):
        for k in range(a, min(b, n)):
            if out[k] != '\n':
                out[k] = ' '

    while i < n:
        # MoonBit multiline string: a line whose first non-space chars are `#|`
        if text[i] == '#' and i + 1 < n and text[i + 1] == '|':
            j = text.find('\n', i)
            j = n if j < 0 else j
            blank(i, j)
            i = j
            continue
        c = text[i]
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            j = text.find('\n', i)
            j = n if j < 0 else j
            blank(i, j)
            i = j
        elif c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == '\\' else 1
            blank(i, j + 1)
            i = j + 1
        elif c == "'":
            j = i + 1
            while j < n and text[j] != "'":
                j += 2 if text[j] == '\\' else 1
            blank(i, j + 1)
            i = j + 1
        else:
            i += 1
    return ''.join(out)


def brace_pairs(masked):
    stack, pairs = [], []
    line = 0
    for off, ch in enumerate(masked):
        if ch == '\n':
            line += 1
        elif ch == '{':
            stack.append((off, line))
        elif ch == '}':
            if stack:
                o_off, o_line = stack.pop()
                pairs.append((o_off, off, o_line, line))
    return pairs


def line_starts(text):
    starts = [0]
    for i, ch in enumerate(text):
        if ch == '\n':
            starts.append(i + 1)
    return starts


def check_file(path):
    """Yield (lineno, while_lineno, body_text_or_None) for every real `nobreak`."""
    text = path.read_text(encoding='utf-8')
    masked = mask(text)
    starts = line_starts(text)
    by_close = {c: (o, ol, cl) for o, c, ol, cl in brace_pairs(masked)}
    for lineno, line in enumerate(masked.splitlines(), 1):
        if KEY not in line:
            continue
        line_off = starts[lineno - 1]
        nb = line_off + line.index(KEY)
        k = nb - 1
        while k >= 0 and masked[k] in ' \t':
            k -= 1
        if k < 0 or masked[k] != '}' or k not in by_close:
            yield lineno, None, None
            continue
        o_off, o_line, _c_line = by_close[k]
        line_len = starts[o_line + 1] - starts[o_line] if o_line + 1 < len(starts) else 200
        opener = masked[starts[o_line]:starts[o_line] + line_len]
        body = masked[o_off:k]
        if not re.search(r'\bwhile\b', opener):
            yield lineno, o_line + 1, body  # not a while: still judged on its body
            continue
        yield lineno, o_line + 1, body


def main(argv):
    args = argv[1:]
    listing = '--list' in args
    roots = [a for a in args if a != '--list']
    if not roots:
        print('usage: d1check.py <module-root> [--list]')
        print('ROOT MISSING FAIL')
        return 2
    root = pathlib.Path(roots[0])
    if not root.is_dir():
        print(f'ROOT MISSING FAIL: {root}')
        return 2
    files = list(iter_mbt(root))
    if not files:
        print(f'NO MBT FILES FAIL: {root}')
        return 3

    hits = []
    for p in files:
        rel = p.relative_to(root).as_posix()
        for lineno, wline, body in check_file(p):
            hits.append((rel, lineno, wline, body))

    print(f'SCANNED {len(files)} .mbt file(s) under {root.as_posix()}')
    if not hits:
        print('HITS []')
        print('RESULT PASS (no nobreak in tree)')
        return 0
    print('HITS', [f'{r}:{n}' for r, n, _, _ in hits])
    if listing:
        print('| 文件 | 行 | 所属 while 行 | break | continue | 语义判定 |')
        print('|---|---|---|---|---|---|')
    fail = 0
    for rel, lineno, wline, body in hits:
        if body is None:
            print(f'{rel}:{lineno} NO_ENCLOSING_BLOCK FAIL')
            fail += 1
            continue
        has_break = bool(BREAK_RE.search(body))
        has_cont = bool(CONT_RE.search(body))
        ok = not has_break and not has_cont
        if listing:
            print(f'| `{rel}` | {lineno} | {wline} | {has_break} | {has_cont} | '
                  f'{"PASS" if ok else "FAIL"} |')
        else:
            print(f'{rel}:{lineno} while@{wline} break={has_break} '
                  f'continue={has_cont} {"PASS" if ok else "FAIL"}')
        fail += 0 if ok else 1
    print('RESULT', 'PASS' if fail == 0 else f'FAIL ({fail} violation(s))')
    return 0 if fail == 0 else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))
