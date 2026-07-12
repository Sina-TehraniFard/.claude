---
name: codex-review
description: OpenAI Codexにコードレビューを依頼。codexにレビューさせて、codexでレビューして、などのリクエストで使用
argument-hint: "[対象ファイルやブランチ]"
allowed-tools: Bash(codex exec review:*)
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

その他のオプション（特定コミットの指定、モデル指定など）は `codex exec review --help` を参照すること。

## 使用例

### 未コミットの変更をレビュー
```bash
codex exec review --uncommitted
```

### mainブランチとの差分をレビュー
```bash
codex exec review --base main
```

### カスタム指示でレビュー
```bash
codex exec review "セキュリティの観点でレビューしてください"
```

## 注意事項

- Gitリポジトリ内で実行すること（または`--skip-git-repo-check`を使用）
- レビュー結果は標準出力に表示される
- 大きな差分ではレビューに数分かかることがあるため、Bash ツールで実行する際は timeout を 600000ms（10分）程度に設定すること
