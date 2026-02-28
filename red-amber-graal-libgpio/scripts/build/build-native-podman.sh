#!/usr/bin/env bash
# Build the aarch64 native binary via a Podman arm64 container under QEMU.
# This avoids the GraalVM CE 25.0.2 cross-compile bug where ForeignFunctionsFeature
# selects the host ABI (AMD64) instead of the target ABI (AArch64), crashing with
# a ClassCastException.  See notes/graalvm-ffm-cross-compile-bug.md.
#
# Prerequisites:
#   - Podman installed
#   - qemu-user-static + qemu-user-static-binfmt installed (run: make setup-podman)
#   - /proc/sys/fs/binfmt_misc/qemu-aarch64 exists
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_TAG="red-amber-graal-builder:25.0.2"
JAR_NAME="red-amber-graal-libgpio-0.0.1-SNAPSHOT.jar"
BINARY_NAME="red-amber-graal-libgpio-native"

# --- Preflight checks --------------------------------------------------------

if ! command -v podman &>/dev/null; then
    echo "ERROR: podman not found."
    exit 1
fi

if [ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
    echo "ERROR: QEMU aarch64 binfmt handler not registered."
    echo "  Run: make setup-podman"
    exit 1
fi

# --- Build the JAR -----------------------------------------------------------

echo "==> Building JAR..."
mvn -f "$PROJECT_ROOT/pom.xml" package -DskipTests

JAR_PATH="$PROJECT_ROOT/target/$JAR_NAME"
if [ ! -f "$JAR_PATH" ]; then
    echo "ERROR: JAR not found at $JAR_PATH"
    exit 1
fi

# --- Build the container image (skip if already exists) ----------------------

if podman image exists "$IMAGE_TAG"; then
    echo "==> Container image $IMAGE_TAG already exists, skipping build."
    echo "    To rebuild: podman rmi $IMAGE_TAG"
else
    echo "==> Building container image $IMAGE_TAG (arm64, downloads GraalVM CE 25.0.2)..."
    podman build \
        --platform=linux/arm64 \
        --tag "$IMAGE_TAG" \
        "$PROJECT_ROOT"
fi

# --- Run native-image inside the container -----------------------------------

echo "==> Running native-image inside arm64 container..."
podman run --rm \
    --platform=linux/arm64 \
    -v "$PROJECT_ROOT/target":/build:Z \
    "$IMAGE_TAG" \
    native-image \
        --no-fallback \
        --enable-native-access=ALL-UNNAMED \
        -cp "/build/$JAR_NAME" \
        dev.lofthouse.App \
        -o "/build/$BINARY_NAME"

BINARY_PATH="$PROJECT_ROOT/target/$BINARY_NAME"
if [ ! -f "$BINARY_PATH" ]; then
    echo "ERROR: native-image did not produce $BINARY_PATH"
    exit 1
fi

echo "==> Native binary built: $BINARY_PATH"
echo "    ($(du -h "$BINARY_PATH" | cut -f1))"
