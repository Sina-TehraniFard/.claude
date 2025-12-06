---
description: "記事を本番環境にインポート・更新"
argument-hint: "[記事パスまたはスラッグ]"
allowed-tools: "Read, Bash, Glob, Edit, AskUserQuestion"
---

# /c-push-prod

記事を本番環境（scriptlab.jp）にインポートまたは更新します。開発サーバ・ローカル環境のどちらからでも実行可能です。

---

## あなたの役割

あなたは記事デプロイの専門家です。以下を自動的に判断して実行します：

- 実行環境の検出（開発サーバ or ローカル）
- 記事ファイルの特定
- バリデーションの実行
- 本番環境へのインポート/更新
- 結果の報告

---

## Step 1: 環境検出と設定

### 1.1 実行環境の判定

以下のコマンドで環境を判定します：

```bash
hostname
```

**環境判定ルール**：
- ホスト名に「sina」や開発サーバの特徴がある → 開発サーバ（直接SSH可能）
- それ以外 → ローカル環境（開発サーバ経由でSSH）

### 1.2 環境別の設定

**開発サーバの場合**：
```
SSH_KEY=~/.ssh/scriptlab-ec2-key.pem
SSH_HOST=ubuntu@PROD_EC2_IP
IMPORTER_DIR=/home/sina/workspace/scriptlab/slab-importer
CONTENT_DIR=/home/sina/workspace/scriptlab/slab-content
```

**ローカル環境の場合**：
```
※ 開発サーバ（DEV_SERVER_IP）を経由してSSH接続
SSH経由でインポートスクリプトを実行
```

---

## Step 2: 記事ファイルの特定

### 2.1 引数のパース

引数の形式を判定：

1. **フルパス**: `/home/sina/workspace/scriptlab/slab-content/daily/xxx.md`
2. **相対パス**: `daily/xxx.md` または `xxx.md`
3. **スラッグ**: `aaa-gwt-difference`（拡張子なし）
4. **空**: 対話的に選択

### 2.2 ファイルの検索

スラッグのみの場合、以下のディレクトリを検索：
- `slab-content/daily/`
- `slab-content/software-engineering/`
- `slab-content/aws/`
- `slab-content/programming-language-theory/`

```bash
find ${CONTENT_DIR} -name "${SLUG}.md" -o -name "*${SLUG}*.md" 2>/dev/null
```

### 2.3 ファイルが見つからない場合

AskUserQuestionで確認：
```
記事ファイルが見つかりません。

以下から選択してください：
- 正しいパスを入力する
- 最近更新した記事から選ぶ
- キャンセル
```

---

## Step 3: バリデーションの実行

### 3.1 バリデーションコマンド

**開発サーバから実行**：
```bash
cd ${IMPORTER_DIR} && \
DOCKER_COMPOSE_FILE=/home/sina/workspace/scriptlab/slab-wp/docker/docker-compose.yml \
./scripts/import-posts.sh --validate "${ARTICLE_PATH}"
```

### 3.2 バリデーション結果の確認

**エラーがある場合**：
- エラー内容をユーザーに表示
- 修正を促す
- `--force` オプションの提案（非推奨）

**警告のみの場合**：
- 警告内容を表示
- 続行するか確認

**成功の場合**：
- そのままインポートに進む

---

## Step 4: 本番環境へのインポート

### 4.1 インポートコマンド

**開発サーバから実行**：
```bash
cd ${IMPORTER_DIR} && \
PROD_SSH_KEY=~/.ssh/scriptlab-ec2-key.pem \
PROD_SSH_HOST=ubuntu@PROD_EC2_IP \
./scripts/import-posts.sh --env production "${ARTICLE_PATH}"
```

**ローカルから実行（開発サーバ経由）**：
```bash
ssh DEV_SERVER_IP 'cd /home/sina/workspace/scriptlab/slab-importer && \
PROD_SSH_KEY=~/.ssh/scriptlab-ec2-key.pem \
PROD_SSH_HOST=ubuntu@PROD_EC2_IP \
./scripts/import-posts.sh --env production "${ARTICLE_PATH}"'
```

### 4.2 インポート結果の確認

成功時のログから以下を抽出：
- 投稿ID
- タイトル
- 新規作成 or 更新

---

## Step 5: 結果報告と後処理

### 5.1 成功時の報告

```
✅ 本番環境へのインポートが完了しました

記事: [タイトル]
投稿ID: [ID]
URL: https://scriptlab.jp/[スラッグ]
ステータス: [新規作成 / 更新]

カテゴリ: [カテゴリ名]
```

### 5.2 articles.md の更新確認

記事管理テーブル（articles.md）の「公開済み」カラムを更新：

```bash
# articles.mdのパス
ARTICLES_MD="${CONTENT_DIR}/articles.md"
```

AskUserQuestionで確認：
```
articles.md の公開済みカラムを更新しますか？
- はい、更新する
- いいえ、後で手動で更新する
```

更新する場合、該当行の「公開済み」カラムに `✓` を追加。

---

## 重要な注意事項

### 環境変数

開発サーバでの作業時は以下が利用可能：
- `PROD_SSH_KEY=~/.ssh/scriptlab-ec2-key.pem`
- `PROD_SSH_HOST=ubuntu@PROD_EC2_IP`

### カテゴリ階層規約

記事は以下の規約を満たす必要があります：
- 親カテゴリに属する場合、子カテゴリも必須
- 複数の親カテゴリを持つ場合、それぞれに子カテゴリが必要

### ドライラン

不安な場合は `--dry-run` オプションでテスト：
```bash
./scripts/import-posts.sh --env production --dry-run "${ARTICLE_PATH}"
```

---

## エラーハンドリング

### SSH接続エラー

```
対応:
1. SSH鍵のパスを確認: ~/.ssh/scriptlab-ec2-key.pem
2. EC2インスタンスの状態を確認
3. セキュリティグループの設定を確認
```

### バリデーションエラー

```
対応:
1. エラーメッセージに従って記事を修正
2. 再度 /c-push-prod を実行
3. どうしても解決できない場合は --force を検討（非推奨）
```

### 記事が見つからない

```
対応:
1. ファイルパスを確認
2. slab-content ディレクトリ内を検索
3. 正しいパスを指定して再実行
```

---

## 使用例

### 例1: スラッグで指定
```
/c-push-prod aaa-gwt-difference
```

### 例2: 相対パスで指定
```
/c-push-prod daily/docker-wordpress-setup.md
```

### 例3: フルパスで指定
```
/c-push-prod /home/sina/workspace/scriptlab/slab-content/daily/aaa-gwt-difference.md
```

### 例4: 対話モード
```
/c-push-prod
（引数なしで実行すると、最近更新したファイルから選択可能）
```
