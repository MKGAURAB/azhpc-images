# Azure VM Test Template

This directory contains test templates for the HPC Packer plugin.

## Files

| File | Description |
|------|-------------|
| `test-plugin.pkr.hcl` | Quick validation test (null source) |
| `azure-vm.pkr.hcl` | Full Azure VM image build |

## Quick Validation

Test the plugin configuration without creating resources:

```powershell
packer validate test-plugin.pkr.hcl
```

## Azure VM Build

### Prerequisites

1. **Azure Service Principal** with Contributor access
2. **Resource Group** for storing the managed image

### Authentication

Set environment variables:

```powershell
# PowerShell
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"
$env:ARM_CLIENT_ID = "your-client-id"
$env:ARM_CLIENT_SECRET = "your-client-secret"
$env:ARM_TENANT_ID = "your-tenant-id"
```

```bash
# Bash
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_TENANT_ID="your-tenant-id"
```

Or use Azure CLI authentication (simpler for local testing):

```bash
az login
```

### Validate

```powershell
packer validate azure-vm.pkr.hcl
```

### Build

```powershell
# With default settings
packer build azure-vm.pkr.hcl

# With custom variables
packer build \
  -var "location=westus2" \
  -var "vm_size=Standard_D4s_v3" \
  -var "managed_image_name=my-hpc-image" \
  azure-vm.pkr.hcl
```

### Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `subscription_id` | `ARM_SUBSCRIPTION_ID` env | Azure Subscription ID |
| `client_id` | `ARM_CLIENT_ID` env | Service Principal Client ID |
| `client_secret` | `ARM_CLIENT_SECRET` env | Service Principal Secret |
| `tenant_id` | `ARM_TENANT_ID` env | Azure Tenant ID |
| `location` | `eastus` | Azure region |
| `resource_group` | `packer-rg` | Resource group for output image |
| `vm_size` | `Standard_DS2_v2` | VM size for build |
| `image_publisher` | `Canonical` | Base image publisher |
| `image_offer` | `0001-com-ubuntu-server-jammy` | Base image offer |
| `image_sku` | `22_04-lts-gen2` | Base image SKU |
| `managed_image_name` | `hpc-ubuntu-2204` | Output image name |

## What Gets Installed

The `hpc-package-manager` provisioner installs:

- `git`, `curl`, `wget` - Basic utilities
- `build-essential`, `cmake`, `ninja-build` - Build tools
- `pkg-config`, `libssl-dev`, `libffi-dev` - Development libraries
- `python3-dev`, `python3-pip` - Python development

## Customizing

To add more packages, edit the `packages` list in `azure-vm.pkr.hcl`:

```hcl
provisioner "hpc-package-manager" {
  update   = true
  packages = [
    "git",
    "curl",
    # Add your packages here
    "htop",
    "tmux"
  ]
  clean_cache = true
}
```
