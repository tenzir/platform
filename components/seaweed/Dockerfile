# A fork of the official seaweed container that allows configuring the bucket
# name and access keys via environment variables, by writing a config file
# to `/config.json`

FROM chrislusf/seaweedfs:4.03

USER root

# Install caddy (optional, enabled via TENZIR_ENABLE_CADDY)
RUN apk add --no-cache caddy

COPY config/seaweed.tenzir-entrypoint.sh /tenzir-entrypoint.sh
RUN chmod +x /tenzir-entrypoint.sh
COPY config/Caddyfile /etc/caddy/Caddyfile

RUN mkdir -p /opt/tenzir-seaweed
RUN chown seaweed:seaweed /opt/tenzir-seaweed
# Add a soft link for backwards compatibility, since we
# changed the default location of the config file.
RUN ln -s /opt/tenzir-seaweed/config.json /config.json

# Prepare permissions on the volume mount
# (https://github.com/docker/compose/issues/3270)
RUN mkdir -p /var/lib/seaweedfs
RUN chown seaweed:seaweed /var/lib/seaweedfs

# Create caddy data directories with correct permissions
RUN mkdir -p /data/caddy /config/caddy
RUN chown -R seaweed:seaweed /data/caddy /config/caddy

USER seaweed
ENTRYPOINT ["/tenzir-entrypoint.sh"]

