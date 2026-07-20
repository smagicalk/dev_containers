FROM debian:13-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
ARG GO_VERSION=1.26.5
ARG NODE_VERSION=24.18.0
ARG PNPM_VERSION=11.15.0
ARG RUST_TOOLCHAIN=stable
ARG FLUTTER_VERSION=3.44.6
ARG KOTLIN_VERSION=2.4.10
ARG SCALA_VERSION=3.8.4
ARG MAVEN_VERSION=3.9.16
ARG GRADLE_VERSION=9.6.1
ARG CMAKE_VERSION=4.3.3
ARG ZIG_VERSION=0.16.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN printf 'path-exclude=/usr/share/doc/*\npath-exclude=/usr/share/man/*\npath-exclude=/usr/share/info/*\n' > /etc/dpkg/dpkg.cfg.d/01_nodoc \
    && apt-get update && apt-get install -y --no-install-recommends \
    openssh-server ca-certificates curl wget git gnupg jq unzip zip xz-utils zstd \
    bash-completion locales tzdata sudo vim-tiny nano tmux less htop procps \
    iproute2 iputils-ping net-tools dnsutils traceroute tcpdump socat netcat-openbsd \
    build-essential gcc g++ clang lld llvm make ninja-build meson autoconf automake \
    libtool pkg-config gdb strace file rsync openssl \
    python3 python3-dev python3-pip python3-venv pipx \
    lua5.4 liblua5.4-dev luarocks \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --set lua-interpreter /usr/bin/lua5.4 \
    && update-alternatives --set lua-compiler /usr/bin/luac5.4

# Docker CLI（需要在运行容器时挂载 /var/run/docker.sock 才能控制宿主机 Docker）
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin docker-buildx-plugin \
    && rm -rf /var/lib/apt/lists/*

# Go
RUN case "${TARGETARCH:-amd64}" in amd64) GOARCH=amd64 ;; arm64) GOARCH=arm64 ;; *) echo "Unsupported TARGETARCH=${TARGETARCH}"; exit 1 ;; esac \
    && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GOARCH}.tar.gz" -o /tmp/go.tar.gz \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz \
    && rm -rf /usr/local/go/test

# Node.js + npm + Corepack/pnpm
RUN case "${TARGETARCH:-amd64}" in amd64) NODE_ARCH=x64 ;; arm64) NODE_ARCH=arm64 ;; *) exit 1 ;; esac \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" -o /tmp/node.tar.xz \
    && tar -C /usr/local --strip-components=1 -xJf /tmp/node.tar.xz \
    && rm /tmp/node.tar.xz \
    && corepack enable \
    && corepack install --global pnpm@${PNPM_VERSION} \
    && pnpm --version

# Rust
ENV RUSTUP_HOME=/opt/rustup CARGO_HOME=/opt/cargo
RUN curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain "${RUST_TOOLCHAIN}" \
    && /opt/cargo/bin/rustup component add rustfmt clippy \
    && rm -rf /opt/rustup/downloads /opt/rustup/tmp /opt/rustup/toolchains/*/share/doc \
    && chmod -R a+rX /opt/rustup /opt/cargo

# uv
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# CMake 官方二进制
RUN case "${TARGETARCH:-amd64}" in amd64) CMAKE_ARCH=x86_64 ;; arm64) CMAKE_ARCH=aarch64 ;; *) exit 1 ;; esac \
    && curl -fsSL "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${CMAKE_ARCH}.tar.gz" -o /tmp/cmake.tar.gz \
    && mkdir -p /opt/cmake \
    && tar -C /opt/cmake --strip-components=1 -xzf /tmp/cmake.tar.gz \
    && rm /tmp/cmake.tar.gz \
    && ln -sf /opt/cmake/bin/cmake /usr/local/bin/cmake \
    && ln -sf /opt/cmake/bin/ctest /usr/local/bin/ctest \
    && ln -sf /opt/cmake/bin/cpack /usr/local/bin/cpack \
    && rm -rf /opt/cmake/doc /opt/cmake/man /opt/cmake/bin/cmake-gui

# Zig 官方二进制
RUN case "${TARGETARCH:-amd64}" in amd64) ZIG_ARCH=x86_64 ;; arm64) ZIG_ARCH=aarch64 ;; *) exit 1 ;; esac \
    && curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-${ZIG_ARCH}-linux-${ZIG_VERSION}.tar.xz" -o /tmp/zig.tar.xz \
    && mkdir -p /opt/zig \
    && tar -C /opt/zig --strip-components=1 -xJf /tmp/zig.tar.xz \
    && rm /tmp/zig.tar.xz \
    && ln -sf /opt/zig/zig /usr/local/bin/zig \
    && rm -rf /opt/zig/doc

