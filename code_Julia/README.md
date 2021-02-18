# Code Julia pour le projet REOP

## Utilisation

Ce dossier contient un code Julia permettant de bien démarrer le projet du cours de recherche opérationnelle.


## Contenu

Toutes les fonctions sont importées par le fichier `import_all.jl`. Voici une brève description des autres fichiers :

- `cost.jl` : Calcul du coût d'une solution.
- `emballage.jl` : Définition de la classe `Emballage` et lecture à partir d'une chaîne de caractères.
- `feasibility.jl` : Satisfaction des contraintes par une solution.
- `fournisseur.jl` : Définitin de la classe `Fournisseur` et lecture à partir d'une chaîne de caractères.
- `graphe.jl` : Définition de la classe `Graphe` (qui stocke les distances entre sites) et lecture à partir d'une chaîne de caractères.
- `instance.jl` : Définition de la classe `Instance`, qui regroupe tous les paramètres d'une instance ainsi qu'une solution (vide par défaut), et lecture à partir d'un fichier.
- `plot.jl` : Outils de visualisation d'une instance ou d'une solution.
- `route.jl` : Définition de la classe `Route` et lecture à partir d'une chaîne de caractères.
- `solution.jl` : Lecture d'une solution à partir d'un fichier, et stockage à l'intérieur d'une instance.
- `usine.jl` : Définitin de la classe `Usine` et lecture à partir d'une chaîne de caractères.
- `write.jl` : Écriture des instances et solutions dans des fichiers texte.

## Algorithme de résolution 

Comme décrit dans le rapport, nous avons choisi de décomposer ce problème en 2 étapes :
- 'calcul_flux.jl' : Calcul des flux chaque jour pour chaque emballage entre chaque usine et chaque fournisseur 
- 'affectation_route.jl' : Construit les routes à partir des flux obtenu par le fichier précédent 

-'main.jl' : propose la génération de la solution et son coût