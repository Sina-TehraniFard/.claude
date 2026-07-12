---
description: "記事を本番環境にインポート・更新"
argument-hint: "[記事パスまたはスラッグ]"
allowed-tools: "Read, Bash, Glob, Edit, AskUserQuestion"
disable-model-invocation: true
---

# /c-push-prod

記事を本番環境（scriptlab.jp）にインポートまたは更新します。開発サーバ・ローカル環境のどちらからでも実行可能です。

---

## あなたの役割

あなたは記事デプロイの専門家です。以下を自動的に判断して実行します：

- 実行環境の検出（開発サーバ or ローカル）
- 記事ファイルの特定
- バリデーションの実行
- **ユーザー承認の取得（インポート直前に必須）**
- 本番環境へのインポート/更新
- draft → published への移動
- 結果の報告

---

## 接続情報（この定義を唯一の正とする）

以降の手順に登場する IP・鍵パスはすべてここで定義した変数を参照する：

```bash
PROD_SSH_HOST=ubuntu@PROD_EC2_IP           # 本番EC2
PROD_SSH_KEY=~/.ssh/scriptlab-ec2-key.pem   # EC2用SSH鍵（開発サーバ上）
DEV_SERVER=DEV_SERVER_IP                      # 開発サーバ（LAN IP）
DEV_SERVER_TS=DEV_SERVER_TS_IP                 # 開発サーバ（Tailscale IP、LAN不可時のフォールバック）
```

---

## Step 1: 環境検出と設定

### 1.1 実行環境の判定

以下のコマンドで環境を判定します：

```bash
hostname
```

環境判定ルール：
- ホスト名が「sina」→ 開発サーバ（直接SSH可能）
- それ以外 → ローカル環境（開発サーバ経由でSSH）

### 1.2 環境別の設定

開発サーバの場合：
```
IMPORTER_DIR=/home/sina/workspace/scriptlab/slab-importer
CONTENT_DIR=/home/sina/workspace/scriptlab/slab-content
```

ローカル環境の場合：
```
開発サーバ（${DEV_SERVER}）を経由してSSH接続
接続できない場合は Tailscale IP（${DEV_SERVER_TS}）を試す
```

---

## Step 2: 記事ファイルの特定

### 2.1 ディレクトリ構成

記事は以下の2ディレクトリで管理されている：
- `slab-content/draft/` — 下書き記事
- `slab-content/published/` — 公開済み記事

### 2.2 引数のパース

引数の形式を判定：

1. フルパス: `/home/sina/workspace/scriptlab/slab-content/draft/xxx.md`
2. 相対パス: `draft/xxx.md` または `xxx.md`
3. スラッグ: `aaa-gwt-difference`（拡張子なし）
4. 空: 対話的に選択

### 2.3 ファイルの検索

スラッグまたはファイル名のみの場合、まず完全一致で検索する：

```bash
find ${CONTENT_DIR}/draft ${CONTENT_DIR}/published -name "${SLUG}.md" 2>/dev/null
```

完全一致が0件の場合のみ、部分一致で検索する：

```bash
find ${CONTENT_DIR}/draft ${CONTENT_DIR}/published -name "*${SLUG}*.md" 2>/dev/null
```

**候補が複数見つかった場合、または部分一致でしか見つからず対象が曖昧な場合は、勝手に1件を選ばないこと**。候補一覧（フルパス）を提示し、AskUserQuestion でユーザーに選択させる。

### 2.4 引数が空の場合

`draft/` と `published/` の最近更新されたファイルを一覧し、AskUserQuestionで選択を促す：

```bash
ls -lt ${CONTENT_DIR}/draft/ ${CONTENT_DIR}/published/ | head -15
```

### 2.5 ファイルが見つからない場合

AskUserQuestionで確認：
- 正しいパスを入力する
- 最近更新した記事から選ぶ
- キャンセル

---

## Step 3: バリデーションの実行

### 3.1 バリデーションコマンド

開発サーバから実行：
```bash
cd ${IMPORTER_DIR} && \
DOCKER_COMPOSE_FILE=/home/sina/workspace/scriptlab/slab-wp/docker/docker-compose.yml \
./scripts/import-posts.sh --validate "${ARTICLE_PATH}"
```

### 3.2 バリデーション結果の確認

エラーがある場合：
- エラー内容をユーザーに表示
- 修正を促す
- `--force` オプションの提案（非推奨）

警告のみの場合：
- 警告内容を表示
- Step 3.5 の最終確認に進む（警告で止めない）

成功の場合：
- Step 3.5 の最終確認に進む

### 3.5 インポート前の最終確認（必須・スキップ禁止）

本番公開の前に、以下をユーザーに提示し、AskUserQuestion で承認を得る。**承認なしで Step 4 に進んではならない**：

- 対象ファイルのフルパス
- 記事タイトル（フロントマターから取得）
- 公開先: https://scriptlab.jp（新規作成 or 更新の別も分かれば提示）

承認が得られなければ中止し、修正・ファイル再選択など次のアクションを確認する。

---

## Step 4: 本番環境へのインポート

### 4.1 インポートコマンド

接続先は冒頭の「接続情報」を参照。

開発サーバから実行：
```bash
cd ${IMPORTER_DIR} && \
PROD_SSH_KEY=${PROD_SSH_KEY} \
PROD_SSH_HOST=${PROD_SSH_HOST} \
./scripts/import-posts.sh --env production "${ARTICLE_PATH}"
```

ローカルから実行（開発サーバ経由）：
```bash
ssh ${DEV_SERVER} "cd /home/sina/workspace/scriptlab/slab-importer && \
PROD_SSH_KEY=${PROD_SSH_KEY} \
PROD_SSH_HOST=${PROD_SSH_HOST} \
./scripts/import-posts.sh --env production '${ARTICLE_PATH}'"
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
本番環境へのインポートが完了しました

記事: [タイトル]
投稿ID: [ID]
URL: https://scriptlab.jp/[スラッグ]
ステータス: [新規作成 / 更新]
カテゴリ: [カテゴリ名]
```

### 5.2 draft から published への移動

記事が `draft/` にある場合、インポート成功後に `published/` へ移動する。

確認なしで自動的に実行する：
```bash
mv ${CONTENT_DIR}/draft/[ファイル名].md ${CONTENT_DIR}/published/[ファイル名].md
```

記事が既に `published/` にある場合（更新時）は移動不要。

移動後、結果を報告に含める：
```
ファイル移動: draft/ → published/[ファイル名].md
```

---

## 重要な注意事項

### 環境変数

開発サーバでの作業時は以下を使用：
- `PROD_SSH_KEY` / `PROD_SSH_HOST`: 冒頭の「接続情報」を参照
- `DOCKER_COMPOSE_FILE=/home/sina/workspace/scriptlab/slab-wp/docker/docker-compose.yml`

### フロントマターの形式

カテゴリはフラットリスト形式で記載する（ネスト構造ではない）：
```yaml
category:
  - 親カテゴリ
  - 子カテゴリ
```

親カテゴリに属する場合、子カテゴリも必須。

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
1. SSH鍵のパスを確認: ${PROD_SSH_KEY}（冒頭の「接続情報」を参照）
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
2. draft/ と published/ 内を検索
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
/c-push-prod draft/docker-wordpress-setup.md
```

### 例3: フルパスで指定
```
/c-push-prod /home/sina/workspace/scriptlab/slab-content/published/aaa-gwt-difference.md
```

### 例4: 対話モード
```
/c-push-prod
（引数なしで実行すると、最近更新したファイルから選択可能）
```
