---
name: git-merge
description: ブランチをマージしてコンフリクトを解消。マージ、コンフリクト解消、競合解決に関するリクエストで使用
argument-hint: "<マージ元ブランチ名>"
allowed-tools: Bash, Read, Edit
---

# Git マージ & コンフリクト解消

## 禁止事項

```bash
# 絶対に使わない - ファイル全体を上書きしてマージ先の変更が消える
git checkout --ours <file>
git checkout --theirs <file>
```

## 正しい手順

### 1. マージ実行
```bash
git merge <branch-name>
```

### 2. 競合箇所を特定
```bash
grep -n "<<<<<<" <file>
```

### 3. 競合マーカーの部分だけを編集

```
<<<<<<< HEAD
（自分のコード）
=======
（マージ先のコード）
>>>>>>> branch-name
```

**この部分だけを編集。他は触らない。**

### 4. コミット
```bash
git add <file>
git commit  # メッセージは自動生成
```

## 重要

- 編集するのは競合マーカー（`<<<<<<<`〜`>>>>>>>`）の部分のみ
- 競合していない部分は自動でマージ済み、触らない
