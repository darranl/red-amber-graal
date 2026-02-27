#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "==> Building JAR..."
mvn -f "$PROJECT_ROOT/pom.xml" package -DskipTests

JAR=$(ls "$PROJECT_ROOT"/target/red-amber-graal-libgpio-*.jar | head -1)

echo "==> Creating directories on BlackRaspberry..."
ssh blackraspberry "mkdir -p ~/.local/lib/red-amber-graal ~/.local/bin"

echo "==> Deploying JAR..."
scp "$JAR" blackraspberry:~/.local/lib/red-amber-graal/red-amber-graal-libgpio.jar

echo "==> Deploying run wrapper..."
scp -p "$PROJECT_ROOT/scripts/pi/red-amber-graal-libgpio" blackraspberry:~/.local/bin/red-amber-graal-libgpio

echo "==> Done."
