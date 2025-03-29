ARG VERSION=8.4.2
ARG FROM=cli

FROM php:${VERSION}${FROM:+-$FROM}

ARG DISTRO=debian
ARG SUITE
ARG VERSION
ARG PHP_EXT
ARG EXEC_CMD=php

ENV TZ=Asia/Shanghai \
    EXEC_CMD=${EXEC_CMD}

COPY --chmod=0755 rootfs/usr/local/bin /usr/local/bin
COPY --chmod=0666 rootfs/usr/local/etc /usr/local/etc

RUN --mount=type=bind,target=/build,source=./build \
    set -eux; \
    cd /build; \
    . ./build.sh; \
    build

WORKDIR /opt

ENTRYPOINT ["entrypoint"]