# Portage iOS natif : état des lieux et plan

Rédigé le 13/11/2026, sur l'état du dépôt à `0274b05`. Ce fichier existe pour que le portage ne vive pas dans une conversation.

**Cible** : Swift 6, SwiftUI, iOS 26, iPhone d'abord, iPad ensuite. **Contrainte** : pas de Mac ; tout se compile, se teste et se signe dans le cloud ; l'essai réel se fait sur l'iPhone d'un ami. **Ambition** : la qualité d'un Apple Design Award, et l'esprit de l'app Android.

Rien n'est modifié sous `android/`. Ce document ne contient pas de code d'application : il dit quoi porter, comment, et ce qui ne se portera pas tel quel. La suite ordonnée des tâches est dans `ROADMAP.md`.

## En bref

1. **Tout se porte, sauf une chose** : activer « Ne pas déranger » depuis l'app (§ 2.2.6).
2. **La barrière change de nature et garde ses trois issues.** iOS ne laisse ni voir quelle app est ouverte ni dessiner par-dessus ; il offre un bouclier que le système affiche. Depuis iOS 26.4 ce bouclier a un sous-menu, depuis 26.5 il ouvre notre app : « Commencer », « Je l'ai déjà faite », « Plus tard » y tiennent (§ 2.1). Deux réserves : cela se prouve seulement sur un vrai iPhone, et Apple doit accorder un entitlement, **à demander tout de suite**.
3. **Il n'y a plus de service.** La séance devient deux instants enregistrés et une Live Activity ; les rappels se programment d'avance, sous une limite de 64 (§ 2.2).
4. **Données** : des fichiers `Codable`, pas SwiftData. La sauvegarde d'Android se lit telle quelle. Les applications bloquées ne migrent pas, et l'export d'Android oublie le journal enrichi (§ 3).
5. **Contenus** : ils restent dans Android ; un outil les exporte à chaque construction (§ 4). Environ 120 Mo.
6. **Une seule dépendance** : KosherSwift, **à l'étiquette 1.10.11** et non à la 3.1, parce qu'Android est sur KosherJava 2.5.0. Les vecteurs existants (chaque jour de septembre 2025 à décembre 2030, en diaspora et en Israël) sont le juge (§ 5).
7. **Droits** : les accords doivent nommer l'App Store ; le Kitsour Yalkout Yossef entier est le point le plus exposé ; le vol en direct exige le relais (§ 6).
8. **Sans Mac** : le cœur se prouve sur Linux, l'app se construit sur Codemagic, l'iPhone ne sert que quatre fois (§ 7).
9. **Trente tâches**, chacune avec son critère de fin (`ROADMAP.md`).
10. **Quinze décisions** vous reviennent (§ 8).

## Comment ce document a été établi

Les quatre documents de référence, `Store.kt`, les fichiers de la barrière et l'écran des réglages ont été lus ligne à ligne ; les manifestes ont été dépouillés par script. Le reste des sources Kotlin, `tools/` et les ressources ont été lus en entier par des passes de lecture parallèles, qui renvoient aux lignes ; leurs relevés ont été recoupés par sondage. Côté iOS, les points dont dépend la conception ont été vérifiés à la source le 13/11/2026 : documentation d'Apple, sources de KosherSwift, tarifs de GitHub (§ 9). Rien n'a été compilé ni exécuté.

