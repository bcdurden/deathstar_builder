# HowTo Provision Harvester with Tinkerbell

This will be an ongoing howto for adapting Tinkerbell Stack to Provision a Deathstar. There's several moving parts involved:

* Tinkerbell Stack in Kubernetes w/ custom Boots image and Deployment Adjustment
* HTTP Server hosting Harvester images
* Hardware object for each node


## Issues Discovered
The included Boots image with Tinkerbell Stack's helm chart has an embedded iPXE image that doesn't work properly or offer the same functionality that the open-source iPXE efi image does. 

This prevents Harvester from being PXE bootable via Boots by iPXE and the more sophisticated Workflow/Template/Actions mechanisms present within Tinkerbell need some custom actions for handling the new `zst` raw image released by the upstream Harvester team. It will image the hard drive just fine, but the next step in kickstarting an automated install is not possible. In other words, it's not quite there yet. This path is more preferrable as it allows vastly more flexible configuration options on the bare metal device.

The solution to this issue was to use a custom Boots image that has a new iPXE efi image embedded. This image is based on a slightly older version of Boots and has some slightly different commandline parameters that need to be altered to compensate.

Running Tink on a cluster that has an Ingress endpoint of `*` will cause problems with the TFTP and iPXE file hosting as Ingress with a `*` host entry pulls ALL TCP/UDP requests regardless of entry point. Multiple load balancers will not solve this problem. For this reason, I was not able to get this tink deployment working on an existing baremetal installation of Harvester. Instead, I created a 1-node RKE2 instance on the host network.

## Considerations

* Tinkerbell runs in a Kubernetes cluster. Ideally, one would use a 'bootstrap' cluster much like Rancher Desktop or KinD can provide. What will be key is having an LB to bind a static IP which can be done via kubevip
* PXE booting requires usage of UDP packets and TFTP. Typical Ingress within Kubernetes is not going to allow passing that traffic, so it's much easier to just use a LoadBalancer service type which will.
* An HTTP Server must be running somewhere on the host network to host the Harvester images (vmlinuz, initrd, rootfs, and iso)
* If you are hosting the bare metal device on a network that has DHCP, you'll need to add your MAC ID to the deny list of your DHCP server so it doesn't step over Tink/Boots
* If you plan on defining your Harvester config within a single yaml, you'll need to host that yaml somewhere as well (easy choice is the HTTP server you're already running)

With that, let's get to it!

## Tink Stack

From the Tink stack itself, the only things we need at this stage is Boots and the DHCP relay. In order to avoid complexity and manual editing of the Helm Chart for the above changes, I've pruned the needs down to a CRDs file and a deployment yaml file. They are located in the same directory as this markdown file. If you intend to replicate, you'll want to set the VIP to something static on your own host network (my IP in this case is `10.10.0.20`)

Example deployment:
```console
> kc apply -f crds.yaml -f deploy.yaml
customresourcedefinition.apiextensions.k8s.io/hardware.tinkerbell.org created
serviceaccount/boots created
serviceaccount/kube-vip created
clusterrole.rbac.authorization.k8s.io/boots-role created
clusterrole.rbac.authorization.k8s.io/kube-vip-role created
clusterrolebinding.rbac.authorization.k8s.io/boots-rolebinding created
clusterrolebinding.rbac.authorization.k8s.io/kube-vip-rolebinding created
service/boots created
daemonset.apps/kube-vip created
deployment.apps/boots created
deployment.apps/tink-stack-relay created
> kc get po -n tink-system
NAME                                READY   STATUS    RESTARTS   AGE
boots-78c467cfd-pfrzk               1/1     Running   0          10m
kube-vip-6zsdv                      1/1     Running   0          10m
tink-stack-relay-7d9c5bb674-nd9h6   1/1     Running   0          10m
> kc get svc -n tink-system
NAME    TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                                                AGE
boots   LoadBalancer   10.43.46.228   10.10.0.20    80:32209/TCP,514:30727/UDP,67:30628/UDP,69:32363/UDP   10m

```

