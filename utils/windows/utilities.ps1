# utilities.ps1
# Windows equivalent of utils/utilities.sh
# Provides helper functions: Get-ComponentConfig, Write-ComponentVersion, Download-AndVerify

############################################################################
# @Brief  : Safely check if a property exists on a PSObject (strict-mode safe)
# @Args   : Object - the object to check, Name - property name
# @RetVal : $true if the property exists, $false otherwise
############################################################################
function Test-Property {
    param($Object, [string]$Name)
    return $null -ne $Object.PSObject.Properties.Item($Name)
}

############################################################################
# @Brief  : Extract component version from the versions.json file
# @Args   : ComponentName - name of the component
# @RetVal : PSObject with component configuration
# Lookup hierarchy:
#   1. component.distribution.architecture.<GPU_SKU> (if GPU and SKU are set)
#   2. component.distribution.architecture
#   3. component.common
############################################################################
function Get-ComponentConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComponentName
    )

    # Read versions.json directly from the downloaded repo folder
    $versionsJsonPath = "C:\azhpc-images\versions.json"
    if ($env:TOP_DIR -and (Test-Path (Join-Path $env:TOP_DIR "versions.json"))) {
        $versionsJsonPath = Join-Path $env:TOP_DIR "versions.json"
    }
    $versions = Get-Content $versionsJsonPath -Raw | ConvertFrom-Json

    $distribution = $env:DISTRIBUTION
    $architecture = $env:ARCHITECTURE
    $config = $null

    # Try GPU_SKU-specific configuration first (e.g., nvidia_h100)
    if ($env:GPU -and $env:SKU) {
        $skuKey = "$($env:GPU)_$($env:SKU)".ToLower()
        try {
            $config = $versions.$ComponentName.$distribution.$architecture.$skuKey
        } catch {
            $config = $null
        }
    }

    # Try architecture level
    if (-not $config) {
        try {
            $config = $versions.$ComponentName.$distribution.$architecture
        } catch {
            $config = $null
        }
    }

    # Fall back to common
    if (-not $config) {
        try {
            $config = $versions.$ComponentName.common
        } catch {
            $config = $null
        }
    }

    if (-not $config) {
        Write-Warning "No configuration found for component '$ComponentName' (distribution=$distribution, architecture=$architecture)"
    }

    return $config
}

############################################################################
# @Brief  : Write the component and its version to the tracking file
# @Args   : ComponentName, Version
############################################################################
function Write-ComponentVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComponentName,

        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    $installDir = "C:\AzureHPC"
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    $componentVersionsFile = Join-Path $installDir "component_versions.json"

    if (Test-Path $componentVersionsFile) {
        $existingVersions = Get-Content $componentVersionsFile -Raw | ConvertFrom-Json
        $existingVersions | Add-Member -NotePropertyName $ComponentName -NotePropertyValue $Version -Force
    } else {
        $existingVersions = [PSCustomObject]@{
            $ComponentName = $Version
        }
    }

    $existingVersions | ConvertTo-Json -Depth 10 | Out-File $componentVersionsFile -Encoding UTF8
    Write-Host "Recorded component version: $ComponentName = $Version"
}

############################################################################
# @Brief  : Download a file and verify its SHA256 checksum
# @Args   : Url, ExpectedSha256, [DestinationPath]
############################################################################
function Download-AndVerify {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $false)]
        [string]$ExpectedSha256,

        [Parameter(Mandatory = $false)]
        [string]$DestinationPath
    )

    $fileName = [System.IO.Path]::GetFileName($Url)
    if ($DestinationPath) {
        if (-not (Test-Path $DestinationPath)) {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        }
        $filePath = Join-Path $DestinationPath $fileName
    } else {
        $filePath = Join-Path (Get-Location) $fileName
    }

    Write-Host "Downloading $Url ..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $maxRetries = 3
    $retryDelay = 5
    for ($i = 1; $i -le $maxRetries; $i++) {
        try {
            $ProgressPreference = "SilentlyContinue"
            Invoke-WebRequest -Uri $Url -OutFile $filePath -UseBasicParsing
            break
        } catch {
            if ($i -eq $maxRetries) {
                throw "Failed to download $Url after $maxRetries attempts: $_"
            }
            Write-Warning "Download attempt $i failed, retrying in $retryDelay seconds..."
            Start-Sleep -Seconds $retryDelay
        }
    }

    # Verify checksum if provided
    if ($ExpectedSha256) {
        $actualHash = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash.ToLower()
        $expectedHash = $ExpectedSha256.ToLower()

        if ($actualHash -ne $expectedHash) {
            Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
            throw "Checksum verification failed for $fileName. Expected: $expectedHash, Got: $actualHash"
        }
        Write-Host "Checksum verified for $fileName"
    }

    $fileSize = [math]::Round((Get-Item $filePath).Length / 1MB, 2)
    Write-Host "Downloaded: $fileName ($fileSize MB)"

    return $filePath
}
