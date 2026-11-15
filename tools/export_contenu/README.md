# Export des contenus pour iOS

`export.py` relit les contenus d'Android et les écrit sous `ios/Ressources/` (et les vecteurs de test
sous `ios/Paquets/Coeur/Tests/Ressources/`) : `ios/PORTAGE.md` § 4.2, `ios/ROADMAP.md` tâche 5.
Android reste la source ; l'outil n'écrit que sous `ios/`. Python 3, bibliothèque standard, hors ligne.

    python3 tools/export_contenu/export.py              # exporte et réécrit le manifeste
    python3 tools/export_contenu/export.py --verifier   # idem, et échoue si le manifeste a changé
    python3 tools/export_contenu/export.py --tables D   # sans JVM : reprend D/tables.json et D/vecteurs_recherche.json
    python3 tools/export_contenu/export.py --java D     # lit le Kotlin de l'app dans D (la preuve de la garde)

L'étape 3 demande un JDK 17 à 24 (Gradle 8.14.3 ne tourne pas sur Java 25 et plus ; `JAVA_HOME`
choisit le JDK) et Gradle 8.14.3 (celui du PATH, `$GRADLE`, sinon `android/gradlew`) ; sa
construction va dans `~/.cache/myhitbodedut-export` (`$EXPORT_CONSTRUCTION`), hors du dépôt. Elle
tourne avant que l'export n'efface ses sorties : un échec ne laisse rien à moitié. Comptez une
minute la première fois.

| Étape | Sortie |
| --- | --- |
| 1. Textes | `Contenu/*.json` octet pour octet ; `Contenu/hilloulot_bios/<mois>.json` ; les livres de plus de 2 Mo en `Contenu/livres/<id>/index.json` et un fichier par chapitre (`<texte>-<chapitre>.json`), recomposition vérifiée |
| 2. Chaînes | `Chaines/Localizable.xcstrings` (clés d'Android, `%1$s` → `%1$@`, `%d` → `%lld`, `%2$02d` → `%2$02lld`, pluriels), `Chaines/Tableaux.json` ; sans les chaînes propres à Android (divulgations, batterie, superposition) ; mêmes clés et mêmes marqueurs dans les trois langues, sinon arrêt |
| 3. Tables du Kotlin | `Contenu/tables.json` : `tables/` compile sur la JVM les fichiers de l'app qui portent les tables du § 4.1 C, et `Tables.kt` les écrit (identifiants `R.*` → noms de ressources) ; `Personnage.kt` et `PoliceHebraique.kt`, liés à Android, par expression régulière (`tables.py`), arrêt si rien n'est trouvé. Aussi `vecteurs_recherche.json` (`Recherche.kt`) |
| 4. Palettes | `Contenu/palettes.json` : 13 jetons × 6 fonds × 6 accents × jour et nuit |
| 5. Images | `Images/*.webp` tels quels ; `Icones/*.svg` depuis les `VectorDrawable` |
| 6. Polices | `Polices/*.ttf`, `Polices/licences/` |
| 7. Musique | `Musique/*.m4a` et `Contenu/musique.json`, dans l'ordre de `MusiquePlay.kt` ; jamais `src/musique_hors_play` |
| 8. Recherche | `Contenu/recherche.sqlite` (`recherche.py`) : chaque bloc déjà passé par la normalisation de `RechercheGlobale.nu`, et ce que les règles de résultat demandent ; la normalisation Python doit rendre celle du Kotlin sur `cas_normalisation.json`, sinon arrêt |
| 9. Vecteurs | `ios/Paquets/Coeur/Tests/Ressources/` |
| 10. Manifeste | `MANIFESTE.json` : chemin, source, taille, SHA-256, licence et mention de chaque fichier ; pour l'index, la taille et l'empreinte de son **contenu** (`octets_contenu`, `sha256_contenu`) : deux versions de SQLite rangent les mêmes lignes dans des octets différents |

Versionnés : `MANIFESTE.json` seul (et, plus tard, `Chaines/ios.xcstrings`, écrit à la main). La CI
(`ios-coeur.yml`, travail `export`) relance l'export : si un contenu d'Android change sans que le
manifeste suive, elle échoue et dit quel fichier a bougé.

L'export s'arrête si un compte s'écarte (38 textes par rite, 150 psaumes et 2 527 versets, 10 psaumes
du Tikoun, 171 textes de 'hizouk, 12 livres, 4 049 hilloulot, 51 villes, 3 226 aéroports, 26 morceaux ;
dans les tables, 6 échelles de paliers, 11 familles et 128 niveaux de trophées, 30 et 7 portions,
10 sujets de Tefilot et 10 de séance, 5 temps, 21 correspondances de poses, 15 zmanim) ou si un
fichier produit n'a pas de licence.

## Le projet `tables/`

Rien n'y est tapé à la main : chaque table vient de l'objet de l'app qui la porte, par son API ou,
pour une table privée, par réflexion. Les fichiers de l'app sont compilés tels quels depuis
`android/` (liste dans `build.gradle.kts`), avec des bouchons pour ce qu'Android fournirait :

| Bouchon | Pour |
| --- | --- |
| `R` (généré par `tables.py` d'après `res/`) | les identifiants, que `Tables.kt` retraduit en noms |
| `bouchons/Annotations.kt` | `@StringRes`, `@DrawableRes`, `@RawRes` |
| `bouchons/Android.kt`, `Resources.kt`, `Os.kt` | `Context` (les `load(context)` des chargeurs), le fil principal de `Hilloulot` |
| `bouchons/App.kt` | `RegleLangue`, `ChizukCard`, `HalakhaActivity` : nommés par des fichiers compilés, mais tenus à Android ; jamais appelés, sauf le titre du Ben Ich Haï, dont le bouchon rend les champs pour les vecteurs |

`org.json` est celui d'Android (AOSP, republié par Apache Geode) : il garde l'ordre des clés du
fichier, comme l'appareil, et cet ordre décide des trente premiers résultats d'une recherche.
`org.json:json`, celui des tests d'Android sur la JVM, les mélange.

Les expressions régulières d'Android tournent sur ICU : `\s` y est la propriété White_Space
(l'insécable, les espaces fines du siddour), quand celui de la JVM n'est que l'ASCII. La seule
expression exécutée ici dont le sens change est le `\s+` de `RechercheGlobale.nu` : la copie
compilée lui donne `(?U)`, et la construction s'arrête si cette expression change. `recherche.py`
et `RechercheGlobale.swift` suivent l'appareil.

La garde : un seuil changé dans une copie de `Trophees.kt` change `tables.json`, donc le manifeste ;
la CI le vérifie à chaque passage (`--java` sur une copie modifiée, `--verifier` doit échouer).

Pas encore faites : les miniatures PNG des personnages pour le bouclier et les widgets, avec ces
écrans (tâches 25 et 27).
