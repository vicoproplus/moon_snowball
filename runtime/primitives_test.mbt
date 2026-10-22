// Boundary assertions for the runtime primitives, the six-field Env state and
// the Among constructor. Primitive outcomes are pinned to the C authority
// snowball/runtime/snowball_runtime.c (line references per primitive); the
// initial-state / `ket = limit` contract comes from the Python blueprint
// basestemmer.py:5-14, and the proven port is
// .probe/translator/sbproto/runtime/runtime.mbt.

///|
/// SN_env initial state: cursor 0, limit = len, limit_backward 0, bra 0,
/// ket = limit (basestemmer.py:5-14; the Python blueprint is the source of the
/// `ket = limit` rule). api.c:38-42 only does replace_s then cursor = 0.
/// set_current resets all six fields on a dirty Env.
test "Env initial state and set_current reset all six fields" {
  let e = @runtime.Env::new("hello")
  inspect(@runtime.get_current(e), content="hello")
  inspect(e.current, content="hello")
  inspect(e.cursor, content="0")
  inspect(e.limit, content="5")
  inspect(e.limit_backward, content="0")
  inspect(e.bra, content="0")
  inspect(e.ket, content="5")

  let empty = @runtime.Env::new("")
  inspect(empty.cursor, content="0")
  inspect(empty.limit, content="0")
  inspect(empty.ket, content="0")

  // Dirty every field first: set_current must reset all six
  // (basestemmer.py:5-14).
  let e2 = @runtime.Env::new("abcdef")
  e2.cursor = 4
  e2.limit = 5
  e2.limit_backward = 2
  e2.bra = 1
  e2.ket = 3
  e2.set_current("xy")
  inspect(e2.current, content="xy")
  inspect(e2.cursor, content="0")
  inspect(e2.limit, content="2")
  inspect(e2.limit_backward, content="0")
  inspect(e2.bra, content="0")
  inspect(e2.ket, content="2")

  // The free-function form, used by generated code, is the same operation.
  let e3 = @runtime.Env::new("abcdef")
  e3.cursor = 3
  @runtime.set_current(e3, "z")
  inspect(e3.cursor, content="0")
  inspect(e3.limit, content="1")

  // get_current returns the whole buffer, not [0, limit).
  let e4 = @runtime.Env::new("abcdef")
  e4.cursor = 2
  e4.limit = 4
  inspect(@runtime.get_current(e4), content="abcdef")
}

///|
/// Forward groupings. The repeat=1 variants stop *on* the first symbol of the
/// opposite class and fail only at the limit (rt.c:286-320).
test "forward grouping primitives" {
  let g = "aeiou"
  let e = @runtime.Env::new("bcda")
  inspect(@runtime.go_out_grouping(e, g), content="true")
  inspect(e.cursor, content="3")
  // No member at all: runs to the limit and fails there.
  let e2 = @runtime.Env::new("bcd")
  inspect(@runtime.go_out_grouping(e2, g), content="false")
  inspect(e2.cursor, content="3")
  // go_in_grouping stops on the first non-member.
  let e3 = @runtime.Env::new("aaab")
  inspect(@runtime.go_in_grouping(e3, g), content="true")
  inspect(e3.cursor, content="3")
  let e4 = @runtime.Env::new("baaa")
  inspect(@runtime.go_in_grouping(e4, g), content="true")
  inspect(e4.cursor, content="0")
  // The repeat=0 variants consume exactly one symbol.
  let e5 = @runtime.Env::new("abc")
  inspect(@runtime.in_grouping(e5, g), content="true")
  inspect(e5.cursor, content="1")
  inspect(@runtime.in_grouping(e5, g), content="false")
  inspect(e5.cursor, content="1")
  let e6 = @runtime.Env::new("bcd")
  inspect(@runtime.out_grouping(e6, g), content="true")
  inspect(e6.cursor, content="1")
  // At the limit both repeat=0 variants fail without moving.
  e6.cursor = 3
  inspect(@runtime.in_grouping(e6, g), content="false")
  inspect(e6.cursor, content="3")
  inspect(@runtime.out_grouping(e6, g), content="false")
  inspect(e6.cursor, content="3")
  // Non-ASCII BMP members compare as UTF-16 code units.
  let e7 = @runtime.Env::new("éx")
  inspect(@runtime.in_grouping(e7, "éü"), content="true")
  inspect(e7.cursor, content="1")
}

