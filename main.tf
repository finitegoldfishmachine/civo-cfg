variable "civo_token" {
  sensitive = true
  description = "The Civo API token to use"
  type = string
}

variable "cloudflare_api_token" {
  sensitive = true
  description = "The Cloudflare API token to use"
  type = string
}

variable "ssh_enabled" {
  description = "Whether or not to open port 22 for SSH"
  type = bool
  default = false
}

variable "satisfactory_enabled" {
  description = "Whether or not to open ports for Satisfactory"
  type = bool
  default = false
}

terraform {
  required_providers {
    civo = {
      source = "civo/civo"
      version = "1.0.41"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "civo" {
  token = var.civo_token
  region = "NYC1"
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "civo_network" "core" {
    label = "corenet"
}

locals {
  gigabyte = 1024 # megabytes

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

resource "civo_instance" "core" {
    hostname = "core.goldfish.zone"
    size = element(data.civo_size.sixteen.sizes, 0).name # We want the cheapest instance with 16 GB of RAM
    disk_image = element(data.civo_disk_image.ubuntu.diskimages, 0).id # We want the latest version of the selected distro
    network_id = civo_network.core.id
    firewall_id = civo_firewall.core.id
}

data "civo_size" "sixteen" {
  filter {
    key = "type"
    values = ["Instance"]
  }

  filter {
    key = "ram"
    values = [16 * local.gigabyte]
  }

  sort {
    key = "cpu"
    direction = "asc"
  }
}

data "civo_disk_image" "ubuntu" {
  filter {
      key = "name"
      values = ["ubuntu"]
      match_by = "substring"
  }

  sort {
    key = "version"
    direction = "desc"
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
