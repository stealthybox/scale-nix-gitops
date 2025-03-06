#!/bin/bash

sudo service nix-daemon start

# Auto-activate the flox environment in the workspace directory
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
