# set_properties.ps1
# Windows equivalent of utils/set_properties.sh
# Sets up environment variables and loads component versions from versions.json

$ErrorActionPreference = "Stop"

# Set directory paths
$env:TOP_DIR = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$env:COMPONENT_DIR = Join-Path $env:TOP_DIR "components\windows"
$env:TEST_DIR = Join-Path $env:TOP_DIR "tests\windows"
$env:UTILS_DIR = Join-Path $env:TOP_DIR "utils\windows"

# Detect Windows distribution
$osInfo = Get-CimInstance Win32_OperatingSystem
$osBuild = [System.Environment]::OSVersion.Version
if ($osBuild.Build -ge 26100) {
    $env:DISTRIBUTION = "windows_2025"
} elseif ($osBuild.Build -ge 20348) {
    $env:DISTRIBUTION = "windows_2022"
} else {
    Write-Error "Unsupported Windows Server version: $($osInfo.Caption)"
    exit 1
}

$env:ARCHITECTURE = "x86_64"

Write-Host "Distribution: $env:DISTRIBUTION"
Write-Host "Architecture: $env:ARCHITECTURE"
Write-Host "OS: $($osInfo.Caption)"

# Verify versions.json exists
$versionsJsonPath = Join-Path $env:TOP_DIR "versions.json"
if (-not (Test-Path $versionsJsonPath)) {
    Write-Error "versions.json not found at $versionsJsonPath"
    exit 1
}

Write-Host "Verified versions.json at $versionsJsonPath"

# Create AzureHPC directory
$azureHpcPath = "C:\AzureHPC"
if (-not (Test-Path $azureHpcPath)) {
    New-Item -ItemType Directory -Path $azureHpcPath -Force | Out-Null
}
