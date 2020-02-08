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
- `median`: 1次元配列に対するメディアンフィルタ。画像のノイズ除去などに使われるアルゴリズムで、「ある要素とその両隣の3要素の中央値を、ある要素に上書きする」という挙動をす[<8;90;16mるもの。
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

各ベンチマークの挙動を性格に把握できるようにするために、動作の最初から最後まで愚直にコードを読んでみます。
`vvadd` と `mt-vvadd` はそれぞれシングルスレッドとマルチスレッドで、行っている計算もシンプルなので、ちょうどよい題材として本記事で取り上げます。まずは `vvadd` を読みます。

Spikeにより、 `0x80000000` 番地に配置された `.text.init` セクションのコードが実行されます。そのコードは https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/common/crt.S#L15-L136 のもの。以下、インラインコメントの形で挙動を解説します。

```c benchmarks/common/crt.S
  # .text.init セクションは、
  # https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/common/test.ld#L25-L26
  # にて 0x80000000 番地に置かれている。
  .section ".text.init"
  .globl _start
_start:
  # 各種レジスタをゼロクリア
  li  x1, 0
  li  x2, 0
  li  x3, 0
  li  x4, 0
  li  x5, 0
  li  x6, 0
  li  x7, 0
  li  x8, 0
  li  x9, 0
  li  x10,0
  li  x11,0
  li  x12,0
  li  x13,0
  li  x14,0
  li  x15,0
  li  x16,0
  li  x17,0
  li  x18,0
  li  x19,0
  li  x20,0
  li  x21,0
  li  x22,0
  li  x23,0
  li  x24,0
  li  x25,0
  li  x26,0
  li  x27,0
  li  x28,0
  li  x29,0
  li  x30,0
  li  x31,0

  # enable FPU and accelerator if present
  li t0, MSTATUS_FS | MSTATUS_XS
  csrs mstatus, t0

  # make sure XLEN agrees with compilation choice
  li t0, 1
  slli t0, t0, 31
#if __riscv_xlen == 64
  # RV64ターゲットでコンパイルした場合はこちらに入る。
  # もしも t0 が32ビットレジスタ（つまりプロセッサはRV32）なのに、現在実行しているコンパイル済みの実行可能ファイルが
  # __riscv_xlen == 64 としてコンパイルされており、このコードパスに入っているとする。
  # その場合は、 t0 = 1 << 31 == 10000000 00000000 00000000 00000000 であり、これは符号付き32ビット整数と解釈すると -2147483648 である。
  # したがって t0 < 0 なので、直下の bgez は不成立となり、 2: が実行される。
  bgez t0, 1f  # 1f は "forward方向の 1: ラベル" を指す。
#else
  bltz t0, 1f
#endif
2:
  # ここに入ると無限ループ。
  # sw で何をしているのかは理解できていない...
  li a0, 1
  sw a0, tohost, t0
  j 2b  # 2b は "backward方向の 2: ラベル" を指す。
1:

#ifdef __riscv_flen
  # initialize FPU if we have one
  # 例外が発生した場合のジャンプ先を、この数行後の 1: ラベルの番地とする。
  # 1: ラベル直後においても再び例外発生の際のジャンプ先を設定しているが、これは、プロセッサが実際には浮動小数点演算をサポートしていない場合には、
  # 1: ラベルに至る前の fssr や fmv.s.x 命令が例外を発生させてしまう可能性があるからだと思われる。
  #
  # mtvec の値の仕様は https://content.riscv.org/wp-content/uploads/2017/05/riscv-privileged-v1.10.pdf を参照。
  la t0, 1f
  csrw mtvec, t0 

  # 浮動小数点のコントロールレジスタ fcsr を0にセット。
  # fssr 命令は古く、 fscsr 命令に成り代わった模様: https://github.com/riscv/riscv-isa-manual/issues/419#issuecomment-516338426
  fssr    x0
  # 浮動小数点数演算のための汎用レジスタをゼロクリア。
  fmv.s.x f0, x0
  fmv.s.x f1, x0
  fmv.s.x f2, x0
  fmv.s.x f3, x0
  fmv.s.x f4, x0
  fmv.s.x f5, x0
  fmv.s.x f6, x0
  fmv.s.x f7, x0
  fmv.s.x f8, x0
  fmv.s.x f9, x0
  fmv.s.x f10,x0
  fmv.s.x f11,x0
  fmv.s.x f12,x0
  fmv.s.x f13,x0
  fmv.s.x f14,x0
  fmv.s.x f15,x0
  fmv.s.x f16,x0
  fmv.s.x f17,x0
  fmv.s.x f18,x0
  fmv.s.x f19,x0
  fmv.s.x f20,x0
  fmv.s.x f21,x0
  fmv.s.x f22,x0
  fmv.s.x f23,x0
  fmv.s.x f24,x0
  fmv.s.x f25,x0
  fmv.s.x f26,x0
  fmv.s.x f27,x0
  fmv.s.x f28,x0
  fmv.s.x f29,x0
  fmv.s.x f30,x0
  fmv.s.x f31,x0
1:
#endif

  # initialize trap vector
  la t0, trap_entry
  csrw mtvec, t0

  # initialize global pointer
  # グローバル変数のアドレスは gp をベースにして計算する。
  # .option push / .option pop は、それらに挟まれたオプション設定を一時的に有効にするためのGNU Assemblerのオプション。
  # .option norelax はリンカによるrelaxを明示的に拒否するためのオプション。
  # https://www.st.com/content/ccc/resource/technical/document/user_manual/group1/fb/cb/d6/71/03/25/42/a1/UserManual_GNU_Assembler/files/UserManual_GNU_Assembler.pdf/jcr:content/translations/en.UserManual_GNU_Assembler.pdf
  # の p.257-258 に詳しい。
.option push
.option norelax
  la gp, __global_pointer$
.option pop

  # tp: thread pointer
  # スレッドローカル変数のアドレスは tp をベースにして計算する。
  # _end は https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/common/test.ld#L63 の番地。
  # ただし、 riscv-tests/benchmarks においては、
  # https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/common/test.ld#L53
  # で引っ張ってきている .tdata セクションは指定されていない。つまりスレッドローカル変数は使われていない。
  la  tp, _end + 63
  and tp, tp, -64

  # get core id
  csrr a0, mhartid
  # for now, assume only 1 core
  li a1, 1
# mhartid (物理スレッドID, CPUコアID) が1以上ならば、この bgeu を無限ループ（スピンウェイト）する。
# つまりコア番号0のCPUコアでしか以降の命令（ベンチマーク）は実行されないようになっている。
# ベンチマークプログラムとしてはマルチスレッド対応がほしいところなので、これが緩和されるようIssueが立っている（立てた）。
# https://github.com/riscv/riscv-tests/issues/240
1:bgeu a0, a1, 1b

  # give each core 128KB of stack + TLS
  #
  # ここでは、 mhartid が 0, 1, 2, 3 な4コアの環境で、スタック領域とスレッドローカル変数の割当を図示する。
  # （上述の通り mhartid == 0 しかこのコードは通らないが、もしその制約が撤廃されたらの話）
  #
  # ----------- sp (core#3)
  #  ^
  #  | 2^17
  #  |
  #  v
  # ----------- sp (core#2) = tp (core#3)
  #  ^
  #  | 2^17
  #  |
  #  v
  # ----------- sp (core#1) = tp (core#2)
  #  ^
  #  | 2^17
  #  |
  #  v
  # ----------- sp (core#0) = tp (core#1)
  #  ^
  #  | 2^17
  #  |
  #  v
  # ----------- tp (core#0) = (_end + 63) & -64
  #
  # 各コア、スタックポインタは下方向に（低位に向かって）伸ばし、スレッドポインタは上方向に（高位に向かって）伸ばす。
  # おそらくこうセッティングしたいと思うのだが、下記のコードではコアIDが大きいほどスタックサイズが大きいように見える...
  # この点はIssueで確認中: https://github.com/riscv/riscv-tests/issues/241
  #
#define STKSHIFT 17
  sll a2, a0, STKSHIFT
  add tp, tp, a2
  add sp, a0, 1
  sll sp, sp, STKSHIFT
  add sp, sp, tp

  # _init 関数へジャンプ
  j _init
```

## `benchmarks/mt-vvadd` （ベクトルの加算; マルチスレッド）の挙動を追う

## 機能調査

### RV64F (単精度浮動小数点演算), RV64D (倍精度浮動小数点演算) を利用しているベンチマークはあるか。あるとしたらどれか。

### RV64V (ベクトル演算) を利用しているベンチマークはあるか。あるとしたらどれか。

### RV64A (アトミック命令) を利用しているベンチマークはあるか。あるとしたらどれか。

### ヒープ領域は必要か（スタック領域のみで十分か）。

### スレッドをCPUコアに割り当てるスケジューラは必要か。

### まとめ表
