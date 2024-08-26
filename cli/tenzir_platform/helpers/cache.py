# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

import os
import json
from tenzir_platform.helpers.environment import PlatformEnvironment
from typing import Optional


def filename_in_cache(platform: PlatformEnvironment, filename: str):
    """Return the filename of a file in the cache directory"""
    return (
        os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
        + "/tenzir-platform/"
        + platform.stage_identifier
        + "/"
        + filename
    )


def store_workspace(platform: PlatformEnvironment, workspace_id: str, user_key: str):
    content = json.dumps({"workspace_id": workspace_id, "user_key": user_key})
    filename = filename_in_cache(platform, "workspace")
    if platform.verbose:
        print(f"saving workspace id to {filename}")
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with open(filename, "w") as f:
        f.write(content)


def load_current_workspace(platform: PlatformEnvironment) -> tuple[str, str]:
    filename = filename_in_cache(platform, "workspace")
    with open(filename, "r") as f:
        content_str = f.read().rstrip()
        content = json.loads(content_str)
        if platform.verbose:
            print(f"loaded workspace from {filename}")
        return content["workspace_id"], content["user_key"]
