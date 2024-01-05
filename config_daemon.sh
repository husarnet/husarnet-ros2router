#!/bin/bash

# check process PID with "ps aux | grep config_daemon.sh"
# kill the process with "pkill -f config_daemon.sh"

CFG_PATH=/var/tmp
HASH_FILE="$CFG_PATH/prev_filter_hash.txt"

# Function to calculate MD5 hash of a file
calculate_hash() {
    md5sum "$1" | awk '{ print $1 }'
}

rm -rf $HASH_FILE
rm -rf $CFG_PATH/config.yaml.tmp

while true; do
    if [ -f $CFG_PATH/config.yaml ]; then
        # config.yaml exists
        cp $CFG_PATH/config.yaml $CFG_PATH/config.yaml.tmp
        cp $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml $CFG_PATH/config.yaml
    else
        # config.yaml does not exist
        cp $CFG_PATH/DDS_ROUTER_CONFIGURATION_base.yaml $CFG_PATH/config.yaml
        touch $CFG_PATH/config.yaml.tmp
    fi

    if [[ $husarnet_ready == true ]]; then
        husarnet_api_response=$(curl -s http://$HUSARNET_API_HOST:16216/api/status)

        if [[ $? -ne 0 ]]; then
            echo "Failed to connect to Husarnet API endpoint."
            pkill ddsrouter
            exit 1
        fi

        # check if we are in Initial Peers (WAN) config
        if [[ -z "$DISCOVERY_SERVER_LISTENING_PORT" && -z "$ROS_DISCOVERY_SERVER" ]]; then
            export restart_ddsrouter=false
            export local_ip=$(echo $husarnet_api_response | yq .result.local_ip)

            peers=$(echo $husarnet_api_response | yq '.result.whitelist')
            : ${peers_previous:=$peers}

            peers_no=$(echo $peers | yq '. | length')

            yq -i 'del(.participants[] | select(.name == "HusarnetParticipant").connection-addresses[0])' $CFG_PATH/config.yaml

            for ((i = 0; i < $peers_no; i++)); do
                # Extract husarnet_address for the current peer using jq
                export i
                export address=$(echo $peers | yq -r '.[env(i)]')

                if [ "$local_ip" != "$address" ]; then
                    yq -i '(.participants[] | select(.name == "HusarnetParticipant").connection-addresses) += {"ip": env(address), "port": 11811} ' $CFG_PATH/config.yaml
                fi
            done

            # check if peers table has changed
            if [[ -n $(diff <(echo $peers | yq .) <(echo $peers_previous | yq .)) ]]; then
                restart_ddsrouter=true
            fi
        fi
    fi

    # Update filter.tmp.yaml
    if [[ -n "${FILTER}" ]]; then
        echo "$FILTER" >$CFG_PATH/filter.tmp.yaml
    else
        cp /filter.yaml $CFG_PATH/filter.tmp.yaml
    fi

    # Calculate current hash of filter.tmp.yaml
    current_hash=$(calculate_hash "$CFG_PATH/filter.tmp.yaml")

    # Read the previous hash, if it exists
    previous_hash=""
    if [[ -f "$HASH_FILE" ]]; then
        previous_hash=$(cat "$HASH_FILE")
    fi

    # Compare hashes and run gomplate if different
    if [[ "$current_hash" != "$previous_hash" ]]; then
        cat "$CFG_PATH/filter.tmp.yaml" | gomplate >"$CFG_PATH/filter.yaml"
    fi

    yq -i '. * load("'"$CFG_PATH"'/filter.yaml")' "$CFG_PATH/config.yaml"

    # Store the current hash for next comparison
    echo "$current_hash" >"$HASH_FILE"

    # remove comments
    yq -i '... comments=""' $CFG_PATH/config.yaml

    # Use sed to replace '//' with '/'
    sed -i 's#//#/#g' $CFG_PATH/config.yaml

    if ! cmp -s $CFG_PATH/config.yaml $CFG_PATH/config.yaml.tmp; then
        # mv is an atomic operation on POSIX systems (cp is not)
        cp $CFG_PATH/config.yaml $CFG_PATH/DDS_ROUTER_CONFIGURATION.yaml.tmp &&
            mv $CFG_PATH/DDS_ROUTER_CONFIGURATION.yaml.tmp $CFG_PATH/DDS_ROUTER_CONFIGURATION.yaml

        # we need to trigger the FileWatcher, because mv doesn't do that
        echo "" >>$CFG_PATH/DDS_ROUTER_CONFIGURATION.yaml
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
