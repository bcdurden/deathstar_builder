# Tailscale fix as of GL-Inet 4.23

Existing tailscale implementation in router suite does not support advertising vlan-based routes. Meaning it can't be used as a tailscale node that advertises anything other than the base lan ip cidr range defined in the base UI. Anything in Luci or downstream layer-3 switches cannot be advertised.

The fix is to edit the start script, which is setup in an odd way. The tailscale opkg installed underhood by the UI will create several artifacts in the OS to manage tailscale. The first is basic  services configs. Tailscale is managed by a service but the configurations that are injected are not immediately obvious in their location.

There is glue code in `/usr/bin/gl_tailscale` that will start/stop the systemd service itself and inject tailscale config upstream of the service. This file is where the changes need to be made to advertise additional downstream routes.

In this folder, I've created a gl_tailscale file that can be copy-pasted over the original in `/usr/bin/gl_tailscale`. The only changes are adding of cidr range variables at the top that are added into the advertised-routes fields later in the script. Once copying this file in via the SSH shell (either via `scp` or copy-pasta in `vi`) the service can be restarted by running it with a parameter of `restart`. Once done, you'll need to approve the new routes in the tailscale admin console.

Example:
```console
root@GL-AXT1800:/usr/bin# echo -n > /usr/bin/gl_tailscale 
root@GL-AXT1800:/usr/bin# vi gl_tailscale
root@GL-AXT1800:/usr/bin# /usr/bin/gl_tailscale restart
logtail started
Program starting: v1.32.2-dev-t, Go 1.19.3: []string{"/usr/sbin/tailscaled", "--cleanup"}
LogID: 46f00354b898276fea23817231d9ff5248a6251a6c982fef73b4cdf88f41eb69
logpolicy: using system state directory "/var/lib/tailscale"
dns: [rc=unknown ret=direct]
dns: using *dns.directManager
flushing log.
logger closing down
logtail started
Program starting: v1.32.2-dev-t, Go 1.19.3: []string{"/usr/sbin/tailscaled", "--cleanup"}
LogID: 46f00354b898276fea23817231d9ff5248a6251a6c982fef73b4cdf88f41eb69
logpolicy: using system state directory "/var/lib/tailscale"
dns: [rc=unknown ret=direct]
dns: using *dns.directManager
flushing log.
logger closing down
```