resource "harvester_virtualmachine" "node" {
  count = var.worker_count

  name                 = "${var.node_prefix}-${count.index}"
  namespace            = var.namespace
  restart_after_update = true

  description = "Mgmt Cluster Worker node"
  tags = {
    ssh-user = "ubuntu"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait > /dev/null",
      "echo 'Completed cloud-init!'",
    ]

    connection {
      type        = "ssh"
      host        = self.network_interface[index(self.network_interface.*.name, "default")].ip_address
      user        = "ubuntu"
      private_key = var.ssh_key
    }
  }

  cpu    = var.worker_node_core_count
  memory = var.worker_node_memory_size

  run_strategy = "RerunOnFailure"
  hostname     = "${var.node_prefix}-${count.index}"
  machine_type = "q35"

  ssh_keys = var.ssh_keys
  network_interface {
    name           = "default"
    network_name   = var.vlan_id
    wait_for_lease = true
  }

  disk {
    name       = "rootdisk"
    type       = "disk"
    size       = var.disk_size
    bus        = "virtio"
    boot_order = 1

    image       = var.node_image_id
    auto_delete = true
  }

  cloudinit {
    type      = "noCloud"
    user_data    = <<EOT
      #cloud-config
      write_files:
      - path: /etc/rancher/rke2/config.yaml
        owner: root
        content: |
          token: ${var.cluster_token}
          server: https://${var.master_hostname}:9345
          system-default-registry: ${var.rke2_registry}
      - path: /etc/hosts
        owner: root
        content: |
          127.0.0.1 localhost
          127.0.0.1 "${var.node_prefix}-${count.index}"
          ${var.master_vip} ${var.master_hostname}
      - path: /etc/rancher/rke2/registries.yaml
        owner: root
        content: |
          mirrors:
            docker.io:
              endpoint:
                - "https://${var.rke2_registry}"
            ${var.rke2_registry}:
              endpoint:
                - "https://${var.rke2_registry}"
      runcmd:
      - - systemctl
        - enable
        - '--now'
        - qemu-guest-agent.service
      - INSTALL_RKE2_TYPE="agent" INSTALL_RKE2_ARTIFACT_PATH=/var/lib/rancher/rke2-artifacts sh /var/lib/rancher/install.sh
      - systemctl enable rke2-agent.service
      - systemctl start rke2-agent.service
      ssh_authorized_keys: 
      - ${var.ssh_pubkey}
    EOT
    network_data = var.network_data
  }
}