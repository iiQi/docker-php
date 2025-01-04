#!/usr/bin/env bash

changeRepo() {
  sed -i 's#http://deb.debian.org#https://mirrors.aliyun.com#g' /etc/apt/sources.list.d/debian.sources
  sed -i 's/^# \(export\|alias\)/\1/g' /root/.bashrc
}

savedMark() {
  apt-mark showmanual
}

installDeps() {
  deps=$*

  [ -z "$deps" ] || apt-get update && apt-get install -y --no-install-recommends $deps
}

clearDeps() {
  savedAptMark=$*
  apt-mark auto '.*' > /dev/null
  [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark

  find /usr/local -type f -name '*.so' -exec ldd '{}' ';' \
    | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
    | sort -u \
    | xargs -r dpkg-query --search \
    | cut -d: -f1 \
    | sort -u \
    | xargs -r apt-mark manual \
  ;

  apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

  rm -rf /var/lib/apt/lists/*
  rm -rf /tmp/pear
}