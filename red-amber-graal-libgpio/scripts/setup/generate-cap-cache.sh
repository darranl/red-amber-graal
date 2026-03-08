#!/usr/bin/env bash
# Generates the CAP cache for aarch64 cross-compilation via an arm64 Podman container.
# Uses native-image -H:+NewCAPCache -H:+ExitAfterCAPCache, which compiles and runs small
# C query programs to measure aarch64 type layouts, then exits without building a full image.
# Much faster than a full native-image build — expected to complete in under a minute under QEMU.
#
# Replaces the previous Pi SSH-based approach. No Pi connectivity required.
#
# Usage:
#   ./generate-cap-cache.sh [--skip-jar-build] [--cap-cache-dir=PATH]
#
#   --skip-jar-build     Omit the 'mvn package -DskipTests' step (avoids recursive Maven call)
#   --cap-cache-dir=PATH Write cache to PATH instead of target/cap-cache
#
# Prerequisites:
#   - Podman installed
#   - QEMU aarch64 binfmt registered (run: make setup-podman)
#   - ghcr.io/lofthouse-dev/graalvm-pi-builder:bookworm-graal25 image available locally
#     (build with: cd ../graalvm-pi-builder && make build-dev)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_TAG="ghcr.io/lofthouse-dev/graalvm-pi-builder:bookworm-graal25"
JAR_NAME="red-amber-graal-libgpio-0.0.1-SNAPSHOT.jar"
CAP_CACHE_DIR="$PROJECT_ROOT/target/cap-cache"
SKIP_JAR_BUILD=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --skip-jar-build)
            SKIP_JAR_BUILD=true
            ;;
        --cap-cache-dir=*)
            CAP_CACHE_DIR="${arg#--cap-cache-dir=}"
            ;;
        *)
            echo "ERROR: Unknown argument: $arg"
            exit 1
            ;;
    esac
done

# Early-exit if cache already present
if compgen -G "$CAP_CACHE_DIR/*.cap" > /dev/null 2>&1; then
    echo "==> CAP cache up to date at $CAP_CACHE_DIR, skipping."
    exit 0
fi

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

# Build the JAR (unless called from Maven lifecycle to avoid recursive invocation)
if [ "$SKIP_JAR_BUILD" = false ]; then
    echo "==> Building JAR..."
    mvn -f "$PROJECT_ROOT/pom.xml" package -DskipTests
fi

JAR_PATH="$PROJECT_ROOT/target/$JAR_NAME"
if [ ! -f "$JAR_PATH" ]; then
    echo "ERROR: JAR not found at $JAR_PATH"
    exit 1
fi

# Verify container image is available
if ! podman image exists "$IMAGE_TAG"; then
    echo "ERROR: Container image $IMAGE_TAG not found."
    echo "  Build it with: cd ../graalvm-pi-builder && make build-dev"
    exit 1
fi
echo "==> Using container image $IMAGE_TAG"

# Generate CAP cache inside arm64 container
mkdir -p "$CAP_CACHE_DIR"
echo "==> Generating CAP cache inside arm64 container (QEMU)..."
podman run --rm \
    --platform=linux/arm64 \
    -v "$PROJECT_ROOT/target":/build:Z \
    -v "$CAP_CACHE_DIR":/cap-cache:Z \
    "$IMAGE_TAG" \
    native-image \
        -H:+NewCAPCache \
        -H:+ExitAfterCAPCache \
        -H:CAPCacheDir=/cap-cache \
        -cp "/build/$JAR_NAME" \
        dev.lofthouse.App

echo "==> Done. Cache written to $CAP_CACHE_DIR"
echo "    Re-run after 'mvn clean', a GraalVM CE upgrade, or a Pi OS/glibc update."
