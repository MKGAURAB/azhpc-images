#!/bin/bash
set -ex

# =============================================================================
# Layer 1: Base OS - No HPC, No GPU dependencies
# =============================================================================
# This layer installs base utilities, build tools, and system configuration.
# It has no dependencies on HPC networking or GPU components.
#
# Usage:
#   ./install_layer1_base.sh
#
# Can be called standalone or from install.sh
# =============================================================================

echo "=========================================="
echo "Layer 1: Base OS Installation"
echo "=========================================="

# Source utilities if available (for set_properties.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Set up environment variables
source ../../utils/set_properties.sh

# Remove packages requiring Ubuntu Pro for security updates
echo "Removing unused packages..."
./remove_unused_packages.sh

# Install base utilities (build tools, libraries, etc.)
echo "Installing base utilities..."
./install_utils.sh

# Update cmake to required version
echo "Installing CMake..."
$COMPONENT_DIR/install_cmake.sh

echo "========================================="
echo "Layer 1 Complete: Base OS"
echo "Disk usage: $(df -h / | tail -1 | awk '{print $3 " / " $2}')"
echo "=========================================="
