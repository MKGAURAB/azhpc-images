#!/bin/bash
set -ex

# =============================================================================
# Azure Linux 3.0 - Complete Installation Script
# =============================================================================
# This script installs all layers in sequence: Base OS, HPC, and GPU+MPI
# It maintains backward compatibility with the original monolithic approach
# while also supporting the new layered architecture used by Packer.
#
# Usage:
#   ./install.sh <GPU_TYPE> <SKU>
#   
#   GPU_TYPE: NVIDIA or AMD
#   SKU: GPU model (e.g., A100, H100, MI300X)
#
# Example:
#   ./install.sh NVIDIA A100
#   ./install.sh AMD MI300X
#
# Layered usage (for Packer):
#   Layer 1 (Base):     ./install_layer1_base.sh
#   Layer 2 (HPC):      ./install_layer2_hpc.sh
#   Layer 3 (GPU+MPI):  ./install_layer3_gpu.sh NVIDIA A100
#   Finalization:       ./finalize.sh
# =============================================================================

# Check if arguments are passed
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing arguments. Please provide both GPU type (NVIDIA/AMD) and SKU."
    echo "Usage: ./install.sh <GPU_TYPE> <SKU>"
    exit 1
fi

export GPU=$1
export SKU=$2

if [[ "$GPU" != "NVIDIA" && "$GPU" != "AMD" ]]; then
    echo "Error: Invalid GPU type. Please specify 'NVIDIA' or 'AMD'."
    exit 1
fi

echo "=========================================="
echo "Azure Linux 3.0 - Full Installation"
echo "GPU: $GPU"
echo "SKU: $SKU"
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Source environment
source ../../utils/set_properties.sh

# Ensure layer scripts have execute permissions
chmod +x install_layer1_base.sh install_layer2_hpc.sh install_layer3_gpu.sh finalize.sh 2>/dev/null || true

# ==========================================
# Layer 1: Base OS Installation
# ==========================================
echo ""
echo "Starting Layer 1: Base OS..."
./install_layer1_base.sh

# ==========================================
# Layer 2: HPC Components Installation
# ==========================================
echo ""
echo "Starting Layer 2: HPC Components..."
./install_layer2_hpc.sh

# ==========================================
# Layer 3: GPU + MPI Installation
# ==========================================
echo ""
echo "Starting Layer 3: GPU + MPI..."
./install_layer3_gpu.sh "$GPU" "$SKU"

# ==========================================
# Finalization
# ==========================================
echo ""
echo "Starting Finalization..."
./finalize.sh

echo "=========================================="
echo "Installation Complete!"
echo "GPU: $GPU, SKU: $SKU"
echo "=========================================="

# clear history
# Uncomment the line below if you are running this on a VM
# $UTILS_DIR/clear_history.sh
