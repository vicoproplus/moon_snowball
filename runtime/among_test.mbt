// Cross-validation of the binary among search against the linear longest-match
// reference. All tables here are synthetic: the forward table is sorted
// lexicographically, the six backward tables are sorted by comparing entries
// from their end, with `substring_i` linking each entry to its longest proper
// suffix that is also present (and -1 when there is none).

///|
/// Compare two strings from their end, the sort order of a backward among
/// table: the first differing code unit counted from the end decides, and when
/// one string is an exhausted suffix the shorter one sorts first.
fn cmp_rev(a : String, b : String) -> Int32 {
  let mut i = a.length() - 1
  let mut j = b.length() - 1
  while i >= 0 && j >= 0 {
    if a[i] != b[j] {
      return a[i].to_int() - b[j].to_int()
    }
    i -= 1
    j -= 1
  }
  a.length() - b.length()
}

///|
/// Build a backward among table from `(string, result)` rows: insertion-sort
/// the rows by reverse order, then point each row's `substring_i` at the index
/// of its longest proper suffix that is also a row (-1 when there is none).
fn build_reverse_table(rows : Array[(String, Int32)]) -> Array[@runtime.Among] {
  let sorted = rows.copy()
  let mut k = 1
  while k < sorted.length() {
    let cur = sorted[k]
    let mut p = k - 1
    while p >= 0 && cmp_rev(sorted[p].0, cur.0) > 0 {
      sorted[p + 1] = sorted[p]
      p -= 1
    }
    sorted[p + 1] = cur
    k += 1
  }
  let out : Array[@runtime.Among] = []
  let mut idx = 0
  while idx < sorted.length() {
    let (s, r) = sorted[idx]
    let mut link = -1
    let mut t = 1
    while t < s.length() && link < 0 {
      let suffix = s.view(start_offset=t).to_owned()
      let mut q = 0
      while q < idx {
        if sorted[q].0 == suffix {
          link = q
        }
        q += 1
      }
      t += 1
    }
    out.push(@runtime.Among::new(s, link, r))
    idx += 1
  }
  out
}

///|
/// True when adjacent entries of a backward table are in non-decreasing
/// reverse order (a cheap guard against building the table the wrong way).
fn is_reverse_sorted(v : Array[@runtime.Among]) -> Bool {
  let mut k = 1
  while k < v.length() {
    if cmp_rev(v[k - 1].s, v[k].s) > 0 {
      return false
    }
    k += 1
  }
  true
}

///|
/// Forward search over a lexicographic table with a hand-checked prefix chain.
/// Every word must produce the same result code and cursor as the linear scan.
test "find_among agrees with linear reference on lexicographic table" {
  let fwd : Array[@runtime.Among] = [
    @runtime.Among::new("", -1, 9),
    @runtime.Among::new("a", -1, 1),
    @runtime.Among::new("ab", 1, 2),
    @runtime.Among::new("abc", 2, 3),
    @runtime.Among::new("abcd", 3, 4),
    @runtime.Among::new("b", 0, 5),
    @runtime.Among::new("bc", 5, 6),
    @runtime.Among::new("bcd", 6, 7),
  ]
  let words : Array[String] = [
    "", "a", "b", "ab", "abc", "abcd", "abcde", "xabc", "bc", "bcd", "bcde", "zzz",
    "abz", "bce", "ba", "abd",
  ]
  let mut checked = 0
  for w in words {
    let e1 = @runtime.Env::new(w)
    let e2 = @runtime.Env::new(w)
    let r1 = @runtime.find_among(e1, fwd)
    let r2 = @runtime.find_among_linear(e2, fwd)
    if r1 != r2 || e1.cursor != e2.cursor {
      fail(
        "forward word \{w.escape(quote=true)}: find_among = (\{r1},\{e1.cursor}) vs linear (\{r2},\{e2.cursor})",
      )
    }
    checked += 1
  }
  // Vacuity guard: the table does match, and the cursor lands past the word.
  let probe = @runtime.Env::new("abcd")
  inspect(@runtime.find_among(probe, fwd), content="4")
  inspect(probe.cursor, content="4")
  inspect(checked, content="16")
}

