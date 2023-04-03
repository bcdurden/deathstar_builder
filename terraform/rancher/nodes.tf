module "rke2-hardened" {
  source  = "bcdurden/rke2-hardened/harvester"
  version = "0.0.3"
  
  main_cluster_prefix = var.main_cluster_prefix
  worker_prefix = var.worker_prefix
  kubeconfig_filename = var.kubeconfig_filename
  master_vip = var.master_vip
  control_plane_ha_mode = var.control_plane_ha_mode
  worker_count = var.worker_count
  node_disk_size = var.node_disk_size
  control_plane_cpu_count = var.control_plane_cpu_count
  control_plane_memory_size = var.control_plane_memory_size
  worker_cpu_count = var.worker_cpu_count
  worker_memory_size = var.worker_memory_size
  harvester_rke2_image_name = var.harvester_rke2_image_name
  target_network_name = var.target_network_name
  carbide_username = var.carbide_username
  carbide_password = var.carbide_password
  registry_url = var.registry_url
}