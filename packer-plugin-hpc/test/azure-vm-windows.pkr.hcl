packer {
  required_plugins {
    hpc = {
      version = ">= 1.0.0"
      source  = "github.com/MKGAURAB/hpc"
    }
  }
}

# ============================================================================
# Variables
# ============================================================================

variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
  default     = env("ARM_SUBSCRIPTION_ID")
}

variable "location" {
  type        = string
  description = "Azure region for the VM"
  default     = "westus2"
}

variable "resource_group" {
  type        = string
  description = "Resource group for the build VM"
  default     = "packer-plugin-hpc-test-rg"
}

variable "vm_size" {
  type        = string
  description = "Azure VM size"
  default     = "Standard_B2s"
}

variable "managed_image_name" {
  type        = string
  description = "Name for the output managed image"
  default     = "hpc-windows-2022"
}

# ============================================================================
# Azure ARM Source - Windows Server 2022
# ============================================================================

source "azure-arm" "windows" {
  # Authentication - Use Azure CLI
  use_azure_cli_auth = true
  subscription_id    = var.subscription_id

  # Build VM configuration
  location = var.location
  vm_size  = var.vm_size

  # Source image - Windows Server 2022
  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  image_sku       = "2022-datacenter-g2"

  # OS configuration
  os_type         = "Windows"
  os_disk_size_gb = 128

  # WinRM communicator
  communicator   = "winrm"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_timeout  = "30m"
  winrm_username = "packer"

  # Output image
  managed_image_resource_group_name = var.resource_group
  managed_image_name                = var.managed_image_name

  # Build settings
  azure_tags = {
    Owner    = "mogaurab"
    purpose  = "hpc-image"
    built_by = "packer"
  }
}

# ============================================================================
# Build
# ============================================================================

build {
  sources = ["source.azure-arm.windows"]

  # Use HPC package-manager provisioner
  # Chocolatey is auto-installed if not present on Windows
  provisioner "hpc-package-manager" {
    update   = true
    packages = [
      "git",
      "curl",
      "wget",
      "7zip",
      "notepadplusplus"
    ]
    clean_cache = false
    verify      = true
  }

  # Generalize the image (required for Azure)
  provisioner "powershell" {
    inline = [
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit /mode:vm",
      "while($true) {",
      "  $imageState = (Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State).ImageState",
      "  Write-Host $imageState",
      "  if ($imageState -eq 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { break }",
      "  Start-Sleep -s 5",
      "}"
    ]
  }
}
