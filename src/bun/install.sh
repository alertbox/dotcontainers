#!/usr/bin/env bash

set -e

# This script installs Bun, a fast all-in-one JavaScript runtime.
# Source: https://github.com/oven-sh/bun/tree/main/dockerhub

# https://github.com/oven-sh/bun/releases
BUN_VERSION=${VERSION:-"latest"}

echo "Activating feature 'bun@${BUN_VERSION}'"

# The 'install.sh' entrypoint script is always executed as the root user.
apt_get_update() {
    echo "Running apt-get update..."
    apt-get update -qq
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
            apt_get_update
        fi
        apt-get -qq install --no-install-recommends "$@"

        apt-get clean
        rm -rf /var/lib/apt/lists/*
    fi
}

export DEBIAN_FRONTEND=noninteractive

check_packages ca-certificates curl dirmngr gpg gpg-agent unzip


arch="$(dpkg --print-architecture)"
case "${arch##*-}" in
    amd64) build="x64-baseline";;
    arm64) build="aarch64";;
    *) echo "error: unsupported architecture: $arch"; exit 1 ;;
esac

case "$BUN_VERSION" in
    latest | canary | bun-v*) tag="$BUN_VERSION"; ;;
    v*)                       tag="bun-$BUN_VERSION"; ;;
    *)                        tag="bun-v$BUN_VERSION"; ;;
esac

case "$tag" in
    latest) release="latest/download"; ;;
    *)      release="download/$tag"; ;;
esac

echo "(*) Installing Bun..."

curl -fsSLO --compressed --retry 5 "https://github.com/oven-sh/bun/releases/$release/bun-linux-$build.zip" \
    || (echo "error: failed to download: $tag" && exit 1)

for key in "F3DCC08A8572C0749B3E18888EAB4D40A7B22B59"; do
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" ;
done

curl -fsSLO --compressed --retry 5 "https://github.com/oven-sh/bun/releases/$release/SHASUMS256.txt.asc"
gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc || (echo "error: failed to verify: $tag" && exit 1)
grep " bun-linux-$build.zip\$" SHASUMS256.txt | sha256sum -c - || (echo "error: failed to verify: $tag" && exit 1)

# Ensure `bun install -g` works
unzip "bun-linux-$build.zip"
mv "bun-linux-$build/bun" /usr/local/bin/bun
rm -f "bun-linux-$build.zip" SHASUMS256.txt.asc SHASUMS256.txt
chmod +x /usr/local/bin/bun
which bun && bun --version

# Create a symlink:
ln -s /usr/local/bin/bun /usr/local/bin/bunx
which bunx
mkdir -p /usr/local/bun-node-fallback-bin
ln -s /usr/local/bin/bun /usr/local/bun-node-fallback-bin/nodebun

echo "Done!"
