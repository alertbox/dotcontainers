#!/usr/bin/env bash

# The 'install.sh' entrypoint script is always executed as the root user.
#
# This script installs OpenTofu.
# Source: https://bun.sh/install
#         https://github.com/oven-sh/bun/tree/main/dockerhub

set -e

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
            echo "Running apt-get update..."
            apt-get update -qq
        fi
        apt-get -qq install --no-install-recommends "$@"
        apt-get clean
    fi
}

export DEBIAN_FRONTEND=noninteractive

# https://github.com/opentofu/opentofu/releases
VERSION=${VERSION:-"latest"}

echo "Activating feature 'tofu'"

# Clean up.
rm -rf /var/lib/apt/lists/*

check_packages ca-certificates curl dirmngr gpg gpg-agent

case "${VERSION}" in
    latest | v*) TAG="$VERSION"; ;;
    *)           TAG="v${VERSION}"; ;;
esac

INSTALLER="install-opentofu.sh"

# Download the installer script:
curl "https://get.opentofu.org/${INSTALLER}" --proto '=https' --tlsv1.2 -fsSLO --compressed --retry 5 ||
      (echo "error: failed to download: ${TAG}" && exit 1)

# Give it execution permissions:
chmod +x $INSTALLER

su ${_REMOTE_USER} -c "./${INSTALLER} --install-method deb --opentofu-version ${VERSION}" ||
    (echo "error: failed to install tofu." && exit 1)

# Clean up
rm -rf $INSTALLER

echo "Done!"
