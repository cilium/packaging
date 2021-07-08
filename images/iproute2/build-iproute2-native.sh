#!/bin/bash

# Copyright 2017-2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o xtrace
set -o errexit
set -o pipefail
set -o nounset

cd /src/iproute2

LIBBPF_FORCE="on"					\
PKG_CONFIG_PATH="/out/linux/amd64/lib64/pkgconfig"	\
PKG_CONFIG="pkg-config --define-prefix"			\
./configure

make -j "$(getconf _NPROCESSORS_ONLN)"

strip ip/ip
strip tc/tc
strip misc/ss

mkdir -p /out/linux/amd64/bin
cp ip/ip tc/tc misc/ss /out/linux/amd64/bin
