output "jumpbox_vm_ip" {
    value = harvester_virtualmachine.jumpbox.network_interface[index(harvester_virtualmachine.jumpbox.network_interface.*.name, "default")].ip_address
}
output "jumpbox_ssh_key" {
    value = tls_private_key.rsa_key.private_key_pem
    sensitive = true
}
output "jumpbox_key_file" {
    value = local_sensitive_file.jumpbox_key_pem.filename
}