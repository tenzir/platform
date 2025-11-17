---
title: "Switch default user for seaweed container"
type: change
authors: lava
pr: 135
---
To conform with best practices, we updated the `tenzir-seaweed` image to use a non-root user by default.

**NOTE**: This is a breaking change due to the updated permissions of the seaweed data volume.
If you have an existing docker compose stack, either manually specify the root user in your `docker-compose.yaml`:

```yaml
services:
  seaweed:
    user: root
```

Or run a one-time command after upgrading to change the permissions of the seaweed data volume:

```sh
docker compose run --user root --entrypoint /bin/sh seaweed
$ chown -R seaweed:seaweed /var/lib/seaweedfs
```
