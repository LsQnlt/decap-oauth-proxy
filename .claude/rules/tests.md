---
description: Tests Minitest avec WebMock
paths:
  - "test/**/*.rb"
---

# Tests

- Minitest + `rack-test`, lancés avec `bundle exec ruby -Itest test/app_test.rb`. Les identifiants et `ALLOWED_ORIGINS` de test sont fixés en tête du fichier de test : aucun identifiant réel n'est nécessaire.
- GitHub est simulé avec WebMock (`stub_request`). Ne jamais appeler le vrai `github.com` dans un test ; un test qui part en réseau est un test cassé.
- Un comportement de sécurité se double d'un test qui vérifie l'échec attendu, pas seulement le cas passant : `state` manquant ou faux renvoie `400`, le token ne part pas vers une origine absente de l'allowlist, une séquence `</script>` est bien échappée. Toucher à un invariant de `sinatra.md` sans ajouter ou mettre à jour son test est une régression.
- Garder les tests lisibles : un helper `start_flow` pose le cookie `state`, chaque test décrit un seul comportement.
