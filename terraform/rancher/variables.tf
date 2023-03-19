variable "main_cluster_prefix" {
    type = string
    default = "rke2-mgmt-controlplane"
}
variable "worker_prefix" {
    type = string
    default = "rke2-mgmt-worker"
}
variable "kubeconfig_filename" {
    type = string
    default = "kube_config_server.yaml"
}
variable "cert_manager_version" {
  type        = string
  description = "Version of cert-manager to install alongside Rancher (format: 0.0.0)"
  default     = "1.8.1"
}

variable "rancher_version" {
  type        = string
  description = "Rancher server version (format v0.0.0)"
  default     = "2.7.0"
}
variable "master_vip" {
    type = string
    default = "10.10.5.4"
}
variable "rancher_server_dns" {
  type        = string
  description = "DNS host name of the Rancher server"
  default = "rancher.sienarfleet.systems"
}
variable "registry_url" {
  type = string
  default = "harbor.sienarfleet.systems"
}
variable "rancher_bootstrap_password" {
  type = string
  default = "admin" 
}
variable "rancher_replicas" {
  type = string
  default = 3
}
variable "worker_count" {
  type = string
  default = 1
}
variable "node_disk_size" {
  type = string
  default = "20Gi"
}
variable "control_plane_ha_mode" {
  type = bool
  default = false
}
variable "control_plane_cpu_count" {
  type = string
  default = 2
}
variable "control_plane_memory_size" {
  type = string
  default = "4Gi"
}
variable "worker_cpu_count" {
  type = string
  default = 2
}
variable "worker_memory_size" {
  type = string
  default = "4Gi"
}
variable "harvester_rke2_image_name" {
  type = string
}
variable "target_network_name" {
  type = string
}
variable "carbide_password" {
    type = string
}
variable "carbide_username" {
    type = string
}