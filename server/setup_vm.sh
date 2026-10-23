#!/bin/sh
# One-shot setup for a fresh Ubuntu VM (made for Oracle Cloud's Always Free
# ARM machine, works on any Ubuntu box): installs Docker, opens 80/443 in the
# VM's own firewall, writes .env with fresh keys and starts the stack.
#
#   sh setup_vm.sh yourname.duckdns.org
#
# Prints the SERVER_KEY to put in src/net/net_config.gd.
set -eu
DOMAIN="${1:?usage: sh setup_vm.sh your.domain}"
cd "$(dirname "$0")"

if ! command -v docker >/dev/null; then
	curl -fsSL https://get.docker.com | sudo sh
fi

# Oracle's Ubuntu images block everything but SSH in iptables, on top of the
# cloud firewall (the VCN security list), so both need 80 and 443.
if sudo iptables -C INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null; then :; else
	sudo iptables -I INPUT 6 -p tcp --dport 80 -j ACCEPT
	sudo iptables -I INPUT 6 -p tcp --dport 443 -j ACCEPT
	sudo apt-get install -y iptables-persistent >/dev/null 2>&1 || true
	sudo netfilter-persistent save || true
fi

if [ ! -f .env ]; then
	key() { openssl rand -hex 24; }
	cat > .env <<ENV
DOMAIN=$DOMAIN
DB_PASSWORD=$(key)
SERVER_KEY=$(key)
HTTP_KEY=$(key)
SESSION_KEY=$(key)
REFRESH_KEY=$(key)
CONSOLE_SIGNING_KEY=$(key)
CONSOLE_PASSWORD=$(key)
ENV
	chmod 600 .env
fi

sudo docker compose up -d
echo
echo "Server starting at https://$DOMAIN"
grep '^SERVER_KEY=' .env
