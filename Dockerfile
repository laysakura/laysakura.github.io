FROM node:13.8.0

# hexo-deployer-git でタイムゾーンに応じて日付またぎの際にURLが変わってしまうので、JST固定。
RUN rm /etc/localtime \
    && echo Asia/Tokyo > /etc/timezone \
    && dpkg-reconfigure -f noninteractive tzdata

# https://qiita.com/hikaruna/items/0bc1e97e8d254f4c27e7
# に記載の方法を使い、node_modules を / に配置する。
WORKDIR /
COPY package.json package-lock.json /
RUN npm install && npm cache clean --force
ENV PATH $PATH:/node_modules/.bin

# セキュリティのためappユーザに切り替える
RUN useradd --user-group --create-home --shell /bin/false app
ENV HOME=/home/app
USER app
WORKDIR $HOME/laysakura.github.io

CMD ["hexo", "server"]
