#!/usr/bin/env bash

set -e

BUN_VERSION=${VERSION:-"latest"}

echo "Activating feature 'bun@${BUN_VERSION}'"

# The 'install.sh' entrypoint script is always executed as the root user.
apt_get_update() {
    echo "Running apt-get update..."
    apt-get update -y
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
            apt_get_update
        fi
        apt-get -y install --no-install-recommends "$@"
    fi
}

export DEBIAN_FRONTEND=noninteractive

check_packages curl unzip

install() {
    # Download and run the installer:
    case "${BUN_VERSION}" in
        latest) curl --proto '=https' --tlsv1.2 -fsSL https://bun.sh/install | bash ;;
        *)      curl --proto '=https' --tlsv1.2 -fsSL https://bun.sh/install | bash -s "bun-v${BUN_VERSION}" ;;
    esac

    # Symlink the bun binary to /usr/local/bin
    ln -sf $HOME/.bun/bin/bun /usr/local/bin/bun
    ln -sf $HOME/.bun/bin/bunx /usr/local/bin/bunx
}

echo "(*) Installing Bun..."

install

echo "Done!"
