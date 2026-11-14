# Porter une règle d'Android dans Coeur

Pour qui porte un fichier Kotlin de l'app vers `ios/Paquets/Coeur`. Le pourquoi du portage est dans
`ios/PORTAGE.md`, l'ordre des tâches dans `ios/ROADMAP.md`. Cette notice dit **comment**, et ce qui
a déjà coûté une passe de CI.

Il n'y a pas de compilateur Swift dans une session de travail : la CI Linux (`ios-coeur.yml`,
Swift 6.2) est le seul juge de la syntaxe. Tout le reste se prouve avant d'envoyer.

## Les trois juges

1. **Les tests d'Android, portés avec les mêmes cas.** Un test Kotlin devient un test Swift de même
   nom (en camelCase), mêmes entrées, mêmes attendus. Rien n'est affaibli, rien n'est retiré sans le
   dire en tête du fichier.
2. **Les vecteurs de la JVM.** Le vrai code Kotlin répond, cas par cas, dans un fichier que le test
   Swift rejoue (`tools/vecteurs_ios/README.md`). C'est ainsi qu'on sait ce qu'Android rend pour mille
   entrées et non pour les six du test d'origine, sans recopier une valeur à la main.
3. **La CI.** Elle compile sans avertissement et lance les tests ; `ios-oracle.yml` refait les
   vecteurs et échoue si Android a bougé.

## La marche

1. Lire le fichier Kotlin **en entier**, ses tests, et ce qu'il appelle.
2. Écrire `tools/vecteurs_ios/Vecteurs<Domaine>.kt` : les cas des tests d'Android, puis un balayage
   large (bornes, valeurs négatives, années bissextiles, hébreu vocalisé, chaînes vides). Le lancer :
   `tools/vecteurs_ios/lancer.sh Vecteurs<Domaine>` (seul, compilé à part), puis sans argument.
3. Écrire le Swift dans `Sources/Coeur/`, ses tests dans `Tests/CoeurTests/` : la suite portée du
   test Kotlin, et un test qui rejoue le fichier de vecteurs.
4. Simuler en Python ce qui peut l'être contre les vecteurs : la logique se prouve là, pas en CI.
5. Relire le Swift avec la liste ci-dessous, puis envoyer. Lire le journal de la CI, pas son seul verdict.

## Ce que Kotlin et Java font autrement

Le socle (`Sources/Coeur/Socle`) porte ces différences ; `socle.json` les tient à l'œil.

| Kotlin, Java | En Swift | Le piège |
| --- | --- | --- |
| `Int` : 32 bits, déborde en silence | `Int` : 64 bits, s'arrête au débordement | un calcul qui compte sur le débordement s'écrit en `Int32` avec `&+`, `&*` |
| `Math.floorMod`, `Int.mod` | `Kotlin.floorMod` | `%` garde le signe du dividende dans les deux langages |
| `roundToInt()`, `Math.round` | `Kotlin.arrondi`, `Kotlin.arrondiLong` | les demis vont vers +∞ : −2,5 donne −2 ; `rounded()` de Swift donne −3 |
| `Math.round(a.toFloat() / b)` | `Kotlin.arrondiFlottant(Float(a) / Float(b))` | le calcul est en simple précision |
| `toInt()`, `toLong()` d'un `Double` | `Kotlin.versInt`, `Kotlin.versLong` | Java borne ; `Int(x)` de Swift s'arrête hors bornes et sur NaN |
| `"%.1f".format(Locale.ROOT, x)` | `Java.format(x, decimales: 1)` | Java arrondit l'écriture décimale (0,15 → « 0.2 »), `String(format:)` la valeur binaire (« 0.1 ») |
| `"%02d:%02d".format(h, m)` | `String(format: "%02d:%02d", h, m)` | identique pour des entiers |
| `s.length`, `take`, `drop`, `substring` | `s.utf16.count`, `premieresUnites`, `sansPremieresUnites`, `unites(a, b)` | `count` de Swift compte des caractères entiers : une lettre hébraïque et ses voyelles n'en font qu'un |
| `contains`, `indexOf`, `startsWith`, `replace`, `==` | `contientUnites`, `positionUnites`, `commenceParUnites`, `remplacantUnites`, `egalUnites` | Swift compare à l'équivalence canonique : « é » y égale « e » + accent, et `contains("מ")` ne trouve pas le mem de « מָה » |
| `isBlank()`, `trim()` | `estBlanc`, `rogne` | les blancs de Kotlin ne sont pas ceux de `whitespacesAndNewlines` |
| `Regex`, `find`, `findAll`, `replace`, `split` | `ExpressionReguliere` : `trouve`, `toutes`, `remplace`, `decoupe` | même moteur que sur un téléphone (ICU) ; hors ASCII, `\s`, `\w`, `\b`, `\d` n'ont pas l'étendue de la JVM des tests : écrire la classe en toutes lettres |
| `hashCode()` d'une chaîne | `Kotlin.hashCode` | 32 bits, sur les unités UTF-16 |
| `Random(graine)`, `shuffled(r)`, `random(r)` | `HasardKotlin` : `nextInt`, `melange`, `tirage` | mêmes tirages qu'Android pour une même graine |
| `JSONObject`, `optInt`, `optString` | `ObjetJSON`, `entier`, `texte` | Android lit « 20 » et 20,7 comme 20, et rend « null » pour `null` ; les clés gardent leur ordre |
| `Normalizer.normalize(s, NFC)` | `s.formeNFC` | |
| `LocalDate` | `JourCivil` | jamais de `Date` pour un jour, jamais `Calendar.current` ni l'heure qu'il est : tout se passe en argument |
| `mapOf`, `LinkedHashMap`, `groupBy` | un tableau de paires, ou des clés triées | un `Dictionary` de Swift se parcourt dans un ordre qui change d'un lancement à l'autre |
| `sortedBy` (stable) | trier sur `(clé, rang)` | la stabilité du tri de Swift n'est pas promise |
| `lowercase()`, `uppercase()` | `lowercased()`, `uppercased()` | identiques pour le français, l'anglais et l'hébreu |

