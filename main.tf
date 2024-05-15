locals {
  gigabyte = 1024 # megabytes
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