///|
/// Backward search over six synthetic reverse-ordered tables x 20 suffixes x
/// 3 prefixes (360 cases). Every case must agree on result code and cursor.
test "find_among_b agrees with linear reference on reverse tables" {
  let t0 = build_reverse_table([
    ("s", 1),
    ("ss", 2),
    ("sses", 3),
    ("es", 4),
    ("ies", 5),
  ])
  let t1 = build_reverse_table([
    ("ed", 1),
    ("eed", 2),
    ("ied", 3),
    ("ies", 4),
    ("s", 5),
  ])
  let t2 = build_reverse_table([
    ("ing", 1),
    ("ings", 2),
    ("ed", 3),
    ("s", 4),
    ("ly", 5),
  ])
  let t3 = build_reverse_table([
    ("ational", 1),
    ("ization", 2),
    ("ate", 3),
    ("icate", 4),
    ("al", 5),
    ("ation", 6),
  ])
  let t4 = build_reverse_table([
    ("ness", 1),
    ("ousness", 2),
    ("ement", 3),
    ("ment", 4),
    ("ent", 5),
    ("s", 6),
  ])
  let t5 = build_reverse_table([
    ("x", 1),
    ("ou", 2),
    ("iz", 3),
    ("bb", 4),
    ("ez", 5),
    ("s", 6),
    ("es", 7),
  ])
  let tables : Array[Array[@runtime.Among]] = [t0, t1, t2, t3, t4, t5]
  for ti, t in tables {
    if !is_reverse_sorted(t) {
      fail("table \{ti} is not sorted in reverse order")
    }
  }
  let suffixes : Array[String] = [
    "", "s", "ies", "sses", "ss", "ed", "eed", "ing", "bb", "iz", "ational", "ization",
    "ousness", "ement", "ment", "al", "icate", "ness", "ou", "x",
  ]
  let mut checked = 0
  for ti, t in tables {
    for suf in suffixes {
      for prefix in ["", "z", "qu"] {
        let w = prefix + suf
        let e3 = @runtime.Env::new(w)
        e3.cursor = e3.limit
        let e4 = @runtime.Env::new(w)
        e4.cursor = e4.limit
        let r3 = @runtime.find_among_b(e3, t)
        let r4 = @runtime.find_among_b_linear(e4, t)
        if r3 != r4 || e3.cursor != e4.cursor {
          fail(
            "table \{ti} word \{w.escape(quote=true)}: find_among_b = (\{r3},\{e3.cursor}) vs linear (\{r4},\{e4.cursor})",
          )
        }
        checked += 1
      }
    }
  }
  // Vacuity guard: t0 does match on a full suffix, cursor moving to the front.
  let probe = @runtime.Env::new("sses")
  probe.cursor = probe.limit
  inspect(@runtime.find_among_b(probe, t0), content="3")
  inspect(probe.cursor, content="0")
  inspect(tables.length(), content="6")
  inspect(checked, content="360")
}

///|
/// A `cb` callback is consulted only after the cursor is positioned at the end
/// of the matched entry; a rejection follows the `substring_i` chain to the
/// next (shorter) entry and repositions the cursor there (rt.c:378-429).
test "find_among consults cb after positioning the cursor" {
  let accept : (@runtime.Env) -> Bool = fn(env) { env.cursor == 3 }
  let fwd : Array[@runtime.Among] = [
    @runtime.Among::new("", -1, 9),
    @runtime.Among::new("a", -1, 1),
    @runtime.Among::new("ab", 1, 2),
    @runtime.Among::new("abc", 2, 3, cb=Some(accept)),
  ]
  let e = @runtime.Env::new("abc")
  inspect(@runtime.find_among(e, fwd), content="3")
  inspect(e.cursor, content="3")

  // The longest entry matches but rejects: the chain falls back to "ab"
  // (entry 2, no callback), and the cursor backs up to c + 2.
  let reject : (@runtime.Env) -> Bool = fn(_env) { false }
  let fwd2 : Array[@runtime.Among] = [
    @runtime.Among::new("", -1, 9),
    @runtime.Among::new("a", -1, 1),
    @runtime.Among::new("ab", 1, 2),
    @runtime.Among::new("abc", 2, 3, cb=Some(reject)),
  ]
  let e2 = @runtime.Env::new("abc")
  inspect(@runtime.find_among(e2, fwd2), content="2")
  inspect(e2.cursor, content="2")
}

