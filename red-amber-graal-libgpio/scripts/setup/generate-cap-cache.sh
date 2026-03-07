#!/usr/bin/env bash
# Generates the CAP cache for aarch64 cross-compilation via an arm64 Podman container.
# Uses native-image -H:+NewCAPCache -H:+ExitAfterCAPCache, which compiles and runs small
# C query programs to measure aarch64 type layouts, then exits without building a full image.
# Much faster than a full native-image build — expected to complete in under a minute under QEMU.
#
# Replaces the previous Pi SSH-based approach. No Pi connectivity required.
#
# Prerequisites:
#   - Podman installed
#   - QEMU aarch64 binfmt registered (run: make setup-podman)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_TAG="red-amber-graal-builder:25.0.2"
JAR_NAME="red-amber-graal-libgpio-0.0.1-SNAPSHOT.jar"
LOCAL_CACHE="$PROJECT_ROOT/cap-cache"

# Preflight checks
if ! command -v podman &>/dev/null; then
    echo "ERROR: podman not found."
    exit 1
fi

if [ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
    echo "ERROR: QEMU aarch64 binfmt handler not registered."
    echo "  Run: make setup-podman"
    exit 1
fi

# Build the JAR
echo "==> Building JAR..."
mvn -f "$PROJECT_ROOT/pom.xml" package -DskipTests

JAR_PATH="$PROJECT_ROOT/target/$JAR_NAME"
if [ ! -f "$JAR_PATH" ]; then
    echo "ERROR: JAR not found at $JAR_PATH"
    exit 1
fi

# Build/reuse container image
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

# Generate CAP cache inside arm64 container
mkdir -p "$LOCAL_CACHE"
echo "==> Generating CAP cache inside arm64 container (QEMU)..."
podman run --rm \
    --platform=linux/arm64 \
    -v "$PROJECT_ROOT/target":/build:Z \
    -v "$LOCAL_CACHE":/cap-cache:Z \
    "$IMAGE_TAG" \
    native-image \
        -H:+NewCAPCache \
        -H:+ExitAfterCAPCache \
        -H:CAPCacheDir=/cap-cache \
        -cp "/build/$JAR_NAME" \
        dev.lofthouse.App

echo "==> Done. Cache written to $LOCAL_CACHE"
echo "    Commit cap-cache/ to version control."
echo "    Re-run if the GraalVM CE version changes."
