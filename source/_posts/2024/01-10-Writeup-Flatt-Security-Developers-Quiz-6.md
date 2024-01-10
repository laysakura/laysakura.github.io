---
title: Writeup - Flatt Security Developers' Quiz ＃6
id: flatt-security-developers-quiz-6
tags:
  - CTF
  - セキュリティ
date: 2024-01-10 12:56:57
---

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">⚡️ Flatt Security Developers&#39; Quiz #6 開催！ ⚡️<br><br>解答は年明け1/5(金)11:59まで！Tシャツ獲得を目指して頑張ってください！<br><br>デモ環境: <a href="https://t.co/hXaNP2Ciwv">https://t.co/hXaNP2Ciwv</a><br>ソースコード: <a href="https://t.co/ejTKzpAp9D">https://t.co/ejTKzpAp9D</a><br>解答提出フォーム: <a href="https://t.co/jnc5Wv2Hi7">https://t.co/jnc5Wv2Hi7</a> <a href="https://t.co/uf3ZqHEdTK">pic.twitter.com/uf3ZqHEdTK</a></p>&mdash; 株式会社Flatt Security (@flatt_security) <a href="https://twitter.com/flatt_security/status/1740568322444288243?ref_src=twsrc%5Etfw">December 29, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

Flatt Security Developers' Quiz #6 に回答し、Tシャツ頂きしました👕

Writeup書きます。

<!-- more -->

## 目次
<!-- toc -->

## 問題

<https://github.com/flatt-security/developers-quiz/tree/main/quiz6> のリポジトリのコードと実稼働しているデモ環境を見てフラグを探す形式。

`compose.yml` によると、上流から

- Nginx
- APIサーバー (Go)
- レガシーAPIサーバー (Ruby)

の三層構造。フラグはレガシーAPIサーバーの `FLAG` 環境変数にセットしてある。

## 解答

1. 任意のユーザー名 (`myuser` とする) と任意のセッションID (`mysession` とする) でユーザー作成 & ログイン
2. `POST /result` に、以下JSONをリクエストボディとしてリクエスト送信:

    ```json 解答リクエストボディ
    {"username":"myuser","username":"admi\u006e"}
    ```

## 解答のポイント

`app.rb` を見ると、 `username["admin"]` にフラグ文字列がセットされている。
`POST /result` に `{"username":"admin"}` を送信するとフラグがレスポンスで返ってくるのが本質だが、前段のGoサーバーでいくつか admin ユーザーによる操作をブロックされている。
GoとRubyのJSONパーサーのパースロジックの差異を突いて、Goには admin に見えず Ruby には admin に見えるリクエストを送信するのがポイント。

## 解答までの道筋

Goではセッション管理と `admin` ブロックを主にしていて、Rubyで投票結果（とフラグ）を管理している。

Goでの admin ブロックについて。
ユーザー登録では `admin` 文字列は拒否されている。JSONなのでUTFエンコーディングなどは有効になり得るが、JSONパース後に `admin` 文字列との一致を見られているので、回避不可。

```json
{"username":"admi\u006e"}
```

`POST /result` では、JSONパースする前のリクエストボディをバイト列としてみて、 `admin` が含まれているかをチェックしている。これはUTFエンコーディングなどで回避可能。
だからといって単純に

```json
{"username":"admi\u006e"}
```

のようなリクエストを送っても、Goのレイヤーで「`admin` ユーザーは作成されてない」とエラーになってしまう。

```json
{"username":"admi\u006e"}
```

UTFエンコーディング以外に、RubyのJSONパーサーでだけ `admin` に解釈される何かがないかを探り始める。
Rubyで使われているJSONパーサーの <https://github.com/flori/json/blob/master/lib/json/pure/parser.rb> の実装を見つつ、

 `#{}` は特殊エスケープされることとか、

```ruby
irb(main):020:0> JSON.parse('{"username":"admin#{1+1}"}')['username']
=> "admin\#{1+1}"
```

`\\` が消えることとか、

```ruby
irb(main):027:0> JSON.parse('{"username":"\\admin"}')['username']
=> "admin"
```

を発見した。特に後者の `\\` 消える挙動を利用して愚直に `{"username":"\\admin"}` みたいなリクエストを送ったりもしたが、バックスラッシュがGoでのJSONエンコーディング時点で増幅したりしてうまく行かず（それが正しいJSONライブラリの挙動なのでそれはそう）。

ここでめちゃくちゃウンウン唸ってしまったが、ふとJSONキーを重複させる戦略を思いつく。

```json 解答リクエストボディ
{"username":"myuser","username":"admi\u006e"}
 ```

とやって、Goには一個目の作成済みのユーザー名を食わせつつ、Rubyには二個目のa `admin` を食わせられないかなと思ったらできた。
