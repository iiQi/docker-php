#!/usr/bin/env sh

changeRepo() {
  sed -i 's#http://deb.debian.org#https://mirrors.aliyun.com#g' /etc/apt/sources.list.d/debian.sources

  apt-get update
}

savedMark() {
  apt-mark showmanual
}

installDeps() {
  [ -z "$*" ] || apt-get install -y --no-install-recommends "$@"
}

clearDeps() {
  apt-mark auto '.*' > /dev/null
  [ -z "$*" ] || apt-mark manual "$@"

  find /usr/local -type f -name '*.so' -exec ldd '{}' ';' \
    | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
    | sort -u \
    | xargs -r dpkg-query --search \
    | cut -d: -f1 \
    | sort -u \
    | xargs -r apt-mark manual \
  ;

  apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
}

clearCache() {
  rm -rf /var/lib/apt/lists/*
}