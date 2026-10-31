// Golden-file driver for the twelve Snowball stemmers (Task 7 / FR-12..FR-14).
//
// Twelve rows = the eleven registry entries (`lang_registry.mbt`, contract §3)
// plus the porter311 control row (contract §3.4: same corpus as porter, never
// in the registry).  Each row is compared line by line against
// `<corpus>/<lang>/output.txt` and reported as
//
//     lang=<n> checked=<N> mismatch=<M> ms=<t>
//
// with the `lang=` prefix the prototype lacked (SCD-08).  After the twelve
// comparison rows the driver prints twelve
//
//     lang=<n> lines=<M>
//
// rows carrying the line count of the generated `<lang>/<lang>_gen.mbt`.
// Task 12 (FR-20) judges each of those rows against the committed baseline
// below and appends ` WARN line-count drift` when the count moves more than
// 20% away from it, then prints the summary row
//
//     line-count drift: <k>/12
//
// with k the number of warned rows.  A WARN is a warning, never a failure:
// `scripts/gate.sh` judges only the comparison rows.  The driver is judged
// by that gate; it never prints `GATE OK` itself.
//
// Data root precedence (R-2 / contract §4): `--data-root <p>` >
// `SNOWBALL_DATA_ROOT` > module-relative `.planning/data/sd` (resolved against
// the current directory, which is the module root under `moon run`).  The
// resolved root is printed as an absolute path at startup; no absolute path is
// ever hardcoded here.
//
// arabic ships gzipped upstream and MoonBit has no gzip: the driver never
// opens a `.gz`.  Its plain text is the unpacked artifact the pipeline's
// unpack stage writes to `<module root>/build/data/arabic`, so a compressed
// registry entry resolves to
//
//     `--arabic-dir <p>` > `<data root>/arabic` (when it already holds plain
//     `voc.txt` + `output.txt`) > `<cwd>/build/data/arabic`
//
// and the chosen directory plus its source is printed at startup.
//
// Three further observable lines come from the non-latin spec §2.2 (X-1/X-2),
// on top of the `source=flag|data-root|build` precedence token above (which
// keeps meaning "which directory won the arabic race" and is NOT overloaded):
//
//     source=voc.txt.gz          — printed inside the arabic row's segment,
//                                  followed by one `unpacked_preferred ...`
//                                  line naming the directory actually read
//     progress=<n> elapsed=<s>   — every 1,000,000 compared lines (interval
//                                  fixed by ruling R-B), `<s>` in SECONDS
//     total=<s>                  — the run's wall time in seconds, printed
//                                  exactly once, after the boundary segment's
//                                  tally (the last ordinary line; a failure
//                                  abort may follow it)
//
// No line ever claims a sub-sample: every row compares all of its lines
// (U4-D6).
//
// After the twelve comparison rows and the `lines=` block the driver prints the
// boundary segment of the non-latin spec §4.4: the eleven hand-picked non-ASCII
// cases B-01..B-11 over russian / arabic / turkish.  A fixture that feeds this
// segment must hold the full corpus, not a head: russian/voc.txt and
// russian/output.txt need at least 49,675 lines (B-02's anchor) and each of the
// russian, arabic and turkish pairs needs at least 1,000 lines (B-11's head).
// A shorter file aborts loudly instead of turning an anchored case into a pass.
// Each case contributes at least two lines at column 0 — a
// `boundary <id> ...` provenance line (its corpus anchor, or its synthetic
// origin) and then the observation line of spec §3.2:
//
//     case=<输入> got=<输出> ok=<bool>
//
// UNQUOTED for B-01..B-08 and B-10, exactly as §4.4 tabulates them.  B-09 is
// the one case whose declared form quotes the value (`case="" got="" ok=true`),
// because an empty input is unreadable unquoted; that quoting is not a style
// choice and is not extended to any other case.  B-11 keeps §4.4's single
// aggregate `same=true` token: the per-language detail lines report
// `differing=` so the token appears exactly once.  Nothing here preprocesses
// the input (U4-D4: apostrophes reach `stem_word` verbatim) and nothing maps
// U+0131 (U4-D3).

///|
/// One gate row: registry name, corpus directory, whether the corpus is
/// stored compressed upstream, and the stem callback.  The declared
/// `checked` value is not duplicated here: the gate reads it from
/// `lang_registry.mbt`, so there is exactly one source for it.
struct Row {
  name : String
  dir : String
  compressed : Bool
  stem : (String) -> String raise @rt.Lab
}

///|
/// Target-scoped exit primitive from `moonbitlang/x/sys` (native C `exit`,
/// wasm/wasm-gc/js backend implementations).  The driver decides its own exit
/// code (0 clean, 1 corpus/comparison/usage failure) instead of relying on an
/// uncaught error's status.
fn native_exit(code : Int32) -> Unit {
  @sys.exit(code)
}

///|
/// Abort with one stderr line.  The caller (`main`) turns the raised error
/// into exit code 1; the message stays the first stderr line.
fn[T] fail(msg : String) -> T raise @fs.IOError {
  eprintln(msg)
  raise @fs.IOError(msg)
}

///|
/// The twelve rows, in registry order plus the porter311 control row last.
/// Every callback is built once around a single stemmer instance, so the
/// per-word call allocates nothing beyond the word itself.
fn wired_rows() -> Array[Row] raise @fs.IOError {
  let rows : Array[Row] = []
  for e in @registry.langs {
    let stem : (String) -> String raise @rt.Lab = match e.name {
      "arabic" => {
        let p = @arabic.Arabic::new()
        word => @arabic.stem_word(p, word)
      }
      "dutch" => {
        let p = @dutch.Dutch::new()
        word => @dutch.stem_word(p, word)
      }
      "english" => {
        let p = @english.English::new()
        word => @english.stem_word(p, word)
      }
      "french" => {
        let p = @french.French::new()
        word => @french.stem_word(p, word)
      }
      "german" => {
        let p = @german.German::new()
        word => @german.stem_word(p, word)
      }
      "italian" => {
        let p = @italian.Italian::new()
        word => @italian.stem_word(p, word)
      }
      "porter" => {
        let p = @porter.Porter::new()
        word => @porter.stem_word(p, word)
      }
      "portuguese" => {
        let p = @portuguese.Portuguese::new()
        word => @portuguese.stem_word(p, word)
      }
      "russian" => {
        let p = @russian.Russian::new()
        word => @russian.stem_word(p, word)
      }
      "spanish" => {
        let p = @spanish.Spanish::new()
        word => @spanish.stem_word(p, word)
      }
      "turkish" => {
        let p = @turkish.Turkish::new()
        word => @turkish.stem_word(p, word)
      }
      _ => fail("golden: unknown registry entry: \{e.name}")
    }
    rows.push({
      name: e.name,
      dir: e.golden_dir,
      compressed: e.compressed,
      stem,
    })
  }
  // The control row reuses porter's corpus (contract §3.4) and is reported
  // under its own name; its declared `checked` value is porter's, which the
  // gate derives from the registry.
  let p311 = @porter311.Porter311::new()
  rows.push({
    name: "porter311",
    dir: "porter",
    compressed: false,
    stem: word => @porter311.stem_word(p311, word),
  })
  rows
}

