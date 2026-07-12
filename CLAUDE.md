# Global Notes

## ネットワーク / サーバー接続

- 開発サーバー（sina）の静的LAN IP: `DEV_SERVER_IP`
- Tailscale IP: `DEV_SERVER_TS_IP`（固定、変わらない）
- MacのTailscale IP: `MAC_TS_IP`
- `DEV_SERVER_IP` への接続で問題が出たら、ユーザーが外出先にいる可能性がある。Tailscale IP `DEV_SERVER_TS_IP` を試すよう提案すること

## agent-browser（ヘッドレスブラウザ CLI）

- `agent-browser` がインストール済み（`/opt/homebrew/bin/agent-browser`）。vercel-labs 製。ブラウザテスト・UI 操作・スクリーンショット取得に使用する
- スクリーンショットは各プロジェクトの ai-docs ディレクトリ配下に保存すること（基本どのプロジェクトにも ai-docs がある前提）
  - 例: `agent-browser screenshot --output ./aidlc-docs/EB-XXX/assets/screenshots/foo.png`
- ローカル開発サーバーのポートはプロジェクトごとに異なる。不明な場合は確認すること
