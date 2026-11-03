///|
pub enum StemmerKind {
  Arabic(@arabic.Arabic)
  Armenian(@armenian.Armenian)
  Basque(@basque.Basque)
  Catalan(@catalan.Catalan)
  Czech(@czech.Czech)
  Danish(@danish.Danish)
  Dutch(@dutch.Dutch)
  DutchPorter(@dutch_porter.DutchPorter)
  English(@english.English)
  Esperanto(@esperanto.Esperanto)
  Estonian(@estonian.Estonian)
  Finnish(@finnish.Finnish)
  French(@french.French)
  German(@german.German)
  Greek(@greek.Greek)
  Hindi(@hindi.Hindi)
  Hungarian(@hungarian.Hungarian)
  Indonesian(@indonesian.Indonesian)
  Irish(@irish.Irish)
  Italian(@italian.Italian)
  Lithuanian(@lithuanian.Lithuanian)
  Nepali(@nepali.Nepali)
  Norwegian(@norwegian.Norwegian)
  Persian(@persian.Persian)
  Polish(@polish.Polish)
  Porter(@porter.Porter)
  Portuguese(@portuguese.Portuguese)
  Romanian(@romanian.Romanian)
  Russian(@russian.Russian)
  Serbian(@serbian.Serbian)
  Sesotho(@sesotho.Sesotho)
  Spanish(@spanish.Spanish)
  Swedish(@swedish.Swedish)
  Tamil(@tamil.Tamil)
  Turkish(@turkish.Turkish)
  Yiddish(@yiddish.Yiddish)
}

///|
pub struct Stemmer {
  kind : StemmerKind
  mut last : String
}

///|
pub fn list() -> Array[String] {
  [
    "arabic", "armenian", "basque", "catalan", "czech", "danish", "dutch", "dutch_porter",
    "english", "esperanto", "estonian", "finnish", "french", "german", "greek", "hindi",
    "hungarian", "indonesian", "irish", "italian", "lithuanian", "nepali", "norwegian",
    "persian", "polish", "porter", "portuguese", "romanian", "russian", "serbian",
    "sesotho", "spanish", "swedish", "tamil", "turkish", "yiddish",
  ]
}

///|
fn canonical_name(name : String) -> String? {
  match name {
    "arabic" | "ar" | "ara" => Some("arabic")
    "armenian" | "hy" | "hye" | "arm" => Some("armenian")
    "basque" | "eu" | "eus" | "baq" => Some("basque")
    "catalan" | "ca" | "cat" => Some("catalan")
    "czech" | "cs" | "ces" | "cze" => Some("czech")
    "danish" | "da" | "dan" => Some("danish")
    "dutch" | "nl" | "dut" | "nld" | "kraaij_pohlmann" => Some("dutch")
    "dutch_porter" => Some("dutch_porter")
    "english" | "en" | "eng" => Some("english")
    "esperanto" | "eo" | "epo" => Some("esperanto")
    "estonian" | "et" | "est" => Some("estonian")
    "finnish" | "fi" | "fin" => Some("finnish")
    "french" | "fr" | "fre" | "fra" => Some("french")
    "german" | "de" | "ger" | "deu" => Some("german")
    "greek" | "el" | "gre" | "ell" => Some("greek")
    "hindi" | "hi" | "hin" => Some("hindi")
    "hungarian" | "hu" | "hun" => Some("hungarian")
    "indonesian" | "id" | "ind" => Some("indonesian")
    "irish" | "ga" | "gle" => Some("irish")
    "italian" | "it" | "ita" => Some("italian")
    "lithuanian" | "lt" | "lit" => Some("lithuanian")
    "nepali" | "ne" | "nep" => Some("nepali")
    "norwegian" | "no" | "nor" => Some("norwegian")
    "persian" | "fa" | "fas" | "per" => Some("persian")
    "polish" | "pl" | "pol" => Some("polish")
    "porter" => Some("porter")
    "portuguese" | "pt" | "por" => Some("portuguese")
    "romanian" | "ro" | "rum" | "ron" => Some("romanian")
    "russian" | "ru" | "rus" => Some("russian")
    "serbian" | "sr" | "srp" => Some("serbian")
    "sesotho" | "st" | "sot" => Some("sesotho")
    "spanish" | "es" | "esl" | "spa" => Some("spanish")
    "swedish" | "sv" | "swe" => Some("swedish")
    "tamil" | "ta" | "tam" => Some("tamil")
    "turkish" | "tr" | "tur" => Some("turkish")
    "yiddish" | "yi" | "yid" => Some("yiddish")
    _ => None
  }
}