///|
/// True for POSIX-rooted paths and Windows drive paths (`C:...`).
fn is_absolute_path(p : String) -> Bool {
  if p.length() == 0 {
    false
  } else if p[0] == '/' || p[0] == '\\' {
    true
  } else {
    p.length() >= 2 && p[1] == ':'
  }
}

///|
/// Join a base directory with a relative fragment using `/` (accepted by the
/// native IO layer on every platform) and collapse trailing separators.
fn join_path(base : String, rel : String) -> String {
  let mut end = base.length()
  while end > 0 && (base[end - 1] == '/' || base[end - 1] == '\\') {
    end -= 1
  }
  let trimmed = if end == base.length() {
    base
  } else {
    base.view(start_offset=0, end_offset=end).to_owned()
  }
  if trimmed.length() == 0 {
    rel
  } else {
    trimmed + "/" + rel
  }
}

///|
/// The current directory as an absolute path, or a hard error: every path the
/// driver prints must be absolute.
fn cwd() -> String raise @fs.IOError {
  match @env.current_dir() {
    Some(d) =>
      if is_absolute_path(d) {
        d
      } else {
        fail("golden: cannot resolve the absolute current directory: \{d}")
      }
    None =>
      fail("golden: cannot resolve data root: current directory unavailable")
  }
}

///|
/// Make `p` absolute: an already-absolute value is kept, anything else is
/// resolved against the current directory.
fn absolute(p : String) -> String raise @fs.IOError {
  if is_absolute_path(p) {
    p
  } else {
    join_path(cwd(), p)
  }
}

///|
/// Data root precedence: `--data-root` > `SNOWBALL_DATA_ROOT` > the
/// module-relative default `.planning/data/sd`.  Returns the absolute path and
/// the winning source (`flag` / `env` / `default`).
fn resolve_data_root(flag : String?) -> (String, String) raise @fs.IOError {
  match flag {
    Some(p) => (absolute(p), "flag")
    None =>
      match @env.get_env_var("SNOWBALL_DATA_ROOT") {
        Some(v) =>
          if v.length() == 0 {
            (absolute(".planning/data/sd"), "default")
          } else {
            (absolute(v), "env")
          }
        None => (absolute(".planning/data/sd"), "default")
      }
  }
}

///|
/// True when a directory already holds the arabic plain-text pair.
fn has_plain_arabic(dir : String) -> Bool {
  @fs.path_exists(join_path(dir, "voc.txt")) &&
  @fs.path_exists(join_path(dir, "output.txt"))
}

///|
/// Where arabic's plain text lives (see the file header): `--arabic-dir` >
/// `<data root>/arabic` when already unpacked > `<cwd>/build/data/arabic`
/// (the artifact the pipeline's unpack stage writes).  The driver never opens
/// the `.gz` files.
fn resolve_arabic_dir(
  flag : String?,
  data_root : String,
) -> (String, String) raise @fs.IOError {
  match flag {
    Some(p) => (absolute(p), "flag")
    None => {
      let in_root = join_path(data_root, "arabic")
      if has_plain_arabic(in_root) {
        (in_root, "data-root")
      } else {
        (absolute("build/data/arabic"), "build")
      }
    }
  }
}

///|
/// The corpus directory of one row: compressed entries (arabic) use the
/// unpacked directory, everything else `<data root>/<dir>`.
fn row_dir(row : Row, data_root : String, arabic_dir : String) -> String {
  if row.compressed {
    arabic_dir
  } else {
    join_path(data_root, row.dir)
  }
}

///|
/// A missing corpus file must abort with the ABSOLUTE path and the literal
/// `missing` as the first stderr line, before any summary is printed.
fn require_file(path : String, lang : String) -> Unit raise @fs.IOError {
  if !@fs.path_exists(path) {
    fail("golden: missing corpus file for \{lang}: \{path}")
  }
  if !@fs.is_file(path) {
    fail("golden: missing regular corpus file for \{lang}: \{path}")
  }
}

///|
/// Number of lines under the driver's own reading rule: every LF starts a new
/// line, and a final line without LF still counts.  Identical to the
/// `split_lines` rule the earlier version used.
fn count_lines(s : String) -> Int32 {
  let n = s.length()
  let mut count = 0
  let mut i = 0
  while i < n {
    if s[i] == '\n' {
      count += 1
    }
    i += 1
  }
  if n > 0 && s[n - 1] != '\n' {
    count += 1
  }
  count
}

///|
/// One row: read both files, assert equal line counts (before the per-line
/// loop), compare every stemmed word with the golden output, show at most five
/// `MISMATCH` detail lines, and print the `lang=... checked=... mismatch=...`
/// row.  Returns the mismatch count.
fn run_one(
  row : Row,
  voc_path : String,
  out_path : String,
) -> Int32 raise @fs.IOError {
  let voc = @fs.read_file_to_string(voc_path, encoding="utf8")
  let exp = @fs.read_file_to_string(out_path, encoding="utf8")
  let voc_n = count_lines(voc)
  let out_n = count_lines(exp)
  if voc_n != out_n {
    println("voc=\{voc_n} output=\{out_n}")
    fail(
      "golden: line count mismatch for \{row.name}: voc=\{voc_n} output=\{out_n} (voc=\{voc_path} output=\{out_path})",
    )
  }
  let t0 = @env.now()
  let mut checked = 0
  let mut mismatch = 0
  let mut shown = 0
  let vn = voc.length()
  let en = exp.length()
  let mut vs = 0
  let mut es = 0
  while vs < vn && es < en {
    let mut ve = vs
    while ve < vn && voc[ve] != '\n' {
      ve += 1
    }
    let mut ee = es
    while ee < en && exp[ee] != '\n' {
      ee += 1
    }
    let word = voc.view(start_offset=vs, end_offset=ve).to_owned()
    let want = exp.view(start_offset=es, end_offset=ee)
    let got = (row.stem)(word) catch { _ => "<lab escaped>" }
    if !(got.view() == want) {
      mismatch += 1
      if shown < 5 {
        shown += 1
        println(
          "MISMATCH lang=\{row.name} line=\{checked + 1} word=\{word} want=\{want.to_owned()} got=\{got}",
        )
      }
    }
    checked += 1
    // Spec §2.2 X-2 / ruling R-B: one progress line every 1,000,000 compared
    // lines, elapsed in SECONDS.  The interval is fixed: never derived from
    // the corpus size, never emitted as a per-row trailing summary.
    if checked % 1000000 == 0 {
      println("progress=\{checked} elapsed=\{(@env.now() - t0) / 1000}")
    }
    vs = ve + 1
    es = ee + 1
  }
  let elapsed = @env.now() - t0
  println(
    "lang=\{row.name} checked=\{checked} mismatch=\{mismatch} ms=\{elapsed}",
  )
  mismatch
}

