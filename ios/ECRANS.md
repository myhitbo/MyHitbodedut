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
Et regarder l'écran : `ios-captures.yml` lance l'app sur le simulateur et la photographie (« Les captures », plus bas).

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
- Les grands écrans (`Ecrans/GrandEcran.swift`, `Vues/GrandEcranVue.swift`) : la racine écarte le contenu des
  bords (`margesLarges`, les marges de values-w600dp à w1200dp d'Android) ; un écran long se coupe en deux moitiés
  dans `DeuxColonnes(espacement:)`, côte à côte sur l'iPad quand la place entre les marges en tient deux, l'une
  sous l'autre sinon (au point près comme une `VStack(alignment: .leading)` du même espacement : l'iPhone ne
  change pas). On coupe là où les hauteurs s'équilibrent, en gardant l'ordre de lecture.
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
présentation, le bravo, la note, les marque-pages, l'ajout de temps). Une route dont l'écran n'est pas encore porté est
retirée sans rien ouvrir. Une vue qui pousse ses propres valeurs (`BibliothequeRoute`, `TehilimRoute`) pose leur
`navigationDestination` elle-même : la pile, typée-effacée, les accepte.

Les modèles partagés (le magasin, la séance en cours, sa musique et son mini-lecteur, l'accueil et celui des
versions, les Livres, le Chemin, Zmanim, les réglages) sont
construits une fois par `ios/App/ModelesApp.swift`, sur le magasin des fichiers du dossier de l'app
(`PersistanceFichiers`, l'acteur `Depot`) ; les autres, à l'ouverture de leur écran, gardés le temps de l'écran par
`Garde` (Racine.swift) : la destination de la pile est recalculée à chaque dessin, le modèle ne doit pas l'être. Les
services du système ont leurs adaptateurs dans `ios/App/Services/` (notifications, icône, musique et ambiance, lecture
du billet du vol par Vision ; la position par CoreLocation et la boussole par CoreMotion, `Lieu.swift`,
`Boussole.swift` ; le planificateur des notifications posé dans le centre d'iOS et les répercussions des réglages,
`Notifications.swift` ; la Live Activity, `Activite.swift` ; Temps d'écran, `TempsEcran.swift` ; le code du téléphone par
LocalAuthentication, `CodeDuTelephone.swift` ; les alarmes d'AlarmKit de la minuterie système, `Minuterie.swift`).

Le verrou du journal (VerrouJournal.kt) est un modèle partagé d'`Ecrans`, `VerrouJournal`, que `ModelesApp` construit
une fois sur le code du téléphone et distribue : la racine pose `.verrouJournal(_:)` (Vues/VerrouJournalVue.swift) sur
l'écran du journal (couvert jusqu'au code, refermé à l'arrière-plan : `JournalVerrouille`) ; la fabrique des notes le
donne à `JournalNoteModele`, que `JournalNoteVue` couvre tant qu'une note déjà écrite attend le code (le journal ouvre
les siennes sans lui) ; `ReglagesModele.verrouJournal` garde l'export et l'interrupteur ; `AccueilVersionModele.verrou`
tait les notes des accueils. Tout ce qui montre ou emporte le texte du journal passe par lui.

Ce qui vient d'hors de l'app passe par une adresse « myhitbodedut:// » (`LienApp`, Ecrans, testé sous Linux) : les
widgets et la Live Activity l'ouvrent (`onOpenURL`), une notification la garde dans son `userInfo`. Le délégué des
notifications (posé dès le lancement par `DelegueApp`) et `onOpenURL` la confient à `Aiguillage`, que la racine vide
une à une (`GestesExterieurs`, `ios/App/Gestes.swift`) : l'écran demandé s'ouvre sur le Jour, « Plus tard » reporte
le rappel, « Terminer maintenant » clôt la séance. Le même modificateur fait repasser le planificateur des
notifications (`PlanificateurNotifications`, sur `PlanNotifications`) et redessiner les widgets au retour au premier
plan, en partant en arrière-plan, au début et à la fin d'une séance.

Les widgets (`ios/Widgets`) lisent le journal et les réglages dans le conteneur du groupe d'apps (`Depot`, en lecture),
calculent avec Coeur (`Chronologies`, `Store`, `DirectionJerusalem`) et traduisent avec les catalogues de l'app
(copiés dans l'extension ; la langue de l'app est retenue dans les préférences du groupe). `ios/Widgets/Commun` est
compilé dans l'app et dans l'extension : le dossier du groupe, les genres des widgets, les attributs de la Live
Activity et `TerminerSeanceIntent`.

La barrière (tâches 27 et 28) : la règle est dans `Barriere` (l'instantané, la boîte, `PlanBouclier` pour le visage et
les boutons du bouclier, `Planification` pour les rendez-vous et les magasins), que l'app et les trois extensions
partagent ; `Coeur` remplit l'instantané (`EtatBarriere`). L'app tient `TempsEcranApp` (`App/Services/TempsEcran.swift`,
un seul objet pour `TempsEcran`, `ReglagesBarriereSysteme` et `BarriereSysteme`, vide dans la construction
SANS_BARRIERE) : à chaque changement du journal ou des réglages et à chaque retour au premier plan, il verse la boîte au
journal, réécrit `barriere/etat.json`, met les magasins d'accord et refait les rendez-vous. `App/Services/TempsEcranCommun.swift`
(magasins, sélection, `DeviceActivitySchedule`) est compilé aussi dans `Surveillance` et `BouclierAction`. Les écrans de
la barrière et la dédicace passent par une seule route de la pile, `Ecran.barriere` (`App/Barriere/BarriereEcrans.swift`),
le sélecteur d'Apple et `Label(jeton)` restant dans l'app, autour de `ChoixApplicationsVue`.

La langue de l'app est la première des langues préférées qu'elle livre (`Traducteur.langueDuTelephone`) ; la
racine pose `\.locale` (l'arabe est `ar-TN`) et `\.layoutDirection` (l'hébreu et l'arabe de droite à gauche). Le
traducteur lit les deux catalogues (`Traducteur(catalogues:)`) : celui d'Android, puis les chaînes propres à iOS
(`ios.xcstrings`), si bien qu'un `Libelle` d'une clé d'iOS se résout comme les autres.

## Les captures : l'app lancée pour de vrai

La CI qui compile ne lance pas l'app ; `.github/workflows/ios-captures.yml` (macOS, une quarantaine de minutes) la
lance sur le simulateur et la photographie. Il part à la main seulement (« Run workflow » sur la branche, ou l'API :
`workflow_dispatch`, entrées `langues`, `ecrans`, `passes`, `audit`), jamais à chaque envoi. Deux lancements aux
entrées différentes tournent ensemble (le groupe de concurrence les porte) : une capture complète se partage, par
exemple, entre la passe « iphone » des cinq langues et les passes « sombre grand ipad paysage ».

- **Ouvrir un écran sans le toucher** : lancée avec `-capture <écran>`, l'app s'ouvre d'elle-même sur cet écran
  (`ios/App/Captures.swift` : l'onglet, puis la pile, puis la feuille, par deux crochets, dans `ModelesApp.charger`
  et `Racine`) ; avec `-captureDemo`, sur le journal de démonstration (`Ecrans/Demonstration.swift`, celui des
  captures d'Android : douze jours de suite, des notes, la présentation vue, une ville par langue), tenu en
  mémoire. Sans ces arguments, rien ne change. Un écran nouveau
  s'ajoute à `Captures.ecrans`, au `switch` de `Captures.ouvrir`, et à la liste du script. Ce qu'un toucher
  ouvrirait passe par `LectureCaptures` (Ecrans) : « chapitres » ouvre la liste des 1 048 chapitres du plus long
  livre ; tout écran de lecture suivi de « -barre » (« halakha-barre », « source-barre », « lecteur-barre »…),
  demandé à la main dans l'entrée `ecrans`, s'ouvre sa barre de lecture dépliée.
- **Le ciel à heure fixe** (24/11) : « ciel-<clé> » ouvre le Jour et « serenite-<clé> » l'accueil Sérénité, le ciel
  au soleil que nomme la clé, sans lieu (le soleil moyen de `Soleil.parHeure`, levé à 6 h 30, couché à 18 h 30) :
  `m-20`, `m-12`, `m-04`, `m+00`, `m+03`, `m+10`, `m+40` le matin, `s+40` … `s-20` le soir, les heures des captures
  d'Android (captures.py, étape 35 ; `Captures.heuresDuCiel`) ; « ciel-0644 » prend une heure quelconque. Seule
  l'heure du ciel est fixée (`AccueilModele.heureDuCiel`, `AccueilVersionModele.heureDuCiel`), pas celle du journal.
  Pas dans la liste complète : on les demande dans l'entrée `ecrans`, et ils passent alors aussi en sombre, en grand
  et sur l'iPad (le script les compte parmi ses écrans courts). Le ciel reste animé pendant la capture, comme sur
  Android.
- **Le script** (`tools/captures_ios/capturer.sh`) : pour chaque langue (fr, en, he, es, ar-TN, par
  `-AppleLanguages` et `-AppleLocale`, le fuseau de la ville de la démonstration par `SIMCTL_CHILD_TZ`) et chaque
  écran, il lance l'app, attend qu'elle dise « CAPTURE PRETE » sur sa sortie d'erreur (l'écran ouvert, sans
  animation), photographie (`simctl io screenshot`, la barre d'état fixée à 9:41). Puis les
  passes « sombre » (fr, he), « grand » (Dynamic Type `accessibility-extra-large` ; fr, ar-TN) et « ipad » (fr,
  he), sur une partie des écrans.
- **Couché** : `simctl` ne sait pas tourner le simulateur, ni l'app le demander au simulateur
  (`requestGeometryUpdate` y est sans effet) ; la passe « paysage » passe donc par le test d'interface
  (`testCapturesCouchees`, `XCUIDevice.orientation`), sur l'iPhone et l'iPad, quelques écrans en fr et he ; ses
  images (l'écran de l'appareil debout, tourné d'un quart de tour par `sips`), nommées
  `paysage-ipad-<langue>-<écran>.jpg` et `paysage-iphone-…`, sont l'artefact « captures-couchees-ios ».
- **Les plantages** : une app qui ne tourne plus après son lancement est un plantage ; son rapport
  (`~/Library/Logs/DiagnosticReports`, résumé par `rapport.py` : l'exception, le message de Swift, le fil fautif),
  sa sortie d'erreur et son journal système vont dans le résumé du travail, qui échoue.
- **L'audit d'accessibilité** : `ios/UITests/AuditAccessibiliteTests.swift` passe `performAccessibilityAudit`
  d'Xcode sur chaque écran (en français), sorte par sorte (le contraste d'abord, les tailles du texte en dernier ;
  cinq essais chacune : l'audit entier ne finissait pas à temps sur le simulateur de la CI) ; chaque défaut, une
  ligne « AUDIT » du résumé, et le travail échoue s'il en reste un. Les faux positifs connus sont tolérés, chacun
  avec sa raison (`tolerance`, lignes « TOLERE ») : ce qui dépasse la zone visible (sous une barre — de
  navigation, d'onglets, ou marquée `barre-bas` comme la barre de départ —, hors de la fenêtre, hors de son
  défilement), un composant inactif, le clavier du système, le texte des demi-feuilles, la grille du calendrier
  (plafonnée à AX1, visualiseur de grand contenu), l'écran voilé sous la fiche d'un trophée, les paragraphes d'une
  liste paresseuse de texte long, un texte qu'aucun élément ne porte ou de plusieurs paragraphes ; un audit
  inachevé (cinq essais, l'audit d'Xcode s'arrêtant au bout de 15 s environ sur le simulateur lent de la CI) n'est
  pas un défaut et se dit à part (« Refaits faute d'avoir fini à temps »). Un défaut nouveau ne se tolère
  qu'avec sa raison, et après l'avoir vu sur les captures « grand ». Relever sans échouer :
  `TEST_RUNNER_AUDIT_RELEVE=1`. L'app y est lancée avec « -cielImmobile » (`CielImmobile`) : le ciel du Jour et de
  Sérénité dans sa pose de repos, comme avec Réduire les animations ; XCTest attend que l'app soit au repos avant
  chaque mesure, ce qu'un ciel animé n'est jamais (le 25/11, l'audit des tailles du texte du Jour ne finissait plus),
  et la pose de repos est la plus exigeante pour le contraste.
- **Les grandes tailles du texte** : aucune police à taille fixe (`tailleSp`, `policeHebraique`, `@ScaledMetric`
  au centième) ; `Vues/Accessibilite.swift` : `lignesAuPlus`/`uneLigne` (la limite de lignes d'Android à la taille
  ordinaire, aucune au-delà), `RangeeAdaptable` (en colonne aux tailles d'accessibilité), `TuileExtensible`,
  `boutonsDeLecture` (les boutons de lecture sous le texte), `hauteursDeFeuille` (feuille entière aux tailles
  d'accessibilité).
- **Les images** : l'artefact « captures-ios » (JPEG réduits à 1 400 points, journaux), posé avant l'audit, dont le
  journal est l'artefact « audit-ios » ; les images sont nommées
  `<langue>-<écran>.jpg`, et `<passe>-<langue>-<écran>.jpg` pour les autres passes. Sans compte GitHub, le lien
  signé de l'artefact se demande par l'API (`actions/artifacts/<id>/zip`, ou l'outil MCP
  `download_workflow_run_artifact`), puis `curl` le télécharge.

## Les libellés et les mesures

`.github/workflows/ios-interface.yml` (macOS, à chaque envoi qui touche ios/, et à la main) compile l'app une fois en
Release pour le simulateur (`build-for-testing`), puis lance sans recompiler (`test-without-building`) :

- **Le poids** : le .app en octets, ses entrées et ses plus gros fichiers dans le résumé ; le travail échoue à
  200 Mo (155,8 Mo le 24/11 au soir).
- **Les libellés** (`ios/UITests/LibellesTests.swift`) : l'accueil, la séance et Cha'harit, en fr, en, he, es et
  ar-TN. Ce que VoiceOver lit est jugé : l'audit des descriptions d'Xcode dans chaque langue, chaque bouton, onglet
  ou champ sans libellé, une clé ou un gabarit non résolus, un symbole nommé, un libellé anglais ou espagnol
  identique au français, un mot latin en hébreu ou en arabe. Ce qu'un porteur de libellé contient (l'icône d'un
  bouton, les images d'un onglet, un texte regroupé) est lu par lui et n'est pas jugé à part : l'arbre d'un test
  d'interface le montre, VoiceOver non. Chaque défaut, une ligne « DEFAUT » du résumé, et le travail échoue ; un
  faux positif ne se tolère qu'avec sa raison (`tolerance`, lignes « TOLERE »). Relever sans échouer :
  `TEST_RUNNER_LIBELLES_RELEVE=1`.
- **Les mesures** (`ios/UITests/MesuresTests.swift`) : lancée avec « -mesures », l'app écrit ses temps
  (`ios/App/Mesures.swift`) dans le fichier que le test lui donne (MESURES_FICHIER) : chaque étape du lancement
  depuis le démarrage du processus (main, fin d'init, modèles, première image de l'accueil, accueil prêt) avec son
  temps de calcul, l'ouverture d'un texte du lecteur (`LectureModele.mesure`), et avec « -mesuresDefilement » le
  défilement du texte ouvert, que l'app fait elle-même en comptant ses images (`DefilementMesure`) ; le plus long
  livre s'ouvre par « -capture plus-long-livre ». Un test qui mesure le défilement ne touche pas l'écran : chaque
  geste d'un test d'interface fait photographier tout l'arbre d'accessibilité sur le fil principal de l'app.
  Au simulateur de la CI, rien n'est jugé sur les temps : ils sont rapportés ; les seuils (400 ms, aucune image
  perdue) se vérifient sur un iPhone, depuis Xcode, où `testDefilementSignposts` et `testDefilementAccrocs`
  (`XCTHitchMetric`, au doigt) ont leur sens.
- **Le résumé et les journaux** : les lignes MESURE, les mesures d'XCTest (lues dans le paquet de résultats par
  `xcresulttool`), les défauts et les tolérés ; l'artefact « interface-ios » garde les journaux et les fichiers
  des mesures.

## Style

Celui de `Coeur` : identifiants et commentaires en français, un commentaire dit le pourquoi ou renvoie au fichier
Kotlin d'origine, aucune dépendance nouvelle, Swift 6 sans avertissement.
