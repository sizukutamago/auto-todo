---
name: todo-add
description: >
  Add a new TODO task via natural language chat. AI structures the input into
  a task file and places it in inbox/. Asks follow-up questions via AskUserQuestion
  only when context is insufficient for planning.
  Use when user says "TODO追加", "タスク追加", "todo-add", "やること追加",
  "〇〇して", "〇〇追加して", or wants to add a task to the auto-todo system.
argument-hint: "<自然言語でやりたいことを伝える>"
allowed-tools: Read, Write, Glob, Grep, AskUserQuestion, Bash(mkdir *)
---

# TODO 追加

ユーザーが自然言語で伝えたタスクを構造化し、inbox/ にタスクファイルを作成する。

## 入力

`$ARGUMENTS` — ユーザーが自然言語で伝えたタスク内容

## 処理フロー

### Step 1: config.yaml を読み込む

`${CLAUDE_PLUGIN_ROOT}/data/config.yaml` を Read する。存在しなければ初期化:

```yaml
version: 1
projects: {}
auto_execute_labels: [docs, lint, format, safe]
notification:
  local: true
  slack_webhook: ""
```

ディレクトリ `${CLAUDE_PLUGIN_ROOT}/data/{inbox,planned,approved,executing,done,failed,logs}` が存在しなければ作成する。

### Step 2: ユーザー入力を分析

`$ARGUMENTS` から以下を抽出・推定する:

- **what**: やりたいことの1行要約
- **where**: プロジェクト名（config.projects のキーと照合）。不明なら null
- **context**: 背景情報・制約・詳細

### Step 3: 情報の十分性を判断

以下のいずれかに該当する場合、情報が**不十分**と判断して AskUserQuestion で深堀りする:

- **what が曖昧**: 対象モジュール/ファイル/機能が特定できない（例: 「キャッシュ追加して」→ どのサービス？）
- **where が不明**: プロジェクトが特定できず、推定もできない
- **コード変更を伴うが context がない**: 実装方針や制約が全くない

以下の場合は深堀り**不要**:

- what, where, context が十分に具体的
- docs, lint, format などの定型タスク
- ユーザーが十分な情報を1文で伝えている

深堀りは AskUserQuestion を使い、最大 3 問まで。質問例:

- 「どのサービス/モジュールが対象ですか？」
- 「技術的な制約や方針はありますか？」
- 「このプロジェクトのパスを教えてください」（where 不明時）

### Step 4: where のプロジェクト名解決

- config.projects にキーが存在する → そのまま使用
- 存在しない → AskUserQuestion でパスを確認し、config.projects に自動登録
- プロジェクトなしのタスク → where: null

### Step 5: ID 生成

`T-YYYYMMDD-NNN` 形式で ID を生成する。NNN は当日の既存タスクの最大値 + 1。
既存の inbox/, planned/, approved/, executing/, done/, failed/ を走査して重複を避ける。

### Step 6: labels 自動付与

context と what の内容から以下のラベルを自動付与:

- コード変更 → `[backend]`, `[frontend]`, `[api]` 等
- ドキュメント → `[docs]`
- テスト → `[testing]`
- CI/CD → `[ci]`
- リファクタリング → `[refactor]`
- バグ修正 → `[bugfix]`
- リンター/フォーマッター → `[lint]`, `[format]`

### Step 7: タスクファイル作成

`${CLAUDE_PLUGIN_ROOT}/data/inbox/T-YYYYMMDD-NNN.md` を作成:

```markdown
---
id: T-YYYYMMDD-NNN
what: <1行要約>
where: <プロジェクト名 or null>
labels: [<自動付与ラベル>]
created_at: <ISO 8601>
---

<context: 背景情報・制約・詳細>
```

### Step 8: 結果をユーザーに報告

作成したタスクの内容をユーザーに表示する:

```
inbox/T-20260323-001.md を作成しました:
  what: UserService にキャッシュ層を追加
  where: kondate
  labels: [backend, performance]
```