///|
/// Line count of the generated package source `<name>/<name>_gen.mbt`, as the
/// `lang=<n> lines=<M>` row (Task 12's drift baseline).
fn gen_lines(module_root : String, name : String) -> Int32 raise @fs.IOError {
  let path = join_path(module_root, name + "/" + name + "_gen.mbt")
  require_file(path, name)
  count_lines(@fs.read_file_to_string(path, encoding="utf8"))
}

///|
/// Line-count baselines of the twelve generated packages (Task 12 / FR-20).
///
/// Source: spec F-U2-21, the T5 post-`moon fmt` committed form of each
/// `<lang>/<lang>_gen.mbt` (10,837 lines for the eleven deliverable packages,
/// 11,407 including the porter311 control row).  This is the ONE baseline
/// table; it is in row order (registry order, porter311 last).  The registry's
/// own `lines` field is the CORPUS line count, so it cannot serve here.
fn baseline_rows() -> Array[(String, Int32)] {
  [
    ("arabic", 1063),
    ("dutch", 1572),
    ("english", 885),
    ("french", 1171),
    ("german", 553),
    ("italian", 837),
    ("porter", 538),
    ("portuguese", 730),
    ("russian", 511),
    ("spanish", 768),
    ("turkish", 2209),
    ("porter311", 570),
  ]
}

///|
/// The baseline for one row name.  An unknown name is a driver bug, not a
/// silently accepted row: fail instead of guessing a baseline.
fn baseline_of(name : String) -> Int32 raise @fs.IOError {
  for entry in baseline_rows() {
    if entry.0 == name {
      return entry.1
    }
  }
  fail("golden: no line-count baseline for \{name}")
}

///|
/// True when `measured` drifted more than 20% from `baseline`, i.e.
/// `|M - B| / B > 0.20`.  Evaluated as `|M - B| * 5 > B` so the comparison is
/// exact and a move of exactly 20% does not warn.
fn line_count_drifted(measured : Int32, baseline : Int32) -> Bool {
  let diff = if measured >= baseline {
    measured - baseline
  } else {
    baseline - measured
  }
  diff * 5 > baseline
}

///|
/// Parse `--data-root` / `--arabic-dir` (space or `=` form).  Anything else is
/// a usage error: the parse raises and `main` maps it to exit 1 (driver exit
/// contract is 0/1; the gate's usage exit 2 belongs to `scripts/gate.sh`).
/// Never a silent fallback.
fn parse_args(args : Array[String]) -> (String?, String?) raise @fs.IOError {
  let mut data_root : String? = None
  let mut arabic_dir : String? = None
  let mut i = 0
  let n = args.length()
  while i < n {
    let a = args[i]
    if a == "--data-root" {
      if i + 1 >= n {
        fail("golden: --data-root needs a value")
      }
      data_root = Some(args[i + 1])
      i += 2
    } else if a.length() > 12 &&
      a.view(start_offset=0, end_offset=12).to_owned() == "--data-root=" {
      data_root = Some(a.view(start_offset=12).to_owned())
      i += 1
    } else if a == "--arabic-dir" {
      if i + 1 >= n {
        fail("golden: --arabic-dir needs a value")
      }
      arabic_dir = Some(args[i + 1])
      i += 2
    } else if a.length() > 13 &&
      a.view(start_offset=0, end_offset=13).to_owned() == "--arabic-dir=" {
      arabic_dir = Some(a.view(start_offset=13).to_owned())
      i += 1
    } else {
      fail("golden: unknown argument: \{a}")
    }
  }
  (data_root, arabic_dir)
}

///|
/// Print one boundary line (`case="<word>" got="<stem>" ok=<bool>`) and stop
/// the run when the case fails: exactly one `ok=` token per line (FR-09); the
/// golden gate counts `ok=true`/`ok=false` lines.
fn report_word_case(
  word : String,
  got : String,
  ok : Bool,
) -> Unit raise @fs.IOError {
  println("case=\"\{word}\" got=\"\{got}\" ok=\{ok}")
  if !ok {
    fail("golden: boundary case failed: case=\"\{word}\" got=\"\{got}\"")
  }
}

///|
/// Boundary segment (FR-09/FR-19): the primitive `go_out_grouping` case, then
/// word-level cases for porter and english.  The four empty/single-character
/// inputs are the brief's assertion set; porter also pins the two non-ASCII
/// prototype values and runs an `Aargauer` determinism probe plus a non-BMP
/// emoji probe ([LOCAL_DEAD_LINK] DL-3).  A failed case aborts the run: the
/// primitive case uses `abort`, the word cases raise, and `main` maps either
/// to exit 1.
fn check_boundary_case() -> Unit raise @fs.IOError {
  // Primitive case (unchanged): go_out_grouping(Env("bcda"), "aeiou") walks
  // b, c, d and stops on the member `a` at cursor 3.
  let env = @rt.Env::new("bcda")
  let result = @rt.go_out_grouping(env, "aeiou")
  let cursor = env.cursor
  let ok = result && cursor == 3
  println(
    "case=go_out_grouping(Env(\"bcda\"),\"aeiou\") got=\{result} ok=\{ok} cursor=\{cursor}",
  )
  if !ok {
    abort(
      "boundary case failed: go_out_grouping(Env(\"bcda\"),\"aeiou\") expected true with cursor=3",
    )
  }
  let porter = @porter.Porter::new()
  let english = @english.English::new()
  // Porter word cases.  `s` -> "" and `'` -> `'` are also the corpus lines
  // `sed -n '32220p'` and `sed -n '1p'` of
  // .planning/data/sd/porter/{voc,output}.txt.
  let porter_cases : Array[(String, String)] = [
    ("", ""),
    ("s", ""),
    ("'", "'"),
    ("y", "y"),
    // Non-ASCII (BMP) words from the prototype set: no among-table membership,
    // so they pass through untouched (.probe/slice/golden.mbt:104-105).
    ("café", "café"),
    ("北京", "北京"),
  ]
  for c in porter_cases {
    let (word, want) = c
    let got = @porter.stem_word(porter, word) catch {
      _ => fail("golden: porter boundary case raised: case=\"\{word}\"")
    }
    report_word_case(word, got, got == want)
  }
  // English word cases.  The brief's generic set says `s` -> ""; the english
  // (Porter2) stemmer keeps a lone `s` -- corpus line 32260 has voc `s` and
  // output `s`, and the english golden row compares 42649 lines at
  // mismatch=0 -- so the observed value `s` is pinned (reported as a concern).
  let english_cases : Array[(String, String)] = [
    ("", ""),
    ("s", "s"),
    ("'", "'"),
    ("y", "y"),
  ]
  for c in english_cases {
    let (word, want) = c
    let got = @english.stem_word(english, word) catch {
      _ => fail("golden: english boundary case raised: case=\"\{word}\"")
    }
    report_word_case(word, got, got == want)
  }
  // `Aargauer` has no exact prototype expectation: the assertion is only
  // "returns without raising, and deterministically".
  let aargauer_first = @porter.stem_word(porter, "Aargauer") catch {
    _ => fail("golden: porter boundary case raised: case=\"Aargauer\"")
  }
  let aargauer_second = @porter.stem_word(porter, "Aargauer") catch {
    _ => fail("golden: porter boundary case raised: case=\"Aargauer\"")
  }
  report_word_case(
    "Aargauer",
    aargauer_first,
    aargauer_first == aargauer_second,
  )
  // [LOCAL_DEAD_LINK] DL-3: the upstream non-BMP fixture is not available in
  // this tree, so this local probe judges only "returns without raising and
  // deterministically".  A returned MoonBit String is well-formed by
  // construction.
  let emoji = "😀"
  let emoji_first = @porter.stem_word(porter, emoji) catch {
    _ => fail("golden: porter boundary case raised: non-BMP emoji probe")
  }
  let emoji_second = @porter.stem_word(porter, emoji) catch {
    _ => fail("golden: porter boundary case raised: non-BMP emoji probe")
  }
  report_word_case(emoji, emoji_first, emoji_first == emoji_second)
}

