# ADR-0006: 通知戦略 — OS ネイティブ通知を主、Slack を補助

## Status

Accepted

## Date

2026-03-23

## Context

auto-todo はバックグラウンドで動作するため、ユーザーへの通知が不可欠。通知なしでは計画の承認や失敗の検知が遅れる。

候補:

1. **OS ネイティブ通知**: macOS `osascript` / Windows PowerShell
2. **Slack webhook**: チャンネルに投稿
3. **メール**: SMTP 送信
4. **ファイルログのみ**: notifications.jsonl に追記
5. **Claude Desktop の通知**: Notification hook 経由

## Decision

**OS ネイティブ通知を主、Slack を補助（オプション）、ファイルログを常時記録。**

通知の実装は `scripts/notify.sh` に抽象化し、設定で切り替え可能にする。

## Consequences

### 良い点

- **即座にユーザーに届く**: macOS の通知センターに表示され、見逃しにくい
- **追加設定不要**: macOS には osascript が標準装備。Slack は任意設定
- **監査ログ**: notifications.jsonl にすべての通知を記録するため、見逃した通知も後から確認可能
- **拡張性**: notify.sh のインターフェースを固定すれば、将来的に他の通知手段（Discord, Teams 等）を追加しやすい

### 通知先の使い分け

| イベント | local | slack | file |
|---------|-------|-------|------|
| scan 完了（変更なし） | - | - | o |
| 計画完了（承認待ち） | o | o | o |
| 自動実行完了 | o | - | o |
| 実行完了（PR 作成） | o | o | o |
| 実行失敗 | o | o | o |
| project 不在 | o | - | o |

### notify.sh インターフェース

```bash
notify.sh <level> <title> <message> [--slack]
# level: info | warning | error
# --slack: Slack にも送信（webhook 設定時のみ）
```

### 悪い点

- **macOS / Windows 固有**: OS ごとに通知コマンドが異なる。→ 対策: notify.sh 内で `uname` 判定して分岐
- **Slack 設定の手間**: webhook URL の取得・設定が必要。→ 対策: Slack はオプション。未設定時はスキップ

### 却下した選択肢

- **メール**: SMTP 設定が重い。個人開発者にはオーバーキル
- **Claude Desktop 通知のみ**: Desktop が開いていないと届かない。OS 通知の方が確実
