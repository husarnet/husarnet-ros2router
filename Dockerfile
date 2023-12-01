FROM ubuntu:20.04 AS ddsrouter_builder

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
        python3 \
        cmake g++ pip wget git \
        libasio-dev \
        libtinyxml2-dev \
        libssl-dev \
        python3-sphinx \
        libyaml-cpp-dev

RUN pip3 install -U \
        colcon-common-extensions \
        vcstool \
        pyyaml \
        sphinx_rtd_theme \
        jsonschema

RUN mkdir -p /dds_router/src

WORKDIR /dds_router

COPY ddsrouter.repos colcon.meta /dds_router/

RUN vcs import src < ddsrouter.repos && \
    git clone --branch release-1.11.0 https://github.com/google/googletest src/googletest-distribution && \
    colcon build

FROM ubuntu:20.04

ARG TARGETARCH
ARG YQ_VERSION=v4.35.1

RUN apt-get update && apt-get install -y \
        curl \
        libyaml-cpp-dev \
        iputils-ping \
        python3.8 \
        libtinyxml2-6 \
        python3 && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

RUN curl -L https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${TARGETARCH} -o /usr/bin/yq && \
    chmod +x /usr/bin/yq

# COPY --from=ddsrouter_builder /dds_router/install /dds_router/install
COPY --from=ddsrouter_builder /dds_router /dds_router

COPY entrypoint.sh /
COPY config.lan.template.yaml /
COPY config.discovery-server.template.yaml /
COPY config.wan.template.yaml /
COPY filter.yaml /
COPY local-participant.yaml /
COPY config_daemon.sh /
COPY superclient.template.xml /

ENV AUTO_CONFIG=TRUE
ENV USE_HUSARNET=TRUE
ENV ROS_DISCOVERY_SERVER=
ENV DISCOVERY_SERVER_ID=0
ENV DISCOVERY_SERVER_LISTENING_PORT=

ENV EXIT_IF_HUSARNET_NOT_AVAILABLE=FALSE
ENV EXIT_IF_HOST_TABLE_CHANGED=FALSE

ENV ROS_LOCALHOST_ONLY=0

ENV FILTER=
ENV LOCAL_PARTICIPANT=

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "ddsrouter", "-c", "/var/tmp/DDS_ROUTER_CONFIGURATION.yaml" ]

