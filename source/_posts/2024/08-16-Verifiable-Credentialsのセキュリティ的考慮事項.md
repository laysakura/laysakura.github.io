---
title: Verifiable Credentialsのセキュリティ的考慮事項
id: vc-security
tags:
  - 認証技術
  - Verifiable Credentials
date: 2024-08-16 14:35:05
---

<img src="/img/2024/08-16/head.png" alt="脅威シナリオ列挙" width="auto" height="auto">

<br>

DID/VCの周辺技術を調べています。DID/VCの概要を知りたい方は [デジタルアイデンティティウォレットとは？｜注目される背景とサービス化の論点 | NRIセキュア ブログ](https://www.nri-secure.co.jp/blog/digital-identity-wallet) などご参照ください。

今回は、VCを取り扱う上で注意すべきセキュリティ的考慮事項についてサーベイしました。仕様ドキュメント・論文・講演をスコープにして探し、以下の4つのドキュメントについてまとめました。

- 仕様
  - W3C - **"Verifiable Credentials Data Model v2.0"** ドラフト
  - W3C - **"Verifiable Credentials Data Model v1.1"** 勧告
- 論文
  - **"SoK: Trusting Self-Sovereign Identity"** (Krul et al., 2024)
- 講演
  - **"Attacking Decentralized Identity"** (DEFCON 31, 2023)

実装者として気付かされる点が多く最も有用だったのは "Verifiable Credentials Data Model v2.0" ドラフトでした。また、脅威シナリオの種類が一番豊富だったのは "SoK: Trusting Self-Sovereign Identity" でした。この2つに関しては厚めに取り上げています。

それぞれのドキュメントのサーベイ結果はやや長くなっているので、まず始めにまとめを記載します。まとめは是非ご覧いただき、興味のあるドキュメントについては詳細を読んでいただければと思います。

<!-- more -->

## 目次
<!-- toc -->

## まとめ

サーベイ対象を網羅的にまとめたものではなく、特に学びになったと感じたところをピックアップしています。

### VCは中間者攻撃・リプレイ攻撃・スプーフィングに脆弱

"Verifiable Credentials Data Model v2.0" の9.5章で触れられています。

VCDM自体にはこれら攻撃に対する防御機構が存在しないため、実装や運用でカバーする必要があります。
このあたりは気をつけていても実装不備を起こしやすいところなので注意したいところです。

攻撃シナリオとしてまとめると以下のような感じです。いずれもHolderが攻撃者、Verifierが被害者です。

- **中間者攻撃**: Holderが他のHolderのVPを窃取し、Verifierに提示。Verifierから不正に権限を得る
- **リプレイ攻撃**: Holderは正規のVPを、許可された利用回数を超えて提示。Verifierから不正な回数権限を得る
- **スプーフィング**: HolderがVPの内容を偽造してVerifierに提示。Verifierから不正に権限を得る

### 有効なクレームを組み合わせて、不正なクレームを構成する攻撃がある

"Verifiable Credentials Data Model v2.0" の9.6章で触れられています。

- クレーム1: 「計算機科学部」の「職員」
- クレーム2: 「経済学部」の「大学院生」

がともに正規に発行されたVCに含まれるクレームだったとき、Holderがこれをガチャガチャして「経済学部」の「職員」であるというクレームにまとめあげ、VPにしてVerifierに提示することがあり得る。

Issuerはクレームのまとまり・単位に気をつける必要がありますね。

### HolderがIssuerのプライバシーを侵害する攻撃もある

"SoK: Trusting Self-Sovereign Identity" の3章で触れられています。

例えば、以下のシチュエーションを考えます。

- Holder: 大学から推薦を受けて企業に入りたい学生
- Issuer: 大学
- Verifier: 企業

IssuerとしてはHolder本人に推薦文を見せたくないケースがあるでしょう。しかし、VCに記載された推薦文の機密性がうまく守られていないと、VerifierだけでなくHolderも推薦文を見れてしまうかもしれません。
ユースケースによってはこういうことも考慮しないといけないのは面白いと感じました。

## W3C - "Verifiable Credentials Data Model v2.0" ドラフトの "9. Security Considerations" を読む

[https://www.w3.org/TR/vc-data-model-2.0/#security-considerations](https://www.w3.org/TR/vc-data-model-2.0/#security-considerations) （9章）を読みます。

ほとんどが素直な和訳を箇条書きにしたものですが、意訳・省略した箇所があります。適宜原文に当たってください。

サブセクションに入る前の冒頭では、以下のことが述べられています。

- VCDM v2.0を扱う**Issuer, Holder, Verifierの全て**が気をつけないと脆弱性に繋がる
- できる限り広くセキュリティ考慮事項を取り上げているが、完全なリストではない
  - ミッションクリティカルなシステムでは別途セキュリティと暗号の専門家のアドバイスを受けるべき

### 9.1 Cryptography Suites and Libraries

- VC (Verifiable Credentials) や VP (Verifiable Presentations) には、暗号で保護される部分がある
- 暗号システムの実装や監査には十分な経験が必要であり、レッドチームはセキュリティレビューの助けになる
- 暗号スイートやライブラリは危殆化するので、簡易かつプロアクティブに切り替えられる仕組みを有する必要がある
- 既存のVCを失効・置換えする仕組みも必要
- 定常的なモニタリングが重要

### 9.2 Key Management

- VC, VPの電子署名のセキュリティは、秘密鍵（署名鍵）の品質と保護に依存する
  - このテーマについては [NIST-SP-800-57-Part-1](https://doi.org/10.6028/NIST.SP.800-57pt1r5) を参照すべし
- [FIPS-186-5](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.186-5.pdf) や [NIST-SP-800-57-Part-1](https://doi.org/10.6028/NIST.SP.800-57pt1r5) で強く推奨されているように、秘密鍵（署名鍵）は単一の目的で使用せねばならない
  - NG例: 署名鍵を署名だけでなく暗号化にも使ってしまう
- NIST-SP-800-57-Part-1 では、秘密鍵（署名鍵）と公開鍵（検証鍵）の**暗号期間 (cryptoperiods)** を限定することを強く勧告している
  - 暗号期間: 特定の鍵が正当なエンティティによる使用を許可される期間、または特定のシステムの鍵が有効であり続ける期間
- NIST-SP-800-57-Part-1 は、鍵タイプ別の暗号期間についてガイダンスを示している
  - 署名鍵の暗号期間は1～3年を推奨している
- NIST-SP-800-57-Part-1 は、秘密鍵の危殆化の対処として、保護措置・危害の軽減・執行に関する推奨事項を示している
  - 秘密鍵だけでなく、その他全ての検証資料 (verification material) について、使用前にその有効性を確認することが強く推奨されている

### 9.3 Content Integrity Protection

- VCには外部リソースへのURLが含まれることが多い
  - 画像・JSON-LD拡張コンテキスト・JSONスキーマ・その他の機械可読データ
- 外部リソースはVCのsecuring mechanismの外にあるので、デフォルトでは改ざんから保護されない
- "[5.3 Integrity of Related Resources](https://www.w3.org/TR/vc-data-model-2.0/#integrity-of-related-resources)" において、外部リソースの完全性を保護する仕組みを提示している
  - （訳注: 外部リソースのハッシュダイジェストを `relatedResource` プロパティとしてIssuerがVCに含めるのが要旨）
  - 全ての外部リソースについて保護する必要はないが、変更されたらセキュリティ問題が発生する可能性がある外部リソースを保護することは強く推奨される

### 9.4 Unsigned Claims

- VCDM v2.0仕様では、署名・証明 (proof) によって保護されないクレデンシャルがあり得る
  - 中間データや、Webフォームに記入した自己主張情報に有用であることが多い
  - 保護されないクレデンシャルは検証可能ではないことに注意

### 9.5 Man-in-the-Middle (MITM), Replay, and Cloning Attacks

このサブセクションでは3種の攻撃例を取り上げています。いずれもVerifierが被害者になるケースです。

- VCDMは、中間者攻撃・リプレイ攻撃・スプーフィングを防止しない
  - オンライン・オフラインどちらでのVC利用においても、送信中・保存中において、傍受・改ざん・リプレイ・複製などの攻撃を受けやすい

#### 9.5.1 Man-in-the-Middle (MITM) Attack

- Verifierは、自身が中間者攻撃の標的ではなく、意図通りのVP受領者であることを保証する必要があるかもしれない
  - （訳注: Holder-Verifier間の通信を傍受する攻撃者を想定している。攻撃者は、HolderからVPを奪い取り、それを所望のVerifierに提示することで、何らかの権限を得ることを目的とするのだろう）
  - VC-JOSE-COSE や VC-DATA-INTEGRITY といったsecuring mechanismには、意図されたVP受領者を指定するオプションがあり、リスク低減に役立つ
- その他のアプローチとしては、 [RFC8471](https://www.w3.org/TR/vc-data-model-2.0/#bib-rfc8471) のトークンバインディングがある
  - （訳注: VerifierがHolderにVP提示を要求し受領する一連のセッションにおいて、Holderがセッション固有のキーペア（署名鍵・検証鍵）を生成。Holderは検証鍵をセッションに紐づける。Holderはまた、VPを署名鍵で署名し、Verifierに提示。Verifierはセッションに紐づいた検証鍵で検証する。VP提示を要求されたエンティティと実際にVPを提示したエンティティの一致を担保する仕組み）
- このような保護を行わないプロトコルは中間者攻撃に脆弱である

### 9.5.2 Replay Attack

- VerifierはVPの利用回数を制限したい場合がある
  - 例: イベントチケットをVCで表現する場合。同一チケットを複数人で使い回されるのを防ぎたい
- リプレイ攻撃を防ぐため、VPにnonceを含めたり、有効期限を含めることができる

### 9.5.3 Spoofing Attack

- VCDMはデータ構造と各要素の概要を示しているが、提示されたクレデンシャル（クレームの集合）が真に認可されたものであるか確認する術は示していない
  - （訳注: 攻撃者がVC, VPを偽造することができるというのを暗に言っている）
- この懸念に対処するために、VCを強力な認証手段と紐づけたり、VPに proof of control となる追加のプロパティを設定することが必要かもしれない
  - （訳注: proof of controlとは、Issuerが示したクレームが完全性を保ってVerifierに届いていることの証明、だと思われる（自信なし））

### 9.6 Bundling Dependent Claims

（訳注: この章は文意がだいぶ曖昧に感じたので、多分に意訳が含まれます）

- Issuerは情報（クレーム）をatomize（原子化、ひとまとめにすること）がベストプラクティスとされている
- Issuerによる情報の原子化がセキュアに行われなかった場合、ホルダーは異なるクレームをIssuerの意図しない形でまとめあげるかもしれない
  - 事例: ある大学がIssuerとなり、Holderに対して以下の2種類のクレームを発行する
    - クレーム1: 「計算機科学部」の「職員」
    - クレーム2: 「経済学部」の「大学院生」
  - 事例(続き): 上記のクレームが鍵括弧単位で原子化されていた場合、Holderはクレームを組み替えて「経済学部」の「職員」であるという別のクレームを作り上げて、Verifierに送付することができるかもしれない

### 9.7 Highly Dynamic Information

- 非常に動的な情報に対してVCが発行される場合、有効期間が適切に設定されている必要がある
  - （訳注: 難解な技能試験の点数などが想定されそう）
  - 長過ぎる有効期間はVCの悪用に繋がる
- 逆に短すぎる有効期間は、HolderおよびVerifierに負担をかける
- ユースケースとVCに含まれるクレームに応じた、適切な有効期間の設定が重要

### 9.8 Device Theft and Impersonation

- VCがデバイスに保存されている場合、そのデバイスが紛失・盗難された場合、攻撃者はVCを悪用してシステムにアクセスできる可能性がある
- 軽減策には以下のようなものがある:
  - PIN, パターン, バイオメトリクス画面によるロック解除で**デバイス**を保護する
  - パスワード, 生体認証, MFAで**クレデンシャルリポジトリ**を保護する
  - パスワード, 生体認証, MFAで**暗号鍵へのアクセス**を保護する
  - ハードウェアベースの署名デバイスを使用する
    - （訳注: YubiKeyとかかな？）
  - 上記の全て、または一部の組み合わせ
- VCに関する信頼とセキュリティレベルを高めるためには、なりすましの防止だけではなく、否認防止メカニズムも必要
  - エンティティの行動・トランザクションに対する責任を明確にし、説明責任を強化し、悪意ある行動を抑止するため
  - 否認防止には多面的なアプローチが必要
    - Securing mechanism
    - 所有証明
    - 認証スキーム

### 9.9 Acceptable Use

- エンティティの目的と、それに対する行動（VPの提示など）が整合していることを担保することが重要
- これが破られるケースとして、認可なき使用（Unauthorized Use）と不適切な使用（Inappropriate Use）が挙げられる

#### 9.9.1 Unauthorized Use

- VC, VPを、意図された用途以外で使用することは、認可なき使用と見なされる可能性がある
- 一例は機密性の侵害:
  - Holderが年齢と在留資格を証明するためにVPをVerifierに共有した際、Verifierが同意を得ずにデータブローカーにデータを売却
- 緩和策として、Issuerは `termsOfUse` プロパティにより、クレデンシャルをいつどのように使用するかを規定できる

#### 9.9.2 Inappropriate Use

- 有効なデジタル署名とステータスチェックにより、クレデンシャル自体の信頼性は担保されるが、クレデンシャルの示す情報があらゆるコンテキストで有効であるとは限らない
- Verifierは、関連し得るクレームが示す特権やサービスだけでなく、クレームの出所を検証することが極めて重要:
  - （訳注: Issuerの素性や、クレデンシャルサブジェクト（≒Holder）との関係性が重要かと思います）
  - 例: 認証を受けた機関による医療診断が必要なシナリオでは、完備な診断情報を含んではいるが、自己主張のクレデンシャルであっては不十分

### 9.10 Code Injection

- VC内のデータに、実行可能コードやスクリプトが含まれる可能性がある
  - Issuerは、必要性があってかつリスクができる限り軽減されている場合を除いて、そのよなことは避けることが推奨される
- 例: 自然言語を多言語で含めたい場合にHTMLを使いたくなるかもしれないが、HTMLパーサーで実行されると `<script>` タグが実行される恐れもある

## W3C - "Verifiable Credentials Data Model v1.1" 勧告の "8. Security Considerations" との差分

[VCDM v1.1勧告の8章](https://www.w3.org/TR/vc-data-model/#security-considerations) を、上述のVCDM v2.0ドラフト9章と比較しました。

基本的には、VCDM v2.0のほうがVCDM v1.1時代に書かれたものを全て包含しており、かつ加筆されています。加筆されたサブセクションは以下です。いずれもデータモデル自体の差から来るものではなく、知見が溜まったので加筆されたものと考えられます。

- Key Management
- Man-in-the-Middle (MITM), Replay, and Cloning Attacks
- Acceptable Use
- Code Injection

ただし、"Content Integrity Protection" のサブセクションだけは、VCDM v1.1時代のもののほうが実例を含んでいました。

<img src="/img/2024/08-16/image.png" alt="https://www.w3.org/TR/vc-data-model/#example-content-integrity-protection-for-links-to-external-data" width="600px" height="auto">

[実例が削除されたcommit](https://github.com/w3c/vc-data-model/commit/8c0775e150757a14577e915d430a9f002b31983f)によると、VCDM v2.0に合わせて記述を新しくしたようです。外部リソースへのURL自体にハッシュダイジェストを含めるのではなく、 `relatedResource` を使うようになったということが肝だと思います。

## "SoK: Trusting Self-Sovereign Identity" の脅威想定部分を読む

Krul, Evan & Paik, Hye-young & Ruj, Sushmita & Kanhere, Salil. (2024). SoK: Trusting Self-Sovereign Identity. Proceedings on Privacy Enhancing Technologies. 2024. 297-313. 10.56553/popets-2024-0079. ([PDF](https://petsymposium.org/popets/2024/popets-2024-0079.pdf))

---

SSI (Self-Sovereign Identity) の信頼に関し分析し、今後の研究の基礎としようと試みた論文です。

この記事ではVCのセキュリティ考慮事項をまとめる目的で、論文から以下をピックアップします。

- **メインテーマ**: VC, VPの発行・保存・提示・検証における脅威シナリオ (2, 3章)
- おまけ: 想定する脅威シナリオで分類される信頼モデル (4章)

なお、論文ではSSIらしい用語定義をしていますが、この記事では以下のように読み替えて説明します。

- Identity Owner → Holder
- Service Provider → Verifier

<img src="/img/2024/08-16/image%201.png" alt="SSIの用語でのVC, VPのライフサイクル" width="550px" height="auto">

### 脅威シナリオ列挙

| ID | 誰にとっての脅威か | 何に対する脅威か | 脅威の内容 |
| --- | --- | --- | --- |
| 2.1 | 明示されず<br>（訳注: Verifierと想定） | Holder識別 | HolderがVerifierに、検証不可なクレデンシャルを送付する<br>（例: 運転資格がないのに運転免許を偽装して送付） |
| 2.2 | 明示されず<br>（訳注: 主にVerifier, 次点でHolderと想定） | Issuer識別 | Issuerが権限を超えたVCを発行する<br>（例: 州の運転免許発行権限しかないのに国際免許を発行） |
| 2.3 | 明示されず<br>（訳注: Verifierと想定） | 譲渡不可 | 他のHolder向けに発行されたVCを、他のHolderと共謀して共有したり、窃取したりして、Verifierに提示する |
| 2.4 | 明示されず<br>（訳注: Issuer, Holder, Verifierと想定） | 保護された通信 | 通信路のVC, VPに受動的（盗聴）または能動的（改ざん）に介入 |
| 2.5 | 明示されず<br>（訳注: Holder, Verifierと想定） | 保護された通信 | DID解決へ介入し、偽のDID Documentを参照させる |
| 3.1 | Issuer | アイデンティティ登録 | Holderが偽の情報を用いてIssuerにアイデンティティ登録する |
| 3.2 | Issuer | 機密クレーム発行 | Holderが、閲覧権限のないクレームを閲覧・収集することで、Issuerのプライバシーを侵害する<br>（例: Issuerが推薦人、Verifierが推薦を要求する機関。Holderは推薦クレームの記載事項を閲覧する権限がない） |
| 3.3 | Holder | 選択的開示 | Verifierが（悪意の有無にかかわらず）目的にとって不要なクレームを収集する |
| 3.4 | Holder | 非連結性 (Unlinkability) | Verifierが、複数回のクレデンシャル要求や、別のVerifierとの共謀により特定のHolderに関するクレデンシャルを収集し、連結した情報を得る |
| 3.5 | Holder | 暗号鍵・ウォレット管理 | ウォレットからVCや暗号鍵を窃取。またはHolder自身が暗号鍵を喪失<br>（訳注: 機種変更などは典型） |
| 3.6 | Holder | 暗号鍵・ウォレット管理 | ウォレットの不適切な管理によるVC, 暗号鍵の漏洩や、なりすまし |
| 3.7 | Verifier | クレデンシャル有効性（失効） | クレームで主張されている権利が既に失われているのに、クレデンシャルを提示 |
| 3.8 | Verifier | Holder識別 | 信頼できるIssuerから発行されたVCではなく、自分で発行したVCを提示 |
| 3.9 | Verifier | Holder識別 | Holderに例外的な事象が発生した際に、自身の権限を他のHolderに移譲する必要があり得る（それができないことが脅威）<br>（訳注: 事故等で意識不明になった際に家族に移譲） |
| 3.10 | Verifier | 信用 (Recourse) | 正当に発行されたVCであっても、Holderに認可を与えてよいか必ずしもわからない<br>（例: 運転免許証があっても安全運転をする保証はない） |
| 3.11 | Verifier | オフライン検証 | HolderとVerifierがネットワークで繋がっておらず、オフラインで検証する必要がある（それができないことが脅威） |

### 信頼モデル

下記3種類の信頼モデルが提示されます。

1. Trustful
    - 信頼の想定
        - Issuerは信頼できる
        - Verifierは信頼できる
    - ユースケース
        - 機密データの取り扱いには不適切
2. Intermediate Trust
    - 信頼の想定
        - （訳注: 明示的に記載されていないが、Issuerは信頼できる想定と思われる）
        - Verifierは信頼できない
    - ユースケース
        - 機密データを扱える
        - 例えば、政府がIssuerになるようなアイデンティティシステム
3. Zero-Trust
    - 信頼の想定
        - 信頼できるIssuerは存在しない
            - （訳注: 各Holder、というかSSIの用語で言うIdentity Ownerが自らのクレデンシャルを発行する世界）
        - （訳注: 明示的に記載されていないが、Verifierも信頼できない想定と思われる）
        - PKI (Public Key Infrastructure) も使えない
        - オプショナルだが、VDR (Verifiable Data Registry) をトラストアンカーとして使えることがある

各信頼モデルが想定する（あるいはしない）脅威をマークしたのが下記の表3です。

<img src="/img/2024/08-16/image%202.png" alt="信頼モデル" width="800px" height="auto">

例えば以下のようなことが読み取れます。

- 全てのモデルで想定しなければならない脅威（何に対する脅威か）
  - 2.1: Holder識別（HolderによるVC偽装）
  - 2.3: 譲渡不可
  - 2.4, 2.5: 保護された通信
- 全てのモデルが、optional extensionなレベルでしか想定しない脅威（何に対する脅威か）
  - 3.9: Holder識別（権限の移譲が必要な例外事象）
  - 3.11: オフライン検証
- Trustfulモデルのみが、optional extensionなレベルでしか想定しない脅威（何に対する脅威か）
  - 3.10: 信用 (Recourse)
  - 3.3: 選択的開示
  - 3.4: 非連結製 (Unlinkability)
  - 3.5, 3.6: 暗号鍵・ウォレット管理
- Intermediate Trustモデルからは考慮すべき (likely) または考慮必須 (required) になる脅威（何に対する脅威か）
  - 考慮すべき
    - 3.10: 信用 (Recourse)
    - 3.5, 3.6: 暗号鍵・ウォレット管理
  - 考慮必須
    - 3.3: 選択的開示
    - 非連結性 (Unlinkability)
- Zero-Trustでは想定してはならない脅威（何に対する脅威か）
  - 2.2: Issuer識別
    - （訳注: Issuer、すなわち各Identity Ownerがどのような権限を持つか、想定ができないということと思われる）
  - 3.1: アイデンティティ登録
    - （訳注: 信頼できる機関としてのIssuerが存在しない世界なので、登録先がないということと思われる）

## DEFCON 31 (2023年8月), Crypto & Privacy Villageの "Attacking Decentralized Identity" を読む

[slideshare](https://www.slideshare.net/slideshow/attacking-decentralized-identitypdf/259803268)

---

タイトルや発表された場所から、具体的な攻撃事例が見れるかと思ったのですが、もう少しライトに「こんな脆弱性があるから」「こんな攻撃（あるいは嫌な思い）が発生しそう」くらいなことを説明したものでした。

長くなってきた（疲れた）ので、リンクの紹介に留めます。
