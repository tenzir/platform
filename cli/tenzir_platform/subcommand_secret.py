# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

"""Usage:
  tenzir-platform secret add <name> [--file=<file>] [--value=<value>] [--env]
  tenzir-platform secret update <secret> [--file=<file>] [--value=<value>] [--env]
  tenzir-platform secret delete <secret>
  tenzir-platform secret list [--json] [--store=<store>]
  tenzir-platform secret store add aws --region=<region> --assumed-role-arn=<assumed_role_arn> [--name=<name>] [--access-key-id=<key_id>] [--secret-access-key=<key>]
  tenzir-platform secret store add vault --address=<address> --mount=<mount> (--token=<token> | --role-id=<role_id> --secret-id=<secret_id>) [--name=<name>] [--namespace=<namespace>]
  tenzir-platform secret store set-default <store>
  tenzir-platform secret store delete <store>
  tenzir-platform secret store list [--json]

Options:
  <name>   The name of the secret.
  <secret> The name or secret id of a the secret.
  <store>  The name or store id of a secret store.
  <value>  The plain value of the secret.
  <file>   The path to a file containing the secret value.

Description:
  tenzir-platform secret add <name> [--file <file>] [--value <value>] [--env]
  tenzir-platform secret update <secret> [--file <file>] [--value <value>] [--env]
    Add or update a secret. By default, reads the secret value
    interactively from stdin.
    The `--file` option can be used to read the secret value from a file instead.
    The `--value` option can be used to pass the secret value as a command-line argument instead.
    The `--env` option can be used to read the secret value from the environment variable with the same name.
    Only one of --file, --value, or --env can be specified.

  tenzir-platform secret delete <secret>
    Delete the specified secret.

  tenzir-platform secret list [--json] [--store <store>]
    List all configured secrets. The `--store` option can be used to list secrets from a specific store by name or ID.

  tenzir-platform secret store add vault --address=<address> --mount=<mount> ...
    Add a HashiCorp Vault secret store (read-only). Authentication can be done via:
    - Token auth: --token=<token>
    - AppRole auth: --role-id=<role_id> --secret-id=<secret_id>
    Secrets can be accessed with a :<key> suffix to return only a specific key's value.
"""

# TODO: We probably also want to add the equivalent of these options (from `gh secret`)
#       in the future.
#   -o, --org organization     Set organization secret
#   -r, --repos repositories   List of repositories that can access an organization or user secret
#   -u, --user                 Set a secret for your user
#   -v, --visibility string    Set visibility for an organization secret: {all|private|selected} (default "private")

import json
import os
from datetime import datetime

from docopt import docopt
from pydantic import BaseModel

from tenzir_platform.helpers.cache import load_current_workspace
from tenzir_platform.helpers.client import AppClient
from tenzir_platform.helpers.environment import PlatformEnvironment
from tenzir_platform.helpers.exceptions import PlatformCliError


class Secret(BaseModel):
    last_updated: datetime
    last_accessed: datetime | None
    id: str
    name: str


class ListSecretsResponse(BaseModel):
    secrets: list[Secret]


def _list_secrets(
    client: AppClient, workspace_id: str, store_id: str | None = None
) -> ListSecretsResponse:
    payload = {"tenant_id": workspace_id}
    if store_id is not None:
        payload["store_id"] = store_id
    resp = client.post(
        "secrets/list",
        json=payload,
    )
    resp.raise_for_status()
    return ListSecretsResponse.model_validate(resp.json())


def _resolve_secret_name_or_id(
    client: AppClient,
    workspace_id: str,
    name_or_id: str,
    store_id: str | None = None,
) -> Secret:
    secrets = _list_secrets(client, workspace_id, store_id).secrets
    matching_by_id = [secret for secret in secrets if secret.id == name_or_id]
    if matching_by_id:
        return matching_by_id[0]
    matching_by_name = [secret for secret in secrets if secret.name == name_or_id]
    if len(matching_by_name) > 1:
        raise PlatformCliError(f"multiple secrets found with the name '{name_or_id}'")
    if matching_by_name:
        return matching_by_name[0]
    raise PlatformCliError("secret not found").add_context(
        f"while trying to resolve id or name '{name_or_id}'"
    )