///|
pub fn new(name : String) -> Stemmer? {
  match canonical_name(name) {
    None => None
    Some("arabic") =>
      Some({ kind: StemmerKind::Arabic(@arabic.Arabic::new()), last: "", })
    Some("armenian") =>
      Some({ kind: StemmerKind::Armenian(@armenian.Armenian::new()), last: "", })
    Some("basque") =>
      Some({ kind: StemmerKind::Basque(@basque.Basque::new()), last: "", })
    Some("catalan") =>
      Some({ kind: StemmerKind::Catalan(@catalan.Catalan::new()), last: "", })
    Some("czech") =>
      Some({ kind: StemmerKind::Czech(@czech.Czech::new()), last: "", })
    Some("danish") =>
      Some({ kind: StemmerKind::Danish(@danish.Danish::new()), last: "", })
    Some("dutch") =>
      Some({ kind: StemmerKind::Dutch(@dutch.Dutch::new()), last: "", })
    Some("dutch_porter") =>
      Some({
        kind: StemmerKind::DutchPorter(@dutch_porter.DutchPorter::new()),
        last: "",
      })
    Some("english") =>
      Some({ kind: StemmerKind::English(@english.English::new()), last: "", })
    Some("esperanto") =>
      Some({
        kind: StemmerKind::Esperanto(@esperanto.Esperanto::new()),
        last: "",
      })
    Some("estonian") =>
      Some({ kind: StemmerKind::Estonian(@estonian.Estonian::new()), last: "", })
    Some("finnish") =>
      Some({ kind: StemmerKind::Finnish(@finnish.Finnish::new()), last: "", })
    Some("french") =>
      Some({ kind: StemmerKind::French(@french.French::new()), last: "", })
    Some("german") =>
      Some({ kind: StemmerKind::German(@german.German::new()), last: "", })
    Some("greek") =>
      Some({ kind: StemmerKind::Greek(@greek.Greek::new()), last: "", })
    Some("hindi") =>
      Some({ kind: StemmerKind::Hindi(@hindi.Hindi::new()), last: "", })
    Some("hungarian") =>
      Some({
        kind: StemmerKind::Hungarian(@hungarian.Hungarian::new()),
        last: "",
      })
    Some("indonesian") =>
      Some({
        kind: StemmerKind::Indonesian(@indonesian.Indonesian::new()),
        last: "",
      })
    Some("irish") =>
      Some({ kind: StemmerKind::Irish(@irish.Irish::new()), last: "", })
    Some("italian") =>
      Some({ kind: StemmerKind::Italian(@italian.Italian::new()), last: "", })
    Some("lithuanian") =>
      Some({
        kind: StemmerKind::Lithuanian(@lithuanian.Lithuanian::new()),
        last: "",
      })
    Some("nepali") =>
      Some({ kind: StemmerKind::Nepali(@nepali.Nepali::new()), last: "", })
    Some("norwegian") =>
      Some({
        kind: StemmerKind::Norwegian(@norwegian.Norwegian::new()),
        last: "",
      })
    Some("persian") =>
      Some({ kind: StemmerKind::Persian(@persian.Persian::new()), last: "", })
    Some("polish") =>
      Some({ kind: StemmerKind::Polish(@polish.Polish::new()), last: "", })
    Some("porter") =>
      Some({ kind: StemmerKind::Porter(@porter.Porter::new()), last: "", })
    Some("portuguese") =>
      Some({
        kind: StemmerKind::Portuguese(@portuguese.Portuguese::new()),
        last: "",
      })
    Some("romanian") =>
      Some({ kind: StemmerKind::Romanian(@romanian.Romanian::new()), last: "", })
    Some("russian") =>
      Some({ kind: StemmerKind::Russian(@russian.Russian::new()), last: "", })
    Some("serbian") =>
      Some({ kind: StemmerKind::Serbian(@serbian.Serbian::new()), last: "", })
    Some("sesotho") =>
      Some({ kind: StemmerKind::Sesotho(@sesotho.Sesotho::new()), last: "", })
    Some("spanish") =>
      Some({ kind: StemmerKind::Spanish(@spanish.Spanish::new()), last: "", })
    Some("swedish") =>
      Some({ kind: StemmerKind::Swedish(@swedish.Swedish::new()), last: "", })
    Some("tamil") =>
      Some({ kind: StemmerKind::Tamil(@tamil.Tamil::new()), last: "", })
    Some("turkish") =>
      Some({ kind: StemmerKind::Turkish(@turkish.Turkish::new()), last: "", })
    Some("yiddish") =>
      Some({ kind: StemmerKind::Yiddish(@yiddish.Yiddish::new()), last: "", })
    _ => None
  }
}

