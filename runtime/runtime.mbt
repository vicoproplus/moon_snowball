// Runtime data model for Snowball-generated stemmers.
// Ported from snowball/runtime/api.c (C is the semantic authority) and
// snowballstemmer 3.1.1 basestemmer.py (Python blueprint).

///|
/// The `labN` control-flow labels of the generated Python.
/// A single error type covers lab0..lab4 (the maximum used by any 3.2.0
/// generated stemmer); `catch` arms name only the labels a block raises.
pub(all) suberror Lab {
  Lab0
  Lab1
  Lab2
  Lab3
  Lab4
}

///|
/// Mutable cursor state, mirrors `struct SN_env` (api.c:38-42).
pub(all) struct Env {
  mut current : String
  mut cursor : Int32
  mut limit : Int32
  mut limit_backward : Int32
  mut bra : Int32
  mut ket : Int32
}

///|
/// One row of a Snowball `among` table (basestemmer.py:1-12).
pub(all) struct Among {
  s : String
  substring_i : Int32
  result : Int32
  cb : ((Env) -> Bool)?
}

///|
/// Initial state for `s` (api.c:38-42): cursor 0, limit = len,
/// limit_backward 0, bra 0, ket = limit.
pub fn Env::new(s : String) -> Self {
  {
    current: s,
    cursor: 0,
    limit: s.length(),
    limit_backward: 0,
    bra: 0,
    ket: s.length(),
  }
}

///|
/// `set_current` from basestemmer.py:6-14: replace the string and reset
/// every cursor field to the initial state.
pub fn Env::set_current(self : Env, s : String) -> Unit {
  self.current = s
  self.cursor = 0
  self.limit = s.length()
  self.limit_backward = 0
  self.bra = 0
  self.ket = self.limit
}

///|
/// Free-function form of `Env::set_current` used by generated code.
pub fn set_current(e : Env, s : String) -> Unit {
  e.set_current(s)
}

///|
pub fn get_current(e : Env) -> String {
  e.current
}

///|
pub fn Among::new(
  s : String,
  substring_i : Int32,
  result : Int32,
  cb~ : ((Env) -> Bool)? = None,
) -> Self {
  { s, substring_i, result, cb, }
}

// ---------------------------------------------------------------- groupings
// snowball_runtime.c:286-332. The C runtime tests a bitmap of the range
// [min, max]; the reference Python tests `ch in grouping`. Here a grouping is
// the literal member string, compared one UTF-16 code unit at a time.

///|
/// Membership in a grouping written as a literal string of members.
/// Compares UTF-16 code units directly (both sides are already `UInt16`),
/// so non-ASCII BMP groups work unchanged.
pub fn in_set(g : String, ch : UInt16) -> Bool {
  let mut i = 0
  let n = g.length()
  while i < n {
    if g[i] == ch {
      return true
    }
    i += 1
  }
  false
}

///|
/// C `in_grouping` with `repeat = 0` (snowball_runtime.c:286-296): consume one
/// member code unit and advance; at the limit or on a non-member return false
/// without moving the cursor.
pub fn in_grouping(e : Env, g : String) -> Bool {
  if e.cursor >= e.limit {
    return false
  }
  if !in_set(g, e.current[e.cursor]) {
    return false
  }
  e.cursor += 1
  true
}

///|
/// C `in_grouping_b` with `repeat = 0` (snowball_runtime.c:298-308): mirror of
/// `in_grouping`, reading `current[cursor - 1]` and moving backwards.
pub fn in_grouping_b(e : Env, g : String) -> Bool {
  if e.cursor <= e.limit_backward {
    return false
  }
  if !in_set(g, e.current[e.cursor - 1]) {
    return false
  }
  e.cursor -= 1
  true
}

///|
/// C `in_grouping` with `repeat = 1` (snowball_runtime.c:286-296): advance
/// while the next code unit is a member; stop on a non-member and return true,
/// or return false at the limit.
pub fn go_in_grouping(e : Env, g : String) -> Bool {
  while e.cursor < e.limit {
    if !in_set(g, e.current[e.cursor]) {
      return true
    }
    e.cursor += 1
  }
  false
}

///|
/// C `in_grouping_b` with `repeat = 1` (snowball_runtime.c:298-308): advance
/// backwards while the preceding code unit is a member; stop and return true on
/// a non-member, or return false at `limit_backward`.
pub fn go_in_grouping_b(e : Env, g : String) -> Bool {
  while e.cursor > e.limit_backward {
    if !in_set(g, e.current[e.cursor - 1]) {
      return true
    }
    e.cursor -= 1
  }
  false
}

