#!/bin/bash
# 未閲覧通知のある pane のうち最新のものへジャンプする（skhd のグローバルホットキーから呼ばれる）。
# 状態ファイル: ~/.claude/hooks/state/notified/<pane_id>（notify.sh が touch、wezterm.lua がフォーカス時に削除）
# 死んだ pane の状態ファイルはここで掃除する。未閲覧通知が無ければ WezTerm を前面化するだけ。

STATE_DIR="$HOME/.claude/hooks/state/notified"
FOCUS="$HOME/.claude/hooks/focus-pane.sh"

if cd "$STATE_DIR" 2>/dev/null; then
  for pane_id in $(ls -t 2>/dev/null); do
    if "$FOCUS" "$pane_id"; then
      exit 0
    else
      rm -f "$pane_id"  # 閉じられた pane の残骸
    fi
  done
fi
exec /usr/bin/open -a WezTerm
