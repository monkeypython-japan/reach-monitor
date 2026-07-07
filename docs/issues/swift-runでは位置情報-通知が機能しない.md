---
area: personal
category: "reach-monitor"
tags:
  - area/personal
  - issue
  - pitfall
  - packaging
status: resolved
date: 2026-07-01
---

# `swift run` では位置情報・通知が機能しない

- ステータス: 解決済み (resolved)
- 日付: 2026-07-01

## 症状

開発中に `swift run` で直接実行すると、位置情報の許可ダイアログが正しく出なかったり、
到達不能時の通知 (`UNUserNotificationCenter`) が一切発火しない。

## 原因

位置情報・通知どちらの権限も、TCC 上は安定したバンドル識別子（`com.mamoru.reachmonitor`、
`bundle/Info.plist` で設定）とコード署名を持つ `.app` バンドルに対して許可される仕組みに
なっている。`swift run` で生成される実行ファイルは `.app` 構造を持たず、安定したバンドル ID
もコード署名も無いため、これらの権限が正しく機能しない。

## 回避策 / 対処

動作確認・検証は必ず `bundle/make-app.sh` でビルドした `.app` バンドル経由（`open` または
LaunchAgent 経由の起動）で行う。`swift build`/`swift run` はコンパイルエラーの確認用と割り切り、
権限が絡む挙動の検証には使わない。CLAUDE.md にも明記済み。

## 関連

- 関連 ADR: [[0001-swiftpmビルドと手動appパッケージングでad-hoc署名を採用]]
- 関連実装: `bundle/Info.plist`, `bundle/make-app.sh`
