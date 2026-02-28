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
#   - GraalVM CE installed locally; JAVA_HOME must point to it
#   - The same GraalVM installation present on BlackRaspberry at the same path
#   - Sysroot mounted: systemctl --user start home-darranl-mnt-pios12_root.mount

set -euo pipefail

SYSROOT="$HOME/mnt/pios12_root"

# Check JAVA_HOME is set
if [ -z "${JAVA_HOME:-}" ]; then
    echo "ERROR: JAVA_HOME is not set"
    echo "  Set JAVA_HOME to a GraalVM CE installation (e.g. via: sdk use java 25.0.2-graalce)"
    exit 1
fi

LOCAL_GRAAL="${JAVA_HOME}"

# Check JAVA_HOME points to GraalVM (native-image is the distinguishing binary)
if [ ! -x "${LOCAL_GRAAL}/bin/native-image" ]; then
    echo "ERROR: JAVA_HOME does not appear to be a GraalVM CE installation: ${LOCAL_GRAAL}"
    echo "  native-image not found at ${LOCAL_GRAAL}/bin/native-image"
    echo "  Set JAVA_HOME to a GraalVM CE installation (e.g. via: sdk use java 25.0.2-graalce)"
    exit 1
fi

# Check sysroot is mounted
if [ ! -d "${SYSROOT}/usr/include" ]; then
    echo "ERROR: Sysroot not mounted at ${SYSROOT}"
    echo "  systemctl --user start home-darranl-mnt-pios12_root.mount"
    exit 1
fi

# Pi GraalVM mirrors local JAVA_HOME — same path, rooted at the sysroot
PI_GRAAL="${SYSROOT}${LOCAL_GRAAL}"
echo "==> Local GraalVM: ${LOCAL_GRAAL}"
echo "==> Pi GraalVM:    ${PI_GRAAL}"

if [ ! -d "${PI_GRAAL}" ]; then
    echo "ERROR: Pi GraalVM not found at ${PI_GRAAL}"
    echo "  Ensure sysroot is mounted and the same GraalVM is installed on BlackRaspberry"
    exit 1
fi

echo "==> Setting up aarch64 static library symlinks for cross-compilation..."

# JDK static libs: libjava.a, libnio.a, libnet.a etc.
STATIC_LINK="${LOCAL_GRAAL}/lib/static/linux-aarch64"
STATIC_TARGET="${PI_GRAAL}/lib/static/linux-aarch64"

if [ -L "${STATIC_LINK}" ] && [ "$(readlink "${STATIC_LINK}")" = "${STATIC_TARGET}" ]; then
    echo "    Already correct (symlink): ${STATIC_LINK}"
elif [ -L "${STATIC_LINK}" ]; then
    ln -sfn "${STATIC_TARGET}" "${STATIC_LINK}"
    echo "    Updated: ${STATIC_LINK} -> ${STATIC_TARGET}"
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

if [ -L "${CLIB_LINK}" ] && [ "$(readlink "${CLIB_LINK}")" = "${CLIB_TARGET}" ]; then
    echo "    Already correct (symlink): ${CLIB_LINK}"
elif [ -L "${CLIB_LINK}" ]; then
    ln -sfn "${CLIB_TARGET}" "${CLIB_LINK}"
    echo "    Updated: ${CLIB_LINK} -> ${CLIB_TARGET}"
elif [ -e "${CLIB_LINK}" ]; then
    echo "ERROR: ${CLIB_LINK} already exists and is not a symlink — remove it manually first"
    exit 1
else
    ln -s "${CLIB_TARGET}" "${CLIB_LINK}"
    echo "    Created: ${CLIB_LINK} -> ${CLIB_TARGET}"
fi

echo "==> Done. Run deploy-pi-native.sh to build and deploy the native binary."
