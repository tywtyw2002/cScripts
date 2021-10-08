#!/usr/bin/env bash
#
# Inject Network or route prefix after gobgpup.


BIN_DIR="/opt/gobgp"
BIN_PROG="${BIN_DIR}/gobgp"
CONF_PATH="${BIN_DIR}/gobgpd-network.conf"

if [[ ! -s "${CONF_PATH}" ]]; then
    exit 0
fi

count=0

echo "Add GoBGP Route Prefix."
while read line; do
    if [[ ! "$line" =~ ^# ]]; then
        $BIN_PROG global rib $line
        ((count++))
    fi
done < $CONF_PATH

echo "Route Injection Done. Total ${count} Records."