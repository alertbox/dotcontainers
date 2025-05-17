#!/usr/bin/env bash

set -e

NODE_PACKAGES=${PACKAGES}

echo "Activating feature 'npm-install'."

# The 'install.sh' entrypoint script is always executed as the root user.
export DEBIAN_FRONTEND=noninteractive

install_via_npm() {
  local package=$1
  echo "Installing package ${package}."
  npm install -g "${package}"
}

install() {
  if [ ${#NODE_PACKAGES[@]} -gt 0 ]; then
    local to_install=(`echo ${NODE_PACKAGES} | tr ',' ' '`)
    for package in "${to_install[@]}"
    do
      install_via_npm "${package}" || continue
    done
  fi
}

echo "(*) Installation of Node.js packages ..."

install

echo "Done!"
