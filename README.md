# Reach Monitor

スタバ・マクドナルド等の共有 Wi-Fi で、**目的アドレスへ実際に到達できているか**を
定期監視し、到達不能になったら通知する macOS メニューバー常駐アプリ。あわせて
**現在の AP に接続してからの経過時間**を表示します。

## 機能
- 既定の監視先（`1.1.1.1:443` / `8.8.8.8:53` / `apple.com:443`）へ 10 秒ごとに
  TCP 接続テストを実行し、到達可否を判定。
- 到達可能 → 不能へ遷移した時に通知（復旧時も控えめに通知）。
- メニューバーアイコンが状態で変化（到達=`wifi`、未到達=`wifi.exclamationmark`）。
- ポップオーバーに総合ステータス・現在 SSID・接続からの経過時間（ライブ更新）・
  各監視先の到達可否とレイテンシを表示。
- CoreWLAN で BSSID を監視し、AP を切り替えると経過時間タイマーをリセット。

## 必要環境
- macOS 14 以降（開発・確認は macOS 26 / Apple Silicon）。
- Swift ツールチェーン（Command Line Tools で可、Xcode 本体は不要）。

## ビルドと起動
```sh
./bundle/make-app.sh        # SwiftPM ビルド → ReachMonitor.app 組立 → ad-hoc 署名
open ReachMonitor.app       # メニューバーに常駐
```

初回起動時に **位置情報** と **通知** の許可を求められます。どちらも承認してください。
- 位置情報：macOS 14+ では SSID/BSSID の取得に必須（未許可だと SSID・経過時間が
  表示できません）。
- 通知：到達不能の通知に必要。

終了はメニューバーのポップオーバー内「終了」ボタンから。

## 設定の変更
監視先や間隔はコード内の定数で管理しています（設定 UI は未実装）。
- 監視対象：[`Sources/ReachMonitor/Targets.swift`](Sources/ReachMonitor/Targets.swift) の
  `DefaultTargets.all`
- チェック間隔・タイムアウト：同ファイルの `MonitorConfig`

変更後は再度 `./bundle/make-app.sh` を実行してください。

## 注意点
- **必ず `.app` 経由で起動**してください。`swift run` の素の実行では bundle id / 署名が
  無く、位置情報・通知が正しく機能しません。
- ad-hoc 署名のため、再署名で署名 identity が変わると位置情報の許可がリセットされる
  ことがあります。
- captive portal 環境では TCP ハンドシェイクだけ通り「到達」に見える場合があります
  （将来 HTTPS 応答内容の検証を追加する余地あり）。

## 構成
```
Package.swift
Sources/ReachMonitor/
  ReachMonitorApp.swift     @main / MenuBarExtra
  AppState.swift            監視を統合し @Published 公開（@MainActor）
  ReachabilityMonitor.swift NWConnection による TCP 到達テスト
  WiFiMonitor.swift         CoreWLAN + CoreLocation で AP を追跡
  NotificationManager.swift 状態遷移エッジでのみ通知
  MenuContent.swift         ポップオーバー UI
  Targets.swift             既定の監視先と各種定数
bundle/
  Info.plist                LSUIElement / bundle id / 位置情報用途文言
  make-app.sh               ビルド & .app パッケージング & 署名
```
