# ガントチャートの構造と責務

## 全体の流れ

`GanttsController` が検索条件と表示パラメータを受け取り、`Redmine::Gantt` を作る。
`Dataset` が表示対象・順序・上限を決め、その共通の行列挙からHTMLとPDF/PNGを作る。
HTMLでは `Chart → ProjectSection → 型別Row → Schedule` の順に表示用データを組み立て、ERBがHTMLへ変換する。
ブラウザ上の操作とSVG描画はStimulusが担当する。

## リクエストの入り口

| ファイル・クラス | 役割 |
|---|---|
| `app/controllers/gantts_controller.rb` / `GanttsController` | プロジェクト・保存済みクエリを取得し、グループ化を解除。必要なHTTPパラメータだけをGanttへ渡し、HTML/PDF/PNGへ振り分ける。 |
| `lib/redmine/gantt.rb` / `Redmine::Gantt` | 表示期間・ズーム・上限の正規化、既存のユーザー設定の保存、Dataset・Chart・出力の入口。 |

初期化は次の7個のキーワード引数で明示する。位置引数や汎用 `options` は使わない。

```ruby
gantt = Redmine::Gantt.new(
  query: query, project: project,
  year: 2026, month: 6, zoom: 3, months: 6,
  max_rows: 500
)
```

`query:` は必須。HTMLでクエリのエラーだけを表示するときは `nil` を渡す。
`project:` は省略時 `nil`（全体表示）。残りの表示引数には既存のデフォルトを適用する。
`max_rows:` の省略は管理設定、明示的な `nil` は上限なし。この違いをキーワード引数のデフォルト値で表す。

queryとprojectのsetterは設けない。条件が変われば新しいGanttを作るため、キャッシュをnilに戻す処理は不要。
ただし、渡されたIssueQueryやActive Recordオブジェクト自体を深くfreezeしているわけではない。
構築後に検索条件を書き換えず、リクエスト・ユーザーをまたいでGanttを共有しない。
初期化時のユーザー設定保存は旧実装から維持している副作用である。
初期化の詳細はprivateメソッドへ分ける。`resolve_start_date` は開始日の決定、
`normalize_zoom`・`normalize_months` は引数・ユーザー設定の正規化、
`save_preferences` はログイン済みかつ値が変わった場合の保存を担当する。

## データとViewModel

以下のファイルは `lib/redmine/gantt/` にある。`Project`・`Version`・`Issue` は
`Redmine::Gantt` 名前空間の表示用クラスで、DBモデルの `::Project` 等とは別物。

| ファイル・クラス | 役割 |
|---|---|
| `dataset.rb` / `Dataset` | IssueQueryの結果、可視な祖先プロジェクト、バージョン、関連、行順、全体の行数上限を管理。HTMLとエクスポートの共通データ源。 |
| `chart.rb` / `Chart::Builder` | Datasetと表示条件からChartを構築。目盛り、表示列、今日の位置、表示範囲内の関連を計算する。 |
| `chart.rb` / `Chart` | チャート全体の表示用値とセクションを保持する。構築後はfreeze。`row_count` は行ViewModelを作らずに求める。 |
| `Chart::Relation` | 関連元・先の行キーと関連種別。 |
| `Chart::ScaleLayer`・`ScaleSegment` | 月・週・日などの目盛り段と、そのラベル・開始位置・幅・休日情報。 |
| `project_section.rb` / `ProjectSection` | 1プロジェクト自身と、そのバージョン・チケットの表示単位。子プロジェクトは別セクション。描画時に1行ずつViewModelを作る。 |
| `row.rb` / `Row` | 行キー、親行キー、深さ、件名、開閉可否、Scheduleなどの共通契約と計算処理。 |
| `project.rb` / `Project` | プロジェクト行の件名・集計スケジュール・期限超過の表示用データ。 |
| `version.rb` / `Version` | バージョン行の進捗・状態・スケジュール。共有バージョンは表示先プロジェクト別の行キーを持つ。 |
| `issue.rb` / `Issue` | チケット行の状態、親子構造、コンテキストメニュー可否、スケジュール。 |
| `schedule.rb` / `Schedule` | 日付・進捗から、バー・遅延部分・進捗部分・端点の日単位オフセットを計算。画素/PDF単位への変換は各出力側で行う。 |

Datasetはレコードをキャッシュする。ProjectSectionは行ViewModelの配列を常時保持しない。
`section.rows` や `chart.rows` は配列化する便利メソッドで、通常の描画では `section.each_row` を使う。

### `enum_for` は何をしているか

```ruby
def each_project
  return enum_for(__method__) unless block_given?
  # ブロックがあれば project, depth, row_count を yield する
end
```

`__method__` は現在のメソッド名。`enum_for` は、そのメソッドの列挙を表すEnumeratorを返す。
その時点では列挙本体を実行しない。これにより、同じメソッドを次の両方の形で使える。

```ruby
dataset.each_project { |project, depth, count| ... }
dataset.each_project.find { |project, depth, count| project.id == requested_id }
```

この実装では `Chart::Builder` の `.map`、セクション取得の `.find`、
`project_rows(...).take(limit)`、関連用の `.filter_map` が利用するため必要。
削除するとブロックなしの呼び出しで `yield` が失敗する。
Enumerator自体は全件配列を作らないが、`.map`・`.to_a` は配列化し、`.take(n)` は最大n件を配列化する。
列挙可能にしただけでDB取得まで逐次処理になるわけではない。

