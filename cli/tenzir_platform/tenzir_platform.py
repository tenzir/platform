# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

"""Tenzir Platform CLI.

Usage: tenzir-platform <command> [<args>...]
       tenzir-platform [--help] [--version]

Options:
  -h, --help                  Show this screen.
  --version                   Show version.

Commands:
   auth       Authenticate the current user
   workspace  Select the currently used workspace
   node       Interact with nodes
   admin      Administer local on-prem platform infrastructure.

See 'tenzir-platform <command> --help' for more information on a specific command.
"""

from docopt import docopt
from enum import Enum
import os
import requests
import requests.exceptions
import sys
import time
import importlib.metadata

from tenzir_platform.subcommand_auth import auth_subcommand
from tenzir_platform.subcommand_workspace import workspace_subcommand
from tenzir_platform.subcommand_node import node_subcommand
from tenzir_platform.subcommand_admin import admin_subcommand
from tenzir_platform.helpers.environment import PlatformEnvironment

version = importlib.metadata.version("tenzir-platform")


def main():
    if len(sys.argv) == 1:
        sys.argv.append("--help")
    arguments = docopt(
        __doc__, version=f"Tenzir Platform CLI {version}", options_first=True
    )
    platform = PlatformEnvironment.load()
    argv = [arguments["<command>"]] + arguments["<args>"]
    if arguments["<command>"] == "auth":
        auth_subcommand(platform, argv)
    elif arguments["<command>"] == "workspace":
        workspace_subcommand(platform, argv)
    elif arguments["<command>"] == "node":
        node_subcommand(platform, argv)
    elif arguments["<command>"] == "admin":
        admin_subcommand(platform, argv)
    else:
        print("unknown subcommand, see 'tenzir-platform --help' for usage")


if __name__ == "__main__":
    main()
