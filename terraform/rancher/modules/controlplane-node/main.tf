resource "harvester_virtualmachine" "node-main" {
  name                 = "${var.node_name_prefix}-0"
  namespace            = var.namespace
  restart_after_update = true

  description = "Mgmt Cluster Control Plane node"
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

  cpu    = var.controlplane_node_core_count
  memory = var.controlplane_node_memory_size

  run_strategy = "RerunOnFailure"
  hostname     = "${var.node_name_prefix}-0"
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
          system-default-registry: ${var.rke2_registry}
          tls-san:
            - ${var.node_name_prefix}-0
            - ${var.master_hostname}
            - ${var.master_vip}
      - path: /etc/hosts
        owner: root
        content: |
          127.0.0.1 localhost
          127.0.0.1 ${var.node_name_prefix}-0
          127.0.0.1 ${var.master_hostname}
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
            ghcr.io:
              endpoint:
                - "https://${var.rke2_registry}"
      runcmd:
      - - systemctl
        - enable
        - '--now'
        - qemu-guest-agent.service
      - INSTALL_RKE2_ARTIFACT_PATH=/var/lib/rancher/rke2-artifacts sh /var/lib/rancher/install.sh
      - cat /var/lib/rancher/kube-vip-k3s |  vipAddress=${var.master_vip} vipInterface=${var.master_vip_interface} sh | sudo tee /var/lib/rancher/rke2/server/manifests/vip.yaml
      - systemctl enable rke2-server.service
      - systemctl start rke2-server.service
      ssh_authorized_keys: 
      - ${var.ssh_pubkey}
    EOT
    network_data = var.network_data
  }
}
resource "harvester_virtualmachine" "node-ha" {
  count = var.ha_mode ? 2 : 0
  name                 = "${var.node_name_prefix}-${count.index + 1}"
  depends_on = [
    harvester_virtualmachine.node-main
  ]
  namespace            = var.namespace
  restart_after_update = true

  description = "Mgmt Cluster Control Plane node"
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

  cpu    = var.controlplane_node_core_count
  memory = var.controlplane_node_memory_size

  run_strategy = "RerunOnFailure"
  hostname     = "${var.node_name_prefix}-${count.index + 1}"
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
      package_update: true
      write_files:
      - path: /etc/rancher/rke2/config.yaml
        owner: root
        content: |
          token: ${var.cluster_token}
          server: https://${var.master_hostname}:9345
          system-default-registry: ${var.rke2_registry}
          tls-san:
            - ${var.node_name_prefix}-${count.index + 1}
            - ${var.master_hostname}
            - ${var.master_vip}
      - path: /etc/hosts
        owner: root
        content: |
          127.0.0.1 localhost
          127.0.0.1 ${var.node_name_prefix}-${count.index + 1}
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
            ghcr.io:
              endpoint:
                - "https://${var.rke2_registry}"
      packages:
      - qemu-guest-agent
      runcmd:
      - - systemctl
        - enable
        - '--now'
        - qemu-guest-agent.service
      - INSTALL_RKE2_ARTIFACT_PATH=/var/lib/rancher/rke2-artifacts sh /var/lib/rancher/install.sh
      - systemctl enable rke2-server.service
      - systemctl start rke2-server.service
      ssh_authorized_keys: 
      - ${var.ssh_pubkey}
    EOT
    network_data = var.network_data
  }
}