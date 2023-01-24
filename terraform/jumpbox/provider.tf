terraform {
  required_version = ">= 0.13"
  required_providers {
    harvester = {
      source  = "harvester/harvester"
      version = "0.6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.2.3"
    }
    ssh = {
      source  = "loafoe/ssh"
      version = "1.2.0"
    }
  }
  backend "kubernetes" {
    secret_suffix    = "state-jumpbox"
    config_path      = "~/.kube/config"
  }
}

provider "harvester" {
}