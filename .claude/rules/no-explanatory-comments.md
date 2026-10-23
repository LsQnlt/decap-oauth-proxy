# Commentaires

Exprimer l'intention par les noms, les blocs courts et la structure du code. Ne pas ajouter spontanément de commentaires explicatifs, TODO, bandeaux de section ou code commenté. Renommer, extraire ou simplifier lorsque cela rend le code compréhensible.

Les commentaires explicitement demandés sont autorisés. Conserver :

- l'en-tête de `app.rb` qui décrit le protocole attendu par le CMS, parce qu'il documente un contrat externe que le code ne porte pas à lui seul ;
- une très courte explication d'une contrainte de sécurité quand elle n'est pas évidente à la lecture (échappement de `<` dans la page de callback, comparaison du `state` à temps constant).
