#!/bin/bash

# Check the argument and exit early if it's not valid
if [[ "$1" != "listener" ]] && [[ "$1" != "talker" ]]; then
    echo "Invalid argument. Please use 'listener' or 'talker'."
    exit 1
fi

cleanup() {
    echo "Shutting down ros2router..."
    docker stop ros2router
}
trap cleanup EXIT

if [[ "$ROS_DISTRO" == "iron" ]]; then
    echo "ROS_DISTRO is set to iron"

    docker run --rm -d \
    --name ros2router \
    --net host \
    --env IGNORE_PARTICIPANTS_FLAGS=filter_different_host \
    husarnet/ros2router:1.3.0

    export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
    export ROS_STATIC_PEERS=127.0.0.1
else
    echo "ROS_DISTRO is set to humble"

    docker run --rm -d \
    --name ros2router \
    --net host \
    --env ROS_LOCALHOST_ONLY=1 \
    husarnet/ros2router:1.3.0
    
    export ROS_LOCALHOST_ONLY=1
fi

# Check the argument and run the corresponding ROS2 node
if [[ "$1" == "listener" ]]; then
    ros2 run demo_nodes_cpp listener
elif [[ "$1" == "talker" ]]; then
    ros2 run demo_nodes_cpp talker
else
    echo "Invalid argument. Please use 'listener' or 'talker'."
    exit 1
fi

# Run the corresponding ROS2 node based on the argument
ros2 run demo_nodes_cpp "$1"