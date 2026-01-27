#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Docker engine must already be installed in Layer 1.
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is not installed. Install install_docker_base.sh in Layer 1 first."
    exit 1
fi

# Install NVIDIA container toolkit and configure runtimes
$COMPONENT_DIR/install_nvidia_container_toolkit.sh

# Restart services to pick up NVIDIA runtime configuration
systemctl restart docker
systemctl restart containerd
