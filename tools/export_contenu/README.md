# Export des contenus pour iOS

`export.py` relit les contenus d'Android et les écrit sous `ios/Ressources/` (et les vecteurs de test
sous `ios/Paquets/Coeur/Tests/Ressources/`) : `ios/PORTAGE.md` § 4.2, `ios/ROADMAP.md` tâche 5.
Android reste la source ; l'outil n'écrit que sous `ios/`. Python 3, bibliothèque standard, hors ligne.

    python3 tools/export_contenu/export.py              # exporte et réécrit le manifeste
    python3 tools/export_contenu/export.py --verifier   # idem, et échoue si le manifeste a changé

| Étape | Sortie |
| --- | --- |
| 1. Textes | `Contenu/*.json` octet pour octet ; `Contenu/hilloulot_bios/<mois>.json` ; les livres de plus de 2 Mo en `Contenu/livres/<id>/index.json` et un fichier par chapitre (`<texte>-<chapitre>.json`), recomposition vérifiée |
| 2. Chaînes | `Chaines/Localizable.xcstrings` (clés d'Android, `%1$s` → `%1$@`, `%d` → `%lld`, `%2$02d` → `%2$02lld`, pluriels), `Chaines/Tableaux.json` ; sans les chaînes propres à Android (divulgations, batterie, superposition) ; mêmes clés et mêmes marqueurs dans les trois langues, sinon arrêt |
| 4. Palettes | `Contenu/palettes.json` : 13 jetons × 6 fonds × 6 accents × jour et nuit |
| 5. Images | `Images/*.webp` tels quels ; `Icones/*.svg` depuis les `VectorDrawable` |
| 6. Polices | `Polices/*.ttf`, `Polices/licences/` |
| 7. Musique | `Musique/*.m4a` et `Contenu/musique.json`, dans l'ordre de `MusiquePlay.kt` ; jamais `src/musique_hors_play` |
| 9. Vecteurs | `ios/Paquets/Coeur/Tests/Ressources/` |
| 10. Manifeste | `MANIFESTE.json` : chemin, source, taille, SHA-256, licence et mention de chaque fichier |

Versionnés : `MANIFESTE.json` seul (et, plus tard, `Chaines/ios.xcstrings`, écrit à la main). La CI
(`ios-coeur.yml`, travail `export`) relance l'export : si un contenu d'Android change sans que le
manifeste suive, elle échoue et dit quel fichier a bougé.

L'export s'arrête si un compte s'écarte (38 textes par rite, 150 psaumes et 2 527 versets, 10 psaumes
du Tikoun, 171 textes de 'hizouk, 12 livres, 4 049 hilloulot, 51 villes, 3 226 aéroports, 26 morceaux)
ou si un fichier produit n'a pas de licence.

Étape 3 : `Contenu/tables.json` est recopié de `ios/Paquets/Coeur/Tests/Vecteurs/tables.json`, que le Kotlin
d'Android écrit sur la JVM (`tools/vecteurs_ios/VecteursTables.kt`, refait et comparé par `ios-oracle.yml`).
Étape 8 : `recherche.py` écrit `Contenu/recherche.sqlite` après avoir vérifié sa normalisation sur les cas
communs d'Android (`Tests/Vecteurs/normalisation.json`) ; le manifeste en retient l'empreinte des lignes.

Pas encore faits : les miniatures PNG des personnages pour le bouclier et les widgets, avec ces écrans (tâches 25 et 27).
