#!/usr/bin/env sh

set -eux

arch=$(dpkg --print-architecture)
arch=${arch#amd64}
arch=${arch:+/$arch}

RESTY_APT_REPO="https://openresty.org/package$arch/debian"
RESTY_APT_PGP="https://openresty.org/package/pubkey.gpg"
RESTY_DEB_VERSION="=1.27.1.2-1~bookworm1"

curl -o /etc/apt/keyrings/openresty.asc ${RESTY_APT_PGP}
chmod a+r /etc/apt/keyrings/openresty.asc
echo "deb [signed-by=/etc/apt/keyrings/openresty.asc] $RESTY_APT_REPO $(. /etc/os-release && echo "$VERSION_CODENAME") openresty" | tee /etc/apt/sources.list.d/openresty.list
apt-get update
apt-get install -y --no-install-recommends openresty${RESTY_DEB_VERSION}

rm -rf /etc/apt/keyrings/openresty.asc /etc/apt/sources.list.d/openresty.list
