#!/system/bin/sh
# ==============================================================================
# Alpine Linux Chroot Installer for Android
# Branch: edge (Rolling / Unstable)
# Repository: https://github.com/faeizmahrus/alpine-android
# ==============================================================================

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Error: This installer must be executed as root (e.g. su -mm)!" >&2
    exit 1
fi

CLEAN_INSTALL=0
TARGET_PATH=""

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -c|--clean)
            CLEAN_INSTALL=1
            shift
            ;;
        *)
            if [ -z "$TARGET_PATH" ]; then
                TARGET_PATH="$1"
            fi
            shift
            ;;
    esac
done

CHROOT_DIR="${TARGET_PATH:-/data/chroot/alpine}"
INSTALL_BASE="$(dirname "$CHROOT_DIR")"
TMP_DIR="/data/local/tmp"
ARCH="aarch64"
ALPINE_BRANCH="edge"
EDGE_YAML_URL="https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/releases/${ARCH}/latest-releases.yaml"

echo "============================================="
echo "   Alpine Linux (edge) Installer for Android "
echo "============================================="
echo "[*] Installation path : $CHROOT_DIR"
echo "[*] Architecture      : $ARCH"
echo "[*] Alpine Branch     : $ALPINE_BRANCH (Rolling)"
[ "$CLEAN_INSTALL" = "1" ] && echo "[*] Clean install     : YES (wiping older chroot)"
echo "---------------------------------------------"

# 1. Handle --clean flag (safely unmount and wipe existing chroot)
if [ "$CLEAN_INSTALL" = "1" ] && [ -d "$CHROOT_DIR" ]; then
    echo "[*] Cleaning up existing chroot directory..."
    umount -f "$CHROOT_DIR/sdcard" 2>/dev/null || true
    umount -f "$CHROOT_DIR/dev/shm" 2>/dev/null || true
    umount -f "$CHROOT_DIR/dev/pts" 2>/dev/null || true
    umount -f "$CHROOT_DIR/dev" 2>/dev/null || true
    umount -f "$CHROOT_DIR/proc" 2>/dev/null || true
    umount -f "$CHROOT_DIR/sys" 2>/dev/null || true
    rm -rf "$CHROOT_DIR"
    echo "[+] Previous chroot removed."
fi

# 2. Prepare directories
mkdir -p "$CHROOT_DIR" "$TMP_DIR"
cd "$TMP_DIR"

# 3. Resolve latest edge minirootfs filename
echo "[*] Fetching latest Alpine edge release metadata..."
TARBALL=""
if command -v curl >/dev/null 2>&1; then
    TARBALL=$(curl -sL "$EDGE_YAML_URL" | grep -m1 "file: alpine-minirootfs-" | awk '{print $2}')
elif command -v wget >/dev/null 2>&1; then
    TARBALL=$(wget -qO- "$EDGE_YAML_URL" | grep -m1 "file: alpine-minirootfs-" | awk '{print $2}')
fi

# Fallback filename if parsing metadata fails
if [ -z "$TARBALL" ]; then
    echo "[!] Warning: Could not parse latest-releases.yaml, using dynamic fallback..."
    TARBALL="alpine-minirootfs-edge-${ARCH}.tar.gz"
fi

URL="https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/releases/${ARCH}/${TARBALL}"

# 4. Download minirootfs
echo "[*] Downloading Alpine edge minirootfs ($TARBALL)..."
if command -v curl >/dev/null 2>&1; then
    curl -LO "$URL"
elif command -v wget >/dev/null 2>&1; then
    wget "$URL"
fi

# 5. Extract rootfs
echo "[*] Extracting rootfs into $CHROOT_DIR..."
tar -xzf "$TARBALL" -C "$CHROOT_DIR"
rm -f "$TARBALL"

# 6. Configure Public DNS
echo "[*] Setting up DNS resolvers..."
cat << 'EOF' > "$CHROOT_DIR/etc/resolv.conf"
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# 7. Configure edge apk repositories (main + community)
echo "[*] Configuring edge package repositories..."
cat << 'EOF' > "$CHROOT_DIR/etc/apk/repositories"
https://dl-cdn.alpinelinux.org/alpine/edge/main
https://dl-cdn.alpinelinux.org/alpine/edge/community
EOF

# 8. Inject Android AID network groups (fixes socket permissions)
echo "[*] Injecting Android network AID GIDs into /etc/group..."
grep -q "^aid_inet:" "$CHROOT_DIR/etc/group" 2>/dev/null || echo "aid_inet:x:3003:root" >> "$CHROOT_DIR/etc/group"
grep -q "^aid_net_raw:" "$CHROOT_DIR/etc/group" 2>/dev/null || echo "aid_net_raw:x:3004:root" >> "$CHROOT_DIR/etc/group"
grep -q "^aid_admin:" "$CHROOT_DIR/etc/group" 2>/dev/null || echo "aid_admin:x:3005:root" >> "$CHROOT_DIR/etc/group"

