# src/systemrescue/scripts/customize.sh
# =====================================
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
set -e
set -x


authorize_keys()
{
    _keys_f="${1}"
    _conf_f="${2}/iso_add/sysrescue.d/150-ssh-authorized-keys.yaml"

    cat > "${_conf_f}" << EOF
# Generated from Packer.
---
global:
  nofirewall: true

sysconfig:
  authorized_keys:
EOF

    cat "${_keys_f}" | while read name key_spec
    do
        echo "    \"${name}\": \"${key_spec}\"" >> "${_conf_f}"
    done

    return ${?}
}


customize()
{
    bash "${PACKER_WORKDIR}/vendor/sysrescue-customize"                        \
        --auto                                                                 \
        --overwrite                                                            \
        --source="${1}"                                                        \
        --dest="${PACKER_ARTIFACT_OUTPUT}"                                     \
        --recipe-dir="${PACKER_WORKDIR}/recipe"                                \
        --work-dir="${PACKER_WORKDIR}/work"

    return ${?}
}


cp --archive "${PACKER_RECIPE_DIR}" "${PACKER_WORKDIR}/recipe"
if [ -f "${PACKER_AUTHORIZED_KEYS_FILE}" ]
then
    authorize_keys "${PACKER_AUTHORIZED_KEYS_FILE}" "${PACKER_WORKDIR}/recipe"
fi

customize "$(find "${PACKER_WORKDIR}/vendor" -name "*.iso")"
exit ${?}
