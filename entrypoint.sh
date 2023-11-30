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

    if [[ -z "$DISCOVERY_SERVER_LISTENING_PORT" && -z "$ROS_DISCOVERY_SERVER" ]]; then
        echo "Launching Initial Peers config"

        cp config.wan.template.yaml $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml

        export LOCAL_IP=$(echo $husarnet_api_response | yq .result.local_ip)
        yq -i '.participants[0].listening-addresses[0].ip = strenv(LOCAL_IP)' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
        yq -i '.participants[0].connection-addresses[0].ip = strenv(LOCAL_IP)' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
    else
        echo "Launching ROS Discovery Server config"

        cp config.discovery-server.template.yaml $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml

        # Set the local Discovery Server ID to the first element of the ID variable
        echo "Local Server ID: $DISCOVERY_SERVER_ID"
        yq -i '.participants[0].discovery-server-guid.id = env(DISCOVERY_SERVER_ID)' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml

        #  ==============================================
        # Checking if listening for incomming connections
        #  ===============================================

        yq -i '.participants[0].listening-addresses = []' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml

        if [[ -n "$DISCOVERY_SERVER_LISTENING_PORT" ]]; then
            echo "> Server config"
            # Check if the value is a number and smaller than 65535
            if [[ "$DISCOVERY_SERVER_LISTENING_PORT" =~ ^[0-9]+$ && $DISCOVERY_SERVER_LISTENING_PORT -lt 65535 ]]; then
                # DISCOVERY_SERVER_PORT is set and its value is smaller than 65535.

                export LOCAL_IP=$(echo $husarnet_api_response | yq .result.local_ip)

                yq -i '.participants[0].listening-addresses += 
                        { 
                            "ip": env(LOCAL_IP),
                            "port": env(DISCOVERY_SERVER_LISTENING_PORT),
                            "transport": "udp"
                        }' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml

                # TIPS:

                ## TIP 1:
                echo "On different hosts, set the ROS_DISCOVERY_SERVER=[$LOCAL_IP]:$DISCOVERY_SERVER_LISTENING_PORT"

                ## TIP 2:
                cp /superclient.template.xml $CFG_PATH/superclient_single.xml
                # Convert the decimal to a hexadecimal value
                hex_server_id=$(printf '%.2X' $DISCOVERY_SERVER_ID)

                # Replace XX in GUID_PREFIX with the hexadecimal value
                export GUID_PREFIX=$(echo "44.53.XX.5F.45.50.52.4F.53.49.4D.41" | sed "s/XX/$hex_server_id/")

                yq -i '.dds.profiles.participant.rtps.builtin.discovery_config.discoveryServersList.RemoteServer.+@prefix = env(GUID_PREFIX)' $CFG_PATH/superclient_single.xml
                yq -i '.dds.profiles.participant.rtps.builtin.discovery_config.discoveryServersList.RemoteServer.metatrafficUnicastLocatorList.locator.udpv6.address = env(LOCAL_IP)' $CFG_PATH/superclient_single.xml
                yq -i '.dds.profiles.participant.rtps.builtin.discovery_config.discoveryServersList.RemoteServer.metatrafficUnicastLocatorList.locator.udpv6.port = env(DISCOVERY_SERVER_LISTENING_PORT)' $CFG_PATH/superclient_single.xml
            else
                echo "Error: DISCOVERY_SERVER_LISTENING_PORT value is not a valid number or is greater than or equal to 65535."
                # Insert other commands here if needed
                exit 1
            fi
        else
            yq -i 'del(.participants[0].listening-addresses)' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
        fi

        #  ==============================================
        # Checking if connecting to other Discovery Servers
        #  ===============================================

        yq -i '.participants[0].connection-addresses = []' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml

        if [[ -n "$ROS_DISCOVERY_SERVER" ]]; then
            echo "> Client config"

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
            DS_REGEX="^(([a-zA-Z0-9-]+):([0-9]+)|\[(([a-fA-F0-9]{1,4}:){1,7}[a-fA-F0-9]{1,4}|[a-fA-F0-9]{0,4})\]:([0-9]+))$"

            # creating config for super_client
            cp /superclient.template.xml $CFG_PATH/superclient.xml
            yq -i '.dds.profiles.participant.rtps.builtin.discovery_config.discoveryServersList.RemoteServer = [ "placeholder1", "placeholder2" ]' $CFG_PATH/superclient.xml

            echo "Connecting to:"
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
                    if [ -z "${BASH_REMATCH[4]}" ]; then
                        # If it's in hostname:port format
                        HOST="${BASH_REMATCH[2]}"
                        export PORT="${BASH_REMATCH[3]}"

                        ipv6=$(echo $husarnet_api_response | yq .result.host_table | yq -r ".$HOST")

                        if [[ "$ipv6" == "null" || -z "$ipv6" ]]; then
                            echo "Error: IPv6 address not found for $HOST"
                            exit 1
                        else
                            export HOST=$ipv6
                        fi
                    else
                        # If it's in [ipv6addr]:port format
                        HOST="${BASH_REMATCH[4]}"
                        export PORT="${BASH_REMATCH[6]}"

                        # Extract all IP addresses from the host_table
                        IP_ADDRESSES=$(echo $husarnet_api_response | yq '.result.host_table[]')

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

                    yq -i '.participants[0].connection-addresses += 
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

            yq -i 'del(.dds.profiles.participant.rtps.builtin.discovery_config.discoveryServersList.RemoteServer[0])' $CFG_PATH/superclient.xml
            yq -i 'del(.dds.profiles.participant.rtps.builtin.discovery_config.discoveryServersList.RemoteServer[0])' $CFG_PATH/superclient.xml
        else
            yq -i 'del(.participants[0].connection-addresses)' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
        fi

    fi
}

