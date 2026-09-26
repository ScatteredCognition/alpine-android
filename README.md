# Alpine Linux Chroot on Android (ARM64)

A lightweight, bare-metal, native chroot deployment of **Alpine Linux** for Android devices with an unlocked bootloader and a root provider (**KernelSU**, **APatch**, **Magisk**, or ROM `su`).

Runs directly on your device's native high-performance **F2FS/ext4** storage with zero emulation overhead, proper POSIX permissions, full Android network hardware access, and seamless bidirectional `/sdcard` sharing.

---

## Why Native Chroot?

| Feature | PRoot / Termux-PRoot | Linux Deploy (Legacy) | This Chroot Setup |
| :--- | :--- | :--- | :--- |
| **Performance** | Emulated (`ptrace`), 3x–10x slowdown | Native, but slow loop disk (`.img`) | **Bare-metal speed** on native F2FS |
| **Android 12–15+ Support** | Yes | No (Broken by debootstrap / loop errors) | **Full support** (Any working `su`) |
| **Storage Overhead** | Duplicated inside app sandbox | Fixed virtual disk image size | **Dynamic** (shares phone's 100+ GB) |
| **Root Privileges** | Faked root | Real root | **True Linux root (`UID 0`)** |
| **POSIX Permissions** | Emulated | Native inside loop | **Full native POSIX + symlinks** |
| **Shared Memory (`/dev/shm`)**| Emulated / Limited | Often missing | **Full tmpfs POSIX shared memory** |

---

## Prerequisites

1. **Android Device (ARM64 / `aarch64`)**:
   - Unlocked bootloader with a custom recovery (**OrangeFox** or **TWRP**) OR terminal root access.
2. **Root (`su`) on Booted Android**:
   - Working `su` binary. Supported root solutions:
     - [KernelSU](https://kernelsu.org/) / [KernelSU-Next](https://github.com/rifsxd/KernelSU-Next) (Kernel-level root)
     - [APatch](https://apatch.dev/) (Kernel-patch root)
     - [Magisk](https://github.com/topjohnwu/Magisk) (Systemless root)
     - Built-in ROM `su` (e.g. LineageOS `su` addon or userdebug builds).
3. **Terminal Access**:
   - [Termux](https://github.com/termux/termux-app/releases), an **ADB root** shell, or a persistent SSH server (such as [MagiskSSH](https://github.com/Magisk-Modules-Alt-Repo/MagiskSSH)).

---

## Installation Methods

### Method 1: Recovery Flashable ZIP (OrangeFox / TWRP)

Flash directly from custom recovery — completely standalone and lives "off the land" without external dependencies:

1. Download the pre-built flashable ZIP from [GitHub Releases](https://github.com/ScatteredCognition/alpine-android/releases), or build it locally:
   ```bash
   ./build-recovery-zip.sh
   # Produces: out/alpine-chroot-edge-aarch64-recovery.zip
   ```
2. Reboot into **OrangeFox** or **TWRP Recovery**.
3. Flash `alpine-chroot-edge-aarch64-recovery.zip` (via recovery GUI, terminal `twrp install`, or `adb sideload`).
4. **What the recovery installer does**:
   - Extracts Alpine `edge` (rolling) rootfs into `/data/chroot/alpine`.
   - Deploys the modular command suite into `/data/chroot/bin/` (`su-helper`, `chroot-helper`, `chroot-run`, `chroot-stop`, `chroot-status`, `chroot-install`, and `alpine`).
   - Installs distro definitions into `/data/chroot/distros/` (`alpine.conf`, `alpine.install.sh`).
   - Installs static standalone networking utilities into `/data/chroot/utils/` (`curl`, `busybox`).
   - Sets up `/etc/resolv.conf`, `edge` apk repositories, and Android AID network groups.
5. Reboot to Android!

---

### Method 2: Manual Terminal Deployment (Root Shell / ADB)

If deploying manually without flashing the recovery ZIP:

1. Copy or extract the repository's `bin/`, `distros/`, and `utils/` directories directly into `/data/chroot/`:
   ```bash
   su
   mkdir -p /data/chroot
   cp -r bin distros utils /data/chroot/
   chmod 755 /data/chroot/bin/*
   chmod 644 /data/chroot/distros/*
   [ -d /data/chroot/utils ] && chmod 755 /data/chroot/utils/*
   ```

2. Run the installer:
   ```bash
   # Standard installation using chroot-install
   /data/chroot/bin/chroot-install alpine

   # Or force a clean reinstall
   /data/chroot/bin/chroot-install --force alpine
   ```

---

## Usage & Command Suite

All commands reside in `/data/chroot/bin/`:

```bash
# Direct execution:
/data/chroot/bin/alpine
/data/chroot/bin/chroot-run alpine
/data/chroot/bin/chroot-stop alpine
/data/chroot/bin/chroot-status
/data/chroot/bin/chroot-install alpine
```

> [!TIP]
> Add `/data/chroot/bin` to your `$PATH` in `~/.bashrc`, `~/.zshrc`, or Termux `~/.bash_profile` to run commands from anywhere without specifying the full path:
> ```bash
> export PATH="/data/chroot/bin:$PATH"
> ```

### 1. Dedicated Shortcut: `alpine`
Launch directly into Alpine Linux:
```bash
# Interactive login shell:
/data/chroot/bin/alpine
# Or direct command execution:
/data/chroot/bin/alpine -c "apk update && apk upgrade"
/data/chroot/bin/alpine -c "htop"
```

### 2. Universal Runner: `chroot-run <distro> [command...]`
Run any configured distribution:
```bash
/data/chroot/bin/chroot-run alpine
/data/chroot/bin/chroot-run alpine -c "uname -a"
```

### 3. Stop / Unmount: `chroot-stop <distro>`
Cleanly unmount all active filesystems for a distribution:
```bash
/data/chroot/bin/chroot-stop alpine
```

### 4. Status Inspection: `chroot-status [distro]`
View active mounts, installation states, and running status:
```bash
/data/chroot/bin/chroot-status
/data/chroot/bin/chroot-status alpine
```

### 5. Install Distros: `chroot-install [-f|--force] <distro>`
Install or reinstall distributions via their installer plugin:
```bash
/data/chroot/bin/chroot-install alpine
/data/chroot/bin/chroot-install --force alpine
```

---

## Post-Installation & Customization

### Shell Selection & Customization

The active shell is resolved automatically based on the `DEFAULT_SHELLS` hierarchy declared in `/data/chroot/distros/<distro>.conf` (for Alpine, `/data/chroot/distros/alpine.conf` checks `/usr/bin/fish /bin/bash /bin/sh` in order).

To use Fish as your default shell, simply install it inside Alpine:
```bash
apk update
apk add fish
```
Once installed, `alpine` (and `chroot-run`) immediately detects `/usr/bin/fish` and launches it automatically without requiring `chsh` or the `shadow` package.

To customize the search hierarchy or add another shell (e.g. `zsh`), edit `DEFAULT_SHELLS` in `/data/chroot/distros/alpine.conf`:
```bash
DEFAULT_SHELLS="/bin/zsh /usr/bin/fish /bin/bash /bin/sh"
```

### Recommended Baseline Tools

```bash
apk add bash curl nano htop git ca-certificates openssh tmux build-base
```

### Running a Persistent SSH Server

You can run an SSH server either natively on the Android host (recommended for whole-device administration) or inside the Alpine chroot:

#### Option A: Host-Level Persistent SSH via MagiskSSH (Recommended)
[MagiskSSH](https://github.com/Magisk-Modules-Alt-Repo/MagiskSSH) runs an OpenSSH server natively on the Android host across reboots via Magisk, KernelSU, or APatch.
1. Flash the **MagiskSSH** module via KernelSU / APatch / Magisk app.
2. Place your PC's public key in `/data/adb/ssh/root/.ssh/authorized_keys` (or set a password).
3. Connect via port `22`:
   ```bash
   ssh root@<PHONE_IP>
   ```
4. Once connected to the host shell, launch into the chroot:
   ```bash
   /data/chroot/bin/alpine
   ```

#### Option B: Standalone In-Chroot OpenSSH (Zero Host Dependencies)
If you prefer running an SSH server directly inside Alpine without host modules:
```bash
# 1. Inside Alpine: install and generate host keys
apk add openssh
ssh-keygen -A

# 2. Add your authorized public key
mkdir -p /root/.ssh
echo "<your_ssh_public_key>" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# 3. Start SSH daemon (on a non-standard port like 2222)
/usr/sbin/sshd -p 2222
```
Connect from your PC anytime:
```bash
ssh -p 2222 root@<PHONE_IP>
```
To keep in-chroot SSH persistent across reboots, call `/data/chroot/bin/alpine -c "/usr/sbin/sshd -p 2222"` from an init script or Termux:Boot / KernelSU `service.sh`.

### Creating Non-Root Users Inside Chroot (with Internet Access)

Android restricts raw network sockets to specific Android Group IDs (GIDs). When creating non-root accounts inside the chroot, assign them to the Android AID networking groups so they can access the network:

```bash
# 1. Inside Alpine: create the user
adduser user

# 2. Add the user to the Android AID networking groups
addgroup user aid_inet
addgroup user aid_net_raw
```

---

## Technical Deep Dive & Architecture

### 1. Android AID Network Group Hook
Android kernels use `CONFIG_ANDROID_PARANOID_NETWORK`, which blocks standard `socket(AF_INET, ...)` syscalls from non-Android processes. This project resolves this by declaring Android's private GIDs in Alpine's `/etc/group`:
- `aid_inet` (GID `3003`): Required for standard internet connections (HTTP/HTTPS, SSH, package downloads).
- `aid_net_raw` (GID `3004`): Required for raw ICMP sockets (e.g. `ping`).
- `aid_admin` (GID `3005`): Administrative network management.

### 2. POSIX Shared Memory (`/dev/shm`) Workaround
Android does not provide standard POSIX `/dev/shm` (it uses `ashmem` / `dmabuf`), causing modern Linux software (compilers, Python multiprocessing, PostgreSQL) to fail. `chroot-helper` automatically mounts a lightweight `tmpfs` directly to `/dev/shm`:
```bash
mount -t tmpfs -o rw,nosuid,nodev tmpfs "$ROOTFS_PATH/dev/shm"
```

### 3. Dynamic DNS Synchronization
Android routes DNS through its internal `netd` daemon and system properties (`net.dns1`) rather than `/etc/resolv.conf`. Each time `alpine` or `chroot-run` runs, `chroot-helper` refreshes `/etc/resolv.conf` with `1.1.1.1` and `8.8.8.8` to guarantee working network lookups across Wi-Fi and mobile data switches.

### 4. Clean Environment Isolation
Android exports numerous non-POSIX environment variables (`ANDROID_DATA`, `BOOTCLASSPATH`, `LD_PRELOAD`) that can crash Linux binaries. `chroot-helper` uses:
```bash
exec chroot "$ROOTFS_PATH" /usr/bin/env -i HOME="$ENV_HOME" TERM="$ENV_TERM" SHELL="$SHELL_BIN" PATH="$ENV_PATH" "$SHELL_BIN" -l
```
This strips the Android environment completely and supplies only pure, clean POSIX variables.

### 5. Idempotent Mount Plumbing
The engine uses `mountpoint -q` checks before every bind-mount. Multiple terminal tabs or SSH sessions can safely invoke `alpine` simultaneously without triggering duplicate or recursive mount errors.

### 6. Bundled Static Utilities (`/data/chroot/utils`)
Stock Android ROMs lack standard networking and archive tools (`curl`, `wget`, `tar` options). To ensure 100% self-reliance regardless of host toolchains:
- Statically linked `curl` and multi-call `busybox` (with `wget`, `tar`, `gzip`, etc.) are bundled and installed to `/data/chroot/utils`.
- The command suite automatically adds `/data/chroot/utils` to `$PATH`, ensuring reliable tooling on any bare-metal Android installation.

---

## Adding New Distributions

This chroot engine is modular and designed to support any Linux distribution (e.g. Debian, Arch, Ubuntu, Fedora). To add a new distribution named `<name>`:

### 1. Create `/data/chroot/distros/<name>.conf`

Define the distribution's configuration variables:

```bash
DISTRO_NAME="debian"
DISTRO_DESCRIPTION="Debian GNU/Linux (trixie/sid)"

# Target rootfs directory
ROOTFS_PATH="/data/chroot/debian"

# Shell resolution hierarchy (checked in order, must fall back to /bin/sh)
DEFAULT_SHELLS="/bin/bash /bin/sh"

# DNS servers to write into /etc/resolv.conf
DNS_SERVERS="1.1.1.1 8.8.8.8"

# Mount flags (1 to enable, 0 to disable)
ENABLE_CORE_MOUNTS=1
ENABLE_SHM=1
ENABLE_DEVPTS=1
ENABLE_SDCARD=1

# Optional extra custom bind mounts: format "HOST_PATH:CHROOT_TARGET" separated by spaces
EXTRA_MOUNTS=""

# Environment variables supplied to chroot session
ENV_HOME="/root"
ENV_TERM="xterm-256color"
ENV_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
```

### 2. Create `/data/chroot/distros/<name>.install.sh`

Create the installer plugin adhering to the plugin contract:
- **Contract**: Implement `install_distro <target_directory>`.
- **Scope**: ONLY fetch/download the rootfs tarball and configure in-chroot files (e.g. package mirrors, initial config).
- **Environment**: Automatically inherits `$TMP_DIR`, augmented `$PATH` (with `curl` and `busybox`), and helper functions (`safe_download`, `safe_extract`).
- **Do NOT**: Manage mounts, unmount, purge, or configure DNS/groups — `chroot-install` automatically runs all pre-hooks (safe unmount, zero-mount verification, purge, directory creation) and post-hooks (DNS injection, Android AID network group injection).

Example:
```bash
#!/system/bin/sh
install_distro() {
    local target="$1"
    local tarball="$TMP_DIR/debian-rootfs.tar.gz"

    echo "[*] Downloading rootfs..."
    safe_download "https://example.com/debian-rootfs.tar.gz" "$tarball"

    echo "[*] Extracting..."
    safe_extract "$tarball" "$target"
    rm -f "$tarball"

    echo "[✓] Configured debian rootfs."
}
```

### 3. Install & Run

Once the `.conf` and `.install.sh` files exist in `distros/`, the new distro is instantly recognized by the command suite:
```bash
/data/chroot/bin/chroot-install <name>
/data/chroot/bin/chroot-run <name>
/data/chroot/bin/chroot-status <name>
/data/chroot/bin/chroot-stop <name>
```

---

## Authors & Attributions

- **Author**: Faeiz Mahrus
- **AI Pair Programmer**: Developed and architected with **Google Antigravity**

---

## License

MIT License. See [LICENSE](LICENSE) for details.
