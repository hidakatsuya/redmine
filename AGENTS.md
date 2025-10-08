# Repository Guidelines

## プロジェクト構成とモジュール配置

`app/` が主要な Rails アプリケーションコードを保持し、`app/models`、`app/controllers`、`app/views` で役割が分かれます。共有ロジックは `lib/`、Redmine プラグインは `plugins/`、データベース関連は `db/`、静的アセットは `public/` と `app/assets/` に配置されています。システムテストと単体テストは `test/` 配下にまとまり、追加ドキュメントは `doc/` と `extra/` を確認してください。

## ビルド・テスト・開発コマンド

Redmineの開発は redmined CLI https://github.com/hidakatsuya/redmined を使用します。

- `redmined -T bundle install`, `redmined -T yarn install` : Ruby とフロントエンド依存関係を同期します。
- `redmined -T bin/rails server` : ローカル開発サーバーを起動します。
- `redmined -T bin/rails db:migrate` : スキーマを最新状態に更新します（必要に応じて `RAILS_ENV=test` を指定）。
- `redmined -T bin/rails test` : Minitest ベースのテストスイートを実行します。
- `redmined -T bin/rails assets:clobber assets:precompile` : フロントエンドアセットの再生成と検証を行います。
- `redmined -T bundle exec rubocop` : コードスタイルをチェックします。
- `redmined -T bundle exec rubocop -a` : コードスタイルを自動修正します。
- `redmined -T bin/importmap pin <npm-package>` : importmap-rails を使用して npm パッケージをピン留めします。

その他、Rails などのコマンドを実行する場合は、すべて `redmined -T` を付けて実行してください。

## コーディングスタイルと命名規約

Ruby は RuboCop 基準（2 スペースインデント、snake_case メソッド/変数、CamelCase クラス）に合わせます。ERB テンプレートは HTML5 構造を保ち、必要な場合のみ `<%=` を使用します。JavaScript/CSS は `app/assets` で管理し、Stylelint 設定に従って BEM に近い命名と 2 スペースインデントを統一します。翻訳キーは `config/locales/*.yml` に snake_case で追加してください。

JavaScript については、古くから `app/assets` で管理されていますが、少しずつ Stimulus コントローラーへの移行を進めています。それらは `app/javascripts` に配置されます。基本的に JavaScript を伴う機能追加は、Stimulus コントローラーで実装します。また、ライブラリを使う場合も、importmap-rails https://github.com/rails/importmap-rails を使用して `config/importmap.rb` に追加して使用します。

## テストガイドライ

標準テストフレームワークは ActiveSupport::TestCase です。テストファイルは、`test/` 配下に次のように分類して配置されています。これら以外の空のディレクトリは使用しません。

- `test/fixtures` : テストフィクスチャの定義
- `test/functional` : 主にコントローラーテストを配置
- `test/generators` : ジェネレーターのテストを配置
- `test/helpers` : ヘルパーのテストを配置
- `test/integration` : 結合テストを配置
- `test/mailers` : メーラーのテストを配置
- `test/system` : システムテストを配置
- `test/unit` : モデル、ジョブ、`lib/redmine` など、上記以外のテストを配置

`test/models/foo_test.rb` のように対象ごとにディレクトリを揃え、メソッドは `test 'subject'` で説明します。新機能は必要なテストをすべて用意し、それらのテストでカバーできない動作はシステムテストを用意します。リグレッションにはフィクスチャを活用し、DB 変更を伴う場合はテスト環境でのマイグレーションを確認してください。フィクスチャは、`ActiveSupport::TestCase` にて、`fixtures :all` を宣言して常にすべてのフィクスチャをロードしているので、テストで個別に `fixtures` を宣言する必要はありません。

## コミットとプルリクエスト方針

コミットメッセージは短い要約（英語 imperative）と必要なら詳細本文を追加してください。このリポジトリは、redmine/redmine のフォークリポジトリですが、redmine/redmine はプロリクエストを受け付けていないため、指示するまでプルリクエストは作成しないでください。
