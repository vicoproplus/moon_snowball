// Black-box boundary set for the porter stemmer (Task 9 / FR-09, FR-19).
//
// The 33 (word, expected) pairs are the prototype's measured set,
// .probe/slice/golden.mbt:70-120 ("porter edge cases"); the trailing
// `golden.mbt:<line>` comment on each pair is that case's source line there.
// Two pairs are additionally pinned to the upstream corpus:
//   sed -n '32220p' .planning/data/sd/porter/voc.txt    -> s
//   sed -n '32220p' .planning/data/sd/porter/output.txt -> (empty line)
//   sed -n '1p'     .planning/data/sd/porter/voc.txt    -> '
//   sed -n '1p'     .planning/data/sd/porter/output.txt -> '
//
// stem_word raises @runtime.Lab (slice assertions); every call below catches
// it explicitly and turns it into a test failure instead of swallowing it.

///|
test "porter edge cases: 33 prototype pairs" {
  let porter = @porter.Porter::new()
  let cases : Array[(String, String)] = [
    ("", ""), // golden.mbt:73; empty input stays empty
    ("s", ""), // golden.mbt:74; corpus voc:32220 -> output:32220 (empty)
    ("ss", "ss"), // golden.mbt:75
    ("'", "'"), // golden.mbt:76; corpus voc:1 -> output:1 (both "'")
    ("y", "y"), // golden.mbt:77
    ("Y", "Y"), // golden.mbt:78
    ("yes", "ye"), // golden.mbt:79
    ("y's", "y'"), // golden.mbt:80
    ("by", "by"), // golden.mbt:81
    ("dying", "dy"), // golden.mbt:82
    ("say", "sai"), // golden.mbt:83
    ("skies", "ski"), // golden.mbt:84
    ("eed", "eed"), // golden.mbt:85
    ("agreed", "agre"), // golden.mbt:86
    ("feed", "feed"), // golden.mbt:87
    ("controll", "control"), // golden.mbt:88
    ("roll", "roll"), // golden.mbt:89
    ("inning", "in"), // golden.mbt:90
    ("happiness", "happi"), // golden.mbt:91
    ("crying", "cry"), // golden.mbt:92
    ("relational", "relat"), // golden.mbt:93
    ("decisiveness", "decis"), // golden.mbt:94
    ("formaliti", "formal"), // golden.mbt:95
    ("sensibiliti", "sensibl"), // golden.mbt:96
    ("triplicate", "triplic"), // golden.mbt:97
    ("electrical", "electr"), // golden.mbt:98
    ("homologous", "homolog"), // golden.mbt:99
    ("bowdlerize", "bowdler"), // golden.mbt:100
    ("cease", "ceas"), // golden.mbt:101
    // Non-ASCII (BMP) Branch-1 words: grouping membership works on UTF-16 code
    // units and none of them is in an among table, so they pass through.
    ("北京", "北京"), // golden.mbt:104
    ("café", "café"), // golden.mbt:105
    ("naïve", "naïv"), // golden.mbt:106
    ("Über", "Über"), // golden.mbt:107
  ]
  for c in cases {
    let (word, want) = c
    let got = @porter.stem_word(porter, word) catch {
      _ => fail("porter: stem_word raised for \"\{word}\"")
    }
    if got != want {
      fail("porter: stem_word(\"\{word}\") = \"\{got}\", want \"\{want}\"")
    }
  }
  inspect(cases.length(), content="33")
}
