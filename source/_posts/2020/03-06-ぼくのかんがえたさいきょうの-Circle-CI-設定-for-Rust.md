---
title: ぼくのかんがえたさいきょうの CircleCI 設定 for Rust
id: rust-circle-ci
tags:
  - Rust
date: 2020-03-06 07:02:35
---

あまり見ない気がするので書きました。特徴は、

- lint, testなどの各ジョブが並列に動く（ジョブ実行数を多くしてないとdocker containerの立ち上げ分むしろ全体時間はロスになることもあるが...）。
- [Travis CI のマトリクスビルド](https://docs.travis-ci.com/user/build-matrix/#matrix-expansion) に近いことを、 `parameters:` を使ってやっている。
    - [`rust-toolchain` ファイル](http://www.soudegesu.com/post/rust/rust-with-rustup/#%E3%83%84%E3%83%BC%E3%83%AB%E3%83%81%E3%82%A7%E3%82%A4%E3%83%B3%E3%82%92%E5%9B%BA%E5%AE%9A%E3%81%99%E3%82%8B) に書かれたバージョンと、 `.circleci/config.yml` に書かれた MSRV (Minimum Supported Rust Version) の2つでビルドしている。
- `cargo-readme` を使ってrustdocとREADMEを比較し、どちらかがメンテされていない場合にエラーにする（お好みで）。
- キャッシュ使う。

あたりです。見慣れなさそうなところはインラインコメント付けましたので参考にしてください 💁‍♀️

<!-- more -->

## 更新履歴

- 2020/03/09
    - rust-jp Slackスペースでの sinsoku さんのご指摘により、以下修正 🙏
        - job中のコマンドをYAMLのアンカーで共通化していたのを、CircleCIの [`commands:`](https://circleci.com/docs/ja/2.0/configuration-reference/#commandsversion21-%E3%81%8C%E5%BF%85%E9%A0%88) 機能を使うように修正。
        - キャッシュをリストアする際に、キャッシュキーを複数設定するように修正。


```yml .circleci/config.yml
version: 2.1

# こうすると各ジョブの中で
#   executor:
#     name: default
# と指定できて便利。
executors:
  default:
    docker:
      - image: circleci/rust:latest
    working_directory: ~/app

# どのジョブでも使うキャッシュ関連のコマンドを共通定義。
# See: https://circleci.com/docs/ja/2.0/configuration-reference/#commandsversion21-%E3%81%8C%E5%BF%85%E9%A0%88
commands:
  record_build_env:
    steps:
      - run:
          name: Record build environment to use as cache key
          command: |
            echo $OS_VERSION | tee /tmp/build-env
            rustc --version | tee /tmp/build-env

  save_cache_:  # `save_cache` は予約語なのでアンダースコアをつける。
    steps:
      - save_cache:
          # CIRCLECI_CACHE_VERSION 環境変数は、キャッシュをパージしたくなった際にセットする（または今までセットしていたのとは異なる文字列をセットする）。
          # CIRCLE_JOB は CircleCI が勝手にセットしてくれる。この例だと `lint`, `readme`, `MSRV (Minimum Supported Rust Version)` などがセットされる。
          key: cache-cargo-target-{{ .Environment.CIRCLECI_CACHE_VERSION }}-{{ .Environment.CIRCLE_JOB }}-{{ checksum "/tmp/build-env" }}-{{ checksum "Cargo.lock" }}
          paths:
            - ~/.cargo
            - target

  restore_cache_:  # `restore_cache` は予約語なのでアンダースコアをつける。
    steps:
      - restore_cache:
          keys:
            - cache-cargo-target-{{ .Environment.CIRCLECI_CACHE_VERSION }}-{{ .Environment.CIRCLE_JOB }}-{{ checksum "/tmp/build-env" }}-{{ checksum "Cargo.lock" }}

            # 依存関係を追加するなどして Cargo.lock に変更があった際も、同一ジョブ・同一環境の最新のキャッシュをリストアする。
            # さもないと、依存関係の微修正でもフルビルドが走ってしまう。
            #
            # CircleCIのキャッシュキーは、上の候補から順番に前方一致で検索される。
            # See: https://circleci.com/docs/ja/2.0/caching/#%E3%82%BD%E3%83%BC%E3%82%B9%E3%82%B3%E3%83%BC%E3%83%89%E3%81%AE%E3%82%AD%E3%83%A3%E3%83%83%E3%82%B7%E3%83%A5
            - cache-cargo-target-{{ .Environment.CIRCLECI_CACHE_VERSION }}-{{ .Environment.CIRCLE_JOB }}-{{ checksum "/tmp/build-env" }}

jobs:
  lint:
    executor:
      name: default
    steps:
      - checkout

      # `commands:` で定義したコマンドを呼び出す。
      # 環境情報からキャッシュキーを構築し、キャッシュをリストア。
      - record_build_env
      - restore_cache_

      - run:
          name: rustup component add
          command: rustup component add clippy rustfmt

      # clippyのwarningも全て CI fail にする。お好みで。
      - run:
          name: fmt
          command: cargo fmt --all -- --check
      - run:
          name: clippy
          command: cargo clippy --all-targets --all-features -- -D warnings

      - save_cache_

  # rustdocとREADMEを比較。お好みで。
  readme:
    executor:
      name: default
    steps:
      - checkout

      - record_build_env
      - restore_cache_

      - run:
          name: Install cargo-readme
          command: cargo install cargo-readme
      - run:
          name: Check diff between rustdoc & README
          command: |
            cargo readme | tee /tmp/README.md
            diff /tmp/README.md README.md

      - save_cache_

  test:
    # マトリクスビルドもどきを実現するためのパラメータ定義。パラメータを与えて呼び出しているのは最下部の `workflows: -> test: -> jobs: -> test:` の箇所。
    parameters:
      rust_version:
        type: string
        default: ""
    executor:
      name: default
    steps:
      - checkout
      - run:
          name: rustup version
          command: rustup --version

      # rust_version パラメータが与えられている場合に限り、そのバージョンの rustc をインストールし、 `rust override set` する。
      # そうでなければ何もしないので、後続の `cargo` コマンド実行時に `rust-toolchain` ファイルに記載された rustc が勝手にインストールされて使用される。
      - when:
          condition: << parameters.rust_version >>
          steps:
            - run:
                name: Install & select $rust_version if specified
                command: |
                  rustup install << parameters.rust_version >>
                  rustup override set << parameters.rust_version >>

      - record_build_env
      - restore_cache_

      - run:
          name: build & test
          command: RUST_BACKTRACE=1 cargo test --verbose --all -- --nocapture

      - save_cache_

workflows:
  version: 2
  test:
    jobs:
      - readme
      - lint

      # パラメータでMSRVを指定
      - test:
          name: MSRV (Minimum Supported Rust Version)
          rust_version: 1.40.0

      # パラメータ指定なしなので、 rust-toolchain に記載のバージョンが使われる
      - test:
          name: Rust Version from `rust-toolchain`
```
