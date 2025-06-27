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
   alert      Configure alerts for disconnected nodes.
   admin      Administer local on-prem platform infrastructure.
   tools      Utility commands for configuring the platform.
   secret     Manage secrets.

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
from tenzir_platform.subcommand_alert import alert_subcommand
from tenzir_platform.subcommand_workspace import workspace_subcommand
from tenzir_platform.subcommand_node import node_subcommand
from tenzir_platform.subcommand_admin import admin_subcommand
from tenzir_platform.subcommand_tools import tools_subcommand
from tenzir_platform.subcommand_secret import secret_subcommand
from tenzir_platform.helpers.environment import PlatformEnvironment
from tenzir_platform.helpers.exceptions import PlatformCliError

version = importlib.metadata.version("tenzir-platform")


def main():
    if len(sys.argv) == 1:
        sys.argv.append("--help")
    arguments = docopt(
        __doc__, version=f"Tenzir Platform CLI {version}", options_first=True
    )
    try:
        platform = PlatformEnvironment.load()
        argv = [arguments["<command>"]] + arguments["<args>"]
        if arguments["<command>"] == "auth":
            auth_subcommand(platform, argv)
        elif arguments["<command>"] == "alert":
            alert_subcommand(platform, argv)
        elif arguments["<command>"] == "workspace":
            workspace_subcommand(platform, argv)
        elif arguments["<command>"] == "node":
            node_subcommand(platform, argv)
        elif arguments["<command>"] == "admin":
            admin_subcommand(platform, argv)
        elif arguments["<command>"] == "tools":
            tools_subcommand(platform, argv)
        elif arguments["<command>"] == "secret":
            secret_subcommand(platform, argv)
        else:
            print("unknown subcommand, see 'tenzir-platform --help' for usage")
    except PlatformCliError as e:
        print(f"\033[91mError:\033[0m {e.error}")
        for context in e.contexts:
            print(f"  {context}")
        for hint in e.hints:
            print(f"(hint) {hint}")
        exit(-1)


if __name__ == "__main__":
    main()
