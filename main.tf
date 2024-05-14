variable "civo_token" {
  type = string
  description = "The Civo API token to use"
  sensitive = true
}

variable "ssh_enabled" {
  type = bool
  description = "Whether or not to open port 22 for SSH"
  default = false
}

variable "satisfactory_enabled" {
  type = bool
  description = "Whether or not to open ports for Satisfactory"
  default = false
}

terraform {
  required_providers {
    civo = {
      source = "civo/civo"
      version = "1.0.41"
    }
  }
}

provider "civo" {
  token = var.civo_token
  region = "NYC1"
}

resource "civo_network" "core" {
    label = "corenet"
}

locals {
  gigabyte = 1024 # megabytes

  base_rule = {
    protocol = "udp"
    # port_range = "xxxx" or "xxxx-xxxx"
    # label = "some label"
    cidr = ["0.0.0.0/0"]
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

  # "for expression" barf ahead, but it returns the same structure as the fw_overlays but composited on top of base_rule.
  # Example: start with  {
  #                        protocol = "udp"
  #                        cidr = ["0.0.0.0/0"]
  #                      }
  #          merges with {
  #                        label = "foo"
  #                        protocol = "tcp"
  #                        port_range = "1"
  #                      }
  #          and returns {
  #                        label = "foo"
  #                        protocol = "tcp"
  #                        port_range = "1"
  #                        cidr = ["0.0.0.0/0"]
  #                      }
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
