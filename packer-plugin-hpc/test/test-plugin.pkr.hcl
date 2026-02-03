packer {
  required_plugins {
    hpc = {
      version = ">= 1.0.0"
      source  = "github.com/MKGAURAB/hpc"
    }
  }
}

source "null" "test" {
  communicator = "none"
}

build {
  sources = ["source.null.test"]
  
  provisioner "hpc-package-manager" {
    update   = true
    packages = ["git", "curl", "wget"]
    verify   = true
  }
}
