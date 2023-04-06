SHELL:=/bin/bash
REQUIRED_BINARIES := kubectl cosign helm terraform kubectx kubecm ytt yq jq
WORKING_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
BOOTSTRAP_DIR := ${WORKING_DIR}/bootstrap
TERRAFORM_DIR := ${WORKING_DIR}/terraform
WORKLOAD_DIR := ${WORKING_DIR}/workloads
GITOPS_DIR := ${WORKING_DIR}/gitops

HARVESTER_CONTEXT := "deathstar"
BASE_URL := sienarfleet.systems
GITEA_URL := git.$(BASE_URL)
GIT_ADMIN_PASSWORD="C4rb1De_S3cr4t"
CLOUDFLARE_TOKEN=""
CERT_MANAGER_VERSION=1.9.2
RANCHER_VERSION=2.7.1

# Carbide info
CARBIDE_TOKEN_FILE=/Volumes/BIGBOY/keys/carbide.yaml
CARBIDE_USER := $(shell yq e .token_id ${CARBIDE_TOKEN_FILE})
CARBIDE_PASSWORD:= $(shell yq e .token_password ${CARBIDE_TOKEN_FILE})
CARBIDE_LICENSE := $(shell yq e .license ${CARBIDE_TOKEN_FILE})
IMAGES_FILE=""

# Registry info
REGISTRY_URL := harbor.$(BASE_URL)
REGISTRY_USER=admin
REGISTRY_PASSWORD=""

# Rancher on Harvester Info
RKE2_VIP=10.10.5.10
RANCHER_TARGET_NETWORK=services
RANCHER_URL := rancher.deathstar.${BASE_URL}
RANCHER_HA_MODE=false
RANCHER_CP_CPU_COUNT=4
RANCHER_CP_MEMORY_SIZE="8Gi"
RANCHER_WORKER_COUNT=3
RANCHER_NODE_SIZE="40Gi"
RANCHER_HARVESTER_WORKER_CPU_COUNT=4
RANCHER_HARVESTER_WORKER_MEMORY_SIZE="8Gi"
RANCHER_REPLICAS=3
HARVESTER_RANCHER_CLUSTER_NAME=rancher-harvester
RKE2_IMAGE_NAME=ubuntu-rke2-airgap-harvester
HARBOR_IMAGE_NAME=harbor-ubuntu
HARVESTER_RANCHER_CERT_SECRET=rancher_cert.yaml
HARVESTER_CERT_SECRET=harbor_cert.yaml
AIRGAP_IMAGE_HOST_IP=

# gitops automation vars
WORKLOADS_KAPP_APP_NAME=workloads
WORKLOADS_NAMESPACE=default
TARGET_CLUSTER=
RANDOM_PASSWORD := ${shell head /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 13}

check-tools: ## Check to make sure you have the right tools
	$(foreach exec,$(REQUIRED_BINARIES),\
		$(if $(shell which $(exec)),,$(error "'$(exec)' not found. It is a dependency for this Makefile")))
# certificate targets
# CloudDNS holder: kubectl create secret generic clouddns-dns01-solver-svc-acct --from-file=key.json
certs: check-tools # needs CLOUD_TOKEN_FILE set and LOCAL_CLUSTER_NAME for non-default contexts
	@printf "\n===>Making Certificates\n";
	@kubectx ${HARVESTER_CONTEXT}
	@helm install cert-manager ${BOOTSTRAP_DIR}/rancher/cert-manager-v1.8.1.tgz \
    --namespace cert-manager \
	--create-namespace \
	--set installCRDs=true || true
	@kubectl create secret generic clouddns-dns01-solver-svc-acct -n cert-manager --from-file=$(CLOUD_TOKEN_FILE) --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -f $(BOOTSTRAP_DIR)/certs/issuer-prod-clouddns.yaml --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create ns harbor --dry-run=client -o yaml | kubectl apply -f -
	@ytt -f $(BOOTSTRAP_DIR)/certs/cert-harbor.yaml -v base_url=$(BASE_URL) | kubectl apply -f -
	@ytt -f $(BOOTSTRAP_DIR)/certs/cert-wildcard.yaml -v base_url=$(BASE_URL) | kubectl apply -f -
	@kubectl create ns git --dry-run=client -o yaml | kubectl apply -f -
	@ytt -f $(BOOTSTRAP_DIR)/certs/cert-gitea.yaml -v base_url=$(BASE_URL) | kubectl apply -f -
	@ytt -f $(BOOTSTRAP_DIR)/certs/cert-rancherdeathstar.yaml -v base_url=$(BASE_URL) | kubectl apply -f -