Statuts employés : **Vérifié** (lu à la source), **Constaté** (rapporté par des développeurs, non documenté), **À éprouver** (ne se saura que sur l'iPhone), **Déduit**.

## L'esprit à garder

Ce que l'app Android tient, et que le portage ne doit pas perdre en route :

- **Rien ne sort de l'appareil.** Ni compte, ni mesure d'audience, ni serveur, sauf une fonction éteinte par défaut.
- **Un ralentisseur, pas un verrou.** La barrière se contourne, et c'est voulu.
- **Le temps passé valide la journée**, jamais plus que la durée choisie. Et jamais de reproche : « Pas encore de série », « 'Hazak ! » après un abandon.
- **L'app ne tranche pas.** Chaque horaire nomme sa méthode ; les ajouts du jour sont « indicatifs, le texte fait foi » ; rien n'est retiré d'une prière, seulement replié.
- **Les droits avant le contenu.** Pas de texte intégral sans autorisation, pas de vocalisation d'éditeur sans licence.
- **Trois langues à parité**, l'hébreu de droite à gauche, aucun repli silencieux d'une langue sur une autre.
- **Ce qui est affirmé est tenu par un test.** Les 108 fichiers de tests d'Android sont la spécification ; une bonne part se porte telle quelle.

## 1. Inventaire des fonctions

Une ligne par écran, service, récepteur, widget, règle et réglage. Les fichiers Kotlin sont dans `android/app/src/main/java/com/myhitbodedut/` sauf mention.

**Difficulté**

| Signe | Sens |
| --- | --- |
| ① | Logique pure : portage direct, testable sur Linux avec les cas du test Android ou du site |
| ② | Écran ou API iOS ordinaire |
| ③ | Travail soutenu : dessin ou animation sur mesure, beaucoup de cas, API exigeante |
| ④ | Limite de plateforme : conception différente, **à éprouver sur un vrai iPhone** |
| ✗ | Rien à porter (géré par iOS) ou sans équivalent |

### 1.1 Socle

| Fonction | Source Kotlin | Équivalent iOS | Diff. |
| --- | --- | --- | --- |
| Démarrage : langue, palette, icône | `MyHitbodedutApp.kt` | `@main struct App`, palette dans l'`Environment`, planification au lancement | ② |
| Persistance (deux fichiers : réglages, journal) | `Store.kt` | `actor Depot`, fichiers `Codable` en App Group (§ 3) | ② |
| Export et import de la sauvegarde | `Store.kt:1484-1624`, `SettingsActivity.kt:52-60, 541-592` | `fileExporter` / `fileImporter`, mêmes règles (§ 3.5) | ① |
| Réinitialiser l'application | `Store.kt:191-194`, `SettingsActivity.kt:179-196` | effacer les fichiers, lever les boucliers, annuler les notifications, arrêter la séance | ② |
| Clair, sombre, 6 fonds × 6 accents | `Apparence.kt`, `res/values*/palettes.xml` | 13 jetons de couleur dans l'`Environment`, `preferredColorScheme` ; test de contraste porté de `PaletteTest` | ② |
| Icône qui suit le personnage et l'accent (12 alias) | `IconeLanceur.kt`, manifeste | `setAlternateIconName`, 12 icônes ; **sur geste explicite seulement** : iOS affiche une alerte à chaque changement (§ 2.3) | ② |
| צדיק / צדקת | `Adresse.kt` | énumération | ① |
| Personnage féminin partout (21 correspondances) | `Personnage.kt` | une seule vue `Illustration(.pose)` qui choisit la variante | ① |
| Pose du jour selon le moment | `Character.kt` | fonction pure (jour + sel) | ① |
| Sujets de séance (10, facultatif) | `Theme.kt` | énumération, clés identiques | ① |
| Libellés désignés par clé (`fete_*`, `ajout_*`, `zman_*`) | `Libelles.kt` (généré) | recherche par clé dans le catalogue de chaînes | ① |
| Entrées en cascade, fondus, compteurs | `Effets.kt`, `res/anim`, `res/animator/presse.xml` | transitions SwiftUI, `contentTransition(.numericText)`, « Réduire les animations » | ② |
| Canaux et identifiants de notification | `Notifications.kt` | catégories `UNNotificationCategory`, identifiants fixes par type | ① |
| Liste des autorisations et ce qui manque | `Autorisation.kt`, `Permissions.kt` | notifications, Temps d'écran, localisation ; « batterie » et « démarrage automatique » n'existent pas | ② |
| Explication avant une autorisation sensible | `Divulgation.kt` | écran d'explication avant `requestAuthorization` (même texte, mêmes deux boutons) | ① |
| Reprise après redémarrage, changement d'heure ou de fuseau | `BootReceiver.kt` | pas d'équivalent : les notifications et les boucliers survivent seuls ; recalcul au lancement, par `BGAppRefreshTask` et sur `significantTimeChange` (§ 2.2.2) | ③ |
| Plein écran sous les barres système | `Barres.kt` | zones sûres natives | ✗ |
| Bandeau qui s'efface au défilement (21 écrans) | `BandeauDefilant.kt` | barre de navigation native d'iOS 26 | ✗ |
| Image à hauteur souple | `IllustrationSouple.kt` | mise en page SwiftUI | ✗ |
| Écran de relecture des textes (édition d'essai) | `debug/…/ProofreadActivity.kt` | écran `#if DEBUG`, ou abandon | ② |
| Vitrine des widgets pour les captures | `debug/…/VitrineWidgetActivity.kt` | aperçus et captures en CI | ✗ |

### 1.2 Accueil

| Fonction | Source Kotlin | Équivalent iOS | Diff. |
| --- | --- | --- | --- |
| Écran « Aujourd'hui » (état, série, anneaux, bouton, pastilles, semaine, cartes) | `MainActivity.kt` | `TabView` à 5 onglets réels, `NavigationStack` par onglet | ③ |
| Onglet « Bibliothèque » (recherche, reprise, favoris, entrées) | `MainActivity.kt`, `activity_main.xml:352-651` | onglet avec `searchable` | ② |
| Voile d'ouverture (tsiyoun, hassid, 1,5 s) | `MainActivity.kt:956-1011` | écran de lancement uni `#1E3A30`, puis voile dans l'app, raccourci (§ 2.3) | ② |
| Les trois anneaux : valeurs, paliers de série, marques de fête | `Anneaux.kt` | fonction pure | ① |
| Dessin des anneaux (second tour assombri, sens inversé en hébreu) | `AnneauxDessin.kt` | `Canvas` SwiftUI, partagé avec les widgets | ② |
| Anneaux animés et tactiles (remplissage 900 ms, mise en avant, fête) | `AnneauxView.kt` | `Canvas` + animation, `sensoryFeedback` | ③ |
| Anneaux en grande icône de notification | `AnneauxImage.kt` | pièce jointe image de la notification, ou rien | ② |
| Plaque au centre des anneaux (8 faces, retour après 8 s) | `Plaque.kt`, `MainActivity.kt:467-558` | règle pure + retournement `rotation3DEffect` | ② |
| Meilleure série, moyenne | `Plaque.kt`, `Store.kt:662-665` | fonction pure | ① |
| Série (jours exemptés ni comptés ni cassants) | `Store.kt:643-659` | fonction pure | ① |
| Bande de la semaine, dimanche → samedi | `Store.kt:671-686`, `JaugeSemaine.kt`, `MainActivity.kt:829-897` | règle pure + vue | ② |
| Ajouter du temps à un jour passé | `AjoutTemps.kt` | feuille depuis la bande et le calendrier | ② |
| « Je l'ai faite sans le téléphone » (aujourd'hui ou hier) | `MainActivity.kt:251-287` | même dialogue | ② |
| Bilan « Votre semaine », une fois | `BilanSemaine.kt`, `MainActivity.kt:600-618` | règle pure + feuille | ① |
| Salutation selon l'heure et le prénom | `Salutation.kt` | fonction pure | ① |
| Cartes « Pour cette heure » et Birkat haLevana | `AccueilMoment.kt`, `JourAffiche.momentDuSiddour` | règle pure + cartes | ② |
| Cartes « changement prochain dans la prière » (6 types, 3 jours avant) | `RappelsTefila.kt` | règle pure + cartes | ② |
| Source du jour (même paragraphe pour tous) | `SourceDuJour.kt` | règle pure : même ordre des candidats, même indice | ② |
| Carte de 'hizouk « relance » après une série rompue | `MainActivity.kt:747-762`, `ChizukCard.kt` | carte | ② |
| Prochain trophée, boutons Trophées et Mon parcours | `MainActivity.kt:565-581` | liens | ① |
| Présentation en 7 écrans, versionnée | `Onboarding.kt`, `OnboardingActivity.kt` | `TabView` paginé ; premier écran : « Je viens d'Android » (§ 3.8) | ② |
| Dix conseils | `Tips.kt`, `TipsActivity.kt` | liste | ① |
| Demander une dédicace (compose un courriel) | `Dedicace.kt` | `openURL("mailto:")` | ① |

### 1.3 Séance, journal, musique

| Fonction | Source Kotlin | Équivalent iOS | Diff. |
| --- | --- | --- | --- |
| Écran de séance (durées, sans durée, Parler / Écrire / Prier / Une question) | `SessionActivity.kt` | vue SwiftUI, `isIdleTimerDisabled` | ③ |
| Arithmétique d'une séance (minutée, ouverte, plafond 240, minutes à inscrire, échue) | `SessionRule.kt` | fonction pure, cas de `SessionRuleTest` | ① |
| Durées proposées et saisie libre (1 à 240) | `DureeSeance.kt` | règle pure + sélecteur | ① |
| Séance téléphone posé : décompte, notification permanente, clôture, inscription | `SessionService.kt` | **pas de service** : instants enregistrés, Live Activity, notification de fin programmée, réconciliation au retour (§ 2.2.1) | ④ |
| Action « Terminer maintenant » hors de l'app | `SessionService.kt` (`ACTION_FINISH`) | bouton de la Live Activity et du widget (`AppIntent`) | ③ |
| Séance orpheline close ou relancée | `SessionService.reconcilier`, `SessionRule.estEchue` | même règle, au retour au premier plan et dans les extensions | ② |
| Son de fin quand le décompte est masqué | `SessionService.kt:197-213` | son de la notification de fin ; option « minuterie système » (AlarmKit) qui sonne même en silencieux | ③ |
| Masquer le décompte partout | `Store.hideCountdown`, `SessionRule.compteur` | même règle : écran, Live Activity, bouclier | ① |
| Écran calme après 6 s | `PratiqueCalme.kt` | calque + `persistentSystemOverlays(.hidden)`, désactivé sous VoiceOver | ② |
| Lueur de respiration 4 s / 6 s | `SouffleView.kt` | `TimelineView` + dégradé radial | ② |
| Hitbodedout guidée en 5 temps, phrase propre au sujet | `Hitbodedut.kt`, `HitbodedutCard.kt`, `GuideSujets.kt`, `raw/guide_sujets.json` | données + carte | ② |
| « Je n'arrive pas à parler » : texte puis 10 questions | `QuestionsBlocage.kt`, `SessionActivity.kt:117-126` | règle pure + carte | ① |
| « Ne pas déranger » pendant la séance | `NePasDeranger.kt` | **aucun équivalent** : une app ne peut pas activer un mode de concentration (§ 2.2.6) | ✗ |
| Bravo de fin, danse, signes qui montent ; encouragement après abandon | `CelebrationActivity.kt` | vue plein écran, `TimelineView` | ③ |
| Mesure de la danse (saut, flexion, balancement) | `DanseMesure.kt` | fonction pure | ① |
| Confettis ; choix de ce qui est neuf ; notification « Mazal tov ! » | `Confettis.kt` (`Celebrations`) | `Canvas` ; règle pure ; la fête se montre au retour dans l'app (aucun code ne tourne à la clôture en arrière-plan) | ③ |
| Partager sa hitbodedout (texte, série, lien) | `CelebrationActivity.kt:190-199` | `ShareLink` | ① |
| Note du jour, humeurs, gratitude, « à travailler » | `NoteDialog.kt`, `JournalPlus.kt` | feuille avec `interactiveDismissDisabled` dès qu'on a écrit | ② |
| Journal (historique, résumé, graphique du mois) | `JournalActivity.kt`, `JournalPlus.Graphique` | liste + Swift Charts | ② |
| Journal protégé des captures (`FLAG_SECURE`) | `JournalActivity.kt:23-28` | masquer le contenu quand la scène devient inactive ; la capture d'écran ne se bloque pas sur iOS | ② |
| Mon parcours (séries, temps, sujets fréquents, humeur moyenne) | `ParcoursActivity.kt` | règle pure + Swift Charts | ② |
| Réglages et bibliothèque de musique, écoute d'essai, renommage | `MusicActivity.kt`, `MusicLibrary.kt` | liste ; ajout par `fileImporter` avec **copie** dans l'app | ② |
| Lecteur : boucle, fondu, focus audio | `MusicPlayer.kt` | `AVAudioPlayer`, `AVAudioSession(.playback)`, interruptions, mode d'arrière-plan audio | ③ |
| Mini-lecteur de séance (disque qui tourne, pochette) | `MiniLecteur.kt` | accessoire de bas d'écran (`tabViewBottomAccessory` ou vue dédiée), commandes de l'écran verrouillé en plus (`MPNowPlayingInfoCenter`) | ③ |
| Lecture aléatoire sans redite | `MelangeMusique.kt` | fonction pure | ① |
| Morceaux livrés (26) | `MusiquePlay.kt` | liste générée par l'export (§ 4) | ① |
| Morceaux hors Play (30 niggounim sans provenance) | `musique_hors_play/…/MusiqueHorsPlay.kt` ; `musique_play/…/MusiqueHorsPlay.kt` (liste vide) | **non livrés sur iOS** (§ 6.1) | ✗ |
| Ambiances calculées (pluie, mer, forêt, feu, nuit) | `Ambiance.kt` | `AVAudioEngine` ; même générateur, arithmétique 32 bits à débordement (`&+`, `&*`) pour les mêmes échantillons | ③ |

### 1.4 Rappels et alertes

| Fonction | Source Kotlin | Équivalent iOS | Diff. |
| --- | --- | --- | --- |
| Rappel quotidien à plusieurs heures, « Commencer », « Plus tard » (+30 min) | `Reminder.kt` (`ReminderReceiver`) | notifications locales **programmées d'avance**, jour par jour (§ 2.2.2) | ③ |
| Quand le rappel se tait (fait, jour de repos, veille après midi) | `ReminderRule.kt` | fonction pure, appliquée à la programmation | ① |
| « Plus que N pour tel trophée », une fois | `Reminder.kt:134-143`, `Trophees.proche` | évalué à la programmation | ② |
| Écran des rappels | `RemindersActivity.kt` | liste d'heures, `DatePicker` | ② |
| « Chabbat dans 3 h » | `ChabbatAlerte.kt` (`ChabbatAlerteReceiver`) | notification calculée d'avance (allumage − 3 h) | ② |
| Rappel de Birkat haLevana (premier soir, motsaé Chabbat, dernier soir) | `LevanaAlerte.kt` (`LevanaAlerteReceiver`) | notifications calculées d'avance, à tsét ou 20 h | ② |
| Rappels du vol | `VolAlerte.kt` (`VolAlerteReceiver`) | toutes les notifications du vol posées au calcul | ② |
| Budget commun | — (une alarme par type sur Android) | **planificateur unique sous la limite de 64 notifications en attente** | ③ |

### 1.5 Paliers et trophées

| Fonction | Source Kotlin | Équivalent iOS | Diff. |
| --- | --- | --- | --- |
| Six échelles de paliers, records | `Paliers.kt` | fonction pure (`PaliersTest`) | ① |
| 11 familles, 128 niveaux, chemin, grades, dates de gain | `Trophees.kt` | fonction pure (`TropheesTest`, `CheminTropheesTest`, `BilanTropheesTest`, `TropheesTikkunTest`) | ① |
| Écran Trophées et paliers, partage du grade en image | `PaliersActivity.kt` | vue + `ImageRenderer` + `ShareLink` | ③ |
| Dessin vectoriel des trophées (9 formes, matières, métaux) | `TropheeDessin.kt`, `raw/trophees_formes.json` | analyseur de chemins SVG → `Path`, dégradés | ③ |
| Fiche d'un trophée, fête en chaîne | `FicheTrophee.kt` | feuille + confettis + haptique | ② |
| Retournement 3D, reflet, étincelles, rayons, compteur | `AnimationsTrophees.kt` | animations SwiftUI | ③ |

### 1.6 La barrière « Je suis avec Hachem »

| Fonction | Source Kotlin | Équivalent iOS | Diff. |
| --- | --- | --- | --- |
| État de la barrière et sa raison (8 états) | `GateStatus.kt` | même règle pure, plus 5 états propres à iOS (§ 2.1.8) | ① |
| Surveillance de l'app au premier plan (toutes les 900 ms) | `GateService.kt` (déclaré par l'édition `full`) | **impossible et inutile** : le bouclier est posé d'avance par `ManagedSettings` (§ 2.1) | ④ |
| Écran de garde plein écran, trois issues | `BlockerView.kt`, `view_blocker.xml` | bouclier système : extension `ShieldConfiguration` (deux pages) + extension `ShieldAction` | ④ |
| Écran de garde pendant une séance | `BlockerView.kt` (`SESSION_RUNNING`) | second magasin de réglages `seance`, même extension | ④ |
| Aperçu sans effet | `GateService.preview` | réplique dans l'app + « essai réel de 2 minutes » | ② |
| Choix des applications | `AppPickerActivity.kt` (déclaré par l'édition `full`) | `FamilyActivityPicker` (jetons opaques) | ② |
| Fenêtre horaire, y compris de nuit | `Store.inWindow`, `Store.fenetreFaite` | règle pure + `DeviceActivitySchedule` (§ 2.1.5) | ③ |
| Report | `Store.snooze`, `isSnoozed` | extension d'action + rendez-vous donné à la surveillance (§ 2.1.6) | ④ |
| Chabbat, Yom Tov, pause du jour | `Store.isExempt`, `Holidays.kt` | jours exemptés calculés d'avance pour l'extension (§ 2.1.7) | ③ |
| « Je l'ai déjà faite » | `GateService.kt:138-142` | deuxième page du bouclier ; l'extension écrit dans la boîte | ③ |
| Notification permanente d'état | `GateService.kt:204-242` | **supprimée** : iOS ne demande pas de service au premier plan | ✗ |
| Édition sans barrière | variante `light` (`build.gradle.kts:157-178`) | configuration de construction `SANS_BARRIERE` (§ 2.1.11) | ② |

### 1.7 Zmanim, calendrier, lieu, boussole

| Fonction | Source Kotlin | Équivalent iOS | Diff. |
| --- | --- | --- | --- |
| Les 15 zmanim du profil et l'allumage | `Zmanim.kt` | enveloppe de KosherSwift, méthodes renommées (§ 5.1) ; vecteurs à la seconde | ③ |
| Jour chômé, veille, Israël par défaut | `Holidays.kt` | fonction pure sur KosherSwift | ① |
| Date hébraïque, fêtes, omer, paracha, conditions de prière | `CalendrierJuif.kt` | KosherSwift (`JewishCalendar`, `TefilaRules`, `HebrewDateFormatter`) + règles écrites à la main ; 3 896 entrées de vecteurs (1 948 jours, diaspora et Israël) | ③ |
| Horaires du jour (allumage, sortie), ajouts, moment du siddour, grilles | `JourAffiche.kt` | fonction pure (`JourAfficheTest`) | ① |
| Onglet Zmanim | `ZmanimActivity.kt` | vue | ② |
| Carte du jour, lignes d'horaires, blocs Levana / hilloula / halakha | `VueJour.kt` | vues partagées | ③ |
| Calendrier (mois hébreu ou civil, deux quantièmes) | `CalendrierActivity.kt` | grille `LazyVGrid`, sens RTL | ③ |
| Bannière d'horaire dans le siddour | `HorairePriere.kt` | fonction pure | ① |
| Birkat haLevana : fenêtres, usages, phase, dessin de la lune, jauge | `Levana.kt` | règles pures (`LevanaTest`) + `Canvas` | ② |
| Choix du lieu : 51 villes ou « Ma position » approximative | `ChoixLieu.kt`, `Villes.kt`, `raw/villes.json` | liste + `CLLocationManager` en précision réduite | ② |
| Position périmée après un voyage ; reprise silencieuse | `Store.lieuPerime`, `ChoixLieu.kt:84-99, 236-244` | même règle ; reprise au premier plan seulement | ② |
| Israël ou diaspora par position | `TerritoireIsrael.kt` | fonction pure | ① |
| Pourim à Jérusalem sans réglage | `Store.mukafChoma`, `CalendrierJuif.aJerusalem` | fonction pure | ① |
| Partager un jour en image | `PartageJour.kt` | `ImageRenderer` + `ShareLink` | ② |
| Direction de Jérusalem (grand cercle, cap constant, distance) | `DirectionJerusalem.kt` | fonction pure (`DirectionJerusalemTest`) | ① |
| Boussole : capteurs, déclinaison, lissage | `BoussoleActivity.kt` | `CLLocationManager` (cap) ; nord vrai par le modèle WMM2025 du site quand le lieu est une ville (§ 2.2.5) | ③ |
| Dessin de la boussole (hassid, rose fixe, rose vivante) | `BoussoleDessin.kt`, `BoussoleView.kt` | `Canvas`, haptique à l'arrivée | ③ |
| Hilloulot : données, jour, Adar, recherche | `Hilloulot.kt`, `raw/hilloulot.json`, `raw/hilloulot_bios.json` | règle pure + chargement hors du fil principal | ② |
| Écran des hilloulot | `HilloulotActivity.kt` | liste dépliable, recherche | ③ |

### 1.8 Widgets

| Fonction | Source Kotlin | Équivalent iOS | Diff. |
| --- | --- | --- | --- |
| Widget série (3 tailles, chrono vivant, bouton) | `StreakWidget.kt`, `WidgetTaille.kt`, `VignetteDecor.kt` | WidgetKit `systemSmall` / `Medium` / `Large` ; `Text(timerInterval:)` ; bouton par `AppIntent` | ③ |
| Widgets zmanim petit, moyen, grand | `ZmanimVignette.kt` (`ZmanimPetitWidget`, `ZmanimGrandWidget`), `ZmanimWidget.kt` | une famille par taille ; **chronologie avec une entrée par zman** | ③ |
| Prochain changement des widgets | `ZmanimVignette.kt` (`ZmanimTic`) | remplacé par la chronologie | ✗ |
| Prière du moment et sa limite | `ZmanimWidget.prochaine` | fonction pure | ① |
| Widget boussole 2×2 | `BoussoleWidget.kt` | `systemSmall`, direction par rapport au nord | ② |
| — | — | en plus sur iOS : widgets d'écran verrouillé (série, prochain zman) | ② |

### 1.9 Vol

| Fonction | Source Kotlin | Équivalent iOS | Diff. |
| --- | --- | --- | --- |
| Zmanim sous l'avion (grand cercle, racines, réserves, ligne de date) | `Vol.kt` | fonction pure ; 26 vols de `web/test/vecteurs_vol.json` à 2 s | ③ |
| Chabbat, fêtes et Omer sur la route | `VolCalendrier.kt` | fonction pure | ① |
| Prière du moment en vol | `VolPriere.kt` | fonction pure | ① |
| Liste des rappels du vol | `VolRappels.kt` | fonction pure (`VolRappelsTest`) | ① |
| Saisie en une phrase, trois langues | `SaisieVol.kt` | `Regex` Swift ; cas de `SaisieVolTest` | ③ |
| Aéroports : lecture, recherche pliée | `Aeroports.kt`, `raw/aeroports*.json` | fonction pure | ② |
| Carte d'embarquement BCBP | `CarteEmbarquement.kt` | fonction pure | ① |
| Code-barres d'un PDF ou d'une photo | `LecteurBillet.kt` (ZXing) | PDFKit + Vision (`VNDetectBarcodesRequest`), sans dépendance | ③ |
| Écran du vol | `VolActivity.kt` | vues SwiftUI à état | ③ |
| GPS seul, 90 s, en mode avion | `VolActivity.kt:901-957` | `CLLocationManager`, précision complète demandée pour ce seul usage | ④ |
| Route d'un numéro de vol (adsbdb) | `RouteVol.kt` | `URLSession` | ② |
| Position en direct (OpenSky) | `SuiviVol.kt`, `tools/relais_vol/` | `URLSession`, **par le relais seulement** (§ 6.2) | ② |

### 1.10 Textes : siddour, Tehilim, Tikoun, Tefilot

| Fonction | Source Kotlin | Équivalent iOS | Diff. |
| --- | --- | --- | --- |
| Lecture d'un fichier de contenu, texte en trois langues | `Json.kt` (`readRaw`, `LocalizedText`) | `JSONDecoder`, `Bundle` ; chargement hors du fil principal | ① |
| Modèle du siddour (3 rites, 4 groupes, 38 textes), signet courant, heures fixes, Méguila, Ilanot | `Siddur.kt` | types `Codable` + règles pures (`SiddurTest`, `MegilaTest`, `IlanotTest`) | ① |
| Sommaire du siddour (« Pour cette heure », Hallel, Ilanot, Méguila, groupes) | `SiddurActivity.kt` | liste | ② |
| Ajouts du jour : mis en évidence, repliés, variantes retirées, renvois, « si l'on prie seul » | `SiddurJour.kt`, `raw/siddur_annotations.json` | fonction pure ; même fichier d'annotations (1 572) ; cas de `SiddurJourTest` et de `web/src/js/siddur-jour.js` | ③ |
| Lecteur du siddour **et des 12 livres** (bande de signets, replis animés, marque-page par appui long, reprise) | `SiddurLectureActivity.kt` | `ScrollView` + `LazyVStack`, `scrollPosition(id:)` ; jusqu'à 14 390 blocs et 1 048 signets (§ 2.2.9) | ④ |
| Aération des longs paragraphes, premier mot en gras | `Aeration.kt` | fonction pure (`AerationTest`, `web/src/js/aeration.js`) | ① |
| Balisage `<b>`, `<small>`, `<br>` des blocs | `Html.fromHtml` dans le lecteur | mini-analyseur vers `AttributedString` | ② |
| Barre de lecture « Aa » : taille 80–200 %, fond noir, police, langues, noussa'h, masquer | `ReglagesLecture.kt` | barre flottante en verre (`glassEffect`) ; la place est gardée quand la taille change | ③ |
| Sept polices hébraïques, signes absents masqués | `PoliceHebraique.kt`, `res/font/` | mêmes fichiers TTF embarqués ; masquage par prétraitement ; rendu CoreText à contrôler police par police | ③ |
| Marque-pages (60 au plus, par texte, rite, section, bloc) | `MarquesPages.kt` | règle pure (`MarquesPagesTest`) | ① |
| « Reprendre », favoris, feuille des marque-pages | `RepriseFavoris.kt` | vues | ② |
| Indicateur de défilement discret | `IndicateurDefilement.kt` | indicateur natif | ✗ |
| Tehilim : 150 psaumes, portions du mois (30) et de la semaine (7) | `Tehilim.kt`, `raw/tehilim.json` | règle pure (`TehilimTest`) | ① |
| Sommaire des Tehilim (portions du jour, grille des 150) | `TehilimActivity.kt` | grille | ② |
| Lecture d'un psaume ou d'une portion, marque-page par verset | `TehilimLectureActivity.kt` | un `Text` par verset | ② |
| Tikoun HaKlali : dix psaumes, ouverture, clôture, kavana, prière de Rabbi Natan, arrêt de 32:7 | `Tikkun.kt`, `raw/tikkun_haklali.json` | données + règle pure (`TikkunTest`) | ① |
| Tikoun d'un seul tenant, « J'ai dit le Tikoun en entier », jour qui bascule à 4 h | `TikkunFlowActivity.kt`, `Store.kt:162-163, 1423-1456` | vue + règle pure | ② |
| Tefilot par sujet (10 sujets, 21 prières de Likoutei Tefilot) | `Tefilot.kt`, `TefilotActivity.kt` | liste à sections | ② |

### 1.11 Bibliothèque, halakha, 'hizouk, recherche, langues

| Fonction | Source Kotlin | Équivalent iOS | Diff. |
| --- | --- | --- | --- |
| Sources de la hitbodedout : sections, sous-sections, entrées « source » ou « article » | `Library.kt`, `raw/bibliotheque.json` | types `Codable` | ① |
| Texte intégral seulement s'il est autorisé ; vocalisation selon la licence de l'édition | `LibraryRules.kt` | règle pure (`LibraryRulesTest`, `LicencesEditionsTest`) | ① |
| Écrans des sources et des livres | `LibraryActivity.kt`, `LibrarySubSectionActivity.kt`, `LibraryEntryActivity.kt` | `NavigationStack`, listes | ② |
| Table des 12 livres | `LivresBruts.kt`, `raw/livres_titres.json` | inutile : les fichiers se nomment par leur identifiant | ✗ |
| 'Hizouk : modèle, 7 moments, 171 textes | `Chizuk.kt`, `raw/chizuk.json` | types `Codable` | ① |
| Règle de publication (vérifié **et** relu), hébreu avec ou sans voyelles | `ChizukRules.kt` | règle pure (`ChizukRulesTest`) | ① |
| Sac mélangé sans remise, par moment, gardé | `ChizukBag.kt` | règle pure (`ChizukBagTest`) | ① |
| Carte de 'hizouk à hauteur fixe, corps qui se réduit | `ChizukCard.kt` | `ViewThatFits` / `minimumScaleFactor`, Dynamic Type | ② |
| Caches des contenus | `ChizukCard.kt` (objet `Data`) | `actor Contenus`, chargement paresseux | ② |
| « J'ai besoin de 'hizouk » : un autre, garder, partager | `ChizukActivity.kt` | vue + `ShareLink` | ② |
| Halakha du Ben Ich Haï par paracha et par jour | `Halakha.kt`, `raw/ben_ish_hai.json` | règle pure sur KosherSwift (`HalakhaTest`) ; les clés du JSON sont les noms de l'énumération `Parsha` de KosherJava | ② |
| Deux se'ifim du Yalkout Yossef par jour, selon la période | `YalkutYosef.kt`, `raw/yalkut_yosef.json` | règle pure (`YalkutYosefTest`, `web/test/yalkut.test.mjs`) ; numérotation des mois de KosherJava | ② |
| Écran « Halakha du jour » (jour précédent, suivant, recherche, livre au choix) | `HalakhaActivity.kt` | vue | ② |
| Recherche globale : normalisation, un résultat par texte, 30 par sorte | `RechercheGlobale.kt`, `RechercheActivity.kt` | même normalisation `nu()` ; **index construit à l'export** plutôt que 28 Mo relus en mémoire (§ 2.2.10) | ③ |
| Références localisées, nombres en lettres hébraïques | `Reference.kt` | fonction pure (`TraductionAffichageTest`) | ① |
| Règle d'affichage des langues, repli sur l'anglais | `Langue.kt` (`RegleLangue`, `LangueApp`) | règle pure ; le repli est natif (`CFBundleDevelopmentRegion = en`) | ① |
| Choix de la langue de l'application | `Langues.kt`, `SettingsActivity.kt:432-448` | langue par app des Réglages d'iOS (§ 2.2.7) | ② |
| Six modes de langues du texte | `LanguesTexte.kt` | règle pure (`LanguesTexteTest`) | ① |

### 1.12 Réglages

Une ligne par réglage. La clé est celle de `SharedPreferences` ; elle reste la clé du fichier `reglages.json` (§ 3.2). « E » : présent dans la sauvegarde JSON.

| Réglage | Clé | Défaut | Où | E | iOS |
| --- | --- | --- | --- | --- | --- |
| Langue de l'application | `langue_app`, `langue_repli` | celle du téléphone, sinon anglais | Réglages | | réglage système par app |
| Prénom | `first_name` (fichier du journal) | vide | Réglages | E | identique |
| Comment vous appeler | `adresse` | aucun | Réglages, présentation | E | identique |
| Revoir la présentation | `onboarded_version` | — | Réglages | | identique |
| Clair ou sombre | `apparence_mode` | `auto` | Réglages | E | identique |
| Couleur du fond | `apparence_fond` | `vert` | Réglages | E | identique |
| Couleur des boutons | `apparence_accent` | `vert` | Réglages | E | identique ; l'icône ne change plus toute seule |
| Police hébraïque | `lecture_police` | à empattements | Réglages, barre de lecture | | identique |
| Grand texte (140 %) et taille fine | `lecture_echelle` | 1,0 | Réglages, barre de lecture | | identique, **multiplié** par la taille de texte du système |
| Lecture sur fond noir | `lecture_sombre` | non | barre de lecture | | identique |
| Langues du texte | `lecture_langues` | selon la langue de l'app | barre de lecture | | identique |
| Bouton de lecture masqué | `lecture_masquee` | non | barre de lecture | | identique |
| Noussa'h | `siddur_nusah` | `edot` | siddour, barre de lecture | | identique |
| Écran d'ouverture | `ecran_ouverture` | `aujourdhui` | Réglages | | onglet initial |
| Israël ou diaspora | `in_israel` | d'après le fuseau, figé au premier accès | Réglages ; suit le lieu | E | identique |
| Lieu des zmanim | `lieu_nom`, `lieu_latitude`, `lieu_longitude`, `lieu_altitude`, `lieu_fuseau`, `lieu_ville`, `lieu_t` | aucun | Zmanim, boussole | | identique |
| Minutes d'allumage | `allumage_minutes` | 18 (parmi 18, 20, 22, 30, 40) | Zmanim | | identique |
| Ta'hanoun de fin de Tichri (Sfard) | `sans_tahanoun_fin_tichri_sfard` | dit | Zmanim | | identique |
| Calendrier civil ou hébreu | `calendrier_civil` | hébreu | Calendrier | | identique |
| Birkat haLevana affichée | `levana_affichee` | oui | Réglages | | identique |
| Rappel de Birkat haLevana | `levana_rappel`, `levana_rappel_soir` | oui | Réglages | | notifications programmées |
| Usage de Birkat haLevana | `levana_usage` | selon le noussa'h | Réglages | | identique |
| Hilloulot sur la carte du jour | `hilloulot_affichees` | oui | Réglages, Hilloulot | | identique |
| Halakha sur la carte du jour | `halakha_affichee` | oui | Réglages, Halakha | | identique |
| Livre de la halakha | `halakha_source` | `yalkut` | Réglages, Halakha | | identique (selon § 6.3) |
| Direction suivie par la boussole | `boussole_carte` | grand cercle | Boussole | | identique |
| Affichage de la boussole | `boussole_rose` | le hassid | Boussole | | identique |
| « Je suis avec Hachem » | `enabled` | éteint | Réglages, pastille de l'accueil | | identique ; demande l'autorisation Temps d'écran |
| Applications retenues | `blocked_apps` | aucune | Réglages | E | `selection.plist` ; la liste d'Android est gardée sans effet |
| Heures du mode | `window_start`, `window_end` | 06:00 – 11:00 | Réglages | E | identique |
| Durée du report | `snooze_minutes` | 15 (parmi 5, 10, 15, 30, 60) | Réglages | E | identique |
| Report en cours | `snoozed_until` | — | (état) | | identique |
| Voir l'écran maintenant | — | — | Réglages | | aperçu + essai réel (§ 2.1.8) |
| Chabbat et Yom Tov | `pause_shabbat` | oui | Réglages | E | identique |
| Pause aujourd'hui | `paused_dates` | — | Réglages | E | identique |
| Durée habituelle | `target_minutes` | 15 | accueil, séance, Réglages | E | identique |
| Objectif quotidien | `daily_goal_minutes` | 0 = la durée habituelle | Réglages | E | identique |
| Sujet de la prochaine séance | `session_theme` | aucun | accueil, séance | | identique |
| Masquer le décompte | `hide_countdown` | non | Réglages | E | identique |
| Hitbodedout guidée | `guided_hitbodedut` | non | Réglages | E | identique |
| Ne pas déranger pendant la séance | `ne_pas_deranger`, `filtre_avant_seance` | non | Réglages | | **remplacé** par un guide vers un mode de concentration (§ 2.2.6) |
| Signal de fin | — | — | — | | **nouveau** : discret (notification) ou minuterie système (AlarmKit) |
| Rappels | `reminder_on` | non | Rappels | E | identique |
| Heures de rappel | `reminder_times` (et `reminder_minutes`) | 07:00 | Rappels | E | identique |
| Rappel reporté | `reminder_snoozed_until` | — | (état) | | identique |
| Dire qu'un trophée est proche | `rappel_trophee_proche`, `trophees_proches_signales` | oui | Rappels | | identique |
| Musique pendant la séance | `music_enabled` | oui | Musique, accueil | E | identique |
| Volume | `music_volume` | 60 | Musique | E | identique |
| Lecture aléatoire | `music_shuffle` | non | Musique, mini-lecteur | E | identique |
| Morceau retenu | `music_track` | le premier | Musique | E | identique pour les morceaux livrés |
| Morceaux ajoutés, noms donnés | `music_user_tracks`, `music_names` | — | Musique | | fichiers copiés dans l'app |
| Ambiance | `ambiance` | `silence` | Musique | | identique |
| Rappels pendant le vol | `vol_rappels_actifs` | oui | Vol | | identique |
| Services en ligne du vol | `vol_suivi_direct` | **éteint** | Vol | | identique |
| Indicatif radio | `vol_indicatif` | vide | Vol | | identique |
| Favoris, marque-pages, places de lecture | `favoris`, `chizuk_favoris`, `marques_pages`, `position:*`, `derniere_lecture` | — | lecteurs | | `lecture.json` |
| États « déjà vu » | `paliers_vus`, `paliers_notifies`, `trophees_vus`, `trophees_notifies`, `grade_vu`, `anneaux_fetes`, `bilan_vu`, `chizuk_bag_*`, `chizuk_last_*` | — | (état) | | identiques ; clé absente = « jamais vu » |
| Tikoun du jour et journal du Tikoun | `tikkun_day`, `tikkun_done`, `tikkun_journal` | — | Tikoun | | identiques |
| Exporter, importer | — | — | Réglages | | § 3 |
| Sauvegarde iCloud du journal | — | — | — | | **nouveau**, éteint par défaut (D6) |
| Règles de confidentialité | — | — | Réglages | | lien vers la page publique, section iOS à ajouter |
| Demander une dédicace | — | — | Réglages | | identique |
| Réinitialiser l'application | — | — | Réglages | | identique |
| Autorisations : batterie, affichage par-dessus, données d'utilisation | — | — | Réglages | | **sans objet** ; restent notifications, Temps d'écran, localisation |

## 2. Écarts imposés par iOS

Statuts employés dans cette section : **Vérifié** (lu le 13/11/2026 dans la documentation d'Apple, liens au § 9), **Constaté** (rapporté par des développeurs, non documenté par Apple), **À éprouver** (ne se saura que sur l'iPhone).

### 2.1 La barrière « Je suis avec Hachem »

Le README dit encore « iOS n'autorise pas ce type de blocage par une application tierce ». Ce n'est plus vrai depuis l'API Temps d'écran, mais iOS l'autorise **à sa manière**, qui n'est pas celle d'Android.

#### 2.1.1 Ce qui change de nature

| Android (`GateService`, `BlockerView`) | iOS | Conséquence |
| --- | --- | --- |
| L'app regarde quelle application est au premier plan, toutes les 900 ms | **Interdit.** Une app ne sait jamais ce qui est ouvert | La barrière ne réagit pas : elle est **posée d'avance** sur les applications choisies |
| L'app dessine son propre écran par-dessus | **Interdit.** Seul le système affiche un « bouclier », dont l'app remplit quelques champs | Pas de carte de 'hizouk complète, pas d'animation, pas de mise en page libre |
| L'app lit la liste des applications installées | **Interdit.** Le sélecteur d'Apple rend des jetons opaques | L'app ne connaît ni le nom ni le nombre exact « par nom » ; la liste d'Android ne migre pas |
| Un service tourne en permanence, avec sa notification | **Inutile.** Le système garde le bouclier, app fermée ou téléphone redémarré | Plus de notification permanente, plus de réglage de batterie |
| Le code décide à chaque instant (fenêtre, report, Chabbat) | Le code ne tourne qu'aux **rendez-vous** donnés au système, dans une extension minuscule | Tout ce qui dépend de l'heure se planifie |

#### 2.1.2 Les pièces

| Pièce | Cadre Apple | Rôle |
| --- | --- | --- |
| Autorisation | `FamilyControls`, `AuthorizationCenter.requestAuthorization(for: .individual)` | l'utilisateur s'autorise lui-même (Face ID ou code) ; il peut la retirer à tout moment dans Réglages → Temps d'écran |
| Sélection | `FamilyActivityPicker` → `FamilyActivitySelection` | applications, catégories et sites, en jetons |
| Deux magasins nommés | `ManagedSettingsStore(named:)` : `barriere` et `essai` | chacun porte les jetons à retenir, posés ou retirés à chaque rendez-vous. Écrit le 23/11 : `seance` est fondu dans `barriere` (le visage, invite ou séance, se choisit à l'affichage d'après `etat.json`, `PlanBouclier`), et l'essai réel a son magasin ; `isActive` (iOS 26.5) n'est pas employé, faute d'avoir été éprouvé |
| Extension « bouclier » | `ManagedSettingsUI`, `ShieldConfigurationDataSource` | remplit le bouclier : icône, titre, sous-titre, deux boutons, couleurs |
| Extension « action » | `ManagedSettings`, `ShieldActionDelegate` | reçoit l'appui sur un bouton, agit, répond au système |
| Extension « surveillance » | `DeviceActivity`, `DeviceActivityMonitor` | réveillée aux rendez-vous (`intervalDidStart`, `intervalDidEnd`) |
| Conteneur partagé | App Group | `etat.json`, `boite.jsonl`, `seance.json` (§ 3.2) |

L'entitlement `com.apple.developer.family-controls` est nécessaire pour l'app **et pour chacune des trois extensions**.

#### 2.1.3 Choisir les applications

`FamilyActivityPicker` remplace `AppPickerActivity`. Ce qui se perd : « Tout sélectionner » (remplacé par le choix de catégories entières, que le sélecteur propose), l'ordre alphabétique maison. Ce qui se gagne : les **sites web** dans Safari, que le même sélecteur propose et que le même bouclier retient.

- L'écran affiche les choix avec `Label(jeton)` : le système dessine le nom et l'icône, l'app ne les lit pas.
- **50 applications au plus** par bouclier (Vérifié : « Your app can shield up to 50 application tokens at once »). Au-delà, rien ne signale l'échec. L'écran compte les jetons, prévient à 50 et propose de choisir une catégorie, qui n'a pas cette limite.
- Les jetons sont **locaux à l'appareil** (Constaté). Après une restauration ou un changement d'iPhone, l'état « sélection à refaire » le dit (§ 2.1.8).

#### 2.1.4 Le bouclier : trois visages

Ce qu'un bouclier peut porter (Vérifié) : une icône, un titre, un sous-titre, un bouton principal, un bouton secondaire, une couleur de fond ou un flou, la couleur du bouton ; depuis **iOS 26.4**, un **sous-menu de trois entrées au plus** sous le bouton secondaire (le système y ajoute « Annuler »). Rien d'autre : ni image libre, ni liste, ni champ de saisie, ni mise à jour en direct. Le texte est figé au moment où le bouclier apparaît, comme l'écran d'Android l'était.

Ce qu'un appui peut déclencher (Vérifié) : ne rien faire (`.none`), fermer l'application retenue (`.close`), redemander le contenu du bouclier (`.defer`) et, depuis **iOS 26.5**, **ouvrir notre application** (`.openParentalControlsApp`).

Les trois issues de l'écran d'Android tiennent donc dans un seul bouclier :

| | Rien de fait aujourd'hui (`PROMPT`) | Séance en cours (`SESSION_RUNNING`) | Essai (`PREVIEW`) |
| --- | --- | --- | --- |
| Icône | le hassid qui appelle (`Character.call`) | le hassid en prière (`Character.during`) | le hassid qui appelle |
| Titre | « Avez-vous fait votre hitbodedout ? » | « Hitbodedout en cours » | « Avez-vous fait votre hitbodedout ? » |
| Sous-titre | « Un moment à l'écart avant le reste de la journée. » puis « Série en cours : 12 jours » | « Il reste 12 min. Le téléphone peut attendre. » (ou la phrase du décompte masqué, ou de la séance sans durée) | « APERÇU, AUCUN EFFET » |
| Bouton principal | « Commencer maintenant, 15 min » → ouvre l'app, qui démarre la séance | « Revenir à la hitbodedout » → ouvre l'app | « Fermer l'aperçu » → lève l'essai |
| Bouton secondaire | « Autre réponse » → sous-menu : « Je l'ai déjà faite », « Plus tard (15 min) » | aucun | aucun |
| Couleurs | fond et bouton de la palette choisie (`brand_dark`, `brand`) | idem | idem |

Détails :

- Les textes sont ceux de `strings.xml` (`blocker_*`), dans la langue de l'app ; l'app les dépose déjà traduits dans `etat.json`, l'extension ne charge aucun catalogue.
- L'extension du bouclier reçoit le **nom de l'application retenue** (Vérifié : « the display names, bundle identifiers, and domains »). Le sous-titre peut donc dire « Instagram attendra. » Ce nom ne sort pas de l'extension.
- Le mot de 'hizouk du moment « porte » (`ChizukCard.show(…, Moment.PORTE)`) : sur le bouclier, **seulement s'il tient en entier** dans le sous-titre ; jamais tronqué. L'export (§ 4) marque les textes assez courts. Les autres attendent sur l'écran de séance, où « Commencer » mène.
- « Commencer » : l'extension écrit la demande dans la boîte et répond `.openParentalControlsApp` ; l'app, en s'ouvrant, lit la demande, démarre la séance à la durée habituelle et montre l'écran de séance. C'est le geste d'Android (`onStartSession`). **À éprouver** : ce cas d'API porte le nom du contrôle parental ; son comportement avec une autorisation `.individual` n'est confirmé par aucune source de première main.
- **Repli** si `.openParentalControlsApp` ne répond pas, ou avant iOS 26.5 : l'extension pose une notification immédiate « Touchez pour commencer votre hitbodedout » et répond `.close`. Deux gestes au lieu d'un.
- Avant iOS 26.4 (si la cible reste 26.0, décision D2) : pas de sous-menu ; le bouton secondaire répond `.defer` et le bouclier se redessine en « deuxième page » (principal : « Je l'ai déjà faite », secondaire : « Plus tard (15 min) »).

#### 2.1.5 La fenêtre horaire

`window_start` et `window_end` gardent leur sens, fenêtre de nuit comprise (21:00 – 02:00).

- Une activité **`fenetre`**, répétée chaque jour, de `window_start` à `window_end` (`DeviceActivitySchedule`). À son début, l'extension évalue l'état (§ 2.1.8) et active le magasin `barriere` s'il y a lieu ; à sa fin, elle le désactive.
- Une activité **`minuit`**, répétée chaque jour à 00:00, réévalue : c'est elle qui lève la barrière d'une fenêtre de nuit quand le jour qui commence est un Chabbat, et qui applique `Store.fenetreFaite` (la séance de 21 h 30 couvre la nuit jusqu'à 2 h).
- Dès qu'une séance est inscrite dans l'app, l'app désactive `barriere` elle-même, tout de suite.

Limites (Vérifié) : un intervalle dure **15 minutes au moins** et une semaine au plus ; **20 activités** au plus par app (cinq sont utilisées : `fenetre`, `minuit`, `report`, `seance`, `essai`) ; le système n'appelle l'extension **que lorsque l'appareil sert** : un début de fenêtre à 6 h est traité au premier déverrouillage du matin, ce qui suffit, puisque la barrière ne sert qu'à ce moment-là. Une fenêtre de moins de 15 minutes est refusée par l'écran de réglage.

#### 2.1.6 Le report

Sur Android : « Plus tard (15 min) » écrit `snoozed_until`, l'écran disparaît, et le service le remet à l'heure dite. La durée se règle parmi 5, 10, 15, 30, 60 minutes.

Sur iOS, l'extension d'action :

1. désactive `barriere` et écrit le report dans la boîte ;
2. demande au système une activité **`report`** dont le **début** est l'instant de fin du report (et la fin, quinze minutes plus tard, pour respecter la durée minimale) ;
3. au début de cette activité, l'extension de surveillance réévalue et réactive `barriere`, puis arrête l'activité.

Planifier le *début* à l'instant voulu évite deux pièges constatés : un intervalle qui commence « maintenant » peut être reporté au lendemain, et un intervalle de moins de 15 minutes est refusé. Les cinq durées d'Android restent donc offertes, 5 et 10 minutes comprises. **À éprouver** sur l'iPhone, avec en repli l'avertissement de fin d'intervalle (`warningTime`). Filets : l'app réévalue à chaque retour au premier plan, et les activités `fenetre` et `minuit` réévaluent à leur tour.

Le report n'est pas compté en temps d'usage mais en temps d'horloge, comme sur Android. (Un seuil d'usage, « cinq minutes d'Instagram puis le bouclier », est possible, mais ce n'est pas la règle de l'app, et les seuils d'usage sont la partie la moins fiable de l'API sous iOS 26.)

#### 2.1.7 Chabbat, Yom Tov, pause du jour

La règle d'Android (`Store.isExempt`) : le jour civil est exempté s'il est en pause, ou si « Chabbat et Yom Tov » est actif et que le jour est chômé (`JewishCalendar.isAssurBemelacha`, Israël ou diaspora).

Sur iOS, l'extension de surveillance ne calcule pas le calendrier : l'app écrit dans `etat.json` **la liste des jours exemptés des deux années à venir** (environ 150 dates, 2 Ko), plus les jours mis en pause. L'extension y cherche la date du jour. Si la liste est périmée (l'app n'a pas été ouverte depuis deux ans), le samedi reste exempté par le jour de la semaine : le Chabbat n'est jamais retenu par erreur.

Trois conséquences à connaître :

- Le Chabbat, **aucun bouclier ne paraît** et rien ne sonne ; la série n'est pas cassée ; l'état dit « Jour sans obligation ».
- Comme sur Android, c'est le **jour civil** qui compte, pas le coucher du soleil. Pour une fenêtre du matin c'est exact. Pour une fenêtre du vendredi soir, la barrière agit jusqu'à minuit : c'est le comportement d'Android (README, « Shabbat et fêtes »). Maintenant que l'app a un lieu et des zmanim, exempter du coucher du soleil à la sortie des étoiles serait possible ; ce serait une **amélioration des deux plateformes**, à décider ensemble, pas un écart d'iOS.
- « Pause aujourd'hui » dans les réglages désactive `barriere` immédiatement et met la liste à jour.

#### 2.1.8 « Pourquoi la barrière n'agit pas »

`GateStatus.evaluate` se porte ligne pour ligne, dans le même ordre de priorité, et la carte d'état reste en tête des réglages. iOS y ajoute les pannes qui lui sont propres, parce qu'elles sont silencieuses :

| État | Android | iOS : comment on le sait | Ce que l'écran dit et propose |
| --- | --- | --- | --- |
| Autorisations manquantes | overlay ou données d'usage | `authorizationStatus != .approved` | « Autoriser Temps d'écran » |
| Mode désactivé | `enabled == false` | idem | l'interrupteur |
| Aucune application choisie | `blocked_apps` vide | sélection vide | « Choisir les applications » |
| Journée validée | `fenetreFaite` | même règle, journal + boîte | — |
| Jour sans obligation | `isExempt` | même règle | — |
| Report en cours | `isSnoozed` | même règle | l'heure de reprise |
| Hors de la fenêtre | `!inWindow` | même règle | les heures |
| « Je suis avec Hachem » veille | sinon | sinon, **et** le magasin `barriere` est bien actif | « N applications sont bloquées jusqu'à 11:00 ou jusqu'à votre hitbodedout » (N compte les jetons : une catégorie vaut un) |
| *Autorisation retirée* | — | l'autorisation a disparu alors que le mode est allumé (iOS lève alors tout, sans prévenir l'app) | « iOS a retiré l'accès. Le rendre ? » |
| *Sélection à refaire* | — | jetons invalides après restauration ou changement d'iPhone | « Choisir de nouveau les applications » |
| *Surveillance absente* | — | `DeviceActivityCenter.activities` ne contient pas `fenetre` | l'app la réinscrit ; sinon message |
| *Bouclier désaccordé* | — | la règle dit « veille » mais le magasin est inactif, ou l'inverse | l'app corrige d'elle-même et le note au journal |
| *Surveillance muette* | — | le dernier réveil de l'extension (écrit dans la boîte) date de plus d'un jour | « iOS n'a pas réveillé la surveillance depuis hier. Ouvrir l'app le matin la relance. » |

Deux outils de confiance, dans la même carte :

- **L'essai réel**, qui remplace « Voir l'écran maintenant » : l'app retient les applications choisies pendant deux minutes, à n'importe quelle heure, avec le bouclier « APERÇU, AUCUN EFFET » ; on ouvre une de ses applications pour voir le vrai bouclier, puis « Fermer l'aperçu ». Une réplique dessinée dans l'app montre l'apparence sans attendre.
- **Le journal de la barrière** : les cinquante derniers événements (armée à 06:02 par la surveillance, report de 15 min, levée par la séance…), que l'on peut partager. Sans Mac et sans débogueur, c'est aussi l'outil de mise au point sur l'iPhone de l'ami.

#### 2.1.9 Limites à connaître

| Limite | Source | Parade |
| --- | --- | --- |
| 50 applications par bouclier | Vérifié | compteur, catégories |
| 20 activités surveillées, 15 minutes minimum | Vérifié | cinq activités, début planifié à l'instant voulu |
| L'extension n'est appelée que lorsque l'appareil sert | Vérifié | sans effet pour une barrière |
| Mémoire de l'extension de surveillance : environ 6 Mo | Constaté | l'extension ne lit que `etat.json`, ne charge ni journal ni calendrier, bascule `isActive` |
| Le simulateur ne fait pas tourner Temps d'écran (l'autorisation n'aboutit pas) | Constaté | toute la logique est pure et testée hors appareil ; les quatre recettes sur iPhone (ROADMAP) |
| Retrait de l'autorisation : tout est levé, l'app n'est pas prévenue | Constaté | état « Autorisation retirée » au retour dans l'app |
| Boucliers restant après la suppression de l'app | Constaté (sept. 2025) | « Réinitialiser » et l'extinction du mode vident les magasins ; l'aide le dit |
| Seuils d'usage déclenchés à tort sous iOS 26.0 à 26.4, encore signalés après | Constaté | aucun seuil d'usage n'est employé |
| Jetons qui changent, boucliers vides | Constaté | état « Sélection à refaire », nouvelle sélection en deux gestes |

Contournable, et c'est voulu, comme sur Android : retirer l'autorisation ou supprimer l'app lève tout. La barrière reste un ralentisseur.

#### 2.1.10 Pendant une séance

Sur Android, tant qu'une séance court, ouvrir une application retenue montre « Hitbodedout en cours », même hors fenêtre. Sur iOS : au début de la séance l'app active le magasin `seance` ; elle le désactive à la fin. Si l'app dort quand la séance minutée se termine, trois filets : une activité `seance` dont le début est l'heure de fin ; le bouclier lui-même, qui, s'il est demandé après l'heure de fin, affiche « Vous avez parlé avec Hachem aujourd'hui » et un bouton « Continuer » qui lève tout ; le retour dans l'app. Dans les trois cas la journée est inscrite pour la durée choisie, jamais plus (`SessionRule.minutesAInscrire`).

#### 2.1.11 L'entitlement, et la construction sans barrière

- **Développement** : l'entitlement est disponible tout de suite pour un compte du programme développeur. Les essais sur l'iPhone de l'ami n'attendent rien.
- **TestFlight et App Store** : il faut la version « Distribution », **à demander à Apple pour chaque identifiant** (l'app et les trois extensions : quatre demandes), par le titulaire du compte. Délais rapportés : d'un jour à plus d'un mois. **À déposer dès la création du compte** (ROADMAP, préalables).
- En attendant, et comme plan de repli si Apple refusait : une configuration de construction `SANS_BARRIERE`, l'équivalent de l'édition `light`, sans les trois extensions ni l'entitlement. Elle permet d'ouvrir TestFlight sur tout le reste.

#### 2.1.12 La voie écartée

Une autre mécanique existe sans aucun entitlement : une automatisation de l'app Raccourcis, « quand j'ouvre Instagram, lancer l'action de MyHitbodedut », qui amène notre app au premier plan avec un écran entièrement libre. Elle rendrait l'écran d'Android à l'identique. Elle n'est pas retenue pour la v1 : l'utilisateur doit la construire à la main, application par application, elle se dérègle sans prévenir, et depuis iOS 26.5 le bouclier ouvre notre app d'un appui. Elle reste le **second plan de repli** si l'entitlement de distribution était refusé.

#### 2.1.13 Le parcours, de bout en bout

1. Réglages → « Je suis avec Hachem ». Un écran dit ce qui sera fait et ce qui ne le sera pas (le texte de `Divulgation`, adapté : rien n'est lu, rien n'est envoyé, comment l'éteindre).
2. Feuille du système : autoriser Temps d'écran (Face ID).
3. Sélecteur d'Apple : applications, catégories, sites. Si une sauvegarde d'Android a été importée : l'aide-mémoire du § 3.7.
4. Heures du mode, durée du report : mêmes réglages qu'Android.
5. « Faire un essai » : deux minutes, le vrai bouclier.
6. Le lendemain à 6 h 40, l'utilisateur ouvre une application retenue : bouclier, « Commencer maintenant, 15 min », l'app s'ouvre sur la séance qui démarre. À la fin, tout est levé jusqu'au lendemain.

### 2.2 Les autres écarts

#### 2.2.1 La séance sans service

Android fait vivre la séance dans un service au premier plan. iOS suspend l'app quelques secondes après qu'on l'a quittée. Le modèle d'Android s'y prête pourtant : une séance n'est que deux instants enregistrés (`session_started_at`, `session_ends_at`), et `SessionRule` sait déjà clore une séance dont « personne ne s'occupe plus ».

| Besoin | Android | iOS |
| --- | --- | --- |
| Voir le temps restant, téléphone posé | notification permanente | **Live Activity** : écran verrouillé et Dynamic Island, `Text(timerInterval:)` ; respecte « masquer le décompte » et la séance sans durée |
| Terminer sans ouvrir l'app | action de la notification | bouton de la Live Activity (`AppIntent`) |
| Signal de fin | sonnerie de notification si le décompte est masqué | notification locale programmée au début, à l'heure de fin ; si la musique ou une ambiance joue, l'app vit et joue elle-même le signal avant le fondu |
| Signal de fin sûr, téléphone en silencieux | — | réglage « minuterie système » : **AlarmKit** (iOS 26) sonne malgré le silencieux et le mode de concentration |
| Inscrire la journée à la fin | le service | au retour dans l'app, ou par l'extension de surveillance si la barrière est active (§ 2.1.10) ; toujours pour la durée choisie et au jour du début |
| Garder l'écran allumé sur l'écran de séance | `FLAG_KEEP_SCREEN_ON` | `isIdleTimerDisabled` |
| Garder l'écran allumé pendant la lecture (VeilleLecture, dix minutes après le dernier toucher) et pendant le défilement automatique (keepScreenOn) | `FLAG_KEEP_SCREEN_ON` de la fenêtre, `keepScreenOn` de la vue | un seul `isIdleTimerDisabled` pour l'app : chaque écran le demande sous son nom (`EcranAllumeDemandes`), allumé tant qu'une demande reste |
| Musique écran éteint | service `mediaPlayback` | mode d'arrière-plan audio, seulement quand un son joue réellement (règle 2.5.4 de l'App Store) |
| Fête d'un trophée gagné pendant la séance | notification « Mazal tov ! » émise par le service | montrée au retour dans l'app ; aucune notification ne peut être calculée pendant que l'app dort |

Une Live Activity dure huit heures au plus ; une séance en dure quatre.

#### 2.2.2 Rappels et alertes : aucun code ne tourne à l'heure dite

Android pose **une** alarme, et décide au moment où elle sonne (`ReminderRule.shouldNotify`). iOS ne réveille pas l'app pour une notification locale : tout se décide **à la programmation**, et une app ne peut avoir que **64 notifications en attente** (Vérifié).

Un **planificateur unique**, fonction pure `(état, maintenant) → liste de notifications`, remplace les quatre récepteurs :

| Type | Règle (inchangée) | Part du budget |
| --- | --- | --- |
| Rappel de hitbodedout | chaque heure choisie, sauf jour fait, jour de repos, veille après midi | 30 : dix jours à trois heures par jour, moins de jours s'il y a plus d'heures |
| « Chabbat dans 3 h » | allumage du vendredi moins 3 h, au lieu des zmanim | 4 |
| Birkat haLevana | premier soir, motsaé Chabbat conseillé, dernier soir, à tsét ou 20 h | 6 |
| Vol | Tefilat haDerekh, débuts de prière, 30 min avant la limite, Omer | 14 |
| Fin de séance, rappel reporté | — | 2 |
| Marge | | 8 |

Le planificateur repasse à chaque ouverture, à chaque séance inscrite (les rappels restants du jour sont retirés), au début d'une séance (ceux qui tomberaient pendant sont retirés), à chaque changement de réglage, de lieu, d'heure ou de fuseau, et lors des rafraîchissements d'arrière-plan qu'iOS accorde (`BGAppRefreshTask`, sans garantie).

Ce qui se perd : si l'app n'est pas ouverte pendant dix jours et qu'iOS ne lui accorde aucun rafraîchissement, les rappels s'arrêtent. C'est préférable à l'autre choix, une notification répétée à heure fixe, qui sonnerait le Chabbat et un jour déjà fait. « Plus tard » (+30 min) et « Commencer » restent des actions de la notification. Les notifications locales survivent au redémarrage : `BootReceiver` n'a pas d'équivalent à écrire.

#### 2.2.3 Widgets

Les widgets d'Android sont des images dessinées par l'app et rafraîchies par des alarmes. WidgetKit demande une **chronologie** : la liste, calculée d'avance, de ce que le widget montrera et quand. C'est mieux adapté aux zmanim, dont chaque changement est connu d'avance : une entrée par zman, une au changement de jour hébreu (à tsét), sans réveil de l'app. iOS accorde de 40 à 70 rechargements par jour ; il en faut une vingtaine.

- Le chrono vivant (`Chronometer`) devient `Text(timerInterval:)`.
- « Commencer » ouvre l'app sur la séance ; « Terminer maintenant » agit sans l'ouvrir (`AppIntent`).
- Trois tailles au lieu d'un widget redimensionnable ; l'écran verrouillé en plus.
- Le fond dessiné est retiré par les modes teinté et transparent d'iOS 26 : prévoir le rendu « accentué » de chaque widget.

#### 2.2.4 Musique et ambiances

- Les morceaux ajoutés : Android garde une URI et une permission persistante ; iOS **copie le fichier** dans l'app (`fileImporter`), ce qui est plus sûr et se sauvegarde.
- Android n'expose ni commandes d'écran verrouillé ni « en cours de lecture ». Sur iOS c'est attendu dès que l'audio joue en arrière-plan : `MPNowPlayingInfoCenter` et les commandes à distance, avec la pochette ou le hassid à la guitare.
- Les ambiances sont calculées, sans fichier, et doivent rester **les mêmes échantillons** que sur Android et le site (générateur mulberry32, graine 7) : arithmétique entière 32 bits à débordement, à écrire avec `&+`, `&*` et le décalage non signé. `AmbianceTest` fournit les valeurs.
- Une ambiance « silence » ne garde pas l'app en vie : pas de son muet pour tricher, l'App Store le refuse.

#### 2.2.5 Lieu et boussole

- **Position approximative** : `NSLocationDefaultAccuracyReduced` fait demander la position approximative par défaut, comme `ACCESS_COARSE_LOCATION`. La position exacte n'est demandée, pour une fois (`requestTemporaryFullAccuracyAuthorization`), qu'au toucher de « Position réelle (GPS) » en vol.
- **Reprise au changement de fuseau en arrière-plan** : impossible sans localisation permanente, que l'app ne demandera pas. La position est reprise au retour dans l'app ; la règle « position périmée si le fuseau a changé » (`Store.lieuPerime`) continue de taire les alertes d'ici là.
- **Boussole** : CoreMotion donne l'orientation par rapport au nord **magnétique** (`xMagneticNorthZVertical`), téléphone à plat ou tenu droit, sans demander la localisation (**à éprouver**). Android ajoute la déclinaison magnétique **du lieu des zmanim** (`GeomagneticField`), qui peut être une ville choisie sans localisation. iOS ne fournit le nord vrai que si la localisation est permise. Pour garder « une ville de la liste n'a besoin d'aucune autorisation », on porte le modèle **WMM2025** du site (`web/src/js/magnetisme.js`, 130 lignes, vecteurs `web/test/vecteurs_wmm2025.txt`). Le modèle vaut jusqu'à fin 2029.
- **GPS en mode avion** : l'iPhone garde le GPS en mode avion ; le délai du premier relevé sans réseau peut dépasser les 90 secondes d'Android. **À éprouver.**

#### 2.2.6 « Ne pas déranger »

Aucune app ne peut activer un mode de concentration. Le réglage `ne_pas_deranger` disparaît. À la place : un écran d'aide pour créer dans les Réglages d'iOS un mode de concentration « Hitbodedout » qui s'active de lui-même quand MyHitbodedut est ouverte, et un **filtre de mode de concentration** (`SetFocusFilterIntent`) qui permet, à l'inverse, de dire à iOS : « quand ce mode est actif, masquer le décompte ».

#### 2.2.7 Langue

Android choisit la langue dans l'app (`setApplicationLocales`). Sur iOS, la voie prévue est le réglage **par application** : Réglages → MyHitbodedut → Langue. Il vaut pour l'app, les widgets, les notifications et le bouclier, sans une ligne de code. La ligne « Langue » des réglages de l'app y mène.

- Le repli « téléphone dans une autre langue → anglais » (`LangueApp`) est natif : région de développement `en`, trois localisations explicites `fr`, `en`, `he` (et non `iw`).
- **À éprouver** : iOS ne montre la ligne « Langue » que si l'appareil connaît plusieurs langues préférées. Si elle manque sur un téléphone réglé en français seul, ajouter un sélecteur dans l'app (surcharge de `locale` et de `layoutDirection`), au prix d'extensions à traduire à la main.
- Les langues **du texte** (six modes) restent un réglage de l'app.

#### 2.2.8 Sauvegarde du téléphone

Android : le nuage ne reçoit que les réglages ; le journal, les notes et le prénom n'y vont jamais ; le transfert d'appareil à appareil emporte tout (`backup_rules.xml`, `data_extraction_rules.xml`). iOS ne distingue pas ces deux cas aussi finement : un fichier marqué `isExcludedFromBackup` est exclu de la sauvegarde iCloud **et** de la sauvegarde locale. Proposition : `journal.json` exclu par défaut, pour tenir la promesse « le journal ne part pas dans le nuage », avec un interrupteur « Inclure mon journal dans la sauvegarde de l'iPhone », éteint, et un rappel d'export. Décision D6.

#### 2.2.9 Le lecteur

`SiddurLectureActivity` lit des prières de quelques centaines de blocs, mais aussi le Likoutei Moharan (7 057 blocs, 411 signets) et le Kitsour Yalkout Yossef (14 390 blocs, 1 048 signets). Quatre exigences se croisent : liste paresseuse à hauteurs très inégales, saut exact à un bloc, suivi de la section en cours, place gardée quand la taille change. C'est le point le plus délicat de l'interface.

- La place de reprise devient un **couple (section, bloc)** et non un indice de ligne affichée : sur Android elle dépend des ajouts du jour et des replis ouverts.
- Hébreu de droite à gauche et traduction de gauche à droite dans le même paragraphe : direction forcée par bloc, isolats bidi comme le fait déjà le code.
- Les sept polices sont embarquées telles quelles ; le masquage des signes absents (`PoliceHebraique.kt:64-95`) se refait par prétraitement. Le placement des voyelles, du meteg et des te'amim sous CoreText n'est pas celui d'Android : à contrôler police par police sur les captures de la CI.
- Pas d'image pendant la prière (Choul'han Aroukh O.H. 90:23, cité dans le layout) : la règle se garde.
- La taille de lecture de l'app (80 à 200 %) se **multiplie** par la taille de texte du système.

#### 2.2.10 La recherche

Android relit et normalise tout à chaque frappe : 28 Mo de JSON analysés et gardés en mémoire à la première recherche. Sur un iPhone, cela coûte des secondes et plus de 100 Mo de mémoire. L'export (§ 4) construit donc un **index** : pour chaque bloc, le texte déjà passé par `nu()` (sans voyelles, sans te'amim, sans balises, minuscules), dans une base SQLite que l'app ouvre en lecture seule (SQLite fait partie d'iOS). Les règles de résultat ne changent pas : un résultat par prière ou par livre, 30 par sorte, même extrait. Ce que cela permet en plus, si on le veut : ouvrir au bloc trouvé.

