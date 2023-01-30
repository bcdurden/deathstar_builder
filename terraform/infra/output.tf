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
output "harbor_vm_ip" {
    value = harvester_virtualmachine.harbor.network_interface[index(harvester_virtualmachine.harbor.network_interface.*.name, "default")].ip_address
}
output "harbor_ssh_key" {
    value = tls_private_key.rsa_key.private_key_pem
    sensitive = true
}
output "harbor_key_file" {
    value = local_sensitive_file.harbor_key_pem.filename
}