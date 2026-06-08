#!/usr/bin/env bash
set -euo pipefail

# ---------- 1. Default Variables & Setup ----------
GUAC_URL="http://localhost:8081/guacamole"
ADMIN_USER="guacadmin"
ADMIN_PASS="guacadmin"
GROUP_NAME="rdp-users"
RDP_PORT="3389"

# Variables to be populated dynamically
NEW_USER=""
NEW_PASS=""
RDP_HOST=""
RDP_USER=""
RDP_PASS=""
CONFIG_FILE=""

usage() {
    echo "Usage: $0 [-u NEW_USER] [-p NEW_PASS] [-t RDP_HOST] [-U RDP_USER] [-P RDP_PASS] [-f config.txt]"
    echo "  -u : Specify new Guacamole username"
    echo "  -p : Specify new Guacamole password"
    echo "  -t : Specify target RDP Host (IP or FQDN)"
    echo "  -R : Specify target RDP Port (default is 3389)"
    echo "  -U : Specify target RDP Username"
    echo "  -P : Specify target RDP Password"
    echo "  -f : Path to a configuration text file"
    exit 1
}

# ---------- 2. Parse CLI Arguments ----------
while getopts "u:p:t:U:P:R:f:h" opt; do
    case "${opt}" in
        u) NEW_USER="${OPTARG}" ;;
        p) NEW_PASS="${OPTARG}" ;;
        t) RDP_HOST="${OPTARG}" ;;
        U) RDP_USER="${OPTARG}" ;;
        P) RDP_PASS="${OPTARG}" ;;
        R) RDP_PORT="${OPTARG}" ;;
        f) CONFIG_FILE="${OPTARG}" ;;
        h|\?) usage ;;
    esac
done

# ---------- 3. Parse Config File (If Provided) ----------
if [ -n "$CONFIG_FILE" ]; then
    if [ -f "$CONFIG_FILE" ]; then
        while IFS='=' read -r key value; do
            # Clean up potential Windows line endings and trim spaces
            key=$(echo "$key" | tr -d '\r' | xargs)
            value=$(echo "$value" | tr -d '\r' | xargs)

            # Skip comments and empty lines
            [[ "$key" =~ ^#.*$ ]] || [ -z "$key" ] && continue

            # Only populate if not already set by a CLI flag
            case "$key" in
                GUAC_URL)    GUAC_URL="$value" ;;
                ADMIN_USER)  ADMIN_USER="$value" ;;
                ADMIN_PASS)  ADMIN_PASS="$value" ;;
                NEW_USER)    [ -z "$NEW_USER" ] && NEW_USER="$value" ;;
                NEW_PASS)    [ -z "$NEW_PASS" ] && NEW_PASS="$value" ;;
                RDP_HOST)    [ -z "$RDP_HOST" ] && RDP_HOST="$value" ;;
                RDP_USER)    [ -z "$RDP_USER" ] && RDP_USER="$value" ;;
                RDP_PASS)    [ -z "$RDP_PASS" ] && RDP_PASS="$value" ;;
                RDP_PORT)    RDP_PORT="$value" ;;
                GROUP_NAME)  GROUP_NAME="$value" ;;
            esac
        done < "$CONFIG_FILE"
    else
        echo "Error: Config file '$CONFIG_FILE' not found." >&2
        exit 1
    fi
fi

# ---------- 4. Validation ----------
if [ -z "$NEW_USER" ] || [ -z "$NEW_PASS" ] || [ -z "$RDP_HOST" ] || [ -z "$RDP_USER" ] || [ -z "$RDP_PASS" ]; then
    echo "Error: Missing required configuration."
    echo "NEW_USER, NEW_PASS, RDP_HOST, RDP_USER, and RDP_PASS must be provided."
    usage
fi

# Dynamic variable based on parsed NEW_USER
CONN_NAME="RDP Session - $NEW_USER"

echo "----------------------------------------"
echo "Provisioning Guacamole User: $NEW_USER"
echo "Target RDP Host            : $RDP_HOST"
echo "----------------------------------------"

