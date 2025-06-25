---
title: "Better error handling in the Tenzir Platform CLI"
type: feature
authors: lava
pr: 107
---
When encountering authentication errors, the Tenzir Platform CLI now exists with a nice error message instead of printing a raw stacktrace:

```
$ TENZIR_PLATFORM_CLI_ID_TOKEN=xxxx tenzir-platform workspace list
Error: Invalid JWT
  while validating TENZIR_PLATFORM_CLI_ID_TOKEN
note: upstream error: Not enough segments
```
