# src/systemrescue/scripts/download.sh
# ====================================
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


CURL_OPTS="--fail --location --show-error"


_fext()
{
    echo -n "${1}" | rev | cut -d'.' -f1 | rev
}


_url_fname()
{
    echo -n "${1}" | rev | cut -d'/' -f1 | rev
}


download()
{
    _curl_add_opts="--no-progress-meter --remote-name"

    cd "${1}"
    curl ${CURL_OPTS} ${_curl_add_opts} -- "${SYSRESC_SIG_URL}"                \
        && curl ${CURL_OPTS} ${_curl_add_opts} -- "${SYSRESC_SUM_URL}"         \
        && curl ${CURL_OPTS} ${_curl_add_opts} -- "${SYSRESC_ISO_URL}"         \
        && curl ${CURL_OPTS} ${_curl_add_opts} -- "${SYSRESC_CUSTOMIZE_URL}"

    return ${?}
}


setup()
{
    curl ${CURL_OPTS} --silent -- "${SYSRESC_PUBKEY_URL}" | gpg --quiet --import -- -    \
        && mkdir --parents -- "${PACKER_WORKDIR}/vendor"                       \
        && echo "${PACKER_WORKDIR}/vendor"

    return ${?}
}


validate()
{
    _iso_fname="$(_url_fname "${SYSRESC_ISO_URL}")"
    _sig_fname="$(_url_fname "${SYSRESC_SIG_URL}")"
    _sum_fname="$(_url_fname "${SYSRESC_SUM_URL}")"
    _sum_ext="$(_fext "${_sum_fname}")"

    cd "${1}"
    gpg --verify -- "${_sig_fname}" "${_iso_fname}"                            \
        && "${_sum_ext}sum" --check -- "${_sum_fname}"

    return ${?}
}


_workdir="$(setup)"
download "${_workdir}" && validate "${_workdir}"
exit ${?}
