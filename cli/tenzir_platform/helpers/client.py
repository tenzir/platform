# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

import subprocess
import time
from datetime import datetime, timezone
from enum import Enum

import jwt
import requests
import requests.exceptions
from requests import Response
from tenzir_platform.helpers.environment import PlatformEnvironment

UNAUTHENTICATED = "unauthenticated"


class TargetApi(Enum):
    USER = "user"
    USER_PUBLIC = "user_public"
    ADMIN = "admin"


class AppClient:
    def __init__(
        self,
        platform: PlatformEnvironment,
    ) -> None:
        self.verbose = platform.verbose
        self.id_token: str = UNAUTHENTICATED
        self.user_key: str = UNAUTHENTICATED
        self.endpoint_prefix = platform.api_endpoint.rstrip("/")

    def user_login(self, id_token: str):
        self.id_token = id_token

    def workspace_login(self, user_key: str):
        self.user_key = user_key

    def request(
        self,
        method: str,
        endpoint_suffix: str,
        json: dict | list | None,
        target_api: TargetApi = TargetApi.USER,
        connection_retry: int = 0,
    ) -> Response:
        start = time.time()

        match target_api:
            case TargetApi.USER:
                assert (
                    self.user_key != UNAUTHENTICATED
                ), "missing workspace_login() before making user api requests"
                headers = {"X-Tenzir-UserKey": self.user_key}
                endpoint = self.endpoint_prefix + "/user"
            case TargetApi.USER_PUBLIC:
                headers = {}
                endpoint = self.endpoint_prefix + "/user"
            case TargetApi.ADMIN:
                assert (
                    self.id_token != UNAUTHENTICATED
                ), "missing user_login() before making admin api requests"
                headers = {"X-Tenzir-AdminKey": self.id_token}
                endpoint = self.endpoint_prefix + "/admin"

        for i in range(connection_retry + 1):
            try:
                url = f"{endpoint}/{endpoint_suffix}"
                if self.verbose:
                    print(f"{method} {url}")
                resp = requests.request(
                    method=method,
                    url=url,
                    json=json,
                    headers=headers,
                )
            except requests.exceptions.ConnectionError:
                if i == connection_retry:
                    raise
                print(f"connection error, retrying in 3s...")
                time.sleep(3)
                continue
            break

        return resp

    def post(
        self,
        endpoint_suffix: str,
        json: dict | list,
        target_api: TargetApi = TargetApi.USER,
        connection_retry: int = 0,
    ) -> Response:
        return self.request(
            method="POST",
            endpoint_suffix=endpoint_suffix,
            json=json,
            target_api=target_api,
            connection_retry=connection_retry,
        )

    def get(
        self,
        endpoint_suffix: str,
        target_api: TargetApi = TargetApi.USER,
        connection_retry: int = 0,
    ) -> Response:
        return self.request(
            method="GET",
            endpoint_suffix=endpoint_suffix,
            json=None,
            target_api=target_api,
            connection_retry=connection_retry,
        )
