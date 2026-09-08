---
name: luchida-release
description: Luchida プロジェクト専用の一連リリースフロー（feature PR マージ、release/vX.Y.Z 作成、全 workspace の package.json bump、develop/main マージ、タグ作成、GitHub Release 作成、back-merge、PM2 再起動判断）を要所でユーザー確認を取りながら実行する。「luchida のリリース作って」「luchida を v0.X.Y として進めて」「luchida をマージしてリリースまで進めて」のように Luchida を明示したリクエストでのみ使用。Luchida 以外のプロジェクトのリリース依頼では使用しない。
allowed-tools: Bash, Read, Edit, AskUserQuestion
---

# Luchida リリースフロー

Luchida プロジェクト（Sina-TehraniFard/luchida）の **feature PR マージから PM2 再起動判断まで** の一連リリースフローを LLM が実行する。各段階でユーザー確認を取り、本番への影響を最小化する。

## 前提情報（hardcoded）

- リポジトリ: `Sina-TehraniFard/luchida`
- bump 対象: ルート `package.json` と `packages/*/package.json` の全 workspace（`npm version --workspaces --include-workspace-root` で 1 コマンド。workspace 間の依存指定は `*` 固定なので更新不要。#435）
- PM2 プロセス名: `luchida-backend`
- ポジション確認 DB: `postgresql://luchida:luchida@localhost:5432/luchida`、`positions` テーブル
- back-merge ブランチ命名: `sync/main-to-develop-vX.Y.Z`
- リリース PR タイトル形式: `chore(release): vX.Y.Z`、`Release vX.Y.Z: <要約>`
- 起動コマンド規約・リリースフロー全体像は本スキル同梱の [reference_release_flow.md](reference_release_flow.md) に従う（元ファイル `/Users/tehrani/.claude/projects/-Users-tehrani-workspace-luchida/memory/reference_release_flow.md` のスナップショット。両方存在する場合は同梱版を正とする）

## 重要原則

- **本スキルは Luchida 専用**。対象が Luchida 以外なら Step 0 で中断する
- **本来 develop / main へのマージは LLM 禁止**だが、本スキル起動時は「ユーザーがマージ権限を明示的に委譲した状態」と見なして実行する
- 要所で AskUserQuestion を挟み、ユーザーの確認を取る。必須の確認ポイントは 3 箇所: **Step 1（実行プラン一括承認）**、**Step 5 の develop → main マージ直前**、**Step 9 の PM2 再起動（本番反映）実行直前**。それ以外の Step は Step 1 の承認範囲内で自動実行してよい
- PM2 再起動はオープンポジション確認の後に判断
- 「4 戦略」のような戦略数依存の表現は禁止（戦略数は動的）

## 実行フロー

### Step 0: 前提情報の収集

1. **対象プロジェクトの確認**: 対象が luchida プロジェクト（cwd が luchida リポジトリ、またはユーザーが Luchida を明示）であることを確認する。luchida でない場合は**ここで中断**し、本スキルは Luchida 専用である旨をユーザーに伝える
2. ユーザーから feature PR 番号と新バージョン番号を確認（または推論）
   - PR 番号が未指定なら `gh pr list --repo Sina-TehraniFard/luchida --state open` で候補確認
   - 新バージョンが未指定なら `package.json` の現在値を読み取り、パッチ番号 +1（または minor/major の判断）を提案
3. feature PR の現状確認
   ```bash
   gh pr view {PR_NUMBER} --repo Sina-TehraniFard/luchida --json mergeable,mergeStateStatus,statusCheckRollup,title,baseRefName,headRefName
   ```
   - `MERGEABLE` / `CLEAN` / CI `SUCCESS` であることを確認
4. オープンポジション確認（PM2 再起動判断の前提情報として）
   ```bash
   PGPASSWORD=luchida psql -h localhost -U luchida -d luchida -c "SELECT id, currency_pair, buy_sell, lot, entry_price, opened_at FROM positions WHERE status = 'OPEN' ORDER BY opened_at DESC;"
   ```

