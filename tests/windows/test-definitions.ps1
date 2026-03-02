# test-definitions.ps1
# Windows equivalent of tests/test-definitions.sh
# Provides verification functions for each installable component

$script:TestErrors = @()

############################################################################
# Helper Functions
############################################################################

function Test-ExitOnError {
    if (-not $env:HPC_DEBUG) {
        throw "Test failed"
    }
}

function Check-Exists {
    param([string]$Path)

    if (Test-Path $Path) {
        Write-Host "[OK] : $Path exists"
        return $true
    } else {
        Write-Host "*** Error - $Path not found!" -ForegroundColor Red
        $script:TestErrors += "Missing: $Path"
        Test-ExitOnError
        return $false
    }
}

function Check-ExitCode {
    param(
        [int]$ExitCode,
        [string]$SuccessMessage,
        [string]$ErrorMessage
    )

    if ($ExitCode -eq 0) {
        Write-Host "[OK] : $SuccessMessage"
    } else {
        Write-Host "*** Error - $ErrorMessage (exit code: $ExitCode)" -ForegroundColor Red
        $script:TestErrors += $ErrorMessage
        Test-ExitOnError
    }
}

############################################################################
# Component Verification Functions
############################################################################

function Verify-NvidiaDriverInstallation {
    Write-Host "`n--- Verifying NVIDIA Driver ---"

    $nvidiaSmi = "C:\Windows\System32\nvidia-smi.exe"
    Check-Exists $nvidiaSmi

    if (Test-Path $nvidiaSmi) {
        try {
            $output = & $nvidiaSmi 2>&1
            $exitCode = $LASTEXITCODE
            Check-ExitCode -ExitCode $exitCode -SuccessMessage "nvidia-smi executed successfully" -ErrorMessage "nvidia-smi failed"

            # Extract driver version
            $driverVersion = (& $nvidiaSmi --query-gpu=driver_version --format=csv,noheader 2>$null | Select-Object -First 1).Trim()
            if ($driverVersion) {
                Write-Host "[OK] : NVIDIA Driver version: $driverVersion"

                # Verify against component_versions.json
                $componentVersionsFile = "C:\AzureHPC\component_versions.json"
                if (Test-Path $componentVersionsFile) {
                    $versions = Get-Content $componentVersionsFile -Raw | ConvertFrom-Json
                    if ($versions.NVIDIA -and $driverVersion -like "$($versions.NVIDIA)*") {
                        Write-Host "[OK] : Driver version matches recorded version ($($versions.NVIDIA))"
                    } else {
                        Write-Warning "Driver version mismatch: running=$driverVersion, recorded=$($versions.NVIDIA)"
                    }
                }
            }

            # Check GPU count
            $gpuCount = (& $nvidiaSmi --query-gpu=count --format=csv,noheader 2>$null | Select-Object -First 1).Trim()
            Write-Host "[OK] : GPU count: $gpuCount"

            # Check GPU name
            $gpuName = (& $nvidiaSmi --query-gpu=name --format=csv,noheader 2>$null | Select-Object -First 1).Trim()
            Write-Host "[OK] : GPU name: $gpuName"

            # Check GPU memory
            $gpuMemory = (& $nvidiaSmi --query-gpu=memory.total --format=csv,noheader 2>$null | Select-Object -First 1).Trim()
            Write-Host "[OK] : GPU memory: $gpuMemory"
        } catch {
            Write-Host "*** Error - nvidia-smi execution failed: $_" -ForegroundColor Red
            $script:TestErrors += "nvidia-smi execution failed"
            Test-ExitOnError
        }
    }
}

function Verify-NvlinkSetup {
    Write-Host "`n--- Verifying NVLink ---"

    $nvidiaSmi = "C:\Windows\System32\nvidia-smi.exe"
    if (Test-Path $nvidiaSmi) {
        try {
            $nvlinkOutput = & $nvidiaSmi nvlink --status 2>&1
            $exitCode = $LASTEXITCODE
            if ($exitCode -eq 0) {
                Write-Host "[OK] : NVLink status check passed"
                $nvlinkOutput | ForEach-Object { Write-Host "  $_" }
            } else {
                Write-Host "[OK] : NVLink not available on this GPU (expected for PCIe GPUs)"
            }
        } catch {
            Write-Host "[OK] : NVLink query skipped (not supported on this SKU)"
        }
    }
}

function Verify-ComponentVersionsFile {
    Write-Host "`n--- Verifying Component Versions File ---"

    $componentVersionsFile = "C:\AzureHPC\component_versions.json"
    if (Check-Exists $componentVersionsFile) {
        try {
            $versions = Get-Content $componentVersionsFile -Raw | ConvertFrom-Json
            Write-Host "[OK] : Component versions file is valid JSON"

            $versions.PSObject.Properties | ForEach-Object {
                Write-Host "  $($_.Name): $($_.Value)"
            }
        } catch {
            Write-Host "*** Error - Component versions file is invalid: $_" -ForegroundColor Red
            $script:TestErrors += "Invalid component_versions.json"
            Test-ExitOnError
        }
    }
}

function Verify-NvidiaDriverPackage {
    Write-Host "`n--- Verifying NVIDIA Driver Package (pnputil) ---"

    try {
        $drivers = pnputil /enum-drivers 2>&1
        $nvidiaDrivers = ($drivers | Out-String) -split "Published Name" |
            Where-Object { $_ -match "NVIDIA" -or $_ -match "nvidia" }

        if ($nvidiaDrivers.Count -gt 0) {
            Write-Host "[OK] : NVIDIA driver package(s) found in driver store"
            foreach ($drv in $nvidiaDrivers) {
                $lines = $drv -split "`n" | Where-Object { $_.Trim() }
                foreach ($line in $lines) {
                    Write-Host "  $($line.Trim())"
                }
            }
        } else {
            Write-Host "*** Error - No NVIDIA driver package found in driver store" -ForegroundColor Red
            $script:TestErrors += "No NVIDIA driver package in driver store"
            Test-ExitOnError
        }

        # Also list all third-party drivers for diagnostics
        $allOem = ($drivers | Out-String) -split "Published Name" |
            Where-Object { $_ -match "oem" }
        Write-Host "`n  Total third-party driver packages: $($allOem.Count)"
    } catch {
        Write-Host "*** Error - pnputil enumeration failed: $_" -ForegroundColor Red
        $script:TestErrors += "pnputil enumeration failed"
        Test-ExitOnError
    }
}
