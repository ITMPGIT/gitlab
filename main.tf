# variables that can be overriden
variable "hostname" { default = "staticip" }
variable "domain" { default = "example.com" }
variable "ip_type" { default = "static" } # dhcp is other valid type
variable "memoryMB" { default = 1024 * 1 }
variable "cpu" { default = 1 }
variable "prefixIP" { default = "192.168.122" }
variable "octetIP" { default = "31" }


# instance the provider
provider "libvirt" {
  #uri = "qemu+ssh://virt:${SSH_PASS}oem@192.168.1.108/system?sshauth=ssh-password&knownhosts=~/.ssh/known_hosts"
  #uri = "qemu+ssh://oem@192.168.1.108/system?sshauth=privkey"
  uri = "qemu+ssh://oem@192.168.1.108/system?knownhosts=~/.ssh/known_hosts&sshauth=privkey&no_verify=1"
}

# fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "os_image" {
  name = "${var.hostname}-os_image"
  pool = "default"
  # using newest ubuntu focal 20.04
  #source = "https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"
  #source = "https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
  #source = "/media/oem/08ce451b-7ba9-4ddb-a8ff-ea89d7c074aa/OL7U9_x86_64-kvm-b145.qcow"
  # cloud image OL7
  source = "https://yum.oracle.com/templates/OracleLinux/OL7/u9/x86_64/OL7U9_x86_64-kvm-b145.qcow"
  format = "qcow2"
}

# Use CloudInit ISO to add ssh-key to the instance
resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "${var.hostname}-commoninit.iso"
  pool           = "default"
  user_data      = data.template_file.user_data.rendered
  network_config = data.template_file.network_config.rendered
}


data "template_file" "user_data" {
  template = file("${path.module}/cloud_init.cfg")
  vars = {
    hostname = var.hostname
    fqdn     = "${var.hostname}.${var.domain}"
  }
}

data "template_file" "network_config" {
  template = file("${path.module}/network_config_${var.ip_type}.cfg")
  vars = {
    domain   = var.domain
    prefixIP = var.prefixIP
    octetIP  = var.octetIP
  }
}


# Create the machine
resource "libvirt_domain" "domain-ubuntu" {
  # domain name in libvirt, not hostname
  name   = "${var.hostname}-${var.prefixIP}.${var.octetIP}"
  memory = var.memoryMB
  vcpu   = var.cpu

  disk {
    volume_id = libvirt_volume.os_image.id
  }
  network_interface {
    network_name = "default"
  }

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  # IMPORTANT
  # Ubuntu can hang is a isa-serial is not present at boot time.
  # If you find your CPU 100% and never is available this is why
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = "true"
  }
}

terraform {
  required_version = ">= 0.12"
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
  #backend "pg" {
 #   conn_str = "postgres://postgres:postgres@192.168.1.107/terraform?sslmode=disable"
 # }
}
output "ips" {
  #value = libvirt_domain.domain-ubuntu
  #value = libvirt_domain.domain-ubuntu.*.network_interface
  # show IP, run 'terraform refresh' if not populated
  value = libvirt_domain.domain-ubuntu.*.network_interface.0.addresses
}