### Step 1: 実行プラン提示と確認

AskUserQuestion で以下を確認:
- バージョン番号（v0.X.Y）の確定
- 進める範囲（PR マージ → リリース → 再起動 まで全部か、途中までか）
- 進める範囲のうち PM2 再起動を含むか（ポジションの有無は再起動可否に影響しない。再起動で強制決済は走らず継承されるため、ポジションを理由に分岐しない）

### Step 2: feature PR マージ

```bash
gh pr merge {PR_NUMBER} --repo Sina-TehraniFard/luchida --merge
gh pr view {PR_NUMBER} --repo Sina-TehraniFard/luchida --json state,mergeCommit -q '{state, mergeCommit: .mergeCommit.oid}'
```

- `state: MERGED` を確認
- merge commit SHA を記録（後続では使わない、確認用）

### Step 3: release ブランチ作成 + bump

```bash
git fetch origin --quiet
git checkout -b release/v{NEW_VERSION} origin/develop
```

ルートと全 workspace（backend / backtest / frontend / contracts、今後追加されるものも含む）の version を 1 コマンドで揃える。手で 1 ファイルずつ書き換えない（上げ忘れが出る。#435）:

```bash
npm version {NEW_VERSION} --workspaces --include-workspace-root --no-git-tag-version
git diff --stat   # ルート + packages/*/package.json が全部 {NEW_VERSION} になっていること
```

workspace 間の依存指定（例: backend の `"@luchida/contracts": "*"`）は `*` 固定なので更新不要。`npm ls` が `invalid` を出したら依存指定に固定バージョンが紛れているので `*` に直す。

```bash
git add package.json packages/*/package.json
git commit -m "chore(release): v{NEW_VERSION}"
git push -u origin release/v{NEW_VERSION}
```

### Step 4: release → develop PR 作成・マージ

```bash
gh pr create --repo Sina-TehraniFard/luchida --base develop --head release/v{NEW_VERSION} \
  --title "chore(release): v{NEW_VERSION}" \
  --body "$(cat <<'EOF'
## Summary

v{NEW_VERSION} パッチアップリリース。{HIGHLIGHT_SUMMARY}

## Highlights

{BULLET_LIST_OF_KEY_CHANGES}

## 関連 PR / Issue

- #{FEATURE_PR_NUMBER}（feature PR、マージ済み）
- {RELATED_ISSUE_LINKS}

## マージ後手順

- [ ] develop → main にマージ
- [ ] git tag v{NEW_VERSION} をマージコミットに付与 → push
- [ ] gh release create v{NEW_VERSION} で GitHub Release 作成
- [ ] PM2 再起動の判断（オープンポジション状況による）
- [ ] main → develop back-merge

## Test plan

- [x] backend test PASS
EOF
)"
```

リリースノート本文は feature PR の内容から生成。

```bash
gh pr edit {RELEASE_PR_NUMBER} --repo Sina-TehraniFard/luchida --add-assignee Sina-TehraniFard
gh pr merge {RELEASE_PR_NUMBER} --repo Sina-TehraniFard/luchida --merge
gh pr view {RELEASE_PR_NUMBER} --repo Sina-TehraniFard/luchida --json state,mergeCommit -q '{state, mergeCommit: .mergeCommit.oid}'
```

### Step 5: develop → main リリース PR 作成・マージ

**マージ直前の必須確認**: main PR を作成したら、マージ実行前に AskUserQuestion で「この PR を main にマージしてよいか」を確認する（PR URL・タイトル・含まれる変更の要約を提示）。承認を得るまで `gh pr merge` は実行しない。

