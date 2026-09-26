#!/system/bin/sh
# ==============================================================================
# stop-alpine.sh - Clean reverse unmount script for Alpine Linux Chroot
# ==============================================================================

CHROOT_DIR="${1:-/data/chroot/alpine}"

if [ "$(id -u)" -ne 0 ]; then
    exec su -mm -c "$0" "$@"
fi

echo "[*] Unmounting Alpine chroot at $CHROOT_DIR..."

umount -f "$CHROOT_DIR/sdcard" 2>/dev/null || true
umount -f "$CHROOT_DIR/dev/shm" 2>/dev/null || true
umount -f "$CHROOT_DIR/dev/pts" 2>/dev/null || true
umount -f "$CHROOT_DIR/dev" 2>/dev/null || true
umount -f "$CHROOT_DIR/proc" 2>/dev/null || true
umount -f "$CHROOT_DIR/sys" 2>/dev/null || true

echo "[+] Alpine filesystems unmounted cleanly."
