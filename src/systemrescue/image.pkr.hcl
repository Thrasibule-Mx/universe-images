# src/systemrescue/image.pkr.hcl
# ==============================
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
    description = "The architecture for which the image is being built."

    validation {
        condition = contains(["amd64"], var.arch)
        error_message = "Architecture must be one of: 'amd64'."
    }
}

variable "authorized_keys" {
    type = string
    default = ""
    description = "Path to a file listing the authorized SSH keys."
}

variable "recipe_directory" {
    type = string
    default = "recipe"
    description = "Path to the recipe directory listing the customizations to be applied."
}

variable "version" {
    type = string
    default = "13.02"
    description = "Version of the SystemRescue ISO to use when building the image."
}

locals {
    runid = "${uuidv4()}"

    image_name = "systemrescue-${var.version}-${var.arch}"
    artifact_output = "${local.image_name}.iso"

    sysresc_pubkey_url = "https://www.system-rescue.org/security/signing-keys/gnupg-pubkey-fdupoux-20210704-v001.pem"
    sysresc_customize_url = "https://gitlab.com/systemrescue/systemrescue-sources/-/raw/main/airootfs/usr/share/sysrescue/bin/sysrescue-customize"

    sysresc_baseurl = "https://sourceforge.net/projects/systemrescuecd/files/sysresccd-x86/${var.version}/${local.artifact_output}"
    sysresc_iso_url = "${local.sysresc_baseurl}"
    sysresc_sig_url = "${local.sysresc_baseurl}.asc"
    sysresc_sum_url = "${local.sysresc_baseurl}.sha256"
}

source "file" "iso" {
    target = local.artifact_output
}

build {
    name = local.image_name

    sources = [
        "source.file.iso",
    ]

    provisioner "shell-local" {
        script = "scripts/download.sh"
        env = {
            PACKER_WORKDIR = "/tmp/packer/${local.runid}"

            SYSRESC_PUBKEY_URL = local.sysresc_pubkey_url
            SYSRESC_CUSTOMIZE_URL = local.sysresc_customize_url

            SYSRESC_ISO_URL = local.sysresc_iso_url
            SYSRESC_SIG_URL = local.sysresc_sig_url
            SYSRESC_SUM_URL = local.sysresc_sum_url
        }
    }

    provisioner "shell-local" {
        script = "scripts/customize.sh"
        env = {
            PACKER_WORKDIR = "/tmp/packer/${local.runid}"
            PACKER_RECIPE_DIR = "${trimsuffix(var.recipe_directory, "/")}"
            PACKER_AUTHORIZED_KEYS_FILE = var.authorized_keys
            PACKER_ARTIFACT_OUTPUT = local.artifact_output
        }
    }

    provisioner "shell-local" {
        inline = [
            "rm --force --recursive '/tmp/packer/${local.runid}'",
            "rmdir --ignore-fail-on-non-empty '/tmp/packer'",
        ]
    }

    post-processors {
        post-processor "checksum" {
            checksum_types = ["sha256"]
            output = "${local.artifact_output}.{{ .ChecksumType }}"
        }
    }
}
