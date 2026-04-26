# Sign&go IAM Platform

Plateforme IAM complete Sign&go + IDSphere deployee avec Docker Compose, Traefik et Let's Encrypt.

## Stack technique

- Traefik 2.11 - reverse proxy + TLS Let's Encrypt DNS-01
- Sign&go 10.1.0 - IAM (admin, user, security.server)
- IDSphere 5.1.0 - gestionnaire d'identites (web, workflow)
- PostgreSQL 16 et 17 - 4 bases de donnees dediees
- Loki 3.4.2 + Grafana Alloy 1.8.3 - logs
- Prometheus 3.3.1 + cAdvisor 0.51.0 - metriques
- Grafana 11.6.1 - dashboards

## Sous-domaines exposes

| Sous-domaine | Service | Description |
|--------------|---------|-------------|
| admin.DOMAIN | sng admin | Console d'administration Sign&go |
| user.DOMAIN | sng user | Portail utilisateur Sign&go |
| traefik.DOMAIN | traefik | Dashboard Traefik (basic auth) |
| grafana.DOMAIN | grafana | Observabilite (logs et metriques) |
| ids.DOMAIN | ids-web | Interface IDSphere |

## Prerequis

### Infrastructure
- VM Linux Ubuntu 22.04+ avec 4 GB RAM minimum (8 GB recommande)
- Docker 24+ et Docker Compose v2
- Domaine gere sur Cloudflare
- Token API Cloudflare avec Zone:DNS:Edit + Zone:Zone:Read

### Securite reseau
- Port 22 (SSH) ouvert depuis votre IP
- Port 443 (HTTPS) ouvert depuis 0.0.0.0/0
- Port 80 ferme (le defi DNS-01 ne necessite pas le port 80)

### Licences et fichiers
- Licence Sign&go : fichier SngKey.key (fourni par Ilex)
- Licence IDSphere : chaine de caracteres (fournie par Ilex)
- Modele IDSphere : fichier entities.json definissant les entites metier
- Acces registry OVH : afr2k7pd.gra7.container-registry.ovh.net

## Installation rapide

### 1. Cloner le projet

    git clone https://github.com/cahmpro/sng-iam-platform.git signandgo-iam
    cd signandgo-iam

Important : le nom du dossier devient le prefixe Docker Compose. On utilise signandgo-iam pour la coherence avec COMPOSE_PROJECT_NAME du .env.

### 2. Generer les secrets

    ./scripts/gen-secrets.sh > .env

Ce script genere un .env avec des mots de passe aleatoires. Notez precieusement le mot de passe Traefik affiche en commentaire.

### 3. Completer le .env manuellement

    nano .env

Renseigner :
- DOMAIN (exemple cah.formindemo.fr)
- LETSENCRYPT_EMAIL
- CF_DNS_API_TOKEN
- SIGNANDGO_LICENSE (chaine fournie par Ilex)
- IDS_LICENSE (chaine fournie par Ilex)

### 4. Placer les fichiers requis

    mkdir -p secrets idsphere/entities
    cp /chemin/vers/SngKey.key secrets/
    chmod 600 secrets/SngKey.key
    cp /chemin/vers/entities.json idsphere/entities/

### 5. Configurer le DNS Cloudflare

Creer 5 enregistrements A (DNS only, proxy desactive) pointant vers l'IP de la VM :

    admin.<DOMAIN>     A   <IP_VM>
    user.<DOMAIN>      A   <IP_VM>
    traefik.<DOMAIN>   A   <IP_VM>
    grafana.<DOMAIN>   A   <IP_VM>
    ids.<DOMAIN>       A   <IP_VM>

### 6. Login au registry OVH

    docker login afr2k7pd.gra7.container-registry.ovh.net

### 7. Bootstrap

    ./scripts/bootstrap.sh

Ce script verifie le .env, cree les reseaux Docker (sng.network, frontend, obs.network) et le volume cipher.configurationdb avec UID 1001.

### 8. Deployer Sign&go et observabilite

    ./scripts/deploy.sh

Patientez 2 minutes pour l'initialisation des bases Sign&go et l'obtention du certificat Let's Encrypt.

### 9. Initialiser et deployer IDSphere

    ./scripts/init-idsphere.sh

Ce script demarre la base PostgreSQL IDSphere, lance ids-installation-tools pour creer le schema et generer le JAR custom, puis demarre ids-workflow et ids-web.

### 10. Verification

    ./scripts/health-check.sh

Tester l'acces aux URLs publiques.

## Scripts disponibles

| Script | Description |
|--------|-------------|
| gen-secrets.sh | Genere un .env avec des secrets aleatoires |
| bootstrap.sh | Cree reseaux, volumes, verifie prerequis |
| deploy.sh | Deploie Sign&go + observabilite |
| init-idsphere.sh | Initialise et deploie IDSphere |
| health-check.sh | Verifie l'etat de tous les services |

## Points d'attention - Sign&go

Variables critiques decouvertes lors du deploiement, non triviales :

