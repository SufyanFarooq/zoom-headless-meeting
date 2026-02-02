FROM ubuntu:22.04 AS base

SHELL ["/bin/bash", "-c"]

ENV project=meeting-sdk-linux-sample
ENV cwd=/tmp/$project

WORKDIR $cwd

ARG DEBIAN_FRONTEND=noninteractive

# Install Dependencies
# Note: Disabling GPG verification for Docker builds (acceptable for official Ubuntu repos)
# Configure apt to use /tmp for cache (more space) and not keep downloaded packages
RUN echo 'Acquire::AllowInsecureRepositories "true";' > /etc/apt/apt.conf.d/99allow-insecure \
    && echo 'Acquire::AllowDowngradeToInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99allow-insecure \
    && echo 'APT::Keep-Downloaded-Packages "false";' >> /etc/apt/apt.conf.d/99allow-insecure \
    && echo 'Dir::Cache::archives "/tmp/apt-cache";' >> /etc/apt/apt.conf.d/99allow-insecure \
    && mkdir -p /tmp/apt-cache \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/archives/* \
    && apt-get update --allow-insecure-repositories -o Dir::Cache::archives=/tmp/apt-cache \
    && apt-get install -y --allow-unauthenticated --no-install-recommends -o Dir::Cache::archives=/tmp/apt-cache \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    gdb \
    git \
    gfortran \
    util-linux \
    libopencv-dev \
    libcli11-dev \
    libdbus-1-3 \
    libgbm1 \
    libgl1 \
    libglib2.0-0 \
    libglib2.0-dev \
    libssl-dev \
    libx11-dev \
    libx11-xcb1 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-shape0 \
    libxcb-shm0 \
    libxcb-xfixes0 \
    libxcb-xtest0 \
    libgl1-mesa-dri \
    libxfixes3 \
    linux-libc-dev \
    pciutils \
    pkgconf \
    tar \
    unzip \
    zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/archives/* \
    && rm -rf /tmp/apt-cache/*

# Install ALSA + Pulse plugins so Zoom SDK can detect virtual audio devices
# libasound2-plugins provides pulse plugin for ALSA->PulseAudio routing
RUN apt-get update --allow-insecure-repositories -o Dir::Cache::archives=/tmp/apt-cache \
    && apt-get install -y --allow-unauthenticated --no-install-recommends -o Dir::Cache::archives=/tmp/apt-cache \
    libasound2 libasound2-plugins libasound2-dev alsa alsa-utils alsa-oss \
    linux-modules-extra-$(uname -r) 2>/dev/null || true \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/archives/* \
    && rm -rf /tmp/apt-cache/*

# Install Pulseaudio and Xvfb (virtual display for Zoom desktop app video icon compatibility)
# Zoom desktop client needs a display to recognize video capability - Xvfb provides that in headless
RUN apt-get update --allow-insecure-repositories -o Dir::Cache::archives=/tmp/apt-cache \
    && apt-get install -y --allow-unauthenticated --no-install-recommends -o Dir::Cache::archives=/tmp/apt-cache pulseaudio pulseaudio-utils xvfb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/archives/* \
    && rm -rf /tmp/apt-cache/*

FROM base AS deps

ENV TINI_VERSION=v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

WORKDIR /opt
RUN git clone --depth 1 https://github.com/Microsoft/vcpkg.git \
    && ./vcpkg/bootstrap-vcpkg.sh -disableMetrics \
    && ln -s /opt/vcpkg/vcpkg /usr/local/bin/vcpkg \
    && vcpkg install vcpkg-cmake

FROM deps AS build

WORKDIR $cwd
# Set execute permissions for scripts and use entry-bot-optimized.sh
RUN chmod +x bin/*.sh 2>/dev/null || true
ENTRYPOINT ["/tini", "--"]
CMD ["bash", "-c", "chmod +x bin/*.sh 2>/dev/null || true; exec \"$@\""]


