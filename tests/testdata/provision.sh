#!/bin/bash
set -e

API_URL="http://localhost:80/api"
CONTAINER_NAME="${CONTAINER_NAME:-test-mail}"
ADMIN_PASSWORD="admin"

echo "Waiting for server to be ready..."
MAX_RETRIES=30
for i in $(seq 1 $MAX_RETRIES); do
  if curl -sf -u "admin:${ADMIN_PASSWORD}" "${API_URL}/principal" > /dev/null 2>&1; then
    echo "Server is ready!"
    break
  fi
  if [ "$i" -eq "$MAX_RETRIES" ]; then
    echo "Server failed to start after $MAX_RETRIES retries"
    exit 1
  fi
  echo "Waiting... (attempt $i/$MAX_RETRIES)"
  sleep 2
done

echo "Using admin password for provisioning..."

# Create domain (ignore if already exists)
echo "Creating domain example.org..."
DOMAIN_RESPONSE=$(curl -s -u "admin:${ADMIN_PASSWORD}" -X POST "${API_URL}/principal" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "domain",
    "name": "example.org",
    "quota": 0,
    "description": "Example domain"
  }')

if echo "$DOMAIN_RESPONSE" | grep -q '"data"'; then
  DOMAIN_ID=$(echo "$DOMAIN_RESPONSE" | grep -o '"data":[0-9]*' | cut -d':' -f2)
  echo "Domain created with ID: $DOMAIN_ID"
else
  echo "Domain already exists or creation failed"
  DOMAIN_ID=""
fi

# Create Alice
echo "Creating account alice@example.org..."
ALICE_ID=$(curl -s -u "admin:${ADMIN_PASSWORD}" -X POST "${API_URL}/principal" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "individual",
    "name": "alice",
    "quota": 0,
    "description": "Alice",
    "emails": ["alice@example.org"],
    "secrets": ["aliceSecret"],
    "roles": ["user"]
  }' | grep -o '"data":[0-9]*' | cut -d':' -f2)

echo "Alice account created with ID: $ALICE_ID"

# Create Bob
echo "Creating account bob@example.org..."
BOB_ID=$(curl -s -u "admin:${ADMIN_PASSWORD}" -X POST "${API_URL}/principal" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "individual",
    "name": "bob",
    "quota": 0,
    "description": "Bob",
    "emails": ["bob@example.org"],
    "secrets": ["bobSecret"],
    "roles": ["user"]
  }' | grep -o '"data":[0-9]*' | cut -d':' -f2)

echo "Bob account created with ID: $BOB_ID"

# Create group
echo "Creating group everyone@example.org..."
GROUP_ID=$(curl -s -u "admin:${ADMIN_PASSWORD}" -X POST "${API_URL}/principal" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "group",
    "name": "everyone",
    "quota": 0,
    "description": "Everyone group",
    "emails": ["everyone@example.org"]
  }' | grep -o '"data":[0-9]*' | cut -d':' -f2)

echo "Group created with ID: $GROUP_ID"

# Add members to group
echo "Adding members to group..."
curl -s -u "admin:${ADMIN_PASSWORD}" -X PATCH "${API_URL}/principal/${GROUP_ID}" \
  -H "Content-Type: application/json" \
  -d '[
    {"action": "addItem", "field": "members", "value": "alice@example.org"},
    {"action": "addItem", "field": "members", "value": "bob@example.org"}
  ]' > /dev/null

echo "Provisioning complete!"
echo "Alice ID: $ALICE_ID"
echo "Bob ID: $BOB_ID"
echo "Group ID: $GROUP_ID"

echo "Importing test emails..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
docker cp "${SCRIPT_DIR}/eml" "${CONTAINER_NAME}:/tmp/eml"
docker exec "${CONTAINER_NAME}" bash -c 'for f in /tmp/eml/*.eml; do cat "$f"; echo ""; done | /usr/local/bin/stalwart-cli -u http://localhost:80 -c admin:admin import messages -f mbox alice -'
echo "Email import complete!"

