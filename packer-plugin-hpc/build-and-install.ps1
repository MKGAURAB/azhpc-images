#!/usr/bin/env pwsh
# build-and-install.ps1
# Cross-platform script to build and install the Packer HPC plugin
# Works on Windows, Linux, and macOS with PowerShell Core

param(
    [switch]$BuildOnly,
    [switch]$InstallOnly,
    [switch]$Force,
    [string]$Version = "1.0.0",
    [string]$VersionPrerelease = "dev"
)

$ErrorActionPreference = "Stop"

# Detect OS and architecture
function Get-Platform {
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        return @{ OS = "windows"; Arch = "amd64"; Ext = ".exe" }
    } elseif ($IsLinux) {
        $arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq "Arm64") { "arm64" } else { "amd64" }
        return @{ OS = "linux"; Arch = $arch; Ext = "" }
    } elseif ($IsMacOS) {
        $arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq "Arm64") { "arm64" } else { "amd64" }
        return @{ OS = "darwin"; Arch = $arch; Ext = "" }
    } else {
        # Fallback detection for older PowerShell
        if ($env:OS -eq "Windows_NT") {
            return @{ OS = "windows"; Arch = "amd64"; Ext = ".exe" }
        } else {
            return @{ OS = "linux"; Arch = "amd64"; Ext = "" }
        }
    }
}

# Get script directory
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not $ScriptDir) {
    $ScriptDir = Get-Location
}

# Detect platform
$Platform = Get-Platform
$GOOS = $Platform.OS
$GOARCH = $Platform.Arch
$EXT = $Platform.Ext

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Packer Plugin HPC - Build & Install Script" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Platform:    $GOOS/$GOARCH" -ForegroundColor Gray
Write-Host "Version:     $Version$(if ($VersionPrerelease) { "-$VersionPrerelease" })" -ForegroundColor Gray
Write-Host "Directory:   $ScriptDir" -ForegroundColor Gray
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# Check Go
try {
    $goVersion = go version 2>&1
    Write-Host "  ✓ Go: $($goVersion -replace 'go version ','')" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Go not found. Please install Go from https://go.dev/dl/" -ForegroundColor Red
    exit 1
}

