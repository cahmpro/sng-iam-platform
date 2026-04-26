#!/bin/bash
# Bootstrap initial : crée les réseaux et volumes Docker nécessaires

set -e

echo "=== Bootstrap Sign&go IAM Platform ==="

# Vérifications préalables
command -v docker >/dev/null 2>&1 || { echo "❌ Docker n'est pas installé"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "❌ Docker Compose v2 requis"; exit 1; }

# Vérification du .env
if [ ! -f .env ]; then
  echo "❌ Fichier .env absent."
  echo "   Lance d'abord : ./scripts/gen-secrets.sh > .env"
  echo "   Puis édite .env pour renseigner DOMAIN, emails, tokens et licences."
  exit 1
fi

# Charger le .env
set -a
source .env
set +a

# Vérifier les variables critiques
MISSING=0
for var in DOMAIN DB_PASSWORD ADMIN_PASSWORD CF_DNS_API_TOKEN SIGNANDGO_LICENSE LETSENCRYPT_EMAIL; do
  if [ -z "${!var}" ]; then
    echo "❌ Variable $var manquante ou vide dans .env"
    MISSING=1
  fi
done
[ $MISSING -eq 1 ] && exit 1

echo "✅ Variables d'environnement OK"

# Créer les réseaux Docker
echo ""
echo "=== Réseaux Docker ==="
for net in sng.network frontend obs.network; do
  if docker network inspect $net >/dev/null 2>&1; then
    echo "  ✓ $net existe déjà"
  else
    docker network create $net >/dev/null
    echo "  ✓ $net créé"
  fi
done

# Créer le volume cipher avec les bonnes permissions
echo ""
echo "=== Volume cipher.configurationdb ==="
if docker volume inspect cipher.configurationdb >/dev/null 2>&1; then
  echo "  ✓ cipher.configurationdb existe déjà"
else
  docker volume create cipher.configurationdb >/dev/null
  docker run --rm -v cipher.configurationdb:/opt -u root debian:latest \
    /bin/bash -c "useradd -u 1001 server && chown server:server /opt" >/dev/null
  echo "  ✓ cipher.configurationdb créé avec UID 1001"
fi

# Vérifier les fichiers requis
echo ""
echo "=== Fichiers requis ==="
[ -f secrets/SngKey.key ] && echo "  ✓ secrets/SngKey.key" || echo "  ⚠ secrets/SngKey.key MANQUANT (licence Sign&go)"
[ -f idsphere/entities/entities.json ] && echo "  ✓ idsphere/entities/entities.json" || echo "  ⚠ idsphere/entities/entities.json MANQUANT (modèle IDSphere)"
[ -f idsphere/config/application.properties ] && echo "  ✓ idsphere/config/application.properties" || echo "  ⚠ idsphere/config/application.properties MANQUANT"

echo ""
echo "=== Bootstrap terminé ==="
echo ""
echo "Étapes suivantes :"
echo "  1. ./scripts/deploy.sh         # Déploie Sign&go + observabilité"
echo "  2. ./scripts/init-idsphere.sh  # Initialise IDSphere (premier déploiement uniquement)"
echo "  3. ./scripts/health-check.sh   # Vérifie l'état de la stack"
