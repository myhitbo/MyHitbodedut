# Vecteurs pour iOS : ce que répond le code d'Android

Les tests Swift de `ios/Paquets/Coeur` ne recopient aucune valeur à la main : ils rejouent des
fichiers de vecteurs, `ios/Paquets/Coeur/Tests/Vecteurs/*.json`, produits ici en faisant répondre le
code Kotlin de l'app lui-même, sur la JVM seule, sans SDK ni appareil. Repris de la PR #29, où ce
projet vit sous `tools/export_contenu/tables` ; ici, il est à part de celui de la tâche 6, qui
compile d'autres fichiers avec d'autres bouchons.

    tools/vecteurs_ios/lancer.sh                  # tout, écrit dans le dépôt
    tools/vecteurs_ios/lancer.sh VecteursSocle    # un générateur seul, compilé à part des autres

Il faut un JDK 21 (celui de la CI : d'une version à l'autre, Java n'écrit pas les nombres ni ne lit
les expressions régulières tout à fait de même), Gradle 8.14.3 et node 22.

| Générateur | Fichier | Ce qu'il juge |
| --- | --- | --- |
| `VecteursSocle` | `socle.json` | `Sources/Coeur/Socle` : chaînes en unités UTF-16, blancs de Kotlin, hasard, arrondis, nombres de Java, lecture et écriture du JSON d'Android |
| `VecteursTemps` | `temps.json` | `Socle/Temps.swift` : heures civiles et fuseaux comme java.time (changements d'heure compris) |
| `VecteursPratique` | `pratique.json` | la tâche 8 : séance, durées, série, semaine, anneaux, plaque, salutation, sujets, fenêtre de nuit, reprise, rappel suivant, vignette, boussole |
| `VecteursSauvegarde` | `sauvegarde.json` | la tâche 7 : les fichiers d'or de `Vecteurs/sauvegarde/` importés par `Store.importJson` dans un téléphone neuf, puis exportés ; `Coffre` sur la sauvegarde chiffrée du site |
| `site/sauvegarde-site.mjs` | `sauvegarde/web-v2.json` | le fichier d'or du site, écrit par le vrai `web/src/js/store.js` sur une horloge fixe |

## Comment c'est fait

- **Les sources d'Android sont lues en place.** `fichiers.txt` nomme celles qui sont compilées :
  `Store` et ce qu'il nomme, pas les écrans.
- **`R`** est engendrée d'après `res/`.
- **`android.jar` est rendu docile** : mêmes signatures, mais chaque méthode rend zéro, faux ou null au
  lieu de lever « Stub! ». C'est ce que fait Android Gradle Plugin pour les tests unitaires.
- **`org.json` est celui d'Android** (AOSP, l'artefact `android-json` de 2013, ses clés rangées dans
  l'ordre d'écriture comme sur un téléphone d'aujourd'hui). Comparé aux sources AOSP actuelles : mêmes
  conversions et même écriture (« / » échappé) ; seul diffère le message d'un `\u` mal formé.
  `geode-json`, celui de la tâche 6, garde l'ordre mais n'échappe pas « / » : il ne conviendrait pas
  pour juger une écriture.
- **`Theatre`** (`bouchons/Theatre.kt`) donne un `Context` : préférences en mémoire, vraies chaînes et
  vrais fichiers de `res/raw`.
- **`bouchons/coquilles/`** : ce que les règles nomment d'androidx, de Material et des écrans,
  signatures seules. Quatre courtes recopies (`HalakhaActivity.source`, `VueJour.usageLevana`, les
  bornes de `ReglagesLecture`, les visages de `BlockerMode`) : la construction s'arrête si le fichier
  d'origine ne les contient plus mot pour mot. `BuildConfig` porte les valeurs de la construction Play.

## La sauvegarde réelle (P7)

Elle n'entre pas au dépôt. Pour la juger :

    gradle -p tools/vecteurs_ios reelle -Pfichier=<sauvegarde.json> -Pattendu=<android.json>
    SAUVEGARDE_REELLE=<sauvegarde.json> SAUVEGARDE_REELLE_ANDROID=<android.json> swift test --filter Sauvegarde

Chiffrée, son mot de passe va dans `SAUVEGARDE_REELLE_MDP` (jamais sur la ligne de commande de Gradle).
Le test Swift vérifie que tout ce qu'Android a écrit revient dans l'export d'iOS, et, avec
`SAUVEGARDE_REELLE_ANDROID`, que l'import d'iOS égale celui d'Android. Dans la CI : un fichier chiffré
déposé en `ios/Paquets/Coeur/Tests/Vecteurs/sauvegarde/android-reelle.chiffre.json` et le secret
`SAUVEGARDE_REELLE_MDP` du dépôt suffisent (`ios-coeur.yml`) ; c'est au propriétaire de décider si un
fichier chiffré de son journal peut entrer au dépôt.

## La garde

`.github/workflows/ios-oracle.yml` relance tout et échoue si un fichier de
`ios/Paquets/Coeur/Tests/Vecteurs` a changé : une règle d'Android ou du site a bougé sans qu'iOS
suive. Le remède : relancer `lancer.sh`, versionner les vecteurs, faire passer les tests de `Coeur`.

Ce n'est pas une preuve d'exactitude : deux portages qui s'accordent montrent seulement que le
portage est fidèle.
