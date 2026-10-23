#!/usr/bin/env python3
"""Prototype Snowball-generated-Python -> MoonBit translator (ast based).

Usage: translate.py <in.py> <out.mbt> <StructName> <runtime_alias>

Design: the Python emitted by Snowball 3.2.0 for -python has a very small,
regular grammar (see .planning/facts/translator-probe.md).  We therefore do a
*structural* rewrite with `ast`, never regex: every decision below depends on
parent/child relationships (comparison operands, try/handler pairing, which
assignments are function-local), which a text pass cannot see.

Facts this file relies on (all verified on the ten 3.2.0 files):
  * only 17 statement kinds occur: Assign If Raise Pass Expr Try Break AugAssign
    While Return ClassDef FunctionDef Continue For ImportFrom;
  * every function body ends in `return <bool>`;
  * every `try` has exactly one handler, always `except labN: pass`, no
    else/finally;
  * locals are function-scoped and always assigned before use;
  * `self.X` only names runtime state (cursor/limit/bra/ket/limit_backward/
    current), a routine, or a runtime primitive -- except for the handful of
    stemmer-global integers/booleans that localise_mask refused to localise
    (dutch `I_p1`/`I_p2`), which stay class attributes -> MoonBit fields.
"""
import ast
import sys

UNIT = {"slice_from", "slice_del", "insert", "set_current"}
BOOL = {"eq_s", "eq_s_b", "eq_v", "eq_v_b",
        "in_grouping", "in_grouping_b", "out_grouping", "out_grouping_b",
        "go_in_grouping", "go_in_grouping_b", "go_out_grouping",
        "go_out_grouping_b"}
INT = {"find_among", "find_among_b", "replace_s"}
STR = {"slice_to", "assign_to", "get_current"}
RUNTIME = UNIT | BOOL | INT | STR
ENV_FIELDS = {"cursor", "limit", "limit_backward", "bra", "ket", "current"}

class Unsupported(Exception):
    """An input construct the translator refuses to express; nothing is written."""

    def __init__(self, kind, lineno):
        super().__init__(kind)
        self.kind = kind
        self.lineno = lineno


def mangle(name):
    if name.startswith("__r_"):
        return "r_" + name[4:]
    if name == "_stem":
        return "stem_inner"
    if name and name[0].isupper():
        return name[0].lower() + name[1:]
    return name


def str_lit(s):
    out = []
    for ch in s:
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\t":
            out.append("\\t")
        else:
            out.append(ch)
    return '"' + "".join(out) + '"'


def char_lit(ch):
    if ch == "\\":
        return "'\\\\'"
    if ch == "'":
        return "'\\''"
    if ch == "\n":
        return "'\\n'"
    return "'" + ch + "'"


def is_current_subscript(n):
    return (isinstance(n, ast.Subscript) and isinstance(n.value, ast.Attribute)
            and n.value.attr == "current")


