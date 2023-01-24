# EL8000 Infrastructure Demo
This document will contain a basic explanation of how to utilize them demo and some of the ideas it represents. 

With this repo, you can deploy an entire demo infrastructure onto the EL8000 with Harvester in an airgap. Getting to this point requires some prep. There is a prep stage where public internet is required (to prep Harvester and pull container images into an artifact). Once these steps have been completed and Harvester is installed/running, the environment can be torn down and rebuilt at will with no internet access.

## Required Tools
Building out the demo it is a series of stages. In the initial stage, you'll need a set of tools installed on your workstation.
For now that list is:
`kubectl cosign helm terraform kubectx kubecm ytt yq jq`

This list is enforced in the Makefile

## Demo Equipment List
* EL8000
* Network Switch (managed or unmanaged is fine -- keep in mind the backplane of Harvester is where Longhorn runs, so the more bandwidth available, the better)
* OpenWRT device for routing/wifi needs (currently this is a Beryl unit, and the configurations here might slightly different depending on your verison)
* Workstation with Wifi used for bootstrapping
* Any wifi devices to be used for viewing dashboards

# Getting Started
Installing Harvester is a pre-req here and this document won't cover that here. This demo will use a Makefile to run Terraform against the Harvester cluster in order to create resources. It also provides several utility features for pulling Rancher container images and pushing them into an airgapped registry as well as building infrastructure components like base images, networks, a Harbor image registry, and a gitea repo service.

The main resources it creates is an air-gapped HA-RKE2 cluster and installing Rancher MCM onto it. In the end it also appends your kubeconfig to contain the new RKE2 kubeconfig. It also provides the ability to tear everything back down.

The Terraform code is located in `terraform/` and the Rancher-specific code is in `terraform/rancher`.

## Network Configuration Considerations
Harvester utilizes VLANs to map networks to VMs and this implementation requires DHCP CIDR ranges per VLAN. Due to how network traffic will flow and how DHCP traffic may be queried, a hardware-based or more real-time based solution is required. 

A VM to manage DHCP and VLAN traffic exeternally is not going to be capable of handling the amount of traffic necessary. Harvester does not use VLANs for hardware-based network separation but does require the upstream switch/router solution to allow traffic to pass. 

It's best to configure open traffic between VLANs with firewall rules. In a more production environment, we'd lock things down further where VLANs 6-8 could not communicate with each other as well as define a LoadBalancing VIP pool on another VLAN entirely.

### VLANs and DHCP
Underhood, Harvester relies on the networking stack to trunk VLANs in hybrid mode. It is also greatly preferred to have DHCP per VLAN with different cidr ranges for network separation. Configure your DHCP servers to listen on appropriate VLANs and provide DHCP addresses in the ranges specified below:

|Name 	|VLAN 	|CIDR 	|DHCP Range   	| Total Dynamic IPs  	|
|---	|---	|---	|---	|---	|
|Management   	|-   	|10.11.0.0/24   	|10.11.0.50-254   	|204   	|
|Services   	|5   	|10.11.5.0/24   	|10.11.5.50-254   	|204   	|
|Sandbox   	|6   	|10.11.16.0/20   	|10.11.16.50-10.11.31.254   	|4044   	|
|Dev   	|7   	|10.11.32.0/20   	|10.11.32.50-10.11.47.254   	|4044   	|
|Prod   	|8   	|10.11.48.0/20   	|10.11.48.50-10.11.63.254   	|4044   	|


## Harvester Configuration
When configuring the EL8000 Harvester installation, there are a few key configuration items that need to happen. The EL8000 is a 4-node device and each node will need to have the correct configuration.
* Each Harvester node should use a static VIP (the last step of configuration) in the `10.11.0.4-50` range
* Each Harvester node should have the management NIC defined using the 1Gbps interface
* Each Harvester node should have the vlan network NIC defined using a 10Gbps interface
* There's a possibility that private X509 self-signed certs become a problem, certs have been generated or can be generated to ensure this isn't the case. Paste the certificate data into the appropriate configuration field post-install

# Order of Operations
What follows below is a high-level order of tasks to be performed in order to deploy inside an airgap.

