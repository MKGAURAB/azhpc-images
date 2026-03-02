# clear_history.ps1
# Windows equivalent of utils/clear_history.sh
# Prepares the VM for Sysprep generalization

$ErrorActionPreference = "Stop"

Write-Host "=== Windows Image Cleanup and Sysprep Preparation ==="

# Clean Panther directory (Sysprep logs)
$pantherPath = "$env:SystemRoot\Panther"
if (Test-Path $pantherPath) {
    Write-Host "Cleaning Panther directory..."
    Remove-Item -Path "$pantherPath\*" -Recurse -Force -ErrorAction SilentlyContinue
}

# Clean Windows Temp directories
$tempPaths = @(
    "$env:SystemRoot\Temp",
    "$env:TEMP",
    "$env:LOCALAPPDATA\Temp"
)

foreach ($tempPath in $tempPaths) {
    if (Test-Path $tempPath) {
        Write-Host "Cleaning temp directory: $tempPath"
        Remove-Item -Path "$tempPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Clean Windows Update cache
$wuCachePath = "$env:SystemRoot\SoftwareDistribution\Download"
if (Test-Path $wuCachePath) {
    Write-Host "Cleaning Windows Update cache..."
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$wuCachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
}

# Clean NVIDIA installer temp files
$nvidiaTempPaths = @(
    "C:\NVIDIA",
    "C:\Temp\NvidiaDriver"
)

foreach ($nvPath in $nvidiaTempPaths) {
    if (Test-Path $nvPath) {
        Write-Host "Cleaning NVIDIA temp: $nvPath"
        Remove-Item -Path $nvPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Clear event logs
Write-Host "Clearing event logs..."
Get-WinEvent -ListLog * -Force -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($_.LogName)
    } catch {
        # Some logs cannot be cleared - this is expected
    }
}

# Remove WinRM HTTPS listener and certificates (if present)
Write-Host "Cleaning WinRM configuration..."
try {
    $winrmListeners = Get-ChildItem WSMan:\localhost\Listener -ErrorAction SilentlyContinue
    foreach ($listener in $winrmListeners) {
        $transport = ($listener | Get-ChildItem | Where-Object { $_.Name -eq "Transport" }).Value
        if ($transport -eq "HTTPS") {
            $certThumbprint = ($listener | Get-ChildItem | Where-Object { $_.Name -eq "CertificateThumbprint" }).Value
            # Remove the certificate
            if ($certThumbprint) {
                Remove-Item -Path "Cert:\LocalMachine\My\$certThumbprint" -Force -ErrorAction SilentlyContinue
            }
            # Remove the HTTPS listener
            Remove-Item -Path "WSMan:\localhost\Listener\$($listener.Name)" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
} catch {
    Write-Warning "WinRM cleanup encountered issues: $_"
}

# Clean user profiles temp data
Write-Host "Cleaning user temp data..."
$userProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
foreach ($profile in $userProfiles) {
    $userTemp = Join-Path $profile.FullName "AppData\Local\Temp"
    if (Test-Path $userTemp) {
        Remove-Item -Path "$userTemp\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Remove installer cache files
$installerCachePaths = @(
    "$env:SystemRoot\Installer\$PatchCache$",
    "C:\ProgramData\Package Cache"
)

foreach ($cachePath in $installerCachePaths) {
    if (Test-Path $cachePath) {
        Write-Host "Cleaning cache: $cachePath"
        # Only clean selectively to avoid breaking installed software
    }
}

# Defragment and optimize the disk
Write-Host "Optimizing disk..."
try {
    Optimize-Volume -DriveLetter C -Defrag -ErrorAction SilentlyContinue
} catch {
    Write-Warning "Disk optimization skipped: $_"
}

Write-Host "=== Cleanup complete ==="
Write-Host "VM is ready for Sysprep generalization."
Write-Host ""
Write-Host "To generalize, run:"
Write-Host "  C:\Windows\System32\Sysprep\sysprep.exe /oobe /quiet /generalize /shutdown"