## Hardware object
One of the several objects within the Tinkerbell system is the Hardware object. This object defines a real set of hardware to be referenced by detected MAC ID. In this local directory I have one defined and it matches the MAC ID on one of my mini PCs.

The fields included are named well and should be intuitive at a glance. The `userdata` field is mostly used as a suffix to an ipxe script fed into the Harvester bootloader. The `osie.baseURL` is a pointer to the HTTP host for the `vmlinuz` and `initrd` file. The resolved path becomes `<baseURL>/<instance.operating_system.version>/files` where `files` is the default names for the `vmlinuz`, `initrd`, and `rootfs` files as pulled from Harvester's release page on Github. Essentially, Boots uses the metadata entries for harvester to determine the subpath of the URL.

From there, the `userdata` field is used to feed the typical ipxe bootline. Keep in mind for UEFI that there needs to be an explicit `initrd` declaration. Harverster configuration can be named inline or the yaml file can be referenced as I do since I also host that on my HTTP server. Here is the spec I use:
```yaml
apiVersion: "tinkerbell.org/v1alpha1"
kind: Hardware
metadata:
  name: um790-1
  namespace: tink-system
spec:
  disks:
    - device: /dev/nvme0n1
  metadata:
    facility:
      facility_code: onprem
      plan_slug: c2.medium.x86
    manufacturer:
      slug: minisforum
    instance:
      operating_system:
        distro: harvester
        version: v1.2.0
      userdata: 'initrd=harvester-v1.2.0-initrd-amd64 ip=dhcp net.ifnames=1 rd.cos.disable rd.noverifyssl console=tty1 harvester.install.config_url=http://bootstrap.sienarfleet.systems/harvester/config-create.yaml'

  interfaces:
    - dhcp:
        arch: x86_64
        hostname: um790-1
        ip:
          address: 10.10.0.16
          gateway: 10.10.0.1
          netmask: 255.255.255.0
        lease_time: 86400
        mac: 58:47:ca:71:d8:49
        name_servers:
          - 10.10.0.1
        uefi: true
      netboot:
        allowPXE: true
        allowWorkflow: false
        osie:
          baseURL: http://10.10.0.2/harvester
```

When applied, there's little fanfare.
```console
> kc apply -f hardware.yaml
hardware.tinkerbell.org/um790-1 configured
```


## Watch It Spin
Now, you need to set your hardware to boot with PXE if you have not already. And ensure any DHCP listener you have configured on your host network is ignoring that MAC ID. For myself in OPNSense, I've added the above MAC ID to my ignore list for my LAN DHCP service. This way it is skipped and the Boots server will pick it up and assign instead.

If you want to watch it spin, you can stream the logs of the boots pod. After the hardware hits the PXE boot sequence, you should see traffic begin appearing. The auto.ipxe file is downloaded first and then once the host executes that and the bootscript, you'll see furhter traffic as it pulls the `vmlinuz`, `initrd`, and `rootfs` files. If all things are configured correctly, you should see Harvester boot and immediately begin installing on the bare metal display and the logs will look similar:

