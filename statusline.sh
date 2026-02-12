#!/bin/bash
# ======================================================================
# Claude Code Status Line
# 1行目: claude-powerline (powerline + tokyo-night)
# 2行目: コンテキスト使用率ゲージ (色変化)
# ======================================================================

set -euo pipefail

# stdin から JSON を読み取り (powerline とゲージの両方で使う)
data=$(cat)

# --- 1行目: claude-powerline ---
echo "$data" | npx -y @owloops/claude-powerline@latest --style=powerline --theme=tokyo-night 2>/dev/null

# --- 2行目: コンテキスト使用率ゲージ ---
pct=$(echo "$data" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

RESET='\033[0m'
BOLD='\033[1m'

# コンテキスト使用率に応じた色 (緑 → 黄 → オレンジ → 赤)
if [ "$pct" -lt 25 ]; then
  BAR_FG='\033[38;5;82m'    # 明るい緑
  BAR_BG='\033[38;5;236m'   # 暗いグレー
  PCT_FG='\033[38;5;82m'
elif [ "$pct" -lt 50 ]; then
  BAR_FG='\033[38;5;226m'   # 黄色
  BAR_BG='\033[38;5;236m'
  PCT_FG='\033[38;5;226m'
elif [ "$pct" -lt 75 ]; then
  BAR_FG='\033[38;5;208m'   # オレンジ
  BAR_BG='\033[38;5;236m'
  PCT_FG='\033[38;5;208m'
else
  BAR_FG='\033[38;5;196m'   # 赤
  BAR_BG='\033[38;5;236m'
  PCT_FG='\033[38;5;196m'
fi

# プログレスバー (━ ベースのクリーンなスタイル)
bar_width=30
filled=$((pct * bar_width / 100))
empty=$((bar_width - filled))

bar=""
for ((i = 0; i < filled; i++)); do
  bar+="━"
done
# 先端マーカー
if [ "$filled" -lt "$bar_width" ]; then
  bar+="╸"
  empty=$((empty - 1))
fi
bar_empty=""
for ((i = 0; i < empty; i++)); do
  bar_empty+="━"
done

# 警告メッセージ
warn=""
if [ "$pct" -ge 90 ]; then
  warn=" ${PCT_FG}${BOLD}⚠ COMPACT SOON${RESET}"
elif [ "$pct" -ge 75 ]; then
  warn=" ${PCT_FG}${BOLD}${RESET}"
fi

printf " ${BAR_FG}${bar}${RESET}${BAR_BG}${bar_empty}${RESET} ${PCT_FG}${BOLD}${pct}%%${RESET}${warn}"
