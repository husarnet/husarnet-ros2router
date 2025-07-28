#!/bin/bash

CFG_PATH=/var/tmp

strip_quotes() {
    local value="$1"

    # Remove double quotes from the beginning and end
    value="${value%\"}"
    value="${value#\"}"

    # Remove single quotes from the beginning and end
    value="${value%\'}"
    value="${value#\'}"

    echo "$value"
}

create_config_husarnet() {
    if [ -z "${ROS_DOMAIN_ID}" ]; then
        export ROS_DOMAIN_ID=0
    fi


    export LOCAL_IP=$(echo $husarnet_api_response | yq .result.local_ip)
    if [[ -z "$LOCAL_IP" || $LOCAL_IP == "null" ]]; then
      export LOCAL_IP=$(echo $husarnet_api_response | yq -r .result.live.local_ip)
    fi

    if [[ -z "$ROS_DISCOVERY_SERVER" ]]; then
        echo "Launching Initial Peers config"

        yq -i '.participants += load("/participant.husarnet.wan.yaml")' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml

        yq -i '(.participants[] | select(.name == "HusarnetParticipant").listening-addresses[0].ip) = strenv(LOCAL_IP)' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
        yq -i '(.participants[] | select(.name == "HusarnetParticipant").connection-addresses[0].ip) = strenv(LOCAL_IP)' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
    else
        echo "Launching ROS Discovery Server config"

        yq -i '.participants += load("/participant.husarnet.ds.yaml")' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml

        # Splitting the string into an array using semicolon as the delimiter
        IFS=';' read -ra DS_LIST <<<"$ROS_DISCOVERY_SERVER"

        # Process the array
        NEW_LIST=()
        for entry in "${DS_LIST[@]}"; do
            # If the entry is empty, replace it with "_EMPTY_"
            if [ -z "$entry" ]; then
                NEW_LIST+=("_EMPTY_")
            else
                NEW_LIST+=("$entry")
            fi
        done

        # Join back into a string
        IFS=";"
        NEW_STR="${NEW_LIST[*]}"

        # Splitting the modified string into an array for final result
        IFS=';' read -ra DS_LIST <<<"$NEW_STR"

        # Regular expression to match hostname:port or [ipv6addr]:port
        DS_REGEX="^(([a-zA-Z0-9-]+)(:[0-9]+)?|\[(([a-fA-F0-9]{1,4}:){1,7}[a-fA-F0-9]{1,4}|[a-fA-F0-9]{0,4})\](:[0-9]+)?)$"

        # creating config for super_client
        cp /superclient.template.xml $CFG_PATH/superclient.xml
        yq -i '.dds.profiles.participant.rtps.builtin.discovery_config.discoveryServersList.RemoteServer = [ "placeholder1", "placeholder2" ]' $CFG_PATH/superclient.xml

        # Loop over Discovery Servers
        current_id=0
        for ds in ${DS_LIST[@]}; do
            # If the current element is _EMPTY_, skip further processing in this iteration
            if [ "$ds" = "_EMPTY_" ]; then
                ((current_id++))
                continue
            fi

            if [[ "${ds}" =~ $DS_REGEX ]]; then
                # Extract HOST and PORT from the match results
                if [[ -n ${BASH_REMATCH[2]} ]]; then
                    # If it's in hostname:port format
                    HOST="${BASH_REMATCH[2]}"
                    export PORT="${BASH_REMATCH[3]//:/}"
                    if [ -z "$PORT" ]; then
                        export PORT="11811"
                    fi

                    # TODO: search aliases too
                    ipv6=$(echo $husarnet_api_response | yq .result.host_table | yq -r ".$HOST")
                    if [[ "$ipv6" == "null" || -z "$ipv6" ]]; then
                      ipv6=$(echo $husarnet_api_response | yq -r ".result.config.dashboard.peers[] | select(.hostname == \"$HOST\") | .address")
                    fi

                    if [[ "$ipv6" == "null" || -z "$ipv6" ]] && [[ "$HOST" == "husarnet-local" ]]; then
                        ipv6=$(echo $husarnet_api_response | yq .result.live.local_ip)
                    fi

                    if [[ "$ipv6" == "null" || -z "$ipv6" ]]; then
                        echo "Error: IPv6 address not found for $HOST"
                        exit 1
                    else
                        export HOST=$ipv6
                    fi
                elif [[ -n ${BASH_REMATCH[4]} ]]; then
                    # If it's in [ipv6addr]:port format
                    HOST="${BASH_REMATCH[4]}"
                    export PORT="${BASH_REMATCH[6]//:/}"
                    if [ -z "$PORT" ]; then
                        export PORT="11811"
                    fi

                    # Extract all IP addresses from the host_table
                    IP_ADDRESSES=$(echo $husarnet_api_response | yq '.result.host_table[]')
                    if [[ -z "$IP_ADDRESSES" ]]; then
                      IP_ADDRESSES=$(echo $husarnet_api_response | yq '.result.config.dashboard.peers[].address')
                    fi

                    # Iterate over each address in IP_ADDRESSES
                    address_found=false
                    IFS=$'\n' # Set Internal Field Separator to newline for the loop
                    for address in $IP_ADDRESSES; do
                        if [[ "$address" == "$HOST" ]]; then
                            address_found=true
                            break
                        fi
                    done

                    if $address_found; then
                        export HOST
                    else
                        echo "Error: $HOST address not found"
                        exit 1
                    fi
                fi

                if [[ ! ($PORT -le 65535) ]]; then
                    echo "Discovery Server Port is not a valid number or is outside the valid range (0-65535)."
                    exit 1
                fi

                export SERVER_ID=${current_id}
                ((current_id++))

                if [[ $LOCAL_IP == $HOST ]]; then
                    echo "> Server config"
                    export DISCOVERY_SERVER_ID=$SERVER_ID

                    yq -i '(.participants[] | select(.name == "HusarnetParticipant").listening-addresses) += 
                        { 
                            "ip": strenv(HOST), 
                            "port": env(PORT), 
                            "transport": "udp"
                        }' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml

                else
                    echo "> Client config"
                    yq -i '(.participants[] | select(.name == "HusarnetParticipant").connection-addresses) += 
                            { 
                                "discovery-server-guid": 
                                { 
                                    "ros-discovery-server": true, 
                                    "id": env(SERVER_ID) 
                                }, 
                                "addresses": 
                                [ 
                                    { 
                                        "ip": strenv(HOST), 
                                        "port": env(PORT), 
                                        "transport": "udp" 
                                    } 
                                ] 
                            }' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
                fi
                echo "[$HOST]:$PORT (Server ID: $SERVER_ID)"

                # XML config for client (optional)
                # # Convert the decimal to a hexadecimal value
                hex_server_id=$(printf '%.2X' $SERVER_ID)

                # Replace XX in GUID_PREFIX with the hexadecimal value
                export GUID_PREFIX=$(echo "44.53.XX.5F.45.50.52.4F.53.49.4D.41" | sed "s/XX/$hex_server_id/")

                yq -i '.dds.profiles.participant.rtps.builtin.discovery_config.discoveryServersList.RemoteServer += 
                        {
                            "+@prefix": env(GUID_PREFIX),
                            "metatrafficUnicastLocatorList": 
                            {
                                "locator": 
                                {
                                    "udpv6": 
                                    {
                                        "address": env(HOST),
                                        "port": env(PORT)
                                    }
                                }
                            }
                        }' $CFG_PATH/superclient.xml

            else
                echo "Error: ROS_DISCOVERY_SERVER does not have a valid format: $ds"
                exit 1
            fi
        done

        # Check if DISCOVERY_SERVER_ID is not set or outside the range 0-255
        if [[ ! "$DISCOVERY_SERVER_ID" =~ ^[0-9]+$ ]] || [[ "$DISCOVERY_SERVER_ID" -lt 0 ]] || [[ "$DISCOVERY_SERVER_ID" -gt 255 ]]; then
            echo "DISCOVERY_SERVER_ID=${DISCOVERY_SERVER_ID} is not valid number. Setting a random value (10-255)."
            # Generate a random value between 10 and 255 and export it
            export DISCOVERY_SERVER_ID=$((RANDOM % 246 + 10))
        fi

        yq -i '(.participants[] | select(.name == "HusarnetParticipant").discovery-server-guid.id) = env(DISCOVERY_SERVER_ID)' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml

        yq -i 'del(.dds.profiles.participant.rtps.builtin.discovery_config.discoveryServersList.RemoteServer[0])' $CFG_PATH/superclient.xml
        yq -i 'del(.dds.profiles.participant.rtps.builtin.discovery_config.discoveryServersList.RemoteServer[0])' $CFG_PATH/superclient.xml

        echo "> DS Local Server ID: $DISCOVERY_SERVER_ID"
        echo "> TIP: Find a Super Client config in $CFG_PATH/superclient.xml"
    fi
}

