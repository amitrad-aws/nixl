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

ARG BASE_IMAGE="nvcr.io/nvidia/cuda-dl-base"
ARG BASE_IMAGE_TAG="25.06-cuda12.9-devel-ubuntu24.04"

FROM ${BASE_IMAGE}:${BASE_IMAGE_TAG} AS nixl-deps-base

ARG UCX_REF="v1.19.0"
ARG UCX_PREFIX="/usr"
ARG UCX_PLUGIN_DIR="$UCX_PREFIX/lib/ucx"
ARG NIXL_PREFIX="/usr/local/nixl"
ARG NPROC
ARG LIBFABRIC_VERSION="v2.3.0"
ARG LIBFABRIC_INSTALL_PATH="/usr/local"

# Install build dependencies from Ubuntu repository
RUN apt-get update -y && \
    apt-get install -y ubuntu-keyring && \
    apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install \
    automake \
    autotools-dev \
    build-essential \
    clang \
    cmake \
    curl \
    doxygen \
    etcd-client \
    etcd-server \
    flex \
    git \
    hwloc \
    iproute2 \
    libaio-dev \
    libboost-all-dev \
    libclang-dev \
    libcpprest-dev \
    libcurl4-openssl-dev \
    libgflags-dev \
    libgmock-dev \
    libgoogle-glog-dev \
    libgrpc++-dev \
    libgrpc-dev \
    libgtest-dev \
    libhwloc-dev \
    libiberty-dev \
    libibmad-dev \
    libjsoncpp-dev \
    libnuma-dev \
    libpci-dev \
    libprotobuf-dev \
    libssl-dev \
    libtool \
    liburing-dev \
    libz-dev \
    meson \
    net-tools \
    ninja-build \
    numactl \
    pciutils \
    pkg-config \
    protobuf-compiler-grpc \
    pybind11-dev \
    uuid-dev \
    wget \
    zlib1g-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Remove broken cmake installations (some docker images have these)
RUN rm -rf /usr/lib/cmake/grpc /usr/lib/cmake/protobuf

# Install Python based on OS version
RUN apt-get update && \
    if apt-cache show python3.12-dev > /dev/null 2>&1; then \
        DEBIAN_FRONTEND=noninteractive apt-get install -y python3.12-dev python3-pip; \
    else \
        DEBIAN_FRONTEND=noninteractive apt-get install -y python3.10-dev python3-pip; \
    fi && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add DOCA repository and install packages
RUN ARCH=$(uname -m) && \
    ARCH_SUFFIX=$(if [ "$ARCH" = "aarch64" ]; then echo "arm64"; else echo "amd64"; fi) && \
    MELLANOX_OS="$(. /etc/lsb-release; echo ${DISTRIB_ID}${DISTRIB_RELEASE} | tr A-Z a-z | tr -d .)" && \
    wget --tries=3 --waitretry=5 --no-verbose https://www.mellanox.com/downloads/DOCA/DOCA_v3.1.0/host/doca-host_3.1.0-091000-25.07-${MELLANOX_OS}_${ARCH_SUFFIX}.deb -O doca-host.deb && \
    dpkg -i doca-host.deb && \
    rm -f doca-host.deb && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends doca-sdk-gpunetio libdoca-sdk-gpunetio-dev libdoca-sdk-verbs-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Force reinstall of RDMA packages from DOCA repository
# Reinstall needed to fix broken libibverbs-dev, which may lead to lack of Infiniband support.
# Upgrade is not sufficient if the version is the same since apt skips the installation.
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get -y install \
    --reinstall libibverbs-dev rdma-core ibverbs-utils libibumad-dev \
    libnuma-dev librdmacm-dev ibverbs-providers && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
RUN git clone --depth 1 https://github.com/etcd-cpp-apiv3/etcd-cpp-apiv3.git && \
    cd etcd-cpp-apiv3 && \
    sed -i '/^find_dependency(cpprestsdk)$/d' etcd-cpp-api-config.in.cmake && \
    mkdir build && cd build && \
    cmake .. -DBUILD_ETCD_CORE_ONLY=ON -DCMAKE_BUILD_TYPE=Release && make -j${NPROC:-$(nproc)} && make install && \
    ldconfig && \
    cd /workspace && rm -rf etcd-cpp-apiv3

RUN git clone --recurse-submodules --depth 1 --shallow-submodules https://github.com/aws/aws-sdk-cpp.git --branch 1.11.581 && \
    mkdir aws_sdk_build && cd aws_sdk_build && \
    cmake ../aws-sdk-cpp/ -DCMAKE_BUILD_TYPE=Release -DBUILD_ONLY="s3" -DENABLE_TESTING=OFF -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j${NPROC:-$(nproc)} && make install && \
    cd /workspace && rm -rf aws-sdk-cpp aws_sdk_build

