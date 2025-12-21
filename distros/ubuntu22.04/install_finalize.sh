#!/bin/bash
set -ex

# =============================================================================
# Finalization Layer - Run after all other layers are complete
# =============================================================================
# This script performs final cleanup, security scanning, and image preparation.
# It should be run ONLY on the final layer before image capture.
#
# Components:
#   - Trivy security vulnerability scan
#   - Disable cloud-init
#   - Disable automatic kernel upgrades
#   - Disable predictive network interface naming
#   - Cleanup downloaded tarballs and temporary files
#
# Usage:
#   ./install_finalize.sh
#
# This script is automatically called by install.sh, or can be called
# separately in Packer workflows after the final layer is complete.
# =============================================================================

echo "=========================================="
echo "Finalization: Cleanup and Security Scan"
echo "=========================================="

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Set up environment variables
source ../../utils/set_properties.sh

# Cleanup downloaded tarballs and temporary files to save space
echo "Cleaning up temporary files..."
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh 2>/dev/null || true
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf* 2>/dev/null || true
rm -rf /var/intel/ /var/cache/* 2>/dev/null || true
rm -Rf -- */ 2>/dev/null || true

# Run Trivy security vulnerability scan
echo "Running Trivy security scan..."
$COMPONENT_DIR/trivy_scan.sh

# Disable cloud-init (not needed for HPC images)
echo "Disabling cloud-init..."
$COMPONENT_DIR/disable_cloudinit.sh

# Disable automatic kernel upgrades
echo "Disabling auto upgrades..."
./disable_auto_upgrade.sh

# Disable predictive network interface renaming
echo "Disabling predictive interface renaming..."
./disable_predictive_interface_renaming.sh

echo "========================================="
echo "Finalization Complete"
echo "Final disk usage: $(df -h / | tail -1 | awk '{print $3 " / " $2}')"
echo "=========================================="

# Print component versions if available
if [ -f /opt/azurehpc/component_versions.txt ]; then
    echo ""
    echo "Component Versions:"
    cat /opt/azurehpc/component_versions.txt
fi
