# ADR-0001: 1タスク1ファイル + ディレクトリベース状態管理

## Status

Accepted (Revised v2)

## Date

2026-03-23

## Context

TODO フォーマットの検討を重ねた結果、以下の制約が明確になった:

1. **ユーザーはチャットで伝えるだけ**: 構造化は AI がやる
2. **priority は不要**: 並列実行するので人間が優先度を指定する意味がない
3. **フォーマット崩れを避けたい**: 単一ファイルに全タスクを詰めると1箇所の構文エラーで全崩壊
4. **context を自由に書きたい**: YAML の `|` ブロックより Markdown 本文のほうが楽
5. **計画・実行結果もタスクと一体管理したい**: 別ファイルに分ける意味が薄い

## Decision

**1タスク = 1 Markdown ファイル（YAML frontmatter + 本文）。ディレクトリ移動で状態遷移を表現する。タスクの全ライフサイクル（入力・計画・実行結果）を同一ファイルに記録する。**

### ディレクトリ構造

```
~/.claude/auto-todo/
├── config.yaml          # グローバル設定
├── inbox/               # 追加直後
├── planned/             # 計画生成済み（承認待ち）
├── approved/            # ユーザー承認済み（実行待ち）
├── executing/           # 実行中
├── done/                # 完了
├── failed/              # 失敗
└── logs/                # 通知ログ等
```

### タスクファイル（全フェーズの例）

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

### 実装方針
1. Redis クライアントのラッパーを作成
2. CachedUserRepository を Decorator パターンで実装

### テスト戦略
- CachedUserRepository のユニットテスト

### リスク
- Redis 接続設定が環境ごとに異なる可能性

## 実行結果

- コミット: abc1234
- PR: #42
- テスト: 全パス（24/24）
- 変更ファイル数: 5
```

### フィールド定義

| フィールド | 設定者 | いつ | 説明 |
|-----------|--------|------|------|
| id | AI | 追加時 | `T-YYYYMMDD-NNN` 自動生成 |
| what | AI（ユーザー入力から正規化） | 追加時 | やりたいこと |
| where | AI（ユーザー入力から推定） | 追加時 | プロジェクト名 or null |
| labels | AI | 追加時 | 自動分類タグ |
| risk | AI | plan 時 | low / medium / high |
| branch | AI | execute 時 | 作業ブランチ名 |
| pr | AI | execute 時 | PR 番号 |
| *_at | AI | 各フェーズ | タイムスタンプ |

### 状態遷移 = ディレクトリ移動

| 遷移 | 移動先 | トリガー |
|------|--------|---------|
| 追加 | inbox/ | ユーザーがチャットで伝える |
| 計画完了 | planned/ | scan+plan ジョブ（「実行計画」セクションを追記） |
| 承認 | approved/ | ユーザーが `/todo-approve` or ファイルを移動 |
| 実行開始 | executing/ | execute ジョブ |
| 成功 | done/ | execute ジョブ（「実行結果」セクションを追記） |
| 失敗 | failed/ | execute ジョブ（失敗理由を追記） |
| リトライ | approved/ | ユーザーが failed/ から移動 |
| 却下 | （削除 or done/） | ユーザー判断 |

## Consequences

### 良い点

- **全ライフサイクルが1ファイル**: タスクの経緯が1箇所で追える。「なぜこう実装したか」が計画と結果から読み取れる
- **ディレクトリ = 状態**: Finder / エディタのサイドバーがそのままカンバンボード。YAML フラグの編集より直感的
- **堅牢**: 1ファイルの構文エラーが他タスクに影響しない
- **context が自由**: Markdown 本文なので何行でも書ける。コードブロック、リンク、画像も可
- **plans/ と history.jsonl が不要**: ファイル構成がシンプルに
- **承認が直感的**: `mv planned/T-001.md approved/` で承認完了。あるいは `/todo-approve`

### 悪い点

- **全タスク一覧に走査が必要**: `ls */` or `/todo-status` でディレクトリを横断する必要がある。→ tasks.yaml なら1ファイルで済む。ただし `/todo-status` スキルで解決可能
- **ファイル数が増える**: 長期運用で done/ に大量ファイル。→ 対策: 月次 or 四半期でアーカイブ

### 廃止したもの

- **tasks.yaml**: 1タスク1ファイルに分解
- **state/tasks.json**: ディレクトリ位置が状態を表現
- **state/history.jsonl**: タスクファイル本文に履歴を記録
- **plans/\<task-id\>.md**: タスクファイルの「実行計画」セクションに統合
- **priority フィールド**: 並列実行のため不要
