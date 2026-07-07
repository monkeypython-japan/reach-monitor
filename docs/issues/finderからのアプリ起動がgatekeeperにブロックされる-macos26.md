---
area: personal
category: "reach-monitor"
tags:
  - area/personal
  - issue
  - pitfall
  - packaging
status: workaround
date: 2026-07-07
---

# Finder からのアプリ起動が Gatekeeper にブロックされる（macOS 26）

- ステータス: 回避中 (workaround)
- 日付: 2026-07-07

## 症状

`bundle/make-app.sh` でビルド・ad-hoc 署名した `ReachMonitor.app` を Finder で
ダブルクリック、あるいは右クリック→「開く」しても起動しない。「開発元を確認できません」
のような確認ダイアログすら表示されず、サイレントに失敗する。

- `spctl -a -t exec -vvv ReachMonitor.app` → `rejected`
- `spctl --status` → `assessments enabled`（Gatekeeper 自体は有効）
- `xattr -l ReachMonitor.app` → `com.apple.provenance` 属性が付いている。`xattr -cr` で
  除去しても `spctl` の判定は変わらない
- `spctl --add ReachMonitor.app` → `This operation is no longer supported.`（廃止済み）
- 一方、`open ReachMonitor.app` やバイナリの直接実行（
  `ReachMonitor.app/Contents/MacOS/ReachMonitor` を直接叩く）は成功しプロセスが立ち上がる

## 原因

macOS 26 のこの環境では、ad-hoc 署名 (`codesign --sign -`) された開発用アプリを Finder が
起動しようとした際、Gatekeeper がダイアログを出さずにブロックする。従来 macOS で使えた
「右クリック→開く」による確認ダイアログ経由の例外登録も機能しない。`open` コマンドや
`launchctl` 経由の起動はこの制限を受けない。

## 回避策 / 対処

Finder からの起動は諦め、`launchctl`（LaunchAgent）経由でバイナリを直接起動する方式に変更した
（[[0004-launchagent経由での起動方式に変更|ADR-0004]]）。`bundle/make-app.sh` が
`~/Library/LaunchAgents/com.mamoru.reachmonitor.plist` を生成・登録し、`RunAtLoad` で
ログイン時に自動起動、`make-app.sh start`/`stop` で手動制御する。

正式な Finder 起動を復活させるには Apple Developer 証明書での署名・公証が必要になる見込みだが、
個人利用の範囲では過剰なため対応していない（[[0001-swiftpmビルドと手動appパッケージングでad-hoc署名を採用|ADR-0001]]）。

## 関連

- 関連 ADR: [[0004-launchagent経由での起動方式に変更]], [[0001-swiftpmビルドと手動appパッケージングでad-hoc署名を採用]]
- 関連実装: `bundle/make-app.sh`
