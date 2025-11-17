# A fork of the official seaweed container that allows configuring the bucket
# name and access keys via environment variables, by writing a config file
# to `/config.json`

FROM chrislusf/seaweedfs:4.00

COPY seaweed.tenzir-entrypoint.sh /tenzir-entrypoint.sh 

USER root
RUN mkdir -p /opt/tenzir-seaweed
RUN chown seaweed:seaweed /opt/tenzir-seaweed
# Add a soft link for backwards compatibility, since we
# changed the default location of the config file.
RUN ln -s /opt/tenzir-seaweed/config.json /config.json

USER seaweed
ENTRYPOINT ["/tenzir-entrypoint.sh"]

