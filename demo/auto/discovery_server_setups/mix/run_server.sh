#!/bin/bash

cleanup() {
    echo "Shutting down Docker Compose..."
    docker compose -f compose.server.yaml down
}
trap cleanup EXIT

rm -f ./logs_pipe
mkfifo ./logs_pipe
cat <./logs_pipe &

export DOCKER0_IP=$(ip addr show docker0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
nohup docker compose -f compose.server.yaml up >./logs_pipe 2>&1 &

export ROS_LOCALHOST_ONLY=1
sudo ip link set lo multicast on

# just to make a time difference between two talkers
sleep 10

# Run ROS2 listener
ros2 run demo_nodes_cpp talker
