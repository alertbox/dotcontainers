#!/usr/bin/env bash

set -e

SAM_VERSION=${VERSION:-"latest"}

echo "Activating feature 'aws-sam-cli@${SAM_VERSION}'"

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

check_packages curl ca-certificates gnupg2 dirmngr unzip

install() {
    # See Linux install docs at https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html
    GITHUB=https://github.com
    GITHUB_REPO="${GITHUB}/aws/aws-sam-cli"

    MACHINE_ARCH=$(dpkg --print-architecture)
    case "${MACHINE_ARCH}" in
        amd64) ARCH=x86_64 ;;
        arm64) ARCH=arm64 ;;
        *)
            echo "AWS Serverless CLI (SAM) does not support machine architecture '$MACHINE_ARCH'. Please use an x86-64 or ARM64 machine."
            exit 1
    esac
    TARGET=aws-sam-cli-linux-${ARCH}
    # https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-arm64.zip
    case "${SAM_VERSION}" in
        latest) BINARY_URI=${GITHUB_REPO}/releases/latest/download/${TARGET}.zip ;;
        *)      BINARY_URI=${GITHUB_REPO}/releases/download/v${SAM_VERSION}/${TARGET}.zip ;;
    esac

    curl -OL ${BINARY_URI}
    unzip ${TARGET}.zip -d aws-sam
    ./aws-sam/install
}

echo "(*) Installing AWS Serverless CLI (SAM)..."

install

# Clean up
rm -rf /var/lib/apt/lists/*
rm -rf ${TARGET}.zip
rm -rf ./aws-sam

echo "Done!"
