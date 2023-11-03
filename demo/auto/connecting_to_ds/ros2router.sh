#!/bin/bash

cleanup() {
    echo "Shutting down ros2router"
    docker stop ros2router
}
trap cleanup EXIT

docker run --rm -d \
  --network host \
  --name ros2router \
  -e ROS_DISCOVERY_SERVER=rosbot2r:11811 \
  -e DISCOVERY_SERVER_ID=10 \
  husarnet/ros2router:1.3.0

# Run ROS2 listener
ros2 run demo_nodes_cpp listener
