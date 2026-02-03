// Package packagemanager implements a Packer provisioner for package management.
//
//go:generate packer-sdc mapstructure-to-hcl2 -type Config
package packagemanager

import (
	"bytes"
	"context"
	"fmt"

	"github.com/hashicorp/hcl/v2/hcldec"
	"github.com/hashicorp/packer-plugin-sdk/packer"
	"github.com/hashicorp/packer-plugin-sdk/template/config"
	"github.com/hashicorp/packer-plugin-sdk/template/interpolate"
)

// Config contains the configuration for the provisioner.
type Config struct {
	// PackageManager explicitly sets the package manager to use.
	// If empty, will auto-detect. Valid values: apt, yum, dnf, tdnf, choco, winget
	PackageManager string `mapstructure:"package_manager" required:"false"`

	// Update runs package manager update before installing packages
	Update bool `mapstructure:"update" required:"false"`

	// Upgrade runs package manager upgrade after update
	Upgrade bool `mapstructure:"upgrade" required:"false"`

	// Packages is the list of packages to install
	Packages []string `mapstructure:"packages" required:"false"`

	// CleanCache removes package manager cache after installation
	CleanCache bool `mapstructure:"clean_cache" required:"false"`

	// Verify checks that packages were installed successfully
	Verify bool `mapstructure:"verify" required:"false"`

	ctx interpolate.Context
}

// Provisioner implements the packer.Provisioner interface.
type Provisioner struct {
	config Config
}

// ConfigSpec returns the HCL spec for the provisioner.
func (p *Provisioner) ConfigSpec() hcldec.ObjectSpec {
	return p.config.FlatMapstructure().HCL2Spec()
}

// Prepare validates and processes the configuration.
func (p *Provisioner) Prepare(raws ...interface{}) error {
	err := config.Decode(&p.config, &config.DecodeOpts{
		PluginType:         "packer.provisioner.package-manager",
		Interpolate:        true,
		InterpolateContext: &p.config.ctx,
	}, raws...)
	if err != nil {
		return err
	}

	return nil
}

// Provision executes the provisioner.
func (p *Provisioner) Provision(ctx context.Context, ui packer.Ui, comm packer.Communicator, generatedData map[string]interface{}) error {
	ui.Say("Running package-manager provisioner...")

	// Detect package manager if not set
	manager := p.config.PackageManager
	if manager == "" {
		detected, err := p.detectPackageManager(ui, comm)
		if err != nil {
			return fmt.Errorf("failed to detect package manager: %v", err)
		}
		manager = detected
	}

	// If Windows detected without Chocolatey, install it
	if manager == "choco-install" {
		ui.Say("Windows detected without Chocolatey. Installing Chocolatey...")
		if err := p.installChocolatey(ctx, ui, comm); err != nil {
			return fmt.Errorf("failed to install Chocolatey: %v", err)
		}
		manager = "choco"
		ui.Message("Chocolatey installed successfully")
	} else {
		ui.Message(fmt.Sprintf("Detected package manager: %s", manager))
	}

	// Update package cache
	if p.config.Update {
		ui.Say("Updating package cache...")
		cmd := p.getUpdateCommand(manager)
		if err := p.runCommand(ctx, ui, comm, cmd); err != nil {
			return fmt.Errorf("update failed: %v", err)
		}
	}

	// Upgrade packages
	if p.config.Upgrade {
		ui.Say("Upgrading packages...")
		cmd := p.getUpgradeCommand(manager)
		if err := p.runCommand(ctx, ui, comm, cmd); err != nil {
			return fmt.Errorf("upgrade failed: %v", err)
		}
	}

	// Install packages
	if len(p.config.Packages) > 0 {
		ui.Say(fmt.Sprintf("Installing %d packages...", len(p.config.Packages)))
		cmd := p.getInstallCommand(manager, p.config.Packages)
		if err := p.runCommand(ctx, ui, comm, cmd); err != nil {
			return fmt.Errorf("package installation failed: %v", err)
		}
	}

	// Clean cache
	if p.config.CleanCache {
		ui.Say("Cleaning package cache...")
		cmd := p.getCleanCommand(manager)
		if err := p.runCommand(ctx, ui, comm, cmd); err != nil {
			ui.Message(fmt.Sprintf("Warning: cache cleanup failed: %v", err))
		}
	}

	// Verify packages
	if p.config.Verify && len(p.config.Packages) > 0 {
		ui.Say("Verifying installed packages...")
		if err := p.verifyPackages(ctx, ui, comm, manager); err != nil {
			return fmt.Errorf("package verification failed: %v", err)
		}
	}

	ui.Say("Package-manager provisioner completed successfully!")
	return nil
}

