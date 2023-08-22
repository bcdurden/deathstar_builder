module "rke2-hardened" {
  source  = "bcdurden/rke2-hardened/harvester"
  version = "0.1.0"
  
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
  cp_network_data = [
    <<EOT
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      dhcp4: no
      addresses: [10.10.5.20/24]
      gateway4: 10.10.5.1
      nameservers:
        addresses: [10.10.0.1]
    EOT
    ,
    <<EOT
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      dhcp4: no
      addresses: [10.10.5.21/24]
      gateway4: 10.10.5.1
      nameservers:
        addresses: [10.10.0.1]
    EOT
    ,
    <<EOT
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      dhcp4: no
      addresses: [10.10.5.22/24]
      gateway4: 10.10.5.1
      nameservers:
        addresses: [10.10.0.1]
    EOT
    ]
}