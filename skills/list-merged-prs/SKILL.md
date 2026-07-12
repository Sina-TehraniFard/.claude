---
name: list-merged-prs
description: 現在のブランチに取り込まれたマージ済みPRのURLを列挙。「マージ済みPR一覧」「このブランチにマージされたPRを確認」のようなマージ済みPRに関するリクエストで使用
allowed-tools: Bash
---

# マージ済みPR一覧取得

現在のブランチにマージされたPRのURLを列挙する。

## 手順

### 1. 現在のブランチを確認
```bash
git branch --show-current
```

### 2. 現在のブランチをベースにマージされたPRを取得
```bash
gh pr list --state merged --base <現在のブランチ> --json number,title,url
```

Squash merge / Rebase merge 運用でもGitHub側のマージ済み情報を直接参照するため漏れなく取得できる。件数が多い場合は `--limit` で調整する。

## 出力形式

URLをリスト形式で出力する:
- https://github.com/org/repo/pull/123
- https://github.com/org/repo/pull/456
