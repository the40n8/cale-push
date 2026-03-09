# Docker

Guide complet pour faire tourner cale-push dans un conteneur Docker.
Idéal pour les NAS (Synology, QNAP, Unraid, etc.) où l'installation de paquets natifs est limitée.

## Prérequis

- Docker (ou Podman)
- Docker Compose (optionnel, recommandé)
- Radarr et/ou Sonarr accessibles depuis le conteneur (réseau local ou `host.docker.internal`)
- Un client torrent supporté (Transmission ou qBittorrent)

## Démarrage rapide

### 1. Cloner le repo

```bash
git clone https://github.com/the40n8/cale-push.git
cd cale-push
```

### 2. Créer la configuration

```bash
mkdir -p config
cp config.example config/config
nano config/config
```

Remplissez vos valeurs. Points importants pour Docker :

```bash
# URLs Radarr/Sonarr : utilisez l'IP LAN du NAS, pas 127.0.0.1
RADARR_URL="http://192.168.1.100:7878/radarr"
SONARR_URL="http://192.168.1.100:8989/sonarr"

# Path mapping : traduit les chemins Radarr/Sonarr vers les chemins Docker
# Le côté gauche = chemin vu par Radarr
# Le côté droit  = chemin dans le conteneur (là où le volume est monté)
PATH_MAP="/movies:/media/movies,/tv:/media/tv"

# Les fichiers de données sont stockés dans /config (monté en volume)
HISTORY_FILE="/config/uploaded.txt"
CACHE_FILE="/config/cache.tsv"
```

### 3. Construire l'image

```bash
docker build -t cale-push .
```

### 4. Tester

```bash
docker run --rm \
    -v "$(pwd)/config:/config" \
    -v "/chemin/vers/films:/media/movies:ro" \
    -v "/chemin/vers/series:/media/tv:ro" \
    cale-push check
```

## Utilisation

### Commandes one-shot

```bash
# Raccourci — remplacez /chemin/vers par vos vrais chemins
alias cale='docker run --rm -v "$(pwd)/config:/config" -v "/chemin/vers/films:/media/movies:ro" -v "/chemin/vers/series:/media/tv:ro" -v "/chemin/vers/torrents:/torrents" cale-push'

# Scanner les candidats
cale scan movies
cale scan series
cale scan all

# Pousser du contenu
cale push movies
cale push movies --max 3
cale push all --dry-run
cale push movies --min-quality 1080p

# Vérifier la config
cale check

# Chercher sur La Cale
cale search 257088
cale search "Inception"
```

### Avec Docker Compose

Le fichier `docker-compose.yml` fourni propose deux services :

| Service | Usage |
|---------|-------|
| `cale-push` | Commandes one-shot (scan, check, search, preview) |
| `cale-push-timer` | Service automatique (push toutes les 10 minutes) |

**Modifier `docker-compose.yml`** — remplacez les chemins `/path/to/...` :

```yaml
volumes:
  - ./config:/config                      # Votre config
  - /share/Multimedia/Films:/media/movies:ro   # Vos films
  - /share/Multimedia/Series:/media/tv:ro      # Vos séries
  - /share/Downloads/torrents:/torrents        # Dossier torrents
```

**Commandes :**

```bash
# Commande one-shot
docker compose run --rm cale-push scan movies
docker compose run --rm cale-push push all --dry-run

# Lancer le service automatique
docker compose up -d cale-push-timer

# Voir les logs du service
docker compose logs -f cale-push-timer

# Arrêter le service
docker compose down
```

## Configuration réseau

### Radarr/Sonarr sur le même NAS

Si Radarr/Sonarr tournent sur le même NAS (en Docker ou natif) :

```bash
# Option 1 : IP LAN du NAS
RADARR_URL="http://192.168.1.100:7878/radarr"

# Option 2 : host.docker.internal (Docker Desktop / Linux avec --add-host)
RADARR_URL="http://host.docker.internal:7878/radarr"

# Option 3 : réseau Docker partagé
# Ajoutez dans docker-compose.yml :
#   networks:
#     default:
#       external: true
#       name: media-stack
RADARR_URL="http://radarr:7878/radarr"
```

### Client torrent

Le client torrent (Transmission/qBittorrent) doit aussi être accessible :

```bash
# Transmission sur le NAS
TRANSMISSION_HOST="192.168.1.100:9091"
TRANSMISSION_AUTH="user:password"

# qBittorrent sur le NAS
QBIT_HOST="192.168.1.100:8080"
QBIT_USER="admin"
QBIT_PASS="password"
```

## Path mapping (PATH_MAP)

C'est le point le plus important pour Docker. Radarr renvoie les chemins des fichiers tels qu'il les voit. Si Radarr tourne dans un conteneur, ces chemins ne correspondent pas à ceux du conteneur cale-push.

### Principe

```
Radarr voit     →  /movies/Film Name/file.mkv
Votre NAS a     →  /share/Multimedia/Films/Film Name/file.mkv
Docker monte    →  /share/Multimedia/Films → /media/movies
cale-push doit  →  /media/movies/Film Name/file.mkv
```

