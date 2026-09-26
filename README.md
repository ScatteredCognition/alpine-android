# Alpine Linux Chroot on Android (ARM64)

A lightweight, bare-metal, native chroot deployment of **Alpine Linux** for Android devices with an unlocked bootloader and a root provider (**KernelSU**, **APatch**, **Magisk**, or ROM `su`).

Runs directly on your device's native high-performance **F2FS/ext4** storage with zero emulation overhead, proper POSIX permissions, full Android network hardware access, and seamless bidirectional `/sdcard` sharing.

---

## ⚡ Why Native Chroot?

| Feature | PRoot / Termux-PRoot | Linux Deploy (Legacy) | This Chroot Setup |
| :--- | :--- | :--- | :--- |
| **Performance** | Emulated (`ptrace`), 3x–10x slowdown | Native, but slow loop disk (`.img`) | **Bare-metal speed** on native F2FS |
| **Android 12–15+ Support** | Yes | ❌ Broken (debootstrap / loop errors) | **Full support** (Any working `su`) |
| **Storage Overhead** | Duplicated inside app sandbox | Fixed virtual disk image size | **Dynamic** (shares phone's 100+ GB) |
| **Root Privileges** | Faked root | Real root | **True Linux root (`UID 0`)** |
| **POSIX Permissions** | Emulated | Native inside loop | **Full native POSIX + symlinks** |
| **Shared Memory (`/dev/shm`)**| Emulated / Limited | Often missing | **Full tmpfs POSIX shared memory** |

---

## 📋 Prerequisites

1. **Android Device (ARM64 / `aarch64`)**:
   - Unlocked bootloader with a custom recovery (**OrangeFox** or **TWRP**) OR terminal root access.
2. **Root (`su`) on Booted Android**:
   - Working `su` binary (**KernelSU**, **APatch**, **Magisk**, or built-in ROM `su`).
3. **Terminal Access**:
   - [Termux](https://github.com/termux/termux-app/releases), an **ADB root** shell, or local terminal.

---

## 🚀 Installation Methods

### Method 1: Recovery Flashable ZIP (OrangeFox / TWRP)

Flash directly from custom recovery — completely standalone and lives "off the land" without external dependencies:

1. Download or build the recovery flashable zip:
   ```bash
   ./build-recovery-zip.sh
   # Produces: out/alpine-chroot-edge-aarch64-recovery.zip
   ```
2. Reboot into **OrangeFox** or **TWRP Recovery**.
3. Flash `alpine-chroot-edge-aarch64-recovery.zip` (via recovery GUI, terminal `twrp install`, or `adb sideload`).
4. **What the recovery installer does**:
   - Extracts Alpine `edge` (rolling) rootfs into `/data/chroot/alpine`.
   - Sets up `/etc/resolv.conf`, `edge` apk repositories, and Android AID network groups.
   - Installs standalone launchers directly at `/data/chroot/alpine`, `/data/chroot/enter-alpine.sh`, and `/data/chroot/stop-alpine.sh`.
   - Optionally registers a `/data/adb/modules/alpine` overlay only if KernelSU/Magisk modules directory exists.
5. Reboot to Android!

---

### Method 2: Direct One-Liner (via Root Shell / Termux / ADB)

From a root terminal on your device (`su` or `adb shell`):

```bash
su -c "curl -sL https://raw.githubusercontent.com/faeizmahrus/alpine-android/main/scripts/install-alpine.sh | sh"
```

To perform a clean installation (safely unmounting and purging any broken or existing chroot first):
```bash
su -mm -c "curl -sL https://raw.githubusercontent.com/faeizmahrus/alpine-android/main/scripts/install-alpine.sh | sh -s -- --clean"
```

---

### Method 3: Manual Clone & Install

```bash
# Push or clone repository onto the device
git clone https://github.com/faeizmahrus/alpine-android.git /data/local/tmp/alpine-android
cd /data/local/tmp/alpine-android

# Standard install (default: /data/chroot/alpine, rolling edge branch)
su -mm -c "sh scripts/install-alpine.sh"

# Or clean install from scratch (wipes any existing chroot cleanly)
su -mm -c "sh scripts/install-alpine.sh --clean"
```

The script will automatically:
1. Safely unmount active mountpoints (`/dev`, `/proc`, `/sys`, `/sdcard`) and purge previous files if `--clean` is passed.
2. Resolve and download the latest official Alpine Linux `edge` (rolling) `aarch64` minirootfs.
3. Extract it into `/data/chroot/alpine`.
4. Configure public DNS resolvers (`1.1.1.1` and `8.8.8.8`).
5. Configure `edge/main` and `edge/community` apk repositories.
6. Inject Android AID network groups into `/etc/group` so network sockets function properly.
7. Create `/data/chroot/enter-alpine.sh` and `/data/chroot/stop-alpine.sh`.
8. Symlink `alpine`, `enter-alpine`, and `stop-alpine` into `$PATH` (KernelSU/Magisk modules).

---

## 💻 Usage

### 1. Enter Alpine Linux

```bash
# Using the launcher directly:
/data/chroot/enter-alpine.sh

# Or (if using an alias or overlaid into PATH):
alpine
```

> [!TIP]
> To run `alpine` from any shell without modifying your system, add this alias to your `~/.bashrc`, `~/.zshrc`, or Termux `~/.bash_profile`:
> ```bash
> alias alpine="/data/chroot/enter-alpine.sh"
> alias stop-alpine="/data/chroot/stop-alpine.sh"
> ```

You will be dropped into your Alpine shell:
```text
root@localhost:~#
```

### 2. Execute Single Commands from Android
You can run any command inside Alpine without keeping an interactive session open:

```bash
/data/chroot/enter-alpine.sh -c "apk update && apk upgrade"
/data/chroot/enter-alpine.sh -c "python3 script.py"
/data/chroot/enter-alpine.sh -c "htop"
```

### 3. Access Android Storage Inside Alpine
Your phone's internal storage (`/sdcard`) is automatically bind-mounted inside Alpine:
```bash
ls /sdcard
ls /sdcard/Download
```

### 4. Exit & Cleanly Unmount
- To exit the Alpine shell back to Android: type `exit`.
- To cleanly unmount all Alpine filesystems (`/dev`, `/proc`, `/sys`, `/sdcard`):
  ```bash
  /data/chroot/stop-alpine.sh
  # Or: stop-alpine (if in PATH)
  ```

---

## 🛠️ Post-Installation & Customization

### Change Default Shell to Fish

Inside Alpine, install `fish` and the `shadow` suite (which provides `chsh`):

```bash
apk update
apk add fish shadow

# Set fish as default login shell for root
chsh -s /usr/bin/fish root
```

The `enter-alpine.sh` launcher will automatically detect Fish and launch `/usr/bin/fish -l` by default.

### Recommended Baseline Tools

```bash
apk add bash curl nano htop git ca-certificates openssh tmux build-base
```

### Running OpenSSH Inside Alpine (Zero Dependencies)

If you want SSH server access without any external Magisk modules or host daemons:

```bash
# 1. Inside Alpine: install and generate host keys
apk add openssh
ssh-keygen -A

# 2. Add your authorized public key
mkdir -p /root/.ssh
echo "<your_ssh_public_key>" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# 3. Start SSH server
/usr/sbin/sshd -p 2222
```

Connect from your PC anytime:
```bash
ssh -p 2222 root@<PHONE_IP>
```

### Creating Non-Root Users (with Internet Access)

Android restricts raw network sockets to specific Android Group IDs (GIDs). To ensure any non-root users you create can access the internet:

```bash
# 1. Create the user
adduser -s /usr/bin/fish user

# 2. Add the user to the Android AID networking groups
addgroup user aid_inet
addgroup user aid_net_raw
```

---

## 🔬 Technical Deep Dive & Architecture

### 1. Android AID Network Group Hook
Android kernels use `CONFIG_ANDROID_PARANOID_NETWORK`, which blocks standard `socket(AF_INET, ...)` syscalls from non-Android processes. This project resolves this by declaring Android's private GIDs in Alpine's `/etc/group`:
- `aid_inet` (GID `3003`): Required for standard internet connections (HTTP/HTTPS, SSH, package downloads).
- `aid_net_raw` (GID `3004`): Required for raw ICMP sockets (e.g. `ping`).
- `aid_admin` (GID `3005`): Administrative network management.

### 2. POSIX Shared Memory (`/dev/shm`) Workaround
Android does not provide standard POSIX `/dev/shm` (it uses `ashmem` / `dmabuf`), causing modern Linux software (compilers, Python multiprocessing, PostgreSQL) to fail. The launcher automatically mounts a lightweight `tmpfs` directly to `/data/chroot/alpine/dev/shm`:
```bash
mount -t tmpfs -o rw,nosuid,nodev tmpfs "$CHROOT_DIR/dev/shm"
```

### 3. Dynamic DNS Synchronization
Android routes DNS through its internal `netd` daemon and system properties (`net.dns1`) rather than `/etc/resolv.conf`. Each time `enter-alpine.sh` runs, it refreshes `/etc/resolv.conf` with `1.1.1.1` and `8.8.8.8` to guarantee working network lookups across Wi-Fi and mobile data switches.

### 4. Clean Environment Isolation
Android exports numerous non-POSIX environment variables (`ANDROID_DATA`, `BOOTCLASSPATH`, `LD_PRELOAD`) that can crash Linux binaries. The launcher uses:
```bash
exec chroot "$CHROOT_DIR" /usr/bin/env -i HOME=/root TERM=xterm-256color SHELL="$LOGIN_SHELL" PATH=... "$LOGIN_SHELL" -l
```
This strips the Android environment completely and supplies only pure, clean POSIX variables.

### 5. Idempotent Mount Plumbing
The launcher uses `mountpoint -q` checks before every bind-mount. Multiple terminal tabs or SSH sessions can safely invoke `alpine` simultaneously without triggering duplicate or recursive mount errors.

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
