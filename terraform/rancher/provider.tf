terraform {
  required_version = ">= 0.13"
  backend "kubernetes" {
    secret_suffix    = "state-rke2"
    config_path      = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}