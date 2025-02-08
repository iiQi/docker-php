#!/usr/bin/env bash

set -eux

yqBin="./yq"
extConfig="config/ext.yaml"
packageConfig="config/package.yaml"
suiteConfig="config/suite.yaml"
export VERSION DISTRO SUITE PHP_EXT extConfig packageConfig
get_select_ext() {
  if [ -z "$PHP_EXT" ]; then
    $yqBin '.default.[env(SUITE)] * .[env(VERSION)].[env(SUITE)] | .ext' "$suiteConfig"
  else
    printf "%s" "$PHP_EXT" | $yqBin 'split(",")'
  fi
}

get_ext() {
  get_select_ext | $yqBin '.
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

get_deps() {
  get_ext | $yqBin '
    [ .[] | select(has("deps")) | .deps.[env(DISTRO)][] ]
    | ([load(env(packageConfig)) | .[env(DISTRO)].build[]]) *+ .
    | unique | join(" ")
  '
}

install_ext() {
  conf=$*
  eval "$(
    printf "%s" "$conf" | \
    $yqBin -o=shell 'del(.needs)
                    | .option = (.option | map("--" + . | @sh) | join(" ") // "")
                    | .arg = (.arg // "")
                    '
  )"

  "install_ext_$type" "$name" "$arg" $option
}

install_ext_pecl() {
  name=$1
  arg=${2:-}

  printf "%b" "$arg" | pecl install "$name"
  docker-php-ext-enable "$name"
}

install_ext_builtin() {
  name=$1

  shift

  if [ -n "$*" ]; then
    docker-php-ext-configure "$name" "$@"
  fi

  docker-php-ext-install "$name"
}

pkg_cmd() {
  case "$DISTRO" in
   debian )
     printf "apt-get install -y --no-install-recommends {}"
    ;;
   alpine )
     printf "apk add --no-cache {}"
    ;;
  esac
}

build(){
  . "distro/$DISTRO.sh"

  # 修改源
  changeRepo

  savedMark="$(savedMark)"

  # 安装系统依赖
  installDeps $(get_deps)

  get_ext | $yqBin '.[] | del(.deps) | @json' | while IFS= read -r line; do
    install_ext "$line"
  done

  #清理pecl
  rm -rf /usr/local/lib/php/.channels/* /usr/local/lib/php/doc/* /usr/local/lib/php/test/* /tmp/pear

  groupadd -g 1000 www
  useradd -g 1000 -u 1000 -b /var -s /bin/bash www
  cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

  # 清理编译依赖
  clearDeps $savedMark

  PKG_CMD=$(pkg_cmd) $yqBin '.[env(DISTRO)].package[]
        | with( select(type == "!!str"); . = {"run": env(PKG_CMD) ,"name": .} | . = {"run":.run | sub("{}", parent.name)} )
        | .run
        ' "$packageConfig" | sh -e
}