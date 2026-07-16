---
area: personal
category: "reach-monitor"
tags:
  - area/personal
  - adr
  - decision
  - ui
  - performance
adr: 0010
status: accepted
date: 2026-07-16
---

# ADR-0010: 経過時間の tick を AppState から分離し CPU 消費を抑える

- ステータス: 承認 (Accepted)
- 日付: 2026-07-16

## コンテキスト

「到達判定は10秒間隔なのに CPU 使用率が予想より高い」という指摘を受けて `sample` で
プロファイルしたところ、原因は到達判定(10秒間隔)や Wi-Fi ポーリング(5秒間隔)ではなく、
経過時間表示用の 1 秒間隔 `Timer`（`AppState.clockTimer`、`@Published var currentTime`）
だった。`currentTime` は `AppState` の `@Published` プロパティであり、`MenuContent`
（ターゲット一覧の `ForEach`・ボタンなどを含むポップオーバー全体）が `AppState` を
`@EnvironmentObject` として購読しているため、1 秒ごとの tick のたびに `MenuContent`
の view body 全体が再評価されていた。

さらに `MenuBarExtra(style: .window)` はポップオーバーが閉じていても中身の
`NSHostingView` を保持し続ける（`onAppear`/`onDisappear` で開閉を確実に検知できない）
ため、ポップオーバーを開いていない間もこの毎秒の再評価が起き続けていた。
`ForEach`・ジェネリック型メタデータ解決・AppKit の制約レイアウト（`CA::Transaction::commit`
等）を含む再評価が毎秒走ることが、常時数%の CPU 消費として観測されていた。

## 検討した選択肢

- **採用案**: 経過時間の tick を `AppState` から完全に切り離し、`ClockTick`
  （`@Published var now` のみを持つ小さな `ObservableObject`）を新設する。
  経過時間を実際に表示する View（メニューバーのラベル、ポップオーバーの
  `ElapsedTimeRow`）だけがこれを購読し、`AppState` はもう時刻を持たない。
  `AppState.reachElapsedSeconds`/`menuBarElapsedText` は `now: Date` を引数に取る
  純粋関数に変更した。
- **却下案 A**: `clockTimer` の間隔を 1 秒より粗く（例: 30 秒）するだけに留める —
  却下理由: ポップオーバーを開いている間の `hh:mm:ss` 表示の精度が落ちる上、
  「`AppState` 全体を購読しているせいで無関係な View まで再評価される」という
  根本原因は解消しない。
- **却下案 B**: `MenuContent` の `onAppear`/`onDisappear` でポップオーバーの開閉を
  検知し、閉じている間だけ `clockTimer` を止める — 却下理由: `.window` スタイルの
  `MenuBarExtra` はコンテンツを閉時も保持するため、`onDisappear` が確実に発火する
  保証がなく、検知ロジックの信頼性が低い。

## 決定

`Sources/ReachMonitor/ClockTick.swift` を新設し、`ReachMonitorApp` が
`@StateObject` として保持・起動する。`MenuContent` 内の経過時間行は
`ElapsedTimeRow`（`@EnvironmentObject var clock: ClockTick` を持つ専用サブビュー）
として切り出し、`wifiSection` から呼び出す形にする。`AppState` の
`reachTimerStart`/`reachTimerFrozenElapsed` によるエッジ検出ロジック自体は変更しない。

## 結果

### 利点

- ポップオーバー非表示時も含め、毎秒の `MenuContent` 全体再評価が消え、
  実測で CPU 使用率が数% → ほぼ 0% まで低下した（`sample`/`top` で確認済み）。
- `AppState` の責務が「監視結果の集約」に絞られ、時刻という無関係な関心事が
  外に出たことで見通しも改善した。

### 欠点・トレードオフ

- 経過時間を表示する箇所が増えるたびに、その View 側で `ClockTick` を
  個別に購読する必要がある（`AppState` を見るだけでは経過時間が取れない）。

## 備考

- 関連実装: `Sources/ReachMonitor/ClockTick.swift`, `Sources/ReachMonitor/AppState.swift`,
  `Sources/ReachMonitor/MenuContent.swift`, `Sources/ReachMonitor/ReachMonitorApp.swift`
- 経過時間の意味論（到達確認基準・凍結の挙動）自体は
  [[0005-経過時間は到達確認基準とする|ADR-0005]] のまま変更していない。
  本 ADR は「誰が何秒おきに描画を要求するか」という配線だけを変更している。
