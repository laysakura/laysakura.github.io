---
title: Rustの2種類の 'static
id: rust-static-lifetime-and-static-bounds
tags:
  - Rust
date: 2020-05-21 17:19:56
---

<img src="/img/2020-05-21-19-04-46.png" alt="2種類の 'static" width="auto" height="auto">

Rustの `'static` 、難しいですよね。

「プログラム中ずっと生き残るライフタイムでしょ？簡単簡単」

なるほど。では次の2つの `'static` の違いがわかるでしょうか？

```rust 1つめ
let x: &'static str = "Hello, world.";
```

```rust 2つめ
/// Returns some reference to the boxed value if it is of type `T`, or
/// `None` if it isn't.
pub fn downcast_ref<T: Error + 'static>(&self) -> Option<&T> { ... }
```

「・・・2つめのなんだっけ？」
という人はぜひ読んでみてください🦀

この記事では、Rustの2種類の `'static` 、

- `'static` ライフタイム
- `'static` ライフタイム **境界**

を解説します。

<!-- more -->

## 目次
<!-- toc -->

## `'static` ライフタイム

あまり難しくないです。
`'static` ライフタイムは、 **プログラムが走っている間ずっと有効な値への参照に対してつけられる、最大のライフタイム** です。
"プログラムが走っている間ずっと有効な値" の例としては、

- リテラル (`1`, `"abc"`)
- 定数 ( `const N: i32 = 5;` )
- グローバル変数 ( `static N: i32 = 5;` )

などがあります。

冒頭にも出した例は、文字列リテラルへの `'static` ライフタイムを持つ参照です。

```rust 'static ライフタイム
let x: &'static str = "Hello, world.";
```

"プログラムが走っている間ずっと有効な値" への参照だからといって、 `'static` ライフタイムを使う必要はありません。より短いライフタイムをつけることもできます（ `'static` よりも長いライフタイムはありません）。

```rust リテラルの参照のライフタイムに、関数の引数のライフタイムと同じものを使う例
fn f<'a>(v: &'a u32) {
    let x: &'a str = "Hello, world.";
}
```

## `'static` ライフタイム **境界**

こちらは比較的難しいです。

ジェネリクスにトレイト境界がつくことありますよね。 `T: Ord + Debug` だと、「 `T` という型は何でもいいんだけど、 `Ord` トレイトと `Debug` トレイトだけは実装された型じゃないと受け付けない」という制約を表します。

トレイト境界と同様に、型に対してライフタイム境界を指定することもできます。 `T: 'a` や `T: 'static` といった指定ですね。後者は `T` に対して `'static` ライフタイム境界がついています。

まずは厳密な話よりも実用上重要なポイントを述べます。 **型 `T` に `'static` ライフタイム境界がついているならば、 `T` が struct や enum であった場合、そのフィールドには参照を含まないことを要請する。** という使い方が大半です。
もう少し厳密にいうと、 `T: 'static` ならば、型 `T` のフィールドに参照を含んでいても良いが、含むならばその参照は `&'static` である (`'static` ライフタイムを持つ)、です。
自分はstructやenumに `'static` ライフタイムな参照を含めたくなったケースがない（その場合は値そのものをフィールドにする）ので、太字の考え方をしています。

ここまで知ってしまえば意外と簡単に思えてきますね。

ではここで理解度クイズです。(1)~(4)でコンパイルエラーを引き起こす呼び出しを全て挙げてください。

```rust 
// 'static ライフタイム境界を満たす型Tなら何でも受け付ける
fn i_need_static_bound_type<T: 'static>(v: T) {}

// 参照を含まない
struct IHaveValue(String);

// 'static ライフタイムの参照だけ含む
struct IHaveStaticRef(&'static str);

// 'a というライフタイムの参照だけ含む
struct IHaveNonStaticRef<'a>(&'a str);

fn main() {
    i_need_static_bound_type(IHaveValue("abc".to_string())); // (1)
    i_need_static_bound_type(IHaveStaticRef("abc")); // (2)
    i_need_static_bound_type(IHaveNonStaticRef("abc")); // (3)

    {
        let local_string: String = format!("abc");
        i_need_static_bound_type(IHaveNonStaticRef(&local_string)); // (4)
    }
}
```

わかりましたか？正解は...

🦀
ミ🦀
🦀彡
ミ🦀
🦀彡
ミ🦀
🦀彡
ミ🦀
🦀彡
ミ🦀
🦀彡
ミミ🦀
🦀彡彡

***(4) だけです！***

(1)(2)が `i_need_static_bound_type` への `T` として受け入れられるのはわかりますね。前者は値だけを持ったstructを渡していて、後者は `'static` ライフタイムな参照だけを持ったstructを渡しています。
(3) がコンパイルエラーにならないのは少々意外かもしれません。関数呼び出し時に渡す引数の参照のライフタイムを指定していない場合は、可能な限り最大のライフタイムが割り当てられます。この場合は `"abc"` というリテラルを指定しているので、プログラムが走っている間はずっと値が生きています。なので最大の `'static` ライフタイムが割り当てられます。
(4) は `local_string` という、内側の `{}` に囲まれたスコープで死んでしまう値の参照を渡しています。この参照のライフタイムは `'static` ライフタイムより短いので、 `T: 'static` で `'static` ライフタイム境界を要請している `i_need_static_bound_type` には渡せなかったわけですね。

### おまけ: `'static` じゃないライフタイム境界

ライフタイム境界には、 `T: 'a` のように、 `'static` ではないライフタイムも指定できます。この場合も `'static` ライフタイムと同様、
**`T` （自体やそのフィールド）には参照が含まれていない。または参照が含まれていたら、その参照のライフタイムは全て `'a` 以上。** という制約を表します。

まず `'static` ライフタイムをしっかり身につけてからだと、すんなり理解できると思います。ここまで理解できたら、是非 [高度なライフタイム](https://doc.rust-jp.rs/book/second-edition/ch19-02-advanced-lifetimes.html) も読んでみてください。

## 記事を書いた背景

[rust-jp Slackチーム](https://rust-jp.rs/) に、 [`'static` に関する一連の投稿](https://rust-jp.slack.com/archives/C0562JBPY/p1580988202180800) がありました。

<img src="/img/2020-05-21-17-45-05.png" alt="slack1" width="auto" height="auto">
<img src="/img/2020-05-21-17-45-47.png" alt="slack2" width="auto" height="auto">

※内容が主題なので投稿者はぼかしてます。

正直当初はまるでわからなかったのですが、紆余曲折を経てわかるようになったので記事にしました。

わからないことがわかるようになるのは嬉しいですね。