///|
/// Backward groupings, including the limit_backward lower bound (rt.c:298-332).
test "backward grouping primitives honour limit_backward" {
  let g = "aeiou"
  // in_grouping_b consumes one member backwards.
  let e = @runtime.Env::new("baaa")
  e.cursor = 3
  inspect(@runtime.in_grouping_b(e, g), content="true")
  inspect(e.cursor, content="2")
  inspect(@runtime.in_grouping_b(e, g), content="true")
  inspect(e.cursor, content="1")
  inspect(@runtime.in_grouping_b(e, g), content="false")
  inspect(e.cursor, content="1")
  // cursor == limit_backward blocks even a member right before the cursor.
  let e2 = @runtime.Env::new("aab")
  e2.cursor = 2
  e2.limit_backward = 2
  inspect(@runtime.in_grouping_b(e2, g), content="false")
  inspect(e2.cursor, content="2")
  // out_grouping_b consumes one non-member backwards.
  let e3 = @runtime.Env::new("aab")
  e3.cursor = 3
  inspect(@runtime.out_grouping_b(e3, g), content="true")
  inspect(e3.cursor, content="2")
  inspect(@runtime.out_grouping_b(e3, g), content="false")
  inspect(e3.cursor, content="2")
  // ... and stops at limit_backward instead of crossing it.
  let e4 = @runtime.Env::new("bba")
  e4.cursor = 2
  e4.limit_backward = 1
  inspect(@runtime.out_grouping_b(e4, g), content="true")
  inspect(e4.cursor, content="1")
  inspect(@runtime.out_grouping_b(e4, g), content="false")
  inspect(e4.cursor, content="1")
  // go_out_grouping_b stops *on* the first member without consuming it, so a
  // member immediately before the cursor leaves the cursor in place ...
  let e5 = @runtime.Env::new("bcda")
  e5.cursor = 4
  inspect(@runtime.go_out_grouping_b(e5, g), content="true")
  inspect(e5.cursor, content="4")
  // ... and with non-members in between it walks back to the member.
  let e5b = @runtime.Env::new("abcd")
  e5b.cursor = 4
  inspect(@runtime.go_out_grouping_b(e5b, g), content="true")
  inspect(e5b.cursor, content="1")
  let e6 = @runtime.Env::new("bcd")
  e6.cursor = 3
  inspect(@runtime.go_out_grouping_b(e6, g), content="false")
  inspect(e6.cursor, content="0")
  // limit_backward is the lower bound: the 'a' at index 0 stays untouched.
  let e7 = @runtime.Env::new("abcd")
  e7.cursor = 4
  e7.limit_backward = 1
  inspect(@runtime.go_out_grouping_b(e7, g), content="false")
  inspect(e7.cursor, content="1")
  // go_in_grouping_b stops on the first non-member.
  let e8 = @runtime.Env::new("baaa")
  e8.cursor = 4
  inspect(@runtime.go_in_grouping_b(e8, g), content="true")
  inspect(e8.cursor, content="1")
  let e9 = @runtime.Env::new("aaab")
  e9.cursor = 4
  inspect(@runtime.go_in_grouping_b(e9, g), content="true")
  inspect(e9.cursor, content="4")
  // All members: walks to limit_backward and fails there.
  let e10 = @runtime.Env::new("aaaa")
  e10.cursor = 4
  inspect(@runtime.go_in_grouping_b(e10, g), content="false")
  inspect(e10.cursor, content="0")
  // limit_backward lower bound: two members are consumed, then the bound stops
  // the walk even though 'a' at index 1 is still a member.
  let e11 = @runtime.Env::new("aaaa")
  e11.cursor = 4
  e11.limit_backward = 2
  inspect(@runtime.go_in_grouping_b(e11, g), content="false")
  inspect(e11.cursor, content="2")
}

