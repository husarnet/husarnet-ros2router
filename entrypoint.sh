#!/bin/bash
set -e

# setup dds router environment
source "/dds_router/install/setup.bash"

husarnet_api_response=$(curl -s http://127.0.0.1:16216/api/status)

if [ "$(echo $husarnet_api_response | yq -r .result.is_ready)" == "true" ]; then

    if [ -z "${ROS_DOMAIN_ID}" ]; then
        export ROS_DOMAIN_ID=0
    fi

    if [ "$DISCOVERY" == "SERVER" ]; then
        yq '.participants[1].listening-addresses[0].domain = strenv(DS_HOSTNAME)' config.server.template.yaml > DDS_ROUTER_CONFIGURATION.yaml
        yq -i '.participants[0].domain = env(ROS_DOMAIN_ID)' DDS_ROUTER_CONFIGURATION.yaml
    fi

    if [ "$DISCOVERY" == "CLIENT" ]; then
        yq '.participants[1].connection-addresses[0].addresses[0].domain = strenv(DS_HOSTNAME)' config.client.template.yaml > DDS_ROUTER_CONFIGURATION.yaml
        yq -i '.participants[0].domain = env(ROS_DOMAIN_ID)' DDS_ROUTER_CONFIGURATION.yaml
    fi

    if [ "$DISCOVERY" == "AUTO" ]; then
        cp config.auto.template.yaml DDS_ROUTER_CONFIGURATION.yaml
        
        export LOCAL_IP=$(echo $husarnet_api_response | yq .result.local_ip)
        yq -i '.participants[1].listening-addresses[0].ip = strenv(LOCAL_IP)' DDS_ROUTER_CONFIGURATION.yaml
        yq -i '.participants[1].connection-addresses[0].ip = strenv(LOCAL_IP)' DDS_ROUTER_CONFIGURATION.yaml
        yq -i '.participants[0].domain = env(ROS_DOMAIN_ID)' DDS_ROUTER_CONFIGURATION.yaml

        cp DDS_ROUTER_CONFIGURATION.yaml DDS_ROUTER_CONFIGURATION_base.yaml

        nohup ./known_hosts_daemon.sh &> known_hosts_daemon_logs.txt &
    fi
else
    echo "Husarnet Daemon not available"
fi

exec "$@"