///|
pub fn delete(_s : Stemmer) -> Unit {
  ()
}

///|
pub fn stem(s : Stemmer, word : String) -> String raise @rt.Lab {
  let res = match s.kind {
    StemmerKind::Arabic(p) => @arabic.stem_word(p, word)
    StemmerKind::Armenian(p) => @armenian.stem_word(p, word)
    StemmerKind::Basque(p) => @basque.stem_word(p, word)
    StemmerKind::Catalan(p) => @catalan.stem_word(p, word)
    StemmerKind::Czech(p) => @czech.stem_word(p, word)
    StemmerKind::Danish(p) => @danish.stem_word(p, word)
    StemmerKind::Dutch(p) => @dutch.stem_word(p, word)
    StemmerKind::DutchPorter(p) => @dutch_porter.stem_word(p, word)
    StemmerKind::English(p) => @english.stem_word(p, word)
    StemmerKind::Esperanto(p) => @esperanto.stem_word(p, word)
    StemmerKind::Estonian(p) => @estonian.stem_word(p, word)
    StemmerKind::Finnish(p) => @finnish.stem_word(p, word)
    StemmerKind::French(p) => @french.stem_word(p, word)
    StemmerKind::German(p) => @german.stem_word(p, word)
    StemmerKind::Greek(p) => @greek.stem_word(p, word)
    StemmerKind::Hindi(p) => @hindi.stem_word(p, word)
    StemmerKind::Hungarian(p) => @hungarian.stem_word(p, word)
    StemmerKind::Indonesian(p) => @indonesian.stem_word(p, word)
    StemmerKind::Irish(p) => @irish.stem_word(p, word)
    StemmerKind::Italian(p) => @italian.stem_word(p, word)
    StemmerKind::Lithuanian(p) => @lithuanian.stem_word(p, word)
    StemmerKind::Nepali(p) => @nepali.stem_word(p, word)
    StemmerKind::Norwegian(p) => @norwegian.stem_word(p, word)
    StemmerKind::Persian(p) => @persian.stem_word(p, word)
    StemmerKind::Polish(p) => @polish.stem_word(p, word)
    StemmerKind::Porter(p) => @porter.stem_word(p, word)
    StemmerKind::Portuguese(p) => @portuguese.stem_word(p, word)
    StemmerKind::Romanian(p) => @romanian.stem_word(p, word)
    StemmerKind::Russian(p) => @russian.stem_word(p, word)
    StemmerKind::Serbian(p) => @serbian.stem_word(p, word)
    StemmerKind::Sesotho(p) => @sesotho.stem_word(p, word)
    StemmerKind::Spanish(p) => @spanish.stem_word(p, word)
    StemmerKind::Swedish(p) => @swedish.stem_word(p, word)
    StemmerKind::Tamil(p) => @tamil.stem_word(p, word)
    StemmerKind::Turkish(p) => @turkish.stem_word(p, word)
    StemmerKind::Yiddish(p) => @yiddish.stem_word(p, word)
  }
  s.last = res
  res
}

///|
pub fn length(s : Stemmer) -> Int32 {
  s.last.length()
}
