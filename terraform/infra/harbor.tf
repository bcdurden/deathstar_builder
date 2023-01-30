resource "harvester_virtualmachine" "harbor" {
  name                 = "harbor"
  namespace            = "default"
  restart_after_update = true

  description = "Harbor VM"
  tags = {
    ssh-user = "ubuntu"
  }

  cpu    = 4
  memory = "8Gi"

  run_strategy = "RerunOnFailure"
  hostname     = "harbor"
  machine_type = "q35"

  network_interface {
    name           = "default"
    network_name   = harvester_network.services.id
    wait_for_lease = true
  }

  disk {
    name       = "rootdisk"
    type       = "disk"
    size       = "120Gi"
    bus        = "virtio"
    boot_order = 1

    image       = harvester_image.harbor-airgap.id
    auto_delete = true
  }

  cloudinit {
    type      = "noCloud"
    
    user_data    = <<EOT
      #cloud-config
      write_files:
      - path: /etc/systemd/system/harbor.service
        owner: root
        content: |
          [Unit]
          Description=Harbor service with docker compose
          PartOf=docker.service
          After=docker.service

          [Service]
          Type=oneshot
          RemainAfterExit=true
          WorkingDirectory=/home/ubuntu/harbor
          ExecStart=/usr/bin/docker compose up -d --remove-orphans
          ExecStop=/usr/bin/docker compose down

          [Install]
          WantedBy=multi-user.target
      runcmd:
      - cd /home/ubuntu/harbor/ && ./install.sh --with-notary --with-chartmuseum  --with-trivy
      - systemctl enable harbor.service
      - systemctl restart harbor

      ssh_authorized_keys: 
      - ${tls_private_key.rsa_key.public_key_openssh}
    EOT

    network_data   = <<EOT
      network:
        version: 2
        renderer: networkd
        ethernets:
          enp1s0:
            dhcp4: no
            addresses: [10.10.5.5/24]
            gateway4: 10.10.5.1
            nameservers:
              addresses: [10.10.5.2]
    EOT
  }
}