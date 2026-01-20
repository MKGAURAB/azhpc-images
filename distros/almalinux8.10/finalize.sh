#!/bin/bash
set -ex

# =============================================================================
# Finalization: AlmaLinux 8.10
# =============================================================================
# Cleans temporary artifacts, runs Trivy, and disables cloud-init.
# =============================================================================

echo "=========================================="
echo "Finalization: Cleanup and Security (AlmaLinux 8.10)"
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source ../../utils/set_properties.sh

echo "Cleaning temporary files..."
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh 2>/dev/null || true
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf* 2>/dev/null || true
rm -rf /var/intel/ /var/cache/* 2>/dev/null || true
rm -Rf -- */ 2>/dev/null || true

echo "Running Trivy security scan..."
$COMPONENT_DIR/trivy_scan.sh

echo "Disabling cloud-init..."
$COMPONENT_DIR/disable_cloudinit.sh

echo "=========================================="
echo "Finalization Complete"
echo "Disk usage: $(df -h / | tail -1 | awk '{print $3 " / " $2}')"
echo "=========================================="