### Configuration

```bash
# Dans config/config :
# Format : "chemin_radarr:chemin_docker"
# Plusieurs mappings séparés par des virgules

# Exemple simple
PATH_MAP="/movies:/media/movies"

# Exemple avec films et séries
PATH_MAP="/movies:/media/movies,/tv:/media/tv"

# Exemple NAS Synology
PATH_MAP="/data/media/movies:/media/movies,/data/media/tv:/media/tv"

# Exemple NAS QNAP
PATH_MAP="/share/Multimedia/Films:/media/movies,/share/Multimedia/Series:/media/tv"
```

### Comment trouver les bons chemins

1. **Chemin Radarr** : allez dans Radarr → un film → le chemin du fichier affiché (ex: `/movies/Inception (2010)/Inception.mkv`)
2. **Chemin Docker** : c'est le côté droit du volume monté dans `docker-compose.yml`

```bash
# Vérifier que le mapping est correct
docker compose run --rm cale-push scan movies
# Si les fichiers sont "not found", ajustez PATH_MAP
```

## Exemples complets

### Synology DSM

```yaml
# docker-compose.yml
services:
  cale-push-timer:
    build: .
    image: cale-push:latest
    container_name: cale-push-timer
    restart: unless-stopped
    volumes:
      - /volume1/docker/cale-push/config:/config
      - /volume1/video/Films:/media/movies:ro
      - /volume1/video/Series:/media/tv:ro
      - /volume1/downloads/torrents:/torrents
    environment:
      - TZ=Europe/Paris
    entrypoint: ["/bin/bash", "-c"]
    command:
      - |
        while true; do
          /opt/cale-push/cale-push push all 2>&1 | tee -a /config/cale-push.log
          sleep 600
        done
```

```bash
# config/config
RADARR_URL="http://192.168.1.50:7878"
RADARR_API_KEY="abc123"
SONARR_URL="http://192.168.1.50:8989"
SONARR_API_KEY="def456"
PATH_MAP="/movies:/media/movies,/tv:/media/tv"
HISTORY_FILE="/config/uploaded.txt"
CACHE_FILE="/config/cache.tsv"
TORRENT_PROVIDER="qbittorrent"
QBIT_HOST="192.168.1.50:8080"
QBIT_USER="admin"
QBIT_PASS="password"
```

### Unraid

```yaml
# docker-compose.yml
services:
  cale-push-timer:
    build: .
    image: cale-push:latest
    container_name: cale-push-timer
    restart: unless-stopped
    volumes:
      - /mnt/user/appdata/cale-push:/config
      - /mnt/user/data/media/movies:/media/movies:ro
      - /mnt/user/data/media/tv:/media/tv:ro
      - /mnt/user/data/torrents:/torrents
    environment:
      - TZ=Europe/Paris
    entrypoint: ["/bin/bash", "-c"]
    command:
      - |
        while true; do
          /opt/cale-push/cale-push push all 2>&1 | tee -a /config/cale-push.log
          sleep 600
        done
```

### QNAP

```bash
# config/config
PATH_MAP="/share/Multimedia/Films:/media/movies,/share/Multimedia/Series:/media/tv"
RADARR_URL="http://192.168.1.30:7878"
TRANSMISSION_HOST="192.168.1.30:9091"
```

## Mise à jour

```bash
cd cale-push
git pull
docker build -t cale-push .
docker compose down && docker compose up -d
```

## Dépannage

### "file not found" sur les fichiers média

Le path mapping est incorrect. Vérifiez :

```bash
# 1. Quel chemin Radarr renvoie ?
curl -s -H "X-Api-Key: VOTRE_CLE" http://IP:7878/api/v3/movie | jq '.[0].movieFile.path'
# → "/movies/Film Name/file.mkv"

# 2. Où est monté le volume dans Docker ?
# docker-compose.yml → /share/Films:/media/movies:ro
# → le fichier est à /media/movies/Film Name/file.mkv dans le conteneur

# 3. Donc PATH_MAP doit être :
PATH_MAP="/movies:/media/movies"
```

### Radarr/Sonarr inaccessible

- N'utilisez pas `127.0.0.1` ou `localhost` — le conteneur a son propre réseau
- Utilisez l'IP LAN du NAS ou `host.docker.internal`
- Vérifiez que les ports sont ouverts

### Permissions

Si le conteneur ne peut pas écrire dans `/config` ou `/torrents` :

```bash
# Vérifier l'UID/GID
id
# → uid=1000(nathan) gid=1000(nathan)

# Ajouter au docker-compose.yml :
#   user: "1000:1000"
```

### Logs

```bash
# Logs du service automatique
docker compose logs -f cale-push-timer

# Ou dans le fichier de log
cat config/cale-push.log

# Activer le logging fichier dans config/config :
LOG_FILE="/config/cale-push.log"
```
