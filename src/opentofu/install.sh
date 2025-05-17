#!/usr/bin/env bash

set -e

OPENTOFU_VERSION=${VERSION:-"latest"}

echo "Activating feature 'opentofu@${OPENTOFU_VERSION}'"

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

check_packages curl

install() {
    # Download the installer script:
    curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh
    # Alternatively: wget --secure-protocol=TLSv1_2 --https-only https://get.opentofu.org/install-opentofu.sh -O install-opentofu.sh

    # Give it execution permissions:
    chmod +x install-opentofu.sh

    # Please inspect the downloaded script

    # Run the installer:
    ./install-opentofu.sh --install-method deb --opentofu-version ${OPENTOFU_VERSION}
}

echo "(*) Installing OpenTofu (Tofu)..."

install

# Clean up
rm -f install-opentofu.sh

echo "Done!"
