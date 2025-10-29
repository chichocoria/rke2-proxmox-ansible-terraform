##Declaramos variables que se van a utilizar en todo momento

##Nombre de la variable del template que creamos en proxmox
variable "cloudinit_template_name" {
  type = string
}

##Nombre del node de proxmox
variable "proxmox_node" {
  type = string
}

##La variable ssh_key alamacena la clave publica ssh, al declarase sensitive no se muesta ni en logs ni en outputs por seguridad
variable "ssh_key" {
  type      = string
  sensitive = true
}

##Se crean 1 nodo master
resource "proxmox_vm_qemu" "k8s-server" {
  count       = 1
  name        = "kubernetes-master-${count.index + 1}"
  ciuser      = "darioc"
  target_node = var.proxmox_node
  clone       = var.cloudinit_template_name
  boot        = "order=scsi0"
  full_clone  = "true"
  agent       = 1
  os_type     = "l26"
  cores       = 2
  sockets     = 1
  cpu         = "host"
  memory      = 4096
  scsihw      = "virtio-scsi-pci"

  disks {
    scsi {
      # Este es el disco del OS, que redimensionamos a 40G
      scsi0 {
        disk {
          size    = 40
          storage = "lvm-vms" # El storage donde quieres la VM
        }
      }
      # Este es el disco Cloud-Init que venía del template
      scsi2 {
        cloudinit {
          storage = "lvm-vms" 
        }
      }
    }
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  ipconfig0  = "ip=192.168.52.104/24,gw=192.168.52.1"
  nameserver = "8.8.8.8"
  sshkeys    = <<EOF
  ${var.ssh_key}
  EOF
}


##Se crean 2 nodos workers
resource "proxmox_vm_qemu" "k8s-agent" {
  count       = 2
  name        = "kubernetes-node-${count.index + 1}"
  ciuser      = "darioc"
  target_node = var.proxmox_node
  clone       = var.cloudinit_template_name
  boot        = "order=scsi0"
  full_clone  = "true"
  agent       = 1
  os_type     = "l26"
  cores       = 2
  sockets     = 1
  cpu         = "host"
  memory      = 4096
  scsihw      = "virtio-scsi-pci"

  disks {
    scsi {
      # Disco del OS redimensionado
      scsi0 {
        disk {
          size    = 40
          storage = "lvm-vms"
        }
      }
      # Disco Cloud-Init conservado
      scsi2 {
        cloudinit {
          storage = "lvm-vms" # Debe coincidir con el storage del template
        }
      }
    }
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  ipconfig0  = "ip=192.168.52.10${count.index + 2}/24,gw=192.168.52.1"
  nameserver = "8.8.8.8"
  sshkeys    = <<EOF
  ${var.ssh_key}
  EOF
}

################################ CLOUDFLARE ###############################

variable "zone_id" {
  default = "var.zone_id"
}

variable "account_id" {
  default = "var.account_id"
}

variable "domain" {
  default = "chicho.com.ar"
}

resource "cloudflare_record" "rke2prueba" {
  zone_id = var.zone_id
  name    = "rke2prueba"
  value   = "chicho.com.ar"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "avatares2" {
  zone_id = var.zone_id
  name    = "avatares2"
  value   = "chicho.com.ar"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "monitoreo-avatares2" {
  zone_id = var.zone_id
  name    = "monitoreo-avatares2"
  value   = "chicho.com.ar"
  type    = "CNAME"
  proxied = true
}
