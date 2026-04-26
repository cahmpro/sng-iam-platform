#!/bin/bash
# Déploie la stack Sign&go + observabilité

set -e

echo "=== Déploiement Sign&go + Observabilité ==="

if [ ! -f .env ]; then
  echo "❌ Fichier .env absent"
  exit 1
fi

# Sign&go
echo ""
echo "→ Démarrage Sign&go..."
docker compose up -d
echo "  Attente init des bases (60s)..."
sleep 60

# Observabilité
echo ""
echo "→ Démarrage observabilité..."
docker compose -f docker-compose.obs.yml up -d
sleep 20

echo ""
echo "✅ Stack démarrée"
echo "   Vérifie l'état avec : ./scripts/health-check.sh"
