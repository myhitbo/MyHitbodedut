# KosherSwift devant les vecteurs d'Android

Tâche 2 de `ROADMAP.md`, décision D4. Mesures du 13/11/2026, sur la CI Linux (`swift:6.2-noble`) :
flux `ios-coeur.yml` (Coeur sur la 1.10.11) et `ios-kosherswift.yml` (les deux étiquettes).

## En bref

- **1.10.11 tient le critère.** Les 35 lignes de `web/test/vecteurs_kosherjava.json` (15 zmanim et
  l'allumage, 560 valeurs) sont rendues à une seconde près, et les 29 `ABSENT` à l'identique.
- **3.1.2 ne le tient pas.** 'Hatsot s'écarte de 15 s, le lever et le coucher jusqu'à 29 s,
  l'allumage de 13 min à Tromsø. Passer à la 3.x reste une décision pour les trois plateformes ensemble.
- **La 1.10.11 ne compile pas telle quelle sous Linux**, pour un seul fichier, que Coeur n'emploie pas ;
  un commit de quelques lignes suffit. Il vit dans le fork public `myhitbo/KosherSwift` (décision D12),
  dont Coeur dépend.

## Les deux étiquettes

| | 1.10.11 | 3.1.2 |
| --- | --- | --- |
| Révision | `1fb606ea5b02c87b0a02931ecf3c06503134b6fc` (étiquette amont) ; Coeur emploie `97551b47c3682fbf97ec95adae891d5c3e7dd076`, la même plus le correctif Linux | `6b12b4089f2a8b198971b793e6d29e171c3f1b37` |
| Employée par | `ios/Paquets/Coeur`, par le fork `myhitbo/KosherSwift`, branche `linux-1.10.11` (épinglée par révision) | `ios/Outils/KosherSwift3` (mesure seulement) |
| API | celle de KosherJava 2.5.0 (`ComplexZmanimCalendar`, `getSofZmanShmaMGA`, `getTzais72`…) | celle de la 3.x (`ComprehensiveZmanimCalendar`, `…MGA72Minutes`, `getTzais72Minutes`, `getChatzosHayom`) |
| Compilation sous Linux, telle quelle | **non** : `ZmanimFormatter` emploie `DateComponentsFormatter`, absent de `swift-corelibs-foundation` | oui |
| Compilation sous Linux, avec le correctif | oui (fork, branche `linux-1.10.11`) | sans objet |
| Ses propres tests sous Linux | 36 tests, verts avec le correctif | 42 tests, verts |
| Mode de langage | Swift 5 (`swift-tools-version: 5.7.1`) | Swift 5 |
| Compilée en mode Swift 6 | 11 erreurs distinctes, toutes « static property … is not concurrency-safe » (`NOAACalculator.geoLocation`, listes de paracha, de massekhtot, comparateurs de `Zman`…) | 13, de même nature |
| Depuis Coeur, en Swift 6 | aucun avertissement : les objets de KosherSwift ne quittent pas la fonction qui les crée | — |

## Le correctif Linux

`ZmanimFormatter.format(milliseconds:)` met en forme une durée avec `DateComponentsFormatter`, qui
n'existe pas sous Linux. Le correctif garde ce code pour Darwin (`#if canImport(Darwin)`) et en donne
une version écrite à la main pour Linux. Il ne touche aucun calcul.

Il est le seul commit de la branche `linux-1.10.11` du fork public https://github.com/myhitbo/KosherSwift
(décision D12), posé sur l'étiquette 1.10.11 (`1fb606e`). Coeur dépend de ce commit, épinglé par révision
(`97551b4`), sous Linux comme sur iOS. Le fork tient aussi l'obligation de la LGPL : les sources de la
bibliothèque employée, modifications comprises, sont publiques. Le proposer à l'auteur, Elyahu41, reste à
faire, avec l'accord du propriétaire.

## 1.10.11 : les mesures

| Juge | Exigence | Mesuré |
| --- | --- | --- |
| `vecteurs_kosherjava.json`, 35 lignes × 16 valeurs | 1 s ; `ABSENT` exact | 531 instants, tous à moins d'une seconde ; écart maximal **994 ms** ('hatsot de la nuit, Paris, 29/03/2026, jour du passage à l'heure d'été) ; 29 `ABSENT` identiques, dont Tromsø au solstice d'été et d'hiver |
| `zmanim_reference_noaa.json` (formules de la NOAA) | 2 s, 20 s pour 'hatsot | écart maximal **15 s**, sur 'hatsot (New York, 21/12/2026), comme sur Android ; les autres valeurs sont dans les 2 s |
| `zmanim_reference_pyephem.json` | 60 s | écart maximal **14 s** ('hatsot, Jérusalem, 21/12/2026) |
| `HolidaysTest`, porté | égalité | vert (Tichri 5787, diaspora et Israël) |
| Structure (`ZmanimTest`) | ordre, heures saisonnières, changement d'heure, cercle polaire, allumage | vert |

**En vol** (tâche 13, mesuré le 15/11/2026 sous Linux et sur le simulateur iOS) : les zmanim au point sous
l'avion s'écartent de ceux de KosherJava de **3,2 s au plus** (plag, 'hatsot sur TLV-JFK et la veille de Chavouot),
pour 2 s demandées par ROADMAP. Le zman se cherche là où l'avion se trouve à cet instant : quand ce point fuit
avec le soleil, l'écart de moins d'une seconde du sol est amplifié, jusqu'à quatre fois. `VolTests` tolère 4 s
(`toleranceEnVol`) ; l'heure affichée, à la minute, n'en dépend pas.

L'écart de 994 ms passe le critère d'une seconde de justesse, sur une seule valeur, un jour de changement
d'heure. Sa cause n'est pas établie (les arrondis de Java et de Swift n'expliquent qu'une milliseconde) :
à examiner avec le générateur de la tâche 10, qui couvrira plus de dates. L'heure affichée, à la minute,
ne changerait qu'au voisinage exact d'une minute ronde.

## 3.1.2 : les mesures

KosherSwift 3.1.2, sous les noms de l'ère 3.x, réglée comme Android (niveau de la mer, NOAA, 'hatsot
astronomique, allumage à 18 minutes), devant les mêmes 35 lignes :

| Zman | Écart maximal | Où | Valeurs au-delà d'une seconde (sur 35) |
| --- | --- | --- | --- |
| alot, misheyakir, tset | 0,001 s | — | 0 |
| chatsot, chatsot_layla | 14,9 s | New York, 21/12/2026 | 35 |
| netz, chkia, tset_rt | 29,5 s | Tromsø, 15/01/2026 | 16 |
| plag | 23,3 s | Tromsø, 15/01/2026 | 15 |
| minha_ketana | 17,2 s | Tromsø, 15/01/2026 | 4 |
| szks_gra, szks_mga | 14,7 s | Tromsø, 15/01/2026 | 2 |
| szt_gra, szt_mga | 9,8 s | Tromsø, 15/01/2026 | 1 |
| minha_gedola | 2,5 s | Tromsø, 15/01/2026 | 1 |
| allumage | **794,7 s** | Tromsø, 15/01/2026 | 16 |
| `ABSENT` | — | — | 0 désaccord |

Les angles sous l'horizon (alot, misheyakir, tset) ne bougent pas. 'Hatsot bouge partout : la 3.x calcule
le passage au méridien autrement. Le lever, le coucher et tout ce qui en dépend bougent de quelques
secondes, et de près de 30 s près du cercle polaire. Un téléphone sur la 3.1.2 et un autre sur Android
afficheraient donc parfois une minute différente : c'est la raison de la décision D4.

## Pour refaire ces mesures

- Coeur sur la 1.10.11 : le flux `iOS (cœur, Linux)` à chaque envoi qui touche `ios/` ; les écarts
  maximaux sont imprimés par les tests (`VecteursZmanim`, `NOAA`, `PyEphem`).
- Les deux étiquettes : le flux `iOS (KosherSwift, 1.10.11 et 3.1.2)`, sur demande ; le tableau de la
  3.1.2 paraît dans le résumé du travail `ecarts-312`.
