#!/bin/sh
# Publishes an MSIX to the Microsoft Store through Partner Center's submission API.
#
# Usage:
#   Windows/tools/publish-store.sh <package.msix|msixbundle> [--notes "What's new"]
#   Windows/tools/publish-store.sh --check          report the app's current submission state
#
# Credentials live in ~/.local/share/keystore/store-partner-center.json (mode 600, never
# committed), the same place the Play service account does:
#
#   { "tenantId": "...", "clientId": "...", "clientSecret": "...", "sellerId": "...",
#     "productId": "..." }
#
# tenantId/clientId come from Partner Center → Account settings → Users → Microsoft Entra ID
# applications (the app needs the Manager role, and must be added *there*, not only in Azure —
# a token from an app that Partner Center doesn't know authenticates fine and then 403s on every
# call). clientSecret is minted in Azure → Entra ID → App registrations → your app →
# Certificates & secrets. sellerId is the seller account id shown in Partner Center; productId
# is the app's Store product id.
#
# The access token is fetched fresh on every run (they last an hour), is passed to curl through
# a variable, and is never echoed — same rule as every other credential in this repo.
#
# Requires: curl, python3.

set -eu

KEYSTORE="${KEYSTORE_DIR:-$HOME/.local/share/keystore}/store-partner-center.json"
API="https://api.store.microsoft.com/submission/v1"

fail() { echo "publish-store: $1" >&2; exit 1; }

[ -f "$KEYSTORE" ] || fail "no credentials at $KEYSTORE (see the header of this script)"

read_field() {
  python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['$1'])" "$KEYSTORE" 2>/dev/null \
    || fail "credentials file is missing '$1'"
}

TENANT_ID=$(read_field tenantId)
CLIENT_ID=$(read_field clientId)
SELLER_ID=$(read_field sellerId)
PRODUCT_ID=$(read_field productId)

# Client-credentials against Entra ID. The scope is the Store API's, not the retired Dev Center
# resource (https://manage.devcenter.microsoft.com) that older tooling still sends.
access_token() {
  python3 - "$KEYSTORE" "$TENANT_ID" <<'PY'
import json, sys, urllib.parse, urllib.request

credentials = json.load(open(sys.argv[1]))
body = urllib.parse.urlencode({
    "grant_type": "client_credentials",
    "client_id": credentials["clientId"],
    "client_secret": credentials["clientSecret"],
    "scope": "https://api.store.microsoft.com/.default",
}).encode()

request = urllib.request.Request(
    f"https://login.microsoftonline.com/{sys.argv[2]}/oauth2/v2.0/token", data=body)
with urllib.request.urlopen(request) as response:
    print(json.load(response)["access_token"], end="")
PY
}

TOKEN=$(access_token) || fail "could not get an access token — check tenant/client/secret"
[ -n "$TOKEN" ] || fail "the token endpoint returned nothing"

api() { # api <method> <path> [body-file]
  if [ $# -ge 3 ]; then
    curl -sS -X "$1" "$API$2" \
      -H "Authorization: Bearer $TOKEN" \
      -H "X-Seller-Account-Id: $SELLER_ID" \
      -H "Content-Type: application/json" \
      --data-binary "@$3"
  else
    curl -sS -X "$1" "$API$2" \
      -H "Authorization: Bearer $TOKEN" \
      -H "X-Seller-Account-Id: $SELLER_ID"
  fi
}

if [ "${1:-}" = "--check" ]; then
  api GET "/product/$PRODUCT_ID/submission/status" | python3 -m json.tool
  exit 0
fi

PACKAGE="${1:-}"
[ -n "$PACKAGE" ] || fail "usage: publish-store.sh <package.msix|msixbundle> [--notes \"…\"]"
[ -f "$PACKAGE" ] || fail "no such package: $PACKAGE"

NOTES=""
if [ "${2:-}" = "--notes" ]; then
  NOTES="${3:-}"
fi

echo "publish-store: creating a submission for $PRODUCT_ID"
CREATED=$(api POST "/product/$PRODUCT_ID/submission")
SUBMISSION_ID=$(printf '%s' "$CREATED" | python3 -c "
import json, sys
payload = json.load(sys.stdin)
id = (payload.get('submissionId') or payload.get('id')
      or payload.get('responseData', {}).get('submissionId'))
if not id:
    sys.exit('publish-store: unexpected response: ' + json.dumps(payload)[:400])
print(id, end='')
")

# Partner Center hands back a short-lived, pre-authorised blob URL: the package goes there, not
# through the API host.
echo "publish-store: requesting an upload URL"
UPLOAD_URL=$(api GET "/product/$PRODUCT_ID/submission/$SUBMISSION_ID/packageupload" | python3 -c "
import json, sys
payload = json.load(sys.stdin)
url = payload.get('uploadUrl') or payload.get('responseData', {}).get('uploadUrl')
if not url:
    sys.exit('publish-store: no uploadUrl in the response: ' + json.dumps(payload)[:400])
print(url, end='')
")

echo "publish-store: uploading $(basename "$PACKAGE") ($(du -h "$PACKAGE" | cut -f1))"
curl -sS -X PUT "$UPLOAD_URL" \
  -H "x-ms-blob-type: BlockBlob" \
  --data-binary "@$PACKAGE" >/dev/null

if [ -n "$NOTES" ]; then
  echo "publish-store: setting the release notes"
  NOTES_FILE=$(mktemp)
  python3 -c "
import json, sys
json.dump({'releaseNotes': sys.argv[1]}, open(sys.argv[2], 'w'))
" "$NOTES" "$NOTES_FILE"
  api PUT "/product/$PRODUCT_ID/submission/$SUBMISSION_ID/metadata" "$NOTES_FILE" >/dev/null
  rm -f "$NOTES_FILE"
fi

echo "publish-store: committing the submission"
api POST "/product/$PRODUCT_ID/submission/$SUBMISSION_ID/commit" | python3 -m json.tool

cat <<'EOF'

Submitted. Certification takes a few hours to a few days; watch it with:

    Windows/tools/publish-store.sh --check

EOF
