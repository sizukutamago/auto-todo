# ADR-0003: scan+plan と execute の 2 系統スケジュール分離

## Status

Accepted

## Date

2026-03-23

## Context

Desktop Scheduled Tasks でタスク自動消化を実現するにあたり、フロー全体を1つのジョブで一気通貫にするか、フェーズごとに分離するかを決定する必要がある。

- **一気通貫**: 1つの Scheduled Task が scan → plan → approve → execute をすべて実行
- **2系統分離**: scan+plan と execute を別の Scheduled Task として分離

Desktop Scheduled Tasks は非対話的に実行されるため、実行途中でユーザーの承認を待つことは設計上困難。セッションがタイムアウトする、あるいは承認待ちで永久にブロックされるリスクがある。

## Decision

**2系統に分離する。**

| ジョブ | 頻度 | Permission Mode | 目的 |
|--------|------|----------------|------|
| auto-todo-scan-plan | Hourly | plan | TODO スキャン + 計画生成 |
| auto-todo-execute | Daily 10:00 AM | acceptEdits | 承認済みタスクの実行 |

例外: `approval: auto` かつ `risk: low` のタスクは scan+plan ジョブ内で即時実行を許可する。

## Consequences

### 良い点

- **承認フローが自然**: scan+plan は読み取りのみ（plan モード）で安全に高頻度実行できる。ユーザーは自分のペースで plans/*.md を確認・承認できる
- **blast radius の制限**: scan+plan ジョブはコードを変更しないため、万が一の暴走でもリスクが低い
- **フェーズごとのパーミッション最適化**: scan+plan は Read/Grep/Glob のみ。execute は Edit/Write/Bash を追加。最小権限の原則を適用しやすい
- **デバッグしやすい**: 計画生成と実行が分離しているため、どちらで問題が起きたか特定しやすい

### 悪い点

- **レイテンシ**: タスク追加から実行完了まで最大 24 時間かかる（Hourly scan + ユーザー承認 + Daily execute）。→ 対策: `/auto-todo:todo-execute` で手動即時実行を提供
- **auto-execute のリスク**: 低リスクタスクの自動実行を scan+plan ジョブ内で行うと、plan モードでは実行できない。→ 対策: auto-execute 判定時のみ permission を切り替え、worktree 隔離を必須とする

### 却下した選択肢

- **一気通貫**: 非対話環境で承認を待てない。plan と execute で必要なパーミッションが異なるため、全体を bypassPermissions にする必要が出てセーフティが崩壊する
- **3系統分離（scan / plan / execute）**: 過度な分割。scan と plan は読み取りのみで実質同じパーミッションなので分ける理由がない
