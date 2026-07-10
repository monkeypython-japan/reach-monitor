---
area: personal
category: "reach-monitor"
tags:
  - area/personal
  - adr
  - decision
  - network
  - ui
adr: 0008
status: accepted
date: 2026-07-11
---

# ADR-0008: NWPathMonitor で使用中のリンク種別を判定する

- ステータス: 承認 (Accepted)
- 日付: 2026-07-11

## コンテキスト

Wi-Fi と Ethernet の両方に接続できる環境（USB-C ドック等）では、実際にどちらの
インターフェース経由で通信しているかが分かりにくい。特に Ethernet 優先の環境や
キャプティブポータル調査時に「今どのリンクを使っているか」をポップオーバーで
確認したいという要望があった。

## 検討した選択肢

- **採用案**: `NWPathMonitor` でシステムのデフォルト経路を監視し、
  `path.availableInterfaces.first` の `type`（`.wifi` / `.wiredEthernet` 等）を
  「現在使用中のリンク」として表示する。
- **却下案**: 既存の `WiFiMonitor`（CoreWLAN）が持つ Wi-Fi インターフェースの
  有無だけで Wi-Fi/Ethernet を簡易判定する — 却下理由: Wi-Fi と Ethernet の両方が
  繋がっていて Ethernet が優先されているケースを区別できず、誤った表示になる。

## 決定

新規 `LinkMonitor`（`Sources/ReachMonitor/LinkMonitor.swift`）が `NWPathMonitor` を
起動し、経路変化のたびに先頭インターフェースの種別を `AppState.link` に反映する。
`AppState.linkTypeText` が種別を日本語ラベル（"Wi-Fi" / "Ethernet" 等）に変換し、
ポップオーバーの「使用中のリンク」行として表示する。

## 結果

### 利点

- Wi-Fi/Ethernet 両方接続時でも、実際にトラフィックが流れている方を正しく表示できる。
- 既存の `ReachabilityMonitor` / `WiFiMonitor` と同じ「バックグラウンド監視 →
  `onUpdate` をメインキューに渡す」パターンに沿っており、`AppState` 側の変更が小さい。

### 欠点・トレードオフ

- `NWInterface.InterfaceType` はインターフェース名（`en0` 等）を含まないため、
  複数の Ethernet アダプタがある場合などの詳細な区別はできない（種別のみ表示）。

## 備考

- 関連実装: `Sources/ReachMonitor/LinkMonitor.swift`, `Sources/ReachMonitor/AppState.swift`,
  `Sources/ReachMonitor/MenuContent.swift`
- Wi-Fi の SSID 表示（[[0003-corewlanとcorelocationによるssid-bssid取得|ADR-0003]]）とは
  独立した仕組み。SSID は Wi-Fi インターフェースの関連付け状態を表すのに対し、本 ADR の
  リンク種別は実際のデフォルト経路を表す。
