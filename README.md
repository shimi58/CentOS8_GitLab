# DockerForWindowsでGitLab･Mattermostを構築する

## はじめに

　MattermostAPIを使って色々試してみたいと思い、サクッとGitLab環境を構築しようと思ったら思いの外ハマりまくったので、やったことを残しておきます。
やりたいこととしては、DockerForWindowsを用いてGitLab環境を構築する、です。

## 動くもの

GitHub上に置いています。(https://github.com/shimi58/CentOS8_GitLab)   
ただし、Mattermost設定に関しては構築する毎に変わってくるので後述の手順が必要。


|      動作確認環境      |   バージョン   |
| ---------------------- | -------------- |
| Windows10 Home Edition | バージョン2004 |
| Docker for Windows     | 2.4.0.0        |

※GitLabのDockerは、DockerForWindows公式サポート外なんですよねぇ。。ポートフォワーディングがうまく行かず(80→80はうまくいくけど、8080→80とかだと繋がらなくなる)、そういうことかなぁと。
    ![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/384317/e2f2f82a-e23d-4f18-c936-93c496637c27.png)


## 環境構築

### Docker上でCentOS8構築

Dockerfileに記述していきます。  
出来上がりは以下のとおり。

```Dockerfile
FROM centos:8

# 日本語化
RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial && \
    dnf -y upgrade && \
    dnf -y install glibc-locale-source && \
    dnf clean all && \
    localedef -f UTF-8 -i ja_JP ja_JP.UTF-8 && \
    ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

# Gitlabインストール用にLANGをC.UTF-8に変更しておく
ENV LANG="C.UTF-8" \
    LANGUAGE="ja_JP:ja" \
    LC_ALL="ja_JP.UTF-8"

# rootパスワード設定
RUN echo "root:root" | chpasswd

# =====
# BASE packages
# =====
RUN dnf install -y  openssl openssl-devel openssh openssh-server wget sudo unzip  which tree git firewalld

# =====
# GitLab CEをインストール
# =====
RUN curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash

RUN dnf install -y gitlab-ce

```

```docker-compose.yml
version: '3'
services:
  centos8:
    container_name: "centos8"
    build: ./
    tty: true
    privileged: true
    command: /sbin/init   
    ports:
      - "2222:22"
      - "9080:9080" #GitLab用
      - "9081:9081" #GitLabMattermost用
      - '10443:443'
    volumes:
      # 公式に則って永続化
      - './srv/gitlab/config:/etc/gitlab'   #GitLab定義ファイルを配置
      - './srv/gitlab/logs:/var/log/gitlab' #GItLabログファイル出力
      - './srv/gitlab/data:/var/opt/gitlab' #GItLabデータ格納

```

#### 補足

- 日本語環境設定

    ```
    # 日本語化
    RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial && \
        dnf -y upgrade && \
        dnf -y install glibc-locale-source && \
        dnf clean all && \
        localedef -f UTF-8 -i ja_JP ja_JP.UTF-8 && \
        ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

    # Gitlabインストール用にLANGをC.UTF-8に変更しておく
    ENV LANG="C.UTF-8" \
        LANGUAGE="ja_JP:ja" \
        LC_ALL="ja_JP.UTF-8"
    ```

    こちら(https://qiita.com/polarbear08/items/e5c00869c7566db5f7b8 )を参考にさせていただきました。
    LANGをC.UTF-8にしておかないと、｢gitlab-ctl reconfigure｣のDBマイグレーションあたりで止まるので要注意。

- GitLab CEをインストール

    ```cmd
    RUN curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash

    RUN dnf install -y gitlab-ce
    ```

    こちらは公式にある手順の通りです。(公式だとサンプルはgitlab-eeになっているので注意)

- データ永続化

    ```docker-compose.yml
        volumes:
          # 公式に則って永続化
          - './srv/gitlab/config:/etc/gitlab'   #GitLab定義ファイルを配置
          - './srv/gitlab/logs:/var/log/gitlab' #GItLabログファイル出力
          - './srv/gitlab/data:/var/opt/gitlab' #GItLabデータ格納
    ```

    こちらを設定しておくと、コンテナを落としてもデータが保持された状態になる


### 構築手順

1. 前述のDockerfile、docker-compose.ymlを任意のディレクトリに配置する

1. 配置したディレクトリに移動し、コンテナを起動する

    ```cmd
    docker-compose up -d
    ```

1. gitlab.rbを所定のフォルダに配置する

    ```
    srv
    └─gitlab
        ├─config
        │      gitlab.rb
        │
        ├─data
        └─logs
    ```

    このファイルはこちら(https://github.com/shimi58/CentOS8_GitLab )に。  
    ※最初は後述のMattermostの設定をコメントアウトしたほうがいいかも。(Applicationsに出てこなくなったり、手順通りできなくなる可能性あり)

1. GitLabのポートを設定する

    ```gitlab.rb
    external_url 'http://localhost:9080'
    ```

1. GitLab Mattermostを有効化する

    ```gitlab.rb
    mattermost_external_url 'http://localhost:9081'
    mattermost['enable'] = true
    ```

1.  コンテナにログインする

    ```cmd
    docker exec -it centos8 bash
    ```

    ※DockerForWindowsのCLIからログインすると、LANG設定まわりが反映されないので、powershellからログインしている
        ![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/384317/9141cfbe-74b4-cf8c-1cbe-2066b429fde8.png)
        ※LANG設定が期待通り


1. GitLab設定を反映する

    ```cmd
    sudo /opt/gitlab/embedded/bin/runsvdir-start &
    gitlab-ctl reconfigure
    ```

    ※｢gitlab-ctl reconfigure｣単独だと途中で止まるので、こちら(https://teratail.com/questions/229107 )を参考に、runsvdir-start をバックグラウンド実行してから reconfigure。  
    初回は5分弱はかかります。

1. 反映が終わったら、GitLabにアクセス

    ```url
    http://localhost:9080
    ```
    ※ログインできることを確認する

    - このタイミングでMattermostも表示できる
    
        ```url
        http://localhost:9081
        ```

#### 補足

- 以降はMattermostのSSO連携の手順となる

1. パスワード初期設定を終え、ログイン

    ![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/384317/67e60359-d01a-9722-eaf5-410bdbf1def6.png)
    ※初期IDは｢root｣

1. Mattermostの設定を確認する
    - ｢Admin Area｣→｢Applications｣に移動
    - すでにMattermost用の定義があればそれを使用し、なければ新規に作成する(手順通りやると最初から項目が出てくるはず、、)

    ![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/384317/cd6569dc-ce61-20c6-2a26-7bd1f816dfe6.png)

    ※こちら(https://qiita.com/TomoyukiSugiyama/items/0d828ee2325095a7f247 )を参考にさせていただきました。


1.  上述で確認した、｢Application ID｣、｢Secret｣をgitlab.rbに反映する
    あわせて、必要な設定を追加する

    ```gitlab.rb
    mattermost['gitlab_enable'] = true #SSO有効化
    mattermost['gitlab_id'] = "5e7f43cdf588e92c8b0ca589832c64dd5094969c5848667a09e50ffe4834c065"      #Application ID
    mattermost['gitlab_secret'] = "23791f7219f6782f38c9c1f462c5e715e88216ee13d3513a122dc9c302ba130b"  #secret
    mattermost['gitlab_auth_endpoint'] = "http://localhost:9080/oauth/authorize" #GitLabのURLを記載する
    mattermost['gitlab_token_endpoint'] = "http://localhost:9080/oauth/token"    #GitLabのURLを記載する
    mattermost['gitlab_user_api_endpoint'] = "http://localhost:9080/api/v4/user" #GitLabのURLを記載する
    ```

1. GitLab設定を反映する

    ```cmd
    gitlab-ctl reconfigure
    ```
1. Mattermostから、｢Sign in with GitLab｣を選択し、ログインする

    ![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/384317/2226c3bb-3c30-5a77-b127-4353df9d0721.png)
    ※うまく疎通が通ったらこの画面に移行するので、｢Anthorize｣を選択。

1. Mattermost画面に遷移することを確認する

    ![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/384317/b497b933-ee6a-4d83-25dc-afff77c05731.png)


## さいごに


　今回構築したGitLabですが、COREi7、メモリ16Gでもめちゃんこ重たいです。
    ![image.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/384317/20c393f6-6894-23de-5efd-2f7025b2008b.png)
    ※CPUメモリともにめっちゃ頑張ってます。。
ということで、ようやくMattermostAPIが触れる下地ができたので、次はAPI触っていきたいと思います。
