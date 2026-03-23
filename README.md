# auto-todo

Claude Code プラグイン。チャットで TODO を伝えるだけで、自動的にコードベースを分析し、実行計画を立て、承認後に実装・PR 作成まで行うオーケストレータ。

## コンセプト

```
チャットで TODO を伝える
  → AI が構造化して inbox/ に配置
  → スケジュールジョブがコード分析・計画生成（planned/）
  → ユーザーが計画を確認・承認（approved/）
  → 自動で Git worktree 内で実装・テスト・PR 作成（done/）
```

- **1タスク = 1ファイル** — Markdown + YAML frontmatter。タスクの全ライフサイクルを1ファイルに記録
- **ディレクトリ = 状態** — ファイルの移動が状態遷移。Finder がカンバンボード
- **並列実行** — プロジェクト単位で並列、同一プロジェクト内は直列
- **6層セーフティ** — Permission Mode / allowedTools / worktree 隔離 / hooks / sandbox / 人間の承認

## インストール

Claude Code 内で:

```
/plugin marketplace add sizukutamago/auto-todo
/plugin install auto-todo@sizukutamago-auto-todo
```

### 初期設定

`data/config.yaml` にプロジェクトを登録:

```yaml
version: 1
projects:
  my-app: ~/workspace/my-app
  my-lib: ~/workspace/my-lib
auto_execute_labels: [docs, lint, format, safe]
notification:
  local: true
  slack_webhook: ""
```

未登録のプロジェクトは `/auto-todo:todo-add` 時に自動でパスを確認・登録します。

### Desktop Scheduled Tasks（任意）

Claude Desktop で自動実行を有効にする場合:

1. Desktop サイドバーの Schedule → "+ New task"
2. **auto-todo-scan-plan**: Hourly / Permission: plan / Folder: 任意
   - プロンプト: `inbox のタスクをスキャンして計画を生成して（todo-scan-plan-scheduled スキル使用）`
3. **auto-todo-execute**: Daily 10:00 AM / Permission: acceptEdits / Folder: 任意
   - プロンプト: `承認済みタスクを実行して（todo-execute-scheduled スキル使用）`

## 使い方

### タスクを追加する

```
/auto-todo:todo-add kondate の UserService にキャッシュ追加して。Redis で。IF は変えないで。
```

情報が十分ならそのまま `inbox/` にファイルを作成。不足していれば AI が質問して補完します。

```
/auto-todo:todo-add CI 直して
  → AI: 「どのプロジェクトですか？」「どのテストが落ちてますか？」
```

### タスク一覧を確認する

```
/auto-todo:todo-status
```

```
## auto-todo ステータス

### inbox (1)
- T-20260323-001: UserService にキャッシュ層を追加 @kondate

### planned (1) ← 承認待ち
- T-20260323-002: README にセットアップ手順を追加 @flow-pilot [docs]

### approved (0)
### done (2)
- T-20260322-001: ESLint warning を解消 @app — PR #41
```

### コードベースを分析して計画を立てる

```
/auto-todo:todo-scan
```

`inbox/` のタスクを分析し、実行計画を生成して `planned/` に移動します。低リスクタスク（docs, lint 等）は自動承認されて `approved/` に直行します。

### 計画を承認する

```
/auto-todo:todo-approve T-20260323-001
```

`planned/` → `approved/` に移動。次回の execute ジョブで実行されます。

承認前に計画を確認したい場合は `planned/T-20260323-001.md` を開いてください。実行計画（変更対象ファイル・実装方針・テスト戦略・リスク）が記載されています。

### タスクを即時実行する

```
/auto-todo:todo-execute T-20260323-001
```

承認済みタスクを Git worktree 内で実装し、テスト・コミット・PR 作成まで行います。引数を省略すると `approved/` の全タスクを実行します。

### タスクをキャンセルする

```
/auto-todo:todo-cancel T-20260323-002
```

## 状態遷移

```
inbox/ ──→ planned/ ──→ approved/ ──→ executing/ ──→ done/
                                          │
                                        failed/
                                          │
                                      approved/（リトライ）
```

| ディレクトリ | 意味 | 誰が移動するか |
|------------|------|--------------|
| inbox/ | 追加直後 | AI（todo-add） |
| planned/ | 計画生成済み、承認待ち | AI（todo-scan） |
| approved/ | 承認済み、実行待ち | ユーザー（todo-approve） |
| executing/ | 実行中 | AI（todo-execute） |
| done/ | 完了 | AI（todo-execute） |
| failed/ | 失敗 | AI（todo-execute） |

## タスクファイルの例

```markdown
---
id: T-20260323-001
what: UserService にキャッシュ層を追加
where: kondate
labels: [backend, performance]
risk: medium
branch: auto-todo/T-20260323-001
pr: 42
created_at: 2026-03-23T09:00:00+09:00
planned_at: 2026-03-23T10:15:00+09:00
executed_at: 2026-03-24T10:30:00+09:00
---

Redis read-through キャッシュ。
UserRepository のインターフェースは変更しない。

## 実行計画
（scan 時に AI が追記）

## 実行結果
（execute 時に AI が追記）
```

## セーフティ

| 層 | 防御対象 | 手段 |
|----|---------|------|
| Permission Mode | 不要なツール実行 | scan: plan / execute: acceptEdits + allowedTools |
| allowedTools | Bash コマンド制限 | ホワイトリスト方式 |
| Git worktree | main ブランチ汚染 | 全実行を worktree で隔離 |
| PreToolUse hook | 危険コマンド | `rm -rf`, `sudo`, `curl`, 秘密ファイルをブロック |
| 人間の承認 | 判断ミス | planned/ → approved/ の明示的な承認ステップ |
| max-turns | 暴走 | ターン数制限で強制停止 |

## ディレクトリ構成

```
auto-todo/
├── .claude-plugin/plugin.json    # マニフェスト
├── skills/                       # 8 スキル
│   ├── todo-add/
│   ├── todo-status/
│   ├── todo-approve/
│   ├── todo-execute/
│   ├── todo-cancel/
│   ├── todo-scan/
│   ├── todo-scan-plan-scheduled/
│   └── todo-execute-scheduled/
├── agents/                       # サブエージェント
│   ├── planner.md                # Opus 1M — コード分析・計画生成
│   └── executor.md               # Sonnet — 実装・テスト
├── hooks/hooks.json              # セーフティ hooks
├── scripts/
│   ├── safety-check.sh           # 危険コマンドブロック
│   └── notify.sh                 # OS 通知 + Slack
├── data/
│   └── config.yaml               # プロジェクト登録・設定
└── docs/
    ├── SPEC.md                   # 詳細仕様書
    └── adr/                      # Architecture Decision Records (6本)
```
