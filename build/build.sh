#!/usr/bin/env bash

set -eux

extConfig="config/ext.yaml"
packageConfig="config/package.yaml"
suiteConfig="config/suite.yaml"

YQ=${YQ:-"./yq"}
MAJOR_VERSION=${VERSION%%.*}
MINOR_VERSION=${VERSION%.*}

export DISTRO SUITE VERSION MAJOR_VERSION MINOR_VERSION PHP_EXT extConfig packageConfig

getSuite() {
  $YQ '.default.[env(SUITE)] * .[env(MINOR_VERSION)].[env(SUITE)] * .[env(VERSION)].[env(SUITE)]' "$suiteConfig"
}

getSelectExt() {
  if [ -z "$PHP_EXT" ]; then
    getSuite | $YQ '.ext'
  else
    printf "%s" "$PHP_EXT" | $YQ 'split(",")'
  fi
}

getExt() {
  getSelectExt | $YQ '.
    |= with_entries(
        with( .value; select(type == "!!str") | parent.key = . | . = {"name": .})
        | .key = .value.name
        | with(.value; select(.option) | .input_option = .option | del(.option))
        | .value.select = true
      )
    | load(env(extConfig)) *d .
    | .
    |= with_entries( with(.value; select(.input_option) | .option = .input_option | del(.input_option)) )
    | . = {"ext": .}
    | .needs = ( [ .ext.* | select (.select == true) | .needs[] ] | unique )
    | .needs |= with_entries( .key = .value | .value = {"name": .key, "select": true} )
    | .needs *d .ext
    | filter(.select == true)
    | map(del(.select))
  '
}

getDeps() {
  getExt | $YQ '
    [ .[] | select(has("deps")) | .deps.[env(DISTRO)][] ]
    | ([load(env(packageConfig)) | .[env(DISTRO)].build[]]) *+ .
    | unique | join(" ")
  '
}

installExt() {
  conf=$*
  eval "$(
    printf "%s" "$conf" | \
    $YQ -o=shell 'del(.needs)
                    | .option = (.option | map("--" + . | @sh) | join(" ") // "")
                    | .arg = (.arg // "")
                    '
  )"
  type=$(echo "$type" | awk '{ print toupper(substr($0,1,1)) tolower(substr($0,2)) }')

  "installExt${type}" "$name" "$arg" $option
}

installExtPecl() {
  name=$1
  arg=${2:-}

  printf "%b" "$arg" | pecl install "$name"
  docker-php-ext-enable "$name"
}

installExtBuiltin() {
  name=$1

  shift

  if [ -n "$*" ]; then
    docker-php-ext-configure "$name" "$@"
  fi

  docker-php-ext-install "$name"
}

pkgCmd() {
  case "$DISTRO" in
   debian )
     printf "apt-get install -y --no-install-recommends {}"
    ;;
   alpine )
     printf "apk add --no-cache {}"
    ;;
  esac
}

getPackage() {
  PKG_TYPE=$1

  export PKG_TYPE

  $YQ '.[env(DISTRO)].[env(PKG_TYPE)] *+ .default.[env(PKG_TYPE)] | .[]
        | with( select(type == "!!str"); . = {"run": env(PKG_CMD) ,"name": .} | . = {"run":.run | sub("{}", parent.name)} )
        | .run
        ' "$packageConfig"
}

build(){
  . "distro/$DISTRO.sh"

  # 修改源
  changeRepo

  savedMark="$(savedMark)"

  # 安装系统依赖
  installDeps $(getDeps)

  getExt | $YQ '.[] | del(.deps) | @json' | while IFS= read -r line; do
    installExt "$line"
  done

  #清理pecl
  rm -rf /usr/local/lib/php/.channels/* /usr/local/lib/php/doc/* /usr/local/lib/php/test/* /tmp/pear

  groupadd -g 1000 www
  useradd -g 1000 -u 1000 -b /var -s /bin/bash www
  cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

  # 清理编译依赖
  clearDeps $savedMark

  PKG_CMD=$(pkgCmd) getPackage "package" | sh -e

  # 清理缓存
  clearCache
}