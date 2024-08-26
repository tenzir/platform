# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

"""Usage:
  tenzir-platform auth login [--non-interactive]

Options:
  --non-interactive   Use client credentials flow for login.

Notes:
  When the `--non-interactive` the CLI will attempt to read a client
  secret from the `TENZIR_PLATFORM_CLI_CLIENT_SECRET[_FILE]` variable.
  This option is only useful for users running an on-prem instance of
  the platform who can configure a suitable client.
"""

from tenzir_platform.helpers.oidc import IdTokenClient
from tenzir_platform.helpers.environment import PlatformEnvironment
from docopt import docopt


def login(platform: PlatformEnvironment, interactive: bool):
    token_client = IdTokenClient(platform)
    token = token_client.load_id_token(interactive=interactive)
    decoded_token = token_client.validate_token(token)
    print(f"Logged in as {decoded_token.user_id}")


def auth_subcommand(platform: PlatformEnvironment, argv):
    args = docopt(__doc__, argv=argv)
    if args["login"]:
        interactive = not args["--non-interactive"]
        login(platform, interactive)
