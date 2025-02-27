# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

"""Usage:
  tenzir-platform secret set <name> [--file=<file>] [--value=<value>] [--env]
  tenzir-platform secret delete <name>
  tenzir-platform secret list

Options:
  <name>   The name of the secret.

Description:
  tenzir-platform secret set <name> [--file <file>] [--value <value>] [--env]
    Add or update a secret. By default, reads the secret value
    interactively from stdin.
    The `--file` option can be used to read the secret value from a file instead.
    The `--value` option can be used to pass the secret value as a command-line argument instead.
    The `--env` option can be used to read the secret value from the environment variable with the same name.
    Only one of these options can be specified.

  tenzir-platform secret delete <name>
    Delete the specified secret.

  tenzir-platform secret list
    List all configured secrets.
"""

# TODO: We probably also want to add the equivalent of these options for `gh secret`
#   -o, --org organization     Set organization secret
#   -r, --repos repositories   List of repositories that can access an organization or user secret
#   -u, --user                 Set a secret for your user
#   -v, --visibility string    Set visibility for an organization secret: {all|private|selected} (default "private")


from tenzir_platform.helpers.cache import load_current_workspace
from tenzir_platform.helpers.client import AppClient
from tenzir_platform.helpers.environment import PlatformEnvironment
from pydantic import BaseModel
from docopt import docopt
from typing import Optional, List
from requests import HTTPError
from pytimeparse2 import parse as parse_duration
import json
import time
import tempfile
import os
import subprocess
import re
import random
import datetime

def set(
    client: AppClient, workspace_id: str, name: str, file: Optional[str], value: Optional[str], env: bool = False
):
    if sum(bool(x) for x in [file, value, env]) > 1:
        print("Error: Only one of --file, --value, or --env can be specified.")
        return

    secret_value = None
    if file:
        with open(file, 'r') as f:
            secret_value = f.read().strip()
    elif value:
        secret_value = value
    elif env:
        secret_value = os.getenv(name)
    else:
        secret_value = input("Enter secret value: ").strip()

    resp = client.post(
        "secrets/upsert",
        json={
            "tenant_id": workspace_id,
            "name": name,
            "value": secret_value,
        },
    )
    resp.raise_for_status()
    print(json.dumps(resp.json()))


def delete(client: AppClient, workspace_id: str, name: str):
    resp = client.post(
        "secrets/remove",
        json={
            "tenant_id": workspace_id,
            "secret_id": name,
        },
    )
    resp.raise_for_status()
    print(f"deleted secret {name}")


def list(
    client: AppClient,
    workspace_id: str,
):
    resp = client.post(
        "secrets/list",
        json={
            "tenant_id": workspace_id,
        },
    )
    resp.raise_for_status()
    secrets = resp.json()["secrets"]
    if len(secrets) == 0:
        print("no secrets configured")
        return
    print("Secrets")
    for secret in secrets:
        name = secret['name']
        print(f"{name}")


def secret_subcommand(platform: PlatformEnvironment, argv):
    args = docopt(__doc__, argv=argv)
    try:
        workspace_id, user_key = load_current_workspace(platform)
        client = AppClient(platform=platform)
        client.workspace_login(user_key)
    except Exception as e:
        print(f"error: {e}")
        print(
            "Failed to load current workspace, please run 'tenzir-platform workspace select' first"
        )
        exit(1)

    try:
        if args["set"]:
            name = args["<name>"]
            file = args["--file"]
            value = args["--value"]
            env = args["--env"]
            set(client, workspace_id, name, file, value, env)
        elif args["delete"]:
            name = args["<name>"]
            delete(client, workspace_id, name)
        elif args["list"]:
            list(client, workspace_id)
    except HTTPError as e:
        if e.response.status_code == 403:
            print(
                "Access denied. Please try re-authenticating by running 'tenzir-platform workspace select'"
            )
        else:
            print(f"Error communicating with the platform: {e}")
