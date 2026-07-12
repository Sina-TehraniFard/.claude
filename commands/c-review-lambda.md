---
description: "AWS Lambda(Python)をLambda固有観点（コールドスタート・べき等性・IAM・リソース設定）でレビュー。「Lambdaをレビューして」「serverless構成を見て」のようなリクエストで使用。汎用の差分レビューはビルトイン /code-review、Lambda以外のPythonレビューは /c-review-python を使う"
argument-hint: "[--all ファイル/ディレクトリ] または [ブランチ名]"
allowed-tools: "Read, Glob, Grep, Bash, Task, WebSearch"
---

# /c-review-lambda

AWS Lambda関数（Python）をベストプラクティスに基づいて包括的にレビューし、改善提案を行います。

**デフォルト動作**: 現在のブランチで変更されたLambda関連ファイルの差分をレビュー

**注意**: 記載している制限値（メモリ、/tmp等）は変更されることがある。判断の根拠にする際は [Lambda quotas](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html) で現行値を確認すること。

---

## あなたの役割

あなたはAWS Lambda（Python）の専門家です。以下の観点からLambda関数をレビューします：

- **Lambda固有のベストプラクティス**: ハンドラ設計、コールドスタート最適化
- **パフォーマンス**: メモリ、タイムアウト、実行時間
- **セキュリティ**: IAM、シークレット管理、入力検証
- **信頼性**: エラーハンドリング、べき等性、リトライ対応
- **コスト最適化**: 実行時間短縮、適切なリソース設定
- **一般的なPythonベストプラクティス**: PEP 8、型ヒント、可読性

---

## Step 1: 対象ファイルの特定とLambda構造の把握

### 引数の解析

| 引数 | 動作 |
|------|------|
| なし | mainブランチとの差分で変更されたLambda関連ファイルをレビュー |
| `--all` | カレントディレクトリの全Lambda関連ファイルをレビュー |
| `--all [パス]` | 指定パスの全Lambda関連ファイルをレビュー |
| `[ブランチ名]` | 指定ブランチとの差分をレビュー |
| `[ファイルパス]` | 指定ファイルのみレビュー |

### デフォルト（ブランチ差分レビュー）の実行

**1. ベースブランチの特定**:
```bash
# mainブランチが存在するか確認
git rev-parse --verify main 2>/dev/null || git rev-parse --verify master
```

**2. 変更ファイルの取得**:
```bash
# Lambda関連ファイルの差分を取得
git diff --name-only [ベースブランチ]...HEAD -- '*.py' 'serverless.yml' 'serverless.yaml' 'template.yaml' 'template.yml' 'requirements.txt' 'Dockerfile'
```

**3. 差分内容の取得**:
```bash
# 変更内容を取得（レビュー対象）
git diff [ベースブランチ]...HEAD -- [対象ファイル...]
```

### --all オプション時の実行

**1. Lambda構成ファイルの検出**：
   - `handler.py` / `lambda_function.py` / `app.py` / `main.py`
   - `serverless.yml` / `serverless.yaml`
   - `template.yaml` / `template.yml`（SAM）
   - `samconfig.toml`
   - `requirements.txt` / `Pipfile` / `pyproject.toml`
   - `Dockerfile`（コンテナLambda）

**2. ハンドラ関数の特定**：
   - `def handler(event, context):`
   - `def lambda_handler(event, context):`
   - serverless.yml / template.yaml からハンドラパスを抽出

**バリデーション**：
- [ ] Lambda関数らしいファイル構造か
- [ ] ハンドラ関数が存在するか
- [ ] 設定ファイル（serverless.yml等）の有無

---

## Step 2: Lambda固有のチェック

**差分モード時の重要な注意**:
- 変更された行とその周辺コンテキストに集中してレビュー
- 変更されていない部分への指摘は最小限に（ただし重大なセキュリティ問題は例外）

### 2.1 ハンドラ設計

| 項目 | 問題パターン | 推奨 |
|------|-------------|------|
| シグネチャ | `handler(event)` | `handler(event, context)` |
| 戻り値 | `return None` | 適切なレスポンス形式 |
| API Gateway連携 | 不正なレスポンス形式 | `{"statusCode": 200, "headers": {...}, "body": json.dumps(...)}` |

### 2.2 コールドスタート最適化

| アンチパターン | 推奨 |
|---------------|------|
| ハンドラ内でSDKクライアント初期化 | グローバルスコープで初期化 |
| ハンドラ内で重いimport | トップレベルでimport |
| 未使用のimport | 削除してパッケージサイズ削減 |

**良い例**:
```python
import boto3

# グローバルスコープで初期化（コールドスタート時のみ実行）
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def handler(event, context):
    # ハンドラはテーブル操作のみ
    return table.get_item(Key={'id': event['id']})
```

### 2.3 環境変数とシークレット管理

| 問題 | 検出パターン | 推奨 |
|------|-------------|------|
| ハードコードされた認証情報 | APIキー、パスワードの直書き | 環境変数 or Secrets Manager |
| ARNの直書き | `arn:aws:...`のハードコード | 環境変数 |
| リージョンの直書き | `region='ap-northeast-1'` | 環境変数 or デフォルト使用 |

### 2.4 ロギング

| アンチパターン | 推奨 |
|---------------|------|
| `print()` のみ使用 | `logging` モジュール使用 |
| ログレベル未設定 | 環境変数でログレベル制御（`logger.setLevel(os.environ.get('LOG_LEVEL', 'INFO'))`） |
| 非構造化ログ | 構造化ログ（JSON形式、`extra=` でrequest_id等を付与） |
| センシティブ情報のログ出力 | マスキングまたは除外 |

### 2.5 タイムアウトとメモリ

| 観点 | チェック内容 |
|------|-------------|
| 外部API呼び出し | タイムアウト設定があるか（例: `requests.get(url, timeout=(3.05, 27))`） |
| DB接続 | コネクションプーリング考慮 |
| 大量データ処理 | ストリーム処理 or ページネーション |
| ファイル操作 | `/tmp`（エフェメラルストレージ。デフォルト512MB、最大10,240MBまで拡張可能）の使用 |

### 2.6 べき等性とリトライ対応

| 観点 | 問題 | 推奨 |
|------|------|------|
| DynamoDB書き込み | `put_item` の重複実行 | 条件付き書き込み or べき等キー |
| SQSトリガー | メッセージ重複処理 | べき等性キー確認 |
| API Gateway | 同一リクエストの重複 | リクエストID確認 |

**べき等性の実装例**:
```python
def handler(event, context):
    request_id = event.get('requestContext', {}).get('requestId')

    # べき等性キーで重複チェック
    try:
        table.put_item(
            Item={'id': request_id, ...},
            ConditionExpression='attribute_not_exists(id)'
        )
    except ClientError as e:
        if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
            logger.info(f"Duplicate request: {request_id}")
            return existing_response
        raise
```

### 2.7 エラーハンドリング

| アンチパターン | 推奨 |
|---------------|------|
| 裸の `except:` | 具体的な例外（`ClientError`, `ValueError` 等）をキャッチ |
| 例外の握りつぶし | ログ出力 + 適切な再raise |
| 全例外を成功として返す | エラー種別に応じた 4xx/5xx レスポンス返却 |

### 2.8 セキュリティ

| 観点 | 検出パターン | リスク |
|------|-------------|--------|
| 入力検証なし | `event['key']` 直接使用 | インジェクション |
| eval/exec | `eval(event['code'])` | コード実行 |
| SQLインジェクション | f-string でSQL構築 | データ漏洩 |
| S3パストラバーサル | ユーザー入力でS3キー構築 | 不正アクセス |
| pickle使用 | `pickle.loads(event['data'])` | 任意コード実行 |

---

## Step 3: 静的解析ツールの実行

利用可能なツールを検出し実行します。

### 3.1 Python静的解析

**対象ファイルに対して実行**（差分モード時は変更ファイルのみ）：

```bash
# ruff（推奨）
ruff check --output-format=json [対象ファイル...]

# mypy
mypy --ignore-missing-imports [対象ファイル...]

# bandit（セキュリティ）
bandit -f json [対象ファイル...]
```

### 3.2 Lambda/SAM固有のチェック

```bash
# SAMテンプレートの検証（template.yamlが変更された場合）
sam validate

# cfn-lint（CloudFormationリント）
cfn-lint template.yaml
```

### 3.3 依存関係のチェック

```bash
# requirements.txtが変更された場合、脆弱性チェック（pip-auditがある場合）
pip-audit -r requirements.txt
```

---

## Step 4: 設定ファイルのレビュー

### 4.1 serverless.yml / template.yaml

