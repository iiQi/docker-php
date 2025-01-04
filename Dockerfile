ARG PHP_VER=8.4.2
ARG FROM=cli

FROM php:${PHP_VER}${FROM:+-$FROM}

ARG DISTRO=debian
ARG SUITE=swoole
ARG PHP_CMD=php

ENV TZ=Asia/Shanghai \
    PHP_CMD=${PHP_CMD}

COPY rootfs /

RUN --mount=type=bind,target=/build,source=./build \
    set -eux; \
    cd /build; \
    sh ./main.sh $DISTRO $SUITE

ENTRYPOINT ["entrypoint"]