// ---------------------------------------------------------------------------
// U3 Latin boundary segment (spec §4.4, B-01..B-21) — appended by Task 5.
//
// Append-only: the twelve comparison rows, `check_boundary_case`, the row
// format and the gate summary above are untouched.  Every line this segment
// prints has the spec §3.2 shape
//
//     case=<input> got=<output> ok=<bool>
//
// except B-21, which reports lengths (`case=<len=10000> got=<len=N> ok=<bool>`)
// because a 10,000-character result does not belong in a transcript.  `got=` is
// always the stemmer's live output and `ok=` is always COMPUTED from it:
// equality with the spec §4.4 expectation for B-01..B-18, and "returned
// without raising, with a well-formed result" for B-19..B-21.  A failed
// observation prints `ok=false` and makes the driver exit non-zero.
// ---------------------------------------------------------------------------

///|
/// The `got=` text when `stem_word` raises `@rt.Lab`: a raised error is an
/// observation like any other (B-19..B-21 require "no raise"), never a reason
/// to abandon the transcript.  Same sentinel `run_one` uses.
let lab_escaped : String = "<lab escaped>"

///|
/// True when `s` is a well-formed sequence of UTF-16 code units, i.e. exactly
/// the strings whose UTF-8 encoding is valid (no unpaired surrogate).  A
/// MoonBit `String` is a UTF-16 code-unit sequence, so this is the "valid
/// UTF-8" test the B-19..B-21 rows need, without adding an import here.
fn is_well_formed_string(s : String) -> Bool {
  let n = s.length()
  let mut i = 0
  while i < n {
    let unit = s[i].to_int()
    if unit >= 0xD800 && unit <= 0xDBFF {
      // A leading surrogate must be followed by a trailing one.
      if i + 1 >= n {
        return false
      }
      let trail = s[i + 1].to_int()
      if trail < 0xDC00 || trail > 0xDFFF {
        return false
      }
      i += 2
    } else if unit >= 0xDC00 && unit <= 0xDFFF {
      // A trailing surrogate with no leading one in front of it.
      return false
    } else {
      i += 1
    }
  }
  true
}

///|
/// The six U3 Latin stemmers wired as plain `String -> String` callbacks, each
/// around its OWN instance: the boundary segment never shares state with the
/// twelve comparison rows (`wired_rows` owns those instances).
fn latin_boundary_stems() -> Array[(String, (String) -> String raise @rt.Lab)] {
  let fr = @french.French::new()
  let de = @german.German::new()
  let es = @spanish.Spanish::new()
  let it = @italian.Italian::new()
  let pt = @portuguese.Portuguese::new()
  let nl = @dutch.Dutch::new()
  [
    ("french", word => @french.stem_word(fr, word)),
    ("german", word => @german.stem_word(de, word)),
    ("spanish", word => @spanish.stem_word(es, word)),
    ("italian", word => @italian.stem_word(it, word)),
    ("portuguese", word => @portuguese.stem_word(pt, word)),
    ("dutch", word => @dutch.stem_word(nl, word)),
  ]
}

///|
/// Stem one boundary word, turning a `Lab` escape into `lab_escaped` so the
/// observation is reported (with `ok=false`) instead of aborting the segment.
fn boundary_stem(
  stem : (String) -> String raise @rt.Lab,
  word : String,
) -> String {
  stem(word) catch {
    _ => lab_escaped
  }
}

///|
/// Stem `word` with the partner registered under `lang`; an unknown tag is a
/// driver bug, not a silently skipped row.
fn boundary_stem_of(
  stems : Array[(String, (String) -> String raise @rt.Lab)],
  lang : String,
  word : String,
) -> String raise @fs.IOError {
  for entry in stems {
    if entry.0 == lang {
      return boundary_stem(entry.1, word)
    }
  }
  fail("golden: no boundary stemmer for \{lang}")
}

///|
/// Print one `case=<input> got=<output> ok=<bool>` line (spec §3.2) and return
/// 1 when the observation failed so the caller can count failures.
fn report_boundary(input : String, got : String, ok : Bool) -> Int32 {
  println("case=\{input} got=\{got} ok=\{ok}")
  if ok {
    0
  } else {
    1
  }
}

///|
/// The spec §4.4 table for B-01..B-16 as `(language, input, expected)`, in
/// table order.  The expected values are the spec's; every `got=` printed is
/// the stemmer's live output compared against them.
fn latin_expected_cases() -> Array[(String, String, String)] {
  [
    ("french", "abaisse", "abaiss"),
    ("french", "abaissait", "abaiss"),
    ("french", "abaissé", "abaiss"),
    ("german", "aargauer", "aargau"),
    ("german", "aashöllen", "aasholl"),
    ("german", "abenddämmerung", "abenddammer"),
    ("spanish", "aarón", "aaron"),
    ("spanish", "abandonó", "abandon"),
    ("spanish", "abarcará", "abarc"),
    ("italian", "abbandonerà", "abbandon"),
    ("italian", "abbandonò", "abbandon"),
    ("portuguese", "á", "á"),
    ("portuguese", "ã", "ã"),
    ("portuguese", "aacho", "aach"),
    ("dutch", "á", "á"),
    ("dutch", "áan", "áan"),
  ]
}

///|
/// B-01..B-16: one `case=<input> got=<output> ok=<bool>` line per corpus-
/// anchored expectation of spec §4.4.  Returns the number of failed rows.
fn check_latin_spec_cases(
  stems : Array[(String, (String) -> String raise @rt.Lab)],
) -> Int32 raise @fs.IOError {
  let mut failures = 0
  for entry in latin_expected_cases() {
    let (lang, input, expected) = entry
    let got = boundary_stem_of(stems, lang, input)
    failures += report_boundary(input, got, got == expected)
  }
  failures
}

