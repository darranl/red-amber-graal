#!/usr/bin/env bash
#
# mount-image-sysroot.sh
#
# Mounts the graalvm-pi-builder container image read-only and prints the mount
# path to stdout. The mount provides an aarch64 Debian bookworm filesystem that
# serves as the cross-compile sysroot for aarch64-linux-gnu-gcc and GraalVM's
# native-image linker.
#
# Does NOT require QEMU — this is a filesystem-level mount operation only.
# The image must be present locally (run 'podman pull IMAGE' to update it).
#
# Must be called from within a 'podman unshare' user namespace — rootless Podman
# requires this for image mount operations. deploy-pi-native.sh and
# setup-libs-with-mount.sh handle this automatically.
#
# Usage (inside podman unshare):
#   SYSROOT=$(./scripts/setup/mount-image-sysroot.sh)

set -euo pipefail

IMAGE="ghcr.io/lofthouse-dev/graalvm-pi-builder:bookworm-graal25"

if ! command -v podman &>/dev/null; then
    echo "ERROR: podman not found" >&2
    exit 1
fi

if ! podman image exists "$IMAGE"; then
    echo "ERROR: Container image not found locally: $IMAGE" >&2
    echo "  Pull it with:  podman pull $IMAGE" >&2
    echo "  Or build it with: cd graalvm-pi-builder && make build" >&2
    exit 1
fi

podman image mount "$IMAGE"
