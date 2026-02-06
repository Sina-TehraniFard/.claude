---
name: list-merged-prs
description: 現在のブランチにマージされたPRを列挙。PR一覧、マージ済みPR確認に関するリクエストで使用
allowed-tools: Bash
---

# マージ済みPR一覧取得

現在のブランチにマージされたPRのURLを列挙する。

## 手順

### 1. 現在のブランチを確認
```bash
git branch --show-current
```

### 2. masterからの差分でマージコミットを確認
```bash
git log master..<現在のブランチ> --oneline --merges
```

### 3. PR番号を抽出してURLを列挙
```bash
for pr in <PR番号リスト>; do gh pr view $pr --json url --jq '.url'; done
```

## 出力形式

URLをリスト形式で出力する:
- https://github.com/org/repo/pull/123
- https://github.com/org/repo/pull/456
