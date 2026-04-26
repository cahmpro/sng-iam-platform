#!/bin/bash
# Vérifie l'état de la stack

set -a
[ -f .env ] && source .env
set +a

echo "=== Health check Sign&go IAM Platform ==="
echo ""

check_container() {
  local name=$1
  local status=$(docker inspect --format='{{.State.Status}}' "$name" 2>/dev/null || echo "absent")
  local health=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null || echo "")

  if [ "$status" = "running" ]; then
    if [ -n "$health" ] && [ "$health" != "<no value>" ]; then
      echo "  ✓ $name ($health)"
    else
      echo "  ✓ $name (running)"
    fi
  else
    echo "  ✗ $name ($status)"
  fi
}

check_url() {
  local url=$1
  local code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
  if [[ "$code" =~ ^(200|301|302|401)$ ]]; then
    echo "  ✓ $url ($code)"
  else
    echo "  ✗ $url ($code)"
  fi
}

echo "Conteneurs Sign&go :"
for c in traefik admin user security.server configuration.db technical.db logs.db; do
  check_container "$c"
done

echo ""
echo "Conteneurs Observabilité :"
for c in loki alloy prometheus grafana cadvisor; do
  check_container "$c"
done

echo ""
echo "Conteneurs IDSphere :"
for c in idsphere.db ids-workflow ids-web; do
  check_container "$c"
done

if [ -n "$DOMAIN" ]; then
  echo ""
  echo "URLs publiques :"
  for sub in admin user traefik grafana ids; do
    check_url "https://${sub}.${DOMAIN}"
  done
fi

echo ""
echo "Certificat Let's Encrypt :"
if [ -f traefik/letsencrypt/acme.json ]; then
  size=$(stat -c%s traefik/letsencrypt/acme.json 2>/dev/null || stat -f%z traefik/letsencrypt/acme.json 2>/dev/null || echo 0)
  if [ "$size" -gt 1000 ]; then
    echo "  ✓ acme.json présent ($size octets)"
  else
    echo "  ⚠ acme.json vide ou très petit ($size octets)"
  fi
else
  echo "  ✗ acme.json absent"
fi
