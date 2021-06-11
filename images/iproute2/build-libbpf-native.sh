#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o xtrace
set -o errexit
set -o pipefail
set -o nounset

cd /src/libbpf/src

make clean
make -j "$(getconf _NPROCESSORS_ONLN)"
PREFIX="/out/linux/amd64/"		\
make install