RUN git clone https://github.com/nvidia/gusli.git && \
     cd gusli && \
     make all BUILD_RELEASE=1 BUILD_FOR_UNITEST=0 VERBOSE=1 ALLOW_USE_URING=0 && \
     cd .. && \
     ldconfig && \
     rm -rf gusli

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.86.0
# RUSTARCH will be set at runtime based on detected architecture

# Download rustup-init and its checksum for the target architecture
RUN ARCH=$(uname -m) && \
    RUSTARCH="${ARCH}-unknown-linux-gnu" && \
    wget --tries=3 --waitretry=5 \
    "https://static.rust-lang.org/rustup/archive/1.28.1/${RUSTARCH}/rustup-init" \
    "https://static.rust-lang.org/rustup/archive/1.28.1/${RUSTARCH}/rustup-init.sha256" && \
    sha256sum -c rustup-init.sha256 && \
    chmod +x rustup-init && \
    ./rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --default-host ${RUSTARCH} && \
    rm rustup-init* && \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME

RUN rm -rf /usr/lib/ucx
RUN rm -rf /opt/hpcx/ucx

RUN cd /usr/local/src && \
     git clone https://github.com/openucx/ucx.git && \
     cd ucx && 			     \
     git checkout $UCX_REF &&        \
     ./autogen.sh && ./configure     \
         --prefix=$UCX_PREFIX        \
         --enable-shared             \
         --disable-static            \
         --disable-doxygen-doc       \
         --enable-optimizations      \
         --enable-cma                \
         --enable-devel-headers      \
         --with-cuda=/usr/local/cuda \
         --with-verbs                \
         --with-dm                   \
         --with-gdrcopy=/usr/local   \
         --with-efa                  \
         --enable-mt &&              \
     make -j${NPROC:-$(nproc)} &&                \
     make -j${NPROC:-$(nproc)} install-strip &&  \
     ldconfig && \
     cd /usr/local/src && rm -rf ucx

RUN cd /tmp && \
     git clone --depth 1 https://github.com/google/gtest-parallel.git && \
     mkdir -p /usr/local/bin && \
     cp gtest-parallel/gtest-parallel gtest-parallel/gtest_parallel.py /usr/local/bin/ && \
     rm -rf gtest-parallel
ENV PATH=/usr/local/bin:$PATH

# Build libfabric from source
RUN cd /tmp && \
    wget --tries=3 --waitretry=5 --timeout=30 --read-timeout=60 \
    "https://github.com/ofiwg/libfabric/releases/download/${LIBFABRIC_VERSION}/libfabric-${LIBFABRIC_VERSION#v}.tar.bz2" -O libfabric.tar.bz2 && \
    tar xjf libfabric.tar.bz2 && rm libfabric.tar.bz2 && \
    cd libfabric-* && \
    ./autogen.sh && \
    ./configure --prefix="${LIBFABRIC_INSTALL_PATH}" \
                --disable-verbs \
                --disable-psm3 \
                --disable-opx \
                --disable-usnic \
                --disable-rstream \
                --enable-efa \
                --with-cuda=/usr/local/cuda \
                --enable-cuda-dlopen \
                --with-gdrcopy \
                --enable-gdrcopy-dlopen && \
    make -j${NPROC:-$(nproc)} && \
    make install && \
    ldconfig && \
    cd /tmp && rm -rf libfabric-*

# By default, uv downloads python packages to $HOME/.cache/uv and hard links them
# from the virtual environment. This means that the files reside in /root/.cache/uv,
# which is not what we want since some systems mount user home dir into /root,
# in which case the venv is broken when the container is started.
# Set a custom cache directory inside /workspace to avoid this.
ENV UV_CACHE_DIR=/workspace/.cache/uv
RUN mkdir -p $UV_CACHE_DIR
# Disable build isolation, i.e. uv should not create a new virtual environment for
# building wheels. This is faster as it skips installing dependencies twice.
ENV UV_NO_BUILD_ISOLATION=1
# Disable syncing, i.e. uv will not download packages outside uv pip commands.
ENV UV_NO_SYNC=1
# Set LD_LIBRARY_PATH to find UCX and libfabric at runtime
ENV LD_LIBRARY_PATH=/usr/local/lib:$LIBFABRIC_INSTALL_PATH/lib:$LD_LIBRARY_PATH
# Create a new virtual environment
ENV VIRTUAL_ENV=/workspace/.venv
RUN rm -rf $VIRTUAL_ENV && uv venv $VIRTUAL_ENV --python 3.12
# Activate the virtual environment
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
# Install python dependencies and PyTorch (into venv)
RUN export PYTHONDONTWRITEBYTECODE=1 && \
    export UV_NO_CACHE=1 && \
    uv pip install --upgrade setuptools meson meson-python pybind11 patchelf pyYAML click tabulate auditwheel tomlkit && \
    CUDA_MAJOR_MINOR=$(nvcc --version | grep "release" | sed -n 's/.*release \([0-9]*\.[0-9]*\).*/\1/p' | tr -d .) && \
    export UV_INDEX="https://download.pytorch.org/whl/cu${CUDA_MAJOR_MINOR}" && \
    uv pip install torch torchvision torchaudio

