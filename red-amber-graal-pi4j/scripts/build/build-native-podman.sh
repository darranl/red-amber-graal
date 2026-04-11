#!/usr/bin/env bash
# NOT VIABLE: Podman/QEMU native build hung overnight during testing — impractical build time.
# Use deploy-pi-native.sh (Maven cross-compile via container sysroot) instead.
# Preserved for debugging purposes only.
#
# Original intent: build via a Podman arm64 container under QEMU to work around the
# GraalVM CE 25.0.2 cross-compile ClassCastException. That bug is now fixed via the
# -J-Djdk.internal.foreign.CABI=LINUX_AARCH_64 property in pom.xml. See
# notes/graalvm-ffm-cross-compile-bug.md.
#
# Prerequisites:
#   - Podman installed
#   - qemu-user-static + qemu-user-static-binfmt installed (run: make setup-podman)
#   - /proc/sys/fs/binfmt_misc/qemu-aarch64 exists
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_TAG="ghcr.io/lofthouse-dev/graalvm-pi-builder:bookworm-graal25"
JAR_NAME="red-amber-graal-pi4j-0.0.1-SNAPSHOT.jar"
BINARY_NAME="red-amber-graal-pi4j-native"

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

# --- Verify container image is available -------------------------------------

if ! podman image exists "$IMAGE_TAG"; then
    echo "ERROR: Container image $IMAGE_TAG not found."
    echo "  Build it with: cd ../graalvm-pi-builder && make build-dev"
    exit 1
fi
echo "==> Using container image $IMAGE_TAG"

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
