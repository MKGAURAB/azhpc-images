# install_utils.ps1
# Windows equivalent of distros/<distro>/install_utils.sh
# Installs prerequisite tools and utilities on the Windows VM

$ErrorActionPreference = "Stop"

Write-Host "=== Installing Windows Prerequisites ==="

# Source utilities
. "$PSScriptRoot\..\..\utils\windows\utilities.ps1"

# Create standard directories
$directories = @(
    "C:\AzureHPC",
    "C:\AzureHPC\logs",
    "C:\AzureHPC\diagnostics"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "Created directory: $dir"
    }
}

# Record OS information
$osInfo = Get-CimInstance Win32_OperatingSystem
Write-Host "OS: $($osInfo.Caption)"
Write-Host "Build: $($osInfo.BuildNumber)"
Write-Host "Architecture: $env:PROCESSOR_ARCHITECTURE"

Write-Host "=== Prerequisites installation complete ==="
