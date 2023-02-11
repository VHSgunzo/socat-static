#!/usr/bin/env bash

set -e
set -o pipefail
set -x

platform_arch="$(uname -m)"
export MAKEFLAGS="-j$(nproc)"
platform="$(uname -s|tr 'A-Z' 'a-z')"
OUT_DIR="/output/$platform/$platform_arch"

# Check for the latest versions of these packages
SOCAT_VERSION=1.7.4.4
NCURSES_VERSION=6.4
READLINE_VERSION=8.2
OPENSSL_VERSION=1.1.1s

build_ncurses() {
    cd /build

    # Download
    curl -LO http://invisible-mirror.net/archives/ncurses/ncurses-${NCURSES_VERSION}.tar.gz
    tar zxvf ncurses-${NCURSES_VERSION}.tar.gz
    cd ncurses-${NCURSES_VERSION}

    # Build
    CC='/usr/bin/gcc -static' CFLAGS='-fPIC' ./configure \
        --disable-shared \
        --enable-static
}

build_readline() {
    cd /build

    # Download
    curl -LO ftp://ftp.cwru.edu/pub/bash/readline-${READLINE_VERSION}.tar.gz
    tar xzvf readline-${READLINE_VERSION}.tar.gz
    cd readline-${READLINE_VERSION}

    # Build
    CC='/usr/bin/gcc -static' CFLAGS='-fPIC' ./configure \
        --disable-shared \
        --enable-static
    make

    # Note that socat looks for readline in <readline/readline.h>, so we need
    # that directory to exist.
    ln -s /build/readline-${READLINE_VERSION} /build/readline
}

build_openssl() {
    cd /build

    # Download
    curl -LO https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
    tar zxvf openssl-${OPENSSL_VERSION}.tar.gz
    cd openssl-${OPENSSL_VERSION}

    # Configure
    CC='/usr/bin/gcc -static' ./Configure no-shared no-async linux-x86_64

    # Build
    make
    echo "** Finished building OpenSSL"
}

build_socat() {
    cd /build

    # Download
    curl -LO http://www.dest-unreach.org/socat/download/socat-${SOCAT_VERSION}.tar.gz
    tar xzvf socat-${SOCAT_VERSION}.tar.gz
    cd socat-${SOCAT_VERSION}

    # Build
    # NOTE: `NETDB_INTERNAL` is non-POSIX, and thus not defined by MUSL.
    # We define it this way manually.
    CC='/usr/bin/gcc -static' \
        CFLAGS='-fPIC' \
        CPPFLAGS="-I/build -I/build/openssl-${OPENSSL_VERSION}/include -DNETDB_INTERNAL=-1" \
        LDFLAGS="-L/build/readline-${READLINE_VERSION} -L/build/ncurses-${NCURSES_VERSION}/lib \
        $([ "$NO_OPENSSL" != 1 ] && echo "-L/build/openssl-${OPENSSL_VERSION}")" \
        ./configure $([ "$NO_OPENSSL" == 1 ] && echo "--disable-openssl")
    make
    make strip
    make DESTDIR="$OUT_DIR" install
}

build_ncurses
build_readline
[ "$NO_OPENSSL" != 1 ] && \
    build_openssl
build_socat

if [ -d "/output" ]
    then
        #mkdir -p "$OUT_DIR"
        #cp /build/socat-${SOCAT_VERSION}/socat "$OUT_DIR"/
        (cd "/output" && tar -acvf socat$([ "$NO_OPENSSL" == 1 ] && \
            echo "-no-openssl")-${SOCAT_VERSION}.tar.xz \
            -C "/output" "$platform/$platform_arch")
        rm -rf "/output/$platform"
        echo "** Finished **"
    else
        echo "** /output does not exist **"
        exit 1
fi
