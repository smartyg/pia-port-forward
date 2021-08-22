#!/bin/bash

#check environment variables: USER PASS
if [[ ! $USER || ! $PASS ]]
then
	echo This script requires 2 environment variables:
	echo USER    - the username
	echo PASS    - the password for the given username
	exit 1
fi

if [[ ! $RUNTIME_DIRECTORY || ! $CONFIGURATION_DIRECTORY ]]
then
	echo This script is intended to start from systemd, the following environment variables are now missing:
	echo CONFIGURATION_DIRECTORY
	echo RUNTIME_DIRECTORY
	exit 1
fi

if [ $# -ne 1 ]
then
	INSTANCE="general"
else
	INSTANCE="$1"
fi

TOKEN_URL="https://privateinternetaccess.com/gtoken/generateToken"

RUN_DIR="$RUNTIME_DIRECTORY"
SCRIPT_DIR="$CONFIGURATION_DIRECTORY"
CONF_DIR="${SCRIPT_DIR}/.."
TOKEN_FILE="${RUN_DIR}/../token"
PAYLOAD_FILE="${RUN_DIR}/payload"
PORT_FILE="${RUN_DIR}/port"
GATEWAY_FILE="${RUN_DIR}/../gateway"
IPADDR_FILE="${RUN_DIR}/../ipaddr"

# Run time variables, will be read from the run-dir
TOKEN=
TOKEN_EXPIRES=0
SIGNATURE=
PAYLOAD=
PAYLOAD_PORT=
PAYLOAD_EXPIRES=0
PORT=
IPADDR=

function set_variable
{
	[ $# -ne 2 ] && return 1

	local name="$1"
	local value="$2"

	printf -v "$name" '%s' "$value"
	return 0
}

function save_token
{
	[ $# -ne 2 ] && return 1

	local token="$1"
	local expires="$2"

	cat << EOF > "$TOKEN_FILE"
TOKEN="${token}"
TOKEN_EXPIRES="${expires}"
EOF
	return 0
}

function save_payload
{
	[ $# -ne 4 ] && return 1

	local signature="$1"
	local payload="$2"
	local payload_port="$3"
	local payload_expires="$4"

	cat << EOF > "$PAYLOAD_FILE"
SIGNATURE="${signature}"
PAYLOAD="${payload}"
PAYLOAD_PORT="${payload_port}"
PAYLOAD_EXPIRES="${payload_expires}"
EOF
	return 0
}

function save_port
{
	[ $# -ne 1 ] && return 1

	local port="$1"

	cat << EOF > "$PORT_FILE"
PORT="${port}"
EOF
	return 0
}

function token_timeout_timestamp
{
	date +"%c" --date='1 day' # Timestamp 24 hours
}

function request_token
{
	echo "request new token"
	local response=$(curl -s -u "${USER}:${PASS}" "${TOKEN_URL}")

	if [ "$(echo "${response}" | jq -r '.status')" != "OK" ]
	then
		echo -e "${RED}The token request response does not contain an OK status.${NC}"
		return 1
	fi

	echo "recieved a new token"

	local token=$(echo "${response}" | jq -r '.token')
	local token_expires=$(token_timeout_timestamp)

	set_variable TOKEN "${token}"
	set_variable TOKEN_EXPIRES "${token_expires}"
	save_token "${token}" "${token_expires}"

	echo "Token is now: ${TOKEN}"

	return 0
}

function request_payload
{
	echo "request new payload"
	is_token_expired && request_token || return 1

	echo "Token is: ${TOKEN}"

	local response=$(curl -sGk --data-urlencode "token=${TOKEN}" "https://${GATEWAY}:19999/getSignature")
	if [ "$(echo "$response" | jq -r '.status')" != "OK" ]
	then
		echo -e "${RED}The payload response does not contain an OK status.${NC}"
		echo "response: ${response}"
		return 1
	fi

	echo "recieved a new payload"

	local payload=$(echo "$response" | jq -r '.payload')
	local signature=$(echo "$response" | jq -r '.signature')

	local payload_token=$(echo "$payload" | base64 -d | jq -r '.token')
	local payload_port=$(echo "$payload" | base64 -d | jq -r '.port')
	local payload_expires=$(echo "$payload" | base64 -d | jq -r '.expires_at')

	set_variable SIGNATURE "${signature}"
	set_variable PAYLOAD "${payload}"
	set_variable PAYLOAD_PORT "${payload_port}"
	set_variable PAYLOAD_EXPIRES "${payload_expires}"
	save_payload "${signature}" "${payload}" "${payload_port}" "${payload_expires}"

	echo "Payload is now: ${PAYLOAD}"

	return 0
}

function request_port
{
	echo "open port"
	if [ is_payload_expired ]
	then
		request_payload
	fi

	echo "Payload is: ${PAYLOAD}"

	local response=$(curl -sGk --data-urlencode "payload=${PAYLOAD}" --data-urlencode "signature=${SIGNATURE}" "https://${GATEWAY}:19999/bindPort")
	if [ "$(echo "$response" | jq -r '.status')" != "OK" ]
	then
		echo -e "${RED}The port bind response does not contain an OK status.${NC}"
		return 1
	fi

	echo "Port ${PAYLOAD_PORT} is (re)binded"

	set_variable PORT "${PAYLOAD_PORT}"
	save_port "${PAYLOAD_PORT}"

	echo "Port is now: ${PORT}"

	return 0
}

function is_payload_expired
{
	local payload_expires_epoch=$(date --date="$PAYLOAD_EXPIRES" "+%s")
	local cur_epoch=$(date "+%s")

	[ "$payload_expires_epoch" -lt "$cur_epoch" ] && return 0
	return 1
}

function is_token_expired
{
	local token_expires_epoch=$(date --date="$TOKEN_EXPIRES" "+%s")
	local cur_epoch=$(date "+%s")
	
	[ "$token_expires_epoch" -lt "$cur_epoch" ] && return 0
	return 1
}

function run_scripts
{
	local port="$1"
	local old_port="$2"
	local payload_expires="$3"
	local gateway="$4"
	local ipaddr="$5"

	if [ -d "$SCRIPT_DIR" ]
	then
		for f in $(find "$SCRIPT_DIR" -follow -maxdepth 1 -executable -type f | sort)
		do
			local script_name=$(basename "${f}")
			echo "run ${script_name}"
			${f} "$port" "$old_port" "$payload_expires" "$gateway" "$ipaddr"
			[ $? -ne 0 ] && echo -e "script \"${script_name}\" returned with status $?."
		done
	fi
}

[ -e "$GATEWAY_FILE" ] && source "$GATEWAY_FILE"
if [[ ! $GATEWAY ]]
then
        echo "This script requires the gateway address to be availible in: ${GATEWAY_FILE}"
        exit 1
fi
[ -e "$TOKEN_FILE" ] && source "$TOKEN_FILE"
[ -e "$PAYLOAD_FILE" ] && source "$PAYLOAD_FILE"
[ -e "$PORT_FILE" ] && source "$PORT_FILE"
[ -e "$IPADDR_FILE" ] && source "$IPADDR_FILE"

OLD_PORT="$PORT"

request_port
if [ $? -ne 0 ]
then
	exit 1
fi

run_scripts "$PORT" "$OLD_PORT" "$PAYLOAD_EXPIRES" "$GATEWAY" "$IPADDR"

exit 0
