#!/bin/bash
# Initialise la base IDSphere (one-shot, premier déploiement uniquement)

set -e

echo "=== Initialisation IDSphere ==="

if [ ! -f .env ]; then
  echo "❌ Fichier .env absent"
  exit 1
fi

set -a
source .env
set +a

# Détecter le préfixe Docker Compose
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]//g')}"
NETWORK="${PROJECT_NAME}_ids.network"
VOLUME="${PROJECT_NAME}_idsphere.jar"

echo "  Project name: $PROJECT_NAME"
echo "  Network: $NETWORK"
echo "  Volume: $VOLUME"

if [ ! -f idsphere/entities/entities.json ]; then
  echo "❌ idsphere/entities/entities.json manquant"
  exit 1
fi

# Démarrer la base
echo ""
echo "→ Démarrage idsphere.db..."
docker compose -f docker-compose.ids.yml up -d idsphere.db
echo "  Attente DB healthy (15s)..."
sleep 15

if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
  echo "❌ Réseau $NETWORK introuvable"
  exit 1
fi

# Init
echo ""
echo "→ Initialisation schéma + génération du JAR (peut prendre 2 minutes)..."
docker run --rm \
  --network "$NETWORK" \
  --mount type=bind,source="$(pwd)/idsphere/entities/entities.json",target=/application/entities/entities.json,readonly \
  --mount type=volume,source="$VOLUME",target=/application/target/entities \
  -e TECHNICAL_ADMIN_PASSWORD="${IDS_ADMIN}" \
  -e spring.datasource.driver-class-name=org.postgresql.Driver \
  -e spring.datasource.url=jdbc:postgresql://idsphere.db:5432/idsphere \
  -e spring.datasource.username=idsphere \
  -e spring.datasource.password="${IDS_DB_PASSWORD}" \
  -e ids.license="${IDS_LICENSE}" \
  afr2k7pd.gra7.container-registry.ovh.net/fr-ilex/idsphere/ids-installation-tools:5.1.0

echo ""
if docker run --rm -v "$VOLUME":/data alpine ls /data/ids-generated-entities.jar >/dev/null 2>&1; then
  echo "✅ JAR généré"
else
  echo "❌ JAR non généré"
  exit 1
fi

echo ""
echo "→ Démarrage ids-workflow et ids-web..."
docker compose -f docker-compose.ids.yml up -d ids-workflow ids-web
echo "  Attente démarrage (90s)..."
sleep 90

echo ""
echo "✅ IDSphere initialisé"
echo "   URL : https://ids.${DOMAIN}"
echo "   Login : admin"
echo "   Password : valeur de IDS_ADMIN dans .env"
