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

- **dhrystone**: Dhrystone。整数演算を中心とした合成ベンチマーク。
- **median**: 1次元配列に対するメディアンフィルタ。画像のノイズ除去などに使われるアルゴリズムで、「ある要素とその両隣の3要素の中央値を、ある要素に上書きする」という挙動をするもの。
- **mm**: シングルスレッドの行列積。
    - [結果出力は物理スレッドのIDを伴う](https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/mm/mm_main.c#L45-L50)が、[データ同じ行列積を各物理スレッドで行っている](https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/mm/mm_main.c#L38)だけなので注意。
    - カーネル部分は性能が出るようにチューニングされている。
- **mt-matmul**: マルチスレッドの行列積。
    - 並列計算をしている。上流で \\(A \times B = C\\) の \\(A\\) を物理スレッドの数だけ分割している。
        - ただし、 **各ベンチマークは `benchmarks/common/crt.S` をいじってビルドしないとシングルスレッド動作してしまうので要注意。** ベンチマークが標準でマルチスレッド予定があるかは ["Benchmark runs in single-thread" のIssue](https://github.com/riscv/riscv-tests/issues/240) で確認中。
    - シングルスレッドのカーネル部分は単純な3重ループで性能は出なさそう。
        - 行列積、シングルスレッド版とマルチスレッド版があるのは良いのだが、カーネル部分があまりにも異なるのはちょっと...
- **mt-vvadd**: ベクトルの加算。 `コアID mod コア数` 番目の要素の足し算を各コアが担当する、単純な並列化が成されている。
- **multiply**: ハードウェアの32ビット乗算器をエミュレートしたようなプログラム。
- **pmp**: PMP (Physical Memory Protection; 物理メモリ保護) のテスト。[ベンチマークではなくテスト](https://github.com/riscv/riscv-tests/issues/232)。
- **qsort**: クイックソート。
- **rsort**: 基数ソート。
    - [コメントにはクイックソートと書かれている](https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/rsort/rsort.c#L7)が.際のコードはどう見ても基数ソート。[Issueでも指摘されている。](https://github.com/riscv/riscv-tests/issues/45)
- **spmv**: 倍精度浮動小数の疎行列・ベクトル積。
- **towers**: ハノイの塔。
- **vvadd**: ベクトルの加算。シングルスレッド。

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

パフォーマンスカウンタの値（`mcycle`: サイクル数, `minstret`: 実行された命令数）がコンソール出力されています。

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
  #
#define STKSHIFT 17
  add sp, a0, 1
  sll sp, sp, STKSHIFT
  add sp, sp, tp
  sll a2, a0, STKSHIFT
  add tp, tp, a2

  # _init 関数へジャンプ。
  #   a0 = mhartid (CPUコアのID) ; ただし mhartid != 0 はこのコードパスに到達しない。
  #   a1 = 1 (コア数)
  # の2引数を _init に渡す。
  j _init

# この後は、例外発生時のジャンプ先の例外ハンドラが続く（省略）
  .align 2
trap_entry:
...
```

マルチコアにおけるスタック領域が、コア番号が大きいほど大きくなるバグがありましたが、[PR](https://github.com/riscv/riscv-tests/pull/242)をマージしてもらって直りました😉

`crt.S` では最後に `_init` にジャンプしました。この `_init` は https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/common/syscalls.c#L106-L123 で定義されています。

```c benchmarks/common/syscalls.c
void _init(int cid, int nc)  // cid = CPUコアID, nc = 1
{
  init_tls();
  thread_entry(cid, nc);

  // only single-threaded programs should ever get here.
  int ret = main(0, 0);

  char buf[NUM_COUNTERS * 32] __attribute__((aligned(64)));
  char* pbuf = buf;
  for (int i = 0; i < NUM_COUNTERS; i++)
    if (counters[i])
      pbuf += sprintf(pbuf, "%s = %d\n", counter_names[i], counters[i]);
  if (pbuf != buf)
    printstr(buf);

  exit(ret);
}
```

まずは `init_tls()` の定義を見てみます。名前からしてTLS (スレッドローカル変数) を初期化していそうですね。https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/common/syscalls.c#L96-L104 に定義があります。

```c benchmarks/common/syscalls.c
static void init_tls()
{
  // 各CPUコアの tp (thread pointer) の値を thread_pointer 変数に格納。
  register void* thread_pointer asm("tp");
  
  // リンカスクリプトの
  // https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/common/test.ld#L49-L60
  // で確保しているTLSの境界値をここで使えるように宣言。
  extern char _tdata_begin, _tdata_end, _tbss_end;

  // _tdata_begin から始まる tdata_size 分の領域を、自分のCPUコアの tp の箇所にコピーする（TLSは上（高位）に向かって伸びる）。
  // つまり、各CPUコアは予め同じ _tdata_begin のデータをTLSに持った状態でプログラムが開始する。
  size_t tdata_size = &_tdata_end - &_tdata_begin;
  // memcpy の実装は、シンプルにポインタを1バイトずつ操作するものが定義されている。
  // https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/common/syscalls.c#L379-L393
  memcpy(thread_pointer, &_tdata_begin, tdata_size);

  // BSSセクションはゼロ初期化するものなので、 _tdata を配置したその上に、 tbss_size 分だけゼロクリアする。
  size_t tbss_size = &_tbss_end - &_tdata_end;
  // memset はこちら https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/common/syscalls.c#L395-L412
  memset(thread_pointer + tdata_size, 0, tbss_size);
}
```

各コアのTLSに、 `.tdata` (初期値を持つ読み書き可能なデータ) と `.tbss` (ゼロ初期化された読み書き可能なデータ) を配置しているのがわかりました。

`_init()` の処理は次に `thread_entry()` を呼び出します。シングルスレッド動作する `vvadd` においては、 https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/common/syscalls.c#L82-L87 のデフォルト定義が使われます。

```c benchmarks/common/syscalls.c
// GNU拡張を使って weak シンボルとして thread_entry のデフォルト定義が与えられている。
// 静的・動的リンク時に別の thread_entry シンボルが見つかったらそちらが優先的に使われる。
void __attribute__((weak)) thread_entry(int cid, int nc)
{
  // multi-threaded programs override this function.
  // for the case of single-threaded programs, only let core 0 proceed.
  // コアID0 以外はここでずっと足止めを食らう。
  / crt.S でもコアID0 以外が無限ループを食らう箇所があったが、あの制約が撤廃されても、
  // thread_entry 関数を自前で書かないベンチマークアプリケーションはシングルスレッド処理になる。
  while (cid != 0);
}
```

シングルスレッドな `vvadd` においては、コア0だけが `_init` の処理を進め、 `int ret = main(0, 0);` を呼び出します。 `main()` の中身は後で見ましょう。 `_init()` の残りをインラインコメントで解説します。

```c benchmarks/common/syscalls.c
void _init(int cid, int nc)  // cid = CPUコアID, nc = 1
{
  init_tls();
  thread_entry(cid, nc);

  // only single-threaded programs should ever get here.
  int ret = main(0, 0);

  // パフォーマンスカウンタの内容をコンソール出力する、シングルスレッドベンチマークの共通後処理。
  // buf はコンソール出力する文字列を格納する領域。サイズはパフォーマンスカウンタの個数 * 32。
  // 1個のカウンタあたり最長32バイトの文字出力ができるようにしている。
  // NUM_COUNTERS は
  // https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/common/syscalls.c#L36-L38
  // で2個に固定されている。Spikeでの実行例で見たように、 mcycle, minstret の2つに設定されている。
  // 設定箇所をするための関数は
  // https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/common/syscalls.c#L39-L54
  // であり、各アプリケーションから計測対象コードの前後で setStats(1); setStats(0) されている。
  char buf[NUM_COUNTERS * 32] __attribute__((aligned(64)));
  char* pbuf = buf;
  for (int i = 0; i < NUM_COUNTERS; i++)
    if (counters[i])
      pbuf += sprintf(pbuf, "%s = %d\n", counter_names[i], counters[i]);
  if (pbuf != buf)
    printstr(buf);
  // sprintf や printstr はSpikeの用意しているシステムコール呼び出しを使って実現している。

  // exit() の処理は、コードを追っていくと最終的に
  // https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/common/syscalls.c#L56-L60
  // の tohost_exit() に行き着く。
  exit(ret);
}
```

パフォーマンスカウンタ `mcycle`, `minstret` の値をコンソールに文字出力して、 `exit(main関数の返り値)` を呼び出して終了しています。
`exit()` が最終的に行き着く `tohost_exit()` は興味深いので実装を見てみます。

```c benchmarks/common/syscalls.c
void __attribute__((noreturn)) tohost_exit(uintptr_t code)
{
  tohost = (code << 1) | 1;  // tohost という変数に main 関数の返り値を左シフトして最下位ビットを1にした値を書き込み
  while (1);                 // 無限ループ
}
```

これでどうしてベンチマークプログラムの実行が終わるのでしょうか？
これはSpikeの定めている **HTIF (Host-Target Interface** によるものです。特定の番地の64ビット符号なし整数に0以外の値が書き込まれていたら、Host側のSpikeはTarget側のベンチマークプログラムに何らかの介入をします。ターゲット側からみたら、 `tohost` がSpikeに対する連絡手段となるのです。
Target側が無限ループしているのにHost側に制御が移る理由があまりわかっていないのですが、おそらくSpikeはタイマ割り込みはいつでも発生するように作っているのだと思います。タイ回り込みの処理において `tohost` 領域の値をチェックして、非ゼロの場合にTargetプログラムを終了させる挙動かと推察します。
このあたりは確信できるドキュメントなど見つからなかったので、詳しい方は教えていただけると嬉しいです。

`tohost` の番地は `.tohost` セクションの番地から取得できるように https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/common/test.ld#L29 において設定されています。

ここまでで `main()` 周辺の仕組みが完全にわかったので、 `main()` を読んでみます。

```c benchmarks/vvadd/vvadd_main.c
void vvadd( int n, int a[], int b[], int c[] )
{
  int i;
  for ( i = 0; i < n; i++ )
    c[i] = a[i] + b[i];
}

int main( int argc, char* argv[] )
{
  int results_data[DATA_SIZE];

#if PREALLOCATE
  // If needed we preallocate everything in the caches
  vvadd( DATA_SIZE, input1_data, input2_data, results_data );
#endif

  // Do the vvadd
  setStats(1);  // パフォーマンスカウンタ mcycle, minstret の値を記録
  vvadd( DATA_SIZE, input1_data, input2_data, results_data );
  setStats(0);  // パフォーマンスカウンタ mcycle, minstret の増分を記録。main() 終了後に増分がコンソール出力される。

  // Check the results
  return verify( DATA_SIZE, results_data, verify_data );
}
```

特筆すべきことはないですね。 `PREALLOCATE` をコンパイル時にセットしておくと、パフォーマンスカウンタ計測の前に予め入力ベクトルを舐めてキャッシュに乗せるようです。


## `benchmarks/mt-vvadd` （ベクトルの加算; マルチスレッド）の挙動を追う

シングルスレッド版 `vvadd` との違いはわずかです。 `mt-vvadd` は `thread_entry` 関数を自前で定義しているので、すべてのコアがこの関数をエントリポイントとして実行することができます（実際には `crt.S` でコア0以外は無限ループに嵌められていますが...）。

`mt-vvadd` の `thread_entry` は https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/mt-vvadd/mt-vvadd.c#L47-L78 に定義があります。息切れしてきたので解説は省略します🙄
計算のコアの `vvadd()` は https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/mt-vvadd/vvadd.c#L9-L18 に定義があります。`コアID mod コア数` 番目の要素の足し算を各コアが担当していることがわかります。

## 機能調査

ベンチマークプログラムのコードがカーネル部分も周辺部分も読めるようになったので、自作CPU, OSで備えるべき機能を検討するために以下の観点を調べます。

### RV64F (単精度浮動小数点演算), RV64D (倍精度浮動小数点演算) を利用しているベンチマークはあるか。あるとしたらどれか。

`float` 型または `double` 型を使っているかが肝になります。たとえ使っていたとしても、RV64Iの範囲で整数レジスタを使ってソフトウェア的に浮動小数点演算をするコードをコンパイラに吐いてもらうこともできますが、やはりハードウェア側でRV64F, RV64DのISAに対応しておいてFPUをハードウェアで作っておいたほうが圧倒的に速度が出るので、 `float` や `double` 型を使っているベンチマークがあれば自作CPUはRV64F, RV64D対応したくなります。

**mm**, **spmv** は `double` 型を使っていて、それ以外はなさそうです。

### RV64V (ベクトル演算) を利用しているベンチマークはあるか。あるとしたらどれか。

RV64Vはまだドラフト段階であり、調べている限り、RISC-Vでのベクトル演算アセンブリを吐くためのコンパイライントリンシックは今の所なさそうです。
となると直接アセンブリでベクトル命令を書いているベンチマークがあるかどうかが調査ポイントですが、 riscv-tests/benchmarks の中ではアセンブリを書いてなさそうです。
ただし、 [**mm** は標準ライブラリの `fmaf` を読んでいる形跡](https://github.com/riscv/riscv-tests/blob/3a98ec2e306938cce07ab15e3678d670611aa66d/benchmarks/mm/common.h#L12)があります。

標準ライブラリが絡んでくるとコンパイル済みのアセンブリを見たほうが調査精度が高そうです。幸い riscv-tests/benchmarks は `mm.riscv` などの実行可能ファイルだけではなく `mm.riscv.dump` のようなアセンブリファイルも出力してくれるので、 `*.dump`ファイルを対象にベクトル命令をgrepしてみます。

```bash コンテナ内
cd /riscv-tests/target/share/riscv-tests/benchmarks
grep vl *.dump
grep vs *.dump
```

どうやらどれもベクトル命令は吐いてなさそうです。

### RV64A (アトミック命令) を利用しているベンチマークはあるか。あるとしたらどれか。

```bash コンテナ内
% grep '\slr\s' *.dump
% grep '\ssc\s' *.dump
% grep '\samo' *.dump
-> mm.riscv.dump:    800035c6:     04c6a72f                amoadd.w.aq     a4,a2,(a3)
-> mt-matmul.riscv.dump:    8000121c:      04c6a72f                amoadd.w.aq     a4,a2,(a3)
-> mt-vvadd.riscv.dump:    80001066:       04c6a72f                amoadd.w.aq     a4,a2,(a3)
-> qsort.riscv.dump:    800022f2:  03af21af                amoadd.w.rl     gp,s10,(t5)
-> rsort.riscv.dump:    8000242a:  03af21af                amoadd.w.rl     gp,s10,(t5)
```

アトミック命令が **mm**, **mt-matmul**, **mt-vvadd**, **qsort**, **rsort** で使われていますね。

### ヒープ領域は必要か（スタック領域のみで十分か）。

ヒープの有無はリンカスクリプトからはわかりません。
ヒープがあるとしたら、 `.data` や `.bss` セクションの直後（高位）の領域をベースアドレス配置されるのが通常です。
（スタックはヒープから思い切り離れたところにそのトップアドレスを配置し、ヒープは高位へ、スタックは低位へ伸びていくのが慣例ですね）

ヒープはOSがシステムコールの形で動的な確保と開放をサポートします。Linuxにおけるヒープ操作のためのシステムコールは `brk(2)` ですね。
riscv-tests は動作に特定のOSを必要としていない組み込みプログラムなので、ヒープ操作のシステムコール必要としておらず、呼び出していません。
したがってヒープ領域は不要です。

（一部のベンチマークプログラムは `alloca` を呼び出していますが、これはスタック領域を動的に伸ばすための関数です）`

### スレッドをCPUコアに割り当てるスケジューラは必要か。

コードを追いながら見たように、

- `crt.S` においてコアID0 以外は無限ループでストップするようになっている。
- 仮に `crt.S` の上記制約がなくなったとしても、マルチスレッドのベンチマークの **mt-matmul** と **mt-vvadd** は、どのコアも同じ命令の実行を行っている（各コアが扱う入力データが分割されている、いわゆるデータ並列）。
    - 自分のコアの計算が早く終わった場合にも `barrier()` するだけで、ロードバランシングのためにスケジューラに制御を移したりはしない。

という状況なので、スケジューラは不要です。

### まとめ表

|                  | dhrystone | median | mm | mt-matmul | mt-vvadd | multiply | pmp | qsort | rsort | spmv | towers | vvadd |
|------------------|-----------|--------|----|-----------|----------|----------|-----|-------|-------|------|--------|-------|
| RV64F要否        | x         | x      | x  | x         | x        | x        | x   | x     | x     | x    | x      | x     |
| RV64D要否        | x         | x      | o  | x         | x        | x        | x   | x     | x     | o    | x      | x     |
| RV64A要否        | x         | x      | o  | o         | o        | x        | x   | o     | o     | x    | x      | x     |
| RV64V要否        | x         | x      | x  | x         | x        | x        | x   | x     | x     | x    | x      | x     |
| ヒープ要否       | x         | x      | x  | x         | x        | x        | x   | x     | x     | x    | x      | x     |
| スケジューラ要否 | x         | x      | x  | x         | x        | x        | x   | x     | x     | x    | x      | x     |