///|
/// C `out_grouping` with `repeat = 0` (snowball_runtime.c:310-320): consume one
/// non-member code unit and advance; at the limit or on a member return false
/// without moving the cursor.
pub fn out_grouping(e : Env, g : String) -> Bool {
  if e.cursor >= e.limit {
    return false
  }
  if !in_set(g, e.current[e.cursor]) {
    e.cursor += 1
    return true
  }
  false
}

///|
/// C `out_grouping_b` with `repeat = 0` (snowball_runtime.c:322-332): mirror of
/// `out_grouping`, reading `current[cursor - 1]` and moving backwards.
pub fn out_grouping_b(e : Env, g : String) -> Bool {
  if e.cursor <= e.limit_backward {
    return false
  }
  if !in_set(g, e.current[e.cursor - 1]) {
    e.cursor -= 1
    return true
  }
  false
}

///|
/// C `out_grouping` with `repeat = 1` (snowball_runtime.c:310-320): advance
/// while the next code unit is not a member; stop on a member and return true,
/// or return false at the limit.
pub fn go_out_grouping(e : Env, g : String) -> Bool {
  while e.cursor < e.limit {
    if in_set(g, e.current[e.cursor]) {
      return true
    }
    e.cursor += 1
  }
  false
}

///|
/// C `out_grouping_b` with `repeat = 1` (snowball_runtime.c:322-332): advance
/// backwards while the preceding code unit is not a member; stop and return
/// true on a member, or return false at `limit_backward`.
pub fn go_out_grouping_b(e : Env, g : String) -> Bool {
  while e.cursor > e.limit_backward {
    if in_set(g, e.current[e.cursor - 1]) {
      return true
    }
    e.cursor -= 1
  }
  false
}

// ------------------------------------------------------------ string compare
// snowball_runtime.c:334-350. The cursor advances only on a full match.

///|
/// C `eq_s` (snowball_runtime.c:334-337): check the remaining length first,
/// then compare code units; advance `cursor` by `s.length()` only on success.
pub fn eq_s(e : Env, s : String) -> Bool {
  let n = s.length()
  if e.limit - e.cursor < n {
    return false
  }
  let mut i = 0
  while i < n {
    if e.current[e.cursor + i] != s[i] {
      return false
    }
    i += 1
  }
  e.cursor += n
  true
}

///|
/// C `eq_s_b` (snowball_runtime.c:339-342): mirror of `eq_s` against
/// `limit_backward`; retreat `cursor` by `s.length()` only on success.
pub fn eq_s_b(e : Env, s : String) -> Bool {
  let n = s.length()
  if e.cursor - e.limit_backward < n {
    return false
  }
  let mut i = 0
  while i < n {
    if e.current[e.cursor - n + i] != s[i] {
      return false
    }
    i += 1
  }
  e.cursor -= n
  true
}

///|
/// C `eq_v` (snowball_runtime.c:344-346): `eq_v` is `eq_s` with the string's
/// own length, which is exactly `String`.
pub fn eq_v(e : Env, s : String) -> Bool {
  eq_s(e, s)
}

///|
/// C `eq_v_b` (snowball_runtime.c:348-350): `eq_v_b` is `eq_s_b` with the
/// string's own length.
pub fn eq_v_b(e : Env, s : String) -> Bool {
  eq_s_b(e, s)
}

// -------------------------------------------------------------- slice edits
// snowball_runtime.c:503-613. C edits one growable symbol buffer in place;
// MoonBit strings are immutable, so the same buffer is rebuilt from the same
// prefix and suffix, and the cursor bookkeeping follows the C line by line.

///|
/// C `replace_s` (snowball_runtime.c:503-523): replace `[c_bra, c_ket)` by `s`
/// and return `adjustment = len(s) - (c_ket - c_bra)`.
///
/// The content is rewritten unconditionally (even when `adjustment == 0`), but
/// `limit`/`cursor` are adjusted only inside `if adjustment != 0` — including
/// the `else if cursor > c_bra` arm, exactly as in C.
pub fn replace_s(e : Env, c_bra : Int32, c_ket : Int32, s : String) -> Int32 {
  let adjustment = s.length() - (c_ket - c_bra)
  e.current = e.current.view(end_offset=c_bra).to_owned() +
    s +
    e.current.view(start_offset=c_ket).to_owned()
  if adjustment != 0 {
    e.limit += adjustment
    if e.cursor >= c_ket {
      e.cursor += adjustment
    } else if e.cursor > c_bra {
      e.cursor = c_bra
    }
  }
  adjustment
}

