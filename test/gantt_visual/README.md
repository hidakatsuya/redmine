# ガントの比較テスト

G01–G20 の既存42ケースに、非公開の中間プロジェクトを挟む開閉ケースと、
G21 のプロジェクト表示状態9ケース、G22 のウィンドウリサイズ5ケースを加えた計57ケースの検証用ツール。
専用 SQLite DB、固定日時、同じ bundle / Chrome / フォントで比較する。
実行結果は `tmp/gantt_visual/` に保存し、通常の Rails テストには組み込まない。

ブラウザ操作は Playwright MCP で実行する。`playwright_capture.js` は Playwright MCP の
`browser_run_code_unsafe` にファイルとして渡す関数であり、Selenium やローカルの
ブラウザドライバーには依存しない。

## 準備

1. `git worktree add --detach tmp/gantt_visual_baseline origin/master` で比較元を固定する。
2. 比較元に `config/database.yml` を用意する。以下のコマンドはすべて `DATABASE_URL` で専用 DB を指定する。
3. Redmined に MiniMagick が利用する ImageMagick と日本語フォントを用意する。
   今回は Debian の `fonts-noto-cjk` をユーザーフォントとして配置した。さらに、比較元worktreeと
   比較先の両方の `config/configuration.yml` に同じ `minimagick_font_path` を設定する。
   フォントをコンテナへ追加するだけではPNGエクスポートには使われない。
4. ホスト側に Python の Pillow / pypdf を用意する。PDFの画像化には、検証対象と同じ
   フォント環境を使うため Redmined 内の Ghostscript を使う。
   実際に使ったバージョンとbundleは結果レポートに記録する。

Python依存は `requirements.txt` に固定している。

比較元worktreeにも、比較先と同じ設定を用意する。ほかのローカル設定をコピーする必要はない。

```yaml
default:
  minimagick_font_path: /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc
```

```sh
export GANTT_VISUAL_ROOT=tmp/gantt_visual/RUN_ID
mkdir -p "$GANTT_VISUAL_ROOT"
redmined -T env RAILS_ENV=test DATABASE_URL=sqlite3:/redmine/$GANTT_VISUAL_ROOT/seed.sqlite3 bin/rails db:schema:load
redmined -T env RAILS_ENV=test DATABASE_URL=sqlite3:/redmine/$GANTT_VISUAL_ROOT/seed.sqlite3 GANTT_VISUAL_MANIFEST=/redmine/$GANTT_VISUAL_ROOT/manifest.json RUBYOPT=-r/redmine/test/gantt_visual/frozen_clock.rb bin/rails runner test/gantt_visual/seed.rb
GANTT_VISUAL_ROOT="$GANTT_VISUAL_ROOT" python3 test/gantt_visual/cases.py
cp "$GANTT_VISUAL_ROOT/seed.sqlite3" "$GANTT_VISUAL_ROOT/expected.sqlite3"
cp "$GANTT_VISUAL_ROOT/seed.sqlite3" "$GANTT_VISUAL_ROOT/actual.sqlite3"
shasum -a 256 "$GANTT_VISUAL_ROOT/"*.sqlite3
```

`seed.rb` は専用ディレクトリ内の DB に限って fixture を読み込み、比較データとテスト専用ログインを作る。
開発 DB を指定しない。テスト用パスワードはこの専用 DB だけに使用する。
比較元と比較先の開始時にこのDBを別々に複製し、Playwrightはケースごとにcookieと
Web Storageを消去する。

比較元で共通 bundle を使う例:

```sh
redmined -T sh -c 'cd /redmine/tmp/gantt_visual_baseline && BUNDLE_GEMFILE=/redmine/Gemfile RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile'
```

比較先も独立してアセットを生成する。現在の production 環境にはアセット変更時の自動生成がある。
ブランチの Gemfile が異なる場合、共通 bundle による依存の上書きを必ず結果に明記する。

## サーバー起動

比較元と比較先には専用DBの同一コピーを使い、固定日時を有効にして起動する。
今回の手順はホストの3000番を順番に使う。各側のDBの SHA-256 がseed DBと一致することを
起動前に確認し、比較元を取得して停止してから比較先を起動する。ログイン日時やユーザー設定で
実行後のDBは変化するため、ハッシュの比較は起動前に行う。

比較元の起動例:

```sh
redmined -T sh -c 'cd /redmine/tmp/gantt_visual_baseline && BUNDLE_GEMFILE=/redmine/Gemfile RAILS_ENV=production DATABASE_URL=sqlite3:/redmine/tmp/gantt_visual/RUN_ID/expected.sqlite3 SECRET_KEY_BASE=gantt-visual-only RUBYOPT=-r/redmine/test/gantt_visual/frozen_clock.rb bin/rails server -b 0.0.0.0 -p 3000'
```