Un littéral hébreu se recopie du Kotlin **octet pour octet**, sans le retaper ; là où le test Kotlin
normalise (`Normalizer`), le test Swift normalise aussi (`formeNFC`).

## Ce que le compilateur refuse

- **Swift 6, concurrence stricte.** Tout type public est `Sendable` (des `struct` et des `enum`).
  Aucune variable globale ni `static var` ; un `static let` doit être d'un type `Sendable`. Une
  expression régulière partagée s'écrit `static let x = ExpressionReguliere("…")`.
- **Aucun avertissement** dans `Sources/Coeur` ni `Tests/CoeurTests` : la CI les cherche dans le
  journal et échoue. Les plus fréquents : une variable jamais lue ou jamais modifiée (`let`), un
  résultat ignoré (`_ =`), un `try` sans rien qui lève, un optionnel glissé dans une chaîne.
- **`#expect`.** Le macro décompose l'expression qu'on lui donne. Lui passer deux valeurs déjà
  calculées (`let n = liste.count` puis `#expect(n == 3)`), jamais un appel qui prend une fermeture
  ou un chemin de clé (`#expect(x.allSatisfy(\.vide))` ne compile pas). `try #require(…)` pour un
  optionnel dont la suite dépend.
- **Foundation sous Linux.** Pas de `%@` avec une `String` dans `String(format:)` ; pas de
  `DateComponentsFormatter` ; `NSRegularExpression`, `NSRange`, `precomposedStringWithCanonicalMapping`,
  `TimeZone(identifier:)`, `Calendar(identifier: .gregorian)` existent. Dans le doute, s'en passer.
- **Noms.** Un nom par module : ne pas redéclarer un type ou une extension de `String` qui existe
  déjà (dans `Sources/Coeur/Socle`, dans `Tests/CoeurTests/Fichiers.swift` et `Textes.swift`). Les
  aides propres à un fichier sont `private`. Un fichier qui importe KosherSwift ne nomme pas un de
  ses types comme les siens (`Zman`, `JewishCalendar`, `GeoLocation`, `Time`…).
- **KosherSwift** n'est pas `Sendable` et écrit dans une variable statique : ses objets ne sortent
  jamais de la fonction qui les crée, et leurs calculs passent par un verrou (voir `Zmanim.swift`).

## Ce qui ne se porte pas

Un test d'Android qui lit le code d'un écran (`File("…Activity.kt").readText()`), un layout, le
manifeste ou Gradle vérifie Android, pas une règle : il reste à Android, et l'en-tête du test Swift
le dit en une ligne. Ce qui concerne un écran d'iOS reviendra avec cet écran (jalons C à G).

## Style

Celui des fichiers voisins : identifiants et commentaires en français, un commentaire dit le
pourquoi ou renvoie au fichier Kotlin d'origine, aucune dépendance nouvelle, aucun fichier engendré
versionné hormis les vecteurs et le manifeste.
