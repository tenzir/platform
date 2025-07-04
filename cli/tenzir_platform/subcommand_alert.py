# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

"""Usage:
  tenzir-platform alert add <node> <duration> <webhook_url> [<webhook_body>]
  tenzir-platform alert delete <alert_id>
  tenzir-platform alert list

Options:
  <node>         The node to be monitored.
  <duration>     The amount of time to wait before triggering the alert.
  <webhook_url>  The URL to call when the alert triggers
  <webhook_body> The body to send along with the webhook. Must be valid JSON.

Description:
  tenzir-platform alert add <node> <duration> <webhook>
    Add a new alert to the platform.

  tenzir-platform alert delete <alert_id>
    Delete the specified alert.

  tenzir-platform alert list
    List all configured alerts.
"""

from tenzir_platform.helpers.cache import load_current_workspace
from tenzir_platform.helpers.client import AppClient
from tenzir_platform.helpers.environment import PlatformEnvironment
from tenzir_platform.helpers.exceptions import PlatformCliError
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


def _is_node_id(identifier: str):
    return bool(re.match(r"^n-[a-z0-9]{8}$", identifier))


def _get_node_list(client: AppClient, workspace_id: str) -> List:
    resp = client.post(
        "list-nodes",
        json={
            "tenant_id": workspace_id,
        },
    )
    resp.raise_for_status()
    return resp.json()["nodes"]


def _resolve_node_identifier(
    client: AppClient, workspace_id: str, identifier: str
) -> str:
    # If we already have a node id, use that.
    if _is_node_id(identifier):
        return identifier

    # Otherwise go through the list of nodes and look for a matching name.
    nodes = _get_node_list(client, workspace_id)
    name_matched = [node for node in nodes if node["name"] == identifier]
    if len(name_matched) == 0:
        raise PlatformCliError(f"unknown node {identifier}")
    if len(name_matched) > 1:
        matching_ids = [node["node_id"] for node in name_matched]
        raise PlatformCliError(
            f"ambiguous name {identifier} is shared by nodes {matching_ids}"
        )
    return name_matched[0]["node_id"]


def add(
    client: AppClient,
    workspace_id: str,
    node: str,
    duration: str,
    webhook_url: str,
    webhook_body: str,
):
    node_id = _resolve_node_identifier(client, workspace_id, node)
    seconds = parse_duration(duration)
    if not seconds:
        print(f"invalid duration: {duration}")
        return
    try:
        json.loads(webhook_body)
    except:
        print(f"body must be valid json")
        return
    resp = client.post(
        "alert/add",
        json={
            "tenant_id": workspace_id,
            "node_id": node_id,
            "duration": seconds,
            "webhook_url": webhook_url,
            "webhook_body": webhook_body,
        },
    )
    resp.raise_for_status()
    print(json.dumps(resp.json()))


def delete(client: AppClient, workspace_id: str, alert_id: str):
    resp = client.post(
        "alert/delete",
        json={
            "tenant_id": workspace_id,
            "alert_id": alert_id,
        },
    )
    resp.raise_for_status()
    print(f"deleted alert {alert_id}")


def list(
    client: AppClient,
    workspace_id: str,
):
    resp = client.post(
        "alert/list",
        json={
            "tenant_id": workspace_id,
        },
    )
    resp.raise_for_status()
    alerts = resp.json()["alerts"]
    if len(alerts) == 0:
        print("no alerts configured")
        return
    print("Alert           Node            Trigger Url")
    for alert in alerts:
        alert_id = alert["id"]
        duration = alert["duration"]
        node = alert["node_id"]
        url = alert["webhook_url"]
        print(f"{alert_id}\t{node}\t{duration}s\t{url}")


def alert_subcommand(platform: PlatformEnvironment, argv):
    args = docopt(__doc__, argv=argv)
    try:
        workspace_id, user_key = load_current_workspace(platform)
        client = AppClient(platform=platform)
        client.workspace_login(user_key)
    except Exception as e:
        raise PlatformCliError(f"failed to load current workspace: {e}").add_context(
            "please run 'tenzir-platform workspace select' first"
        )

    if args["add"]:
        node = args["<node>"]
        duration = args["<duration>"]
        webhook_url = args["<webhook_url>"]
        webhook_body = args["<webhook_body>"]
        if webhook_body is None:
            webhook_body = (
                f'{{"text": "Node $NODE_NAME disconnected for more than {duration}s"}}'
            )
        assert json.loads(webhook_body), "body must be valid json"
        add(client, workspace_id, node, duration, webhook_url, webhook_body)
    elif args["delete"]:
        alert = args["<alert_id>"]
        delete(client, workspace_id, alert)
    elif args["list"]:
        list(client, workspace_id)