- SECSERVER_SSL_ACTIVE = true active SSL sur 3102/3103. Si false, ecoute uniquement sur 3100
- AGENT_LOCAL_NAME = AGAPI (nom de l'agent admin)
- AGENT_LOCAL_PWD = secret pour l'authentification agent vers security.server
- AGENTS_DEFAULT_HOST = ACL reseau Docker (par defaut 172.18.0.* pour le subnet sng.network)
- USER_URL doit etre defini sinon cascade d'erreurs Spring sur appAuthenticationEntryPoint
- LICENSE_KEY_FILE pour les versions 9.2+

Ces variables sont lues uniquement a l'initialisation de la base configuration.db. Pour les modifier apres coup, il faut detruire le volume.

## Points d'attention - IDSphere

L'image IDSphere 5.1.0 utilise un format proprietaire dollar-IDS_DB_*-dollar dans application.properties. Le post-processeur AddDatabaseConfigurationToEnvironment lit directement le fichier sans utiliser le mapping Spring standard.

Solution : passer les variables sous le format spring.datasource.* directement dans le compose, en syntaxe liste (- key=value), pas en syntaxe map (key: value). La syntaxe map ne preserve pas correctement les noms avec des points dans les variables d'env Docker.

Les mots de passe doivent etre prefixes avec accolade-noop-accolade pour indiquer qu'ils sont en clair :

    - ids.web.security.users[0].password={noop}${IDS_ADMIN}

## Securite

### Secrets exclus du repo

Le .gitignore exclut :
- .env (mots de passe, tokens)
- secrets/ (licence Sign&go)
- traefik/letsencrypt/ (certificats)
- *.key, *.pem, *.p12, *.jks

### TLS

- Externe : Let's Encrypt wildcard *.DOMAIN (renouvellement auto J60-J89)
- Interne : Tomcat self-signed avec insecureSkipVerify dans Traefik (acceptable pour reseau Docker prive)

## Troubleshooting

### Bad Gateway 502 sur admin/user

Cause : Traefik tente de verifier le certificat self-signed du backend.
Solution : serversTransport.insecureSkipVerify: true dans traefik/traefik.yml.

### Service temporarily unreachable

Cause : security.server non joignable depuis admin/user.
Solution : verifier SECSERVER_SSL_ACTIVE coherent partout, et que les ports 3102/3103 sont ouverts.

Tester depuis user :

    docker exec user bash -c "echo > /dev/tcp/security.server/3102 && echo OK"

### Tables manquantes dans configuration.db

Cause : admin n'a pas pu initialiser la base au premier demarrage.
Solution : verifier que toutes les variables AGENT_LOCAL_*, SIGNANDGO_LICENSE, AGENTS_DEFAULT_HOST sont definies, puis detruire le volume et redemarrer :

    docker compose down
    docker volume rm signandgo-iam_configuration.dbdata
    docker compose up -d

### Variable dollar-SECSERVER_INET_PORT-dollar non substituee dans les logs

Cause : l'entrypoint Sign&go ne substitue cette variable dans client.xml que si SECSERVER_SSL_ACTIVE=false.
Solution : definir explicitement SECSERVER_SSL_ACTIVE dans le compose.

### IDSphere : Could not load JDBC driver class dollar-IDS_DB_DRIVER-dollar

Cause : utilisation de la syntaxe map pour les environment variables (key: value).
Solution : utiliser la syntaxe liste (- spring.datasource.driver-class-name=org.postgresql.Driver). Voir la section Points d'attention - IDSphere.

### IDSphere : password must have a password encoding prefix

Cause : Spring Security exige un prefixe sur le mot de passe.
Solution : prefixer la valeur avec accolade-noop-accolade dans le compose :

    - ids.web.security.users[0].password={noop}${IDS_ADMIN}

### Loki : pas de logs dans Grafana

Cause : datasource Loki non selectionnee, ou fenetre de temps trop courte.
Solution : dans Grafana, aller dans Explore, selectionner Loki en datasource, choisir Last 1 hour, puis filtrer par container.

## Roadmap

- v1.1.0 - Sign&go (Docker Compose + Traefik + Let's Encrypt) - termine
- v1.2.0 - Observabilite (Loki + Alloy + Prometheus + Grafana) - termine
- v1.3.0 - IDSphere (web + workflow + DB dediee) - termine
- A venir - Integration Sign&go vers IDSphere via sng-client.xml
- A venir - Backups automatises (pg_dump vers stockage S3)
- A venir - Migration Kubernetes (k3s + ArgoCD + Sealed Secrets)

## Architecture des fichiers

    sng-iam-platform/
    |-- docker-compose.yml          - Stack Sign&go
    |-- docker-compose.obs.yml      - Stack observabilite
    |-- docker-compose.ids.yml      - Stack IDSphere
    |-- .env.example                - Template de configuration
    |-- .gitignore                  - Exclusion des secrets
    |-- traefik/
    |   |-- traefik.yml             - Config statique Traefik
    |   |-- dynamic/                - Middlewares et configs dynamiques
    |   `-- letsencrypt/            - acme.json (gitignored)
    |-- observability/
    |   |-- loki/loki.yml
    |   |-- alloy/config.alloy
    |   |-- prometheus/prometheus.yml
    |   `-- grafana/provisioning/   - Datasources et dashboards
    |-- idsphere/
    |   |-- config/                 - application.properties, sng-client.xml
    |   `-- entities/               - entities.json (modele de donnees)
    |-- secrets/                    - SngKey.key (gitignored)
    `-- scripts/                    - Scripts de deploiement

## Licence

Projet de cadrage IAM. Sign&go et IDSphere sont des produits proprietaires d'Ilex Systemes Informatiques.

## Auteur

cahm pro - cahmpro@gmail.com