///|
/// B-21's input: `n` characters assembled from repeated Porter-style suffixes
/// (`ationalizationement`), pure ASCII so the length is exactly `n` code units.
fn repeated_suffix_input(n : Int32) -> String {
  let pattern = "ationalizationement"
  let mut out = ""
  while out.length() + pattern.length() <= n {
    out = out + pattern
  }
  let rem = n - out.length()
  if rem > 0 {
    out = out + pattern.view(start_offset=0, end_offset=rem).to_owned()
  }
  out
}

///|
/// B-17..B-21, each run once per language (`六语言` of spec §4.4): the empty
/// string, the pure punctuation `-`, two uppercase inputs (out of scope but
/// deterministic, non-panicking and well-formed, U3-D3) and a 10,000-character
/// repeated-suffix input.  Returns the number of failed observations.
fn check_latin_universal_cases(
  stems : Array[(String, (String) -> String raise @rt.Lab)],
) -> Int32 {
  let mut failures = 0
  for entry in stems {
    let stem = entry.1
    // B-17: empty string -> empty string (U3-D4).  The empty input and its
    // empty output are printed quoted (`case="" got=""`, spec §4.4 B-17) so
    // the label cannot be mistaken for a truncated line.
    let empty = boundary_stem(stem, "")
    failures += report_boundary("\"\"", "\"" + empty + "\"", empty == "")
    // B-18: a lone hyphen is all punctuation -> unchanged (U3-D4).
    let dash = boundary_stem(stem, "-")
    failures += report_boundary("-", dash, dash == "-")
    // B-19 / B-20: uppercase input is not in the guaranteed range, so only
    // "no panic, no raise, deterministic, well-formed" is asserted.
    let upper_a = boundary_stem(stem, "Aargauer")
    let upper_a_again = boundary_stem(stem, "Aargauer")
    failures += report_boundary(
      "Aargauer",
      upper_a,
      upper_a != lab_escaped &&
      is_well_formed_string(upper_a) &&
      upper_a == upper_a_again,
    )
    let upper_s = boundary_stem(stem, "Strasse")
    let upper_s_again = boundary_stem(stem, "Strasse")
    failures += report_boundary(
      "Strasse",
      upper_s,
      upper_s != lab_escaped &&
      is_well_formed_string(upper_s) &&
      upper_s == upper_s_again,
    )
  }
  // B-21: a 10,000-character repeated-suffix input must come back as a string
  // for every language; only the lengths are reported.
  let long = repeated_suffix_input(10000)
  for entry in stems {
    let got = boundary_stem(entry.1, long)
    let ok = got != lab_escaped && is_well_formed_string(got)
    println("case=<len=\{long.length()}> got=<len=\{got.length()}> ok=\{ok}")
    if !ok {
      failures += 1
    }
  }
  failures
}

///|
/// FR-17 / F-U3-09 same-instance reuse: stem the first 500 `dutch/voc.txt`
/// lines with ONE `Dutch` instance, then stem each line again with a fresh
/// instance, and require the two transcripts to agree line by line.  Dutch is
/// the only package with mutable region fields (`i_p1`/`i_p2`), so it is the
/// one that can leak state from one call into the next.  Prints exactly one
/// `same=<bool>` line and returns 1 on divergence.
///
/// `same=true` means all three of: 500 lines were compared, EVERY pair agreed,
/// and neither side of any pair hit the `lab_escaped` sentinel.  A raise is a
/// failed observation, not agreement: mapping both sides to the same sentinel
/// would otherwise let an all-raise regression read as `same=true`.
fn check_dutch_instance_reuse(data_root : String) -> Int32 raise @fs.IOError {
  let path = join_path(join_path(data_root, "dutch"), "voc.txt")
  require_file(path, "dutch")
  let text = @fs.read_file_to_string(path, encoding="utf8")
  let shared = @dutch.Dutch::new()
  let n = text.length()
  let mut start = 0
  let mut lines = 0
  let mut diverged = 0
  let mut first_bad = ""
  while start < n && lines < 500 {
    let mut end = start
    while end < n && text[end] != '\n' {
      end += 1
    }
    let word = text.view(start_offset=start, end_offset=end).to_owned()
    let reused = @dutch.stem_word(shared, word) catch { _ => lab_escaped }
    let fresh = @dutch.stem_word(@dutch.Dutch::new(), word) catch {
      _ => lab_escaped
    }
    // A raise on EITHER side is a failed observation, not agreement: both
    // sides collapse to `lab_escaped`, so equality alone would report an
    // all-raise regression as `same=true`.  Such a line is counted (and
    // reported) exactly like a divergence.
    let bad = reused == lab_escaped ||
      fresh == lab_escaped ||
      !(reused == fresh)
    if bad {
      diverged += 1
      if diverged == 1 {
        first_bad = word
      }
    }
    lines += 1
    start = end + 1
  }
  let same = lines == 500 && diverged == 0
  println("case=<dutch-first-500-reuse> same=\{same} ok=\{same}")
  if !same {
    eprintln(
      "boundary: dutch instance reuse diverged at \{first_bad} lines=\{lines} mismatch=\{diverged}",
    )
    1
  } else {
    0
  }
}

///|
/// The Task 5 boundary segment as a whole: B-01..B-21 plus the FR-17 reuse
/// check.  One call from `run()`, right after `check_boundary_case()`.  A
/// failed observation is printed with `ok=false` and then turns into a
/// non-zero exit through `fail`.
fn check_latin_boundaries(data_root : String) -> Unit raise @fs.IOError {
  let stems = latin_boundary_stems()
  let mut failures = 0
  failures += check_latin_spec_cases(stems)
  failures += check_latin_universal_cases(stems)
  failures += check_dutch_instance_reuse(data_root)
  println("boundary: latin failed=\{failures}")
  if failures != 0 {
    fail("boundary: \{failures} Latin boundary observation(s) failed")
  }
}

