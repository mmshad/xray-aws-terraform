#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${DOMAIN}"
EMAIL="${EMAIL}"
TOKEN="${TOKEN}"

# Update DuckDNS and wait for DNS propagation
INSTANCE_IP=$(curl -s ifconfig.me)
curl -s "https://www.duckdns.org/update?domains=${DOMAIN}&token=${TOKEN}&ip=$INSTANCE_IP"

# Wait for DNS to point to instance IP
for i in {1..30}; do
  DIG_IP=$(dig +short "$DOMAIN")
  [ "$DIG_IP" = "$INSTANCE_IP" ] && break
  sleep 5
done

DIG_IP=$(dig +short "$DOMAIN")
[ "$DIG_IP" != "$INSTANCE_IP" ] && { echo "DNS propagation failed"; exit 1; }

# Install Xray
curl -Ls https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh -o /tmp/install-xray.sh
sudo bash /tmp/install-xray.sh
rm -f /tmp/install-xray.sh

# Install Certbot
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends certbot

# Obtain / renew Let's Encrypt cert
sudo certbot certonly --standalone --non-interactive --agree-tos --email "${EMAIL}" -d "${DOMAIN}" --preferred-challenges http

# Define certificate and key file paths
CERT_FILE="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
KEY_FILE="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"

# Pick a port and UUID
while PORT=$(shuf -i 20000-60000 -n 1); do ss -tulpn | grep -q ":$PORT " || break; done
UUID=$(uuidgen)

# Write Xray config file
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

# Emit vmess link
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

# Emit vmess link with color (for user visibility)
echo -e "\033[0;32m$VMESS_LINK\033[0m" | sudo tee -a /var/log/cloud-init-output.log
