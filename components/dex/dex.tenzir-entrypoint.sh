#!/bin/sh

# Custom entrypoint to work around some options of dex being
# only configurable via config file and not via environment
# variable.

cat <<EOF > /etc/dex/tenzir-config.yaml
issuer: ${TENZIR_PLATFORM_OIDC_PROVIDER_ISSUER_URL}

storage:
  type: sqlite3

web:
  http: 0.0.0.0:5556

staticClients:
  - id: tenzir-app
    redirectURIs:
      - '${TENZIR_PLATFORM_DOMAIN}/login/oauth/callback'
    name: 'Tenzir App'
    secret: ${TENZIR_PLATFORM_OIDC_PROVIDER_CLIENT_SECRET}

enablePasswordDB: true

staticPasswords:
- email: "${DEX_EMAIL}"
  hash: "${DEX_PASSWORD_HASH}"
  username: "${DEX_USER}"
  userID: "08a8684b-db88-4b73-90a9-3cd1661f5466"
EOF

# Chain into the entrypoint of the upstream dexidp/dex image
exec /usr/local/bin/docker-entrypoint "$@"



