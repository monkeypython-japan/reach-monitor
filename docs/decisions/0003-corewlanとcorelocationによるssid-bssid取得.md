---
area: personal
category: "reach-monitor"
tags:
  - area/personal
  - adr
  - decision
  - wifi
adr: 0003
status: accepted
date: 2026-07-01
---

# ADR-0003: CoreWLAN + CoreLocation で現在の SSID/BSSID を取得する

- ステータス: 承認 (Accepted)
- 日付: 2026-07-01

## コンテキスト

メニューバーに現在の Wi-Fi 情報（SSID、および AP 切替検知のための BSSID）を表示するには
`CWWiFiClient`（CoreWLAN）を使う必要がある。しかし macOS 14 以降、`CWInterface` の
`ssid()`/`bssid()` は位置情報 (Location) の許可がないと `nil` を返す仕様になっている。

## 検討した選択肢

- **採用案**: `CLLocationManager.requestWhenInUseAuthorization()` で位置情報の許可を要求し、
  許可された場合のみ `CWWiFiClient` から実際の SSID/BSSID を取得する。CoreWLAN の
  change-event delegate（`bssidDidChange` 等）とポーリング（`MonitorConfig.wifiPollInterval`）
  を併用して取りこぼしを防ぐ。
- **却下案**: 位置情報許可を要求せず SSID/BSSID 表示を諦める — 却下理由: 「現在どの Wi-Fi に
  繋がっているか」の表示はアプリの価値の一部であり、省略すると UX が大きく劣化する。

## 決定

`WiFiMonitor` が起動時に位置情報の許可を要求し、許可された場合のみ SSID/BSSID を
`WiFiInfo` として `AppState` に渡す。未許可の場合はポップオーバーに「位置情報が必要」と
表示する。

## 結果

### 利点

- macOS 14+ でも実際の SSID/BSSID を表示できる。
- change-event + ポーリングの併用で、イベント取りこぼし時も一定間隔で復旧する。

### 欠点・トレードオフ

- 初回起動時に位置情報の許可ダイアログが必須になり、拒否されると SSID 表示ができない。
- ad-hoc 署名の identity 変化により許可がリセットされることがある
  （[[位置情報の許可が再署名でリセットされることがある]]）。

## 備考

- 関連 Issue: [[位置情報の許可が再署名でリセットされることがある]]
- 関連実装: `Sources/ReachMonitor/WiFiMonitor.swift`
- 当初 `WiFiMonitor` は BSSID 変化で「AP 接続からの経過時間」も計測していたが、
  この用途は [[0005-経過時間は到達確認基準とする|ADR-0005]] により削除された
  （SSID/BSSID 取得自体の決定はこの ADR の範囲のまま変わらない）。
