#!/usr/bin/env bash
#
# unmount-image-sysroot.sh
#
# Unmounts the graalvm-pi-builder container image previously mounted by
# mount-image-sysroot.sh. Called automatically by deploy-pi-native.sh on exit.

set -euo pipefail

IMAGE="ghcr.io/lofthouse-dev/graalvm-pi-builder:bookworm-graal25"

podman image unmount "$IMAGE"
