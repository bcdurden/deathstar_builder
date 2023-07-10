# Deathstar Build Repo

This repo exists to build my deathstar kit from start to finish. I'm focusing on component-based automation where various pieces can be re-used like lego blocks elsewhere as well as importing components written for other purposes. Most steps host secrets on my encrypted USB drive so I do not share them on github.

## Order of Operations
* From a fresh harvester install, the kubeconfig needs to be pulled down and added to a context named `deathstar`.
* Install cert-manager and create let's encrypt certs by using `make certs`
* Create the infrastructure necessary by running `make infra AIRGAP_IMAGE_HOST_IP=my_macbook_ip`. Ensure a terminal window is hosting my USB file share over http
* Open Harbor URL to ensure it is up and running.
* Create Harbor projects `rancher`, `carbide`, `jetstack`, `hashicorp`, `keycloak`, `grafana`, and `goharbor`
* Push images to it from USB storage using `make push-images IMAGES_FILE=<tarball on usb drive> REGISTRY_PASSWORD=<admin password>` and repeat until all images are pushed
* Either upload existing charts or download new charts (see pull_charts)