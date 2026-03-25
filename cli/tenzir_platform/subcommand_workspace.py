# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

"""
Usage:
  tenzir-platform workspace select <workspace>
  tenzir-platform workspace list [--json]
  tenzir-platform workspace create [--name=<name>]
  tenzir-platform workspace rename <name>
  tenzir-platform workspace invite [--role=<role>] [--label=<label>]
  tenzir-platform workspace list-invitations
  tenzir-platform workspace revoke-invitation <invitation_id>
  tenzir-platform workspace redeem-invitation <token>


Description:
  tenzir-platform workspace select <workspace>
    Select <workspace>, which can be either a workspace id, a name or a number.

  tenzir-platform workspace list
    Display a list of all workspaces accessible for the current user.

  tenzir-platform workspace create [--name=<name>]
    Create a new workspace for your organization.

  tenzir-platform workspace rename <name>
    Rename the current workspace.

  tenzir-platform workspace invite [--role=<role>] [--label=<label>]
    Create an invitation for the currently selected workspace.
    Role can be 'member' (default) or 'admin'.

  tenzir-platform workspace list-invitations
    List all invitations for the currently selected workspace.

  tenzir-platform workspace revoke-invitation <invitation_id>
    Revoke a workspace invitation by id for the currently selected workspace.

  tenzir-platform workspace redeem-invitation <token>
    Redeem a workspace invitation token to gain access to the workspace.

"""

import json
import re
from datetime import datetime, timezone

from docopt import docopt  # type: ignore[import-untyped]

from tenzir_platform.helpers.cache import load_current_workspace, store_workspace
from tenzir_platform.helpers.client import AppClient, TargetApi
from tenzir_platform.helpers.environment import PlatformEnvironment
from tenzir_platform.helpers.exceptions import PlatformCliError
from tenzir_platform.helpers.oidc import IdTokenClient


def _is_workspace_id(identifier: str):
    return bool(re.match(r"^t-[a-z0-9]{8}$", identifier))


def _get_workspace_list(client: AppClient, id_token: str) -> list[dict[str, str]]:
    resp = client.post(
        "get-login-info",
        json={
            "id_token": id_token,
        },
        target_api=TargetApi.USER_PUBLIC,
    )
    resp.raise_for_status()
    return resp.json()["allowed_tenants"]


def _resolve_workspace_identifier(client: AppClient, id_token: str, identifier: str) -> str:
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
        raise PlatformCliError(f"only have {len(workspaces)} workspaces")

    # Else, look for a matching workspace name
    name_matched = [workspace for workspace in workspaces if workspace["name"] == identifier]
    if len(name_matched) == 0:
        raise PlatformCliError(f"unknown workspace {identifier}")
    if len(name_matched) > 1:
        matching_ids = [workspace["tenant_id"] for workspace in name_matched]
        raise PlatformCliError(
            f"ambiguous name {identifier} is shared by workspaces {matching_ids}"
        )
    return name_matched[0]["tenant_id"]


def list_workspaces(platform: PlatformEnvironment, print_json: bool) -> None:
    """Get list of authorized workspaces for the current CLI user"""
    id_token = IdTokenClient(platform).load_id_token()
    app_cli = AppClient(platform=platform)
    workspaces = _get_workspace_list(app_cli, id_token)
    if print_json:
        print(f"{json.dumps(workspaces)}")
    else:
        for i, workspace in enumerate(workspaces):
            print(f"{i}: {workspace['name']} ({workspace['tenant_id']}) ")


def create(platform: PlatformEnvironment, name: str | None):
    if name is None:
        time_suffix = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        name = f"workspace-{time_suffix}"
    _, user_key = load_current_workspace(platform)
    app_cli = AppClient(platform)
    app_cli.workspace_login(user_key)
    resp = app_cli.post(
        "workspace/create",
        json={
            "name": name,
            "org_owned": True,
        },
    )
    resp.raise_for_status()
    created_workspace = resp.json()["tenant_id"]
    print(f"Created workspace {created_workspace}")


def invite(platform: PlatformEnvironment, role: str, label: str):
    workspace_id, user_key = load_current_workspace(platform)
    app_cli = AppClient(platform)
    app_cli.workspace_login(user_key)
    resp = app_cli.post(
        "workspace/create-invitation",
        json={
            "tenant_id": workspace_id,
            "role": role,
            "label": label,
        },
    )
    resp.raise_for_status()
    body = resp.json()
    print(f"Invitation id: {body['invitation_id']}")
    print(f"Token: {body['token']}")


def list_invitations(platform: PlatformEnvironment):
    workspace_id, user_key = load_current_workspace(platform)
    app_cli = AppClient(platform)
    app_cli.workspace_login(user_key)
    resp = app_cli.post(
        "workspace/list-invitations",
        json={"tenant_id": workspace_id},
    )
    resp.raise_for_status()
    invitations = resp.json().get("invitations", [])
    if not invitations:
        print("No invitations.")
        return
    for inv in invitations:
        status = inv.get("status", "unknown")
        label = inv.get("label", "")
        label_str = f" ({label})" if label else ""
        print(f"  {inv['invitation_id']}  {status}{label_str}")


def revoke_invitation(platform: PlatformEnvironment, invitation_id: str):
    workspace_id, user_key = load_current_workspace(platform)
    app_cli = AppClient(platform)
    app_cli.workspace_login(user_key)
    resp = app_cli.post(
        "workspace/revoke-invitation",
        json={
            "tenant_id": workspace_id,
            "invitation_id": invitation_id,
        },
    )
    resp.raise_for_status()
    print(f"Revoked invitation {invitation_id}")


def redeem_invitation(platform: PlatformEnvironment, token: str):
    id_token = IdTokenClient(platform).load_id_token()
    app_cli = AppClient(platform)
    resp = app_cli.post(
        "authenticate",
        json={"id_token": id_token},
        target_api=TargetApi.USER_PUBLIC,
    )
    resp.raise_for_status()
    app_cli.workspace_login(resp.json()["user_key"])
    resp = app_cli.post(
        "workspace/redeem-invitation",
        json={"token": token},
    )
    resp.raise_for_status()
    body = resp.json()
    print(f"Joined workspace {body['name']} ({body['tenant_id']}) as {body['role']}")


def select(platform: PlatformEnvironment, workspace_id_or_name: str):
    """Log in to a tenant as the current CLI user"""
    id_token = IdTokenClient(platform).load_id_token()
    app_cli = AppClient(platform)
    workspace_id = _resolve_workspace_identifier(app_cli, id_token, workspace_id_or_name)
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
        list_workspaces(platform, json)
    if args["create"]:
        create(
            platform=platform,
            name=args["--name"],
        )
    if args["invite"]:
        role = args["--role"] or "member"
        if role not in ("admin", "member"):
            raise PlatformCliError("role must be 'admin' or 'member'")
        invite(platform=platform, role=role, label=args["--label"] or "")
    if args["list-invitations"]:
        list_invitations(platform=platform)
    if args["revoke-invitation"]:
        revoke_invitation(platform=platform, invitation_id=args["<invitation_id>"])
    if args["redeem-invitation"]:
        redeem_invitation(platform=platform, token=args["<token>"])
    if args["select"]:
        workspace_id = args["<workspace>"]
        select(platform, workspace_id)
    if args["rename"]:
        workspace_id, user_key = load_current_workspace(platform)
        name = args["<name>"]
        rename(platform=platform, workspace_id=workspace_id, name=name)
