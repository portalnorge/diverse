#!/bin/bash
set -e

echo "[1/6] Installerer avhengigheter..."
apt update -y
apt install -y git make docker.io

echo "[2/6] Installerer Docker Compose V2..."
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.27.1/docker-compose-linux-$(uname -m) -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

echo "[3/6] Starter Docker-tjenesten..."
systemctl enable --now docker

echo "[4/6] Kloner ShellHub kildekode..."
cd /opt
git clone -b v0.18.0 https://github.com/shellhub-io/shellhub.git
cd shellhub

echo "[5/6] Genererer SSH-nøkler..."
make keygen

echo "[6/6] Starter ShellHub (kan ta 5-10 minutter første gang)..."
make start

echo ""
echo "✅ ShellHub-tjenestene kjører!"
echo ""
echo "👉 Nå MÅ du kjøre: ./bin/setup for å opprette admin-bruker."
echo "    cd /opt/shellhub"
echo "    ./bin/setup"
echo ""
