/// Language registry for the eleven shipped stemmer packages.
///
/// Data model is locked by the shared interface contract §3.1: six fields,
/// fixed order, no optional fields.  `charset` is a `String` whose empty value
/// means "no special non-ASCII note" — it is deliberately not an `Option`.
///
/// `lines` values are derived, not estimated:
///   `wc -l .planning/data/sd/<lang>/voc.txt`
///   `gzip -dc .planning/data/sd/arabic/voc.txt.gz | wc -l`
/// They equal the expected `checked` count of the gate's golden run.
///
/// The registry holds the eleven deliverables only; the 3.1.1 control input is
/// a pipeline/gate-only entry and is intentionally absent here.

pub struct LangEntry { name : String; pkg : String; golden_dir : String; lines : Int; compressed : Bool; charset : String }

pub let langs : Array[LangEntry] = [
  {
    name : "arabic",
    pkg : "vicoproplus/moon_snowball/arabic",
    golden_dir : "arabic",
    lines : 9196214,
    compressed : true,
    charset : "阿拉伯字母（U+0600–U+06FF 区段）",
  },
  {
    name : "dutch",
    pkg : "vicoproplus/moon_snowball/dutch",
    golden_dir : "dutch",
    lines : 45670,
    compressed : false,
    charset : "á(U+00E1)、à、ä、é、è、ë、í、ï、ó、ö、ú、ü",
  },
  {
    name : "english",
    pkg : "vicoproplus/moon_snowball/english",
    golden_dir : "english",
    lines : 42649,
    compressed : false,
    charset : "",
  },
  {
    name : "french",
    pkg : "vicoproplus/moon_snowball/french",
    golden_dir : "french",
    lines : 21653,
    compressed : false,
    charset : "é(U+00E9)、è、ê、ç、à、ô、û 等拉丁补充区；语料 NFC、无组合字符",
  },
  {
    name : "german",
    pkg : "vicoproplus/moon_snowball/german",
    golden_dir : "german",
    lines : 35053,
    compressed : false,
    charset : "ä(U+00E4)、ö、ü、ß(U+00DF)；ß 是单码点（非 ss 连写）",
  },
  {
    name : "italian",
    pkg : "vicoproplus/moon_snowball/italian",
    golden_dir : "italian",
    lines : 37426,
    compressed : false,
    charset : "à(U+00E0)、è、é、ì、ò、ù",
  },
  {
    name : "porter",
    pkg : "vicoproplus/moon_snowball/porter",
    golden_dir : "porter",
    lines : 42603,
    compressed : false,
    charset : "",
  },
  {
    name : "portuguese",
    pkg : "vicoproplus/moon_snowball/portuguese",
    golden_dir : "portuguese",
    lines : 32016,
    compressed : false,
    charset : "á、à、â、ã(U+00E3)、ç、é、ê、í、ó、ô、õ、ú",
  },
  {
    name : "russian",
    pkg : "vicoproplus/moon_snowball/russian",
    golden_dir : "russian",
    lines : 49785,
    compressed : false,
    charset : "西里尔 U+0400–U+04FF",
  },
  {
    name : "spanish",
    pkg : "vicoproplus/moon_snowball/spanish",
    golden_dir : "spanish",
    lines : 28378,
    compressed : false,
    charset : "á(U+00E1)、é、í、ó、ú、ñ(U+00F1)",
  },
  {
    name : "turkish",
    pkg : "vicoproplus/moon_snowball/turkish",
    golden_dir : "turkish",
    lines : 96325,
    compressed : false,
    charset : "ı(U+0131)、ş、ğ",
  },
]

/// Look up a language by its upstream stemmer name.
///
/// Returns `None` for any name that is not one of the eleven deliverables.
pub fn lookup(name : String) -> LangEntry? {
  for entry in langs {
    if entry.name == name {
      return Some(entry)
    }
  }
  None
}
