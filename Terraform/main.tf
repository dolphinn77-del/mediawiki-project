data "yandex_compute_image" "ubuntu" {
  family    = "ubuntu-2204-lts"
  folder_id = "standard-images"
}

# -----------------------------
# Network
# -----------------------------

resource "yandex_vpc_network" "mediawiki" {
  name        = "mediawiki-network"
  description = "Network for MediaWiki infrastructure"
}

resource "yandex_vpc_subnet" "mediawiki" {
  name           = "mediawiki-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.mediawiki.id
  v4_cidr_blocks = [var.subnet_cidr]
}

# -----------------------------
# Security groups
# -----------------------------

resource "yandex_vpc_security_group" "common" {
  name        = "mediawiki-common-sg"
  description = "Common rules for MediaWiki infrastructure"
  network_id  = yandex_vpc_network.mediawiki.id

  ingress {
    protocol       = "ANY"
    description    = "Internal traffic inside MediaWiki subnet"
    v4_cidr_blocks = [var.subnet_cidr]
  }

  egress {
    protocol       = "ANY"
    description    = "Allow outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "lb_public" {
  name        = "mediawiki-lb-public-sg"
  description = "Public HTTP access to MediaWiki load balancer"
  network_id  = yandex_vpc_network.mediawiki.id

  ingress {
    protocol       = "TCP"
    description    = "Public HTTP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "SSH bastion access"
    port           = 22
    v4_cidr_blocks = [var.admin_cidr]
  }
}

resource "yandex_vpc_security_group" "zabbix_web" {
  name        = "mediawiki-zabbix-web-sg"
  description = "Zabbix web interface from management network"
  network_id  = yandex_vpc_network.mediawiki.id

  ingress {
    protocol       = "TCP"
    description    = "Zabbix web interface"
    port           = 80
    v4_cidr_blocks = [var.admin_cidr]
  }
}

# -----------------------------
# Virtual machines
# -----------------------------

resource "yandex_compute_instance" "vm" {
  for_each = var.vms

  name        = each.key
  hostname    = each.key
  platform_id = "standard-v3"
  zone        = var.zone

  allow_stopping_for_update = true

  scheduling_policy {
    preemptible = true
  }

  lifecycle {
    ignore_changes = [
      boot_disk[0].initialize_params[0].image_id
    ]
  }

  resources {
    cores         = 2
    memory        = each.value.memory
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      type     = "network-hdd"
      size     = each.value.disk
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.mediawiki.id
    ip_address = each.value.ip
    nat        = true

    security_group_ids = concat(
      [yandex_vpc_security_group.common.id],
      each.key == "lb-01" ? [yandex_vpc_security_group.lb_public.id] : [],
      each.key == "zabbix-01" ? [yandex_vpc_security_group.zabbix_web.id] : []
    )
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(pathexpand(var.ssh_public_key_path))}"
  }
}
