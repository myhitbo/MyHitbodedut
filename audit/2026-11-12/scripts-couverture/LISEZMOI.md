# Scripts de la matrice de couverture

Scripts Python qui ont produit `../couverture-traductions.md`. Ils ne modifient rien au dépôt.

À lancer depuis la racine du dépôt `MyHitbodedut`, par exemple `python3 audit/2026-11-12/scripts-couverture/b1_livres.py`.
Les scripts `e*_web_*.py` comparent avec le site construit et l'attendent dans un dossier `myhitbodedut-web` voisin du dépôt.
`b11_qualite_couverture.py` et `z_total.py` écrivent leurs résultats intermédiaires dans `/tmp`.
