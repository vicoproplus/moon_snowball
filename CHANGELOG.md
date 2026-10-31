# Changelog

本文件记录 moon_snowball 的版本变更，版本倒序排列；每条首行是版本号与日期，
首条版本号与 `moon.mod` 的 `version` 一致。

## 0.1.0 — 2026-10-28

### 新增语言

11 个交付 stemmer（10 种语言 + Porter），每个都是一个独立包
（`vicoproplus/moon_snowball/<lang>`）：

- `arabic`
- `dutch`
- `english`
- `french`
- `german`
- `italian`
- `porter`
- `portuguese`
- `russian`
- `spanish`
- `turkish`

每个 stemmer 都对照上游 `snowball-data` golden 语料逐词验证：11 个交付 stemmer 合计
9,627,772 行，`mismatch=0`。

`porter311` 是 3.1.1 字段形态的对照样本，复用 `porter` 的同一份语料，仅用于在同一条
管线里同时产出两种实现形态、防止形态回归；它不是交付 stemmer，不计入上述 11 个，
也不计入 9,627,772 行。

### 行为变更

首版发布，无破坏性变更。
