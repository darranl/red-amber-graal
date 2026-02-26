#!/usr/bin/env bash
#
# setup-aarch64-libs.sh
#
# Creates symlinks in the local GraalVM CE x86_64 installation that point to
# the aarch64 static libraries from the Pi's GraalVM CE installation (accessed
# via the SSHFS sysroot mount). This is a required one-time setup step before
# running deploy-pi-native.sh.
#
# Prerequisites:
#   - GraalVM CE 25.0.2 installed locally via sdkman (25.0.2-graalce)
#   - GraalVM CE 25.0.2 installed on BlackRaspberry via sdkman (25.0.2-graalce)
#   - Sysroot mounted: systemctl --user start home-darranl-mnt-pios12_root.mount

set -euo pipefail

GRAALVM_VERSION="25.0.2-graalce"
LOCAL_GRAAL="$HOME/.sdkman/candidates/java/${GRAALVM_VERSION}"
SYSROOT="$HOME/mnt/pios12_root"
PI_GRAAL="${SYSROOT}/home/darranl/.sdkman/candidates/java/${GRAALVM_VERSION}"

# Check sysroot is mounted
if [ ! -d "${SYSROOT}/usr/include" ]; then
    echo "ERROR: Sysroot not mounted at ${SYSROOT}"
    echo "  systemctl --user start home-darranl-mnt-pios12_root.mount"
    exit 1
fi

# Check Pi GraalVM installation is accessible
if [ ! -d "${PI_GRAAL}" ]; then
    echo "ERROR: Pi GraalVM CE ${GRAALVM_VERSION} not found at ${PI_GRAAL}"
    echo "  Install on BlackRaspberry: sdk install java ${GRAALVM_VERSION}"
    exit 1
fi

# Check local GraalVM installation exists
if [ ! -d "${LOCAL_GRAAL}" ]; then
    echo "ERROR: Local GraalVM CE ${GRAALVM_VERSION} not found at ${LOCAL_GRAAL}"
    echo "  Install locally: sdk install java ${GRAALVM_VERSION}"
    exit 1
fi

echo "==> Setting up aarch64 static library symlinks for cross-compilation..."

# JDK static libs: libjava.a, libnio.a, libnet.a etc.
STATIC_LINK="${LOCAL_GRAAL}/lib/static/linux-aarch64"
STATIC_TARGET="${PI_GRAAL}/lib/static/linux-aarch64"

if [ -L "${STATIC_LINK}" ]; then
    echo "    Already exists (symlink): ${STATIC_LINK}"
elif [ -e "${STATIC_LINK}" ]; then
    echo "ERROR: ${STATIC_LINK} already exists and is not a symlink — remove it manually first"
    exit 1
else
    ln -s "${STATIC_TARGET}" "${STATIC_LINK}"
    echo "    Created: ${STATIC_LINK} -> ${STATIC_TARGET}"
fi

# SVM C libraries: liblibchelper.a, libjvm.a, libsvm_container.a etc.
CLIB_LINK="${LOCAL_GRAAL}/lib/svm/clibraries/linux-aarch64"
CLIB_TARGET="${PI_GRAAL}/lib/svm/clibraries/linux-aarch64"

if [ -L "${CLIB_LINK}" ]; then
    echo "    Already exists (symlink): ${CLIB_LINK}"
elif [ -e "${CLIB_LINK}" ]; then
    echo "ERROR: ${CLIB_LINK} already exists and is not a symlink — remove it manually first"
    exit 1
else
    ln -s "${CLIB_TARGET}" "${CLIB_LINK}"
    echo "    Created: ${CLIB_LINK} -> ${CLIB_TARGET}"
fi

echo "==> Done. Run deploy-pi-native.sh to build and deploy the native binary."
