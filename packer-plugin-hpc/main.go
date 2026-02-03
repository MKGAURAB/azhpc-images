package main

import (
	"fmt"
	"os"

	packagemanager "github.com/MKGAURAB/packer-plugin-hpc/provisioner/package-manager"
	"github.com/MKGAURAB/packer-plugin-hpc/version"
	"github.com/hashicorp/packer-plugin-sdk/plugin"
	packerversion "github.com/hashicorp/packer-plugin-sdk/version"
)

func main() {
	pps := plugin.NewSet()
	pps.RegisterProvisioner("package-manager", new(packagemanager.Provisioner))
	pps.SetVersion(packerversion.NewPluginVersion(version.Version, version.VersionPrerelease, ""))
	err := pps.Run()
	if err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(1)
	}
}
