# dds-router
Fast DDS Router adjusted for Husarnet

## Demo

Create `compose.yaml` file:

```yaml
version: "2.3"

services:

  listener:
    build: .
    command: ros2 run demo_nodes_cpp listener

  dds_router:
    image: husarnet/dds-router
    restart: always
    network_mode: service:husarnet
    volumes:
      - ./router-config.yaml:/config.yaml
    command: bash -c "/wait_ds.sh && ddsrouter -c /config.yaml -r 10"

  husarnet:
    image: husarnet/husarnet
    restart: on-failure
    volumes:
      - /var/lib/husarnet
    sysctls:
      - net.ipv6.conf.all.disable_ipv6=0
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    environment:
      - HOSTNAME=rviz
      - JOINCODE=${HUSARNET_JOINCODE}
```

and run:

```
docker compose up
```