certs-export: check-tools
	@printf "\n===>Exporting Certificates\n";
	@kubectx ${HARVESTER_CONTEXT}
	@kubectl get secret -n harbor harbor-prod-homelab-certificate -o yaml > $(HARVESTER_CERT_SECRET) || true
	@kubectl get secret -n git gitea-prod-certificate -o yaml > gitea_cert.yaml || true
	@kubectl get secret wildcard-prod-certificate -o yaml > wildcard_cert.yaml || true
	@kubectl get secret -n cattle-system tls-rancherdeathstar-ingress -o yaml | yq e '.metadata.name = "tls-rancher-ingress"' > rancherdeathstar_cert.yaml || true
certs-import: check-tools
	@printf "\n===>Importing Certificates\n";
	@kubectx ${HARVESTER_CONTEXT}
	@kubectl apply -f harbor_cert.yaml
	@kubectl apply -f gitea_cert.yaml

# registry targets
registry: check-tools
	@printf "\n===> Installing Registry\n";
	@kubectx ${HARVESTER_CONTEXT}
	@helm upgrade --install harbor ${BOOTSTRAP_DIR}/harbor/harbor-1.9.3.tgz \
	--version 1.9.3 -n harbor -f ${BOOTSTRAP_DIR}/harbor/values.yaml --create-namespace
registry-delete: check-tools
	@printf "\n===> Deleting Registry\n";
	@kubectx ${HARVESTER_CONTEXT}
	@helm delete harbor -n harbor

# airgap targets
pull-rancher: check-tools
	@printf "\n===>Pulling Rancher Images\n";
	@${BOOTSTRAP_DIR}/airgap_images/pull_carbide_rancher $(CARBIDE_USER) '$(CARBIDE_PASSWORD)'
	@printf "\nIf successful, your images will be available at /tmp/rancher-images.tar.gz and /tmp/cert-manager.tar.gz"
pull-misc: check-tools
	@printf "\n===>Pulling Misc Images\n";
	@${BOOTSTRAP_DIR}/airgap_images/pull_misc
push-images: check-tools
	@printf "\n===>Pushing Images to Harbor\n";
	@${BOOTSTRAP_DIR}/airgap_images/push_carbide $(REGISTRY_URL) $(REGISTRY_USER) '$(REGISTRY_PASSWORD)' $(IMAGES_FILE)

# git targets
git: check-tools
	@kubectx ${HARVESTER_CONTEXT}
	@helm install gitea $(BOOTSTRAP_DIR)/gitea/gitea-6.0.1.tgz \
	--namespace git \
	--set gitea.admin.password=$(GIT_ADMIN_PASSWORD) \
	--set gitea.admin.username=gitea \
	--set persistence.size=10Gi \
	--set postgresql.persistence.size=1Gi \
	--set gitea.config.server.ROOT_URL=https://$(GITEA_URL) \
	--set gitea.config.server.DOMAIN=$(GITEA_URL) \
	--set gitea.config.server.PROTOCOL=http \
	-f $(BOOTSTRAP_DIR)/gitea/values.yaml
git-delete: check-tools
	@kubectx $(HARVESTER_CONTEXT)
	@printf "\n===> Deleting Gitea\n";
	@helm delete gitea -n git

### terraform main targets
_HARBOR_KEY=$(shell kubectl get secret -n harbor harbor-prod-homelab-certificate -o yaml | yq -e '.data."tls.key"' -)
_HARBOR_CERT=$(shell kubectl get secret -n harbor harbor-prod-homelab-certificate -o yaml | yq -e '.data."tls.crt"' -)
infra: check-tools
	@printf "\n=====> Terraforming Infra\n";
	@kubectx ${HARVESTER_CONTEXT}
	@$(MAKE) _terraform COMPONENT=infra VARS='TF_VAR_harbor_url="$(REGISTRY_URL)" TF_VAR_harbor_cert_b64="$(_HARBOR_CERT)" TF_VAR_harbor_key_b64="$(_HARBOR_KEY)" TF_VAR_ubuntu_image_name=$(RKE2_IMAGE_NAME) TF_VAR_harbor_image_name=$(HARBOR_IMAGE_NAME) TF_VAR_host_ip=$(AIRGAP_IMAGE_HOST_IP) TF_VAR_port=9900'
	@kubectl create ns services || true
	@kubectl create ns dev || true
	@kubectl create ns prod || true

