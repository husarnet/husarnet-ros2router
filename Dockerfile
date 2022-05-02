FROM ubuntu:20.04 AS ddsrouter_builder

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3 \
    cmake g++ pip wget git \
    libasio-dev \
    libtinyxml2-dev \
    libssl-dev \
    libyaml-cpp-dev \
    python3-sphinx

RUN pip3 install -U \
    colcon-common-extensions \
    vcstool \
    sphinx_rtd_theme

RUN mkdir -p /dds_router/src

WORKDIR /dds_router

COPY ddsrouter.repos colcon.meta /dds_router/

RUN vcs import src < ddsrouter.repos && \
    git clone --branch release-1.10.0 https://github.com/google/googletest src/googletest-distribution && \
    colcon build

# FROM ros:galactic-ros-core
FROM ubuntu:22.04

ENV DS_HOSTNAME=ds

RUN apt-get update && apt-get install -y \
    libyaml-cpp-dev \
    iputils-ping \
    python3.8 \
    libtinyxml2-6 \
    python3 && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# COPY --from=ddsrouter_builder /dds_router/install /dds_router/install
COPY --from=ddsrouter_builder /dds_router /dds_router

COPY entrypoint.sh /
COPY wait_for_discovery_server.sh /usr/local/bin/wait_ds.sh

RUN chmod +x /entrypoint.sh && \
    chmod +x /usr/local/bin/wait_ds.sh

ENTRYPOINT [ "/entrypoint.sh" ]
