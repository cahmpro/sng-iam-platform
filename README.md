# Sign&go IAM Platform

Déploiement de la plateforme IAM Sign&go 10.1.0 sur AWS EC2 avec Docker Compose, Traefik et Let's Encrypt.

## Stack technique

- Traefik v2.11 (reverse proxy + TLS)
- Let's Encrypt DNS-01 via Cloudflare (certificat wildcard)
- Sign&go 10.1.0 (admin, user, security.server)
- PostgreSQL 16 et images Sign&go custom
- Docker Compose v2

## Domaines

- admin.cah.formindemo.fr - Console admin
- user.cah.formindemo.fr - Portail utilisateur
- traefik.cah.formindemo.fr - Dashboard Traefik
- grafana.cah.formindemo.fr - Grafana (etape 1.2)

## Prerequis

- Ubuntu 22.04+ avec 4 GB RAM minimum
- Docker 24+ et Docker Compose v2
- Domaine sur Cloudflare
- Token Cloudflare avec Zone:DNS:Edit + Zone:Zone:Read
- Licence Sign&go (fichier SngKey.key)
- Acces registry OVH

## Installation

1. Cloner le projet et copier .env.example vers .env
2. Remplir toutes les variables dans .env
3. Placer la licence dans secrets/SngKey.key
4. docker login afr2k7pd.gra7.container-registry.ovh.net
5. Creer les reseaux Docker:
   docker network create sng.network
   docker network create frontend
6. Creer le volume cipher:
   docker volume create cipher.configurationdb
   docker run --rm -v cipher.configurationdb:/opt -u root debian:latest /bin/bash -c "useradd -u 1001 server && chown server:server /opt"
7. Configurer DNS Cloudflare (4 records A, proxy desactive)
8. Security Group AWS: ports 22 (SSH) et 443 (HTTPS) uniquement
9. docker compose up -d
10. Attendre 2 minutes pour l'initialisation des bases

## Securite

Le .gitignore exclut .env, secrets/, traefik/letsencrypt/, *.key, *.pem, *.p12, *.jks

TLS externe: Let's Encrypt wildcard avec rotation automatique J60-J89
TLS interne: Tomcat self-signed avec insecureSkipVerify dans Traefik

## Roadmap

- [x] Etape 1.1: Docker Compose + Traefik + Let's Encrypt
- [ ] Etape 1.2: Observabilite (Loki + Grafana Alloy + Grafana + Prometheus)
- [ ] Etape 1.3: Backups + hardening
- [ ] Etape 2: Migration Kubernetes (k3s + ArgoCD + Sealed Secrets + Cert-manager)

## Variables Sign&go critiques

| Variable | Valeur | Description |
|----------|--------|-------------|
| SECSERVER_SSL_ACTIVE | true | Active SSL sur 3102 |
| AGENT_LOCAL_NAME | AGAPI | Nom de l'agent admin |
| AGENT_LOCAL_PWD | secret | Auth agent vers security.server |
| AGENTS_DEFAULT_HOST | 172.18.0.* | ACL reseau Docker |
| USER_URL | https://user.${DOMAIN}/user | URL portail user |
| LICENSE_KEY_FILE | /docker.d/product.licenses/signandgo.license.key | Chemin licence v9.2+ |

## Troubleshooting

### Bad Gateway 502
Cause: Traefik verifie le certificat self-signed du backend
Solution: serversTransport.insecureSkipVerify: true dans traefik.yml

### Service temporarily unreachable
Cause: security.server non joignable
Solution: verifier SECSERVER_SSL_ACTIVE coherent partout

### Tables manquantes dans configuration.db
Cause: admin n'a pas pu initialiser la base
Solution: verifier toutes les variables AGENT_LOCAL_*, SIGNANDGO_LICENSE, AGENTS_DEFAULT_HOST puis detruire le volume et redemarrer

### ${SECSERVER_INET_PORT} non substitue
Cause: l'entrypoint Sign&go ne substitue cette variable que si SECSERVER_SSL_ACTIVE=false
Solution: definir explicitement SECSERVER_SSL_ACTIVE dans le compose

## Licence

Projet de cadrage IAM - usage interne Formind.
Sign&go est un produit proprietaire d'Ilex Systemes Informatiques.

## Auteur

cahm pro - cahmpro@gmail.com
