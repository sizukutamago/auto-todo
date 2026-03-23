#!/bin/bash
# auto-todo notification script
# Usage: notify.sh <level> <title> <message> [--slack]
#
# level: info | warning | error
# --slack: also send to Slack webhook (if configured)

LEVEL="${1:-info}"
TITLE="${2:-auto-todo}"
MESSAGE="${3:-}"
SLACK_FLAG="${4:-}"

AUTO_TODO_DIR="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}/data"
CONFIG_FILE="$AUTO_TODO_DIR/config.yaml"
LOG_FILE="$AUTO_TODO_DIR/logs/notifications.jsonl"

# Ensure logs directory exists
mkdir -p "$AUTO_TODO_DIR/logs"

# Log to file (always)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "{\"at\":\"$TIMESTAMP\",\"level\":\"$LEVEL\",\"title\":\"$TITLE\",\"message\":\"$MESSAGE\"}" >> "$LOG_FILE"

# macOS native notification
if [[ "$OSTYPE" == "darwin"* ]]; then
  osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\"" 2>/dev/null
fi

# Windows notification (PowerShell)
if [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]]; then
  powershell.exe -Command "
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    \$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
    \$textNodes = \$template.GetElementsByTagName('text')
    \$textNodes.Item(0).AppendChild(\$template.CreateTextNode('$TITLE'))
    \$textNodes.Item(1).AppendChild(\$template.CreateTextNode('$MESSAGE'))
    \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$template)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('auto-todo').Show(\$toast)
  " 2>/dev/null
fi

# Slack notification (optional)
if [[ "$SLACK_FLAG" == "--slack" ]]; then
  # Read webhook URL from config
  SLACK_WEBHOOK=""
  if [ -f "$CONFIG_FILE" ]; then
    SLACK_WEBHOOK=$(grep 'slack_webhook:' "$CONFIG_FILE" | sed 's/.*slack_webhook: *//' | tr -d '"' | tr -d "'")
  fi

  if [ -n "$SLACK_WEBHOOK" ] && [ "$SLACK_WEBHOOK" != "" ]; then
    ICON=""
    case "$LEVEL" in
      error)   ICON=":x:" ;;
      warning) ICON=":warning:" ;;
      *)       ICON=":white_check_mark:" ;;
    esac

    curl -s -X POST "$SLACK_WEBHOOK" \
      -H 'Content-Type: application/json' \
      -d "{\"text\":\"$ICON *$TITLE*\n$MESSAGE\"}" \
      > /dev/null 2>&1
  fi
fi