def _resolve_secret_store(client: AppClient, workspace_id: str, name_or_id: str) -> str:
    """Resolve a store name or ID to a store ID."""
    # If it looks like a store ID or is 'default', assume it's an ID
    if name_or_id.startswith("st-") or name_or_id == "default":
        return name_or_id

    resp = client.post(
        "secrets/list-stores",
        json={
            "tenant_id": workspace_id,
        },
    )
    resp.raise_for_status()
    stores = resp.json()["stores"]

    # Check for exact ID match (in case someone named their store something like "st-xyz")
    matching_by_id = [store for store in stores if store["id"] == name_or_id]
    if matching_by_id:
        return matching_by_id[0]["id"]

    # Check for name match
    matching_by_name = [store for store in stores if store["name"] == name_or_id]
    if len(matching_by_name) > 1:
        matching_ids = [store["id"] for store in matching_by_name]
        raise PlatformCliError(
            f"ambiguous name '{name_or_id}' is shared by stores {matching_ids}"
        )
    if matching_by_name:
        return matching_by_name[0]["id"]

    raise PlatformCliError(f"unknown secret store '{name_or_id}'")


def add(
    client: AppClient,
    workspace_id: str,
    name: str,
    file: str | None,
    value: str | None,
    env: bool = False,
):
    if sum(bool(x) for x in [file, value, env]) > 1:
        raise PlatformCliError(
            "Only one of --file, --value, or --env can be specified."
        )

    secret_value = None
    if file:
        with open(file) as f:
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
        raise PlatformCliError("failed to add secret").add_hint(
            f"received upstream error: {resp.json().get('detail', 'unknown error')}"
        )
        return
    resp.raise_for_status()
    print(json.dumps(resp.json()))


def update(
    client: AppClient,
    workspace_id: str,
    name_or_id: str,
    file: str | None,
    value: str | None,
    env: bool = False,
):
    if sum(bool(x) for x in [file, value, env]) > 1:
        raise PlatformCliError(
            "only one of --file, --value, or --env can be specified."
        ).add_context(f"while trying to update secret {name_or_id}")

    secret_value = None
    if file:
        with open(file) as f:
            secret_value = f.read().strip()
    elif value:
        secret_value = value
    elif env:
        secret_value = os.getenv(name_or_id)
    else:
        secret_value = input("Enter secret value: ").strip()

    secret = _resolve_secret_name_or_id(client, workspace_id, name_or_id)
    resp = client.post(
        "secrets/update",
        json={
            "tenant_id": workspace_id,
            "secret_id": secret.id,
            "value": secret_value,
        },
    )
    resp.raise_for_status()
    print(f"updated secret {name_or_id}")


def delete(client: AppClient, workspace_id: str, name_or_id: str):
    secret = _resolve_secret_name_or_id(client, workspace_id, name_or_id)
    resp = client.post(
        "secrets/remove",
        json={
            "tenant_id": workspace_id,
            "secret_id": secret.id,
        },
    )
    resp.raise_for_status()
    print(f"deleted secret {name_or_id}")


def list(
    client: AppClient,
    workspace_id: str,
    json_format: bool,
    store: str | None = None,
):
    store_id = None
    if store is not None:
        store_id = _resolve_secret_store(client, workspace_id, store)
    secrets_list = _list_secrets(client, workspace_id, store_id)
    if json_format:
        print(secrets_list.model_dump_json(indent=4))
        return
    secrets = secrets_list.secrets
    if len(secrets) == 0:
        print("no secrets configured")
        return
    print("# Secrets")
    for secret in secrets:
        name = secret.name
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
    default_store_id = json_body["default_store_id"]
    for store in json_body["stores"]:
        print(
            f"{'*' if store['id'] == default_store_id else ' '} {store['name']}  (id: {store['id']})"
        )


