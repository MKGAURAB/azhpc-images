#!/bin/bash
set -ex

# =============================================================================
# CONFIGURATION SETUP SCRIPT
# Sets environment variables and performs initial package setup for HPC images
# =============================================================================

#------------------------------------------------------------------------------
# Directory Configuration
#------------------------------------------------------------------------------
setup_directories() {
    export TOP_DIR="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
    export COMPONENT_DIR="$TOP_DIR/components"
    export TEST_DIR="$TOP_DIR/tests"
    export UTILS_DIR="$TOP_DIR/utils"
}

#------------------------------------------------------------------------------
# Distribution Detection
#------------------------------------------------------------------------------
detect_distribution() {
    export DISTRIBUTION=$(. /etc/os-release; echo "$ID$VERSION_ID")
}

#------------------------------------------------------------------------------
# Architecture Detection
#------------------------------------------------------------------------------
detect_architecture() {
    if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
        export ARCHITECTURE_DISTRO=$(dpkg --print-architecture)
    else
        export ARCHITECTURE_DISTRO=$(rpm --eval '%{_arch}')
    fi
    export ARCHITECTURE=$(uname -m)
}

#------------------------------------------------------------------------------
# Module Files Directory Configuration
#------------------------------------------------------------------------------
setup_module_files_directory() {
    case "$DISTRIBUTION" in
        *ubuntu*)
            export MODULE_FILES_DIRECTORY=/usr/share/modules/modulefiles
            ;;
        almalinux*|azurelinux3.0)
            export MODULE_FILES_DIRECTORY=/usr/share/Modules/modulefiles
            ;;
    esac
}

#------------------------------------------------------------------------------
# Package Manager Operations
# 
# In layered Packer builds, set_properties.sh is sourced in EVERY layer.
# However, package updates/upgrades only need to happen in Layer 1 (base_os).
# For Layer 2+ (hpc_packages, gpu_specific), we skip package operations because:
#   1. Packages are already installed from Layer 1
#   2. Running apt upgrade again can cause issues (e.g., packages-microsoft-prod
#      upgrade changes GPG key location, breaking Lustre/PMIX installs)
#   3. It's wasteful to run the same operations multiple times
#
# LAYER_TYPE is set by Packer: base_os, hpc_packages, or gpu_specific
# Single builds (install.sh) don't set LAYERED_BUILD, so they run normally.
#------------------------------------------------------------------------------
is_layered_build_skip_required() {
    [[ "${LAYERED_BUILD:-false}" == "true" ]] && [[ "${LAYER_TYPE}" != "base_os" ]]
}

import_almalinux_gpg_key() {
    case "$DISTRIBUTION" in
        almalinux8.10)
            rpm --import https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux
            ;;
        almalinux9*)
            rpm --import https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux-9
            ;;
    esac
}

setup_ubuntu_packages() {
    # Prevent kernel updates
    local kernel_package="linux-azure"
    [[ "$SKU" == "GB200" ]] && kernel_package="linux-azure-nvidia"
    apt-mark hold "$kernel_package"

    # Upgrade pre-installed components
    apt update
    apt upgrade -y

    # jq is needed to parse component versions from versions.json
    apt install -y jq
}

setup_almalinux_packages() {
    import_almalinux_gpg_key
    yum install -y jq
}

setup_azurelinux_packages() {
    tdnf install -y jq
}

run_package_operations() {
    if is_layered_build_skip_required; then
        echo "Layered build (${LAYER_TYPE}): Skipping package operations (only needed in base_os layer)"
        return
    fi

    case "$DISTRIBUTION" in
        *ubuntu*)
            setup_ubuntu_packages
            ;;
        almalinux*)
            setup_almalinux_packages
            ;;
        azurelinux3.0)
            setup_azurelinux_packages
            ;;
    esac
}

#------------------------------------------------------------------------------
# Component Versions Loading
#------------------------------------------------------------------------------
load_component_versions() {
    export COMPONENT_VERSIONS=$(jq -r . "$TOP_DIR/versions.json")
}

#------------------------------------------------------------------------------
# Main Execution
#------------------------------------------------------------------------------
main() {
    setup_directories
    detect_distribution
    detect_architecture
    run_package_operations
    setup_module_files_directory
    load_component_versions
}

main
