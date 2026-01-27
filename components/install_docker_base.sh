#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Install Moby Engine and CLI (GPU-agnostic runtime)
if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    apt-get install -y moby-engine moby-cli
elif [[ $DISTRIBUTION == almalinux* ]]; then
    yum install -y moby-engine moby-cli
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    tdnf install -y moby-engine moby-cli
fi

# Enable and restart the docker daemon
systemctl enable docker
systemctl restart docker

# Restart containerd service to pick up config changes
systemctl restart containerd

# Status of containerd snapshotter plugins
ctr plugin ls

# Write the docker version to components file
if command -v docker >/dev/null 2>&1; then
    docker_version=$(docker --version | awk -F' ' '{print $3}')
    write_component_version "DOCKER" ${docker_version::-1}
fi

if [[ $DISTRIBUTION == ubuntu* ]]; then
    moby_version=$(apt list --installed | grep moby-engine | awk -F' ' '{print $2}')
elif [[ $DISTRIBUTION == almalinux* ]]; then
    moby_version=$(yum list installed | grep moby-engine | awk -F' ' '{print $2}')
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    moby_version=$(rpm -qa | grep moby | cut -d'-' -f3,4)
fi
write_component_version "MOBY_ENGINE" ${moby_version}
