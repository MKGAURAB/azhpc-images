#!/bin/bash
set -ex

# =============================================================================
# Layer 3: AlmaLinux 9.7 GPU + MPI Components
# =============================================================================
# Installs MPI stacks and GPU-specific drivers/libraries.
# =============================================================================

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing arguments."
    echo "Usage: ./install_layer3_gpu.sh <GPU_TYPE> <SKU>"
    exit 1
fi

export GPU=$1
export SKU=$2

if [[ "$GPU" != "NVIDIA" ]]; then
    echo "Error: Only NVIDIA GPUs are supported for AlmaLinux today."
    exit 1
fi

echo "=========================================="
echo "Layer 3: GPU + MPI Installation (AlmaLinux 9.7)"
echo "GPU Type: $GPU"
echo "SKU: $SKU"
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source ../../utils/set_properties.sh

echo "Installing MPI libraries..."
$COMPONENT_DIR/install_mpis.sh

if [ "$GPU" = "NVIDIA" ]; then
    echo "Installing NVIDIA driver..."
    $COMPONENT_DIR/install_nvidiagpudriver.sh

    echo "Installing NCCL..."
    $COMPONENT_DIR/install_nccl.sh

    echo "Installing Docker with NVIDIA support..."
    $COMPONENT_DIR/install_docker.sh

    echo "Installing DCGM..."
    $COMPONENT_DIR/install_dcgm.sh
fi

echo "Copying test files..."
$COMPONENT_DIR/copy_test_file.sh

echo "Installing health checks..."
$COMPONENT_DIR/install_health_checks.sh "$GPU"

echo "Applying SKU customizations..."
$COMPONENT_DIR/setup_sku_customizations.sh

echo "Cleaning up temporary files..."
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh 2>/dev/null || true
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf* 2>/dev/null || true
rm -rf /var/intel/ /var/cache/* 2>/dev/null || true
rm -Rf -- */ 2>/dev/null || true

echo "=========================================="
echo "Layer 3 Complete"
echo "GPU: $GPU, SKU: $SKU"
echo "Disk usage: $(df -h / | tail -1 | awk '{print $3 " / " $2}')"
echo "=========================================="
