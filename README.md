# decap-oauth-proxy

Proxy OAuth GitHub pour Decap CMS (et Sveltia CMS) avec le backend `github`. Il remplace le service d'authentification de Netlify quand le site est hébergé ailleurs. Une seule instance peut servir plusieurs sites : chaque site est un domaine de plus dans `ALLOWED_ORIGINS`.

Deux routes, aucun stockage :

- `GET /auth?provider=github&scope=repo` : pose un `state` aléatoire en cookie et redirige vers GitHub.
- `GET /callback?code=…&state=…` : vérifie le `state`, échange le code contre un token, rend une page qui transmet le token à la fenêtre du CMS par `postMessage`, uniquement vers une origine listée dans `ALLOWED_ORIGINS`.

Le token ne transite que par la popup et la fenêtre du CMS ; il n'est ni journalisé ni conservé.

## Variables d'environnement

| Variable               | Rôle                                                                                        |
| ---------------------- | ------------------------------------------------------------------------------------------- |
| `GITHUB_CLIENT_ID`     | Client ID de l'OAuth App GitHub                                                             |
| `GITHUB_CLIENT_SECRET` | Client secret de la même OAuth App                                                          |
| `ALLOWED_ORIGINS`      | Origines autorisées à recevoir un token, séparées par des virgules, sans slash final        |
| `PORT`                 | Port d'écoute, `3000` par défaut                                                            |

Une origine est `schéma://hôte[:port]`, par exemple `https://example.org,https://preview.example.org`. `https://example.org` et `https://www.example.org` sont deux origines différentes.

## Déployer le proxy

1. Créer une **OAuth App** GitHub (Settings → Developer settings → OAuth Apps, de préférence sous l'organisation qui possède les dépôts des sites) :
   - Homepage URL : l'URL du proxy, par exemple `https://auth.example.org`
   - Authorization callback URL : `https://auth.example.org/callback`
2. Déployer ce dépôt comme application Docker (Coolify, Dokku, un `docker run`…) sur ce domaine, avec les trois variables ci-dessus. Le secret se met dans les variables d'environnement de l'hébergeur, jamais dans un fichier versionné.
3. Vérifier que `https://auth.example.org/` répond `ok`.

## Brancher un site

1. Ajouter l'origine du site à `ALLOWED_ORIGINS` et redémarrer le proxy.
2. Dans le `admin/config.yml` du site :

   ```yaml
   backend:
     name: github
     repo: organisation/depot
     branch: main
     base_url: https://auth.example.org
   ```

   `base_url` est l'origine du proxy, sans slash final : Decap compare l'origine des messages reçus à cette valeur.

3. Ouvrir `/admin/` sur le site et se connecter. Chaque contributeur doit avoir accès en écriture au dépôt ; s'il appartient à une organisation, l'OAuth App doit y être approuvée (Organization settings → Third-party access).

Les mêmes réglages valent pour Sveltia CMS, qui lit le même `config.yml` et suit le même protocole de popup.

## Développement

```sh
bundle install
GITHUB_CLIENT_ID=x GITHUB_CLIENT_SECRET=y ALLOWED_ORIGINS=http://localhost:4000 bundle exec puma -C puma.rb
bundle exec ruby -Itest test/app_test.rb
```

Les tests simulent GitHub avec WebMock : aucun identifiant réel n'est nécessaire.

Pour tester le flux complet avec un site servi en local (`http://localhost:4000` pour Jekyll), il faut une OAuth App dont l'URL de callback pointe sur `http://localhost:3000/callback`, et `base_url: http://localhost:3000` dans le `config.yml` du site.
