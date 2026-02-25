#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Building JAR..."
mvn -f "$SCRIPT_DIR/pom.xml" package -DskipTests

JAR=$(ls "$SCRIPT_DIR"/target/red-amber-graal-libgpio-*.jar | head -1)

echo "==> Creating directories on BlackRaspberry..."
ssh blackraspberry "mkdir -p ~/.local/lib/red-amber-graal ~/.local/bin"

echo "==> Deploying JAR..."
scp "$JAR" blackraspberry:~/.local/lib/red-amber-graal/red-amber-graal-libgpio.jar

echo "==> Deploying run wrapper..."
scp -p "$SCRIPT_DIR/pi-scripts/red-amber-graal-libgpio" blackraspberry:~/.local/bin/red-amber-graal-libgpio

echo "==> Done."
