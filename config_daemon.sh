#!/bin/bash

# check process PID with "ps aux | grep config_daemon.sh"
# kill the process with "pkill -f config_daemon.sh"

while true; do
    if [ -f config.yaml ]; then
        # config.yaml exists
        cp config.yaml config.yaml.tmp
        cp DDS_ROUTER_CONFIGURATION_base.yaml config.yaml
    else
        # config.yaml does not exist
        cp DDS_ROUTER_CONFIGURATION_base.yaml config.yaml
        touch config.yaml.tmp
    fi

    if [[ $husarnet_ready == true ]]; then
        husarnet_api_response=$(curl -s http://127.0.0.1:16216/api/status)

        if [[ $? -ne 0 ]]; then
            echo "Failed to connect to Husarnet API endpoint."
            pkill ddsrouter
            exit 1
        fi

        # check if we are in Initial Peers (WAN) config
        if [[ -z "$DS_LISTENING_PORT" && -z "$ROS_DISCOVERY_SERVER" ]]; then
            export restart_ddsrouter=false
            export local_ip=$(echo $husarnet_api_response | yq .result.local_ip)

            peers=$(echo $husarnet_api_response | yq '.result.whitelist')
            : ${peers_previous:=$peers}

            peers_no=$(echo $peers | yq '. | length')

            yq -i 'del(.participants[1].connection-addresses[0])' config.yaml

            for ((i = 0; i < $peers_no; i++)); do
                # Extract husarnet_address for the current peer using jq
                export i
                export address=$(echo $peers | yq -r '.[env(i)]')

                if [ "$local_ip" != "$address" ]; then
                    yq -i '.participants[1].connection-addresses += {"ip": env(address), "port": 11811} ' config.yaml
                fi
            done

            # check if peers table has changed
            if [[ -n $(diff <(echo $peers | yq .) <(echo $peers_previous | yq .)) ]]; then
                restart_ddsrouter=true
            fi
        fi
    fi

    yq -i '.allowlist = load("filter.yaml").allowlist' config.yaml
    yq -i '.blocklist = load("filter.yaml").blocklist' config.yaml
    yq -i '.builtin-topics = load("filter.yaml").builtin-topics' config.yaml

    if ! cmp -s config.yaml config.yaml.tmp; then
        # mv is an atomic operation on POSIX systems (cp is not)
        cp config.yaml DDS_ROUTER_CONFIGURATION.yaml.tmp &&
            mv DDS_ROUTER_CONFIGURATION.yaml.tmp DDS_ROUTER_CONFIGURATION.yaml

        # we need to trigger the FileWatcher, because mv doesn't do that
        echo "" >>DDS_ROUTER_CONFIGURATION.yaml
    fi

    if [ "$restart_ddsrouter" == "true" ]; then
        echo "Host table changed."

        if [[ $EXIT_IF_HOST_TABLE_CHANGED == "TRUE" ]]; then
            echo "Exiting."
            pkill ddsrouter
            exit 1
        else
            echo "If you want to include new peers, restart the ddsrouter service."
        fi
    fi

    # indicate that one loop is done
    touch /tmp/loop_done_semaphore

    sleep 5
done
