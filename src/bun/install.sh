#!/usr/bin/env bash

set -e

# Clean up.
rm -rf /var/lib/apt/lists/*

# This script installs Bun, a fast all-in-one JavaScript runtime.
# Source: https://bun.sh/install
#         https://github.com/oven-sh/bun/tree/main/dockerhub

# https://github.com/oven-sh/bun/releases
BUN_VERSION=${VERSION:-"latest"}
# https://bun.sh/docs/cli/add
BUN_PACKAGES=${PACKAGES}

echo "Activating feature 'bun'"

# The 'install.sh' entrypoint script is always executed as the root user.
#
# These following environment variables are passed in by the dev container CLI.
# These may be useful in instances where the context of the final
# remoteUser or containerUser is useful.
# For more details, see https://containers.dev/implementors/features#user-env-var

export DEBIAN_FRONTEND=noninteractive

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

check_packages ca-certificates curl dirmngr gpg gpg-agent unzip

command -v unzip >/dev/null ||
    (echo "error: unzip is required to install bun" && exit 1)

arch="$(dpkg --print-architecture)"
case "${arch##*-}" in
    amd64) build="x64-baseline";;
    arm64) build="aarch64";;
    *) echo "error: unsupported architecture: $arch"; exit 1 ;;
esac

version="$BUN_VERSION"
case "$version" in
    latest | canary | bun-v*) tag="$version"; ;;
    v*)                       tag="bun-$version"; ;;
    *)                        tag="bun-v$version"; ;;
esac

case "$tag" in
    latest) release="latest/download"; ;;
    *)      release="download/$tag"; ;;
esac

# Ensure `bun install -g` works
install_env=BUN_INSTALL
bin_env=\$$install_env/bin

install_dir=${!install_env:-${_REMOTE_USER_HOME}/.bun}
bin_dir=$install_dir/bin
exe_name=bun
exe=$bin_dir/$exe_name

echo "Installing Bun ($build)..."

curl "https://github.com/oven-sh/bun/releases/$release/bun-linux-$build.zip" -fsSLO --compressed --retry 5 ||
      (echo "error: failed to download: $tag" && exit 1)

unzip "bun-linux-$build.zip" ||
    (echo "error: failed to unzip bun." && exit 1)

if [[ ! -d $bin_dir ]]; then
    mkdir -p "$bin_dir" ||
        (echo "error: failed to create install directory \"$bin_dir\"." && exit 1)
fi
mv "bun-linux-$build/$exe_name" $exe ||
    (echo "error: failed to move extracted bun to destination." && exit 1)

chmod +x $exe ||
    (echo "error: failed to set permission on bun executable." && exit 1)

commands=(
    "export $install_env=\"$install_dir\""
    "export PATH=\"$bin_env:\$PATH\""
)

bash_configs=(
    "${_REMOTE_USER_HOME}/.bashrc"
    "${_REMOTE_USER_HOME}/.bash_profile"
)

if [[ ${XDG_CONFIG_HOME:-} ]]; then
    bash_configs+=(
        "$XDG_CONFIG_HOME/.bash_profile"
        "$XDG_CONFIG_HOME/.bashrc"
        "$XDG_CONFIG_HOME/bash_profile"
        "$XDG_CONFIG_HOME/bashrc"
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

# If packages are requested, loop through and install
if [ ${#BUN_PACKAGES[@]} -gt 0 ]; then
    packages=(`echo ${BUN_PACKAGES} | tr ',' ' '`)
    for i in "${packages[@]}"
    do
        echo "Installing package ${i}"
        su ${_REMOTE_USER} -c "$exe add --global ${i}" || continue
    done
fi

rm -rf "bun-linux-$build.zip"

echo "Done!"
