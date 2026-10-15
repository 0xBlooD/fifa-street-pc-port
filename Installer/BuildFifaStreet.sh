#!/usr/bin/env bash
# ==============================================================================
# ReStreet (FIFA Street 2012) - Linux Recompilation Script
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/recomp-template"

GAME_DATA=""
OUTPUT_DIR=""
WORKSPACE=""
JOBS="${JOBS:-$(nproc)}"
BUILD_TYPE="Release"
REXSDK_DIR="${REXSDK_DIR:-${ROOT_DIR}/ReXGlue}"

usage() {
    cat <<EOF
Usage: $(basename "$0") --gamedata <path> --output <path> [options]

Required Arguments:
  -g, --gamedata <path>   Path to extracted GameData directory containing default.xex
  -o, --output <path>     Path to output directory for compiled game binaries

Options:
  -w, --workspace <path>  Working directory for temporary code generation and build
  -j, --jobs <n>          Number of parallel compilation jobs (default: $(nproc))
  -b, --build-type <type> CMake build type: Release (default) or Debug
  -s, --sdk <path>        Path to ReXGlue SDK directory (default: ${ROOT_DIR}/ReXGlue)
  -h, --help              Show this help message
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -g|--gamedata)
            GAME_DATA="$(cd "$2" && pwd)"
            shift 2
            ;;
        -o|--output)
            mkdir -p "$2"
            OUTPUT_DIR="$(cd "$2" && pwd)"
            shift 2
            ;;
        -w|--workspace)
            mkdir -p "$2"
            WORKSPACE="$(cd "$2" && pwd)"
            shift 2
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        -b|--build-type)
            BUILD_TYPE="$2"
            shift 2
            ;;
        -s|--sdk)
            REXSDK_DIR="$(cd "$2" && pwd)"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo >&2 "[ERROR] Unknown option: $1"
            usage
            ;;
    esac
done

if [ -z "${GAME_DATA}" ] || [ -z "${OUTPUT_DIR}" ]; then
    echo >&2 "[ERROR] Both --gamedata and --output are required."
    usage
fi

echo "=========================================================="
echo " FIFA Street PC - Linux Recomp Build"
echo " GameData:  ${GAME_DATA}"
echo " Output:    ${OUTPUT_DIR}"
echo " ReXGlue:   ${REXSDK_DIR}"
echo " Parallel:  ${JOBS} jobs | ${BUILD_TYPE}"
echo "=========================================================="

# 1. Validate Game Data Modules
DEFAULT_XEX="${GAME_DATA}/default.xex"
FIFA_DLL="${GAME_DATA}/fifadllzf.xex.dll"
FOOTBALL_COMP_DLL="${GAME_DATA}/dlc/dlc_FootballCompEng/dlc/FootballCompEng/FootballCompEngzf.xex.dll"

# Check case-insensitive alternatives if needed
if [ ! -f "${DEFAULT_XEX}" ]; then
    DEFAULT_XEX="$(find "${GAME_DATA}" -maxdepth 2 -iname "default.xex" | head -n 1)"
fi
if [ ! -f "${FIFA_DLL}" ]; then
    FIFA_DLL="$(find "${GAME_DATA}" -maxdepth 2 -iname "fifadllzf.xex.dll" | head -n 1)"
fi
if [ ! -f "${FOOTBALL_COMP_DLL}" ]; then
    FOOTBALL_COMP_DLL="$(find "${GAME_DATA}" -ipath "*footballcompeng*.xex.dll" | head -n 1)"
fi

if [ -z "${DEFAULT_XEX}" ] || [ ! -f "${DEFAULT_XEX}" ]; then
    echo >&2 "[ERROR] default.xex not found in ${GAME_DATA}"
    exit 1
fi
if [ -z "${FIFA_DLL}" ] || [ ! -f "${FIFA_DLL}" ]; then
    echo >&2 "[ERROR] fifadllzf.xex.dll not found in ${GAME_DATA}"
    exit 1
fi
if [ -z "${FOOTBALL_COMP_DLL}" ] || [ ! -f "${FOOTBALL_COMP_DLL}" ]; then
    echo >&2 "[ERROR] FootballCompEngzf.xex.dll not found (required for World Tour)."
    exit 1
fi

# 2. Locate Code Generator
CODEGEN=""
for candidate in \
    "${REXSDK_DIR}/out/linux-amd64/${BUILD_TYPE}/rexglue" \
    "${REXSDK_DIR}/out/linux-amd64/Release/rexglue" \
    "${REXSDK_DIR}/out/linux-amd64/Debug/rexglue" \
    "${REXSDK_DIR}/out/linux-amd64/rexglue" \
    "${REXSDK_DIR}/out/build/linux-amd64/rexglue"; do
    if [ -x "${candidate}" ]; then
        CODEGEN="${candidate}"
        break
    fi
