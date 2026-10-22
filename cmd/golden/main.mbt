// Golden-file driver for Snowball stemmers (U1-a first version, Task 6).
//
// Spec §2.2 data flow: resolve the corpus root (SNOWBALL_DATA_ROOT, else
// <cwd>/.planning/data/sd), reject missing files, reject voc/output line-count
// mismatches, compare every stemmed word against output.txt, and print one
// summary line per language.
//
// The wired language list is intentionally empty in U1-a: `<module>/porter`
// and `<module>/english` do not exist until U1-b (blocked on the U2 pipeline).
// Task 7 fills `wired_langs` with the porter/english callbacks; the data
// readiness checks below already validate both corpora unconditionally.

///|
/// One wired language: the name used in `lang=` lines plus its stem callback.
/// Only `wired_langs` constructs values of this type (Task 7).
pub struct Lang {
  name : String
  stem : (String) -> String raise @rt.Lab
}

///|
/// Constructor used by `wired_langs` (Task 7 appends the porter/english
/// entries with it).
pub fn Lang::new(
  name : String,
  stem : (String) -> String raise @rt.Lab,
) -> Lang {
  { name, stem }
}

///|
/// Corpora that must be present and line-consistent before any comparison
/// runs (spec §2.2 steps 2-3). Task 7 pairs each name with a callback.
fn required_langs() -> Array[String] {
  ["porter", "english"]
}

///|
/// Languages wired to a stem callback. U1-a ships this empty on purpose:
/// porter/english are U1-b and would otherwise import packages that do not
/// exist yet. Task 7 (U1-b) fills this with the porter/english entries.
fn wired_langs() -> Array[Lang] {
  let langs : Array[Lang] = []
  langs
}

///|
/// Split on LF, dropping the trailing-newline pseudo-line (spec §2.2: read
/// UTF-8, strip the line-end LF). A final line without LF is kept.
fn split_lines(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut start = 0
  let mut i = 0
  let n = s.length()
  while i < n {
    if s[i] == '\n' {
      out.push(s.view(start_offset=start, end_offset=i).to_owned())
      start = i + 1
    }
    i += 1
  }
  if start < n {
    out.push(s.view(start_offset=start).to_owned())
  }
  out
}

///|
/// True for POSIX-rooted paths and Windows drive paths (`C:...`).
fn is_absolute_path(p : String) -> Bool {
  if p.length() == 0 {
    false
  } else if p[0] == '/' || p[0] == '\\' {
    true
  } else {
    p.length() >= 2 && (p[1] == ':')
  }
}

///|
/// Join a base directory with a relative fragment using `/` (accepted by the
/// native IO layer on every platform) and collapse trailing separators so the
/// resolved root prints cleanly.
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
/// Spec §2.2 step 1: SNOWBALL_DATA_ROOT wins; otherwise the module-root
/// relative `.planning/data/sd` resolved against the current directory.
/// No absolute path is ever hardcoded here.
fn resolve_data_root() -> String raise @fs.IOError {
  let fallback = ".planning/data/sd"
  let raw = match @env.get_env_var("SNOWBALL_DATA_ROOT") {
    Some(v) => if v.length() == 0 { fallback } else { v }
    None => fallback
  }
  if is_absolute_path(raw) {
    raw
  } else {
    match @env.current_dir() {
      Some(cwd) => join_path(cwd, raw)
      None => {
        let msg = "golden: cannot resolve data root: current directory unavailable"
        eprintln(msg)
        raise @fs.IOError(msg)
      }
    }
  }
}

///|
/// Spec §2.2 step 3: a missing corpus file must abort before any summary line
/// with the absolute path and the literal `missing` on stderr.
fn require_file(path : String) -> Unit raise @fs.IOError {
  if !@fs.path_exists(path) {
    let msg = "golden: missing corpus file: \{path}"
    eprintln(msg)
    raise @fs.IOError(msg)
  }
  if !@fs.is_file(path) {
    let msg = "golden: missing regular corpus file: \{path}"
    eprintln(msg)
    raise @fs.IOError(msg)
  }
}

///|
/// Read a UTF-8 corpus file and split it into lines. The encoding name is
/// `utf8` (not `utf-8`) for `moonbitlang/x/fs`.
fn file_lines(path : String) -> Array[String] raise @fs.IOError {
  split_lines(@fs.read_file_to_string(path, encoding="utf8"))
}