### 2.3 Petits écarts

| Sujet | Android | iOS |
| --- | --- | --- |
| Icône qui suit le personnage et l'accent | changée en silence au lancement | iOS affiche « Vous avez changé l'icône » à chaque fois : seulement sur un geste (« Mettre l'icône aux couleurs choisies ») |
| Icône en verre d'iOS 26 | — | le format en couches se compose dans un outil qui n'existe que sur Mac ; on livre l'icône classique (1024 px, variantes sombre et teintée), que le système habille |
| Voile d'ouverture d'1,5 s | à chaque lancement | l'écran de lancement d'iOS est une image fixe : fond `#1E3A30`, puis le voile dans l'app, raccourci à un fondu ; les règles d'Apple déconseillent de retarder l'accès |
| Journal protégé des captures | `FLAG_SECURE` | la capture d'écran ne se bloque pas ; le contenu est masqué dans le sélecteur d'apps |
| Barre du bas : deux onglets réels et trois entrées qui ouvrent un écran | `BottomNavigationView` | cinq onglets réels, chacun avec sa pile de navigation |
| Bandeau qui s'efface en lisant | `BandeauDefilant` | barre de navigation d'iOS 26, qui se réduit d'elle-même |
| « Aucune permission Internet » | propriété du manifeste | n'existe pas sur iOS : la promesse se tient par le code. Un test interdit toute URL hors de la liste (relais du vol, adsbdb), et la fiche de confidentialité le dit |
| Édition `light`, mise à jour par Obtainium, Play Protect | README | sans objet |
| Autorisations « batterie » et « démarrage automatique » | réglages système | sans objet |
| Glyphes ‹ › permutés à la main en RTL | `HalakhaActivity.kt:135-145` | miroir automatique |
| Divulgation avant les accès spéciaux | exigence de Google Play | gardée comme bonne pratique : expliquer avant la feuille du système |
| Écran de relecture | édition d'essai | construction interne |

### 2.4 Ce qu'iOS apporte, sans rien retirer

Par ordre d'intérêt pour la pratique. Aucun n'est nécessaire à la parité ; chacun est une tâche à part (ROADMAP).

1. **Live Activity** de la séance, écran verrouillé et Dynamic Island (elle est aussi la réponse à l'absence de service).
2. **Widgets d'écran verrouillé et StandBy** : la série, la prière du moment et sa limite.
3. **Siri, Raccourcis, bouton Action, Centre de contrôle** : « Commence ma hitbodedout », par `AppIntent`.
4. **Spotlight** : retrouver une prière, un psaume, un livre depuis la recherche du téléphone.
5. **Minuterie système** (AlarmKit) pour le signal de fin.
6. **Filtre de mode de concentration**.
7. **iPad** : deux colonnes en lecture (hébreu, traduction), barre latérale, clavier.

### 2.5 La barre de qualité

Un Apple Design Award récompense, entre autres, l'inclusion, l'interaction, le plaisir, le visuel. Ce que cela demande ici, en critères vérifiables :

| Critère | Engagement |
| --- | --- |
| Inclusion | VoiceOver sur chaque écran, en trois langues, hébreu compris ; texte du système jusqu'aux tailles d'accessibilité sans perte ; « Réduire les animations » respecté partout (Android le fait déjà) ; fond « Contraste élevé » ; צדיק / צדקת et le personnage féminin ; droite-à-gauche sans défaut |
| Interaction | retours haptiques aux mêmes endroits qu'Android (anneau touché, anneau fermé, boussole de face, trophée) ; aucun geste caché sans équivalent visible |
| Plaisir | la danse, les confettis, le trophée qui se retourne : portés image par image, pas approchés |
| Visuel | les 36 palettes, contrastes tenus par le test porté de `PaletteTest` ; le verre d'iOS 26 pour les barres et la barre de lecture, jamais sur le texte saint |
| Performance | premier écran en moins de 400 ms ; défilement du lecteur sans saccade sur le plus long livre ; installation sous 200 Mo |
| Honnêteté | chaque horaire avec sa méthode ; « estimation » dite ; sources affichées ; aucun reproche (« Pas encore de série ») |

## 3. Modèle de données Swift et format JSON

### 3.1 Choix : des fichiers `Codable`, pas SwiftData

**Recommandation : fichiers JSON `Codable` dans un conteneur App Group, écrits par un seul `actor`.** Les raisons, par ordre de poids :

1. **Le format d'export est déjà le format de stockage.** Sur Android, le journal est une chaîne JSON `{date → {minutes, note, themes, note_seule}}` dans `SharedPreferences` (`Store.kt:203-248`), et l'export recopie cette carte telle quelle (`Store.kt:1490-1492`). Garder cette forme sur iOS supprime toute couche de conversion : importer une sauvegarde Android, c'est décoder puis fusionner.
2. **Les extensions.** Le bouclier, la surveillance `DeviceActivity`, les widgets et les Live Activities tournent dans d'autres processus, avec très peu de mémoire (§ 2.1.9). Un petit fichier JSON lu d'un trait leur convient ; une pile SwiftData/Core Data ouverte dans une extension de quelques mégaoctets, avec deux processus sur la même base, est exactement ce qu'il faut éviter.
3. **Le volume.** Dix ans de pratique font 3 650 lignes. Android relit et réécrit tout le journal à chaque séance sans que cela se voie ; l'import est plafonné à 2 Mo (`SettingsActivity.kt:657`). Aucune requête, aucun index, aucune relation : rien de ce que SwiftData apporte.
4. **Swift 6.** Un `actor Depot` propriétaire du fichier donne l'isolation stricte sans effort ; `ModelContext` n'est pas `Sendable` et impose `@ModelActor` partout.
5. **Le cloud, sans Mac.** Un paquet Swift qui ne dépend que de Foundation se compile et se teste sur un runner **Linux** (dix fois moins cher qu'un runner macOS, § 7). SwiftData n'existe pas sur Linux.
6. **Les migrations.** Android n'a jamais migré de schéma : il lit avec `optInt`/`optString` et ignore ce qu'il ne connaît pas. Le décodage tolérant fait la même chose, à l'identique.

Ce qu'on perd : la synchronisation CloudKit « gratuite » de SwiftData. Elle n'est pas voulue en v1 (« rien ne quitte l'appareil ») ; si elle l'est un jour pour l'iPad (décision D7), la règle de fusion de l'import (§ 3.5) est déjà une règle de réconciliation, et `CKSyncEngine` s'y branche avec un enregistrement par jour.

### 3.2 Les fichiers

Conteneur partagé `group.com.myhitbodedut` (app, widgets, extensions de la barrière).

| Fichier | Équivalent Android | Contenu | Écrit par | Lu par | Sauvegarde iCloud |
| --- | --- | --- | --- | --- | --- |
| `journal.json` | `myhitbodedut-journal.xml` | `days`, `journal_plus`, `first_name` | l'app seule | app, widgets | **exclu** par défaut (`isExcludedFromBackup`), comme `backup_rules.xml` ; décision D6 |
| `reglages.json` | `myhitbodedut.xml` | tous les réglages, **sous les noms de clés d'Android** (`window_start`, `lieu_latitude`, `siddur_nusah`…) | l'app seule | app, widgets, extensions | inclus |
| `lecture.json` | clés `favoris`, `chizuk_favoris`, `marques_pages`, `position:*`, `derniere_lecture` | favoris, marque-pages (60 au plus), places de lecture | l'app seule | app | inclus |
| `seance.json` | `session_started_at`, `session_ends_at`, `session_target`, `session_theme` | la séance en cours, en millisecondes Unix | app, intention « Commencer » | app, extensions, Live Activity | exclu (état éphémère) |
| `barriere/selection.plist` | `blocked_apps` | la `FamilyActivitySelection` (jetons opaques, liés à l'appareil) | l'app seule | extensions | exclu (inutilisable ailleurs) |
| `barriere/etat.json` | — (calculé par `GateStatus`) | instantané pour les extensions : fenêtre, report, jours exemptés à venir, série, textes du bouclier dans la langue choisie | l'app seule | extensions | exclu |
| `barriere/boite.jsonl` | — | événements **ajoutés** par les extensions (« déjà faite », « plus tard », réveils) ; l'app les verse au journal puis vide le fichier | extensions (ajout seul) | app | exclu |
| `Documents/Musique/` | URI `content://` persistantes | les morceaux ajoutés, **copiés** dans l'app | l'app | app | inclus |

Règle d'or : **un seul écrivain par fichier**, écriture atomique (`Data.write(options: .atomic)`). Les extensions n'écrivent jamais le journal : elles ajoutent une ligne à la boîte. C'est ce qui évite les verrous entre processus.

### 3.3 Les types

```swift
// Paquet « Coeur » : Foundation seule, compilable sur Linux.

/// Un jour civil, sans heure ni fuseau : l'équivalent de java.time.LocalDate.
/// Jamais de `Date` pour un jour : c'est la première source d'erreurs de fuseau.
public struct JourCivil: Hashable, Comparable, Sendable, Codable {
    public let annee: Int, mois: Int, jour: Int
    public init?(iso: String)            // « 2026-11-04 », aller-retour strict (Store.dateValide)
    public var iso: String { get }
    public func plus(jours: Int) -> JourCivil   // arithmétique en jours juliens, pas de Calendar
    public var jourDeSemaine: Int { get }       // 1 = dimanche … 7 = samedi
}

/// Store.DayRecord
public struct Journee: Sendable, Equatable {
    public var minutes: Int            // cumul des séances du jour
    public var note: String            // 4 000 caractères au plus (Store.NOTE_MAX)
    public var themes: [String]        // clés de Theme ; une clé inconnue est conservée
    public var noteSeule: Bool         // une note sans hitbodedout ne valide pas le jour
    public var faite: Bool { !noteSeule }
}

/// JournalPlus.Plus
public struct JournalPlus: Sendable, Equatable {
    public var avant: Int, apres: Int          // humeur 0 (non dite) à 5
    public var gratitude: String, travail: String   // 200 caractères au plus
}

public struct Journal: Sendable, Equatable {
    public var jours: [JourCivil: Journee]
    public var plus: [JourCivil: JournalPlus]
    public var prenom: String                  // 40 caractères au plus
}

/// La sauvegarde échangée avec Android et le web. Décodage tolérant, encodage canonique.
public struct Sauvegarde: Sendable, Equatable {
    public var format: String                  // « myhitbodedut »
    public var version: Int                    // 1
    public var exportedAt: String?             // jamais interprété
    public var days: [(JourCivil, Journee)]    // l'ordre du fichier est gardé
    public var settings: ReglagesExportes?     // chaque champ optionnel
    public var pausedDates: [String]
    public var blockedApps: [String]           // paquets Android, gardés tels quels
    public var journalPlus: [JourCivil: JournalPlus]?   // clé du web, absente d'Android
}

public actor Depot {                           // l'unique écrivain
    public func journal() -> Journal
    public func modifier(_ changement: @Sendable (inout Journal) -> Void) throws
    public func importer(_ donnees: Data, aujourdhui: JourCivil) throws -> Int?   // nil : fichier invalide
    public func exporter(maintenant: Date) -> Data
}
```

Les énumérations gardent les clés d'Android comme valeurs brutes, et c'est ce qui rend les réglages portables :

| Type | Valeurs (`rawValue`) | Défaut | Source |
| --- | --- | --- | --- |
| `Theme` | `emotions`, `gratitude`, `decisions`, `famille`, `zivoug`, `parnassa`, `avoda`, `difficultes`, `croissance`, `autre` ; aucun = absence | aucun | `Theme.kt:22-33` |
| `Adresse` | `m`, `f` ; aucun = `""` | aucun | `Adresse.kt:19-20` |
| `ModeApparence` | `auto`, `clair`, `sombre` | `auto` | `Apparence.kt:33-35` |
| `Fond` | `vert`, `blanc`, `sable`, `bleu`, `rose`, `contraste` | `vert` | `Apparence.kt:44-49` |
| `Accent` | `vert`, `bleu`, `violet`, `bordeaux`, `ambre`, `turquoise` | `vert` | `Apparence.kt:58-63` |
| `Nusah` | `edot`, `sefard`, `ashkenaz` | `edot` | `Siddur.kt:32-34` |
| Morceau livré | `hamelech_basade`, `yanuka_nigoun_3`, `shpayer_*` (10), `ianir_*` (14) | le premier | `MusiquePlay.kt:15-40` |

### 3.4 Le format JSON, version 1

Trois programmes l'écrivent aujourd'hui : Android (`Store.exportJson`, `Store.kt:1484-1522`), le site (`web/src/js/store.js:509-547`) et, demain, iOS. iOS doit **lire les trois** et **écrire un fichier qu'Android et le site relisent sans perte**.

```json
{
  "format": "myhitbodedut",
  "version": 1,
  "exported_at": "2026-11-13T08:15:30.123Z",
  "days": {
    "2026-11-03": { "minutes": 20, "note": "Dehors, avant le lever du jour.", "themes": ["gratitude", "parnassa"] },
    "2026-11-04": { "minutes": 0, "note": "Pas pu aujourd'hui.", "note_seule": true }
  },
  "settings": {
    "window_start": 360, "window_end": 660, "snooze_minutes": 15,
    "target_minutes": 15, "daily_goal_minutes": 0,
    "pause_shabbat": true, "in_israel": false,
    "reminder_enabled": true, "reminder_minutes": 420, "reminder_times": [420, 1260],
    "first_name": "", "hide_countdown": false, "guided_hitbodedut": false,
    "music_enabled": true, "music_volume": 60, "music_shuffle": false, "music_track": "hamelech_basade",
    "adresse": "m", "apparence_mode": "auto", "apparence_fond": "vert", "apparence_accent": "vert"
  },
  "paused_dates": ["2026-10-30"],
  "blocked_apps": ["com.instagram.android", "com.whatsapp"],
  "journal_plus": {
    "2026-11-03": { "avant": 2, "apres": 4, "gratitude": "La santé des enfants.", "travail": "La patience." }
  }
}
```

**Racine**

| Clé | Type | Android l'écrit | Le site l'écrit | À l'import |
| --- | --- | --- | --- | --- |
| `format` | chaîne | oui | oui | doit valoir `myhitbodedut`, sinon fichier refusé |
| `version` | entier `1` | oui | oui | **jamais lu** (ni Android ni le site) |
| `exported_at` | chaîne ISO-8601 UTC | `Instant.toString()` (fraction de 0, 3, 6 ou 9 chiffres) | `toISOString()` (3 chiffres) | **jamais lu** : ne pas faire échouer l'import sur sa forme |
| `days` | objet date → journée | oui | oui | fusion, § 3.5 |
| `settings` | objet | 21 clés | les mêmes, celles de la barrière et des rappels seulement si elles viennent d'un import | chaque clé est facultative |
| `paused_dates` | tableau de dates | oui | oui | réunion ; les dates invalides tombent |
| `blocked_apps` | tableau de chaînes | noms de paquets Android | recopié tel quel | réunion ; les chaînes vides tombent |
| `journal_plus` | objet date → `{avant, apres, gratitude, travail}` | **non** | oui (« une clé de plus, qu'Android ignore », `store.js:543`) | Android l'ignore ; le site ne remplace pas un jour déjà renseigné |

**Une journée** (`Store.toJson`, `Store.kt:256-265`) : `minutes` (entier), `note` (chaîne), `themes` (tableau de chaînes, **clé absente** quand il est vide), `note_seule` (booléen, **clé absente** quand il est faux). La clé de la journée est une date ISO stricte, `AAAA-MM-JJ`.

**Les réglages** : `window_start`, `window_end`, `reminder_minutes` et chaque élément de `reminder_times` sont des minutes depuis minuit (0 à 1439) ; `snooze_minutes` 1 à 240 ; `target_minutes` 1 à 240 ; `daily_goal_minutes` 0 à 240 (0 = « comme la durée habituelle ») ; `music_volume` 0 à 100 ; `music_track` l'identifiant d'un morceau, `""` si aucun ; `adresse`, `apparence_*` : les valeurs brutes du § 3.3.

### 3.5 L'import : mêmes règles qu'Android, ligne pour ligne

Portage de `Store.importJson` (`Store.kt:1525-1624`). C'est une **fusion**, jamais un remplacement.

| Élément | Règle | Source |
| --- | --- | --- |
| Taille | 2 Mo au plus, sinon refus | `SettingsActivity.kt:557-575` |
| Validité | JSON lisible et `format == "myhitbodedut"`, sinon `nil` (« fichier invalide ») | `Store.kt:1526-1527` |
| Clé de journée | date ISO stricte qui se réécrit à l'identique ; sinon la ligne est ignorée | `Store.kt:268-270`, `1537` |
| Journée à venir | ignorée (aujourd'hui est accepté, demain non) | `Store.kt:1538` |
| `minutes` | ramenées entre 0 et 1 440 | `Store.kt:1541` |
| `note` | coupée à 4 000 caractères | `Store.kt:1542` |
| Jour déjà présent | minutes : le **maximum** des deux ; note : celle d'ici si elle n'est pas vide, sinon celle du fichier ; sujets : la **réunion**, sans doublon, ceux d'ici d'abord ; `note_seule` : vrai seulement si vrai des deux côtés | `Store.kt:1547-1559` |
| Compte rendu | le nombre de journées lues dans le fichier, fusions comprises | `Store.kt:1561` |
| `window_*` | pris s'ils sont entre 0 et 1 439, sinon le réglage d'ici reste | `Store.kt:1571-1575` |
| `snooze_minutes`, `target_minutes`, `daily_goal_minutes`, `music_volume` | ramenés dans leurs bornes | `Store.kt:1576-1583`, `1600` |
| `reminder_times` | la liste si elle existe (valeurs 0 à 1 439, triées, sans doublon), sinon `reminder_minutes` seul | `Store.kt:1590-1593` |
| `first_name` | pris s'il est présent, espaces retirés, 40 caractères | `Store.kt:1594`, `1273` |
| `music_track` | pris s'il n'est pas vide **et** s'il désigne un morceau livré sur iOS ; une URI `content://` d'Android est ignorée | adaptation iOS |
| `adresse`, `apparence_*` | pris s'ils portent une valeur connue ; **une valeur inconnue est ignorée** (règle du site, `store.js:615-618` ; Android, lui, retombe sur le défaut) | adaptation |
| `paused_dates` | réunies à celles d'ici ; dates invalides retirées | `Store.kt:1613-1617` |
| `blocked_apps` | **gardés tels quels dans `reglages.json`, sans effet sur iOS** (§ 3.7) | adaptation iOS |
| `journal_plus` | pour chaque date valide et passée : pris seulement si le jour n'a rien ici | `store.js:587-592` |

Tolérance de type : Android lit avec `optInt`, `optBoolean`, `optString`. Le décodeur iOS accepte donc ce qu'ils acceptent : un nombre écrit en chaîne (`"20"`), un nombre décimal (tronqué), un booléen écrit `"true"`. Le site est plus strict (`Number.isInteger`) ; iOS suit Android, le plus tolérant des deux.

Après l'import, comme sur Android (`SettingsActivity.kt:582-591`) : appliquer le clair ou le sombre, recharger les widgets, replanifier les notifications, recalculer la barrière.

### 3.6 L'export : ce qu'iOS écrit

- Les **mêmes clés qu'Android, dans le même ordre**, indentées de deux espaces, en UTF-8 sans BOM, par un petit sérialiseur ordonné (une centaine de lignes ; `JSONEncoder` ne garde pas l'ordre des clés). Les journées sont écrites dans l'ordre des dates.
- `exported_at` : UTC avec millisecondes, `2026-11-13T08:15:30.123Z`.
- `themes` et `note_seule` absents quand ils sont vides ou faux, comme Android.
- `window_start`, `window_end`, `snooze_minutes`, `reminder_*` : **les vraies valeurs d'iOS**, puisque la barrière et les rappels y existent avec le même sens.
- `blocked_apps` : la liste reçue d'Android, **recopiée sans y toucher** (ou `[]`). C'est la règle que le site applique déjà aux réglages qu'il n'a pas, « pour qu'un aller-retour par l'iPhone ne les remette pas à zéro sur Android » (`store.js:516-518`).
- `journal_plus` : écrit, comme le site.
- Nom proposé : `myhitbodedut-AAAA-MM-JJ.json` (`SettingsActivity.kt:168`) ; type `public.json`.

### 3.7 Ce que la sauvegarde ne transporte pas

**Constat (vérifié dans `Store.exportJson`)** : l'export d'Android ne contient ni le journal enrichi (`journal_plus` : humeur, gratitude, « à travailler »), ni le journal du Tikoun (`tikkun_journal`, dont dépendent ses trophées), ni le noussa'h, ni le lieu des zmanim, ni les favoris, marque-pages et places de lecture, ni les noms donnés aux morceaux, ni les réglages de lecture, de Levana, d'allumage, de halakha, d'écran d'ouverture. Une migration Android → iPhone faite aujourd'hui garde donc les journées, les notes, les sujets, la série et les réglages principaux, et **perd le reste**.

Trois réponses possibles (décision D8) :

1. **Ne rien changer** : iOS écrit le v1 d'Android plus `journal_plus`. L'utilisateur refait ses réglages de lecture et de lieu sur l'iPhone.
2. **Étendre côté iOS seulement** : iOS écrit en plus, **sous les noms des préférences d'Android**, `tikkun_journal`, `favoris`, `chizuk_favoris`, `marques_pages` à la racine, et `siddur_nusah`, `allumage_minutes`, `halakha_source`, `lecture_police`, `lecture_echelle`, `lecture_langues`, `ecran_ouverture`, `levana_usage`, `ambiance` dans `settings`. Android les ignore (`importJson` ne lit que les clés qu'il connaît) ; un iPhone les relit. Rien n'est gagné pour la migration depuis Android.
3. **Étendre aussi l'export d'Android** (une demande distincte, hors de ce document qui ne touche pas à `android/`) : une vingtaine de lignes dans `Store.exportJson`/`importJson`, les mêmes clés. C'est la seule voie qui rende la migration complète. **Recommandé avant de proposer la migration aux utilisateurs.**

**Les applications bloquées ne migrent pas, et ne peuvent pas migrer.** Android garde des noms de paquets (`com.instagram.android`) ; iOS ne connaît que des jetons opaques que seul le sélecteur d'Apple délivre, sur l'appareil même (§ 2.1.3). À l'import, l'écran de la barrière affiche la liste venue d'Android en aide-mémoire (« Sur Android, vous reteniez : instagram, whatsapp… ») au-dessus du bouton « Choisir les applications ».

### 3.8 La migration, vue de l'utilisateur

1. Sur Android : Réglages → Mes données → Exporter. Le fichier part par courriel, messagerie ou un dossier en ligne.
2. Sur l'iPhone, à la première ouverture, l'écran d'accueil de la présentation propose « Je viens d'Android » → sélecteur de fichiers (`fileImporter`).
3. L'app annonce « N journées importées », montre la série retrouvée, puis poursuit la présentation avec les réglages déjà remplis (durée, prénom, צדיק / צדקת, couleurs).
4. Si la sauvegarde contenait des applications bloquées : l'étape « Je suis avec Hachem » s'ouvre avec l'aide-mémoire du § 3.7.

Le même chemin sert à quitter la version web installée sur l'iPhone (elle écrit le même fichier).

### 3.9 Tests de conformité

| Fichier d'or | Ce qu'il prouve |
| --- | --- |
| `android-v1-reel.json` | une vraie sauvegarde du propriétaire (hors dépôt si elle contient des notes ; sinon anonymisée) se lit sans perte |
| `android-v1-forge.json` | toutes les branches : `themes` absent, `note_seule`, clé de date mal formée, date à venir, minutes hors bornes, note de 5 000 caractères, `reminder_minutes` sans `reminder_times`, nombres en chaînes |
| `web-v1.json` | `journal_plus` présent, clés de barrière absentes |
| aller-retour | `importer(exporter(x)) == x` ; `exporter(importer(android))` garde `blocked_apps` et les 21 réglages |
| fusion | les cas d'import et d'export du site, portés tels quels : `web/test/regles.test.mjs`, `journal-plus.test.mjs`, `musique.test.mjs`, `hitbodedut.test.mjs` (Android n'a pas de test d'exécution de `importJson` : il demande un `Context`) |
| ordre et forme | la sortie d'iOS, relue par un `JSONObject` de référence, rend les mêmes valeurs ; clés dans l'ordre d'Android |

Tous tournent sur Linux (paquet `Coeur`), sans simulateur.

## 4. Contenus

### 4.1 Où ils vivent aujourd'hui

Quatre endroits. Chemins relatifs à `android/app/src/main/`.

**A. Les fichiers JSON de `res/raw/`** : presque tout le texte. Lus en entier par `Json.readRaw` puis `org.json`, gardés en mémoire par l'objet `Data` (`ChizukCard.kt:153-244`).

| Contenu | Fichier | Taille | Produit par (`tools/`) | Source et droits déclarés |
| --- | --- | --- | --- | --- |
| Siddour, 3 rites, 38 textes chacun | `siddur_edot.json`, `siddur_sefard.json`, `siddur_ashkenaz.json` | 0,7 Mo chacun | `siddur_construction.py`, puis `siddur_occasions`, `siddur_nikkud`, `noms_kavanot`, `siddur_cheva_berakhot`, `siddur_meen_chaloch` | Torat Emet 357 et Daat (domaine public), Shaliehsaboo (CC0), **Metsudah 1981 (CC-BY)** pour la semaine en Sfard et Ashkenaz, **Wikipédia hébreu (CC BY-SA)** pour Yizkor et Chéva bérakhot |
| Ajouts du jour (1 572 annotations) | `siddur_annotations.json` | 334 Ko | `siddur_annotations.py` | dérivé des trois siddourim |
| Tehilim, hébreu, français, anglais | `tehilim.json` | 860 Ko | sans outil de création au dépôt ; `tehilim_conversion.py`, `traductions_tanakh.py` | tanach.us, Bible du Rabbinat 1899, JPS 1917 (domaine public) |
| Tikoun HaKlali | `tikkun_haklali.json` | 131 Ko | sans outil de création au dépôt ; `traductions_tanakh.py`, `traductions_textes.py` | psaumes du domaine public ; liturgie fournie par le propriétaire ; traduction de la liturgie originale |
| 'Hizouk, 171 textes | `chizuk.json` | 368 Ko | sans outil de création au dépôt ; `noms_divins.py`, `noms_abreges.py` | éditions du domaine public via Sefaria ; **86 extraits de « Bisdei Yaar » (Rav Shalom Arush), texte de l'éditeur** ; traductions originales |
| Sources de la hitbodedout, Tefilot, fiches d'articles | `bibliotheque.json` | 256 Ko | sans outil de création au dépôt, mêmes retouches | sources du domaine public ; 24 articles en **fiche seulement**, sans texte intégral |
| Phrases du guide par sujet | `guide_sujets.json` | 11 Ko | sans outil de création au dépôt | propre à l'app |
| Halakha du jour, Yalkout Yossef (788 se'ifim choisis) | `yalkut_yosef.json` | 410 Ko | `yalkut_yosef_construction.py` | **droits réservés à l'auteur ; saisie Torat Emet CC BY-NC-SA 2.5 ; accord déclaré** |
| Halakha du jour, Ben Ich Haï | `ben_ish_hai.json` | 2,0 Mo | `ben_ish_hai_construction.py` | Wikisource via Sefaria, domaine public |
| Hilloulot, 4 049 entrées | `hilloulot.json` | 1,1 Mo | `hilloulot_construction.py` depuis `tools/hilloulot/*.json` | Wikipédia hébreu (CC BY-SA 4.0), faits de hyomi et de Hidabroot, Torat Emet (CC BY-NC-SA 2.5) |
| Biographies, 2 346 | `hilloulot_bios.json` | 6,9 Mo | idem | **MyTzadik et המאיר לארץ, reprise avec mention, accord déclaré** |
| Douze livres | `livre_<id>.json`, `livres_titres.json` | 28,5 Mo, dont Likoutei Moharan 10,4 et **Kitsour Yalkout Yossef entier 11,5** | `livres_decoupe.py` depuis `livres/livres.json` | voir § 6.3 |
| Villes (51) | `villes.json` | 12 Ko | `villes_construction.py` | GeoNames, CC-BY 4.0, attribution affichée |
| Aéroports (3 226) et leurs noms | `aeroports.json`, `aeroports_noms.json` | 0,6 Mo | `aeroports_construction.py`, `aeroports_noms.py` | OurAirports (domaine public), fuseaux timezone-boundary-builder (ODbL, attribution), Wikidata (CC0) |
| Formes des trophées | `trophees_formes.json` | 6 Ko | `trophees_formes.py` | propre à l'app |
| Musique livrée, 26 morceaux | `*.m4a` | 73,7 Mo | fournis par le propriétaire, `ajoute_musique.py` | § 6.1 |

`livres/livres.json` (28 Mo) est la **source** des douze livres ; il n'entre pas dans l'APK.

**B. `res/values*/strings.xml`** : 1 184 chaînes, 36 pluriels et 2 tableaux en français, 1 139 chaînes en anglais et en hébreu (les 45 de différence ne se traduisent pas : nom de l'app, titres des morceaux). Outre l'interface, du contenu : les dix conseils (`tip_N_title`, `tip_N_body`), la présentation, les dix questions, les noms et descriptions des trophées, les libellés des fêtes, des ajouts et des zmanim, la note de la boussole.

**C. Des tables écrites dans le Kotlin** :

| Table | Fichier |
| --- | --- |
| Cinq temps de la hitbodedout guidée, **hébreu vocalisé et sources en dur** | `Hitbodedut.kt` |
| Échelles des paliers ; 11 familles et 128 niveaux de trophées, coûts, métaux | `Paliers.kt`, `Trophees.kt` |
| Portions des Tehilim (30 du mois, 7 de la semaine) ; ordre du Tikoun | `Tehilim.kt`, `Tikkun.kt` |
| Dix sujets de Tefilot ; dix sujets de séance ; dix questions ; sept écrans de présentation ; dix conseils | `Tefilot.kt`, `Theme.kt`, `QuestionsBlocage.kt`, `Onboarding.kt`, `Tips.kt` |
| Fenêtres de fête du Yalkout Yossef ; parachiot jointes du Ben Ich Haï | `YalkutYosef.kt`, `Halakha.kt` |
| Index de fête de KosherJava → clés ; liste des conditions | `CalendrierJuif.kt` |
| Profil des 15 zmanim ; minutes d'allumage | `Zmanim.kt` |
| 18 noms de livres en trois langues ; nombres en lettres | `Reference.kt` |
| 59 compagnies, 57 villes, noms de mois (saisie d'un vol) | `SaisieVol.kt` |
| Contour d'Israël (45 points) ; cible de la boussole | `TerritoireIsrael.kt`, `DirectionJerusalem.kt` |
| Poses par moment ; 21 correspondances du personnage féminin | `Character.kt`, `Personnage.kt` |
| Signes absents de chaque police | `PoliceHebraique.kt` |
| Liste des morceaux livrés | `MusiquePlay.kt` |

**D. Les ressources visuelles** : 50 illustrations WebP (`res/drawable-nodpi/`, 1,6 Mo), 71 dessins vectoriels (`res/drawable/`), 7 polices (`res/font/`, 0,75 Mo) et leurs 6 licences OFL (`assets/licences/`), couleurs et palettes (`res/values*/colors.xml`, `palettes.xml`).

S'y ajoute, hors d'Android : le modèle magnétique WMM2025 du site (`web/src/js/magnetisme.js`), que la boussole d'iOS reprend (§ 2.2.5).

### 4.2 `tools/export_contenu` : proposition

**Principe.** Android reste la source. L'outil **lit** `android/`, `web/` et `tools/`, et **n'écrit que sous `ios/`**. Il est déterministe et hors ligne. `web/build.mjs` fait déjà la même chose pour le site (copie des JSON, biographies par mois, chaînes par langue, liste des morceaux lue dans `MusiquePlay.kt`) : l'outil d'iOS en est le frère.

```
tools/export_contenu/
  export.py            # chef d'orchestre, Python 3, bibliothèque standard
  chaines.py           # strings.xml → Localizable.xcstrings
  recherche.py         # index de recherche (sqlite3)
  tables/              # petit projet Gradle autonome, hors de android/
    build.gradle.kts   #   compile des fichiers Kotlin purs de l'app, sans SDK Android
    Tables.kt          #   main() : écrit tables.json
    stubs/R.kt         #   généré : R.string.*, R.drawable.*, R.raw.* en entiers
    stubs/Annotations.kt  # androidx.annotation.StringRes, etc.
  README.md
```

| Étape | Entrée | Sortie sous `ios/Ressources/` | Méthode |
| --- | --- | --- | --- |
| 1. Textes | `res/raw/*.json` | `Contenu/*.json`, **octet pour octet** ; `hilloulot_bios/<mois>.json` ; les livres de plus de 2 Mo découpés en `livres/<id>/index.json` et un fichier par chapitre | copie, découpe |
| 2. Chaînes | `res/values/`, `values-en/`, `values-iw/strings.xml` | `Localizable.xcstrings` (clés = noms Android), `Tableaux.json` | `%1$s` → `%1$@`, `%d` → `%lld` ; pluriels (`one`, `two`, `other` en hébreu) ; échappements ; liste d'exclusion des chaînes propres à Android (divulgations, batterie, overlay) |
| 3. Tables du Kotlin | les fichiers du tableau C | `Contenu/tables.json` | **exécuter le Kotlin sur la JVM**, comme `tools/vecteurs_kosherjava` le fait déjà : le projet `tables/` compile les fichiers purs avec deux bouchons (`R`, annotations) et écrit les tables. Les identifiants de ressources redeviennent des noms de clés. Pour les deux tables prises dans des fichiers liés à Android (`Personnage.kt`, `PoliceHebraique.kt`) : expression régulière, **avec arrêt si rien n'est trouvé** |
| 4. Palettes | `colors.xml`, `palettes.xml`, jour et nuit | `Contenu/palettes.json` (13 jetons × 6 accents × 6 fonds × 2 modes) | lecture XML |
| 5. Images | `drawable-nodpi/*.webp`, `drawable/*.xml` | `Images/*.webp` tels quels (iOS lit le WebP) ; miniatures PNG des personnages pour le bouclier et les widgets ; icônes vectorielles en SVG | copie ; réduction ; conversion `VectorDrawable` → SVG (déjà écrite dans `web/build.mjs:71-92`) |
| 6. Polices | `res/font/*.ttf`, `assets/licences/` | `Polices/` | copie |
| 7. Musique | `MusiquePlay.kt`, `res/raw/*.m4a` | `Musique/*.m4a`, `Contenu/musique.json` | liste lue dans le source ; **jamais** `src/musique_hors_play` |
| 8. Recherche | siddourim, livres, halakha, hilloulot | `Contenu/recherche.sqlite` | texte passé par la même normalisation que `RechercheGlobale.nu` ; une liste de cas communs tient les deux écritures ensemble |
| 9. Vecteurs de test | `web/test/vecteurs_kosherjava.json`, `vecteurs_vol.json`, `vecteurs_wmm2025.txt`, `android/app/src/test/resources/zmanim_reference_*.json` | `ios/Paquets/Coeur/Tests/Ressources/` | copie |
| 10. Manifeste | tout ce qui précède | `ios/Ressources/MANIFESTE.json` : pour chaque fichier, sa source, sa taille, son empreinte SHA-256, sa licence et la mention à afficher | calcul |

**Ce qui est versionné.** Rien de généré, sauf `MANIFESTE.json`. Recopier 28 Mo de livres et 74 Mo de musique dans le dépôt le doublerait. La CI lance l'export avant de construire ; le manifeste, lui, est versionné et **comparé** : si un contenu d'Android change sans que le manifeste suive, la CI d'iOS échoue et dit quel fichier a bougé. C'est le pendant du contrôle `cmp` de `web.yml`.

**Contrôles repris d'Android.** Les tests de données (`DataLoadTest`, `SiddurTest`, `TehilimTest`, `TikkunTest`, `LivresTest`, `NomsDivinsTest`, `LicencesEditionsTest`, `TraductionTest`, `MusicFilesTest`, `VillesTest`) deviennent des tests Swift sur les ressources exportées : mêmes comptes (38 textes par rite, 150 psaumes, 2 527 versets), mêmes règles (aucune licence « unknown », aucune vocalisation d'éditeur, mêmes clés dans les trois langues, marqueurs de format concordants).

**Ce que l'outil ne fait pas.** Il ne reconstruit aucun contenu depuis ses sources d'origine (exports Sefaria, `airports.csv`…) : ces entrées ne sont pas dans le dépôt, et la chaîne de production d'Android reste la seule. Il ne traduit rien : les quelques chaînes propres à iOS (Temps d'écran, états de la barrière, signal de fin) s'écrivent à la main dans `ios/Ressources/Chaines/ios.xcstrings`, en trois langues, **à relire par le propriétaire** comme l'ont été celles d'Android.

### 4.3 Poids

| Lot | Poids |
| --- | --- |
| Textes (JSON) | 43,5 Mo |
| Musique (26 morceaux) | 73,7 Mo |
| Images, polices, index de recherche | environ 5 Mo |
| **Total des ressources** | **environ 120 Mo** |

L'app installée resterait sous 200 Mo, le seuil au-delà duquel iOS demande confirmation hors Wi-Fi. Tout embarquer garde la promesse du hors ligne dès la première ouverture. Si la musique grossit, Apple héberge des lots de ressources téléchargeables (Background Assets) sans serveur du développeur ; ce n'est pas nécessaire en v1.

## 5. Dépendances

### 5.1 KosherSwift

**Lequel.** Deux portages portent ce nom, tous deux cités par KosherJava :

| | `Elyahu41/KosherSwift` | `DanielSmith1239/KosherSwift` |
| --- | --- | --- |
| Licence | **LGPL 2.1**, celle de KosherJava | LGPL 3.0 |
| Forme | calque de l'API Java (classes, mêmes noms de méthodes) | types plus idiomatiques (`JewishDate`, énumérations) |
| Tests | fichiers d'or produits par KosherJava (`Golden/hebrew.tsv.gz`, `zmanim.tsv.gz`) | parité KosherJava, CI Linux (`swift:6.0`) |
| Dernière étiquette | 3.1.2, le 08/11/2026 | 3.0.0, le 22/10/2026 |

**Recommandation : `Elyahu41/KosherSwift`**, parce que `Zmanim.kt` et `CalendrierJuif.kt` s'y transposent méthode pour méthode, et que la licence est celle qu'Android accepte déjà.

**Quelle version : le point à ne pas manquer.** Android est sur **KosherJava 2.5.0** (`build.gradle.kts:217`). Or KosherJava a publié 3.0.0 le 21/10/2026, avec des ruptures, puis 3.1.0, et KosherSwift a suivi (lu dans ses sources le 13/11/2026) :

| Appel d'Android (2.5.0) | KosherSwift **1.10.11** (04/11/2026) | KosherSwift **3.1.2** |
| --- | --- | --- |
| `ComplexZmanimCalendar` | `ComplexZmanimCalendar` | `ComprehensiveZmanimCalendar` |
| `getSofZmanShmaMGA()`, `getSofZmanTfilaMGA()` | mêmes noms | `getSofZmanShmaMGA72Minutes()`, `getSofZmanTfilaMGA72Minutes()` |
| `getTzais72()` | même nom | `getTzais72Minutes()` |
| `getChatzos()` (le passage au méridien) | même nom | `getChatzosHayom()`, réglé par `useAstronomicalChatzos` |
| `getSolarMidnight()` : **milieu entre deux passages au méridien** | **même définition** | **minuit astronomique**, calculé directement |
| `formatParsha(…)` | `formatParsha(jewishCalendar:)` | `formatParshah(jewishCalendar:)` |
| `JewishCalendar(LocalDate)` | date de travail et fuseau | `JewishCalendar(localDate:)` |
| `TefilaRules`, `HebrewDateFormatter`, `NOAACalculator`, molad et Kiddouch Levana | présents | présents |

L'étiquette **1.10.11 est la dernière à l'API et aux définitions de l'ère 2.5** : c'est elle qui doit rendre, à la seconde, ce que rend Android. La 3.1.2 rendrait des 'hatsot de la nuit différents de quelques secondes, donc parfois une minute affichée différente d'un téléphone à l'autre.

**Recommandation : 1.10.11, épinglée par révision exacte, dans un fork de l'organisation.** Passer à la 3.x se décidera pour les trois plateformes ensemble (Android, site, iOS), vecteurs régénérés (décision D4).

**La validation, par `tools/vecteurs_kosherjava`.** L'outil existe et son fichier aussi : `web/test/vecteurs_kosherjava.json` (762 Ko), produit en faisant répondre le code Android lui-même. Le site s'y mesure déjà. iOS s'y mesure de la même façon :

| Test Swift | Référence | Exigence |
| --- | --- | --- |
| `VecteursCalendrier` | 3 896 entrées : chaque jour du 01/09/2025 au 31/12/2030, en diaspora et en Israël ; champs `h` (jour, mois, année), `t` (date en hébreu), `f` (fêtes), `o` (omer), `p` (paracha), `x` (chômé), `c` (conditions) | **égalité stricte**, jour par jour |
| `VecteursZmanim` | 35 lignes : Jérusalem, Paris, New York, Melbourne, Tromsø × 7 dates ; les 15 zmanim et l'allumage, ou `ABSENT` | une seconde |
| `ReferenceNOAA`, `ReferencePyEphem` | `android/app/src/test/resources/zmanim_reference_*.json` | 2 s (20 s pour 'hatsot), 60 s |
| `VecteursVol` | `web/test/vecteurs_vol.json`, 26 vols | 2 s, mêmes réserves, mêmes dates de ligne |

Ce que ces vecteurs **ne couvrent pas**, et qu'il faut ajouter : le molad et les bornes de Birkat haLevana (`Levana.kt`), la paracha à venir (`Halakha.kt`), `isRoshChodesh` et la numérotation des mois (`YalkutYosef.kt`). Proposition : un second générateur à côté du premier, `tools/vecteurs_kosherjava/VecteursIos.kt`, qui écrit un fichier propre à iOS. Le fichier du site n'est pas touché, `android/` non plus.

**Si les vecteurs ne passent pas.** Dans l'ordre : corriger dans le fork (les corrections d'une bibliothèque LGPL se publient, ce qui va de soi) et les proposer en amont ; essayer l'autre portage ; en dernier recours, porter soi-même les trois parties utilisées (calcul NOAA, calendrier, `TefilaRules`), comme le site l'a fait pour `TefilaRules` en 138 lignes (`web/src/js/tefila.js`). Dans tous les cas le juge est le même fichier.

**Swift 6.** KosherSwift n'a aucune annotation `Sendable` et ses classes sont modifiables. Elles ne quittent jamais la fonction qui les crée : `Zmanim.jour(lieu:date:)` construit le calendrier, lit les quinze valeurs et rend des `struct` `Sendable`. Import en `@preconcurrency`.

**Linux.** Les sources lues n'importent que Foundation. Qu'elles se compilent et passent leurs tests sous Linux reste **à vérifier** (tâche 2 de la feuille de route) ; si ce n'est pas le cas, les tests de calendrier tournent sur macOS et le reste du cœur sur Linux.

### 5.2 Rien d'autre dans l'application

| Android | iOS | Dépendance ajoutée |
| --- | --- | --- |
| `com.kosherjava:zmanim` | KosherSwift | **oui, la seule** |
| `com.google.zxing:core` (code-barres du billet) | Vision, PDFKit | non |
| `org.json` | Foundation | non |
| AppCompat, Material, ConstraintLayout, RecyclerView | SwiftUI | non |
| vues de graphique dessinées à la main | Swift Charts | non |
| recherche en mémoire | SQLite, présent dans iOS | non |

Cadres d'Apple employés : SwiftUI, WidgetKit, ActivityKit, AppIntents, FamilyControls, ManagedSettings, ManagedSettingsUI, DeviceActivity, UserNotifications, AVFoundation, MediaPlayer, CoreLocation, CoreMotion, Vision, PDFKit, BackgroundTasks, Charts ; en option AlarmKit et CoreSpotlight.

Ni mesure d'audience, ni rapport de plantage tiers, ni bibliothèque de réseau, d'images, d'animation ou d'architecture. Les plantages se lisent dans App Store Connect, pour les utilisateurs qui ont accepté de les partager avec Apple.

### 5.3 Outils de construction (hors de l'application)

| Outil | Pourquoi | Remarque |
| --- | --- | --- |
| XcodeGen 2.46.0 | le projet Xcode est **engendré** d'un fichier texte ; sans Mac, personne ne peut cliquer dans Xcode | les extensions Temps d'écran sont des cibles `app-extension` dont le point d'extension se déclare dans leur `Info.plist` |
| fastlane | signature, envoi à TestFlight, fiche, captures | clé d'API d'équipe |
| Python 3, JDK, Gradle | `tools/export_contenu` | déjà employés par le dépôt |
| Swift Testing, XCTest | tests | livrés avec Xcode |

**Refusée, avec regret : une bibliothèque de comparaison d'images.** Ses images de référence doivent être produites sur le simulateur même de la CI, ce qui ne peut se préparer sans Mac. Les captures sont donc produites par les tests d'interface, publiées, et regardées (§ 7.6).

## 6. Droits : ce que l'App Store change

`PUBLICATION_PLAY_STORE.md` § 3 a déjà tranché l'essentiel pour Google Play. L'App Store est la même diffusion publique et mondiale ; tout ce qui y est écrit vaut. Trois choses s'ajoutent.

1. **Apple peut demander la preuve.** Règles 5.2.1 à 5.2.3 : pas de contenu protégé « without permission », et « Authorization must be provided upon request ». La fiche de l'app porte une déclaration de droits sur les contenus de tiers. Les écrits des ayants droit doivent être **prêts avant la soumission**, pas cherchés après un refus.
2. **Les écrits nomment-ils Google Play ?** Le cahier des charges demandait un accord couvrant « une application mobile, via Google Play ». Pour chaque accord, faire préciser « toutes plateformes, dont l'App Store d'Apple », ou en obtenir un second.
3. **L'enveloppe d'Apple.** Toute app de l'App Store est distribuée sous protection technique et sous le contrat de licence d'Apple. Cela frotte avec les licences qui interdisent d'ajouter des restrictions : CC BY-SA, CC BY-NC-SA, LGPL. Ce n'est pas un interdit, c'est un point à traiter licence par licence (§ 6.3, § 6.5).

Aucun de ces points n'est un avis juridique : ce sont des lectures, comme dans le cahier des charges de Play.

### 6.1 Musique

iOS livre **la liste de la version Play**, et elle seule (`MusiquePlay.kt`, 26 morceaux, 73,7 Mo). Il n'existe pas d'équivalent de l'édition GitHub : TestFlight est aussi une distribution par Apple.

| Morceaux | Base du droit (d'après le dépôt) | Avant l'App Store |
| --- | --- | --- |
| `yanuka_nigoun_3` | accord du Yanuka, déclaré | l'avoir par écrit, toutes plateformes |
| `shpayer_*` (10), `ianir_*` (14) | accord écrit du 29/10 de נעם שפייר et יניר קילינסקי, « toutes leurs musiques » | vérifier qu'il n'est pas limité à Google Play |
| `hamelech_basade` | « déclaré libre de droits » | la réserve du cahier des charges demeure : une mélodie peut être libre et son **enregistrement** ne pas l'être ; noter l'interprète, la source, la date |
| 30 niggounim sans titre, Ishay Ribo, MBD, Motty Steinmetz, Shmuel, Shneor Lerer | provenance inconnue ou autorisation non demandée | **absents d'iOS** ; l'utilisateur peut ajouter ses propres fichiers |

Deux remarques propres à Apple : les titres portent le nom des artistes (c'est un usage de leur nom, couvert par leur accord) ; le mode d'arrière-plan audio ne se justifie que par cette lecture, ce qui est le cas.

### 6.2 Vol : OpenSky et adsbdb

**OpenSky.** Ses conditions (relues le 13/11/2026) : l'API REST est réservée à la recherche et à l'enseignement sans but lucratif ; tout usage « in any operational capacity », dont l'intégration à un produit en service, demande une **licence écrite**, même sans but lucratif. Le dépôt consigne un échange (courriel du 28/10/2026, ticket 837455) : application gratuite, sans publicité ni fonction payante, admise, **à quatre conditions** : les données sont demandées par **le relais**, avec le client OAuth2 du compte, et non par chaque téléphone ; la réponse n'est gardée qu'un instant et partagée par zone ; ni revente ni redistribution ; l'attribution figure **dans l'app et sur la page du magasin**.

Conséquences pour iOS :

- **L'app iOS n'appelle jamais OpenSky directement.** Le chemin « sans relais » d'Android (`SuiviVol.kt`, accès anonyme) n'est pas porté. Sans adresse de relais à la construction, le suivi en direct n'apparaît pas.
- Le relais (`tools/relais_vol`) n'est **pas encore en ligne** (`tools/relais_vol/README.md:46-50`). C'est un préalable.
- `tools/relais_vol/README.md:69-70` le dit déjà : une publication sur l'App Store est « à revoir avec les conditions d'OpenSky ». Demander à OpenSky de confirmer que l'accord couvre l'app iOS.
- L'attribution « Données aéronautiques : OpenSky Network (opensky-network.org) » va dans l'app (elle y est) **et dans le texte de la fiche App Store**.
- Le relais est un serveur tenu par le développeur. La page de confidentialité dit aujourd'hui « aucun serveur du développeur » : à corriger pour iOS.

**adsbdb.** Pas de conditions publiées ; API gratuite, sans compte ; les routes sont l'œuvre de David J. Taylor et Jim Mason et « may not be copied, published, or incorporated into other databases without the explicit permission ». Les deux règles du cahier des charges se gardent : **aucun cache, aucune liste de routes embarquée** ; attribution affichée. Le courriel de courtoisie au mainteneur, « facultatif mais prudent » pour Play, devient **recommandé** : c'est la pièce qu'Apple demanderait.

**Plus simple pour une v1** : livrer le vol hors ligne (calcul, saisie, billet, GPS, rappels), qui ne dépend de personne, et n'ouvrir les services en ligne que lorsque le relais tourne et que les deux écrits existent (décision D10).

### 6.3 Textes

| Contenu | Droits d'après le dépôt | Avant l'App Store |
| --- | --- | --- |
| **Kitsour Yalkout Yossef, livre entier** (`livre_yalkut_yosef_kitsour.json`, 1 048 simanim) et sélection quotidienne (`yalkut_yosef.json`) | « כל הזכויות שמורות » au Rav Yitzhak Yosef ; saisie Torat Emet **CC BY-NC-SA 2.5** ; « licence reçue par le propriétaire » ; **aucune pièce au dépôt** (`FEUILLE_DE_ROUTE.md:1048-1051`) | **le point le plus exposé.** L'œuvre est d'un auteur vivant ; elle n'est pas dans la bibliothèque de Sefaria. Obtenir l'écrit, nommant l'app et l'App Store. À défaut : iOS livre sans le livre entier (le Ben Ich Haï, du domaine public, reste la halakha du jour) |
| 86 extraits de « Bisdei Yaar » (Rav Shalom Arush) dans `chizuk.json` | « texte de l'éditeur » ; autorisation déclarée le 22/09 ; la feuille de route note ailleurs « breslev.co.il : accord écrit nécessaire » | écrit à obtenir, ou extraits retirés d'iOS (la règle de publication de `ChizukRules` sait écarter des textes) |
| Tefila LiChlomo (Yanuka, מכון ים שלמה) | « כל הזכויות שמורות », autorisation déclarée | écrit |
| Hishtapkhout haNefesh, Kokhvei Or (or-breslev.co.il) | œuvres du domaine public, édition reprise « avec l'accord déclaré » | écrit |
| Biographies de MyTzadik et de המאיר לארץ (2 346) | « reprise autorisée avec mention, accord reçu » | écrit ; la mention et le lien restent affichés |
| Extraits de Wikipédia hébreu (hilloulot, Yizkor, Chéva bérakhot) | CC BY-SA 4.0 | attribution et lien (déjà affichés) ; écran « Sources et licences » ; les données dérivées restent disponibles sous la même licence (le fichier du dépôt, ou le site) |
| Siddour Sfard et Ashkenaz de la semaine (Metsudah 1981) | CC-BY | attribution (déjà affichée) |
| Tout texte sous licence « non commerciale » | — | l'app reste **gratuite, sans achat, sans publicité, sans don** intégré |
| Tanakh, Likoutei Moharan, Sefer haMidot, Ben Ich Haï, traductions de 1899 et 1917 | domaine public | rien |
| Traductions françaises et anglaises des livres | originales, « relecture humaine souhaitable » | rien de juridique ; la règle 1.1.5 d'Apple vise les citations religieuses « inaccurate or misleading » : la prudence d'Android (relu, vérifié, « le texte fait foi ») est le bon niveau |
| 24 articles (Chaar Breslev, Acher BaNa'hal) | protégés ; **fiches seulement**, jamais le texte | rien : la règle de `LibraryRules` se porte avec son test |
| Villes, aéroports, fuseaux, noms | GeoNames CC-BY 4.0, OurAirports (domaine public), ODbL, Wikidata CC0 | attributions (déjà affichées) |

Deux incohérences à corriger dans les données avant de les exporter, qui ne sont pas des questions d'iOS mais se verraient en revue : la chaîne `halakha_yalkut_source` et le `_meta` de la sélection disent « une sélection, non le livre entier » alors que le livre entier est livré depuis le 19/10.

### 6.4 Images et polices

- **Le personnage** (42 poses, deux icônes, cinq scènes) : fourni par le propriétaire. Le dépôt ne dit ni qui l'a dessiné ni sous quels droits. À consigner : c'est le visage de l'app sur la fiche.
- **La photo d'ouverture** : Wikimedia Commons, domaine public (README, « Les illustrations »).
- **Les polices** : six familles sous OFL 1.1, licences jointes ; l'OFL permet l'embarquement. Les textes de licence s'affichent dans « Sources et licences ».

### 6.5 KosherSwift et la LGPL 2.1

La LGPL 2.1 laisse l'app fermée, mais demande que l'utilisateur puisse **refaire le lien** avec une version modifiée de la bibliothèque. Un paquet Swift se lie statiquement : il faut donc soit publier le code de l'app, soit offrir par écrit les fichiers objets. L'auteur de KosherJava dit son intention : l'app peut rester fermée, seuls les changements à la bibliothèque se publient. Les avis divergent sur la compatibilité de principe entre LGPL et App Store ; la pratique est répandue ; Apple renvoie à un juriste.

Ce qui met l'app en règle sans débat : (1) la mention de KosherSwift, de sa version exacte et de la licence dans « Sources et licences » ; (2) le fork public de la bibliothèque, avec toute correction ; (3) une **offre écrite** de fournir les objets de l'app, ou, plus simple, la publication des sources du dossier `ios/` (décision D12). Android embarque déjà KosherJava sous la même licence : la question n'est pas nouvelle pour le projet.

### 6.6 Conformité de la fiche

| Sujet | À faire |
| --- | --- |
| Compte | individuel : le **nom légal** du titulaire est affiché comme vendeur (pas « MyHitbodedut Team ») ; organisation : numéro D-U-N-S (décision D1) |
| Fiche de confidentialité | « aucune donnée collectée » tant que le vol en direct est éteint ; avec le relais : le dire, et dire ce qu'il reçoit (indicatif, position au dixième de degré) et qu'il ne garde rien |
| Règles de confidentialité | la page publique existe en trois langues ; lui ajouter une section iOS (Temps d'écran au lieu des deux accès spéciaux, relais) |
| `PrivacyInfo.xcprivacy` | obligatoire pour l'app et chaque extension : raison d'usage des préférences partagées (App Group), dates de fichiers |
| Chiffrement | HTTPS du système seulement : `ITSAppUsesNonExemptEncryption = NO` |
| Âge | nouveau questionnaire d'Apple ; contenu religieux, rien de sensible |
| Union européenne | statut de commerçant ou non au sens du DSA, **à déclarer dans tous les cas** |
| Note à l'examinateur | comment voir la barrière sans attendre le matin : « Faire un essai » ; l'argument de Play, tel quel : une barrière que l'utilisateur pose sur son propre téléphone, contre ses propres habitudes, et qu'il retire quand il veut |
| Prix | gratuit, sans achat intégré (§ 6.3) |

## 7. Construire, tester et signer sans Mac

### 7.1 L'arborescence proposée

```
ios/
  PORTAGE.md, ROADMAP.md
  project.yml                 # XcodeGen : le projet Xcode n'est jamais versionné
  Paquets/
    Coeur/                    # Swift pur, Foundation + KosherSwift : règles, modèle, JSON, zmanim, vol
      Sources/Coeur/, Tests/CoeurTests/, Tests/Ressources/ (vecteurs copiés par l'export)
    Barriere/                 # minuscule : état, évaluation, boîte ; lié aux trois extensions
  App/                        # SwiftUI : écrans, navigation, audio, notifications
  Widgets/                    # WidgetKit + Live Activities
  Surveillance/               # DeviceActivityMonitor
  Bouclier/                   # ShieldConfigurationDataSource
  BouclierAction/             # ShieldActionDelegate
  Ressources/
    MANIFESTE.json            # versionné : empreintes des contenus exportés
    Chaines/ios.xcstrings     # versionné : chaînes propres à iOS
    (le reste est engendré par tools/export_contenu, non versionné)
  fastlane/, codemagic.yaml
```

Cinq identifiants à créer : `com.myhitbodedut`, `.widgets`, `.surveillance`, `.bouclier`, `.bouclier-action`, et le groupe `group.com.myhitbodedut`.

### 7.2 Qui vérifie quoi

| Où | Ce qui s'y vérifie | Coût |
| --- | --- | --- |
| **Linux** (GitHub Actions, et la session de travail elle-même) | tout le paquet `Coeur` : règles, JSON, zmanim et calendrier contre les vecteurs, vol, planificateur de notifications, état de la barrière ; l'export des contenus et son manifeste | 0,006 $ la minute |
| **macOS** (Codemagic, ou GitHub `macos-26`) | la compilation de l'app et des extensions, les tests d'interface sur simulateur, les captures, l'archive signée, l'envoi à TestFlight | 0,062 $ la minute sur GitHub ; 500 minutes gratuites par mois sur Codemagic |
| **L'iPhone de l'ami** | Temps d'écran (rien n'en tourne sur simulateur), Live Activity réelle, audio écran éteint, notifications à l'heure, boussole, GPS en mode avion | son temps : **quatre recettes** en tout (ROADMAP) |

D'où la règle de conduite : **tout ce qui peut être une fonction pure l'est**, et se prouve sur Linux. La barrière, les rappels, les widgets ne laissent à l'iPhone que le dernier mètre.

### 7.3 Le budget

Vérifié le 13/11/2026 : GitHub ne compte plus en minutes multipliées mais en dollars. Un compte gratuit inclut **12 $ par mois** pour les dépôts privés, toutes plateformes confondues ; c'est aussi la bourse de la CI d'Android, du site et de Nokia. À 0,062 $ la minute, **193 minutes de macOS** l'épuisent ; une construction avec tests d'interface en prendrait dix à quinze (estimation). Les dépôts publics ne paient rien, mais celui-ci contient la musique et ne peut pas le devenir tel quel.

| Tâche | Où | Quand |
| --- | --- | --- |
| Tests du cœur, export | GitHub, Linux | à chaque envoi qui touche `ios/`, `tools/export_contenu/` ou les contenus |
| Construction, tests d'interface, captures | **Codemagic** (500 min gratuites par mois, machine M2, compte personnel) | à la demande et sur les demandes de fusion qui touchent `ios/App`, `Widgets` ou les extensions |
| Archive signée, TestFlight | Codemagic | à la demande, ou sur une étiquette `ios-v*` |
| Secours | aucun : plafond de dépense GitHub à 0 $ (D5, 13/11/2026) | si les 500 minutes de Codemagic sont épuisées, on attend le mois suivant |

Décision D5 : gratuit strict.

### 7.4 Signer

Tout se fait par le web et par la CI.

1. Le titulaire du compte crée dans App Store Connect une **clé d'API d'équipe** (une clé individuelle ne donne pas accès aux profils). Elle devient trois secrets : identifiant de clé, identifiant d'émetteur, fichier `.p8`.
2. Les cinq identifiants, le groupe d'apps, les capacités (Groupes d'apps partout ; Family Controls sur l'app et les trois extensions de la barrière) se créent sur le portail.
3. Certificats et profils : deux voies sans Mac, toutes deux documentées. **Codemagic** les crée lui-même à partir de la clé (« without requiring a Mac ») ; ou **fastlane `match`**, lancé une fois sur un runner, qui engendre la clé privée et la demande de certificat, et range le tout chiffré dans un dépôt privé. Recommandation : la signature automatique de Codemagic pour commencer, `match` si l'on veut pouvoir signer aussi depuis GitHub.
4. **À éprouver** : que les profils créés par API portent bien Family Controls (développement tout de suite, distribution après l'accord d'Apple). C'est le premier risque technique de la chaîne, traité dans la tâche 3.

### 7.5 Installer sur l'iPhone de l'ami, puis TestFlight

| Étape | Comment, sans Mac |
| --- | --- |
| Connaître l'identifiant de l'appareil (UDID) | l'app « Appareils Apple » sous Windows, ou une page qui installe un profil de lecture ; Apple ne documente que la voie Mac |
| L'enregistrer | portail développeur, ou `fastlane register_devices` avec la clé |
| Installer une construction de développement | lien `itms-services` vers un manifeste et l'archive, servis en HTTPS (les artefacts de Codemagic ne donnent que le fichier brut : prévoir un hébergement, décision D15) |
| Mode développeur | **obligatoire** hors TestFlight : toucher l'icône installée, puis Réglages → Confidentialité et sécurité → Mode développeur, redémarrer. Les sources se contredisent sur l'apparition de ce réglage sans Mac : **premier point de la première recette** |
| TestFlight | plus de mode développeur ni d'UDID ; exige l'entitlement de distribution pour la barrière, sinon la construction `SANS_BARRIERE` |

Tant que la barrière n'a pas son accord de distribution, elle ne se teste que par des constructions de développement sur des appareils enregistrés. C'est suffisant pour l'iPhone de l'ami.

### 7.6 Voir sans Mac

- **Captures** : les tests d'interface parcourent les écrans en trois langues, clair et sombre, de l'iPhone SE au Pro Max ; les images sont extraites du rapport de test et poussées sur une branche `claude/captures-ios`, comme le font déjà `claude/captures-android` et `claude/captures-mac`. Une session de travail les relit.
- **Journaux** : chaque construction publie son rapport ; pas de débogueur, donc des messages clairs et le **journal de la barrière** partageable (§ 2.1.8).
- **Aperçus** : les vues clés se rendent en image dans des tests, pour juger la typographie hébraïque police par police.

### 7.7 Versions

- Xcode **26.6** sur l'image `macos-26` (image du 02/11/2026 : Xcode 26.0.1 à 26.6, simulateurs iOS 26.2, 26.4.1, 26.5), disponible aussi chez Codemagic.
- iOS 27 est sorti. Construire avec le SDK 26 reste accepté (exigence en vigueur : Xcode 26 ou plus récent). On passera à Xcode 27 quand Apple l'exigera ; la cible minimale ne bouge pas.
- Mode de langage Swift 6, vérification stricte de la concurrence.

## 8. Décisions attendues du propriétaire

Chacune dit ce qu'elle bloque. Les recommandations sont celles que la feuille de route suppose.

| # | Décision | Options | Recommandation | Bloque |
| --- | --- | --- | --- | --- |
| D1 | **Compte Apple Developer** (99 $ par an) | individuel : votre nom légal est affiché comme vendeur ; organisation : numéro D-U-N-S, nom de société | à vous de voir ; l'individuel est immédiat | tout ce qui se signe (tâche 3) |
| D2 | **Version minimale d'iOS** | 26.0, avec replis ; **26.5**, sans | **26.5** : le bouclier y a son sous-menu et ouvre l'app (§ 2.1.4) ; iOS 27 est déjà sorti | conception de la barrière |
| D3 | **Barrière** : demander à Apple l'entitlement de distribution, pour quatre identifiants | maintenant ; plus tard | **dès que les identifiants existent** (délais d'un jour à plus d'un mois) ; en attendant, TestFlight sans barrière | TestFlight et App Store de la barrière |
| D4 | **Moteur de calendrier** | KosherSwift 1.10.11, à l'égal d'Android (KosherJava 2.5.0) ; ou passer Android, le site et iOS à la 3.1 | **1.10.11** d'abord ; la 3.x plus tard, pour les trois ensemble | tâche 2 |
| D5 | **Budget d'intégration continue** | Codemagic gratuit (500 min par mois) et Linux sur GitHub ; plafond de dépense GitHub ; dépôt public | **Codemagic + Linux**, plafond GitHub de quelques dollars pour le secours | rythme des tâches 14 à 30 |
| D6 | **Journal et sauvegarde iCloud de l'iPhone** | exclu, comme sur Android ; inclus ; au choix de l'utilisateur | **exclu par défaut, interrupteur pour l'inclure** | tâche 7 |
| D7 | **Synchronisation iPhone ↔ iPad** | aucune ; iCloud privé de l'utilisateur | **aucune en v1** : c'est la promesse « rien ne quitte l'appareil » | tâche 29 |
| D8 | **Sauvegarde JSON incomplète** (journal enrichi, journal du Tikoun, favoris, noussa'h… absents de l'export d'Android, § 3.7) | ne rien changer ; étendre côté iOS ; **étendre aussi l'export d'Android** | **étendre Android d'abord** (demande séparée), sinon la migration perd ces données | annonce de la migration |
| D9 | **Musique** | les 26 morceaux de la version Play | oui, **après** avoir fait préciser « App Store » dans les accords ; consigner l'origine de המלך בשדה | soumission |
| D10 | **Vol en direct** | en v1, avec relais en ligne et écrits d'OpenSky et d'adsbdb ; **après la v1** | **après la v1** : le vol hors ligne ne dépend de personne | tâche 26 |
| D11 | **Textes sous droits** : Kitsour Yalkout Yossef entier, Bisdei Yaar, Tefila LiChlomo, or-breslev, biographies | écrits nommant l'App Store ; ou retrait de la version iOS | **obtenir les écrits** ; à défaut, iOS part sans le texte concerné | soumission |
| D12 | **LGPL de KosherSwift** | publier les sources de `ios/` ; offre écrite des fichiers objets | **offre écrite**, et fork public de la bibliothèque | soumission |
| D13 | **Périmètre de la v1** | parité complète (30 tâches) ; v1 resserrée (séance, journal, barrière, siddour, Tehilim, zmanim) puis lots | parité complète, **dans l'ordre de la feuille de route**, qui livre une app utile dès la tâche 19 | ordre des tâches |
| D14 | **Fiche App Store** | langues de la fiche ; catégorie ; statut au sens du DSA européen (à déclarer dans tous les cas) ; nom ; identifiant `com.myhitbodedut` | **comme sur Play** : anglais et hébreu, Style de vie ; l'identifiant d'Android ; le français s'ajoute sans peine si vous le voulez | tâche 30 |
| D15 | **L'iPhone de l'ami** | modèle, version d'iOS (26.5 au moins), quatre rendez-vous d'essai ; où héberger le lien d'installation | le relever maintenant | tâches 3 et 4 |

### 8.1 Choix arrêtés le 13/11/2026

| # | Choix | Conséquence |
| --- | --- | --- |
| D1 | compte **individuel** | votre nom légal apparaît comme vendeur ; P1 peut se faire tout de suite |
| D2 | iOS **26.5** minimum | pas de repli à écrire pour le bouclier |
| D3 | entitlement demandé **dès que les quatre identifiants existent** (tâche 3) | TestFlight sans barrière en attendant |
| D4 | **KosherSwift 1.10.11** | la 3.x plus tard, pour Android, le site et iOS ensemble |
| D5 | **gratuit strict** : Codemagic (500 min par mois) et Linux sur GitHub, plafond GitHub à 0 $ | pas de secours macOS payant ; un mois à court de minutes Codemagic suspend les tâches 14 à 30 jusqu'au mois suivant |
| D6 | journal **exclu** de la sauvegarde iCloud par défaut, **interrupteur** pour l'inclure | tâche 7 |
| D7 | **aucune** synchronisation en v1 | tâche 29 sans CloudKit |
| D8 | **étendre d'abord l'export d'Android**, par une demande séparée | P8 levée ; annonce de la migration après cette extension |
| D9 | les **26 morceaux**, après la mention « App Store » dans les accords ; origine de המלך בשדה consignée | P6 |
| D10 | vol en direct **après la v1** | tâche 26 limitée au vol hors ligne |
| D11 | **écrits nommant l'App Store**, sinon iOS part sans le texte concerné | P6 |
| D12 | **offre écrite** des fichiers objets et **fork public** de KosherSwift | `ios/` reste privé |
| D13 | **parité complète**, 30 tâches dans l'ordre de la feuille de route | — |
| D14 | fiche en **anglais, hébreu et français** ; Style de vie ; `com.myhitbodedut` ; **non-commerçant** au sens du DSA | une fiche française de plus à rédiger (tâche 30) ; aucune coordonnée publiée dans l'UE |
| D15 | lien TestFlight envoyé **en message privé** à l'ami | modèle, version d'iOS, identifiant et rendez-vous restent à relever (P4) |

**Mise à jour du 15/11/2026.** Le propriétaire a rendu les dépôts **publics**. Les runners macOS standard de GitHub sont gratuits pour un dépôt public : D5 reste « gratuit strict », mais la compilation de l'app par le vrai Xcode et les tests du paquet sur simulateur passent sur GitHub (`.github/workflows/ios-app.yml`, `macos-26`, Xcode 26.6, SDK iOS 26.5), sans attendre Codemagic. La signature, TestFlight et l'App Store restent soumis à P1 et P2. D12 (« `ios/` reste privé ») est caduque.

## 9. Sources lues le 13/11/2026

**Dans le dépôt** (à `0274b05`) : `README.md`, `FEUILLE_DE_ROUTE.md`, `PUBLICATION_PLAY_STORE.md`, `ZMANIM.md` ; `android/app/build.gradle.kts` ; les quatre manifestes ; les 152 fichiers Kotlin de `src/main`, les deux de `src/debug`, `src/musique_play` et `src/musique_hors_play` ; les ressources (`res/`, formes des fichiers de `res/raw`) ; les 48 scripts de `tools/` et ses sous-dossiers ; les flux de `.github/workflows` ; `web/build.mjs`, `web/src/js/store.js` et la liste des tests du site ; la liste et les en-têtes des 108 fichiers de tests Android.

**Apple**
- Bouclier : `developer.apple.com/documentation/managedsettingsui/shieldconfiguration/secondarybuttonsubmenuitems` (iOS 26.4) ; `…/managedsettings/shieldactionresponse/openparentalcontrolsapp` (iOS 26.5) ; `…/managedsettingsui/shieldconfigurationdatasource`
- Magasins : `…/managedsettings/managedsettingsstore/isactive` (iOS 26.5) ; `…/managedsettings/shieldsettings/applications-swift.property` (50 jetons)
- Surveillance : `…/deviceactivity/deviceactivitycenter` ; `…/monitoringerror/intervaltooshort` (15 minutes) ; `…/monitoringerror/excessiveactivities` (20 activités)
- Autorisation et entitlement : `…/familycontrols/authorizationcenter/requestauthorization(for:)` ; `…/familycontrols/requesting-the-family-controls-entitlement` ; formulaire `developer.apple.com/contact/request/family-controls-distribution`
- Règles de l'App Store : `developer.apple.com/app-store/review/guidelines/` ; exigences à venir : `developer.apple.com/news/upcoming-requirements/`
- Mode développeur : `…/documentation/xcode/enabling-developer-mode-on-a-device`

**Bibliothèques et outils**
- KosherSwift : `github.com/Elyahu41/KosherSwift` (licence, étiquettes 1.10.11 et 3.1.2, sources) ; `github.com/DanielSmith1239/KosherSwift` ; journal des changements de KosherJava : `github.com/KosherJava/zmanim/blob/master/CHANGELOG.md`
- XcodeGen : `github.com/yonaskolb/XcodeGen` (2.46.0)
- GitHub Actions : `docs.github.com/en/billing/concepts/product-billing/github-actions` ; image `macos-26` : `github.com/actions/runner-images`
- Codemagic : `docs.codemagic.io/billing/pricing/`, `docs.codemagic.io/code-signing/ios-code-signing`
- fastlane : `docs.fastlane.tools/app-store-connect-api/`

**Services et droits**
- OpenSky : `opensky-network.org/about/terms-of-use`
- adsbdb : `www.adsbdb.com`

**Non confirmé, à lever sur l'iPhone ou par écrit** : le comportement de `.openParentalControlsApp` avec une autorisation individuelle ; la limite de mémoire des extensions ; la présence de Family Controls dans les profils créés par API ; l'apparition du Mode développeur sans Mac ; le sort des jetons après un changement d'iPhone ; la compilation de KosherSwift sous Linux et en Swift 6.

## 10. Relevé au passage, côté Android

Rien n'est modifié sous `android/`. Ces points ont été vus en lisant, sans rien exécuter. Ce ne sont pas des écarts d'iOS, mais le portage les croisera.

| Où | Constat |
| --- | --- |
| `Store.exportJson` (`Store.kt:1484-1522`) | le journal enrichi, le journal du Tikoun, les favoris, les marque-pages, le noussa'h et le lieu ne sont pas dans la sauvegarde ; le site, lui, y écrit `journal_plus` (§ 3.7) |
| `ZmanimVignette.kt:85` | la pastille des widgets zmanim cherche le libellé de la fête sans le préfixe `fete_`, que `VueJour.kt:158` ajoute : elle montrerait toujours la paracha, jamais la fête |
| `strings.xml:1031` et le `_meta` de `yalkut_yosef.json` | « une sélection, non le livre entier », alors que le Kitsour entier est livré parmi les Livres |
| `Store.kt:50-51` | l'en-tête dit qu'aucune permission Internet n'est déclarée ; l'édition complète la déclare |
| `SuiviVol.kt:197` | par le relais, un quota dépassé chez OpenSky (réponse 502) s'afficherait comme une erreur de serveur, non comme « quota » |
| `SessionService.kt:381` | le manifeste déclare les types `specialUse` et `mediaPlayback` ; le code ne passe que le premier |
| `SiddurLectureActivity.kt:693-699` | un marque-page porte son rite, que l'ouverture ne transmet pas : ouvert sous un autre rite, il vise le même couple (section, bloc) d'un autre texte |
| `tools/traductions_tanakh.py:104` | lit `res/raw/livres.json`, qui n'existe plus depuis que la source est dans `src/main/livres/` |
