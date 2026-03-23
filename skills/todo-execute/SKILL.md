---
name: todo-execute
description: >
  Execute approved TODO tasks. Creates git worktrees for isolation,
  implements changes according to plans, runs tests, and creates PRs.
  Use when user says "実行", "execute", "todo-execute", "タスク実行",
  "これやって", or wants to execute approved tasks immediately.
argument-hint: "[task-id]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# TODO 実行

approved/ のタスクを実行する。Git worktree で隔離し、計画に沿って実装・テスト・PR 作成を行う。

## 入力

`$ARGUMENTS` — タスク ID（省略時は approved/ の全タスクを実行）

## 処理フロー

### Step 1: 対象タスクの特定

- `$ARGUMENTS` あり → `${CLAUDE_PLUGIN_ROOT}/data/approved/$ARGUMENTS.md` を対象
- `$ARGUMENTS` なし → `${CLAUDE_PLUGIN_ROOT}/data/approved/` 内の全ファイル

approved/ が空なら「実行待ちのタスクがありません」と報告して終了。

### Step 2: プロジェクト別グループ化

タスクを where フィールドでグループ化:
- 異なるプロジェクト → 並列実行（Agent で並列起動）
- 同一プロジェクト → 直列実行
- where: null → 独立ワーカーで実行

### Step 3: 各タスクの実行

各タスクについて:

1. ファイルを `approved/` → `executing/` に移動
2. where != null の場合:
   a. プロジェクトパスを解決（config.projects）
   b. Git worktree を作成:
      ```bash
      cd <project_path>
      git worktree add ${CLAUDE_PLUGIN_ROOT}/data/worktrees/<task-id> -b auto-todo/<task-id>
      ```
   c. worktree ディレクトリに移動
3. where == null の場合:
   - CWD で直接作業

4. 「実行計画」セクションの内容に沿って実装:
   - ファイル作成・修正（Write, Edit）
   - コードベースの参照（Read, Glob, Grep）

5. テスト実行:
   - プロジェクトにテストがある場合: `npm test`, `pytest`, etc.
   - テストがない場合: ビルド確認のみ

6. 成功の場合:
   a. 変更をコミット:
      ```bash
      git add -A
      git commit -m "auto-todo: <what>"
      ```
   b. PR 作成（gh CLI が利用可能な場合）:
      ```bash
      gh pr create --title "auto-todo: <what>" --body "..."
      ```
   c. 「実行結果」セクションをタスクファイルに追記
   d. frontmatter に branch, pr, executed_at を追記
   e. ファイルを `executing/` → `done/` に移動

7. 失敗の場合:
   a. 「実行結果」セクションに失敗理由を追記
   b. frontmatter に executed_at を追記
   c. ファイルを `executing/` → `failed/` に移動
   d. worktree は残す（デバッグ用）

### Step 4: 通知

各タスクの結果を通知:
- 成功: `[auto-todo] T-001 実行完了: PR #42`
- 失敗: `[auto-todo] T-001 実行失敗: テストエラー`

### セーフティ

- execute はこのスキル経由でのみ実行される
- Scheduled Task 版（todo-execute-scheduled）は allowedTools を制限する
- worktree 隔離により main ブランチは無傷
- max-turns に達した場合は failed/ に移動