```bash
gh pr create --repo Sina-TehraniFard/luchida --base main --head develop \
  --title "Release v{NEW_VERSION}: {SHORT_SUMMARY}" \
  --body "$(cat <<'EOF'
## Summary

v{NEW_VERSION} パッチアップリリース。{ISSUE_SCOPE}

詳細は #{RELEASE_PR_NUMBER}（release PR）本文を参照。

## 主な変更点 (since v{PREV_VERSION})

- **#{FEATURE_PR_NUMBER}**: {FEATURE_DESCRIPTION}
- **#{RELEASE_PR_NUMBER}**: 全 workspace の package.json を v{NEW_VERSION} へ bump

## マージ後手順

- [ ] git tag v{NEW_VERSION} をマージコミットに付与 → push
- [ ] gh release create v{NEW_VERSION} で GitHub Release 作成
- [ ] PM2 再起動の判断（オープンポジション状況による）
- [ ] main → develop back-merge

## Test plan

- [x] backend test PASS
EOF
)"

gh pr edit {MAIN_PR_NUMBER} --repo Sina-TehraniFard/luchida --add-assignee Sina-TehraniFard
gh pr merge {MAIN_PR_NUMBER} --repo Sina-TehraniFard/luchida --merge

# main マージコミット SHA を取得（タグ付与に使う）
MAIN_MERGE_SHA=$(gh pr view {MAIN_PR_NUMBER} --repo Sina-TehraniFard/luchida --json mergeCommit -q .mergeCommit.oid)
```

### Step 6: タグ作成・push

```bash
git fetch origin main --quiet
git tag v{NEW_VERSION} {MAIN_MERGE_SHA}
git push origin v{NEW_VERSION}
```

### Step 7: GitHub Release 作成

```bash
gh release create v{NEW_VERSION} --repo Sina-TehraniFard/luchida \
  --title "v{NEW_VERSION} — {SHORT_TITLE}" \
  --notes "$(cat <<'EOF'
## Highlights

{ISSUE_SUMMARY}

{BULLET_LIST_OF_HIGHLIGHTS}

## Added / Changed / Fixed

{DETAILED_BREAKDOWN}

## 本番反映

{IMPACT_DESCRIPTION}

**PM2 再起動の判断**: {POSITION_STATUS_AT_RELEASE_TIME}

## 関連 PR / Issue

- #{FEATURE_PR_NUMBER}
- #{RELEASE_PR_NUMBER}
- #{MAIN_PR_NUMBER}
- {RELATED_ISSUES}

## Diff

https://github.com/Sina-TehraniFard/luchida/compare/v{PREV_VERSION}...v{NEW_VERSION}
EOF
)"
```

### Step 8: main → develop back-merge

```bash
git fetch origin --quiet
git checkout -b sync/main-to-develop-v{NEW_VERSION} origin/develop
git merge origin/main --no-ff -m "chore: main を develop に同期（v{NEW_VERSION} リリース後の back-merge）"
git push -u origin sync/main-to-develop-v{NEW_VERSION}

gh pr create --repo Sina-TehraniFard/luchida --base develop --head sync/main-to-develop-v{NEW_VERSION} \
  --title "chore: main を develop に同期（v{NEW_VERSION} リリース後の back-merge）" \
  --body "$(cat <<'EOF'
## Summary

v{NEW_VERSION} リリース後の慣例 back-merge。main 側の merge commit を develop に取り込み、次回リリース時の merge-base を整える。

## 内容

- ファイル変更ゼロ（merge commit メタデータの同期のみ）

## 関連

- v{NEW_VERSION} Release: #{MAIN_PR_NUMBER}
EOF
)"

gh pr edit {SYNC_PR_NUMBER} --repo Sina-TehraniFard/luchida --add-assignee Sina-TehraniFard
gh pr merge {SYNC_PR_NUMBER} --repo Sina-TehraniFard/luchida --merge
```

### Step 9: PM2 再起動判断

オープンポジションを再確認:

```bash
PGPASSWORD=luchida psql -h localhost -U luchida -d luchida -c "SELECT id, currency_pair, buy_sell, lot, entry_price, opened_at FROM positions WHERE status = 'OPEN' ORDER BY opened_at DESC;"
```

