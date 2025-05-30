#!/usr/bin/env sh

set -eux;

rm -rf /init
cp -rf /build/s6/* /

chmod +x /init
chmod +x /etc/s6/*/*
chmod a+w /etc/s6/.s6-svscan
