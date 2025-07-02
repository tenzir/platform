---
title: "Add secrets support for the Platform"
type: feature
authors: lava
pr: 73
---

With this release, the Tenzir Platform now supports storing secrets on a per-workspace level.

In the Tenzir UI, you can click on the new gears icon in the workspace switcher to get to the Workspace settings, where you can add, modify or delete secrets for you workspace.

In the Tenzir CLI, you can use the new `tenzir-platform secret` subcommand for the same purpose:

```plain
tenzir-platform secret add <name> [--file=<file>] [--value=<value>] [--env]
tenzir-platform secret update <secret> [--file=<file>] [--value=<value>] [--env]
tenzir-platform secret delete <secret>
tenzir-platform secret list [--json]
```
