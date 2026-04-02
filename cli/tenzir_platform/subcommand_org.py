# SPDX-FileCopyrightText: (c) 2026 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

"""Usage:
tenzir-platform org info
tenzir-platform org create <name>
tenzir-platform org create-workspace [--name=<name>]
tenzir-platform org delete
tenzir-platform org invite [--role=<role>] [--label=<label>]
tenzir-platform org leave
tenzir-platform org list-invitations
tenzir-platform org revoke-invitation <invitation_id>
tenzir-platform org redeem-invitation <token>
tenzir-platform org remove-member <user_id>
"""

from datetime import datetime, timezone

from docopt import docopt  # type: ignore[import-untyped]
from requests import HTTPError

from tenzir_platform.helpers.client import AppClient, TargetApi
from tenzir_platform.helpers.environment import PlatformEnvironment
from tenzir_platform.helpers.exceptions import PlatformCliError
from tenzir_platform.helpers.oidc import IdTokenClient


def _authenticate(platform: PlatformEnvironment) -> AppClient:
    """Authenticate the user and return a client with a user_key.

    Uses the id_token to obtain a user_key without requiring a workspace
    to be selected."""
    id_token = IdTokenClient(platform).load_id_token()
    client = AppClient(platform)
    resp = client.post(
        "authenticate",
        json={"id_token": id_token},
        target_api=TargetApi.USER_PUBLIC,
    )
    resp.raise_for_status()
    client.workspace_login(resp.json()["user_key"])
    return client


def _get_current_org_id(client: AppClient) -> str:
    resp = client.post("org/list", json={})
    resp.raise_for_status()
    organizations = resp.json().get("organizations", [])
    if len(organizations) == 0:
        raise PlatformCliError("you are not a member of any organization")
    return organizations[0]["organization_id"]


def create(platform: PlatformEnvironment, name: str):
    client = _authenticate(platform)
    resp = client.post("org/create", json={"name": name})
    resp.raise_for_status()
    print(f"Created organization {resp.json()['organization_id']}")


def create_workspace(platform: PlatformEnvironment, name: str | None):
    if name is None:
        time_suffix = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        name = f"workspace-{time_suffix}"
    client = _authenticate(platform)
    resp = client.post(
        "workspace/create",
        json={
            "name": name,
            "org_owned": True,
        },
    )
    resp.raise_for_status()
    created_workspace = resp.json()["tenant_id"]
    print(f"Created workspace {created_workspace}")


def info(platform: PlatformEnvironment):
    client = _authenticate(platform)
    org_id = _get_current_org_id(client)
    org_resp = client.post("org/get", json={"organization_id": org_id})
    org_resp.raise_for_status()
    members_resp = client.post("org/list-members", json={"organization_id": org_id})
    members_resp.raise_for_status()
    org = org_resp.json()
    members = members_resp.json().get("members", [])
    invitations = []
    try:
        invitations_resp = client.post("org/list-invitations", json={"organization_id": org_id})
        invitations_resp.raise_for_status()
        invitations = invitations_resp.json().get("invitations", [])
    except HTTPError as e:
        if e.response is None or e.response.status_code != 403:
            raise
    print(f"Organization: {org['name']} ({org['organization_id']})")
    print(f"Members: {len(members)}")
    print(f"Pending invitations: {len([i for i in invitations if i.get('status') == 'pending'])}")


def invite(platform: PlatformEnvironment, role: str, label: str):
    client = _authenticate(platform)
    org_id = _get_current_org_id(client)
    resp = client.post(
        "org/create-invitation",
        json={
            "organization_id": org_id,
            "role": role,
            "label": label,
        },
    )
    resp.raise_for_status()
    body = resp.json()
    print(f"Invitation id: {body['invitation_id']}")
    print(f"Token: {body['token']}")


def list_invitations(platform: PlatformEnvironment):
    client = _authenticate(platform)
    org_id = _get_current_org_id(client)
    resp = client.post("org/list-invitations", json={"organization_id": org_id})
    resp.raise_for_status()
    invitations = resp.json().get("invitations", [])
    if not invitations:
        print("No invitations.")
        return
    for inv in invitations:
        status = inv.get("status", "unknown")
        label = inv.get("label", "")
        label_str = f" ({label})" if label else ""
        print(f"  {inv['invitation_id']}  {status}  role={inv.get('role', '?')}{label_str}")


def revoke_invitation(platform: PlatformEnvironment, invitation_id: str):
    client = _authenticate(platform)
    org_id = _get_current_org_id(client)
    resp = client.post(
        "org/revoke-invitation",
        json={
            "organization_id": org_id,
            "invitation_id": invitation_id,
        },
    )
    resp.raise_for_status()
    print(f"Revoked invitation {invitation_id}")


def redeem_invitation(platform: PlatformEnvironment, token: str):
    client = _authenticate(platform)
    resp = client.post(
        "org/redeem-invitation",
        json={"token": token},
    )
    resp.raise_for_status()
    body = resp.json()
    print(f"Joined organization {body['name']} ({body['organization_id']}) as {body['role']}")


def delete(platform: PlatformEnvironment):
    client = _authenticate(platform)
    org_id = _get_current_org_id(client)
    resp = client.post("org/delete", json={"organization_id": org_id})
    resp.raise_for_status()
    print(f"Deleted organization {org_id}")


def remove_member(platform: PlatformEnvironment, user_id: str):
    client = _authenticate(platform)
    org_id = _get_current_org_id(client)
    resp = client.post(
        "org/remove-member",
        json={"organization_id": org_id, "user_id": user_id},
    )
    resp.raise_for_status()
    print(f"Removed member {user_id}")


def leave(platform: PlatformEnvironment):
    client = _authenticate(platform)
    org_id = _get_current_org_id(client)
    resp = client.post("org/leave", json={"organization_id": org_id})
    resp.raise_for_status()
    print(f"Left organization {org_id}")


def org_subcommand(platform: PlatformEnvironment, argv):
    args = docopt(__doc__, argv=argv)
    if args["info"]:
        info(platform=platform)
    elif args["create"]:
        create(platform=platform, name=args["<name>"])
    elif args["create-workspace"]:
        create_workspace(platform=platform, name=args["--name"])
    elif args["delete"]:
        delete(platform=platform)
    elif args["invite"]:
        role = args["--role"] or "member"
        if role not in ("admin", "member"):
            raise PlatformCliError("role must be 'admin' or 'member'")
        invite(platform=platform, role=role, label=args["--label"] or "")
    elif args["leave"]:
        leave(platform=platform)
    elif args["list-invitations"]:
        list_invitations(platform=platform)
    elif args["revoke-invitation"]:
        revoke_invitation(platform=platform, invitation_id=args["<invitation_id>"])
    elif args["redeem-invitation"]:
        redeem_invitation(platform=platform, token=args["<token>"])
    elif args["remove-member"]:
        remove_member(platform=platform, user_id=args["<user_id>"])
