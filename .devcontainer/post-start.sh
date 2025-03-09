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