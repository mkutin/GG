#!/bin/sh

# Создаем ключ
# ssh-keygen -t rsa -C "your_email@example.com"
# Переносим публичный ключ на сервер
# cat /hdd2/id_rsa.pub >> ./.ssh/authorized_keys
# chmod 700 ./.ssh/authorized_keys

# --- Config ---
RemoteSshUsername='sub1319_15'
RemoteIp='62.213.111.107'
GitRepositoryName='petrik.ru'
# --------------

cd /tmp
rm -rf site_checkout
git clone git@github.com:ifrogmedia/$GitRepositoryName.git site_checkout
cd site_checkout
git checkout master
rm -rf .git
rm .gitignore
#
rsync -zr -e ssh . $RemoteSshUsername@$RemoteIp:httpdocs
cd ..
rm -rf site_checkout