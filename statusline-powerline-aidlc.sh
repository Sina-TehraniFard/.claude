#!/bin/sh
# claude-powerline（使用率表示）+ AI-DLC ステータスラインの合成。
# AI-DLC が入っていないプロジェクトでは powerline のみ表示される。
input=$(cat)
printf '%s' "$input" | npx -y @owloops/claude-powerline@1.27.1 --config /Users/tehrani/.claude/claude-powerline.json 2>/dev/null
if [ -n "$CLAUDE_PROJECT_DIR" ] && [ -f "$CLAUDE_PROJECT_DIR/.claude/hooks/aidlc-statusline.ts" ]; then
  printf '%s' "$input" | bun "$CLAUDE_PROJECT_DIR/.claude/hooks/aidlc-statusline.ts" 2>/dev/null
fi
