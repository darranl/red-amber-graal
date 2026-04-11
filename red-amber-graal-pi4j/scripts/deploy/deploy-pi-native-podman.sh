#!/usr/bin/env bash
# NOT VIABLE: Podman/QEMU native build hung overnight during testing — impractical build time.
# Use deploy-pi-native.sh (Maven cross-compile via container sysroot) instead.
# Preserved for debugging purposes only.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BINARY_NAME="red-amber-graal-pi4j-native"

echo "==> Building native binary via Podman..."
"$PROJECT_ROOT/scripts/build/build-native-podman.sh"

BINARY="$PROJECT_ROOT/target/$BINARY_NAME"

echo "==> Creating ~/.local/bin on BlackRaspberry..."
ssh blackraspberry "mkdir -p ~/.local/bin"

echo "==> Deploying native binary..."
scp "$BINARY" "blackraspberry:~/.local/bin/$BINARY_NAME"

echo "==> Done."