# Check Packer
try {
    $packerVersion = packer version 2>&1 | Select-Object -First 1
    Write-Host "  ✓ Packer: $packerVersion" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Packer not found. Please install Packer from https://developer.hashicorp.com/packer/downloads" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Build plugin
if (-not $InstallOnly) {
    Write-Host "Building plugin..." -ForegroundColor Yellow
    
    Push-Location $ScriptDir
    try {
        # Set environment variables for cross-compilation
        $env:GOOS = $GOOS
        $env:GOARCH = $GOARCH
        $env:CGO_ENABLED = "0"
        
        # Generate HCL2 specs (required when Config struct changes)
        Write-Host "  Running: go generate ./..." -ForegroundColor Gray
        go generate ./...
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ⚠ go generate had warnings (continuing...)" -ForegroundColor Yellow
        }
        
        # Binary name
        $BinaryName = "packer-plugin-hpc$EXT"
        
        # Build command
        $ldflags = "-X github.com/MKGAURAB/packer-plugin-hpc/version.Version=$Version"
        if ($VersionPrerelease) {
            $ldflags += " -X github.com/MKGAURAB/packer-plugin-hpc/version.VersionPrerelease=$VersionPrerelease"
        }
        
        Write-Host "  Running: go build -ldflags=`"$ldflags`" -o $BinaryName" -ForegroundColor Gray
        
        go build -ldflags="$ldflags" -o $BinaryName
        
        if ($LASTEXITCODE -ne 0) {
            throw "Build failed with exit code $LASTEXITCODE"
        }
        
        # Verify binary
        if (Test-Path $BinaryName) {
            $size = [math]::Round((Get-Item $BinaryName).Length / 1MB, 2)
            Write-Host "  ✓ Built: $BinaryName ($size MB)" -ForegroundColor Green
            
            # Test describe
            $describeOutput = & "./$BinaryName" describe 2>&1 | ConvertFrom-Json
            Write-Host "  ✓ Plugin version: $($describeOutput.version)" -ForegroundColor Green
            Write-Host "  ✓ Provisioners: $($describeOutput.provisioners -join ', ')" -ForegroundColor Green
        } else {
            throw "Binary not found after build"
        }
    } finally {
        Pop-Location
    }
    
    Write-Host ""
}

# Install plugin
if (-not $BuildOnly) {
    Write-Host "Installing plugin..." -ForegroundColor Yellow
    
    $BinaryName = "packer-plugin-hpc$EXT"
    $BinaryPath = Join-Path $ScriptDir $BinaryName
    
    if (-not (Test-Path $BinaryPath)) {
        Write-Host "  ✗ Binary not found: $BinaryPath" -ForegroundColor Red
        Write-Host "    Run without -InstallOnly to build first" -ForegroundColor Gray
        exit 1
    }
    
    # Install command
    $installArgs = @("plugins", "install")
    if ($Force) {
        $installArgs += "--force"
    }
    $installArgs += "--path"
    $installArgs += $BinaryPath
    $installArgs += "github.com/MKGAURAB/hpc"
    
    Write-Host "  Running: packer $($installArgs -join ' ')" -ForegroundColor Gray
    
    & packer @installArgs
    
    if ($LASTEXITCODE -ne 0) {
        throw "Installation failed with exit code $LASTEXITCODE"
    }
    
    Write-Host "  ✓ Plugin installed successfully!" -ForegroundColor Green
    Write-Host ""
}

# Verify installation
Write-Host "Verifying installation..." -ForegroundColor Yellow

$pluginDirs = @()
if ($GOOS -eq "windows") {
    $pluginDirs += "$env:APPDATA\packer.d\plugins\github.com\MKGAURAB\hpc"
    $pluginDirs += "$env:USERPROFILE\.packer.d\plugins\github.com\MKGAURAB\hpc"
} else {
    $pluginDirs += "$HOME/.packer.d/plugins/github.com/MKGAURAB/hpc"
    $pluginDirs += "$HOME/.config/packer/plugins/github.com/MKGAURAB/hpc"
}

$found = $false
foreach ($dir in $pluginDirs) {
    if (Test-Path $dir) {
        $plugins = Get-ChildItem $dir -Filter "packer-plugin-hpc*" -ErrorAction SilentlyContinue
        if ($plugins) {
            Write-Host "  ✓ Found in: $dir" -ForegroundColor Green
            foreach ($p in $plugins) {
                Write-Host "    - $($p.Name)" -ForegroundColor Gray
            }
            $found = $true
            break
        }
    }
}

if (-not $found) {
    Write-Host "  ⚠ Plugin not found in expected locations" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Usage in Packer templates:" -ForegroundColor Yellow
Write-Host ""
Write-Host '  packer {' -ForegroundColor White
Write-Host '    required_plugins {' -ForegroundColor White
Write-Host '      hpc = {' -ForegroundColor White
Write-Host '        version = ">= 1.0.0"' -ForegroundColor White
Write-Host '        source  = "github.com/MKGAURAB/hpc"' -ForegroundColor White
Write-Host '      }' -ForegroundColor White
Write-Host '    }' -ForegroundColor White
Write-Host '  }' -ForegroundColor White
Write-Host ""
Write-Host '  provisioner "hpc-package-manager" {' -ForegroundColor White
Write-Host '    update   = true' -ForegroundColor White
Write-Host '    packages = ["git", "curl"]' -ForegroundColor White
Write-Host '  }' -ForegroundColor White
Write-Host ""
Write-Host "Test with:" -ForegroundColor Yellow
Write-Host "  packer validate test/test-plugin.pkr.hcl" -ForegroundColor Gray
Write-Host ""
