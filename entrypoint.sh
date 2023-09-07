#!/bin/bash
set -e

# setup dds router environment
source "/dds_router/install/setup.bash"

if [ "$DS_ROLE" == "SERVER" ]; then
    envsubst < config.server.template.yaml > DDS_ROUTER_CONFIGURATION.yaml
fi

if [ "$DS_ROLE" == "CLIENT" ]; then
    envsubst < config.client.template.yaml > DDS_ROUTER_CONFIGURATION.yaml
fi

exec "$@"