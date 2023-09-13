resource "harvester_image" "ubuntu-2004" {
  name      = "ubuntu-2004"
  namespace = "default"

  display_name = "ubuntu-2004"
  source_type  = "download"
  url          = "http://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img"
}
resource "harvester_image" "ubuntu-airgap" {
  name      = var.ubuntu_image_name
  namespace = "default"

  display_name = var.ubuntu_image_name
  source_type  = "download"
  url          = "http://${var.host_ip}:${var.port}/${var.ubuntu_image_name}.img"
}
# resource "harvester_image" "harbor-airgap" {
#   name      = var.harbor_image_name
#   namespace = "default"

#   display_name = var.harbor_image_name
#   source_type  = "download"
#   url          = "http://${var.host_ip}:${var.port}/${var.harbor_image_name}.img"
# }