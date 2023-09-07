# dds-router

Fast DDS Router Docker image adjusted for Husarnet VPN.

## Quick Start (Docker)

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

<!-- ## devel cheatsheet

```bash
docker run --rm -it \
  --network host \
  --ipc host \
  -v $(pwd)/config.client.template.yaml:/config.client.template.yaml \
  -v $(pwd)/entrypoint.sh:/entrypoint.sh \
  -e DS_HOSTNAME=rosbot2r \
  husarnet/dds-router:v2.0.0 bash
``` -->