#!/bin/bash
# auto-todo safety check hook
# Blocks dangerous commands in PreToolUse for Bash
#
# Input: JSON via stdin with tool_input.command
# Output: JSON with permissionDecision if blocking, exit 0 otherwise

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$CMD" ]; then
  exit 0
fi

# Dangerous patterns to block
BLOCKED_PATTERNS=(
  'rm -rf /'
  'rm -rf ~'
  'rm -rf \.'
  'sudo '
  'chmod 777'
  'mkfs\.'
  'dd if='
)

# Data exfiltration patterns
EXFIL_PATTERNS=(
  'curl .*-d '
  'curl .*--data'
  'curl .*-X POST'
  'wget .*--post'
)

# Secret file patterns
SECRET_PATTERNS=(
  '\.env'
  'credentials'
  'secret'
  '\.pem$'
  '\.key$'
  'id_rsa'
  'id_ed25519'
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$CMD" | grep -qiE "$pattern"; then
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"[auto-todo] Blocked dangerous command: matches pattern '$pattern'\"}}"
    exit 0
  fi
done

for pattern in "${EXFIL_PATTERNS[@]}"; do
  if echo "$CMD" | grep -qiE "$pattern"; then
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"[auto-todo] Blocked potential data exfiltration: matches pattern '$pattern'\"}}"
    exit 0
  fi
done

# Check for secret file access in Read/Write context
for pattern in "${SECRET_PATTERNS[@]}"; do
  if echo "$CMD" | grep -qiE "(cat|head|tail|less|more|vim|nano|code).*$pattern"; then
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"[auto-todo] Blocked access to secret file: matches pattern '$pattern'\"}}"
    exit 0
  fi
done

# Allow everything else
exit 0
