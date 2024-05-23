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
        "Read:${TENZIR_PLATFORM_INTERNAL_BUCKET_NAME}",
        "Write:${TENZIR_PLATFORM_INTERNAL_BUCKET_NAME}",
        "List:${TENZIR_PLATFORM_INTERNAL_BUCKET_NAME}",
        "Tagging:${TENZIR_PLATFORM_INTERNAL_BUCKET_NAME}",
        "Admin:${TENZIR_PLATFORM_INTERNAL_BUCKET_NAME}"
      ]
    }
  ]
}
EOF

exec /entrypoint.sh "$@"
