# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

"""Usage:
  tenzir-platform tools print-workspace-token <workspace_id>
  tenzir-platform tools add-auth-rule email-domain <domain> [--connection=<connection>]
  tenzir-platform tools add-auth-rule organization-membership <organization_claim> <organization> [--connection=<connection>]
  tenzir-platform tools add-auth-rule organization-role <roles_claim> <role> <organization_claim> <organization> [--connection=<connection>]
  tenzir-platform tools add-auth-rule user <user_id>
  tenzir-platform tools add-auth-rule allow-all

This set of commands does not interact with the remote Tenzir Platform. It
contains a set of utility commands that administrators can use to prepare the
configuration for a self-hosted Tenzir Platform instance.
"""

from tenzir_platform.helpers.environment import PlatformEnvironment
from docopt import docopt
import os
import base58

def print_workspace_token(workspace_id: str) -> None:
    base58_workspace_id = base58.b58encode(workspace_id.encode()).decode()
    print(f"debug: {workspace_id} -> {base58_workspace_id}")
    random_bytes = os.urandom(24).hex()
    print(f"wsp_{random_bytes}{base58_workspace_id}")

def tools_subcommand(platform: PlatformEnvironment, argv):
    args = docopt(__doc__, argv=argv)

    if args["print-workspace-token"]:
        workspace_id = args["<workspace_id>"]
        print_workspace_token(workspace_id=workspace_id)
    elif args["print-auth-rule"]:
        # TODO
        pass
