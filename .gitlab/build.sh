#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Simplified build script for CI using nixl-deps-base image
# Dependencies (UCX, libfabric, etcd, aws-sdk, rust, DOCA) are pre-installed in the base image

# shellcheck disable=SC1091
. "$(dirname "$0")/../.ci/scripts/common.sh"

set -e
set -x
set -o pipefail

# Parse commandline arguments
INSTALL_DIR=$1
EXTRA_BUILD_ARGS=${2:-""}
LIBFABRIC_INSTALL_DIR=${LIBFABRIC_INSTALL_DIR:-/usr/local}

if [ -z "$INSTALL_DIR" ]; then
    echo "Usage: $0 <install_dir> [extra_build_args]"
    exit 1
fi

# For running as user - check if running as root
if [ "$(id -u)" -ne 0 ]; then
    SUDO=sudo
else
    SUDO=""
fi

ARCH=$(uname -m)
[ "$ARCH" = "arm64" ] && ARCH="aarch64"

# Set library and binary paths
export LD_LIBRARY_PATH="${INSTALL_DIR}/lib:${INSTALL_DIR}/lib/$ARCH-linux-gnu:${INSTALL_DIR}/lib64:$LD_LIBRARY_PATH:${LIBFABRIC_INSTALL_DIR}/lib"
export CPATH="${INSTALL_DIR}/include:${LIBFABRIC_INSTALL_DIR}/include:$CPATH"
export PATH="${INSTALL_DIR}/bin:$PATH"
export PKG_CONFIG_PATH="${INSTALL_DIR}/lib/pkgconfig:${INSTALL_DIR}/lib64/pkgconfig:${INSTALL_DIR}:${LIBFABRIC_INSTALL_DIR}/lib/pkgconfig:$PKG_CONFIG_PATH"
export NIXL_PLUGIN_DIR="${INSTALL_DIR}/lib/$ARCH-linux-gnu/plugins"
export CMAKE_PREFIX_PATH="${INSTALL_DIR}:${CMAKE_PREFIX_PATH}"

# Build NIXL
# shellcheck disable=SC2086
meson setup nixl_build --prefix=${INSTALL_DIR} -Dbuild_docs=true -Drust=false ${EXTRA_BUILD_ARGS} -Dlibfabric_path="${LIBFABRIC_INSTALL_DIR}"
ninja -j"$NPROC" -C nixl_build && ninja -j"$NPROC" -C nixl_build install
mkdir -p dist && cp nixl_build/src/bindings/python/nixl-meta/nixl-*.whl dist/

# Build nixlbench
cd benchmark/nixlbench
meson setup nixlbench_build -Dnixl_path=${INSTALL_DIR} -Dprefix=${INSTALL_DIR}
ninja -j"$NPROC" -C nixlbench_build && ninja -j"$NPROC" -C nixlbench_build install
