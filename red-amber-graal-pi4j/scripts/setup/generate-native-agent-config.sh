#!/usr/bin/env bash
#
# generate-native-agent-config.sh
#
# Runs the Pi4J JAR on BlackRaspberry under the GraalVM native-image-agent to
# generate a correct reachability-metadata.json for all Pi4J FFM downcalls.
#
# Pi4J v4 creates all its FunctionDescriptors in static initialisers, so they
# are captured by the agent even if the app fails immediately on hardware.
# The generated config is written to target/agent-config/ for review before
# being copied to src/main/resources/META-INF/native-image/...
#
# Usage:
#   ./generate-native-agent-config.sh [--skip-jar-build]
#
#   --skip-jar-build  Omit 'mvn package -DskipTests' (use if JAR is already built)
#
# Prerequisites:
#   - JAVA_HOME set to a GraalVM CE installation locally and on BlackRaspberry
#     at the same absolute path (e.g. via: sdk use java 25.0.2-graalce)
#   - SSH access to 'blackraspberry'

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKIP_JAR_BUILD=false
REMOTE_JAR="\$HOME/.local/lib/red-amber-graal/red-amber-graal-pi4j.jar"
REMOTE_CONFIG_DIR="/tmp/native-agent-config"
LOCAL_CONFIG_DIR="$PROJECT_ROOT/target/agent-config"

for arg in "$@"; do
    case "$arg" in
        --skip-jar-build)
            SKIP_JAR_BUILD=true
            ;;
        *)
            echo "ERROR: Unknown argument: $arg"
            exit 1
            ;;
    esac
done

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
JAVA_PI="${JAVA_HOME}/bin/java"

# Check java exists on the Pi at the mirrored path
if ! ssh blackraspberry "test -x ${JAVA_PI}"; then
    echo "ERROR: java not found on BlackRaspberry at ${JAVA_PI}"
    echo "  Ensure the same GraalVM CE is installed on BlackRaspberry at the same path"
    exit 1
fi

if [ "$SKIP_JAR_BUILD" = false ]; then
    echo "==> Building shaded JAR..."
    mvn -f "$PROJECT_ROOT/pom.xml" package -DskipTests
fi

JAR=$(ls "$PROJECT_ROOT"/target/red-amber-graal-pi4j-*.jar | head -1)
if [ ! -f "$JAR" ]; then
    echo "ERROR: JAR not found under $PROJECT_ROOT/target/"
    echo "  Run without --skip-jar-build or run: mvn package -DskipTests"
    exit 1
fi

echo "==> Deploying JAR to BlackRaspberry..."
ssh blackraspberry "mkdir -p ~/.local/lib/red-amber-graal"
scp "$JAR" blackraspberry:~/.local/lib/red-amber-graal/red-amber-graal-pi4j.jar

echo "==> Running native-image-agent on BlackRaspberry..."
echo "    (App will fail on hardware — that is expected; static initialisers run first)"
ssh blackraspberry "
    rm -rf ${REMOTE_CONFIG_DIR} && mkdir -p ${REMOTE_CONFIG_DIR}
    ${JAVA_PI} \
        -agentlib:native-image-agent=config-output-dir=${REMOTE_CONFIG_DIR} \
        --enable-native-access=ALL-UNNAMED \
        -jar ${REMOTE_JAR} --cycles=1
"

echo "==> Retrieving agent-generated config..."
mkdir -p "$LOCAL_CONFIG_DIR"
scp "blackraspberry:${REMOTE_CONFIG_DIR}/reachability-metadata.json" \
    "$LOCAL_CONFIG_DIR/reachability-metadata.json"

echo ""
echo "==> Done. Generated config written to:"
echo "    $LOCAL_CONFIG_DIR/reachability-metadata.json"
echo ""
echo "    Review the 'foreign.downcalls' section, then copy into:"
echo "    src/main/resources/META-INF/native-image/dev.lofthouse/red-amber-graal-pi4j/reachability-metadata.json"
echo ""
echo "    Other files (reflect-config.json, resource-config.json, etc.) are"
echo "    provided by Pi4J's own JARs — only reachability-metadata.json is needed."
