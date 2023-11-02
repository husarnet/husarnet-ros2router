#!/bin/bash

cleanup() {
    echo "Shutting down Docker Compose..."
    docker compose -f compose.client.yaml down
}
trap cleanup EXIT

export UID=$(id -u)
export GID=$(id -g)
docker compose -f compose.client.yaml up -d

export ROS_LOCALHOST_ONLY=1
sudo ip link set lo multicast on

# Run ROS2 listener
ros2 run demo_nodes_cpp listener
