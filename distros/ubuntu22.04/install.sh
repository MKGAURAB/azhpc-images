#!/bin/bash
set -ex

# =============================================================================
# HPC Image Installation Script
# =============================================================================
# This is the main entry point that maintains FULL BACKWARD COMPATIBILITY
# with existing pipelines while internally using the new layered architecture.
#
# Usage (unchanged from before):
#   ./install.sh <GPU_TYPE> <SKU>
#
# Layered Architecture (for Packer builds):
#   Layer 1 (Base):     ./install_layer1_base.sh
#   Layer 2 (HPC):      ./install_layer2_hpc.sh
#   Layer 3 (GPU+MPI):  ./install_layer3_gpu.sh NVIDIA A100
#   Finalize:           ./install_finalize.sh
#
# This script runs ALL layers sequentially for backward compatibility.
# =============================================================================

# Check if arguments are passed
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing arguments. Please provide both GPU type (NVIDIA/AMD) and SKU."
    exit 1
fi

export GPU=$1
export SKU=$2

if [[ "$#" -gt 0 ]]; then
   if [[ "$GPU" != "NVIDIA" && "$GPU" != "AMD" ]]; then
       echo "Error: Invalid GPU type. Please specify 'NVIDIA' or 'AMD'."
       exit 1
    fi
fi

echo "=========================================="
echo "HPC Image Full Installation"
echo "GPU: $GPU, SKU: $SKU"
echo "=========================================="

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# =============================================================================
# Layer 1: Base OS (utilities, cmake, build tools)
# =============================================================================
echo ""
echo ">>> Running Layer 1: Base OS..."
./install_layer1_base.sh

# =============================================================================
# Layer 2: HPC Components (Lustre, DOCA, PMIX, AMD/Intel libs, tuning)
# =============================================================================
echo ""
echo ">>> Running Layer 2: HPC Components..."
./install_layer2_hpc.sh

# =============================================================================
# Layer 3: GPU + MPI (drivers, NCCL/RCCL, MPI, health checks)
# =============================================================================
echo ""
echo ">>> Running Layer 3: GPU + MPI..."
./install_layer3_gpu.sh "$GPU" "$SKU"

# =============================================================================
# Finalization: Security scan, cleanup, disable cloud-init
# =============================================================================
echo ""
echo ">>> Running Finalization..."
./install_finalize.sh

echo ""
echo "=========================================="
echo "HPC Image Installation Complete"
echo "GPU: $GPU, SKU: $SKU"
echo "=========================================="

# clear history
# Uncomment the line below if you are running this on a VM
# $UTILS_DIR/clear_history.sh
