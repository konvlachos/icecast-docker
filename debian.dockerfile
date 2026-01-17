FROM debian:trixie-slim@sha256:4bcb9db66237237d03b55b969271728dd3d955eaaa254b9db8a3db94550b1885 AS builder
ARG VERSION

RUN <<'EOF'
set -eux
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    automake \
    autoconf \
    build-essential \
    ca-certificates \
    git \
    libtool \
    make \
    pkg-config \
    libcurl4-openssl-dev \
    libogg-dev \
    libspeex-dev \
    libssl-dev \
    libtheora-dev \
    libvorbis-dev \
    libxml2-dev \
    libxslt1-dev \
    librhash-dev
rm -rf /var/lib/apt/lists/*
EOF

# build and install libigloo >= 0.9.4 (correct upstream)
RUN git clone https://gitlab.xiph.org/xiph/icecast-libigloo.git /tmp/igloo && \
    cd /tmp/igloo && \
    ./autogen.sh && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    rm -rf /tmp/igloo

WORKDIR /build
ADD icecast-$VERSION.tar.gz .
RUN if test ! -d icecast-$VERSION; then mv icecast-* icecast-$VERSION; fi

WORKDIR /build/icecast-$VERSION
RUN ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --localstatedir=/var

RUN make -j$(nproc)
RUN make install DESTDIR=/build/output


# ──────────────────────────────────────────────
FROM debian:trixie-slim@sha256:4bcb9db66237237d03b55b969271728dd3d955eaaa254b9db8a3db94550b1885
ARG VERSION

RUN <<'EOF'
set -eux
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates \
    media-types \
    libcurl4 \
    libogg0 \
    libspeex1 \
    libssl3t64 \
    libtheora0 \
    libvorbis0a \
    libxml2 \
    libxslt1.1 \
    librhash1
rm -rf /var/lib/apt/lists/*
EOF

ENV USER=icecast
RUN useradd --no-create-home $USER

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY xml-edit.sh /usr/local/bin/xml-edit
RUN chmod +x /usr/local/bin/docker-entrypoint /usr/local/bin/xml-edit

COPY --from=builder /build/output /
RUN xml-edit errorlog - /etc/icecast.xml

RUN mkdir -p /var/log/icecast && \
    chown $USER /etc/icecast.xml /var/log/icecast

EXPOSE 8000
USER $USER
ENTRYPOINT ["docker-entrypoint"]
CMD ["icecast", "-c", "/etc/icecast.xml"]
