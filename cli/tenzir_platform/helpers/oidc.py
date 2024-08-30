# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

import hashlib
import os
import time

import jwt
import requests
from jwt import PyJWKClient
from typing import Optional, Any
from tenzir_platform.helpers.cache import filename_in_cache
from tenzir_platform.helpers.environment import PlatformEnvironment


class INVALID_API_KEY(Exception):
    pass


class ValidOidcToken:
    """The validated and decoded id_token.

    - Validate the presence of some claims required by the OIDC spec
    - Provide helper methods for checks"""

    def __init__(self, raw_oidc: dict[str, Any]) -> None:
        if "sub" not in raw_oidc or not isinstance(raw_oidc["sub"], str):
            raise INVALID_API_KEY("sub string required in OIDC token")
        self.user_id = raw_oidc["sub"]
        self._raw_oidc = raw_oidc

    def check_connection(self, connection: str) -> bool:
        return self.user_id.startswith(f"{connection}|")

    def get_claim_str(self, key: str, default: str) -> str:
        if key in self._raw_oidc and not isinstance(self._raw_oidc[key], str):
            raise INVALID_API_KEY(f"{key} is expected to be a string")
        return self._raw_oidc.get(key, default)

    @staticmethod
    def _is_list(val: Any) -> bool:
        return isinstance(val, list) and all(isinstance(x, str) for x in val)

    def get_claim_list(self, key: str, default: list[str]) -> list[str]:
        if key in self._raw_oidc and not ValidOidcToken._is_list(self._raw_oidc[key]):
            raise INVALID_API_KEY(f"{key} is expected to be a list of strings")
        return self._raw_oidc.get(key, default)

    def __str__(self) -> str:
        return self._raw_oidc.__str__()


class IdTokenClient:
    def __init__(self, platform: PlatformEnvironment):
        self.platform_environment = platform
        self.issuer = platform.issuer_url
        self.client_id = platform.client_id
        self.client_secret = platform.client_secret
        self.client_secret_file = platform.client_secret_file
        self.verbose = False
        discovery_url = f"{self.issuer.rstrip('/')}/.well-known/openid-configuration"
        discovered_configuration = requests.get(discovery_url).json()
        self.jwks_url = discovered_configuration["jwks_uri"]
        self.token_endpoint = discovered_configuration["token_endpoint"]
        self.device_authorization_endpoint = discovered_configuration[
            "device_authorization_endpoint"
        ]

    def validate_token(self, id_token: str) -> ValidOidcToken:
        """Verify the token using the audience specific to the CLI"""
        jwks_client = PyJWKClient(self.jwks_url)
        signing_key = jwks_client.get_signing_key_from_jwt(id_token)
        validated_token = jwt.decode(
            id_token,
            signing_key.key,
            algorithms=["RS256"],
            issuer=self.issuer,
            # for id tokens, the audience is the client_id
            audience=self.client_id,
        )
        return ValidOidcToken(validated_token)

    def reauthenticate_token(self, interactive: bool = True) -> str:
        if interactive:
            token_data = self._device_code_flow()
        else:
            token_data = self._client_credentials_flow()
        return self._unwrap_flow_result(token_data)

    def _device_code_flow(self) -> dict[str, str]:
        device_code_payload = {
            "client_id": self.client_id,
            # Request email by default since many auth rules are checked against the email address.
            "scope": "openid email",
        }

        device_code_response = requests.post(
            self.device_authorization_endpoint,
            data=device_code_payload,
        )

        if device_code_response.status_code != 200:
            raise Exception(
                f"Error generating the device code: {device_code_response.text}"
            )

        device_code_data = device_code_response.json()
        print(
            "1. On your computer or mobile device navigate to: ",
            device_code_data["verification_uri_complete"],
        )
        print(
            "2. Verify you're seeing the following code and confirm: ",
            device_code_data["user_code"],
        )
        print("3. Wait up to 10 seconds")

        token_payload = {
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            "device_code": device_code_data["device_code"],
            "client_id": self.client_id,
        }
        authenticated = False
        while not authenticated:
            token_response = requests.post(self.token_endpoint, data=token_payload)
            token_data = token_response.json()
            if token_response.status_code == 200:
                print("Authenticated!")
                break
            elif token_data["error"] not in ("authorization_pending", "slow_down"):
                print(token_data["error_description"])
                authenticated = True
            else:
                time.sleep(device_code_data["interval"])
        return token_data

    def _client_credentials_flow(self) -> dict[str, str]:
        if self.client_secret_file is not None:
            with open(self.client_secret_file, "r") as f:
                client_secret = f.read()
        elif self.client_secret is not None:
            client_secret = self.client_secret
        else:
            raise Exception(
                "Need a client secret in order to perform non-interactive login"
            )

        client_credentials_payload = {
            "grant_type": "client_credentials",
            "scope": "openid",
            "client_id": self.client_id,
            "client_secret": client_secret,
            "audience": self.client_id,
        }
        response = requests.post(self.token_endpoint, client_credentials_payload)
        response.raise_for_status()
        return response.json()

    def _unwrap_flow_result(self, token_data: dict[str, str]) -> str:
        id_token = token_data["id_token"]
        current_user = self.validate_token(id_token)
        if self.verbose:
            print(f"obtained id_token: {current_user}")
        self._store_id_token(id_token)
        return id_token

    def _filename_in_cache(self):
        return filename_in_cache(self.platform_environment, "id_token")

    def _store_id_token(self, token: str):
        filename = self._filename_in_cache()
        print(f"saving token to {filename}")
        os.makedirs(os.path.dirname(filename), exist_ok=True)
        with open(filename, "w") as f:
            f.write(token)

    def load_id_token(self, interactive: bool = True) -> str:
        filename = self._filename_in_cache()
        try:
            with open(filename, "r") as f:
                token = f.read()
            self.validate_token(token)
            return token
        except Exception:
            print("could not load valid token from cache, reauthenticating")
        return self.reauthenticate_token(interactive=interactive)