### プロジェクト単位の取得と今後の更新

`gantt.project_section(project)` は、そのプロジェクトが全体チャートに含まれる場合のみセクションを返す。
`each_project` は全体の行数上限を先に配分するため、部分取得で上限外の行が紛れ込まない。
他プロジェクトのViewModelは作らないが、所属判定のため上限付きの検索結果全体は取得する。
DBクエリまでプロジェクト単位に分割したAPIではない。

Turboでセクションを更新する際は、祖先の集計、共有バージョン、プロジェクト間の関連線も更新対象になり得る。
検索結果や上限の配分が変わる場合は他セクションにも影響する。現在は更新用エンドポイントを設けていない。

## ビューとヘルパー

| ファイル | 役割 |
|---|---|
| `app/views/gantts/show.html.erb` | 画面タイトル、クエリエラー、フォーム、チャート、サイドバー、必要なスタイルを配置。 |
| `app/views/gantts/_query_form.html.erb` | フィルタ、表示列、関連線・進捗線、期間、ズームの操作フォーム。 |
| `app/views/gantts/_chart.html.erb` | ヘッダー、情報列、背景グリッド、セクション一覧、SVGレイヤー、前後リンクを配置。 |
| `app/views/gantts/chart/_project_section.html.erb` | `gantt-project-ID` の更新可能なHTML境界。each_rowで型別部分テンプレートを描画。 |
| `app/views/gantts/chart/_project.html.erb` | プロジェクトの件名・追加列・タイムライン。 |
| `app/views/gantts/chart/_version.html.erb` | バージョンの件名・追加列・タイムライン。 |
| `app/views/gantts/chart/_issue.html.erb` | チケットの件名・アイコン・選択用チェックボックス・追加列・タイムライン。 |
| `app/views/gantts/chart/_schedule.html.erb` | 全行型共通のバー、遅延・完了部分、端点、ラベル、操作領域。 |
| `app/helpers/gantts/chart_helper.rb` / `Gantts::ChartHelper` | ViewModelからHTML属性・CSS変数・Stimulusデータ・アイコンを組み立てる。 |
| `app/helpers/gantt_helper.rb` / `GanttHelper` | 前後・月・ズーム・出力リンクに使うパラメータ生成、ズームリンク、ChartHelperの取り込み。 |
| `app/assets/stylesheets/gantt.css` | Grid構造、固定情報列、バー・目盛り、印刷レイアウト。 |
| `app/assets/stylesheets/context_menu.css` | Redmine共通の選択表示。ガントの件名は不透明な青と白い文字、バーは半透明の選択色。 |

DB取得と行順の判断はDataset、表示用状態はViewModel、HTMLの表現はERB/Helperに置く。
永続化しないガント専用クラスは `lib/redmine/gantt/` にまとめ、DBモデルは既存の `app/models/` を利用する。

## JavaScript

ガント専用Stimulusコントローラは `app/javascript/controllers/gantt/` に置く。

| ファイル | 役割 |
|---|---|
| `options_controller.js` | フォームの表示列・関連線・進捗線の変更をイベント通知。既存の列選択UIとの連携にjQueryを利用。 |
| `subjects_controller.js` | 行キー・親行キーと開閉状態から子孫の可視性を更新し、レイアウト変更を通知。 |
| `column_controller.js` | 追加情報列のPointer操作を幅変更イベントに変換。 |
| `splitter_controller.js` | 件名ペインの幅を変更し、CSS変数とイベントで通知。 |
| `chart_controller.js` | 上記イベントを受けて表示状態を反映。DOMのバー位置から関連線・進捗線をネイティブSVGで描画。ResizeObserverとrequestAnimationFrameで再描画をまとめる。印刷前後の配置切替も担当。 |

件名・バーの右クリックや複数選択は既存の `app/assets/javascripts/context_menu.js` と連携する。
取得対象の関連種別は `Dataset::RELATION_TYPES`、色と描画間隔は `ChartHelper::RELATION_STYLES` に定義する。
凡例とSVG描画は同じスタイル定義を利用し、データ取得は表示スタイルに依存しない。
ガント専用JSはDBの検索・行順・業務上の日程を決めない。Raphaelは利用しない。
関連線は旧実装のcontent-box寸法を基準に接続点と回り込み位置を決める。

## PDF・PNGと画面印刷

| ファイル・クラス | 役割 |
|---|---|
| `lib/redmine/gantt/exports/base.rb` / `Exports::Base` | Datasetの共通行列挙、ラベル、日付座標など、エクスポート間の共通処理。 |
| `lib/redmine/gantt/exports/pdf.rb` / `Exports::PDF` | 既存ITCPDFの描画・改ページを維持。 |
| `lib/redmine/gantt/exports/image.rb` / `Exports::Image` | 既存MiniMagickの画像描画を維持。MiniMagickがロードされている場合のみ利用可能。 |

PDF/PNGはHTMLのスクリーンショットではなく、DatasetとScheduleを使って直接描画する。
HTML用の行ViewModelは生成しない。
画面印刷はHTML/CSS/SVGをブラウザが印刷する別経路で、印刷前に可視行と関連線を同じ連続座標面に置く。
旧実装と同様、改ページ境界で件名が欠ける既知の制約がある。検証範囲は `GANTT_TEST_RESULTS.md` を参照。