# SDKMAN + Java/Kotlin/Scala/Maven/Gradle
ENV SDKMAN_DIR=/opt/sdkman
RUN curl -s https://get.sdkman.io | bash \
    && source /opt/sdkman/bin/sdkman-init.sh \
    && sdk install java 25.0.3-tem \
    && sdk default java 25.0.3-tem \
    && sdk install kotlin "${KOTLIN_VERSION}" \
    && sdk default kotlin "${KOTLIN_VERSION}" \
    && sdk install scala "${SCALA_VERSION}" \
    && sdk default scala "${SCALA_VERSION}" \
    && sdk install maven "${MAVEN_VERSION}" \
    && sdk default maven "${MAVEN_VERSION}" \
    && sdk install gradle "${GRADLE_VERSION}" \
    && sdk default gradle "${GRADLE_VERSION}" \
    && rm -rf /opt/sdkman/archives /opt/sdkman/tmp /opt/sdkman/candidates/java/*/src.zip /opt/sdkman/candidates/java/*/man

# Flutter（内含 Dart）
RUN test "${TARGETARCH:-amd64}" = "amd64" \
    && curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o /tmp/flutter.tar.xz \
    && tar -C /opt -xJf /tmp/flutter.tar.xz \
    && rm /tmp/flutter.tar.xz \
    && git config --system --add safe.directory /opt/flutter \
    && /opt/flutter/bin/flutter config --no-analytics \
    && FLUTTER_REV=$(git -C /opt/flutter rev-parse HEAD) \
    && git clone -q --filter=blob:none --no-checkout --depth 1 --branch stable https://github.com/flutter/flutter.git /tmp/flutter-shallow \
    && test "$(git -C /tmp/flutter-shallow rev-parse HEAD)" = "${FLUTTER_REV}" \
    && rm -rf /opt/flutter/.git \
    && mv /tmp/flutter-shallow/.git /opt/flutter/.git \
    && rm -rf /tmp/flutter-shallow \
    && git -C /opt/flutter reset -q --hard HEAD \
    && /opt/flutter/bin/flutter --version >/dev/null \
    && rm -rf /opt/flutter/.github /opt/flutter/.idea /opt/flutter/docs /opt/flutter/examples /opt/flutter/.pub-preload-cache /root/.cache /root/.dart-tool

ENV JAVA_HOME=/opt/sdkman/candidates/java/current
ENV GOPATH=/root/go
ENV PATH=/usr/local/go/bin:/root/go/bin:/opt/cargo/bin:/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:/opt/sdkman/candidates/java/current/bin:/opt/sdkman/candidates/kotlin/current/bin:/opt/sdkman/candidates/scala/current/bin:/opt/sdkman/candidates/maven/current/bin:/opt/sdkman/candidates/gradle/current/bin:/opt/cmake/bin:/opt/zig:${PATH}

RUN echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen \
    && locale-gen \
    && mkdir -p /run/sshd /workspace \
    && sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && printf '%s\n' \
       'PermitRootLogin yes' \
       'PasswordAuthentication yes' \
       'KbdInteractiveAuthentication no' \
       'SetEnv RUSTUP_HOME=/opt/rustup CARGO_HOME=/opt/cargo GOPATH=/root/go JAVA_HOME=/opt/sdkman/candidates/java/current' \
       > /etc/ssh/sshd_config.d/99-devbox.conf \
    && printf '%s\n' \
       'export SDKMAN_DIR=/opt/sdkman' \
       '[[ -s /opt/sdkman/bin/sdkman-init.sh ]] && source /opt/sdkman/bin/sdkman-init.sh' \
       > /etc/profile.d/sdkman.sh \
    && chmod 644 /etc/profile.d/sdkman.sh

RUN echo "export GOPATH=/root/go" > /etc/profile.d/devbox-path.sh && echo "export JAVA_HOME=/opt/sdkman/candidates/java/current" >> /etc/profile.d/devbox-path.sh && echo "export PATH=/usr/local/go/bin:/root/go/bin:/opt/cargo/bin:/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:/opt/sdkman/candidates/java/current/bin:/opt/sdkman/candidates/kotlin/current/bin:/opt/sdkman/candidates/scala/current/bin:/opt/sdkman/candidates/maven/current/bin:/opt/sdkman/candidates/gradle/current/bin:/opt/cmake/bin:/opt/zig:$PATH" >> /etc/profile.d/devbox-path.sh && chmod 644 /etc/profile.d/devbox-path.sh

RUN ln -sf /usr/local/go/bin/go /usr/local/bin/go \
    && ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt \
    && ln -sf /opt/cargo/bin/rustc /usr/local/bin/rustc \
    && ln -sf /opt/cargo/bin/cargo /usr/local/bin/cargo \
    && ln -sf /opt/cargo/bin/rustup /usr/local/bin/rustup \
    && ln -sf /opt/flutter/bin/flutter /usr/local/bin/flutter \
    && ln -sf /opt/flutter/bin/dart /usr/local/bin/dart

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh \
    && sshd -t \
    && go version \
    && rustc --version \
    && python3 --version \
    && node --version \
    && java -version \
    && kotlin -version \
    && scala -version \
    && mvn -version \
    && gradle --version \
    && lua -v \
    && dart --version

WORKDIR /workspace
EXPOSE 22
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD []
