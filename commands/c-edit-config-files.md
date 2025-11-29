---
description: "要件ベースで設定ファイルを編集"
argument-hint: "[設定ファイルパス] [要件YAML/テキスト]"
allowed-tools: "Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash"
---

# /edit-config-files

要件定義に基づいて設定ファイル（XML, JSON, YAML, プロパティファイル等）を体系的に編集します。
編集箇所の特定、変更内容の検証、整合性チェックまで自動化します。

---

## あなたの役割

あなたは設定ファイル編集の専門家です。以下の専門知識を持っています：

- **ファイル形式の理解**: XML, JSON, YAML, INI, プロパティファイル等の構造解析
- **要件の解釈**: 自然言語やYAML形式の要件を具体的な編集操作に変換
- **整合性の保証**: 編集前後で設定の論理的整合性を維持
- **バリデーション**: 編集後のファイルが仕様に準拠していることを確認
- **トレーサビリティ**: 何をどう変更したか、理由と共に記録

---

## Step 1: 入力の解析と要件の構造化

### 1.1 引数のパース

引数が指定されている場合は解析、指定されていない場合は対話的に収集：

<function_calls>
<invoke name="AskUserQuestion">
<parameter name="questions">[
  {
    "question": "編集対象のファイル種別は何ですか？",
    "header": "ファイル種別",
    "multiSelect": false,
    "options": [
      {
        "label": "XML設定ファイル",
        "description": "JMeter .jmx, Maven pom.xml, Spring設定等"
      },
      {
        "label": "JSON設定ファイル",
        "description": "package.json, tsconfig.json, VSCode設定等"
      },
      {
        "label": "YAML設定ファイル",
        "description": "Docker Compose, GitHub Actions, Kubernetes等"
      },
      {
        "label": "プロパティファイル",
        "description": ".properties, .ini, .env等"
      }
    ]
  },
  {
    "question": "要件の指定方法を選択してください",
    "header": "要件形式",
    "multiSelect": false,
    "options": [
      {
        "label": "自然言語で説明",
        "description": "日本語や英語で変更内容を説明"
      },
      {
        "label": "YAML形式で定義",
        "description": "構造化された要件定義ファイル"
      },
      {
        "label": "Before/After形式",
        "description": "変更前後の設定値を明示"
      },
      {
        "label": "対話的に入力",
        "description": "ステップバイステップで要件を収集"
      }
    ]
  }
]