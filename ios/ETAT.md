# État du portage iOS — 25/11/2026

L'app iOS est écrite, câblée et verte dans la CI. Elle **compile avec le vrai Xcode** (26.6, iOS 26.5) et **passe ses tests**, sous Linux et sur le simulateur iOS, au commit d895864, extensions comprises. Personne ne l'a encore lancée sur un iPhone : il faut pour cela le compte Apple (voir « Ce qui vous attend »).

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

## Écrit depuis le 24/11

- **La barrière** : les trois extensions (surveillance DeviceActivity qui pose et lève les boucliers des magasins nommés, bouclier à trois visages, actions « Commencer », « Déjà faite », « Plus tard »), l'état écrit pour elles à chaque changement, la relève de leur boîte, l'aperçu du bouclier et le choix des applications. Règles communes dans `Barriere/Pilotage`, testées sous Linux.
- **Les rappels** : l'écran des heures (depuis les Textes et une ligne des Réglages, propre à iOS) et le diagnostic des notifications en attente.
- **Les widgets** : la série, les zmanim (petit, moyen, grand, écran verrouillé) et la boussole ; la chronologie se calcule dans l'extension avec Coeur, d'après la copie du journal et des réglages que l'app dépose dans le groupe d'apps.
- **La Live Activity de la séance** : écran verrouillé et Dynamic Island, décompte (masqué par le filtre de concentration), « Terminer ».
- **La présentation** : l'écran « Je viens d'Android » (import de la sauvegarde, série retrouvée).
- **Les réglages** : la dédicace, l'aide à la concentration (et son filtre de concentration qui masque le décompte).

## Ce qui n'est pas fait

- **Éprouver sur un iPhone** tout ce qui dépend du compte Apple : la barrière (entitlement Family Controls, recettes R2 et R4), la Live Activity, le groupe d'apps des widgets (sans lui, ils montrent un journal neuf et « Choisir le lieu »).
- **Le reste de la tâche 17** : la notification de fin programmée au début de la séance, l'option « minuterie système ».
- **L'écran « Journal de la barrière »** (`SystemeBarriere.historique()` fournit déjà les 50 derniers événements).
- **Une entrée mène encore à « Bientôt »** : la relecture, un outil de débogage d'Android.
- **Aucun test d'interface ni capture** encore (critères visuels des tâches 14 à 26) ; la galerie de la tâche 14 est à faire.
- **Les chaînes neuves propres à iOS** (`Ressources/Chaines/ios.xcstrings`, `InfoPlist.xcstrings`) sont en `needs_review` : à relire.

## Ce qui vous attend (préalables de `ROADMAP.md`)

- **P1, P2** : le compte Apple Developer et une clé d'API App Store Connect, pour signer, installer sur un iPhone et envoyer à TestFlight (`SIGNATURE.md`).
- **P3** : la demande de l'entitlement Family Controls de distribution, pour la barrière.
- **P7** : une sauvegarde réelle exportée d'Android, pour vérifier qu'elle se lit sans perte (dernier critère de la tâche 7).
