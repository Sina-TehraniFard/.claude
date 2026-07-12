---
name: ryugaku-app-review
description: 留学アプリ (ryugaku-app) 専用のコードレビュー。subagent 並列で REVIEW_CHECKLIST と ai-review-spec に基づき、1ファイル1subagent を下限として精査する。「ryugaku-app をレビューして」「留学アプリのコードレビュー」「留学アプリの PR レビュー」のように ryugaku-app / 留学アプリを明示したリクエスト、または対象が ryugaku-app リポジトリだと明確な場合のみ使用。プロジェクト指定のない汎用の「レビューして」「コードレビュー」ではビルトインの /code-review・/review 等を使い、本スキルは使用しない
---

# 留学アプリ コードレビュー

留学アプリ (`/Users/tehrani/workspace/covvy/ryugaku-app`) のコードを subagent 並列でレビューする。

## 必読ファイル（subagent に必ず参照させる）

レビュー対象ファイルとセットで、以下4種を毎回参照させる:

1. `REVIEW_CHECKLIST.md` (リポジトリルート)
2. `doc/ai-review-spec/` 配下の各 spec
3. `doc/CODING_STANDARD.md`
4. `doc/ARCHITECTURE.md`

## subagent 配分の絶対ルール

### 下限: 1 ファイル = 1 subagent（絶対値、譲れない）

レビュー対象ファイルが N 個あるとき、subagent の数は最低でも N 個確保する。「ファイルをまとめて1つの subagent に投げる」は禁止。

### 観点別 X 倍（対象が少ない場合）

ファイル数に余裕がある場合、観点を増やして X 倍する:

| 観点 | 推奨 subagent_type | 用途 |
|------|-------------------|------|
| 既存パターン整合性 | `dev-be:consistency-reviewer` | schools/lps と命名・パターン・構造で一貫しているか |
| DRY/凝集度/結合度 | `dev-be:structure-reviewer` | 設計品質 |
| import/型定義/定数 | `dev-be:toplevel-reviewer` | 非関数コード |
| REVIEW_CHECKLIST 観点 | `general-purpose` | フリーフォーマットで checklist と照合 |

例: 3 ファイル × 4 観点 = 12 subagent を並列起動。

### 大規模対応（対象が多い場合）

ファイル数が 10 を超える場合は subagent 戦略を見直す:

- 第一波: 1 ファイル 1 観点（最低限の N 体）で速報レビュー
- 第二波: 主要ファイルだけ観点を追加（X 倍）
- もしくは差分の論理単位（機能単位）で分割実行

総 subagent 数の目安:
- 1〜3 ファイル → 4〜12 体（観点別 X=4）
- 4〜9 ファイル → N×2〜3 体（重要観点に絞る）
- 10+ ファイル → N×1 体（速報）+ 第二波で重要箇所を補強

## 実行手順

### 1. レビュー対象ファイルを確定

| 入力 | 取得方法 |
|------|---------|
| PR 番号（例: `807`） | `gh pr diff [番号] --name-only` |
| ディレクトリ指定 | 配下のファイルを `find` で列挙 |
| 空（カレントブランチ） | `git diff --name-only`（ベースブランチとの merge-base 起点）と `git status --short` の全変更ファイルを対象にする。除外は lock ファイル（`pnpm-lock.yaml` 等）・自動生成物などの汎用除外のみで、特定ディレクトリでは絞らない。特定機能に絞りたい場合は AskUserQuestion でユーザーに確認する |
| ファイル絶対パスのリスト | そのまま使用 |

### 2. subagent 数を計算

- N（ファイル数）と M（観点数）を決定
- 並列起動数 = N × M（絶対下限 N）
- N が 10+ なら M=1 で開始

### 3. subagent プロンプトに含める必須要素

各 subagent のプロンプトに必ず含めること:

- 検証対象ファイルの**絶対パス**
- 比較対象（lps / schools / 共通コンポーネントなど既存実装）
- **規約4ファイル絶対パス**（必読ファイル節を参照）
- 既知の保留事項（再指摘不要なものを明示）
- 報告形式（字数制限、JSON 形式の有無、severity / score）

### 4. 並列実行

**1 メッセージ内で複数の Agent ツール呼び出し**を行う。順次実行しない。

### 5. 統合報告

- **重複指摘の精査**: 複数 subagent が同じ指摘 → 信頼度高い
- **誤判定の検出**: grep で実証 / 既存ファイルと比較
- **既存パターン整合性チェック**: lps/schools と同型なら「共通化PR候補」に分類して partnerships 単独修正は避ける
- **優先度付け**: Must / Should / Nice
- ユーザーへの最終報告は **重要度順 + 修正候補** で簡潔に

## 質問が必要な場合

仕様や方針が不明な場合は **AskUserQuestion** ツールで質問する。
- 平易な日本語
- 選択肢 2〜4 個
- Recommended には `(Recommended)` を付ける
- 「ファイルにまとめて確認」は禁止

## 既知の保留事項（subagent に伝えて再指摘不要にする）

**鮮度ガード**: 以下のリストは EB-626 時点（2026年4月末）のスナップショットである。指摘を抑制する前に、該当コードが本当に未対応のままかを必ず現行コードで確認すること。対応済み（共通化 PR 反映済み等）の項目は再指摘不要リストとして使わず、この SKILL.md から削除する。

partnerships 一覧ページに既知の以下があり、別 PR で対応予定:

- `hooks/filter.ts` の handleXxx/removeXxx の DRY 違反 → lps と同型 / 共通化PR で対応
- `applied-filters.tsx` の3ブロックコピペ → lps と同型 / 共通化PR
- `useCallback` 不在 → lps/schools と同型
- `setParams(null)` 全リセット → lps/schools と同型
- `[...arr]` スプレッド → Prisma `in` 型 (`Array<T>`) 制約のため必須
- `_component` 単数形 → ARCHITECTURE 準拠
- `AlertDialogCancel` 二重配置 → schools と同型
- `toast.promise + Promise.all + setTimeout(1000)` → schools と同型 / 共通化PR
- `[...selectedIds]` 冗長コピー → schools と同型
- repository 内の `getXxxList` 関数の認可 → EB-626 の既存実装、別件
- `parseAsInteger.withDefault(0)` リテラル → lps/schools と同型

## 誤判定の典型パターン（subagent ハルシネーション）

レビュー結果を採用する前に検証する:

1. **「未使用 export」指摘**: `grep -rn "<シンボル>" src/` で実証
2. **「lps/schools と乖離」指摘**: 実際の lps/schools コードを確認
3. **ESLint プロジェクトルール違反の提案**:
   - `useState` setter を props に直渡し → `no-restricted-syntax` 違反（ラッパー必須）
   - `if` 文のネスト → `no-restricted-syntax` 違反（guard clause / spread に書き換え）
4. **`as` 型アサーションの追加提案** → `satisfies` で代用できないか確認

## 不要なコメントは削除する方針

- 「コードを読めば分かる」レベルのコメントは追加しない
- 既存の関数 TSDoc（schools/lps にあるパターン）は残す
- `// === ... ===` のような独自区切りは禁止
- マジックナンバー説明（例: `{/* 189pxはヘッダー高さ... */}`）は schools と同パターンなら残す
