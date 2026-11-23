# Écrire un écran de l'app iOS

Pour qui écrit un écran de l'app (tâches 14 à 30 de `ROADMAP.md`). Les règles viennent de `Coeur` (voir
`Paquets/Coeur/PORTER.md`) ; cette notice dit comment un écran s'en sert, et ce qui juge son code.

## Les quatre juges

1. **La CI Linux** (`ios-coeur.yml`) construit et teste `Coeur`, `Barriere` et `Ecrans` : les modèles d'écran.
2. **La passe rapide des vues** (`ios-vues.yml`, macOS, une dizaine de minutes) compile seulement : le paquet avec
   toutes ses vues (`COEUR_TOUTES_VUES=1` compile aussi celles que Package.swift tiendrait en chantier), puis l'app ;
   chaque erreur est listée dans le résumé du travail, et le journal joint. C'est elle qu'on attend entre deux
   corrections de vues.
3. **La CI macOS** (`ios-app.yml`, gratuite depuis que le dépôt est public, une quarantaine de minutes) engendre le
   projet par XcodeGen, compile l'app avec le vrai Xcode pour le simulateur, et lance les tests du paquet sur un
   iPhone simulé.
4. **L'écran d'Android**, `android/app/src/main/java/com/myhitbodedut/<Écran>Activity.kt` et son layout : la
   spécification de ce que l'écran montre et fait. Rien n'est modifié sous `android/`.

Il n'y a pas de compilateur Swift dans la session de travail : la CI tranche. Lire son journal, pas son verdict.

## Où va quoi

| Quoi | Où | Jugé par |
| --- | --- | --- |
| Une règle (calcul, texte, table) | `Paquets/Coeur/Sources/Coeur` | Linux et simulateur, avec les vecteurs de l'oracle |
| Le modèle d'un écran : son état, ses actions, ce qu'il affiche | `Paquets/Coeur/Sources/Ecrans/<Écran>Modele.swift` | Linux et simulateur (`Tests/EcransTests`) |
| La vue SwiftUI de l'écran | `Paquets/Coeur/Sources/Vues/<Écran>Vue.swift` | Xcode (macOS) |
| Ce qui parle au système (notifications, son, lieu, Temps d'écran, Live Activity, widgets) | un protocole dans `Ecrans/Services.swift`, son adaptateur dans `ios/App/Services/` | Xcode ; un faux dans les tests |
| Le point d'entrée, les onglets, l'injection des services | `ios/App/` | Xcode |

## Le modèle d'écran

- `@MainActor @Observable public final class <Écran>Modele` : ses propriétés stockées sont l'état de l'écran ;
  ses propriétés calculées, ce qu'il affiche ; ses méthodes, ses actions. Toute la logique y est, la vue n'en a
  aucune : un `if` qui décide quoi montrer appartient au modèle.
- Il reçoit ce dont il dépend : le `Magasin` (journal et réglages), les contenus (`ContenusApp`), l'horloge
  (`Horloge`), les services (`Services.swift`). Ces modèles communs sont dans `Ecrans`, avec un double pour les
  tests et les aperçus : `PersistanceEnMemoire`, `HorlogeFixe`, `FauxNotificateur`…
  Jamais `Date()`, `Calendar.current`, `TimeZone.current` ni `Bundle.main` en direct : l'heure, le fuseau et les
  fichiers passent par ce qui est injecté, pour que le test les fixe.
- Les textes sont des `Libelle` (clé du catalogue, arguments) : le modèle ne met rien en forme.
- Son test (`Tests/EcransTests/<Écran>ModeleTests.swift`) porte les règles de l'écran Android qui se vérifient
  par des valeurs : ce qui s'affiche dans chaque état, ce que fait chaque action. `@MainActor` sur la suite.

## La vue

- `public struct <Écran>Vue: View`, qui lit le modèle et appelle ses actions. Mise en page, couleurs (jetons de
  la `Palette`), polices, accessibilité. SwiftUI d'iOS 26.5 ; aucune dépendance.
- Les couleurs : un jeton, jamais une couleur écrite (`Vues/Apparence.swift`) : `.foregroundStyle(Teinte(.ink))`,
  `.background(Teinte(.paper))`, résolus d'après la palette et le mode de l'écran. Les composants communs
  (`Vues/Composants.swift`) : `Carte`, `.buttonStyle(.principal)` et `.secondaire`, `Pastille`, `Etiquette`,
  `LigneSection`, `LigneHoraire` ; une illustration d'Android : `Illustration("char_welcome", libelle:)` ou
  `Illustration(decorative:)` ; une police des textes saints : `.policeHebraique(police, taille:)`.
- Les chaînes : `Text("cle")` pour une clé simple du catalogue (les clés sont celles d'Android), et pour un
  `Libelle` l'aide commune de `Vues` (`TexteLibelle(libelle)`, ou `Text(libelle, traducteur:)` avec
  `@Environment(\.traducteur)`), qui le résout dans la langue de l'app par le `Traducteur` d'`Ecrans`. Une
  chaîne propre à iOS : `Text("cle", tableName: "ios")` (`Ressources/Chaines/ios.xcstrings`).
- L'hébreu de droite à gauche vient de l'environnement (`layoutDirection`) ; une image ou un sens qui doivent se
  retourner le disent explicitement.
- Pas d'image pendant la prière (règle d'Android) ; « Réduire les animations » respecté.
- Un champ, un interrupteur, une feuille qui suivent le modèle : une propriété calculée lue et écrite, dans une
  extension du modèle sous `Vues` (`Vues/Liaisons.swift`, ou au bas de la vue), prise par
  `Bindable(modele).propriete` ; son `set` appelle l'action du modèle. Jamais `Binding(get:set:)` avec des
  fermetures `@MainActor` : Swift 6.3.3 plante en produisant leur conversion vers les paramètres
  `@isolated(any) @Sendable` de `Binding` (IRGen, « report_size_overflow »). Un paramètre se passe par un indice
  (`Bindable(modele)[dynamicMember: \ReglagesModele.[interrupteur: quel]]`).