class Translator:
    def __init__(self, tree, struct, rt):
        self.t = tree
        self.struct = struct
        self.rt = rt            # e.g. "rt"
        self.cls = None
        self.methods = set()
        self.consts = {}        # class-level a_N / as_N / g_* / I_*
        self.fields = {}        # self.<attr> that survive localisation
        self.locals = {}        # routine -> {local: MoonBit type}
        self.raising = set()

    # -------------------------------------------------------------- analysis
    def analyse(self):
        for node in self.t.body:
            if isinstance(node, ast.ClassDef) and node.bases and \
                    isinstance(node.bases[0], ast.Name) and node.bases[0].id == "BaseStemmer":
                self.cls = node
        if self.cls is None:
            raise Unsupported("no-basestemmer-class", 1)
        for item in self.cls.body:
            if isinstance(item, ast.FunctionDef):
                self.methods.add(item.name)
            elif isinstance(item, ast.Assign):
                tgt = item.targets[0]
                if isinstance(tgt, ast.Name):
                    self.consts[tgt.id] = item.value
            elif isinstance(item, ast.AnnAssign):
                # An annotated class constant (`a_0: list = [...]`) is a shape
                # emit_const never sees; it must be refused here, not dropped.
                raise Unsupported("const-shape", item.lineno)
        for node in ast.walk(self.t):
            if isinstance(node, ast.Attribute) and isinstance(node.value, ast.Name) \
                    and node.value.id == "self":
                a = node.attr
                if a in ENV_FIELDS or a in self.methods or a in RUNTIME:
                    continue
                self.fields[a] = self.consts.get(a)
        for item in self.cls.body:
            if not isinstance(item, ast.FunctionDef):
                continue
            loc = {}
            for node in ast.walk(item):
                pairs = []
                if isinstance(node, ast.Assign):
                    pairs = [(t, node.value) for t in node.targets]
                elif isinstance(node, (ast.AugAssign, ast.For)):
                    pairs = [(node.target, None)]
                for tgt, val in pairs:
                    if not isinstance(tgt, ast.Name) or tgt.id == "_":
                        continue
                    nm = tgt.id
                    nty = self.infer(val) if val is not None else None
                    if nm not in loc:
                        loc[nm] = nty or "Int"
                    elif nty and nty != loc[nm]:
                        raise Unsupported("local-type-conflict", getattr(val, "lineno", node.lineno))
            self.locals[item.name] = loc
        # error-signature closure: a routine needs `raise Lab` if it raises or
        # calls a routine that does.
        direct = {f.name: any(isinstance(n, ast.Raise) for n in ast.walk(f))
                  for f in self.cls.body if isinstance(f, ast.FunctionDef)}
        calls = {}
        for f in self.cls.body:
            if not isinstance(f, ast.FunctionDef):
                continue
            calls[f.name] = {n.func.attr for n in ast.walk(f)
                             if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute)
                             and isinstance(n.func.value, ast.Name) and n.func.value.id == "self"
                             and n.func.attr in self.methods}
        self.raising = {k for k, v in direct.items() if v}
        changed = True
        while changed:
            changed = False
            for k, callees in calls.items():
                if k not in self.raising and callees & self.raising:
                    self.raising.add(k)
                    changed = True

    def infer(self, val):
        if isinstance(val, ast.Constant):
            if isinstance(val.value, bool):
                return "Bool"
            if isinstance(val.value, str):
                return "String"
            return "Int"
        if isinstance(val, ast.Call):
            f = val.func
            if isinstance(f, ast.Attribute):
                if f.attr in STR:
                    return "String"
                if f.attr in BOOL:
                    return "Bool"
                if f.attr in INT:
                    return "Int"
                if f.attr in self.methods:
                    return "Bool"
        if isinstance(val, ast.UnaryOp) and isinstance(val.op, ast.Not):
            return "Bool"
        if isinstance(val, ast.Compare):
            return "Bool"
        return "Int"

    # ------------------------------------------------------------- expressions
    def e(self, n, as_char=False):
        m = getattr(self, "e_" + type(n).__name__, None)
        if m is None:
            raise Unsupported(type(n).__name__.lower(), n.lineno)
        return m(n, as_char)

    def e_Name(self, n, as_char=False):
        return mangle(n.id)

    def e_Attribute(self, n, as_char=False):
        v = n.value
        if isinstance(v, ast.Name) and v.id == "self":
            a = n.attr
            if a in ENV_FIELDS:
                return "e." + a
            if a in self.fields:
                return "p." + mangle(a)
            if a in self.methods:
                return mangle(a)
            raise Unsupported("self." + a, n.lineno)
        if isinstance(v, ast.Name) and v.id == self.cls.name:
            return mangle(n.attr)
        raise Unsupported("attribute", n.lineno)

    def e_Constant(self, n, as_char=False):
        if isinstance(n.value, bool):
            return "true" if n.value else "false"
        if isinstance(n.value, str):
            if as_char:
                if len(n.value) != 1:
                    raise Unsupported("char-literal", n.lineno)
                return char_lit(n.value)
            return str_lit(n.value)
        if n.value is None:
            return "None"
        return str(n.value)

    def e_Subscript(self, n, as_char=False):
        return f"{self.e(n.value)}[{self.e(n.slice)}]"

    def e_UnaryOp(self, n, as_char=False):
        if isinstance(n.op, ast.Not):
            return f"!({self.e(n.operand)})"
        if isinstance(n.op, ast.USub):
            return f"-{self.e(n.operand)}"
        raise Unsupported("unary", n.lineno)

    def e_BoolOp(self, n, as_char=False):
        op = " && " if isinstance(n.op, ast.And) else " || "
        return "(" + op.join(self.e(v) for v in n.values) + ")"

    def e_Compare(self, n, as_char=False):
        ops = {ast.Eq: "==", ast.NotEq: "!=", ast.Gt: ">", ast.GtE: ">=",
               ast.Lt: "<", ast.LtE: "<="}
        parts = []
        left = n.left
        for op, comp in zip(n.ops, n.comparators):
            ltxt = self.e(left, as_char=is_current_subscript(comp))
            rtxt = self.e(comp, as_char=is_current_subscript(left))
            parts.append(f"{ltxt} {ops[type(op)]} {rtxt}")
            left = comp
        return " && ".join(parts) if len(parts) > 1 else parts[0]

    def e_BinOp(self, n, as_char=False):
        ops = {ast.Add: "+", ast.Sub: "-", ast.Mult: "*", ast.Mod: "%"}
        return f"({self.e(n.left)} {ops[type(n.op)]} {self.e(n.right)})"

    def e_Tuple(self, n, as_char=False):
        raise Unsupported("tuple", n.lineno)

    def e_Set(self, n, as_char=False):
        raise Unsupported("set", n.lineno)

    def e_List(self, n, as_char=False):
        raise Unsupported("list", n.lineno)

    def rt_call(self, name, args):
        return f"@{self.rt}.{name}(" + ", ".join(["e"] + args) + ")"

    def e_Call(self, n, as_char=False):
        f = n.func
        if isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) \
                and f.value.id == "self":
            a = f.attr
            if a in self.methods:
                return mangle(a) + "(p" + "".join(", " + self.e(x) for x in n.args) + ")"
            if a in RUNTIME:
                return self.rt_call(a, [self.e(x) for x in n.args])
            raise Unsupported("method." + a, n.lineno)
        if isinstance(f, ast.Name) and f.id == "len":
            return f"({self.e(n.args[0])}).length()"
        if isinstance(f, ast.Name) and f.id == "Among":
            if len(n.args) >= 4 or n.keywords:
                raise Unsupported("among-callback", n.lineno)
            args = []
            for a in n.args:
                if isinstance(a, ast.Constant):
                    args.append(str_lit(a.value) if isinstance(a.value, str) else str(a.value))
                elif isinstance(a, ast.UnaryOp) and isinstance(a.op, ast.USub):
                    args.append("-" + str(a.operand.value))
                else:
                    raise Unsupported("among-arg", a.lineno)
            return f"@{self.rt}.Among::new({', '.join(args)})"
        raise Unsupported("call", n.lineno)

    # -------------------------------------------------------------- statements
    def stmts(self, body, ind):
        out = []
        for s in body:
            out.extend(self.stmt(s, ind))
        return out

    def stmt(self, s, ind):
        m = getattr(self, "s_" + type(s).__name__, None)
        if m is None:
            raise Unsupported(type(s).__name__.lower(), s.lineno)
        return m(s, ind, "  " * ind)

    def s_Pass(self, s, ind, pad):
        return []

    def s_Expr(self, s, ind, pad):
        v = s.value
        expr = self.e(v)
        if isinstance(v, ast.Call) and isinstance(v.func, ast.Attribute) \
                and isinstance(v.func.value, ast.Name) and v.func.value.id == "self" \
                and v.func.attr in UNIT:
            return [pad + expr]
        return [pad + "let _ = " + expr]

    def s_Assign(self, s, ind, pad):
        if len(s.targets) != 1:
            raise Unsupported("chained-assign", s.lineno)
        return [pad + self.e(s.targets[0]) + " = " + self.e(s.value)]

    def s_AugAssign(self, s, ind, pad):
        ops = {ast.Add: "+=", ast.Sub: "-="}
        return [pad + self.e(s.target) + " " + ops[type(s.op)] + " " + self.e(s.value)]

    def s_Return(self, s, ind, pad):
        return [pad + "return " + self.e(s.value)]

    def s_Break(self, s, ind, pad):
        return [pad + "break"]

    def s_Continue(self, s, ind, pad):
        return [pad + "continue"]

    def s_Raise(self, s, ind, pad):
        exc = s.exc
        name = exc.func.id if isinstance(exc, ast.Call) else exc.id
        if not (isinstance(name, str) and name.startswith("lab")):
            raise Unsupported("raise", s.lineno)
        return [pad + f"raise @{self.rt}.Lab" + name[3:]]

    def s_If(self, s, ind, pad):
        out = [pad + "if " + self.e(s.test) + " {"]
        out += self.stmts(s.body, ind + 1)
        if s.orelse:
            if len(s.orelse) == 1 and isinstance(s.orelse[0], ast.If):
                inner = self.s_If(s.orelse[0], ind, pad)
                inner[0] = pad + "} else " + inner[0][len(pad):]
                return out + inner
            out.append(pad + "} else {")
            out += self.stmts(s.orelse, ind + 1)
        out.append(pad + "}")
        return out

    def s_While(self, s, ind, pad):
        out = [pad + "while " + self.e(s.test) + " {"]
        out += self.stmts(s.body, ind + 1)
        out.append(pad + "}")
        return out

    def s_For(self, s, ind, pad):
        it = s.iter
        if isinstance(it, ast.Tuple):
            n = len(it.elts)
            out = [pad + f"for _ in 0..<{n} {{"]
        elif isinstance(it, ast.Call) and isinstance(it.func, ast.Name) and it.func.id == "range":
            out = [pad + f"for _ in 0..<{self.e(it.args[0])} {{"]
        else:
            raise Unsupported("for", s.lineno)
        out += self.stmts(s.body, ind + 1)
        out.append(pad + "}")
        return out

    def s_Try(self, s, ind, pad):
        if len(s.handlers) != 1:
            raise Unsupported("multi-except", s.lineno)
        if s.orelse:
            raise Unsupported("try-else", s.lineno)
        if s.finalbody:
            raise Unsupported("try-finally", s.lineno)
        h = s.handlers[0]
        lab = h.type.id
        out = [pad + "try {"] + self.stmts(s.body, ind + 1) + [pad + "} catch {"]
        out.append("  " * (ind + 1) + f"@{self.rt}.Lab" + lab[3:] + " => ()")
        out.append("  " * (ind + 1) + "err => raise err")
        out.append(pad + "}")
        return out

    def s_FunctionDef(self, s, ind, pad):
        raise Unsupported("nested-function", s.lineno)

    # ------------------------------------------------------------------ output
    def among_expr(self, el):
        # The callee is part of the shape: a class-level `A('a', -1, 1)`
        # (an alias of Among) is the same call the expression context refuses,
        # so both contexts reach the same `unsupported: call` verdict.
        if not (isinstance(el, ast.Call) and isinstance(el.func, ast.Name)
                and el.func.id == "Among"):
            raise Unsupported("call", getattr(el, "lineno", 0))
        if len(el.args) >= 4 or el.keywords:
            # Among(s, substring_i, result, __r_foo): the callback would have
            # to capture the stemmer struct at module-level table initialisation,
            # which MoonBit rejects ([4021] p is unbound).  Refuse, never guess.
            # The keyword form (`cb=__r_foo`) slips the positional count, so it
            # is refused too.
            raise Unsupported("among-callback", el.lineno)
        args = []
        for a in el.args:
            if isinstance(a, ast.Constant):
                args.append(str_lit(a.value) if isinstance(a.value, str) else str(a.value))
            elif isinstance(a, ast.UnaryOp) and isinstance(a.op, ast.USub):
                args.append("-" + str(a.operand.value))
            else:
                raise Unsupported("among-arg", a.lineno)
        return f"@{self.rt}.Among::new({', '.join(args)})"

    def emit_const(self, name, val):
        if name in self.fields:
            return None
        if isinstance(val, ast.List):
            lines = [f"let {mangle(name)} : Array[@{self.rt}.Among] = ["]
            lines += ["  " + self.among_expr(el) + "," for el in val.elts]
            lines.append("]")
            return "\n".join(lines)
        if isinstance(val, ast.Set):
            members = []
            for el in val.elts:
                if not isinstance(el, ast.Constant):
                    raise Unsupported("const-set-element", el.lineno)
                if el.value not in members:
                    members.append(el.value)
            return f"let {mangle(name)} : String = {str_lit(''.join(members))}"
        if isinstance(val, ast.Tuple):
            items = [str_lit(x.value) if isinstance(x, ast.Constant) else self.e(x)
                     for x in val.elts]
            return f"let {mangle(name)} : Array[String] = [{', '.join(items)}]"
        if isinstance(val, ast.Constant) and isinstance(val.value, str):
            # A grouping with no members needing escapes is emitted as a plain
            # string literal (`g_aeo = "aeo"`), not a set literal.
            return f"let {mangle(name)} : String = {str_lit(val.value)}"
        raise Unsupported("const-shape", getattr(val, "lineno", 0))

    def run(self):
        self.analyse()
        out = ["// Generated by translate.py from Snowball 3.2.0 -python output.",
               "// Structural translation; do not edit by hand.", ""]
        out += ["///|", f"pub struct {self.struct} {{", f"  e : @{self.rt}.Env"]
        for a, default in self.fields.items():
            ty = "Bool" if isinstance(default, ast.Constant) and isinstance(default.value, bool) else "Int"
            out.append(f"  mut {mangle(a)} : {ty}")
        out += ["}", "", "///|", f"pub fn {self.struct}::new() -> {self.struct} {{"]
        init = [f'e: @{self.rt}.Env::new("")']
        for a, default in self.fields.items():
            if isinstance(default, ast.Constant) and isinstance(default.value, bool):
                init.append(f"{mangle(a)}: {'true' if default.value else 'false'}")
            else:
                init.append(f"{mangle(a)}: 0")
        out += ["  { " + ", ".join(init) + " }", "}", ""]
        out += ["///|",
                f"pub fn stem_word(p : {self.struct}, word : String) -> String raise @{self.rt}.Lab {{",
                f"  @{self.rt}.set_current(p.e, word)",
                "  let _ = stem_inner(p)",
                f"  @{self.rt}.get_current(p.e)",
                "}", ""]
        for name, val in self.consts.items():
            txt = self.emit_const(name, val)
            if txt:
                out += ["///|", txt, ""]
        for item in self.cls.body:
            if isinstance(item, ast.FunctionDef):
                out += self.emit_routine(item)
        return "\n".join(out) + "\n"

    def emit_routine(self, fn):
        loc = self.locals.get(fn.name, {})
        sig = f"fn {mangle(fn.name)}(p : {self.struct}) -> Bool"
        if fn.name in self.raising:
            sig += f" raise @{self.rt}.Lab"
        out = ["///|", sig + " {", "  let e = p.e"]
        for name, ty in loc.items():
            default = {"Int": "0", "Bool": "false", "String": '""'}[ty]
            out.append(f"  let mut {mangle(name)} : {ty} = {default}")
        out += self.stmts(fn.body, 1)
        out += ["}", ""]
        return out


def main():
    src, dst, struct, rt = sys.argv[1:5]
    tree = ast.parse(open(src, encoding="utf-8").read())
    try:
        txt = Translator(tree, struct, rt).run()
    except Unsupported as exc:
        print(f"{src}:{exc.lineno}: unsupported: {exc.kind}", file=sys.stderr)
        return 2
    open(dst, "w", encoding="utf-8", newline="\n").write(txt)
    print(f"{dst}: {txt.count(chr(10))} lines")
    return 0


if __name__ == "__main__":
    sys.exit(main())
