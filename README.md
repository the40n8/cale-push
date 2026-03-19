# cale-push

> **English note:** This tool is designed for [La Cale](https://la-cale.space), a French private tracker. The documentation below is in French as the target audience is the La Cale community. Code, comments, and variables are in English.

---

Scannez votre bibliothèque d'ISOs Linux et poussez automatiquement vos contenus vers [La Cale](https://la-cale.space), tracker privé français.

Fortement inspiré du travail remarquable de [theolddispatch](https://github.com/theolddispatch/v2.0/) — réécrit et restructuré pour être modulaire, générique et utilisable par toute la communauté.

> [!WARNING]
> **Version bêta — cherche des testeurs !**
> Ce projet n'a pas encore été testé dans tous ses scénarios (la limite d'upload en cours de développement nous a rattrapés).
> Si vous l'utilisez et rencontrez des bugs ou des comportements inattendus, **les issues et merge requests sont très bienvenues** — c'est comme ça qu'on avance ensemble.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/the40n8/cale-push/main/tools/install.sh)"
```

> Pas fan d'exécuter un script random depuis internet ? Pour les paranos comme moi &rarr; [installation manuelle](#installation-manuelle)

## Fonctionnalités

- **Scan automatique** de votre bibliothèque Radarr (ISOs Linux) et Sonarr (distributions en plusieurs volumes)
- **Détection de doublons** par TMDB ID via l'API La Cale
- **Priorité intelligente** : push d'abord les contenus absents, puis les releases alternatives
- **Nommage conforme** aux [règles La Cale](docs/) (accents, ordre des tags, etc.)
- **Cache local** pour limiter les appels API
- **Re-vérification** avant l'upload pour éviter les doublons de dernière minute
- **Providers modulaires** pour le client torrent (Transmission, qBittorrent, extensible)
- **Notifications** : Discord webhook, Telegram bot, email (extensible)
- **Dry-run et filtres** : `--dry-run`, `--min-quality`, liste d'exclusion
- **Logging fichier** pour les runs systemd/cron
- **Retry automatique** avec backoff exponentiel sur les erreurs API
- **CLI complète** pour les opérations manuelles (`check`, `push`, `scan`, `search`, `preview`, ...)
- **Service systemd** pour l'automatisation (compatible cron pour les NAS)
- **Docker** : image prête pour NAS (Synology, QNAP, Unraid) avec path mapping
- **Mise à jour intégrée** via `./cale-push update`
- **Bash completion** incluse

## Prérequis

- Bash 4+
- `curl`, `jq`, `mktorrent`, `mediainfo`
- Radarr et/ou Sonarr avec des fichiers médias
- Un client torrent supporté (Transmission par défaut)
- Un compte La Cale avec une clé API (scope `upload:write`)

### Installation des dépendances (Ubuntu/Debian)

```bash
sudo apt install curl jq mktorrent mediainfo
```

## Installation

Le one-liner (en haut de ce README) clone le repo dans `~/.cale-push`, crée un lien dans `~/.local/bin`, et copie le template de config. L'installeur vérifie les dépendances et vous indique celles qui manquent.

Personnalisable via des variables d'environnement :

```bash
CALE_PUSH_DIR="$HOME/.cale-push"   # Répertoire d'installation
CALE_PUSH_BIN="$HOME/.local/bin"   # Répertoire pour le lien symbolique
```

### Installation manuelle

Vous pouvez inspecter le script avant de l'exécuter :

```bash
curl -fsSL https://raw.githubusercontent.com/the40n8/cale-push/main/tools/install.sh -o install.sh
less install.sh   # inspecter
bash install.sh
```

Ou tout faire à la main :

```bash
git clone https://github.com/the40n8/cale-push.git ~/.cale-push
ln -s ~/.cale-push/cale-push ~/.local/bin/cale-push

mkdir -p ~/.config/lacale
cp ~/.cale-push/config.example ~/.config/lacale/config
nano ~/.config/lacale/config

cale-push check
```

## Mise à jour

```bash
./cale-push update          # Met à jour vers la dernière version
./cale-push version         # Affiche la version actuelle
```

## Configuration

Copiez `config.example` vers `~/.config/lacale/config` et remplissez vos valeurs :

```bash
# La Cale (obligatoire)
LACALE_API_KEY="votre_cle_api"
TRACKER_URL="https://tracker.la-cale.space/announce?passkey=votre_passkey"

# Radarr (obligatoire pour les ISOs)
RADARR_URL="http://127.0.0.1:7878/radarr"
RADARR_API_KEY="votre_cle_radarr"

# Sonarr (obligatoire pour les distributions multi-volumes)
SONARR_URL="http://127.0.0.1:8989/sonarr"
SONARR_API_KEY="votre_cle_sonarr"

# Client torrent
TORRENT_PROVIDER="transmission"
TRANSMISSION_HOST="127.0.0.1:9091"
TRANSMISSION_AUTH="user:password"
```

Un fichier `config.local` à côté du script permet des overrides locaux (ignoré par git).

## Utilisation

### CLI

```bash
# Vérifier la configuration
./cale-push check

# Scanner les candidats
./cale-push scan movies
./cale-push scan series
./cale-push scan all

# Pousser du contenu vers La Cale
./cale-push push movies              # ISOs uniquement
./cale-push push series --max 3      # Max 3 volumes
./cale-push push all                 # ISOs + distributions multi-volumes
./cale-push push all --dry-run       # Simulation sans upload
./cale-push push movies --min-quality 1080p  # Uniquement les ISOs en haute qualité

# Chercher si un contenu existe sur La Cale
./cale-push search 257088            # Par TMDB ID
./cale-push search "Ubuntu 24.04"    # Par titre

# Prévisualiser le nom de release généré
./cale-push preview "Linux.Mint.2024.MULTi.VFF.2160p.4KLight.BluRay.AC3.5.1.x265-GRP.iso"

# État (historique, cache, timer)
./cale-push status

# Mise à jour
./cale-push update
```

### Service automatique

Deux méthodes selon votre environnement :

**Systemd** (Linux standard) :

```bash
# Installer le timer (toutes les 10 minutes par défaut)
./cale-push install movies

# Intervalle personnalisé (syntaxe systemd)
./cale-push install movies --interval 30min
./cale-push install all --interval 1h

# Voir les logs
journalctl --user -u cale-push -f

# Désinstaller
./cale-push uninstall
```

**Cron** (NAS, conteneurs, ou préférence utilisateur) :

```bash
# Installer une entrée crontab (syntaxe cron standard)
./cale-push install movies --cron "*/10 * * * *"
./cale-push install series --cron "*/30 * * * *"

# Voir les entrées installées
crontab -l

# Désinstaller (retire aussi bien systemd que cron)
./cale-push uninstall
```

Ou manuellement avec les fichiers dans `systemd/`.

### Docker (NAS)

Pour les NAS (Synology, QNAP, Unraid) ou tout environnement sans les dépendances natives :

```bash
# Construire l'image
docker build -t cale-push .

# Commande one-shot
docker run --rm \
    -v ./config:/config \
    -v /chemin/isos:/media/movies:ro \
    -v /chemin/distros:/media/tv:ro \
    -v /chemin/torrents:/torrents \
    cale-push push movies

# Ou avec Docker Compose (service automatique)
docker compose up -d cale-push-timer
```

Configurez `PATH_MAP` dans votre config pour mapper les chemins Radarr/Sonarr vers les chemins Docker :

```bash
PATH_MAP="/movies:/media/movies,/tv:/media/tv"
```

Voir [docs/docker.md](docs/docker.md) pour la documentation complète (exemples Synology, QNAP, Unraid, dépannage).

### Liste d'exclusion

Créez un fichier avec un TMDB ID ou titre par ligne pour exclure du push :

```bash
echo "EXCLUDE_FILE=$HOME/.config/lacale/exclude" >> ~/.config/lacale/config

# Exclure par TMDB ID
echo "257088" >> ~/.config/lacale/exclude

# Exclure par titre
echo "Arch Linux 2024.01" >> ~/.config/lacale/exclude
```

### Logging fichier

Pour les runs automatiques, activez le log fichier :

```bash
echo 'LOG_FILE="$HOME/.local/share/lacale/cale-push.log"' >> ~/.config/lacale/config
```

## Fichiers créés

| Fichier | Défaut | Rôle |
| --- | --- | --- |
| Historique | `~/.lacale_uploaded.txt` | Un nom de release par ligne — évite de re-pusher |
| Cache API | `~/.lacale_cache.tsv` | Cache des réponses La Cale (TMDB ID → nombre de releases) |
| Log | _(désactivé)_ | Activez via `LOG_FILE=...` dans la config |
| Work dir | `/tmp/lacale_upload_$$` | NFO et torrents temporaires — supprimé automatiquement en fin de run |

Tous ces chemins sont configurables via la config (`HISTORY_FILE`, `CACHE_FILE`, `LOG_FILE`).

## Système de priorité

Le script utilise un système à deux passes :

1. **Pass 1 (unique)** : Push les contenus qui n'existent pas du tout sur La Cale (vérifié par TMDB ID)
2. **Pass 2 (alternative)** : Push les releases alternatives pour les contenus déjà présents

Les contenus uniques sont toujours partagés en priorité.

## Nommage des releases

Le nommage suit les règles officielles La Cale (disponibles sur le forum, compte requis) :

| Type | Format |
| ---- | ------ |
| Film | `Titre.Annee.Langue.Resolution.Source.CodecVideo-Team` |
| Film (HDR) | `Titre.Annee.Langue.Dynamic.Resolution.Source.CodecVideo-Team` |
| Série | `Titre.S01E01.Langue.Resolution.Source.CodecVideo-Team` |

Structure complète (champs optionnels inclus) :

```text
Titre.Annee.Info.Edition.Imax.Langue.LangueInfo.Dynamic.Resolution.Plateforme.Source.Audio.AudioChannel.AudioSpec.CodecVideo-Team
```

Détection automatique depuis le nom de fichier et les métadonnées Radarr/Sonarr :

- **Info** : REPACK, PROPER, CUSTOM
- **Edition** : DC, EXTENDED, UNRATED, REMASTERED
- **Langue** : MULTi, FRENCH, VOSTFR, VFF, VFQ...
- **Dynamic** : HDR, HDR10+, DV
- **Plateforme** : NF, AMZN, DSNP...
- **Source** : BluRay, WEB, 4KLight, REMUX...
- **Audio** : AC3, EAC3, TrueHD, DTS-HD.MA...
- **Canaux** : 5.1, 7.1...
- **Atmos**

## Providers (client torrent)

Système modulaire pour le client torrent.

### Providers inclus

| Provider | Client | Config requise |
| -------- | ------ | -------------- |
| `transmission` | Transmission | `TRANSMISSION_HOST`, `TRANSMISSION_AUTH` |
| `qbittorrent` | qBittorrent | `QBIT_HOST`, `QBIT_USER`, `QBIT_PASS` |

### Créer un provider

1. Copiez `providers/example.sh` vers `providers/monprovider.sh`
2. Implémentez `provider_check()` et `provider_add_torrent()`
3. Mettez `TORRENT_PROVIDER="monprovider"` dans votre config

## Notifications

Système modulaire de notifications. Activez un ou plusieurs notifiers dans votre config :

```bash
NOTIFY_ENABLED="discord,telegram"  # Séparé par des virgules
```

### Notifiers inclus

| Notifier | Service | Config requise |
| -------- | ------- | -------------- |
| `discord` | Discord Webhook | `DISCORD_WEBHOOK_URL` |
| `email` | Email (sendmail) | `NOTIFY_EMAIL_TO` + commande `mail` |
| `telegram` | Telegram Bot | `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID` |

### Créer un notifier

1. Copiez `notifiers/example.sh` vers `notifiers/monnotifier.sh`
2. Implémentez `notifier_check()` et `notify_monnotifier()`
3. Ajoutez `monnotifier` à `NOTIFY_ENABLED` dans votre config

## Architecture

```text
cale-push/
├── cale-push                   # CLI (point d'entrée)
├── config.example              # Template de configuration
├── Dockerfile                  # Image Docker (Alpine + dépendances)
├── docker-compose.yml          # Compose avec service timer
├── docker-entrypoint.sh        # Entrypoint Docker
├── lib/
│   ├── core.sh                 # Logging, utilitaires, map_path
│   ├── cache.sh                # Cache local (TSV avec TTL)
│   ├── naming.sh               # Générateur de noms de release
│   ├── tags.sh                 # Mapping des tags La Cale
│   ├── api.sh                  # Création torrent, vérification slots
│   ├── notify.sh               # Dispatcher de notifications
│   ├── radarr.sh               # Intégration Radarr
│   └── sonarr.sh               # Intégration Sonarr
├── uploaders/
│   ├── internal.sh             # Upload via session (défaut)
│   ├── external.sh             # Upload via clé API (futur)
│   └── example.sh              # Template pour nouveaux uploaders
├── providers/
│   ├── transmission.sh         # Provider Transmission
│   ├── qbittorrent.sh          # Provider qBittorrent
│   └── example.sh              # Template pour nouveaux providers
├── notifiers/
│   ├── discord.sh              # Notifications Discord (webhook)
│   ├── email.sh                # Notifications email
│   ├── telegram.sh             # Notifications Telegram (bot)
│   └── example.sh              # Template pour nouveaux notifiers
├── tools/
│   └── install.sh              # One-liner installer
├── completions/
│   └── cale-push.bash          # Bash completion
├── systemd/
│   ├── cale-push.service
│   └── cale-push.timer
└── docs/
    ├── api.md                  # Endpoints API utilisés (liens docs officielles)
    └── docker.md               # Documentation Docker complète
```

## Méthode d'upload

Deux méthodes disponibles via `UPLOAD_METHOD` dans la config :

| Méthode | Description | Prérequis |
| --- | --- | --- |
| `external` | Clé API avec scope `upload:write` (défaut) | `LACALE_API_KEY` avec scope `upload:write` |
| `internal` | Login session email/password (fallback) | `LACALE_EMAIL`, `LACALE_PASSWORD` |

La méthode `external` utilise l'API La Cale avec une clé API — c'est la méthode recommandée. La méthode `internal` simule une session navigateur avec un PoW altcha et peut servir de fallback.

## Notes techniques

- Le NFO est généré automatiquement via `mediainfo`
- Le torrent est créé avec le flag source `lacale` (requis par le tracker)
- La vérification de doublon par infohash (`/api/internal/torrents/parse`) est effectuée avant chaque upload pour éviter les 409
- Pour les reuploads, le fichier original n'est pas renommé — seul le titre de la release sur le site suit les règles

## Contribuer

Les contributions sont les bienvenues ! Voir [CONTRIBUTING.md](CONTRIBUTING.md) pour les détails.

Des templates sont disponibles pour les [issues](https://github.com/the40n8/cale-push/issues/new/choose) et les [pull requests](https://github.com/the40n8/cale-push/compare) — merci de les utiliser pour faciliter la review.

Certaines parties de ce projet ont été développées avec l'aide de [Claude Code](https://claude.ai/claude-code) (voir `CLAUDE.md`). L'assistance IA est acceptée dans les contributions, à condition de comprendre et tester ce que vous soumettez — pas de vibe coding.

## Crédits

Ce projet est fortement inspiré du travail remarquable de [theolddispatch](https://github.com/theolddispatch/v2.0/). Son script original (upload via formulaire web, Radarr + qBittorrent) a posé les bases de la logique d'upload, du login session altcha, et de la génération BBCode.

- Projet original : [theolddispatch/v2.0](https://github.com/theolddispatch/v2.0/)
- Restructuration modulaire, API et Docker : la communauté La Cale

## Licence

Ce projet est sous licence [MIT](LICENSE). Vous êtes libre de l'utiliser, le modifier et le redistribuer.
