---
title: Rustの std::sync::RwLock はLinuxでwriter starvation問題を起こす (macOSなら平気)
id: rust-RwLock-writer-starvation
tags:
  - Rust
date: 2022-03-30 15:26:26
---

<img src="/img/2022/03-30-starvation.png" alt="お腹が減ったワンちゃん" width="400px" height="auto">

まとめ:

- `std::sync::RwLock::{write(), try_read()}` を併用した場合には「書き込みロックを最優先」という挙動は必ずしも期待できない (LinuxではNG)
- Pthread の規約が挙動に自由度をもたせており、Linuxにおけるデフォルト実装では **writer starvation** が発生する
- Rustにおいて writer starvation を回避しつつ readers-writer lock を使うには [`parking_lot::RwLock`](https://docs.rs/parking_lot/latest/parking_lot/type.RwLock.html) を使うと良い

<!-- more -->

## 目次
<!-- toc -->

## 背景: Readers-writer lock とは？

あるリソースがあり、並列に動作する複数のスレッドからそのカウンタ変数を読み書きしたいとします。

カウンタ変数 `c = 1` をリソースの例とします。
スレッド1がカウンタ変数をインクリメントして `c = 2` にし、スレッド2がもう一度インクリメントして `c = 3` になることが期待結果だとします。
しかしスレッド1とスレッド2が同時にインクリメントを走らせ、どちらも `c = 1` の時点でカウンタ変数を読んでしまった場合、結果は `c = 2` になってしまいます。

リソースを複数スレッドで更新する場合、よく使われるのは排他ロック (mutex) ですね。
上記の例でも、各スレッドが `c` を読む前に排他ロックを獲得し、更新が完了したら排他ロックを解放すれば、必ず `c = 3` の結果が得られます。

しかし、多くのスレッドがリソースに対して読み取りアクセスのみをし、少ないスレッドが書き込みアクセスをするようなケースでは、排他ロックよりも効率の良いロックがあります。それが **readers-writer lock** です。
ロックの獲得を待っている間は、プログラムで本当に行いたい処理ができないので、できる限りロック待ちの時間は短くしたいです。ただ待ってるだけなら自分のプログラムにしか迷惑を書けませんが、spin waitでロックが空くのを待ってしまうと、OS上の他のプログラムに割当てられるはずだったCPU時間まで奪ってしまいます。
Readers-writer lock では、読み取りロック (reader lock) を取るスレッドしかいない場合にはロック待ちが発生しません。書き込みロック (writer lock) を獲得しているスレッドが1つでも存在した場合、その間は他のスレッドは読み取りロックも書き込みロックも獲得できません。
この性質から、読み取りロックは shared lock, 書き込みロックは exclusive lock とも呼ばれます。

## 背景: Rustにおける readers-writer lock

[std::sync::RwLock](https://doc.rust-lang.org/std/sync/struct.RwLock.html) が通常使われます。
上記ページ Examples からの引用ですが、こんなセマンティクスで読み取りロックと書き込みロックを取得します。

```rust
use std::sync::RwLock;

let lock = RwLock::new(5);

// many reader locks can be held at once
{
    let r1 = lock.read().unwrap();
    let r2 = lock.read().unwrap();
    assert_eq!(*r1, 5);
    assert_eq!(*r2, 5);
} // read locks are dropped at this point

// only one write lock may be held, however
{
    let mut w = lock.write().unwrap();
    *w += 1;
    assert_eq!(*w, 6);
} // write lock is dropped here
```

## 背景: RwLock::write() と RwLock::try_read()

「リソースを更新する頻度は少ないが、更新したいときは（読み取りを止めて）最優先で更新したい」というケースはよくあるものです。

その場合は、リソースを更新する側のロックには [std::sync::RwLock::write()](https://doc.rust-lang.org/std/sync/struct.RwLock.html#method.write) を、読み取る側のロックには [std::sync::RwLock::try_read()](https://doc.rust-lang.org/std/sync/struct.RwLock.html#method.try_read) を使うと良いと考えられます (筆者は考えました)。
`RwLock::write()` はブロッキングコールであり、書き込みロックが獲得できるまでロック待ちをします。 `RwLock::try_read()` はノンブロッキングコールです。書き込みロックが獲得されていなければロック取得できるのはもちろん、書き込みロックが取得されている場合は、ロック待ちなしでエラー (`Err`) が返却されます。

しかし `std::sync::RwLock::write()` と `std::sync::RwLock::try_lock()` の併用では、プラットフォームによっては **「更新が最優先にならない」** という事象を発見しました。

## 再現コード

短いのでまず再現コードを貼ります。下記のコードは、macOSだと期待通りに終了し、Linuxだと終了せずに走り続けます。

```rust
use std::{process::exit, sync::Arc, thread};

use std::sync::RwLock;

fn reader_loop(lock: &RwLock<()>) {
    loop {
        let _guard = lock.try_read().unwrap();
    }
}

fn writer_exit(lock: &RwLock<()>) {
    let _guard = lock.write().unwrap();

    eprintln!("writer: exit");
    exit(0);
}

fn main() {
    let w_lock = Arc::new(RwLock::new(()));

    for _ in 0..30 {
        // more than the number of physical CPU cores
        let r_lock = w_lock.clone();
        let _r_handle = thread::spawn(move || reader_loop(&r_lock));
    }

    let w_handle = thread::spawn(move || {
        writer_exit(w_lock.as_ref());
    });

    w_handle.join().unwrap();
}
```

まず30個 (CPUコア数より多ければいくつでも良い) の読み取りスレッドを立ち上げます。読み取りスレッドは無限ループの中で `try_read()` を発行し続けます。
次に1個の書き込みスレッドを立ち上げます。書き込みスレッドは、 `write()` で書き込みロックの獲得に成功したらその直後にプロセスを `exit` します。

「更新が最優先」の挙動になるならば、 `exit` が呼ばれてプロセスが終了します。これが期待挙動です。
しかしLinuxでは `write()` がいつまで経っても成功せず、プロセスは終了しません。

## 原因分析

`std::sync::RwLock::write()` の実装を追うと、libcの [`pthread_rwlock_wrlock()` を呼び出している箇所](https://github.com/rust-lang/rust/blob/1446d17b8f4bd3ff8dbfb129a7674165e06f9f4c/library/std/src/sys/unix/locks/pthread_rwlock.rs#L75) にたどり着きます。
[`pthread_rwlock_wrlock()` のマニュアル](https://linux.die.net/man/3/pthread_rwlock_wrlock)を読むと、

> Implementations **may** favor writers over readers to avoid writer starvation.

とあります (強調は筆者による)。

つまり、「書き込み側を読み取り側よりも優先するかどうかは実装次第」ということです。
Writer starvationというのは、「書き込み側が、読み取り側に邪魔されて、いつまで立ってもロック獲得の機会を与えられない」状況のことです。

macOSの実装では writer starvation が発生しない、つまり書き込み側が読み取りに優先するのですが、Linuxはそうはなっていないというのが原因でした。
上記再現コードでは、CPUコアよりも多くのスレッドが無限ループで (CPU時間を明け渡すことなく) 読み取りロックを獲得しています。Linuxでは writer starvation が起こるケースです。

[`PTHREAD_RWLOCK_PREFER_WRITER_NONRECURSIVE_NP` 属性](https://linuxjm.osdn.jp/html/LDP_man-pages/man3/pthread_rwlockattr_setkind_np.3.html) をセットすれば writer starvation を避けられそうですが、Rustで素直に解決するための方法を以下に記載します。

## 修正: `parking_lot::RwLock` を使う

[parking_lot::RwLock](https://docs.rs/parking_lot/latest/parking_lot/type.RwLock.html) を見ると、

> This lock uses a task-fair locking policy **which avoids both reader and writer starvation**.

とあります (強調は筆者による)。
Writer starvation を避けられるように作られており、実際 `parking_lot::RwLock` を使用するように再現コードを書き換えれば、期待通りLinuxでもプロセスが終了するようになります。

## おわりに

業務で作っている IoTや車載機のためのストリーム処理系SpringQL のデバッグ中にこの問題を発見しました。

{% githubCard user:SpringQL repo:SpringQL %}

自分の開発PC (macOS) では快調に動くのに、CIの ubuntu-latest では毎回テストが刺さっていて、（動くと思ってるのは自分だけで本当は世界の誰も動かせないのでは...？）と疑心暗鬼になりながらのデバッグでした。
Linuxだけ書き込みロック獲得がどうも遅い (ちょうど4秒くらい待たされる) と気づいてからは実装依存の箇所を探そうと思い至り、そこからは楽しく[修正できました](https://github.com/SpringQL/SpringQL/pull/62)。

再現コード・修正コードは[こちらのリポジトリ](https://github.com/laysakura/rust-RwLock-writer-starvation)に置いています。お手元の環境でもお試しください。
