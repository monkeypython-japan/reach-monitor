---
area: personal
category: "reach-monitor"
tags:
  - area/personal
  - issue
  - pitfall
  - ui
status: resolved
date: 2026-07-01
---

# MenuBarExtra のラベルが色を失う（テンプレート画像化される）

- ステータス: 解決済み (resolved)
- 日付: 2026-07-01

## 症状

メニューバーのステータス表示に SwiftUI の `Circle().fill(.red)` / `.fill(.black)` を使うと、
実機のメニューバーでは赤や黒ではなく灰色（あるいは輪郭だけ）の丸にしか見えない。色分けによる
状態表示という目的が達成できない。

## 原因

`MenuBarExtra` はラベルに渡した SwiftUI View を既定でテンプレート画像（モノクロ・
`isTemplate = true` 相当）としてレンダリングする。これはメニューバーの外観（ライト/
ダークモード、アクセントカラー）に馴染ませるための標準動作だが、副作用として `fill()` で
指定した色の情報が失われ、単色シルエットとして描画されてしまう。

## 回避策 / 対処

SwiftUI の `View` をそのままラベルに使うのをやめ、`NSImage(size:flipped:)` で円を
`NSBezierPath` として描画し、`isTemplate = false` を明示的に設定した `NSImage` を
`Image(nsImage:)` でラベルに渡すようにした（[[0006-メニューバーアイコンにnsimage-istemplate-falseを使用|ADR-0006]]）。

```swift
let image = NSImage(size: size, flipped: false) { rect in
    nsColor.setFill()
    NSBezierPath(ovalIn: rect).fill()
    return true
}
image.isTemplate = false
```

## 関連

- 関連 ADR: [[0006-メニューバーアイコンにnsimage-istemplate-falseを使用]]
- 関連実装: `Sources/ReachMonitor/ReachMonitorApp.swift`
