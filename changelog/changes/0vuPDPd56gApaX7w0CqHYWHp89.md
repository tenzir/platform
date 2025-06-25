---
title: "Option to allow passing extra headers to the API endpoint"
type: feature
authors: lava
pr: 107
---

The Tenzir Platform CLI now respects the `TENZIR_PLATFORM_CLI_EXTRA_HEADERS` environment variable
to add extra headers to any request made against the platform API. The value of this variable
must be set to a map of strings, eg.:

```
TENZIR_PLATFORM_CLI_EXTRA_HEADERS='{"Proxy-Authentication": "Bearer XXXXXXXXXXXXXXXXX"}'
```
