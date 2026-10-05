#!/bin/bash
# Claude Code の Stop / Notification hook から呼ばれる通知スクリプト。
# 送り元は Claude アイコン付きの専用バンドル（terminal-notifier のラッパー）。
# stdin: hook の JSON（Notification イベントなら .message を通知本文に使う）
# $1: .message が無い場合のフォールバック文言

VOLUME=0.2  # 通知音の音量（0.0〜1.0）
SOUND=/System/Library/Sounds/Tink.aiff
DISMISS_AFTER=2  # 通知を自動で消すまでの秒数
NOTIFIER="$HOME/.claude/hooks/Claude Code.app/Contents/MacOS/terminal-notifier"

input=$(cat)
msg=$(jq -r '.message // empty' <<<"$input" 2>/dev/null)
[ -z "$msg" ] && msg="${1:-応答が完了しました}"

# アイドル通知はStop hookの「応答が完了しました」と重複するので無視
case "$msg" in
  *"waiting for your input"*) exit 0 ;;
esac
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
project=$(basename "${cwd:-$PWD}")

# 同じプロジェクトの通知は最新の1件に置き換え、DISMISS_AFTER 秒後に自動で消す
group="claude-code-$project"
"$NOTIFIER" -title "$project" -message "$msg" -group "$group" >/dev/null 2>&1
nohup bash -c "sleep $DISMISS_AFTER; \"\$0\" -remove \"\$1\"" "$NOTIFIER" "$group" >/dev/null 2>&1 &
afplay -v "$VOLUME" "$SOUND" >/dev/null 2>&1 &
exit 0
