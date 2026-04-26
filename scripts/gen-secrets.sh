#!/bin/bash
# Génère un .env avec des secrets aléatoires
# Usage : ./scripts/gen-secrets.sh > .env
# Puis éditer .env pour renseigner DOMAIN, emails, tokens et licences

set -e

# Vérifier les outils
command -v openssl >/dev/null 2>&1 || { echo "❌ openssl requis" >&2; exit 1; }

# Générer le hash htpasswd pour Traefik
if command -v htpasswd >/dev/null 2>&1; then
  TRAEFIK_PWD=$(openssl rand -base64 16)
  TRAEFIK_HASH=$(htpasswd -nbB admin "$TRAEFIK_PWD" | sed 's/\$/\$\$/g')
  TRAEFIK_NOTE="# Traefik dashboard : login=admin password=$TRAEFIK_PWD (à conserver !)"
else
  TRAEFIK_HASH='admin:$$2y$$05$$REPLACE_WITH_REAL_HASH'
  TRAEFIK_NOTE="# ⚠ htpasswd absent (apt install apache2-utils), à générer avec :"$'\n'"#   htpasswd -nbB admin <password> | sed 's/\$/\$\$/g'"
fi

cat << ENV
# ============================================================================
# .env généré le $(date)
# ============================================================================

# --- Docker Compose project name (recommandé pour la portabilité) ---
COMPOSE_PROJECT_NAME=signandgo-iam

# --- Domaine (À REMPLIR) ---
# Tous les sous-domaines doivent exister dans le DNS :
#   admin.<DOMAIN>, user.<DOMAIN>, traefik.<DOMAIN>, grafana.<DOMAIN>, ids.<DOMAIN>
DOMAIN=
LETSENCRYPT_EMAIL=

# --- Cloudflare API token (À REMPLIR) ---
# Permissions requises : Zone:DNS:Edit + Zone:Zone:Read
# Créer sur : https://dash.cloudflare.com/profile/api-tokens
CF_DNS_API_TOKEN=

# --- Licences (À REMPLIR) ---
SIGNANDGO_LICENSE=
IDS_LICENSE=

# --- PostgreSQL Sign&go (3 bases : configuration, technical, logs) ---
DB_PASSWORD=$(openssl rand -base64 24)

# --- Sign&go ---
ADMIN_PASSWORD=$(openssl rand -base64 24)
AGENT_LOCAL_PWD=$(openssl rand -base64 24)

# --- Traefik dashboard ---
$TRAEFIK_NOTE
TRAEFIK_DASHBOARD_AUTH=$TRAEFIK_HASH

# --- Grafana ---
GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 16)

# --- IDSphere ---
IDS_DB_PASSWORD=$(openssl rand -base64 24)
IDS_ADMIN=$(openssl rand -base64 24)
IDS_WORKFLOW_JWT_PASSPHRASE=$(openssl rand -base64 32)
IDS_CONTEXT_PATH=/
ENV
