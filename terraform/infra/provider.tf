terraform {
  required_version = ">= 0.13"
  required_providers {
    harvester = {
      source  = "harvester/harvester"
      version = "0.6.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.17.0"
    }
    random = {
      source = "hashicorp/random"
      version = "3.4.3"
    }
  }
  backend "kubernetes" {
    secret_suffix    = "state-infra"
    config_path      = "~/.kube/config"
  }
}

provider "harvester" {
}
provider "random" {
}
provider "kubernetes" {
  config_path = "~/.kube/config"
}