# ---------- 5. Authenticate ----------
AUTH_RESPONSE=$(curl -sk -X POST "$GUAC_URL/api/tokens" \
  -d "username=$ADMIN_USER&password=$ADMIN_PASS")
TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.authToken')
DATASOURCE=$(echo "$AUTH_RESPONSE" | jq -r '.dataSource')
echo "[OK] Authenticated  token=$TOKEN  dataSource=$DATASOURCE"

# ---------- 6. Create user group ----------
curl -sk -X POST "$GUAC_URL/api/session/data/$DATASOURCE/userGroups" \
  -H "Content-Type: application/json" \
  -H "Guacamole-Token: $TOKEN" \
  -d '{"identifier":"'"$GROUP_NAME"'","attributes":{}}' > /dev/null || true
echo "[OK] Group '$GROUP_NAME' created or already exists"

# ---------- 7. Create user ----------
curl -sk -X POST "$GUAC_URL/api/session/data/$DATASOURCE/users" \
  -H "Content-Type: application/json" \
  -H "Guacamole-Token: $TOKEN" \
  -d '{
    "username":"'"$NEW_USER"'",
    "password":"'"$NEW_PASS"'",
    "attributes":{
      "disabled":"","expired":"",
      "guac-totp-key-confirmed": "false",
      "access-window-start":"","access-window-end":"",
      "valid-from":"","valid-until":"","timezone":null
    }
  }' > /dev/null
echo "[OK] User '$NEW_USER' created"

# ---------- 8. Add user to group ----------
curl -sk -X PATCH \
  "$GUAC_URL/api/session/data/$DATASOURCE/userGroups/$GROUP_NAME/memberUsers" \
  -H "Content-Type: application/json" \
  -H "Guacamole-Token: $TOKEN" \
  -d '[{"op":"add","path":"/","value":"'"$NEW_USER"'"}]' > /dev/null
echo "[OK] User '$NEW_USER' added to group '$GROUP_NAME'"

# ---------- 9. Create RDP connection ----------
CONN_RESPONSE=$(curl -sk -X POST \
  "$GUAC_URL/api/session/data/$DATASOURCE/connections" \
  -H "Content-Type: application/json" \
  -H "Guacamole-Token: $TOKEN" \
  -d '{
    "name":"'"$CONN_NAME"'",
    "parentIdentifier":"ROOT",
    "protocol":"rdp",
    "parameters":{
      "hostname":"'"$RDP_HOST"'",
      "port":"'"$RDP_PORT"'",
      "username":"'"$RDP_USER"'",
      "password":"'"$RDP_PASS"'",
      "color-depth":"16",
      "security":"nla",
      "ignore-cert":"true",
      "resize-method":"display-update",
      "disable-wallpaper":"true",
      "disable-theming":"true",
      "enable-font-smoothing":"true",
      "enable-full-window-drag":"false",
      "enable-desktop-composition":"false",
      "enable-menu-animations":"false"
    },
    "attributes":{
      "guacd-encryption":null,
      "max-connections":null,
      "max-connections-per-user":null,
      "weight":null,
      "failover-only":null
    }
  }')
CONN_ID=$(echo "$CONN_RESPONSE" | jq -r '.identifier')
echo "[OK] Connection '$CONN_NAME' created  id=$CONN_ID"

# ---------- 10. Grant permissions directly to the user ----------
echo "Assigning connection $CONN_ID to user $NEW_USER ..."
curl -s -X PATCH \
  "$GUAC_URL/api/session/data/$DATASOURCE/users/$NEW_USER/permissions" \
  -H "Content-Type: application/json" \
  -H "Guacamole-Token: $TOKEN" \
  -w "\nHTTP Status: %{http_code}\n" \
  -d '[
        {
          "op": "add",
          "path": "/connectionPermissions/'"$CONN_ID"'",
          "value": "READ"
        },
        {
          "op": "add",
          "path": "/connectionGroupPermissions/ROOT",
          "value": "READ"
        }
      ]' > /dev/null
echo "[OK] Permissions assigned successfully."