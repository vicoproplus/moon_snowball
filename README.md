# moon_snowball

MoonBit 版 Snowball 词干算法：11 个交付 stemmer（10 种语言 + Porter），逐词对照上游
`snowball-data` golden 语料验证，合计 **9,627,772** 行、`mismatch=0`。

- 输入只接受 UTF-8 的 `String`，库内不做任何编码转换（KOI8-R / ISO-8859-1 / CP1256 见第 6 节）。
- `String` 按 UTF-16 码元处理；本批语料零非 BMP、NFC、无组合字符，故「码元 == 码点」成立。
- 端到端可运行只在 native 目标实测通过（见第 4 节）。

## 1. 安装与最小示例

模块名必须带作者前缀（裸名会被 registry 拒绝：`registry module name must be in the form of <author>/<module_name>`）：

**`moon add vicoproplus/moon_snowball`**

最小可运行程序（4 行；放进你自己的可执行包，例如 `cmd/main/main.mbt`）：

```moonbit
fn main raise @runtime.Lab {
  let p = @english.English::new()
  println(@english.stem_word(p, "running"))
}
```

同一包的清单 `cmd/main/moon.pkg` 需要 `pkgtype(kind: "executable")` 与两个导入：
`import { "vicoproplus/moon_snowball/english" @english, "vicoproplus/moon_snowball/runtime" @runtime, }`。
`english` 提供 stemmer；`runtime` 只用来写错误类型——`stem_word` 是 `raise @runtime.Lab` 的函数，
所以 `fn main` 必须带 `raise @runtime.Lab`（漏写会报 `Function with error is not allowed in fn main`）。

运行：`moon run --target native cmd/main`。本仓库 `moon.mod` 设了 `preferred_target = "native"`，
在仓库内可直接 `moon run`；在你自己的模块里请显式带 `--target`。

期望输出（`golden:sd/english/output.txt:32214`：第 32214 行输入 `running` → 输出 `run`；native 实测
stdout 即该行、exit 0）：

```text
run
```

> **比对规则**：比较前先去掉行尾的 `\r`，再逐字节比较，不做其他规范化。本机 Windows native 的
> `println` 行尾是 CRLF，`moon run` 的 stdout 是 `run\r\n`（其他平台是 `run\n`）；去掉 `\r` 后与
> `output.txt:32214` 逐字节相同。输入应为小写（大写输入的行为见第 6 节）。

## 2. 语言表

11 个交付 stemmer。名字与 `snowball/libstemmer/modules.txt` 第 1 列逐字一致；行数是
`wc -l <lang>/voc.txt` 的输出（arabic 为 `gzip -dc arabic/voc.txt.gz | wc -l`），等于闸门每次运行的
`checked`；本批实测每行 `mismatch=0`。

| 语言 | 语料行数（`voc.txt`） | 闸门 `checked` | `mismatch` | 需特殊对待的字符（`lang_registry.mbt` 的 `charset`） |
|---|---|---|---|---|
| `arabic` | 9,196,214 | 9,196,214 | 0 | 阿拉伯字母（U+0600–U+06FF 区段） |
| `dutch` | 45,670 | 45,670 | 0 | á、à、ä、é、è、ë、í、ï、ó、ö、ú、ü |
| `english` | 42,649 | 42,649 | 0 | 无（语料纯 ASCII） |
| `french` | 21,653 | 21,653 | 0 | é、è、ê、ç、à、ô、û；语料 NFC、无组合字符 |
| `german` | 35,053 | 35,053 | 0 | ä、ö、ü、ß（ß 是单码点，非 ss 连写） |
| `italian` | 37,426 | 37,426 | 0 | à、è、é、ì、ò、ù |
| `porter` | 42,603 | 42,603 | 0 | 无（语料纯 ASCII） |
| `portuguese` | 32,016 | 32,016 | 0 | á、à、â、ã、ç、é、ê、í、ó、ô、õ、ú |
| `russian` | 49,785 | 49,785 | 0 | 西里尔（U+0400–U+04FF） |
| `spanish` | 28,378 | 28,378 | 0 | á、é、í、ó、ú、ñ |
| `turkish` | 96,325 | 96,325 | 0 | ı（U+0131）、ş、ğ |

