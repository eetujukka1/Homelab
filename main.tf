data "local_file" "ssh_public_key" {
  filename = var.ssh_key_files.public
}

data "proxmox_virtual_environment_nodes" "available_nodes" {}

locals {
  vm_index = toset([for i in range(var.vm_count) : tostring(i)])
  node_count = length(data.proxmox_virtual_environment_nodes.available_nodes.names)
}

resource "random_pet" "pet_name" {
  for_each = local.vm_index
}

resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  for_each     = toset(slice(data.proxmox_virtual_environment_nodes.available_nodes.names, 0, min(local.node_count, var.vm_count)))
  content_type = "import"
  datastore_id = "local"
  node_name    = each.key
  url          = var.image.url
  file_name    = var.image.filename
}

resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  for_each    = local.vm_index
  name        = "${random_pet.pet_name[each.key].id}"
  description = "Managed by Terraform"
  node_name   = data.proxmox_virtual_environment_nodes.available_nodes.names[tonumber(each.key) % local.node_count]

  stop_on_destroy = true

  initialization {
    datastore_id = "local-lvm"

    ip_config {
      ipv4 {
        address = "${cidrhost(var.cidr, var.first_host + tonumber(each.key))}/24"
        gateway = cidrhost(var.cidr, 1)
      }
    }

    user_account {
      username = var.login_user
      keys     = [trimspace(data.local_file.ssh_public_key.content)]
    }
  }

  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_virtual_environment_download_file.ubuntu_cloud_image[data.proxmox_virtual_environment_nodes.available_nodes.names[tonumber(each.key) % local.node_count]].id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.storage
  }

  cpu {
    cores = var.cpu.cores
    type = var.cpu.type
  }

  memory {
    dedicated = var.memory
    floating = var.memory
  }

  network_device {
    bridge = "vmbr0"
  }
}


resource "local_file" "ansible_inventory" {
  content = <<-EOT
[k3s_servers]
%{ for k, vm in {
  for k, vm in proxmox_virtual_environment_vm.ubuntu_vm : k => {
    ansible_host = cidrhost(var.cidr, var.first_host + tonumber(k))
    ansible_user = var.login_user
    vm_name = vm.name
  }
} ~}
%{ if tonumber(k) < min(var.vm_count / 2 - (var.vm_count / 2 % 2 == 0 ? 1 : 0), 7) ~}
${vm.vm_name} ansible_host=${vm.ansible_host} ansible_user=${vm.ansible_user}
%{ endif ~}
%{ endfor ~}

[k3s_agents]
%{ for k, vm in {
  for k, vm in proxmox_virtual_environment_vm.ubuntu_vm : k => {
    ansible_host = cidrhost(var.cidr, var.first_host + tonumber(k))
    ansible_user = var.login_user
    vm_name = vm.name
  }
} ~}
%{ if tonumber(k) >= min(var.vm_count / 2 - (var.vm_count / 2 % 2 == 0 ? 1 : 0), 7) ~}
${vm.vm_name} ansible_host=${vm.ansible_host} ansible_user=${vm.ansible_user}
%{ endif ~}
%{ endfor ~}

[all:vars]
ansible_ssh_private_key_file=${var.ssh_key_files.private}
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_connection=ssh
  EOT
  filename = "${path.module}/inventory.ini"
}