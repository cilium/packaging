#!/bin/bash

# Copyright 2017-2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o xtrace
set -o errexit
set -o pipefail
set -o nounset

triplet="aarch64-linux-gnu"

cd /src/iproute2

make distclean

LIBBPF_FORCE="on"					\
PKG_CONFIG_PATH="/out/linux/arm64/lib64/pkgconfig"	\
PKG_CONFIG="${triplet}-pkg-config --define-prefix"	\
CC="${triplet}-gcc"					\
AR="${triplet}-ar"					\
./configure

make -j "$(getconf _NPROCESSORS_ONLN)"

${triplet}-strip ip/ip
${triplet}-strip tc/tc
${triplet}-strip misc/ss

mkdir -p /out/linux/arm64/bin
cp ip/ip tc/tc misc/ss /out/linux/arm64/bin