`porter311` 是**对照样本**，不是交付 stemmer：它复用 `porter` 的同一份语料（`checked` 同为 42,603），
差异只在实现形态（3.1.1 带 `i_p1`/`i_p2` 实例字段 vs 3.2.0 局部变量），存在目的是在同一条管线里
同时产出两种字段形态、防形态回归。它出现在 12 行闸门里，但不进语言注册表，也不计入 9,627,772。

## 3. 排除的语言

下面 4 个上游语言**不在本批交付内**，原因相同：它们的 Snowball 源码把 routine 作为 among 回调传入
（4 参 `Among(..., __r_foo)`），而生成码里的回调需要捕获 stemmer 实例；模块级 `let` 表的初始化位置
无法闭包捕获该实例（编译器报 `[4021] p is unbound`）。修法是把 among 表从模块级 `let` 改成实例字段
（或在 `new()` 里构造）——属未验证工作，故本批只登记不交付。

| 语言 | 4 参 `Among` 计数 | 状态 | 原因 |
|---|---|---|---|
| `finnish` | 11 | 不交付 | among 回调型：among 表需改为实例字段 |
| `hindi` | 12 | 不交付 | 同上（回调需捕获实例，模块级 `let` 无法捕获） |
| `lovins` | 294 | 不交付 | 同上（上游 `modules.txt` 默认注释掉该行） |
| `polish` | 21 | 不交付 | 同上（回调需捕获实例，模块级 `let` 无法捕获） |

## 4. 平台支持

本机实测（moon 0.1.20261012，Windows 10 19045）：

| 目标 | `moon build` | `moon test` | `moon run` | 结论 |
|---|---|---|---|---|
| native | Yes | Yes | Yes | 端到端可用，CI 与本地验收一律用它 |
| wasm | Yes | No | No | 仅作 build 产物检查：本机 `moonrun` 缺 `GetTempPath2W`（Win11+/Server 2022+ 才有），启动即 0xC0000139 |
| wasm-gc | Yes | No | No | 同上 |
| js | Yes | No with the stock toolchain/node shim | No | 编译可用；运行需要真实 node，本机 node 是坏 shim（把 `node` 换成本地 bun 替身后 `moon test --target js` 通过），所以本机 stock 工具链下这项判 No |
| llvm | No | — | — | 仅 nightly 提供，stable 直接 ICE；`test` / `run` 未尝试 |

表中 `—` 表示该组合**未尝试**，不是失败。llvm 目标只在 nightly 工具链里提供，本机 stable 上编译即
ICE，因此没有尝试它的 `moon test` / `moon run`。

移植建议：CI 与本地验证一律 `--target native`；wasm / wasm-gc 只做 `moon build` 产物检查，
不要依赖 `moon run --target wasm`。

## 5. 语料

Golden 来自上游 `snowball-data`：UTF-8、纯 LF、无 BOM、无 NUL。行数是 `wc -l` 的输出（arabic 为
`gzip -dc | wc -l`），与第 2 节的 `lines` 逐条相等。字节数为本仓库 golden 文件的实测大小。

| 语料（`sd/<name>/`） | 行数 | 分发形态 | `voc.txt` 字节 | `output.txt` 字节 |
|---|---|---|---|---|
| arabic | 9,196,214 | gz | 23,186,643（gz） | 4,213,721（gz） |
| dutch | 45,670 | plain | 505,891 | 441,688 |
| english | 42,649 | plain | 365,849 | 307,066 |
| french | 21,653 | plain | 200,772 | 153,422 |
| german | 35,053 | plain | 370,070 | 306,286 |
| italian | 37,426 | plain | 351,821 | 267,587 |
| porter | 42,603 | plain | 365,375 | 308,128 |
| portuguese | 32,016 | plain | 294,835 | 227,114 |
| russian | 49,785 | plain | 854,337 | 657,357 |
| spanish | 28,378 | plain | 267,628 | 201,670 |
| turkish | 96,325 | plain | 1,074,859 | 802,426 |
| **11 个交付 stemmer 合计** | **9,627,772** | 10 plain + 1 gz | — | — |
| 12 行闸门合计（含 `porter311` 对照） | **9,670,375** | — | — | — |

两处合计的差 = 42,603，即 `porter311` 复用的那份 `porter` 语料。arabic 是唯一以 gz 分发的语料，
解压后 `voc.txt` 155,998,775 B / `output.txt` 94,413,737 B，各 9,196,214 行。

## 6. 能力边界