func (p *Provisioner) detectPackageManager(ui packer.Ui, comm packer.Communicator) (string, error) {
	// Try Linux package managers first
	linuxManagers := []struct {
		name string
		cmd  string
	}{
		{"apt", "which apt-get"},
		{"dnf", "which dnf"},
		{"yum", "which yum"},
		{"tdnf", "which tdnf"},
	}

	for _, m := range linuxManagers {
		stdout := new(bytes.Buffer)
		stderr := new(bytes.Buffer)
		cmd := &packer.RemoteCmd{
			Command: m.cmd,
			Stdout:  stdout,
			Stderr:  stderr,
		}
		if err := comm.Start(context.Background(), cmd); err != nil {
			continue
		}
		cmd.Wait()
		if cmd.ExitStatus() == 0 {
			return m.name, nil
		}
	}

	// Try Windows package managers
	windowsManagers := []struct {
		name string
		cmd  string
	}{
		{"choco", "if (Test-Path 'C:\\ProgramData\\chocolatey\\bin\\choco.exe') { exit 0 } else { exit 1 }"},
		{"winget", "where winget"},
	}

	for _, m := range windowsManagers {
		stdout := new(bytes.Buffer)
		stderr := new(bytes.Buffer)
		cmd := &packer.RemoteCmd{
			Command: m.cmd,
			Stdout:  stdout,
			Stderr:  stderr,
		}
		if err := comm.Start(context.Background(), cmd); err != nil {
			continue
		}
		cmd.Wait()
		if cmd.ExitStatus() == 0 {
			return m.name, nil
		}
	}

	// Check if this is Windows without a package manager
	isWindows := p.isWindows(comm)
	if isWindows {
		// Return "choco-install" to signal we need to install Chocolatey first
		return "choco-install", nil
	}

	return "", fmt.Errorf("no supported package manager found")
}

func (p *Provisioner) getUpdateCommand(manager string) string {
	switch manager {
	case "apt":
		// Enable universe repository and update - required for packages like make, gcc on minimal Ubuntu images
		return "sudo add-apt-repository -y universe 2>/dev/null || true; sudo DEBIAN_FRONTEND=noninteractive apt-get update -y"
	case "yum":
		return "sudo yum makecache -y"
	case "dnf":
		return "sudo dnf makecache -y"
	case "tdnf":
		return "sudo tdnf makecache -y"
	case "choco":
		// Skip update for choco - it's typically freshly installed
		return "cmd /c echo Chocolatey ready"
	case "winget":
		return "cmd /c echo Winget ready"
	default:
		return "echo 'Unknown package manager'"
	}
}

func (p *Provisioner) getUpgradeCommand(manager string) string {
	switch manager {
	case "apt":
		return "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"
	case "yum":
		return "sudo yum upgrade -y"
	case "dnf":
		return "sudo dnf upgrade -y"
	case "tdnf":
		return "sudo tdnf upgrade -y"
	case "choco":
		return "cmd /c C:\\ProgramData\\chocolatey\\bin\\choco.exe upgrade all -y --no-progress"
	case "winget":
		return "cmd /c echo Winget upgrade skipped"
	default:
		return "echo 'Unknown package manager'"
	}
}