///|
/// eq_s / eq_s_b (rt.c:334-342): check the available length first, compare,
/// and advance only on a full match. eq_s_b measures against limit_backward.
test "eq_s and eq_s_b advance only on a full match" {
  let e = @runtime.Env::new("abcd")
  inspect(@runtime.eq_s(e, "ab"), content="true")
  inspect(e.cursor, content="2")
  inspect(@runtime.eq_s(e, "ac"), content="false")
  inspect(e.cursor, content="2")
  // Empty string always matches, cursor unchanged.
  inspect(@runtime.eq_s(e, ""), content="true")
  inspect(e.cursor, content="2")
  // Too long for the remaining input: false without reading past the limit.
  inspect(@runtime.eq_s(e, "cde"), content="false")
  inspect(e.cursor, content="2")
  inspect(@runtime.eq_s(e, "cd"), content="true")
  inspect(e.cursor, content="4")
  // At the limit only the empty string matches.
  inspect(@runtime.eq_s(e, ""), content="true")
  inspect(e.cursor, content="4")
  inspect(@runtime.eq_s(e, "x"), content="false")
  inspect(e.cursor, content="4")

  let e2 = @runtime.Env::new("abcd")
  e2.cursor = 4
  inspect(@runtime.eq_s_b(e2, "cd"), content="true")
  inspect(e2.cursor, content="2")
  inspect(@runtime.eq_s_b(e2, "bc"), content="false")
  inspect(e2.cursor, content="2")
  inspect(@runtime.eq_s_b(e2, ""), content="true")
  inspect(e2.cursor, content="2")
  inspect(@runtime.eq_s_b(e2, "abcd"), content="false")
  inspect(e2.cursor, content="2")
  inspect(@runtime.eq_s_b(e2, "ab"), content="true")
  inspect(e2.cursor, content="0")
  inspect(@runtime.eq_s_b(e2, ""), content="true")
  inspect(e2.cursor, content="0")
  inspect(@runtime.eq_s_b(e2, "a"), content="false")
  inspect(e2.cursor, content="0")

  // eq_s_b uses cursor - limit_backward, not cursor: cursor 3 and lb 2 leave
  // one symbol, so "bc" (two symbols) fails even though current[1..3) is "bc".
  let e3 = @runtime.Env::new("abcd")
  e3.cursor = 3
  e3.limit_backward = 2
  inspect(@runtime.eq_s_b(e3, "bc"), content="false")
  inspect(e3.cursor, content="3")
  inspect(@runtime.eq_s_b(e3, "c"), content="true")
  inspect(e3.cursor, content="2")
  inspect(@runtime.eq_s_b(e3, "c"), content="false")
  inspect(e3.cursor, content="2")
}