> * [Grab Harvester Kubeconfig](#grab-harvester-kubeconfig)
> * [Prep Makefile](#prep-makefile)
> * [Build Jumpbox](#build-jumpbox)
> * [Pulling Containers](#pulling-containers)
> * [Build Harbor and Gitea](#build-harbor-and-gitea)
> * [Pushing Images](#pushing-images)
> * [Pushing Images](#pushing-images)

## Grab Harvester Kubeconfig
The Harvester kubeconfig can be downloaded via the `Support` menu. This link is located in the bottom left of the UI and there will then be a button that says `Download Kubeconfig`. This will download a file to your local workstation called `local.yaml`. Copy this to your local directory, rename it to `harvester.yaml`, and use `kubecm` to integrate it into your kubeconfig. `kubecm` will automatically name the kubecontext based on the filename, but you can change it to whatever you want using the tool.
```bash
kubecm add -f harvester.yaml
```

## Prep Makefile
Prepping the makefile is mostly straight-forward. The only parts that need to be updated are some of the variables up top as they will differ between environments. The values below will need to be changed to reflect your environment. URLs are used by Rancher for Ingress, so both DNS and URLs are pretty necessary.
```bash
# Harvester and DNS bits
BASE_URL=mustafar.lol
```

## Build Infra
There is an infra stage that now needs to be installed. This creates the base level Harvester networking components as well as pulling down a base Ubuntu 20.04 image. You can tweak these to your liking within `terraform/infra`. But be aware that changing the names of these resources may have repurcussions in other Terraform code that is dependent upon it.

Use `make infra` to deploy these components

TODO
```console
result here
```

## Build Jumpbox
If you don't already have the Rancher images on a USB drive, you'll need to pull them down. A jumpbox is necessary to pull down the hardened Carbide images for Rancher as well as other product images from the public cloud. The jumpbox is easy to setup and can be provisioned using `make jumpbox`. Choose 'yes' when the Terraform command prompts for it.

See the output of this command to get the key location and IP address of the jumpbox. Use `ssh -i terraform/jumpbox/jumpbox ubuntu@IP`

```console
Terraform will perform the following actions:

  # harvester_virtualmachine.jumpbox will be created
  + resource "harvester_virtualmachine" "jumpbox" {
      + cpu                  = 2
      + description          = "Jumpbox VM"
      + efi                  = false
      + hostname             = "jumpbox"
      + id                   = (known after apply)
      + machine_type         = "q35"
      + memory               = "4Gi"
...
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

local_sensitive_file.jumpbox_key_pem: Creating...
local_sensitive_file.jumpbox_key_pem: Creation complete after 0s [id=b10da6327cc1fc7bc68250993a5334db6f5e6172]
harvester_virtualmachine.jumpbox: Creating...
harvester_virtualmachine.jumpbox: Still creating... [2m0s elapsed]
harvester_virtualmachine.jumpbox: Still creating... [2m10s elapsed]
harvester_virtualmachine.jumpbox: Still creating... [2m20s elapsed]
harvester_virtualmachine.jumpbox: Creation complete after 2m29s [id=default/ubuntu-jumpbox]
...
> ssh -i terraform/jumpbox/jumpbox ubuntu@10.10.5.25
Welcome to Ubuntu 20.04.5 LTS (GNU/Linux 5.4.0-135-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Thu Jan 19 21:45:23 UTC 2023

  System load:  0.0                Processes:               143
  Usage of /:   1.3% of 193.65GB   Users logged in:         0
  Memory usage: 8%                 IPv4 address for enp1s0: 10.10.5.25
  Swap usage:   0%

...

To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

ubuntu@jumpbox:~$ 
```

Follow this up by copying your local git directory to the jumpbox ubuntu user. We use this to pull all Rancher and application images to deploy to Harbor.

```console
> tar czvf ../el8000_internal.tgz .
a .
a ./terraform
a ./bootstrap
a ./images
a ./Makefile
a ./charts
a ./README.md
a ./.gitignore
...
> scp -i terraform/jumpbox/jumpbox ../el8000_internal.tgz ubuntu@10.10.5.25:./
el8000_internal.tgz                                                                                                100%   44MB  49.7MB/s   00:00   
> rm ../el8000_internal.tgz
```

FYI: the next few steps can be done in parallel, and you'll likely want to as pulling the image can take a long time unless you have them on a USB keydrive!

## Pulling Containers
Pulling the containers is a simple command. This will create two artifacts, one called `cert-manager-images.tar.gz` and the other is `rancher-images.tar.gz`. If you are in a hard airgap, you'll need to copy these images to physical media and get them into the airgap. This pull will take a while, you can run the next command in parallel in a different session.
```bash
make pull-rancher
```

Other images can be pulled down using the `pull-misc` target.
```bash
make pull-misc
```

In the end, all containers are placed in /tmp so do not reboot the jumpbox until you have uploaded them or saved them to physical media.

## Build Harbor and Gitea
The demo functions by hosting infra-level dependencies in Harvester's cluster (as opposed to another RKE2 cluster). This allows us to treat Harvester as true infrastructure. Harbor and Gitea are easy to install and also require creation of let's encrypt certs.

Have a chat with Adam Toy to get the needed cloudflare token if you are using the `mustafar.lol` domain.

### Certs
Using `make certs CLOUDFLARE_TOKEN='my_token'` is the command to use in order to provision the `mustafar.lol` domain certs for all the services we intend to use in the Harvester Ingress.

### Harbor
Create Harbor by using `make registry`. Keep in mind the helm chart is stored locally, but the public cloud images are pulled for this. This is where we draw the line for chicken&egg (for now). Since Harbor runs inside Harvester, a true chicken/egg solution would need a way to cache images in Harvester proper, which is not currently supported. For now we just consider this as part of the prep of Harvester before putting it in an airgap.

Harbor is accessible from the `harbor.mustafar.lol` URL. See the helm chart values file in `bootstrap/harbor` for the default admin password.

Once Harbor is running, we'll need to prep Harbor by creating a few projects and uploading some Helm charts. Sign into Harbor and create these projects:

* rancher
* jetstack
* hashicorp
* longhornio
* grafana
* goharbor

After they are created, the helm charts located in `bootstrap/rancher` will need to be uploaded into each requisite project. The mapping is:

* cert-manager-v1.8.1.tgz -> jetstack
* consul-0.39.0.tgz -> hashicorp
* vault-0.22.0.tgz -> hashicorp
* rancher-2.7.0.tgz -> rancher
* kubewarden-* -> rancher
* neuvector-* -> rancher
* longhorn-1.3.1.tgz -> longhornio
* loki-stack-2.8.3.tgz -> grafana

With that, we're done prepping Harbor.

### Gitea
Similarly to Harbor, using `make git` will install gitea.

Gitea is accessible from the `git.mustafar.lol` URL. See the GIT_ADMIN_PASSWORD variable in `Makefile` to see the default admin password.

## Pushing Images
After downloading the images, they will all be located in the /tmp directory on the jumpbox. We can upload them from there. If you have them on a USB key drive already, you can run this command from your local workstation instead, just be aware the pathing will be different!

Pushing the containers is done against your image registry. In order to prevent hardcoding passwords, we deliberately keep the password variable in the Makefile empty so we are forced to use it at the command-line and not accidentally store the password into version control.

To push the images, you'll use the command below. Keep in mind, you'll do this many times, once for `cert-manager-images.tar.gz` and once for `rancher-images.tar.gz` as well as all the external images. This push can take a significant period of time as the artifact has to be decompressed and then invididually pushed. Best time to take coffee break!
```bash
make push-images REGISTRY_PASSWORD='my_password' IMAGES_FILE=/img/file/location.tar.gz
```

## Prep Harvester's Ubuntu OS Image
For a real airgap in Harvester, we need to ensure our bootstrap image contains all necessary binaries and packages in order to install RKE2 so that it does not need internet access at all. There are a variety of ways to make this image, Packer being the obvious one, but for now to make things easier, we're going to use `libguestfs` tools and build the image on the jumpbox.

To make this special image, we'll need to pull down the previously mentioned OS image to our jumpbox and then do some work upon it using `libguestfs` tools. This package is already installed in our jumpbox, so we'll work from there. This is slightly involved, but once finished, you'll have 80% of the manual steps above canned into a single image making it very easy to automate in an airgap. 

First pull the public cloud image down
```bash
wget http://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img
```

Before we get started, we'll need to expand the filesystem of the cloud image because some of the files we are downloading are a little large. I'm using 3 gigs here, but if you're going to install something large like nvidia-drivers, use as much space as you like. We'll condense the image back down later.
```bash
sudo virt-filesystems --long -h --all -a ubuntu-20.04-server-cloudimg-amd64.img
truncate -r ubuntu-20.04-server-cloudimg-amd64.img ubuntu-rke2.img
truncate -s +3G ubuntu-rke2.img
sudo virt-resize --expand /dev/sda1 ubuntu-20.04-server-cloudimg-amd64.img ubuntu-rke2.img

```

Unfortunately `virt-resize` will also rename the partitions, which will screw up the bootloader. We now have to fix that by using virt-rescue and calling grub-install on the disk.

Start the `virt-rescue` app like this:
```bash
sudo virt-rescue ubuntu-rke2.img 
```

And then paste these commands in after the rescue app finishes starting:
```bash
mkdir /mnt
mount /dev/sda3 /mnt
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
chroot /mnt
grub-install /dev/sda
```

After that you can exit hitting `ctrl ]` and then hitting `q`.
```console
sudo virt-rescue ubuntu-rke2.img 
WARNING: Image format was not specified for '/home/ubuntu/ubuntu-rke2.img' and probing guessed raw.
         Automatically detecting the format is dangerous for raw images, write operations on block 0 will be restricted.
         Specify the 'raw' format explicitly to remove the restrictions.
Could not access KVM kernel module: No such file or directory
qemu-system-x86_64: failed to initialize KVM: No such file or directory
qemu-system-x86_64: Back to tcg accelerator
supermin: mounting /proc
supermin: ext2 mini initrd starting up: 5.1.20
...

The virt-rescue escape key is ‘^]’.  Type ‘^] h’ for help.

------------------------------------------------------------

Welcome to virt-rescue, the libguestfs rescue shell.

Note: The contents of / (root) are the rescue appliance.
You have to mount the guest’s partitions under /sysroot
before you can examine them.

groups: cannot find name for group ID 0
><rescue> mkdir /mnt
><rescue> mount /dev/sda3 /mnt
><rescue> mount --bind /dev /mnt/dev
><rescue> mount --bind /proc /mnt/proc
><rescue> mount --bind /sys /mnt/sys
><rescue> chroot /mnt
><rescue> grub-install /dev/sda
Installing for i386-pc platform.
Installation finished. No error reported.
```

Now we can inject both packages as well as run commands within the context of the image. We'll borrow some of the manual provisioning steps above and copy those pieces into the image. The run-command will do much of what our `pull_rke2` script was doing but focused around pulling binaries and install scripts. We will create the configurations for these items using cloud-init in later steps.

```bash
sudo virt-customize -a ubuntu-rke2.img --install qemu-guest-agent
sudo virt-customize -a ubuntu-rke2.img --run-command "mkdir -p /var/lib/rancher/rke2-artifacts && wget https://get.rke2.io -O /var/lib/rancher/install.sh && chmod +x /var/lib/rancher/install.sh"
sudo virt-customize -a ubuntu-rke2.img --run-command "wget https://kube-vip.io/k3s -O /var/lib/rancher/kube-vip-k3s && chmod +x /var/lib/rancher/kube-vip-k3s"
sudo virt-customize -a ubuntu-rke2.img --run-command "mkdir -p /var/lib/rancher/rke2/server/manifests && wget https://kube-vip.io/manifests/rbac.yaml -O /var/lib/rancher/rke2/server/manifests/kube-vip-rbac.yaml"
sudo virt-customize -a ubuntu-rke2.img --run-command "cd /var/lib/rancher/rke2-artifacts && curl -sLO https://github.com/rancher/rke2/releases/download/v1.24.8+rke2r1/rke2.linux-amd64.tar.gz"
sudo virt-customize -a ubuntu-rke2.img --run-command "cd /var/lib/rancher/rke2-artifacts && curl -sLO https://github.com/rancher/rke2/releases/download/v1.24.8+rke2r1/sha256sum-amd64.txt"
sudo virt-customize -a ubuntu-rke2.img --run-command "cd /var/lib/rancher/rke2-artifacts && curl -sLO https://github.com/rancher/rke2/releases/download/v1.24.8+rke2r1/rke2-images.linux-amd64.tar.zst"
sudo virt-customize -a ubuntu-rke2.img --run-command "echo -n > /etc/machine-id"
```

If we look at the image we just created, we can see it is quite large!
```console
ubuntu@jumpbox:~$ ll ubuntu*
-rw-rw-r-- 1 ubuntu ubuntu  637927424 Dec 13 22:16 ubuntu-20.04-server-cloudimg-amd64.img
-rw-rw-r-- 1 ubuntu ubuntu 3221225472 Dec 19 14:40 ubuntu-rke2.img
```

We need to shrink it back using virt-sparsify. This looks for any unused space (most of what we expanded) and then removes that from the physical image. Along the way we'll want to convert and then compress this image:
```bash
sudo virt-sparsify --convert qcow2 --compress ubuntu-rke2.img ubuntu-rke2-airgap-harvester.img
```

Example of our current image and cutting the size in half:
```console
ubuntu@jumpbox:~$ sudo virt-sparsify --convert qcow2 --compress ubuntu-rke2.img ubuntu-rke2-airgap-harvester.img
[   0.0] Create overlay file in /tmp to protect source disk
[   0.0] Examine source disk
 100% ⟦▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒⟧ --:--
[  14.4] Fill free space in /dev/sda2 with zero
 100% ⟦▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒⟧ --:--
[  17.5] Fill free space in /dev/sda3 with zero
 100% ⟦▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒⟧ 00:00
[  21.8] Copy to destination and make sparse
[ 118.8] Sparsify operation completed with no errors.
virt-sparsify: Before deleting the old disk, carefully check that the 
target disk boots and works correctly.
ubuntu@jumpbox:~$ ll ubuntu*
-rw-rw-r-- 1 ubuntu ubuntu  637927424 Dec 13 22:16 ubuntu-20.04-server-cloudimg-amd64.img
-rw-r--r-- 1 root   root   1562816512 Dec 19 15:00 ubuntu-rke2-airgap-harvester.img
-rw-rw-r-- 1 ubuntu ubuntu 3221225472 Dec 19 14:40 ubuntu-rke2.img
```

What we have now is a customized image named `ubuntu-rke2-airgap-harvester.img` containing the RKE2 binaries and install scripts that we can later invoke in cloud-init. Let's upload this to Harvester now. The easiest way to upload into Harvester is host the image somewhere so Harvester can pull it. If you want to manually upload it from your web session, you stand the risk of it being interrupted by your web browser and having to start over.

Since my VM is hosted in my same harvester instance, I'm going to use a simple `python3` fileserver in my workspace directory:
```bash
python3 -m http.server 9900
```

See it running here:
```console
ubuntu@jumpbox:~$ python3 -m http.server 9900
Serving HTTP on 0.0.0.0 port 9900 (http://0.0.0.0:9900/) ...
```

From my web browser I can visit this URL at http://<my_jumpbox_ip>:9900 and 'copy link' on the `ubuntu-rke2-airgap-harvester.img` file.

![filehost](images/filehost.png)

And then create a new Harvester image and paste the URL into the field. Ensure the name of the image matches what you specified in your `Makefile` as this image is what will be used to bootstrap RKE2. The file should download quickly here as the VM is co-located on the Harvester box so it is effectively a local network copy.

![filehost](images/createimage.png)
![images](images/images.png)

# Post Harvester Prep Steps
From this point, we don't need public internet any longer. So the Harvester instance and hardware can be taken into an airgap as necessary. Technically, the push images step can also be done inside the gap if you download the images onto physical media.

All that remains after this point is installation of Rancher itself.

## Rancher Manager Installation
Rancher Manager is installed via Terraform and uses a set of modules that will build out an airgapped RKE2 cluster. Many configurations are defaulted, but the control-plane and worker node counts are defaulted in the Makefile allowing you to control them based on desired state. If you wish to alter the per-node VM compute/memory allocations, please see the `terraform/rancher/variables.tf` file and make adjustments to defaults where necessary. This is not a typical production setup so there is no tfvars file, this keep things clean and portable.

See the `Makefile` at the top for a list of RKE2 variables that can be used when using the `rancher` target.

Deploy Rancher using `make rancher` with any args defined after, or none if you want default values. This command will create an RKE2 cluster within the Harvester cluster and install Rancher upon it. After finishing it will pull the kubeconfig down into your local kubecontext and install a TLS certificate on it.

```console
> make rancher RANCHER_WORKER_COUNT=1 RKE2_VIP=10.11.5.4 HARVESTER_CONTEXT=my-harvester

====> Terraforming RKE2 + Rancher
Switched to context "my-harvester".
/Library/Developer/CommandLineTools/usr/bin/make terraform COMPONENT=rancher VARS='TF_VAR_harbor_url="harbor.mustafar.lol" TF_VAR_rancher_server_dns="rancher.mustafar.lol" TF_VAR_master_vip="10.11.5.4" TF_VAR_harbor_url="harbor.mustafar.lol" TF_VAR_worker_count=1 TF_VAR_control_plane_ha_mode=false TF_VAR_node_disk_size="20Gi"'
Switched to context "my-harvester".
Initializing modules...

...

tls_private_key.global_key: Creating...
tls_private_key.global_key: Creation complete after 0s [id=f2c24ab5b2ef91f5c52f902467786dfce6d95c11]
module.controlplane-nodes.harvester_virtualmachine.node-main: Creating...
module.controlplane-nodes.harvester_virtualmachine.node-main: Still creating... [50s elapsed]
module.controlplane-nodes.harvester_virtualmachine.node-main: Provisioning with 'remote-exec'...
module.controlplane-nodes.harvester_virtualmachine.node-main (remote-exec): Connecting to remote host via SSH...
module.controlplane-nodes.harvester_virtualmachine.node-main (remote-exec):   Host: 10.11.5.219
module.controlplane-nodes.harvester_virtualmachine.node-main (remote-exec):   User: ubuntu
module.controlplane-nodes.harvester_virtualmachine.node-main (remote-exec):   Password: false
module.controlplane-nodes.harvester_virtualmachine.node-main (remote-exec):   Private key: true
module.controlplane-nodes.harvester_virtualmachine.node-main (remote-exec):   Certificate: false
module.controlplane-nodes.harvester_virtualmachine.node-main (remote-exec):   SSH Agent: true
module.controlplane-nodes.harvester_virtualmachine.node-main (remote-exec):   Checking Host Key: false
module.controlplane-nodes.harvester_virtualmachine.node-main (remote-exec):   Target Platform: unix
module.controlplane-nodes.harvester_virtualmachine.node-main: Still creating... [1m0s elapsed]
module.controlplane-nodes.harvester_virtualmachine.node-main (remote-exec): Connected!
module.controlplane-nodes.harvester_virtualmachine.node-main (remote-exec): Waiting for cloud-init to complete...
module.controlplane-nodes.harvester_virtualmachine.node-main: Still creating... [1m10s elapsed]
module.controlplane-nodes.harvester_virtualmachine.node-main: Still creating... [1m20s elapsed]
module.controlplane-nodes.harvester_virtualmachine.node-main: Still creating... [1m30s elapsed]
module.controlplane-nodes.harvester_virtualmachine.node-main (remote-exec): Completed cloud-init!
module.controlplane-nodes.harvester_virtualmachine.node-main: Creation complete after 1m35s [id=default/rke2-mgmt-controlplane-0]
ssh_resource.retrieve_config: Creating...
module.worker.harvester_virtualmachine.node[0]: Creating...
ssh_resource.retrieve_config: Creation complete after 1s [id=5577006791947779410]
local_file.kube_config_server_yaml: Creating...
local_file.kube_config_server_yaml: Creation complete after 0s [id=1dc12cd2784bcf2c483b0f2eae3c15cb0ce4c8b5]
module.worker.harvester_virtualmachine.node[0]: Still creating... [1m0s elapsed]
module.worker.harvester_virtualmachine.node[0]: Provisioning with 'remote-exec'...
module.worker.harvester_virtualmachine.node[0] (remote-exec): Connecting to remote host via SSH...
module.worker.harvester_virtualmachine.node[0] (remote-exec):   Host: 10.11.5.64
module.worker.harvester_virtualmachine.node[0] (remote-exec):   User: ubuntu
module.worker.harvester_virtualmachine.node[0] (remote-exec):   Password: false
module.worker.harvester_virtualmachine.node[0] (remote-exec):   Private key: true
module.worker.harvester_virtualmachine.node[0] (remote-exec):   Certificate: false
module.worker.harvester_virtualmachine.node[0] (remote-exec):   SSH Agent: true
module.worker.harvester_virtualmachine.node[0] (remote-exec):   Checking Host Key: false
module.worker.harvester_virtualmachine.node[0] (remote-exec):   Target Platform: unix
module.worker.harvester_virtualmachine.node[0]: Still creating... [1m10s elapsed]
module.worker.harvester_virtualmachine.node[0] (remote-exec): Connected!
module.worker.harvester_virtualmachine.node[0] (remote-exec): Waiting for cloud-init to complete...
module.worker.harvester_virtualmachine.node[0] (remote-exec): Completed cloud-init!
module.worker.harvester_virtualmachine.node[0]: Creation complete after 1m16s [id=default/rke2-mgmt-worker-0]
helm_release.cert_manager: Creating...
helm_release.cert_manager: Still creating... [20s elapsed]
helm_release.cert_manager: Creation complete after 24s [id=cert-manager]
helm_release.rancher_server: Creating...
helm_release.rancher_server: Still creating... [1m10s elapsed]
helm_release.rancher_server: Creation complete after 1m13s [id=rancher]

Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:

kube = <sensitive>
ssh_key = <sensitive>
ssh_pubkey = <<EOT
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7QpnkfcaXro+dEHWwjK7zk5y0WoRcnsqvAS4csVV79AT38nQ+W6Uuix5z+LOpYsPad/xzZSX+n2qipLJZiNBxIEksXyjU3m5go1V4+Kb+hzL0t79yNy8SMdWaIMJgHp/tDQfJDXPtQ/FKkOJCGnnDvP/W18Wes3zPunXkMsXddDRTYnzJ8iuFq8UZ2z5gg3OSYOZ7iO8fXOMd1XJW/ynNvDZN3EGbRTZEWahcYnREGbl+/wnxXh93TYXSRZ5+lPSOAI4T/fwpoq3x0P58y7rAVRLoAQNBBleP+NhhWyBY8rdcdjh6v57Wk9xr+PUzt+7DFaHC5yewKRR0ZsKfQmTV

EOT
Add Context: rancher-el8000 
「/tmp/rancher-el8000.yaml」 write successful!
+------------+-------------------+-----------------------+--------------------+-----------------------------------+--------------+
|   CURRENT  |        NAME       |        CLUSTER        |        USER        |               SERVER              |   Namespace  |
+============+===================+=======================+====================+===================================+==============+
|      *     |    my-harvester   |   cluster-8c5g87ht4k  |   user-8c5g87ht4k  |   https://10.11.0.20/k8s/cluster  |    default   |
|            |                   |                       |                    |              s/local              |              |
+------------+-------------------+-----------------------+--------------------+-----------------------------------+--------------+
|            |   rancher-el8000  |   cluster-bfgk6bft59  |   user-bfgk6bft59  |       https://10.11.5.4:6443      |    default   |
+------------+-------------------+-----------------------+--------------------+-----------------------------------+--------------+

Switched to context "rancher-el8000".
secret/tls-rancher-ingress created
Switched to context "my-harvester".
```