create_config_lan_only() {
    cp config.lan.template.yaml $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
    # yq -i '.participants[0].domain = env(ROS_DOMAIN_ID_2)' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
}

WHITELIST_INTERFACES=$(strip_quotes "$WHITELIST_INTERFACES")
ROS_DISCOVERY_SERVER=$(strip_quotes "$ROS_DISCOVERY_SERVER")
DISCOVERY_SERVER_LISTENING_PORT=$(strip_quotes "$DISCOVERY_SERVER_LISTENING_PORT")
FILTER=$(strip_quotes "$FILTER")

if [[ $AUTO_CONFIG == "TRUE" ]]; then

    # Check the value of USE_HUSARNET
    if [[ $USE_HUSARNET == "FALSE" || $USE_HUSARNET == false || $USE_HUSARNET == 0 ]]; then
        echo "Using LAN setup."
        create_config_lan_only
        export husarnet_ready=false
    else
        for i in {1..7}; do
            husarnet_api_response=$(curl -s http://127.0.0.1:16216/api/status)

            # Check the exit status of curl. If it's 0, the command was successful.
            if [[ $? -eq 0 ]]; then
                if [ "$(echo $husarnet_api_response | yq -r .result.is_ready)" != "true" ]; then
                    if [[ $i -eq 7 ]]; then
                        echo "Husarnet API is not ready."
                        if [[ $EXIT_IF_HUSARNET_NOT_AVAILABLE == "TRUE" ]]; then
                            echo "Error: Exiting..."
                            exit 1
                        else
                            echo "Using LAN setup."
                            create_config_lan_only
                            export husarnet_ready=false
                            break
                        fi
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
                    if [[ $EXIT_IF_HUSARNET_NOT_AVAILABLE == "TRUE" ]]; then
                        echo "Error: Exiting..."
                        exit 1
                    else
                        echo "Using LAN setup."
                        create_config_lan_only
                        export husarnet_ready=false
                        break
                    fi
                else
                    echo "Failed to connect to Husarnet API endpoint. Retrying in 2 seconds..."
                    sleep 2
                fi
            fi
        done

    fi

    if [[ -n "${LOCAL_PARTICIPANT}" ]]; then
        yq -i '.participants += env(LOCAL_PARTICIPANT)' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
    else
        yq -i '.participants += load("/local-participant.yaml")' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
    fi

    if [[ $ROS_LOCALHOST_ONLY == "1" ]]; then
        if [[ "$ROS_DISTRO" == "iron" ]]; then
            yq -i '.participants[1].ignore-participant-flags = "filter_different_host"' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
            yq -i '.participants[1].whitelist-interfaces = []' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
        else
            yq -i '.participants[1].ignore-participant-flags = "no_filter"' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
            yq -i '.participants[1].whitelist-interfaces = [ "127.0.0.1" ]' $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml
        fi

    fi

    rm -f $CFG_PATH/config.yaml.tmp
    rm -f /tmp/loop_done_semaphore

    # Start a config_daemon
    rm -f $CFG_PATH/config_daemon_logs_pipe
    mkfifo $CFG_PATH/config_daemon_logs_pipe
    cat <$CFG_PATH/config_daemon_logs_pipe &
    pkill -f config_daemon.sh
    nohup ./config_daemon.sh >$CFG_PATH/config_daemon_logs_pipe 2>&1 &

    # wait for the semaphore indicating the loop has completed once
    while [ ! -f /tmp/loop_done_semaphore ]; do
        sleep 0.1 # short sleep to avoid hammering the filesystem
    done

fi

# setup dds router environment
source "/dds_router/install/setup.bash"

exec "$@"