| 能力项 | 本库行为 | 依据 |
|---|---|---|
| 非 BMP 字符（U+10000 以上，如 emoji） | **未定义** | `String` 是 UTF-16，非 BMP 占 2 个码元，与 Snowball「1 码点 = 1 symbol」不同；本批语料 0 个非 BMP，能力未验证 |
| 组合字符（NFD 形式，如 `e` + U+0301） | **未定义** | 不做 Unicode 归一化，码元原样参与分组与切片；语料全部 NFC、`combining=0` |
| 大写输入 | **未定义** | 「确定行为 + 不 panic + 合法 UTF-8」这条判据的证据只覆盖六个拉丁语系 stemmer（`french`、`german`、`spanish`、`italian`、`portuguese`、`dutch`，另有 `porter` 一个大写确定性探针）；`english` 与非拉丁的 `russian`、`arabic`、`turkish` 没有大写输入用例。不保证与官方输出一致；库内不做 `to_lower`（会破坏与 golden 的等价性） |
| KOI8-R | **不转换** | `modules.txt` 为 russian 登记 `UTF_8,KOI8_R`；本库只接收 UTF-8，不做转码 |
| ISO-8859-1 | **不转换** | `modules.txt` 为 porter / dutch / english / french / german / italian / portuguese / spanish 登记 `ISO_8859_1`；本库只接收 UTF-8，不做转码 |
| CP1256 | **不转换** | arabic 的常用旧编码；上游 Python 包内 0 处 `CP1256` 引用，本库同样不转码 |

表中标「未定义」的三项都属**能力未验证**：本批语料不触发它们，任何一行都不得被当作「已完成」的依据。
需要这些能力时请在上层先做归一化 / 转码，再调用 stemmer。

## 7. License / 许可

This package is dual-licensed: MIT for the hand-written MoonBit implementation and
tooling, and BSD-3-Clause for all upstream Snowball material (including the vendored
generated stemmers under `tools/vendor/`).

- `LICENSE` — MIT License. Covers this repository's hand-written MoonBit code: the
  runtime implementation and its public API, the language registry, hand-written
  bindings and driver code, the hand-written tooling (`tools/translate.py`,
  `tools/check_gate.py`, `tools/d1check.py`, `tools/lang_inputs.py`,
  `tools/audit_paths.py`, `tools/translate_all.py`, `tools/gen_all.sh`,
  `tools/unpack_arabic.sh`), the `scripts/` pipeline, and the tests.
- `LICENSE-SNOWBALL` — BSD-3-Clause. Covers the upstream Snowball algorithm and
  runtime, every stemmer source generated or translated from upstream Snowball
  output (`<lang>/<lang>_gen.mbt`, including `porter311/porter311_gen.mbt`), **and**
  the 11 vendored generated stemmers shipped under `tools/vendor/`
  (`tools/vendor/py32/{arabic,dutch,english,french,german,italian,portuguese,
  russian,spanish,turkish}_stemmer.py` and
  `tools/vendor/snowballstemmer-3.1.1/porter_stemmer.py`). The MoonBit sources
  self-identify as translations of Snowball 3.2.0 output and the vendored Python
  files are headed "Generated from `<lang>.sbl` by Snowball 3.2.0/3.1.1", so all of
  them are derivatives of the upstream project rather than independently authored
  code. `tools/vendor/` is therefore **not** MIT. The file opens with the upstream
  BSD-3-Clause text (29 lines).

`moon.mod` declares `license = "MIT"`. That manifest field is the package-level license
declaration only; it does not change the fact that BSD-3-Clause applies to the
upstream-derived files listed above.

本仓库采用双许可：手写的 MoonBit 实现为 MIT，上游 Snowball 相关内容（算法、运行时，
以及由上游 Snowball 输出生成或翻译的词干算法源码）为 BSD-3-Clause。

- `LICENSE` — MIT 许可，适用于本仓库手写的 MoonBit 实现（运行时与公开 API、语言注册表、
  手写绑定与驱动代码、手写工具脚本 `tools/translate.py`、`tools/check_gate.py`、
  `tools/d1check.py`、`tools/lang_inputs.py`、`tools/audit_paths.py`、
  `tools/translate_all.py`、`tools/gen_all.sh`、`tools/unpack_arabic.sh`，以及
  `scripts/` 流水线与测试）。
