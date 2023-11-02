In a terminal window execute:

```bash
export JOINCODE=fc94:b01d:1803:8dd8:b293:5c7d:7639:932a/xxxxxxxxxxxxxxxxxxxxxx # find it at https://app.husarnet.com
COMPOSE_PROJECT_NAME=listener docker compose up
```

in a second terminal run:

```bash
export JOINCODE=fc94:b01d:1803:8dd8:b293:5c7d:7639:932a/xxxxxxxxxxxxxxxxxxxxxx # find it at https://app.husarnet.com
COMPOSE_PROJECT_NAME=talker docker compose up
```