# API La Cale

Documentation officielle (compte requis) :

- **Référence** : [la-cale.space/faq/api](https://la-cale.space/faq/api)
- **Swagger** : [la-cale.space/api/external/docs](https://la-cale.space/api/external/docs)

## Endpoints utilisés par cale-push

| Endpoint | Utilisation |
|----------|-------------|
| `GET /api/external?tmdbId=…` | Recherche doublon avant upload (`lib/cache.sh`) |
| `GET /api/external/meta` | Résolution catégorie/tags (`uploaders/external.sh`) |
| `POST /api/external/upload` | Upload via clé API (`uploaders/external.sh`) |
| `GET /api/auth/altcha/challenge` | Challenge PoW pour login session (`uploaders/internal.sh`) |
| `POST /api/auth/login` | Login session email/password (`uploaders/internal.sh`) |
| `GET /api/internal/categories` | Résolution catégorie (`uploaders/internal.sh`) |
| `POST /api/internal/torrents/parse` | Vérification doublon par infohash avant upload (`uploaders/internal.sh`) |
| `POST /api/internal/torrents/upload` | Upload via session (`uploaders/internal.sh`) |
