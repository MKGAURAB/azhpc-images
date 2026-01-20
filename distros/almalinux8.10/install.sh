#!/bin/bash
set -ex

# =============================================================================
# AlmaLinux 8.10 Installation Entry Point
# =============================================================================
# Provides backward-compatible orchestration that runs all three layers
# followed by finalize.sh when executed outside of Packer.
# =============================================================================

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing arguments. Please provide both GPU type and SKU."
    echo "Usage: ./install.sh NVIDIA A100"
    exit 1
fi

export GPU=$1
export SKU=$2

if [[ "$GPU" != "NVIDIA" ]]; then
    echo "Error: Only NVIDIA GPUs are supported for AlmaLinux today."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source ../../utils/set_properties.sh

chmod +x install_layer1_base.sh install_layer2_hpc.sh install_layer3_gpu.sh finalize.sh 2>/dev/null || true

echo "\n>>> Running Layer 1..."
./install_layer1_base.sh

echo "\n>>> Running Layer 2..."
./install_layer2_hpc.sh

echo "\n>>> Running Layer 3..."
./install_layer3_gpu.sh "$GPU" "$SKU"

echo "\n>>> Finalizing..."
./finalize.sh