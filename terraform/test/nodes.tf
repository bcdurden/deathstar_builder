module "rke2-hardened" {
  source  = "bcdurden/rke2-hardened/harvester"
  version = "0.0.3"

  master_vip = var.master_vip
  harvester_rke2_image_name = var.harvester_rke2_image_name
  target_network_name = var.target_network_name
  carbide_username = var.carbide_username
  carbide_password = var.carbide_password
  registry_url = var.registry_url
}