///|
/// Backward mirror of the callback contract: `find_among_b` positions the
/// cursor at c - len(entry) before calling `cb`, and a rejection walks the
/// suffix chain (rt.c:432-482). The table is reverse-sorted: "", "a", "ba",
/// "cba".
test "find_among_b consults cb after positioning the cursor" {
  let accept : (@runtime.Env) -> Bool = fn(env) { env.cursor == 0 }
  let t : Array[@runtime.Among] = [
    @runtime.Among::new("", -1, 9),
    @runtime.Among::new("a", 0, 1),
    @runtime.Among::new("ba", 1, 2),
    @runtime.Among::new("cba", 2, 3, cb=Some(accept)),
  ]
  let e = @runtime.Env::new("cba")
  e.cursor = e.limit
  inspect(@runtime.find_among_b(e, t), content="3")
  inspect(e.cursor, content="0")

  let reject : (@runtime.Env) -> Bool = fn(_env) { false }
  let t2 : Array[@runtime.Among] = [
    @runtime.Among::new("", -1, 9),
    @runtime.Among::new("a", 0, 1),
    @runtime.Among::new("ba", 1, 2),
    @runtime.Among::new("cba", 2, 3, cb=Some(reject)),
  ]
  let e2 = @runtime.Env::new("cba")
  e2.cursor = e2.limit
  inspect(@runtime.find_among_b(e2, t2), content="2")
  inspect(e2.cursor, content="1")
}

///|
/// The cursor set before a `cb` call (basestemmer.py:147) can be undone by a
/// callback that moves it; after a `true` callback the cursor must be set
/// again to `c + len(entry)` (basestemmer.py:151). The callback only accepts
/// when it sees the pre-callback position (cursor 3) and then zeroes the
/// cursor, so an implementation that skips either set cannot return 3 with
/// cursor 3.
test "find_among repositions the cursor after a true callback" {
  let reset : (@runtime.Env) -> Bool = fn(env) {
    let positioned = env.cursor == 3
    env.cursor = 0
    positioned
  }
  let fwd : Array[@runtime.Among] = [
    @runtime.Among::new("", -1, 9),
    @runtime.Among::new("a", -1, 1),
    @runtime.Among::new("ab", 1, 2),
    @runtime.Among::new("abc", 2, 3, cb=Some(reset)),
  ]
  let e = @runtime.Env::new("abc")
  inspect(@runtime.find_among(e, fwd), content="3")
  // c = 0 and len("abc") = 3: the second set lands at 3, not at the 0 the
  // callback left behind (a missing second set would leave the cursor at 0).
  inspect(e.cursor, content="3")
}

///|
/// Backward mirror: the callback only accepts when it sees the pre-callback
/// position (cursor 0), then parks the cursor at the limit; a `true` callback
/// must still leave it at `c - len(entry)` (basestemmer.py:200-212, re-set at
/// line 207).
test "find_among_b repositions the cursor after a true callback" {
  let reset : (@runtime.Env) -> Bool = fn(env) {
    let positioned = env.cursor == 0
    env.cursor = env.limit
    positioned
  }
  let t : Array[@runtime.Among] = [
    @runtime.Among::new("", -1, 9),
    @runtime.Among::new("a", 0, 1),
    @runtime.Among::new("ba", 1, 2),
    @runtime.Among::new("cba", 2, 3, cb=Some(reset)),
  ]
  let e = @runtime.Env::new("cba")
  e.cursor = e.limit
  inspect(@runtime.find_among_b(e, t), content="3")
  // c = 3 and len("cba") = 3: the second set lands at 0, not at the 3 the
  // callback left behind.
  inspect(e.cursor, content="0")
}
