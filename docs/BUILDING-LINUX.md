# Building from Source on Linux

This guide covers building **ReStreet** (FIFA Street 2012) natively on x86_64 Linux systems using ReXGlue and the Vulkan graphics backend.

Following the project's [contribution guidelines](../CONTRIBUTING.md), this repository does not include ISOs, XEX files, extracted game archives, or compiled game binaries. You must supply your own legally obtained Xbox 360 copy of FIFA Street (2012).

---

## 1. Prerequisites

### System Requirements
- **OS**: 64-bit Linux distribution (e.g. Ubuntu 22.04+, Arch Linux, Fedora 39+, Debian 12+)
- **CPU**: x86-64 with SSSE3 support
- **GPU**: Vulkan 1.2+ capable GPU with proprietary or Mesa RADV/ANV/NVK drivers
- **RAM**: 8 GB minimum
- **Disk**: ~15 GB free space for compilation and game assets

### Build Tools & Libraries
Install the required packages using your distribution's package manager:

#### Arch Linux / Manjaro
```bash
sudo pacman -S base-devel git cmake ninja clang vulkan-devel vulkan-headers sdl3
```

#### Ubuntu / Debian
```bash
sudo apt update
sudo apt install build-essential git cmake ninja-build clang llvm \
    libvulkan-dev vulkan-tools libsdl3-dev
```

#### Fedora
```bash
sudo dnf install @development-tools git cmake ninja-build clang llvm \
    vulkan-loader-devel vulkan-headers
```

---

## 2. Quick Start: Automated Build

We provide a turnkey script that clones the pinned ReXGlue revision, applies project patches, and builds the SDK:

```bash
# 1. Clone the project and switch to feat/linux-port branch
git clone https://github.com/0xBlooD/fifa-street-pc-port.git
cd fifa-street-pc-port

# 2. Build ReXGlue SDK (Vulkan backend + code generator)
./scripts/build-linux.sh
```

---

## 3. Manual Step-by-Step Build

### Step 3.1: Prepare ReXGlue SDK
```bash
git clone --recursive https://github.com/rexglue/rexglue-sdk.git ReXGlue
git -C ReXGlue checkout c94f5ebdcb3c9d1a460ca48e04f9758448f8d518
git -C ReXGlue submodule update --init --recursive
git -C ReXGlue apply patches/rexglue-local-changes.patch
```

### Step 3.2: Compile ReXGlue (Vulkan Backend)
```bash
cmake -S ReXGlue --preset linux-amd64 -DREXGLUE_USE_D3D12=OFF -DREXGLUE_USE_VULKAN=ON
cmake --build ReXGlue/out/build/linux-amd64 --config Release --parallel $(nproc)
```

### Step 3.3: Extract Game ISO
Use [extract-xiso](https://github.com/XboxDev/extract-xiso) compiled natively for Linux:
```bash
extract-xiso -x -d dist/GameData "path/to/FIFA Street.iso"
```
Ensure `dist/GameData` contains:
- `default.xex`
- `fifadllzf.xex.dll`
- `dlc/dlc_FootballCompEng/dlc/FootballCompEng/FootballCompEngzf.xex.dll`

### Step 3.4: Recompile FIFA Street
Run the Linux recompilation tool:
```bash
./Installer/BuildFifaStreet.sh --gamedata dist/GameData --output dist/Game
```

---

## 4. Running the Game on Linux

Launch directly from the output directory:
```bash
cd dist/Game
./fifastreet
```

Configuration is loaded from `fifastreet.toml`. Key environment variables:
- `REX_TRUE_VSYNC=1`: Enable True VSync synchronization.
- `REX_FRAME_LIMITER_MIN_HZ=auto` (or custom rate, e.g. `60`, `144`).
- `VK_INSTANCE_LAYERS=...`: Optional Vulkan overlay/validation layers.

---

## 5. Contributing & Validation

Please refer to [CONTRIBUTING.md](../CONTRIBUTING.md) before opening pull requests:
- Keep ReXGlue engine modifications clean and isolated in `patches/rexglue-local-changes.patch`.
- Test builds without regressions on existing Windows configurations.
- Never commit copyrighted game files, ISOs, or recompiled binaries.