///|
/// Corpus anchors of the spec §4.4 boundary cases, measured against the corpus
/// with `grep -n` (2026-10-23, `.planning/data/sd/**/voc.txt` + `output.txt`):
///
///     B-01  russian/voc.txt:2      `абиссинию`  ->  russian/output.txt:2
///     B-02  russian/voc.txt:49674  `актёр`      ->  russian/output.txt:49674
///     B-03  arabic/voc.txt:2       `ءامنتم`     ->  arabic/output.txt:2
///     B-04  turkish/voc.txt:2      `a'da`       ->  turkish/output.txt:2
///     B-05  turkish/voc.txt:3      `a'daki`     ->  turkish/output.txt:3
///     B-06  turkish/voc.txt:4      `a'dan`      ->  turkish/output.txt:4
///     B-08  turkish/voc.txt:33     `abalıya`    ->  turkish/output.txt:33
///
/// B-02 is the FIRST line of the russian corpus containing `ё` (U+0451); the
/// corpus sorts `ё` after every other letter, so the first hit sits deep in the
/// file (line 49674 of 49785) and it is a real golden line, not a coinage.
/// B-08 is the first turkish line that is actually SHORTENED while keeping its
/// `ı` (U+0131) in `output.txt` (`abalıya` -> `abalı`); the earlier candidate
/// `aarayış` (line 14) keeps the `ı` too but is left untouched, so it would
/// test nothing.  Both expectations are read from `output.txt` at run time;
/// only the line numbers are written down here.
let b02_russian_yo_line : Int = 49674

///|
let b08_turkish_dotless_line : Int = 33

///|
/// B-11's line count (spec §4.4: "同实例前 1000 行 vs 逐行新建").  Every corpus
/// head the segment reads is at least this long, so one read serves both the
/// anchored cases and B-11.
let b11_line_count : Int = 1000

///|
/// One of the three non-latin languages of spec §4.4, wired twice: through ONE
/// shared stemmer instance (`stem`) and through a FRESH instance created per
/// call (`stem_fresh`) — the two paths B-11 compares.  `dir` is the corpus
/// directory the comparison rows used, so the segment reads exactly the bytes
/// the golden loop read (arabic: the decompressed artifact).
struct SpecLang {
  name : String
  dir : String
  stem : (String) -> String raise @rt.Lab
  stem_fresh : (String) -> String raise @rt.Lab
}

///|
/// The three languages of spec §4.4, in the order the table lists them.  Each
/// row is looked up in the SAME registry `wired_rows` walks and its directory
/// comes from `row_dir` (so `golden_dir` and `compressed` decide it), never
/// from a literal language name: a registry edit cannot make the twelve
/// comparison rows and this segment read different directories.  The shared
/// instance is the one the row was wired around, exactly like `wired_rows`
/// builds it; `stem_fresh` is still a brand-new instance per call.
fn spec_langs(data_root : String, arabic_dir : String) -> Array[SpecLang] raise @fs.IOError {
  let rows = wired_rows()
  let out : Array[SpecLang] = []
  for name in ["russian", "arabic", "turkish"] {
    let mut picked : Row? = None
    for row in rows {
      if row.name == name {
        picked = Some(row)
      }
    }
    match picked {
      Some(row) => {
        let fresh : (String) -> String raise @rt.Lab = match name {
          "russian" => w => @russian.stem_word(@russian.Russian::new(), w)
          "arabic" => w => @arabic.stem_word(@arabic.Arabic::new(), w)
          "turkish" => w => @turkish.stem_word(@turkish.Turkish::new(), w)
          _ => row.stem
        }
        out.push(
          {
            name: row.name,
            dir: row_dir(row, data_root, arabic_dir),
            stem: row.stem,
            stem_fresh: fresh,
          },
        )
      }
      None => fail("golden: registry is missing the spec §4.4 language: \{name}")
    }
  }
  out
}

///|
/// `stem_word` under the driver's own escape rule, identical to `run_one`: an
/// escaped lab is a printable, comparable value, never an abort — a boundary
/// case must be able to report it instead of killing the run.
fn stem_caught(
  stem : (String) -> String raise @rt.Lab,
  word : String,
) -> String {
  stem(word) catch {
    _ => "<lab escaped>"
  }
}

///|
/// The first `n` lines of `path`, under the same reading rule as `count_lines`
/// (every LF starts a line, a final line without LF still counts).  `x/fs` has
/// no partial read, so the file is read once and only `n` lines are kept.
fn head_lines(path : String, n : Int) -> Array[String] raise @fs.IOError {
  let s = @fs.read_file_to_string(path, encoding="utf8")
  let out : Array[String] = []
  let len = s.length()
  let mut start = 0
  let mut i = 0
  while i < len && out.length() < n {
    if s[i] == '\n' {
      out.push(s.view(start_offset=start, end_offset=i).to_owned())
      start = i + 1
    }
    i += 1
  }
  if out.length() < n && start < len {
    out.push(s.view(start_offset=start).to_owned())
  }
  out
}

///|
/// Corpus line `n` (1-based) of an already-read head.  A missing line is a hard
/// error: a truncated data root must never turn an anchored case into a pass.
fn corpus_line(
  lines : Array[String],
  n : Int,
  file : String,
) -> String raise @fs.IOError {
  if n > lines.length() {
    fail(
      "golden: boundary segment needs \{file} line \{n}, file has \{lines.length()}",
    )
  }
  lines[n - 1]
}

///|
/// Render a boundary value so an empty string stays visible on a provenance
/// line: `""` for empty, the value verbatim otherwise.
fn render_value(v : String) -> String {
  if v.length() == 0 {
    "\"\""
  } else {
    v
  }
}

///|
/// The two lines of one boundary case: the provenance line, then the
/// observation line `case=<输入> got=<输出> ok=<bool>` built from the label
/// fragments spec §4.4 declares for that row (UNQUOTED for every case except
/// B-09, whose declared form quotes the empty value — see the file header).
/// The provenance line prints `measured` (the value the driver actually
/// obtained) in place of `got_label`, so a red can never show a spec literal
/// that contradicts `ok=false`; only the `case=` line keeps the declared label.
/// Returns the verdict without ever aborting, so GT2-1 gets both a printed
/// `ok=false` and a non-zero exit.
fn emit_case(
  id : String,
  lang : String,
  anchor : String,
  input_label : String,
  got_label : String,
  measured : String,
  ok : Bool,
  extra : String,
) -> Bool {
  println(
    "boundary \{id} lang=\{lang} anchor=\{anchor} input=\{input_label} got=\{measured} ok=\{ok}\{extra}",
  )
  println("case=\{input_label} got=\{got_label} ok=\{ok}")
  ok
}

///|
/// One corpus-anchored case (B-01..B-06, B-08): the word comes from voc line
/// `n` and the expectation from the SAME line of `output.txt`, both read live;
/// the word goes to `stem_word` verbatim (U4-D4 — no apostrophe preprocessing
/// anywhere in the driver).
///
/// The expectation stays corpus-driven, but WHICH word is being tested is
/// pinned: `expect_word` asserts spec §4.4's literal input, `require_char`
/// asserts the character a case is named after (B-02's `ё`, B-08's `ı`), and
/// `require_shortened` asserts B-08 really is a shortened golden line.  A
/// consistently re-sorted corpus therefore fails loudly here instead of
/// passing twelve rows while the `case=` line silently names another word.
fn anchored_case(
  id : String,
  lang : SpecLang,
  voc : Array[String],
  out : Array[String],
  n : Int,
  expect_word? : String,
  require_char? : (Char, String),
  require_shortened? : Bool = false,
) -> Bool raise @fs.IOError {
  let word = corpus_line(voc, n, "\{lang.name}/voc.txt")
  let want = corpus_line(out, n, "\{lang.name}/output.txt")
  match expect_word {
    Some(w) =>
      if word != w {
        fail(
          "golden: boundary \{id} input identity changed: expected \{w}, \{lang.name}/voc.txt:\{n} holds \{word}",
        )
      }
    None => ()
  }
  match require_char {
    Some((c, label)) =>
      if !word.contains_char(c) {
        fail("golden: boundary \{id} input lacks \{label}: \{word}")
      }
    None => ()
  }
  let got = stem_caught(lang.stem, word)
  if require_shortened && got == word {
    fail("golden: boundary \{id} input was not shortened (got == input): \{word}")
  }
  emit_case(
    id,
    lang.name,
    "voc.txt:\{n} output.txt:\{n}",
    word,
    got,
    got,
    got == want,
    " golden=\{want}",
  )
}

