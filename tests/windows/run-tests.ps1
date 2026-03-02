# run-tests.ps1
# Windows equivalent of tests/run-tests.sh
# Top-level test runner for Windows Server HPC image validation
#
# Usage:
#   .\run-tests.ps1
#   .\run-tests.ps1 -GpuPlatform NVIDIA
#   .\run-tests.ps1 -GpuPlatform NVIDIA -DebugMode

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("NVIDIA")]
    [string]$GpuPlatform = "NVIDIA",

    [Parameter(Mandatory = $false)]
    [switch]$DebugMode
)

$ErrorActionPreference = "Stop"

Write-Host "============================================="
Write-Host "  Windows HPC Image Test Suite"
Write-Host "  GPU Platform: $GpuPlatform"
Write-Host "============================================="

# Set debug mode
if ($DebugMode) {
    $env:HPC_DEBUG = "true"
    Write-Host "Debug mode: ON (tests will continue on failure)"
} else {
    $env:HPC_DEBUG = $null
}

# Determine script directory
$HPC_ENV = "C:\AzureHPC"
$testDir = $PSScriptRoot

# Source test definitions
. "$testDir\test-definitions.ps1"

# ============================================
# Detect VM properties
# ============================================
Write-Host "`n--- Detecting VM properties ---"

# Get VM size from IMDS
try {
    $metadataEndpoint = "http://169.254.169.254/metadata/instance?api-version=2019-06-04"
    $metadata = Invoke-RestMethod -Uri $metadataEndpoint -Headers @{ "Metadata" = "true" } -Method Get -TimeoutSec 10
    $vmSize = $metadata.compute.vmSize.ToLower()
    Write-Host "VM Size: $vmSize"
} catch {
    $vmSize = "unknown"
    Write-Warning "Could not retrieve VM size from IMDS: $_"
}

# Detect Windows version
$osBuild = [System.Environment]::OSVersion.Version
if ($osBuild.Build -ge 26100) {
    $distribution = "windows_2025"
} elseif ($osBuild.Build -ge 20348) {
    $distribution = "windows_2022"
} else {
    $distribution = "unknown"
}
Write-Host "Distribution: $distribution"

# ============================================
# Load test matrix
# ============================================
Write-Host "`n--- Loading test matrix ---"
$testMatrixFile = Join-Path $testDir "test-matrix_NVIDIA_windows.json"

if (-not (Test-Path $testMatrixFile)) {
    throw "Test matrix file not found: $testMatrixFile"
}

$testMatrixAll = Get-Content $testMatrixFile -Raw | ConvertFrom-Json

# Get tests for this distribution
$testMatrix = $testMatrixAll.$distribution
if (-not $testMatrix) {
    Write-Warning "No test matrix found for distribution '$distribution', trying 'common'"
    $testMatrix = $testMatrixAll.windows_2022  # fallback
}

# Get the variant (common vs sku-specific)
$variant = "common"
$matrixData = $testMatrix.$variant
if (-not $matrixData) {
    throw "No test matrix found for variant '$variant' in distribution '$distribution'"
}

$components = $matrixData.components

Write-Host "Components to test: $($components -join ', ')"

# ============================================
# Load component versions
# ============================================
$componentVersionsFile = Join-Path $HPC_ENV "component_versions.json"
if (Test-Path $componentVersionsFile) {
    $componentVersions = Get-Content $componentVersionsFile -Raw | ConvertFrom-Json
    Write-Host "Component versions loaded from $componentVersionsFile"
} else {
    Write-Warning "Component versions file not found: $componentVersionsFile"
    $componentVersions = $null
}

# ============================================
# Run component tests
# ============================================
Write-Host "`n============================================="
Write-Host "  Running Component Tests"
Write-Host "============================================="

$testsPassed = 0
$testsFailed = 0

foreach ($component in $components) {
    Write-Host "`n>>> Testing: $component"
    try {
        switch ($component) {
            "check_nvidia_driver"         { Verify-NvidiaDriverInstallation }
            "check_nvlink"                { Verify-NvlinkSetup }
            "check_nvidia_driver_package" { Verify-NvidiaDriverPackage }
            "check_component_versions"    { Verify-ComponentVersionsFile }
            default {
                Write-Warning "Unknown component test: $component"
            }
        }
        $testsPassed++
    } catch {
        Write-Host "*** FAILED: $component - $_" -ForegroundColor Red
        $testsFailed++
        if (-not $DebugMode) {
            throw "Test '$component' failed: $_"
        }
    }
}

# ============================================
# Summary
# ============================================
Write-Host "`n============================================="
Write-Host "  Test Summary"
Write-Host "============================================="
Write-Host "Passed: $testsPassed"
Write-Host "Failed: $testsFailed"

if ($script:TestErrors.Count -gt 0) {
    Write-Host "`nErrors encountered:" -ForegroundColor Yellow
    $script:TestErrors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}

if ($testsFailed -eq 0) {
    Write-Host "`nALL OK!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nSOME TESTS FAILED!" -ForegroundColor Red
    exit 1
}
