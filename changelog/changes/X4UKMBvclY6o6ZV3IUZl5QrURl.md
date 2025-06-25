---
title: "Update Tenzir Platform examples"
type: change
authors: lava
pr: 106
---
We updated all examples in the Tenzir Platform repository to use the latest
best practices and to better integrate with the new docs page at https://docs.tenzir.com

We also removed the outdated `tenzir-developers` example, and added a new `native-tls` example instead
showing a complete setup with a private certificate authority.

Note that in order to get more consistent terminology in our examples, we updated the following
variable names. If you are planning to use an old `.env` file with the new platform version,
you will need to update these names as well.

The internal environment variables used by the individual docker services have not been changed,
so if you use your own `docker-compose.yaml` file updating the platform version is safe
without renaming these variables in your `.env` file.

```
TENZIR_PLATFORM_DOMAIN -> TENZIR_PLATFORM_UI_ENDPOINT
TENZIR_PLATFORM_CONTROL_ENDPOINT -> TENZIR_PLATFORM_NODES_ENDPOINT
TENZIR_PLATFORM_BLOBS_ENDPOINT -> TENZIR_PLATFORM_DOWNLOADS_ENDPOINT

TENZIR_PLATFORM_OIDC_ADMIN_RULES -> TENZIR_PLATFORM_ADMIN_RULES
```
