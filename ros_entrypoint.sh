#!/bin/bash
set -e

# setup ros2 environment
source /opt/ros/galactic/setup.bash

# setup Fast DDS RMW
source /fastdds_overlay/install/setup.bash
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp

exec "$@"