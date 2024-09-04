# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

"""Usage:
  tenzir-platform admin add-auth-rule [-d] email-domain <workspace_id> <domain> [--connection=<connection>]
  tenzir-platform admin add-auth-rule [-d] organization-membership <workspace_id> <organization_claim> <organization> [--connection=<connection>]
  tenzir-platform admin add-auth-rule [-d] organization-role <workspace_id> <roles_claim> <role> <organization_claim> <organization> [--connection=<connection>]
  tenzir-platform admin add-auth-rule [-d] user <workspace_id> <user_id>
  tenzir-platform admin delete-auth-rule <workspace_id> <auth_rule_index>
  tenzir-platform admin list-auth-rules <workspace_id>
  tenzir-platform admin create-workspace <owner_namespace> <owner_id> [--name=<workspace_name>] [--category=<workspace_category>]
  tenzir-platform admin delete-workspace <workspace_id>
  tenzir-platform admin update-workspace <workspace_id> [--name=<workspace_name>] [--icon-url=<icon_url>] [--owner-namespace=<namespace>] [--owner-id=<owner_id>] [--category=<workspace_category>]
  tenzir-platform admin list-global-workspaces
  tenzir-platform admin spawn-node <workspace_id> <image> [--lifetime=<lifetime>]

Options:
  -d,--dry-run                      Do not add the rule, only print a JSON representation.
  --connection=<connection>         An optional prefix that must be matched by the 'sub' field
  --name=<workspace_name>           The user-visible name of the workspace.
  --icon-url=<icon_url>             The image to be used for this workspace in the frontend.
  --owner-id=<owner_id>             The owner id of the current namespace. This can be set to
                                    an arbitrary string that allows the platform administrators
                                    to identify the owner of this workspace.
  --owner-namespace=<namespace>     Must be either 'user' or 'organization'.
  --category=<workspace_category>   An arbitrary string that is used as header when grouping
                                    multiple workspaces from the same owner in the frontend.
                                    Note that currently only workspaces with the same owner id
                                    are grouped.
  --lifetime=<lifetime>             The lifetime of the new node in seconds. [default: 360]
"""

from tenzir_platform.helpers.client import AppClient, TargetApi
from tenzir_platform.helpers.oidc import IdTokenClient
from tenzir_platform.helpers.environment import PlatformEnvironment
from tenzir_platform.helpers.auth_rule import (
    AuthRule,
    UserAuthRule,
    EmailDomainRule,
    RoleAndOrganizationRule,
    OrganizationMembershipRule,
)
from pydantic import BaseModel
from typing import Optional
from docopt import docopt
import json


def _get_global_workspaces(client: AppClient):
    resp = client.get(
        "global-tenant-list",
        target_api=TargetApi.ADMIN,
    )
    resp.raise_for_status()
    return resp.json()


def add_auth_rule(client: AppClient, workspace_id: str, rule: AuthRule):
    resp = client.post(
        "add-auth-function",
        target_api=TargetApi.ADMIN,
        json={"tenant_id": workspace_id, "auth_fn": rule.model_dump()},
    )
    resp.raise_for_status()
    print(f"Added {rule.model_dump_json()}")


def delete_auth_rule(client: AppClient, workspace_id: str, index: int):
    resp = client.post(
        "delete-auth-function",
        target_api=TargetApi.ADMIN,
        json={"tenant_id": workspace_id, "index": index},
    )
    resp.raise_for_status()
    print(f"Deleted auth function {index} of workspace {workspace_id}")


def list_auth_rules(client: AppClient, workspace_id: str):
    resp = client.get(
        "global-tenant-list",
        target_api=TargetApi.ADMIN,
    )
    resp.raise_for_status()
    for t in resp.json():
        if t["id"] == workspace_id:
            print(json.dumps(t["auth_functions"], indent=4))


def create_workspace(client: AppClient, name: str, owner: str, owner_namespace: str):
    resp = client.post(
        "create-tenant",
        target_api=TargetApi.ADMIN,
        json={
            "owner": {
                "namespace": owner_namespace,
                "owner_id": owner,
            },
            "name": name,
        },
    )
    resp.raise_for_status()
    tenant_id = resp.json()["tenant_id"]
    print(f"Created workspace {tenant_id}")


def delete_workspace(client: AppClient, workspace_id: str):
    resp = client.post(
        "force-delete-tenant",
        target_api=TargetApi.ADMIN,
        json={
            "tenant_id": workspace_id,
        },
    )
    resp.raise_for_status()
    response = resp.json()
    print(json.dumps(response, indent=4))


