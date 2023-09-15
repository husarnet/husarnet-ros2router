# dds-router

Fast DDS Router Docker image with auto-configuration for Husarnet VPN.

## Environment Variables

### general

| env | default value | description |
| - | - | - |
| `AUTO_CONFIG` | `TRUE` | If set to `TRUE` the `DDS_ROUTER_CONFIGURATION.yaml` will be created automatically based on all others environemt variables. Set it to `FALSE` to use a custom DDS Router config instead **ignoring all others environemt variables**. |
| `USE_HUSARNET` | `TRUE` | If set to `TRUE` the DDS Router configuration file will be filled with Husarnet peers addresses. If set to `FALSE` the DDS Router will work only in the local network using a default DDS simple discovery protocol. In this case the domain id for the first participant is set to `ROS_DOMAIN_ID` variable value, and the domain id for the second participant is always `0`. If `ROS_DOMAIN_ID=0`, then the domain id for the first participant is set to `77` (there could not be two participants with domain id equals to `0`). |
| `FAIL_IF_HUSARNET_NOT_AVAILABLE` | `FALSE` | If set to `FALSE` and can't reach Husarnet Daemon HTTP API the system behaviour is the same as if `USE_HUSARNET=FALSE`. If set to `TRUE` the container is stopped in case of no Husarnet Daemon API connection. |
| `ROS_DOMAIN_ID` | `0` | from `0` to `232`. |
| `LOCAL_TRANSPORT` | `udp` | `udp` for UDP based local DDS setup, `builtin` for a shared memory based local DDS setup (if using `builtin` with `--network host`, remember to add also `--ipc host `). |
| `DISCOVERY` | `WAN` | `WAN` for the [WAN Participant (initial peers)](https://eprosima-dds-router.readthedocs.io/en/latest/rst/user_manual/participants/wan.html#user-manual-participants-wan) setup, `SERVER` or `CLIENT` for [Local Discovery Server Participant](https://eprosima-dds-router.readthedocs.io/en/latest/rst/user_manual/participants/local_discovery_server.html#user-manual-participants-local-discovery-server) setup. |
| `DS_HOSTNAME` | `master` | The Husarnet hostname of the device with `DISCOVERY=SERVER` (you need to specify the same `DS_HOSTNAME` both on `SERVER` and `CLIENT` devices). Don't use it if `DISCOVERY=WAN`. |
| `DS_CLIENT_ID` | `1` | The ID of the client if `DISCOVERY=CLIENT`. Each client conntected to the Discovery Server need to has a differnet `DS_CLIENT_ID`. Don't use it if `DISCOVERY=WAN`. |
| `DS_SERVER_ID` | `0` | The ID of the server. You need to set if both `DISCOVERY=CLIENT` or `DISCOVERY=SERVER`. Don't use it if `DISCOVERY=WAN`. |


## Quick Start

### Option 1: Initial Peers config

1. Connect both hosts to the same Husarnet network (eg. named `host_A` and `host_B`).

2. On both `host_A` and `host_B` execute:

```bash
docker run \
--detach \
--restart=unless-stopped \
--network host \
-e ROS_DOMAIN_ID \
husarnet/dds-router:v2.0.0
```

3. Start a chatter demo:

- on the `host_A`:

```bash
ros2 run demo_nodes_cpp talker
```

- on the `host_B`:

```bash
ros2 run demo_nodes_cpp listener
```

### Option 2: Discovery Server config

1. Connect both hosts to the same Husarnet network (eg. named `host_A` and `host_B`).

2. Execute on `host_A`:

```bash
docker run \
--detach \
--restart=unless-stopped \
--network host \
-e DISCOVERY=SERVER \
-e DS_HOSTNAME=host_A \
husarnet/dds-router:v2.0.0
```

3. Execute on `host_B`:

```bash
docker run \
--detach \
--restart=unless-stopped \
--network host \
-e DISCOVERY=CLIENT \
-e DS_HOSTNAME=host_A \
husarnet/dds-router:v2.0.0
```

4. Start a chatter demo:

- on the `host_A`:

```bash
ros2 run demo_nodes_cpp talker
```

- on the `host_B`:

```bash
ros2 run demo_nodes_cpp listener
```

### Option 3: custom config

1. Connect both hosts to the same Husarnet network (eg. named `host_A` and `host_B`).

2. Create a DDS Router config file on the `host_A`:

```bash
user@host_A:~$ vim config.yaml
```

with the following content:


```yaml
version: v3.0

allowlist:
  - name: "rt/chatter"
    type: "std_msgs::msg::dds_::String_"

participants:

  - name: SimpleParticipant
    kind: local
    domain: 0

  - name: ServerDSParticipant
    kind: local-discovery-server
    discovery-server-guid:
      id: 200
    listening-addresses:
      - domain: host_A
        port: 11811
        transport: udp
```

3. Create a DDS Router config file on the `host_B`:

```bash
user@host_B:~$ vim config.yaml
```

with the following content:


```yaml
version: v3.0

allowlist:
  - name: "rt/chatter"
    type: "std_msgs::msg::dds_::String_"

participants:

  - name: SimpleParticipant
    kind: local
    domain: 0

  - name: ClientDSParticipant
    kind: local-discovery-server
    discovery-server-guid:
      id: 202
    connection-addresses:
      - discovery-server-guid:
          id: 200
        addresses:
          - domain: host_A 
            port: 11811
            transport: udp
```

4. On both `host_A` and `host_B` execute (in the same folder as `config.yaml` file):

```bash
docker run --name dds-router \
  --restart=unless-stopped \
  --network host \
  --ipc host \
  --user $(id -u):$(id -g) \
  -v $(pwd)/config.yaml:/config.yaml \
  -v /etc/group:/etc/group:ro \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/shadow:/etc/shadow:ro \
  -e AUTO_CONFIG=FALSE \
  husarnet/dds-router:v2.0.0 bash -c "ddsrouter -c /config.yaml -r 10"
```

5. Start a chatter demo:

- on the `host_A`:

```bash
export ROS_DOMAIN_ID=0
ros2 run demo_nodes_cpp talker
```

- on the `host_B`:

```bash
export ROS_DOMAIN_ID=0
ros2 run demo_nodes_cpp listener
```

## Topic Filtering

The repo contains the `create_filter.sh` script allowing you to automate the process of creating a [DDS Router filter rules](https://eprosima-dds-router.readthedocs.io/en/latest/rst/user_manual/configuration.html#id1):

```bash
curl -s https://raw.githubusercontent.com/husarnet/dds-router/topic-filtering/create_filter.sh > create_filter.sh
chmod +x create_filter.sh
./create_filter.sh /chatter /cmd_vel > filter.yaml
```

Modify the `filter.yaml` file if needed and assign it as a bind mount volume:

```bash
docker run \
--detach \
--restart=unless-stopped \
--network host \
-e ROS_DOMAIN_ID \
-v $(pwd)/filter.yaml:/filter.yaml \
husarnet/dds-router:v2.0.0
```



<!-- ## devel cheatsheet

```bash
docker run --rm -it \
  --network host \
  --ipc host \
  -v $(pwd)/config.client.template.yaml:/config.client.template.yaml \
  -v $(pwd)/config.server.template.yaml:/config.server.template.yaml \
  -v $(pwd)/config.simple.template.yaml:/config.simple.template.yaml \
  -v $(pwd)/known_hosts_daemon.sh:/known_hosts_daemon.sh \
  -v $(pwd)/entrypoint.sh:/entrypoint.sh \
  -e DS_HOSTNAME=rosbot2r \
  husarnet/dds-router:v2.0.0 bash
``` -->
