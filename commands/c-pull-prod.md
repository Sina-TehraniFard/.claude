---
description: "本番環境のデータをローカルにコピー"
argument-hint: "[--db-only | --uploads-only | --skip-plugins]"
allowed-tools: "Bash, Read, Glob, AskUserQuestion"
disable-model-invocation: true
---

# /c-pull-prod

本番環境（scriptlab.jp）のデータをローカル開発環境に同期します。`/c-push-prod` の逆方向の操作です。

---

## あなたの役割

あなたは環境同期の専門家です。以下を自動的に判断して実行します：

- SSH接続の確立と接続方法の選択
- 本番DBのエクスポートとローカルへのインポート
- メディアファイル（uploads）の同期
- URLの置換（本番URL → ローカルURL）
- プラグイン・設定の整合性確認

**重要**: このコマンドはローカルのDBとuploadsを上書きします。

---

## 接続情報（この定義を唯一の正とする）

以降の手順に登場する IP・鍵パス・URL はすべてここで定義した変数を参照する：

```bash
source ~/.claude/local.env               # DEV_SERVER / DEV_SERVER_TS / PROD_EC2 を読み込む（git管理外）
PROD_SSH_KEY=~/.ssh/scriptlab-ec2-key.pem   # EC2用SSH鍵（ローカルまたは開発サーバ上）
LOCAL_URL=http://${DEV_SERVER}              # ローカルWordPressのサイトURL
```

**フォールバック**: `${DEV_SERVER}` に接続できない場合、ユーザーが外出先にいる可能性がある。Tailscale IP `${DEV_SERVER_TS}` に差し替えて再試行すること。

---

## 引数の扱い

| 引数 | 動作 |
|------|------|
| （なし） | DB + uploads + プラグイン全て同期 |
| `--db-only` | DBのみ同期（uploadsはスキップ） |
| `--uploads-only` | uploadsのみ同期（DBはスキップ） |
| `--skip-plugins` | プラグイン同期をスキップ |

---

## Step 1: 環境検出とSSH接続確認

### 1.1 接続方法の判定

以下の順で接続を試み、最初に成功した方法を使用：

```bash
# 方法1: EC2に直接SSH（ローカルに鍵がある場合）
ssh -o BatchMode=yes -o ConnectTimeout=5 -i ${PROD_SSH_KEY} ${PROD_EC2} 'echo ok'

# 方法2: 開発サーバ経由（鍵が開発サーバにある場合）
ssh -o BatchMode=yes -o ConnectTimeout=5 ${DEV_SERVER} "ssh -o ConnectTimeout=5 -i ${PROD_SSH_KEY} ${PROD_EC2} 'echo ok'"

# 方法2': 方法2で DEV_SERVER に繋がらない場合は Tailscale IP で再試行
ssh -o BatchMode=yes -o ConnectTimeout=5 ${DEV_SERVER_TS} "ssh -o ConnectTimeout=5 -i ${PROD_SSH_KEY} ${PROD_EC2} 'echo ok'"
```

接続成功した方法を `SSH_CMD` として以降で使用：
- 方法1: `SSH_CMD="ssh -i ${PROD_SSH_KEY} ${PROD_EC2}"`
- 方法2: `SSH_CMD="ssh ${DEV_SERVER} 'ssh -i ${PROD_SSH_KEY} ${PROD_EC2}'"`（Tailscale経由の場合は `${DEV_SERVER}` を `${DEV_SERVER_TS}` に読み替え）

すべて失敗した場合はエラーを報告して終了。

### 1.2 ローカル環境の確認

```bash
# Dockerコンテナの状態確認
docker compose -f docker/docker-compose.yml ps

# wpcliが停止していたら起動
docker compose -f docker/docker-compose.yml up -d wpcli
```

### 1.3 環境設定

接続先は冒頭の「接続情報」を参照。

```
本番URL: https://scriptlab.jp
ローカルURL: ${LOCAL_URL}
本番Docker Compose: /home/ubuntu/slab-wp/docker/docker-compose.prod.yml
ローカルDocker Compose: docker/docker-compose.yml
WP-CLI（本番）: docker compose -f docker-compose.prod.yml exec -T wpcli wp
WP-CLI（ローカル）: ./scripts/dev.sh wp
```

