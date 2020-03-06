---
title: ぼくのかんがえたさいきょうの Circle CI 設定 for Rust
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

# YAMLのアンカー
# (See: https://magazine.rubyist.net/articles/0009/0009-YAML.html#%E3%82%A2%E3%83%B3%E3%82%AB%E3%83%BC%E3%81%A8%E3%82%A8%E3%82%A4%E3%83%AA%E3%82%A2%E3%82%B9 )
# を用いて、共通で使うコマンドやキャッシュキーを定義する。
references:
  commands:
    build_dep: &build_dep
      name: Record build environment to use as cache key
      command: |
        echo $OS_VERSION | tee /tmp/build-dep
        rustc --version | tee /tmp/build-dep
        cat Cargo.lock >> /tmp/build-dep

    cache-key: &cache-key v1-cache-cargo-target-{{ .Environment.CIRCLE_JOB }}-{{ .Environment.CIRCLECI_CACHE_VERSION }}-{{ checksum "/tmp/build-dep" }}

jobs:
  lint:
    executor:
      name: default
    steps:
      - checkout

      # 環境情報からキャッシュキーを構築し、キャッシュをrestore
      - run: *build_dep
      - restore_cache:
          key: *cache-key

      - run:
          name: rustup component add
          command: rustup component add clippy rustfmt
      - run:
          name: fmt
          command: cargo fmt --all -- --check

      # clippyのwarningも全て CI fail にする。お好みで。
      - run:
          name: clippy
          command: cargo clippy --all-targets --all-features -- -D warnings

      - save_cache:
          key: *cache-key
          paths:
            - ~/.cargo

  # rustdocとREADMEを比較の比較。お好みで。
  readme:
    executor:
      name: default
    steps:
      - checkout

      - run: *build_dep
      - restore_cache:
          key: *cache-key

      - run:
          name: Install cargo-readme
          command: cargo install cargo-readme
      - run:
          name: Check diff between rustdoc & README
          command: |
            cargo readme | tee /tmp/README.md
            diff /tmp/README.md README.md

      - save_cache:
          key: *cache-key
          paths:
            - ~/.cargo

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

      - run: *build_dep
      - restore_cache:
          key: *cache-key

      - run:
          name: build & test
          command: RUST_BACKTRACE=1 cargo test --verbose --all -- --nocapture

      - save_cache:
          key: *cache-key
          paths:
            - ~/.cargo
            - target

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
