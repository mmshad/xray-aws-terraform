#!/usr/bin/env bash
set -euo pipefail

# Static variables passed from Terraform
DUCKDNS_DOMAIN="${DUCKDNS_DOMAIN}"
CERTBOT_EMAIL="${CERTBOT_EMAIL}"
DUCKDNS_TOKEN="${DUCKDNS_TOKEN}"
PROTOCOL="${PROTOCOL}"
CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN}"
CLOUDFLARE_DOMAIN="${CLOUDFLARE_DOMAIN}"
CLOUDFLARE_SUBDOMAIN="${CLOUDFLARE_SUBDOMAIN}"

# Fetch instance IP
INSTANCE_IP=$(curl -s ifconfig.me)

# Function to handle Cloudflare DNS updates
update_cloudflare_dns() {
  FULL_DOMAIN="${CLOUDFLARE_SUBDOMAIN}.${CLOUDFLARE_DOMAIN}"

  # Get Zone ID
  ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$${CLOUDFLARE_DOMAIN}" \
    -H "Authorization: Bearer $${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" | jq -r '.result[0].id') || { echo "Failed to fetch Zone ID"; exit 1; }

  # Get DNS Record ID (if exists)
  RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$${ZONE_ID}/dns_records?name=$${FULL_DOMAIN}" \
    -H "Authorization: Bearer $${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" | jq -r '.result[0].id') || { echo "Failed to fetch DNS Record ID"; exit 1; }

  # Create or update the A record
  if [ "$RECORD_ID" = "null" ]; then
    echo "Creating DNS record for $FULL_DOMAIN"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$${ZONE_ID}/dns_records" \
      -H "Authorization: Bearer $${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$${FULL_DOMAIN}\",\"content\":\"$${INSTANCE_IP}\",\"ttl\":120,\"proxied\":true}" || { echo "Failed to create DNS record"; exit 1; }
  else
    echo "Updating DNS record for $FULL_DOMAIN"
    curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$${ZONE_ID}/dns_records/$${RECORD_ID}" \
      -H "Authorization: Bearer $${CLOUDFLARE_API_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$${FULL_DOMAIN}\",\"content\":\"$${INSTANCE_IP}\",\"ttl\":120,\"proxied\":true}" || { echo "Failed to update DNS record"; exit 1; }
  fi

  # Disable Cloudflare proxy for the subdomain
  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$${ZONE_ID}/dns_records/$${RECORD_ID}" \
    -H "Authorization: Bearer $${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$${FULL_DOMAIN}\",\"content\":\"$${INSTANCE_IP}\",\"ttl\":120,\"proxied\":false}" || { echo "Failed to disable Cloudflare proxy"; exit 1; }
}

# Install jq for JSON parsing
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends jq certbot

# Determine DNS provider and update DNS records
if [ -n "${DUCKDNS_TOKEN}" ]; then
  echo "Using DuckDNS for DNS updates"
  curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip=$INSTANCE_IP"

  # Wait for DNS to point to instance IP
  for i in {1..30}; do
    DIG_IP=$(dig +short "$DUCKDNS_DOMAIN")
    [ "$DIG_IP" = "$INSTANCE_IP" ] && break
    sleep 5
  done

  DIG_IP=$(dig +short "$DUCKDNS_DOMAIN")
  [ "$DIG_IP" != "$INSTANCE_IP" ] && { echo "DNS propagation failed"; exit 1; }

elif [ -n "${CLOUDFLARE_API_TOKEN}" ]; then
  echo "Using Cloudflare for DNS updates"
  update_cloudflare_dns
else
  echo "No DNS provider configured. Exiting."
  exit 1
fi

# Install Xray
curl -Ls https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh -o /tmp/install-xray.sh
sudo bash /tmp/install-xray.sh
rm -f /tmp/install-xray.sh

# Update certificate and domain variables based on DNS provider
if [ -n "${CLOUDFLARE_API_TOKEN}" ]; then
  CERT_FILE="/etc/letsencrypt/live/${CLOUDFLARE_SUBDOMAIN}.${CLOUDFLARE_DOMAIN}/fullchain.pem"
  KEY_FILE="/etc/letsencrypt/live/${CLOUDFLARE_SUBDOMAIN}.${CLOUDFLARE_DOMAIN}/privkey.pem"
  DOMAIN="${CLOUDFLARE_SUBDOMAIN}.${CLOUDFLARE_DOMAIN}"
else
  CERT_FILE="/etc/letsencrypt/live/${DUCKDNS_DOMAIN}/fullchain.pem"
  KEY_FILE="/etc/letsencrypt/live/${DUCKDNS_DOMAIN}/privkey.pem"
  DOMAIN="${DUCKDNS_DOMAIN}"
fi

# Obtain / renew Let's Encrypt cert
sudo certbot certonly --standalone --non-interactive --agree-tos --email "${CERTBOT_EMAIL}" -d "$DOMAIN" --preferred-challenges http

# Pick a port and UUID
while PORT=$(shuf -i 20000-60000 -n 1); do ss -tulpn | grep -q ":$PORT " || break; done
UUID=$(uuidgen)

# Update Xray configuration to use the selected domain
if [ "$PROTOCOL" = "vless" ]; then
  # VLESS configuration
  cat <<EOF | sudo tee /usr/local/etc/xray/config.json >/dev/null
{
  "inbounds": [{
    "port": $PORT,
    "protocol": "vless",
    "settings": {
      "clients": [{
        "id": "$UUID",
        "flow": ""
      }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "tlsSettings": {
        "certificates": [{
          "certificateFile": "$CERT_FILE",
          "keyFile": "$KEY_FILE"
        }]
      },
      "wsSettings": {
        "path": "/v2ray",
        "host": "$DOMAIN"
      }
    }
  }],
  "outbounds":[{ "protocol":"freedom" }]
}
EOF
else
  # VMESS configuration (default)
  cat <<EOF | sudo tee /usr/local/etc/xray/config.json >/dev/null
{
  "inbounds": [{
    "port": $PORT,
    "protocol": "vmess",
    "settings": {
      "clients": [{
        "id": "$UUID",
        "total": 10737418240
      }]
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "tlsSettings": {
        "certificates": [{
          "certificateFile": "$CERT_FILE",
          "keyFile": "$KEY_FILE"
        }]
      },
      "wsSettings": {
        "path": "/v2ray",
        "host": "$DOMAIN"
      }
    }
  }],
  "outbounds":[{ "protocol":"freedom" }]
}
EOF
fi

# Modify the Xray service file to run as root
sudo pkill xray
sudo systemctl stop xray
sudo sed -i 's/User=nobody/User=root/' /etc/systemd/system/xray.service

# Reload the systemd daemon and restart Xray
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart xray
sudo systemctl status xray --no-pager

sleep 5

# Generate connection link based on protocol
if [ "$PROTOCOL" = "vless" ]; then
  # Emit vless link
  VLESS_LINK="vless://$UUID@$DOMAIN:$PORT?type=ws&security=tls&path=/v2ray&host=$DOMAIN#Xray-TLS-WS"
  echo -e "\033[0;32m$VLESS_LINK\033[0m" | sudo tee -a /var/log/cloud-init-output.log
else
  # Emit vmess link (default)
  VMESS_JSON=$(printf '{
    "v":"2",
    "ps":"Xray TLS WS",
    "add":"%s",
    "port":"%s",
    "id":"%s",
    "aid":"0",
    "net":"ws",
    "type":"none",
    "host":"%s",
    "path":"/v2ray",
    "tls":"tls"
  }'  "$DOMAIN" "$PORT" "$UUID" "$DOMAIN")

  VMESS_LINK="vmess://$(echo -n "$VMESS_JSON" | base64 -w0)"
  echo -e "\033[0;32m$VMESS_LINK\033[0m" | sudo tee -a /var/log/cloud-init-output.log
fi
