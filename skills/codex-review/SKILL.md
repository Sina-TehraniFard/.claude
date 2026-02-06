---
name: codex-review
description: OpenAI Codexにコードレビューを依頼。codexにレビューさせて、codexでレビューして、などのリクエストで使用
argument-hint: "[対象ファイルやブランチ]"
allowed-tools: Bash
---

# Codex コードレビュー

OpenAI Codex CLI を使用してコードレビューを実行します。

## 基本コマンド

```bash
codex exec review
```

## よく使うオプション

| オプション | 説明 |
|-----------|------|
| `--uncommitted` | ステージ済み、未ステージ、未追跡の変更をレビュー |
| `--base <BRANCH>` | 指定ブランチとの差分をレビュー |
| `--commit <SHA>` | 特定コミットの変更をレビュー |
| `-m <MODEL>` | 使用するモデルを指定 |
| `--skip-git-repo-check` | Gitリポジトリ外で実行 |

## 使用例

### 未コミットの変更をレビュー
```bash
codex exec review --uncommitted
```

### mainブランチとの差分をレビュー
```bash
codex exec review --base main
```

### 特定コミットをレビュー
```bash
codex exec review --commit <SHA>
```

### カスタム指示でレビュー
```bash
codex exec review "セキュリティの観点でレビューしてください"
```

## 注意事項

- Gitリポジトリ内で実行すること（または`--skip-git-repo-check`を使用）
- レビュー結果は標準出力に表示される
