variable pm_api_token {
  type        = string
  sensitive   = true
}

variable pm_api_url {
  type = string
}

variable image {
  type = object({
    url = string
    filename = string
  })
  default = {
    url = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    filename = "noble-server-cloudimg-amd64.qcow2"
  }
}

variable cidr {
  type    = string
  default = "192.168.8.0/24"
}

variable first_host {
  type    = number
  default = 170
}

variable vm_count {
  type    = number
  default = 6
}

variable ssh_key_files {
  type    = object({
    public = string
    private = string
  })
  default = {
    public = "/Users/eetujukka/.ssh/id_ed25519.pub"
    private = "/Users/eetujukka/.ssh/id_ed25519"
  }
}

variable login_user {
  type    = string
  default = "user"
}

variable memory {
  type = number
  default = 8192
}

variable storage {
  type = number
  default = 50
}

variable cpu {
  type = object({
    cores = number
    type = string
  })
  default = {
    cores = 4
    type = "host"
  }
}