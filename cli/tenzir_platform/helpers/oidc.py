# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

import hashlib
import os
import time
import base64
import sys
import jwt
import requests
from jwt import PyJWKClient
from typing import Optional, Any
from tenzir_platform.helpers.cache import filename_in_cache
from tenzir_platform.helpers.environment import PlatformEnvironment
from tenzir_platform.helpers.exceptions import PlatformCliError


def INVALID_API_KEY(hint: str):
    return PlatformCliError("invalid JWT").add_hint(hint)


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


x_www_form_urlencoded = {"Content-Type": "application/x-www-form-urlencoded"}


class IdTokenClient:
    def __init__(self, platform: PlatformEnvironment):
        self.platform_environment = platform
        self.issuer = platform.issuer_url
        self.client_id = platform.client_id
        self.client_secret = platform.client_secret
        self.audience = (
            platform.audience if platform.audience is not None else platform.client_id
        )
        self.scope = platform.scope
        if platform.client_secret_file is not None:
            with open(platform.client_secret_file, "r") as f:
                self.client_secret = f.read()
        self.hardcoded_id_token = platform.id_token
        self.verbose = platform.verbose
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
            audience=self.audience,
        )
        return ValidOidcToken(validated_token)

    def reauthenticate_token(self, interactive: bool = True) -> str:
        if interactive:
            token_data = self._device_code_flow()
        else:
            token_data = self._client_credentials_flow()
        if self.verbose:
            print(f"received token data: {token_data}")
        return self._unwrap_flow_result(token_data)

    def _device_code_flow(self) -> dict[str, str]:
        device_code_payload = {
            "client_id": self.client_id,
            "scope": self.scope if self.scope is not None else "openid email",
        }

        device_code_response = requests.post(
            self.device_authorization_endpoint,
            data=device_code_payload,
            headers=x_www_form_urlencoded,
        )

        if device_code_response.status_code != 200:
            raise PlatformCliError(
                f"Error generating the device code: {device_code_response.text}"
            )

        device_code_data = device_code_response.json()
        # The `_complete` url  already contains the user code as a url param,
        # some OIDC providers provide it and some don't.
        if "verification_uri_complete" in device_code_data:
            verification_url = device_code_data["verification_uri_complete"]
        elif "verification_uri" in device_code_data:
            verification_url = device_code_data["verification_uri"]
        elif "verification_url" in device_code_data:
            verification_url = device_code_data[
                "verification_url"
            ]  # Google is not following the spec :/
        else:
            raise PlatformCliError(
                f"couldn't find verification URL in OIDC provider response"
            ).add_hint(f"received data {device_code_data}")

        print(
            "1. On your computer or mobile device navigate to: ",
            verification_url,
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
        # Google's braindead implementation creates a "public" client secret
        # for apps using device code flow, that is required for the request.
        if self.client_secret is not None:
            token_payload["client_secret"] = self.client_secret
        authenticated = False
        while not authenticated:
            token_response = requests.post(
                self.token_endpoint, data=token_payload, headers=x_www_form_urlencoded
            )
            token_data = token_response.json()
            if token_response.status_code == 200:
                print("Authenticated!")
                break
            elif token_data["error"] not in ("authorization_pending", "slow_down"):
                raise PlatformCliError(
                    "failed to perform device code authentication"
                ).add_hint(f"upstream error message: {token_data['error_description']}")
            else:
                time.sleep(device_code_data["interval"])
        return token_data

    def _client_credentials_flow(self) -> dict[str, str]:
        if self.client_secret is None:
            raise PlatformCliError(
                "Need a client secret in order to perform non-interactive login"
            )
        client_secret = self.client_secret
        client_credentials_payload = {
            "grant_type": "client_credentials",
            "scope": self.scope if self.scope is not None else "openid",
            "client_id": self.client_id,
            "client_secret": client_secret,
            "audience": self.client_id,
        }
        credentials = base64.b64encode(
            f"{self.client_id}:{client_secret}".encode("utf-8")
        ).decode("utf-8")
        response = requests.post(
            self.token_endpoint,
            data=client_credentials_payload,
            headers={
                "Authorization": f"Basic {credentials}",
                **x_www_form_urlencoded,
            },
        )
        response.raise_for_status()
        return response.json()

    def _unwrap_flow_result(self, token_data: dict[str, str]) -> str:
        if "id_token" in token_data:
            id_token = token_data["id_token"]
        elif "access_token" in token_data:
            # Some identity providers don't provide an id token for decive
            # code authorization. If the access token is in JWT format, we
            # can still salvage this.
            try:
                self.validate_token(token_data["access_token"])
            except:
                raise PlatformCliError("access token is not in JWT format").add_context(
                    "while validating the access_token returned by the identity provider"
                )
            print(
                "warning: no id_token in response from identity provider, falling back to access_token",
                file=sys.stderr,
            )
            id_token = token_data["access_token"]
        else:
            raise INVALID_API_KEY(f"cannot process token response: {token_data}")
        current_user = self.validate_token(id_token)
        if self.verbose:
            print(f"obtained id_token: {current_user}")
        self._store_id_token(id_token)
        return id_token

    def _filename_in_cache(self):
        return filename_in_cache(self.platform_environment, "id_token")

    def _store_id_token(self, token: str):
        filename = self._filename_in_cache()
        if self.verbose:
            print(f"saving token to {filename}")
        os.makedirs(os.path.dirname(filename), exist_ok=True)
        with open(filename, "w") as f:
            f.write(token)

    def load_id_token(self, interactive: Optional[bool] = None) -> str:
        # If the user is explicitly passing an id token via
        # environment variable, always use that.
        if self.hardcoded_id_token:
            try:
                self.validate_token(self.hardcoded_id_token)
                return self.hardcoded_id_token
            except Exception as e:
                raise PlatformCliError(f"invalid JWT").add_context(
                    "while validating TENZIR_PLATFORM_CLI_ID_TOKEN"
                ).add_hint(f"upstream error: {e}")
        # Otherwise, try to load a valid token from the cache
        # in the filesystem.
        filename = self._filename_in_cache()
        try:
            with open(filename, "r") as f:
                token = f.read()
            self.validate_token(token)
            return token
        except Exception:
            print(
                "could not load valid token from cache, reauthenticating",
                file=sys.stderr,
            )
        # If the user didn't explicitly choose [non-]interactive login,
        # assume that client credentials flow is desired whenever a client
        # secret was set.
        if interactive is None:
            interactive = self.client_secret is None
            assert interactive is not None  # assist mypy
        return self.reauthenticate_token(interactive=interactive)
