#!/usr/bin/env bash
#
# setup-aarch64-libs.sh
#
# Creates symlinks in the local GraalVM CE x86_64 installation that point to
# the aarch64 static libraries from a sysroot (container image mount or SSHFS).
# Called automatically by deploy-pi-native.sh before each native build.
#
# Environment variables:
#   SYSROOT               (required) Path to the aarch64 sysroot root directory.
#                         Use mount-image-sysroot.sh to obtain this path from the
#                         graalvm-pi-builder container image.
#   SYSROOT_GRAALVM_HOME  (optional) Path to GraalVM CE inside the sysroot, e.g.
#                         /opt/graalvm for the container image. If unset, defaults
#                         to $JAVA_HOME (matches SSHFS Pi sysroot where GraalVM is
#                         installed at the same sdkman path as locally).
#
# Prerequisites:
#   - GraalVM CE installed locally; JAVA_HOME must point to it
#   - SYSROOT set to a mounted aarch64 filesystem (see mount-image-sysroot.sh)

set -euo pipefail

# Check SYSROOT is set
if [ -z "${SYSROOT:-}" ]; then
    echo "ERROR: SYSROOT environment variable is not set"
    echo "  Use 'make deploy-native' or 'make setup-libs' which set this automatically,"
    echo "  or run: SYSROOT=\$(./scripts/setup/mount-image-sysroot.sh) ./scripts/setup/setup-aarch64-libs.sh"
    exit 1
fi

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

# Check sysroot looks valid
if [ ! -d "${SYSROOT}/usr/include" ]; then
    echo "ERROR: Sysroot does not look valid at ${SYSROOT} (missing usr/include)"
    echo "  Ensure the container image is mounted: ./scripts/setup/mount-image-sysroot.sh"
    exit 1
fi

# Resolve GraalVM path inside the sysroot.
# SYSROOT_GRAALVM_HOME overrides the default (used when sysroot is a container
# image with GraalVM at a fixed path, e.g. /opt/graalvm).
# Without it, assumes GraalVM is at the same path as local JAVA_HOME (SSHFS Pi sysroot).
SYSROOT_GRAAL="${SYSROOT}${SYSROOT_GRAALVM_HOME:-${LOCAL_GRAAL}}"
echo "==> Local GraalVM:  ${LOCAL_GRAAL}"
echo "==> Sysroot GraalVM: ${SYSROOT_GRAAL}"

if [ ! -d "${SYSROOT_GRAAL}" ]; then
    echo "ERROR: GraalVM not found in sysroot at ${SYSROOT_GRAAL}"
    if [ -n "${SYSROOT_GRAALVM_HOME:-}" ]; then
        echo "  Check SYSROOT_GRAALVM_HOME=${SYSROOT_GRAALVM_HOME} is correct for this sysroot"
    else
        echo "  Ensure the sysroot has GraalVM at the same path as local JAVA_HOME: ${LOCAL_GRAAL}"
        echo "  Or set SYSROOT_GRAALVM_HOME to the GraalVM path inside the sysroot"
    fi
    exit 1
fi

echo "==> Setting up aarch64 static library symlinks for cross-compilation..."

# JDK static libs: libjava.a, libnio.a, libnet.a etc.
STATIC_LINK="${LOCAL_GRAAL}/lib/static/linux-aarch64"
STATIC_TARGET="${SYSROOT_GRAAL}/lib/static/linux-aarch64"

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
CLIB_TARGET="${SYSROOT_GRAAL}/lib/svm/clibraries/linux-aarch64"

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

echo "==> Done."
