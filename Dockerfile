FROM ubuntu:22.04 AS ddsrouter_builder

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
    colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release  && \
    rm -rf build log src

FROM ubuntu:22.04

ARG TARGETARCH
ARG YQ_VERSION=v4.35.1
ARG GOMPLATE_VERSION=v3.11.6

RUN apt-get update && apt-get install -y \
        gosu \
        curl \
        libyaml-cpp-dev \
        iputils-ping \
        libtinyxml2-dev \
        python3 \
        iproute2 && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

RUN curl -L https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${TARGETARCH} -o /usr/bin/yq && \
    chmod +x /usr/bin/yq

RUN curl -L https://github.com/hairyhenderson/gomplate/releases/download/${GOMPLATE_VERSION}/gomplate_linux-${TARGETARCH} -o /usr/bin/gomplate && \
    chmod +x /usr/bin/gomplate

COPY --from=ddsrouter_builder /dds_router /dds_router

COPY entrypoint.sh /
COPY run_auto_config.sh /

COPY participant.husarnet.ds.yaml /
COPY participant.husarnet.wan.yaml /
COPY participant.lan.yaml /
COPY participant.shm.yaml /
COPY participant.lo.yaml /
COPY participant.if.yaml /
COPY participant.echo.yaml /

COPY filter.yaml /
COPY config.base.yaml /
COPY config_daemon.sh /
COPY superclient.template.xml /

ENV AUTO_CONFIG=TRUE
ENV PARTICIPANTS=husarnet,shm,lo
ENV HUSARNET_API_HOST=127.0.0.1
ENV ROS_DISCOVERY_SERVER=
ENV DISCOVERY_SERVER_ID=-1
ENV EXIT_IF_HOST_TABLE_CHANGED=FALSE

ENV ROS_DOMAIN_ID=
ENV ROS_NAMESPACE=

ENV FILTER=
ENV CONFIG_BASE=
ENV USER=root

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "ddsrouter", "-c", "/var/tmp/DDS_ROUTER_CONFIGURATION.yaml" ]

