---
title: Rustでmockするならmockallで決まり！・・・でよろしいでしょうか？
id: rust-mockall
tags:
  - Rust
date: 2021-04-25 14:39:42
---

Rustで DI (Dependency Injection)、してますか？
今日話題にするのはドメイン層でインターフェイスを定義してインフラ層でその実装を書くやつです。
例えばドメイン層で `trait UserRepository` を書いて、インフラ層で `struct UserRepositoryImpl` するやつです。

テストを書くとき、 `struct UserRepositoryImpl` はDBアクセスなどしてしまうので取り回しが悪いから、mock を作って fixture を入出力したいことありますよね。
Rustでそういうことやるなら mockall がオススメだよという記事です。

{% githubCard user:asomers repo:mockall %}

そんなに不満はないのですが、もしベターなやり方があったら記事末尾のコメントや[Twitter](https://twitter.com/laysakura)やらもらえたら嬉しいです。

前職のFOLIO時代の同僚で現CADDiの [むらみんさんの記事](https://caddi.tech/archives/2331) に

> 外部通信のような比較的大きい副作用が絡むテストに於いて テストダブルを差し込むことは可能なのですが、かなりの労力が必要になる印象を持っています。

と書いていたのを今更ながら発見して、自分はこうしてるけど皆はどうしてるんだろ？と思って筆（キーボード）を取りました。

<!-- more -->

## 目次
<!-- toc -->

## mockall 紹介の題材

{% githubCard user:laysakura repo:mockall-example-rs %}

mockallを紹介するためにクリーンアーキテクチャなアプリケーションを用意しました。
簡易的なメアド帳です。動かし方は [README.md](https://github.com/laysakura/mockall-example-rs) に書いています。

## コードレベルのアーキテクチャ

[Multi-package project](https://doc.rust-lang.org/edition-guide/rust-2018/cargo-and-crates-io/cargo-workspaces-for-multi-package-projects.html) です。

- `domain` : Enterprise Business Rules
  - Entity, Value Object, リポジトリインターフェイスを置いています。
- `app` : Application Business Rules
  - UseCaseと、 `tests` 以下にUseCaseのブラックボックステストを置いています。
    **ここのテストで、mockall で自動生成したリポジトリインターフェイスのモックを使っています。**
- `interface-adapter` : Interface Adapters
  - ControllerやDTO (Data Transfer Object) を置いています。
- `infra` : Frameworks & Drivers
  - UIとしてCLI実装を置いています。
  - リポジトリ実装として、永続化層にYAMLファイルを使ったものを置いています。

## mockall の使い方について解説

`app/tests` のテストにおいてモックを使っているので、 `app` と `domain` 層だけの解説になります。
`interface-adapter` 層と `infra` 層は興味があればコードを見てみてください。

### UserRepository, UseCase 実装まで

まず、 `User` の一覧・作成・更新を担当する `UserRepository` を作ります。永続化の方法などは `infra` 層に任せたいので、 `domain` 層に trait として作ります。

```rust domain/src/user/user_repository.rs
pub trait UserRepository {
    fn list(&self) -> Vec<User>;

    /// # Failures
    ///
    /// - `MyErrorType::Duplicate` : when user with given ID already exists.
    fn create(&self, user: User) -> MyResult<()>;

    /// # Failures
    ///
    /// - `MyErrorType::NotFound` : when user with given ID (inside User) does not exist.
    fn update(&self, user: User) -> MyResult<()>;
}
```

エラー型の詳細はコードを読んでみてください。シンプルなインターフェイスです。

ユースケースにおいて、このアプリケーションの機能を列挙していきます。

```rust app/src/use_case.rs
#[derive(Clone, Eq, PartialEq, Ord, PartialOrd, Hash, Debug)]
pub struct UseCase;

impl UseCase {
    pub fn search_users(
        &self,
        first_name: Option<&UserFirstName>,
        last_name: Option<&UserLastName>,
        email: Option<&EmailAddress>,
    ) -> Vec<User> {
        todo!()
    }

    pub fn add_user(&self, user: User) -> MyResult<()> {
        todo!()
    }

    pub fn update_user_by_email(
        &self,
        email: &EmailAddress,
        first_name: Option<UserFirstName>,
        last_name: Option<UserLastName>,
    ) -> MyResult<()> {
        todo!()
    }
}
```

ユースケースの各種機能を実現する一連の処理を記述すると、リポジトリを使うことになります。
例として `UseCase::search_users()` の実装をなんとなく書いてみましょう。

```rust app/src/use_case.rs
#[derive(Clone, Eq, PartialEq, Ord, PartialOrd, Hash, Debug)]
pub struct UseCase;

impl UseCase {
    pub fn search_users(
        &self,
        first_name: Option<&UserFirstName>,
        last_name: Option<&UserLastName>,
        email: Option<&EmailAddress>,
    ) -> Vec<User> {
            let users = // ... `UserRepository::list()` を叩いて User を全件取得
            let users = users
                .into_iter()
                .filter(|user| {
                    // first_name, last_name, email の引数を使い、特定の条件に合うものにだけ絞り込み
                    // ...
                })
                .collect();
            users
    }

    // ...
}
```

`UserRepository::list()` を呼び出す必要がありますね。
そのためには `UseCase` が `UserRepository` のインスタンスを得られる必要があります。
より正確には、 `UserRepository` は trait なので、型パラメーターを使って `<R: UserRepository>` のインスタンスが必要です。
ここでは `struct UseCase` のフィールドとして持たせることにします。

```rust app/src/use_case.rs
#[derive(Clone, Eq, PartialEq, Ord, PartialOrd, Hash, Debug)]
pub struct UseCase<'r, R: UserRepository> {
    user_repo: &'r R,
}
```

`UserRepository` の各関連関数は `&self` しか取らない (`self` を取らない) ので、 `UseCase` が持つのは `<R: UserRepository>` の所有権ではなく参照で十分です。
結果として `'r` というライフタイムパラメータも必要になってちょっと煩わしいですが、これがRustです。
Tipsですが、 `Rc` とか使うと struct の中のライフタイムパラメータを避けられるのでライフタイムパラメータで頭痛がしてきたときは使ってしまいます。

さて、 `UseCase` が `user_repo` フィールドを持つようになったので、 `UseCase::search_users` 実装のコメントアウトしていた部分が書けます。

```rust app/src/use_case.rs
#[derive(Clone, Eq, PartialEq, Ord, PartialOrd, Hash, Debug)]
pub struct UseCase;

impl UseCase {
    pub fn search_users(
        &self,
        first_name: Option<&UserFirstName>,
        last_name: Option<&UserLastName>,
        email: Option<&EmailAddress>,
    ) -> Vec<User> {
            let users = self.user_repo.list();  // ここが書けた
            let users = users
                .into_iter()
                .filter(|user| {
                    // first_name, last_name, email の引数を使い、特定の条件に合うものにだけ絞り込み
                    // ...
                })
                .collect();
            users
    }

    // ...
}
```

### Tips: domain層の trait を関連型でまとめた trait を作っておくと、型パラメータの数が減らせて便利

mockall の紹介という意味では不要なのですが、Rustでクリーンアーキテクチャするときに個人的に便利だと思っているTipsです。

今回 `domain` 層に `trait UserRepository` を置いてありますが、実際のアプリケーションだともっとたくさんの trait が出てくるはずです。
`infra` 層ではその実装が全部出揃うので苦労しませんが、 `domain` , `app` , `interface-adapter` では `domain` 層の trait の型パラメーターだらけになるの、経験があるのではないでしょうか？

```rust
struct UseCase<UserRepo: UserRepository, ItemRepo: ItemRepository, ...> {
    ...
}
```

みたいな感じで...

型パラメーターを一本化するために、おまとめ trait を `domain` 層に置いておくと便利に感じます。このアプリケーションのコードにおいては以下のようなものを置いています。

```rust domain/src/repositories.rs
/// UseCaseなどの各所で都度同じような型パラメータを定義しないで済むように、リポジトリtraitをこのtraitの関連型としてまとめる。
/// 例えば、 `ARepository` と `BRepository` を両方使う `XUseCase` があった場合、この trait がなければ
///  `XUseCase<A: ARepository, B: BRepository>` と2つの型パラメーターが必要なところ、
/// `XUseCase<R: Repositories>` の1つで済む。
pub trait Repositories {
    type UserRepo: UserRepository;

    fn user_repository(&self) -> &Self::UserRepo;
}
```

今回は使用している trait が `UserRepository` 1つなので若干ありがたみに書けますが、コメントにお気持ちを書いています。
有用そうなら真似してみてください。

### UseCase 実装を完成させてテストを書こうとしてみる

`UseCase` のコンストラクタはこのように書けます。

```rust app/src/use_case.rs
impl<'r, R: Repositories> UseCase<'r, R> {
    pub fn new(repositories: &'r R) -> Self {
        Self {
            user_repo: repositories.user_repository(),
        }
    }

    // ...
}
```

その他の関数も含めて完成させたものが [app/src/use_case.rs](https://github.com/laysakura/mockall-example-rs/blob/master/app/src/use_case.rs) です。
ユースケースは複雑度も高い部分なので念入りにテストしたいですね。今回は `app/tests` 以下に、 `UseCase::search_users()` 関数のブラックボックステストを書くことにします。

```rust app/tests/test_use_case_search_users.rs
#[test]
fn test_with_blank_repository() {
    let repositories = // ... 先程 Tips で紹介したおまとめ trait の `Repositories` の実装をインスタンス化したもの
    let use_case = UseCase::new(&repositories);

    assert_eq!(use_case.search_users(None, None, None), vec![]);
    assert_eq!(
        use_case.search_users(Some(&UserFirstName::new("a")), None, None),
        vec![]
    );
    assert_eq!(
        use_case.search_users(None, Some(&UserLastName::new("a")), None),
        vec![]
    );
    assert_eq!(
        use_case.search_users(None, None, Some(&EmailAddress::new("a@b"))),
        vec![]
    );
}
```

「 `UserRepository` が空っぽの場合はどんなクエリを投げても検索結果は空」ということをテストしています。
ここで空っぽの `UserRepository` を作るためにモックを作りたいですね。
愚直にやるとこんな感じでしょうか。

```rust
struct EmptyUserRepository;

impl UserRepository for EmptyUserRepository {
    fn list(&self) -> Vec<User> {
        vec![]
    }

    fn create(&self, user: User) -> MyResult<()> {
        unimplemented!()
    }

    fn update(&self, user: User) -> MyResult<()> {
        unimplemented!()
    }
}
```

そしてこれを使い、おまとめ trait 実装も作ります。

```rust
pub struct EmptyRepositories {
    user_repo: EmptyUserRepository,
}

impl Repositories for EmptyRepositories {
    type UserRepo = EmptyUserRepository;

    fn user_repository(&self) -> &Self::UserRepo {
        &self.user_repo
    }
}

impl EmptyRepositories {
    pub fn new(user_repo: EmptyUserRepository) -> Self {
        Self { user_repo }
    }
}
```

これがあれば、テストコードのコメントアウト部分も埋められます。

```rust app/tests/test_use_case_search_users.rs
#[test]
fn test_with_blank_repository() {
    let user_repo = EmptyUserRepository;
    let repositories = EmptyRepositories::new();
    let use_case = UseCase::new(&repositories);

    assert_eq!(use_case.search_users(None, None, None), vec![]);
    // ...
```

これでできる！できるのですが！以下の点が気に掛かります。

- `UseCase::search_users()` が内部的に叩いていない `UserRepository::create()` , `UserRepository::update()` にまで `unimplemented!()` を書いて回る必要がある。
- やりたい動作（今回は「空っぽのユーザーリストを返す」）の数だけモックの `struct` を作る必要がある。
  - しかも今回はおまとめ trait も作っているので、おまとめ trait の数も増える。

mockall ならこれらの悩みを解決してくれます。

### mockall を使って `UserRepository::list()` をモックする

詳細な使い方は [ドキュメント](https://docs.rs/mockall/0.9.1/mockall/) を参照してください。ここでは自分の使い方を小ネタ含めてお伝えします。

先程は `struct EmptyUserRepository` を手書きしましたが、mockall を使うと trait にアノテーションを書けば `MockUserRepository` をマクロで自動実装してくれます。

```toml domain/Cargo.toml
# ...

[dependencies]
mockall = {version = "0.9"}
```

```rust domain/src/user/user_repository.rs
#[mockall::automock]
pub trait UserRepository {
    fn list(&self) -> Vec<User>;

    fn create(&self, user: User) -> MyResult<()>;

    fn update(&self, user: User) -> MyResult<()>;
}
```

自動実装された `MockUserRepository` をおまとめ trait に設定します。モックの挙動は都度自由に差し替えられるので、今回は `EmptyRepositories` という挙動を表す名前はやめて、 `TestRepositories` という汎用的な名前にします。

```rust
pub struct TestRepositories {
    user_repo: TestUserRepository,
}

impl Repositories for TestRepositories {
    type UserRepo = MockUserRepository;

    fn user_repository(&self) -> &Self::UserRepo {
        &self.user_repo
    }
}

impl EmptyRepositories {
    pub fn new(user_repo: MockUserRepository) -> Self {
        Self { user_repo }
    }
}
```

`TestRepositories` , `MockUserRepository` を使ってテストコ−ドを書いていきます。

```rust app/tests/test_use_case_search_users.rs
use domain::user::user_repository::MockUserRepository;

#[test]
fn test_with_blank_repository() {
    let user_repo = MockUserRepository::new();
    let repositories = TestRepositories::new();
    let use_case = UseCase::new(&repositories);

    assert_eq!(use_case.search_users(None, None, None), vec![]);
    assert_eq!(
        use_case.search_users(Some(&UserFirstName::new("a")), None, None),
        vec![]
    );
    // ...
}
```

これを実際に走らせると、 `MockUserRepository::list(): No matching expectation found` というランタイムエラーになります。
これは「 `list()` 関数のモック挙動が挿されていないぞ」という意味です。
空っぽのユーザーリストを返す挙動を挿しましょう。 **テストコードのどこでも、クロージャーを使って挙動を差し替えられる** のが便利ポイントです。

```rust app/tests/test_use_case_search_users.rs
use domain::user::user_repository::MockUserRepository;

#[test]
fn test_with_blank_repository() {
    let mut user_repo = MockUserRepository::new();
    user_repo.expect_list().returning(|| vec![]);  // expect_list() 関数で、 list() 関数のモック挙動をクロージャーで挿し込む

    let repositories = TestRepositories::new();
    let use_case = UseCase::new(&repositories);

    assert_eq!(use_case.search_users(None, None, None), vec![]);
    assert_eq!(
        use_case.search_users(Some(&UserFirstName::new("a")), None, None),
        vec![]
    );
    // ...
}
```

これでテストケースの1個目が完成です。

### Fixture を使って複数の User を返すリポジトリのモック実装を作る

```rust
MockUserRepository::new().expect_list().returning(|| /* お好みのUserリスト */);
```

の形式でいろいろな状態のリポジトリを簡単にモック実装できることがを紹介しました。
いろいろな状態のリポジトリを作るには色々な `User` が必要なので、fixture を作っておくと便利です。

実際に作った [fixture はこちら](https://github.com/laysakura/mockall-example-rs/blob/master/app/tests/fixture/mod.rs)です。
`User` を変数の形で定義するのではなく、 `User` を返す関数を定義しているのがともすると特徴的に感じるかと思いますが、以下のような理由です。

- Rustの基本機能でグローバル変数のようなものを作ろうとすると `const` か `static` を使うが、いずれも基本的には `User` のようなプリミティブではない型を定義できない。
- [once_cell](https://docs.rs/once_cell/1.7.2/once_cell/) などを使えば `static` でグローバル変数を作れるが、mockall が提供する `.expect_YOUR_METHOD().returning(|| /* ... */)` のクロージャーの中で `static` 変数を使おうとすると、 `Copy` 実装がされていない限りは都度 `.clone()` していかないと使えなかったりして取り回しが面倒。

このように些細な理由ではありますが、 fixture は関数形式で作っておくことをおすすめします。

横道に逸れましたが、この fixture を使って「ユーザーを3種類返すリポジトリ」のモック実装をし、その環境における `UseCase::search_users()` の挙動のテストをします。

```rust app/tests/test_use_case_search_users.rs
use domain::user::user_repository::MockUserRepository;

// ...

#[test]
fn test_with_3users_repository() {
    let mut user_repo = MockUserRepository::new();
    user_repo
        .expect_list()
        .returning(|| vec![User::fx1(), User::fx2(), User::fx3()]);

    let repositories = TestRepositories::new(user_repo);
    let use_case = UseCase::new(&repositories);

    assert_eq!(use_case.search_users(None, None, None), vec![]);
    assert_eq!(
        use_case.search_users(Some(&UserFirstName::fx1()), None, None),
        vec![User::fx1()]
    );
    assert_eq!(
        use_case.search_users(Some(&UserFirstName::fx2()), None, None),
        vec![User::fx2(), User::fx3()]
    );
    assert_eq!(
        use_case.search_users(None, None, Some(&EmailAddress::fx1())),
        vec![User::fx1()]
    );
    assert_eq!(
        use_case.search_users(
            Some(&UserFirstName::fx2()),
            None,
            Some(&EmailAddress::fx2())
        ),
        vec![User::fx2()]
    );
}
```

### モック実装が必要かを依存先に選ばせる

先程 `domain` において

```rust domain/src/user/user_repository.rs
#[mockall::automock]
pub trait UserRepository {
    fn list(&self) -> Vec<User>;

    fn create(&self, user: User) -> MyResult<()>;

    fn update(&self, user: User) -> MyResult<()>;
}
```

と書きましたが、この書き方だと `domain` crate に依存する crate は、テストも書かないかもしれないのに `MockUserRepository` が見えた状態になってしまいます。
気になる場合は [Cargo の Features](https://doc.rust-lang.org/cargo/reference/features.html) を使って制御すると良いでしょう。

```toml domain/Cargo.toml
# ...

[features]
mock = ["mockall"]

[dependencies]
mockall = {version = "0.9", optional = true}
```

```toml app/Cargo.toml
# ...

[dependencies]
domain = {path = "../domain"}  # app のテスト以外では Mock 実装不要だが

[dev-dependencies]
domain = {path = "../domain", features = ["mock"]}  # テストでは必要
```

```rust domain/src/user/user_repository.rs
#[cfg_attr(feature = "mock", mockall::automock)]
pub trait UserRepository {
    // ...
}
```

このようにすれば、 `app` において `dev-dependencies` が有効になる `cargo test` のときなどだけ `MockUserRepository` がリンクされます。

## おわりに

今回は mockall の使い方の中でも、

- 引数を取らない関数のモック
- 自分自身で実装した trait にアノテーションを書く形式の自動モック実装

を紹介しました。この他に使ったことのある便利機能として、

- [引数を取る関数について、「呼び出し時に引数はこの値にセットされているはずだ」と assert するモック](https://docs.rs/mockall/0.9.1/mockall/#matching-arguments)
- [自分でいじれない crate の中にある trait をモックする](https://docs.rs/mockall/0.9.1/mockall/#external-traits)

などありますので、ドキュメントを一読いただきよろしければ使ってみてください。
