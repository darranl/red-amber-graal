#!/usr/bin/env bash
#
# deploy-pi-native-on-pi.sh
#
# Builds a GraalVM native image directly on BlackRaspberry (aarch64 → aarch64,
# no cross-compiler or sysroot needed) and installs the binary in place.
#
# This is the preferred native-image path when cross-compilation is not
# available (see notes/graalvm-ffm-cross-compile-bug.md). BlackRaspberry (4B,
# 4 GB RAM) can complete the build in ~5 minutes. This path is not viable on
# the Pi Zero 2 W (512 MB RAM).
#
# Prerequisites:
#   - JAVA_HOME set to a GraalVM CE installation locally
#   - The same GraalVM CE installation present on BlackRaspberry at the same path
#   - SSH access to 'blackraspberry'

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

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

# Pi GraalVM mirrors local JAVA_HOME — same absolute path on both machines
NATIVE_IMAGE_PI="${JAVA_HOME}/bin/native-image"
REMOTE_JAR="\$HOME/.local/lib/red-amber-graal/red-amber-graal-libgpio.jar"
REMOTE_BUILD_DIR="/tmp/red-amber-graal-native-build"

# Check native-image exists on the Pi at the mirrored path
if ! ssh blackraspberry "test -x ${NATIVE_IMAGE_PI}"; then
    echo "ERROR: native-image not found on BlackRaspberry at ${NATIVE_IMAGE_PI}"
    echo "  Ensure the same GraalVM CE is installed on BlackRaspberry at the same path"
    exit 1
fi

echo "==> Building JAR..."
mvn -f "$PROJECT_ROOT/pom.xml" package -DskipTests

JAR=$(ls "$PROJECT_ROOT"/target/red-amber-graal-libgpio-*.jar | head -1)

echo "==> Deploying JAR to BlackRaspberry..."
ssh blackraspberry "mkdir -p ~/.local/lib/red-amber-graal"
scp "$JAR" blackraspberry:~/.local/lib/red-amber-graal/red-amber-graal-libgpio.jar

echo "==> Building native image on BlackRaspberry..."
ssh blackraspberry "
    rm -rf ${REMOTE_BUILD_DIR} && mkdir -p ${REMOTE_BUILD_DIR}
    cd ${REMOTE_BUILD_DIR}
    ${NATIVE_IMAGE_PI} \
        --no-fallback \
        --enable-native-access=ALL-UNNAMED \
        -cp ${REMOTE_JAR} \
        -H:Name=red-amber-graal-libgpio-native \
        dev.lofthouse.App
    mkdir -p ~/.local/bin
    mv red-amber-graal-libgpio-native ~/.local/bin/red-amber-graal-libgpio-native
    rm -rf ${REMOTE_BUILD_DIR}
"

echo "==> Done."
