FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    HOME=/home/TylerDurdenDev

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    wget \
    git \
    nano \
    vim-tiny \
    less \
    procps \
    htop \
    tmux \
    screen \
    sudo \
    openssh-server \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    iproute2 \
    iputils-ping \
    dnsutils \
    net-tools \
    jq \
    unzip \
    zip \
    tree \
    build-essential \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# ttyd is downloaded from the official GitHub release at build time.
# Pin the release explicitly so the image is reproducible.
ARG TTYD_VERSION=1.7.7
RUN ARCH="$(dpkg --print-architecture)" && \
    case "$ARCH" in \
      amd64) TTYD_ARCH="x86_64" ;; \
      arm64) TTYD_ARCH="aarch64" ;; \
      *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    curl -fsSL -o /usr/local/bin/ttyd \
      "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${TTYD_ARCH}" && \
    chmod 0755 /usr/local/bin/ttyd && \
    /usr/local/bin/ttyd --version

RUN useradd --create-home --shell /bin/bash TylerDurdenDev && \
    usermod -aG sudo TylerDurdenDev && \
    mkdir -p /data /run/sshd /var/log/supervisor && \
    chown -R TylerDurdenDev:TylerDurdenDev /data /home/TylerDurdenDev

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY scripts/sshd_config /etc/ssh/sshd_config

RUN chmod 0755 /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh && \
    chmod 0644 /etc/ssh/sshd_config && \
    ssh-keygen -A

WORKDIR /data

EXPOSE 8080 2222

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
