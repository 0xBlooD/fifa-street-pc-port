#!/usr/bin/env bash
# ==============================================================================
# ReStreet (FIFA Street 2012) - Linux Build Orchestration Script
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

REXGLUE_DIR="${ROOT_DIR}/ReXGlue"
REXGLUE_COMMIT="c94f5ebdcb3c9d1a460ca48e04f9758448f8d518"
PATCH_FILE="${ROOT_DIR}/patches/rexglue-local-changes.patch"

JOBS="${JOBS:-$(nproc)}"
BUILD_TYPE="${BUILD_TYPE:-Release}"

echo "=========================================================="
echo " ReStreet - Linux Native Build"
echo " Target: x86_64 Linux | Backend: Vulkan"
echo " Parallel Jobs: ${JOBS} | Build Type: ${BUILD_TYPE}"
echo "=========================================================="

# 1. Dependency Checks
command -v cmake >/dev/null 2>&1 || { echo >&2 "[ERROR] cmake is required but not installed."; exit 1; }
command -v ninja >/dev/null 2>&1 || { echo >&2 "[ERROR] ninja is required but not installed."; exit 1; }
command -v clang >/dev/null 2>&1 || { echo >&2 "[ERROR] clang is required but not installed."; exit 1; }
command -v clang++ >/dev/null 2>&1 || { echo >&2 "[ERROR] clang++ is required but not installed."; exit 1; }
command -v git >/dev/null 2>&1 || { echo >&2 "[ERROR] git is required but not installed."; exit 1; }

# 2. Prepare ReXGlue
if [ ! -d "${REXGLUE_DIR}/.git" ]; then
    echo "[1/4] Cloning ReXGlue repository..."
    git clone --recursive https://github.com/rexglue/rexglue-sdk.git "${REXGLUE_DIR}"
    git -C "${REXGLUE_DIR}" checkout "${REXGLUE_COMMIT}"
    git -C "${REXGLUE_DIR}" submodule update --init --recursive
else
    echo "[1/4] ReXGlue repository found at ${REXGLUE_DIR}."
fi

# 3. Apply ReStreet local patch
echo "[2/4] Checking and applying ReStreet local patch..."
if git -C "${REXGLUE_DIR}" apply --check "${PATCH_FILE}" >/dev/null 2>&1; then
    git -C "${REXGLUE_DIR}" apply "${PATCH_FILE}"
    echo "Patch applied successfully."
else
    # Check if patch is already applied (reverse check)
    if git -C "${REXGLUE_DIR}" apply --reverse --check "${PATCH_FILE}" >/dev/null 2>&1; then
        echo "Patch already applied. Skipping."
    else
        echo >&2 "[WARNING] Could not apply patch cleanly. Please inspect git status in ${REXGLUE_DIR}."
    fi
fi

# 4. Build ReXGlue SDK (Vulkan + Code Generator)
BUILD_DIR="${REXGLUE_DIR}/out/build/linux-amd64"
cmake -S "${REXGLUE_DIR}" --preset linux-amd64 \
    -DREXGLUE_USE_D3D12=OFF \
    -DREXGLUE_USE_VULKAN=ON

echo "[4/4] Building ReXGlue SDK..."
cmake --build "${BUILD_DIR}" --config "${BUILD_TYPE}" --parallel "${JOBS}"

echo ""
echo "=========================================================="
echo " ReXGlue SDK build complete!"
echo " Code generator: ${REXGLUE_DIR}/out/linux-amd64/${BUILD_TYPE}/rexglue"
echo " Runtime libraries: ${REXGLUE_DIR}/out/linux-amd64/${BUILD_TYPE}/"
echo "=========================================================="
echo "To recompile FIFA Street from extracted GameData:"
echo "  ./Installer/BuildFifaStreet.sh --gamedata /path/to/GameData --output dist/Game"
echo "=========================================================="
