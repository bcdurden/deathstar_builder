terraform {
  required_version = ">= 0.13"
  required_providers {
    harvester = {
      source  = "harvester/harvester"
      version = "0.6.0"
    }
  }
  backend "kubernetes" {
    secret_suffix    = "state-rke2"
    config_path      = "~/.kube/config"
  }
}

provider "harvester" {
}
provider "kubernetes" {
  config_path = "~/.kube/config"
}