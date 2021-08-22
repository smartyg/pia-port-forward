#!/bin/bash

#check environment variables
# USER PASS GATEWAY
if [[ ! $USER || ! $PASS || ! $GATEWAY ]]
then
	echo This script requires 3 environment variables:
	echo USER    - the username
	echo PASS    - the password for the given username
	echo GATEWAY - the gateway address
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

# Run time variables, will be read from the run-dir
TOKEN=
TOKEN_EXPIRES=0
SIGNATURE=
PAYLOAD=
PAYLOAD_PORT=
PAYLOAD_EXPIRES=0
PORT=

function set_variable
{
	if [ $# -ne 2 ]
	then
		return 1
	fi

	local name="$1"
	local value="$2"

	printf -v "$name" '%s' "$value"
	return 0
}

function save_token
{
	if [ $# -ne 2 ]
	then
		return 1
	fi

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
	if [ $# -ne 4 ]
	then
		return 1
	fi

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
	if [ $# -ne 1 ]
	then
		return 1
	fi

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
	local response=$(curl -s -u "${USER}:${PASS}" "${TOKEN_URL}")

	if [ "$(echo "${response}" | jq -r '.status')" != "OK" ]
	then
		echo -e "${RED}The token request response does not contain an OK status.${NC}"
		return 1
	fi
	local token=$(echo "${response}" | jq -r '.token')
	local token_expires=$(token_timeout_timestamp)

	set_variable TOKEN "${token}"
	set_variable TOKEN_EXPIRES "${token_expires}"
	save_token "${token}" "${token_expires}"

	return 0
}

function request_payload
{
	if [ is_token_expired ]
	then
		request_token
		if [ $? -ne 0 ]
		then
			return 1
		fi
	fi

	local response=$(curl -sGk --data-urlencode "token=${TOKEN}" "https://${GATEWAY}:19999/getSignature")
	if [ "$(echo "$response" | jq -r '.status')" != "OK" ]
	then
		echo -e "${RED}The payload response does not contain an OK status.${NC}"
		return 1
	fi

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

	return 0
}

function request_port
{
	if [ is_payload_expired ]
	then
		request_payload
		if [ $? -ne 0 ]
		then
			return 1
		fi
	fi

	local response=$(curl -sGk --data-urlencode "payload=${PAYLOAD}" --data-urlencode "signature=${SIGNATURE}" "https://${GATEWAY}:19999/bindPort")
	if [ "$(echo "$response" | jq -r '.status')" != "OK" ]
	then
		echo -e "${RED}The port bind response does not contain an OK status.${NC}"
		return 1
	fi

	set_variable PORT "${PAYLOAD_PORT}"
	save_port "${PAYLOAD_PORT}"

	return 0
}

function is_payload_expired
{
	local payload_expires_epoch=$(date --date='$PAYLOAD_EXPIRES' "+%s")
	local cur_epoch=$(date "+%s")

	if [ "$payload_expires_epoch" -lt "$cur_epoch" ]
	then
		return 0
	fi

	return 1
}

function is_token_expired
{
	local token_expires_epoch=$(date --date='$TOKEN_EXPIRES' "+%s")
	local cur_epoch=$(date "+%s")
	if [ "$token_expires_epoch" -lt "$cur_epoch" ]
	then
		return 0
	fi
	return 1
}

function run_scripts
{
	if [ -d "$SCRIPT_DIR" ]
	then
		for f in $(find "$SCRIPT_DIR" -follow -maxdepth 1 -executable -type f | sort)
		do
			local script_name=$(basename "${f}")
			echo "run ${script_name}"
			${f} $@
			[ $? -ne 0 ] && echo -e "script \"${script_name}\" returned with status $?."
		done
	fi
}

[ -e "$TOKEN_FILE" ] && source "$TOKEN_FILE"
[ -e "$PAYLOAD_FILE" ] && source "$PAYLOAD_FILE"
[ -e "$PORT_FILE" ] && source "$PORT_FILE"

OLD_PORT="$PORT"

request_port
if [ $? -ne 0 ]
then
	exit 1
fi

run_scripts "$PORT" "$OLD_PORT" "$PAYLOAD_EXPIRES" "$GATEWAY"

exit 0