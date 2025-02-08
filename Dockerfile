ARG VERSION=8.4.2
ARG FROM=cli

FROM php:${VERSION}${FROM:+-$FROM}

ARG VERSION
ARG DISTRO=debian
ARG SUITE
ARG PHP_EXT
ARG PHP_CMD=php

ENV TZ=Asia/Shanghai \
    PHP_CMD=${PHP_CMD}

COPY --chmod=0755 rootfs/usr/local/bin /usr/local/bin
COPY --chmod=0666 rootfs/usr/local/etc /usr/local/etc

RUN --mount=type=bind,target=/build,source=./build \
    set -eux; \
    cd /build; \
    . ./build.sh; \
    build

ENTRYPOINT ["entrypoint"]