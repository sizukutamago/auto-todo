# ADR-0004: 6 層セーフティ設計

## Status

Accepted

## Date

2026-03-23

## Context

auto-todo は「ユーザーが見ていない間にコードを変更するエージェント」であり、安全性の担保は最重要の設計課題。単一のセーフティ機構では不十分で、多層防御が必要。

検討した防御手段:

1. Permission Mode（plan / acceptEdits / dontAsk）
2. allowedTools / disallowedTools
3. Git worktree 隔離
4. PreToolUse hooks によるガードレール
5. OS Sandbox（Seatbelt）
6. 人間の承認ゲート
7. max-turns / budget 制限
8. bypassPermissions（却下）

## Decision

以下の 6 層を組み合わせて採用する。**bypassPermissions は使用しない。**

### Layer 1: Permission Mode

| フェーズ | Mode | 理由 |
|---------|------|------|
| scan+plan | `plan` | 読み取りのみ。Write/Edit/Bash を構造的に禁止 |
| execute | `acceptEdits` + `allowedTools` | ファイル編集は許可するが、Bash は明示ホワイトリストのみ |

### Layer 2: allowedTools 制限

```
scan+plan: Read, Glob, Grep, Bash(git status *), Bash(git log *), Bash(git diff *)
execute:   Read, Edit, Write, Glob, Grep,
           Bash(npm test *), Bash(npm run build *), Bash(npx *),
           Bash(git add *), Bash(git commit *), Bash(git checkout -b *),
           Bash(gh pr create *)
```

### Layer 3: Git worktree 隔離

execute フェーズは常に worktree 内で実行。main ブランチに直接変更を加えない。

### Layer 4: PreToolUse hooks

```json
{
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [{ "type": "command", "command": "scripts/safety-check.sh" }]
    }
  ]
}
```

safety-check.sh がブロックするパターン:
- `rm -rf`, `rm -r` (引数なし or 広範囲)
- `sudo`
- `curl`, `wget` (データ送信防止)
- `chmod 777`
- `.env`, `credentials`, `secret` を含むファイルへの read/write
- worktree 外のパスへの write

### Layer 5: 人間の承認ゲート

2 箇所で人間が判断する:
1. **計画承認**: plans/*.md の `approved: true`
2. **PR レビュー**: execute 結果の PR マージ

### Layer 6: max-turns 制限

execute フェーズに `--max-turns 50` を設定。無限ループを防止。

## Consequences

### 良い点

- **Defense in Depth**: いずれか1層が突破されても他の層が防御する
- **bypassPermissions 不使用**: 最も危険なモードを排除。Codex も「公式にも強い注意があり、設計としては過剰権限」と指摘
- **worktree 隔離**: 最悪のケースでも main ブランチは無傷。worktree を削除するだけで復旧
- **PR ゲート**: コード変更は必ず PR 経由。直接マージされない

### 悪い点

- **設定の複雑さ**: 6 層の設定を正しく維持する負担がある。→ 対策: プラグインの hooks.json と settings.json でデフォルト値を提供
- **false positive**: safety-check.sh が正当なコマンドをブロックする可能性。→ 対策: ブロックログを残し、ユーザーが allowlist を調整可能にする

### 却下した選択肢

- **bypassPermissions**: 全ツールが承認なしで実行可能になる。hooks は残るが、設計として「何でもできる状態から制限する」は「何もできない状態から許可する」より危険。acceptEdits + allowedTools + hooks で十分
- **Sandbox のみ**: OS レベルの制御は粒度が粗い。ファイルシステムレベルでは許可するが、Claude のツールレベルでは禁止したい操作がある（例: .env の Read は OS 的には許可するが Claude には読ませたくない）