---

## Step 2: 同期前の状態確認

本番とローカルの現状を**並列で**取得し、差分を把握：

```bash
# 本番側（並列）
${SSH_CMD} 'cd /home/ubuntu/slab-wp/docker && \
  docker compose -f docker-compose.prod.yml exec -T wpcli wp post list --post_type=post --post_status=publish --format=count && \
  docker compose -f docker-compose.prod.yml exec -T wpcli wp option get siteurl'

# ローカル側（並列）
./scripts/dev.sh wp post list --post_type=post --post_status=publish --format=count
./scripts/dev.sh wp option get siteurl
```

ユーザーに現状を簡潔に報告：

```
📊 同期前の状態:
  本番:   記事 XX件 / uploads XXM
  ローカル: 記事 XX件 / uploads XXM
```

---

## Step 3: データベースの同期

**`--uploads-only` が指定されている場合はこのStepをスキップ**

### 3.1 本番DBのエクスポート

```bash
# 本番でDBダンプを作成
${SSH_CMD} 'cd /home/ubuntu/slab-wp/docker && \
  docker compose -f docker-compose.prod.yml exec -T wpcli wp db export /tmp/prod-dump.sql'

# wpcliコンテナからホストにコピー
${SSH_CMD} 'docker cp slab-wpcli:/tmp/prod-dump.sql /tmp/prod-dump.sql'
```

### 3.2 ローカルへの転送

```bash
# SSH接続方法に応じた転送
# 方法1（直接接続の場合）:
scp -i ${PROD_SSH_KEY} ${PROD_EC2}:/tmp/prod-dump.sql /tmp/prod-dump.sql

# 方法2（開発サーバ経由の場合）:
ssh ${DEV_SERVER} "scp -i ${PROD_SSH_KEY} ${PROD_EC2}:/tmp/prod-dump.sql /tmp/prod-dump.sql"
scp ${DEV_SERVER}:/tmp/prod-dump.sql /tmp/prod-dump.sql
```

### 3.3 ローカルDBのリセットとインポート

**実行前に必ずユーザーの承認を得ること**: `wp db reset` はローカルDBを完全に消去する（ローカルにしか存在しない下書き記事等も消える）。AskUserQuestion でその旨を提示し、承認を得てから実行する。ユーザーが希望する場合は先にローカルDBのバックアップを取る：

```bash
# （任意）ローカルDBの退避ダンプ
./scripts/dev.sh wp db export /tmp/local-backup-$(date +%s).sql
```

承認後に実行：

```bash
# SQLダンプをwpcliコンテナにコピー
docker cp /tmp/prod-dump.sql scriptlab-wpcli:/tmp/prod-dump.sql

# DBリセット＆インポート
./scripts/dev.sh wp db reset --yes
./scripts/dev.sh wp db import /tmp/prod-dump.sql
```

### 3.4 URL置換

```bash
# ドライランで確認
./scripts/dev.sh wp search-replace 'https://scriptlab.jp' "${LOCAL_URL}" --all-tables --dry-run

# 実行
./scripts/dev.sh wp search-replace 'https://scriptlab.jp' "${LOCAL_URL}" --all-tables
```

---

## Step 4: メディアファイルの同期

**`--db-only` が指定されている場合はこのStepをスキップ**

### 4.1 本番uploadsのアーカイブ作成

```bash
${SSH_CMD} 'docker exec slab-wordpress tar -czf /tmp/uploads.tar.gz -C /var/www/html/wp-content uploads && \
  docker cp slab-wordpress:/tmp/uploads.tar.gz /tmp/uploads.tar.gz'
```

### 4.2 ローカルへの転送

```bash
# SSH接続方法に応じた転送（Step 3.2と同様の分岐）
scp -i ${PROD_SSH_KEY} ${PROD_EC2}:/tmp/uploads.tar.gz /tmp/uploads.tar.gz
```

### 4.3 ローカルuploadsの置換

