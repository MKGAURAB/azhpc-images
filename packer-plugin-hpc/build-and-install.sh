#!/bin/bash
# build-and-install.sh
# Cross-platform script to build and install the Packer HPC plugin
# Works on Linux and macOS

set -e

# Default values
VERSION="1.0.0"
VERSION_PRERELEASE="dev"
BUILD_ONLY=false
INSTALL_ONLY=false
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --install-only)
            INSTALL_ONLY=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --prerelease)
            VERSION_PRERELEASE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --build-only       Only build, don't install"
            echo "  --install-only     Only install (binary must exist)"
            echo "  --force            Force reinstall"
            echo "  --version VER      Set version (default: 1.0.0)"
            echo "  --prerelease PRE   Set prerelease (default: dev)"
            echo "  --help             Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Detect OS and architecture
detect_platform() {
    local os arch ext

    case "$(uname -s)" in
        Linux*)     os="linux" ;;
        Darwin*)    os="darwin" ;;
        MINGW*|MSYS*|CYGWIN*) os="windows" ;;
        *)          os="linux" ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64)   arch="amd64" ;;
        aarch64|arm64)  arch="arm64" ;;
        *)              arch="amd64" ;;
    esac

    if [[ "$os" == "windows" ]]; then
        ext=".exe"
    else
        ext=""
    fi

    echo "$os $arch $ext"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect platform
read -r GOOS GOARCH EXT <<< "$(detect_platform)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Packer Plugin HPC - Build & Install Script${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GRAY}Platform:    ${GOOS}/${GOARCH}${NC}"
if [[ -n "$VERSION_PRERELEASE" ]]; then
    echo -e "${GRAY}Version:     ${VERSION}-${VERSION_PRERELEASE}${NC}"
else
    echo -e "${GRAY}Version:     ${VERSION}${NC}"
fi
echo -e "${GRAY}Directory:   ${SCRIPT_DIR}${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check Go
if command -v go &> /dev/null; then
    GO_VERSION=$(go version | sed 's/go version //')
    echo -e "  ${GREEN}✓${NC} Go: ${GO_VERSION}"
else
    echo -e "  ${RED}✗${NC} Go not found. Please install Go from https://go.dev/dl/"
    exit 1
fi

# Check Packer
if command -v packer &> /dev/null; then
    PACKER_VERSION=$(packer version | head -n1)
    echo -e "  ${GREEN}✓${NC} Packer: ${PACKER_VERSION}"
else
    echo -e "  ${RED}✗${NC} Packer not found. Please install from https://developer.hashicorp.com/packer/downloads"
    exit 1
fi

echo ""

# Build plugin
if [[ "$INSTALL_ONLY" != "true" ]]; then
    echo -e "${YELLOW}Building plugin...${NC}"
    
    cd "$SCRIPT_DIR"
    
    # Set environment variables
    export GOOS
    export GOARCH
    export CGO_ENABLED=0
    
    # Generate HCL2 specs (required when Config struct changes)
    echo -e "  ${GRAY}Running: go generate ./...${NC}"
    go generate ./... || echo -e "  ${YELLOW}⚠${NC} go generate had warnings (continuing...)"
    
    # Binary name
    BINARY_NAME="packer-plugin-hpc${EXT}"
    
    # Build ldflags
    LDFLAGS="-X github.com/MKGAURAB/packer-plugin-hpc/version.Version=${VERSION}"
    if [[ -n "$VERSION_PRERELEASE" ]]; then
        LDFLAGS="${LDFLAGS} -X github.com/MKGAURAB/packer-plugin-hpc/version.VersionPrerelease=${VERSION_PRERELEASE}"
    fi
    
    echo -e "  ${GRAY}Running: go build -ldflags=\"${LDFLAGS}\" -o ${BINARY_NAME}${NC}"
    
    go build -ldflags="${LDFLAGS}" -o "${BINARY_NAME}"
    
    # Verify binary
    if [[ -f "$BINARY_NAME" ]]; then
        SIZE=$(du -h "$BINARY_NAME" | cut -f1)
        echo -e "  ${GREEN}✓${NC} Built: ${BINARY_NAME} (${SIZE})"
        
        # Make executable on Unix
        chmod +x "$BINARY_NAME"
        
        # Test describe
        DESCRIBE_OUTPUT=$(./"$BINARY_NAME" describe 2>&1)
        PLUGIN_VERSION=$(echo "$DESCRIBE_OUTPUT" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        PROVISIONERS=$(echo "$DESCRIBE_OUTPUT" | grep -o '"provisioners":\[[^]]*\]' | sed 's/"provisioners":\[//;s/\]//;s/"//g')
        echo -e "  ${GREEN}✓${NC} Plugin version: ${PLUGIN_VERSION}"
        echo -e "  ${GREEN}✓${NC} Provisioners: ${PROVISIONERS}"
    else
        echo -e "  ${RED}✗${NC} Binary not found after build"
        exit 1
    fi
    
    echo ""
fi

# Install plugin
if [[ "$BUILD_ONLY" != "true" ]]; then
    echo -e "${YELLOW}Installing plugin...${NC}"
    
    BINARY_NAME="packer-plugin-hpc${EXT}"
    BINARY_PATH="${SCRIPT_DIR}/${BINARY_NAME}"
    
    if [[ ! -f "$BINARY_PATH" ]]; then
        echo -e "  ${RED}✗${NC} Binary not found: ${BINARY_PATH}"
        echo -e "    ${GRAY}Run without --install-only to build first${NC}"
        exit 1
    fi
    
    # Build install command
    INSTALL_CMD="packer plugins install"
    if [[ "$FORCE" == "true" ]]; then
        INSTALL_CMD="${INSTALL_CMD} --force"
    fi
    INSTALL_CMD="${INSTALL_CMD} --path ${BINARY_PATH} github.com/MKGAURAB/hpc"
    
    echo -e "  ${GRAY}Running: ${INSTALL_CMD}${NC}"
    
    eval "$INSTALL_CMD"
    
    echo -e "  ${GREEN}✓${NC} Plugin installed successfully!"
    echo ""
fi

# Verify installation
echo -e "${YELLOW}Verifying installation...${NC}"

PLUGIN_DIRS=(
    "$HOME/.packer.d/plugins/github.com/MKGAURAB/hpc"
    "$HOME/.config/packer/plugins/github.com/MKGAURAB/hpc"
)

FOUND=false
for dir in "${PLUGIN_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        PLUGINS=$(ls -1 "$dir" 2>/dev/null | grep "packer-plugin-hpc" || true)
        if [[ -n "$PLUGINS" ]]; then
            echo -e "  ${GREEN}✓${NC} Found in: ${dir}"
            echo "$PLUGINS" | while read -r p; do
                echo -e "    ${GRAY}- ${p}${NC}"
            done
            FOUND=true
            break
        fi
    fi
done

if [[ "$FOUND" != "true" ]]; then
    echo -e "  ${YELLOW}⚠${NC} Plugin not found in expected locations"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Usage in Packer templates:${NC}"
echo ""
echo '  packer {'
echo '    required_plugins {'
echo '      hpc = {'
echo '        version = ">= 1.0.0"'
echo '        source  = "github.com/MKGAURAB/hpc"'
echo '      }'
echo '    }'
echo '  }'
echo ""
echo '  provisioner "hpc-package-manager" {'
echo '    update   = true'
echo '    packages = ["git", "curl"]'
echo '  }'
echo ""
echo -e "${YELLOW}Test with:${NC}"
echo -e "  ${GRAY}packer validate test/test-plugin.pkr.hcl${NC}"
echo ""
