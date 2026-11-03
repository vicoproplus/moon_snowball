///|
/// Language registry for the shipped stemmer packages.
///
/// Data model is locked by the shared interface contract §3.1: six fields,
/// fixed order, no optional fields.  `charset` is a `String` whose empty value
/// means "no special non-ASCII note" — it is deliberately not an `Option`.
///
/// `lines` values are derived, not estimated:
///   `wc -l .planning/data/sd/<lang>/voc.txt`
///   `gzip -dc .planning/data/sd/arabic/voc.txt.gz | wc -l`
/// They equal the expected `checked` count of the gate's golden run.
pub struct LangEntry {
  name : String
  pkg : String
  golden_dir : String
  lines : Int32
  compressed : Bool
  charset : String
}

///|
pub let langs : Array[LangEntry] = [
  {
    name: "arabic",
    pkg: "vicoproplus/moon_snowball/arabic",
    golden_dir: "arabic",
    lines: 9196214,
    compressed: true,
    charset: "阿拉伯字母（U+0600–U+06FF 区段）",
  },
  {
    name: "armenian",
    pkg: "vicoproplus/moon_snowball/armenian",
    golden_dir: "armenian",
    lines: 101780,
    compressed: false,
    charset: "亚美尼亚字母 U+0530–U+058F",
  },
  {
    name: "basque",
    pkg: "vicoproplus/moon_snowball/basque",
    golden_dir: "basque",
    lines: 21386,
    compressed: false,
    charset: "拉丁扩展（á、é、í、ó、ú、ñ、ü）",
  },
  {
    name: "catalan",
    pkg: "vicoproplus/moon_snowball/catalan",
    golden_dir: "catalan",
    lines: 48897,
    compressed: false,
    charset: "拉丁补充（à、ç、é、è、í、ï、ó、ò、ú、ü）",
  },
  {
    name: "czech",
    pkg: "vicoproplus/moon_snowball/czech",
    golden_dir: "czech",
    lines: 58137,
    compressed: false,
    charset: "拉丁扩展（á、č、ď、ě、ň、ř、š、ť、ů、ž 等）",
  },
  {
    name: "danish",
    pkg: "vicoproplus/moon_snowball/danish",
    golden_dir: "danish",
    lines: 23868,
    compressed: false,
    charset: "æ(U+00E6)、ø(U+00F8)、å(U+00E5)",
  },
  {
    name: "dutch",
    pkg: "vicoproplus/moon_snowball/dutch",
    golden_dir: "dutch",
    lines: 45670,
    compressed: false,
    charset: "á(U+00E1)、à、ä、é、è、ë、í、ï、ó、ö、ú、ü",
  },
  {
    name: "dutch_porter",
    pkg: "vicoproplus/moon_snowball/dutch_porter",
    golden_dir: "dutch_porter",
    lines: 45670,
    compressed: false,
    charset: "á(U+00E1)、à、ä、é、è、ë、í、ï、ó、ö、ú、ü",
  },
  {
    name: "english",
    pkg: "vicoproplus/moon_snowball/english",
    golden_dir: "english",
    lines: 42649,
    compressed: false,
    charset: "",
  },
  {
    name: "esperanto",
    pkg: "vicoproplus/moon_snowball/esperanto",
    golden_dir: "esperanto",
    lines: 84456,
    compressed: false,
    charset: "ĉ、ĝ、ĥ、ĵ、ŝ、ŭ",
  },
  {
    name: "estonian",
    pkg: "vicoproplus/moon_snowball/estonian",
    golden_dir: "estonian",
    lines: 57537,
    compressed: false,
    charset: "ä、ö、ü、õ、š、ž",
  },
  {
    name: "finnish",
    pkg: "vicoproplus/moon_snowball/finnish",
    golden_dir: "finnish",
    lines: 84399,
    compressed: false,
    charset: "芬兰语拉丁补充区（ä(U+00E4)、ö(U+00F6) 等）",
  },
  {
    name: "french",
    pkg: "vicoproplus/moon_snowball/french",
    golden_dir: "french",
    lines: 21653,
    compressed: false,
    charset: "é(U+00E9)、è、ê、ç、à、ô、û 等拉丁补充区；语料 NFC、无组合字符",
  },
  {
    name: "german",
    pkg: "vicoproplus/moon_snowball/german",
    golden_dir: "german",
    lines: 35053,
    compressed: false,
    charset: "ä(U+00E4)、ö、ü、ß(U+00DF)；ß 是单码点（非 ss 连写）",
  },
  {
    name: "greek",
    pkg: "vicoproplus/moon_snowball/greek",
    golden_dir: "greek",
    lines: 90727,
    compressed: false,
    charset: "希腊字母 U+0370–U+03FF",
  },
  {
    name: "hindi",
    pkg: "vicoproplus/moon_snowball/hindi",
    golden_dir: "hindi",
    lines: 65118,
    compressed: false,
    charset: "天城文（U+0900–U+097F）",
  },
  {
    name: "hungarian",
    pkg: "vicoproplus/moon_snowball/hungarian",
    golden_dir: "hungarian",
    lines: 29881,
    compressed: false,
    charset: "á、é、í、ó、ö、ő、ú、ü、ű",
  },
  {
    name: "indonesian",
    pkg: "vicoproplus/moon_snowball/indonesian",
    golden_dir: "indonesian",
    lines: 64586,
    compressed: false,
    charset: "",
  },
  {
    name: "irish",
    pkg: "vicoproplus/moon_snowball/irish",
    golden_dir: "irish",
    lines: 186280,
    compressed: false,
    charset: "á、é、í、ó、ú",
  },
  {
    name: "italian",
    pkg: "vicoproplus/moon_snowball/italian",
    golden_dir: "italian",
    lines: 37426,
    compressed: false,
    charset: "à(U+00E0)、è、é、ì、ò、ù",
  },
  {
    name: "lithuanian",
    pkg: "vicoproplus/moon_snowball/lithuanian",
    golden_dir: "lithuanian",
    lines: 86109,
    compressed: false,
    charset: "ą、č、ę、ė、į、š、ų、ū、ž",
  },
  {
    name: "nepali",
    pkg: "vicoproplus/moon_snowball/nepali",
    golden_dir: "nepali",
    lines: 4000,
    compressed: false,
    charset: "天城文 U+0900–U+097F",
  },
  {
    name: "norwegian",
    pkg: "vicoproplus/moon_snowball/norwegian",
    golden_dir: "norwegian",
    lines: 20913,
    compressed: false,
    charset: "æ、ø、å",
  },
  {
    name: "persian",
    pkg: "vicoproplus/moon_snowball/persian",
    golden_dir: "persian",
    lines: 104268,
    compressed: false,
    charset: "阿拉伯-波斯字母 U+0600–U+06FF",
  },
  {
    name: "polish",
    pkg: "vicoproplus/moon_snowball/polish",
    golden_dir: "polish",
    lines: 62576,
    compressed: false,
    charset: "波兰语拉丁扩展（ą、ć、ę、ł、ń、ó、ś、ź、ż）",
  },
  {
    name: "porter",
    pkg: "vicoproplus/moon_snowball/porter",
    golden_dir: "porter",
    lines: 42603,
    compressed: false,
    charset: "",
  },
  {
    name: "portuguese",
    pkg: "vicoproplus/moon_snowball/portuguese",
    golden_dir: "portuguese",
    lines: 32016,
    compressed: false,
    charset: "á、à、â、ã(U+00E3)、ç、é、ê、í、ó、ô、õ、ú",
  },
  {
    name: "romanian",
    pkg: "vicoproplus/moon_snowball/romanian",
    golden_dir: "romanian",
    lines: 87642,
    compressed: false,
    charset: "ă、â、î、ș、ț",
  },
  {
    name: "russian",
    pkg: "vicoproplus/moon_snowball/russian",
    golden_dir: "russian",
    lines: 49785,
    compressed: false,
    charset: "西里尔 U+0400–U+04FF",
  },
  {
    name: "serbian",
    pkg: "vicoproplus/moon_snowball/serbian",
    golden_dir: "serbian",
    lines: 29996,
    compressed: false,
    charset: "西里尔 U+0400–U+04FF",
  },
  {
    name: "sesotho",
    pkg: "vicoproplus/moon_snowball/sesotho",
    golden_dir: "sesotho",
    lines: 9848,
    compressed: false,
    charset: "",
  },
  {
    name: "spanish",
    pkg: "vicoproplus/moon_snowball/spanish",
    golden_dir: "spanish",
    lines: 28378,
    compressed: false,
    charset: "á(U+00E1)、é、í、ó、ú、ñ(U+00F1)",
  },
  {
    name: "swedish",
    pkg: "vicoproplus/moon_snowball/swedish",
    golden_dir: "swedish",
    lines: 30738,
    compressed: false,
    charset: "å、ä、ö",
  },
  {
    name: "tamil",
    pkg: "vicoproplus/moon_snowball/tamil",
    golden_dir: "tamil",
    lines: 443271,
    compressed: false,
    charset: "泰米尔文 U+0B80–U+0BFF",
  },
  {
    name: "turkish",
    pkg: "vicoproplus/moon_snowball/turkish",
    golden_dir: "turkish",
    lines: 96325,
    compressed: false,
    charset: "ı(U+0131)、ş、ğ",
  },
  {
    name: "yiddish",
    pkg: "vicoproplus/moon_snowball/yiddish",
    golden_dir: "yiddish",
    lines: 99996,
    compressed: false,
    charset: "希伯来字母 U+0590–U+05FF",
  },
]

///|
/// Look up a language by its upstream stemmer name.
///
/// Returns `None` for any name that is not one of the shipped deliverables.
pub fn lookup(name : String) -> LangEntry? {
  for entry in langs {
    if entry.name == name {
      return Some(entry)
    }
  }
  None
}
