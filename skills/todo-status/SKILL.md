---
name: todo-status
description: >
  Show status summary of all TODO tasks across all directories.
  Use when user says "タスク一覧", "TODO確認", "todo-status", "状態確認",
  "何がある", "タスクどうなってる", or wants to see task overview.
allowed-tools: Read, Glob
---

# TODO ステータス一覧

全ディレクトリを走査してタスクの状態サマリーを表示する。

## 処理フロー

1. `${CLAUDE_PLUGIN_ROOT}/data/` 配下の各ディレクトリを走査:
   - inbox/, planned/, approved/, executing/, done/, failed/
2. 各ディレクトリ内の `*.md` ファイルの frontmatter を読み取る
3. 以下のフォーマットで一覧表示:

```
## auto-todo ステータス

### inbox (2)
- T-20260323-001: UserService にキャッシュ層を追加 @kondate
- T-20260323-004: 設計ドキュメントをまとめる

### planned (1) ← 承認待ち
- T-20260323-002: README にセットアップ手順を追加 @flow-pilot [docs]

### approved (0)

### executing (1)
- T-20260323-003: CI の flaky test を修正 @flow-pilot

### done (3) ← 直近5件のみ表示
- T-20260322-001: ESLint warning を解消 @app — PR #41

### failed (0)
```

4. done/ は直近 5 件のみ表示。全件見たい場合は `ls ${CLAUDE_PLUGIN_ROOT}/data/done/` を案内
