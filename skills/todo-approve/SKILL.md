---
name: todo-approve
description: >
  Approve a planned task for execution. Moves the task file from planned/ to approved/.
  Use when user says "承認", "approve", "todo-approve", "実行して", "これでOK",
  or wants to approve a planned TODO task.
argument-hint: "<task-id>"
allowed-tools: Read, Write, Bash(mv *)
---

# TODO 承認

planned/ にあるタスクを approved/ に移動して実行待ちにする。

## 入力

`$ARGUMENTS` — タスク ID（例: T-20260323-001）。省略時は planned/ の一覧を表示して選択を促す。

## 処理フロー

1. `$ARGUMENTS` が空の場合:
   - `${CLAUDE_PLUGIN_ROOT}/data/planned/` のファイル一覧を表示
   - 「どのタスクを承認しますか？」と AskUserQuestion で確認
2. `${CLAUDE_PLUGIN_ROOT}/data/planned/$ARGUMENTS.md` の存在を確認
   - 存在しない → 「planned/ に該当タスクがありません」と報告。planned/ の一覧を表示
3. frontmatter に `approved_at: <現在時刻 ISO 8601>` を追記
4. ファイルを `planned/` → `approved/` に移動:
   ```bash
   mv ${CLAUDE_PLUGIN_ROOT}/data/planned/$ARGUMENTS.md ${CLAUDE_PLUGIN_ROOT}/data/approved/
   ```
5. 結果を報告:
   ```
   T-20260323-001 を承認しました（approved/ に移動）
   次回の execute ジョブ、または /auto-todo:todo-execute T-20260323-001 で実行されます
   ```
