#!/usr/bin/env sh

set -eux

RESTY_APT_ARCH="amd64"
RESTY_APT_REPO="https://openresty.org/package/debian"
RESTY_APT_PGP="https://openresty.org/package/pubkey.gpg"
RESTY_DEB_VERSION="=1.25.3.2-1~bookworm1"

curl -o /etc/apt/keyrings/openresty.asc ${RESTY_APT_PGP}
chmod a+r /etc/apt/keyrings/openresty.asc
echo "deb [arch=$RESTY_APT_ARCH signed-by=/etc/apt/keyrings/openresty.asc] $RESTY_APT_REPO $(. /etc/os-release && echo "$VERSION_CODENAME") openresty" | tee /etc/apt/sources.list.d/openresty.list
apt-get update
apt-get install -y --no-install-recommends openresty${RESTY_DEB_VERSION}
