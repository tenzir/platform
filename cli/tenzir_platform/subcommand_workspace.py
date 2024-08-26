# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

"""
Usage:
  tenzir-platform workspace list [--json]
  tenzir-platform workspace select <workspace>
  tenzir-platform workspace rename <name>


Description:
  tenzir-platform workspace list
    Display a list of all workspaces accessible for the current user.

  tenzir-platform workspace select <workspace>
    Select <workspace>, which can be either a workspace id, a name or a number.

  tenzir-platform workspace rename <name>
    Rename the current workspace.

"""

from tenzir_platform.helpers.client import AppClient, TargetApi
from tenzir_platform.helpers.environment import PlatformEnvironment
from tenzir_platform.helpers.cache import store_workspace, load_current_workspace
from tenzir_platform.helpers.oidc import IdTokenClient
from docopt import docopt
from typing import List
import json
import re


def _is_workspace_id(identifier: str):
    return bool(re.match(r"^t-[a-z0-9]{8}$", identifier))


def _get_workspace_list(client: AppClient, id_token: str) -> List:
    resp = client.post(
        "get-login-info",
        json={
            "id_token": id_token,
        },
        target_api=TargetApi.USER_PUBLIC,
    )
    resp.raise_for_status()
    return resp.json()["allowed_tenants"]


def _resolve_workspace_identifier(
    client: AppClient, id_token: str, identifier: str
) -> str:
    # If we already have a node id, use that.
    if _is_workspace_id(identifier):
        return identifier

    # Otherwise go through the list of workspaces
    workspaces = _get_workspace_list(client, id_token)

    # If we're given a number, interpret it as a workspace index
    try:
        return workspaces[int(identifier)]["tenant_id"]
    except ValueError:
        pass
    except IndexError:
        raise Exception(f"Only have {len(workspaces)-1} workspaces")

    # Else, look for a matching workspace name
    name_matched = [
        workspace for workspace in workspaces if workspace["name"] == identifier
    ]
    if len(name_matched) == 0:
        raise Exception(f"Unknown workspace {identifier}")
    if len(name_matched) > 1:
        matching_ids = [workspace["tenant_id"] for workspace in name_matched]
        raise Exception(
            f"Ambigous name {identifier} is shared by workspaces {matching_ids}"
        )
    return name_matched[0]["tenant_id"]


def list(platform: PlatformEnvironment, print_json: bool):
    """Get list of authorized workspaces for the current CLI user"""
    id_token = IdTokenClient(platform).load_id_token()
    app_cli = AppClient(platform=platform)
    workspaces = _get_workspace_list(app_cli, id_token)
    if print_json:
        print(f"{json.dumps(workspaces)}")
    else:
        for i, workspace in enumerate(workspaces):
            print(f"{i}: {workspace['name']} ({workspace['tenant_id']}) ")


def select(platform: PlatformEnvironment, workspace_id_or_name: str):
    """Log in to a tenant as the current CLI user"""
    id_token = IdTokenClient(platform).load_id_token()
    app_cli = AppClient(platform)
    workspace_id = _resolve_workspace_identifier(
        app_cli, id_token, workspace_id_or_name
    )
    resp = app_cli.post(
        "switch-tenant",
        json={
            "id_token": id_token,
            "tenant_id": workspace_id,
        },
        target_api=TargetApi.USER_PUBLIC,
    )
    resp.raise_for_status()
    user_key = resp.json()["user_key"]
    store_workspace(platform, workspace_id, user_key)
    print(f"Switched to workspace {workspace_id}")


def rename(platform: PlatformEnvironment, workspace_id: str, name: str):
    app_cli = AppClient(platform)
    resp = app_cli.post(
        "rename-tenant",
        json={
            "tenant_id": workspace_id,
            "name": name,
        },
        target_api=TargetApi.USER_PUBLIC,
    )
    resp.raise_for_status()
    print(f"Renamed workspace {workspace_id}")


def workspace_subcommand(platform: PlatformEnvironment, argv):
    args = docopt(__doc__, argv=argv)
    if args["list"]:
        json = args["--json"]
        list(platform, json)
    if args["select"]:
        workspace_id = args["<workspace>"]
        select(platform, workspace_id)
    if args["rename"]:
        workspace_id, user_key = load_current_workspace(platform)
        name = args["<name>"]
        rename(platform=platform, workspace_id=workspace_id, name=name)
