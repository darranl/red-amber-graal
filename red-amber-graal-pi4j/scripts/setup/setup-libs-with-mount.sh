#!/usr/bin/env bash
# Mounts the graalvm-pi-builder container image and runs setup-aarch64-libs.sh.
# Called by 'make setup-libs'. For direct use or debugging without a full deploy.
#
# Rootless Podman requires 'podman image mount' to run inside a user namespace;
# this script re-invokes itself inside 'podman unshare' automatically.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="ghcr.io/lofthouse-dev/graalvm-pi-builder:bookworm-graal25"

if [ "${_IN_UNSHARE:-}" != "1" ]; then
    exec _IN_UNSHARE=1 podman unshare -- "$0" "$@"
fi

SYSROOT="$("$SCRIPT_DIR/mount-image-sysroot.sh")"
echo "    Sysroot: $SYSROOT"

cleanup() {
    "$SCRIPT_DIR/unmount-image-sysroot.sh" || true
}
trap cleanup EXIT

SYSROOT="$SYSROOT" SYSROOT_GRAALVM_HOME=/opt/graalvm \
    "$SCRIPT_DIR/setup-aarch64-libs.sh"