- `LICENSE-SNOWBALL` — BSD-3-Clause 许可，适用于上游 Snowball 算法、运行时，由
  上游 Snowball 输出生成或翻译的词干算法源码（`<lang>/<lang>_gen.mbt`，含
  `porter311/porter311_gen.mbt`），以及随包分发的 11 个 vendored 生成式 stemmer
  （`tools/vendor/py32/{arabic,dutch,english,french,german,italian,portuguese,
  russian,spanish,turkish}_stemmer.py` 与
  `tools/vendor/snowballstemmer-3.1.1/porter_stemmer.py`）。MoonBit 源码自述为
  Snowball 3.2.0 输出的翻译件，vendored Python 文件首行为
  「Generated from `<lang>.sbl` by Snowball 3.2.0/3.1.1」，两者都是上游衍生代码，
  并非原创；因此 `tools/vendor/` **不属于** MIT 范围。文件开头为上游
  BSD-3-Clause 全文（29 行）。
- `moon.mod` 中的 `license = "MIT"` 仅为包清单字段，不改变上述 BSD-3-Clause 的适用范围。

## 8. 管线

从语料到 12 行 `mismatch=0` 只有一个入口；CI 调用同一个入口，不复制判定逻辑。

首次运行的前提：`unpack` 阶段发现语料根不完整时会 `git clone` 上游 `snowball-data`（只稀疏检出 12 个
语言目录），所以首次运行需要网络与 `git`；`generate` 阶段在 WSL 里运行上游 Snowball 编译器，非 WSL
主机改用缓存好的 `build/gen/porter_stemmer.py`（vendored 分支），没有该缓存时拒绝继续（exit 6，
`generate=skipped reason=no-wsl using=vendored`）；需要的工具是 `moon`、`gzip`、`python`。

在干净的 clone 里直接跑，**不要**预设 `SNOWBALL_DATA_ROOT`：默认语料根是模块内的
`.planning/data/sd`，它不在仓库里（被 git 忽略），缺什么由 `unpack` 克隆/解压出来：

```sh
sh scripts/pipeline.sh                        # unpack→generate→translate→fmt→check→golden
grep -E '^(lang=[^ ]+ checked=|stage=golden|GATE)' .planning/logs/u2/T2-entry.log
```

已有 `snowball-data` 副本时，可选地让 `SNOWBALL_DATA_ROOT` 指过去（下面是**占位符**，换成你自己的路径）：

```sh
SNOWBALL_DATA_ROOT=/path/to/snowball-data sh scripts/pipeline.sh   # 该路径必须已存在
```

`SNOWBALL_DATA_ROOT` 命名的路径必须已经存在，否则管线在解析阶段就以 exit 4 退出
（`data_root (SNOWBALL_DATA_ROOT) does not exist`）。它的相对值按**调用时的当前目录**解析，而默认根按
**模块根**解析——两者不同，所以默认根不需要（也不应该）用相对值手写。

期望末段（12 行逐行 `mismatch=0`；同一行里 `checked` 必须等于第 2 节的行数）：

```text
lang=porter checked=42603 mismatch=0 ms=233
lang=porter311 checked=42603 mismatch=0 ms=245
...
lang=arabic checked=9196214 mismatch=0 ms=201027
stage=golden rows=12 mismatch=0 elapsed=...
GATE OK
```

`SNOWBALL_DATA_ROOT` 之外，本文引用的 `snowball/libstemmer/modules.txt` 与各处的 `.planning/**` 都是
**开发树**里的证据路径，不随包发布：`.planning/data/sd` 由 `unpack` 物化（克隆 `snowball-data`，
arabic 解压成明文），`.planning/logs/u2/T2-entry.log` 由同一次运行写出。

12 行耗时合计 206,471 ms（其中 arabic 占 201,027 ms）是 SD 语料上**某一次** `golden` 运行的
单次读数，不是发布验收的计时；Task 10 终验在同一台机器上测得 porter 244 ms、arabic 200,939 ms、
12 行合计 206,372 ms。耗时随机器与负载波动，判据只有 `mismatch=0`（12 行）与 `checked` 的相等，
不要拿毫秒数做回归判定。这个数字只覆盖 `golden` 阶段；
「从克隆到 12 行 `mismatch=0` 20 分钟」是预算值，整链（含首次克隆、arabic 解压、generate）由 CI
在干净环境里执行；本机没有整链计量（本机一次空树的 `unpack` 只有这一阶段就用了 656 s，链路慢于 CI）。
