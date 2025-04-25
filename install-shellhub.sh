#!/bin/bash

set -e

DOMAIN="ssh.portalnorge.no"
EMAIL="you@example.com" # <- Endre om du vil ha Let's Encrypt-varsel

echo "[1/7] Oppretter mapper og laster ned ShellHub binaries..."
mkdir -p /opt/shellhub && cd /opt/shellhub
curl -LO https://github.com/shellhub-io/shellhub/releases/latest/download/shellhub-backend
curl -LO https://github.com/shellhub-io/shellhub/releases/latest/download/shellhub-frontend
chmod +x shellhub-*

echo "[2/7] Lager systemd-tjenester..."

cat > /etc/systemd/system/shellhub-backend.service <<EOF
[Unit]
Description=ShellHub Backend
After=network.target

[Service]
ExecStart=/opt/shellhub/shellhub-backend serve --enterprise false
Restart=always
User=www-data
Group=www-data

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/shellhub-frontend.service <<EOF
[Unit]
Description=ShellHub Frontend
After=shellhub-backend.service

[Service]
ExecStart=/opt/shellhub/shellhub-frontend
Restart=always
User=www-data
Group=www-data

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now shellhub-backend shellhub-frontend

echo "[3/7] Installerer nødvendige Apache-moduler..."
apt update -y
apt install -y apache2 certbot python3-certbot-apache
a2enmod proxy proxy_http proxy_wstunnel ssl rewrite headers

echo "[4/7] Lager Apache-virtualhost for $DOMAIN..."

cat > /etc/apache2/sites-available/$DOMAIN.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN

    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^/?(.*) https://%{SERVER_NAME}/\$1 [R,L]
</VirtualHost>

<VirtualHost *:443>
    ServerName $DOMAIN

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/$DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$DOMAIN/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf

    ProxyPreserveHost On
    ProxyPass / http://localhost:8080/
    ProxyPassReverse / http://localhost:8080/

    RequestHeader set X-Forwarded-Proto "https"
</VirtualHost>
EOF

echo "[5/7] Aktiverer siden..."
a2ensite $DOMAIN.conf

echo "[6/7] Skaffer Let's Encrypt-sertifikat..."
certbot --apache -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

echo "[7/7] Starter Apache på nytt..."
systemctl reload apache2

echo "✅ Ferdig! Gå til: https://$DOMAIN for å bruke ShellHub 🎉"
