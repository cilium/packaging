#!/bin/bash

# Copyright 2017-2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o xtrace
set -o errexit
set -o pipefail
set -o nounset

rev="316390403ebb92b39ee81b115fc737bd0d4a1a64"

# git clone https://github.com/libbpf/libbpf /src/libbpf
# cd /src/libbpf
# git checkout -b "build-${rev:0:7}" "${rev}

# It is much quicker to download a tarball then a full git checkout,
curl --fail --show-error --silent --location "https://github.com/cilium/libbpf/archive/${rev}.tar.gz" --output /tmp/libbpf.tgz
mkdir -p /src
tar -xf /tmp/libbpf.tgz -C /tmp
mv "/tmp/libbpf-${rev}" /src/libbpf
rm -f /tmp/libbpf.tgz
