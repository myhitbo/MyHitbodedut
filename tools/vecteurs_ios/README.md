# Vecteurs pour iOS : ce que répond le code d'Android

Les tests Swift de `ios/Paquets/Coeur` ne recopient aucune valeur à la main : ils rejouent des
fichiers de vecteurs, `ios/Paquets/Coeur/Tests/Vecteurs/*.json`, produits ici en faisant répondre le
code Kotlin de l'app lui-même, sur la JVM seule, sans SDK ni appareil. C'est le pendant, pour iOS, de
`tools/vecteurs_kosherjava` pour le site (`ios/PORTAGE.md` § 5.1, `ios/ROADMAP.md` tâches 6 et 11).

    tools/vecteurs_ios/lancer.sh                  # tous les générateurs, écrit dans le dépôt
    tools/vecteurs_ios/lancer.sh VecteursSocle    # un seul, compilé à part des autres

Il faut un JDK 21 (celui de la CI : d'une version à l'autre Java n'écrit pas les nombres ni ne lit les
expressions régulières tout à fait de même). `android.jar` (plateforme 36) est pris dans `ANDROID_JAR`,
sinon dans `ANDROID_HOME`, sinon téléchargé et vérifié par son empreinte.

## Comment c'est fait

Le projet Gradle est `tools/export_contenu/tables` ; il est autonome et ne modifie rien sous `android/`.

- **Les sources d'Android sont lues en place.** `fichiers.txt` nomme celles qui sont compilées : les
  règles et les données, pas les écrans.
- **`R`** est engendrée d'après `res/` ; un générateur parle des ressources par leur nom
  (`Identifiants.nom(id)`), jamais par leur numéro.
- **`android.jar` est rendu docile** : mêmes signatures, mais chaque méthode rend zéro, faux ou null au
  lieu de lever « Stub! ». C'est ce que fait Android Gradle Plugin pour les tests unitaires
  (`unitTests.isReturnDefaultValues`).
- **`org.json` est celui d'Android** (AOSP), clés gardées dans l'ordre d'écriture comme sur un
  téléphone. Celui des tests unitaires d'Android (json.org) range ses clés autrement et ne convertit
  pas tout à fait de même.
- **`Theatre`** (`bouchons/Theatre.kt`) donne un `Context` : préférences en mémoire, vraies chaînes et
  vrais fichiers de `res/raw`, dans la langue demandée. `Store` et ce qui en dépend tournent dessus.
- **`bouchons/coquilles/`** : les quelques classes d'androidx, de Material et des écrans que les règles
  nomment, signatures seules. Trois courtes recopies (`HalakhaActivity.source`, `VueJour.usageLevana`,
  les bornes de `ReglagesLecture`) : la construction s'arrête si le fichier d'origine ne les contient
  plus mot pour mot.

## Écrire un générateur

Un fichier `Vecteurs<Domaine>.kt` dans ce dossier, qui déclare un objet du même nom :

    object VecteursDuree : Generateur {
        override val fichier = "duree.json"
        override fun produire(): Map<String, Any?> = linkedMapOf(
            "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursDuree.kt"),
            "cas" to listOf(0, 59, 60, 61).map { m -> linkedMapOf("minutes" to m, "texte" to JaugeSemaine.format(m)) },
        )
    }

Les règles : rien qui dépende de l'heure qu'il est, du fuseau de la machine ou du hasard (tout est
passé en argument, avec des graines fixes) ; les clés d'un objet dans un ordre voulu (`linkedMapOf`) ;
des fichiers petits (une empreinte plutôt qu'un corpus entier). Deux passes donnent les mêmes octets.

## La garde

`.github/workflows/ios-oracle.yml` relance tous les générateurs et échoue si un fichier de
`ios/Paquets/Coeur/Tests/Vecteurs` a changé : une règle d'Android a bougé sans qu'iOS suive. Le remède
est de relancer `lancer.sh`, de versionner les vecteurs, puis de faire passer les tests de `Coeur`.

Ce n'est pas une preuve d'exactitude : deux portages qui s'accordent montrent seulement que le portage
est fidèle (voir `tools/vecteurs_kosherjava/README.md`).
