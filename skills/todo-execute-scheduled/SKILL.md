---
name: todo-execute-scheduled
description: >
  Scheduled task version of todo-execute. Runs daily via Desktop Scheduled Tasks.
  Executes approved tasks in git worktrees with safety constraints.
  NOT user-invocable — triggered only by Desktop Scheduled Tasks.
user-invocable: false
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(mv *), Bash(mkdir *), Bash(git *), Bash(npm test *), Bash(npm run build *), Bash(npx *), Bash(gh pr create *), Bash(ls *)
---

# Scheduled: TODO 実行

Desktop Scheduled Task から定期実行される execute ジョブ。

## 処理フロー

1. `${CLAUDE_PLUGIN_ROOT}/data/config.yaml` を Read
2. `${CLAUDE_PLUGIN_ROOT}/data/approved/` 内の `*.md` を一覧（空なら終了）
3. タスクを where でグループ化
4. 各グループを順次処理（同一プロジェクト内は直列）:
   a. ファイルを approved/ → executing/ に移動
   b. where != null:
      - プロジェクトパスを解決
      - Git worktree を作成
      - worktree 内で実装
   c. where == null:
      - 直接実行
   d. テスト実行
   e. 成功: commit → PR → done/ に移動
   f. 失敗: failed/ に移動、worktree 残す
5. 通知（scripts/notify.sh 経由）

## セーフティ制約

- worktree 外のプロジェクトファイルを直接変更しない
- `rm -rf`, `sudo`, `curl`, `wget` は禁止（hooks/hooks.json で enforcement）
- `.env`, `credentials`, `secret` を含むファイルを読まない
- main ブランチに直接コミットしない
- max-turns に達したら failed/ に移動
