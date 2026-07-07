---
area: personal
category: "reach-monitor"
tags:
  - area/personal
  - adr
  - decision
  - ui
adr: 0006
status: accepted
date: 2026-07-01
---

# ADR-0006: メニューバーアイコンは NSImage(isTemplate: false) で描画する

- ステータス: 承認 (Accepted)
- 日付: 2026-07-01

## コンテキスト

初期実装ではメニューバーアイコンに SF Symbol（`wifi` / `wifi.exclamationmark`）を使っていたが、
既存の Wi-Fi アイコンと酷似していて紛らわしいという指摘を受けた。「到達している場合は赤丸、
切断されている場合は黒丸」のように、状態が色で一目で分かる表示に変更する要望が出た。

最初に SwiftUI の `Circle().fill(color)` を `MenuBarExtra` のラベルに使ったところ、
色が反映されず単色（グレー）の丸にしか見えないという不具合が発生した
（詳細は [[menubarextraのラベルが色を失う-テンプレート画像化]]）。

## 検討した選択肢

- **採用案**: `NSImage(size:flipped:)` で円を `NSBezierPath` として直接描画し、
  `isTemplate = false` を明示的に設定した `NSImage` を `Image(nsImage:)` 経由で
  `MenuBarExtra` のラベルに使う。
- **却下案**: SwiftUI の `Circle().fill(Color)` をそのままラベルに使う — 却下理由:
  `MenuBarExtra` はラベルの SwiftUI View を既定でテンプレート画像（モノクロ）として
  レンダリングするため、`fill()` で指定した色が失われる。

## 決定

`AppState.menuBarIcon`（`ReachMonitorApp.swift` 内の extension）が状態に応じた色
（到達=赤、非到達=黒、確認中=グレー）で `NSImage` を描画し、`isTemplate = false` を
設定して返す。`MenuBarExtra` のラベルはこの `NSImage` をラップした `Image` と、
経過時間の `Text` を並べた `HStack` にする。

## 結果

### 利点

- メニューバー上で状態が色付きの丸として正しく表示され、既存の Wi-Fi アイコンと
  混同されなくなった。

### 欠点・トレードオフ

- `NSImage` を手動描画する分、SwiftUI だけで完結する場合よりコードがやや低レベルになる
  （`AppKit` の知識が必要）。

## 備考

- 関連 Issue: [[menubarextraのラベルが色を失う-テンプレート画像化]]
- 関連実装: `Sources/ReachMonitor/ReachMonitorApp.swift`
