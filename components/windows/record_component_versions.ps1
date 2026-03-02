# record_component_versions.ps1
# Records final component versions and system information
# Windows equivalent of the write_component_version pattern used across Linux scripts

$ErrorActionPreference = "Stop"

# Source utilities
. "$PSScriptRoot\..\..\utils\windows\utilities.ps1"

Write-Host "=== Recording Final Component Versions ==="

# Record OS information
$osInfo = Get-CimInstance Win32_OperatingSystem
Write-ComponentVersion -ComponentName "OS" -Version $osInfo.Caption
Write-ComponentVersion -ComponentName "OSVersion" -Version $osInfo.Version
Write-ComponentVersion -ComponentName "BuildDate" -Version (Get-Date -Format "yyyy-MM-dd")

# Record GPU SKU if set
if ($env:SKU) {
    Write-ComponentVersion -ComponentName "GPU_SKU" -Version $env:SKU
}

# Record NVIDIA driver version from nvidia-smi (runtime verification)
$nvidiaSmi = "C:\Windows\System32\nvidia-smi.exe"
if (Test-Path $nvidiaSmi) {
    try {
        $driverVersion = (& $nvidiaSmi --query-gpu=driver_version --format=csv,noheader 2>$null | Select-Object -First 1).Trim()
        if ($driverVersion) {
            Write-ComponentVersion -ComponentName "NVIDIA_RUNTIME" -Version $driverVersion
        }

        # Record GPU name
        $gpuName = (& $nvidiaSmi --query-gpu=name --format=csv,noheader 2>$null | Select-Object -First 1).Trim()
        if ($gpuName) {
            Write-ComponentVersion -ComponentName "GPU_NAME" -Version $gpuName
        }

        # Record GPU count
        $gpuCount = (& $nvidiaSmi --query-gpu=count --format=csv,noheader 2>$null | Select-Object -First 1).Trim()
        if ($gpuCount) {
            Write-ComponentVersion -ComponentName "GPU_COUNT" -Version $gpuCount
        }
    } catch {
        Write-Warning "Could not query nvidia-smi for runtime GPU info"
    }
}

# Display final component versions
$componentVersionsFile = "C:\AzureHPC\component_versions.json"
if (Test-Path $componentVersionsFile) {
    Write-Host "`nFinal component versions:"
    Get-Content $componentVersionsFile | Write-Host
}

Write-Host "`n=== Component version recording complete ==="