- Une signature de SwiftUI en doute se vérifie à la source :
  `python3 tools/swiftui_papier/declarations.py swiftui/<symbole> --profondeur 3` (la documentation d'Apple).

## La navigation

Trois onglets, comme la barre d'Android depuis la refonte du 13/11 (`Ecrans/Onglets.swift`) : Le Jour, Les Livres,
Le Chemin, chacun avec sa pile (`NavigationPath`). Zmanim et les réglages ne sont plus des onglets : l'en-tête du
Jour les ouvre (`AccueilModele.entete`, `ouvrirZmanim`, `ouvrirReglages`), dans la pile du Jour. La barre de départ
(`BarreDepart`) est au bas des trois racines, et son volet posé une fois sur les onglets (`feuilleDepart`), comme la
fiche des trophées neufs (`feteDesTrophees`, Vues/TropheeFeteVue.swift), qui voile aussi la barre des onglets.

Ces trois onglets sont l'accueil de la version Classique. Les trois autres versions de l'app (`VersionApp` :
Sérénité, Bento, Pile) ont chacune le leur (`AccueilVersionVue` : `SereniteVue`, `BentoVue`, `PileVue`, sur le
modèle partagé `AccueilVersionModele`), que la racine pose à la place des onglets, avec la seule pile du Jour : sur
Android, l'activité de la version remplace MainActivity et sa barre (VersionApp.rediriger). Leurs entrées poussent les
mêmes écrans (`AccueilVersionRoute`). Choisir une version vide les piles et montre aussitôt son accueil
(VersionApp.appliquer) ; seul à l'écran, cet accueil impose son mode clair ou sombre (`fondSombre`), pour que la barre
d'état reste lisible sur ses couleurs fixes. Au retour de la présentation, l'accueil Classique propose le choix de la
version tant qu'aucune n'est retenue (`AccueilRoute.choixVersion`, MainActivity.onResume).

Un modèle ne pousse rien lui-même : il ajoute une route à sa file (`routes`), ou la vue reçoit une fermeture
`ouvrir(route)` ; la racine (`ios/App/Racine.swift`) traduit la route en `Ecran`, qu'elle pousse dans la pile de
l'onglet choisi (les trois piles partagent leurs destinations), ou en feuille par-dessus (`Pardessus` : la
présentation, le bravo, la note, les marque-pages). Une route dont l'écran n'est pas encore porté est retirée sans
rien ouvrir. Une vue qui pousse ses propres valeurs (`BibliothequeRoute`, `TehilimRoute`) pose leur
`navigationDestination` elle-même : la pile, typée-effacée, les accepte.

Les modèles partagés (le magasin, la séance en cours, sa musique et son mini-lecteur, l'accueil et celui des
versions, les Livres, le Chemin, Zmanim, les réglages) sont
construits une fois par `ios/App/ModelesApp.swift`, sur le magasin des fichiers du dossier de l'app
(`PersistanceFichiers`, l'acteur `Depot`) ; les autres, à l'ouverture de leur écran, gardés le temps de l'écran par
`Garde` (Racine.swift) : la destination de la pile est recalculée à chaque dessin, le modèle ne doit pas l'être. Les
services du système ont leurs adaptateurs dans `ios/App/Services/` (notifications, icône, musique et ambiance, lecture
du billet du vol par Vision ;
Temps d'écran, Live Activity et répercussions des réglages sont encore des adaptateurs vides, qui le disent).

La langue de l'app est la première des langues préférées qu'elle livre (`Traducteur.langueDuTelephone`) ; la
racine pose `\.locale` (l'arabe est `ar-TN`) et `\.layoutDirection` (l'hébreu et l'arabe de droite à gauche). Le
traducteur lit les deux catalogues (`Traducteur(catalogues:)`) : celui d'Android, puis les chaînes propres à iOS
(`ios.xcstrings`), si bien qu'un `Libelle` d'une clé d'iOS se résout comme les autres.

## Style

Celui de `Coeur` : identifiants et commentaires en français, un commentaire dit le pourquoi ou renvoie au fichier
Kotlin d'origine, aucune dépendance nouvelle, Swift 6 sans avertissement.