///|
/// C `slice_check` (snowball_runtime.c:528-542): `0 <= bra <= ket <= limit`
/// and `limit <= len(current)` (C's `z->l > SIZE(z->p)` guard). A slice outside
/// these bounds is a generator bug; C throws, so abort here instead of reading
/// out of range.
fn slice_check(e : Env) -> Unit {
  if e.bra < 0 ||
    e.bra > e.ket ||
    e.ket > e.limit ||
    e.limit > e.current.length() {
    abort("Snowball slice invalid")
  }
}

///|
/// C `slice_from_s` (snowball_runtime.c:546-551): validate the slice, replace
/// `[bra, ket)` by `s`, then set `ket = bra + len(s)`.
pub fn slice_from(e : Env, s : String) -> Unit {
  slice_check(e)
  let _ = replace_s(e, e.bra, e.ket, s)
  e.ket = e.bra + s.length()
}

///|
/// C `slice_del` (snowball_runtime.c:557-576): the fast path, not routed
/// through `replace_s`. Validate the slice, then inside `if slice_size != 0`:
/// drop `[bra, ket)` from the buffer, `limit -= slice_size`, move the cursor
/// (`>= ket` → `-= slice_size`, else `> bra` → `= bra`), and `ket = bra`.
pub fn slice_del(e : Env) -> Unit {
  slice_check(e)
  let slice_size = e.ket - e.bra
  if slice_size != 0 {
    e.current = e.current.view(end_offset=e.bra).to_owned() +
      e.current.view(start_offset=e.ket).to_owned()
    e.limit -= slice_size
    if e.cursor >= e.ket {
      e.cursor -= slice_size
    } else if e.cursor > e.bra {
      e.cursor = e.bra
    }
    e.ket = e.bra
  }
}

///|
/// C `insert_s` (snowball_runtime.c:578-586): replace `[c_bra, c_ket)` by `s`,
/// then adjust `ket`/`bra` by the same `adjustment` — both shifts live inside
/// `if c_bra <= ket`, which is the C branch structure (the Python variant
/// differs here).
pub fn insert(e : Env, c_bra : Int32, c_ket : Int32, s : String) -> Unit {
  let adjustment = s.length() - (c_ket - c_bra)
  let _ = replace_s(e, c_bra, c_ket, s)
  if c_bra <= e.ket {
    e.ket += adjustment
    if c_bra <= e.bra {
      e.bra += adjustment
    }
  }
}

///|
/// C `slice_to` (snowball_runtime.c:592-603): validate the slice and return a
/// copy of `[bra, ket)`; read-only, no state change.
pub fn slice_to(e : Env) -> String {
  slice_check(e)
  e.current.view(start_offset=e.bra, end_offset=e.ket).to_owned()
}

///|
/// C `assign_to` (snowball_runtime.c:605-613): return a copy of `[0, limit)`;
/// read-only, no state change.
pub fn assign_to(e : Env) -> String {
  e.current.view(end_offset=e.limit).to_owned()
}

// --------------------------------------------------------------- among tables
// Among: Python blueprint among.py:1-12; algorithm basestemmer.py:102-212,
// which is the same binary search as the C runtime's table walk.

///|
/// Unsigned code-unit value of `s` at `i`, the `ord()` operand used by the
/// among comparisons (strings are UTF-16, so one code unit is one symbol).
fn code_point(s : String, i : Int32) -> Int32 {
  s[i].to_int()
}

///|
/// C `find_among` (snowball_runtime.c:378-429): binary search over a table
/// sorted lexicographically, then walk the `substring_i` prefix chain from the
/// surviving entry. `common_i`/`common_j` share the already-checked prefix of
/// the current binary-search window; `first_key_inspected` compensates for the
/// first probe being entry 0 (translation trap 20: `j - i <= 1 && i > 0`
/// breaks immediately).
///
/// A match sets `cursor = c + len(w.s)`; with a callback the cursor is set
/// before `f(e)` and again only when the callback returns true. Exhausting the
/// chain returns 0 with the cursor untouched.
pub fn find_among(e : Env, v : Array[Among]) -> Int32 {
  let mut i = 0
  let mut j = v.length()
  let c = e.cursor
  let l = e.limit
  let mut common_i = 0
  let mut common_j = 0
  let mut first_key_inspected = false
  while true {
    let k = i + ((j - i) >> 1)
    let mut diff = 0
    let mut common = if common_i < common_j { common_i } else { common_j }
    let w = v[k]
    let mut i2 = common
    while i2 < w.s.length() {
      if c + common == l {
        diff = -1
        break
      }
      diff = code_point(e.current, c + common) - code_point(w.s, i2)
      if diff != 0 {
        break
      }
      common += 1
      i2 += 1
    }
    if diff < 0 {
      j = k
      common_j = common
    } else {
      i = k
      common_i = common
    }
    if j - i <= 1 {
      if i > 0 {
        break
      }
      if j == i {
        break
      }
      if first_key_inspected {
        break
      }
      first_key_inspected = true
    }
  }
  while true {
    let w = v[i]
    if common_i >= w.s.length() {
      e.cursor = c + w.s.length()
      match w.cb {
        None => return w.result
        Some(f) =>
          if f(e) {
            e.cursor = c + w.s.length()
            return w.result
          }
      }
    }
    i = w.substring_i
    if i < 0 {
      return 0
    }
  } nobreak {
    0
  }
}

