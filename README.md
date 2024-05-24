# Tenzir Platform

On-premise version of the Tenzir Platform.

**NOTE**: The examples and files in this repository are only
usable in combination with Sovereign Edition access token.
Please [contact sales](https://tenzir.com/pricing) for more
information. Visit [app.tenzir.com](https://app.tenzir.com) for
a free, hosted version.

## Quick Start

For detailed instructions, visit our [documentation](https://docs.tenzir.com/setup-guides/deploy-the-platform).

```
echo <SOVEREIGN_EDITION_TOKEN> | docker login ghcr.io -u tenzir-distribution --password-stdin
cd examples/localdev
mv env.example .env
vim .env
docker compose up -d
docker compose logs -f
```


For Tenzir employees, it's instead recommended to start with [this version](https://github.com/tenzir/event-horizon/tree/main/platform/compose) that ties into our deployed infrastructure.
