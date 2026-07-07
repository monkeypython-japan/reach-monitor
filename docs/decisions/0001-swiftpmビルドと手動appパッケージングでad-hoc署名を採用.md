---
area: personal
category: "reach-monitor"
tags:
  - area/personal
  - adr
  - decision
  - packaging
adr: 0001
status: accepted
date: 2026-07-01
---

# ADR-0001: SwiftPM ビルド + 手動 .app パッケージング（ad-hoc 署名）を採用する

- ステータス: 承認 (Accepted)
- 日付: 2026-07-01

## コンテキスト

reach-monitor は macOS メニューバー常駐アプリとして実装することが決まったが、開発機には
Xcode 本体（`.xcodeproj` を作成・ビルドできる GUI ツール）がインストールされておらず、
Command Line Tools のみが利用可能だった（Swift 6.3.2 は使える）。個人利用（App Store 配布や
Developer ID 証明書での配布は不要）という前提のもと、Xcode を新たにインストールせずに
最短でメニューバーアプリを起動できる構成を選ぶ必要があった。

## 検討した選択肢

- **採用案**: Swift Package Manager の executable target としてビルドし、`bundle/make-app.sh`
  で `.app` バンドル構造（`Contents/MacOS`, `Contents/Info.plist`, `Contents/PkgInfo`）を
  手動で組み立て、`codesign --sign -`（ad-hoc）で署名する。
- **却下案 A**: Xcode をインストールし `.xcodeproj` として構成する — 却下理由:
  個人利用の枠を超えた環境変更になる。GUI ビルドは自動化・スクリプト化がしづらく、
  Claude Code から完結して構築・検証するのに向かない。
- **却下案 B**: Developer ID 証明書を取得して正式に署名・公証 (notarize) する — 却下理由:
  Apple Developer Program への登録が必要でコストと手間が見合わない（個人の Mac 1 台で
  動けば十分）。

## 決定

Xcode 非依存の SwiftPM ビルドを採用し、`.app` バンドルの組み立てと ad-hoc 署名は
`bundle/make-app.sh` に閉じ込めてスクリプトで完結させる。

## 結果

### 利点

- Xcode インストール不要で、`swift build` と `codesign` だけで完結する。
- ビルド・パッケージング・インストールが一つのスクリプトで再現可能（CI 的にも扱いやすい）。

### 欠点・トレードオフ

- ad-hoc 署名のため Gatekeeper の扱いが正規署名と異なり、Finder からの起動がブロックされる
  （詳細は [[finderからのアプリ起動がgatekeeperにブロックされる-macos26]]）。
- 位置情報などの TCC 権限が署名 identity（ad-hoc は実行ファイルのハッシュ由来）に紐付くため、
  再署名のたびに許可がリセットされ得る（[[位置情報の許可が再署名でリセットされることがある]]）。
- App Store 配布や他 Mac への配布は前提としていない。

## 備考

- 関連 Issue: [[finderからのアプリ起動がgatekeeperにブロックされる-macos26]],
  [[位置情報の許可が再署名でリセットされることがある]]
- 関連実装: `bundle/make-app.sh`, `Package.swift`
