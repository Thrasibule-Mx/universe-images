# images/redhat/image.pkr.hcl
# ===========================
#
# Copying
# -------
#
# Copyright (c) 2023 universe/images authors and contributors.
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
variable "arch" {
    type = string
    default = "amd64"
    description = "The target architecture for the image."

    validation {
        condition = contains(["amd64", "arm32v7", "arm64v8", "riscv64"], var.arch)
        error_message = "Architecture must be one of: 'amd64', 'arm32v7', 'arm64v8' or 'riscv64'."
    }
}

variable "compress" {
    type = string
    default = "gz"
    description = "Compression format of the final artifact."

    validation {
        condition = contains(["gz", "lz4", "zip"], var.compress)
        error_message = "Compression must be one of: 'gz', 'lz4' or 'zip'."
    }
}

variable "galaxy_file" {
    type = string
    default = ""
    description = "Path to a Galaxy requirements file listing the playbook's dependencies."
}

variable "os" {
    type = string
    default = "fedora"
    description = "Name of the operating system to build."

    validation {
        condition = contains(["centos", "fedora"], var.os)
        error_message = "OS must be one of: 'centos', 'fedora'."
    }
}

variable "playbook_file" {
    type = string
    default = "staging.yaml"
    description = "A playbook file to be executed by ansible."
}

variable "playbook_dir" {
    type = string
    default = "staging"
    description = "A path to the complete ansible directory structure containing the ansible roles."
}

variable "version" {
    type = string
    default = "latest"
    description = "Version of the Fedora image to use when building the image."
}

locals {
    image_name = "${var.os}-${var.version}-${var.arch}"
    docker_output = "${local.image_name}.tar"
    artifact_output = "${local.docker_output}.${var.compress}"
}

source "docker" "image" {
    image = "quay.io/${var.os}/${var.os}:${var.version}"
    platform = var.arch
    export_path = local.docker_output

    privileged = true
}

build {
    name = local.image_name

    sources = [
        "source.docker.image",
    ]

    # Image preparation.
    provisioner "shell" {
        inline = [
            "rm --force /.dockerenv",
            "sed --in-place /tsflags/d /etc/dnf/dnf.conf",
            "rpm --query --all | xargs dnf reinstall --assumeyes",
        ]
    }

    # Ansible provisionning.
    provisioner "shell" {
        inline = [
            "dnf install --assumeyes ansible-core",
        ]
    }

    provisioner "ansible-local" {
        playbook_file = var.playbook_file
        playbook_dir = var.playbook_dir
        galaxy_file = var.galaxy_file

        clean_staging_directory = true
        extra_arguments = [
            "--verbose"
        ]
    }

    # Image cleanup.
    provisioner "shell" {
        inline = [
            "dnf autoremove --assumeyes",
            "dnf clean all --assumeyes",
            "journalctl --vacuum-size=1M",
            "find /var/log -mindepth 1 -type f -delete",
            "find /var/log -mindepth 1 -type d -delete",
        ]
    }

    # Image info.
    provisioner "shell" {
        inline = [
            "echo",
            "echo 'Release:'",
            "cat /etc/${var.os}-release",
            "echo",
            "echo 'Packages:'",
            "rpm --query --all | sort",
        ]
    }

    # Image release.
    post-processors {
        post-processor "compress" {
            output = local.artifact_output
            format = var.compress
            compression_level = 9
        }

        post-processor "checksum" {
            checksum_types = ["sha256"]
            output = "${local.artifact_output}.{{ .ChecksumType }}"
        }
    }
}