WHITELIST_INTERFACES=$(strip_quotes "$WHITELIST_INTERFACES")
ROS_DISCOVERY_SERVER=$(strip_quotes "$ROS_DISCOVERY_SERVER")
FILTER=$(strip_quotes "$FILTER")

run_auto_config() {
    cp config.base.yaml $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml

    if [[ -n "${CONFIG_BASE}" ]]; then
        yq -i '. * env(CONFIG_BASE)' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
    fi

    # Verify that PARTICIPANTS is set and not empty
    if [ -z "$PARTICIPANTS" ]; then
        echo "Error: PARTICIPANTS environment variable is not set."
        exit 1
    fi

    # # Regex to verify the format
    # if ! [[ $PARTICIPANTS =~ ^([a-z]+,?)*$ ]]; then
    #     echo "Error: PARTICIPANTS env format is incorrect."
    #     exit 1
    # fi

    # Regex to verify the format
    if ! [[ $PARTICIPANTS =~ ^([a-z]+(-[a-zA-Z0-9*]+)?,?)+$ ]]; then
        echo "Error: PARTICIPANTS env format is incorrect."
        exit 1
    fi

    # Initialize all participant variables to false
    PARTICIPANT_HUSARNET_ENABLED=false
    PARTICIPANT_LO_ENABLED=false
    PARTICIPANT_SHM_ENABLED=false
    PARTICIPANT_LAN_ENABLED=false
    PARTICIPANT_ECHO_ENABLED=false
    PARTICIPANT_IF_LIST=()

    # Function to enable a participant
    enable_participant() {
        case $1 in
        husarnet)
            PARTICIPANT_HUSARNET_ENABLED=true
            ;;
        lo)
            PARTICIPANT_LO_ENABLED=true
            ;;
        shm)
            PARTICIPANT_SHM_ENABLED=true
            ;;
        lan)
            PARTICIPANT_LAN_ENABLED=true
            ;;
        echo)
            PARTICIPANT_ECHO_ENABLED=true
            ;;
        if-*)
            interface_pattern=${1#if-}
            if [[ $interface_pattern == *"*"* ]]; then
                # Handle wildcard interface patterns
                for intf in /sys/class/net/${interface_pattern#*/}; do
                    intf=${intf#/sys/class/net/}
                    if [[ -d "/sys/class/net/$intf" ]]; then
                        PARTICIPANT_IF_LIST+=("$intf")
                    fi
                done
            else
                # Handle specific interface name
                PARTICIPANT_IF_LIST+=("$interface_pattern")
            fi
            ;;
        *)
            # Ignore any other values
            ;;
        esac
    }

    # Enable participants based on the PARTICIPANTS variable
    IFS=',' read -ra ADDR <<<"$PARTICIPANTS"
    for i in "${ADDR[@]}"; do
        enable_participant "$i"
    done

    # Check the value of HUSARNET_PARTICIPANT_ENABLED
    if [[ $PARTICIPANT_HUSARNET_ENABLED == false ]]; then
        # echo "Using LAN setup."
        echo "Don't using Husarnet participants."
        export husarnet_ready=false
    else
        echo ">> Husarnet participant enabled"
        echo "Checking if Husarnet API (http://$HUSARNET_API_HOST:16216) is ready "
        for i in {1..7}; do
            husarnet_api_response=$(curl -s http://$HUSARNET_API_HOST:16216/api/status)

            # Check the exit status of curl. If it's 0, the command was successful.
            if [[ $? -eq 0 ]]; then
                # Determine daemon readiness – works with both old and new APIs
                ready=$(
                    echo "$husarnet_api_response" |
                    yq -r '.result.is_ready // .result.live.health.summary // "false"'
                )

                if [[ "$ready" != "true" ]]; then
                    if [[ $i -eq 7 ]]; then
                        echo "Husarnet API is not ready."
                        echo "Error: Exiting..."
                        exit 1
                    else
                        echo "Husarnet API is not ready"
                        sleep 2
                    fi
                else
                    echo "Husarnet API is ready!"
                    create_config_husarnet
                    export husarnet_ready=true
                    break
                fi
            else
                if [[ $i -eq 5 ]]; then
                    echo "Can't reach Husarnet Daemon HTTP API after 5 retries"
                    echo "Error: Exiting..."
                    exit 1
                else
                    echo "Failed to connect to Husarnet API endpoint. Retrying in 2 seconds..."
                    sleep 2
                fi
            fi
        done

    fi

    if [[ $PARTICIPANT_LO_ENABLED == true ]]; then
        echo ">> lo participant enabled"
        yq -i '.participants += load("/participant.lo.yaml")' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
    fi

    if [[ $PARTICIPANT_SHM_ENABLED == true ]]; then
        echo ">> SHM participant enabled"
        yq -i '.participants += load("/participant.shm.yaml")' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
    fi

    if [[ $PARTICIPANT_LAN_ENABLED == true ]]; then
        echo ">> LAN participant enabled"
        yq -i '.participants += load("/participant.lan.yaml")' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
    fi

    if [[ $PARTICIPANT_ECHO_ENABLED == true ]]; then
        echo ">> ECHO participant enabled"
        yq -i '.participants += load("/participant.echo.yaml")' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
    fi

    if [[ ${#PARTICIPANT_IF_LIST[@]} -gt 0 ]]; then
        echo ">> IF participants enabled"
        yq -i '.participants += load("/participant.if.yaml")' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
        for interface in "${PARTICIPANT_IF_LIST[@]}"; do

            # Get the IP address associated with the network interface
            export local_ip=$(ip addr show $interface | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

            if [ ! -z "$local_ip" ]; then
                echo "$interface: $local_ip"
                yq -i '(.participants[] | select(.name == "IfParticipant").whitelist-interfaces) += strenv(local_ip)' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
            else
                echo "$interface: no IP address assigned"
            fi
        done
    fi

    if [ -n "${ROS_DOMAIN_ID}" ]; then
        yq -i '(.participants[] | select (.domain).domain ) = env(ROS_DOMAIN_ID)' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
    fi

    rm -f $CFG_PATH/config.yaml.tmp
    rm -f /tmp/loop_done_semaphore

    # Start a config_daemon
    rm -f $CFG_PATH/config_daemon_logs_pipe
    mkfifo $CFG_PATH/config_daemon_logs_pipe

    cat <$CFG_PATH/config_daemon_logs_pipe &

    pkill -f config_daemon.sh

    # Starting config_daemon.sh as the specified user and redirecting output to the pipe
    nohup ./config_daemon.sh >$CFG_PATH/config_daemon_logs_pipe 2>&1 &

    # wait for the semaphore indicating the loop has completed once
    while [ ! -f /tmp/loop_done_semaphore ]; do
        sleep 0.1 # short sleep to avoid hammering the filesystem
    done
}

run_auto_config
