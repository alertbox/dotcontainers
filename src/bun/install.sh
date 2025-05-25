#!/usr/bin/env bash

# The 'install.sh' entrypoint script is always executed as the root user.
#
# This script installs Bun CLI.
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

# https://github.com/oven-sh/bun/releases
VERSION=${VERSION:-"latest"}
# https://bun.sh/docs/cli/add
PACKAGES=${PACKAGES:-}

echo "Activating feature 'bun'"

# Clean up.
rm -rf /var/lib/apt/lists/*

check_packages ca-certificates curl dirmngr gpg gpg-agent unzip

ARCH="$(dpkg --print-architecture)"
case "${ARCH##*-}" in
    amd64) BUILD="x64-baseline";;
    arm64) BUILD="aarch64";;
    *)     echo "error: unsupported architecture: $ARCH"; exit 1 ;;
esac

case "${VERSION}" in
    latest | canary | bun-v*) TAG="$VERSION"; ;;
    v*)                       TAG="bun-${VERSION}"; ;;
    *)                        TAG="bun-v${VERSION}"; ;;
esac

case "${TAG}" in
    latest) RELEASE="latest/download"; ;;
    *)      RELEASE="download/${TAG}"; ;;
esac

INSTALL_ENV="BUN_INSTALL"
BIN_ENV="\$${INSTALL_ENV}/bin"

INSTALL_DIR="${!INSTALL_ENV:-${_REMOTE_USER_HOME}/.bun}"
BIN_DIR="${INSTALL_DIR}/bin"
EXE="${BIN_DIR}/bun"
ZIP="bun-linux-${BUILD}.zip"

curl "https://github.com/oven-sh/bun/releases/${RELEASE}/${ZIP}" -fsSLO --compressed --retry 5 ||
      (echo "error: failed to download: ${TAG}" && exit 1)

unzip $ZIP ||
    (echo "error: failed to unzip ${ZIP}." && exit 1)

if [[ ! -d $BIN_DIR ]]; then
    mkdir -p $BIN_DIR ||
        (echo "error: failed to create install directory ${BIN_DIR}." && exit 1)
fi

mv "bun-linux-${BUILD}/bun" $EXE ||
    (echo "error: failed to move extracted bun to destination." && exit 1)

chmod +x $EXE ||
    (echo "error: failed to set permission on bun executable." && exit 1)

commands=(
    "export ${INSTALL_ENV}=\"${INSTALL_DIR}\""
    "export PATH=\"${BIN_ENV}:\$PATH\""
)

bash_configs=(
    "${_REMOTE_USER_HOME}/.bashrc"
    "${_REMOTE_USER_HOME}/.bash_profile"
)

if [[ ${XDG_CONFIG_HOME:-} ]]; then
    bash_configs+=(
        "${XDG_CONFIG_HOME}/.bash_profile"
        "${XDG_CONFIG_HOME}/.bashrc"
        "${XDG_CONFIG_HOME}/bash_profile"
        "${XDG_CONFIG_HOME}/bashrc"
    )
fi

for bash_config in "${bash_configs[@]}"; do
    if [[ -w $bash_config ]]; then
        {
            echo -e '\n# bun'
            for command in "${commands[@]}"; do
                echo "$command"
            done
        } >> "$bash_config"
        break
    fi
done

# If packages are requested, install globally.
# Ensure `bun install -g` works.
if [ ${#PACKAGES[@]} -gt 0 ]; then
    su ${_REMOTE_USER} -c "$EXE add --global $PACKAGES"
fi

rm -rf $ZIP

echo "Done!"
