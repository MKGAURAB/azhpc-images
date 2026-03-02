# install_nvidiagpudriver.ps1
# Windows equivalent of components/install_nvidiagpudriver.sh
# Downloads and installs the NVIDIA Tesla/Data Center GPU driver

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Source utilities
. "$PSScriptRoot\..\..\utils\windows\utilities.ps1"

Write-Host "=== Installing NVIDIA GPU Driver (Windows) ==="

# Get driver configuration from versions.json
$nvidiaConfig = Get-ComponentConfig -ComponentName "nvidia"
if (-not $nvidiaConfig) {
    throw "No NVIDIA configuration found in versions.json for $env:DISTRIBUTION/$env:ARCHITECTURE"
}

$driverConfig = $nvidiaConfig.driver
$NVIDIA_DRIVER_VERSION = $driverConfig.version

if (-not $NVIDIA_DRIVER_VERSION) {
    throw "NVIDIA driver version not found in versions.json"
}

Write-Host "NVIDIA Driver Version: $NVIDIA_DRIVER_VERSION"

# Construct download URL for Windows Server DCH driver
# Format: https://us.download.nvidia.com/tesla/{version}/{version}-data-center-tesla-desktop-winserver-2022-2025-dch-international.exe
if (Test-Property $driverConfig 'url') {
    $driverUrl = $driverConfig.url
} else {
    $driverUrl = "https://us.download.nvidia.com/tesla/$NVIDIA_DRIVER_VERSION/$NVIDIA_DRIVER_VERSION-data-center-tesla-desktop-winserver-2022-2025-dch-international.exe"
}

$tempDir = "C:\Temp\NvidiaDriver"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$driverPath = Join-Path $tempDir "nvidia-driver.exe"

# Download driver
Write-Host "Downloading from $driverUrl"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$maxRetries = 3
for ($i = 1; $i -le $maxRetries; $i++) {
    try {
        (New-Object System.Net.WebClient).DownloadFile($driverUrl, $driverPath)
        break
    } catch {
        if ($i -eq $maxRetries) { throw "Failed to download NVIDIA driver after $maxRetries attempts: $_" }
        Write-Warning "Download attempt $i failed, retrying..."
        Start-Sleep -Seconds 5
    }
}

# Verify download
$fileSize = [math]::Round((Get-Item $driverPath).Length / 1MB, 2)
Write-Host "Downloaded: $fileSize MB"
if ($fileSize -lt 100) {
    throw "Download failed - file too small ($fileSize MB)"
}

# Verify SHA256 if available
if (Test-Property $driverConfig 'sha256') {
    $actualHash = (Get-FileHash -Path $driverPath -Algorithm SHA256).Hash.ToLower()
    $expectedHash = $driverConfig.sha256.ToLower()
    if ($actualHash -ne $expectedHash) {
        Remove-Item -Path $driverPath -Force
        throw "Driver checksum mismatch. Expected: $expectedHash, Got: $actualHash"
    }
    Write-Host "Checksum verified"
}

# Install driver silently
# Common successful exit codes:
#   0 = Success
#   1 = Success with reboot required (NVIDIA standard)
#   3010 = Success with reboot required (Windows installer standard)
Write-Host "Installing NVIDIA driver v$NVIDIA_DRIVER_VERSION (silent mode)..."
$process = Start-Process -FilePath $driverPath -ArgumentList "-s", "-noreboot", "Display.Driver" -Wait -PassThru
$exitCode = $process.ExitCode
Write-Host "Installation exit code: $exitCode (0x$([Convert]::ToString($exitCode, 16)))"

$successExitCodes = @(0, 1, 3010)
if ($exitCode -notin $successExitCodes) {
    throw "NVIDIA driver installation failed with exit code: $exitCode (0x$([Convert]::ToString($exitCode, 16)))"
}

# Cleanup
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# Record version
Write-ComponentVersion -ComponentName "NVIDIA" -Version $NVIDIA_DRIVER_VERSION

Write-Host "=== NVIDIA GPU Driver installation complete ==="

# Return exit code if reboot required
if ($exitCode -in @(1, 3010)) {
    Write-Host "NOTE: A reboot is required to complete driver installation."
}
