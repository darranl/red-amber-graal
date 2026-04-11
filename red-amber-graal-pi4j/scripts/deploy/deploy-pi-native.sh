#!/usr/bin/env bash
# Cross-compile an aarch64 native binary via Maven and deploy it to BlackRaspberry.
#
# Uses the graalvm-pi-builder container image as the aarch64 sysroot. Rootless
# Podman requires 'podman image mount' to run inside a user namespace — this
# script re-invokes itself inside 'podman unshare' automatically for the build
# phase, then returns to the outer shell for the deploy (scp) phase.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
IMAGE="ghcr.io/lofthouse-dev/graalvm-pi-builder:bookworm-graal25"
BINARY_NAME="red-amber-graal-pi4j-native"

# Check JAVA_HOME is set and points to GraalVM
if [ -z "${JAVA_HOME:-}" ]; then
    echo "ERROR: JAVA_HOME is not set"
    echo "  Set JAVA_HOME to a GraalVM CE installation (e.g. via: sdk use java 25.0.2-graalce)"
    exit 1
fi
if [ ! -x "${JAVA_HOME}/bin/native-image" ]; then
    echo "ERROR: JAVA_HOME does not appear to be a GraalVM CE installation: ${JAVA_HOME}"
    echo "  native-image not found at ${JAVA_HOME}/bin/native-image"
    exit 1
fi

# BUILD PHASE — runs inside 'podman unshare' for rootless image mount access
if [ "${_BUILD_PHASE:-}" = "1" ]; then
    echo "==> Mounting container image as sysroot..."
    SYSROOT="$("$PROJECT_ROOT/scripts/setup/mount-image-sysroot.sh")"
    echo "    Sysroot: $SYSROOT"

    cleanup() {
        echo "==> Unmounting container image sysroot..."
        "$PROJECT_ROOT/scripts/setup/unmount-image-sysroot.sh" || true
    }
    trap cleanup EXIT

    export SYSROOT
    export SYSROOT_GRAALVM_HOME=/opt/graalvm
    "$PROJECT_ROOT/scripts/setup/setup-aarch64-libs.sh"

    echo "==> Building native aarch64 binary..."
    mvn -f "$PROJECT_ROOT/pom.xml" package -DskipTests -Dnative "-Dsysroot=$SYSROOT" \
        "-Dmaven.repo.local=${MAVEN_LOCAL_REPO}"
    exit 0
fi

# OUTER PHASE — enter podman unshare for the build, then deploy
# Capture HOME-relative paths before unshare remaps $HOME to /root
export MAVEN_LOCAL_REPO="${HOME}/.m2/repository"

echo "==> Entering podman unshare for sysroot mount..."
_BUILD_PHASE=1 podman unshare -- "$0"

# Deploy phase runs outside unshare — scp does not need the sysroot
BINARY="$PROJECT_ROOT/target/$BINARY_NAME"

echo "==> Creating ~/.local/bin on BlackRaspberry..."
ssh blackraspberry "mkdir -p ~/.local/bin"

echo "==> Deploying native binary..."
scp "$BINARY" "blackraspberry:~/.local/bin/$BINARY_NAME"

echo "==> Done."
