# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

"""Tenzir Platform CLI.

Usage: tenzir-platform [-v|--verbose] <command> [<args>...]
       tenzir-platform [--help] [--version]

Options:
  -h, --help                  Show this screen.
  -v, --verbose               Enable verbose logging.
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
from requests import HTTPError
import sys
import importlib.metadata
import traceback

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


def _pretty_print_cli_error(e: PlatformCliError, verbose: bool):
    print(f"\033[91mError:\033[0m {e.error}", file=sys.stderr)
    for context in e.contexts:
        print(f"  {context}", file=sys.stderr)
    for hint in e.hints:
        print(f"(hint) {hint}", file=sys.stderr)
    if verbose:
       traceback.print_exc(file=sys.stderr)


def main():
    if len(sys.argv) == 1:
        sys.argv.append("--help")
    arguments = docopt(
        __doc__, version=f"Tenzir Platform CLI {version}", options_first=True
    )
    try:
        platform = PlatformEnvironment.load()
        if arguments["--verbose"]:
            platform.verbose = True
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
    except HTTPError as e:
        if e.response.status_code == 403:
            print(
                "Access denied. Please try re-authenticating by running 'tenzir-platform workspace select'"
            )
        else:
            detail = ""
            try:
                error_json = e.response.json()
                if "detail" in error_json:
                    detail = f" Detail: {error_json['detail']}"
                elif "error" in error_json:
                    detail = f" Error: {error_json['error']}"
            except Exception:
                pass
            error = PlatformCliError(str(e))
            error.add_hint(f"status code {e.response.status_code}")
            if detail:
                error.add_hint(f"detail: {detail}")
            if platform.verbose and e.response is not None:
                error.add_hint(f"response: {e.response.content}")
            _pretty_print_cli_error(error, platform.verbose)
            exit(-1)
    except PlatformCliError as e:
        _pretty_print_cli_error(e, platform.verbose)
        exit(-1)


if __name__ == "__main__":
    main()
