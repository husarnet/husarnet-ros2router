#!/bin/bash

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

# Run ROS2 listener
ros2 run demo_nodes_cpp listener
