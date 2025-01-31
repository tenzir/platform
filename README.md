<a target="_blank" href="https://docs.tenzir.com">
<p align="center">
<img src="./assets/tenzir-white.svg#gh-dark-mode-only" width="60%" alt="Tenzir">
<img src="./assets/tenzir-black.svg#gh-light-mode-only" width="60%" alt="Tenzir">
</p>
</a>

<h3 align="center">
The data pipeline engine for security teams.
</h3>
</p>

## What is Tenzir?

If you need to collect, parse, shape, normalize, aggregate, store, query, and
route security telemetry data at scale, you'll love how our pipelines manage
your dataflows. Tenzir makes it easy to quickly onboard and store data from
numerous sources, reduce data volumes to optimize cloud and data costs, and
execute detections and run analytics in-stream.

## Get started

This repository hosts the on-premise version of the Tenzir Platform and a
command-line utility for managing workspaces and nodes on the Tenzir Platform.

If you want to get up and running quickly to try out the platform locally,
you can start with the `localdev` example setup, which is designed to be
self-contained:

```
echo YOUR_DOCKER_TOKEN | docker login ghcr.io -u tenzir-distribution --password-stdin
cd examples/localdev
docker compose up
```

If you are a customer of the **Sovereign Edition**, deploy the Tenzir Platform
locally by following our [Deploy the platform][guide] setup guide step by step.

If you are a Tenzir employee and want to work on the code base of the Tenzir
Platform, we recommend to start from the `examples/keycloak` example and
substitute the `keycloak` and `postgres` services for our Testbed infrastructure,
whose details can be found in 1password.

> [!NOTE]
> To get more information about the **Sovereign Edition**, please [contact
> sales](mailto://sales@tenzir.com). Visit [app.tenzir.com][app] to enjoy the
> free, cloud-hosted version of the Tenzir Platform.

[app]: https://app.tenzir.com
[guide]: https://docs.tenzir.com/setup-guides/deploy-the-platform

## Community

Got questions? We're here to help. Join our friendly community Discord server
where you'll find a thriving group of enthusiasts that love the intersection of
data infrastructure and security operations.

<a href="https://discord.gg/xqbDgVTCxZ" alt="Tenzir Discord community">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://invidget.switchblade.xyz/xqbDgVTCxZ">
  <img alt="Tenzir Discord community" src="https://invidget.switchblade.xyz/xqbDgVTCxZ?theme=light">
</picture>
</a>
