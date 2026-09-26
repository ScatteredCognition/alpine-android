#!/usr/bin/env bash
# ==============================================================================
# build-recovery-zip.sh - Builds a TWRP/OrangeFox flashable ZIP for Alpine Chroot
# Branch: edge (Rolling / Unstable)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/installer"
OUT_DIR="$SCRIPT_DIR/out"
ARCH="aarch64"
ALPINE_BRANCH="edge"
EDGE_YAML_URL="https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/releases/${ARCH}/latest-releases.yaml"
OUTPUT_ZIP="$OUT_DIR/alpine-chroot-edge-${ARCH}-recovery.zip"

echo "============================================="
echo "   Building Alpine edge Recovery ZIP        "
echo "============================================="

mkdir -p "$OUT_DIR"

# Resolve latest edge filename dynamically
echo "[*] Resolving latest Alpine edge tarball..."
TARBALL=$(curl -sL "$EDGE_YAML_URL" | grep -m1 "file: alpine-minirootfs-" | awk '{print $2}')
[ -z "$TARBALL" ] && TARBALL="alpine-minirootfs-edge-${ARCH}.tar.gz"

URL="https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/releases/${ARCH}/${TARBALL}"

echo "[*] Downloading Alpine edge minirootfs ($TARBALL)..."
curl -sL -o "$WORK_DIR/rootfs.tar.gz" "$URL"

# Ensure permissions
chmod 755 "$WORK_DIR/META-INF/com/google/android/update-binary"

# Copy bin, distros, and utils into installer package
mkdir -p "$WORK_DIR/bin" "$WORK_DIR/distros" "$WORK_DIR/utils"
[ -d "$SCRIPT_DIR/bin" ] && cp -rf "$SCRIPT_DIR/bin/"* "$WORK_DIR/bin/"
[ -d "$SCRIPT_DIR/distros" ] && cp -rf "$SCRIPT_DIR/distros/"* "$WORK_DIR/distros/"
[ -d "$SCRIPT_DIR/utils" ] && cp -rf "$SCRIPT_DIR/utils/"* "$WORK_DIR/utils/"
chmod 755 "$WORK_DIR/bin/"* "$WORK_DIR/distros/"*.install.sh "$WORK_DIR/utils/"* 2>/dev/null || true

# Create ZIP
echo "[*] Packaging flashable recovery ZIP..."
rm -f "$OUTPUT_ZIP"
cd "$WORK_DIR"
zip -r9 "$OUTPUT_ZIP" META-INF rootfs.tar.gz bin distros utils
rm -f "$WORK_DIR/rootfs.tar.gz"
rm -rf "$WORK_DIR/bin" "$WORK_DIR/distros" "$WORK_DIR/utils"

echo "---------------------------------------------"
echo "[✓] Flashable ZIP created successfully!"
echo "[*] Output: $OUTPUT_ZIP"
echo "============================================="
