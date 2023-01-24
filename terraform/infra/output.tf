output "ubuntu_image_name" {
    value = harvester_image.ubuntu-2004.id
}
output "services_network_name" {
    value = harvester_network.services.id
}
output "sandbox_network_name" {
    value = harvester_network.sandbox.id
}
output "dev_network_name" {
    value = harvester_network.dev.id
}
output "prod_network_name" {
    value = harvester_network.prod.id
}