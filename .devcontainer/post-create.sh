#!/bin/bash

# Fix permissions for Nix builds (  https://github.com/NixOS/nix/issues/6680#issuecomment-1230902525  )
echo "
Fixing permissions for Nix
  https://github.com/NixOS/nix/issues/6680#issuecomment-1230902525
"
sudo flox activate -d /root/ -- \
  setfacl -k /tmp
if [ -e /dev/kvm ]; then
  sudo chgrp $(id -g) /dev/kvm;
fi

# Ensure Nix is running
sudo service nix-daemon start

# Auto-activate the flox environment in the workspace devcontainer and $PWD
echo '
    if command -v flox >/dev/null; then
    [ -d "${PWD}/.devcontainer/.flox" ] \
        && eval "$(flox activate -m run -d "${PWD}/.devcontainer")"

    [ "$PWD" != "$HOME" ] \
        && [ -d .flox ] \
        && eval "$(flox activate -m dev)"
    fi
' >> ~/.bashrc

# Ensure the kind cluster and registry exist
# Use the .flox env to put `kind` on the PATH
time flox activate -d .devcontainer -- .devcontainer/kind-with-registry.sh
