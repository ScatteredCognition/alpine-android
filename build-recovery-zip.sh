#!/usr/bin/env bash
# ==============================================================================
# build-recovery-zip.sh - Builds a TWRP/OrangeFox flashable ZIP for Alpine Chroot
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/installer"
OUT_DIR="$SCRIPT_DIR/out"
ARCH="aarch64"
ALPINE_VER="v3.20"
ALPINE_RELEASE="3.20.3"
TARBALL="alpine-minirootfs-${ALPINE_RELEASE}-${ARCH}.tar.gz"
URL="https://dl-cdn.alpinelinux.org/alpine/${ALPINE_VER}/releases/${ARCH}/${TARBALL}"
OUTPUT_ZIP="$OUT_DIR/alpine-chroot-${ALPINE_RELEASE}-${ARCH}-recovery.zip"

echo "============================================="
echo "   Building Recovery Flashable ZIP          "
echo "============================================="

mkdir -p "$OUT_DIR"

# Download minirootfs if missing
if [ ! -f "$WORK_DIR/rootfs.tar.gz" ]; then
    echo "[*] Downloading Alpine minirootfs (${ALPINE_RELEASE}-${ARCH})..."
    curl -sL -o "$WORK_DIR/rootfs.tar.gz" "$URL"
fi

# Ensure permissions
chmod 755 "$WORK_DIR/META-INF/com/google/android/update-binary"

# Create ZIP
echo "[*] Packaging flashable recovery ZIP..."
rm -f "$OUTPUT_ZIP"
cd "$WORK_DIR"
zip -r9 "$OUTPUT_ZIP" META-INF rootfs.tar.gz

echo "---------------------------------------------"
echo "[✓] Flashable ZIP created successfully!"
echo "[*] Output: $OUTPUT_ZIP"
echo "============================================="
