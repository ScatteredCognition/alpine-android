#!/system/bin/sh
# ==============================================================================
# enter-alpine.sh - Mount plumbing and entry launcher for Alpine Linux Chroot
# ==============================================================================

CHROOT_DIR="${1:-/data/chroot/alpine}"

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

# Keep DNS updated
echo "nameserver 1.1.1.1" > "$CHROOT_DIR/etc/resolv.conf"
echo "nameserver 8.8.8.8" >> "$CHROOT_DIR/etc/resolv.conf"

# Shell resolution hierarchy: Fish -> Bash -> Ash
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
