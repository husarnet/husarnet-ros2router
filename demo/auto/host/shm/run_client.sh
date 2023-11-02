#!/bin/bash

cleanup() {
    echo "Shutting down Docker Compose..."
    docker compose -f compose.client.yaml down
}
trap cleanup EXIT

docker compose -f compose.client.yaml up -d

export ROS_LOCALHOST_ONLY=1

# Run ROS2 listener
ros2 run demo_nodes_cpp listener
