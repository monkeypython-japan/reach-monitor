---
area: personal
category: "reach-monitor"
tags:
  - area/personal
  - issue
  - moc
modified: 2026-07-07
---

# reach-monitor 既知の問題 (Issues) 一覧

reach-monitor の既知の不具合・ハマりどころ・回避策のインデックス。
*再発時に検索で引っかかってほしい情報* を残す。決定の記録は [[_index|ADR 一覧]] (`decisions/`) を参照。

## ステータス凡例

- **未解決 (open)** — 原因未特定 or 未対処
- **回避中 (workaround)** — 暫定回避策で運用中、恒久対処は未了
- **解決済み (resolved)** — 恒久対処済み（記録は残す）
- **対応しない (wontfix)** — リスク・前提を踏まえ意図的に対応しないと決定（再評価条件を本文に残す）

## 一覧

一覧は [[issues.base]] が `issue` タグ付きノートから**自動生成**する（手動更新不要）。Obsidian で下に Base ビューが表示される。種別列はタグ（`bug`/`pitfall`/`workaround`）から、ステータス列は `status` から算出している。

![[issues.base]]

## 作成・運用ルール

1. `template.md` をコピーして `<症状の要約>.md` を作成
2. frontmatter の種別タグ（`bug` / `pitfall` / `workaround`）+ レイヤータグ（`network` / `wifi` / `ui` / `packaging`）・`status` を記入
3. エラーメッセージは再検索できるよう実際の文言を残す
4. frontmatter を正しく付ければ、一覧 Base には自動で載る（手動でテーブルに追記する必要はない）
