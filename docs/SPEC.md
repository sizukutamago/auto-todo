# auto-todo 詳細仕様書

## 概要

auto-todo は Claude Code プラグイン。ユーザーがチャットで伝えた TODO を自動的に計画・実行する「承認可能な実行計画を継続生成するオーケストレータ」。

## コアコンセプト

- **1タスク = 1ファイル**: Markdown + YAML frontmatter。全ライフサイクルを1ファイルに記録
- **ディレクトリ = 状態**: `inbox/ → planned/ → approved/ → done/` のファイル移動が状態遷移
- **チャット入力**: ユーザーは自然言語で伝えるだけ。構造化は AI がやる。情報不足時のみ AskUserQuestion で深堀り
- **並列実行**: プロジェクト単位で並列、同一プロジェクト内は直列

---

## 1. ユーザーワークフロー

### 1.1 日常の流れ

```
ユーザー: /auto-todo:todo-add kondate の UserService にキャッシュ追加して。Redis で。
  ↓
Claude: inbox/T-20260323-001.md を作成しました
  ↓
（自動）scan+plan ジョブ（Hourly）
  → コードベース分析 → 計画を追記 → planned/ に移動
  ↓
通知: 「T-001 の計画ができました」
  ↓
ユーザー: planned/T-001.md を読む → /auto-todo:todo-approve T-001
  （ファイルが approved/ に移動）
  ↓
（自動）execute ジョブ（Daily）
  → worktree で実装 → テスト → PR 作成 → done/ に移動
  ↓
通知: 「T-001 完了。PR #42」
  ↓
ユーザー: PR レビュー → マージ
```

### 1.2 シナリオ

#### A: 通常のコード変更

```
1. ユーザーがチャットで TODO を伝える:

   /auto-todo:todo-add kondate のキャッシュ追加して

   → Claude が情報を分析:
     what: 「キャッシュ追加」— 対象モジュールが不明
     where: kondate — OK
     context: なし — 不十分

   → AI 判断: 情報不足 → AskUserQuestion で深堀り:
     Q1: "どのサービス/モジュールが対象ですか？"
         [UserService] [ProductService] [全体] [Other]
     Q2: "キャッシュの方式に希望はありますか？"
         [Redis] [インメモリ] [AI に任せる]
     Q3: "制約・注意点はありますか？"
         [既存 IF を変えない] [特になし] [Other]

   ユーザー: UserService, Redis, 既存 IF を変えない

   → Claude が inbox/T-20260323-001.md を作成:
     ---
     id: T-20260323-001
     what: UserService にキャッシュ層を追加
     where: kondate
     labels: [backend, performance]
     created_at: 2026-03-23T09:00:00+09:00
     ---
     Redis read-through キャッシュ。
     UserRepository のインターフェースは変更しない。

   ※ 情報が十分な場合は深堀りせず即座に作成:
   /auto-todo:todo-add kondate の UserService にキャッシュ追加して。
              Redis read-through で。IF は変えないで。
   → 深堀り不要と判断 → 即座に inbox/ に作成

2. scan+plan ジョブ:
   a. inbox/ のファイルを検出
   b. where: kondate → プロジェクトパスを解決
   c. コードベースを分析（plan モード: 読み取りのみ）
   d. 「実行計画」セクションをファイルに追記
   e. risk, planned_at を frontmatter に追記
   f. ファイルを planned/ に移動
   g. 通知

3. ユーザーが確認・承認:
   /auto-todo:todo-approve T-20260323-001
   → ファイルが approved/ に移動

4. execute ジョブ:
   a. approved/ のファイルをプロジェクト別にグループ化
   b. プロジェクト単位で並列実行
   c. Git worktree 作成（ブランチ: auto-todo/T-20260323-001）
   d. 計画に沿って実装
   e. テスト実行
   f. コミット＆ PR 作成
   g. 「実行結果」セクションをファイルに追記
   h. ファイルを done/ に移動
   i. 通知
```

#### B: 低リスク自動実行（docs, lint 等）

```
1. /auto-todo:todo-add flow-pilot の README にセットアップ手順追加して
   → inbox/T-20260323-002.md（labels: [docs]）

2. scan+plan ジョブ:
   - labels に "docs" → auto_execute_labels に該当
   - risk: low と判定
   - 計画追記 → planned/ → 自動で approved/ → そのまま execute
   - worktree 内で実装 → PR 作成 → done/ に移動
   - 通知: "T-002 自動実行完了: PR #43"

※ worktree 隔離は自動実行でも必須
```