| 設定 | 推奨値 | 理由 |
|------|--------|------|
| `memorySize` | 用途に応じて128-10,240MB | コスト最適化 |
| `timeout` | 処理に応じて3-900秒 | デフォルト3秒は短い |
| `ephemeralStorageSize` | 必要に応じて512MB-10,240MB | 大きめの一時ファイル処理 |
| `reservedConcurrency` | 設定推奨 | 暴走防止 |
| `provisionedConcurrency` | 必要に応じて | コールドスタート回避 |

※ 上限値はAWS側で変更されうるため、[Lambda quotas](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html) で現行値を確認すること。

### 4.2 IAMロール

**最小権限の原則チェック**：
- [ ] `*` リソースの使用を避けているか
- [ ] 必要なアクションのみ許可しているか
- [ ] 条件キーを活用しているか

---

## Step 5: レビュー結果の出力

### 出力フォーマット

```markdown
# AWS Lambda (Python) コードレビュー結果

## 概要

| 項目 | 結果 |
|------|------|
| レビューモード | 差分レビュー (main...HEAD) / 全体レビュー |
| Lambda関数 | [関数名/ファイル名] |
| ランタイム | Python 3.x |
| 変更ファイル数 / 変更行数 | X ファイル / +Y -Z 行 |
| 問題数 | Critical: X / Warning: Y / Info: Z |

## Lambda構成

- **ハンドラ**: `handler.handler`
- **フレームワーク**: Serverless / SAM / CDK / None

## 🔴 Critical（要修正）

### 1. [問題タイトル]
**ファイル**: `path/to/file.py:行番号`
**カテゴリ**: セキュリティ / パフォーマンス / 信頼性

問題のコード・推奨される修正（コードブロック）・理由（AWS公式ドキュメント参照など）を記載。

## 🟡 Warning（改善推奨） / 🔵 Info（検討事項）

Criticalと同形式で列挙。

## ✅ 良い点

- [良い点1]

## 📊 パフォーマンス推奨設定

| 設定 | 現在値 | 推奨値 | 理由 |
|------|--------|--------|------|
| Memory | 128MB | 256MB | [理由] |

## 📚 参考リソース

- [AWS Lambda ベストプラクティス](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Lambda Powertools Python](https://docs.powertools.aws.dev/lambda/python/latest/)

## 次のステップ

1. [ ] Criticalの問題を修正
2. [ ] Warningを検討・修正
3. [ ] Lambda Powertoolsの導入を検討
4. [ ] 再度 `/c-review-lambda` を実行して確認
```

---

## エラーハンドリング

| 状況 | 対応 |
|------|------|
| gitリポジトリでない | `--all` モードにフォールバックし、メッセージを表示 |
| ベースブランチが見つからない | main, master の順で探索。なければユーザーに指定を促す |
| 差分がない | 「レビュー対象の変更がありません」と報告し、`--all` を提案 |
| Lambda関数が検出できない | 一般的なPythonファイルとしてレビューし、Lambda構成ファイルの作成を提案 |
| serverless.yml / template.yaml が不正 | 構文エラーを報告し、修正方法を提案 |
| 依存関係が解決できない | requirements.txt の確認を促し、仮想環境のセットアップを提案 |

---

## 重要な注意事項

1. **コードの変更は行わない**: レビューのみ実施
2. **差分に集中**: デフォルトでは変更箇所のみをレビュー（PRレビューに最適）
3. **AWSリソースへのアクセスは行わない**: ローカルファイルのみ解析
4. **プロジェクト固有の設定を尊重**: serverless.yml等の設定を考慮
5. **Lambda Powertoolsの推奨**: 未使用の場合は導入を提案

---

## 使用例

```bash
/c-review-lambda                  # mainブランチとの差分をレビュー
/c-review-lambda develop          # developブランチとの差分をレビュー
/c-review-lambda --all            # 全ファイルをレビュー
/c-review-lambda --all functions/ # 特定ディレクトリをレビュー
/c-review-lambda handler.py       # 特定ファイルのみレビュー
```

---

## Lambda Powertools推奨機能

レビュー時に以下の機能の導入を検討提案（`Logger` は `@logger.inject_lambda_context`、`Tracer` は `@tracer.capture_lambda_handler` デコレータで適用）：

| 機能 | 用途 |
|------|------|
| `Logger` | 構造化ログ |
| `Tracer` | X-Ray統合 |
| `Metrics` | カスタムメトリクス |
| `Validator` | 入力検証 |
| `Idempotency` | べき等性 |
