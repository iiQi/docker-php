#!/usr/bin/env sh

set -eux

distro=$1
suite=$2

configFile="suite/$suite.yaml"
yqBin="./yq"
deps=$($yqBin ".$distro.deps | join(\" \")" "$configFile")
package=$($yqBin ".$distro.package | join(\" \")" "$configFile")

install_pecl() {
  package=$1
  arg=$2

  printf "%b" "$arg" | pecl install -o "$package";
}

. "distro/$distro.sh"

# 修改源
changeRepo

savedMark="$(savedMark)"

# 安装系统依赖
installDeps $deps

# 源码编译php扩展依赖包
$yqBin '.php.ext.[] | select(has("deps")) | .deps' "$configFile" | sh

# PHP 扩展
phpExt=$($yqBin '.php.ext.[] | select(.name) | .name, .php.ext.[] | select(kind == "scalar")' "$configFile")
[ -z "$phpExt" ] || docker-php-ext-install -j"$(nproc)" $phpExt

# PECL
phpPECL=$($yqBin '.php.pecl.[] | select(kind == "scalar")' "$configFile")
[ -z "$phpPECL" ] || pecl install -o $phpPECL

# 带选项参数的 PECL
$yqBin '.php.pecl.[] | select(has("arg")) | [.name, .arg] | @tsv' "$configFile" | while IFS="$(printf '\t')" read -r name arg; do
  [ -z "$name" ] || install_pecl "$name" "$arg"
done

phpPECL=$($yqBin '.php.pecl.[] | select(.name) | .name, .php.pecl.[] | select(kind == "scalar")' "$configFile")
[ -z "$phpPECL" ] || docker-php-ext-enable $phpPECL

#清理pecl
rm -rf /usr/local/lib/php/.channels/* /usr/local/lib/php/doc/* /usr/local/lib/php/test/* /tmp/pear

groupadd -g 1000 www
useradd -g 1000 -u 1000 -b /var -s /bin/bash www
cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

# 清理编译依赖
clearDeps $savedMark

installPackage $package