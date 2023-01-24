data "harvester_network" "services" {
  name      = "services"
  namespace = "default"
}
data "harvester_image" "ubuntu2004" {
  name      = "ubuntu-2004"
  namespace = "default"
}