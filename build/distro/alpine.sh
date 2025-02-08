#!/usr/bin/env sh

changeRepo() {
  sed -i 's#dl-cdn.alpinelinux.org#mirrors.aliyun.com#g' /etc/apk/repositories;
}

savedMark() {
  return
}

installDeps() {
  apk add --no-cache --virtual .build-deps \
              $PHPIZE_DEPS \
              "$@"
}

installPackage() {
  [ -z "$*" ] || apk add --no-cache "$@"


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
#  apk add --no-cache \
#          bash
}

clearCache() {
  return
}