///|
/// replace_s (rt.c:503-523): content is rewritten unconditionally, but limit
/// and cursor move only inside `if adjustment != 0`, with the cursor fix being
/// `cursor >= c_ket` / `else if cursor > c_bra`.
test "replace_s follows the C adjustment branches" {
  // adjustment != 0 and cursor >= c_ket: cursor shifts by the adjustment.
  let e = @runtime.Env::new("abcdef")
  e.cursor = 5
  e.bra = 1
  e.ket = 3
  inspect(@runtime.replace_s(e, 1, 3, "XYZW"), content="2")
  inspect(e.current, content="aXYZWdef")
  inspect(e.limit, content="8")
  inspect(e.cursor, content="7")
  inspect(e.ket, content="3")
  // c_bra < cursor < c_ket and adjustment != 0: cursor snaps back to c_bra.
  let e2 = @runtime.Env::new("abcdef")
  e2.cursor = 2
  e2.bra = 1
  e2.ket = 4
  inspect(@runtime.replace_s(e2, 1, 4, "XX"), content="-1")
  inspect(e2.current, content="aXXef")
  inspect(e2.limit, content="5")
  inspect(e2.cursor, content="1")
  // cursor == c_bra is not "inside": the snap-back arm needs a strict >.
  let e3 = @runtime.Env::new("abcdef")
  e3.cursor = 1
  e3.bra = 1
  e3.ket = 3
  inspect(@runtime.replace_s(e3, 1, 3, "XXXX"), content="2")
  inspect(e3.current, content="aXXXXdef")
  inspect(e3.limit, content="8")
  inspect(e3.cursor, content="1")
  // adjustment == 0: content still changes, but neither limit nor cursor is
  // touched (an interior cursor is *not* snapped back to c_bra).
  let e4 = @runtime.Env::new("abcdef")
  e4.cursor = 2
  e4.bra = 1
  e4.ket = 3
  inspect(@runtime.replace_s(e4, 1, 3, "XY"), content="0")
  inspect(e4.current, content="aXYdef")
  inspect(e4.limit, content="6")
  inspect(e4.cursor, content="2")
  inspect(e4.ket, content="3")
  // Empty replacement removes [c_bra, c_ket) and shifts limit/cursor back.
  let e5 = @runtime.Env::new("abcdef")
  e5.cursor = 6
  e5.bra = 2
  e5.ket = 5
  inspect(@runtime.replace_s(e5, 2, 5, ""), content="-3")
  inspect(e5.current, content="abf")
  inspect(e5.limit, content="3")
  inspect(e5.cursor, content="3")
}

///|
/// insert (rt.c:578-586): replace [c_bra, c_ket) then shift ket/bra by the
/// adjustment, both shifts nested inside `if c_bra <= ket`.
test "insert shifts bra and ket only when c_bra <= ket" {
  // c_bra = 3 > e.ket = 2: C's whole correction block is skipped, so bra and
  // ket keep their values and only content/limit move. The Python blueprint
  // uses two independent `if`s instead (basestemmer.py:252-256):
  // `c_bra <= self.bra` is 3 <= 3 there, so a Python-style insert would set
  // bra = 4 and this case discriminates the two forks.
  let e = @runtime.Env::new("abc")
  e.bra = 3
  e.ket = 2
  @runtime.insert(e, 3, 3, "Z")
  inspect(e.current, content="abcZ")
  inspect(e.limit, content="4")
  inspect(e.bra, content="3")
  inspect(e.ket, content="2")
  inspect(e.cursor, content="0")
  // Normal insert in front of the slice: ket and bra both shift.
  let e2 = @runtime.Env::new("abc")
  e2.bra = 1
  e2.ket = 2
  @runtime.insert(e2, 1, 1, "Z")
  inspect(e2.current, content="aZbc")
  inspect(e2.limit, content="4")
  inspect(e2.bra, content="2")
  inspect(e2.ket, content="3")
  inspect(e2.cursor, content="0")
  // c_bra <= ket but c_bra > bra: ket shifts, bra does not.
  let e3 = @runtime.Env::new("abcd")
  e3.bra = 1
  e3.ket = 3
  @runtime.insert(e3, 2, 2, "XY")
  inspect(e3.current, content="abXYcd")
  inspect(e3.limit, content="6")
  inspect(e3.bra, content="1")
  inspect(e3.ket, content="5")
  inspect(e3.cursor, content="0")
}

