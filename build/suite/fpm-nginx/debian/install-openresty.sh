#!/usr/bin/env sh

set -eux

arch=$(dpkg --print-architecture)
arch=${arch#amd64}
arch=${arch:+/$arch}

. /etc/os-release

RESTY_APT_REPO="https://openresty.org/package$arch/debian"
RESTY_APT_PGP="https://openresty.org/package/pubkey.gpg"
RESTY_DEB_VERSION="=1.27.1.2-1~${VERSION_CODENAME}1"

# bookworm
if [ "$VERSION_CODENAME" = "bookworm" ]; then
  curl -o /etc/apt/keyrings/openresty.asc ${RESTY_APT_PGP}
  chmod a+r /etc/apt/keyrings/openresty.asc
  echo "deb [signed-by=/etc/apt/keyrings/openresty.asc] $RESTY_APT_REPO $VERSION_CODENAME openresty" | tee /etc/apt/sources.list.d/openresty.list

# bullseye
elif [  "$VERSION_CODENAME" = "bullseye"  ]; then
  apt-get install -y --no-install-recommends gnupg2 software-properties-common
  curl https://openresty.org/package/pubkey.gpg | apt-key add -
  add-apt-repository -y "deb $RESTY_APT_REPO $VERSION_CODENAME openresty"
  apt-get remove -y --purge gnupg2 software-properties-common
fi

apt-get update
apt-get install -y --no-install-recommends openresty${RESTY_DEB_VERSION}

rm -rf /etc/apt/keyrings/openresty.asc /etc/apt/sources.list.d/openresty.list
