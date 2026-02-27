#!/usr/bin/env bash
#
# generate-cap-cache.sh
#
# Generates the C Annotation Processor (CAP) cache required for aarch64
# cross-compilation. The cache records target struct layouts (field offsets,
# type sizes) by compiling and running C code natively on BlackRaspberry.
#
# The resulting cap-cache/ directory is persistent (not under target/) and
# should be committed to version control. Re-run this script if the GraalVM
# version changes.
#
# Prerequisites:
#   - GraalVM CE 25.0.2-graalce installed on BlackRaspberry via sdkman
#   - JAR deployed to BlackRaspberry (run deploy-pi.sh first, or this script
#     will deploy it automatically)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GRAALVM_VERSION="25.0.2-graalce"
NATIVE_IMAGE_PI="\$HOME/.sdkman/candidates/java/${GRAALVM_VERSION}/bin/native-image"
REMOTE_JAR="\$HOME/.local/lib/red-amber-graal/red-amber-graal-libgpio.jar"
REMOTE_CACHE="/tmp/red-amber-graal-libgpio-cap-cache"
LOCAL_CACHE="$PROJECT_ROOT/cap-cache"

# Check native-image is installed on the Pi
if ! ssh blackraspberry "test -x ${NATIVE_IMAGE_PI}"; then
    echo "ERROR: GraalVM CE ${GRAALVM_VERSION} not found on BlackRaspberry."
    echo "  ssh blackraspberry && sdk install java ${GRAALVM_VERSION}"
    exit 1
fi

echo "==> Building JAR..."
mvn -f "$PROJECT_ROOT/pom.xml" package -DskipTests

JAR=$(ls "$PROJECT_ROOT"/target/red-amber-graal-libgpio-*.jar | head -1)

echo "==> Deploying JAR to BlackRaspberry..."
ssh blackraspberry "mkdir -p ~/.local/lib/red-amber-graal"
scp "$JAR" blackraspberry:~/.local/lib/red-amber-graal/red-amber-graal-libgpio.jar

echo "==> Generating CAP cache on BlackRaspberry..."
ssh blackraspberry "
    rm -rf ${REMOTE_CACHE} && mkdir -p ${REMOTE_CACHE}
    ${NATIVE_IMAGE_PI} \
        -H:+NewCAPCache \
        -H:+ExitAfterCAPCache \
        -H:CAPCacheDir=${REMOTE_CACHE} \
        -cp ${REMOTE_JAR} \
        dev.lofthouse.App
"

echo "==> Fetching CAP cache..."
mkdir -p "$LOCAL_CACHE"
scp "blackraspberry:${REMOTE_CACHE}/*" "$LOCAL_CACHE/"

echo "==> Done. Cache written to $LOCAL_CACHE"
echo "    Commit cap-cache/ to version control."
echo "    Re-run this script if the GraalVM version changes."
