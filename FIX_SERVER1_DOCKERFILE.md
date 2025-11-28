# Fix Server 1 - Missing Dockerfile

## Problem
Server 1 par Dockerfile nahi hai, isliye image build nahi ho rahi.

## Solution Options

### Option 1: Check Server 1 Project Directory

**Server 1 par SSH karein aur check karein:**

```bash
# Server 1 par SSH karein
ssh user@SERVER1_IP

# Check project directory
cd /opt/zoom-headless-meeting
pwd

# Check if Dockerfile exists
ls -la Dockerfile

# Check all files
ls -la
```

**Agar Dockerfile nahi hai, to:**

### Option 2: Copy Dockerfile from Local Machine

**Local machine se Server 1 par copy karein:**

```bash
# Local machine par
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"

# Copy Dockerfile to Server 1
scp Dockerfile user@SERVER1_IP:/opt/zoom-headless-meeting/

# Verify on Server 1
ssh user@SERVER1_IP "ls -la /opt/zoom-headless-meeting/Dockerfile"
```

### Option 3: Copy Complete Project to Server 1

**Agar Server 1 par project incomplete hai:**

```bash
# Local machine se Server 1 par complete project copy karein
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"

# Copy entire project (excluding node_modules, .git)
rsync -avz --exclude 'node_modules' --exclude '.git' \
  ./ user@SERVER1_IP:/opt/zoom-headless-meeting/

# Ya tar.gz bana ke copy karein
tar -czf project.tar.gz --exclude='node_modules' --exclude='.git' .
scp project.tar.gz user@SERVER1_IP:/tmp/
ssh user@SERVER1_IP "cd /opt/zoom-headless-meeting && tar -xzf /tmp/project.tar.gz"
```

### Option 4: Create Dockerfile on Server 1

**Server 1 par manually Dockerfile create karein:**

```bash
# Server 1 par SSH karein
ssh user@SERVER1_IP
cd /opt/zoom-headless-meeting

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM ubuntu:22.04 AS base

SHELL ["/bin/bash", "-c"]

ENV project=meeting-sdk-linux-sample
ENV cwd=/tmp/$project

WORKDIR $cwd

ARG DEBIAN_FRONTEND=noninteractive

# Install Dependencies
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

# Install ALSA with dummy module support
RUN apt-get update --allow-insecure-repositories -o Dir::Cache::archives=/tmp/apt-cache \
    && apt-get install -y --allow-unauthenticated --no-install-recommends -o Dir::Cache::archives=/tmp/apt-cache \
    libasound2 libasound2-plugins alsa alsa-utils alsa-oss \
    linux-modules-extra-$(uname -r) 2>/dev/null || true \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/archives/* \
    && rm -rf /tmp/apt-cache/*

# Install Pulseaudio
RUN apt-get update --allow-insecure-repositories -o Dir::Cache::archives=/tmp/apt-cache \
    && apt-get install -y --allow-unauthenticated --no-install-recommends -o Dir::Cache::archives=/tmp/apt-cache pulseaudio pulseaudio-utils \
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
RUN chmod +x bin/*.sh 2>/dev/null || true
ENTRYPOINT ["/tini", "--"]
CMD ["bash", "-c", "chmod +x bin/*.sh 2>/dev/null || true; exec \"$@\""]
EOF

# Verify
cat Dockerfile
```

## Quick Fix (Recommended)

**Step 1: Local Machine se Dockerfile Copy Karein**

```bash
# Local machine par
cd "/Users/mac/Documents/client static sites/meetingsdk-headless-linux-sample"

# Server 1 ka IP chahiye (replace SERVER1_IP)
scp Dockerfile user@SERVER1_IP:/opt/zoom-headless-meeting/
```

**Step 2: Server 1 par Verify Karein**

```bash
# Server 1 par SSH karein
ssh user@SERVER1_IP
cd /opt/zoom-headless-meeting
ls -la Dockerfile
```

**Step 3: Build Image**

```bash
# Server 1 par
docker build -t zoom-bot:latest . --platform linux/amd64
```

## Summary

**Problem:** Server 1 par Dockerfile nahi hai  
**Solution:** Local machine se Dockerfile copy karein  
**Commands:**
- Local: `scp Dockerfile user@SERVER1_IP:/opt/zoom-headless-meeting/`
- Server 1: `docker build -t zoom-bot:latest . --platform linux/amd64`

