# État du portage iOS — 24/11/2026 (mis à jour le soir)

L'app iOS est écrite, câblée et verte dans la CI. Elle **compile avec le vrai Xcode** (26.6, iOS 26.5) et **passe ses tests**, sous Linux et sur le simulateur iOS, au commit 28e8b48. Personne ne l'a encore lancée sur un iPhone : il faut pour cela le compte Apple (voir « Ce qui vous attend »).

## Ce qui est fait

| Couche | Où | Contenu | Juge |
| --- | --- | --- | --- |
| Règles | `Paquets/Coeur/Sources/Coeur` | Tout le Kotlin de règles d'Android : calendrier juif et zmanim, siddour du jour, Tehilim, Tikoun, halakha, hilloulot, recherche, pratique (Store), paliers et trophées, vol et géographie, planificateur de notifications, chronologies des vignettes, sauvegarde et fusion | 866 tests, rejouant les réponses du vrai Kotlin (l'oracle JVM, `tools/vecteurs_ios`) |
| Barrière | `Paquets/Coeur/Sources/Barriere` | État partagé avec les extensions, les treize états, report, fenêtre de nuit, boîte d'événements | 21 tests |
| Modèles d'écran | `Paquets/Coeur/Sources/Ecrans` | Toute la logique des écrans d'Android : accueil, séance, bravo, note, journal, parcours, textes, siddour et lecteur, Tehilim, Tikoun, Tefilot, bibliothèque, 'hizouk, halakha, hilloulot, recherche, Zmanim, calendrier, lieu, partage, boussole, musique, paliers, présentation, conseils, réglages, vol ; persistance sur fichiers | 748 tests (Linux et simulateur) |
| Vues | `Paquets/Coeur/Sources/Vues` | Les vues SwiftUI de tous ces écrans, sans logique, d'après les écrans Android | compilées par Xcode |
| App | `App`, `App/Services` | Cinq onglets, navigation entre tous les écrans, présentation au premier lancement ; services système (notifications, lieu, cap, son, fichiers, réseau du vol, lecture du billet) | compilée par Xcode |

## Écarts voulus

- **Les tables** (`tables.json`) jugent les tables écrites en Swift au lieu d'être lues par l'app (ROADMAP tâche 6).
- **Le vol** : en vol, les zmanim sont jugés à 4 s (KosherSwift amplifie en vol son écart au sol, mesuré à 3,2 s au pire).
- **La CI macOS** tourne sur un runner Intel (`macos-26-intel`) : depuis le 16/11/2026, les runners arm64 de GitHub ne prennent plus les travaux. L'app y est compilée pour le simulateur arm64, et les tests du paquet tournent sur le simulateur x86_64 sans la cible des vues. Swift 6.3.3 plante en effet sur les `Binding(get:set:)` à fermetures `@MainActor` : les vues passent par `Binding.passerelle` (`Vues/Liaison.swift`, voir `ECRANS.md`).
- **Les catalogues de chaînes** : Xcode compile une copie (`Ressources/Catalogue`) où deux pluriels sans nombre (« jour » / « jours ») deviennent des chaînes simples ; le Traducteur lit le catalogue fidèle à Android.

## Ce qui n'est pas fait

- **La barrière (Temps d'écran)** : l'autorisation et le choix des applications (FamilyActivityPicker) sont écrits ; le bouclier et la surveillance demandent votre compte Apple et les trois extensions (ROADMAP tâches 4, 27, 28). Sans l'entitlement Family Controls accordé par Apple, iOS refuse l'autorisation, et l'écran le dit.
- **La Live Activity, les widgets de la série et des zmanim, l'écran des rappels** : à écrire (tâches 17, 19, 25). Les règles (chronologies, planificateur) sont prêtes. Le widget de la boussole est fait : il ouvre la boussole par `myhitbodedut://boussole`.
- **Deux entrées mènent encore à « Bientôt »** : l'aperçu du bouclier (il dépend des extensions de la barrière) et l'écran de relecture (un outil de débogage d'Android). La dédicace, l'aide à la concentration (avec son filtre de concentration qui masque le décompte) et le choix des applications sont faits.
- **Aucun test d'interface ni capture** encore (critères visuels des tâches 14 à 26) ; la galerie de la tâche 14 est à faire.
- **Les chaînes neuves propres à iOS** (`Ressources/Chaines/ios.xcstrings`, `InfoPlist.xcstrings`) sont en `needs_review` : à relire.

## Ce qui vous attend (préalables de `ROADMAP.md`)

- **P1, P2** : le compte Apple Developer et une clé d'API App Store Connect, pour signer, installer sur un iPhone et envoyer à TestFlight (`SIGNATURE.md`).
- **P3** : la demande de l'entitlement Family Controls de distribution, pour la barrière.
- **P7** : une sauvegarde réelle exportée d'Android, pour vérifier qu'elle se lit sans perte (dernier critère de la tâche 7).
