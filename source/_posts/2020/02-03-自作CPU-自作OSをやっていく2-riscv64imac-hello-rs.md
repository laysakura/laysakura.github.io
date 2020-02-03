---
title: 自作CPU & 自作OSをやっていく (2) - 64ビットRISC-Vの "Hello World" をRustで作った
id: handcraft-cpu-os-2
tags:
  - 自作CPU & 自作OS
date: 2020-02-03 14:45:00
---

{% githubCard user:laysakura repo:riscv64imac-hello-rs %}

2020年1月から、趣味エンジニアリング活動として自作CPUと自作OSをやっていく。

目指してることとか、作りたい成果物とか、ロードマップとか、進捗とかを記録していく。インプットが増えたり手を動かしていくと色々と軌道修正があるだろうから複数記事になるはず。 [自作CPU & 自作OS](/tags/自作CPU-自作OS/) タグで追えるようにしておく。

今回は、64ビットRISC-V (RV64I) の "Hello World" をRustで作ったので、そのリポジトリの紹介。

<!-- more -->

冒頭にも貼ったが、

{% githubCard user:laysakura repo:riscv64imac-hello-rs %}

のリポジトリに公開している。READMEに全部書いてあるが、特徴を抜粋すると

- `Dockerfile` を書いているので、面倒なコンパイラツールチェインなどのインストールを自前で市内で良い。
- 64ビットなRISC-Vターゲットへコンパイルされる（世のサンプルは32ビット版が多いのでちょっと参考になるかも）。
- RustのStableビルドを使う。Nightlyビルドは使わない。
- [xargo](https://github.com/japaric/xargo) を使わず `cargo` を使う。
- Visual Studio Codeを使う人なら、Remote Development Containerで走るように設定ファイルを同梱している。

あたり。

参考にさせていただいた [RustでRISC-V OS自作！はじめの一歩](https://qiita.com/tomoyuki-nakabayashi/items/76f912adb6b7da6030c7) とファイル構成は同じなので、比較しながら読めば十分に挙動は追えるはず（解説をサボった）。こちらの記事との差分は、

- 64ビット版であること。
- QEMUで `-machine sifive_u` ではなく `-machine virt` を使った。それに伴いUARTのアドレスが `0x10013000` から `0x10000000` に変わった。
- リンカスクリプトで無駄を省いたりコメント追加したりした。あと `MEMORY` コマンドを使った（と言っても定義して実際に使ったのはRAMだけだが...）。
- `boot.s` で、スタック領域を確保するときに `la` アセンブリ疑似命令を使うようにした。

あたり。

## 苦労したこと・学んだこと

- RustのStableビルドで勝負するなら、インラインアセンブリが使えないので、生アセンブリファイルを書く必要がある。
- 生アセンブリファイルを書いた瞬間に、[RISC-V用のコンパイラツールチェイン](https://github.com/riscv/riscv-gnu-toolchain) が必要になる。アセンブリファイルのアセンブルのため、その結果のオブジェクトファイルを `rustc` でコンパイルした別のオブジェクトファイルとリンクするため。
    - `rustc` がバックエンドに使ってるLLVMでRISC-V用のオブジェクトファイル生成もリンクもできているわけなので、本来的には不要なはず。 `build.rs` をもっと上手に書けば不要にできるのか...？🤷
- QEMUのバージョンの違いで "Hello World" が出力されたりされなかったり...
    - UARTのアドレスを規定するのがQEMUだと理解するまでは「謎挙動」に見えて苦しんでいた。 https://gitlab.freedesktop.org/spice/qemu/blob/e24f44dbeab8e54c72bdaedbd35453fb2a6c38da/hw/riscv/virt.c#L51-63 を見つけてようやく意味がわかった。
- スタック領域確保、64ビットにした途端に動かなくなった...
    - 最終的に `la` を使って回避したが、 [RustでRISC-V OS自作！はじめの一歩](https://qiita.com/tomoyuki-nakabayashi/items/76f912adb6b7da6030c7) のまま `lui` と `ori` 使う形式でも動きそうなもんだけどな...🤔
- リンカスクリプト何もわからん状態だったが、 [リンカスクリプトの書き方](http://blueeyes.sakura.ne.jp/2018/10/31/1676/) 読んでだいぶ分かるようになった気がするありがたい。
- SiFiveはRISC-Vクロスコンパイル用のビルド済みgccもqemuを提供してくれていてとてもありがたいけど、Ubuntu 14.04前提なのが厳しかった。特に `riscv64-unknown-elf-gdb` と `qemu-system-riscv64` 起動に必要な動的ライブラリの適切なバージョンを引っ張ってくるので地獄を見た（最初は `rust` dockerイメージで頑張ってたけど匙投げて `ubuntu:14.04` 使うようにしてから苦行程度に落ち着いた）。
