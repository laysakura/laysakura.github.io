---
title: 自作CPU & 自作OSをやっていく (4) - macOSでPapilio Pro LX9のFPGAにBitstreamファイルを書き込む
id: handcraft-cpu-os-4
tags:
  - 自作CPU & 自作OS
date: 2020-02-16 20:10:00
---

<img src="/img/2020/02-16-papilio-pro-lx9.jpg" alt="Papilio Pro LX9" width="800">

2020年1月から、趣味エンジニアリング活動として自作CPUと自作OSをやっていく。

最終的にはFPGAに自作のCPUを書き込んでいくのだが、筆者はFPGAを使った経験がほとんどない。
CPUの回路設計はまだ手もつけていないが、不確実性を下げるために、先にFPGAを購入して普段遣いのmacOSからFPGA開発ができるように整えておく。

最終的には、macOSから `papilio-prog` コマンドでBitstreamファイル (`.bit`) を [Papilio Pro LX9](http://akizukidenshi.com/catalog/g/gM-06926/) 評価ボードに書き込むことに成功したので、その記録を備忘として残しておく。

[自作CPU & 自作OS](/tags/自作CPU-自作OS/) タグで、この前後の進捗とか目指しているもの（初回記事）とかを追えるようにしている。

<!-- more -->

## 目次
<!-- toc -->

## FPGAの選定

正確に言うとFPGAではなく、FPGAがペリフェラル（周辺機器）と一体になった **評価ボード** を購入する。I/Oがないと、FPGAがどれだけ計算してくれても本当に動いているかは人間にはわからないし、それ以前にFPGAに回路設計を書き込むこともできない。

評価ボードも色々とあるのだが、

- 予算1万円程度
- macOSでの動作報告あり

という軸で1時間程度ネットサーフィンし、Papilio Proにした。Papilio Proにもいくつか種類があるみたいだが、日本の代理店から気軽に買えそうな [Papilio Pro LX9](http://akizukidenshi.com/catalog/g/gM-06926/) を秋月電子通商の通販で買った。ポチって1日後に届いたからえらい。

## Bitstreamファイルの書き込み

### USB mini-B ケーブルをつなぐ

Papilio Pro LX9のFPGAに書き込むためには、USB mini-Bという少し変わった規格のケーブルが必要である。自分はホストマシンがMacBook Pro 2019なので、USB-C to USB mini-B のこちらのケーブルを買った。

<iframe style="width:120px;height:240px;display:block;margin:0px auto;" marginwidth="0" marginheight="0" scrolling="no" frameborder="0" src="https://rcm-fe.amazon-adsystem.com/e/cm?ref=qf_sp_asin_til&t=laysakura-22&m=amazon&o=9&p=8&l=as1&IS2=1&detail=1&asins=B07CG8KX82&linkId=5227412989b1e923eb1b2a50788f3bde&bc1=000000&lt1=_top&fc1=333333&lc1=0066c0&bg1=ffffff&f=ifr">
    </iframe>

ケーブルを接続すると、PWRの赤色LEDが常灯し、LED1の緑色LEDが一定時間ごとに点滅する。どうやらLED1を点滅させるようにFPGAがコンフィグレーションされているようだ。

### `papilio-prog` コマンドの準備

Papilio Pro LX9に載っているFPGAはXilinx社製のSPARTAN-6というもの。

Xilinx社のFPGAに書き込めるファイルフォーマットはBitstream (`.bit`) というものらしい。ChiselからBitstreamを作る方法は別途調べる必要があるが、確立できると一旦は信じる。

FPGAへ書き込むためのソフトウェアとして有名なのはXilinx社のVivadoというものなようだが、macOSに対応していない。Dockerコンテナの中でVivadoを飼っても、ホストマシンのUSBでつないでいるPapilio Pro LX9をコンテナ内から認識させるのは至難の業である（どうやらVirtualBoxとDockerを組み合わせればいけそうだが）。
VirtualBoxなどのVMでLinuxを立ち上げることまではしたくなかったので、macOSでFPGA書き込みできる方法を探したところ、Papilio-Loaderというものが使えるらしい。

http://forum.gadgetfactory.net/files/ から **Papilio Loader GUI** という製品を探し、macOS版をダウンロードする。本記事記載時点のダウンロードリンクは http://forum.gadgetfactory.net/files/file/10-papilio-loader-gui/?do=download&r=916&confirm=1&t=1&csrfKey=97793f1c268a77d4c25aad1c135b43f1 。

zipファイルを展開するとpkgファイルができるので、それをダブルクリックしてGUIでインストール。 `“Papilio-Loader.pkg”は、開発元が未確認のため開けません。` というエラーダイアログが出るが、macOSの **「システム環境設定 → セキュリティとプライバシー → "一般"タブ」** から **「ダウンロードしたアプリケーションの実行許可」** を与えてやれば良い。
インストールしたら、お使いのシェルが起動時に読むファイルにてPATHを通す。

```bash $HOME/.zshrc
export PATH=/Applications/GadgetFactory/Papilio-Loader/Java-GUI/programmer/macosx:$PATH
```

この段階で一度 `papilio-prog` コマンドを起動してみよう。

```bash
papilio-prog
```

成功したら下記の出力が見られる。

```text
No or ambiguous options specified.

Usage:papilio-prog [-v] [-j] [-f <bitfile>] [-b <bitfile>] [-s e|v|p|a] [-c] [-C] [-r] [-A <addr>:<binfile>]
   -h                   print this help
   -v                   verbose output
   -j                   Detect JTAG chain, nothing else
   -d                   FTDI device name
   -f <bitfile>         Main bit file
   -b <bitfile>         bscan_spi bit file (enables spi access via JTAG)
   -s [e|v|p|a]         SPI Flash options: e=Erase Only, v=Verify Only,
                        p=Program Only or a=ALL (Default)
   -c                   Display current status of FPGA
   -C                   Display STAT Register of FPGA
   -r                   Trigger a reconfiguration of FPGA
   -a <addr>:<binfile>  Append binary file at addr (in hex)
   -A <addr>:<binfile>  Append binary file at addr, bit reversed
```

だが、大抵は「`libftdi-1.2.0.0.dylib` が見つからない」というエラーを見ることになるだろう。仕方ないから入れる。なお、よくわからないが古めのバージョンの `libftdi-1.2.0.0` に決め打ちで動的リンクされているようで、 `brew install libftdi` でインストールしても失敗する。

```bash
git clone git://developer.intra2net.com/libftdi
cd libftdi

git checkout v1.2

mkdir build
cd build

cmake -DCMAKE_INSTALL_PREFIX=$HOME/usr/local ../
# もしかしたら、事前に `brew install libusb  と `brew install confuse` あたりが必要かも。

make
make install
```

この状態でもう一度 `papilio-prog` コマンドを試すと動いた。

### サンプルのBitstreamファイルの書き込み

[Papilio Quick Start Guide](https://papilio.cc/index.php?n=Papilio.GettingStarted) に、サンプルのBitstreamファイル [`Quickstart-Papilio_Pro_LX9-v1.5.bit`](http://papilio.cc/sketches/Quickstart-Papilio_Pro_LX9-v1.5.bit) が置いてあるので、ダウンロードしておく。

ケーブルを繋いだ状態で以下のコマンドを実行すると、LED1の点滅が止まる。これで多分書き込みに成功。

```bash
papilio-prog -v -f /path/to/Quickstart-Papilio_Pro_LX9-v1.5.bit
=> Using built-in device list
=> JTAG chainpos: 0 Device IDCODE = 0x24001093     Desc: XC6SLX9
=> Created from NCD file: top_avr_core_v8.ncd;UserID=0xFFFFFFFF
=> Target device: 6slx9tqg144
=> Created: 2012/02/13 17:18:57
=> Bitstream length: 2724832 bits
=> 
=> Uploading "/path/to/Quickstart-Papilio_Pro_LX9-v1.5.bit". DNA is 0x59655577c72e74fe
=> Done.
=> Programming time 587.0 ms
=> USB transactions: Write 176 read 8 retries 6
```
