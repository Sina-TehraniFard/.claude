#!/bin/bash
# 指定した WezTerm pane にフォーカスを移す唯一の入口。
# 通知クリック（notify.sh の -execute）とグローバルホットキー（jump-to-notified.sh）の両方がここを通る。
# usage: focus-pane.sh <pane_id>
# exit: 0=成功 / 1=引数なし / 2=pane が存在しない

pane_id="$1"
[ -z "$pane_id" ] && exit 1
WEZTERM=/opt/homebrew/bin/wezterm
JQ=/opt/homebrew/bin/jq

# 生存確認: 存在しない pane なら何もしない（呼び出し側が次善策を取る）
"$WEZTERM" cli list --format json 2>/dev/null \
  | "$JQ" -e --arg p "$pane_id" 'any(.[]; (.pane_id | tostring) == $p)' >/dev/null || exit 2

/usr/bin/open -a WezTerm
exec "$WEZTERM" cli activate-pane --pane-id "$pane_id"