///|
/// Spec §2.2 steps 2-3 for one language: both files must exist and carry the
/// same number of lines; otherwise print both counts and exit non-zero before
/// the per-line loop starts.
fn validate_lang(root : String, name : String) -> Unit raise @fs.IOError {
  let voc_path = join_path(root, name + "/voc.txt")
  let out_path = join_path(root, name + "/output.txt")
  require_file(voc_path)
  require_file(out_path)
  let voc_n = file_lines(voc_path).length()
  let out_n = file_lines(out_path).length()
  if voc_n != out_n {
    println("voc=\{voc_n} output=\{out_n}")
    let msg = "golden: line count mismatch for \{name}: voc=\{voc_n} output=\{out_n}"
    eprintln(msg)
    raise @fs.IOError(msg)
  }
}

///|
/// Spec §2.2 steps 4-5 for one wired language: compare each word with the
/// golden output, show at most 5 five-field mismatch lines, then print one
/// `lang=<n> checked=<N> mismatch=<M> ms=<t>` summary. Returns the mismatch
/// count so the caller can choose a non-zero exit.
fn run_one(
  lang : Lang,
  voc_path : String,
  out_path : String,
) -> Int raise @fs.IOError {
  let voc = file_lines(voc_path)
  let exp = file_lines(out_path)
  let mut checked = 0
  let mut mismatch = 0
  let mut shown = 0
  let n = if voc.length() < exp.length() {
    voc.length()
  } else {
    exp.length()
  }
  let t0 = @env.now()
  while checked < n {
    let word = voc[checked]
    let stem = lang.stem
    let got = stem(word) catch { _ => "<lab escaped>" }
    if got != exp[checked] {
      mismatch += 1
      if shown < 5 {
        shown += 1
        println(
          "lang=\{lang.name} line=\{checked + 1} word=\{word} want=\{exp[checked]} got=\{got}",
        )
      }
    }
    checked += 1
  }
  let elapsed = @env.now() - t0
  println("lang=\{lang.name} checked=\{checked} mismatch=\{mismatch} ms=\{elapsed}")
  mismatch
}

///|
/// Run every wired language. `langs` is empty in U1-a, so this prints zero
/// `lang=` lines; Task 7 makes it print the porter/english pair. The line-count
/// self-check exists now (0 == 0) and becomes the "exactly 2 lang lines" guard
/// once the list is populated.
fn run_all(langs : Array[Lang], root : String) -> Int raise @fs.IOError {
  let mut failed = 0
  let mut emitted = 0
  for lang in langs {
    let mismatch = run_one(
      lang,
      join_path(root, lang.name + "/voc.txt"),
      join_path(root, lang.name + "/output.txt"),
    )
    emitted += 1
    if mismatch != 0 {
      failed += 1
    }
  }
  if emitted != langs.length() {
    let msg = "golden: expected \{langs.length()} lang lines but emitted \{emitted}"
    eprintln(msg)
    raise @fs.IOError(msg)
  }
  failed
}

///|
/// Boundary segment (FR-09/FR-19). Task 6 carries the runtime-primitive case:
/// `go_out_grouping(Env("bcda"), "aeiou")` walks b, c, d and stops on the
/// member `a` at cursor 3, returning true. The word-boundary cases ("", "s",
/// "'", "y") are deferred to Task 9 (they need a stem callback).
fn check_boundary_case() -> Unit {
  let env = @rt.Env::new("bcda")
  let result = @rt.go_out_grouping(env, "aeiou")
  let cursor = env.cursor
  let ok = result && (cursor == 3)
  println(
    "case=go_out_grouping(Env(\"bcda\"),\"aeiou\") got=\{result} ok=\{ok} cursor=\{cursor}",
  )
  if !ok {
    abort(
      "boundary case failed: go_out_grouping(Env(\"bcda\"),\"aeiou\") expected true with cursor=3",
    )
  }
}

///|
/// Exit-code contract (spec §2.2, §4.5 U1-F1..F3): a missing root or file, a
/// line-count mismatch, a per-line mismatch, or a failed boundary assertion
/// all exit non-zero; only a clean run exits 0.
fn main raise @fs.IOError {
  let root = resolve_data_root()
  println("data_root=\{root}")
  if !@fs.path_exists(root) {
    let msg = "golden: data root is missing: \{root}"
    eprintln(msg)
    raise @fs.IOError(msg)
  }
  if !@fs.is_dir(root) {
    let msg = "golden: data root is not a directory: \{root}"
    eprintln(msg)
    raise @fs.IOError(msg)
  }
  for name in required_langs() {
    validate_lang(root, name)
  }
  let failed = run_all(wired_langs(), root)
  check_boundary_case()
  if failed != 0 {
    let msg = "golden: \{failed} language(s) reported mismatches"
    eprintln(msg)
    raise @fs.IOError(msg)
  }
}
