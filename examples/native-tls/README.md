# Native TLS Setup

In general, the recommended way of running the platform services is
behind a reverse proxy running on the same host. This way the TLS
termination can be handled by the reverse proxy, and the plain HTTP
communication between proxy and backend containers is never exposed
to the network.

However, in some environments the reverse proxy cannot be guaranteed
to run on the same host machine as the other platform containers, or
the containers themselves are deployed to different machines.

In these scenarios, it becomes necessary to enable native TLS support
for the individual platform containers. This example setup shows how
to configure the platform for this scenario.

## Private Certificate Authority

This example assumes that certificates from a private CA and
server certificates from a private certificate authority.

An alternative 