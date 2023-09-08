#!/bin/bash

while true; do
    # sleep 5
    echo "Hello, World!"
    cp DDS_ROUTER_CONFIGURATION_base.yaml config.yaml
    peers=$(curl -s http://127.0.0.1:16216/api/status | yq '.result.peers')
    peers_no=$(echo $peers | yq '. | length')

    for (( i=0; i<$peers_no; i++ )); do
        # Extract husarnet_address for the current peer using jq
        export address=$(echo $peers | yq -r '.[$i].husarnet_address')

        yq '.participants[$i].connection-addresses += {"domain": env(address), "port": 11811} ' config.yaml 
        # Add the address to connection-addresses in the config file using yq
        # yq eval -i ".participants[] | select(.name == \"RemoteParticipant\") .connection-addresses += [{\"domain\": \"$address\", \"port\": 11811}]" $config_file
    done

    cp config.yaml DDS_ROUTER_CONFIGURATION.yaml
    sleep 5
done
