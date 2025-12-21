#!/bin/bash
set -ex

# =============================================================================
# Layer 3: GPU + MPI Components
# =============================================================================
# This layer installs GPU drivers, CUDA/ROCm, MPI libraries, and GPU-specific
# communication libraries (NCCL/RCCL).
#
# MPI is included here because:
#   - HPC-X has different versions for AMD vs NVIDIA GPUs
#   - NCCL/RCCL tests require both MPI and GPU
#   - Health checks need GPU-specific containers
#
# Components installed:
#   - NVIDIA: GPU driver, CUDA, NCCL, Docker+NVIDIA toolkit, DCGM
#   - AMD: ROCm, RCCL, Docker
#   - Both: MPI libraries (HPC-X, OpenMPI, MVAPICH, Intel MPI)
#   - Health checks
#   - SKU customizations
#
# Usage:
#   ./install_layer3_gpu.sh <GPU_TYPE> <SKU>
#   
#   GPU_TYPE: NVIDIA or AMD
#   SKU: GPU model (e.g., A100, H100, MI300X)
#
# Example:
#   ./install_layer3_gpu.sh NVIDIA A100
#   ./install_layer3_gpu.sh AMD MI300X
#
# Prerequisites: Layer 1 and Layer 2 must be completed
# =============================================================================

# Check if arguments are passed
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing arguments."
    echo "Usage: ./install_layer3_gpu.sh <GPU_TYPE> <SKU>"
    echo "  GPU_TYPE: NVIDIA or AMD"
    echo "  SKU: GPU model (e.g., A100, H100, MI300X)"
    exit 1
fi

export GPU=$1
export SKU=$2

if [[ "$GPU" != "NVIDIA" && "$GPU" != "AMD" ]]; then
    echo "Error: Invalid GPU type. Please specify 'NVIDIA' or 'AMD'."
    exit 1
fi

echo "=========================================="
echo "Layer 3: GPU + MPI Installation"
echo "GPU Type: $GPU"
echo "SKU: $SKU"
echo "=========================================="

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Set up environment variables
source ../../utils/set_properties.sh

# Install MPI libraries (GPU-aware - HPC-X version depends on GPU type)
echo "Installing MPI libraries..."
$COMPONENT_DIR/install_mpis.sh

if [ "$GPU" = "NVIDIA" ]; then
    echo "=========================================="
    echo "Installing NVIDIA GPU Stack"
    echo "=========================================="
    
    # Install NVIDIA GPU driver and CUDA
    echo "Installing NVIDIA driver..."
    $COMPONENT_DIR/install_nvidiagpudriver.sh
    
    # Install NCCL (NVIDIA Collective Communications Library)
    echo "Installing NCCL..."
    $COMPONENT_DIR/install_nccl.sh
    
    # Install Docker with NVIDIA container toolkit
    echo "Installing Docker with NVIDIA support..."
    $COMPONENT_DIR/install_docker.sh

    # Install DCGM (Data Center GPU Manager)
    echo "Installing DCGM..."
    $COMPONENT_DIR/install_dcgm.sh
fi

if [ "$GPU" = "AMD" ]; then
    echo "=========================================="
    echo "Installing AMD GPU Stack"
    echo "=========================================="
    
    # Set up Docker first (required for AMD)
    echo "Installing Docker..."
    apt-get install -y moby-engine
    systemctl enable docker
    systemctl restart docker

    # Install ROCm software stack
    echo "Installing ROCm..."
    $COMPONENT_DIR/install_rocm.sh
    
    # Install RCCL (ROCm Communication Collectives Library)
    echo "Installing RCCL..."
    $COMPONENT_DIR/install_rccl.sh
fi

# Install Azure/NHC Health Checks (requires GPU platform)
echo "Installing health checks..."
$COMPONENT_DIR/install_health_checks.sh "$GPU"

# Apply SKU-specific customizations
echo "Setting up SKU customizations..."
$COMPONENT_DIR/setup_sku_customizations.sh

echo "=========================================="
echo "Layer 3 Complete: GPU + MPI"
echo "GPU: $GPU, SKU: $SKU"
echo "Disk usage: $(df -h / | tail -1 | awk '{print $3 " / " $2}')"
echo "=========================================="
