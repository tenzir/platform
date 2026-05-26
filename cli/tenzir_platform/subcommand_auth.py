# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

"""Usage:
  tenzir-platform auth login [--interactive | --non-interactive]
  tenzir-platform auth token

Options:
  --interactive          Use device code flow for login.
  --non-interactive      Use client credentials flow for login.

Description:
  tenzir-platform auth login
    Authenticate the current user against the platform.

  tenzir-platform auth token
    Mint a fresh user key for the currently selected workspace and
    print it to stdout. The key is not written to the workspace cache.
    If no workspace is selected, a workspace-less user key is minted
    instead.

Notes:
  When the `--non-interactive` the CLI will attempt to read a client
  secret from the `TENZIR_PLATFORM_CLI_CLIENT_SECRET[_FILE]` variable.
  This option is only useful for users running an on-prem instance of
  the platform who can configure a suitable client.

  If neither option is specified, the login method will be chosen
  automatically based on the presence of a client secret.
"""


import sys

from docopt import docopt

from tenzir_platform.helpers.cache import load_current_workspace
from tenzir_platform.helpers.client import AppClient, TargetApi
from tenzir_platform.helpers.environment import PlatformEnvironment
from tenzir_platform.helpers.oidc import IdTokenClient


_TOKEN_LIFETIME_SECONDS = 15 * 60


def login(platform: PlatformEnvironment, interactive: bool | None):
    token_client = IdTokenClient(platform)
    token = token_client.load_id_token(interactive=interactive)
    decoded_token = token_client.validate_token(token)
    print(f"Logged in as {decoded_token.user_id}")


def print_token(platform: PlatformEnvironment):
    id_token = IdTokenClient(platform).load_id_token()
    app_cli = AppClient(platform)
    try:
        workspace_id, _ = load_current_workspace(platform)
    except FileNotFoundError:
        print(
            "Warning: no workspace selected; minting a workspace-less user key.",
            file=sys.stderr,
        )
        resp = app_cli.post(
            "authenticate",
            json={"id_token": id_token},
            target_api=TargetApi.USER_PUBLIC,
        )
    else:
        resp = app_cli.post(
            "switch-tenant",
            json={
                "id_token": id_token,
                "tenant_id": workspace_id,
                "requested_lifetime_seconds": _TOKEN_LIFETIME_SECONDS,
            },
            target_api=TargetApi.USER_PUBLIC,
        )
    resp.raise_for_status()
    print(resp.json()["user_key"])


def auth_subcommand(platform: PlatformEnvironment, argv):
    args = docopt(__doc__, argv=argv)
    if args["login"]:
        explicit_interactive = args["--interactive"]
        explicit_noninteractive = args["--non-interactive"]
        if explicit_interactive:
            interactive = True
        elif explicit_noninteractive:
            interactive = False
        else:
            interactive = None
        login(platform, interactive)
    if args["token"]:
        print_token(platform)
