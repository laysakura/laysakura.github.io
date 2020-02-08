---
title: 自作CPU & 自作OSをやっていく (3) - riscv/riscv-tests の挙動を追う
id: handcraft-cpu-os-3
tags:
  - 自作CPU & 自作OS
date: 2020-02-08 15:00:00
---

2020年1月から、趣味エンジニアリング活動として自作CPUと自作OSをやっていく。

今回は、自作CPUのパフォーマンスベンチマークとして利用するつもりの [riscv-tests](https://github.com/riscv/riscv-tests) の挙動を追ってみる。
関心があるのは、命令セットやOSの機能をどこまで用意してあげればベンチマークが実行できるのかという点。とりわけ、以下の観点をチェックしていく。

- ISA (命令セット)
    - RV64F (単精度浮動小数点演算), RV64D (倍精度浮動小数点演算) を利用しているベンチマークはあるか。あるとしたらどれか。
    - RV64V (ベクトル演算) を利用しているベンチマークはあるか。あるとしたらどれか。
    - RV64A (アトミック命令) を利用しているベンチマークはあるか。あるとしたらどれか。
- OS機能
    - ヒープ領域は必要か（スタック領域のみで十分か）。
    - スレッドをCPUコアに割り当てるスケジューラは必要か。

[自作CPU & 自作OS](/tags/自作CPU-自作OS/) タグで、この前後の進捗とか目指しているもの（初回記事）とかを追えるようにしている。

<!-- more -->

## 目次
<!-- toc -->

## riscv-tests とは

https://github.com/riscv/riscv-tests に公開されている、RISC-Vのテスト・ベンチマーク群です。
RISC-Vプロジェクトの本拠地UC Berkleyグループが作成しているもので、コミット履歴を見る限りは、「開発自体は落ち着いたが継続的にメンテナンスはされている」というステータスであるように見えます。
RISC-Vなプロセッサやシミュレータを作る人とっては重宝するのではないでしょうか。

### ディレクトリ構造概説: `riscv-tests/isa`

**重要**

RISC-Vの各命令の単体テスト。アセンブリと便利なプリプロセッサマクロで書かれている。
サブディレクトリは `rv64ui` (RV64I, 動作モードはUser) のように区切られており、所望の命令のテストファイルが探しやすくなっている。

### ディレクトリ構造概説: `riscv-tests/benchmarks`

**重要**

ベンチマークプログラム。比較的シンプルなアプリケーションの集合。以下のものが含まれる:

- `dhrystone`: Dhrystone。整数演算を中心とした合成ベンチマーク。
- `median`: 1次元配列に対するメディアンフィルタ。画像のノイズ除去などに使われるアルゴリズムで、「ある要素とその両隣の3要素の中央値を、ある要素に上書きする」という挙動をするもの。
- `mm`: 行列積。
    - [結果出力は物理スレッドのIDを伴う](https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/mm/mm_main.c#L45-L50)が、[データ同じ行列積を各物理スレッドで行っている](https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/mm/mm_main.c#L38)だけなので注意。
    - カーネル部分は性能が出るようにチューニングされている。
- `mt-matmul`: 行列積。こっちか `mm` かに一本化してほしい...
    - 並列計算をしている。上流で \\(A \times B = C\\) の \\(A\\) を物理スレッドの数だけ分割している。
        - ただし、 **各ベンチマークは `benchmarks/common/crt.S` をいじってビルドしないとシングルスレッド動作してしまうので要注意。** ベンチマークが標準でマルチスレッド予定があるかは ["Benchmark runs in single-thread" のIssue](https://github.com/riscv/riscv-tests/issues/240) で確認中。
    - シングルスレッドのカーネル部分は単純な3重ループで性能は出なさそう。
- `mt-vadd`: ベクトルの加算。 \\(コアID mod コア数\\) 番目の要素の足し算を各コアが担当する、単純な並列化が成されている。
- `multiply`: ハードウェアの32ビット乗算器をエミュレートしたようなプログラム。
- `pmp`: PMP (Physical Memory Protection; 物理メモリ保護) のテスト。[ベンチマークではなくテスト](https://github.com/riscv/riscv-tests/issues/232)。
- `qsort`: クイックソート。
- `rsort`: 基数ソート。
    - [コメントにはクイックソートと書かれている](https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/rsort/rsort.c#L7)が.際のコードはどう見ても基数ソート。[Issueでも指摘されている。](https://github.com/riscv/riscv-tests/issues/45)
- `spmv`: 倍精度浮動小数の疎行列・ベクトル積。
    - `towers`: ハノイの塔。
    - `vvadd`: ベクトルの加算。シングルスレッド。

### ディレクトリ構造概説: `riscv-tests/env`

**重要**

サブモジュール。
`riscv-tests/isa` が実行可能ファイルを作るためのリンカスクリプトとエントリポイント用のアセンブリや、 `memcpy` などのユーティリティ関数が含まれている。


### ディレクトリ構造概説: `riscv-tests/mt`

**（たぶん）重要じゃない**

マルチスレッドの行列積やベクトル和のプログラムがたくさんあるが、 [コミット履歴](https://github.com/riscv/riscv-tests/commits/master/mt) を見る感じ、ガッとどこか別のプロジェクトから引っ張ってきて2016年にメンテが途絶えている。

### ディレクトリ構造概説: `riscv-tests/debug`

**（たぶん）重要じゃない**

あんまりしっかり見ていないが、 `riscv-tests/isa` や `riscv-tests/benchmarks` のプログラム自体をデバッグするための諸々に見える。

## riscv-tests を Spike シミュレータで実行する

ISAやOSで特定機能のサポートをする必要があるかを調査するのが目的なので、いきなりコードの静的解析に入っても良いのですが、せっかくなら動かしてみましょう。
といってもRISC-Vなプロセッサの実機もまだ持ってない（これから作る）し、普段遣いのPCは x86_64 なので、[RISC-Vのシミュレータの Spike](https://github.com/riscv/riscv-isa-sim) を使います。

※QEMUでもRISC-Vのシミュレーションはできるはずですが、自分はQEMUでriscv-testsを動作させることはできませんでした...

### Spike とRISC-V用のコンパイラツールチェインをDockerで用意する

ホストマシンの環境差異に悩まされたくないのでDockerを使います。Dockerfileは

{% githubCard user:laysakura repo:docker-riscv-spike-toolchain %}

に置いてあるものを使います。

riscv-tests リポジトリはコンテナの中でcloneしても良いですが、実行結果をファイルにまとめてホストと共有したりすると便利なので、ホストでcloneします。

```bash ホスト上
# riscv-tests のclone
git clone https://github.com/riscv/riscv-tests
cd riscv-tests
git submodule update --init --recursive

# riscv-tests をボリュームマウントして docker run
docker build -t laysakura/docker-riscv-spike-toolchain:latest https://raw.githubusercontent.com/laysakura/docker-riscv-spike-toolchain/master/Dockerfile
docker run -it -v $PWD:/riscv-tests laysakura/docker-riscv-spike-toolchain:latest bash
```

```bash コンテナ内
# spike コマンドの確認
spike --help
-> Spike RISC-V ISA Simulator 1.0.1-dev
-> ...

# riscv64-unknown-elf-gcc コマンドの確認
riscv64-unknown-elf-gcc --version
-> riscv64-unknown-elf-gcc (SiFive GCC 8.3.0-2019.08.0) 8.3.0
-> ...
```

### riscv-tests のビルド

```bash コンテナ内
cd /riscv-tests
apt -y install autoconf
./configure --prefix=$PWD/target
make
make install
```

### `benchmarks` （ベンチマーク）の実行

`/riscv-tests/target/share/riscv-tests/benchmarks/*.riscv` が、RV64アーキテクチャの実行可能なELFファイルです。

```bash コンテナ内
cd /riscv-tests/target/share/riscv-tests/

spike benchmarks/vvadd.riscv
-> mcycle = 2414
-> minstret = 2420
```

パフォーマンスカウンタの値（mcycle: サイクル数, minstret: 実行された命令数）がコンソール出力されています。

### `isa` （命令セットが正しく実装されているかの単体テスト）の実行

```bash コンテナ内
cd /riscv-tests/target/share/riscv-tests/

spike isa/rv64ui-p-add
```

成功実行のときは何もコンソール出力されません。

テストコードを改変すると失敗時の出力が見られます（試す必要は特にないです）。

```bash ホスト上
vim riscv-tests/isa/rv64ui/add.S

git diff
-> diff --git a/isa/rv64ui/add.S b/isa/rv64ui/add.S
-> index 0696428..d61ae35 100644
-> --- a/isa/rv64ui/add.S
-> +++ b/isa/rv64ui/add.S
-> @@ -17,7 +17,7 @@ RVTEST_CODE_BEGIN
->    # Arithmetic tests
->    #-------------------------------------------------------------
-> 
-> -  TEST_RR_OP( 2,  add, 0x00000000, 0x00000000, 0x00000000 );
-> +  TEST_RR_OP( 2,  add, 0x00000001, 0x00000000, 0x00000000 );
->    TEST_RR_OP( 3,  add, 0x00000002, 0x00000001, 0x00000001 );
->    TEST_RR_OP( 4,  add, 0x0000000a, 0x00000003, 0x00000007 );
```

```bash コンテナ内
cd /riscv-tests
make && make install
spike target/share/riscv-tests/isa/rv64ui-p-add
-> *** FAILED *** (tohost = 2)
```

## `benchmarks/vvadd` （ベクトルの加算; シングルスレッド）の挙動を追う

## `benchmarks/mt-vvadd` （ベクトルの加算; マルチスレッド）の挙動を追う

## 機能調査

### RV64F (単精度浮動小数点演算), RV64D (倍精度浮動小数点演算) を利用しているベンチマークはあるか。あるとしたらどれか。

### RV64V (ベクトル演算) を利用しているベンチマークはあるか。あるとしたらどれか。

### RV64A (アトミック命令) を利用しているベンチマークはあるか。あるとしたらどれか。

### ヒープ領域は必要か（スタック領域のみで十分か）。

### スレッドをCPUコアに割り当てるスケジューラは必要か。

### まとめ表
