# resource "harvester_virtualmachine" "harbor" {
#   depends_on = [
#     kubernetes_secret.harbor_config
#   ]

#   name                 = "harbor"
#   namespace            = "default"
#   restart_after_update = true

#   description = "Harbor VM"
#   tags = {
#     ssh-user = "ubuntu"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "echo 'Waiting for cloud-init to complete...'",
#       "cloud-init status --wait > /dev/null",
#       "echo 'Completed cloud-init!'",
#     ]

#     connection {
#       type        = "ssh"
#       host        = self.network_interface[index(self.network_interface.*.name, "default")].ip_address
#       user        = "ubuntu"
#       private_key = tls_private_key.rsa_key.private_key_openssh
#     }
#   }

#   cpu    = 2
#   memory = "8Gi"

#   run_strategy = "RerunOnFailure"
#   hostname     = "harbor"
#   machine_type = "q35"

#   network_interface {
#     name           = "default"
#     network_name   = harvester_network.services.id
#     wait_for_lease = true
#   }

#   disk {
#     name       = "rootdisk"
#     type       = "disk"
#     size       = "120Gi"
#     bus        = "virtio"
#     boot_order = 1

#     image       = harvester_image.harbor-airgap.id
#     auto_delete = true
#   }

#   cloudinit {
#     type      = "noCloud"
#     user_data_secret_name = "harbor-instance-config"

#     network_data   = <<EOT
#       network:
#         version: 2
#         renderer: networkd
#         ethernets:
#           enp1s0:
#             dhcp4: no
#             addresses: [10.10.5.5/24]
#             gateway4: 10.10.5.1
#             nameservers:
#               addresses: [10.10.0.1]
#     EOT
#   }
# }