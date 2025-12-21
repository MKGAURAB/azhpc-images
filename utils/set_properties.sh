#!/bin/bash
set -ex

export TOP_DIR="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
export COMPONENT_DIR=$TOP_DIR/components
export TEST_DIR=$TOP_DIR/tests
export UTILS_DIR=$TOP_DIR/utils
export DISTRIBUTION=$(. /etc/os-release;echo $ID$VERSION_ID)

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    export ARCHITECTURE_DISTRO=$(dpkg --print-architecture)
else    
    export ARCHITECTURE_DISTRO=$(rpm --eval '%{_arch}')
fi
export ARCHITECTURE=$(uname -m)

# =============================================================================
# LAYERED PACKER BUILD OPTIMIZATION
# =============================================================================
# In layered Packer builds, set_properties.sh is sourced in EVERY layer.
# However, package updates/upgrades only need to happen in Layer 1 (base_os).
#
# For Layer 2+ (hpc_packages, gpu_specific), we skip apt update/upgrade/install:
#   1. Packages are already installed from Layer 1
#   2. Running apt upgrade again can cause issues (e.g., packages-microsoft-prod
#      upgrade changes GPG key location, breaking Lustre/PMIX installs)
#   3. It's wasteful to run the same operations multiple times
#
# LAYER_TYPE is set by Packer: base_os, hpc_packages, or gpu_specific
# Single builds (install.sh) don't set LAYERED_BUILD, so they run normally.
# =============================================================================

# Skip package operations if this is Layer 2+ in a layered build
# LAYER_TYPE=base_os is Layer 1, anything else is Layer 2+
if [[ "${LAYERED_BUILD:-false}" == "true" ]] && [[ "${LAYER_TYPE}" != "base_os" ]]; then
    echo "Layered build (${LAYER_TYPE}): Skipping package operations (only needed in base_os layer)"
else
    # Layer 1 (base_os) or single build: Run all package operations
    if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
        # Don't allow the kernel to be updated
        if [ "$SKU" = "GB200" ]; then
            apt-mark hold linux-azure-nvidia
        else
            apt-mark hold linux-azure
        fi
        # upgrade pre-installed components
        apt update
        apt upgrade -y
        # jq is needed to parse the component versions from the versions.json file
        apt install -y jq
    elif [[ $DISTRIBUTION == almalinux* ]]; then
        if [[ $DISTRIBUTION == "almalinux8.10" ]]; then
            # Import the newest AlmaLinux GPG key
            rpm --import https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux
        elif [[ $DISTRIBUTION == "almalinux9.6" ]]; then
            rpm --import https://repo.almalinux.org/almalinux/RPM-GPG-KEY-AlmaLinux-9
        fi
        yum install -y jq    
    elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
        tdnf install -y jq
    fi
fi

# Export MODULE_FILES_DIRECTORY (always needed)
if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    export MODULE_FILES_DIRECTORY=/usr/share/modules/modulefiles
elif [[ $DISTRIBUTION == almalinux* ]] || [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    export MODULE_FILES_DIRECTORY=/usr/share/Modules/modulefiles
fi

# Component Versions
export COMPONENT_VERSIONS=$(jq -r . $TOP_DIR/versions.json)
