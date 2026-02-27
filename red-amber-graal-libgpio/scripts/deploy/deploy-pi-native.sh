#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Check that native-image is available (requires GraalVM selected in sdkman)
if ! command -v native-image &>/dev/null; then
    echo "ERROR: native-image not found. Select GraalVM in sdkman:"
    echo "  sdk use java 25.0.2-graalce"
    exit 1
fi

# Check sysroot is mounted (required for aarch64 cross-compilation)
SYSROOT="$HOME/mnt/pios12_root"
if [ ! -d "$SYSROOT/usr/include" ]; then
    echo "ERROR: sysroot not mounted at $SYSROOT"
    echo "  systemctl --user start home-darranl-mnt-pios12_root.mount"
    exit 1
fi

echo "==> Building native aarch64 binary..."
mvn -f "$PROJECT_ROOT/pom.xml" package -DskipTests -Dnative

BINARY="$PROJECT_ROOT/target/red-amber-graal-libgpio-native"

echo "==> Creating ~/.local/bin on BlackRaspberry..."
ssh blackraspberry "mkdir -p ~/.local/bin"

echo "==> Deploying native binary..."
scp "$BINARY" blackraspberry:~/.local/bin/red-amber-graal-libgpio-native

echo "==> Done."
