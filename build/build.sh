#!/usr/bin/env bash

set -eux

extConfig="config/ext.yaml"
packageConfig="config/package.yaml"
suiteConfig="config/suite.yaml"
runtimeConfig="config/runtime.yaml"

YQ=${YQ:-"./yq"}
MAJOR_VERSION=${VERSION%%.*}
MINOR_VERSION=${VERSION%.*}

export DISTRO SUITE VERSION MAJOR_VERSION MINOR_VERSION PHP_EXT extConfig packageConfig

runtimeConfig() {
  if [ -f "$runtimeConfig" ]; then
    $YQ ".$1" "$runtimeConfig"
  fi
}

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

mergeExtNeeds() {
  $YQ '.
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

getExt() {
  getSelectExt | mergeExtNeeds
}

getDevExt() {
  getSuite | $YQ '.dev' | mergeExtNeeds
}

mergeDeps() {
  $YQ '
    [ .[] | select(has("deps")) | .deps.[env(DISTRO)][] ]
    | ([load(env(packageConfig)) | .[env(DISTRO)].build[]]) *+ .
    | unique | join(" ")
  '
}

getDeps() {
  getExt | mergeDeps
}

getDevDeps() {
  getDevExt | mergeDeps
}

installExt() {
  eval "$(
    printf "%s" "$1" |
      $YQ -o=shell 'del(.needs)
                    | .option = (.option | map("--" + . | @sh) | join(" ") // "")
                    | .arg = (.arg // "")
                    | .enable = (.enable // "yes")
                    '
  )"
  type=$(echo "$type" | awk '{ print toupper(substr($0,1,1)) tolower(substr($0,2)) }')

  export option arg enable

  "installExt${type}" "$name"
}

installExtPecl() {
  name=$1

  printf "%b" "$arg" | pecl install "$name"
  if [ "yes" = "$enable" ]; then
    docker-php-ext-enable "$name"
  fi
}

installExtBuiltin() {
  name=$1

  if [ -n "$*" ]; then
    docker-php-ext-configure "$name" $option
  fi

  docker-php-ext-install "$name"
}

pkgCmd() {
  case "$DISTRO" in
  debian)
    printf "apt-get install -y --no-install-recommends {}"
    ;;
  alpine)
    printf "apk add {}"
    ;;
  esac
}

getPackage() {
  PKG_TYPE=$1
  export PKG_TYPE

  SUITE_PKG=$(getSuite | $YQ '.[env(PKG_TYPE) + "-package" | sub("package-", "")] | .[env(DISTRO)]')
  export SUITE_PKG

  $YQ '.[env(DISTRO)].[env(PKG_TYPE)] *+ .default.[env(PKG_TYPE)] *+ env(SUITE_PKG) | .[]
        | with( select(type == "!!str"); . = {"run": env(PKG_CMD) ,"name": .} | . = {"run":.run | sub("{}", parent.name)} )
        | .run
        ' "$packageConfig"
}

build() {
  . "distro/$DISTRO.sh"

  if [ "$(runtimeConfig 'repo.change')" = "before" ]; then
    changeRepo
  fi

  # 更新源
  updateRepo

  savedMark="$(savedMark)"

  # 安装系统依赖
  installDeps $(getDeps)

  getExt | $YQ '.[] | del(.deps) | @json' | while IFS= read -r line; do
    installExt "$line"
  done

  #清理pecl
  rm -rf /usr/local/lib/php/.channels/* /usr/local/lib/php/doc/* /usr/local/lib/php/test/* /tmp/pear

  groupadd -g 1000 www
  useradd -g 1000 -u 1000 -m -d /home/www -s /bin/bash www
  cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

  # 清理编译依赖
  clearDeps $savedMark

  PKG_CMD=$(pkgCmd) getPackage "package" | sh -e

  # 清理缓存
  clearCache
}

buildDev() {
  . "distro/$DISTRO.sh"

  updateRepo

  savedMark="$(savedMark)"

  installDeps $(getDevDeps)

  getDevExt | $YQ '.[] | del(.deps) | @json' | while IFS= read -r line; do
    installExt "$line"
  done

  #清理pecl
  rm -rf /usr/local/lib/php/.channels/* /usr/local/lib/php/doc/* /usr/local/lib/php/test/* /tmp/pear

  # 清理编译依赖
  clearDeps $savedMark

  PKG_CMD=$(pkgCmd) getPackage "dev" | sh -e

  clearCache

  if [ "$(runtimeConfig 'repo.change')" = "after" ]; then
    changeRepo
  fi
}
