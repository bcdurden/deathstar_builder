# Helm resources
resource "local_file" "kube_config_server_yaml" {
  filename = var.kubeconfig_filename
  content  = ssh_resource.retrieve_config.result
}

# Install cert-manager helm chart
# resource "helm_release" "cert_manager" {
#   depends_on = [
#     module.controlplane-nodes,
#     module.worker,
#     local_file.kube_config_server_yaml
#   ]

#   name             = "cert-manager"
#   chart            = "../../bootstrap/rancher/cert-manager-v${var.cert_manager_version}.tgz"
#   namespace        = "cert-manager"
#   create_namespace = true
#   wait             = true

#   set {
#     name  = "installCRDs"
#     value = "true"
#   }
#   set {
#     name  = "image.repository"
#     value = "${var.registry_url}/jetstack/cert-manager-controller"
#   }
#   set {
#     name  = "webhook.image.repository"
#     value = "${var.registry_url}/jetstack/cert-manager-webhook"
#   }
#   set {
#     name  = "cainjector.image.repository"
#     value = "${var.registry_url}/jetstack/cert-manager-cainjector"
#   }
#   set {
#     name  = "startupapicheck.image.repository"
#     value = "${var.registry_url}/jetstack/cert-manager-ctl"
#   }
# }

# # Install Rancher helm chart
# resource "helm_release" "rancher_server" {
#   depends_on = [
#     helm_release.cert_manager
#   ]

#   name             = "rancher"
#   chart            = "../../bootstrap/rancher/rancher-${var.rancher_version}.tgz"
#   namespace        = "cattle-system"
#   create_namespace = true
#   wait             = true

#   set {
#     name  = "hostname"
#     value = var.rancher_server_dns
#   }
#   set {
#     name  = "replicas"
#     value = var.rancher_replicas
#   }
#   set {
#     name  = "bootstrapPassword"
#     value = var.rancher_bootstrap_password
#   }
#   set {
#     name  = "rancherImage"
#     value = "${var.registry_url}/rancher/rancher"
#   }
#   set {
#     name  = "systemDefaultRegistry"
#     value = "${var.registry_url}"
#   }
#     set {
#     name = "ingress.tls.source"
#     value = "secret"
#   }
# }
