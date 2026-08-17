#!/bin/bash
# Claude Code の Stop / Notification hook から呼ばれる通知スクリプト。
# このセッションが動いている WezTerm pane にフォーカスしている間は通知を抑制する。
# 通知クリックで WezTerm の該当 pane（タブ）にフォーカスが移る。
# 送り元は Claude アイコン付きの専用バンドル（terminal-notifier のラッパー）。
# stdin: hook の JSON（Notification イベントなら .message を通知本文に使う）
# $1: .message が無い場合のフォールバック文言

VOLUME=0.2  # 通知音の音量（0.0〜1.0）
SOUND=/System/Library/Sounds/Tink.aiff
STYLE=system  # toast=自前のふわっとトースト / system=macOS通知センター
NOTIFIER="$HOME/.claude/hooks/Claude Code.app/Contents/MacOS/terminal-notifier"
TOAST="$HOME/.claude/hooks/bin/claude-toast"

input=$(cat)
msg=$(jq -r '.message // empty' <<<"$input" 2>/dev/null)
[ -z "$msg" ] && msg="${1:-応答が完了しました}"

# アイドル通知はStop hookの「応答が完了しました」と重複するので無視
case "$msg" in
  *"waiting for your input"*) exit 0 ;;
esac
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
project=$(basename "${cwd:-$PWD}")

front=$(lsappinfo info -only name "$(lsappinfo front)" 2>/dev/null)
if [[ "$front" == *"WezTerm"* && -n "$WEZTERM_PANE" ]]; then
  if /opt/homebrew/bin/wezterm cli list-clients --format json 2>/dev/null \
    | jq -r '.[].focused_pane_id' | grep -qx "$WEZTERM_PANE"; then
    exit 0
  fi
fi

if [ -n "$WEZTERM_PANE" ]; then
  click="$HOME/.claude/hooks/focus-pane.sh $WEZTERM_PANE"
  # 未閲覧通知の状態を記録（wezterm.lua がフォーカス復帰時に削除、jump-to-notified.sh が参照）
  mkdir -p "$HOME/.claude/hooks/state/notified"
  touch "$HOME/.claude/hooks/state/notified/$WEZTERM_PANE"
else
  click="/usr/bin/open -a WezTerm"
fi

if [ "$STYLE" = "toast" ] && [ -x "$TOAST" ]; then
  # トーストは自前でクリック処理・フォーカス自動消去を持つ（クリックハンドラ不要）
  nohup "$TOAST" -title "$project" -message "$msg" \
    ${WEZTERM_PANE:+-pane "$WEZTERM_PANE"} >/dev/null 2>&1 &
else
  "$NOTIFIER" -title "$project" -message "$msg" \
    -group "claude-code-${WEZTERM_PANE:-default}" -execute "$click" >/dev/null 2>&1
fi
afplay -v "$VOLUME" "$SOUND" >/dev/null 2>&1 &
exit 0
