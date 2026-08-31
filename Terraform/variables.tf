variable "zone" {
  description = "Yandex Cloud availability zone"
  type        = string
  default     = "ru-central1-d"
}

variable "subnet_cidr" {
  description = "MediaWiki project subnet"
  type        = string
  default     = "10.50.0.0/24"
}

variable "admin_cidr" {
  description = "Public IPv4 address of Ansible/Terraform management node"
  type        = string
}

variable "ssh_user" {
  description = "SSH user on Ubuntu VMs"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  description = "SSH public key used for VM access"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "vms" {
  description = "MediaWiki infrastructure virtual machines"

  type = map(object({
    ip     = string
    memory = number
    disk   = number
  }))

  default = {
    lb-01 = {
      ip     = "10.50.0.10"
      memory = 1
      disk   = 10
    }

    wiki-01 = {
      ip     = "10.50.0.21"
      memory = 2
      disk   = 15
    }

    wiki-02 = {
      ip     = "10.50.0.22"
      memory = 2
      disk   = 15
    }

    db-01 = {
      ip     = "10.50.0.31"
      memory = 2
      disk   = 20
    }

    db-02 = {
      ip     = "10.50.0.32"
      memory = 2
      disk   = 20
    }

    backup-01 = {
      ip     = "10.50.0.41"
      memory = 1
      disk   = 30
    }

    zabbix-01 = {
      ip     = "10.50.0.51"
      memory = 2
      disk   = 20
    }
  }
}