done

if [ -z "${CODEGEN}" ]; then
    CODEGEN="$(command -v rexglue || true)"
fi
if [ -z "${CODEGEN}" ] || [ ! -x "${CODEGEN}" ]; then
    echo >&2 "[ERROR] ReXGlue code generator (rexglue) not found. Run ./scripts/build-linux.sh first."
    exit 1
fi

# 3. Setup Workspace
if [ -z "${WORKSPACE}" ]; then
    WORKSPACE="$(mktemp -d -t fstrb_XXXXXX)"
fi
WORK_PROJECT="${WORKSPACE}/FifaStreetRex"
mkdir -p "${WORK_PROJECT}"

echo "[1/5] Preparing workspace at ${WORK_PROJECT}..."
cp -R "${TEMPLATE_DIR}/." "${WORK_PROJECT}/"
rm -f "${WORK_PROJECT}/fifastreet_manifest.toml"

# 4. Generate Manifest
echo "[2/5] Writing fifastreet_manifest.toml..."
MANIFEST_FILE="${WORK_PROJECT}/fifastreet_manifest.toml"
cat <<EOF > "${MANIFEST_FILE}"
[project]
name = "fifastreet"
sdk_version = "0.10.0"
game_root = "${GAME_DATA}"

[entrypoint]
file_path = "${DEFAULT_XEX}"
out_directory_path = "generated/default"
includes = []

[[modules]]
guest_path = "game:\\\\fifadllzf.xex.dll"
file_path = "${FIFA_DLL}"
out_directory_path = "generated/fifadllzf_xex"
includes = ["config/fifadllzf_overrides.toml"]

[[modules]]
guest_path = "game:\\\\FootballCompEngzf.xex.dll"
file_path = "${FOOTBALL_COMP_DLL}"
out_directory_path = "generated/FootballCompEngzf_xex"
includes = ["config/footballcompeng_overrides.toml"]
EOF

# 5. Run Codegen
echo "[3/5] Running ReXGlue codegen..."
"${CODEGEN}" --log-file "${WORKSPACE}/codegen.log" codegen "${MANIFEST_FILE}"

# 6. Configure and Compile
echo "[4/5] Configuring CMake build..."
PRESET_NAME="linux-amd64-$(echo "${BUILD_TYPE}" | tr '[:upper:]' '[:lower:]')"

cmake -S "${WORK_PROJECT}" --preset "${PRESET_NAME}" \
    -DREXSDK_DIR="${REXSDK_DIR}" \
    -DREXGLUE_USE_VULKAN=ON \
    -DREXGLUE_USE_D3D12=OFF \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_FLAGS="-mssse3" \
    -DCMAKE_CXX_FLAGS="-mssse3"

echo "[5/5] Compiling FIFA Street Linux binaries..."
cmake --build "${WORK_PROJECT}/out/build/${PRESET_NAME}" --config "${BUILD_TYPE}" --parallel "${JOBS}"

# 7. Install artifacts to Output
BUILD_OUT="${WORK_PROJECT}/out/build/${PRESET_NAME}"
echo "Installing to ${OUTPUT_DIR}..."

# Executable and modules
find "${BUILD_OUT}" -maxdepth 2 \( -name "fifastreet" -o -name "fifastreet.exe" -o -name "*.so" -o -name "*.dll" \) -exec cp -v {} "${OUTPUT_DIR}/" \;

# Copy ReXGlue runtime libraries (Vulkan backend)
RUNTIME_DIR="${REXSDK_DIR}/out/linux-amd64/${BUILD_TYPE}"
if [ ! -d "${RUNTIME_DIR}" ]; then
    RUNTIME_DIR="${REXSDK_DIR}/out/linux-amd64/Release"
fi
if [ -d "${RUNTIME_DIR}" ]; then
    find "${RUNTIME_DIR}" -maxdepth 1 -name "*.so*" -exec cp -v {} "${OUTPUT_DIR}/" \;
fi

# Default config
if [ -f "${ROOT_DIR}/Installer/payload/Game/fifastreet.toml" ]; then
    cp -v "${ROOT_DIR}/Installer/payload/Game/fifastreet.toml" "${OUTPUT_DIR}/fifastreet.toml"
fi

echo "=========================================================="
echo " Build successful! Game output ready in: ${OUTPUT_DIR}"
echo " Run with: cd ${OUTPUT_DIR} && ./fifastreet"
echo "=========================================================="
