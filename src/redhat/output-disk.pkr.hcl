# images/redhat/output-disk.pkr.hcl
# =================================
#
# Copying
# -------
#
# Copyright (c) 2026 universe/images authors and contributors.
#
# This file is part of the *universe/images* project.
#
# *universe/images* is a free software project. You can redistribute it and/or
# modify it following the terms of the MIT License.
#
# This software project is distributed *as is*, WITHOUT WARRANTY OF ANY KIND;
# including but not limited to the WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE and NONINFRINGEMENT.
#
# You should have received a copy of the MIT License along with
# *universe/images*. If not, see <http://opensource.org/licenses/MIT>.
#
packer {
    required_plugins {
        ansible = {
            source = "github.com/hashicorp/ansible"
            version = "~> 1"
        }

        qemu = {
            source  = "github.com/hashicorp/qemu"
            version = "~> 1"
        }
    }
}

variable "build_galaxy_file" {
    type = string
    default = "requirements.yaml"
    description = <<EOF
Path to a Galaxy requirements file listing the playbook's dependencies during
the **build** phase.
EOF
}

variable "build_iso_checksum" {
    type = string
    description = <<EOF
Checksum or URL to a checksum file of the ISO used to build the disk image.
EOF
}

variable "build_iso_url" {
    type = string
    description = "URL to the Live CD ISO used to build the disk image."
}

variable "build_playbook_file" {
    type = string
    default = "build.yaml"
    description = <<EOF
A playbook file to be executed by ansible during the **build** phase.
EOF
}

variable "disk_compression" {
    type = bool
    default = true
    description = "Apply compression to the QCOW2 disk file."
}

variable "disk_format" {
    type = string
    default = "qcow2"
    description = <<EOF
Either `qcow2` or `raw`, this specifies the output format of the virtual machine
image.
EOF

    validation {
        condition = contains(["qcow2", "raw"], var.disk_format)
        error_message = "Disk format must be one of: 'qcow2' or 'raw'."
    }
}

variable "disk_additional_size" {
    type = list(string)
    default = []
    description = <<EOF
Additional disks to create. The size in bytes of the hard disk of the VM.Suffix
with the first letter of common byte types. Use `k` or `K` for kilobytes, `M`
for megabytes, `G` for gigabytes, and `T` for terabytes.
EOF

    validation {
        condition = alltrue([
            for x in var.disk_additional_size: can(regex("^\\d+[kKMGT]$", x))
        ])
        error_message = "Size is a number followed by `k`, `K`, `M`, `G` or `T`."
    }
}

variable "disk_size" {
    type = string
    default = "80G"
    description = <<EOF
The size in bytes of the hard disk of the VM. Suffix with the first letter of
common byte types. Use `k` or `K` for kilobytes, `M` for megabytes, `G` for
gigabytes, and `T` for terabytes.
EOF

    validation {
        condition = can(regex("^\\d+[kKMGT]$", var.disk_size))
        error_message = "Size is a number followed by `k`, `K`, `M`, `G` or `T`."
    }
}

variable "dnfopts" {
    type = string
    default = "--assumeyes --best --setopt=install_weak_deps=False"
    description = "Options provided to the DNF package manager."
}

variable "http_directory" {
    type = string
    default = "resources"
    description = <<EOF
Path to a directory to serve using an HTTP server. The files in this directory
will be available over HTTP that will be requestable from the virtual machine.
EOF
}

variable "memory" {
    type = number
    default = 4096
    description = "The amount of memory to use when building the VM in megabytes."
}

variable "output_directory" {
    type = string
    default = "output"
    description = "Directory where to put generated artifacts."
}

variable "staging_galaxy_file" {
    type = string
    default = "requirements.yaml"
    description = <<EOF
Path to a Galaxy requirements file listing the playbook's dependencies during
the **staging** phase.
EOF
}

variable "staging_playbook_file" {
    type = string
    default = "staging.yaml"
    description = <<EOF
A playbook file to be executed by ansible during the **staging** phase.
EOF
}

variable "ssh_private_key_file" {
    type = string
    default = ""
    description = <<EOF
Path to a PEM encoded private key file to use to authenticate with SSH.
EOF
}

variable "vm_name" {
    type = string
    default = "redhat"
    description = "The name of the image file for the new virtual machine."
}

locals {
    defaults = {
        build = {
            ssh_username = "root"
            ssh_timeout = "15m"
        }

        qemu = {
            accelerator = "kvm"
            boot_wait = "15s"
            disk_interface = "virtio"
            headless = false
            net_interface = "virtio-net"
            vtpm = true
            shutdown_command = "echo 'packer' | shutdown --poweroff now"
        }

        staging = {
            disk_image = true
            use_backing_file = true
        }
    }
}

source "qemu" "build" {
    accelerator = local.defaults.qemu.accelerator
    boot_wait = local.defaults.qemu.boot_wait
    disk_compression = var.disk_compression
    disk_interface = local.defaults.qemu.disk_interface
    disk_size = var.disk_size
    format = var.disk_format
    http_directory = var.http_directory
    iso_checksum = var.build_iso_checksum
    iso_url = var.build_iso_url
    memory = var.memory
    net_device = local.defaults.qemu.net_interface
    output_directory = var.output_directory
    shutdown_command = local.defaults.qemu.shutdown_command
    ssh_private_key_file = var.ssh_private_key_file
    ssh_timeout = local.defaults.build.ssh_timeout
    ssh_username = local.defaults.build.ssh_username
    vm_name = var.vm_name
}

build {
    name = "build"

    sources = [
        "source.qemu.build",
    ]

    provisioner "ansible" {
        playbook_file = fileexists(var.build_playbook_file) ? var.build_playbook_file : "/dev/null"
        galaxy_file = fileexists(var.build_galaxy_file) ? var.build_galaxy_file : null

        command = fileexists(var.build_playbook_file) ? "ansible-playbook" : "true"
        skip_version_check = true
        extra_arguments = [
            "--verbose"
        ]
    }

    post-processors {
        post-processor "checksum" {
            checksum_types = ["sha256"]
            output = "${var.output_directory}/${var.vm_name}.{{ .ChecksumType }}"
        }
    }
}