#### C: 実行失敗

```
1. execute ジョブが T-003 を実行 → テスト失敗
2. 「実行結果」セクションに失敗理由を追記
3. ファイルを failed/ に移動
4. worktree は残す（デバッグ用）
5. 通知: "T-003 失敗: テストエラー"
6. ユーザーが判断:
   - リトライ: /auto-todo:todo-approve T-003（→ approved/ に移動）
   - 修正: ファイルの context を編集 → inbox/ に戻す
   - 取り消し: /auto-todo:todo-cancel T-003
```

#### D: プロジェクトに紐づかないタスク

```
1. /auto-todo:todo-add auto-todo の設計ドキュメントをまとめて
   → inbox/T-20260323-004.md（where: null）

2. scan+plan: where: null → CWD で実行。worktree 不要
3. execute: worktree なしで直接実行
```

---

## 2. データモデル

### 2.1 タスクファイル（1タスク = 1ファイル）

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
approved_at: 2026-03-23T12:00:00+09:00
executed_at: 2026-03-24T10:30:00+09:00
---

Redis read-through キャッシュ。
UserRepository のインターフェースは変更しない。

## 実行計画

### 変更対象ファイル

| ファイル | 変更内容 |
|---------|---------|
| src/cache/redis-client.ts | 新規: Redis 接続クライアント |
| src/repository/cached-user-repository.ts | 新規: キャッシュ付き UserRepository |
| src/di/container.ts | 修正: DI バインディング追加 |
| tests/repository/cached-user-repository.test.ts | 新規: テスト |

### 実装方針
1. Redis クライアントのラッパーを作成
2. CachedUserRepository を Decorator パターンで実装
3. DI コンテナにバインディングを追加
4. テスト追加

### テスト戦略
- CachedUserRepository のユニットテスト（Redis モック）
- 既存テストの回帰確認

### リスク
- Redis 接続設定が環境ごとに異なる可能性

## 実行結果

- コミット: abc1234
- PR: #42
- テスト: 全パス（24/24）
- 変更ファイル数: 4
```

### フィールドのライフサイクル

| フィールド | 追加時 | plan 時 | execute 時 |
|-----------|--------|---------|-----------|
| id | o | | |
| what | o | | |
| where | o | | |
| labels | o | 調整可 | |
| risk | | o | |
| branch | | | o |
| pr | | | o |
| created_at | o | | |
| planned_at | | o | |
| approved_at | | | （approve 時） |
| executed_at | | | o |

### 本文のライフサイクル

| セクション | 追加時 | plan 時 | execute 時 |
|-----------|--------|---------|-----------|
| （冒頭: context） | o | | |
| 実行計画 | | o | |
| 実行結果 | | | o |

### 2.2 config.yaml

```yaml
version: 1
projects:
  kondate: ~/workspace/github.com/sizukutamago/kondate
  flow-pilot: ~/workspace/github.com/sizukutamago/flow-pilot
  app: ~/workspace/github.com/sizukutamago/app
auto_execute_labels: [docs, lint, format, safe]
notification:
  local: true
  slack_webhook: ""
```

| フィールド | 説明 |
|-----------|------|
| projects | プロジェクト名→パスの解決辞書。未知の名前は todo-add 時に確認して自動登録 |
| auto_execute_labels | このラベルを持つ低リスクタスクは承認なしで自動実行 |
| notification.local | OS ネイティブ通知の有効/無効 |
| notification.slack_webhook | Slack 通知用 webhook URL（空なら無効） |

### 2.3 状態遷移 = ディレクトリ移動

```
inbox/ ──→ planned/ ──→ approved/ ──→ executing/ ──→ done/
                │                         │
                ↓                         ↓
            （削除）                   failed/
                                         │
                                         ↓
                                     approved/（リトライ）
                                     or inbox/（修正して再投入）
```

### 2.4 並列実行モデル

```
approved/ 内のタスク:
  T-001 (where: kondate)
  T-002 (where: kondate)
  T-003 (where: flow-pilot)
  T-004 (where: null)

実行グループ化:
  ┌─ Worker 1: kondate      → T-001 → T-002（直列）
  ├─ Worker 2: flow-pilot   → T-003
  └─ Worker 3: (no project) → T-004
  （3 ワーカーが並列実行）
```

- **異なるプロジェクト**: 並列（worktree が別）
- **同一プロジェクト**: 直列（ブランチ競合回避）
- **where: null**: 独立ワーカーで並列

### 2.5 自動実行の判定

```
auto_execute?
  ├─ labels ∩ config.auto_execute_labels ≠ ∅
  │   └─ AND risk == low → YES: planned/ → approved/ → executing/ → done/ を一気通貫
  └─ それ以外 → NO: planned/ で停止（承認待ち）