///|
/// C `find_among_b` (snowball_runtime.c:432-482): mirror of `find_among`
/// against `limit_backward`. Comparisons run from the end of each entry; when
/// the input is exhausted (`c - common == lb`) the entry sorts after the input,
/// so `diff = -1`. A match sets `cursor = c - len(w.s)` (the callback is
/// re-applied exactly as in the forward search), and exhausting the suffix
/// chain returns 0 with the cursor untouched.
pub fn find_among_b(e : Env, v : Array[Among]) -> Int32 {
  let mut i = 0
  let mut j = v.length()
  let c = e.cursor
  let lb = e.limit_backward
  let mut common_i = 0
  let mut common_j = 0
  let mut first_key_inspected = false
  while true {
    let k = i + ((j - i) >> 1)
    let mut diff = 0
    let mut common = if common_i < common_j { common_i } else { common_j }
    let w = v[k]
    let mut i2 = w.s.length() - 1 - common
    while i2 >= 0 {
      if c - common == lb {
        diff = -1
        break
      }
      diff = code_point(e.current, c - 1 - common) - code_point(w.s, i2)
      if diff != 0 {
        break
      }
      common += 1
      i2 -= 1
    }
    if diff < 0 {
      j = k
      common_j = common
    } else {
      i = k
      common_i = common
    }
    if j - i <= 1 {
      if i > 0 {
        break
      }
      if j == i {
        break
      }
      if first_key_inspected {
        break
      }
      first_key_inspected = true
    }
  }
  while true {
    let w = v[i]
    if common_i >= w.s.length() {
      e.cursor = c - w.s.length()
      match w.cb {
        None => return w.result
        Some(f) =>
          if f(e) {
            e.cursor = c - w.s.length()
            return w.result
          }
      }
    }
    i = w.substring_i
    if i < 0 {
      return 0
    }
  } nobreak {
    0
  }
}

// Reference implementations used only to cross-check the binary search.

///|
/// Linear longest-match scan of the forward table. Verification-only: it does
/// not consult `substring_i` or `cb`. Returns 0 with the cursor untouched when
/// no entry matches, otherwise sets `cursor = c + len(match)`.
pub fn find_among_linear(e : Env, v : Array[Among]) -> Int32 {
  let c = e.cursor
  let mut best = -1
  let mut best_len = -1
  let mut k = 0
  while k < v.length() {
    let w = v[k]
    let n = w.s.length()
    if n > best_len && c + n <= e.limit {
      let mut ok = true
      let mut t = 0
      while t < n {
        if e.current[c + t] != w.s[t] {
          ok = false
          break
        }
        t += 1
      }
      if ok {
        best = k
        best_len = n
      }
    }
    k += 1
  }
  if best < 0 {
    return 0
  }
  e.cursor = c + best_len
  v[best].result
}

///|
/// Linear longest-match scan of the backward table. Verification-only: it does
/// not consult `substring_i` or `cb`. Returns 0 with the cursor untouched when
/// no entry matches, otherwise sets `cursor = c - len(match)`.
pub fn find_among_b_linear(e : Env, v : Array[Among]) -> Int32 {
  let c = e.cursor
  let mut best = -1
  let mut best_len = -1
  let mut k = 0
  while k < v.length() {
    let w = v[k]
    let n = w.s.length()
    if n > best_len && c - n >= e.limit_backward {
      let mut ok = true
      let mut t = 0
      while t < n {
        if e.current[c - n + t] != w.s[t] {
          ok = false
          break
        }
        t += 1
      }
      if ok {
        best = k
        best_len = n
      }
    }
    k += 1
  }
  if best < 0 {
    return 0
  }
  e.cursor = c - best_len
  v[best].result
}