比較先では `cd /redmine` と `actual.sqlite3` に置き換える。`GANTT_VISUAL_LIMIT` が指定された
G15の4ケースは、同じ値をサーバー環境へ渡し、`gantt_visual_filter=G15-limit-N` で1ケースずつ
取得する。通常ケースの取得後に比較元・比較先それぞれで再起動する。

## Playwright MCPでの取得

1. Chromeを1335x1000、device scale 1、ブラウザズーム100%にする。
2. 出力ディレクトリを静的HTTPサーバーで配信し、次のcontrol URLへ移動する。`OUTPUT`は
   `GANTT_VISUAL_ROOT`の絶対パスへ置き換える。
3. `browser_run_code_unsafe`へ、このディレクトリの`playwright_capture.js`を`filename`として渡す。
4. expectedの完了後、比較元を比較先へ切り替え、labelを変えてactualを取得する。

```text
python3 -m http.server 8099 --directory "$GANTT_VISUAL_ROOT"

http://127.0.0.1:3000/?gantt_visual_output=OUTPUT&gantt_visual_data=http://127.0.0.1:8099&gantt_visual_label=expected
http://127.0.0.1:3000/?gantt_visual_output=OUTPUT&gantt_visual_data=http://127.0.0.1:8099&gantt_visual_label=actual
```

一部だけ再取得するときはcontrol URLへ`gantt_visual_filter=G01|G02`を加える。
取得後はPDFをRedmined内で画像化してから比較レポートを生成する。ホスト側で画像化すると、
Redminedに追加した日本語・RTL用フォントが使われず、PDFに文字が入っていても画像では欠けることがある。

```sh
redmined -T ruby test/gantt_visual/rasterize_pdfs.rb --root "$GANTT_VISUAL_ROOT"
python3 test/gantt_visual/compare.py --root "$GANTT_VISUAL_ROOT"
```

一部だけ再取得した場合は、`rasterize_pdfs.rb --filter 'actual/G17-'` のように対象PDFを
正規表現で絞り込める。比較も `compare.py --filter '^G17-'` で同じように対象ケースを
絞り込める。

ブラウザを同時に複数起動すると検証コンテナのメモリを圧迫するので、比較元・比較先は順番に実行する。
絞り込みはcontrol URLの `gantt_visual_filter` に正規表現を渡す（例: `G11|G12|G18`）。
同じケースの再実行時には、その側のケースディレクトリの生成物を置き換える。比較元はデータや取得処理を修正したとき以外は再取得しない。

画面画像は現在のスクロール位置を基本画像として取得する。タイムラインの端の確認が必要なだけの
横スクロール量がある場合に限り、基本画像と異なる位置の`timeline-start`または`timeline-end`を
追加で取得する。短い期間や縮小表示で期間全体が収まる場合、および基本画像がすでに端にある場合は、
同じ位置の画像を重複して生成しない。

サーバーは各側の取得終了後に停止する。この手順は3000番を占有するため、既存の開発サーバーを
先に停止し、検証完了後に必要なら再起動する。

## 判定の範囲

- 独立した fixture の ID 一覧と表示対象を比較。基本ケースの行順を明示し、全ケースの論理行・順序・可視性を前後比較する。
- 開閉、リサイズ、ツールチップ、右クリック、複数選択には操作 assertion を加える。
- 論理行、警告、今日線、選択状態、関連線の本数を比較し、画素差分とは別に失敗させる。
- G14 は初期クエリと操作後の確定クエリの PDF / PNG を取得する。
- G19 は計画通り画面のみ。他のケースでは Chromium の `Page.printToPDF` を使用する。
- PDF の全ページをRedmined内で96 DPIの画像にし、PDF / PNGエクスポートと画面画像を
  RGBA の全チャンネルで閾値なしに比較する。
- 生成失敗・欠けたページ・HTTP失敗・意味の不一致を、単なる画素差分と分ける。
- 画素差分は自動で許容しない。`report.html` の前後・差分から人間が判断する。

OS の印刷ダイアログのキャンセル、Safari/Firefox、実プリンターはこのツールの対象外。
G20 は Chromium の実際の PDF 生成と復帰後の開閉・リサイズまでを自動確認する。
性能計測は画像取得と分けて行う。

## 非公開の中間プロジェクトの回帰ケース

`G13-hidden-project` は、公開の親 → 非公開の中間プロジェクト → 公開の子という構造を、
非公開プロジェクトのメンバーではない `jsmith` で表示する。
親にもチケットを割り当て、既存の展開アイコンが表示される条件で検証する。

初期表示と再展開後は両側で同じ4行を期待する。親を閉じた正しい状態は親の1行だけ。
件名、選択列、タイムラインの全ペインの可視行を確認する。

比較対象のどちらが修正済みかを固定しない:

| 比較元 | 比較先 | 判定 |
| --- | --- | --- |
| 正しい | 正しい | 一致 |
| 子とチケットが残る既存の不具合 | 同じ既存の不具合 | baseline-limitation |
| 既存の不具合 | 正しい | 閉じた状態のみ expected-difference |
| 正しい | 既存の不具合 | 回帰として失敗 |

