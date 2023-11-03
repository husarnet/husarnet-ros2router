#!/bin/bash

# ROS_DISCOVERY_SERVER env works with IPv6 address from FastDDS `v2.8.0`:
# - ROS 2 Iron - contains FastDDS v2.10.2
# - ROS 2 Humble - includes FastDDS v2.6.6
export ROS_DISCOVERY_SERVER=rosbot2r:11811

# Run ROS2 listener
ros2 run demo_nodes_cpp listener
