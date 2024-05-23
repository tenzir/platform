# A fork of the official seaweed container that allows configuring the bucket
# name and access keys via environment variables, by writing a config file
# to `/config.json`

FROM chrislusf/seaweedfs

COPY seaweed.tenzir-entrypoint.sh /tenzir-entrypoint.sh 

ENTRYPOINT ["/tenzir-entrypoint.sh"]

