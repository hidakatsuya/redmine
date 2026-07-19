# AGENTS.md

## 開発

* `bin/rails test` など Rails のコマンドは redmined CLI https://github.com/hidakatsuya/redmined を使って実行する。その際 `redmined -T bin/rails test` のように `-T` オプションをつけて実行する
* redmined CLI は Apple container https://github.com/apple/container で動作させる。もし、Apple container が起動していない場合は、`container system start` で起動する

## 作業記録と後続の開発に影響を与える意思決定の扱い

* 作業中にコンテキストの圧縮が起こると作業に必要な重要な情報が欠落する場合がある。それを回避するため、重要な意思決定や必要な作業記録は、指示された pull request または Issue のコメントに記録する
* 指示された pull request または issue のコメントへの追加は、hidakatsuya/redmine リポジトリのみ許可する。それ以外のリポジトリにはコメントしてはならない
* 作業を始める際は、指示された pull request または issue のコメントを確認して作業を行うこと
