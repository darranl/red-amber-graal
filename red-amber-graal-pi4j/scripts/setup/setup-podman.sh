#!/usr/bin/env bash
# One-time setup: install QEMU user-mode emulation packages on Arch Linux
# so that Podman can run arm64 containers via binfmt_misc.
set -euo pipefail

echo "==> Installing QEMU user-static packages..."
sudo pacman -S --noconfirm qemu-user-static qemu-user-static-binfmt

echo "==> Restarting systemd-binfmt to register QEMU handlers..."
sudo systemctl restart systemd-binfmt

echo "==> Verifying qemu-aarch64 binfmt handler..."
BINFMT_ENTRY=/proc/sys/fs/binfmt_misc/qemu-aarch64
if [ -f "$BINFMT_ENTRY" ]; then
    echo "    OK — $BINFMT_ENTRY exists"
    cat "$BINFMT_ENTRY"
else
    echo "ERROR: $BINFMT_ENTRY not found."
    echo "  Check that qemu-user-static-binfmt is installed and systemd-binfmt ran."
    exit 1
fi

echo ""
echo "==> Podman QEMU setup complete."
echo "    Run 'make deploy-native-podman' to build and deploy the native binary."
