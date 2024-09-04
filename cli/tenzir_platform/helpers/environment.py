# SPDX-FileCopyrightText: (c) 2024 The Tenzir Contributors
# SPDX-License-Identifier: BSD-3-Clause

from pydantic_settings import BaseSettings
from typing import Optional

API_ENDPOINT = "https://rest.tenzir.app/production-v1"
ISSUER_URL = "https://tenzir.eu.auth0.com/"
CLIENT_ID = "vzRh8grIVu1bwutvZbbpBDCOvSzN8AXh"


# All values can be set using environment variables like
#
#   `TENZIR_PLATFORM_CLI_API_ENDPOINT=https://tenzir.example`
#
# (and also can only set this way, because we don't provide
# separate command-line options)
class PlatformEnvironment(BaseSettings):
    # The remote API endpoint of the platform.
    api_endpoint: str = API_ENDPOINT

    # An arbitrary short string to identify this environment
    # in the local cache directory.
    stage_identifier: str = "prod"

    # Configuration of the OIDC for authentication.
    issuer_url: str = ISSUER_URL
    client_id: str = CLIENT_ID

    # A client secret is only necessary for non-interactive logins
    # using the client credentials flow.
    client_secret: Optional[str] = None
    client_secret_file: Optional[str] = None

    # Enable more verbose print statements.
    verbose: bool = False

    @staticmethod
    def load():
        return PlatformEnvironment(
            _env_prefix="TENZIR_PLATFORM_CLI_", _env_nested_delimiter="__"
        )
