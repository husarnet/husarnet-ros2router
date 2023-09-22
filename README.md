# dds-router

[![Build a Docker Image](https://github.com/husarnet/dds-router/actions/workflows/build_push.yaml/badge.svg)](https://github.com/husarnet/dds-router/actions/workflows/build_push.yaml)

The `husarnet/dds-router` Docker image is designed to effortlessly bridge local ROS 2 nodes, even those with standard DDS settings, to nodes on different machines across various networks. It runs seamlessly with the Husarnet VPN, ensuring that neither distance nor network differences become obstacles in your ROS 2 projects. 

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
   husarnet/dds-router:v2.0.0
   ```

5. **Verify Connection:**

   Open the terminal for the `listener`. You should start seeing incoming messages.

This guide provides a straightforward setup. Dive deeper and explore additional options and examples in the sections below.

## Environment Variables

| env | default value | description |
| - | - | - |
| `AUTO_CONFIG` | `TRUE` | If set to `TRUE`, the `DDS_ROUTER_CONFIGURATION.yaml` will be automatically generated using all other environment variables. Set to `FALSE` to use a custom DDS Router configuration, **bypassing all other environment variables** |
| `USE_HUSARNET` | `TRUE` | When set to `TRUE`, the DDS Router configuration file populates with Husarnet peers addresses. If `FALSE`, the DDS Router operates solely within the local network, defaulting to the DDS simple discovery protocol. In this scenario, the first participant's domain id is `ROS_DOMAIN_ID`, while the second participant's domain id is consistently `0`. However, if `ROS_DOMAIN_ID=0`, the first participant's domain id defaults to `77` to prevent both participants from having a domain id of `0`. |
| `ROS_DISCOVERY_SERVER` | | By default is unset. Set it to one of the following formats: `<husarnet-ipv6-addr>:<discovery-server-port>` or `<husarnet-hostname>:<discovery-server-port>` to connect as the Client to the device acting as a Discovery Server. To specify multiple addresses, use semicolons as separators. The server's ID is determined by its position in the list (starting from `0`). If there's an empty space between semicolons, it indicates that the respective ID is available. Eg. `ROS_DISCOVERY_SERVER=";;abc:123;;;def:456"` means that the ID of `abc:123` is `2` and ID of `def` is `5`|
| `ID` | `0` | The ID of the local Discovery Server |
| `LISTENING_PORT` |  | By default is unset. Set it to a number between `0` to `65535` to activate DDS Router in the Discovery Server - Server config. |
| `ROS_DOMAIN_ID` | `0` | from `0` to `232`. |
| `ROS_DOMAIN_ID_2` | `77` | from `0` to `232`. Set it only if `USE_HUSARNET=FALSE` or `FAIL_IF_HUSARNET_NOT_AVAILABLE=FALSE`. This will setup the DDS Router to work in the local network using the standard DDS discovery mechnism (multicasting). Note that the second peer need to have different `ROS_DOMAIN_ID` is using the DDS Router in the local network to prevent the unwanted messages retransmission loop in the DDS network. |
| `EXIT_IF_HUSARNET_NOT_AVAILABLE` | `FALSE` | When set to `FALSE`, if the Husarnet Daemon HTTP API is unreachable, the system behaves as though `USE_HUSARNET=FALSE`. When set to `TRUE`, the container stops if it cannot connect to the Husarnet Daemon API. |
| `EXIT_IF_HOST_TABLE_CHANGED` | `FALSE` | Valid only if `DS_LISTENING_PORT` and `ROS_DISCOVERY_SERVER` envs are unset and thus starting the **Initial Peers** config. This env is useful in connection with `restart: always` Docker policy - it restarts the DDS Router with a new Initial Peers list applied (the Initial Peers list is not updated by the DDS Router in runtime)  |
| `LOCAL_TRANSPORT` | `udp` | `udp` for UDP based local DDS setup, `builtin` for a shared memory based local DDS setup (if using `builtin` with `--network host`, remember to add also `--ipc host `). |
| `WHITELIST_INTERFACES` |  | Initially unset. This environment variable holds a list of IP addresses separated by commas, spaces, or semicolons. These IP addresses correspond to local network interfaces utilized by the local participant (that doesn't use Husarnet). This configuration is beneficial when there's a need to direct discovery traffic from a local participant solely to ROS 2 nodes that operate either on the host machine or only within a specified Docker network. Example value `127.0.0.1 172.22.0.1 172.19.0.1` etc.|

## Example Setups

### Setup 1

Husarnet operates on the Host OS. ROS 2 nodes on the host use `ROS_DOMAIN_ID=1`, and the goal is to ensure all ROS 2 topics are accessible to other peers in the Husarnet network. The DDS Router should also restart with each reboot of the host OS.

1. Docker Compose

```yaml
services:
  ddsrouter:
    image: husarnet/dds-router:v2.0.0
    restart: always
    network_mode: host
    environment:
      - ROS_DOMAIN_ID=1
```

2. Docker run

```bash
docker run --name ddsrouter \
--restart always \
--network host \
-e ROS_DOMAIN_ID=1 \
husarnet/dds-router:v2.0.0
```

### Setup 2

Husarnet operates on the Host OSes with hostnames `host_a` and `host_b`, and `host_c`. The goal is to ensure all ROS 2 topics are accessible to other peers in the Husarnet network. We want to use a Discovery Server setup, where `host_a` is a server, and `host_b` and `host_c` are clients.

1. `compose.yaml` for `host_a`:

```yaml
services:
  ddsrouter:
    image: husarnet/dds-router:v2.0.0
    network_mode: host
    environment:
      - DS_LISTENING_PORT=11888
      - DS_ID=0 # 0 - id of the Discovery Server running on local machine (host_a:11888)
```

2. `compose.yaml` for `host_b`:

```yaml
services:
  ddsrouter:
    image: husarnet/dds-router:v2.0.0
    network_mode: host
    environment:
      - ROS_DISCOVERY_SERVER="host_a:11888"
      - DS_ID="1 0" # 1 - own ID, 0 - id of the remote Discovery Server (host_a:11888)
```

3. `compose.yaml` for `host_c`:

```yaml
services:
  ddsrouter:
    image: husarnet/dds-router:v2.0.0
    network_mode: host
    environment:
      - ROS_DISCOVERY_SERVER="host_a:11888"
      - DS_ID="2 0" # 2 - own ID, 0 - id of the remote Discovery Server (host_a:11888)
```

### Setup 3

Husarnet runs on the Host OS. While ROS 2 nodes on the are in `ROS_DOMAIN_ID=0` (default), the aim is to make only the `/chatter` topic available to other peers within the Husarnet network.

1. `compose.yaml`

```yaml
services:
  ddsrouter:
    image: husarnet/dds-router:v2.0.0
    network_mode: host
    volumes:
      - ./filter.yaml:/filter.yaml
```

2. `filter.yaml`

```yaml
allowlist:
  - name: "rt/chatter"
    type: "std_msgs::msg::dds_::String_"
blocklist: []
builtin-topics: []
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
husarnet/dds-router:v2.0.0
```

3. Start a chatter demo:

- on the `host_a`:

```bash
ros2 run demo_nodes_cpp talker
```

- on the `host_b`:

```bash
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
husarnet/dds-router:v2.0.0
```

3. Execute on `host_b`:

```bash
docker run \
--detach \
--restart=unless-stopped \
--network host \
-e ROS_DISCOVERY_SERVER="host_a:11888" \
husarnet/dds-router:v2.0.0
```

4. Start a chatter demo:

- on the `host_a`:

```bash
ros2 run demo_nodes_cpp talker
```

- on the `host_b`:

```bash
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
