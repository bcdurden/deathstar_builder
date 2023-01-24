resource "harvester_image" "ubuntu-2004" {
  name      = "ubuntu-2004"
  namespace = "default"

  display_name = "ubuntu-2004"
  source_type  = "download"
  url          = "http://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img"
}