///|
/// Task 5's boundary segment: the eleven cases B-01..B-11 of spec §4.4 over
/// russian / arabic / turkish.  Prints the `boundary cases=<attempted>
/// failed=<n>` tally (the count is derived from the cases actually attempted)
/// and returns the number that did not match; `run` turns a non-zero count
/// into exit code 1.
fn run_spec_boundary_cases(
  data_root : String,
  arabic_dir : String,
) -> Int raise @fs.IOError {
  let langs = spec_langs(data_root, arabic_dir)
  let ru = langs[0]
  let ar = langs[1]
  let tr = langs[2]

  // Corpus heads: B-11's first lines plus every anchored line number.
  let ru_voc = head_lines(join_path(ru.dir, "voc.txt"), b02_russian_yo_line)
  let ru_out = head_lines(join_path(ru.dir, "output.txt"), b02_russian_yo_line)
  let ar_voc = head_lines(join_path(ar.dir, "voc.txt"), b11_line_count)
  let ar_out = head_lines(join_path(ar.dir, "output.txt"), b11_line_count)
  let tr_voc = head_lines(join_path(tr.dir, "voc.txt"), b11_line_count)
  let tr_out = head_lines(join_path(tr.dir, "output.txt"), b11_line_count)

  let mut failed = 0
  let mut attempted = 0
  attempted += 1
  if !anchored_case("B-01", ru, ru_voc, ru_out, 2, expect_word="абиссинию") {
    failed += 1
  }
  attempted += 1
  if !anchored_case(
      "B-02",
      ru,
      ru_voc,
      ru_out,
      b02_russian_yo_line,
      require_char=('ё', "U+0451 (ё)"),
    ) {
    failed += 1
  }

  // B-03: the spec corrects the PRD's "first line" wording — `ءامنتم` is the
  // SECOND arabic line, while the first is `ءامن` -> `ءام`.  Both pairs are
  // printed side by side AND both inputs are asserted: the off-by-one cannot be
  // silently reintroduced by a re-sorted corpus, because line 1 must still be
  // the spec's `ءامن` and line 2 the spec's `ءامنتم`.
  let ar1_word = corpus_line(ar_voc, 1, "arabic/voc.txt")
  let ar1_want = corpus_line(ar_out, 1, "arabic/output.txt")
  let ar2_word = corpus_line(ar_voc, 2, "arabic/voc.txt")
  let ar2_want = corpus_line(ar_out, 2, "arabic/output.txt")
  if ar1_word != "ءامن" {
    fail(
      "golden: boundary B-03 line 1 is not the spec's first-line word ءامن: \{ar1_word}",
    )
  }
  println(
    "boundary B-03 line1=\{ar1_word}->\{ar1_want} line2=\{ar2_word}->\{ar2_want} anchor=voc.txt:2",
  )
  attempted += 1
  if !anchored_case("B-03", ar, ar_voc, ar_out, 2, expect_word="ءامنتم") {
    failed += 1
  }

  attempted += 1
  if !anchored_case("B-04", tr, tr_voc, tr_out, 2, expect_word="a'da") {
    failed += 1
  }
  attempted += 1
  if !anchored_case("B-05", tr, tr_voc, tr_out, 3, expect_word="a'daki") {
    failed += 1
  }
  attempted += 1
  if !anchored_case("B-06", tr, tr_voc, tr_out, 4, expect_word="a'dan") {
    failed += 1
  }

  // B-07: the single dotless i.  Spec §4.4 has the boundary segment construct
  // this input (its anchor column points at the 29,471 `ı` lines, not at one of
  // them); the expectation is the input itself, so any downgrade to ASCII `i` —
  // the U4-D3 risk this unit exists for — fails the case loudly.  The corpus
  // corroborates that expectation: turkish/voc.txt:93707 is a bare `ı` and
  // turkish/output.txt:93707 is `ı` unchanged.
  let dotless = "ı"
  let b07_got = stem_caught(tr.stem, dotless)
  attempted += 1
  if !emit_case(
      "B-07",
      tr.name,
      "synthetic:spec-U4-§4.4-B-07",
      dotless,
      b07_got,
      b07_got,
      b07_got == dotless,
      " golden=\{dotless}",
    ) {
    failed += 1
  }

  attempted += 1
  if !anchored_case(
      "B-08",
      tr,
      tr_voc,
      tr_out,
      b08_turkish_dotless_line,
      require_char=('ı', "U+0131 (ı)"),
      require_shortened=true,
    ) {
    failed += 1
  }

  // B-09 / B-10: one synthetic word through all three languages.  §4.4 gives
  // the row ONE observation line, so `ok` is the conjunction; the provenance
  // line carries the MEASURED value of every language (never a spec literal
  // that could contradict `ok=false`), while the `case=` line keeps §4.4's
  // declared label form.
  let b09_russian = stem_caught(ru.stem, "")
  let b09_arabic = stem_caught(ar.stem, "")
  let b09_turkish = stem_caught(tr.stem, "")
  let b09_ok = b09_russian == "" && b09_arabic == "" && b09_turkish == ""
  let b09_measured = "russian=\{render_value(b09_russian)} arabic=\{render_value(b09_arabic)} turkish=\{render_value(b09_turkish)}"
  attempted += 1
  if !emit_case(
      "B-09",
      "russian,arabic,turkish",
      "synthetic:spec-U4-§4.4-B-09",
      "\"\"",
      "\"\"",
      b09_measured,
      b09_ok,
      " golden=<empty>",
    ) {
    failed += 1
  }

  let dash = "-"
  let b10_russian = stem_caught(ru.stem, dash)
  let b10_arabic = stem_caught(ar.stem, dash)
  let b10_turkish = stem_caught(tr.stem, dash)
  let b10_ok = b10_russian == dash && b10_arabic == dash && b10_turkish == dash
  let b10_measured = "russian=\{render_value(b10_russian)} arabic=\{render_value(b10_arabic)} turkish=\{render_value(b10_turkish)}"
  attempted += 1
  if !emit_case(
      "B-10",
      "russian,arabic,turkish",
      "synthetic:spec-U4-§4.4-B-10",
      dash,
      dash,
      b10_measured,
      b10_ok,
      " golden=\{dash}",
    ) {
    failed += 1
  }

  // B-11: the first 1000 corpus lines of each language through ONE shared
  // instance versus a FRESH instance per line.  §4.4 declares a single
  // `same=true`, so the three languages fold into one aggregate line; the
  // per-language lines report `differing=` and never reuse that token (the
  // plan counts `grep -c 'same=true'` == 1).
  let heads : Array[Array[String]] = [ru_voc, ar_voc, tr_voc]
  let mut b11_diff = 0
  let mut b11_checked = 0
  for i in 0..<langs.length() {
    let l = langs[i]
    let voc = heads[i]
    if voc.length() < b11_line_count {
      fail(
        "golden: boundary B-11 needs \{b11_line_count} lines of \{l.name}/voc.txt, file has \{voc.length()}",
      )
    }
    let mut diff = 0
    let mut escaped = 0
    for j in 0..<b11_line_count {
      let w = voc[j]
      let shared = stem_caught(l.stem, w)
      let fresh = stem_caught(l.stem_fresh, w)
      let shared_escaped = shared == "<lab escaped>"
      let fresh_escaped = fresh == "<lab escaped>"
      if shared_escaped || fresh_escaped {
        escaped += 1
      }
      // Two paths that BOTH raise render the same `<lab escaped>` and would
      // otherwise count as "same": an escaped lab is a failure, not equality.
      if shared != fresh || shared_escaped || fresh_escaped {
        diff += 1
      }
    }
    b11_diff += diff
    b11_checked += b11_line_count
    println(
      "boundary B-11 lang=\{l.name} lines=\{b11_line_count} differing=\{diff} escaped=\{escaped}",
    )
  }
  let b11_same = b11_diff == 0
  println(
    "boundary=B-11 aggregate lang=russian,arabic,turkish lines=\{b11_checked} differing=\{b11_diff} same=\{b11_same}",
  )
  attempted += 1
  if !b11_same {
    failed += 1
  }
  // Derived, never a hand-typed 11: the count of cases this function actually
  // attempted.  Printed here so `run` can put the timing row after it.
  println("boundary cases=\{attempted} failed=\{failed}")
  failed
}

