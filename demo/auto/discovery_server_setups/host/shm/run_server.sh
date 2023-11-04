#!/bin/bash

cleanup() {
    echo "Shutting down Docker Compose..."
    docker compose -f compose.server.yaml down
}
trap cleanup EXIT

export MY_UID=$(id -u)
export MY_GID=$(id -g)
docker compose -f compose.server.yaml up -d

export ROS_LOCALHOST_ONLY=1
sudo ip link set lo multicast on

# Run ROS2 listener
ros2 run demo_nodes_cpp talker
