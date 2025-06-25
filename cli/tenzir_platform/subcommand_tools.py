# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

"""Usage:
  tenzir-platform tools generate-workspace-token <workspace_id>
  tenzir-platform tools print-auth-rule email-domain <domain> [--connection=<connection>]
  tenzir-platform tools print-auth-rule organization-membership <organization_claim> <organization> [--connection=<connection>]
  tenzir-platform tools print-auth-rule organization-role <roles_claim> <role> <organization_claim> <organization> [--connection=<connection>]
  tenzir-platform tools print-auth-rule user <user_id>
  tenzir-platform tools print-auth-rule allow-all

This set of commands does not interact with the remote Tenzir Platform. It
contains a set of utility commands that administrators can use to prepare the
configuration for a self-hosted Tenzir Platform instance.
"""

from tenzir_platform.helpers.environment import PlatformEnvironment
from docopt import docopt
import os
import base58
from tenzir_platform.subcommand_admin import auth_rule_from_arguments


def print_workspace_token(workspace_id: str) -> None:
    base58_workspace_id = base58.b58encode(workspace_id.encode()).decode()
    random_bytes = os.urandom(24).hex()
    print(f"wsk_{random_bytes}{base58_workspace_id}")


def tools_subcommand(_: PlatformEnvironment, argv):
    args = docopt(__doc__, argv=argv)

    if args["generate-workspace-token"]:
        workspace_id = args["<workspace_id>"]
        print_workspace_token(workspace_id=workspace_id)
    elif args["print-auth-rule"]:
        rule = auth_rule_from_arguments(args)
        print(rule.model_dump_json())
