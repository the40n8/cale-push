## Description

<!-- Résumez les changements apportés et pourquoi -->

## Type de changement

- [ ] Correction de bug
- [ ] Nouvelle fonctionnalité
- [ ] Refactoring (pas de changement de comportement)
- [ ] Documentation
- [ ] Autre :

## Tests effectués

- [ ] `./cale-push check`
- [ ] `./cale-push scan movies` ou `./cale-push scan series`
- [ ] `./cale-push push all --dry-run`
- [ ] `./cale-push preview "Fichier.2024.MULTi.1080p.BluRay.x264-GRP.mkv"`
- [ ] shellcheck (si modif de code Bash)

## Checklist

- [ ] Le code suit les conventions du projet (4 espaces, `local`, `snake_case`)
- [ ] Les variables de fichier/chemin sont quotées
- [ ] Pas de dépendances ajoutées en dehors de `bash`, `curl`, `jq`, `mktorrent`, `mediainfo`
- [ ] La documentation est mise à jour si nécessaire

## Notes pour la review

<!-- Tout ce que le reviewer devrait savoir : décisions de design, cas limites, points d'attention -->
