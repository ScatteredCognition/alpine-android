#!/system/bin/sh
# ==============================================================================
# alpine.install.sh - Installer plugin for Alpine Linux
# Called by chroot-install
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
UTILS_DIR="$BASE_DIR/utils"
[ -d "$UTILS_DIR" ] && PATH="$UTILS_DIR:$PATH"

ARCH="aarch64"
ALPINE_BRANCH="edge"
EDGE_YAML_URL="https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/releases/${ARCH}/latest-releases.yaml"

install_distro() {
    local target="$1"
    local clean_flag="$2"
    local tmp_dir="/data/local/tmp"

    echo "[*] Preparing installation target: $target"
    if [ "$clean_flag" = "1" ] && [ -d "$target" ]; then
        echo "[*] Purging existing installation at $target..."
        umount -f "$target/sdcard" 2>/dev/null || true
        umount -f "$target/dev/shm" 2>/dev/null || true
        umount -f "$target/dev/pts" 2>/dev/null || true
        umount -f "$target/dev" 2>/dev/null || true
        umount -f "$target/proc" 2>/dev/null || true
        umount -f "$target/sys" 2>/dev/null || true
        rm -rf "$target"
    fi

    mkdir -p "$target" "$tmp_dir"

    # Select downloader
    DOWNLOADER=""
    if command -v curl >/dev/null 2>&1; then
        DOWNLOADER="curl"
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOADER="wget"
    else
        echo "[!] Error: Neither curl nor wget is available." >&2
        exit 1
    fi

    echo "[*] Fetching Alpine edge release metadata ($DOWNLOADER)..."
    TARBALL=""
    if [ "$DOWNLOADER" = "curl" ]; then
        TARBALL=$(curl -sL "$EDGE_YAML_URL" | grep -m1 "file: alpine-minirootfs-" | awk '{print $2}')
    else
        TARBALL=$(wget -qO- "$EDGE_YAML_URL" | grep -m1 "file: alpine-minirootfs-" | awk '{print $2}')
    fi

    [ -z "$TARBALL" ] && TARBALL="alpine-minirootfs-edge-${ARCH}.tar.gz"

    URL="https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/releases/${ARCH}/${TARBALL}"
    echo "[*] Downloading Alpine edge minirootfs ($TARBALL)..."
    if [ "$DOWNLOADER" = "curl" ]; then
        curl -sL -o "$tmp_dir/$TARBALL" "$URL"
    else
        wget -q -O "$tmp_dir/$TARBALL" "$URL"
    fi

    echo "[*] Extracting minirootfs into $target..."
    TAR_CMD="tar"
    if command -v busybox >/dev/null 2>&1 && busybox tar --help >/dev/null 2>&1; then
        TAR_CMD="busybox tar"
    fi

    (cd "$target" && $TAR_CMD -xzf "$tmp_dir/$TARBALL")
    rm -f "$tmp_dir/$TARBALL"

    # Configure APK repositories
    echo "[*] Configuring edge package repositories..."
    mkdir -p "$target/etc/apk"
    cat << 'EOF' > "$target/etc/apk/repositories"
https://dl-cdn.alpinelinux.org/alpine/edge/main
https://dl-cdn.alpinelinux.org/alpine/edge/community
EOF

    echo "[✓] Alpine Linux installed successfully at $target."
}

# Standalone execution
if [ "$1" = "install" ]; then
    shift
    install_distro "$@"
fi
