#!/bin/bash
set -ex

# =============================================================================
# Layer 2: HPC Components - No GPU, No MPI dependencies
# =============================================================================
# This layer installs HPC networking, storage, and optimization components.
# It does NOT include GPU drivers or MPI libraries.
#
# Components installed:
#   - Lustre client (Azure Managed Lustre)
#   - DOCA/OFED (InfiniBand drivers)
#   - PMIX (Process Management Interface)
#   - AMD CPU libraries (AOCL, AOCC - NOT GPU)
#   - Intel MKL
#   - HPC tuning
#   - Azure NFS helper
#   - HPC diagnostics
#   - Monitoring tools
#   - RDMA persistent naming
#   - udev rules
#
# Usage:
#   ./install_layer2_hpc.sh
#
# Prerequisites: Layer 1 (install_layer1_base.sh) must be completed
# =============================================================================

echo "=========================================="
echo "Layer 2: HPC Components Installation"
echo "=========================================="

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Set up environment variables
source ../../utils/set_properties.sh

# Install Lustre client for Azure Managed Lustre
echo "Installing Lustre client..."
$COMPONENT_DIR/install_lustre_client.sh

# Install DOCA OFED (InfiniBand/RDMA drivers)
echo "Installing DOCA OFED..."
$COMPONENT_DIR/install_doca.sh

# Install PMIX (Process Management Interface for Exascale)
echo "Installing PMIX..."
$COMPONENT_DIR/install_pmix.sh

# Install AMD CPU optimization libraries (AOCL, AOCC compilers)
# Note: This is NOT GPU-related, these are CPU math libraries
echo "Installing AMD CPU libraries..."
$COMPONENT_DIR/install_amd_libs.sh

# Install Intel oneAPI Math Kernel Library
echo "Installing Intel MKL..."
$COMPONENT_DIR/install_intel_libs.sh

# Apply HPC system tuning (sysctl, limits, etc.)
echo "Applying HPC tuning..."
$COMPONENT_DIR/hpc-tuning.sh

# Install Azure NFS mount helper
echo "Installing AZNFS..."
$COMPONENT_DIR/install_aznfs.sh

# Install HPC diagnostics tools
echo "Installing HPC diagnostics..."
$COMPONENT_DIR/install_hpcdiag.sh

# Install monitoring tools
echo "Installing monitoring tools..."
$COMPONENT_DIR/install_monitoring_tools.sh

# Install persistent RDMA naming
echo "Installing RDMA persistent naming..."
$COMPONENT_DIR/install_azure_persistent_rdma_naming.sh

# Add udev rules for InfiniBand devices
echo "Adding udev rules..."
$COMPONENT_DIR/add-udev-rules.sh

# Copy test files
echo "Copying test files..."
$COMPONENT_DIR/copy_test_file.sh

echo "========================================="
echo "Layer 2 Complete: HPC Components"
echo "Disk usage: $(df -h / | tail -1 | awk '{print $3 " / " $2}')"
echo "=========================================="