```

---

## 3. スケジュール設計

### 3.1 Scheduled Task 構成

| タスク名 | 頻度 | Permission | 目的 |
|---------|------|-----------|------|
| auto-todo-scan-plan | Hourly | plan | inbox/ → planned/ |
| auto-todo-execute | Daily 10:00 AM | acceptEdits + allowedTools | approved/ → done/ |

### 3.2 scan+plan ジョブ

```
1. inbox/ のファイルを一覧
2. 各ファイルについて:
   a. frontmatter を読み込み
   b. where のプロジェクトパスを解決（config.projects 参照）
   c. where != null → ディレクトリ存在確認（なければスキップ＆通知）
   d. プロジェクトのコードベースを分析（plan モード: 読み取りのみ）
   e. 「実行計画」セクションをファイルに追記
   f. risk, planned_at を frontmatter に追記
   g. ファイルを planned/ に移動
3. auto_execute 対象の判定:
   a. 該当タスクは planned/ → approved/ → execute まで一気通貫
4. 結果を通知
```

### 3.3 execute ジョブ

```
1. approved/ のファイルを一覧
2. where でグループ化
3. 各グループを並列で処理（同一グループ内は直列）:
   a. ファイルを executing/ に移動
   b. where != null:
      - Git worktree を作成
      - worktree 内で実装
   c. where == null:
      - CWD で直接実行
   d. テスト実行
   e. 成功:
      - コミット → PR 作成
      - 「実行結果」セクション追記
      - branch, pr, executed_at を frontmatter に追記
      - ファイルを done/ に移動
   f. 失敗:
      - 「実行結果」セクションに失敗理由追記
      - ファイルを failed/ に移動
      - worktree は残す
4. 結果を通知
```

---

## 4. スキル一覧

| スキル | トリガー | 目的 |
|--------|---------|------|
| todo-add | `/auto-todo:todo-add <自然言語>` | チャットでタスク追加。AI が構造化して inbox/ に配置。情報不足時は AskUserQuestion で深堀り |
| todo-status | `/auto-todo:todo-status` | 全ディレクトリを走査してタスク一覧を表示 |
| todo-approve | `/auto-todo:todo-approve <task-id>` | planned/ → approved/ に移動 |
| todo-execute | `/auto-todo:todo-execute [task-id]` | 承認済みタスクを即時実行 |
| todo-cancel | `/auto-todo:todo-cancel <task-id>` | タスクファイルを削除 |
| todo-scan | `/auto-todo:todo-scan` | 手動で scan+plan を実行 |

---

## 5. 通知設計

| イベント | local | slack | logs/ |
|---------|-------|-------|-------|
| scan 完了（変更なし） | - | - | o |
| 計画完了（承認待ち） | o | o | o |
| 自動実行完了 | o | - | o |
| 実行完了（PR 作成） | o | o | o |
| 実行失敗 | o | o | o |
| project 不在 | o | - | o |

```
[auto-todo] T-20260323-001 計画完了: UserService にキャッシュ層を追加
  Project: kondate
  Action: /auto-todo:todo-approve T-20260323-001
```

---

## 6. ファイル配置

### プラグインディレクトリ

```
auto-todo/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── todo-add/SKILL.md
│   ├── todo-status/SKILL.md
│   ├── todo-approve/SKILL.md
│   ├── todo-execute/SKILL.md
│   ├── todo-cancel/SKILL.md
│   ├── todo-scan/SKILL.md
│   ├── todo-scan-plan-scheduled/SKILL.md
│   └── todo-execute-scheduled/SKILL.md
├── agents/
│   ├── planner.md
│   └── executor.md
├── hooks/
│   └── hooks.json
└── scripts/
    ├── notify.sh
    └── safety-check.sh
```

### ランタイムデータ

```
~/.claude/auto-todo/
├── config.yaml
├── inbox/
│   └── T-20260323-001.md
├── planned/
│   └── T-20260323-002.md
├── approved/
├── executing/
├── done/
│   └── T-20260322-001.md
├── failed/
└── logs/
    └── notifications.jsonl
```

### Desktop Scheduled Tasks

```
~/.claude/scheduled-tasks/
├── auto-todo-scan-plan/
│   └── SKILL.md
└── auto-todo-execute/
    └── SKILL.md
```
