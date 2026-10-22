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
// rows carrying the line count of the generated `<lang>/<lang>_gen.mbt`
// (Task 12 adds the 20% drift warning on top of these rows), and finally
//
//     golden: <ok>/<total> mismatch=<sum>
//
// The driver is judged by `scripts/gate.sh`; it never prints `GATE OK` itself.
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
/// The C `exit` primitive: the driver decides its own exit code (0 clean,
/// 1 corpus/comparison failure, 2 usage) instead of relying on an uncaught
/// error's status.  `exit` flushes the C stdio buffers the runtime uses.
extern "c" fn native_exit(code : Int) = "exit"

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
    rows.push(
      { name: e.name, dir: e.golden_dir, compressed: e.compressed, stem },
    )
  }
  // The control row reuses porter's corpus (contract §3.4) and is reported
  // under its own name; its declared `checked` value is porter's, which the
  // gate derives from the registry.
  let p311 = @porter311.Porter311::new()
  rows.push(
    {
      name: "porter311",
      dir: "porter",
      compressed: false,
      stem: word => @porter311.stem_word(p311, word),
    },
  )
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
    p.length() >= 2 && (p[1] == ':')
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
    None => fail("golden: cannot resolve data root: current directory unavailable")
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
fn resolve_arabic_dir(flag : String?, data_root : String) -> (String, String) raise @fs.IOError {
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
fn count_lines(s : String) -> Int {
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
fn run_one(row : Row, voc_path : String, out_path : String) -> Int raise @fs.IOError {
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
          "MISMATCH lang=\{row.name} line=\{checked + 1} voc=\{word} want=\{want.to_owned()} got=\{got}",
        )
      }
    }
    checked += 1
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
fn gen_lines(module_root : String, name : String) -> Int raise @fs.IOError {
  let path = join_path(module_root, name + "/" + name + "_gen.mbt")
  require_file(path, name)
  count_lines(@fs.read_file_to_string(path, encoding="utf8"))
}

///|
/// Parse `--data-root` / `--arabic-dir` (space or `=` form).  Anything else is
/// a usage error (exit 2) — never a silent fallback.
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
/// Boundary segment (FR-09/FR-19): `go_out_grouping(Env("bcda"), "aeiou")`
/// walks b, c, d and stops on the member `a` at cursor 3.
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
/// The whole run.  Returns the process exit code: 0 only when every row
/// exists, every line-count pre-check holds, every row reports zero
/// mismatches and every `lines=` row could be read.
fn run() -> Int raise @fs.IOError {
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
  // the same order as the comparison rows.
  let module_root = cwd()
  for row in rows {
    let lines = gen_lines(module_root, row.name)
    println("lang=\{row.name} lines=\{lines}")
  }

  println("golden: \{ok}/\{rows.length()} mismatch=\{total_mismatch}")
  check_boundary_case()
  if failed != 0 {
    fail(
      "golden: \{failed} language(s) reported mismatches (total mismatch=\{total_mismatch})",
    )
  }
  0
}

///|
/// Exit-code contract: 0 only for a clean run; 1 for a missing corpus file,
/// a voc/output line-count mismatch, a per-line mismatch, or an unknown
/// argument.  The gate treats any non-zero code as a failed run.
fn main {
  let code = run() catch {
    _ => 1
  }
  native_exit(code)
}
