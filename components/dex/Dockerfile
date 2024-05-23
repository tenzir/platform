# A fork of the upstream dex container that allows configuring the initial
# user and password via environment variables, by writing a config file
# to `/etc/dex/tenzir-config.yaml`

FROM dexidp/dex:v2.38.0

COPY dex.tenzir-entrypoint.sh /tenzir-entrypoint.sh 

ENTRYPOINT ["/tenzir-entrypoint.sh"]

