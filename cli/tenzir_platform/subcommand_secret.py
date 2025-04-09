# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

"""Usage:
  tenzir-platform secret add <name> [--file=<file>] [--value=<value>] [--env]
  tenzir-platform secret update <secret_id> [--file=<file>] [--value=<value>] [--env]
  tenzir-platform secret delete <secret_id>
  tenzir-platform secret list [--json]
  tenzir-platform secret store add aws --region=<region> --assumed-role-arn=<assumed_role_arn> [--name=<name>]
  tenzir-platform secret store set-default <store_id>
  tenzir-platform secret store delete <store_id>
  tenzir-platform secret store list [--json]

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

# TODO: We probably also want to add the equivalent of these options (from `gh secret`)
#       in the future.
#   -o, --org organization     Set organization secret
#   -r, --repos repositories   List of repositories that can access an organization or user secret
#   -u, --user                 Set a secret for your user
#   -v, --visibility string    Set visibility for an organization secret: {all|private|selected} (default "private")

from tenzir_platform.helpers.cache import load_current_workspace
from tenzir_platform.helpers.client import AppClient
from tenzir_platform.helpers.environment import PlatformEnvironment
from docopt import docopt
from typing import Optional, List
from requests import HTTPError
import json
import os
from enum import Enum

class AddOrUpdate(Enum):
    ADD = "add"
    UPDATE = "update"

def add(
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
        "secrets/add",
        json={
            "tenant_id": workspace_id,
            "name": name,
            "value": secret_value,
        },
    )
    if resp.status_code == 400:
        print(f"Failed to add secret: {resp.json().get('detail', 'unknown error')}")
        return
    resp.raise_for_status()
    print(json.dumps(resp.json()))


def update(
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
        "secrets/update",
        json={
            "tenant_id": workspace_id,
            "secret_id": name,
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
    print(f"Deleted secret {name}")


def list(
    client: AppClient,
    workspace_id: str,
    json_format: bool,
):
    resp = client.post(
        "secrets/list",
        json={
            "tenant_id": workspace_id,
        },
    )
    resp.raise_for_status()
    json_body = resp.json()
    if json_format:
        print(json_body)
        return
    secrets = json_body["secrets"]
    if len(secrets) == 0:
        print("no secrets configured")
        return
    print("# Secrets")
    for secret in secrets:
        name = secret['name']
        print(f"{name}")


def list_stores(client: AppClient, workspace_id: str, json_format: bool):
    resp = client.post(
        "secrets/list-stores",
        json={
            "tenant_id": workspace_id,
        },
    )
    resp.raise_for_status()
    json_body = resp.json()
    if json_format:
        print(json_body)
        return
    for store in json_body["stores"]:
        print(f"{'*' if store['is_default'] else ' '} {store['name']}  (id: {store['id']})")


def delete_store(client: AppClient, workspace_id: str, store_id: str):
    resp = client.post(
        "secrets/delete-external-store",
        json={
            "tenant_id": workspace_id,
            "store_id": store_id,
        },
    )
    if resp.status_code == 400:
        # User tried to delete the default store, or the built-in store.
        print(f"failed to delete store {store_id}")
        return
    resp.raise_for_status()
    print(f"deleted store {store_id}")


def set_default_store(client, workspace_id, store_id):
    resp = client.post(
        "secrets/set-default-store",
        json={
            "tenant_id": workspace_id,
            "store_id": store_id,
        },
    )
    resp.raise_for_status()
    print("updated default store")

def add_store_aws(client: AppClient, workspace_id: str, name: Optional[str], region: str, assumed_role_arn: str):
    resp = client.post(
        "secrets/add-external-store",
        json={
            "tenant_id": workspace_id,
            "type": "aws",
            "name": name,
            "is_writable": False,
            "options": {
                "region": region,
                "assumed_role_arn": assumed_role_arn,
            },
        },
    )
    resp.raise_for_status()
    store_id = resp.json()["store_id"]
    print(f"Added store {store_id}")


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
        if args["store"]:
            if args["add"]:
                store_type = "aws"  # We only support one type at the moment 
                region = args["--region"]
                assumed_role_arn = args["--assumed-role-arn"]
                name = args["--name"]
                if store_type == "aws":
                    add_store_aws(client, workspace_id, name=name, region=region, assumed_role_arn=assumed_role_arn)
                else:
                    print("error: unknown store type")
            elif args["delete"]:
                store_id = args["<store_id>"]
                delete_store(client, workspace_id, store_id)
            elif args["set-default"]:
                store_id = args["<store_id>"]
                set_default_store(client, workspace_id, store_id)
            elif args["list"]:
                json_format = args["--json"]
                list_stores(client, workspace_id, json_format)
        elif args["add"]:
            name = args["<name>"]
            file = args["--file"]
            value = args["--value"]
            env = args["--env"]
            add(client, workspace_id, name, file, value, env)
        elif args["update"]:
            name = args["<secret_id>"]
            file = args["--file"]
            value = args["--value"]
            env = args["--env"]
            update(client, workspace_id, name, file, value, env)
        elif args["delete"]:
            name = args["<secret_id>"]
            delete(client, workspace_id, name)
        elif args["list"]:
            json_format = args["--json"]
            list(client, workspace_id, json_format)
        
    except HTTPError as e:
        if e.response.status_code == 403:
            print(
                "Access denied. Please try re-authenticating by running 'tenzir-platform workspace select'"
            )
        else:
            print(f"Error communicating with the platform: {e}")
