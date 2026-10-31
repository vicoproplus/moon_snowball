// Black-box boundary set for the english stemmer (Task 9 / FR-09, FR-19).
//
// Required coverage: "" / "s" / "'" / "y" plus non-ASCII.  Every expectation
// below was verified against the implementation and, where present, against
// the upstream corpus .planning/data/sd/english/{voc,output}.txt:
//   ""     -> ""      (not in the corpus; observed on a fresh instance)
//   "s"    -> "s"     (corpus voc:32260 -> output:32260).  The brief's generic
//                      "s" -> "" assertion is a porter property: english
//                      (Porter2) only deletes a plural "s" after a vowel, so a
//                      lone "s" is returned unchanged.
//   "'"    -> "'"     (corpus voc:1 -> output:1)
//   "y"    -> "y"     (corpus voc:42455 -> output:42455)
//   "café" / "北京" -> unchanged (not in the corpus; observed)
//
// Provenance for the non-corpus values: cross-checked against the local
// Snowball 3.1.1 Python reference (`.planning/data/py-pkg/snowballstemmer`,
// `EnglishStemmer().stemWord` = Porter2, the same algorithm as this package).
// It returns "" -> "", "s" -> "s", "'" -> "'", "y" -> "y", "café" -> "café",
// "北京" -> "北京", i.e. 6/6 agree with the table above.  Exact command and
// output: `.planning/tmp/u1/final-english-provenance.txt`.
//
// stem_word raises @runtime.Lab; every call catches it explicitly and turns it
// into a test failure instead of swallowing it.

///|
test "english edge cases: empty, single char, apostrophe, non-ASCII" {
  let english = @english.English::new()
  let cases : Array[(String, String)] = [
    ("", ""),
    ("s", "s"),
    ("'", "'"),
    ("y", "y"),
    ("café", "café"),
    ("北京", "北京"),
  ]
  for c in cases {
    let (word, want) = c
    let got = @english.stem_word(english, word) catch {
      _ => fail("english: stem_word raised for \"\{word}\"")
    }
    if got != want {
      fail("english: stem_word(\"\{word}\") = \"\{got}\", want \"\{want}\"")
    }
  }
  inspect(cases.length(), content="6")
}