def update_workspace(
    client: AppClient,
    workspace_id: str,
    workspace_name: Optional[str],
    icon_url: Optional[str],
    owner_namespace: Optional[str],
    owner_id: Optional[str],
    workspace_category: Optional[str],
):
    resp = client.post(
        "update-tenant",
        target_api=TargetApi.ADMIN,
        json={
            "tenant_id": workspace_id,
            "name": workspace_name,
            "icon_url": icon_url,
            "owner_namespace": owner_namespace,
            "owner_id": owner_id,
            "owner_display_name": workspace_category,
        },
    )
    resp.raise_for_status()
    print(f"Updated workspace {workspace_id}")


def list_global_workspaces(client: AppClient):
    tenants = _get_global_workspaces(client)
    print(json.dumps(tenants, indent=4))


def spawn_node(client: AppClient, workspace_id: str, image: str, lifetime: int):
    resp = client.post(
        "spawn-node",
        target_api=TargetApi.ADMIN,
        json={
            "tenant_id": workspace_id,
            "image": image,
            "lifetime": lifetime,
            "node_name": "Spawned by CLI",
            "memory": 8192,
        },
    )
    resp.raise_for_status()
    result = resp.json()
    print(json.dumps(result, indent=4))


def auth_rule_from_arguments(arguments) -> AuthRule:
    connection = arguments["--connection"]
    domain = arguments["<domain>"]
    user_id = arguments["<user_id>"]
    organization_claim = arguments["<organization_claim>"]
    organization = arguments["<organization>"]
    roles_claim = arguments["<roles_claim>"]
    role = arguments["<role>"]
    auth_rule: AuthRule
    if arguments["email-domain"]:
        auth_rule = EmailDomainRule(connection=connection, email_domain=domain)
    elif arguments["organization-membership"]:
        auth_rule = OrganizationMembershipRule(
            connection=connection,
            organization_claim=organization_claim,
            organization=organization,
        )
    elif arguments["organization-role"]:
        auth_rule = RoleAndOrganizationRule(
            connection=connection,
            roles_claim=roles_claim,
            role=role,
            organization_claim=organization_claim,
            organization=organization,
        )
    elif arguments["user"]:
        auth_rule = UserAuthRule(user_id=user_id)
    else:
        raise Exception("couldn't determine auth rule from command-line arguments")
    return auth_rule


def admin_subcommand(platform: PlatformEnvironment, argv):
    arguments = docopt(__doc__, argv=argv)

    def connect_and_login() -> AppClient:
        token_client = IdTokenClient(platform)
        token = token_client.load_id_token()
        client = AppClient(platform)
        client.user_login(token)
        return client

    if arguments["create-workspace"]:
        client = connect_and_login()
        owner_namespace = arguments["<owner_namespace>"]
        owner = arguments["<owner_id>"]
        name: str
        if arguments["--name"] is not None:
            name = arguments["--name"]
        else:
            name = f"{owner}'s Workspace"
        category = arguments["--category"]
        create_workspace(client, name, owner, owner_namespace)

    if arguments["delete-workspace"]:
        workspace_id = arguments["<workspace_id>"]
        client = connect_and_login()
        delete_workspace(client, workspace_id)

    if arguments["update-workspace"]:
        workspace_id = arguments["<workspace_id>"]
        client = connect_and_login()
        owner_namespace = arguments["--owner-namespace"]
        owner_id = arguments["--owner-id"]
        workspace_category = arguments["--category"]
        workspace_name = arguments["--name"]
        icon_url = arguments["--icon-url"]
        update_workspace(
            client,
            workspace_id,
            workspace_name=workspace_name,
            icon_url=icon_url,
            owner_namespace=owner_namespace,
            owner_id=owner_id,
            workspace_category=workspace_category,
        )

    if arguments["list-global-workspaces"]:
        client = connect_and_login()
        list_global_workspaces(client)

    if arguments["add-auth-rule"]:
        workspace_id = arguments["<workspace_id>"]
        dry_run = arguments["--dry-run"]
        auth_rule = auth_rule_from_arguments(arguments)
        if dry_run:
            print(f"Would add rule {auth_rule.model_dump_json()}")
        else:
            client = connect_and_login()
            add_auth_rule(client, workspace_id, auth_rule)

    if arguments["delete-auth-rule"]:
        workspace_id = arguments["<workspace_id>"]
        auth_rule_index: int = arguments["<auth_rule_index>"]
        client = connect_and_login()
        delete_auth_rule(client, workspace_id, auth_rule_index)

    if arguments["list-auth-rules"]:
        workspace_id = arguments["<workspace_id>"]
        client = connect_and_login()
        list_auth_rules(client, workspace_id)

    if arguments["spawn-node"]:
        workspace_id = arguments["<workspace_id>"]
        image = arguments["<image>"]
        lifetime = arguments["--lifetime"]
        client = connect_and_login()
        spawn_node(client, workspace_id, image, lifetime)
