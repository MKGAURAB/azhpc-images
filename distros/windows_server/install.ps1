# install.ps1
# Windows equivalent of distros/<distro>/install.sh
# Top-level orchestrator for Windows Server HPC image build
# Usage: .\install.ps1 -Gpu NVIDIA -Sku H100

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("NVIDIA")]
    [string]$Gpu,

    [Parameter(Mandatory = $true)]
    [string]$Sku
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "============================================="
Write-Host "  Windows Server HPC Image Build"
Write-Host "  GPU: $Gpu | SKU: $Sku"
Write-Host "============================================="

# Set GPU and SKU environment variables (used by Get-ComponentConfig)
$env:GPU = $Gpu
$env:SKU = $Sku

# Source set_properties to initialize paths and load versions.json
. "$PSScriptRoot\..\..\utils\windows\set_properties.ps1"

# Source utilities for helper functions
. "$PSScriptRoot\..\..\utils\windows\utilities.ps1"

# ============================================
# Step 1: Install prerequisites and utilities
# ============================================
Write-Host "`n>>> Step 1: Installing prerequisites..."
& "$PSScriptRoot\install_utils.ps1"

# ============================================
# Step 2: Install NVIDIA GPU Driver
# ============================================
if ($Gpu -eq "NVIDIA") {
    Write-Host "`n>>> Step 2: Installing NVIDIA GPU Driver..."
    & "$env:COMPONENT_DIR\install_nvidiagpudriver.ps1"
}

# Note: Fabric Manager is NOT supported on Windows - it's a Linux-only component
# NC H100 v5 series VMs are PCIe-based and do NOT require Fabric Manager
# NVSwitch-based systems (DGX/HGX) that need Fabric Manager only support Linux

# ============================================
# Step 3: Record final component versions
# ============================================
Write-Host "`n>>> Step 3: Recording component versions..."
& "$env:COMPONENT_DIR\record_component_versions.ps1"

# ============================================
# Cleanup temporary files
# ============================================
Write-Host "`n>>> Cleanup: Removing temporary files..."
$cleanupPaths = @(
    "C:\Temp",
    "$env:TEMP\nvidia*"
)

foreach ($path in $cleanupPaths) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`n============================================="
Write-Host "  Windows Server HPC Image Build Complete"
Write-Host "============================================="

# Display component versions summary
$componentVersionsFile = "C:\AzureHPC\component_versions.json"
if (Test-Path $componentVersionsFile) {
    Write-Host "`nInstalled component versions:"
    Get-Content $componentVersionsFile | Write-Host
}