jumpbox: check-tools
	@printf "\n====> Terraforming Jumpbox\n";
	@kubectx ${HARVESTER_CONTEXT}
	@$(MAKE) _terraform COMPONENT=jumpbox

jumpbox-key: check-tools
	@printf "\n====> Grabbing generated SSH key\n";
	@kubectx ${HARVESTER_CONTEXT}
	@$(MAKE) _terraform-value COMPONENT=jumpbox FIELD=".jumpbox_ssh_key.value"
jumpbox-destroy: check-tools
	@printf "\n====> Destroying Jumpbox\n";
	@kubectx ${HARVESTER_CONTEXT}
	@$(MAKE) _terraform-destroy COMPONENT=jumpbox

image: check-tools
	@printf "\n=====> Downloading Airgapped Image\n";
	@kubectx ${HARVESTER_CONTEXT}
	@$(MAKE) _terraform COMPONENT=image VARS='TF_VAR_host_ip=$(AIRGAP_IMAGE_HOST_IP) TF_VAR_port=9900 TF_VAR_image_name=$(RKE2_IMAGE_NAME)'

rancher: check-tools  # state stored in Harvester K8S
	@printf "\n====> Terraforming RKE2 + Rancher\n";
	@kubecm delete $(HARVESTER_RANCHER_CLUSTER_NAME) > /dev/null 2>&1 || true
	@kubectx ${HARVESTER_CONTEXT}
	@$(MAKE) _terraform COMPONENT=rancher VARS='TF_VAR_carbide_username="$(CARBIDE_USER)" TF_VAR_carbide_password="$(CARBIDE_PASSWORD)" TF_VAR_rancher_server_dns="$(RANCHER_URL)" TF_VAR_master_vip="$(RKE2_VIP)" TF_VAR_registry_url="$(REGISTRY_URL)" TF_VAR_control_plane_cpu_count=$(RANCHER_CP_CPU_COUNT) TF_VAR_control_plane_memory_size=$(RANCHER_CP_MEMORY_SIZE) TF_VAR_worker_count=$(RANCHER_WORKER_COUNT) TF_VAR_control_plane_ha_mode=$(RANCHER_HA_MODE) TF_VAR_node_disk_size=$(RANCHER_NODE_SIZE) TF_VAR_worker_cpu_count=$(RANCHER_HARVESTER_WORKER_CPU_COUNT) TF_VAR_worker_memory_size=$(RANCHER_HARVESTER_WORKER_MEMORY_SIZE) TF_VAR_target_network_name=$(RANCHER_TARGET_NETWORK) TF_VAR_harvester_rke2_image_name=$(shell kubectl get virtualmachineimage -o yaml | yq -e '.items[]|select(.spec.displayName=="$(RKE2_IMAGE_NAME)")' - | yq -e '.metadata.name' -)'
	@cp ${TERRAFORM_DIR}/rancher/kube_config_server.yaml /tmp/$(HARVESTER_RANCHER_CLUSTER_NAME).yaml && kubecm add -c -f /tmp/$(HARVESTER_RANCHER_CLUSTER_NAME).yaml && rm /tmp/$(HARVESTER_RANCHER_CLUSTER_NAME).yaml
	@kubectl get secret -n cattle-system tls-rancherdeathstar-ingress -o yaml | yq e '.metadata.name = "tls-rancher-ingress"' > $(HARVESTER_RANCHER_CERT_SECRET)
	@kubectx $(HARVESTER_RANCHER_CLUSTER_NAME)
	@helm upgrade --install cert-manager -n cert-manager --create-namespace --set installCRDs=true --set image.repository=$(REGISTRY_URL)/jetstack/cert-manager-controller --set webhook.image.repository=$(REGISTRY_URL)/jetstack/cert-manager-webhook --set cainjector.image.repository=$(REGISTRY_URL)/jetstack/cert-manager-cainjector --set startupapicheck.image.repository=$(REGISTRY_URL)/jetstack/cert-manager-ctl --set securityContext.runAsNonRoot=true $(BOOTSTRAP_DIR)/rancher/cert-manager-v$(CERT_MANAGER_VERSION).tgz
	@helm upgrade --install rancher -n cattle-system --create-namespace --set hostname=$(RANCHER_URL) --set replicas=$(RANCHER_REPLICAS) --set bootstrapPassword=admin --set rancherImage=$(REGISTRY_URL)/rancher/rancher --set "carbide.whitelabel.image=$(REGISTRY_URL)/carbide/carbide/carbide-whitelabel" --set systemDefaultRegistry=$(REGISTRY_URL) --set ingress.tls.source=secret --set useBundledSystemChart=true $(BOOTSTRAP_DIR)/rancher/carbide-rancher-v$(RANCHER_VERSION).tgz
	@kubectl apply -f $(HARVESTER_RANCHER_CERT_SECRET) || true
	@kubectl create ns fleet-default || true
	@kubectl create secret generic --type kubernetes.io/basic-auth carbide-registry -n fleet-default --from-literal=username=${CARBIDE_USER} --from-literal=password=${CARBIDE_PASSWORD} --dry-run=client -o yaml | kubectl apply -f - 2>&1 | grep -i -v "Warn" | grep -i -v "Deprecat"
	@until [ $$(curl -sk https://${RANCHER_URL}/v3-public/authtokens | grep uuid | wc -l) = 1 ]; do sleep 2;	echo -e -n ".";	done
	@printf "Rancher installed, now onto bootstrapping...\n";
	@$(MAKE) rancher-bootstrap

rancher-bootstrap:
	@printf "\n====> Bootstrapping Rancher\n";
	@kubectx $(HARVESTER_RANCHER_CLUSTER_NAME)
	@printf "\nRancher password: ${RANDOM_PASSWORD}\n";
	@curl -sk https://${RANCHER_URL}/v3/users?action=changepassword -H 'content-type: application/json' -H "Authorization: Bearer $$(curl -sk -X POST https://${RANCHER_URL}/v3-public/localProviders/local?action=login -H 'content-type: application/json' -d '{"username":"admin","password":"admin"}' | jq -r '.token')" -d '{"currentPassword":"admin","newPassword":"'${RANDOM_PASSWORD}'"}'  > /dev/null 2>&1 
	@curl -sk https://${RANCHER_URL}/v3/settings/server-url -H 'content-type: application/json' -H "Authorization: Bearer $$(curl -sk -X POST https://${RANCHER_URL}/v3-public/localProviders/local?action=login -H 'content-type: application/json' -d '{"username":"admin","password":"${RANDOM_PASSWORD}"}' | jq -r '.token')" -X PUT -d '{"name":"server-url","value":"https://${RANCHER_URL}"}'  > /dev/null 2>&1
	@curl -sk https://${RANCHER_URL}/v3/settings/telemetry-opt -X PUT -H 'content-type: application/json' -H 'accept: application/json' -H "Authorization: Bearer $$(curl -sk -X POST https://${RANCHER_URL}/v3-public/localProviders/local?action=login -H 'content-type: application/json' -d '{"username":"admin","password":"${RANDOM_PASSWORD}"}' | jq -r '.token')" -d '{"value":"out"}' > /dev/null 2>&1
	@curl -sk https://${RANCHER_URL}/v1/catalog.cattle.io.clusterrepos -H 'content-type: application/json' -H "Authorization: Bearer $$(curl -sk -X POST https://${RANCHER_URL}/v3-public/localProviders/local?action=login -H 'content-type: application/json' -d '{"username":"admin","password":"${RANDOM_PASSWORD}"}' | jq -r '.token')" -d '{"type":"catalog.cattle.io.clusterrepo","metadata":{"name":"rancher-ui-plugins"},"spec":{"gitBranch":"main","gitRepo":"https://github.com/rancher/ui-plugin-charts"}}' > /dev/null 2>&1
	@curl -sk https://${RANCHER_URL}/v1/catalog.cattle.io.clusterrepos/rancher-charts?action=install -H 'content-type: application/json' -H "Authorization: Bearer $$(curl -sk -X POST https://${RANCHER_URL}/v3-public/localProviders/local?action=login -H 'content-type: application/json' -d '{"username":"admin","password":"${RANDOM_PASSWORD}"}' | jq -r '.token')" -d '{"charts":[{"chartName":"ui-plugin-operator-crd","version":"101.0.0+up0.1.0","releaseName":"ui-plugin-operator-crd","annotations":{"catalog.cattle.io/ui-source-repo-type":"cluster","catalog.cattle.io/ui-source-repo":"rancher-charts"},"values":{"global":{"cattle":{"systemDefaultRegistry":"rgcrprod.azurecr.us"}}}}],"wait":true,"namespace":"cattle-ui-plugin-system"}'
	@curl -sk https://${RANCHER_URL}/v1/catalog.cattle.io.clusterrepos/rancher-charts?action=install -H 'content-type: application/json' -H "Authorization: Bearer $$(curl -sk -X POST https://${RANCHER_URL}/v3-public/localProviders/local?action=login -H 'content-type: application/json' -d '{"username":"admin","password":"${RANDOM_PASSWORD}"}' | jq -r '.token')" -d '{"charts":[{"chartName":"ui-plugin-operator","version":"101.0.0+up0.1.0","releaseName":"ui-plugin-operator","annotations":{"catalog.cattle.io/ui-source-repo-type":"cluster","catalog.cattle.io/ui-source-repo":"rancher-charts"},"values":{"global":{"cattle":{"systemDefaultRegistry":"rgcrprod.azurecr.us"}}}}],"wait":true,"namespace":"cattle-ui-plugin-system"}'
	@kubectl create ns carbide-stigatron-system --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create ns carbide-stigatron-system --dry-run=client -o yaml | kubectl apply -f -
	@sleep 10
	@helm install -n carbide-stigatron-system --create-namespace stigatron-ui $(BOOTSTRAP_DIR)/rancher/stigatron-ui-0.1.20.tgz

rancher-delete: rancher-destroy
rancher-destroy: check-tools
	@printf "\n====> Destroying RKE2 + Rancher\n";
	@kubectx ${HARVESTER_CONTEXT}
	@$(MAKE) _terraform-destroy COMPONENT=rancher VARS='TF_VAR_carbide_username="$(CARBIDE_USER)" TF_VAR_carbide_password="$(CARBIDE_PASSWORD)" TF_VAR_target_network_name=$(RANCHER_TARGET_NETWORK) TF_VAR_harvester_rke2_image_name=$(shell kubectl get virtualmachineimage -o yaml | yq -e '.items[]|select(.spec.displayName=="$(RKE2_IMAGE_NAME)")' - | yq -e '.metadata.name' -)'
	@kubecm delete $(HARVESTER_RANCHER_CLUSTER_NAME) || true

cloud-provider-creds: check-tools
	@printf "\n===> Creating Cloud Provider creds for all nodes\n";
	@kubectx ${HARVESTER_RANCHER_CLUSTER_NAME}
	@curl -sk -X POST https://$(RANCHER_URL)/k8s/clusters/$$(kubectl get clusters.management.cattle.io -o yaml | yq e '.items[] | select(.metadata.labels."provider.cattle.io" == "harvester")'.metadata.name)/v1/harvester/kubeconfig \
	-H 'Content-Type: application/json' \
	-H "Authorization: Bearer $(shell curl -sk -X POST https://${RANCHER_URL}/v3-public/localProviders/local?action=login -H 'content-type: application/json' -d '{"username":"admin","password":"${PASSWORD}"}' | jq -r '.token')" \
	-d '{"clusterRoleName": "harvesterhci.io:cloudprovider", "namespace": "default", "serviceAccountName": "deathstar"}' | xargs | sed 's/\\n/\n/g' > deathstar-kubeconfig
	@kubectl create secret generic services-shared-cloudprovider -n fleet-default --from-file=credential=deathstar-kubeconfig  --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic devfluffymunchkin-cloudprovider -n fleet-default --from-file=credential=deathstar-kubeconfig  --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic devedgerunner-cloudprovider -n fleet-default --from-file=credential=deathstar-kubeconfig  --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic prodblue-cloudprovider -n fleet-default --from-file=credential=deathstar-kubeconfig  --dry-run=client -o yaml | kubectl apply -f -
	@kubectl annotate secret services-shared-cloudprovider -n fleet-default --overwrite v2prov-secret-authorized-for-cluster='services-shared'
	@kubectl annotate secret devedgerunner-cloudprovider -n fleet-default --overwrite v2prov-secret-authorized-for-cluster='dev-edgerunner'
	@kubectl annotate secret devfluffymunchkin-cloudprovider -n fleet-default --overwrite v2prov-secret-authorized-for-cluster='dev-fluffymunchkin'
	@kubectl annotate secret prodblue-cloudprovider -n fleet-default --overwrite v2prov-secret-authorized-for-cluster='prod-blue'
	@rm deathstar-kubeconfig

# gitops targets
# this only works if harvester cluster has been imported
_CLUSTER_NAME = $(shell kubectl get cluster deathstar -n fleet-default -o yaml | yq -e '.status.clusterName' | tr -d '\n' | base64)
_SECRET_NAME = $(shell kubectl get secret -n cattle-global-data -o yaml | yq -e '.items[] | select(.data.harvestercredentialConfig-clusterId == '\"$(_CLUSTER_NAME)\"')' | yq -e .metadata.name)
workloads-check: check-tools
	@printf "\n===> Synchronizing Workloads with Fleet (dry-run)\n";
	@kubectx $(HARVESTER_RANCHER_CLUSTER_NAME)
	@ytt -f $(WORKLOAD_DIR) | kapp deploy -a $(WORKLOADS_KAPP_APP_NAME) -n $(WORKLOADS_NAMESPACE) -f - 

workloads-yes: 
	@printf "\n===> Synchronizing Workloads with Fleet\n";
	@kubectx ${HARVESTER_RANCHER_CLUSTER_NAME}
	@kubectl get secret -n cattle-global-data $(_SECRET_NAME) -o yaml | yq -e '.metadata.name = $(HARVESTER_CONTEXT)' | yq -e '.metadata.annotations."field.cattle.io/name" = $(HARVESTER_CONTEXT)' - | kubectl apply -f - || true
	@ytt -f $(WORKLOAD_DIR) | kapp deploy -a $(WORKLOADS_KAPP_APP_NAME) -n $(WORKLOADS_NAMESPACE) -f - -y 

workloads-destroy: workloads-delete
workloads-delete: check-tools
	@printf "\n===> Deleting Workloads with Fleet\n";
	@kubectx $(HARVESTER_RANCHER_CLUSTER_NAME)
	@kapp delete -a $(WORKLOADS_KAPP_APP_NAME) -n $(WORKLOADS_NAMESPACE)

status: check-tools
	@printf "\n===> Inspecting Running Workloads in Fleet\n";
	@kubectx ${HARVESTER_RANCHER_CLUSTER_NAME}
	@kapp inspect -a $(WORKLOADS_KAPP_APP_NAME) -n $(WORKLOADS_NAMESPACE)

# downstream
carbide-license: check-tools
	@printf "\n===>Creating Carbide License\n";
	@printf "Copy-paste this into your target cluster shell:\nkubectl create namespace carbide-stigatron-system; kubectl create secret generic stigatron-license -n carbide-stigatron-system --from-literal=license=${CARBIDE_LICENSE} --dry-run=client -o yaml | kubectl apply -f -\n"

# terraform sub-targets (don't use directly)
_terraform: check-tools
	@kubectx ${HARVESTER_CONTEXT}
	@$(VARS) terraform -chdir=${TERRAFORM_DIR}/$(COMPONENT) init
	@$(VARS) terraform -chdir=${TERRAFORM_DIR}/$(COMPONENT) apply
_terraform-init: check-tools
	@kubectx ${HARVESTER_CONTEXT}
	@$(VARS) terraform -chdir=${TERRAFORM_DIR}/$(COMPONENT) init
_terraform-apply: check-tools
	@kubectx ${HARVESTER_CONTEXT}
	@$(VARS) terraform -chdir=${TERRAFORM_DIR}/$(COMPONENT) apply
_terraform-value: check-tools
	@kubectx ${HARVESTER_CONTEXT}
	@terraform -chdir=${TERRAFORM_DIR}/$(COMPONENT) output -json | jq -r '$(FIELD)'
_terraform-destroy: check-tools
	@kubectx ${HARVESTER_CONTEXT}
	@$(VARS) terraform -chdir=${TERRAFORM_DIR}/$(COMPONENT) destroy