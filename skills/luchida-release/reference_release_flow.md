---
name: リリースフロー
description: feature ブランチ → develop → main → タグ → GitHub Release → PM2 再起動の手順。タグ作成だけでは Release は自動生成されない点に注意
type: reference
originSessionId: 08ba129c-71a9-485f-9828-6ac971b971ab
---
# リリースフロー

```
{phase}/main（親ブランチ） → develop → main → v{X.Y.Z} タグ → GitHub Release → PM2 再起動
```

## 手順

1. **作業ブランチ → 親ブランチ**: 作業 PR を `{phase}/main` へマージ（LLM 可）
2. **親ブランチ → develop**: PR を作成し、人間がマージ（LLM 禁止）
   - PR 本文に v{X.Y.Z} のリリースノートを埋める（Highlights / Added / Changed / Fixed / Test plan）
   - `package.json` の version も bump（4 ファイル: ルート + backend + backtest + frontend）
3. **develop → main**: リリース PR を作成し、人間がマージ（LLM 禁止）
   - PR 本文は簡潔に（詳細は元 PR を参照する形）
   - 主な変更とマージ後手順のチェックリストだけ載せる
4. **タグ作成**: `git tag v{X.Y.Z} && git push origin v{X.Y.Z}`（main の merge commit を指す）
5. **GitHub Release 作成**: `gh release create v{X.Y.Z} --title "..." --notes "..."`
   - **タグだけ作っても Release は自動生成されない**。release-please 等の GitHub Actions も未導入
   - リリースノートは元 develop 向け PR の本文を流用するのが楽
6. **PM2 で本番ボット再起動**: `pm2 restart luchida-backend`
   - 起動ログの `連敗状態を起動時に復元` で state が想定通りか確認
   - v0.8.0(#221) 以降、シャットダウン時の自動決済は撤廃（停止＝ポジション保持・再起動で監視再開）。`pm2 restart` でもポジションは決済されない。ただし旧コード(v0.8.0未満)稼働中プロセスの停止は決済が走るため、新コード入れ替えは `kill -9 <pid>`→PM2 autorestart で行う。詳細 [[feedback_bot_restart_policy]]

## 注意

- mainへの直接 push / コミットは禁止。リリース時のみ develop からマージ
- develop にはリリース可能なものだけ置く
- 本番ボット再起動は develop/main マージ後のみ（feedback_bot_restart_policy.md）

## 参考: 過去の release commit メッセージ

```
Merge pull request #135: Release v0.5.1 - PositionManager 設計フェーズ完了 + Backtest README 同期
```
