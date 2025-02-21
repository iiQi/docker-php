#!/usr/bin/env sh

changeRepo() {
  sed -i 's#dl-cdn.alpinelinux.org#mirrors.aliyun.com#g' /etc/apk/repositories;
}

updateRepo() {
  apk update
}

savedMark() {
  return
}

installDeps() {
  apk add --no-cache --virtual .build-deps \
              $PHPIZE_DEPS \
              "$@"
}


clearDeps() {
  runDeps="$( \
              scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
                  | tr ',' '\n' \
                  | sort -u \
                  | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
          )"

  apk add --no-cache $runDeps
  apk del --no-network .build-deps
}

clearCache() {
  rm -rf /var/cache/apk/*
}