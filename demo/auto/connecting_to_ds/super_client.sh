#!/bin/bash

docker run --rm -it \
  --network host \
  -e ROS_DISCOVERY_SERVER=rosbot2r:11811 \
  -e DISCOVERY_SERVER_ID=10 \
  husarnet/ros2router:1.3.0 \
  cat /var/tmp/superclient.xml | awk '/\?xml version="1.0" encoding="UTF-8" \?/,0' > superclient.xml

export FASTRTPS_DEFAULT_PROFILES_FILE=$(pwd)/superclient.xml

# Run ROS2 listener
ros2 run demo_nodes_cpp listener
