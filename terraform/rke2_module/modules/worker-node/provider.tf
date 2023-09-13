terraform {
  required_version = ">= 0.13"
  required_providers {
    harvester = {
      source  = "harvester/harvester"
      version = "0.6.2"
    }

    ssh = {
      source  = "loafoe/ssh"
      version = "1.2.0"
    }
  }
}