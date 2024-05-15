# Civo config
This is my personal config for organizing compute resources on Civo.

Civo's API seems pretty flakey. Issues observed include...
- Not returning a public IP attribute even though it made one in the instance resource (even after repeated plans to force it to check the actual state)
```
│ Error: value must not be empty, got 
│ 
│   with civo_dns_domain_record.core,
│   on main.tf line 150, in resource "civo_dns_domain_record" "core":
│  150:     value = civo_instance.core.public_ip
```

- Not making the firewall but then doing so 5 minutes later because ???
```
| Error: [ERR] failed to create a new firewall: core, err: DatabaseFirewallSaveFailedError: Failed to save that firewall in the internal database
```

Anyway, this isn't to talk a bunch of mess about Civo; these are notes to myself to repeatedly apply the configuration until it gives up, I decide that the provider needs my commits, or I migrate the resources to a different cloud provider.
