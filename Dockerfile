ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm
FROM $BUILD_FROM as builder

LABEL maintainer="pavlov@pavlov.net"

ENV LANG C.UTF-8

# Install build dependencies
RUN apt-get update && apt-get install -y \
    libusb-dev \
    libusb-1.0-0-dev \
    libssl-dev \
    cmake \
    git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

# --- Stage: Build librtlsdr ---
FROM builder as librtlsdr_builder

ARG librtlsdrGitRevision=cd36c28815592af4080d71181964909125a74f44 # v0.9.0

WORKDIR /build
RUN git clone https://github.com/librtlsdr/librtlsdr
WORKDIR /build/librtlsdr

RUN git checkout ${librtlsdrGitRevision}

# Build and install to staging root
RUN mkdir build && cd build && \
    cmake .. && \
    make -j4 && \
    make DESTDIR=/build/root/ install

# --- Stage: Build rtl_433 ---
FROM builder as rtl_433_builder

# Copy librtlsdr output to be available during rtl_433 build
COPY --from=librtlsdr_builder /build/root/usr/local /usr/local

WORKDIR /build
RUN git clone https://github.com/merbanan/rtl_433
WORKDIR /build/rtl_433

ARG rtl433GitRevision=ea7d504877df751a202432d47dbb0c425ab0a93c # 25.12
RUN git checkout ${rtl433GitRevision}

# Build and install to staging root
RUN mkdir build && cd build && \
    cmake .. && \
    make -j4 && \
    make DESTDIR=/build/root/ install

# --- Stage: Final image ---
FROM $BUILD_FROM

ENV LANG C.UTF-8

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y \
    libusb-1.0-0 \
    sed \
    gettext-base && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /root

# Copy installed binaries and libraries from both build stages
COPY --from=librtlsdr_builder /build/root/ /
COPY --from=rtl_433_builder /build/root/ /

# Ensure librtlsdr is available
RUN ldconfig

# Include run script and default config template
COPY run.sh /
COPY rtl_433.conf.template /
RUN chmod +x /run.sh

CMD ["/run.sh"]