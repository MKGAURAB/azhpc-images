packer {
  required_plugins {
    hpc = {
      version = ">= 1.0.0"
      source  = "github.com/MKGAURAB/hpc"
    }
  }
}

# ============================================================================
# Variables - Set these via environment variables or command line
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

variable "image_publisher" {
  type        = string
  description = "Base image publisher"
  default     = "Canonical"
}

variable "image_offer" {
  type        = string
  description = "Base image offer"
  default     = "0001-com-ubuntu-server-jammy"
}

variable "image_sku" {
  type        = string
  description = "Base image SKU"
  default     = "22_04-lts-gen2"
}

variable "managed_image_name" {
  type        = string
  description = "Name for the output managed image"
  default     = "hpc-ubuntu-2204"
}

# ============================================================================
# Azure ARM Source
# ============================================================================

source "azure-arm" "ubuntu" {
  # Authentication - Use Azure CLI
  use_azure_cli_auth = true
  subscription_id    = var.subscription_id

  # Build VM configuration
  location = var.location
  vm_size  = var.vm_size

  # Source image
  image_publisher = var.image_publisher
  image_offer     = var.image_offer
  image_sku       = var.image_sku

  # OS configuration
  os_type         = "Linux"
  os_disk_size_gb = 30

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
  sources = ["source.azure-arm.ubuntu"]

  # Update packages and install HPC dependencies using the plugin
  provisioner "hpc-package-manager" {
    update   = true
    upgrade  = false
    packages = [
      "git",
      "curl",
      "wget",
      "make",
      "gcc",
      "g++",
      "python3",
      "python3-venv"
    ]
    clean_cache = true
    verify      = true
  }

  # Deprovision the VM (required for Azure images)
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
    inline_shebang = "/bin/sh -x"
  }
}
