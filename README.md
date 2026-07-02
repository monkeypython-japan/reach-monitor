# Reach Monitor

スタバ・マクドナルド等の共有 Wi-Fi で、**目的アドレスへ実際に到達できているか**を
定期監視し、到達不能になったら通知する macOS メニューバー常駐アプリ。あわせて
**到達確認からの経過時間**をメニューバーに常時表示する。

## 機能
- 既定の監視先（`1.1.1.1:443` / `8.8.8.8:53` / `apple.com:443`）へ 10 秒ごとに
  TCP 接続テストを実行し、到達可否を判定。
- 到達可能 → 不能へ遷移した時に通知（復旧時も控えめに通知）。
- **メニューバーに色付き丸アイコン + 経過時間（h:mm）を常時表示**：
    - 赤丸：到達可能
    - 黒丸：到達不能
    - 灰色丸：確認中
- **経過時間は到達確認を基準にカウント**：
    - 最初に到達が確認された時点で 0:00 からスタート
    - 到達が失われた瞬間にタイマーが停止（その時点の値のまま固定表示）
    - 再度到達が確認されると 0:00 から再スタート
    - 「今すぐ再チェック」ボタンで発生する一時的な `.checking` 状態はタイマーに影響しない
- ポップオーバー（クリックで展開）に総合ステータス・現在 SSID・到達確認からの経過時間
  （hh:mm:ss）・各監視先の到達可否とレイテンシを表示。
- CoreWLAN + CoreLocation で現在の SSID/BSSID を取得・表示。

## 必要環境
- macOS 14 以降（開発・確認は macOS 26 / Apple Silicon）。
- Swift ツールチェーン（Command Line Tools で可、Xcode 本体は不要）。

## ビルドとインストール

```sh
./bundle/make-app.sh          # ビルド → ~/Applications に配置 → LaunchAgent 登録 → 起動
./bundle/make-app.sh start    # 再起動（ビルドなし）
./bundle/make-app.sh stop     # 停止
```

- ビルド後のアプリは **`~/Applications/ReachMonitor.app`** に配置される。
- **LaunchAgent** により**ログイン時に自動起動**する。
- macOS 26 では ad-hoc 署名アプリを Finder から起動できないため、
  LaunchAgent（`launchctl`）経由で起動する方式を採用。
- ログは `/tmp/reachmonitor.log` に出力される。

### 初回起動時の権限
起動後に **位置情報** と **通知** の許可を求められる。どちらも承認すること。
- 位置情報：macOS 14+ では SSID/BSSID の取得に必須（未許可だと SSID が表示できない）。
- 通知：到達不能の通知に必要。

## 設定の変更
監視先や間隔はコード内の定数で管理（設定 UI は未実装）。
- 監視対象：[`Sources/ReachMonitor/Targets.swift`](Sources/ReachMonitor/Targets.swift) の
  `DefaultTargets.all`
- チェック間隔・タイムアウト：同ファイルの `MonitorConfig`

変更後は再度 `./bundle/make-app.sh` を実行する。

## 注意点
- **必ず .app バンドル経由で起動**すること。`swift run` では bundle id / 署名が無く、
  位置情報・通知が正しく機能しない。
- ad-hoc 署名のため、再署名で署名 identity が変わると位置情報の許可がリセットされる
  ことがある。
- captive portal 環境では TCP ハンドシェイクだけ通り「到達」に見える場合がある
  （将来 HTTPS 応答内容の検証を追加する余地あり）。

## 構成

```
Package.swift
Sources/ReachMonitor/
  ReachMonitorApp.swift     @main / MenuBarExtra + NSImage アイコン
  AppState.swift            監視を統合し @Published 公開（@MainActor）、到達時間の計測
  ReachabilityMonitor.swift NWConnection による TCP 到達テスト
  WiFiMonitor.swift         CoreWLAN + CoreLocation で SSID/BSSID を取得
  NotificationManager.swift 状態遷移エッジでのみ通知
  MenuContent.swift         ポップオーバー UI
  Targets.swift             既定の監視先と各種定数
bundle/
  Info.plist                LSUIElement / bundle id / 位置情報用途文言
  make-app.sh               ビルド & ~/Applications 配置 & LaunchAgent 登録
```