**ポジションの有無は再起動可否に影響しない**。#221（v0.8.0）でシャットダウン時の自動決済は撤廃済みのため、ポジションがあっても再起動でそれが決済されることはなく、再起動後に DB の OPEN を継承して監視・決済判定を再開する（`main.ts` の `shutdown` 関数コメント参照）。よってポジションの有無に関わらず再起動してよく、ポジションを理由にユーザー確認を取る必要はない（再起動中の数秒間は監視ループが止まるが、それも含めて通常運用の範囲）。

**再起動実行前の必須確認**: 再起動を実行する前に AskUserQuestion で「いま PM2 再起動（本番反映）を実行してよいか」と再起動手段（下記 (a) / (b)）を確認する。これは本番プロセスに触れる操作としての確認であり、ポジションの有無を理由とした確認ではない（ポジションは再起動可否に影響しない。前述の通り）。

リリース後の本番反映として、再起動手段は 2 通り:

**(a) `luchida -r`（通常はこちら）**: main の最新を pull してから停止・再起動するラッパー。コード更新を伴うリリース後の本番反映に使う。

```bash
luchida -r
```

ただし `luchida -r` は停止フェーズで対話的な `y` 確認を求め、**LLM の非対話実行では `Refusing to stop in non-interactive mode` で停止フェーズが拒否されボットは止まらない**（コードの git pull だけは実行される）。この場合はユーザーに、プロンプトで `!` プレフィックスを使って実行してもらう:

```
! luchida -r
```

**(b) `pm2 restart luchida-backend`（コード更新が不要な場合のみ）**: git pull は走らず、現在のワークツリーのコードでプロセスを再起動するだけ。ワークツリーが既に新コードに更新済みの場合や、コード変更を伴わない再起動に使う。

```bash
pm2 restart luchida-backend
```

いずれの場合も再起動後にログを確認:

```bash
sleep 5
pm2 logs luchida-backend --lines 30 --nostream
```

ログで以下を確認:
- version が新バージョンになっている（`pm2 jlist` の `version` か起動ログで確認）。`pm2 restart` 単体ではワークツリーのコードが古いと version が上がらないため、リリース後の反映は (a) を使う
- `WebSocket 接続（初回）` が出ている
- `初回 tick 受信` が出ている
- 既存 OPEN ポジションがある場合、`/private/v1/openPositions` の定期取得が出ている（DB の OPEN を継承して監視ループが再開している証跡）
- 起動エラー（CAPITAL バリデーション失敗等）が出ていない

### Step 10: 完了報告

完了内容をユーザーに報告:
- マージ済み PR 一覧（feature / release / main / sync）と merge commit SHA
- タグ URL（https://github.com/Sina-TehraniFard/luchida/releases/tag/v{NEW_VERSION}）
- PM2 再起動の有無と現在の version

## エラーハンドリング

- マージ可否が `BLOCKED` / `DIRTY` の場合: コンフリクト解消や CI 完了を待つ。LLM は勝手にマージしない
- bump コミットで pre-push hook（テスト）が落ちた場合: 原因を調査してユーザーに報告。`--no-verify` は使わない
- PM2 再起動後にエラーログが出た場合: 即座にログをユーザーに提示し、ロールバック判断を仰ぐ

## 注意点

- リリースノート本文の `{PLACEHOLDER}` 部分は、feature PR の内容・関連 Issue・直近の変更ログから動的に生成する
- 「4 戦略」のような戦略数に依存した表現は禁止（戦略数は動的、N 戦略 / 複数戦略と表現する）
- `--no-verify` / `--force` 等の破壊的フラグは使わない
- ポジションの有無は再起動可否に影響しない。再起動で強制決済は走らず（#221 / v0.8.0 で撤廃済み）、再起動後に DB の OPEN を継承して監視・決済判定を再開する。ポジションを理由にユーザー確認を取る必要はない（再起動中の数秒の監視停止も通常運用の範囲）
- リリース後の本番反映は通常 `luchida -r`（git pull を伴う）。LLM の非対話実行では停止フェーズが拒否されるため、ユーザーに `! luchida -r` での実行を依頼する。コード更新が不要な再起動のみ `pm2 restart luchida-backend` を使う
