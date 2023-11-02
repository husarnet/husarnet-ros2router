#!/bin/bash

cleanup() {
    echo "Shutting down Docker Compose..."
    docker compose -f compose.server.yaml down
}
trap cleanup EXIT

docker compose -f compose.server.yaml up -d

export FASTRTPS_DEFAULT_PROFILES_FILE=$(pwd)/localhost-udp-only.xml

# Run ROS2 listener
ros2 run demo_nodes_cpp talker
