#!/bin/bash

PPF_RUN_DIR="@RUNDIR@/ppf"
PPF_GATEWAY_FILE="${PPF_RUN_DIR}/gateway"
IP_ADDR_FILE="${PPF_RUN_DIR}/ipaddr"

[ ! -d "$PPF_RUN_DIR" ] && exit 1

[ ! $route_vpn_gateway ] && echo "GATEWAY=${route_vpn_gateway}" > "$PPF_GATEWAY_FILE"
[ ! $4 ] && echo "IPADDR=${4}" > "$IP_ADDR_FILE"

exit 0
