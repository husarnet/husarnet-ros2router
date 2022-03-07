FROM ros:galactic AS fastdds_builder

# Use bash instead of sh for the RUN steps
SHELL ["/bin/bash", "-c"]

# Install ros packages and dependencies
RUN apt-get update && apt-get install -y \
    # Fast DDS dependencies
    libssl-dev \
    libasio-dev \
    cmake g++ pip wget git \
    libyaml-cpp-dev

WORKDIR /fastdds_overlay
COPY fastdds.repos colcon.meta /fastdds_overlay/
RUN source /opt/ros/galactic/setup.bash && \
    # Download sources
    mkdir src && \
    vcs import src < fastdds.repos && \
    # Install rmw_fastrtps_cpp dependencies without installing ros-galactic-rmw-fastrtps-cpp
    sed -i 's/ros-'$ROS_DISTRO'-rmw-cyclonedds-cpp | ros-'$ROS_DISTRO'-rmw-connextdds | ros-'$ROS_DISTRO'-rmw-fastrtps-cpp/ros-'$ROS_DISTRO'-rmw-dds-common/' /var/lib/dpkg/status && \
    rosdep update --rosdistro $ROS_DISTRO && \
    rosdep install --from-paths src --ignore-src -y && \
    # Build overlay
    colcon build && \
    # Cleanup
    apt autoremove -y && \
    rm -rf log/ build/ src/ colcon.meta fastdds.repos && \
    rm -rf /var/lib/apt/lists/*

FROM ros:galactic-ros-core

ENV DS_HOSTNAME=ds

RUN apt-get update && apt-get install -y \
    libyaml-cpp-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

COPY --from=fastdds_builder /fastdds_overlay/install /fastdds_overlay/install

COPY ros_entrypoint.sh /

COPY wait_for_discovery_server.sh /wait_ds.sh

RUN chmod +x /ros_entrypoint.sh
RUN chmod +x /wait_ds.sh

