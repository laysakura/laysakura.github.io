---
title: Apache Beamが多言語・多バックエンド処理系を実現する仕組み
id: beam-multi-lang-backend
tags:
  - ストリーム処理
  - Apache Beam
date: 2022-08-31 11:18:09
---

<img src="/img/2022/08-31-03.drawio.svg" alt="Apache Beam Portable Framework概要図" width="600px" height="auto">

ストリーム処理とバッチ処理を統合して扱えるプログラミングモデル（あるいはデータ処理のフロントエンド）である [Apache Beam](https://beam.apache.org/) が、特にGoogle Cloud DataflowやApache Flinkからの利用を背景にシェアを伸ばしています。

Apache Beamの特色として、複数のプログラミング言語のSDKを持つこと・複数のバックエンド処理系（Flinkなどを指す）を持つことが挙げられますが、これがどう実現されているのかをまとめます。

<!-- more -->

## 目次
<!-- toc -->

## 前提知識: Beam入門

### Exampleコードからざっくり理解

Exampleを見る前に、Beamのプログラミングをするのはどういうことかをざっくりと説明する。

#### Beamのプログラミング体験

Beamでプログラミングをするということは、「BeamのSDKを介して下図のようなパイプラインを構成」すること。

<img src="/img/2022/08-31-design-your-pipeline-linear.png" alt="https://blog.gopheracademy.com/advent-2018/apache-beam/ より引用" width="auto" height="auto">


パイプラインの重要な構成要素は以下:

- **PCollection**: レコードが入るテーブルやキュー。データの型は単なる String であったり、リレーショナルであったり、ArrayやObjectをネストすることもできる。
- **Transform**: 基本的に、PCollection から PCollection への変換関数。InputをPCollectionに変換するものを特別に Read Transform , PCollectionをOutputへ変換するものを Write Transform と呼ぶ。
- **Input**: 任意のデータ。Read Transform が頑張ってBeam実行系が扱えるPCollectionに変換する。**バッチ処理用に始めから終わりが定義されているデータでも良いし、ストリーム処理用に（概念上）無限に流れるデータでも良い。**
- **Output**: 任意のデータ。これもbounded dataでもunbounded dataでも良い。

#### Beamのコードを見てみる

[JavaのMinimalWordCount example](https://github.com/apache/beam/blob/3ede5b76e48b41e89bc67541ea5044ebe704e905/examples/java/src/main/java/org/apache/beam/examples/MinimalWordCount.java)を見る。

コメントを短縮するとこんな感じ。
`PCollection 出力PCollection = 入力PCollection.apply(Transform)` なメソッドチェーンが続く。

```java MinimalWordCount 抜粋
Pipeline p = Pipeline.create(options);  // 空のパイプラインを作成

p.apply(  // パイプラインにRead Transformを追加する
    // テキストファイルから読み取る Read Transform
    TextIO.read().from("gs://apache-beam-samples/shakespeare/kinglear.txt")
)
    // この時点で PCollection が出来上がっている。
// PCollectionのレコード型は String で、テキストファイル1行ごとにレコードになっている。

// レコードを、空白文字で更に区切る。
// ただ split するだけだと List<List<String>> みたいになってしまうので FlatMap する。
// FlatMapElements は一つの Transform。
    .apply(
        FlatMapElements.into(TypeDescriptors.strings())
            .via((String line) -> Arrays.asList(line.split("[^\\p{L}]+"))))

// Filter の Transformで空文字列を排除
    .apply(Filter.by((String word) -> !word.isEmpty()))

// Countはレコード列に関する集計をしてくれる便利 Transform。
// ここではレコード全体（すなわち単語）ごとに一意なものを取り、それらの個数を数えて key-value に変換。
    .apply(Count.perElement())
// ここで出来上がった PCollection のレコード型は KV<String, Long>

// KVだったレコードをhuman readableなStringに変換
    .apply(
        MapElements.into(TypeDescriptors.strings())
            .via(
                (KV<String, Long> wordCount) ->
                    wordCount.getKey() + ": " + wordCount.getValue()))

// Write Transform を適用し、 wordcounts という名前のファイルにStringなレコードを書いていく
    .apply(TextIO.write().to("wordcounts"));

// ここまでで出来上がったパイプライン p を実行し、結果を待つ。
p.run().waitUntilFinish();
```

#### Beamにおけるパイプライン実行

パイプラインは、SDKを介してRunnerに渡される。パイプラインはRunnerから更にEngineに渡されてEngineが実行するのが基本である。

例えば、ストリーム処理系としてFlinkを利用し、コードはJavaで書く場合は下図のような構成になる。典型的にはRunnerはリモートサーバーで、Engineは別のリモートサーバーで稼働することになる。

<img src="/img/2022/08-31-01.drawio.svg" alt="SDK, Runner, Engine" width="600px" height="auto">

主にlocal環境での動作確認やテスト用に、Direct Runnerというのも用意されている。Engineの機能も果たし、パイプライン実行までしてくれるもの。

<img src="/img/2022/08-31-02.drawio.svg" alt="Direct Runner" width="600px" height="auto">

### Beamのプログラミングモデルをちゃんと理解

[Beam Programming Guide](https://beam.apache.org/documentation/programming-guide/) を読むのが入門として一番良い。が、中々骨があるドキュメントなので、ここで「躓きやすい知識」について記載しておく。
本記事の趣旨とはずれるので、次のセクションまで読み飛ばしても良い。

- **Schema**
  - `6.1. What is a schema?` に書かれているようなデータ型は、スキーマに**できる**（明示的にしなければスキーマにはならない）。
  - スキーマはPCollectionに紐付けられる。入力PCollectionがスキーマと紐付いている場合、PTransformとして schema transform (またの名を relational transform) が使える。
  - Schema transform の出力はスキーマである（関係代数が閉包であるのと同様）ので、schema transformをつなげている部分パイプラインにおいては、スキーマ定義は最低1つで済む。

- **Row**
  - スキーマが付与されたPCollectionの1レコードのインスタンス。すなわち、あらゆるPTransformの中でrowを入力として扱えるわけではない点に注意。

- **Coder**
  - Runnerを流れるバイト列と、SDKと合わせて使うユーザー定義型（クライアントサイド）の変換を受け持つ。
  - リッチなものだと、read transform が特定のフォーマットのデータ（例: JSON）をマッピングさせるのにCoder定義したり。
  - もうちょっと些末なものだと、パイプラインの途中の PTransform が文字列データを入力とする時、パイプラインを流れるデータ列をUTF-8と仮定して [StringUtf8Coder](https://javadoc.io/static/org.apache.beam/beam-sdks-java-core/2.40.0/org/apache/beam/sdk/coders/StringUtf8Coder.html) を使ったり。

## 前提知識: Beamでは複数種類のバックエンドが使える

[Beam Capability Matrix](https://beam.apache.org/documentation/runners/capability-matrix/) に列挙されているものはBeamに認知されていて公式にRunnerが用意されている処理系。

「あなたが構成したパイプラインは DirectRunner でテストし、Google Cloud DataflowでもFlinkでも（他のでも）動かせますよ」という世界観。

豆知識だが、最も注力されているRunnerはGoogle Cloud Dataflow。次いでOSSのFlinkと言った構造。Googlerの投資をOSS陣営のFlinkが追いかけるといった様相が[2016年のGoogleのブログ](https://cloudplatform-jp.googleblog.com/2016/05/apache-beam-dataflow.html)から読み取れるが、そのパワーバランスは2022年になっても継続している模様。

## 前提知識: Beamプログラムは多言語で記述できる

JavaのMinimalWordCount exampleに触れたが、Java以外にもPython, Go, TypeScript用のSDKが用意されており、これらの言語でBeamパイプラインを構成することができる。

ちなみにRust SDKもGooglerから要望が高いという話が[Beam Summit 2022の講演であった](https://www.notion.so/Google-s-investment-on-Beam-and-internal-use-of-Beam-at-Google-b024c069205f419daf1d1c40dd9524b7)ので、いつかサポートされるかも。

## 多言語・他バックエンド対応の課題

### 言語をまたいだUDF定義・実行が厳しい

JavaのMinimalWordCount exampleに出てきたTransformの中には、UDF (User-Defined Function) が含まれていた。

```java MinimalWordCount 抜粋
.apply(
    FlatMapElements.into(TypeDescriptors.strings())
        .via(
            // このラムダ式とか
            (String line) -> Arrays.asList(line.split("[^\\p{L}]+"))))

.apply(Filter.by(
    // これとか
    (String word) -> !word.isEmpty()))
```

Javaで定義されたラムダ式は、Java実装のRunnerなら実行できる（ただしSDKからRunnerにこのラムダ式を送信するための術は必要）。

しかし他の言語（e.g. JVM言語でない Go, Python, TypeScript）で実装されたRunnerでJavaのラムダ式を実行するのは困難である。

したがって、naiveに考えるとSDKを提供する言語の数だけRunner実装を作る必要がある。

### EngineごとにRunnerを作る必要がある？

Runnerの役割は、各Engineに対してBeamのパイプラインをsubmitし、結果を受けることである。

各Engineのデータモデルに合わせてBeamパイプラインを変換しなければならないというのが基本路線であり、naiveに考えるとEngineの数だけRunnerを作る必要がある。

### Runner実装の数 == SDK言語の数 x Engine数？

実際のところ、途中まではそのような方針だった。Flink RunnerもDataflow Runnerも、JavaにもGoにもPythonにも実装されていたりする。 (2022/08現在)

これでは言語追加もEngine追加も全くやりたくないですね…

<img src="/img/2022/08-31-beam-reality-2018.png" alt="https://docs.google.com/presentation/d/1Yg8Xm4fb-oRjiLQjwLt5153hpwwTLclZrVOKP2hQifo/edit#slide=id.p より引用" width="auto" height="auto">

## Apache Beamが多言語・多バックエンド処理系を実現する仕組み

上述の `Runner実装の数 == SDK言語の数 x Engine数` 問題を解決するため、2019年頃からBeamでは “Portability Framework” の導入が進められている。

Portability Frameworkは現在も開発途上であり、細かい方針転換もあったりするようなので、このドキュメントを記載する上で参照したドキュメントをまず列挙する (いずれも 2022/08/31 時点参照)。

- [Runner Authoring Guide](https://beam.apache.org/contribute/runner-guide/)
- Fn APIの design doc
  - [Apache Beam Fn API Overview](https://docs.google.com/document/d/1XYzb1Fnt2sam7u2MsGFaZp-2qSIGxUn66VLer-bcXAk/edit#heading=h.p6lvszfbmyj6)
  - [Apache Beam Fn API How to send and receive data](https://docs.google.com/document/d/1IGduUqmhWDi_69l9nG8kw73HZ5WI5wOps9Tshl5wpQA/edit#heading=h.gh88g5y0rekp)
- [apache/beam](https://github.com/apache/beam) のJavaコード, Protobuf定義

### [理想像] Portable Frameworkの仕組み

ドキュメントなどから読み解ける理想像を記載。なお、まだ全然固まっていないところもあり一部筆者の推測も含む。

Portable Runnerにより、例えば「JVMで動作するFlinkやDataflowなどのEngineを使いつつPythonで定義したパイプラインを実行」することが可能になる。

<img src="/img/2022/08-31-03.drawio.svg" alt="Portable Runner" width="600px" height="auto">

---

まず、UDFが登場しないパイプラインについて図解する。

<img src="/img/2022/08-31-04.drawio.svg" alt="UDFが登場しないパイプラインのPortable Runnerでの実行" width="600px" height="auto">

これが実現できれば、Portable Runnerの実装言語は何でも良くなり、かつRunnerはPortable Runnerが1つあれば事足りるようになる。

---

しかし、Runner APIだけではだけではUDF実行ができない。
ProtocolBeffer（やgRPC）では「クライアント側で任意の言語で定義された関数を、別言語で実装されたサーバー側で実行する」という芸当はできないからだ。

UDFが登場するパイプラインでは下図のようになる。

<img src="/img/2022/08-31-05.drawio.svg" alt="UDFが登場するパイプラインのPortable Runnerでの実行" width="600px" height="auto">

新たに SDK Harness というのが登場している。この実体はDockerコンテナであり、本例では「PythonのUDFが実行できるようにPython処理系 (とBeamランタイム) が入ったDockerコンテナ」である。

Portable Runnerは、自分でもEngineでも実行できない多言語のUDF実行をSDK Harnessに委託する形である。

### [2022/08] Portable Framework の現状

Portable Runner を各言語に定義する動きが見受けられる。

- Java: <https://github.com/apache/beam/blob/master/runners/portability/java/src/main/java/org/apache/beam/runners/portability/PortableRunner.java>
- Python: <https://github.com/apache/beam/blob/master/sdks/python/apache_beam/runners/portability/portable_runner.py>
- TypeScript: <https://github.com/apache/beam/blob/master/sdks/typescript/src/apache_beam/runners/portable_runner/runner.ts>

※なぜGoに Portable Runner がないのかは未調査

SDKからRunnerへのパイプライン受け渡し部分にはRunner APIは使われていない。

<img src="/img/2022/08-31-06.drawio.svg" alt="現状のPortable Runnerでの実行" width="600px" height="auto">

また、SDK Harnessの実装はGoogle Cloud Dataflow用のものだけ進んでいるように見えて、実質SDKとRunnerの言語は合わせる必要がある状況。