func (p *Provisioner) getInstallCommand(manager string, packages []string) string {
	pkgList := ""
	for _, pkg := range packages {
		pkgList += " " + pkg
	}

	switch manager {
	case "apt":
		return fmt.Sprintf("sudo DEBIAN_FRONTEND=noninteractive apt-get install -y%s", pkgList)
	case "yum":
		return fmt.Sprintf("sudo yum install -y%s", pkgList)
	case "dnf":
		return fmt.Sprintf("sudo dnf install -y%s", pkgList)
	case "tdnf":
		return fmt.Sprintf("sudo tdnf install -y%s", pkgList)
	case "choco":
		return fmt.Sprintf("cmd /c C:\\ProgramData\\chocolatey\\bin\\choco.exe install -y --no-progress%s", pkgList)
	case "winget":
		// winget requires individual install commands
		cmds := ""
		for i, pkg := range packages {
			if i > 0 {
				cmds += " && "
			}
			cmds += fmt.Sprintf("winget install --accept-source-agreements --accept-package-agreements -e --id %s", pkg)
		}
		return cmds
	default:
		return "echo 'Unknown package manager'"
	}
}

func (p *Provisioner) getCleanCommand(manager string) string {
	switch manager {
	case "apt":
		return "sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/*"
	case "yum":
		return "sudo yum clean all"
	case "dnf":
		return "sudo dnf clean all"
	case "tdnf":
		return "sudo tdnf clean all"
	case "choco":
		return "cmd /c echo Cache cleanup skipped"
	case "winget":
		return "echo 'Winget does not require cache cleanup'"
	default:
		return "echo 'Unknown package manager'"
	}
}

func (p *Provisioner) runCommand(ctx context.Context, ui packer.Ui, comm packer.Communicator, command string) error {
	ui.Message(fmt.Sprintf("Executing: %s", command))

	// Create buffers for stdout/stderr - required for WinRM to avoid nil pointer dereference
	stdout := new(bytes.Buffer)
	stderr := new(bytes.Buffer)

	cmd := &packer.RemoteCmd{
		Command: command,
		Stdout:  stdout,
		Stderr:  stderr,
	}

	if err := comm.Start(ctx, cmd); err != nil {
		return fmt.Errorf("failed to start command: %v", err)
	}

	// Wait for command completion
	cmd.Wait()

	// Safely log any output (check for nil and empty)
	if stdout != nil && stdout.Len() > 0 {
		ui.Message(stdout.String())
	}
	if stderr != nil && stderr.Len() > 0 {
		ui.Message(fmt.Sprintf("stderr: %s", stderr.String()))
	}

	if cmd.ExitStatus() != 0 {
		errMsg := ""
		if stderr != nil {
			errMsg = stderr.String()
		}
		return fmt.Errorf("command exited with status %d: %s", cmd.ExitStatus(), errMsg)
	}

	return nil
}

func (p *Provisioner) verifyPackages(ctx context.Context, ui packer.Ui, comm packer.Communicator, manager string) error {
	// Show OS info
	osInfoCmd := p.getOSInfoCommand(manager)
	if osInfoCmd != "" {
		ui.Message("=== OS Information ===")
		_ = p.runCommand(ctx, ui, comm, osInfoCmd)
	}

	// List installed packages
	ui.Message("=== Installed Packages ===")
	listCmd := p.getListInstalledCommand(manager)
	if err := p.runCommand(ctx, ui, comm, listCmd); err != nil {
		ui.Message(fmt.Sprintf("Warning: Could not list packages: %v", err))
	}

	// Verify specific packages
	ui.Message("=== Package Verification ===")
	for _, pkg := range p.config.Packages {
		verifyCmd := p.getVerifyPackageCommand(manager, pkg)
		if err := p.runCommand(ctx, ui, comm, verifyCmd); err != nil {
			return fmt.Errorf("package '%s' verification failed: %v", pkg, err)
		}
	}

	ui.Message("=== All packages verified successfully ===")
	return nil
}

func (p *Provisioner) getOSInfoCommand(manager string) string {
	switch manager {
	case "apt":
		return "cat /etc/os-release | head -5"
	case "yum", "dnf":
		return "cat /etc/os-release | head -5"
	case "tdnf":
		return "cat /etc/os-release | head -5"
	case "choco", "winget":
		return "cmd /c ver"
	default:
		return ""
	}
}

