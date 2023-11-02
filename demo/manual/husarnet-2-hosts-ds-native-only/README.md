# 2 hosts only DDS Router in Docker

## Quick Start

2 hosts need to be connected to the same Husarnet network.

### 1st host

```bash
export DOCKER_UID=$(id -u)
export DOCKER_GID=$(id -g)
export ROUTER_CONFIG=router-config.talker.yaml
docker compose up
```

And in a new terminal:

```bash
export ROS_DOMAIN_ID=1
ros2 run demo_nodes_cpp talker
```

### 2nd host

```bash
export DOCKER_UID=$(id -u)
export DOCKER_GID=$(id -g)
export ROUTER_CONFIG=router-config.listener.yaml
docker compose up
```

And in a new terminal:

```bash
export ROS_DOMAIN_ID=0
ros2 run demo_nodes_cpp listener
```