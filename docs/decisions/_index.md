---
area: personal
category: "reach-monitor"
tags:
  - area/personal
  - adr
  - moc
modified: 2026-07-07
---

# reach-monitor ADR 一覧

reach-monitor のアーキテクチャ決定記録 (ADR) のインデックス。設計判断の経緯・採用/却下理由を1決定=1ファイルで残す。作成・運用ルールは末尾を参照。

## ステータス凡例

- **提案 (proposed)** — 検討中・未確定
- **承認 (accepted)** — 採用が確定
- **却下 (rejected)** — 採用しないと決定
- **廃止 (deprecated)** — 過去に有効だったが現在は非推奨
- **置換 (superseded)** — 新しい ADR に置き換えられた

## 一覧

一覧は [[decisions.base]] が `adr` タグ付きノートから**自動生成**する（手動更新不要）。Obsidian で下に Base ビューが表示される。

![[decisions.base]]

## 作成・運用ルール

1. `template.md` をコピーして `NNNN-<決定の要約>.md` を作成（4桁連番、番号は既存の最大+1）
2. frontmatter の `adr` / `status` / `date` と、種別タグ `decision` + レイヤータグを記入
   - レイヤー: `network`（TCP到達判定・状態遷移） / `wifi`（CoreWLAN・位置情報） / `ui`（SwiftUI・メニューバー） / `packaging`（ビルド・署名・LaunchAgent）から該当するもの
   - frontmatter を正しく付ければ、一覧 Base には自動で載る（手動でテーブルに追記する必要はない）
3. 「検討した選択肢（採用案 + 却下案とその理由）」を必ず残す（再利用価値の核）
4. 確定したら `status` を `accepted` に変更する
5. 決定済みの ADR は原則として書き換えず、変更が生じた場合は新しい ADR を起こして旧 ADR を `superseded` にする
