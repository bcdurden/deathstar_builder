# PXE Booting Harvester

I was able to successfully PXE boot Harvester onto a Minisforum UM790 using iPXE using most of the instructions provided by Harvester docs. Unlike the Harvester docs, I did not have ISC DHCP running anywhere as I am using an OPNSense Internet Gateway to both manage DHCP as well as provide PXE services. It was important I do it in this manner as I needed everything to fit within my edge kit while having no additional PCs.

Not having ISC DHCP or a Tinkerbell stack and using OPNSense instead limits my ability to distinguish between MAC IDs in order to apply the correct harvester yaml configuration during boot time. Instead I placed a banner/menu so the user can choose whether to create or join.

## Process

* Hardware is configured to PXE boot and the network stack is enabled
* OPNSense is configured to run a TFTP server as a service with the iPXE image and boot scripts located in `/usr/local/tftp`, see [ipxe-create](./ipxe-create)
* OPNSense is configured to host HTTP Server and holds Harvester runtime images, configuration files, and iso
* boot script starts iPXE session and menu entries link to boot commands that pull runtime images from HTTP Server
* When iPXE runs a boot sequence, it pulls these images over HTTP and boots a Harvester install or join

## Future Expansion
What this looks like when hosted via Harvester Seeder / Tinkerbell, I am unsure. The menu makes sense from a bootstrap capability but some thought will need to be made around the scalability with hardcoded IPs.

## Result
After a custom build of iPXE, background images were enabled as well as console commands. Boot process yields this screen:
![ipxe-carbide](./ipxe_boot.png)