# Changelog

Toutes les modifications notables de ce projet sont documentées ici.

Format basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Ce projet suit le [Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-03-10

### Ajouté

- `install --interval <durée>` : intervalle personnalisé pour le timer systemd (ex. `30min`, `1h`)
- `install --cron <expression>` : installe une entrée crontab standard au lieu du timer systemd (ex. `"*/30 * * * *"`)
- `uninstall` détecte et supprime automatiquement les deux méthodes (systemd et crontab)

---

## [0.1.0] - 2025-03-09

Version bêta initiale — publiée pour trouver des testeurs.

### Fonctionnalités

- CLI avec sous-commandes (`push`, `scan`, `search`, `preview`, `status`, `check`, `install`, `update`)
- Scan automatique de la bibliothèque Radarr (films) et Sonarr (séries)
- Détection de doublons par TMDB ID via l'API La Cale
- Système de priorité deux passes (contenus uniques d'abord, alternatifs ensuite)
- Nommage des releases conforme aux règles officielles La Cale
- Cache local avec TTL (24h présent, 6h absent)
- Re-vérification par infohash avant upload pour éviter les doublons de dernière minute
- Système de providers modulaire (Transmission, qBittorrent)
- Système de notifications modulaire (Discord webhook, email, Telegram bot)
- Upload via session interne (login email/password + altcha PoW)
- Upload via clé API externe (en attente d'activation côté tracker)
- Mode `--dry-run`, filtre `--min-quality`, liste d'exclusion
- Retry automatique avec backoff exponentiel sur les erreurs API
- Bash completion (`completions/cale-push.bash`)
- Service systemd + timer pour l'automatisation
- Support Docker pour NAS (Synology, QNAP, Unraid)
- Path mapping (`PATH_MAP`) pour les environnements Docker/NAS

### Inspiré de

- [theolddispatch/v2.0](https://github.com/theolddispatch/v2.0/) — logique d'upload, login session altcha, génération BBCode
