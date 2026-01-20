#!/bin/bash
set -ex

# =============================================================================
# Layer 2: AlmaLinux 8.10 HPC Components
# =============================================================================
# Installs Lustre, OFED, PMIX, CPU math libraries, and platform tuning.
# =============================================================================

echo "=========================================="
echo "Layer 2: HPC Components Installation (AlmaLinux 8.10)"
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source ../../utils/set_properties.sh

echo "Installing Lustre client..."
$COMPONENT_DIR/install_lustre_client.sh

echo "Installing DOCA OFED..."
$COMPONENT_DIR/install_doca.sh

echo "Installing PMIX..."
$COMPONENT_DIR/install_pmix.sh

echo "Installing AMD CPU libraries..."
$COMPONENT_DIR/install_amd_libs.sh

echo "Installing Intel MKL..."
$COMPONENT_DIR/install_intel_libs.sh

echo "Applying HPC tuning..."
$COMPONENT_DIR/hpc-tuning.sh

echo "Installing Azure NFS helper..."
$COMPONENT_DIR/install_aznfs.sh

echo "Installing HPC diagnostics..."
$COMPONENT_DIR/install_hpcdiag.sh

echo "Installing monitoring tools..."
$COMPONENT_DIR/install_monitoring_tools.sh

echo "Configuring persistent RDMA naming..."
$COMPONENT_DIR/install_azure_persistent_rdma_naming.sh

echo "Adding udev rules for network devices..."
$COMPONENT_DIR/add-udev-rules.sh

if [[ -f ./network-config.sh ]]; then
    chmod +x ./network-config.sh
    echo "Applying network interface rules..."
    ./network-config.sh
fi

echo "=========================================="
echo "Layer 2 Complete"
echo "Disk usage: $(df -h / | tail -1 | awk '{print $3 " / " $2}')"
echo "=========================================="
