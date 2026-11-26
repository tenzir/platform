# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

"""Usage:
  tenzir-platform dashboard add <dashboard_id> <file>
  tenzir-platform dashboard update <dashboard_id> <file>
  tenzir-platform dashboard delete <dashboard_id>
  tenzir-platform dashboard list [--json]

Options:
  <dashboard_id>  A unique identifier for the dashboard.
  <file>          Path to a YAML file describing the dashboard.

Description:
  tenzir-platform dashboard add <dashboard_id> <file>
    Create a new dashboard from a YAML definition file. Fails if a
    dashboard with the same id already exists.

  tenzir-platform dashboard update <dashboard_id> <file>
    Replace the contents of an existing dashboard from a YAML definition
    file. Fails if no dashboard with the given id exists.

  tenzir-platform dashboard delete <dashboard_id>
    Delete the specified dashboard.

  tenzir-platform dashboard list [--json]
    List all dashboards in the current workspace.
"""

import json
import random
import string
from enum import Enum

import yaml
from docopt import docopt
from pydantic import BaseModel, ConfigDict, ValidationError

from tenzir_platform.helpers.cache import load_current_workspace
from tenzir_platform.helpers.client import AppClient
from tenzir_platform.helpers.environment import PlatformEnvironment
from tenzir_platform.helpers.exceptions import PlatformCliError

# The frontend requires `w` and `h` on every cell, so fall back to the same
# defaults it uses for new cells (DEFAULT_CELL_WIDTH/HEIGHT in utils.ts).
DEFAULT_CELL_WIDTH = 12
DEFAULT_CELL_HEIGHT = 6


def _generate_cell_id() -> str:
    """Mirrors platform_api.random.generate_dashboard_cell_id in the backend"""
    return "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(10))


class DashboardCell(BaseModel):
    # Copy of StaticDashboardCell in the backend's static_configuration.py.
    model_config = ConfigDict(extra="forbid")

    class CellType(str, Enum):
        chart = "chart"
        table = "table"

    name: str
    definition: str
    type: CellType | None = None
    x: int
    y: int
    w: int = DEFAULT_CELL_WIDTH
    h: int = DEFAULT_CELL_HEIGHT

    def frontend_representation(self) -> dict:
        result: dict = {
            "title": self.name,
            "pipelineDefinition": self.definition,
            "id": _generate_cell_id(),
            "x": self.x,
            "y": self.y,
            "w": self.w,
            "h": self.h,
        }

        if self.type is not None:
            result["cellType"] = self.type.value
        return result


class DashboardConfig(BaseModel):
    # Copy of StaticDashboardConfig in the backend's static_configuration.py.
    model_config = ConfigDict(extra="forbid")

    name: str
    cells: list[DashboardCell]

    def frontend_representation(self) -> dict:
        return {
            "cells": [cell.frontend_representation() for cell in self.cells],
        }


def _list_dashboards(client: AppClient, workspace_id: str) -> list[dict]:
    "Return a list of all available dashboards in the workspace"
    resp = client.post("dashboard/list", json={"tenant_id": workspace_id})
    resp.raise_for_status()
    return resp.json()["dashboards"]


def _load_dashboard_file(file: str) -> DashboardConfig:
    """Read and validate a dashboard definition from a YAML file."""
    try:
        with open(file) as f:
            data = yaml.safe_load(f)
        return DashboardConfig.model_validate(data)
    except (OSError, yaml.YAMLError, ValidationError) as e:
        raise PlatformCliError(f"failed to read dashboard file '{file}'").add_hint(str(e))


def _find_revision(client: AppClient, workspace_id: str, dashboard_id: str) -> str | None:
    """Return the current revision of a dashboard, or None if it doesn't exist."""
    for dashboard in _list_dashboards(client, workspace_id):
        if dashboard["metadata"]["dashboard_id"] == dashboard_id:
            return dashboard["metadata"]["revision"]
    return None


def add(client: AppClient, workspace_id: str, dashboard_id: str, file: str):
    config = _load_dashboard_file(file)
    if _find_revision(client, workspace_id, dashboard_id) is not None:
        raise PlatformCliError(f"dashboard '{dashboard_id}' already exists").add_hint(
            "use 'tenzir-platform dashboard update' to modify it"
        )
    resp = client.post(
        "dashboard/store",
        json={
            "tenant_id": workspace_id,
            "dashboard_id": dashboard_id,
            "content": config.frontend_representation(),
            "summary": {"title": config.name},
        },
    )
    resp.raise_for_status()
    print(f"created dashboard {dashboard_id}")


def update(client: AppClient, workspace_id: str, dashboard_id: str, file: str):
    config = _load_dashboard_file(file)
    revision = _find_revision(client, workspace_id, dashboard_id)
    if revision is None:
        raise PlatformCliError(f"dashboard '{dashboard_id}' does not exist").add_hint(
            "use 'tenzir-platform dashboard add' to create it"
        )
    resp = client.post(
        "dashboard/store",
        json={
            "tenant_id": workspace_id,
            "dashboard_id": dashboard_id,
            "revision": revision,
            "content": config.frontend_representation(),
            "summary": {"title": config.name},
        },
    )
    resp.raise_for_status()
    print(f"updated dashboard {dashboard_id}")


def delete(client: AppClient, workspace_id: str, dashboard_id: str):
    if _find_revision(client, workspace_id, dashboard_id) is None:
        raise PlatformCliError(f"dashboard '{dashboard_id}' does not exist")
    resp = client.post(
        "dashboard/delete", json={"tenant_id": workspace_id, "dashboard_id": dashboard_id}
    )
    resp.raise_for_status()
    print(f"deleted dashboard {dashboard_id}")


def list_dashboards(client: AppClient, workspace_id: str, json_format: bool):
    dashboards = _list_dashboards(client, workspace_id)
    if json_format:
        print(json.dumps(dashboards, indent=4))
        return
    if not dashboards:
        print("no dashboards configured")
        return
    for dashboard in dashboards:
        title = dashboard["summary"].get("title", "")
        dashboard_id = dashboard["metadata"]["dashboard_id"]
        print(f"{title} ({dashboard_id})")


def dashboard_subcommand(platform: PlatformEnvironment, argv):
    args = docopt(__doc__, argv=argv)
    try:
        workspace_id, user_key = load_current_workspace(platform)
        client = AppClient(platform=platform)
        client.workspace_login(user_key)
    except Exception as e:
        raise PlatformCliError(
            "failed to load current workspace, please run 'tenzir-platform workspace select' first"
        ).add_hint(f"reason: {e}")

    if args["add"]:
        add(client, workspace_id, args["<dashboard_id>"], args["<file>"])
    elif args["update"]:
        update(client, workspace_id, args["<dashboard_id>"], args["<file>"])
    elif args["delete"]:
        delete(client, workspace_id, args["<dashboard_id>"])
    elif args["list"]:
        list_dashboards(client, workspace_id, args["--json"])
