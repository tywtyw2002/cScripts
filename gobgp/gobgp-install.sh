#!/usr/bin/env bash
#
# Install Gobgp
# Gobgp: v2.32.0
#

RELEASE_VERSION='v2.32.0'

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

PROJECT_NAME='gobgp'
GH_API_URL_BASE='https://api.github.com/repos/osrg/gobgp/releases'
ZSH_COMP_URL='https://raw.githubusercontent.com/osrg/gobgp/master/tools/completion/zsh/_gobgp'
BIN_DIR="/opt/${PROJECT_NAME}"
GH_UTILS_URL_BASE='https://raw.githubusercontent.com/tywtyw2002/cScripts/master/gobgp'

FLAG_LATEST=false
FLAG_BACKUP=false
FLAG_NOSERVICE=false
FLAG_UPGRADE=false

for arg in "$@"
do
    case $arg in
        --latest)
            FLAG_LAST=true
            ;;
        --backup)
            FLAG_BACKUP=true
            ;;
        --no-service)
            FLAG_NOSERVICE=true
            ;;
        --upgrade)
            FLAG_UPGRADE=true
            ;;
        *)
            ;;
    esac
done

if [[ "$FLAG_LATEST" = true ]]; then
    GH_API_URL="${GH_API_URL_BASE}/latest"
    echo -e "${INFO} Install Latest Version"
else
    GH_API_URL="${GH_API_URL_BASE}/tags/${RELEASE_VERSION}"
    echo -e "${INFO} Install Version: ${RELEASE_VERSION}"
fi

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
*86)
    FILE_KEYWORD='linux_386'
    ;;
x86_64 | amd64)
    FILE_KEYWORD='linux_amd64'
    ;;
aarch64 | arm64)
    FILE_KEYWORD='linux_arm64'
    ;;
arm*)
    FILE_KEYWORD='linux_armv6'
    ;;
*)
    echo -e "${ERROR} Unsupported architecture: ${OS_ARCH} ${PKGT}"
    exit 1
    ;;
esac
echo -e "${INFO} Architecture: ${OS_ARCH} ${PKGT}"

echo -e "${INFO} Get ${PROJECT_NAME} download URL ..."
DOWNLOAD_URL=$(curl -fsSL ${GH_API_URL} | grep 'browser_download_url' | cut -d'"' -f4 | grep "${FILE_KEYWORD}")
echo -e "${INFO} Download URL: ${DOWNLOAD_URL}"

echo -e "${INFO} Installing ${PROJECT_NAME} ..."


mkdir -p $BIN_DIR || exit 1

if [[ -s "${BIN_DIR}/gobgpd" ]]; then
    FLAG_NOSERVICE=true
fi

# Dowload GoBGP
TMP_DIR=$(mktemp -d)
curl -fsLS "${DOWNLOAD_URL}" -o "${TMP_DIR}/tmp.tar.gz"
tar xf "${TMP_DIR}/tmp.tar.gz" -C ${TMP_DIR}
cp "${TMP_DIR}/gobgp" "${TMP_DIR}/gobgpd" "${BIN_DIR}/"
curl -fsLS "${GH_UTILS_URL_BASE}/gobgpd-inject.sh" -o "${BIN_DIR}/gobgpd-inject.sh"
chmod +x "${BIN_DIR}/gobgpd-inject.sh"
ln -sf "${BIN_DIR}/gobgp" /usr/bin/gobgp
rm -rf ${TMP_DIR}

curl -fsLS ${ZSH_COMP_URL} -o "/usr/share/zsh/vendor-completions/_gobgp"

if  [[ $(command -v zsh) ]]; then
    zsh -c "autoload -Uz compinit && compinit"
fi

# Init default configs
if [[ ! -s "${BIN_DIR}/gobgpd.conf" ]]; then
    curl -fsLS "${GH_UTILS_URL_BASE}/gobgpd.conf" -o "${BIN_DIR}/gobgpd.conf"
fi

if [[ ! -s "${BIN_DIR}/gobgpd-network.conf" ]]; then
    F="${BIN_DIR}/gobgpd-network.conf"
    echo "# Network example." > $F
    echo "# add 172.16.0.20/30 origin igp" >> $F
    echo "# Route Injection." >> $F
    echo "# add ....." >> $F
fi

# Install system Service
if [[ "${FLAG_NOSERVICE}" = false || "${FLAG_UPGRADE}" = true ]]; then
    echo -e "${INFO} Installing System Service ..."
    groupadd --system gobgpd -f
    id -u gobgpd > /dev/null 2>&1 || useradd --system -d ${BIN_DIR} -s /bin/bash -g gobgpd gobgpd
    chown -R gobgpd:gobgpd ${BIN_DIR}
    curl -fsLS "${GH_UTILS_URL_BASE}/gobgpd.service" -o "/etc/systemd/system/gobgpd.service"
    curl -fsLS "${GH_UTILS_URL_BASE}/gobgpd-network.service" -o "/etc/systemd/system/gobgpd-network.service"
    curl -fsLS "${GH_UTILS_URL_BASE}/gobgpd-network.timer" -o "/etc/systemd/system/gobgpd-network.timer"
    systemctl daemon-reload
    systemctl enable gobgpd.service gobgpd-network.timer
fi

echo -e "${INFO} Done."