# 9. Create mount target folders
mkdir -p "$CHROOT_DIR/dev" "$CHROOT_DIR/dev/pts" "$CHROOT_DIR/dev/shm" "$CHROOT_DIR/proc" "$CHROOT_DIR/sys" "$CHROOT_DIR/sdcard"

# 10. Generate enter-alpine.sh launcher
LAUNCHER="$INSTALL_BASE/enter-alpine.sh"
echo "[*] Writing launcher script to $LAUNCHER..."
cat << 'EOF' > "$LAUNCHER"
#!/system/bin/sh
CHROOT_DIR="__CHROOT_DIR__"

# Ensure global mount namespace
if [ "$(id -u)" -ne 0 ]; then
    exec su -mm -c "$0" "$@"
fi

# Idempotent mounts
mountpoint -q "$CHROOT_DIR/dev" || mount --bind /dev "$CHROOT_DIR/dev"
mountpoint -q "$CHROOT_DIR/dev/pts" || mount --bind /dev/pts "$CHROOT_DIR/dev/pts"
mountpoint -q "$CHROOT_DIR/proc" || mount -t proc proc "$CHROOT_DIR/proc"
mountpoint -q "$CHROOT_DIR/sys" || mount -t sysfs sysfs "$CHROOT_DIR/sys"

# POSIX shared memory (tmpfs)
mkdir -p "$CHROOT_DIR/dev/shm" 2>/dev/null || true
mountpoint -q "$CHROOT_DIR/dev/shm" || mount -t tmpfs -o rw,nosuid,nodev tmpfs "$CHROOT_DIR/dev/shm" 2>/dev/null || true

# Internal storage bridge
mkdir -p "$CHROOT_DIR/sdcard" 2>/dev/null || true
mountpoint -q "$CHROOT_DIR/sdcard" || mount --bind /sdcard "$CHROOT_DIR/sdcard" 2>/dev/null || true

# Sync DNS
echo "nameserver 1.1.1.1" > "$CHROOT_DIR/etc/resolv.conf"
echo "nameserver 8.8.8.8" >> "$CHROOT_DIR/etc/resolv.conf"

# Dynamic shell resolution: Fish -> Bash -> Ash
LOGIN_SHELL="/usr/bin/fish"
[ ! -x "$CHROOT_DIR$LOGIN_SHELL" ] && LOGIN_SHELL="/bin/bash"
[ ! -x "$CHROOT_DIR$LOGIN_SHELL" ] && LOGIN_SHELL="/bin/sh"

# Execution dispatch
if [ $# -gt 0 ]; then
    exec chroot "$CHROOT_DIR" /usr/bin/env -i \
        HOME=/root \
        TERM=xterm-256color \
        SHELL="$LOGIN_SHELL" \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        "$LOGIN_SHELL" "$@"
else
    exec chroot "$CHROOT_DIR" /usr/bin/env -i \
        HOME=/root \
        TERM=xterm-256color \
        SHELL="$LOGIN_SHELL" \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        "$LOGIN_SHELL" -l
fi
EOF

sed -i "s|__CHROOT_DIR__|$CHROOT_DIR|g" "$LAUNCHER"
chmod 755 "$LAUNCHER"

# 11. Generate stop-alpine.sh unmount script
STOP_SCRIPT="$INSTALL_BASE/stop-alpine.sh"
echo "[*] Writing unmount script to $STOP_SCRIPT..."
cat << 'EOF' > "$STOP_SCRIPT"
#!/system/bin/sh
CHROOT_DIR="__CHROOT_DIR__"

if [ "$(id -u)" -ne 0 ]; then
    exec su -mm -c "$0" "$@"
fi

umount -f "$CHROOT_DIR/sdcard" 2>/dev/null || true
umount -f "$CHROOT_DIR/dev/shm" 2>/dev/null || true
umount -f "$CHROOT_DIR/dev/pts" 2>/dev/null || true
umount -f "$CHROOT_DIR/dev" 2>/dev/null || true
umount -f "$CHROOT_DIR/proc" 2>/dev/null || true
umount -f "$CHROOT_DIR/sys" 2>/dev/null || true

echo "[+] Alpine filesystems unmounted cleanly."
EOF

sed -i "s|__CHROOT_DIR__|$CHROOT_DIR|g" "$STOP_SCRIPT"
chmod 755 "$STOP_SCRIPT"

# 12. Create global symlinks if module/system path exists
for p in /data/adb/modules/alpine/system/bin /data/adb/modules/ssh/usr/bin /data/adb/modules/ssh/system/bin; do
    if [ -d "$p" ]; then
        ln -sf "$LAUNCHER" "$p/alpine" 2>/dev/null || true
        ln -sf "$LAUNCHER" "$p/enter-alpine" 2>/dev/null || true
        ln -sf "$STOP_SCRIPT" "$p/stop-alpine" 2>/dev/null || true
    fi
done

echo "---------------------------------------------"
echo "[✓] Alpine Linux (edge) installed successfully!"
echo "[*] Enter Alpine: $LAUNCHER (or type 'alpine' if in PATH)"
echo "[*] Stop Alpine : $STOP_SCRIPT (or type 'stop-alpine')"
echo "============================================="
