#!/bin/bash
# Provisions the Stalwart v1.x test container.
#
# Stalwart 1.x stores all of its configuration in the data store and manages it
# through the JMAP management API (x:* methods on /jmap/). The container is
# started in recovery mode (port 8080, temporary admin) so this script can
# apply the config, then it restarts the container in normal mode where the
# configured HTTP listener on port 80 serves JMAP.
set -e

RECOVERY_URL="${RECOVERY_URL:-http://localhost:8080}"
API_URL="${API_URL:-http://127.0.0.1:80}"
ADMIN_CRED="admin:admin"
CONTAINER_NAME="${CONTAINER_NAME:-test-mail}"
IMAGE="${IMAGE:-stalwartlabs/stalwart:v1.2.1}"
CONFIG_PATH="${CONFIG_PATH:-$PWD/tests/testdata/config.json}"
DATA_VOLUME="${DATA_VOLUME:-test-mail-data}"

XUSING='["urn:ietf:params:jmap:core","urn:stalwart:jmap"]'
MAILUSING='["urn:ietf:params:jmap:core","urn:ietf:params:jmap:mail"]'

jmap() { # jmap <base-url> <user:pass> <using-json> <methodCalls-json>
  curl -s -m 15 -u "$2" -X POST "$1/jmap/" \
    -H 'Content-Type: application/json' \
    -d "{\"using\":$3,\"methodCalls\":$4}"
}

json() { # json '<expr over j>' -- reads JSON on stdin, prints result
  if command -v node >/dev/null 2>&1; then
    node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{const j=JSON.parse(d);const r=eval(process.argv[1]);console.log(typeof r==="object"?JSON.stringify(r):r)})' "$1"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; j=json.load(sys.stdin); r=eval(sys.argv[1]); print(json.dumps(r) if isinstance(r,(dict,list)) else r)' "$1"
  else
    echo "provision.sh needs node or python3 to parse JSON" >&2
    exit 1
  fi
}

wait_for() { # wait_for <url> <cred>
  for i in $(seq 1 30); do
    if curl -sf -m 3 -u "$2" "$1" > /dev/null 2>&1; then return 0; fi
    if [ "$i" -eq 30 ]; then echo "Timed out waiting for $1" >&2; return 1; fi
    sleep 2
  done
}

echo "Waiting for recovery API on $RECOVERY_URL..."
wait_for "$RECOVERY_URL/jmap/session" "$ADMIN_CRED"
echo "Recovery API is up"

echo "Applying base config (domain, settings, http listener)..."
BASE=$(jmap "$RECOVERY_URL" "$ADMIN_CRED" "$XUSING" '[
  ["x:Domain/set",{"create":{"dom":{"name":"example.org","certificateManagement":{"@type":"Manual"},"dkimManagement":{"@type":"Automatic"},"dnsManagement":{"@type":"Manual"}}}},"c1"],
  ["x:SystemSettings/set",{"update":{"singleton":{"defaultHostname":"127.0.0.1","defaultDomainId":"#dom"}}},"c2"],
  ["x:Authentication/set",{"update":{"singleton":{"minPasswordLength":1,"minPasswordStrength":"zero"}}},"c3"],
  ["x:NetworkListener/set",{"create":{"http80":{"name":"http80","protocol":"http","bind":{"0.0.0.0:80":true,"[::]:80":true},"useTls":false,"implicitTls":false}}},"c4"]
]')
echo "$BASE" | json 'j.methodResponses.map(r=>r[0]+": "+JSON.stringify(r[1])).join("\n")'
DOMAIN_ID=$(echo "$BASE" | json 'j.methodResponses[0][1].created.dom.id')
echo "Domain id: $DOMAIN_ID"

echo "Reloading settings (password policy)..."
jmap "$RECOVERY_URL" "$ADMIN_CRED" "$XUSING" \
  '[["x:Action/set",{"create":{"r":{"@type":"ReloadSettings"}}},"c1"]]' > /dev/null
sleep 2

