#!/bin/sh

cat <<EOF > /config.json
{
  "identities": [
    {
      "name": "anonymous",
      "actions": [
        "Read",
        "List"
      ]
    },
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

exec /entrypoint.sh "$@"
