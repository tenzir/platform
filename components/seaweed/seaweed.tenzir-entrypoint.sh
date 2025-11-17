#!/bin/sh

# Check for permission mismatch indicating user change
if [ -d /var/lib/seaweedfs ]; then
  dir_owner=$(stat -c '%u' /var/lib/seaweedfs)
  current_user=$(id -u)

  if [ "$dir_owner" = "0" ] && [ "$current_user" != "0" ]; then
    echo "Error: /var/lib/seaweedfs is owned by root, but the current user is non-root." >&2
    echo "The default user has changed. Please see https://docs.tenzir.com/changelog/platform/v1-22-0/ for details." >&2
    exit 1
  fi
fi

cat <<EOF > /opt/seaweed/config.json
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

exec /entrypoint.sh "$@"
