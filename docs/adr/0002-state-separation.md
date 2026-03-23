# ADR-0002: ディレクトリベース状態管理（ファイル移動 = 状態遷移）

## Status

Accepted (Revised v2)

## Date

2026-03-23

## Context

1タスク1ファイル方式の採用（ADR-0001 v2）に伴い、タスクの状態管理方法を再検討する。

候補:
1. **frontmatter の status フィールド**: ファイル内容を書き換えて状態遷移
2. **ディレクトリ移動**: ファイルを inbox/ → planned/ → approved/ → done/ と移動

## Decision

**ディレクトリ移動で状態遷移を表現する。** frontmatter に status フィールドは持たない。ファイルがどのディレクトリにあるかが状態そのもの。

### ディレクトリと状態の対応

| ディレクトリ | 状態 | 管理者 |
|------------|------|--------|
| inbox/ | 追加直後、未分析 | AI（todo-add） |
| planned/ | 計画生成済み、承認待ち | AI（scan+plan ジョブ） |
| approved/ | 承認済み、実行待ち | ユーザー |
| executing/ | 実行中 | AI（execute ジョブ） |
| done/ | 完了 | AI（execute ジョブ） |
| failed/ | 失敗 | AI（execute ジョブ） |

## Consequences

### 良い点

- **状態が視覚的**: `ls inbox/` で未着手タスク、`ls planned/` で承認待ちが即座にわかる
- **承認がファイル操作**: `mv planned/T-001.md approved/` で完了。YAML 編集不要
- **ファイル内容の書き換え不要**: 状態遷移時にファイル内容を触らない（frontmatter のタイムスタンプ追記は行う）
- **Git フレンドリー**: ファイル移動は `git mv` で追跡可能
- **壊れにくい**: データベースやJSONファイルの整合性問題がない。ファイルシステムが状態ストア

### 悪い点

- **アトミック性の欠如**: ファイル移動 + frontmatter 更新が2ステップ。途中で失敗すると不整合。→ 対策: frontmatter 更新を先、移動を後にする。移動失敗時は frontmatter のタイムスタンプで検出
- **同時アクセス**: ユーザーが手動で移動中にジョブが走ると競合。→ 対策: execute ジョブは approved/ のみ参照。ユーザーが触る planned/ → approved/ とジョブが触る approved/ → executing/ は別ステップなので衝突しにくい

### 廃止したもの

- **state/tasks.json**: ディレクトリ位置が状態を表現するため不要
- **state/history.jsonl**: タスクファイル本文に履歴を記録するため不要
- **tasks.yaml**: 1タスク1ファイルに分解したため不要
