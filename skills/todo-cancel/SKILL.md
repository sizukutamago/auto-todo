---
name: todo-cancel
description: >
  Cancel a TODO task. Moves the task file to done/ with cancelled status or deletes it.
  Use when user says "キャンセル", "取り消し", "cancel", "todo-cancel", "やめる",
  or wants to cancel a TODO task.
argument-hint: "<task-id>"
allowed-tools: Read, Bash(mv *), Bash(rm *)
---

# TODO キャンセル

タスクをキャンセルする。

## 入力

`$ARGUMENTS` — タスク ID

## 処理フロー

1. `$ARGUMENTS` の ID で全ディレクトリ（inbox/, planned/, approved/, failed/）を検索
   - executing/ にある場合は「実行中のタスクはキャンセルできません」と報告
   - done/ にある場合は「既に完了しています」と報告
   - 見つからない場合は「該当タスクがありません」と報告
2. 見つかったファイルの frontmatter に `cancelled_at: <現在時刻>` を追記
3. ファイルを done/ に移動（履歴として残す）
4. 結果を報告:
   ```
   T-20260323-002 をキャンセルしました（done/ に移動）
   ```