WordPressコンテナ内で実行（www-dataのパーミッション問題を回避）：

```bash
docker cp /tmp/uploads.tar.gz scriptlab-wordpress:/tmp/uploads.tar.gz

docker exec scriptlab-wordpress bash -c '\
  rm -rf /var/www/html/wp-content/uploads && \
  tar -xzf /tmp/uploads.tar.gz -C /var/www/html/wp-content/ && \
  chown -R www-data:www-data /var/www/html/wp-content/uploads && \
  rm /tmp/uploads.tar.gz'
```

---

## Step 5: プラグインの同期

**`--skip-plugins` が指定されている場合はこのStepをスキップ**

### 5.1 プラグイン一覧の比較

```bash
# 本番のアクティブプラグイン一覧
${SSH_CMD} 'cd /home/ubuntu/slab-wp/docker && \
  docker compose -f docker-compose.prod.yml exec -T wpcli wp plugin list --status=active --format=csv --fields=name,version'

# ローカルのプラグイン一覧
./scripts/dev.sh wp plugin list --format=csv --fields=name,status,version
```

### 5.2 差分があればインストール・有効化

本番にあってローカルにないプラグインをインストール：

```bash
./scripts/dev.sh wp plugin install [plugin-name] --activate
```

---

## Step 6: 後処理

### 6.1 キャッシュとリライトのフラッシュ

```bash
./scripts/dev.sh wp rewrite flush
./scripts/dev.sh wp cache flush
```

### 6.2 テンポラリファイルのクリーンアップ

```bash
# ローカル
rm -f /tmp/prod-dump.sql /tmp/uploads.tar.gz

# 本番
${SSH_CMD} 'rm -f /tmp/prod-dump.sql /tmp/uploads.tar.gz'
```

---

## Step 7: 検証と結果報告

### 7.1 本番とローカルの比較

以下を**並列で**取得して比較：

```bash
# ローカル
./scripts/dev.sh wp option get siteurl
./scripts/dev.sh wp post list --post_type=post --post_status=publish --format=count
./scripts/dev.sh wp post list --post_type=page --post_status=publish --format=count
./scripts/dev.sh wp term list category --format=count
./scripts/dev.sh wp plugin list --status=active --format=count

# 本番（同じ項目）
```

### 7.2 結果報告

```
✅ 本番データの同期が完了しました

| 項目         | 本番  | ローカル |
|-------------|-------|---------|
| サイトURL    | https://scriptlab.jp | ${LOCAL_URL} |
| 記事数       | XX件  | XX件    |
| 固定ページ   | XX件  | XX件    |
| カテゴリ     | XX件  | XX件    |
| プラグイン   | XX件  | XX件    |
| uploads     | XXM   | XXM     |

${LOCAL_URL} で動作確認してください。
```

---

## エラーハンドリング

### SSH接続エラー

```
対応:
1. SSH鍵の存在を確認: ls -la ${PROD_SSH_KEY}
2. EC2インスタンスの状態を確認
3. 開発サーバ経由の接続を試行（LAN不可なら Tailscale IP ${DEV_SERVER_TS} を試す）
```

### DBインポートエラー

```
対応:
1. ローカルのMySQLコンテナが起動しているか確認
2. SQLダンプのサイズを確認（0バイトでないか）
3. docker compose logs mysql でエラーを確認
```

### uploads転送エラー

```
対応:
1. ディスク容量を確認: df -h
2. Dockerコンテナのボリュームを確認
3. tarアーカイブのサイズを確認
```

### パーミッションエラー

uploadsの操作で権限エラーが出た場合、Dockerコンテナ経由で操作する。
ホスト側のファイルはwww-data所有のため、直接操作できない場合がある。

---

## 使用例

### 例1: フル同期
```
/c-pull-prod
```

### 例2: DBのみ同期（記事やカテゴリだけ更新したい時）
```
/c-pull-prod --db-only
```

### 例3: 画像だけ同期
```
/c-pull-prod --uploads-only
```

### 例4: プラグイン同期をスキップ
```
/c-pull-prod --skip-plugins
```
