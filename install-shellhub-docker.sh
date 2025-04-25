#!/bin/bash
set -e

DOMAIN="ssh.portalnorge.no"
EMAIL="terje@portalnorge.no" # Endre gjerne til din e-post

echo "[1/6] Installerer Docker og Compose..."
apt update -y
apt install -y docker.io docker-compose apache2 certbot python3-certbot-apache
systemctl enable --now docker

echo "[2/6] Laster ned og starter ShellHub med Docker Compose..."
mkdir -p /opt/shellhub && cd /opt/shellhub

cat > docker-compose.yml <<EOF
version: '3.8'

services:
  mongo:
    image: mongo:4.4
    restart: always

  redis:
    image: redis:6.2
    restart: always

  shellhub-frontend:
    image: shellhubio/frontend:latest
    restart: always
    ports:
      - "127.0.0.1:8080:80"

  shellhub-backend:
    image: shellhubio/backend:latest
    restart: always
    environment:
      SHELLHUB_ENTERPRISE: "false"
      SHELLHUB_HOST: "https://${DOMAIN}"
    depends_on:
      - mongo
      - redis
EOF

docker compose up -d

echo "[3/6] Setter opp Apache-konfig..."
a2enmod proxy proxy_http proxy_wstunnel ssl rewrite headers

cat > /etc/apache2/sites-available/${DOMAIN}.conf <<EOF
<VirtualHost *:80>
    ServerName ${DOMAIN}

    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^/?(.*) https://%{SERVER_NAME}/\$1 [R,L]
</VirtualHost>

<VirtualHost *:443>
    ServerName ${DOMAIN}

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/${DOMAIN}/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/${DOMAIN}/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf

    ProxyPreserveHost On
    ProxyPass / http://localhost:8080/
    ProxyPassReverse / http://localhost:8080/

    RequestHeader set X-Forwarded-Proto "https"
</VirtualHost>
EOF

echo "[4/6] Aktiverer Apache-konfig..."
a2ensite ${DOMAIN}.conf
systemctl reload apache2

echo "[5/6] Henter Let's Encrypt-sertifikat..."
certbot --apache --non-interactive --agree-tos -m $EMAIL -d $DOMAIN

echo "[6/6] Omstarter Apache..."
systemctl reload apache2

echo "✅ Ferdig! Åpne: https://${DOMAIN} i nettleseren din."
