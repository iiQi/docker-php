#!/usr/bin/env sh

set -eux;

ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log
ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log

mkdir -p /var/run/openresty
mkdir -p /etc/nginx/conf.d

curl -o /usr/local/openresty/nginx/conf/nginx.conf https://raw.githubusercontent.com/iiQi/docker-openresty/main/rootfs/usr/local/openresty/nginx/conf/nginx.conf
curl -o /etc/nginx/conf.d/default.conf https://raw.githubusercontent.com/iiQi/docker-openresty/main/rootfs/etc/nginx/conf.d/default.conf
curl -o /usr/local/bin/openresty-entrypoint https://raw.githubusercontent.com/iiQi/docker-openresty/main/rootfs/usr/local/bin/entrypoint
chmod +x /usr/local/bin/openresty-entrypoint