func (p *Provisioner) getListInstalledCommand(manager string) string {
	switch manager {
	case "apt":
		return "dpkg -l | grep -E '^ii' | head -20"
	case "yum":
		return "rpm -qa | head -20"
	case "dnf":
		return "dnf list installed | head -20"
	case "tdnf":
		return "tdnf list installed | head -20"
	case "choco":
		return "cmd /c C:\\ProgramData\\chocolatey\\bin\\choco.exe list"
	case "winget":
		return "cmd /c winget list"
	default:
		return "echo 'Unknown package manager'"
	}
}

func (p *Provisioner) getVerifyPackageCommand(manager string, pkg string) string {
	switch manager {
	case "apt":
		return fmt.Sprintf("dpkg -s %s > /dev/null 2>&1 && echo '✓ %s installed' || (echo '✗ %s NOT installed' && exit 1)", pkg, pkg, pkg)
	case "yum", "dnf":
		return fmt.Sprintf("rpm -q %s > /dev/null 2>&1 && echo '✓ %s installed' || (echo '✗ %s NOT installed' && exit 1)", pkg, pkg, pkg)
	case "tdnf":
		return fmt.Sprintf("tdnf list installed %s > /dev/null 2>&1 && echo '✓ %s installed' || (echo '✗ %s NOT installed' && exit 1)", pkg, pkg, pkg)
	case "choco":
		return fmt.Sprintf("cmd /c C:\\ProgramData\\chocolatey\\bin\\choco.exe list %s --exact --limit-output >nul 2>&1 && echo ✓ %s installed || (echo ✗ %s NOT installed && exit 1)", pkg, pkg, pkg)
	case "winget":
		return fmt.Sprintf("cmd /c winget list --exact --id %s >nul 2>&1 && echo ✓ %s installed || (echo ✗ %s NOT installed && exit 1)", pkg, pkg, pkg)
	default:
		return fmt.Sprintf("echo 'Cannot verify %s - unknown package manager'", pkg)
	}
}

func (p *Provisioner) isWindows(comm packer.Communicator) bool {
	// Check if this is Windows by looking for cmd.exe
	stdout := new(bytes.Buffer)
	stderr := new(bytes.Buffer)
	cmd := &packer.RemoteCmd{
		Command: "cmd /c echo Windows",
		Stdout:  stdout,
		Stderr:  stderr,
	}
	if err := comm.Start(context.Background(), cmd); err != nil {
		return false
	}
	cmd.Wait()
	return cmd.ExitStatus() == 0
}

func (p *Provisioner) installChocolatey(ctx context.Context, ui packer.Ui, comm packer.Communicator) error {
	// Use a simple approach with output suppressed to avoid WinRM EOF issues
	ui.Message("Installing Chocolatey...")

	// Step 1: Download and run the installer with ALL output suppressed
	// This avoids WinRM connection issues with large output
	installCmd := `powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "$ProgressPreference = 'SilentlyContinue'; $ErrorActionPreference = 'SilentlyContinue'; Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) | Out-Null; exit 0"`

	if err := p.runCommand(ctx, ui, comm, installCmd); err != nil {
		ui.Message(fmt.Sprintf("Initial install attempt result: %v", err))
	}

	// Step 2: Wait for filesystem to sync
	waitCmd := `cmd /c timeout /t 5 /nobreak >nul`
	_ = p.runCommand(ctx, ui, comm, waitCmd)

	// Step 3: Verify Chocolatey was installed
	ui.Message("Verifying Chocolatey installation...")
	verifyCmd := `cmd /c if exist C:\ProgramData\chocolatey\bin\choco.exe (C:\ProgramData\chocolatey\bin\choco.exe --version) else (exit 1)`
	if err := p.runCommand(ctx, ui, comm, verifyCmd); err != nil {
		return fmt.Errorf("Chocolatey installation verification failed: %v", err)
	}

	return nil
}
