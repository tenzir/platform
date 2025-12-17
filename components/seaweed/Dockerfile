# A fork of the official seaweed container that allows configuring the bucket
# name and access keys via environment variables, by writing a config file
# to `/config.json`

FROM chrislusf/seaweedfs:4.03

COPY seaweed.tenzir-entrypoint.sh /tenzir-entrypoint.sh 

USER root
RUN mkdir -p /opt/tenzir-seaweed
RUN chown seaweed:seaweed /opt/tenzir-seaweed
# Add a soft link for backwards compatibility, since we
# changed the default location of the config file.
RUN ln -s /opt/tenzir-seaweed/config.json /config.json

# Prepare permissions on the volume mount
# (https://github.com/docker/compose/issues/3270)
RUN mkdir -p /var/lib/seaweedfs
RUN chown seaweed:seaweed /var/lib/seaweedfs

USER seaweed
ENTRYPOINT ["/tenzir-entrypoint.sh"]

