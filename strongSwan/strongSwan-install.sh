#!/usr/bin/env bash
#
# Install strongSwan
#

set -o errexit
set -o errtrace
set -o pipefail

Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
INFO="[${Green_font_prefix}INFO${Font_color_suffix}]"
ERROR="[${Red_font_prefix}ERROR${Font_color_suffix}]"

PROJECT_NAME='strongSwan'
GH_URL_BASE='https://raw.githubusercontent.com/tywtyw2002/cScripts/master/strongSwan'
PY_INSTALLER='strongswan.py'

echo -e "${INFO} ===== {${PROJECT_NAME} Installer} ====="

if [[ $(uname -s) != Linux ]]; then
    echo -e "${ERROR} This operating system is not supported."
    exit 1
fi

if [[ $(id -u) != 0 ]]; then
    echo -e "${ERROR} This script must be run as root."
    exit 1
fi

echo -e "${INFO} Get CPU architecture ..."
if [[ $(command -v apk) ]]; then
    PKGT='(apk)'
    OS_ARCH=$(apk --print-arch)
elif [[ $(command -v dpkg) ]]; then
    PKGT='(dpkg)'
    OS_ARCH=$(dpkg --print-architecture | awk -F- '{ print $NF }')
else
    OS_ARCH=$(uname -m)
fi

case ${OS_ARCH} in
# *86)
#     FILE_KEYWORD='linux_386'
#     ;;
x86_64 | amd64)
    FILE_KEYWORD='linux_amd64'
    ;;
# aarch64 | arm64)
#     FILE_KEYWORD='linux_arm64'
#     ;;
# arm*)
#     FILE_KEYWORD='linux_armv6'
#     ;;
*)
    echo -e "${ERROR} Unsupported architecture: ${OS_ARCH} ${PKGT}"
    exit 1
    ;;
esac

if [[ ! $(command -v lsb_release) ]]; then
    echo -e "${ERROR} Unsupported Linux Distribution."
    exit 1
fi

OS_ID=$(lsb_release -s -i)
OS_V=$(lsb_release -s -r)

if [[ "${OS_ID}" != Debian && "${OS_ID}" != Ubuntu ]]; then
    echo -e "${ERROR} Unsupported Linux Distribution: ${OS_ARCH} ${OS_ID}"
    exit 1
fi

if [[ "${OS_ID}" = Debian && "${OS_V}" -lt 10  ]]; then
    echo -e "${ERROR} Unsupported ${OS_ID} Version: ${OS_V}"
    exit 1
fi

echo -e "${INFO} Architecture: ${OS_ID} ${OS_V} ${OS_ARCH} ${PKGT}"
echo -e "${INFO} Init Setup Script ..."

TMP_DIR=$(mktemp -d)

curl -fsSL "${GH_URL_BASE}/${PY_INSTALLER}" -o "${TMP_DIR}/setup.py"

FAIL=true

/usr/bin/env python3 "${TMP_DIR}/setup.py" $@ && FAIL=false

if [[ "${FAIL}" = false ]]; then
    echo -e "${INFO} Done."
    rm -rf ${TMP_DIR}
else
    echo -e "${ERROR} Setup Script Failed. TMP Path: ${TMP_DIR}"
    exit 1
fi

exit 0