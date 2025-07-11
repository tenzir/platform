# Run this script as:
#
#     uv run --with trustme,python-dotenv create-certificates.py

import os
import trustme
from dotenv import load_dotenv
from urllib.parse import urlparse

# Load environment variables from `.env`
load_dotenv()

# Create a private certificate authority
ca = trustme.CA()
ca.cert_pem.write_to_path("ssl/ca.pem")

# Check that the user didn't forget to create the .env file and all
# required environment variables are set.
for endpoint in ("UI", "API", "NODES", "DOWNLOADS", "LOGIN"):
    full_url = f"TENZIR_PLATFORM_{endpoint}_ENDPOINT"
    if not os.getenv(full_url):
        print(f"error: missing environment variable {full_url}")
        exit(1)

# Get the DNS names for the certificates.
app_endpoint = urlparse(os.getenv("TENZIR_PLATFORM_UI_ENDPOINT")).hostname
platform_endpoint = urlparse(os.getenv("TENZIR_PLATFORM_API_ENDPOINT")).hostname
control_endpoint = urlparse(os.getenv("TENZIR_PLATFORM_NODES_ENDPOINT")).hostname
blobs_endpoint = urlparse(os.getenv("TENZIR_PLATFORM_DOWNLOADS_ENDPOINT")).hostname
login_endpoint = urlparse(os.getenv("TENZIR_PLATFORM_LOGIN_ENDPOINT")).hostname


# Create certificates. Note that these combine both key and certificate,
# so the `TLS_CERTFILE` and `TLS_KEYFILE` options will point to
# the same file.
def write_certificate(server_names: list[str], filename: str) -> None:
    cert = ca.issue_cert(*server_names)
    cert.private_key_and_cert_chain_pem.write_to_path(filename)


# We're creating certificates that also have the service name
# as SAN, so that the containers can also use TSL for connections
# inside the container network. For a production setup, this
# might not be possible, in this case all traffic must
# be routed through the external network.
write_certificate([app_endpoint, "app", "localhost"], filename="ssl/app-cert.pem")
write_certificate([platform_endpoint, "platform"], filename="ssl/platform-cert.pem")
write_certificate([control_endpoint, "websocket-gateway"], filename="ssl/gateway-cert.pem")
write_certificate([blobs_endpoint, "seaweed"], filename="ssl/blobs-cert.pem")
write_certificate([login_endpoint, "keycloak"], filename="ssl/login-cert.pem")
write_certificate(["postgres"], filename="ssl/db-cert.pem")