def delete_store(client: AppClient, workspace_id: str, name_or_id: str):
    store_id = _resolve_secret_store(client, workspace_id, name_or_id)
    resp = client.post(
        "secrets/delete-external-store",
        json={
            "tenant_id": workspace_id,
            "store_id": store_id,
        },
    )
    if resp.status_code == 400:
        # User tried to delete the default store, or the built-in store.
        raise PlatformCliError("failed to delete secret store").add_context(
            f"while trying to delete store {store_id}"
        )

    resp.raise_for_status()
    print(f"deleted store {store_id}")


def set_default_store(client, workspace_id, name_or_id):
    store_id = _resolve_secret_store(client, workspace_id, name_or_id)
    resp = client.post(
        "secrets/select-store",
        json={
            "tenant_id": workspace_id,
            "store_id": store_id,
        },
    )
    resp.raise_for_status()
    print("updated default store")


def add_store_aws(
    client: AppClient,
    workspace_id: str,
    name: str | None,
    region: str,
    assumed_role_arn: str,
):
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


def add_store_vault(
    client: AppClient,
    workspace_id: str,
    name: str | None,
    address: str,
    mount: str,
    namespace: str | None,
    token: str | None,
    role_id: str | None,
    secret_id: str | None,
):
    # Determine auth method based on provided credentials
    if token:
        auth_method = "token"
    elif role_id and secret_id:
        auth_method = "approle"
    else:
        raise PlatformCliError(
            "must provide either --token or both --role-id and --secret-id"
        )

    options = {
        "address": address,
        "mount": mount,
        "auth_method": auth_method,
    }

    if namespace:
        options["namespace"] = namespace

    if auth_method == "token":
        options["token"] = token
    else:
        options["role_id"] = role_id
        options["secret_id"] = secret_id

    resp = client.post(
        "secrets/add-external-store",
        json={
            "tenant_id": workspace_id,
            "type": "vault",
            "name": name,
            "is_writable": False,
            "options": options,
        },
    )
    if resp.status_code == 400:
        raise PlatformCliError("failed to add vault store").add_hint(
            f"received upstream error: {resp.json().get('detail', 'unknown error')}"
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
        raise PlatformCliError(
            "failed to load current workspace, please run 'tenzir-platform workspace select' first"
        ).add_hint(f"reason: {e}")

    # TODO: Move the store commands to a different subcommand.
    if args["store"]:
        if args["add"]:
            name = args["--name"]
            # Determine store type based on provided arguments
            if args["--address"]:
                # Vault store
                add_store_vault(
                    client,
                    workspace_id,
                    name=name,
                    address=args["--address"],
                    mount=args["--mount"],
                    namespace=args["--namespace"],
                    token=args["--token"],
                    role_id=args["--role-id"],
                    secret_id=args["--secret-id"],
                )
            elif args["--region"]:
                # AWS store
                add_store_aws(
                    client,
                    workspace_id,
                    name=name,
                    region=args["--region"],
                    assumed_role_arn=args["--assumed-role-arn"],
                )
            else:
                raise PlatformCliError("unknown store type")
        elif args["delete"]:
            store = args["<store>"]
            delete_store(client, workspace_id, store)
        elif args["set-default"]:
            store = args["<store>"]
            set_default_store(client, workspace_id, store)
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
        name_or_id = args["<secret>"]
        file = args["--file"]
        value = args["--value"]
        env = args["--env"]
        update(client, workspace_id, name_or_id, file, value, env)
    elif args["delete"]:
        name_or_id = args["<secret>"]
        delete(client, workspace_id, name_or_id)
    elif args["list"]:
        json_format = args["--json"]
        store = args["--store"]
        list(client, workspace_id, json_format, store)
