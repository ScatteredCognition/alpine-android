#!/system/bin/sh
# ==============================================================================
# stop-alpine.sh - Clean reverse unmount script for Alpine Linux Chroot
# ==============================================================================

CHROOT_DIR="${CHROOT_DIR:-/data/chroot/alpine}"
INSTALL_BASE="$(dirname "$CHROOT_DIR")"
[ -d "$INSTALL_BASE/utils" ] && PATH="$INSTALL_BASE/utils:$PATH"

if [ "$(id -u)" -ne 0 ]; then
    if ! command -v su >/dev/null 2>&1; then
        echo "[!] Error: Root privileges required. No 'su' binary found." >&2
        echo "    Please ensure your device has a working root provider (KernelSU, APatch, Magisk, or ROM su)." >&2
        exit 1
    fi
    exec su -mm -c "$0" "$@" 2>/dev/null || exec su -c "$0" "$@"
fi

# Allow overriding chroot directory with -d/--dir or positional argument
if [ "$1" = "-d" ] || [ "$1" = "--dir" ]; then
    CHROOT_DIR="$2"
    shift 2
elif [ -n "$1" ]; then
    CHROOT_DIR="$1"
    shift
fi

echo "[*] Unmounting Alpine chroot at $CHROOT_DIR..."

umount -f "$CHROOT_DIR/sdcard" 2>/dev/null || true
umount -f "$CHROOT_DIR/dev/shm" 2>/dev/null || true
umount -f "$CHROOT_DIR/dev/pts" 2>/dev/null || true
umount -f "$CHROOT_DIR/dev" 2>/dev/null || true
umount -f "$CHROOT_DIR/proc" 2>/dev/null || true
umount -f "$CHROOT_DIR/sys" 2>/dev/null || true

echo "[+] Alpine filesystems unmounted cleanly."
