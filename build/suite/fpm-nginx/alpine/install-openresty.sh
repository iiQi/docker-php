#!/usr/bin/env sh

set -eux;

RESTY_APK_ALPINE_VERSION="3.18"
RESTY_APK_KEY_URL="https://openresty.org/package/admin@openresty.com-5ea678a6.rsa.pub"
RESTY_APK_REPO_URL="https://openresty.org/package/alpine/v${RESTY_APK_ALPINE_VERSION}/main"
RESTY_APK_VERSION="=1.25.3.2-r0"

repo=$(cat /etc/apk/repositories)
curl -o "/etc/apk/keys/$(basename ${RESTY_APK_KEY_URL})" "${RESTY_APK_KEY_URL}"
echo "${RESTY_APK_REPO_URL}" >> /etc/apk/repositories
apk update
apk add "openresty${RESTY_APK_VERSION}"

ln -snf /usr/local/openresty/nginx/conf /etc/openresty

rm -rf "/etc/apk/keys/$(basename ${RESTY_APK_KEY_URL})"
echo "${repo}" > /etc/apk/repositories
