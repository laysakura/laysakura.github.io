## blogの場所

https://laysakura.github.io

## 記事作成の流れ

```bash
docker-compose up --build
```

で http://localhost:4000 でサーバが立つ。ホスト側の編集もリアルタイム反映してくれる。

1. 最新の `ready` ブランチから `article/xxx` ブランチを切り出す。
2. `hexo new '記事のタイトル'` で記事のひな形を生成し、エディタで記事を書く。
3. `git add source/_posts/ ; git commit ; git push origin article/xxx`
4. https://github.com/laysakura/laysakura.github.io で `article/xxx` から `ready` に向けたPRを作成し、マージ。

## デプロイ

```bash
docker exec -it laysakuragithubio_hexo_1 bash -c 'hexo clean && hexo deploy --generate'
```

GitHubで2FAをやっている場合は、認証時のパスワードは [Personal Access Tokens](https://github.com/settings/tokens) を使うこと。

## テーマ変更の流れ

git subtree で `themes/apollo` を作っている。

```bash
emacs  # themes/apollo/ 以下のファイルに変更を加える
git add themes/apollo/
git commit -m 'foobar'

cd ..

# このレポジトリへのpush
git push origin ready

# laysakura/hexo-theme-apollo レポジトリに feature/foobar ブランチとしてpush
git subtree push --prefix=themes/apollo git@github.com:laysakura/hexo-theme-apollo.git feature/foobar
```

https://github.com/laysakura/hexo-theme-apollo でPR & mergeしておく。