echo "Creating accounts..."
ACCOUNTS=$(jmap "$RECOVERY_URL" "$ADMIN_CRED" "$XUSING" "[
  [\"x:Account/set\",{\"create\":{
    \"alice\":{\"@type\":\"User\",\"name\":\"alice\",\"domainId\":\"$DOMAIN_ID\",\"description\":\"Alice\",\"credentials\":{\"0\":{\"@type\":\"Password\",\"secret\":\"aliceSecret\"}},\"roles\":{\"@type\":\"User\"}},
    \"bob\":{\"@type\":\"User\",\"name\":\"bob\",\"domainId\":\"$DOMAIN_ID\",\"description\":\"Bob\",\"credentials\":{\"0\":{\"@type\":\"Password\",\"secret\":\"bobSecret\"}},\"roles\":{\"@type\":\"User\"}},
    \"everyone\":{\"@type\":\"Group\",\"name\":\"everyone\",\"domainId\":\"$DOMAIN_ID\",\"description\":\"Everyone group\"}
  }},\"c1\"]
]")
echo "$ACCOUNTS" | json 'j.methodResponses.map(r=>r[0]+": "+JSON.stringify(r[1])).join("\n")'
ALICE_ID=$(echo "$ACCOUNTS" | json 'j.methodResponses[0][1].created.alice.id')
BOB_ID=$(echo "$ACCOUNTS" | json 'j.methodResponses[0][1].created.bob.id')
GROUP_ID=$(echo "$ACCOUNTS" | json 'j.methodResponses[0][1].created.everyone.id')
echo "Alice: $ALICE_ID  Bob: $BOB_ID  Group: $GROUP_ID"

echo "Adding alice and bob to group..."
jmap "$RECOVERY_URL" "$ADMIN_CRED" "$XUSING" \
  "[[\"x:Account/set\",{\"update\":{\"$ALICE_ID\":{\"memberGroupIds/$GROUP_ID\":true},\"$BOB_ID\":{\"memberGroupIds/$GROUP_ID\":true}}},\"c1\"]]" > /dev/null

echo "Restarting container in normal mode..."
docker rm -f "$CONTAINER_NAME" > /dev/null
docker run -d --network host --user root \
  -v "$CONFIG_PATH":/etc/stalwart/config.json:ro \
  -v "$DATA_VOLUME":/var/lib/stalwart \
  --name "$CONTAINER_NAME" "$IMAGE" > /dev/null

echo "Waiting for JMAP API on $API_URL..."
wait_for "$API_URL/jmap/session" "alice:aliceSecret"
echo "JMAP API is up"

SESSION=$(curl -s -m 5 -u alice:aliceSecret "$API_URL/jmap/session")
ACCOUNT_ID=$(echo "$SESSION" | json 'j.primaryAccounts["urn:ietf:params:jmap:mail"]')
echo "Alice account id: $ACCOUNT_ID"

echo "Importing test emails..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

INBOX=$(jmap "$API_URL" "alice:aliceSecret" "$MAILUSING" \
  "[[\"Mailbox/get\",{\"accountId\":\"$ACCOUNT_ID\",\"ids\":null},\"c1\"]]" \
  | json 'j.methodResponses[0][1].list.find(m=>m.name==="Inbox").id')
echo "Inbox: $INBOX"

RECEIVED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
for eml in "$SCRIPT_DIR"/eml/1.eml "$SCRIPT_DIR"/eml/3.eml; do
  BLOB=$(curl -s -m 30 -u alice:aliceSecret -X POST "$API_URL/jmap/upload/$ACCOUNT_ID/" \
    -H 'Content-Type: message/rfc822' --data-binary @"$eml")
  BLOB_ID=$(echo "$BLOB" | json 'j.blobId')
  NAME=$(basename "$eml" .eml)
  echo "Importing $eml as blob $BLOB_ID..."
  jmap "$API_URL" "alice:aliceSecret" "$MAILUSING" \
    "[[\"Email/import\",{\"accountId\":\"$ACCOUNT_ID\",\"emails\":{\"$NAME\":{\"blobId\":\"$BLOB_ID\",\"mailboxIds\":{\"$INBOX\":true},\"receivedAt\":\"$RECEIVED\"}}},\"c1\"]]" \
    | json 'JSON.stringify(j.methodResponses[0][1])'
done

echo "Provisioning complete!"