指定した既存の不具合以外の可視行、ペイン間の不一致、初期表示や再展開後の差分は失敗にする。
画素差分の閾値や除外領域は設けない。結果にbaseline-limitationが含まれる場合は、
すべての仕様検査が成功したという意味ではない。

## プロジェクトの表示状態

G21 はプロジェクト行と展開アイコンを画面で確認するケース。印刷・エクスポートは既存ケースで確認する。

| ケース | 状態 | 期待する表示 |
| --- | --- | --- |
| subprojects-only | 自身のチケット・バージョンがなく、孫プロジェクトにチケットがある | 親・中間・子にアイコンがあり、親から全ペインを開閉できる |
| issues-only | チケットのみ | プロジェクトとチケット |
| versions-only | 空のバージョンのみ | プロジェクト行もバージョン行も表示しない |
| version-issues | 自身のバージョンに対象チケットがある | プロジェクト・バージョン・チケット |
| shared-version | 他プロジェクトの共有バージョンに対象チケットがある | 自身のプロジェクト配下に共有バージョンとチケット |
| version-parent | 空のバージョンと子プロジェクトがある | 親・子・チケット。空のバージョンは表示しない |
| empty | チケット・バージョン・子プロジェクトがない | 行を表示しない |
| filtered-parent | 自身のチケットがフィルターで除外され、子に対象チケットがある | 親・子・対象チケット |
| subprojects-limit-1 | 子孫のみを持つ親の行で上限に達する | 親の1行にアイコンを残す |

行のキー・順序・アイコンを独立した期待値と照合する。修正前に欠ける親・中間プロジェクトの
アイコンは明示的に指定し、両側に残る場合は baseline-limitation、修正されれば expected-difference、
再発すれば failure とする。比較元・比較先のラベルで正否を固定しない。
subprojects-only の修正前は親のアイコンをクリックできないため、その状態を取得する。
別プロジェクトのアイコンを代わりにクリックすることはしない。

subprojects-limit-1 は G15-limit-1 と同様、`GANTT_VISUAL_LIMIT=1` をサーバーに指定して取得する。
G21 の他ケースは通常の上限500で実行する。

## 共通ツールとしての利用

今後のガント開発では `gantt_test` ブランチのツールを使う。
開発ブランチに検証ツールを複製せず、[../GANTT_TESTING.md](../GANTT_TESTING.md) の手順で
一時ディレクトリへ取り出す。`seed.rb` は実行対象のRailsチェックアウトからfixtureと
object helpersを読み込むため、ツールがチェックアウト外にあっても実行できる。

検証ツールの判定ロジックを変更した場合は、Python依存を用意した環境で次を実行する:

```sh
python3 -m unittest discover -s test/gantt_visual -p 'test_*.py'
```

## ウィンドウリサイズ

`G22-resize-*` は、ズーム1/4、親の開閉、手動列幅変更、多数行の5ケース。
各ケースで1600→900→899→375→1335pxへビューポートを変更する。
選択列を表示するのは手動列幅のケースのみ。すべての画像は関連先タスクへ横スクロールして取得し、
画面内に関連線・矢印・進捗線が見えることを検査する。期間の空白の両端画像は追加しない。

`seed.rb` の専用データには、前向き・重なり・上向き・親から通常チケットへの関連、
0%・部分進捗・完了・未来のチケットを用意している。多数行でも関連のある行は先頭に置く。
`cases.py` 実行後、`line_checks.js` を結果ルート（`cases.json` と同じ場所）へコピーし、
同じデータサーバーで配信する。

```sh
cp test/gantt_visual/line_checks.js "$GANTT_VISUAL_ROOT/line_checks.js"
node --test test/gantt_visual/test_line_checks.cjs
python3 -m unittest discover -s test/gantt_visual -p 'test_*.py'
```

前後比較に加え、各側を独立に検査する。期待値はfixtureの関連・日付・進捗率から作り、
controllerの経路生成やjQueryの座標計算は再利用しない。

- 関連の始点が元バー、矢印が先バーの中央に接続し、線分と矢印が連続している。
- 非表示の行への関連は描かれず、表示中の期待する関連がすべて存在する。
- タスクの日付と幅、件名とタイムラインの行位置が一致する。
- 進捗線の各頂点が対応する可視行内にあり、進捗率による位置、0%の開始位置、完了時の今日位置に一致する。
- 関連線・矢印・進捗線が実際の画面のクリップ範囲内に見える。

バーのborderと線のstrokeの重なりを考慮し、接続位置には2pxの幾何的な許容幅を設ける。
画像の画素比較には閾値や除外領域を設けない。
`lineAudit` は測定した端点・期待する中央・バー高さ・進捗頂点・失敗理由を保存する。
前後の線座標が一致しても、両側に同じ正しさの問題があれば双方を失敗として表示する。
印刷とエクスポートは既存ケースで確認するため、G22では重複して取得しない。
