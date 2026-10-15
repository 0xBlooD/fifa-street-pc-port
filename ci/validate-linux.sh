#!/usr/bin/env bash
# ==============================================================================
# ReStreet Linux CI Validation Script
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> Validating bash syntax for Linux scripts..."
scripts=(
    "${ROOT_DIR}/scripts/build-linux.sh"
    "${ROOT_DIR}/Installer/BuildFifaStreet.sh"
    "${ROOT_DIR}/ci/validate-linux.sh"
)

for script in "${scripts[@]}"; do
    if [ -f "${script}" ]; then
        bash -n "${script}"
        echo "  [OK] $(basename "${script}")"
    fi
done

echo "==> Validating CMakePresets in recomp-template..."
cmake -S "${ROOT_DIR}/Installer/recomp-template" --list-presets >/dev/null
echo "  [OK] CMakePresets.json syntax and presets verified."

echo "==> All Linux validations passed!"
