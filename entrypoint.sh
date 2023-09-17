#!/bin/bash

# is_ipv6() {
#     local ip=$1
#     # Simple regex to validate IPv6 format
#     local ipv6_regex="^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$"
#     [[ $ip =~ $ipv6_regex ]]
# }

create_config_husarnet() {
    if [ -z "${ROS_DOMAIN_ID}" ]; then
        export ROS_DOMAIN_ID=0
    fi

    # Check if DISCOVERY_SERVER_PORT environment variable exists
    if [ -z "${DISCOVERY_SERVER_PORT}" ]; then
        # DISCOVERY_SERVER_PORT is not set.

        # Check if ROS_DISCOVERY_SERVER environment variable exists
        if [ -z "${ROS_DISCOVERY_SERVER}" ]; then
            echo "ROS_DISCOVERY_SERVER is not set. Defaulting to Initial Peers config"

            cp config.wan.template.yaml DDS_ROUTER_CONFIGURATION_base.yaml

            export LOCAL_IP=$(echo $husarnet_api_response | yq .result.local_ip)
            yq -i '.participants[1].listening-addresses[0].ip = strenv(LOCAL_IP)' DDS_ROUTER_CONFIGURATION_base.yaml
            yq -i '.participants[1].connection-addresses[0].ip = strenv(LOCAL_IP)' DDS_ROUTER_CONFIGURATION_base.yaml
        else
            # Regular expression to match hostname:port or [ipv6addr]:port
            regex="^(([a-zA-Z0-9-]+):([0-9]+)|\[(([a-fA-F0-9]{1,4}:){1,7}[a-fA-F0-9]{1,4}|[a-fA-F0-9]{0,4})\]:([0-9]+))$"

            if [[ "${ROS_DISCOVERY_SERVER}" =~ $regex ]]; then
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
                    # Check if the HOST IP exists in the IP_ADDRESSES list
                    if echo "$IP_ADDRESSES" | grep -q "$HOST"; then
                        echo "Address found: $HOST"
                        export HOST
                    else
                        echo "Address not found in the host_table."
                        exit 1
                    fi
                fi

                yq '.participants[1].connection-addresses[0].addresses[0].ip = strenv(HOST)' config.client.template.yaml >DDS_ROUTER_CONFIGURATION_base.yaml
                yq -i '.participants[1].connection-addresses[0].addresses[0].port = env(PORT)' DDS_ROUTER_CONFIGURATION_base.yaml
                yq -i '.participants[1].discovery-server-guid.id = env(DS_CLIENT_ID)' DDS_ROUTER_CONFIGURATION_base.yaml
                yq -i '.participants[1].connection-addresses[0].discovery-server-guid.id = env(DS_SERVER_ID)' DDS_ROUTER_CONFIGURATION_base.yaml

                echo "ROS_DISCOVERY_SERVER is set with HOST: $HOST and PORT: $PORT."
            else
                echo "ROS_DISCOVERY_SERVER does not have a valid format."
                exit 1
            fi
        fi

    else
        # Check if the value is a number and smaller than 65535
        if [[ "$DISCOVERY_SERVER_PORT" =~ ^[0-9]+$ && $DISCOVERY_SERVER_PORT -lt 65535 ]]; then
            # DISCOVERY_SERVER_PORT is set and its value is smaller than 65535.
            export LOCAL_IP=$(echo $husarnet_api_response | yq .result.local_ip)
            yq '.participants[1].listening-addresses[0].ip = strenv(LOCAL_IP)' config.server.template.yaml >DDS_ROUTER_CONFIGURATION_base.yaml
            yq -i '.participants[1].listening-addresses[0].port = env(DISCOVERY_SERVER_PORT)' DDS_ROUTER_CONFIGURATION_base.yaml
        else
            echo "DISCOVERY_SERVER_PORT value is not a valid number or is greater than or equal to 65535."
            # Insert other commands here if needed
            exit 1
        fi
    fi
}

create_config_local() {
    if [[ -z "${ROS_DOMAIN_ID}" || "${ROS_DOMAIN_ID}" -eq 0 ]]; then
        export ROS_DOMAIN_ID=77

        echo "In LAN setup ROS_DOMAIN_ID can't be 0"
        echo "Starting with ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
    fi

    cp config.local.template.yaml DDS_ROUTER_CONFIGURATION_base.yaml
}

if [[ $AUTO_CONFIG == "TRUE" ]]; then

    # Check the value of USE_HUSARNET
    if [[ $USE_HUSARNET == "FALSE" ]]; then
        echo "Using LAN setup."
        create_config_local
        export husarnet_ready=false
    else
        for i in {1..7}; do
            husarnet_api_response=$(curl -s http://127.0.0.1:16216/api/status)

            # Check the exit status of curl. If it's 0, the command was successful.
            if [[ $? -eq 0 ]]; then
                if [ "$(echo $husarnet_api_response | yq -r .result.is_ready)" != "true" ]; then
                    if [[ $i -eq 7 ]]; then
                        echo "Husarnet API is not ready."
                        if [[ $FAIL_IF_HUSARNET_NOT_AVAILABLE == "TRUE" ]]; then
                            echo "Exiting."
                            exit 1
                        else
                            echo "Using LAN setup."
                            create_config_local
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
                    if [[ $FAIL_IF_HUSARNET_NOT_AVAILABLE == "TRUE" ]]; then
                        echo "Exiting."
                        exit 1
                    else
                        echo "Using LAN setup."
                        create_config_local
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

    yq -i '.participants[0].domain = env(ROS_DOMAIN_ID)' DDS_ROUTER_CONFIGURATION_base.yaml
    yq -i '.participants[0].transport = env(LOCAL_TRANSPORT)' DDS_ROUTER_CONFIGURATION_base.yaml

    rm -f config.yaml.tmp
    rm -f /tmp/loop_done_semaphore

    # nohup ./config_daemon.sh &>config_daemon_logs.txt &

    # # wait for the semaphore indicating the loop has completed once
    # while [ ! -f /tmp/loop_done_semaphore ]; do
    #     sleep 0.1 # short sleep to avoid hammering the filesystem
    # done

fi

# setup dds router environment
source "/dds_router/install/setup.bash"

exec "$@"
