---
title: Automotive CTF Japan 2024 予選 - writeup
id: automotive-ctf-2024-qual
tags:
  - CTF
  - 自動車セキュリティ
date: 2024-09-09 09:03:35
---

<img src="/img/2024/09-08/image.png" alt="image.png" width="auto" height="auto">

（↑順位確定時点のスコア画像）

[Automotive CTF Japan](https://vicone.com/jp/automotive-ctf)の予選にチーム参加し、5位で予選を突破しました。
（※所属とは無関係に個人活動として参加）

全問正解できましたが、先着順で順位が上になるのでこの順位です。

基本今まではCTF1人参加だったので、チーム参加は新鮮でした。お誘いくださったbeaさん、一緒に戦った hamayanhamayanさん、kusano_kさん、tkitoさん、ありがとうございました！

自分が解いた問題、途中まで触った問題についてwriteupを書きます。

<!-- more -->

## 目次
<!-- toc -->

## 大会（予選）形式

詳しくは[公式ルール](https://ctf.blockharbor.io/rules/jp)をご参照。

- 2024/08/24~09/08の2週間、オンライン開催
- 1~5名のチームを組んでのチーム戦
- Jeopardy形式。初期状態では全問1000点だが、解いたチームが多い問題ほど配点が低く調整される
  - 解いた順は獲得点数には影響なし
- 獲得点数が同じ場合は、早くその点数に達したほうが高順位

## 感想・反省

- 自動車知識が必要な問題は3~4割ほど？
- 自動車関連はあまり強くないので、昨年の同CTFの過去問で対策してた。しかし過去問はUDS中心だったが今年はcandumpのログ解析中心で、対策は足りなかった
  - 過去問対策の成果:
    - 知識まとめ: <https://laysakura.notion.site/CTF-Automotive-car-vehicle-deca002ee9de42f89ba18ddcdb5c183a>
    - writeup: <https://laysakura.notion.site/Automotive-CTF-2023-Proving-Grounds-writeup-8428584750dc47e0bf83b92525eb1b4a>
- 問題の構造を解析しきるところまではうまくできた。しかしそこから出題意図を読み切ってのフラグ獲得まで至れない問題がいくつかあった。「解き切る力」が今後の課題（新書タイトルっぽい）
- チーム戦ってすごい。「ここまではできたんだけどこっからわからん…」と投げたら解いてもらえたりして心強い。寝て起きただけで得点上がってるのすごい
  - またチーム戦やりたいのでお気軽にお声がけください…！

## Stego

### VCAN

<img src="/img/2024/09-08/image%201.png" alt="image.png" width="500px" height="auto">

チームメンバーが途中まで見てくれてたのに途中から参戦して解き切った。

---

candumpのログが与えられる。

CAN IDが `VO1` とおかしなものだけを対象に、ASCIIを見てみる。Savvy CANを使った。

`bh{` はすぐに見つかるが、フラグとしての全体像はむずい。ぐっと睨むと、先頭3バイトを繋げると意味がありそう…？

<img src="/img/2024/09-08/image%202.png" alt="image.png" width="500px" height="auto">

以下のフラグで正解。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ bh{4N4LYZ1NG_C4N_1S_34SY}

</aside>

## xNexus

### Can bus anomaly #2

<img src="/img/2024/09-08/image%203.png" alt="image.png" width="500px" height="auto">

チームメンバーが途中まで見てくれていて途中から参戦し、解き切った。

弊チームとして最後に解けた問題。

---

xNexusという、自動車のログから脆弱性レポートやら異常検知やらしてくれるRUMみたいなWebサービスのアカウントが渡される。

CAN ID 0x0645 を中心に見て、車種かVINあたりを当てれば良いらしい。

---

チームメンバーも自分も、ログ集めたり整形したりするスクリプト色々書いてウンウンしてたのだが、そういう問題ではなかった模様…

---

基本に立ち返り、問題文を参考に `disable esp power assisted system "can" "attack"` でググったら、Blackhatの↓の論文がヒット。

[https://www.blackhat.com/docs/us-17/thursday/us-17-Nie-Free-Fall-Hacking-Tesla-From-Wireless-To-CAN-Bus-wp.pdf](https://www.blackhat.com/docs/us-17/thursday/us-17-Nie-Free-Fall-Hacking-Tesla-From-Wireless-To-CAN-Bus-wp.pdf)

この中にあるCANバスへの攻撃で今回のログと類似したのあるかな〜と思って読み始めたら、1ページ目にテスラのモデル名が攻撃ターゲットとして記載してある。

まさかねぇと思いつつこれをフラグとして入力したら、あっさり正解… 実質OSINT問題だった。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ bh{Tesla Model S} か bh{Tesla Model S P85} のどちらか（うろ覚え）

</aside>

## We'll See in the Mach-E

このカテゴリは自分が一人で初日に解き切った。

---

wsme.zip というcandumpログが入ったzipを渡されるので、それを解析して諸々の質問に答えていくカテゴリ。

後知恵としては、↓の解き方が良さげだと思っている。

1. 前処理（データクレンジング、SavvyCANで読めるようにGVRETへ変換）する
2. SavvyCANでASCII部分を睨み、気合でVINを特定
3. VINからメーカーを特定。<https://github.com/commaai/opendbc/blob/master/opendbc/dbc/ford_lincoln_base_pt.dbc> を入手し、SavvyCANに適用
4. 問題の情報を得られる各CAN IDを丁寧に1つずつ絞り込む

---

ログファイルに破損？があるので、前処理としてクレンジングしておく。

```bash
rm wellsee_mache.log ; unzip wsme.zip

# can2 には `##5` が紛れており、これは `#` に置換
sed -i 's/##5/#/g' wellsee_mache.log
```

更に、SavvyCANで読み込めるように、GVRET Logs (CSV) 形式に変換する。

該当スクリプト: [https://gist.github.com/laysakura/5647720f545e334f7f9dc9cb77c474d5](https://gist.github.com/laysakura/5647720f545e334f7f9dc9cb77c474d5)

```bash
% python analyze.py csvout < wellsee_mache.log > wellsee_mache.csv
```

### DID Access

<img src="/img/2024/09-08/image%204.png" alt="image.png" width="500px" height="auto">

Read Data By Identifiers (0x22) で、問題文のDID 0x4915を呼んでいる箇所を探す。

`224915` でgrepするとヒットする。

```bash
can3 7E4#03224915CCCCCCCC
```

ソースCAN IDが 7E4。これはUDSの匂い。UDSとすると、デスティネーションCAN IDは +8 の 7EC だと予想できる。

`7EC#` でgrepすると↓ヒット。

```bash
can3 7EC#037F223100000000
```

やはりUDSのレスポンスとして解釈できる。

- 03バイトの
- 7F（negative response）の
- 22サービスに対しての
- 31ネガティブレスポンスコード

ということ。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ 0x31 (フラグ形式うろ覚え)

</aside>

### What is the VIN?

<img src="/img/2024/09-08/image%205.png" alt="image.png" width="500px" height="auto">

CANフレームをASCIIデコードして眺めていると、CAN ID 40A にVINの断片を感じた。断片を繋げてビンゴ。

```python
# 自作スクリプトにて CAN ID 0x40A のログをASCIIで観察
# 後知恵としては、これ使わないでもSavvyCANで同じことできる
% python analyze.py -i 40A longascii < wellsee_mache.log
{"interface": "can3", "canid": "40A", "dataLen": 8, "dataHex": "C10033464D544B34", "dataAscii": "..3FMTK4"}
{"interface": "can0", "canid": "40A", "dataLen": 8, "dataHex": "C10033464D544B34", "dataAscii": "..3FMTK4"}
{"interface": "can2", "canid": "40A", "dataLen": 8, "dataHex": "C10033464D544B34", "dataAscii": "..3FMTK4"}
{"interface": "can1", "canid": "40A", "dataLen": 8, "dataHex": "C10033464D544B34", "dataAscii": "..3FMTK4"}
{"interface": "can3", "canid": "40A", "dataLen": 8, "dataHex": "C1015358384D4D45", "dataAscii": "..SX8MME"}
{"interface": "can2", "canid": "40A", "dataLen": 8, "dataHex": "C1015358384D4D45", "dataAscii": "..SX8MME"}
{"interface": "can0", "canid": "40A", "dataLen": 8, "dataHex": "C1015358384D4D45", "dataAscii": "..SX8MME"}
{"interface": "can1", "canid": "40A", "dataLen": 8, "dataHex": "C1015358384D4D45", "dataAscii": "..SX8MME"}
{"interface": "can3", "canid": "40A", "dataLen": 8, "dataHex": "C1023030383738FF", "dataAscii": "..00878."}
{"interface": "can2", "canid": "40A", "dataLen": 8, "dataHex": "C1023030383738FF", "dataAscii": "..00878."}
{"interface": "can1", "canid": "40A", "dataLen": 8, "dataHex": "C1023030383738FF", "dataAscii": "..00878."}
{"interface": "can0", "canid": "40A", "dataLen": 8, "dataHex": "C1023030383738FF", "dataAscii": "..00878."}
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ 3FMTK4SX8MME00878

</aside>

---

**この問題でVINが分かったので、車種特定 → DBC入手 により、謎のcandumpに意味づけして読むことができるようになる。**

<https://vpic.nhtsa.dot.gov/decoder/Decoder> で検索すると、Fordの2021年の車であることが分かった。

<img src="/img/2024/09-08/image%206.png" alt="image.png" width="500px" height="auto">

対応するDBCファイルとして <https://github.com/commaai/opendbc/blob/master/opendbc/dbc/ford_lincoln_base_pt.dbc> を見つけた。以下の問題はこのファイルをSavvyCANに読み込ませた状態で解いていく。

### Steering Angle

<img src="/img/2024/09-08/image%207.png" alt="image.png" width="500px" height="auto">

SavvyCANでCAN IDを一つずつ眺めていくと、Steering AngleはCAN ID 0x07Eのものとわかる。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ 0x07E

</aside>

### When were we driving?

<img src="/img/2024/09-08/image%208.png" alt="image.png" width="500px" height="auto">

相変わらずCAN ID を一つずつ昇順に見ていく。CANID 0x084 が GlobalClock_Data_FD1 というやつ。

2024年で、1/1から178日後らしい。6/26だって。

<img src="/img/2024/09-08/image%209.png" alt="image.png" width="500px" height="auto">

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ 26/06/2024

</aside>

### Radio

<img src="/img/2024/09-08/image%2010.png" alt="image.png" width="500px" height="auto">

CAN ID 0x1E9 、なんかやたらと自然言語っぽい。

<img src="/img/2024/09-08/image%2011.png" alt="image.png" width="500px" height="auto">

95.5っていうのがFMの周波数？と思ったら当たった。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ 95.5

</aside>

### Street Names

<img src="/img/2024/09-08/image%2012.png" alt="image.png" width="500px" height="auto">

CAN ID 0x2C0 に何やら通りの名前？が。

<img src="/img/2024/09-08/image%2013.png" alt="image.png" width="500px" height="auto">

Piedmont,Acacia,Wheaton,Rochester かな？こういうアメリカ自信ニキに有利問題やめてくれ〜

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ Piedmont,Acacia,Wheaton,Rochester

</aside>

### Where were we driving?

<img src="/img/2024/09-08/image%2014.png" alt="image.png" width="500px" height="auto">

CAN ID 0x462にGPSの緯度経度発見。

<img src="/img/2024/09-08/image%2015.png" alt="image.png" width="500px" height="auto">

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ 42.33,-83.07

</aside>

## Crypto

### Autosar E2E

<img src="/img/2024/09-08/image%2016.png" alt="image.png" width="500px" height="auto">

問題の解析・解法の指針示しまではできたが、解き切れずチームメンバーに解いてもらった。

---

シミュレーターのシェル環境が与えられる。

```python
candump -a vcan0
```

でCANメッセージを観測。最初に以下に気づく。

- CAN ID = 101, 102, 103 が登場
- 140個のメッセージごとにスリープする
- 140 * 3 個のメッセージごとに周期性がある（元のメッセージの繰り返しになる）

---

更に眺めると、↓の法則性に気づく。

| CAN ID | 0-7bit | 8-11bit | 12-15bit | 16-19bit + 20-23bit |
| --- | --- | --- | --- | --- |
| 共通 | 140行セット同士を比べると、**あるバイトが出てくる行は同じ**(101, 102, 103すべて)。 | E or F。行番号で決まっている | 0, 1, …, A, B, …, E の15進数周期 (※Fはない) | - |
| 101 | 8-15bit目と1:1対応 | E, Fが交互に繰り返し？ | - | - |
| 102 | 同上 | わからん | - | - |
| 103 | わからん（規則性があるようには思えない。乱数かも） | 常にF | - | `J09LJw==` 固定 → base64decすると `'OK'` |

---

チームメンバーに相談しつつ更に更にウンウンすると、102の8-11bit目は、 `E` を `0`, `F` を `1` に対応させて8つ組を1つのASCIIとして読むと、Base64エンコードされた `'SEND FLG'` であることが分かった。

つまり、

- 102: リクエスト。 `'SEND FLG'` と言っている
- 103: レスポンス。 `'OK'` と言っている
- 101: リクエスト・レスポンスの開始・終了時に挟まる制御的な何か

とわかった。

---

まだフラグには届かないので探索を続ける。

問題タイトルからAutosar E2Eという規格が関係することは推測がつく。ググって

<https://www.autosar.org/fileadmin/standards/R23-11/FO/AUTOSAR_FO_PRS_E2EProtocol.pdfの仕様文書に行き着く。>

vcan0を流れるCANメッセージがこの仕様書の何かしらのフォーマットに該当するはずと仮定して読み進めると、Profile 1というのが該当しそうなのこと分かった。特に、2バイト目の15進カウンタのところがプンプンする。

<img src="/img/2024/09-08/image%2017.png" alt="image.png" width="500px" height="auto">

仕様書に従ってCANメッセージに当てはめていくと、**1バイト目は Data ID == 0x2 とした場合のCRC** と考えて矛盾ないことが分かった。

Data IDの特定に使ったコードは↓

[https://gist.github.com/laysakura/b087efe4da122a85cd0e006b130a37ae](https://gist.github.com/laysakura/b087efe4da122a85cd0e006b130a37ae)

CRC計算は下図の通りに実装した。

<img src="/img/2024/09-08/image%2018.png" alt="image.png" width="500px" height="auto">

---

ここまで分かったところで、まだフラグに届かない。CRCはチェックサムでしかなく、情報量は増えなかったので…

vcan0に流れるメッセージを眺めているだけではこれ以上の進展はないと見切り、CANのブロードキャストかつ無認証な性質を踏まえ、自分自身がリクエストに**なりすます**問題なのだと看破した。

102に成り代わって、好きな Data ID で `'SEND FLG'` の代わりの好きなメッセージを送れるスクリプトを書いた↓

[https://gist.github.com/laysakura/ed7537b82b6af3e69f9f27468a175152](https://gist.github.com/laysakura/ed7537b82b6af3e69f9f27468a175152)

が・・・・・駄目っ・・・・・！

103はなりすましに反応はしてくれるが、 `'OK'` か `'ERR'` しか言ってくれない。

---

これでフラグに届かないってどういうことよと絶望しつつ、見落としがないかを見極めるために完全掌握した（つもりの）プロトコルに沿ったメッセージやり取りについて、ステートマシンを仮定してロギングするスクリプトを書いた↓

[https://gist.github.com/laysakura/4b24d809b68e0c8b54100ed683e846c8](https://gist.github.com/laysakura/4b24d809b68e0c8b54100ed683e846c8)

苦労して作っただけのことはあり、vcan0で何が起きているのかは一目瞭然になった。

<img src="/img/2024/09-08/image%2019.png" alt="image.png" width="500px" height="auto">

---

しかしここからいくらリクエストをガチャガチャなりすましてもフラグに届かず、チームメンバーに引き継いだ。

102のリクエストになりすますのではなく、103のレスポンスになりすますゲームだった….

<img src="/img/2024/09-08/image%2020.png" alt="image.png" width="500px" height="auto">

<img src="/img/2024/09-08/image%2021.png" alt="image.png" width="500px" height="auto">

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ bh{aut0s4r_e2e_encryp73d!}

</aside>

## Reversing

### Power [自力部分までのメモ]

<img src="/img/2024/09-08/image%2022.png" alt="image.png" width="500px" height="auto">

バイナリの動的解析・静的解析を合わせ、このバイナリがVMMを表しており、VMのバイトコードでやっていることを解析すべき問題であるところの特定までした。

しかし肝心のバイトコード解析が綺麗にいかず、チームメンバーがバイトコードのディスアセンブラを書いた上で華麗に解いてくれた。

問題の過程でGhidraとgdb力を上げることができたし、好きな問題。これからは自力でも解ききれるようになりたい。

以下、自分が取り組んだメモを書き残す。**不正確な箇所を含むことが分かっているので、他の人のwriteupを参考にしてください。**

---

PowerPCのバイナリを解析する問題。

- Ghidraで静的解析
- qemu-ppc + gdb (pwndbgおすすめ) で動的解析

していく。

---

```python
% file power
power: ELF 32-bit MSB executable, PowerPC or cisco 4500, version 1 (SYSV), statically linked, stripped
```

<img src="/img/2024/09-08/image%2023.png" alt="image.png" width="500px" height="auto">

---

```python
% qemu-ppc ./power
nothing happened...
```

---

QEMU + gdb (pwndbg) での解析:

<https://mariokartwii.com/showthread.php?tid=1998>

```python
% qemu-ppc -g 1234 ./power
```

この問題に有効なGDB Python Scriptを書いたのでこれを [hook.py](http://hook.py) として指定し使う。

hook.py: [https://gist.github.com/laysakura/ec4a4834a93a4c566ae3a088b76b1973](https://gist.github.com/laysakura/ec4a4834a93a4c566ae3a088b76b1973)

```python
% gdb-multiarch -q --nh \
  -x ~/.ghq/src/github.com/pwndbg/pwndbg/gdbinit.py \
  -x hook.py \
  -ex 'set architecture powerpc:common' \
  -ex 'set sysroot /usr/powerpc-linux-gnu' \
  -ex 'file power' \
  -ex 'target remote localhost:1234' \
  -ex 'set can-use-hw-watchpoint 0' \
  -ex 'set show-compact-regs on' \
  -ex 'set show-compact-regs-columns 4' \
  -ex 'custom-hooks'
```

---

#### この問題の厄介なところ

- PowerPC
  - 慣れればCISCなx86, x64より読みやすい…?
- 関数が少なく、ブロック&ラベルでジャンプ（bctr）しまくっている
  - Ghidraのデコンパイラに頼りきれない

#### プログラムが表現しているもの概要

- VM (CISC: 1byte or 4byte 命令)
  - 基本的に1byteずつ実行
  - 4byte命令が始まるきっかけ → `\0x4` 命令
- 0x1810ae4 からの謎バイト列 → VMが実行する命令列

#### プログラムの構造・処理の流れ

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⚠️ めちゃくちゃ書きかけ

</aside>

重要処理

| アドレス
1800 ??? | 処理 |
| --- | --- |
| 708 | guestPushFromR3 |
| 838 |  |
|  |  |
|  |  |
|  |  |
| a1c | LAB_vmR0=instruction2 |
|  |  |
|  |  |
|  |  |

- ホストは0x18000e0 のブロックから、概ね2つのブロックの組の単位で実行を進めることで、ゲスト処理を進行させる
  - 1つめブロック:
    - 2つ目ブロックのアドレスを VMStack にpush
    - ゲスト処理進行
      - ホスト変化: R12, R13レジスタが更新される
      - ゲスト変化: この過程で VMRegs や VMStack が変更される
    - 2つ目ブロックのアドレスを VMStack からpopし、そのアドレスにジャンプ
  - 2つめブロック:
    - R3 または R1レジスタが保持するアドレスをderef。その値を書き換える
    - VMStack からpopし、そのアドレスにジャンプ
  - 2つのブロック組の例↓

        <img src="/img/2024/09-08/image%2024.png" alt="image.png" width="500px" height="auto">

- ブロックにおけるr3は、vmR0がセットされている
- R12, R3==vmR0, (たまにR1, R4) が guest → ホストへの通信
- R12, R13 がホスト→guestへの通信

---

- 実行の過程で、ホストOSで `ls /` 的にするシステムコール呼び出し (sc) をしている
  - ホストOS側の `/` の中身で挙動（少なくともメモリの値）が変わる

    ```python
    % QEMU_STRACE=1 qemu-ppc ./power
    3027092 open("/",O_RDONLY) = 3                    # システムコール番号 5
    3027092 getdents(3,0x2368fcb,1024) = 408          # システムコール番号 141 = 0x8d
    3027092 write(0,0x236934b,21)nothing happened...  # システムコール番号 4
     = 21
    3027092 exit_group(0)
    ```

#### メモリ配置

概要

| **アドレス** | **仮命名** | **何が入ってる** | **誰が指している** |
| --- | --- | --- | --- |
| 0x1810c84 ~
… |  | **vmIP**が指す先
つまりVMRegsのoffset |  |
| 0x22ec3cf ~
0x22ec403 |  | VMRegs | 初期化後のR10 |
| 0x2368fcb ~
… |  | ls / 結果 |  |
| 0x236934b | **TheString** | “nothing happened…\n” |  |
| 0x0236938b ~
0x0236938c |  | 0x0000000
…
0x2f000000
… |  |
| 0x023693bb ~
0x023693cf | **VmStack** | 5段のスタック |  |

0x22ec3cf (R10) ~ 0x22ec403 VMRegs構造体

| アドレス | **仮命名** | **値推移メモ (interesting1開始時)** |
| --- | --- | --- |
| 0x22ec3cf | vmR0Offset{R0} | 0x00000197
0x22ec3eb (+0x1c)
0x00000040
0x22ec3fb (+0x2c)
0x22ec3db (+0xc)
0x00000000

0x000000fa |
| 0x22ec3d3 (+0x4) | vmR4 | 0x00000000
…

0x236934b |
| 0x22ec3d7 (+0x8) | … | 0x00000000
…

0x0236938b |
| 0x22ec3db (+0xc) | … | 0x00000000
…
0x00000001
…

0x00000000 |
|  |  |  |
| 0x22ec3df (+0x10) | … | 0x00000000
… |
| 0x22ec3e3 (+0x14) | … | 0x00000000
…
0x0236938b
…

0x00000000 |
| 0x22ec3e7 (+0x18) | … | 0x023693cf
…

0x00000000 |
| 0x22ec3eb (+0x1c) | **vmSP** | 0x023693cb
… |
|  |  |  |
| 0x22ec3ef (+0x20) | **TheStringSrc** | 0x00000000
…

0x00000198 |
| 0x22ec3f3 (+0x24) | **ptrDentry

8ずつ+されている雰囲気** | 0x00000000
…

0x0236916b |
| 0x22ec3f7 (+0x28) | **vmIP**
 | 0x01810c83 (const data)
0x01810c88 (const data)
0x01810c8e (const data)
0x01810c93 (const data)
0x01810ca2 (const data)
0x01810cac |
| 0x22ec3fb (+0x2c) |  | 0x00000000
0x023693cb
0x0236938b
… |
|  |  |  |
| 0x22ec3ff (+0x30) |  | 0x00000000
… |
| 0x22ec403 (+0x34) |  | 0x01800ad8
(initの中で再帰的にinitを呼んだ後、返る際のアドレス)
… |

---

0x023693bb  ~ 0x023693cb VmStack

5段しかないスタック。

| アドレス | **仮命名** | **何が入ってる** | **値推移メモ (interesting1開始時)** |
| --- | --- | --- | --- |
| 0x023693bb |  |  | 0x00000000
….

0x22ec3df (+0x10) |
| 0x023693bf (+0x4) |  |  | 0x00000000
….
0x22ec3db (+0xc)
… |
| 0x023693c3 (+0x8) |  |  | 0x00000000
0x01800a1c (LAB_VMRegs.0=constDataU32)
…
0x22ec3e3 (+0x14)
…

0x22ec3d7 (+0x8) |
| 0x023693c7 (+0xc) |  |  | 0x00000000
0x22ec3fb (+0x2c)
…
0x22ec3e3 (+0x14)
0x01800a1c
0x0236938c

0x0236938b |
|  |  |  |  |
| 0x023693cb (+0x10) |  |  | 0x018004f4 (LAB_018004f4)
0x01800290 (LAB_01800290)
0x018004f4 (LAB_018004f4)
0x01800338 (LAB_TheString(nothing)を作りがち)
0x018004c4 (LAB_TheString[i]=r4)
0x018004f4 |

#### R5にファイル名が…

test-… みたいなディレクトリ消したら見れなくなったな?

<img src="/img/2024/09-08/image%2025.png" alt="image.png" width="500px" height="auto">

---

再現条件

```python
b *0x18000f8
c
c
...  # R5レジスタを見る
```

**8文字以上のディレクトリが必要？**

- [x]  `for i in $(seq 10) ; do sudo mkdir /test-$i ; done`
- [x]  `% for i in seq 1000 ; do sudo mkdir /TEST-$i ; done`

    <img src="/img/2024/09-08/image%2026.png" alt="image.png" width="500px" height="auto">

- [ ]  `for i in $(seq 10) ; do sudo mkdir /TES$i ; done`
  - [ ]  NG
- [ ]  `for i in $(seq 10) ; do sudo mkdir /TES-$i ; done`
  - [ ]  NG
- [x]  `% for i in $(seq 10) ; do sudo mkdir /TE-$i-ST ; done`

    <img src="/img/2024/09-08/image%2027.png" alt="image.png" width="500px" height="auto">

- [x]  `sudo mkdir /TE-10-ST`
- [ ]  `sudo mkdir /TE-1-ST`
  - [ ]  NG
- [ ]  `sudo mkdir /$(cyclic 128)`
  - [ ]  NG
- [ ]  `sudo mkdir /test`
  - [ ]  NG
- [ ]  `sudo mkdir /testtes`
  - [ ]  NG
- [x]  `sudo mkdir /testtest`
- [x]  `sudo mkdir /$(cyclic 8)`
  - [ ]  NG

#### 8文字ディレクトリがあるときの挙動を追う

```python
sudo mkdir /12345678

...

record full
```

#### [WIP] VM命令の解析

vmIPの使用箇所と、後続の動的な用途を観測。VMの命令列がいかなる意味かを探る。

---

もしかしたら命令列だけで意味は確定しないかも。2つの `[vm][main]` のどっち駆動で命令解釈が始まったかで処理結果が変わる可能性を感じる

---

`SUB_pushNextSub_...` `SUB_(next sub)`  の先頭にブレークを貼っていってcontinueし、2つ組のブロックの間で起こったことを観測すると、各命令がどう解釈され、スタック状態がどう変化したのかをマクロに見れそう
→ この単位で見ている限り、スタックの状態は気にしないで良さそう。常にbottom付近。stackはローカル変数と見れる

---

命令セットまとめ (* `<varName_N>` の N は何バイトかを表す)

- `01 <regNoA_1> <regNoB_1>` :
  - `vmR0 = *(byte *)vmGetRegAddr(regNoA_1) + *(byte *)vmGetRegAddr(regNoB_1)`
  - 計算過程で、vmGetRegAddr(regNoA_1), vmGetRegAddr(regNoB_1) のアドレス値がstackにpush/popされる
- `02 <regNo_1>`: **get reg addr**
  - `vmR0 = vmGetRegAddr(regNo_1)`
  - 副作用として、0x01800a1c が一瞬push/pop される
- `03 01 <jmpOffset_1>` : **jump near**
  - vmR0 = jmpOffset_1; vmIP += vmR0
- `03 04 <jmpOffset_4>` : **jump far**
  - vmR0 = jmpOffset_4; vmIP += vmR0
- **host jump to sub nth** ホストのCTRに次のSUBアドレス入れる命令（hostに制御戻す割り込み？）
  - `<nth_1>` : R12 = CTR = 0x1800074 + nth_1 * 4; bctr
    - where nth_1 == 0x12, 0x1a, …? （仮説: 上述の決まった命令セット以外？)

📝 `02 2c` 命令における vmR2c == 0x0 の用途
vmR0 = &vmR2c (0x22ec3fb)  にしたのは観測した。これをstackにpushまでする感じ？

- 1a:
  - 先頭の 1810ae4 にある。他にも7000件超。
  - 先頭のは hostInitで処理されている。 0x1800074 + **1a** * 4 = 0x18000dc (SUB_pushNextSub_… のアドレスへのポインタ) を定数計算するためっぽい
  - で、その後は SUB_pushNextSub_… が実行されて、nextSubのアドレスがpushされる
  - 仮説: push `1a`-th sub routine address?
- 12:
- 0x07, 0x12, 0x2c: nop; vmIP++

---

vmIP, vmSPの変化点でしっかり観測

```python
watch *0x22ec3f7
watch *0x22ec3eb

commands 1-2
> x/2i $pc-4
> end
```

---

使用箇所

<img src="/img/2024/09-08/image%2028.png" alt="image.png" width="500px" height="auto">

---

| **使用箇所** | **利用パターン** | vmIP 遷移 (#) | *vmIP 遷移
(4byte。有効箇所太字) |
| --- | --- | --- | --- |
| 18006f4
SUB_vmIP+=r3→pop→bctr | vmIP += r3 | 0x1810c82 (5)
← (4) + vmR0
= 0x1810aeb + 0x197 | 0x12    0x02    0x2c    0x02 |
| 1800764
vmR12=1_vmReg→pop→bctr | vmIP++ | 0x1810c87 (11) | 0x07    0x02    0x2c    0x03 |
| 180076c
vmR12=1_vmReg→pop→bctr | vmGetRegAddr(instruction) | 0x1810c85 (9) | **0x02**    0x1c    0x07    0x02 |
| 18007b0
vmR12=2_vmRegs(+)->pop->bctr | vmGetRegAddr(instruction) |  |  |
| 18007e8
vmR12=2_vmRegs(+)->pop->bctr | vmGetRegAddr(instruction) |  |  |
| 1800840
vmUpdateR12Indirectly->pop->bctr | r12=*(byte *)vmIP vmIP++; vm…()
(インクリメント前のinstructionは、次に呼び出されるvm…()関数の入力として使われる) | 0x1810ae5 (1) | **0x03**    **0x04**    0x00    0x00 |
| 18008a8
vmUpdateR4ByUpdatedvmR0,DependingOnR13==1,2,3->pop->bctr | vmIP++; vm…()
(インクリメント前のinstructionは、次に呼び出されるvm…関数の入力として使われる) | 0x1810c84 (8) | 0x2c    0x02    0x1c    0x07 |
| 18008e0
vmUpdateR4ByUpdatedvmR0,DependingOnR13==1,2,3->pop->bctr | vmIP++ | 0x1810c86 (10) | 0x1c    0x07    0x02    0x2c |
| 180094c
vmUpdateR4ByUpdatedvmR0,DependingOnR13==1,2,3->pop->bctr
R13==1のケース |*(byte *)vmIP == 1 |  | 先頭バイトは0x1のはず |
| 1800954
vmUpdateR4ByUpdatedvmR0,DependingOnR13==1,2,3->pop->bctr
R13==1のケース |*(byte *)vmIP == 2 |  | 先頭バイトは0x2のはず |
| 1800944
vmUpdateR4ByUpdatedvmR0,DependingOnR13==1,2,3->pop->bctr
R13==1のケース |*(byte *)vmIP == 3 |  | 先頭バイトは0x3のはず |
| 18009b8
vmUpdateR12&vmR0,DependingOn*vmIP==1,2,3 | *(byte *)vmIP == 1or2or3? | 0x1810ae6 (2) | **0x04**   0x00    0x00    0x01 |
| 18009e0
vmUpdateR12&vmR0,DependingOn*vmIP==1,2,3
*(byte *)vmIP == 1 のケース |*(byte *)vmIP == 1 |  |  |
| 1800a00
vmUpdateR12&vmR0,DependingOn*vmIP==1,2,3
*(byte*)vmIP == 4 のケース | *(byte*)vmIP == 4 then
  R12 = *(uint *)vmIP ; vmIP += 4 | 0x1810ae7 (3) | **0x00    0x00    0x01    0x97** |
| 1800a1c
vmUpdateR12&vmR0,DependingOn*vmIP==1,2,3 | vmR0 = instruction | 0x1810aeb (4) | 0x12    0x02    0x2c    0x02 |
| 1800a98
hostInit | vmIP++ | 0x1810c83 (7) | 0x02    0x2c    0x02    0x1c |

```python
% gdb-multiarch -q --nh \
  -x ~/.ghq/src/github.com/pwndbg/pwndbg/gdbinit.py \
  -x hook.py \
  -ex 'set architecture powerpc:common' \
  -ex 'set sysroot /usr/powerpc-linux-gnu' \
  -ex 'file power' \
  -ex 'target remote localhost:1234' \
  -ex 'set can-use-hw-watchpoint 0' \
  -ex 'set show-compact-regs on' \
  -ex 'set show-compact-regs-columns 4' \
  -ex 'custom-hooks' \
  -ex 'b *0x180076c' \
  -ex 'b *0x18007b0' \
  -ex 'b *0x18007e8' \
  -ex 'b *0x1800840' \
  -ex 'b *0x18008a8' \
  -ex 'b *0x180094c' \
  -ex 'b *0x1800954' \
  -ex 'b *0x1800944' \
  -ex 'b *0x18009e0' \
  -ex 'b *0x18009b8' \
  -ex 'b *0x1800a00' \
  -ex 'b *0x1800a1c'
```

---

```python
[regs] R0: 25168048     R1: 37131215    R3: 36619255    R12: 2  R13 (1-3): 0

[VMRegs] vmR0: 0x22ec3fb        vmIP: 0x1810c86 vmSP: 0x23693c7
0x22ec3cf:      0x022ec3fb      0x00000000      0x00000000      0x00000000
0x22ec3df:      0x00000000      0x00000000      0x023693cf      0x023693c7
0x22ec3ef:      0x00000000      0x00000000      0x01810c86      0x00000000
0x22ec3ff:      0x00000000      0x01800ad8

[VMStack] vmSP: 0x23693c7
0x23693bb:      0x00000000
0x23693bf:      0x00000000
0x23693c3:      0x00000000
0x23693c7:      0x022ec3fb
0x23693cb:      0x018004f4

[VMInstructions] vmIP: 0x1810c86
0x1810c7e:      0x00    0xad    0xb7    0x4c    0x12    0x02    0x2c    0x02
0x1810c86:      0x1c    0x07    0x02    0x2c    0x03    0x01    0x40    0x12
0x1810c8e:      0x02    0x14    0x02    0x2c    0x0a    0x02    0x0c    0x02

---

[regs] R0: 25168108     R1: 37131215    R3: 36619255    R12: 28 R13 (1-3): 2

[VMRegs] vmR0: 0x22ec3fb        vmIP: 0x1810c87 vmSP: 0x23693c3
0x22ec3cf:      0x022ec3fb      0x00000000      0x00000000      0x00000000
0x22ec3df:      0x00000000      0x00000000      0x023693cf      0x023693c3
0x22ec3ef:      0x00000000      0x00000000      0x01810c87      0x00000000
0x22ec3ff:      0x00000000      0x01800ad8

[VMStack] vmSP: 0x23693c3
0x23693bb:      0x00000000
0x23693bf:      0x00000000
0x23693c3:      0x01800a1c
0x23693c7:      0x022ec3fb
0x23693cb:      0x018004f4

[VMInstructions] vmIP: 0x1810c87
0x1810c7f:      0xad    0xb7    0x4c    0x12    0x02    0x2c    0x02    0x1c
0x1810c87:      0x07    0x02    0x2c    0x03    0x01    0x40    0x12    0x02
0x1810c8f:      0x14    0x02    0x2c    0x0a    0x02    0x0c    0x02    0x0c
```

#### ptrDentryの変遷

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⚠️ 役立つか不明

</aside>

```python
watch *0x22ec3f3

commands 1
> x/2i $pc-4
> x/1wx 0x22ec3f3
> x/4s 0x22ec3f3
> end
```

- めちゃくちゃたくさんディレクトリ作ったが、文字列サイズが伸びるわけでもない。
- ptrDentryが `ls /` 領域を指してブレークするときの命令:
  - 1回目 0x18004f4:   stw     r4,0(r3)
  - 2回目 0x1800228:   stw     r5,0(r3)
  - (… 以下、交互。回数がいつも決まってるわけではない)
- ptrDentryが 0x0, 0x1, 0x2, 0x3 を指してブレークするときの命令:
  - 0x0→ 0x1800340:   stw     r5,0(r3)
  - 0x1→ 0x1800100:   stw     r5,0(r3)
  - 0x2→ 0x1800100:   stw     r5,0(r3)
  - 0x3→  0x1800100:   stw     r5,0(r3)
  - 0x4→ 0x1800100:   stw     r5,0(r3)
- **ptrDentryが 0x000000fa を指してブレークする前後で TheString 変化が！**
  - before 0x000000fa : 空文字列
  - soon after 0x000000fa: “]XWP “
  - **0xfaになってブレークするときの命令**
    - **0xfa→ 0x1800524:   stw     r4,0(r3)**
    - **以後のブレークは全て 0x1800524**

#### “nothing happened…” を作っているところ再訪

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⚠️ 役立つか不明

</aside>

この領域にフラグが作られて、それがwriteされる問題だと思うんだよな… 俺が作問者ならそうする。

```python
record full
watch *0x236934b  # TheString先頭
b *0x1800938 if $r13==0x2  # TheStringに入れる文字を拾う箇所

commands 1
> x/2i $pc-4
> x/16wx 0x236934b
> x/1s 0x236934b
> end

commands 2
> x/2i $pc-4
> x/16wx $r6  # TheStringに入れる文字列
> x/1s 0x236934b
> end

c
```

---

一旦、 *0x236934b (4バイト) の変遷を追う → **2ステージに分けて文字ができている**

1. c 1~4回: `0x18004c4:   stb     r4,0(r3)` が4回呼び出され、 0xb65d9497 になる
2. c 5~8回:  `0x18004c4:   stb     r4,0(r3)` が4回呼び出され、 0x6e6f7468 == “noth” になる

---

*vmIP から文字を取っているコード → 1800954 (interesting1() の過程) とそこに至るまで

- r3 == 0x236934b
- r6 == 格納する文字列がLSBに入った4バイト
- (r4 = *r6) & 0xFF == 格納する文字

<img src="/img/2024/09-08/image%2029.png" alt="image.png" width="500px" height="auto">

---

0x236934b に格納しているコード → 18004c4

- r3 == 0x236934b
- r4 & 0xFF == 格納する文字？
  - いきなり最初から `'n'` ではなく、 `0xb6` から格納された

<img src="/img/2024/09-08/image%2030.png" alt="image.png" width="500px" height="auto">

---

**TheString (nothing) の取得箇所は常に *0x22ec3ef & 0xFF。この中身が転々としている**

| 文字 | 取得元 | 周辺メモリダンプ |
| --- | --- | --- |
| n | *0x22ec3ef & 0xFF | pwndbg>  x/32wx 0x22ec3ef
0x22ec3ef:      0x000000**6e**      0x000000fa      0x01810c3c      0x0236934b
0x22ec3ff:      0x20000000      0x01800ad8      0x00000000      0x00000000 |
| o | *0x22ec3ef & 0xFF | pwndbg> x/32wx 0x22ec3ef
0x22ec3ef:      0x000000**6f**      0x00000011      0x01810c3c      0x0236934b
0x22ec3ff:      0x40000000      0x01800ad8      0x00000000      0x00000000 |
| t | *0x22ec3ef & 0xFF | pwndbg> x/32wx 0x22ec3ef
0x22ec3ef:      0x000000**74**      0x000000c0      0x01810c3c      0x0236934b
0x22ec3ff:      0x40000000      0x01800ad8      0x00000000      0x00000000 |
| h | *0x22ec3ef & 0xFF | pwndbg> x/32wx 0x22ec3ef
0x22ec3ef:      0x000000**68**      0x000000de      0x01810c3c      0x0236934b
0x22ec3ff:      0x40000000      0x01800ad8      0x00000000      0x00000000 |
| i | *0x22ec3ef & 0xFF | pwndbg> x/32wx 0x22ec3ef
0x22ec3ef:      0x000000**69**      0x000000fa      0x01810c3c      0x0236934b
0x22ec3ff:      0x20000000      0x01800ad8      0x00000000      0x00000000 |
| n |  |  |
| g |  |  |
| (スペース) |  |  |
| h |  |  |
| a |  |  |
| p |  |  |
| p |  |  |
| e |  |  |
| n |  |  |
| e |  |  |
| d |  |  |
| . |  |  |
| . |  |  |
| . |  |  |

#### TheStringのソース文字の変遷を追う

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⚠️ 役立つか不明

</aside>

```python
record full
watch *0x22ec3ef  # TheStringソース文字

commands 1
> x/2i $pc-4
> x/16wx 0x22ec3ef
> end

c
```

| # | 変更箇所 (同上は空欄) | 変更後値 |
| --- | --- | --- |
| 1 | 0x1800228:   stw     r5,0(r3) | 0x10 |
| 2 |  | 0x20 |
| 3 |  | 0x30 |
| … |  | 0x40 |
|  |  | 0x50 |
|  |  | 0x60 |
|  |  | 0x70 |
|  |  | 0x80 |
|  |  | 0x90 |
|  |  | 0xa0 |
|  |  | 0xb**8** |
|  |  | 0xc**c** |
|  |  | 0xdc |
|  |  | 0xec |
|  |  | 0xfc |
|  |  | 0x**1**0c |
|  |  | 0x11c |
|  |  | 0x12c |
|  |  | 0x13c |
|  |  | 0x1**50** |
|  |  | 0x160 |
|  |  | 0x1**78** |
|  |  | 0x188 |
|  |  | 0x198 |
|  | 0x1800524:   stw     r4,0(r3) | **0xb6** |
|  | 0x1800340:   stw     r5,0(r3) | 0x4c (L) |
|  | 0x1800228:   stw     r5,0(r3) | **0x6e (n)** |
|  | 0x1800524:   stw     r4,0(r3) | 0x5d (]) |
|  | 0x1800340:   stw     r5,0(r3) | 0x4c (L) |
|  | 0x1800228:   stw     r5,0(r3) | **0x6e (n)** |
|  | 0x1800340:   stw     r5,0(r3) | **0x6f (o)** |
|  | 0x1800524:   stw     r4,0(r3) | 0x94 |
|  | 0x1800340:   stw     r5,0(r3) | 0x54 (T) |
|  | 0x1800228:   stw     r5,0(r3) | 0x76 (v) |
|  | 0x1800340:   stw     r5,0(r3) | **0x74 (t)** |
|  | 0x1800524:   stw     r4,0(r3) | 0x97 |
|  | 0x1800340:   stw     r5,0(r3) | 0x49 (I) |
|  | 0x1800228:   stw     r5,0(r3) | 0x6b (k) |
|  |  0x1800340:   stw     r5,0(r3) | **0x68 (h)** |
|  |  0x1800524:   stw     r4,0(r3) | 0xb1 |
|  | 0x1800340:   stw     r5,0(r3) | 0x4b (K) |
|  | 0x1800228:   stw     r5,0(r3) | 0x6d (m) |
|  |  0x1800340:   stw     r5,0(r3) | **0x69 (i)** |
|  |  |  |

#### [仮説→true]: getdentry結果が出るまで、TheStringは一文字も確定していない

```python
record full
b *0x1800564  # sc
c  # open
c  # getdentry
n

pwndbg> x/1s 0x236934b
0x236934b:      ""
```

#### [仮説 → true] `vmUpdateR4ByUpdatedvmR0,...()` でR13の値で条件分岐する箇所、R13 in (1, 2, 3) のいずれか

```python
record full
b *0x1800930 if $r13<1 || $r13>3  # cmpwi
c
```

ブレークせず！

**では、R13の意味とはなにか？**

#### [仮説 → false]  `vmUpdateR4ByUpdatedvmR0,...()` で、R13==2の処理をR13==1と同じにすればフラグが得られる

バイナリエディタで処理書き換えた power2 作ったけど、実行するとSEGV
