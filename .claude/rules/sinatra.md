---
description: L'application Sinatra et les invariants de sécurité du flux OAuth
paths:
  - "app.rb"
  - "config.ru"
---

# Sinatra et flux OAuth

## Les deux routes

- `GET /auth` : vérifie le provider et le scope, tire un `state` aléatoire, le pose en cookie et redirige vers GitHub. `GET /callback` : revérifie le `state`, échange le code contre un token, rend une page qui transmet le token au CMS par `postMessage`. `GET /` répond `ok` pour le health check. Ne pas ajouter de route sans besoin démontré.
- Le service ne stocke rien. Le `state` vit dans un cookie signé par sa seule imprévisibilité, pas en base. Garder cette absence d'état.

## Invariants de sécurité, à ne pas affaiblir

- **`state`** : posé en cookie `httponly`, `same_site: :lax`, `path=/callback`, `secure` dès que la requête est en HTTPS. Comparé à `/callback` avec `Rack::Utils.secure_compare` (temps constant), puis le cookie est supprimé. Un `state` vide ou différent renvoie `400`. Ne jamais remplacer cette comparaison par `==`.
- **Allowlist d'origines** : le token n'est envoyé qu'à une fenêtre dont `e.origin` est dans `ALLOWED_ORIGINS`. Le `postMessage` de déclenchement `authorizing:github` est le seul envoyé en `"*"`, parce qu'il ne contient aucun secret. Ne jamais passer le message contenant le token en `"*"`.
- **Scope** : seules les valeurs de `ALLOWED_SCOPES` sont acceptées. Ne pas élargir sans raison ; `repo` donne déjà l'écriture sur les dépôts privés du contributeur.
- **Échappement de la page de callback** : les valeurs injectées dans le `<script>` passent par `js(...)`, qui sérialise en JSON et échappe `<` en `<` pour qu'une valeur ne puisse pas fermer la balise `<script>`. Toute nouvelle valeur injectée dans cette page doit passer par `js(...)`.
- **En-têtes** : la réponse de `/callback` porte `Cache-Control: no-store` pour que le token ne soit pas mis en cache. Le conserver.

## Erreurs

- `show_exceptions`, `dump_errors` et le logging sont réglés volontairement. Une erreur côté GitHub ou un échange raté est rapporté au CMS comme un message `authorization:github:error:...`, jamais comme une 500 avec une trace. Garder ce comportement : le contributeur voit un échec propre, le détail reste dans les logs.
