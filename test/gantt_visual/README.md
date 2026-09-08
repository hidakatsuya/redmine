# ガントの比較テスト

`doc/GANTT_TEST_PLAN.md` の G01–G20 を40個の具体的なケースにした検証用ツール。
専用 SQLite DB、固定日時、同じ bundle / Chromium / フォントで比較する。
実行結果は `tmp/gantt_visual/` に保存し、通常の Rails テストには組み込まない。

## 準備

1. `git worktree add --detach tmp/gantt_visual_baseline origin/master` で比較元を固定する。
2. 比較元に `config/database.yml` を用意する。以下のコマンドはすべて `DATABASE_URL` で専用 DB を指定する。
3. Redmined に Chromium、chromedriver、MiniMagick が利用する ImageMagick と日本語フォントを用意する。
   今回は Debian の `fonts-noto-cjk` をユーザーフォントとして配置した。
4. ホスト側に Python の Pillow / pypdf と Poppler の `pdftoppm` を用意する。
   実際に使ったバージョンと bundle は結果の `environment.json` / `runtime.json` / `dependencies/` に記録する。

```sh
mkdir -p tmp/gantt_visual
redmined -T env RAILS_ENV=test DATABASE_URL=sqlite3:/redmine/tmp/gantt_visual/seed.sqlite3 bin/rails db:schema:load
redmined -T env RAILS_ENV=test DATABASE_URL=sqlite3:/redmine/tmp/gantt_visual/seed.sqlite3 GANTT_VISUAL_MANIFEST=/redmine/tmp/gantt_visual/manifest.json RUBYOPT=-r/redmine/test/gantt_visual/frozen_clock.rb bin/rails runner test/gantt_visual/seed.rb
python3 test/gantt_visual/cases.py
```

`seed.rb` は専用ディレクトリ内の DB に限って fixture を読み込み、比較データとテスト専用ログインを作る。
開発 DB を指定しない。テスト用パスワードはこの専用 DB だけに使用する。
各ケースではこの DB を複製し直し、cookie・ユーザー設定・列幅などを持ち越さない。

比較元で共通 bundle を使う例:

```sh
redmined -T sh -c 'cd /redmine/tmp/gantt_visual_baseline && BUNDLE_GEMFILE=/redmine/Gemfile RAILS_ENV=production DATABASE_URL=sqlite3:/redmine/tmp/gantt_visual/seed.sqlite3 SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile'
```

比較先も独立してアセットを生成する。現在の production 環境にはアセット変更時の自動生成がある。
ブランチの Gemfile が異なる場合、共通 bundle による依存の上書きを必ず結果に明記する。

## 実行と比較

```sh
redmined -T bundle exec ruby test/gantt_visual/capture.rb expected
redmined -T bundle exec ruby test/gantt_visual/capture.rb actual
python3 test/gantt_visual/compare.py
```

ブラウザを同時に複数起動すると検証コンテナのメモリを圧迫するので、比較元・比較先は順番に実行する。
絞り込みは第2引数に正規表現を渡す（例: `actual 'G11|G12|G18'`）。
同じケースの再実行時には、その側のケースディレクトリの生成物を置き換える。比較元はデータや取得処理を修正したとき以外は再取得しない。

サーバーは各ケース専用の子プロセスで、終了時に停止する。ポートは比較元3101、比較先3102。
`localhost:3000` の開発サーバーには触れない。

## 判定の範囲

- 独立した fixture の ID 一覧と表示対象を比較。基本ケースの行順を明示し、全ケースの論理行・順序・可視性を前後比較する。
- 開閉、リサイズ、ツールチップ、右クリック、複数選択には操作 assertion を加える。
- G14 は初期クエリと操作後の確定クエリの PDF/PNG を取得する。
- G19 は計画通り画面のみ。他のケースでは Chromium の `Page.printToPDF` を使用する。
- PDF の全ページを96 DPIで画像化し、PNGとともに RGBA の全チャンネルを閾値なしで比較する。
- 生成失敗・欠けたページ・HTTP失敗・意味の不一致を、単なる画素差分と分ける。
- 画素差分は自動で許容しない。`report.html` の前後・差分から人間が判断する。

OS の印刷ダイアログのキャンセル、Safari/Firefox、実プリンターはこのツールの対象外。
G20 は Chromium の実際の PDF 生成と復帰後の開閉・リサイズまでを自動確認する。
性能計測は画像取得と分けて行う。
