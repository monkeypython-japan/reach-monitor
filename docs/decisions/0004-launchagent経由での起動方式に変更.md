---
area: personal
category: "reach-monitor"
tags:
  - area/personal
  - adr
  - decision
  - packaging
adr: 0004
status: accepted
date: 2026-07-07
---

# ADR-0004: LaunchAgent 経由での起動方式に変更する

- ステータス: 承認 (Accepted)
- 日付: 2026-07-07

## コンテキスト

`bundle/make-app.sh` で組み立てた `.app` を `open ReachMonitor.app` で起動した時点では
動作を確認できていたが、Finder 上で `ReachMonitor.app` をダブルクリック、あるいは
右クリック→「開く」しても起動できない、確認ダイアログすら出ない、という報告があった。

調査の結果、次が判明した:
- `spctl -a -t exec -vvv ReachMonitor.app` の判定が `rejected`。
- `com.apple.provenance` 属性が付与されており、`xattr -cr` で除去しても判定は変わらない。
- `spctl --add` は「このオペレーションはサポートされていません」で使えない（廃止済み）。
- 一方 `~/Applications/ReachMonitor.app/Contents/MacOS/ReachMonitor` を直接実行する、
  または `open` コマンドで起動するとプロセスは正常に立ち上がる。
- macOS 26 ではこの Mac の Gatekeeper が、ad-hoc 署名 (`codesign --sign -`) の開発用アプリを
  Finder からの起動時にダイアログなしでサイレントにブロックする（右クリック→開く による
  従来のエスケープ経路も機能しない）。

つまり Finder 起動という前提そのものが macOS 26 のこの環境では成立しない。

## 検討した選択肢

- **採用案**: `launchctl`（LaunchAgent）経由でバイナリを直接起動する。`bundle/make-app.sh` が
  `~/Library/LaunchAgents/com.mamoru.reachmonitor.plist` を生成し、`RunAtLoad` でログイン時に
  自動起動させる。手動再起動は `make-app.sh start` / `stop` サブコマンドで
  `launchctl bootstrap` / `bootout` を叩く。
- **却下案 A**: Finder からの起動に固執し、Apple Developer 証明書での正式署名・公証を行う —
  却下理由: [[0001-swiftpmビルドと手動appパッケージングでad-hoc署名を採用|ADR-0001]] で
  個人利用の枠を超えるコストは却下済み。
- **却下案 B**: `.app` をインストール先ディレクトリ以外（プロジェクトフォルダ直下）に
  置いたまま運用する — 却下理由: `~/Applications` のようなユーザー用アプリ配置場所に
  比べて信頼性が低く、Gatekeeper の挙動も変わらなかったため意味がない。

## 決定

`.app` は `~/Applications/ReachMonitor.app` にインストールし、Finder からの起動は前提とせず、
LaunchAgent（`launchctl bootstrap`）でログイン時に自動起動する運用に変更する。

## 結果

### 利点

- Gatekeeper のブロックに影響されずに確実に起動できる。
- ログイン時の自動起動が手に入り、手動で毎回開く必要がなくなる。

### 欠点・トレードオフ

- Finder のダブルクリックでは今後も起動できない（意図的に諦めた）。
- 常駐アプリの起動・停止は `make-app.sh start`/`stop` や `launchctl` コマンドを覚える必要がある。

## 備考

- 関連 Issue: [[finderからのアプリ起動がgatekeeperにブロックされる-macos26]]
- 関連実装: `bundle/make-app.sh`
