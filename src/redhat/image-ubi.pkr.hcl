# images/redhat/image-ubi.pkr.hcl
# ===============================
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

        docker = {
            source = "github.com/hashicorp/docker"
            version = "~> 1"
        }
    }
}

variable "arch" {
    type = string
    default = "amd64"
    description = "The target architecture for the image."

    validation {
        condition = contains(["amd64", "arm64v8"], var.arch)
        error_message = "Architecture must be one of: 'amd64' or 'arm64v8'."
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

variable "dnfopts" {
    type = string
    default = "--assumeyes --best --setopt=install_weak_deps=False"
    description = "Options provided to the DNF package manager."
}

variable "galaxy_file" {
    type = string
    default = "requirements.yaml"
    description = <<EOF
Path to a Galaxy requirements file listing the playbook's dependencies.
EOF
}

variable "os" {
    type = string
    default = "ubi10"
    description = "Name of the operating system to build."

    validation {
        condition = can(regex("^ubi\\d+", var.os))
        error_message = "OS must be `ubi<version>`."
    }
}

variable "playbook_file" {
    type = string
    default = "staging.yaml"
    description = "A playbook file to be executed by ansible."
}

variable "repository_url" {
    type = string
    default = "registry.redhat.io"
    description = "Base URL to the Docker repository."
}

variable "version" {
    type = string
    default = "latest"
    description = "Version of the UBI image to use."
}

locals {
    image_name = "${var.os}-${var.version}-${var.arch}"
    docker_output = "${local.image_name}.tar"
    artifact_output = "${local.docker_output}.${var.compress}"
}

source "docker" "image" {
    image = "${var.repository_url}/${var.os}:${var.version}"
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
            "rpm --query --all | xargs dnf reinstall ${var.dnfopts}",
        ]
    }

    provisioner "ansible" {
        playbook_file = fileexists(var.playbook_file) ? var.playbook_file : "/dev/null"
        galaxy_file = fileexists(var.galaxy_file) ? var.galaxy_file : null

        command = fileexists(var.playbook_file) ? "ansible-playbook" : "true"
        skip_version_check = true
        extra_arguments = [
            "--verbose"
        ]
    }

    # Image cleanup.
    provisioner "shell" {
        inline = [
            "dnf autoremove ${var.dnfopts}",
            "dnf clean all ${var.dnfopts}",
            "rm --force --recursive /packer-files",
            "journalctl --vacuum-size=1M",
            "find /var/log -mindepth 1 -type f -delete",
            "find /var/log -mindepth 1 -type d -delete",
        ]
    }

    # Image info.build_iso_checksum
    provisioner "shell" {
        inline = [
            "echo",
            "echo 'Release:'",
            "cat /etc/redhat-release",
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
