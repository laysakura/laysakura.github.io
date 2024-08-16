---
title: W3C Verifiable Credentials API v0.3 (Draft) を読む
id: vc-api-v0.3
tags:
  - 認証技術
  - Verifiable Credentials
date: 2024-07-19 15:43:05
---

<img src="/img/2024/07-19/Untitled%204.png" alt="VC-APIのコンポーネントとエンドポイント" width="auto" height="auto">

DID/VCの周辺技術を調べています。DID/VCの概要を知りたい方は [デジタルアイデンティティウォレットとは？｜注目される背景とサービス化の論点 | NRIセキュア ブログ](https://www.nri-secure.co.jp/blog/digital-identity-wallet) などご参照ください。

今回は、Verifiable Credential API (VC-API) として知られる、VCのライフサイクルを管理するHTTP APIの仕様書を読んでいきます。

<https://w3c-ccg.github.io/vc-api/>

この記事は2024/07/16更新バージョンを対象に執筆しています。まだまだ正式仕様でないので、最新の仕様も合わせて各自ご確認お願いします。

富士榮さんのブログ『IdM実験室』の [W3C Verifiable Credentials Overviewを読む シリーズ](https://idmlab.eidentity.jp/2024/06/w3c-verifiable-credentials-overview.html) を以前大いに参考にさせていただいたので、その形式（英文→DeepL和訳→たまに解説文）で記載します。

<!-- more -->

## 目次
<!-- toc -->

## Abstract (概要)

> Verifiable credentials provide a mechanism to express credentials on the Web in a way that is cryptographically secure, privacy respecting, and machine-verifiable. This specification provides data model and HTTP protocols to issue, verify, present, and manage data used in such an ecosystem.
>

> 検証可能なクレデンシャルは、暗号的に安全で、プライバシーを尊重し、機械が検証可能な方法で Web 上でクレデンシャルを表現するメカニズムを提供する。 この仕様は、このようなエコシステムで使用されるデータを発行、検証、提示、管理するためのデータモデルと HTTP プロトコルを提供する。
>

概要で示されている通り、HTTP APIの説明だけではなくデータモデルの説明も含む文書です。それだけではなく、Issuer-Holder-Verifierの役割を実現するためのソフトウェアコンポーネント・アーキテクチャの話もだいぶ出てきます。

分からない用語や概念があったら [VCDM (Verifiable Credentials Data Model) v2.0 の仕様](https://www.w3.org/TR/vc-data-model-2.0/)も参照しましょう。

## Status of This Document (この文書の状況)

省略しますが、

- まだW3C標準になっていない
- 実験的であり高頻度に変化する
- この文書を参考に、実験用途以外のシステムを実装することは推奨されない

と言ったことが書かれています。

## 1. Introduction (導入)

> *This section is non-normative.*
>

> このセクションはノン・ノルマである。
>

和訳が変ですが、「このセクションの記載事項は仕様準拠と無関係」ということですね。この表現はW3Cドキュメントで頻出です。

---

> The Verifiable Credentials specification [[VC-DATA-MODEL-2.0](https://w3c-ccg.github.io/vc-api/#bib-vc-data-model-2.0)] provides a data model and serialization to express digital credentials in a way that is cryptographically secure, privacy respecting, and machine-verifiable. This specification provides a set of HTTP Application Programming Interfaces (HTTP APIs) and protocols for issuing, verifying, presenting, and managing Verifiable Credentials.
>

> 検証可能クレデンシャル仕様 [VC-DATA-MODEL-2.0]は、暗号的に安全で、プライバシーを尊重し、機械が検証可能な 方法でデジタル・クレデンシャルを表現するデータ・モデルとシリアライゼーションを提供する。 この仕様は、検証可能クレデンシャルの発行、検証、提示、および管理のための一連の HTTP アプリケーション・プログラミング・インタフェース（HTTP API）とプロトコルを提供する。
>

概要とほぼ同じことを言っていますね。

---

続く段落群は解釈が難しかったです。

> When managing [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential), there are two general types of APIs that are contemplated. The first type of APIs are designed to be used within a single security domain. The second type of APIs can be used to communicate across different security domains. This specification defines both types of APIs.
>

> 検証可能クレデンシャルを管理する場合、2 つの一般的なタイプの API を想定している。 最初のタイプの API は、**単一のセキュリティ・ドメイン内**で使用するように設計されている。 2つ目のタイプのAPIは、**異なるセキュリティ・ドメイン間**で通信するために使用できる。 この仕様では、両方のタイプのAPIを定義している。
>

> The APIs that are designed to be used within a single security domain are used by systems that are operating on behalf of a single role such as an Issuer, Verifier, or Holder. One benefit of these APIs for the Verifiable Credentials ecosystem is that they define a useful, common, and vetted modular architecture for managing Verifiable Credentials. For example, this approach helps software architects integrate with common components and speak a common language when implementing systems that issue [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential). Knowing that a particular architecture has been vetted is also beneficial for architects that do not specialize in [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential). Documented architectures and APIs increase market competition and reduce vendor lock-in and switching costs.
>

> **単一のセキュリティドメイン内**で使用するように設計された API は、発行者、検証者、保有者 などの単一の役割の代理として動作するシステムによって使用される。 これらの API が検証可能クレデンシャル・エコシステムにもたらす利点の 1 つは、検証可能 クレデンシャルを管理するための有用で共通の検証済みモジュールアーキテクチャを定義していることであ る。 例えば、このアプローチは、ソフトウェア・アーキテクトが検証可能クレデンシャルを発行するシス テムを実装する際に、共通のコンポーネントと統合し、共通の言語を使用するのに役立つ。 特定のアーキテクチャが検証済みであることを知ることは、検証可能なクレデンシャルを専門としないアーキテクトにとっても有益である。 文書化されたアーキテクチャとAPIは市場競争を激化させ、ベンダーのロックインとスイッチングコストを削減する。
>

> The APIs that are designed to operate across multiple security domains are used by systems that are communicating between two different roles in a [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) interaction, such as an API that is used to communicate presentations between a Holder and a Verifier. In order to achieve protocol interoperability in [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) interactions, it is vital that these APIs be standardized. The additional benefits of documenting these APIs are the same for documenting the single-security-domain APIs: common, vetted architecture and APIs, increased market competition, and reduced vendor lock-in and switching costs.
>

> **複数のセキュリティ・ドメインにわたって**動作するように設計された API は、検証可能なクレデンシャ ル相互作用における 2 つの異なる役割間で通信するシステム、たとえば保有者と検証者の間でプレゼンテー ションを通信するために使用される API などによって使用される。 検証可能なクレデンシャルの相互作用でプロトコルの相互運用性を実現するには、これらの API を標準化することが不可欠である。 これらのAPIを文書化することの付加的な利点は、単一セキュリティ・ドメインのAPIを文書化することと同じである。すなわち、共通の、吟味されたアーキテクチャとAPI、市場競争の増大、ベンダーのロックインと切り替えコストの削減である。
>

ここでいうセキュリティ・ドメインは、自組織内のNWかその外か、くらいに捉えました。

VC-APIはHTTP APIなので、基本的には異なるセキュリティ・ドメインをまたいで呼び出すのがメインの使い方かと思います。

「単一のセキュリティドメイン内で…」から始まる段落では、VC-APIの仕様を共通言語としてソフトウェア開発できるのも大事だよね。VC-APIのインターフェイスを守っている限りは裏側は切り替えて使えるよね。みたいなことを言っているのだと解釈しました。

---

> This specification contains the following sections that software architects and implementers might find useful:
>
> - [1.1 Design Goals and Rationale](https://w3c-ccg.github.io/vc-api/#design-goals-and-rationale) specifies the high level design goals that drove the formulation of this specification.
> - [1.2 Architecture Overview](https://w3c-ccg.github.io/vc-api/#architecture-overview) highlights the different roles and components that are contemplated by the architecture.
> - [2. Terminology](https://w3c-ccg.github.io/vc-api/#terminology) defines specific terms that are used throughout the document.
> - [3.2 Authorization](https://w3c-ccg.github.io/vc-api/#authorization) elaborates upon the various forms of authorization that can be used with the API.
> - [3.7 Issuing](https://w3c-ccg.github.io/vc-api/#issuing) describes the APIs for issuing [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) as well as updating their status.
> - [3.8 Verifying](https://w3c-ccg.github.io/vc-api/#verifying) specifies the APIs for verifying both [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) and verifiable presentations.
> - [3.10 Presenting](https://w3c-ccg.github.io/vc-api/#presenting) defines APIs for generating and deriving [verifiable presentations](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-presentation) within a trust domain, as well as exchanging [verifiable presentations](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-presentation) across trust domains.
> - Finally, Appendix [A. Privacy Considerations](https://w3c-ccg.github.io/vc-api/#privacy-considerations), and [B. Security Considerations](https://w3c-ccg.github.io/vc-api/#security-considerations) are provided to highlight factors that implementers might consider when building systems that utilize the APIs defined by this specification.

> この仕様書には、ソフトウェア・アーキテクトや実装者が役に立つと思われる以下のセクションが含まれている：
>
> - 1.1 設計目標と根拠 本仕様策定の原動力となった高レベルの設計目標を規定する。
> - 1.2 アーキテクチャ概要 アーキテクチャによって想定されるさまざまな役割とコンポーネントを明らかにする。
> - 2. 用語定義 本文書を通じて使用される特定の用語を定義する。
> - 3.2 認可 APIで使用できる様々な形式の認可について詳しく説明する。
> - 3.7 発行 検証可能なクレデンシャルを発行し、そのステータスを更新するための API について記述する。
> - 3.8 検証 検証可能なクレデンシャルと検証可能なプレゼンテーションの両方を検証するための API を規定する。
> - 3.10 提示 は、トラストドメイン内で検証可能な提示を生成・導出するための API、およびトラストドメイン間で検証可能な提示を交換するための API を定義する。
> - 最後に、「付録A. プライバシーに関する考慮事項」と「付録B. セキュリティに関する考慮事項」は、この仕様で定義されたAPIを利用するシステムを構築する際に、実装者が考慮すべき要素を強調するために提供される。

### 1.1 Design Goals and Rationale (設計目標と根拠)

> *This section is non-normative.*
>

> このセクションはノン・ノルマである。
>

---

> The Verifiable Credentials API is optimized towards the following design goals:
>
>
>
> | Goal | Description |
> | --- | --- |
> | Modularity | Implementers need only implement the APIs that are required for their use case enabling modularity between Issuing, Verifying, and Presenting. |
> | Simplicity | The number of APIs and optionality are kept to a minimum to ensure that they are easy to implement and audit from a security standpoint. |
> | Composability | The APIs are designed to be composable such that complex flows are possible using a small number of simple API primitives. |
> | Extensibility | Extensions to API endpoints are expected and catered to in the API design enabling experimentation and the addition of value-added services on top of the base API platform. |

> Verifiable Credentials API は、以下の設計目標に向けて最適化されている：
>
>
>
> | 目標 | 説明 |
> | --- | --- |
> | モジュール性 | 実装者は、そのユースケースに必要なAPIのみを実装すればよく、発行、検証、提示の間のモジュール化を可能にする。 |
> | シンプルさ | APIの数とオプションは、セキュリティの観点から実装と監査が容易であることを保証するために最小限に抑えられている。 |
> | コンポーザビリティ | APIは、少数のシンプルなAPIプリミティブで複雑なフローが可能になるよう、コンポーザブルに設計されている。 |
> | 拡張性 | APIエンドポイントの拡張は、API設計において期待されており、実験や、基本APIプラットフォームの上に付加価値サービスを追加することを可能にする。 |

今どきっぽい思想ですね。

モジュール性により、この仕様に記載されている全てのAPIを実装する必要はないこと、
拡張性により、この仕様に記載されていないAPIや機能を実装しても良いことが示されています。

### 1.2 Architecture Overview (アーキテクチャ概要)

> *This section is non-normative.*
>

> このセクションはノン・ノルマである。
>

---

> The Verifiable Credentials Data Model defines three fundamental roles, the Issuer, the Verifier, and the Holder.
>

> 検証可能クレデンシャル・データ・モデルは、発行者、検証者、保有者の 3 つの基本的な役割を定義する。
>

<img src="/img/2024/07-19/Untitled.png" alt="図1 検証可能クレデンシャル・データ・モデル仕様で定義される役割" width="400px" height="auto">


<center><b>Figure 1</b> The roles defined by the Verifiable Credentials Data Model specification.<br>
<b>図1</b> 検証可能クレデンシャル・データ・モデル仕様で定義される役割。</center>

IHVモデルですね。

---

> Actors fulfilling each of these roles may use a number of software or service components to realize the VC API for exchanging Verifiable Credentials.
>

> これらの各役割を果たすアクタは、検証可能クレデンシャルを交換するための VC API を実現するために、 多数のソフトウェアまたはサービスコンポーネントを使用することができる。
>

> Each role associates with a role-specific Coordinator, Service, and Admin as well as their own dedicated Storage Service. In addition, the Issuer may also manage a Status Service for revocable credentials issued by the Issuer.
>

> 各役割は、役割固有の Coordinator、Service、Admin、および専用の Storage Service と関連付けられる。 さらに発行者は、発行者が発行した取り消し可能なクレデンシャルのステータスサービスを管理することもできる。
>

![図2 VC APIコンポーネント。 矢印はフローの開始を示す。](/img/2024/07-19/Untitled%201.png)

<center><b>Figure 2</b> VC API Components. Arrows indicate initiation of flows.<br>
<b>図2</b> VC APIコンポーネント。 矢印はフローの開始を示す。</center>

何やらすごい絵が出てきました。この絵の解釈には苦労したので、ここで一通り理解を述べておきます。

まず、中央の "Any Authorized Party" とその周辺の "Workflow Service" は多分に付加的なアクター・コンポーネントと思われます。ひとまず無視して考えましょう。

![図2より筆者作成](/img/2024/07-19/Untitled%202.png)

<center>図2より筆者作成</center>

Issuer, Holder, Verifierともに、基本的には対称に、

- アクター（人型のやつ）
- Admin
- Service
- Storage Service
- Coordinator

から成ります。

Issuerだけには "Status Service" がありますが、これは [Bitstring Status List](https://www.w3.org/TR/vc-overview/#s_bsl) などにより実現される、Issuerが発行したVCのステータス（まだ有効か、それとも無効化されたか）を確認するためのサービスです。

Issuer, Holder, Verifier間のインタラクションは、（前述のStatus ServiceとVerifier Serviceの間のステータス確認を除き、）Holder Coordinator (ウォレット相当) を中心として、Coordinator同士で行われます。**Coordinatorはフロントエンド**と考えるとしっくりきます。

次に重要なのがServiceです。**Serviceがこの仕様で記載されたHTTP APIを実装**するものです。

**Admin**はアクターが**設定**するためのもの（管理画面や設定ファイル）で、**Storage Serviceは永続化層**です。

---

ここまでの理解が大事かと思いますが、先程無視した "Any Authorized Party" とその周辺の "Workflow Service" も見てみましょう。

説明のための例として、

- Issuer: 大学
- Holder: 自身の学位を証明したい卒業生
- Verifier: Holderが入社したい企業

のシナリオを考えます。

「大学がイケてるIssuer Coordinatorをインターネットに（少なくとも卒業生に）公開しており、かつ卒業生が自分でウォレットアプリを入手して学位証明のVCを受取り、更にそれをVPにして企業のVerifier Coordinatorに提示する…」 といったことが一気通貫でできれば良いのですが、そうでない場合もありそうですね。

**Any Authorized Partyは**Issuer, Holder, Verifierの間に立って、**代理人的にVCの発行〜検証までを支援**するものと考えられます。

今回は「Any Authorized Party = 大学の学生支援課」と考えてみます。学生支援課は以下の業務（ワークフロー）を実施します。

1. 卒業生（Holder）のために、大学（Issuer Coordinator）からVCを代理で発行してもらう
    - 前提: 大学は、学生支援課からのアクセスに限定したIssuer Coordinatorを提供している
2. 卒業生に指定のウォレットアプリ（Holder Coordinator）をインストールしてもらう
3. VCをウォレットアプリで受け取らせる
4. 卒業生に「どこまでのクレームを開示するか」を調整してもらい、ウォレットアプリからVPを発行してもらう
5. VPを企業（Verifier Coordinator）に提供
    - 前提: 企業は、この大学の学生支援課からのアクセスを許可したVerifier Coordinatorを提供している

この業務を支援するため、各Coordinatorの更に前段に置かれ、学生支援課のような **Any Authorized Party が各々の必要に応じたワークフローの実行を要求できる対象が Workflow Service** だと考えられます。

---

解説が長くなりましたが次に行きます。

> Any given VC API implementation may choose to combine any or all of these components into a single functional application. The boundaries and interfaces between these components are defined in this specification to ensure interoperability and substitutability across the Verifiable Credential conformant ecosystem.
>

> 任意の VC API 実装は、**これらのコンポーネントのいずれかまたはすべて**を単一の機能アプリケーションに 組み合わせることができる。 これらのコンポーネント間の境界とインタフェースは、Verifiable Credential に準拠するエコシステム全体で の相互運用性と代替性を確保するために、本仕様で定義されている。
>

「1.1 設計目標と根拠」のモジュール性の項目では、この仕様のAPIを全て実装する必要がないことが述べられていました。ここではコンポーネントの単位でも全てを実装する必要がないことが述べられています。

また、図2のコンポーネントはVCのエコシステム全体から参照されるようなものであることも述べられています。そんな大事なものならVC-APIの仕様書よりもうちょっと抽象度の高いところで定義すべき気はしてしまいます。

---

> In addition to aggregating components into a single app, implementers may choose to operationalize any given role over any number active instances of deployed software. For example, a browser-based Holder Coordinator should be considered as an amalgam of a web browser, various code running in that browser, one or more web servers (in the case of cross-origin AJAX or remote embedded content), and the code running on that server. Each of those elements runs as different software packages in different configurations, each executing just part of the overall functionality of the component. For the sake of the VC API, each component satisfies all of its required functionality as a whole, regardless of deployment architecture.
>
>
> We define these components as follows:
>

> 実装者は、コンポーネントを単一のアプリに集約するだけでなく、配備されたソ フトウェアのアクティブなインスタンスの数だけ、任意の役割を運用することもできます。 たとえば、ブラウザベースの Holder Coordinator は、Web ブラウザ、そのブラウザで実行されるさまざまなコード、1 つまたは複数の Web サーバー（クロスオリジン AJAX またはリモート埋め込みコンテンツの場合）、およびそのサーバーで実行されるコードの集合体と考える必要があります。 これらの要素はそれぞれ異なる構成で異なるソフトウェアパッケージとして実行され、それぞれがコンポーネントの全体的な機能の一部だけを実行します。 VC API の都合上、各コンポーネントは、デプロイメントのアーキテクチャに関係なく、全体として必要な機能をすべて満たしている。
これらのコンポーネントを以下のように定義する：
>

各コンポーネントを実現するソフトウェアは、複数のパッケージやインスタンスに分かれていても良いということが書かれています。それはまあそうでしょうね。

#### 1.2.1 Coordinators (コーディネーター)

以降の1.2.Xでは各コンポーネントについて説明されますが、図2の直後に解説したのでほぼ和訳のみに留めます。

> Coordinators execute the business rules and policies set by the associated role. Often this is a custom or proprietary Coordinator developed specifically for a single party acting in that role, it is the integration glue that connects the controlling party to the VC ecosystem.
>

> コーディネーターは、関連する役割によって設定されたビジネスルールとポリシーを実行します。 多くの場合、これはその役割を果たす単一の当事者専用に開発されたカスタムまたは独自のコーディネーターであり、コントロールする当事者とVCエコシステムをつなぐ統合の接着剤となる。
>

> Coordinators may or may not provide a visual user interface, depending on the implementation. Pure command-line or continuously running services may also be able to realize this component.
>

> コーディネータは、実装によって、視覚的なユーザーインターフェイスを提供する場合としない場合がある。 純粋なコマンドラインや継続的に実行されるサービスでも、このコンポーネントを実現できるかもしれない。
>

> With the exception of the Status Service, all role-to-role communication is between Coordinators acting on behalf of its particular actor to fulfill its role.
>

> ステータス・サービスを除き、すべての役割間通信は、特定のアクターに代わってその役割を 果たすコーディネーターの間で行われる。
>

> The Issuer Coordinator executes the rules about who gets what credentials, including how the parties creating or receiving those credentials are authenticated and authorized. Typically the Issuer Coordinator integrates the Issuer's back-end system with the Issuer service. This integration uses whatever technologies are Appropriate; the interfaces between the Issuer App and back-end services are out of scope for the VC-API. The Issuer Coordinator drives the Issuer service.
>

> 発行者コーディネータは、クレデンシャルを作成または受領する当事者がどのように認証および認可される かを含め、誰がどのクレデンシャルを取得するかについてのルールを実行する。 通常、発行者コーディネータは発行者のバックエンドシステムと発行者サービスを統合する。 発行者アプリとバックエンド・サービス間のインターフェイスはVC-APIの対象外です。 Issuer CoordinatorはIssuerサービスを駆動する。
>

> The Verifier Coordinator communicates with a Verifier service to first check authenticity and timeliness of a given VC or VP, then Applies the Verifier's business rules before ultimately accepting or rejecting that VC or VP. Such business rules may include evaluating the Issuer of a particular claim or simply checking a configured allow-list. The Verifier App exposes an API for submitting VCs to the Verifier per the Verifier's policies. For example, the Verifier Coordinator may only accept VCs from current users of the Verifier's other services. These rules typically require bespoke integration with the Verifier's existing back-end.
>

> 検証者コーディネータは検証者サービスと通信し、まず指定されたVCまたはVPの真正性と適時性をチェックし、次に検証者のビジネスルールを適用して、最終的にそのVCまたはVPを受諾または拒否する。 このようなビジネス・ルールには、特定のクレームの発行者を評価することや、設定された許可リストをチェックすることなどが含まれる。 検証者アプリは、検証者のポリシーに従って検証者にVCを提出するためのAPIを公開する。 **たとえば、Verifier Coordinator は、Verifier の他のサービスの現ユーザーからの VC のみを受け付けることができる。 このようなルールには通常、検証者の既存のバックエンドとの特注の統合が必要である。**
>

このあたりを読むと、図2に出てくるコンポーネント以外にもあまりVCっぽくない（普通の）バックエンドサービスもあって、それを統合するのがCoordinatorの一つの役割であることがわかります。

> The Holder Coordinator executes the business rules for Approving the flow of credentials under the control of the Holder, from Issuers to Verifiers. In several deployments this means exposing a user interface that gives individual Holders a visual way to authorize or Approve VC storage or transfer. Some functionality of the Holder Coordinator is commonly referred to as a wallet. In the VC API, the Holder Coordinator initiates all flows. They request VCs from Issuers. They decide if, and when, to share those VCs with Verifiers. Within the VC API, there is no way for either the Issuer or the Verifier to initiate a VC transfer. In many scenarios, the Holder Coordinator is expected to be under the control of an individual human, ensuring a person is directly involved in the communication of VCs, even if only at the step of authorizing the transfer. However, many VCs are about organizations, not individuals. How individuals using Holder Coordinators related to organizations, and in particular, how organizational credentials are securely shared with, and presented by, (legal) agents of those organizations is not yet specified as in scope for the VC API.
>

> 保有者コーディネータは、発行者から検証者への、保有者の管理下にあるクレデンシャルのフローを 承認するためのビジネス・ルールを実行する。 いくつかの展開では、これは個々の保有者が VC の保管または転送を承認または承認する視覚的な方法を提供するユーザー・インタフェースを公開することを意味する。 **ホルダーコーディネーターの一部の機能は、一般にウォレットと呼ばれる。** **VC APIでは、ホルダー・コーディネーターがすべてのフローを開始する。** 発行者にVCを要求する。 VCを検証者と共有するかどうか、またいつ共有するかを決定する。 VC API 内では、発行者または検証者のいずれかが VC 転送を開始する方法はない。 多くのシナリオでは、ホルダー・コーディネーターは人間個人の管理下に置かれることが期待され、たとえ送金を承認する段階だけであっても、人間がVCの通信に直接関与することが保証される。 しかし、多くのVCは個人ではなく組織に関するものです。 ホルダ・コーディネータを使用する個人がどのように組織と関係するか、特に、組織のクレデンシャルがどのように組織の（法的な）代理人と安全に共有され、その代理人によって提示されるかは、VC API の対象範囲としてまだ指定されていない。
>

Holder CoordinatorがIssuer CoordinatorとVerifier Coordinatorを呼び出す主体であることが明示されていますね。（ただし、IssuerやVerifierにWorkflow ServiceがあるときにはAny Authorized Partyが主体になることもあり得ると思います。）

#### 1.2.2 Services (サービス)

> Services provide generic VC API functionality, driven by its associated App. Designed to enable infrastructure providers to offer VC capability through Software-as-a-Service. All services expose network endpoints to their authorized Coordinators, which are themselves operating on behalf of the associated role. Although deployed services *MAY* provide their own HTML interfaces, such interfaces are out of scope for the VC API. Only the network endpoints of services are defined herein.
>

> **サービスは**、関連するアプリによって駆動される汎用的な**VC API機能を提供する**。 インフラ・プロバイダーがSaaSを通じてVC機能を提供できるように設計されている。 すべてのサービスは、認可されたCoordinatorにネットワークエンドポイントを公開する。 配備されたサービスは独自のHTMLインターフェースを提供してもよい[MAY]が、 そのようなインターフェースはVC APIの対象外である。 ここでは、サービスのネットワーク・エンドポイントのみを定義する。
>

前述の通り、VC-APIを定義するのはサービスのコンポーネントです。

「SaaSを通じてVC機能を提供できるように設計されている」の表現はどちらで解釈するのが良いか計りかねています:

- Service単独でSaaSになることが想定されている（例: Issuer CoordinatorをユーザーとするIssuer Service SaaS）
  - ServiceはVC-APIを実装するだけの薄いものになる思想な気がしており、SaaSビジネスできるほどの付加価値生まないのでは？
- CoordinatorはAPI GatewayのようにServiceのエンドポイントをそのまま露出するようなものが想定されている（例: Holder CoordinatorをユーザーとするIssuer Coordinator SaaS）
  - こちらのほうがしっくりくる
  - 一方で、ゴリゴリにVC-APIを隠蔽するようなCoordinatorもこの仕様記述全体には合致していそう

> The Issuer Service takes requests to issue VCs from authorized Issuer Coordinators and returns well-formed, signed Verifiable Credentials. This service *MUST* have access to private keys (or key services which utilize private keys) in order to create the proofs for those VCs. The API between the Issuer service and its associated key service is believed to be out of scope for the VC API, but may be addressed by WebKMS or similar specifications.
>

> **発行者サービス**は、認可された発行者コーディネータから VC の発行要求を受け、整形式で署名された検証可能な クレデンシャルを返す。 このサービスは、**これらの VC のプルーフを作成するために、秘密鍵（または秘密鍵を利用する鍵サービ ス）にアクセスできなければならない。** 発行者サービスと関連する鍵サービスとの間のAPIは、VC APIの範囲外であると考えられるが、WebKMSまたは同様の仕様で対処されるかもしれない。
>

Issuer Serviceは（Securing Mechanismを使って）Proofを作成するために、秘密鍵にアクセスできる必要があると述べられていますね。何かしらのKMSと連携するのが良さそうです。WebKMSというのは初めて聞きましたが、W3C標準にはまだなっていなさそうです（[仕様](https://w3c-ccg.github.io/webkms/)）。

> The Verifier service takes requests to verify Verifiable Credentials and Verifiable Presentations and returns the result of checking their proofs and status (if present). The service only checks the authenticity and timeliness of the VC; leaving the Verifier Coordinator to finish Applying any business rules needed.
>

> ベリファイア・サービスは、検証可能クレデンシャルおよび検証可能プレゼンテーショ ンの検証要求を受け付け、それらの証明およびステータス（存在する場合）の確認結果を返す。 **このサービスは、VC の真正性と適時性の みをチェックし、必要なビジネスルールの適用は検証コーディネータに任せる。**
>

> The Holder service takes requests to create Verifiable Presentations from an optional set of VCs and returns well-formed, signed Verifiable Presentations containing those VCs. These VPs are used with Issuers to demonstrate control over DIDs prior to issuance and with Verifiers to present specific VCs.
>

> Holderサービスは、オプションのVCセットから検証可能なプレゼンテーションを作成する リクエストを受け、それらのVCを含む、整形式で署名された検証可能なプレゼンテーションを返す。 これらのVPは、発行者が発行前にDIDを管理していることを示すために使用され、また検証者が特定のVCを提示するために使用される。
>

#### 1.2.3 Status Service (ステータスサービス)

> The Status Service provides a privacy-preserving means for publishing and checking the status of any Verifiable Credentials issued by the Issuer. Verifier services use the Issuer's status endpoint (as specified in each revocable verifiable credential) to check the timeliness of a given VC as part of verification.
>

> ステータス・サービスは、発行者が発行した検証可能クレデンシャルのステータスを公開し、確認するた めのプライバシー保護手段を提供する。 検証者サービスは、発行者のステータス・エンドポイント（取り消し可能な検証可能クレデンシャルごとに指定され ている）を使用して、検証の一環として指定された VC の適時性をチェックする。
>

#### 1.2.4 Storage Services (ストレージサービス)

何も書かれていませんね…

#### 1.2.5 Workflow Service (ワークフローサービス)

> The Workflow Service provides a way for coordinators to automate specific interactions for specific users. Each role (Holder, Issuer, and Verifier) can run their own Workflow Service to create and manage exchanges that realize particular workflows. Administrators configure the workflow system to support particular flows. Then, when the business rules justify it, coordinators create exchanges at their Workflow Service and give authorized access to those exchanges to any party.
>

> ワークフロー・サービスは、**コーディネーターが特定のユーザーのために特定のインタラクションを自動化する方法**を提供する。 各役割（保有者、発行者、検証者）は、特定のワークフローを実現する交換を作成および管理するため、独自のワークフロー・サービスを実行することができる。 管理者は、特定のフローをサポートするためにワークフローシステムを設定する。 その後、ビジネス・ルールにより正当化された場合、コーディネータはワークフロー・サービスにおいて交換を作成し、その交換への認可されたアクセスを任意の関係者に与える。
>

---

ここからの2段落は、本来「1.2.4 ストレージサービス」に書かれるべきものが間違って置かれているような気がしています（[関連issue](https://github.com/w3c-ccg/vc-api/issues/404)）。

> Each actor in the system is expected to store their own verifiable credentials, as needed. Several known implementations use secure data storage such as encrypted data vaults for storing the Holder's VCs and use cryptographic authorizations to grant access to those VCs to Verifier Coordinators, as directed by the Holder. In-browser retrieval of such stored credentials can enable web-based Verifier Coordinators to integrate data from the Holder without sharing that data with the Verifier—the data is only ever present in the browser. Authorizing third-party remote access to Holder storage is likely in-scope for the VC API, although we expect this to be defined using extensible mechanisms to support a variety of storage and authorization approaches.
>

> システム内の各アクターは、必要に応じて自身の検証可能なクレデンシャルを保管することが期待される。 いくつかの既知の実装では、保有者の VC を保管するために暗号化されたデータ保管庫のような安全なデータ保管を使用し、暗号化認可を使用して、保有者の指示に従い、検証者コーディネータにこれらの VC へのアクセスを許可する。 このような保存されたクレデンシャルをブラウザ内で検索することで、ウェブベースの検証者コ ーディネータは、データを検証者と共有することなく、保有者のデータを統合することができる。 ホルダー・ストレージへのサードパーティのリモート・アクセスを認可することは、VC API の範囲内であると思われるが、さまざまなストレージと認可アプローチをサポートする拡張可能なメカニズムを使用して定義されることを期待する。
>

> The Issuer and Verifier storage solutions may or may not use secure data storage. Since all such storage interaction is moderated by the bespoke Issuer and Storage Coordinators, any necessary integrations can simply be part of that bespoke customization. We expect different implementations to compete on the ease of integration into various back-end storage platforms.
>

> 発行者と検証者のストレージ・ソリューションは、安全なデータ・ストレージを使用することも、使用しないこともある。 このようなストレージの相互作用はすべて、特注の発行者およびストレージ・コーディ ネーターによって調整されるため、必要な統合は、単に特注のカスタマイズの一部とすることができる。 様々な実装が、様々なバックエンド・ストレージ・プラットフォームへの統合のしやすさで競争することを期待している。
>

#### 1.2.6 Admin (管理)

> The Admin component is an acknowledgement that each of the other components need a way to be configured and managed, without prescribing the interfaces or means of that configuration. Some components may use JSON files to drive a semi-automated Issuer. Others might expose HTML pages. We expect different Coordinators and Services to compete on the power, ease, and flexibility of their administration and therefore, as of this writing, we anticipate Admin functionality to be out of scope for the VC API. However, we actually believe that to the extent we can standardize configuration setting across implementations, the more substitutable each component.
>

> Adminコンポーネントは、他の各コンポーネントが設定・管理される方法を必要としていることを示すものであり、そのインターフェースや設定方法を規定するものではない。 あるコンポーネントは、JSONファイルを使用して半自動発行機を動かすかもしれない。 また、HTMLページを公開するコンポーネントもあるでしょう。 そのため、この原稿を書いている時点では、管理者機能はVC APIの対象外であると予想しています。 しかし、私たちは、コンフィギュレーション設定を実装間で標準化できればできるほど、各コンポーネントの代替性が高まると考えています。
>

#### 1.2.7 Summary (まとめ)

> Based on this architectural thinking, we may want to frame the VC API as a roadmap of related specifications, integrated in an extensible way for maximum substitutability. Several technologies, such as EDVs and WebKMSs would likely benefit from the crypto suite Approach taken for VC proofs. Defining a generic mechanism that can be realized by any functionally conformant technology enables flexibility while laying the groundwork with current existing functionality. In this way, we may be able to acknowledge that elements like Key Services, Storage, and Status are necessary parts of the VC API while deferring the definition of how those elements work to specification already in development as well as those yet to be written.
>

> このアーキテクチャの考え方に基づき、**VC APIを関連仕様のロードマップとして枠組み化し、拡張可能な方法で統合することで、代替性を最大限に高めることができる。** EDVやWebKMSのようないくつかの技術は、VC証明に採用された暗号スイートアプローチから恩恵を受ける可能性が高い。 機能的に適合する技術で実現可能な汎用メカニズムを定義することで、現在の 既存の機能で基礎を固めつつ、柔軟性を確保することができる。 このようにして、キーサービス、ストレージ、ステータスのような要素がVC APIに必要な部分であることを認めつつ、それらの要素がどのように機能するかの定義は、まだ書かれていないものだけでなく、すでに開発中の仕様にも委ねることができるかもしれない。
>

EDVというのも初めて聞きましたが、Encrypted Data Vaultsのことのようです（[W3C仕様](https://identity.foundation/edv-spec/)）。

このまとめの書きっぷりを見ると、VC-API（この仕様書で表現したいもの）は単なるREST APIの集合ではなく、図2で示した全体のエコシステムなのだと構えたほうが良いかもしれませんね。標準化の過程でどう削ぎ落とされるか、動向に注意したいところです。

### 1.3 Conformance (適合性)

仕様に準拠するためには、仕様書中のどの部分は守らないといけないかが説明されています。

> As well as sections marked as non-normative, all authoring guidelines, diagrams, examples, and notes in this specification are non-normative. Everything else in this specification is normative.
>

> 非規範的とマークされたセクションだけでなく、この仕様書のすべてのオーサリングガイドライン、図、例、注釈は非規範的である。 それ以外はすべて規範的なものである。
>

「規範的」というのはノルマ、必須箇所のことですね。

> The key words *MAY*, *MUST*, *MUST NOT*, *OPTIONAL*, and *SHOULD* in this document are to be interpreted as described in [BCP 14](https://datatracker.ietf.org/doc/html/bcp14) [[RFC2119](https://w3c-ccg.github.io/vc-api/#bib-rfc2119)] [[RFC8174](https://w3c-ccg.github.io/vc-api/#bib-rfc8174)] when, and only when, they appear in all capitals, as shown here.
>

> 本文書におけるキーワードMAY、MUST、MUST NOT、OPTIONAL、SHOULDは、ここに示すように、すべて大文字で表示される場合、またその場合に限り、BCP14 [RFC2119] [RFC8174]に記述されているように解釈される。
>

---

ここは何を言いたいのかわかりませんでした。誤記？

> A conforming ***VC API client*** is ...
>
>
> A conforming ***VC API server*** is ...
>

## 2. Terminology (用語定義)

> *This section is non-normative.*
>

> このセクションはノン・ノルマである。
>

> The following terms are used to describe concepts in this specification.
>

> 以下の用語は、本仕様における概念を説明するために使用される。
>

---

元の記述ではA→Zの辞書順ですが、解説の都合上順番を入れ替える箇所があります。

> **entity**
>
>
> Anything that can be referenced in statements as an abstract or concrete noun. Entities include but are not limited to people, organizations, physical things, documents, abstract concepts, fictional characters, and arbitrary text. Any entity might perform roles in the ecosystem, if it is capable of doing so. Note that some entities fundamentally cannot take actions, e.g., the string "abc" cannot issue credentials.
>

> **エンティティ**
>
>
> 抽象名詞または具体名詞としてステートメントで参照できるもの。 **エンティティには、人、組織、物理的なもの、文書、抽象的な概念、架空の文字、および任意のテキストが含まれるが、これらに限定されない。** どのようなエンティティも、それが可能であれば、エコシステム内で役割を果たすかもしれない。 例えば、文字列 "abc "はクレデンシャルを発行できない。
>

仕様内にはエンティティよりもむしろサブジェクトの表現がよく出てくる印象です。エンティティはあらゆる立場（例: Issuer, プログラムを処理するサーバー）であり得る一方、サブジェクトはVCやVP内のクレームが対象にしているエンティティのことと理解しています。

---

> **claim**
>
>
> An assertion made about a [subject](https://w3c-ccg.github.io/vc-api/#dfn-subjects).
>

> **クレーム**
>
>
> あるサブジェクトについて主張すること。
>

クレームは大事な概念です。<https://idmlab.eidentity.jp/2024/06/w3c-verifiable-credentials-overview_23.htmlから引用します。>

> この「クレーム」という考え方の理解は非常に重要です。**属性（Attribute）からクレーム（Claim）へのパラダイムシフト**についてはKim Cameronの最後のスピーチでも語られた通りです。（日本語訳は[こちら](https://idmlab.eidentity.jp/2021/12/kim-cameron.html)）
>
>
> 該当部分を引用しておきます。
>
> > 私は、属性からクレームへとパラダイムを変更する必要があると話し合った日のことを覚えています。属性とは、単一企業の閉じた世界での特性を表す言葉でしたが、世界を開いてドメイン間を行き来するようになると、そのことに気付きます。それは単に属性の問題ではなく、誰が誰について何を言っているかという問題です。属性はある存在によって語られ、その存在を実際に信じるかどうかを判断しなければなりません。つまり、クレームという概念が生まれたのです。**クレームとは、疑わしい属性のことであり、どのような目的のために何を信用するかを決めるための技術が必要なのです。**
> >
>
> つまり、サブジェクトやクレデンシャルに関する情報で検証されるべきものなんですよね。
>

---

> **credential**
>
>
> A set of one or more [claims](https://w3c-ccg.github.io/vc-api/#dfn-claims) made by an [issuer](https://w3c-ccg.github.io/vc-api/#dfn-issuers). The [claims](https://w3c-ccg.github.io/vc-api/#dfn-claims) in a credential can be about different [subjects](https://w3c-ccg.github.io/vc-api/#dfn-subjects).
> Our definition of credential differs from, [NIST's definitions of credential](https://csrc.nist.gov/glossary/term/credential).
>

> **クレデンシャル**
>
>
> 発行者が行う **1 つまたは複数のクレームのセット**。 クレデンシャル内のクレームは、異なる対象に関するものであってもよい。
> 我々のクレデンシャルの定義は、NIST のクレデンシャルの定義とは異なる。
>

ずっとVCの話をしてきて今更ですが、クレデンシャルの定義もかなり特殊ですね。

---

クレームの集合はクレデンシャルだ！と述べたばかりですが、グラフとも呼びます。クレデンシャルはグラフを形成する、というところですかね。

グラフ構造の絵も含め、<https://www.w3.org/TR/vc-data-model-2.0/#claims> の「3.1 Claims」セクションを見ると良いでしょう。

> **graph**
>
>
> A set of claims, forming a network of information composed of [subjects](https://w3c-ccg.github.io/vc-api/#dfn-subjects) and their relationship to other [subjects](https://w3c-ccg.github.io/vc-api/#dfn-subjects) or data. Each [claim](https://w3c-ccg.github.io/vc-api/#dfn-claims) is part of a graph; this is either explicit in the case of [named graphs](https://w3c-ccg.github.io/vc-api/#dfn-named-graphs), or implicit for the [default graph](https://w3c-ccg.github.io/vc-api/#dfn-default-graph).
>

> **グラフ**
>
>
> **クレームの集合**で、サブジェクトと他のサブジェクトまたはデータとの関係からなる情報のネットワークを形成する。 各クレームはグラフの一部であり、名前付きグラフの場合は明示的、デフォルトグラフの場合は暗黙的である。
>

> **default graph**
>
>
> The [graph](https://w3c-ccg.github.io/vc-api/#dfn-graphs) containing all [claims](https://w3c-ccg.github.io/vc-api/#dfn-claims) that are not explicitly part of a [named graph](https://w3c-ccg.github.io/vc-api/#dfn-named-graphs).
>

> **デフォルトグラフ**
>
>
> 名前付きグラフに明示的に含まれないすべてのクレームを含むグラフ。
>

> **named graph**
>
>
> A [graph](https://w3c-ccg.github.io/vc-api/#dfn-graphs) associated with specific properties, such as `verifiableCredential`. These properties result in separate [graphs](https://w3c-ccg.github.io/vc-api/#dfn-graphs) that contain all [claims](https://w3c-ccg.github.io/vc-api/#dfn-claims) defined in the corresponding JSON objects.
>

> **名前付きグラフ**
>
>
> verifiableCredential など、特定のプロパティに関連付けられたグラフ。 これらのプロパティは、対応する JSON オブジェクトで定義されたすべてのクレームを含む個別のグラフになります。
>

---

IHVモデルの用語です。

> **issuer**
>
>
> A role an [entity](https://w3c-ccg.github.io/vc-api/#dfn-entities) can perform by asserting [claims](https://w3c-ccg.github.io/vc-api/#dfn-claims) about one or more [subjects](https://w3c-ccg.github.io/vc-api/#dfn-subjects), creating a [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) from these [claims](https://w3c-ccg.github.io/vc-api/#dfn-claims), and transmitting the [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) to a [holder](https://w3c-ccg.github.io/vc-api/#dfn-holders).
>

> **発行者**
>
>
> エンティティが、1 つまたは複数の対象に関する主張を行い、これらの主張から検証可能なクレデンシャル を作成し、検証可能なクレデンシャルを保持者に送信することによって実行できる役割。
>

> **holder**
>
>
> A role an [entity](https://w3c-ccg.github.io/vc-api/#dfn-entities) might perform by possessing one or more [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) and generating [verifiable presentations](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-presentation) from them. A holder is often, but not always, a [subject](https://w3c-ccg.github.io/vc-api/#dfn-subjects) of the [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) they are holding. Holders store their [credentials](https://w3c-ccg.github.io/vc-api/#dfn-credential) in [credential repositories](https://w3c-ccg.github.io/vc-api/#dfn-credential-repositories).
>

> **ホルダー（保持者）**
>
>
> エンティティが 1 つまたは複数の検証可能なクレデンシャルを所有し、それらから検証可能な プレゼンテーションを生成することによって果たす役割。 保持者は多くの場合、常にではないが、保持している検証可能なクレデンシャルのサブジェクトである。 保有者はクレデンシャル・リポジトリにクレデンシャルを保管する。
>

> **verifier**
>
>
> A role an [entity](https://w3c-ccg.github.io/vc-api/#dfn-entities) performs by receiving one or more [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential), optionally inside a [verifiable presentation](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-presentation) for processing. Other specifications might refer to this concept as a relying party.
>

> **検証者**
>
>
> エンティティが 1 つ以上の検証可能なクレデンシャルを受け取ることによって果たす役割で、任意 で処理のために検証可能な提示の中にある。 他の仕様では、この概念を relying party (RP) と呼ぶ場合もある。
>

---

VCとVPです。

> **verifiable credential**
>
>
> A verifiable credential is a tamper-evident credential that has authorship that can be cryptographically verified. Verifiable credentials can be used to build [verifiable presentations](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-presentation), which can also be cryptographically verified.
>

> **検証可能なクレデンシャル**
>
>
> 検証可能なクレデンシャルは、暗号的に検証可能な作成者を持つ、改ざん不可能なクレデンシャルである。 検証可能なクレデンシャルは、検証可能なプレゼンテーションを構築するために使用でき、この プレゼンテーションも暗号的に検証できる。
>

> **verifiable presentation**
>
>
> A verifiable presentation is a tamper-evident presentation encoded in such a way that authorship of the data can be trusted after a process of cryptographic verification. Certain types of verifiable presentations might contain data that is synthesized from, but do not contain, the original [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) (for example, zero-knowledge proofs).
>

> **検証可能なプレゼンテーション**
>
>
> 検証可能なプレゼンテーションとは、暗号的な検証プロセスを経た後、データの作成者が信頼できるような方法でエンコードされた、改ざん不可能なプレゼンテーションのことである。 ある種の検証可能なプレゼンテーションには、元の検証可能な証明書（例えば、ゼロ知識証明）を含まないが、そこから合成されたデータが含まれる場合がある。
>

---

> **verifiable data registry**
>
>
> A role a system might perform by mediating the creation and [verification](https://w3c-ccg.github.io/vc-api/#dfn-verify) of identifiers, keys, and other relevant data, such as [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) schemas, revocation registries, issuer public keys, and so on, which might be required to use [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential). Some configurations might require correlatable identifiers for [subjects](https://w3c-ccg.github.io/vc-api/#dfn-subjects). Some registries, such as ones for UUIDs and public keys, might just act as namespaces for identifiers.
>

> **検証可能なデータレジストリ**
>
>
> システムが、識別子、鍵、および検証可能なクレデンシャル・スキーマ、失効レジストリ、発行者 公開鍵など、検証可能なクレデンシャルを使用するために必要とされるその他の関連データの 作成と検証を仲介することによって果たす役割。 構成によっては、サブジェクトに相関可能な識別子が必要な場合もある。 UUIDや公開鍵のためのものなど、いくつかの登録は単に識別子のための名前 空間として機能するかもしれない。
>

かなりわかりにくいですが、[VCDM v2.0 の用語集](https://www.w3.org/TR/vc-data-model-2.0/#dfn-verifiable-data-registries)の絵を見ると理解が進むかと思います。JSON-LDの `@context` プロパティのURLが指す先だとも言えますね。

![Untitled](/img/2024/07-19/Untitled%203.png)

---

> **verification**
>
>
> The evaluation of whether a [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) or [verifiable presentation](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-presentation) is an authentic and current statement of the issuer or presenter, respectively. This includes checking that: the credential (or presentation) conforms to the specification; the proof method is satisfied; and, if present, the status check succeeds. Verification of a credential does not imply evaluation of the truth of [claims](https://w3c-ccg.github.io/vc-api/#dfn-claims) encoded in the credential.
>

> **検証**
>
>
> 検証可能なクレデンシャルまたは検証可能なプレゼンテーションが、それぞれ発行者または提示者 の真正かつ現在の声明であるかどうかの評価。 これには、クレデンシャル（またはプレゼンテーショ ン）が仕様に準拠していること、証明方法が満たされていること、およびステータスのチェックが 成功している（存在する場合）ことのチェックが含まれる。 **クレデンシャルの検証は、クレデンシャルにエンコードされたクレームの真偽の評価を意味しない。**
>

クレームの真正性はIssuerへの信頼によりもたらされるものと理解しています。

---

> **data minimization**
>
>
> The act of limiting the amount of shared data strictly to the minimum necessary to successfully accomplish a task or goal.
>

> **データ最小化**
>
>
> タスクや目標を成功裏に達成するために、共有するデータ量を必要最小限に厳密に制限する行為。
>

> **decentralized identifier**
>
>
> A portable URL-based identifier, also known as a ***DID***, associated with an [entity](https://w3c-ccg.github.io/vc-api/#dfn-entities). These identifiers are most often used in a [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) and are associated with [subjects](https://w3c-ccg.github.io/vc-api/#dfn-subjects) such that a [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) itself can be easily ported from one [credential repository](https://w3c-ccg.github.io/vc-api/#dfn-credential-repositories) to another without the need to reissue the [credential](https://w3c-ccg.github.io/vc-api/#dfn-credential). An example of a DID is `did:example:123456abcdef`.
>

> **分散型識別子**
>
>
> **DID** とも呼ばれる、エンティティに関連付けられたポータブルな URL ベースの識別子。 これらの識別子は検証可能なクレデンシャルで最も頻繁に使用され、検証可能なクレデンシャル自 体が、クレデンシャルを再発行する必要なくあるクレデンシャル・リポジトリから別のクレデンシャル・リポ ジトリに簡単に移植できるように、サブジェクトに関連付けられている。 DID の例は、 `did:example:123456abcdef` である。
>

> **identity provider**
>
>
> An identity provider, sometimes abbreviated as *IdP*, is a system for creating, maintaining, and managing identity information for [holders](https://w3c-ccg.github.io/vc-api/#dfn-holders), while providing authentication services to [relying party](https://w3c-ccg.github.io/vc-api/#dfn-relying-parties) applications within a federation or distributed network. In this case the [holder](https://w3c-ccg.github.io/vc-api/#dfn-holders) is always the [subject](https://w3c-ccg.github.io/vc-api/#dfn-subjects). Even if the [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) are bearer [credentials](https://w3c-ccg.github.io/vc-api/#dfn-credential), it is assumed the [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) remain with the [subject](https://w3c-ccg.github.io/vc-api/#dfn-subjects), and if they are not, they were stolen by an attacker. This specification does not use this term unless comparing or mapping the concepts in this document to other specifications. This specification decouples the [identity provider](https://w3c-ccg.github.io/vc-api/#dfn-identity-providers) concept into two distinct concepts: the [issuer](https://w3c-ccg.github.io/vc-api/#dfn-issuers) and the [holder](https://w3c-ccg.github.io/vc-api/#dfn-holders).
>

> **アイデンティティ・プロバイダー**
>
>
> ID プロバイダ（IdP と略されることもある）は、保有者の ID 情報を作成、維持、管理するシス テムであり、同時にフェデレーションまたは分散ネットワーク内の依拠当事者アプリケーションに 認証サービスを提供する。 この場合、保持者は常にサブジェクトである。 検証可能なクレデンシャルがベアラ・クレデンシャルであっても、検証可能なクレデンシャルが対象者 に残っていることが前提となり、残っていない場合は攻撃者によって盗まれたことになる。 本文書では、本文書の概念を他の仕様と比較またはマッピングしない限り、この用語を使用しない。 この仕様は、ID プロバイダの概念を、発行者と保有者という 2 つの別個の概念に分離する。
>

## 3. The VC API (VC API)

### 3.1 Base URL (ベースURL)

> There are no restrictions put on the base URL location of the implementation. The URL paths used throughout this specification are shown as absolute paths and their base URL *MAY* be the host name of the server (e.g., `example.com`), a subdomain (e.g., `api.example.com`), or a path within that host (e.g., `example.com/api`).
>

> 実装のベースURLの場所に制限はない。 この仕様を通して使用されるURLパスは絶対パスで示され、そのベースURLはサーバーのホスト名(例: [example.com](http://example.com/))、サブドメイン(例: [api.example.com](http://api.example.com/))、またはそのホスト内のパス(例: [example.com/api](http://example.com/api))であってもよい[MAY]。
>

### 3.2 Authorization (認可)

> The VC API can be deployed in a variety of networking environments which might contain hostile actors. As a result, conforming [VC API servers](https://w3c-ccg.github.io/vc-api/#dfn-vc-api-server) **require** conforming [VC API clients](https://w3c-ccg.github.io/vc-api/#dfn-vc-api-client) to utilize secure authorization technologies when performing certain types of requests. **Each HTTP endpoint defined in this document specifies whether or not authorization is required when performing a request.** With the exception of the class of forbidden authorization protocols discussed later in this section, the VC API is agnostic regarding authorization mechanism.
>

> **VC API は、敵対的な行為者を含む可能性のある様々なネットワーク環境にデプロイされる可能性がある**。 その結果、適合する VC API サーバは、適合する VC API クライアントが特定のタイプのリクエストを実行する際に、安全な認可技術を利用することを**要求する**。 本文書で定義される各 HTTP エンドポイントは、リクエストを実行する際に認可が必要かどうかを指定する。 このセクションで後述する禁止された認可プロトコルのクラスを除いて、VC API は認可の仕組みにとらわれない。
>

仕様に準拠するためには、認可が必須であることが示されています。ただし、直後に記述する「パブリック」なAPIでは認可は不要です。

*"Each HTTP endpoint defined in this document specifies whether or not authorization is required when performing a request." (本文書で定義される各 HTTP エンドポイントは、リクエストを実行する際に認可が必要かどうかを指定する。)* の箇所の解釈の仕方はよくわかりません。レスポンスに "401 Not Authorized" が定義されているエンドポイントは認可が必要、という意図なのでしょうか…？標準化の過程で明確になることを期待します。

---

> The VC API is meant to be generic and useful in many scenarios that require the issuance, possession, presentation, and/or verification of Verifiable Credentials. To this end, implementers are advised to consider the following classifications of use cases:
>

> VC API は、検証可能クレデンシャルの発行、所有、提示、検証を必要とする多くのシナリオで汎用的かつ有 用であることを意図している。 このため、実装者は以下のユースケースの分類を考慮することが推奨される：
>

---

パブリックAPIです。個人がサブジェクトであるようなVC/VPでの使用は想定しづらいですが、特定の団体がサブジェクトであるようなVC/VPや、下記説明文にあるようなユースケースが考えられます。

>
>
> - *Public*. A Public API is one that can be called with no authorization. Examples include an open witness or timestamp service (a trusted service that can digitally sign a message with a timestamp for an audit trail purpose), or an open retail coupon endpoint ("buy one, get one free"). Public verifiers might also exist as well, to act as an agnostic third party in a trust scenario.

>
>
> - *パブリック*. Public APIとは、認可なしで呼び出すことができるAPIのことである。 例としては、オープンな証人やタイムスタンプサービス（監査証跡を目的としてタイムスタンプでメッセージにデジタル署名できる信頼されたサービス）、あるいはオープンな小売クーポンのエンドポイント（「1つ買えば1つ無料」）などがある。 信頼シナリオにおいて不可知論的な第三者として機能する公開検証者も存在するかもしれない。

---

APIキーなどを使った認可です。クレデンシャル（= クレームの集合）のサブジェクトが関与しないAPIアクセス（バッチや代理人によるもの）のときに使いそうです。

>
>
> - *Permissioned*. Permissioned authorization requires the entity making the API call to, for example, have an access control token or a capability URL, or to invoke a capability from a mutually trusted source. These permissions grant access to the API, but make no assumptions about credential subjects, previous interactions, or the like. Permissioned access is particularly useful in service-to-service based workflows, where credential subjects are not directly involved.

>
>
> - *パーミション付き*. パーミッション付き認可は、API 呼び出しを行うエンティティが、例えばアクセス制御トークンまたはケイパビリティ URL を持っていること、あるいは相互に信頼されたソースからケイパビリティを呼び出すことを要求する。 これらのパーミッションはAPIへのアクセスを許可するが、クレデンシャルのサブジェクトや以前のやりとりなどについては仮定しない。 **パーミッション付き認可は、クレデンシャルのサブジェクトが直接関与しない**、サービス間ベースのワークフローで特に有用である。

---

CHAPI, OIDC, GNAPなどの認証に基づき、Holderあるいはサブジェクトが認証された状態でAPIを叩く認可です。パーミション付き認可と異なり、クレデンシャルのサブジェクトが関与します。

CHAPI, GNAPには詳しくないのですが、CHAPIは <https://chapi.io/> からデモのPlaygroundを触ることができました。

>
>
> - *Bound*. Bound authorization involves scenarios where the API calls are tightly coupled, linked, or bound to another process, often out-of-band, that has authenticated the holder/subject of the API interaction. These use cases include, but are not limited to, issuance of subject-specific identity claims directly to the subject in question, or verification of credentials to qualify the holder for service at the verifier, for example. Examples of methods to bind activity on one channel to a VC API call include [CHAPI](https://chapi.io/) (the [Credential Handler API](https://chapi.io/)), OIDC (OpenID Connect), and GNAP (the Grant Negotiation and Authorization Protocol). Developers implementing bound authorization will need to take steps to ensure the appropriate level of assurance is achieved in the flow to properly protect the binding.

>
>
> - *紐づいた*. 紐づいた認可には、API 呼び出しが、API 相互作用の保持者／対象者を認証した別のプロセス（多くの場合、帯域外）に密接に結合、リンク、または紐づけされるシナリオが含まれる。 このようなユースケースには、対象者固有の ID クレームを当該対象者に直接発行すること、または保有者が検証機でサービスを受ける資格を得るためのクレデンシャルの検証などが含まれるが、これらに限定されない。 あるチャネルのアクティビティを VC API 呼び出しに紐づけする方法の例としては、CHAPI（クレデンシャル・ハンドラ API）、OIDC（OpenID Connect）、GNAP（グラント交渉および認可プロトコル）などがある。 紐づいた認可を実装する開発者は、紐づけを適切に保護するために、適切なレベルの保証がフローで達成されるように手順を踏む必要がある。

---

> The rest of this section gives examples of the authorization technologies that have been contemplated for use by conforming implementations. Other equivalent authorization technologies can be used. Implementers are cautioned against using non-standard or legacy authorization technologies.
>

> このセクションの残りの部分では、適合する実装が使用することが想定されている 認可技術の例を示す。 他の同等の認可技術を使用することもできる。 実装者は、非標準またはレガシーな認可技術を使用しないように注意されたい。
>

#### 3.2.1 Forbidden Authorization (禁止された認可)

> Requests to the VC API *MUST NOT* utilize any authorization protocol that includes long-lived static credentials such as usernames and passwords or similar values in those requests. An example of such a forbidden protocol is HTTP Basic Authentication [[RFC7617](https://w3c-ccg.github.io/vc-api/#bib-rfc7617)].
>

> VC APIへのリクエストは、**ユーザー名やパスワードのような長期間の静的な認証情報**、あるいはリクエストに類似の値を含む認証プロトコルを利用してはならない[**MUST NOT**]。 そのような禁止プロトコルの例として、**HTTP Basic Authentication** [RFC7617]がある。
>

Basic認証に代表されるような、有効期限なく長期間使える（VCの文脈ではなく通常の意味での）クレデンシャルに基づいた認可は禁止とのこと。

特にパーミション付き認可を実装するときに気をつけたいポイントですね。

#### 3.2.2 OAuth 2.0 (OAuth 2.0)

紐づいた認可を実現する手段として、OAuth 2.0に触れられています。

> If the OAuth 2.0 Authorization Framework [[RFC6749](https://w3c-ccg.github.io/vc-api/#bib-rfc6749)] is utilized for authorization, the access tokens utilized by clients *MAY* be OAuth 2.0 Bearer Tokens [[RFC6750](https://w3c-ccg.github.io/vc-api/#bib-rfc6750)] or any other valid OAuth 2.0 token type. Any valid OAuth 2.0 grant type *MAY* be used to request the access tokens. However, OAuth 2.0 *MUST* be implemented in the following way:
>

> OAuth 2.0 Authorization Framework [RFC6749]が認可に利用される場合、クライアントが利用するアクセストークンは OAuth 2.0 Bearer Tokens [RFC6750]または他の有効な OAuth 2.0 トークンタイプであってもよい[MAY]。 どのような有効なOAuth 2.0のグラントタイプも、アクセストークンを要求するために使用してもよい[MAY]。 ただし、OAuth 2.0は以下の方法で実装されなければならない（MUST）：
>

> OAuth2 tokens for this purpose have an audience of the particular issuer instance, e.g., `origin/issuers/zc612332f3`.
>

> この目的のための OAuth2 トークンは、特定の発行者インスタンスのオーディエンス、例えば `origin/issuers/zc612332f3` を持つ。
>

> The scopes are generalized to read/write actions on particular endpoints:
>

> スコープは、特定のエンドポイントに対する読み書きのアクションに一般化されている：
>

>
>
> - `read:/` would allow reading on any API on a particular instance.
> - `write:/` would allow writing on any API on a particular instance.

>
>
> - `read:/` は、特定のインスタンス上のどのAPIでも読み込みを許可する。
> - `write:/` は、特定のインスタンス上のどのAPIでも書き込みを許可する。

> `write:/credentials/issue` would only allow writing to that particular API.
>

> `write:/credentials/issue` は、そのAPIだけに対する書き込みを許可する。
>

> Other authorization mechanisms that support delegation might be defined in the future.
>

> 将来、委任をサポートする他の認可メカニズムが定義されるかもしれない。
>

### 3.3 Options (オプション)

API定義にoptionalなフィールドがあって、それをサーバー側で取得できるように実装するのもしないのも自由であることが述べられています。

> Some of the endpoints defined in the following sections accept an `options` object. All properties of the `options` object are *OPTIONAL* when configuring each instance, as these properties are intended to meet per-deployment needs that might vary. Thus, any given instance configuration *MAY* prohibit client use of some `options` properties in order to prevent clients from passing certain data to that instance. Likewise, an instance configuration *MAY* require that clients include some `options` properties.
>

> 以下のセクションで定義されているエンドポイントのいくつかは、オプション・オブジェクトを受け入れます。 各インスタンスを設定するとき、オプションオブジェクトのプロパティはすべてオプション(OPTIONAL)です。 したがって、任意のインスタンス構成は、クライアントが特定のデータをそのインスタンスに渡すことを防ぐために、いくつかのオプションプロパティのクライアントによる使用を禁止してもよい[MAY]。 同様に、インスタンス構成は、クライアントがいくつかのオプションプロパティを含むことを要求してもよい(MAY)。
>

### 3.4 Content Serialization (コンテンツのシリアライゼーション)

> Many of the endpoints defined in the following sections receive data and options in request bodies.
>
>
> Implementations *MUST* throw an error if an endpoint receives data, options, or option values that it does not understand or know how to process.
>

> 以下のセクションで定義されるエンドポイントの多くは、リクエストボディで データとオプションを受け取る。
>
>
> 実装は、エンドポイントが理解できない、または処理方法を知らないデータ、オプション、またはオプション値を受信した場合、エラーを投げなければならない(MUST)。
>

### 3.6 API Component Overview (APIコンポーネントの概要)

> This section gives an overview of all endpoints in the VC-API by the component the endpoint is expected be callable from. If a component does not have a listing below it means the VC-API does not currently specify any endpoints for that component.
>

> このセクションでは、VC-APIに含まれるすべてのエンドポイントの概要を、**そのエンドポイントが呼び出し可能であると予想されるコンポーネント別に**示します。 コンポーネントに以下のリストがない場合は、VC-APIが現在そのコンポーネントのエンドポイントを指定していないことを意味します。
>

3.6.Xのセクションで、「このAPIはどのコンポーネントから呼ばれる想定」かを書いていくれています。これは理解が進みますね。

よりわかりやすくするために図示してみました。

![図2を元に筆者作成](/img/2024/07-19/Untitled%204.png)

<center>図2を元に筆者作成</center>

- Coordinatorが自分のServiceのAPIを呼び出す
- Verifier ServiceがStatus Serviceを呼び出す

のいずれかの呼び出しが基本かと思います。

少々腑に落ちないのは以下の点です。

- Holder Coordinatorが直接 Issuer Service のAPIを呼び出す経路がある理由（[関連issue](https://github.com/w3c-ccg/vc-api/issues/405)）
  - このAPIのためだけに外向けのNW疎通が必要というのもつらい
- Coordinatorのうち、Issuer Coordinatorだけがエンドポイントを持つ理由
  - この仕様書で規定するAPIは基本的にServiceのものである理解
  - 各Coordinatorは（独自機能・エンドポイントも許容しつつ）Serviceと同様のエンドポイントを持つことが推奨されるべきと個人的には考えている（[関連issue](https://github.com/w3c-ccg/vc-api/issues/406)）

このあたりはもしかしたら標準化の過程でブラッシュアップされるかもしれません。

#### 3.6.1 Issuer Coordinator (発行者コーディネーター)

（図示したため省略）

#### 3.6.2 Issuer Service (発行者サービス)

（図示したため省略）

#### 3.6.3 Status Service (ステータスサービス)

（図示したため省略）

#### 3.6.4 Verification Service (検証者サービス)

（図示したため省略）

#### 3.6.5 Holder Service (ホルダーサービス)

（図示したため省略）

#### 3.6.5 Issuer Coordinator (発行者コーディネーター)

（図示したため省略）

#### 3.6.6 Workflow Service (ワークフローサービス)

図をうるさくさせないために省略した部分でした。

> Below are all endpoints expected to be exposed by the Workflow Service, along with the component that is expected to call the endpoint
>

> 以下は、ワークフローサービスによって公開されることが期待されるすべてのエンドポイントと、エンドポイントを呼び出すことが期待されるコンポーネントである。
>

>
>
>
>
> | Endpoint | Expected Caller |
> | --- | --- |
> | POST /workflows | Administrators |
> | GET /workflows/{localWorkflowId} | Administrators |
> | POST /workflows/{localWorkflowId}/exchanges | Owner Coordinator |
> | GET /workflows/{localWorkflowId}/exchanges/{localExchangeId} | Owner Coordinator |
> | POST /workflows/{localWorkflowId}/exchanges/{localExchangeId} | Anyone |

>
>
>
>
> | エンドポイント | 期待される呼び出し元 |
> | --- | --- |
> | POST /workflows | 管理者 |
> | GET /workflows/{localWorkflowId} | 管理者 |
> | POST /workflows/{localWorkflowId}/exchanges | オーナーコーディネーター |
> | GET /workflows/{localWorkflowId}/exchanges/{localExchangeId} | オーナーコーディネーター |
> | POST /workflows/{localWorkflowId}/exchanges/{localExchangeId} | 誰でも |

唐突に出てきた管理者・オーナーコーディネーターとは…？

### 3.7~3.10

細かいAPI定義なので省略します。原文や、あるいは [w3c-ccg/vc-api リポジトリ](https://github.com/w3c-ccg/vc-api)にあるOpenAPI定義のYAMLを読むとよいでしょう。

### 3.11 Error Handling (エラー処理)

常識的なことが書いてあります。

> Error handling and messaging in the VC-API aligns with Problem Details for HTTP APIs [[RFC9457](https://w3c-ccg.github.io/vc-api/#bib-rfc9457)]. Implementers *SHOULD* include a status and a title in the error response body relating to the specifics of the endpoint on which the error occurs.
>

> VC-API におけるエラーの処理とメッセージングは、HTTP API のための問題の詳細 [RFC9457]と一致している。 実装者はエラーが発生したエンドポイントの仕様に関連するステータスとタイトルをエラーレスポンスボディに含めるべきである(SHOULD)。
>

> Aligning on error handling and messaging will greatly improve test-suites accuracy when identifying technical friction impacting interoperability.
>

> エラー処理とメッセージングを統一することで、相互運用性に影響を与える技術的な摩擦を特定する際のテストスイートの精度が大幅に向上する。
>

> Leveraging other fields such as detail, instance and type is encouraged, to provide more contextual feedback about the error, while being conscious of security concerns and hence not disclosing sensitive information.
>

> detail、instance、typeのような他のフィールドを活用することは、エラーについてより文脈に沿ったフィードバックを提供するために推奨される。
>

> Implementers should handle all server errors to the best of their capabilities. Endpoints should avoid returning improperly handled 500 errors in production environments, as these may lead to information disclosure.
>

> 実装者は、できる限りすべてのサーバーエラーを処理すべきである。 エンドポイントは、本番環境において不適切に処理された 500 エラーを返すことは避けるべきです。
>

#### 3.11.1 Relationship between verification, validation and error handling (検証・バリデーション・エラー処理の関係)

> It is recommended to avoid raising errors while performing verification, and instead gather ProblemDetails objects to include in the verification results.
>

> 検証の実行中にエラーを発生させることは避け、代わりにProblemDetailsオブジェクトを集めて検証結果に含めることをお勧めします。
>

ProblemDetailsというのはすぐ次のセクションで出てきます。

#### 3.11.2 Types of ProblemDetails (ProblemDetailsの型)

> An implementer can refer to the [[VC-DATA-MODEL-2.0](https://w3c-ccg.github.io/vc-api/#bib-vc-data-model-2.0)] and the [[VC-BITSTRING-STATUS-LIST](https://w3c-ccg.github.io/vc-api/#bib-vc-bitstring-status-list)] for currently defined ProblemDetails types.
>

> 実装者は、現在定義されているProblemDetailsの型について、[VC-DATA-MODEL-2.0]と[VC-BITSTRING-STATUS-LIST]を参照することができる。
>

```json
{
  "type": "https://www.w3.org/TR/vc-data-model#CRYPTOGRAPHIC_SECURITY_ERROR",
  "status": 400,
  "title": "CRYPTOGRAPHIC_SECURITY_ERROR",
  "detail": "The cryptographic security mechanism couldn't be verified. This is likely due to a malformed proof or an invalid verificationMethod."
}
```

#### 3.11.3 Verification Response (検証レスポンス)

***3.11.3.1 Errors and Warnings (エラーと警告)***

> Errors are `ProblemDetails` relating to cryptography, data model, and malformed context. Warnings are `ProblemDetails` relating to statuses and validity periods. If an error is included, the `verified` property of the `VerificationResponse` object *MUST* be set to `false`; if no errors are included, it *MUST* be set to `true`.
>

> **エラーは、暗号、データモデル、不正なコンテキストに関する ProblemDetails** です。 **警告は、ステータスと有効期間に関するProblemDetails**である。 エラーが含まれている場合、VerificationResponseオブジェクトのverifiedプロパティはfalseに設定されなければならない(MUST)。
>

```json
{
  "verified": false,
  "document": verifiableCredential,
  "mediaType": "application/vc",
  "controller": issuer,
  "controllerDocument": didDocument,
  "warnings": [ProblemDetails],
  "errors": [ProblemDetails]
}
```

## A. Privacy Considerations (プライバシーに関する考慮事項)

### A.1 Delegation (委任)

> [Verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) [[VC-DATA-MODEL-2.0](https://w3c-ccg.github.io/vc-api/#bib-vc-data-model-2.0)] are a standard data model designed to mitigate risks of misuse and fraud. As a data model, [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) are protocol-neutral and consider at least two types of entities: [issuer](https://w3c-ccg.github.io/vc-api/#dfn-issuers) and [subject](https://w3c-ccg.github.io/vc-api/#dfn-subjects). When the subject of a [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) is a natural person or linked to a natural person, privacy and human rights can be impacted by the vastly more efficient processing of standardized [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) as compared to their analog ancestors.
>

> 検証可能なクレデンシャル［VC-DATA-MODEL-2.0］は、誤用と詐欺のリスクを軽減するために設計された標準データ・モデルである。 データ・モデルとして、検証可能クレデンシャルはプロトコルに中立であり、少なくとも 2 種類のエンティティ（発行者と対象者）を考慮する。 検証可能なクレデンシャルの対象が自然人または自然人にリンクされている場合、標準化された 検証可能なクレデンシャルの処理がアナログの先祖と比較して大幅に効率化されることによって、プライバシーおよび人権が影響を受ける可能性がある。
>

"analog ancestors" (アナログの先祖) というのが難しい（おもしろい）ですが、「サブジェクトは◯◯である」というクレームを対面で検証してもらうこととかをイメージすれば良いのかなと思います。

---

> Technology, in the form of standardized APIs and protocols for issuing [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential), further enhances the efficiency of processing [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) and adds to the risks of unforeseen privacy and human rights consequences.
>

> 検証可能なクレデンシャルを発行するための標準化された API およびプロトコルの形の技術は、 検証可能なクレデンシャルの処理効率をさらに高め、予期しないプライバシーおよび人権の結果 のリスクを増大させる。
>

---

次の2つのパラグラフでは、

- Issuerとサブジェクトはともに、VCの処理を委任することがある
- Issuerが委任された場合、サブジェクトのプライバシーに悪影響が及ぶ場合がある

ということを語っています。

> [Verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) issuance has a request phase and a delivery phase. The request might be made by the [subject](https://w3c-ccg.github.io/vc-api/#dfn-subjects) or another role, and delivery can be to a client that might or might not be controlled by the subject. Delegation is highly relevant for both phases. The [issuer](https://w3c-ccg.github.io/vc-api/#dfn-issuers) might delegate processing of the request to a separate entity. The subject, for their part, might also delegate the ability to request a [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) to a separate entity. Note that the subject might not always have the capability or ability to perform delegation. Examples include: a new born baby, a pet, and a person with dementia. So the request might be performed by a third party who was not delegated by the subject. The ability to delegate is a third dimension in the enhanced efficiency of processing [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) and has impact on privacy and human rights.
>

> 検証可能なクレデンシャルの発行には、要求フェーズと配信フェーズがある。 要求は、対象者または別の役割によって行われ、引渡しは、対象者が制御している かもしれないし、制御していないかもしれないクライアントに行われるかもしれない。 **委任**は両フェーズに大きく関係する。 発行者は、要求の処理を別のエンティティに委任することができる。 対象者側も、検証可能なクレデンシャルを要求する能力を別個のエンティティに委任す る場合がある。 対象者が委任を実行する能力または能力を常に持っているとは限らないことに注意する。 例えば、生まれたばかりの赤ちゃん、ペット、認知症の人などである。 つまり、リクエストは、対象者から委任されていない第三者によって実行される可能性がある。 委任する能力は、検証可能なクレデンシャルの処理効率を高める第三の側面であり、プライバシーと人権に影響を与える。
>

> The architecture described in this specification is designed for market acceptance through a combination of efficiency and respect for privacy and human rights. APIs and protocols for processing [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) do not favor delegation by the issuer role over delegation by the subject role.
>

> この仕様に記述されているアーキテクチャは、効率性とプライバシーおよび人権の尊重を組み合 わせて市場に受け入れられるように設計されている。 検証可能なクレデンシャルを処理するための API およびプロトコルは、**発行者の役割による委任を対象者の役割による委任より優先しない。**
>

### A.2 "Phoning Home" Considered Harmful (「家に電話する」は有害と考えられている)

"Phone Home" はVCの文脈でよく見かける議論です。VerifierがIssuerに通信すると、Issuerが「HolderはどんなVerifierとやり取りしているか」を把握してしまうという問題ですね。IHVモデルはうまくやればこれを避けることができるのが大きな強みです。

> It is considered a bad privacy practice for a [verifier](https://w3c-ccg.github.io/vc-api/#dfn-verifier) to contact an [issuer](https://w3c-ccg.github.io/vc-api/#dfn-issuers) about a specific [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential). This practice is known as "phoning home" and can result in a mismatch in privacy expectations between [holders](https://w3c-ccg.github.io/vc-api/#dfn-holders), [issuers](https://w3c-ccg.github.io/vc-api/#dfn-issuers), [verifiers](https://w3c-ccg.github.io/vc-api/#dfn-verifier), and other parties expressed in a [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential). Phoning home enables [issuers](https://w3c-ccg.github.io/vc-api/#dfn-issuers) to correlate unsuspecting parties with the use of certain [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) which can violate privacy expectations that each entity might have regarding the use of those credentials. For example, what is expected by the [holder](https://w3c-ccg.github.io/vc-api/#dfn-holders) to be a private interaction between them and the [verifier](https://w3c-ccg.github.io/vc-api/#dfn-verifier) becomes one where the [issuer](https://w3c-ccg.github.io/vc-api/#dfn-issuers) is notified of the interaction.
>

> 検証者が特定の検証可能クレデンシャルについて発行者に連絡することは、プライバシーの悪習慣 と見なされる。 このプラクティスは「フォニ ング・ホーム」として知られており、検証可能クレデンシャルで表現される保有者、発行者、検証者、 および他の当事者間のプライバシーに対する期待の不一致をもたらす可能性がある。 フォニ ング・ホームによって、発行者は疑う余地のない当事者と特定の検証可能なクレデンシャルの 使用を関連付けることができ、そのようなクレデンシャルの使用に関して各エンティティが持 つプライバシーに対する期待に違反する可能性がある。 たとえば、保有者と検証者の間のプライベートなやり取りであると期待されていたものが、発行者にそのやり取りが通知されるものになる。
>

---

図2のStatus ServiceとVerifier Service間のやり取りでプライバシーを守る方法について記載されています。

> There are some interactions where contacting the [issuer](https://w3c-ccg.github.io/vc-api/#dfn-issuers) in a privacy-preserving manner upholds the privacy expectations of the [holder](https://w3c-ccg.github.io/vc-api/#dfn-holders). For example, contacting the [issuer](https://w3c-ccg.github.io/vc-api/#dfn-issuers) to get revocation status information in a privacy-respecting manner, such as through a status list that provides group privacy can be acceptable as long as the [issuer](https://w3c-ccg.github.io/vc-api/#dfn-issuers) is not able to single out which [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) is being queried based on the retrieval of the status list. For more information on one such mechanism see the [Bitstring Status List v1.0](https://www.w3.org/TR/vc-bitstring-status-list/) specification.
>

> プライバシーを保持する方法で発行者に連絡することが、保有者のプライバシーの 期待を維持するようなやりとりもある。 たとえば、グループ・プライバシーを提供するステータス・リストなど、プライバシーを 尊重する方法で発行者に連絡して失効ステータス情報を取得することは、ステータス・リストの 取得に基づいてどの検証可能なクレデンシャルが照会されているかを発行者が特定できない限り、容認 できる。 このような仕組みの詳細については、ビット文字列ステータス・リスト v1.0 仕様を参照のこと。
>

---

> [Verifiers](https://w3c-ccg.github.io/vc-api/#dfn-verifier) are urged to not "phone home" in ways that will create privacy violations. When retrieving content that is linked from a [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential), using mechanisms such as [Oblivious HTTP](https://datatracker.ietf.org/doc/html/draft-ietf-ohai-ohttp) and aggressively caching results can improve the privacy characteristics of the ecosystem.
>

> 検証者は、プライバシー侵害を引き起こすような方法で「電話ホーム」を行わないよう促される。 検証可能なクレデンシャルからリンクされているコンテンツを検索する場合、**Oblivious HTTP** などのメカニズムを使用し、結果を積極的に**キャッシュ**することで、エコシステムのプライバシー特性を改善できる。
>

[Oblivious HTTP](https://datatracker.ietf.org/doc/html/draft-ietf-ohai-ohttp)はIETF提案で、HTTPクライアントのIPアドレスを通信先や中継サーバーから隠すための技術です。

VCから（例えば `@context` プロパティなどから）リンクされたドキュメントをキャッシュすることが、なぜサブジェクトのプライバシー保護に繋がるのかは少々難しいですね。以下のようなシナリオでのプライバシー毀損を想定しているのだと思います。

1. Holder (= サブジェクト) がIssuerにVCを要求
2. Holderが即時にそのVC（またはそれを元にしたVP）をVerifierに供与
3. Verifierが即時にIssuerのドキュメントへアクセス
4. Issuerはアクセス元を解析することで、1.のHolderがどのVerifierとやり取りしているかを把握

## B. Security Considerations (セキュリティに関する考慮事項)

### B.1 Deletion (消去)

> The APIs provided by this specification enable the deletion of [verifiable credentials](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) and [verifiable presentations](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-presentation) from [storage services](https://w3c-ccg.github.io/vc-api/#storage-services). The result of these deletions and the side-effects they might cause are out of scope for this specification. However, implementers are advised to understand the various ways deletion can be implemented. There are at least two types of deletion that are contemplated by this specification.
>

> この仕様が提供するAPIは、ストレージサービスから検証可能なクレデンシャルと 検証可能なプレゼンテーションを削除することを可能にする。 これらの削除の結果と、それらが引き起こす可能性のある副作用は、 本仕様の範囲外である。 しかし、実装者は、削除を実装する様々な方法を理解することが望まれる。 この仕様では、少なくとも2種類の削除を想定している。
>

---

> **Partial deletion** marks a record for deletion but continues to store some or all of the original information. This mode of operation can be useful if there are audit requirements for all credentials and/or presentations over a particular time period, or if recovering an original credential might be a useful feature to provide.
>

> **部分削除**は、削除のためにレコードをマークするが、元の情報の一部またはすべてを保存し続 ける。 この操作モードは、特定の期間にわたるすべてのクレデンシャルおよび／またはプレゼンテーションに監査要件がある場合、または元のクレデンシャルを回復することが提供する有用な機能である場合に有用である。
>

たまに人々が「論理削除」と呼ぶやつですね。

---

> **Complete deletion** purges all information related to a given [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) or [verifiable presentation](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-presentation) in a way that is unrecoverable. This mode of operation can be useful when removing information that is outdated and beyond the needs of any audit or when responding to any sort of "[right to be forgotten](https://en.wikipedia.org/wiki/Right_to_be_forgotten)" request.
>

> **完全削除**は、所定の検証可能なクレデンシャルまたは検証可能なプレゼンテーションに関 連するすべての情報を回復不可能な方法で消去する。 この操作モードは、時代遅れで監査の必要を超えた情報を削除するときや、ある種の「忘れられる権利」要求に対応するときに有用である。
>

「忘れられる権利」はGDPRでも謳われているやつです。

---

> When deleting a [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential), handling of its status information needs to be considered. Some use cases might call for deletion of a particular [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) to also set the revocation and suspension bits of that [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential), such that any sort of status check for the deleted credential fails and use of the credential is halted.
>

> 検証可能なクレデンシャルを削除するときは、そのステータス情報の処理を考慮する必要がある。 使用例によっては、特定の検証可能なクレデンシャルの削除で、その検証可能なクレデンシャルの失効 および一時停止ビットも設定し、削除されたクレデンシャルに対するあらゆる種類のステータス・ チェックが失敗し、クレデンシャルの使用が停止されるようにすることを求める場合がある。
>

これは実装上かなり気をつけないとミスりそうなポイントですね。

---

> Given the scenarios above, implementers are advised to allow the system actions that occur after a delete to be configurable, such that system flexibility is sufficient to address any [verifiable credential](https://w3c-ccg.github.io/vc-api/#dfn-verifiable-credential) use case.
>

> 上記のシナリオを考慮すると、実装者は、システムの柔軟性が検証可能なクレデンシャルの使用 ケースに対処するのに十分であるように、削除後に発生するシステム・アクションを構成可能 にすることを推奨される。
>
