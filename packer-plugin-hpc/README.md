# Packer Plugin HPC

A custom Packer plugin providing provisioners for HPC (High Performance Computing) image building.

## Provisioners

| Provisioner | Description |
|-------------|-------------|
| `hpc-package-manager` | Cross-platform package management (apt/yum/dnf/tdnf) |

## Prerequisites

- **Go** >= 1.21 ([Download](https://go.dev/dl/))
- **Packer** >= 1.10.0 ([Download](https://developer.hashicorp.com/packer/downloads))

## Quick Start

### Build and Install (Recommended)

The easiest way to build and install the plugin is using the provided scripts:

**Windows (PowerShell):**
```powershell
.\build-and-install.ps1
```

**Linux/macOS (Bash):**
```bash
chmod +x build-and-install.sh
./build-and-install.sh
```

### Script Options

| Option | PowerShell | Bash | Description |
|--------|------------|------|-------------|
| Build only | `-BuildOnly` | `--build-only` | Only build, don't install |
| Install only | `-InstallOnly` | `--install-only` | Only install (binary must exist) |
| Force reinstall | `-Force` | `--force` | Force reinstall |
| Set version | `-Version "1.0.0"` | `--version 1.0.0` | Set version |
| Set prerelease | `-VersionPrerelease "dev"` | `--prerelease dev` | Set prerelease suffix |

### Verify Installation

```powershell
packer plugins installed
```

## Usage

### Basic Template

```hcl
packer {
  required_plugins {
    hpc = {
      version = ">= 1.0.0"
      source  = "github.com/MKGAURAB/hpc"
    }
  }
}

source "azure-arm" "ubuntu" {
  # Azure configuration...
}

build {
  sources = ["source.azure-arm.ubuntu"]
  
  provisioner "hpc-package-manager" {
    update   = true
    packages = ["git", "curl", "wget", "build-essential"]
    clean_cache = true
  }
}
```

### Package Manager Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `package_manager` | string | auto-detect | Package manager: `apt`, `yum`, `dnf`, `tdnf` |
| `update` | bool | false | Run package cache update before installing |
| `upgrade` | bool | false | Upgrade all packages after update |
| `packages` | []string | [] | List of packages to install |
| `clean_cache` | bool | false | Clean package cache after installation |

### Test the Plugin

```powershell
packer validate test/test-plugin.pkr.hcl
```

## Development

### Manual Build

```powershell
go build -ldflags="-X github.com/MKGAURAB/packer-plugin-hpc/version.VersionPrerelease=dev" -o packer-plugin-hpc.exe
```

### Regenerating HCL2 Specs

After modifying provisioner configuration structs:

```powershell
go install github.com/hashicorp/packer-plugin-sdk/cmd/packer-sdc@latest
cd provisioner/package-manager
go generate ./...
```

### Important: go-cty Fork

This plugin requires the `nywilken/go-cty` fork for Go 1.21+ compatibility:

```
replace github.com/zclconf/go-cty => github.com/nywilken/go-cty v1.13.3
```

See: [packer-plugin-sdk#187](https://github.com/hashicorp/packer-plugin-sdk/issues/187)

## Troubleshooting

### Plugin Not Found

```powershell
# Re-install with --force
packer plugins install --force --path .\packer-plugin-hpc.exe github.com/MKGAURAB/hpc
```

### Enable Debug Logging

```powershell
$env:PACKER_LOG = "1"
packer validate template.pkr.hcl
```

## Project Structure

```
packer-plugin-hpc/
├── main.go                           # Plugin entry point
├── go.mod / go.sum                   # Go module
├── build-and-install.ps1             # Windows build script
├── build-and-install.sh              # Linux/macOS build script
├── version/
│   └── version.go                    # Version information
├── provisioner/
│   └── package-manager/
│       ├── provisioner.go            # Provisioner implementation
│       └── provisioner.hcl2spec.go   # Generated HCL2 spec
├── test/
│   └── test-plugin.pkr.hcl           # Test template
└── README.md
```

## License

See [LICENSE](../LICENSE) file.