///|
/// The whole run.  Returns the process exit code: 0 only when every row
/// exists, every line-count pre-check holds, every row reports zero
/// mismatches and every `lines=` row could be read.
fn run() -> Int32 raise @fs.IOError {
  let run_t0 = @env.now()
  let argv = @env.args()
  let args = if argv.length() > 1 {
    argv[1:].to_owned()
  } else {
    ([] : Array[String])
  }
  let (data_root_flag, arabic_flag) = parse_args(args)
  let (data_root, data_src) = resolve_data_root(data_root_flag)
  let (arabic_dir, arabic_src) = resolve_arabic_dir(arabic_flag, data_root)
  println("data_root=\{data_root} source=\{data_src}")
  println("arabic_dir=\{arabic_dir} source=\{arabic_src}")

  if !@fs.path_exists(data_root) {
    fail("golden: data root is missing: \{data_root}")
  }
  if !@fs.is_dir(data_root) {
    fail("golden: data root is not a directory: \{data_root}")
  }

  let rows = wired_rows()
  // Pre-flight every corpus file before the first comparison: a missing file
  // must leave no `mismatch=` row behind.
  for row in rows {
    let dir = row_dir(row, data_root, arabic_dir)
    require_file(join_path(dir, "voc.txt"), row.name)
    require_file(join_path(dir, "output.txt"), row.name)
  }

  let mut failed = 0
  let mut total_mismatch = 0
  let mut ok = 0
  for row in rows {
    let dir = row_dir(row, data_root, arabic_dir)
    // Spec §2.2 X-1: a compressed entry states its gz provenance on its own
    // line, then explains that the DECOMPRESSED artifact is the one being
    // preferred and names the directory actually read.  This is separate from
    // the startup `source=flag|data-root|build` line, which answers a
    // different question (which directory won the precedence race).
    if row.compressed {
      println("source=voc.txt.gz")
      println(
        "unpacked_preferred dir=\{dir} upstream_gz=\{join_path(data_root, row.dir)} reason=the decompressed pair is preferred over the .gz upstream and the driver never opens a .gz",
      )
    }
    let mismatch = run_one(
      row,
      join_path(dir, "voc.txt"),
      join_path(dir, "output.txt"),
    )
    if mismatch != 0 {
      failed += 1
    } else {
      ok += 1
    }
    total_mismatch += mismatch
  }

  // The `lines=` block (Task 12's drift baseline): one row per language, in
  // the same order as the comparison rows, each judged against the committed
  // baseline and marked with ` WARN line-count drift` when it moved >20%.
  let module_root = cwd()
  let mut warned = 0
  for row in rows {
    let lines = gen_lines(module_root, row.name)
    let baseline = baseline_of(row.name)
    if line_count_drifted(lines, baseline) {
      warned += 1
      println("lang=\{row.name} lines=\{lines} WARN line-count drift")
    } else {
      println("lang=\{row.name} lines=\{lines}")
    }
  }
  println("line-count drift: \{warned}/\{rows.length()}")

  println("golden: \{ok}/\{rows.length()} mismatch=\{total_mismatch}")
  check_boundary_case()
  // Task 5 (spec §4.4): the U3 Latin boundary segment, after the U2 boundary
  // case so the U2 transcript line keeps its position.
  check_latin_boundaries(data_root)
  // Non-latin spec §4.4 (Task 5): the eleven boundary cases B-01..B-11.  They
  // run after the summary row and BEFORE the timing row and the abort, so a
  // failing boundary still prints every `case=` line, its tally and the run's
  // total time before the non-zero exit — GT2-1 needs the printed
  // `case=ı got=i ok=false` and the non-zero exit together.
  let spec_failed = run_spec_boundary_cases(data_root, arabic_dir)
  // Spec §2.2 X-2: the run's total wall time in seconds, printed exactly once
  // and at line start.  It now comes AFTER the boundary segment, so the number
  // includes the segment's corpus re-reads instead of undercounting the run.
  println("total=\{(@env.now() - run_t0) / 1000}")
  if spec_failed != 0 || failed != 0 {
    fail(
      "golden: \{failed} language(s) reported mismatches (total mismatch=\{total_mismatch}) and \{spec_failed} boundary case(s) of spec §4.4 did not match",
    )
  }
  0
}

///|
/// Exit-code contract: 0 only for a clean run; 1 for a missing corpus file,
/// a voc/output line-count mismatch, a per-line mismatch, or an unknown
/// argument.  The gate treats any non-zero code as a failed run.
fn main {
  let code = run() catch { _ => 1 }
  native_exit(code)
}
