#!/usr/bin/env bash
# Build the aarch64 native binary via Podman/QEMU and deploy it to BlackRaspberry.
# See scripts/build/build-native-podman.sh for build prerequisites.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BINARY_NAME="red-amber-graal-libgpio-native"

echo "==> Building native binary via Podman..."
"$PROJECT_ROOT/scripts/build/build-native-podman.sh"

BINARY="$PROJECT_ROOT/target/$BINARY_NAME"

echo "==> Creating ~/.local/bin on BlackRaspberry..."
ssh blackraspberry "mkdir -p ~/.local/bin"

echo "==> Deploying native binary..."
scp "$BINARY" "blackraspberry:~/.local/bin/$BINARY_NAME"

echo "==> Done."