```console
> kc get po -n tink-system
NAME                                READY   STATUS    RESTARTS   AGE
boots-78c467cfd-pfrzk               1/1     Running   0          33m
kube-vip-6zsdv                      1/1     Running   0          33m
tink-stack-relay-7d9c5bb674-nd9h6   1/1     Running   0          33m
> kc logs -n tink-system boots-78c467cfd-pfrzk -f
{"level":"info","ts":1697051361.3023832,"caller":"boots/main.go:121","msg":"starting","service":"github.com/tinkerbell/boots","pkg":"main","version":"2a94169"}
{"level":"info","ts":1697051361.3844857,"caller":"boots/main.go:192","msg":"serving iPXE binaries from local HTTP server","service":"github.com/tinkerbell/boots","pkg":"main","addr":"10.10.0.20/ipxe/"}
{"level":"info","ts":1697051361.38455,"caller":"boots/main.go:212","msg":"serving dhcp","service":"github.com/tinkerbell/boots","pkg":"main","addr":"0.0.0.0:67"}
{"level":"info","ts":1697051361.3846068,"caller":"boots/main.go:219","msg":"serving http","service":"github.com/tinkerbell/boots","pkg":"main","addr":"0.0.0.0:80"}
{"level":"info","ts":1697051361.3849936,"logger":"github.com/tinkerbell/ipxedust","caller":"ipxedust@v0.0.0-20220406180840-46f16b8d8fb0/ipxedust.go:194","msg":"serving iPXE binaries via TFTP","service":"github.com/tinkerbell/boots","addr":"0.0.0.0:69","timeout":5,"singlePortEnabled":true}
{"level":"info","ts":1697051361.3850613,"caller":"boots/main.go:134","msg":"serving syslog","service":"github.com/tinkerbell/boots","pkg":"main","addr":"0.0.0.0:514"}


{"level":"info","ts":1697053442.7826712,"caller":"dhcp4-go@v0.0.0-20190402165401-39c137f31ad3/handler.go:105","msg":"","service":"github.com/tinkerbell/boots","pkg":"dhcp","pkg":"dhcp","event":"recv","mac":"58:47:ca:71:d8:49","via":"10.42.0.166","iface":"eth0","xid":"\"64:e2:d4:fe\"","type":"DHCPDISCOVER","option(82)":"AQltYWN2bGFuOTkFBAoKABQ="}
{"level":"info","ts":1697053442.7828143,"caller":"boots/dhcp.go:88","msg":"parsed option82/circuitid","service":"github.com/tinkerbell/boots","pkg":"main","mac":"58:47:ca:71:d8:49","circuitID":"macvlan"}
{"level":"info","ts":1697053442.7831402,"caller":"dhcp4-go@v0.0.0-20190402165401-39c137f31ad3/handler.go:61","msg":"","service":"github.com/tinkerbell/boots","pkg":"dhcp","pkg":"dhcp","event":"send","mac":"58:47:ca:71:d8:49","via":"10.42.0.166","iface":"eth0","xid":"\"64:e2:d4:fe\"","type":"DHCPOFFER","address":"10.10.0.16","next_server":"10.10.0.20","filename":"ipxe.efi","option(82)":"AQltYWN2bGFuOTkFBAoKABQ="}
{"level":"info","ts":1697053446.8016496,"caller":"dhcp4-go@v0.0.0-20190402165401-39c137f31ad3/handler.go:105","msg":"","service":"github.com/tinkerbell/boots","pkg":"dhcp","pkg":"dhcp","event":"recv","mac":"58:47:ca:71:d8:49","via":"10.42.0.166","iface":"eth0","xid":"\"64:e2:d4:fe\"","type":"DHCPREQUEST","option(82)":"AQltYWN2bGFuOTkFBAoKABQ="}
{"level":"info","ts":1697053446.8018413,"caller":"boots/dhcp.go:88","msg":"parsed option82/circuitid","service":"github.com/tinkerbell/boots","pkg":"main","mac":"58:47:ca:71:d8:49","circuitID":"macvlan"}
{"level":"info","ts":1697053446.8021653,"caller":"dhcp4-go@v0.0.0-20190402165401-39c137f31ad3/handler.go:61","msg":"","service":"github.com/tinkerbell/boots","pkg":"dhcp","pkg":"dhcp","event":"send","mac":"58:47:ca:71:d8:49","via":"10.42.0.166","iface":"eth0","xid":"\"64:e2:d4:fe\"","type":"DHCPACK","address":"10.10.0.16","next_server":"10.10.0.20","filename":"ipxe.efi","option(82)":"AQltYWN2bGFuOTkFBAoKABQ="}
{"level":"info","ts":1697053451.1982193,"logger":"github.com/tinkerbell/ipxedust","caller":"itftp/itftp.go:102","msg":"file served","service":"github.com/tinkerbell/boots","event":"get","filename":"ipxe.efi","uri":"ipxe.efi","client":{"IP":"10.10.0.16","Port":1202,"Zone":""},"macFromURI":"","bytesSent":1017856,"contentSize":1017856}
{"level":"info","ts":1697053463.8686192,"caller":"dhcp4-go@v0.0.0-20190402165401-39c137f31ad3/handler.go:105","msg":"","service":"github.com/tinkerbell/boots","pkg":"dhcp","pkg":"dhcp","event":"recv","mac":"58:47:ca:71:d8:49","via":"10.42.0.166","iface":"eth0","xid":"\"05:d7:92:6d\"","type":"DHCPDISCOVER","secs":16,"option(82)":"AQltYWN2bGFuOTkFBAoKABQ="}
{"level":"info","ts":1697053463.8687878,"caller":"boots/dhcp.go:88","msg":"parsed option82/circuitid","service":"github.com/tinkerbell/boots","pkg":"main","mac":"58:47:ca:71:d8:49","circuitID":"macvlan"}
{"level":"info","ts":1697053463.869053,"caller":"dhcp4-go@v0.0.0-20190402165401-39c137f31ad3/handler.go:61","msg":"","service":"github.com/tinkerbell/boots","pkg":"dhcp","pkg":"dhcp","event":"send","mac":"58:47:ca:71:d8:49","via":"10.42.0.166","iface":"eth0","xid":"\"05:d7:92:6d\"","type":"DHCPOFFER","address":"10.10.0.16","next_server":"10.10.0.20","filename":"http://10.10.0.20/auto.ipxe","option(82)":"AQltYWN2bGFuOTkFBAoKABQ="}
{"level":"info","ts":1697053463.8722122,"caller":"dhcp4-go@v0.0.0-20190402165401-39c137f31ad3/handler.go:105","msg":"","service":"github.com/tinkerbell/boots","pkg":"dhcp","pkg":"dhcp","event":"recv","mac":"58:47:ca:71:d8:49","via":"10.42.0.166","iface":"eth0","xid":"\"05:d7:92:6d\"","type":"DHCPREQUEST","secs":22,"option(82)":"AQltYWN2bGFuOTkFBAoKABQ="}
{"level":"info","ts":1697053463.8722563,"caller":"boots/dhcp.go:88","msg":"parsed option82/circuitid","service":"github.com/tinkerbell/boots","pkg":"main","mac":"58:47:ca:71:d8:49","circuitID":"macvlan"}
{"level":"info","ts":1697053463.8727465,"caller":"dhcp4-go@v0.0.0-20190402165401-39c137f31ad3/handler.go:61","msg":"","service":"github.com/tinkerbell/boots","pkg":"dhcp","pkg":"dhcp","event":"send","mac":"58:47:ca:71:d8:49","via":"10.42.0.166","iface":"eth0","xid":"\"05:d7:92:6d\"","type":"DHCPACK","address":"10.10.0.16","next_server":"10.10.0.20","filename":"http://10.10.0.20/auto.ipxe","option(82)":"AQltYWN2bGFuOTkFBAoKABQ="}
{"level":"info","ts":1697053463.9004097,"caller":"syslog/receiver.go:107","msg":"host=10.10.0.16 facility=kern severity=INFO app-name=um790-1 msg=\" ipxe:  ok\"","service":"github.com/tinkerbell/boots","pkg":"syslog"}
{"level":"info","ts":1697053463.9004989,"caller":"syslog/receiver.go:107","msg":"host=10.10.0.16 facility=kern severity=INFO app-name=um790-1 msg=\" ipxe: net0: 10.10.0.16/255.255.255.0 gw 10.10.0.1\"","service":"github.com/tinkerbell/boots","pkg":"syslog"}
{"level":"info","ts":1697053463.9005222,"caller":"syslog/receiver.go:107","msg":"host=10.10.0.16 facility=kern severity=INFO app-name=um790-1 msg=\" ipxe: net0: fe80::5a47:caff:fe71:d849/64\"","service":"github.com/tinkerbell/boots","pkg":"syslog"}
{"level":"info","ts":1697053463.9005632,"caller":"syslog/receiver.go:107","msg":"host=10.10.0.16 facility=kern severity=INFO app-name=um790-1 msg=\" ipxe: Next server: 10.10.0.20\"","service":"github.com/tinkerbell/boots","pkg":"syslog"}
{"level":"info","ts":1697053463.9005885,"caller":"syslog/receiver.go:107","msg":"host=10.10.0.16 facility=kern severity=INFO app-name=um790-1 msg=\" ipxe: Filename: http://10.10.0.20/auto.ipxe\"","service":"github.com/tinkerbell/boots","pkg":"syslog"}
{"level":"debug","ts":1697053465.6576567,"caller":"httplog/httplog.go:29","msg":"","service":"github.com/tinkerbell/boots","pkg":"http","event":"sr","method":"GET","uri":"/auto.ipxe","client":"10.10.0.16"}
{"level":"info","ts":1697053465.6577725,"caller":"job/job.go:144","msg":"discovering from ip","service":"github.com/tinkerbell/boots","ip":"10.10.0.16"}
{"level":"info","ts":1697053465.6579127,"caller":"kubernetes/reporter.go:137","msg":"found mac address","service":"github.com/tinkerbell/boots","mac":"58:47:ca:71:d8:49"}
{"level":"error","ts":1697053465.6633186,"caller":"job/events.go:40","msg":"disabling PXE: hardware.tinkerbell.org \"um790-1\" is forbidden: User \"system:serviceaccount:tink-system:boots\" cannot update resource \"hardware\" in API group \"tinkerbell.org\" in the namespace \"tink-system\"","service":"github.com/tinkerbell/boots","mac":"58:47:ca:71:d8:49","hardware.id":"","instance.id":"","error":"disabling PXE: hardware.tinkerbell.org \"um790-1\" is forbidden: User \"system:serviceaccount:tink-system:boots\" cannot update resource \"hardware\" in API group \"tinkerbell.org\" in the namespace \"tink-system\"","errorVerbose":"hardware.tinkerbell.org \"um790-1\" is forbidden: User \"system:serviceaccount:tink-system:boots\" cannot update resource \"hardware\" in API group \"tinkerbell.org\" in the namespace \"tink-system\"\ndisabling PXE"}
{"level":"error","ts":1697053465.663531,"caller":"job/events.go:131","msg":"postEvent called for nil instance","service":"github.com/tinkerbell/boots","mac":"58:47:ca:71:d8:49","hardware.id":"","instance.id":"","kind":"boots.warning","error":"postEvent called for nil instance","errorVerbose":"postEvent called for nil instance\ngithub.com/tinkerbell/boots/job.Job.postEvent\n\t/home/gaurav/go/src/github.com/tinkerbell/boots/job/events.go:131\ngithub.com/tinkerbell/boots/job.Job.Error\n\t/home/gaurav/go/src/github.com/tinkerbell/boots/job/logging.go:14\ngithub.com/tinkerbell/boots/job.Job.DisablePXE\n\t/home/gaurav/go/src/github.com/tinkerbell/boots/job/events.go:40\ngithub.com/tinkerbell/boots/installers/harvester.installer.BootScript.func1\n\t/home/gaurav/go/src/github.com/tinkerbell/boots/installers/harvester/main.go:24\ngithub.com/tinkerbell/boots/job.Installers.auto\n\t/home/gaurav/go/src/github.com/tinkerbell/boots/job/ipxe.go:113\ngithub.com/tinkerbell/boots/job.Job.serveBootScript\n\t/home/gaurav/go/src/github.com/tinkerbell/boots/job/ipxe.go:83\ngithub.com/tinkerbell/boots/job.Job.ServeFile\n\t/home/gaurav/go/src/github.com/tinkerbell/boots/job/http.go:19\nmain.(*jobHandler).serveJobFile\n\t/home/gaurav/go/src/github.com/tinkerbell/boots/cmd/boots/http.go:169\nnet/http.HandlerFunc.ServeHTTP\n\t/home/gaurav/go/src/net/http/server.go:2047\ngo.opentelemetry.io/contrib/instrumentation/net/http/otelhttp.WithRouteTag.func1\n\t/home/gaurav/go/pkg/mod/go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp@v0.21.0/handler.go:223\nnet/http.HandlerFunc.ServeHTTP\n\t/home/gaurav/go/src/net/http/server.go:2047\nnet/http.(*ServeMux).ServeHTTP\n\t/home/gaurav/go/src/net/http/server.go:2425\ngo.opentelemetry.io/contrib/instrumentation/net/http/otelhttp.(*Handler).ServeHTTP\n\t/home/gaurav/go/pkg/mod/go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp@v0.21.0/handler.go:179\ngithub.com/tinkerbell/boots/httplog.(*Handler).ServeHTTP\n\t/home/gaurav/go/src/github.com/tinkerbell/boots/httplog/httplog.go:33\ngithub.com/sebest/xff.(*XFF).Handler.func1\n\t/home/gaurav/go/pkg/mod/github.com/packethost/xff@v0.0.0-20190305172552-d3e9190c41b3/xff.go:133\nnet/http.HandlerFunc.ServeHTTP\n\t/home/gaurav/go/src/net/http/server.go:2047\nnet/http.serverHandler.ServeHTTP\n\t/home/gaurav/go/src/net/http/server.go:2879\nnet/http.(*conn).serve\n\t/home/gaurav/go/src/net/http/server.go:1930\nruntime.goexit\n\t/home/gaurav/go/src/runtime/asm_amd64.s:1581"}
{"level":"info","ts":1697053465.6636,"caller":"httplog/httplog.go:37","msg":"","service":"github.com/tinkerbell/boots","pkg":"http","event":"ss","method":"GET","uri":"/auto.ipxe","client":"10.10.0.16","duration":0.005969451,"status":200}
{"level":"info","ts":1697053465.6640134,"caller":"syslog/receiver.go:107","msg":"host=10.10.0.16 facility=kern severity=INFO app-name=um790-1 msg=\" ipxe: http://10.10.0.20/auto.ipxe.... ok\"","service":"github.com/tinkerbell/boots","pkg":"syslog"}
{"level":"info","ts":1697053465.6691122,"caller":"syslog/receiver.go:107","msg":"host=10.10.0.16 facility=kern severity=INFO app-name=um790-1 msg=\" ipxe: auto.ipxe : 854 bytes [script]\"","service":"github.com/tinkerbell/boots","pkg":"syslog"}
{"level":"info","ts":1697053465.6691554,"caller":"syslog/receiver.go:107","msg":"host=10.10.0.16 facility=kern severity=INFO app-name=um790-1 msg=\" ipxe: Tinkerbell Boots iPXE\"","service":"github.com/tinkerbell/boots","pkg":"syslog"}
{"level":"debug","ts":1697053465.6691537,"caller":"httplog/httplog.go:29","msg":"","service":"github.com/tinkerbell/boots","pkg":"http","event":"sr","method":"POST","uri":"/phone-home","client":"10.10.0.16"}
{"level":"info","ts":1697053465.6692002,"caller":"job/job.go:144","msg":"discovering from ip","service":"github.com/tinkerbell/boots","ip":"10.10.0.16"}
{"level":"info","ts":1697053465.669323,"caller":"job/events.go:102","msg":"ignoring hardware phone-home when state is not preinstalling","service":"github.com/tinkerbell/boots","mac":"58:47:ca:71:d8:49","hardware.id":"","instance.id":"","state":""}
{"level":"info","ts":1697053465.6694167,"caller":"httplog/httplog.go:37","msg":"","service":"github.com/tinkerbell/boots","pkg":"http","event":"ss","method":"POST","uri":"/phone-home","client":"10.10.0.16","duration":0.000263367,"status":200}
{"level":"info","ts":1697053465.672647,"caller":"syslog/receiver.go:107","msg":"host=10.10.0.16 facility=kern severity=INFO app-name=um790-1 msg=\" ipxe: http://10.10.0.20/phone-home... ok\"","service":"github.com/tinkerbell/boots","pkg":"syslog"}
{"level":"info","ts":1697053465.7185366,"caller":"syslog/receiver.go:107","msg":"host=10.10.0.16 facility=kern severity=INFO app-name=um790-1 msg=\" ipxe: http://10.10.0.2/harvester/v1.2.0/harvester-v1.2.0-vmlinuz-amd64... ok\"","service":"github.com/tinkerbell/boots","pkg":"syslog"}
{"level":"info","ts":1697053466.0292306,"caller":"syslog/receiver.go:107","msg":"host=10.10.0.16 facility=kern severity=INFO app-name=um790-1 msg=\" ipxe: http://10.10.0.2/harvester/v1.2.0/harvester-v1.2.0-initrd-amd64... ok\"","service":"github.com/tinkerbell/boots","pkg":"syslog"}
{"level":"info","ts":1697053477.742723,"caller":"dhcp4-go@v0.0.0-20190402165401-39c137f31ad3/handler.go:105","msg":"","service":"github.com/tinkerbell/boots","pkg":"dhcp","pkg":"dhcp","event":"recv","mac":"58:47:ca:71:d8:49","via":"10.42.0.166","iface":"eth0","xid":"\"7a:4e:a2:f8\"","type":"DHCPDISCOVER","secs":4,"option(82)":"AQltYWN2bGFuOTkFBAoKABQ="}
{"level":"info","ts":1697053477.742839,"caller":"boots/dhcp.go:88","msg":"parsed option82/circuitid","service":"github.com/tinkerbell/boots","pkg":"main","mac":"58:47:ca:71:d8:49","circuitID":"macvlan"}
{"level":"info","ts":1697053477.7431183,"caller":"dhcp4-go@v0.0.0-20190402165401-39c137f31ad3/handler.go:61","msg":"","service":"github.com/tinkerbell/boots","pkg":"dhcp","pkg":"dhcp","event":"send","mac":"58:47:ca:71:d8:49","via":"10.42.0.166","iface":"eth0","xid":"\"7a:4e:a2:f8\"","type":"DHCPOFFER","address":"10.10.0.16","option(82)":"AQltYWN2bGFuOTkFBAoKABQ="}
{"level":"info","ts":1697053477.7469444,"caller":"dhcp4-go@v0.0.0-20190402165401-39c137f31ad3/handler.go:105","msg":"","service":"github.com/tinkerbell/boots","pkg":"dhcp","pkg":"dhcp","event":"recv","mac":"58:47:ca:71:d8:49","via":"10.42.0.166","iface":"eth0","xid":"\"7a:4e:a2:f8\"","type":"DHCPREQUEST","secs":4,"option(82)":"AQltYWN2bGFuOTkFBAoKABQ="}
{"level":"info","ts":1697053477.7470136,"caller":"boots/dhcp.go:88","msg":"parsed option82/circuitid","service":"github.com/tinkerbell/boots","pkg":"main","mac":"58:47:ca:71:d8:49","circuitID":"macvlan"}
{"level":"info","ts":1697053477.7471972,"caller":"dhcp4-go@v0.0.0-20190402165401-39c137f31ad3/handler.go:61","msg":"","service":"github.com/tinkerbell/boots","pkg":"dhcp","pkg":"dhcp","event":"send","mac":"58:47:ca:71:d8:49","via":"10.42.0.166","iface":"eth0","xid":"\"7a:4e:a2:f8\"","type":"DHCPACK","address":"10.10.0.16","option(82)":"AQltYWN2bGFuOTkFBAoKABQ="}
{"level":"error","ts":1697053479.3147168,"logger":"github.com/tinkerbell/ipxedust","caller":"itftp/itftp.go:97","msg":"file serve failed","service":"github.com/tinkerbell/boots","event":"get","filename":"ipxe.efi","uri":"ipxe.efi","client":{"IP":"10.10.0.16","Port":1201,"Zone":""},"macFromURI":"","b":0,"contentSize":1017856,"error":"Channel timeout: 10.10.0.16:1201","stacktrace":"github.com/tinkerbell/ipxedust/itftp.Handler.HandleRead\n\t/home/gaurav/go/pkg/mod/github.com/tinkerbell/ipxedust@v0.0.0-20220406180840-46f16b8d8fb0/itftp/itftp.go:97\ngithub.com/pin/tftp.(*Server).handlePacket.func2\n\t/home/gaurav/go/pkg/mod/github.com/pin/tftp@v0.0.0-20210809155059-0161c5dd2e96/server.go:429"}
```