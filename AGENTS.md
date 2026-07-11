# AGENTS.md

* これは Redmine https://www.redmine.org/ のリポジトリ https://github.com/redmine/redmine の fork リポジトリ
* Redmine の開発のため pull request を作成し、最終的にパッチファイルを作成して redmine.org に提出する。そのため、pull request はマージしない

## 開発

* Redmined https://github.com/hidakatsuya/redmined を使う
* Redmined は Apple container https://github.com/apple/container で使う。Apple container が起動していない場合は `container system start` を実行して起動する
* Rails 関連のコマンドは全て Redmined を通して実行する
* `redmined` は non tty モードで実行する: `redmined -T ls`
* 例:
  ```
  redmined -T bin/rails test
  redmined -T bin/rails db:migrate
  redmined -T bundle install
  redmined -T bin/rails redmine:plugins:test
  ```

## redmine.org へ提出するパッチの生成

* 提出するパッチの単位でコミットを作成し、 `git format-patch -k` でパッチファイルを生成する