# Stage 2: Build NIXL (uses dependencies from nixl-deps-base)
FROM nixl-deps-base AS nixl-build

# Re-declare ARGs needed in this stage (ARCH will be detected at runtime)
ARG NIXL_PREFIX="/usr/local/nixl"
ARG UCX_PREFIX="/usr"
ARG UCX_PLUGIN_DIR="$UCX_PREFIX/lib/ucx"
ARG LIBFABRIC_INSTALL_PATH="/usr/local"

# Re-establish ENV variables from stage 1
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.86.0
ENV UV_CACHE_DIR=/workspace/.cache/uv \
    UV_NO_BUILD_ISOLATION=1 \
    UV_NO_SYNC=1
ENV VIRTUAL_ENV=/workspace/.venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

WORKDIR /workspace/nixl
COPY . /workspace/nixl

# Set library and binary paths
# Note: ARCH-dependent paths are set at runtime in entrypoint or need shell expansion
ENV CPATH="$NIXL_PREFIX/include:$LIBFABRIC_INSTALL_PATH/include:$CPATH"
ENV PKG_CONFIG_PATH="$NIXL_PREFIX/lib/pkgconfig:$NIXL_PREFIX/lib64/pkgconfig:$NIXL_PREFIX:$LIBFABRIC_INSTALL_PATH/lib/pkgconfig:$PKG_CONFIG_PATH"
ENV CMAKE_PREFIX_PATH="$NIXL_PREFIX:$CMAKE_PREFIX_PATH"
ENV PATH="$NIXL_PREFIX/bin:/usr/local/bin:$PATH"

# Disabling CUDA IPC not to use NVLINK, as it slows down local
# UCX transfers and can cause contention with local collectives.
ENV UCX_TLS=^cuda_ipc

RUN rm -rf nixl_build && \
    meson setup nixl_build --prefix=$NIXL_PREFIX -Dbuild_docs=true -Drust=false -Dlibfabric_path=$LIBFABRIC_INSTALL_PATH && \
    ninja -j${NPROC:-$(nproc)} -C nixl_build && \
    ninja -j${NPROC:-$(nproc)} -C nixl_build install && \
    mkdir -p dist && cp nixl_build/src/bindings/python/nixl-meta/nixl-*.whl dist/ && \
    rm -rf nixl_build

RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "arm64" ]; then ARCH="aarch64"; fi && \
    echo "$NIXL_PREFIX/lib/$ARCH-linux-gnu" > /etc/ld.so.conf.d/nixl.conf && \
    echo "$NIXL_PREFIX/lib/$ARCH-linux-gnu/plugins" >> /etc/ld.so.conf.d/nixl.conf && \
    echo "$NIXL_PREFIX/lib" >> /etc/ld.so.conf.d/nixl.conf && \
    echo "$NIXL_PREFIX/lib64" >> /etc/ld.so.conf.d/nixl.conf && \
    ldconfig && \
    echo "export LD_LIBRARY_PATH=\"$NIXL_PREFIX/lib:$NIXL_PREFIX/lib/$ARCH-linux-gnu:$NIXL_PREFIX/lib64:\$LD_LIBRARY_PATH:$LIBFABRIC_INSTALL_PATH/lib\"" >> /etc/profile.d/nixl.sh && \
    echo "export NIXL_PLUGIN_DIR=\"$NIXL_PREFIX/lib/$ARCH-linux-gnu/plugins\"" >> /etc/profile.d/nixl.sh

# Build nixlbench
RUN cd benchmark/nixlbench && \
    meson setup nixlbench_build -Dnixl_path=$NIXL_PREFIX -Dprefix=$NIXL_PREFIX && \
    ninja -j${NPROC:-$(nproc)} -C nixlbench_build && \
    ninja -j${NPROC:-$(nproc)} -C nixlbench_build install && \
    cd /workspace/nixl && rm -rf benchmark/nixlbench/nixlbench_build

# Build wheel using the build-wheel.sh script for better UCX plugin bundling and library management
RUN ARCH=$(uname -m) && \
    ./contrib/build-wheel.sh \
    --python-version $(python3 --version | awk '{print $2}' | cut -d. -f1,2) \
    --platform manylinux_2_39_$ARCH \
    --ucx-plugins-dir $UCX_PLUGIN_DIR \
    --nixl-plugins-dir $NIXL_PREFIX/lib/$ARCH-linux-gnu/plugins \
    --output-dir /workspace/nixl/dist

RUN uv pip install dist/nixl-cu*-cp3*.whl dist/nixl-*-none-any.whl
