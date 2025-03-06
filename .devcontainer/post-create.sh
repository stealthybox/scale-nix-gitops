#!/bin/bash

sudo service nix-daemon start

# Auto-activate the flox environment in the workspace directory
echo 'eval "$(flox activate -d "${PWD}/.devcontainer" -m run)"' >> ~/.bashrc

# Ensure the kind cluster and registry exist
# Use the .flox env to put `kind` on the PATH
time flox activate -d .devcontainer -- .devcontainer/kind-with-registry.sh
