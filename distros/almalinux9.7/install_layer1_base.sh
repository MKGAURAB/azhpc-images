#!/bin/bash
set -ex

# =============================================================================
# Layer 1: AlmaLinux 9.7 Base OS
# =============================================================================
# Installs distro prerequisites, development tools, and common utilities.
# =============================================================================

echo "=========================================="
echo "Layer 1: Base OS Installation (AlmaLinux 9.7)"
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source ../../utils/set_properties.sh

echo "Installing base utilities..."
./install_utils.sh

echo "Installing CMake..."
$COMPONENT_DIR/install_cmake.sh

echo "=========================================="
echo "Layer 1 Complete"
echo "Disk usage: $(df -h / | tail -1 | awk '{print $3 " / " $2}')"
echo "=========================================="
