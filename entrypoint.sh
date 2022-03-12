#!/bin/bash
set -e

# setup dds router environment
source "/dds_router/install/setup.bash"
exec "$@"