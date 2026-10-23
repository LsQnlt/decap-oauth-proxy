---
description: Image Docker et déploiement
paths:
  - "Dockerfile"
  - ".dockerignore"
  - "puma.rb"
---

# Docker et déploiement

- Image unique `ruby:3.2-slim`, `bundle install` avec `BUNDLE_FROZEN` et `BUNDLE_WITHOUT="test"`, lancée en `USER app` non root. Garder l'utilisateur non privilégié et `Gemfile.lock` à jour (`bundle install` modifie le lock, pas le Dockerfile).
- Le service écoute sur `PORT` (3000 par défaut), un seul worker Puma, 0 à 4 threads. Déployé derrière un reverse proxy qui termine le TLS (Traefik via Coolify).
- Les secrets (`GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `ALLOWED_ORIGINS`) vont dans les variables d'environnement de l'hébergeur, **jamais** dans le `Dockerfile` ni un fichier versionné. `.env` est ignoré par Git et exclu de l'image via `.dockerignore`.
- `.dockerignore` garde l'image minimale : pas de `.git`, pas de `test`, pas de `README`. Ne pas y faire entrer de secret ni de fichier inutile.
- L'URL de callback configurée sur l'OAuth App GitHub doit correspondre au domaine déployé (`https://.../callback`). Un changement de domaine se répercute là.
