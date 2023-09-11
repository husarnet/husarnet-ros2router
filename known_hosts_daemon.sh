#!/bin/bash

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

    peers=$(curl -s http://127.0.0.1:16216/api/status | yq '.result.whitelist')
    peers_no=$(echo $peers | yq '. | length')

    for (( i=0; i<$peers_no; i++ )); do
        # Extract husarnet_address for the current peer using jq
        export i
        export address=$(echo $peers | yq -r '.[env(i)]')

        yq -i '.participants[1].connection-addresses += {"ip": env(address), "port": 11811} ' config.yaml 
    done

    if ! cmp -s config.yaml config.yaml.tmp; then
        # mv is an atomic operation on POSIX systems (cp is not)
        cp config.yaml DDS_ROUTER_CONFIGURATION.yaml.tmp && \
        mv DDS_ROUTER_CONFIGURATION.yaml.tmp DDS_ROUTER_CONFIGURATION.yaml

        # we need to trigger the FileWatcher, because mv doesn't do that
        echo "" >> DDS_ROUTER_CONFIGURATION.yaml
    fi

    sleep 5
done
