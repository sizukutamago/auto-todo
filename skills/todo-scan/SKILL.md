---
name: todo-scan
description: >
  Manually trigger scan+plan for inbox tasks. Analyzes codebases and generates
  execution plans, then moves tasks from inbox/ to planned/.
  Use when user says "スキャン", "scan", "todo-scan", "計画立てて",
  "タスクを分析", or wants to manually trigger task planning.
allowed-tools: Read, Write, Glob, Grep, Bash(mv *), Bash(git status *), Bash(git log *), Bash(git diff *), Bash(ls *), Agent
---

# TODO スキャン & 計画生成

inbox/ のタスクを分析し、実行計画を生成して planned/ に移動する。

## 処理フロー

### Step 1: config と inbox/ の読み込み

1. `${CLAUDE_PLUGIN_ROOT}/data/config.yaml` を Read
2. `${CLAUDE_PLUGIN_ROOT}/data/inbox/` 内の `*.md` ファイルを一覧

inbox/ が空なら「inbox にタスクがありません」と報告して終了。

### Step 2: 各タスクの計画生成

各 inbox タスクについて:

1. frontmatter の where からプロジェクトパスを解決（config.projects）
2. where != null の場合:
   a. プロジェクトディレクトリの存在確認
   b. 存在しなければスキップ（通知で警告）
   c. プロジェクトの構造を分析:
      - ディレクトリ構造（Glob）
      - 関連ファイルの特定（Grep で what/context のキーワード検索）
      - git status / git log で最近の変更状況
   d. 以下を判定:
      - **risk**: low / medium / high
        - low: docs のみ、設定変更、コメント修正
        - medium: 新規ファイル追加、既存ファイル修正
        - high: コアロジック変更、削除を伴う、複数モジュールにまたがる
      - **estimated_complexity**: S / M / L
3. where == null の場合:
   - CWD を基準に分析
   - risk は context から推定

3. タスクファイルに「実行計画」セクションを追記:

```markdown

## 実行計画

### 変更対象ファイル

| ファイル | 変更内容 |
|---------|---------|
| path/to/file.ts | 修正: 〇〇 |

### 実装方針
1. ...
2. ...

### テスト戦略
- ...

### リスク
- ...
```

4. frontmatter に追記:
   - `risk: <low|medium|high>`
   - `planned_at: <ISO 8601>`

5. ファイルを `inbox/` → `planned/` に移動

### Step 3: 自動実行判定

各 planned タスクについて:
- labels ∩ config.auto_execute_labels ≠ ∅ AND risk == low
  → `planned/` → `approved/` に移動（自動承認）
  → ユーザーに通知: "T-XXX は低リスクのため自動承認しました"

### Step 4: 結果報告

```
scan 完了:
  計画生成: 2 件
    - T-001: UserService にキャッシュ層を追加 → planned/ (承認待ち)
    - T-002: README にセットアップ手順を追加 → approved/ (自動承認)
  スキップ: 0 件
```
