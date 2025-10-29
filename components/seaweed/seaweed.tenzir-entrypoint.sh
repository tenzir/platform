#!/bin/sh

cat <<EOF > /config.json
{
  "identities": [
    {
      "name": "tenzir-platform",
      "credentials": [
        {
          "accessKey": "${TENZIR_PLATFORM_INTERNAL_ACCESS_KEY_ID}",
          "secretKey": "${TENZIR_PLATFORM_INTERNAL_SECRET_ACCESS_KEY}"
        }
      ],
      "actions": [
        "Read",
        "Write",
        "List",
        "Tagging",
        "Admin"
      ]
    }
  ]
}
EOF

# Configure CORS if CORS_ORIGIN is set
if [ -n "$CORS_ORIGIN" ]; then
  cat <<EOF > /security.toml
[cors.allowed_origins]
values = "$CORS_ORIGIN"
EOF
fi

exec /entrypoint.sh "$@"
