#!/system/bin/sh
# ==============================================================================
# alpine.install.sh - Installer plugin for Alpine Linux
#
# PLUGIN SPECIFICATION COMPLIANCE:
# - Scope: ONLY responsible for fetching the Alpine minirootfs and configuring
#          internal guest repositories (/etc/apk/repositories).
# - Execution: Sourced strictly by chroot-install (NOT executable standalone).
# - Host-level mount management, directory purge, unmounting, DNS injection,
#   and Android AID groups are automatically handled by chroot-install.
# - Environment: Receives TMP_DIR, target path ($1), augmented PATH with curl
#                and busybox, and library helpers (safe_download, safe_extract).
# ==============================================================================

ARCH="aarch64"
ALPINE_BRANCH="edge"
EDGE_YAML_URL="https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/releases/${ARCH}/latest-releases.yaml"

install_distro() {
    local target="$1"
    local tmp_dir="${TMP_DIR:-/data/local/tmp}"
    local yaml_file="$tmp_dir/alpine-latest.yaml"

    echo "[*] Fetching Alpine edge release metadata..."
    safe_download "$EDGE_YAML_URL" "$yaml_file"

    local tarball
    tarball=$(grep -m1 "file: alpine-minirootfs-" "$yaml_file" 2>/dev/null | awk '{print $2}')
    rm -f "$yaml_file"

    [ -z "$tarball" ] && tarball="alpine-minirootfs-edge-${ARCH}.tar.gz"

    local download_url="https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/releases/${ARCH}/${tarball}"
    local local_tarball="$tmp_dir/$tarball"

    echo "[*] Downloading Alpine edge minirootfs ($tarball)..."
    safe_download "$download_url" "$local_tarball"

    echo "[*] Extracting minirootfs into $target..."
    safe_extract "$local_tarball" "$target"
    rm -f "$local_tarball"

    # Configure Alpine package repositories inside the rootfs
    echo "[*] Configuring edge package repositories..."
    mkdir -p "$target/etc/apk"
    cat << 'EOF' > "$target/etc/apk/repositories"
https://dl-cdn.alpinelinux.org/alpine/edge/main
https://dl-cdn.alpinelinux.org/alpine/edge/community
https://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF

    echo "[✓] Alpine rootfs and repositories configured successfully."
}
