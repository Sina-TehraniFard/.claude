#!/bin/bash
# Claude Code 通知システムを新しい Mac で再構築するセットアップスクリプト。
# 何度実行しても安全（冪等）。
#
# 前提:
#   - Homebrew / jq 導入済み
#
# 実行後に手動で必要な設定:
#   - 初回通知時に「Claude Code」からの通知を許可する
#   - システム設定 → 通知 → Claude Code → 通知スタイルを「通知パネル」にする（消えない通知）

set -euo pipefail

echo "==> terminal-notifier（通知送信に使用。Claude Code.app ラッパーの実体）"
command -v terminal-notifier >/dev/null 2>&1 || brew install terminal-notifier

echo "==> 完了。冒頭コメントの「手動で必要な設定」を忘れずに。"