///|
/// slice_from / slice_del / slice_to / assign_to (rt.c:546-613). Every slice
/// used here is valid (`0 <= bra <= ket <= limit <= len(current)`).
test "slice edits keep ket, limit and cursor consistent" {
  // slice_from assigns ket = bra + s_size directly (snowball_runtime.c:549).
  let e = @runtime.Env::new("abcdef")
  e.cursor = 5
  e.bra = 1
  e.ket = 3
  @runtime.slice_from(e, "XYZW")
  inspect(e.current, content="aXYZWdef")
  inspect(e.limit, content="8")
  inspect(e.cursor, content="7")
  inspect(e.bra, content="1")
  inspect(e.ket, content="5")
  // Replacing by the empty string removes the slice.
  let e2 = @runtime.Env::new("abcdef")
  e2.bra = 2
  e2.ket = 5
  @runtime.slice_from(e2, "")
  inspect(e2.current, content="abf")
  inspect(e2.limit, content="3")
  inspect(e2.ket, content="2")
  // slice_del fast path: cursor after the slice moves back by slice_size.
  let e3 = @runtime.Env::new("abcdef")
  e3.cursor = 5
  e3.bra = 1
  e3.ket = 3
  @runtime.slice_del(e3)
  inspect(e3.current, content="adef")
  inspect(e3.limit, content="4")
  inspect(e3.cursor, content="3")
  inspect(e3.ket, content="1")
  // Cursor inside the deleted slice snaps to bra.
  let e4 = @runtime.Env::new("abcdef")
  e4.cursor = 2
  e4.bra = 1
  e4.ket = 4
  @runtime.slice_del(e4)
  inspect(e4.current, content="aef")
  inspect(e4.limit, content="3")
  inspect(e4.cursor, content="1")
  inspect(e4.ket, content="1")
  // An empty slice leaves the state untouched (slice_size == 0).
  let e5 = @runtime.Env::new("abc")
  e5.cursor = 1
  e5.bra = 1
  e5.ket = 1
  @runtime.slice_del(e5)
  inspect(e5.current, content="abc")
  inspect(e5.limit, content="3")
  inspect(e5.cursor, content="1")
  // slice_to reads [bra, ket) and mutates nothing.
  let e6 = @runtime.Env::new("abcdef")
  e6.cursor = 4
  e6.bra = 1
  e6.ket = 4
  inspect(@runtime.slice_to(e6), content="bcd")
  inspect(e6.current, content="abcdef")
  inspect(e6.cursor, content="4")
  inspect(e6.bra, content="1")
  inspect(e6.ket, content="4")
  // assign_to reads [0, limit) even when bra/ket point elsewhere; neither
  // getter mutates state.
  let e7 = @runtime.Env::new("abcdef")
  e7.cursor = 2
  e7.limit = 4
  e7.limit_backward = 1
  e7.bra = 2
  e7.ket = 3
  inspect(@runtime.assign_to(e7), content="abcd")
  inspect(@runtime.get_current(e7), content="abcdef")
  inspect(e7.limit, content="4")
  inspect(e7.cursor, content="2")
  inspect(e7.limit_backward, content="1")
  inspect(e7.bra, content="2")
  inspect(e7.ket, content="3")
}

///|
/// Among::new: four fields, with cb an Option defaulting to None
/// (among.py:1-13). Callback behaviour is covered in among_test.mbt
/// (basestemmer.py:144-156/200-212).
test "Among::new defaults cb to None" {
  let a = @runtime.Among::new("abc", -1, 7)
  inspect(a.s, content="abc")
  inspect(a.substring_i, content="-1")
  inspect(a.result, content="7")
  let default_is_none = match a.cb {
    None => true
    Some(_) => false
  }
  inspect(default_is_none, content="true")
  let with_cb = @runtime.Among::new(
    "x",
    3,
    4,
    cb=Some(fn(_e : @runtime.Env) -> Bool { true }),
  )
  let cb_is_none = match with_cb.cb {
    None => true
    Some(_) => false
  }
  inspect(cb_is_none, content="false")
}
