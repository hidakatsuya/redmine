# 共通のガントチャート検証ツール

`gantt_test` は `origin/master` を起点とした検証専用ブランチ。
ガントチャートの変更そのものは含めず、検証ツールの更新をここに集約する。
開発ブランチにこのブランチをマージする必要はない。

開発するチェックアウトで、共通ツールを一時ディレクトリへ取り出す:

```sh
mkdir -p tmp/gantt_tools
git archive gantt_test test/gantt_visual test/gantt_performance test/GANTT_TESTING.md | tar -x -C tmp/gantt_tools
```

以降のコマンドの `test/gantt_visual` と `test/gantt_performance` は、取り出した
`tmp/gantt_tools/test/gantt_visual` と `tmp/gantt_tools/test/gantt_performance` に読み替える。
Redmined 内では `/redmine/tmp/gantt_tools/test/...` という絶対パスで指定できる。
これは実行しているチェックアウトとツールの所在が異なる場合にも使える。

結果用ディレクトリは毎回新しく作る。比較元・比較先には同じ専用DBを複製し、
同じbundle、設定、固定日時、独立して生成したアセットを使う。
開発用DBは計測に使わない。`.env` を直接参照しない。
Railsの起動・DB準備・計測はすべてDocker Desktopの `redmined -T` 経由で行う。
比較用サーバーのポートは既存の開発サーバーと重複させない。

| 検証 | ツール・手順 |
| --- | --- |
| 画面・操作・印刷・PDF/PNGの差分 | [gantt_visual/README.md](gantt_visual/README.md) |
| Puma＋Chromiumによる従来の性能計測 | [gantt_performance/README.md](gantt_performance/README.md) の `compare.rb` |
| Railsのリクエスト時間とRubyメモリ割り当て | 同じREADMEの `compare_requests.rb` |

ブラウザ方式の `request_ms` はPumaのRailsログに記録される時間。
追加方式の `request_ms` は、認証済み `ActionDispatch::Integration::Session` からの
完全なRackリクエストの経過時間。ネットワーク・Puma・ブラウザの時間は含まない。
この2方式の数値は混ぜず、同じ方式の比較元と比較先を比較する。

ビジュアル差分の閾値は設けない。両側に同じ既存の不具合があることと、新しい回帰を区別し、
「画素が一致した」と「すべての仕様検査に合格した」を分けて報告する。
