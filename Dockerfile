ARG PHP_VER=8.4.2
ARG FROM=cli

FROM php:${PHP_VER}${FROM:+-$FROM}

ARG DISTRO=debian
ARG SUITE=swoole
ARG PHP_CMD=php

ENV TZ=Asia/Shanghai \
    PHP_CMD=${PHP_CMD}

COPY --chmod=0755 rootfs/usr/local/bin /usr/local/bin
COPY --chmod=0666 rootfs/usr/local/etc /usr/local/etc

RUN --mount=type=bind,target=/build,source=./build \
    set -eux; \
    cd /build; \
    sh ./main.sh $DISTRO $SUITE

ENTRYPOINT ["entrypoint"]