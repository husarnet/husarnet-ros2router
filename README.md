# husarnet-ros2router

[![Build a Docker Image](https://github.com/husarnet/husarnet-ros2router/actions/workflows/build_push.yaml/badge.svg)](https://github.com/husarnet/husarnet-ros2router/actions/workflows/build_push.yaml)

The `husarnet/ros2router` Docker image is designed to effortlessly bridge local ROS 2 nodes, even those with standard DDS settings, to nodes on different machines across various networks. It runs seamlessly with the Husarnet VPN, ensuring that neither distance nor network differences become obstacles in your ROS 2 projects. 

Compatible with both natively-executed ROS 2 nodes and those operating within Docker.

Based on [DDS Router](https://github.com/eProsima/DDS-Router) project by eProsima.

## How it works?

1. **Run ROS 2 Nodes on Two Machines:**

   Whether they're in the same LAN or different ones, execute the following on your first machine:

   ```bash
   ROS_LOCALHOST_ONLY=1
   ros2 run demo_nodes_cpp listener 
   ```
   
   And on your second machine:

   ```bash
   ROS_LOCALHOST_ONLY=1
   ros2 run demo_nodes_cpp talker
   ```

2. **Husarnet Account Setup**

- Register for a free account on [app.husarnet.com](https://app.husarnet.com/).
- Establish a new Husarnet network in the Online Dashboard.
- Click the **[Add element]** button and copy the code under the **Join Code** tab.

3. **Connect Devices to Husarnet:**

   If you're on Ubuntu, follow these steps:
 
   - Install Husarnet:

   ```bash
   curl https://install.husarnet.com/install.sh | sudo bash
   ```

   - Connect to the Husarnet network:

   ```bash
   sudo husarnet join <paste-join-code-here>
   ```

4. **Start the DDS Router Docker Image:**

   Launch the following command on each host:

   ```bash
   docker run \
   --detach \
   --restart=unless-stopped \
   --network host \
   husarnet/ros2router:1.4.0
   ```

5. **Verify Connection:**

   Open the terminal for the `listener`. You should start seeing incoming messages.

This guide provides a straightforward setup. Dive deeper and explore additional options and examples in the sections below.

## General Example

The all-in-one example, that should be fine in most cases (both with ROS 2 nodes running on host and in Docker containers) is in the `demo/auto/general` directory.

```yaml
services:
  ros2router:
    image: husarnet/ros2router:1.8.0
    network_mode: host
    ipc: shareable
    volumes:
      - ./filter.yaml:/filter.yaml
    environment:
      - DISCOVERY_SERVER_ID=2
      - DISCOVERY_SERVER_LISTENING_PORT=8888
      - PARTICIPANTS=husarnet,shm
      - |
        CONFIG_BASE=
          version: v5.0
          specs:
            discovery-trigger: writer
          participants:
            - name: LocalParticipant
              kind: local
              domain: 0
              transport: builtin
      - ROS_DOMAIN_ID=123

  talker:
    image: husarion/ros2-demo-nodes:humble
    ipc: service:ros2router
    network_mode: service:ros2router
    volumes:
      - ./shm-only.xml:/shm-only.xml
    environment:
      - FASTRTPS_DEFAULT_PROFILES_FILE=/shm-only.xml
      - ROS_DOMAIN_ID=123
    command: ros2 run demo_nodes_cpp talker

# On the same host to connect to LocalParticipant, just execute:
# export ROS_LOCAHOST_ONLY=1
# ros2 run demo_nodes_cpp talker

# On the other host, to listen to /chatter topic:
# 
# Option 1: ROS 2 Iron (assuming "laptop" is the husarnet hostname of the host running ros2router):
# export ROS_DISCOVERY_SERVER=;;laptop:8888
# ros2 run demo_nodes_cpp listener
# 
# Option 2: ROS 2 Humble:
# Modify superclient.xml to point to the host with ros2router (line 31)
# export FASTRTPS_DEFAULT_PROFILES_FILE=${PWD}/superclient.xml
# ros2 run demo_nodes_cpp listener
```

## Environment Variables

### Husarnet VPN related

| env | default value | description |
| - | - | - |
| `PARTICIPANTS` | `husarnet,shm,lo` | The coma separated list of paticipants in the ROS 2 Router configuration. Possible values are: `husarnet`, `shm`, `lo`, `lan`, `if-<if-name-optional-wildcard>`. If unset of empty you need to use a custom DDS router configuration file |
| `ROS_DISCOVERY_SERVER` | | If set the `HusarnetParticipant` will work in the [Disocovery Server setup](https://eprosima-dds-router.readthedocs.io/en/latest/rst/user_manual/participants/local_discovery_server.html#user-manual-participants-local-discovery-server). Set it to one of the following formats: `<husarnet-ipv6-addr>:<discovery-server-port>` or `<husarnet-hostname>:<discovery-server-port>` to connect as the Client to the device acting as a Discovery Server. To specify multiple addresses, use semicolons as separators. The server's ID is determined by its position in the list (starting from `0`). If there's an empty space between semicolons, it indicates that the respective ID is available. Eg. `ROS_DISCOVERY_SERVER=";;abc:123;;;def:456"` means that the ID of `abc:123` is `2` and ID of `def` is `5`. If one of the addresses is the same as the hosts Husarnet IPv6 address, then the Discovery Server - Server config is launch on the host. |
| `DISCOVERY_SERVER_ID` | `-1` | The ID of the local Discovery Server. If the server config is launched (one of the addresses specified in `ROS_DISCOVERY_SERVER` is the same as host's Husarnet address), the value of `DISCOVERY_SERVER_ID` env is ignored and the ID from `ROS_DISCOVERY_SERVER` env is used. If the value is outside of the `0-255` range, then the random value (from `10-255` range) is used instead |
| `ROS_DOMAIN_ID` | | If set it changes the default `domain: 0` for all participants with `kind: local` (basically all instead of `HusarnetParticipant` working in the Discovery Server config)  |
| `EXIT_IF_HOST_TABLE_CHANGED` | `FALSE` | Valid only if `ROS_DISCOVERY_SERVER` envs is unset and thus starting the **Initial Peers** config. This env is useful in connection with `restart: always` Docker policy - it restarts the DDS Router with a new Initial Peers list applied (the Initial Peers list is not updated by the DDS Router in runtime)  |
| `USER` | `root` | Allowing you to run the DDS Router as a different user (useful to enable SHM communication between host and Docker container) |
| `HUSARNET_API_HOST` | `127.0.0.1` | The IPv4 address where Husarnet Daemon is running (If using a different address than `127.0.0.1` remember also to run the Husarnet Daemon with a `HUSARNET_DAEMON_API_INTERFACE` env setup ) |
| `CONFIG_BASE` | | providing some optional, extra config to the ROS 2 Router. Default config base is [here](./config.base.yaml). Find available config options in [the DDS Router documentation](https://eprosima-dds-router.readthedocs.io/en/latest/rst/user_manual/configuration.html#specs-configuration) |
| `FILTER` |  |  It's alternative to providing `/filter.yaml` as a volume |

## Topic Filtering

The Docker image for the Husarnet ROS 2 Router can accept a portion of the typical ROS 2 Router configuration `*.yaml` file. This segment only includes the `allowlist`, `blocklist`, and `builtin-topics` sections. The provided configuration is then integrated with the automatically generated config file content.

Here's a sample of the `filter.yaml` file:

Example of the `filter.yaml` file:

```yaml
allowlist:
  - name: "rt/camera/color/image_raw/theora"
    type: "theora_image_transport::msg::dds_::Packet_"
  - name: "rt/camera/color/image_raw/compressed"
    type: "sensor_msgs::msg::dds_::CompressedImage_"
  - name: "rt/cmd_vel"
    type: "geometry_msgs::msg::dds_::Twist_"
blocklist: []
builtin-topics: []
```

Note that each ROS 2 topic name is preceded with `rX/` prefix (more [here](https://design.ros2.org/articles/topic_and_service_names.html)):

| **ROS Subsystem** | **Prefix** |
| - | - |
| ROS Topics | `rt` |
| ROS Service Request | `rq` |
| ROS Service Response | `rr` |
| ROS Service | `rs` |
| ROS Parameter | `rp` |
| ROS Action | `ra` |
 
The repository includes the `create_filter.sh` script, which facilitates the automated creation of [DDS Router filter rules](https://eprosima-dds-router.readthedocs.io/en/latest/rst/user_manual/configuration.html#id1):

```bash
curl -s https://raw.githubusercontent.com/husarnet/husarnet-ros2router/main/create_filter.sh > create_filter.sh
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
husarnet/ros2router:1.2.0
```

## Quick Start

### Option 1: Initial Peers config

1. Connect both hosts to the same Husarnet network (eg. named `host_a` and `host_b`).

2. On both `host_a` and `host_b` execute:

```bash
docker run \
--detach \
--restart=unless-stopped \
--network host \
-e ROS_DOMAIN_ID \
husarnet/ros2router:1.2.0
```

3. Start a chatter demo:

- on the `host_a`:

```bash
export ROS_LOCALHOST_ONLY=1 # is required to connect with a LocalUdpParticipant
ros2 run demo_nodes_cpp talker
```

- on the `host_b`:

```bash
export ROS_LOCALHOST_ONLY=1 # is required to connect with a LocalUdpParticipant
ros2 run demo_nodes_cpp listener
```

### Option 2: Discovery Server config

1. Connect both hosts to the same Husarnet network (eg. named `host_a` and `host_b`).

2. Execute on `host_a`:

```bash
docker run \
--detach \
--restart=unless-stopped \
--network host \
-e DISCOVERY_SERVER_PORT="11888" \
husarnet/ros2router:1.2.0
```

3. Execute on `host_b`:

```bash
docker run \
--detach \
--restart=unless-stopped \
--network host \
-e ROS_DISCOVERY_SERVER="host_a:11888" \
husarnet/ros2router:1.2.0
```

4. Start a chatter demo:

- on the `host_a`:

```bash
export ROS_LOCALHOST_ONLY=1 # is required to connect with a LocalUdpParticipant
ros2 run demo_nodes_cpp talker
```

- on the `host_b`:

```bash
export ROS_LOCALHOST_ONLY=1 # is required to connect with a LocalUdpParticipant
ros2 run demo_nodes_cpp listener
```

### Option 3: custom config

1. Connect both hosts to the same Husarnet network (eg. named `host_a` and `host_b`).

2. Create a DDS Router config file on the `host_a`:

```bash
user@host_a:~$ vim config.yaml
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
      - domain: host_a
        port: 11811
        transport: udp
```

3. Create a DDS Router config file on the `host_b`:

```bash
user@host_b:~$ vim config.yaml
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
          - domain: host_a 
            port: 11811
            transport: udp
```

4. On both `host_a` and `host_b` execute (in the same folder as `config.yaml` file):

```bash
docker run --name ros2router \
  --restart=unless-stopped \
  --network host \
  --ipc host \
  --user $(id -u):$(id -g) \
  -v $(pwd)/config.yaml:/config.yaml \
  -v /etc/group:/etc/group:ro \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/shadow:/etc/shadow:ro \
  -e AUTO_CONFIG=FALSE \
  husarnet/ros2router:1.2.0 bash -c "ddsrouter -c /config.yaml -r 10"
```

5. Start a chatter demo:

- on the `host_a`:

```bash
export ROS_DOMAIN_ID=0
ros2 run demo_nodes_cpp talker
```

- on the `host_b`:

```bash
export ROS_DOMAIN_ID=0
ros2 run demo_nodes_cpp listener
```



