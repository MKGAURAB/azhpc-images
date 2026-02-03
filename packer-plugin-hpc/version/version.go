package version

// Version is the main version number that is being run at the moment.
var Version = "1.0.0"

// VersionPrerelease is a pre-release marker for the version.
// If this is "" (empty string) then it means that it is a final release.
// Otherwise, this is a pre-release such as "dev" (in development), "beta", "rc1", etc.
var VersionPrerelease = "dev"

// PluginVersion is used by the plugin set to allow Packer to recognize
// what version this plugin is.
var PluginVersion = Version + "-" + VersionPrerelease
