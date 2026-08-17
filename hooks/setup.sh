#!/bin/bash
# Claude Code 通知システムを新しい Mac で再構築するセットアップスクリプト。
# 何度実行しても安全（冪等）。
#
# 前提:
#   - Xcode Command Line Tools / Homebrew / jq 導入済み
#   - WezTerm 導入済みで、dotfiles の wezterm.lua が ~/.config/wezterm に張られている
#     （通知の自動クリアは wezterm.lua 側のハンドラが担当）
#   - ユーザー名が変わる場合は jp.scriptlab.claude-hotkey.plist 内の絶対パスを修正すること
#
# 実行後に手動で必要な設定:
#   - 初回通知時に「Claude Code」からの通知を許可する
#   - システム設定 → 通知 → Claude Code → 通知スタイルを「通知パネル」にする（消えない通知）

set -euo pipefail
HOOKS="$HOME/.claude/hooks"

echo "==> terminal-notifier（通知送信に使用。Claude Code.app ラッパーの実体）"
command -v terminal-notifier >/dev/null 2>&1 || brew install terminal-notifier

echo "==> Swift バイナリをコンパイル"
mkdir -p "$HOOKS/bin"
xcrun swiftc -O -o "$HOOKS/bin/claude-hotkey" "$HOOKS/claude-hotkey.swift"
xcrun swiftc -O -o "$HOOKS/bin/claude-toast" "$HOOKS/claude-toast.swift" \
  || echo "    (claude-toast は任意機能。失敗しても通知センター方式には影響なし)"

echo "==> グローバルホットキー常駐（Ctrl+Cmd+J）を LaunchAgent として登録"
ln -sf "$HOOKS/jp.scriptlab.claude-hotkey.plist" "$HOME/Library/LaunchAgents/jp.scriptlab.claude-hotkey.plist"
launchctl bootout "gui/$(id -u)/jp.scriptlab.claude-hotkey" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/jp.scriptlab.claude-hotkey.plist"

echo "==> 完了。冒頭コメントの「手動で必要な設定」を忘れずに。"
