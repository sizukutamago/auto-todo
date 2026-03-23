# ADR-0005: ディレクトリ移動による承認フロー

## Status

Accepted (Revised v2)

## Date

2026-03-23

## Context

1タスク1ファイル + ディレクトリベース状態管理の採用により、承認フローも再設計が必要。

初期案ではファイル内の `approved: true` フラグを編集する方式だったが、ディレクトリ移動が状態遷移である以上、承認もディレクトリ移動で表現すべき。

## Decision

**承認 = `planned/` から `approved/` へのファイル移動。** 手段は以下の2つ:

1. **スキル**: `/auto-todo:todo-approve T-20260323-001` — ファイル移動 + approved_at 追記を自動で行う
2. **手動移動**: `mv ~/.claude/auto-todo/planned/T-001.md ~/.claude/auto-todo/approved/` — ファイルを直接移動

## Consequences

### 良い点

- **YAML 編集不要**: `approved: true` を手で書く必要がない
- **操作が直感的**: ファイルを移動するだけ。Finder のドラッグ＆ドロップでも可
- **状態モデルとの一貫性**: 全ての状態遷移がディレクトリ移動で統一される

### 悪い点

- **approved_at の追記漏れ**: 手動移動の場合、frontmatter のタイムスタンプが更新されない。→ 対策: execute ジョブが approved/ 内のファイルに approved_at がなければ現在時刻で補完
