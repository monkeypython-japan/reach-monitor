---
area: personal
category: "reach-monitor"
tags:
  - area/personal
  - adr
  - decision
  - network
adr: 0013
status: accepted
date: 2026-07-22
---

# ADR-0013: HTTPS 対象は TCP 接続ではなく TLS 検証まで行う

- ステータス: 承認 (Accepted)
- 日付: 2026-07-22

## コンテキスト

McDonald's のフリー Wi-Fi（SSID: `00_MCD-FREE-WIFI`）のキャプティブポータル未ログイン状態で、
実際には Web 閲覧が一切できないにもかかわらず、ReachMonitor は「到達可能」（青丸）と誤表示し、
メニューバーの経過時間タイマーも止まらなかった。

ポップオーバーで確認すると、`Cloudflare (1.1.1.1:443)` と `Apple (apple.com:443)` は到達可能
（17ms）と表示される一方、`Google DNS (8.8.8.8:53)` だけが不可と表示されていた。

原因はこのキャプティブポータルの実装にある: port 443 宛の TCP 接続を透過的に自身のゲートウェイへ
リダイレクト（DNAT）し、SYN/ACK だけを返すことで、実際には `1.1.1.1`/`apple.com` に届いていない
のに TCP ハンドシェイク自体は成立してしまう。一方 port 53 (TCP) 宛の接続はリダイレクトの対象外
だったため、正しく（本当に外へ出られないので）失敗していた。`ReachabilityMonitor` は「いずれか
1つでも到達すれば `.reachable`」という集計ロジックのため、この2つの偽陽性が正しい判定を
上書きしていた。

これは [[0002-到達判定にtcp接続テストを採用|ADR-0002]] の却下案 B
「HTTPS リクエストで応答内容まで検証する」がまさに想定していた既知の限界そのものであり、
同 ADR には「将来 captive portal 誤検知が問題になれば ADR を起こして再検討する」と明記されて
いた。

## 検討した選択肢

- **採用案**: HTTPS 用ターゲット（`1.1.1.1:443`、`apple.com:443`）を、生の TCP 接続
  （`NWParameters.tcp`）ではなく TLS ハンドシェイク（`NWParameters.tls`）まで行う接続に変更する。
  `Target` に `usesTLS: Bool` を追加し、`ReachabilityMonitor.probe(_:)` はこのフラグに応じて
  パラメータを切り替える。証明書検証は `Network` フレームワークの既定動作（システムの信頼
  ストアによる通常の TLS 検証）に任せる。`Google DNS (8.8.8.8:53)` は元々 TCP DNS で、
  そもそも TLS 化できるプロトコルではないため、生 TCP のまま変更しない
  （このターゲットは既に今回の誤検知を正しく見抜いていた）。
- **却下案 A（ADR-0002 の却下案 B そのもの）**: HTTP(S) リクエストを実際に送り、応答内容
  （例: `captive.apple.com/hotspot-detect.html` の "Success" 文字列、または
  `generate_204` 相当の期待ステータス）まで検証する — 却下理由: TLS 証明書検証だけでも
  「宛先ホスト名/IP に対して正当な証明書チェーンを提示できるか」という、透過型キャプティブ
  ポータルが原理的に偽装できない検証になる。HTTP リクエスト送信・レスポンス解析を自前実装
  する追加コストに見合うだけの精度向上は、個人利用ツールの現状の問題（TCP ハンドシェイクの
  みでは通ってしまう）に対しては不要と判断した。
- **却下案 B**: 集計ロジックを「いずれか1つでも到達」から「過半数」または「全滅以外は
  reachable」以外の別の閾値に変更する — 却下理由: 個々のターゲットの偽陽性という根本原因
  を直さないまま集計ルールだけ変えても、閾値次第で別の誤判定パターンを生むだけで本質的な
  解決にならない。TLS 検証によって偽陽性そのものを潰す方が筋が良い。

## 決定

`Target` に `usesTLS: Bool` を追加し、`DefaultTargets.all` で `1.1.1.1:443`/`apple.com:443` を
`usesTLS: true`、`8.8.8.8:53` を `usesTLS: false` とする。`ReachabilityMonitor.probe(_:)` は
`target.usesTLS ? NWParameters.tls : NWParameters.tcp` でパラメータを選択する。`.ready` は
TLS 対象では証明書検証まで通った場合のみ到達し、キャプティブポータルが有効な証明書を
提示できずハンドシェイクに失敗すれば `.failed`（`probe` の既存ロジックにより `false`）になる。
集計ロジック（いずれか1つでも到達すれば `.reachable`）自体は変更しない。

## 結果

### 利点

- 透過型キャプティブポータルによる「TCP は通るが実際には到達していない」誤検知を、
  HTTP リクエストの自前実装なしに防げる。
- 実際のネットワーク（iPhone パーソナルホットスポット経由）で TLS 検証込みの接続が
  正しく成功することを確認済み（レイテンシは 64〜141ms 程度、生 TCP より若干増えるが
  タイムアウト 5 秒には十分余裕がある）。
- 変更が `Target`/`ReachabilityMonitor` の数行に収まり、個人利用ツールとしてシンプルさを
  保てる。

### 欠点・トレードオフ

- クライアント信頼ストアに独自 CA を仕込む本格的な TLS 中間者（MITM）型キャプティブポータル
  には無力（ただしこれは HTTP コンテンツ検証でも同様に見破れないケースがある、より高度な
  攻撃/構成であり、個人利用ツールの守備範囲外と判断）。
- TLS ハンドシェイクの分だけ生 TCP より若干レイテンシが増える（実測で数十〜100ms程度)。
  `MonitorConfig.connectionTimeout`（5秒）は十分な余裕がある。

## 備考

- 関連実装: `Sources/ReachMonitor/Targets.swift`, `Sources/ReachMonitor/ReachabilityMonitor.swift`
- 関連 ADR: [[0002-到達判定にtcp接続テストを採用|ADR-0002]]（本 ADR が想定していた却下案 B の
  簡易版を採用する形で今回の誤検知に対応した）
