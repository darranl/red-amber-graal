#!/usr/bin/env bash
#
# generate-ffm-bindings.sh
#
# Generates FFM (Foreign Function & Memory) Java bindings for libgpiod v1
# using jextract. The generated sources are placed in src/main/java/ under
# the package dev.lofthouse.redambergraal.ffm and should be committed to
# version control.
#
# Re-run this script when:
#   - libgpiod version changes on the Pi (ABI version in /usr/lib/.../libgpiod.so.*)
#   - Additional gpiod symbols are needed
#
# Prerequisites:
#   - jextract available in PATH (SDKMAN: sdk install jextract)
#   - Sysroot mounted at ~/mnt/pios12_root
#     (systemctl --user start home-darranl-mnt-pios12_root.mount)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SYSROOT="$HOME/mnt/pios12_root"
GPIOD_HEADER="$SYSROOT/usr/include/gpiod.h"
OUTPUT_DIR="$PROJECT_ROOT/src/main/java"
PACKAGE="dev.lofthouse.redambergraal.ffm"
PACKAGE_PATH="dev/lofthouse/redambergraal/ffm"

# ── Prerequisites ──────────────────────────────────────────────────────────

if ! command -v jextract &>/dev/null; then
    echo "ERROR: jextract not found. Install via sdkman:"
    echo "  sdk install jextract"
    exit 1
fi

if [ ! -d "$SYSROOT/usr/include" ]; then
    echo "ERROR: Sysroot not mounted at $SYSROOT"
    echo "  systemctl --user start home-darranl-mnt-pios12_root.mount"
    exit 1
fi

if [ ! -f "$GPIOD_HEADER" ]; then
    echo "ERROR: gpiod.h not found at $GPIOD_HEADER"
    exit 1
fi

# ── Generate ───────────────────────────────────────────────────────────────

echo "==> Removing old generated bindings..."
rm -rf "$OUTPUT_DIR/$PACKAGE_PATH"

echo "==> Generating FFM bindings for libgpiod..."
echo "    Header:   $GPIOD_HEADER"
echo "    Package:  $PACKAGE"
echo "    Output:   $OUTPUT_DIR"
echo "    jextract: $(jextract --version 2>&1 | head -1)"

jextract \
    --output "$OUTPUT_DIR" \
    --target-package "$PACKAGE" \
    --library gpiod \
    -I "$SYSROOT/usr/include" \
    "$GPIOD_HEADER"

echo "==> Done. Generated sources in $OUTPUT_DIR/$PACKAGE_PATH"
echo "    Commit the generated sources to version control."
echo "    Regenerate if libgpiod or GraalVM version changes."
