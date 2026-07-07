---
area: personal
category: "reach-monitor"
tags:
  - area/personal
  - adr
  - decision
  - network
  - wifi
adr: 0007
status: accepted
date: 2026-07-01
---

# ADR-0007: `swiftLanguageModes: [.v5]` を固定する

- ステータス: 承認 (Accepted)
- 日付: 2026-07-01

## コンテキスト

`ReachabilityMonitor`（`NWConnection`）や `WiFiMonitor`（`CWWiFiClient`/
`CLLocationManager`）はいずれもコールバックベースの古い API で、Swift 6 の strict
concurrency チェック（デフォルトの `.v6` 言語モード）と相性が悪く、`Sendable` 適合や
actor 分離まわりで大量の警告・エラーが発生する見込みだった。

## 検討した選択肢

- **採用案**: `Package.swift` で `swiftLanguageModes: [.v5]` を明示的に指定し、strict
  concurrency チェックを回避する。UI に関わる状態更新は `AppState` を `@MainActor` にした
  上で、モニタからのコールバックを `Task { @MainActor in ... }` や
  `DispatchQueue.main.async` で手動的にメインスレッドへ渡す。
- **却下案**: `.v6`（既定）のまま strict concurrency に対応する — 却下理由:
  コールバックベースの `Network`/`CoreWLAN` API を `Sendable` 対応させる作業量が、
  個人開発の小規模アプリの割に合わない。`@MainActor` への手動同期で実質的な安全性は
  確保できるため、型システムによる強制までは不要と判断した。

## 決定

`Package.swift` に `swiftLanguageModes: [.v5]` を設定し、代わりに `AppState` を
`@MainActor` の単一の集約点とすることで、コールバックの出所によらず UI 状態の更新を
安全に行う。

## 結果

### 利点

- コールバックベース API まわりの strict concurrency 警告に煩わされずに実装できる。
- `AppState` 一箇所に `@MainActor` を集約することで、実質的なデータ競合リスクは低い。

### 欠点・トレードオフ

- コンパイラによる並行性安全の保証は `.v6` ほど強くない（手動での規律に依存する）。
- 将来 Swift 6 strict concurrency へ完全移行する場合、この決定を見直す必要がある。

## 備考

- 関連実装: `Package.swift`, `Sources/ReachMonitor/AppState.swift`
