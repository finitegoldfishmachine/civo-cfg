locals {
    base_rule = {
    protocol = "udp"
    cidr = ["0.0.0.0/0"]
    # port_range = "xxxx" or "xxxx-xxxx"
    # label = "some label"
  }

  fw_overlays = {
    satisfactory = var.satisfactory_enabled ? [
      {label = "satisfactory query port", port_range = "15777"},
      {label = "satisfactory game port", port_range = "7777"},
      {label = "satisfactory beacon port", port_range = "15000"},
    ] : []
    ssh = var.ssh_enabled ? [
      {label = "ssh port", port_range = "22", protocol = "tcp"},
    ] : []
  }

  # When it's a personal project, it's okay to make unreadable garbage
  fw_overlay_list = flatten([for k, v in local.fw_overlays : v])
  fw_rule_list = [for idx, elem in local.fw_overlay_list : merge(local.base_rule, elem)]
  fw_rule_map = {for idx, elem in local.fw_rule_list : elem.label => elem}
}

resource "civo_network" "core" {
    label = "corenet"
}

resource "civo_firewall" "core" {

  name                 = "core"
  network_id           = civo_network.core.id
  create_default_rules = false

  dynamic "ingress_rule" {
    for_each = local.fw_rule_map
    content {
      label = ingress_rule.key
      protocol = ingress_rule.value.protocol
      port_range = ingress_rule.value.port_range
      cidr = ingress_rule.value.cidr
      action = "allow" # Default deny posture
    }
  }

  egress_rule {
    label      = "all"
    protocol   = "tcp"
    port_range = "1-65535"
    cidr       = ["0.0.0.0/0"]
    action     = "allow"
  }
}

resource "civo_dns_domain_name" "core" {
  name = "core.goldfish.zone"
}

resource "civo_dns_domain_record" "core" {
    domain_id = civo_dns_domain_name.core.id
    type = "A"
    name = "@"
    value = civo_instance.core.public_ip
    ttl = 600
}

resource "cloudflare_record" "core_nameservers" {
  for_each = toset(["ns0", "ns1"])

  zone_id = data.cloudflare_zone.apex.id
  name    = "core"
  value   = "${each.value}.civo.com"
  type    = "NS"
  ttl     = 3600
}

data "cloudflare_zone" "apex" {
  name = "goldfish.zone"
}
