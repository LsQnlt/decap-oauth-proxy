---
description: Style Ruby du service
paths:
  - "app.rb"
  - "config.ru"
  - "puma.rb"
  - "Gemfile"
---

# Ruby

- Le service est un seul fichier `app.rb` (classe `DecapOAuthProxy < Sinatra::Base`), monté par `config.ru`. Pas de découpage en plusieurs fichiers tant que la lisibilité ne l'exige pas.
- Toute configuration passe par des variables d'environnement lues au chargement avec `ENV.fetch` : une variable manquante doit faire échouer le démarrage, pas produire un comportement par défaut silencieux.
- Noms précis, sorties anticipées (`halt 400, "..." unless ...`), prédicats en `?` sans préfixe `is_`.
- Guillemets doubles, `# frozen_string_literal: true` en tête de chaque fichier, Ruby 3.2 (voir `Gemfile`).
- Ne jamais journaliser le token ni le `client_secret`. Les logs disent ce qui s'est passé, pas les valeurs secrètes.
- Appliquer `.claude/rules/no-explanatory-comments.md`.
