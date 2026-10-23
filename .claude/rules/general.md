# Règles générales

## Réponses

- Répondre de façon concise : la conclusion d'abord, le détail seulement s'il change quelque chose pour le lecteur.
- Quand on parle de code, le relier à ce que vit le contributeur qui se connecte : « ce contrôle d'origine décide si le token GitHub est remis à la fenêtre du CMS », plutôt qu'une description technique seule.
- Répondre en français ; le code, les identifiants et les messages de commit restent en anglais.

## KISS

- Préférer la solution la plus simple qui résout le besoin exprimé. Pas d'abstraction, d'option ou de généralisation « au cas où ». Le service tient en deux routes et aucun stockage : garder cette forme.
- Utiliser d'abord ce que Sinatra et Rack fournissent (cookies, `Rack::Utils`, helpers) avant une gem ou un helper maison.
- Une modification touche le minimum de fichiers. Ne pas réécrire du code voisin qui fonctionne.
- Si deux approches sont possibles, en proposer une et dire pourquoi, sans dérouler toutes les alternatives.

## Git

- Ne jamais lancer `git add`, `git commit`, `git push` ni aucune commande qui modifie l'historique. La revue et le commit appartiennent au développeur.
- En fin de tâche, proposer un message de commit prêt à copier : impératif présent en anglais, une ligne de titre, puis un court corps si le pourquoi n'est pas évident.

## Vocabulaire métier

- **Proxy** : ce service. Remplace le service OAuth de Netlify pour le backend `github` de Decap et Sveltia CMS. Une seule instance sert plusieurs sites.
- **Contributeur** : la personne qui se connecte au back-office d'un site pour publier. Le token qu'elle reçoit porte les droits qu'elle a déjà sur les dépôts, rien de plus.
- **CMS** : Decap ou Sveltia, côté navigateur, qui ouvre la popup de login et attend le token par `postMessage`.
- **`state`** : valeur aléatoire posée en cookie à `/auth` et revérifiée à `/callback` ; c'est la protection CSRF du flux OAuth.
- **Origine autorisée** : une entrée de `ALLOWED_ORIGINS`. Le token n'est transmis qu'à une fenêtre dont l'origine y figure.
- **OAuth App** : l'application GitHub (client id + secret) au nom de laquelle les contributeurs autorisent l'accès.
