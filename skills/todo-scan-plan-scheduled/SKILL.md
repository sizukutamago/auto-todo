---
name: todo-scan-plan-scheduled
description: >
  Scheduled task version of todo-scan. Runs hourly via Desktop Scheduled Tasks.
  Scans inbox/ for new tasks, analyzes codebases, generates execution plans.
  NOT user-invocable — triggered only by Desktop Scheduled Tasks.
user-invocable: false
allowed-tools: Read, Write, Glob, Grep, Bash(mv *), Bash(git status *), Bash(git log *), Bash(git diff *), Bash(ls *), Bash(mkdir *)
---

# Scheduled: TODO スキャン & 計画生成

Desktop Scheduled Task から定期実行される scan+plan ジョブ。

## 処理フロー

1. `${CLAUDE_PLUGIN_ROOT}/data/config.yaml` を Read（存在しなければ終了）
2. `${CLAUDE_PLUGIN_ROOT}/data/inbox/` 内の `*.md` を一覧（空なら終了）
3. 各 inbox タスクについて:
   a. frontmatter を読み込み
   b. where のプロジェクトパスを解決
   c. where != null → ディレクトリ存在確認（なければスキップ）
   d. コードベースを分析（Read, Glob, Grep のみ — 読み取り専用）
   e. risk を判定
   f. 「実行計画」セクションをファイルに追記
   g. frontmatter に risk, planned_at を追記
   h. ファイルを inbox/ → planned/ に移動
4. auto_execute 判定:
   - labels ∩ auto_execute_labels ≠ ∅ AND risk == low
   - 該当タスクは planned/ → approved/ に自動移動
5. 通知（scripts/notify.sh 経由）:
   - 計画完了タスクの一覧
   - 自動承認したタスクの一覧

## 制約

- ファイルの Edit/Write は タスクファイル（${CLAUDE_PLUGIN_ROOT}/data/ 配下）のみ
- プロジェクトのコードは一切変更しない
- Bash はファイル移動と git 情報取得のみ
