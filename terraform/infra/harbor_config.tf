# resource "kubernetes_secret" "harbor_config" {
#   metadata {
#     name = "harbor-instance-config"
#   }

#   type = "secret"

#   data = {
#     userdata = <<EOT
#       #cloud-config
#       write_files:
#       - path: /etc/systemd/system/harbor.service
#         owner: root
#         content: |
#           [Unit]
#           Description=Harbor service with docker compose
#           PartOf=docker.service
#           After=docker.service

#           [Service]
#           Type=oneshot
#           RemainAfterExit=true
#           WorkingDirectory=/home/ubuntu/harbor
#           ExecStart=/usr/bin/docker compose up -d --remove-orphans
#           ExecStop=/usr/bin/docker compose down

#           [Install]
#           WantedBy=multi-user.target
#       - path: /data/cert/${var.harbor_url}.cert
#         encoding: b64
#         owner: root
#         content: ${var.harbor_cert_b64}
#         permissions: '0644'
#       - path: /data/cert/${var.harbor_url}.key
#         encoding: b64
#         owner: root
#         content: ${var.harbor_key_b64}
#         permissions: '0600'
#       - path: /home/ubuntu/harbor/harbor.yml
#         owner: root
#         permissions: '0660'
#         content: |
#           # Configuration file of Harbor
#           # The IP address or hostname to access admin UI and registry service.
#           # DO NOT use localhost or 127.0.0.1, because Harbor needs to be accessed by external clients.
#           hostname: ${var.harbor_url}

#           # http related config
#           http:
#             # port for http, default is 80. If https enabled, this port will redirect to https port
#             port: 80

#           # https related config
#           https:
#             # https port for harbor, default is 443
#             port: 443
#             # The path of cert and key files for nginx
#             certificate: /data/cert/${var.harbor_url}.cert
#             private_key: /data/cert/${var.harbor_url}.key

#           # Uncomment external_url if you want to enable external proxy
#           # And when it enabled the hostname will no longer used
#           # external_url: https://reg.mydomain.com:8433

#           # The initial password of Harbor admin
#           # It only works in first time to install harbor
#           # Remember Change the admin password from UI after launching Harbor.
#           harbor_admin_password: "${random_password.harbor_admin_password.result}"

#           # Harbor DB configuration
#           database:
#             # The password for the root user of Harbor DB. Change this before any production use.
#             password: "${random_password.database_password.result}"
#             # The maximum number of connections in the idle connection pool. If it <=0, no idle connections are retained.
#             max_idle_conns: 100
#             # The maximum number of open connections to the database. If it <= 0, then there is no limit on the number of open connections.
#             # Note: the default number of connections is 1024 for postgres of harbor.
#             max_open_conns: 900

#           # The default data volume
#           data_volume: /data

#           # Trivy configuration
#           #
#           # Trivy DB contains vulnerability information from NVD, Red Hat, and many other upstream vulnerability databases.
#           # It is downloaded by Trivy from the GitHub release page https://github.com/aquasecurity/trivy-db/releases and cached
#           # in the local file system. In addition, the database contains the update timestamp so Trivy can detect whether it
#           # should download a newer version from the Internet or use the cached one. Currently, the database is updated every
#           # 12 hours and published as a new release to GitHub.
#           trivy:
#             # ignoreUnfixed The flag to display only fixed vulnerabilities
#             ignore_unfixed: false
#             # You might want to enable this flag in test or CI/CD environments to avoid GitHub rate limiting issues.
#             # If the flag is enabled you have to download the `trivy-offline.tar.gz` archive manually, extract `trivy.db` and
#             # `metadata.json` files and mount them in the `/home/scanner/.cache/trivy/db` path.
#             skip_update: false
#             # This option doesn’t affect DB download. You need to specify "skip-update" as well as "offline-scan" in an air-gapped environment.
#             offline_scan: false
#             #
#             # insecure The flag to skip verifying registry certificate
#             insecure: false
#           jobservice:
#             # Maximum number of job workers in job service
#             max_job_workers: 10

#           notification:
#             # Maximum retry count for webhook job
#             webhook_job_max_retry: 10

#           chart:
#             # Change the value of absolute_url to enabled can enable absolute url in chart
#             absolute_url: disabled

#           # Log configurations
#           log:
#             # options are debug, info, warning, error, fatal
#             level: info
#             # configs for logs in local storage
#             local:
#               # Log files are rotated log_rotate_count times before being removed. If count is 0, old versions are removed rather than rotated.
#               rotate_count: 50
#               # Log files are rotated only if they grow bigger than log_rotate_size bytes. If size is followed by k, the size is assumed to be in kilobytes.
#               # If the M is used, the size is in megabytes, and if G is used, the size is in gigabytes. So size 100, size 100k, size 100M and size 100G
#               # are all valid.
#               rotate_size: 200M
#               # The directory on your host that store log
#               location: /var/log/harbor

#           #This attribute is for migrator to detect the version of the .cfg file, DO NOT MODIFY!
#           _version: 2.5.0

#           # Global proxy
#           # Config http proxy for components, e.g. http://my.proxy.com:3128
#           # Components doesn't need to connect to each others via http proxy.
#           # Remove component from `components` array if want disable proxy
#           # for it. If you want use proxy for replication, MUST enable proxy
#           # for core and jobservice, and set `http_proxy` and `https_proxy`.
#           # Add domain to the `no_proxy` field, when you want disable proxy
#           # for some special registry.
#           proxy:
#             http_proxy:
#             https_proxy:
#             no_proxy:
#             components:
#               - core
#               - jobservice
#               - trivy

#           # enable purge _upload directories
#           upload_purging:
#             enabled: true
#             # remove files in _upload directories which exist for a period of time, default is one week.
#             age: 168h
#             # the interval of the purge operations
#             interval: 24h
#             dryrun: false
#       runcmd:
#       - cd /home/ubuntu/harbor/ && ./install.sh --with-notary --with-chartmuseum  --with-trivy
#       - systemctl enable harbor.service
#       - systemctl restart harbor

#       ssh_authorized_keys: 
#       - ${tls_private_key.rsa_key.public_key_openssh}
#     EOT 
#   }
# }

