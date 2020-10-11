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
