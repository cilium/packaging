#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o xtrace
set -o errexit
set -o pipefail
set -o nounset

triplet="aarch64-linux-gnu"

cd /src/libbpf/src

make clean
CC="${triplet}-gcc"			\
AR="${triplet}-ar"			\
make -j "$(getconf _NPROCESSORS_ONLN)"

PREFIX="/out/linux/arm64/"		\
PKG_CONFIG="${triplet}-pkg-config"	\
make install
