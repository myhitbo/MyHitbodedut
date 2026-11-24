# Écrire un écran de l'app iOS

Pour qui écrit un écran de l'app (tâches 14 à 30 de `ROADMAP.md`). Les règles viennent de `Coeur` (voir
`Paquets/Coeur/PORTER.md`) ; cette notice dit comment un écran s'en sert, et ce qui juge son code.

## Les trois juges

1. **La CI Linux** (`ios-coeur.yml`) construit et teste `Coeur`, `Barriere` et `Ecrans` : les modèles d'écran.
2. **La CI macOS** (`ios-app.yml`, gratuite depuis que le dépôt est public) engendre le projet par XcodeGen,
   compile l'app avec le vrai Xcode pour le simulateur, et lance les tests du paquet sur un iPhone simulé.
3. **L'écran d'Android**, `android/app/src/main/java/com/myhitbodedut/<Écran>Activity.kt` et son layout : la
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
- Une signature de SwiftUI en doute se vérifie à la source :
  `python3 tools/swiftui_papier/declarations.py swiftui/<symbole> --profondeur 3` (la documentation d'Apple).
- Pièges vus par Xcode 26.6 : `GraphicsContext.Shading.linearGradient`/`radialGradient` prennent un `Gradient`, pas un
  `AnyGradient` ; `alert(item:)` ne prend qu'une `Alert` (pour un dialogue moderne : `alert(_:isPresented:presenting:actions:)`) ;
  un `Binding<Double>(get:set:)` fait planter le compilateur (thunk `@isolated(any)`) : pour un `Slider`, une copie `@State`
  tenue à jour par `onChange`.

## Style

Celui de `Coeur` : identifiants et commentaires en français, un commentaire dit le pourquoi ou renvoie au fichier
Kotlin d'origine, aucune dépendance nouvelle, Swift 6 sans avertissement.
