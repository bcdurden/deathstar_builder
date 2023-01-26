resource "harvester_image" "ubuntu-airgap" {
  name      = var.image_name
  namespace = "default"

  display_name = var.image_name
  source_type  = "download"
  url          = "http://${var.host_ip}:${var.port}/${var.image_name}.img"
}
