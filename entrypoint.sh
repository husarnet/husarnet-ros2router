#!/bin/bash
set -e

# setup dds router environment
source "/dds_router/install/setup.bash"


husarnet_api_response=$(curl -s http://127.0.0.1:16216/api/status)

if [ "$(echo $husarnet_api_response | yq -r .result.is_ready)" == "true" ]; then

    if [ "$DS_ROLE" == "SERVER" ]; then
        yq '.participants[1].listening-addresses[0].domain = strenv(DS_HOSTNAME)' config.server.template.yaml > DDS_ROUTER_CONFIGURATION.yaml
        yq -i '.participants[0].domain = env(ROS_DOMAIN_ID)' DDS_ROUTER_CONFIGURATION.yaml
    fi

    if [ "$DS_ROLE" == "CLIENT" ]; then
        yq '.participants[1].connection-addresses[0].addresses[0].domain = strenv(DS_HOSTNAME)' config.client.template.yaml > DDS_ROUTER_CONFIGURATION.yaml
        yq -i '.participants[0].domain = env(ROS_DOMAIN_ID)' DDS_ROUTER_CONFIGURATION.yaml
    fi

    if [ "$DS_ROLE" == "NONE" ]; then
        cp config.simple.template.yaml DDS_ROUTER_CONFIGURATION.yaml
        
        export HOST=$(echo $husarnet_api_response | yq .result.local_ip)
        yq -i '.participants[1].listening-addresses[0].ip = strenv(HOST)' DDS_ROUTER_CONFIGURATION.yaml
        yq -i '.participants[1].connection-addresses[0].ip = strenv(HOST)' DDS_ROUTER_CONFIGURATION.yaml
        yq -i '.participants[0].domain = env(ROS_DOMAIN_ID)' DDS_ROUTER_CONFIGURATION.yaml

        cp DDS_ROUTER_CONFIGURATION.yaml DDS_ROUTER_CONFIGURATION_base.yaml

        nohup ./known_hosts_daemon.sh &> known_hosts_daemon_logs.txt &
    fi
else
    echo "Husarnet Daemon not available"
fi

exec "$@"