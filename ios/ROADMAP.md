# Feuille de route iOS

Trente tâches, dans l'ordre. Chacune tient en une session de travail (une branche, une demande de fusion, une intégration continue verte) et se termine par un **critère vérifiable**. Le pourquoi de chaque choix est dans `PORTAGE.md` ; les numéros de section y renvoient.

**Où se vérifie le critère**

| Mot | Sens |
| --- | --- |
| Linux | tests du paquet `Coeur` ou de l'outil d'export, sur un runner Linux et dans la session elle-même |
| macOS | compilation de l'app, tests d'interface sur simulateur, captures (Codemagic, § 7.3) |
| iPhone | une des quatre recettes sur l'iPhone de l'ami (fin de ce document) |

**Hypothèses** : les recommandations du § 8 de `PORTAGE.md` (iOS 26.5 au moins, KosherSwift 1.10.11, journal exclu de la sauvegarde iCloud, vol en direct après la v1). Une autre réponse à D2, D4 ou D10 change les tâches 2, 4, 26, 27 et 28, pas l'ordre.

## Préalables : ce qui ne dépend que de vous

| # | Quoi | Sert à | Décision |
| --- | --- | --- | --- |
| P1 | Adhérer à l'Apple Developer Program | tout ce qui se signe | D1 |
| P2 | Créer la clé d'API **d'équipe** d'App Store Connect et la poser en secrets | tâche 3 | — |
| P3 | Demander l'entitlement Family Controls (Distribution) pour les quatre identifiants, dès que la tâche 3 les a créés | TestFlight et App Store de la barrière | D3 |
| P4 | Relever le modèle, la version d'iOS (26.5 au moins) et l'identifiant de l'iPhone de l'ami ; convenir de quatre rendez-vous | tâches 3, 4, 19, 28 | D15 |
| P5 | Ouvrir un compte Codemagic personnel relié au dépôt | tâche 3 | D5 |
| P6 | Faire préciser « App Store » dans les accords des ayants droit (musique, textes) | tâche 30 | D9, D11 |
| P7 | Fournir une vraie sauvegarde exportée d'Android (hors dépôt si elle porte des notes) | tâche 7 | — |
| P8 | Étendre l'export d'Android (demande séparée ; décidé le 13/11/2026) | annonce de la migration | D8 |

## Vue d'ensemble

| # | Tâche | Où | Après | Critère de fin, en bref |
| --- | --- | --- | --- | --- |
| 1 | Squelette et CI Linux | Linux | — | `swift test` vert ; le flux ignore `android/` |
| 2 | KosherSwift devant les vecteurs | Linux | 1 | 35 lignes de zmanim à une seconde |
| 3 | Projet, signature, première installation | macOS, iPhone | P1, P2, P4, P5 | recette R1 |
| 4 | Prototype de barrière | iPhone | 3 | recette R2 ; § 2.1 mis à jour |
| 5 | Export des contenus | Linux | 1 | manifeste stable ; tests de données verts |
| 6 | Tables du Kotlin, index de recherche | Linux | 5 | `tables.json` complet ; garde de dérive |
| 7 | Modèle et sauvegarde JSON | Linux | 1, P7 | fichiers d'or verts |
| 8 | Règles de la pratique | Linux | 7 | 12 fichiers de tests portés |
| 9 | Paliers, trophées, 'hizouk, règles de texte | Linux | 6, 8 | 22 fichiers de tests portés |
| 10 | Calendrier juif | Linux | 2 | 3 896 entrées à l'identique |
| 11 | Siddour du jour, Levana, halakha, hilloulot | Linux | 5, 10 | 8 fichiers de tests portés |
| 12 | Logique de la barrière, planificateur, chronologies | Linux | 8, 10 | jamais plus de 64 ; 13 états |
| 13 | Vol et géographie | Linux | 2, 5 | 26 vols à deux secondes |
| 14 | Système visuel et galerie | Linux, macOS | 3, 5 | contrastes tenus ; galerie publiée |
| 15 | Accueil, navigation, présentation | macOS | 8, 14 | parcours des cinq onglets ; import par l'écran |
| 16 | Séance, journal, parcours | macOS | 9, 15 | séance d'une minute jusqu'au journal |
| 17 | La séance hors de l'app | macOS | 16 | réconciliation testée ; Live Activity en captures |
| 18 | Musique et ambiances | macOS | 16 | mêmes échantillons qu'Android |
| 19 | Rappels, alertes, première TestFlight | macOS, iPhone | 12, 17, 18 | recette R3 |
| 20 | Paliers et trophées à l'écran | macOS | 9, 15 | 9 formes en 5 métaux |
| 21 | Le lecteur et le siddour | macOS | 11, 14 | trois jours × trois rites ; saut au signet 300 |
| 22 | Tehilim, Tikoun, Tefilot, livres, sources, 'hizouk | macOS | 21 | Tikoun dit → trophée |
| 23 | Halakha, hilloulot, recherche | macOS | 6, 21 | recherche sous 300 ms |
| 24 | Zmanim, calendrier, lieu, partage | macOS | 10, 15 | captures en regard de `captures-calendrier/` |
| 25 | Boussole et widgets | macOS | 12, 13, 24 | chronologie d'un jour ; trois familles |
| 26 | Vol à l'écran | macOS | 13, 24 | phrase → frise ; billet lu |
| 27 | Barrière I : l'app, le bouclier, l'action | macOS, iPhone | 4, 12, 16 | trois visages × trois langues |
| 28 | Barrière II : la surveillance, le diagnostic | iPhone | 27 | recette R4 |
| 29 | Accessibilité, iPad, performance | macOS | 21 à 28 | audit sans défaut ; mesures tenues |
| 30 | TestFlight externe, fiche, soumission | macOS | 29, P3, P6 | construction acceptée ; dossier des droits complet |

## Jalons

| Jalon | Tâches | Ce qui existe à la fin |
| --- | --- | --- |
| A. Le socle | 1 à 6 | le moteur de calendrier est jugé, une app vide signée tourne sur l'iPhone, la barrière est éprouvée en prototype, les contenus s'exportent |
| B. Le cœur | 7 à 13 | toute la logique d'Android passe ses tests en Swift, sans écran |
| C. Une app utile | 14 à 20 | séance, journal, musique, rappels, trophées ; en TestFlight interne, sans barrière |
| D. Les textes | 21 à 23 | siddour, Tehilim, Tikoun, livres, halakha, recherche |
| E. Le ciel | 24 à 26 | zmanim, calendrier, boussole, widgets, vol |
| F. La barrière | 27, 28 | « Je suis avec Hachem », complète |
| G. Finir | 29, 30 | prête pour l'App Store |

---

## A. Le socle

### 1. Squelette et CI Linux

- **But** : poser `ios/` et prouver qu'on peut tester du Swift sans Mac.
- **Livrable** : `ios/Paquets/Coeur/Package.swift` (mode de langage Swift 6), le type `JourCivil` (§ 3.3) et ses tests ; `.github/workflows/ios-coeur.yml`, sur Linux, déclenché par `ios/**`, `tools/export_contenu/**` et les contenus.
- **Critère de fin** : `swift test` vert dans la CI ; un envoi qui ne touche que `android/` ne déclenche pas le flux ; `JourCivil` refuse `2026-02-30` et `2026-9-5`, accepte `2026-11-04`, et son arithmétique passe les changements d'année et les 29 février.
- **Où** : Linux.

### 2. KosherSwift devant les vecteurs

- **But** : juger le moteur avant de bâtir dessus (§ 5.1, décision D4).
- **Sources** : `Zmanim.kt`, `Holidays.kt`, `tools/vecteurs_kosherjava/`, `web/test/vecteurs_kosherjava.json`, `android/app/src/test/resources/zmanim_reference_*.json`, `ZmanimTest.kt`, `HolidaysTest.kt`.
- **Livrable** : le fork de KosherSwift épinglé à 1.10.11 ; `Zmanim.jour`, `Zmanim.allumage`, `Holidays` ; `ios/KOSHERSWIFT.md` : résultats de 1.10.11 **et** de 3.1.2, compilation sous Linux (oui ou non), avertissements en Swift 6.
- **Critère de fin** : les 35 lignes de zmanim (15 horaires et l'allumage) à une seconde, `ABSENT` exact à Tromsø ; références NOAA à 2 s (20 s pour 'hatsot) et PyEphem à 60 s ; `HolidaysTest` porté. Si un écart demeure, il est **chiffré** dans la note et D4 vous est reposée : la tâche est finie quand le chiffre existe.
- **Où** : Linux (macOS si KosherSwift ne compile pas sous Linux).

### 3. Projet, signature, première installation

- **But** : la chaîne complète, du dépôt à l'iPhone, sur une app vide (§ 7).
- **Livrable** : `ios/project.yml` (l'app, les widgets, les trois extensions de la barrière, vides ; groupe d'apps ; entitlements) et `ios/project-sans-barriere.yml` (la construction `SANS_BARRIERE`) ; `codemagic.yaml` (`ios-verification` sur simulateur, `ios-dev` signée par la signature automatique de Codemagic, § 7.4) ; `ios/SIGNATURE.md`, les gestes du propriétaire ; les cinq identifiants créés. Ni fastlane, qui viendra avec la fiche et les captures (tâche 30), ni secours GitHub `macos-26` (décision D5).
- **Critère de fin** : Codemagic produit une archive de développement signée qui contient les quatre extensions et l'entitlement Family Controls de développement ; **recette R1** réussie ; P3 déposé.
- **Où** : macOS, iPhone.

### 4. Prototype de barrière

- **But** : lever les « à éprouver » du § 2.1 avant de construire dessus. Code jetable, derrière un écran « Laboratoire ».
- **Livrable** : autorisation individuelle, sélecteur, un magasin nommé piloté par `isActive`, un bouclier à sous-menu, la réponse `.openParentalControlsApp`, une activité dont le début est dans cinq minutes, un journal écrit par les extensions dans le groupe d'apps.
- **Critère de fin** : la grille de la **recette R2** est remplie ; dans `PORTAGE.md` § 2.1, chaque « à éprouver » devient « éprouvé le … » ou cède la place au repli décrit.
- **Où** : iPhone.

### 5. Export des contenus

- **But** : `tools/export_contenu`, étapes 1, 2, 4 à 7, 9 et 10 du § 4.2.
- **Livrable** : l'outil ; `ios/Ressources/MANIFESTE.json` ; la garde de dérive dans la CI ; dans `Coeur`, les types `Codable` des contenus et les tests de données portés (`DataLoadTest`, `SiddurTest`, `LivresTest`, `NomsDivinsTest`, `LicencesEditionsTest`, `TraductionTest`, `MusicFilesTest`, `VillesTest`).
- **Critère de fin** : deux exports de suite donnent le même manifeste ; les JSON copiés sont identiques à `res/raw` octet pour octet ; les comptes tiennent : 38 textes × 3 rites, 150 psaumes et 2 527 versets, 10 psaumes du Tikoun, 171 textes de 'hizouk, 12 livres, 4 049 hilloulot, 51 villes, 3 226 aéroports, 26 morceaux ; mêmes clés de chaînes dans les trois langues, marqueurs de format concordants ; rien n'est écrit hors de `ios/`.
- **Où** : Linux.

### 6. Tables du Kotlin, index de recherche

- **But** : étapes 3 et 8 du § 4.2.
- **Sources** : les fichiers du tableau C du § 4.1 ; `RechercheGlobale.kt`.
- **Livrable** : `tools/export_contenu/tables/` (projet Gradle autonome, deux bouchons), `tables.json` ; `recherche.sqlite` ; `RechercheGlobale` en Swift (normalisation, extraits, portées).
- **Critère de fin** : `tables.json` porte 6 échelles de paliers, 11 familles et 128 niveaux, 30 et 7 portions, 10 sujets, 5 temps, 21 correspondances de poses, 15 zmanim ; modifier un seuil dans une copie de `Trophees.kt` fait échouer la garde ; une liste de cas communs prouve que la normalisation Python et la normalisation Swift rendent la même chaîne ; les cas de recherche de `HalakhaTest` rendent les mêmes résultats.
- **Où** : Linux.

## B. Le cœur

Tout se vérifie sur Linux. Une tâche est finie quand les tests nommés, portés en Swift avec les mêmes cas, sont verts.

### 7. Modèle et sauvegarde JSON

- **Sources** : `Store.kt` (journées, `exportJson`, `importJson`), `JournalPlus.kt`, `web/src/js/store.js:509-631`.
- **Livrable** : `Journee`, `Journal`, `Reglages` (clés d'Android), `actor Depot`, `Sauvegarde` (décodage tolérant, sérialiseur ordonné), la fusion (§ 3.5).
- **Critère de fin** : les six lignes du § 3.9 ; un fichier illisible est mis de côté et non écrasé (l'équivalent de `days_corrompu`) ; la sauvegarde réelle du propriétaire se lit sans perte.

### 8. Règles de la pratique

- **Sources** : `SessionRule.kt`, `DureeSeance.kt`, `Store.kt` (série, semaine, exemptions, fenêtre de nuit, jour du Tikoun), `Anneaux.kt`, `JaugeSemaine.kt`, `BilanSemaine.kt`, `Plaque.kt`, `Salutation.kt`, `Character.kt`, `Theme.kt`, `Adresse.kt`, `AjoutTemps.kt`.
- **Critère de fin** : portés et verts : `SessionRuleTest`, `DureeSeanceTest`, `DureeCourteTest`, `FiabiliteTest`, `AnneauxTest`, `JaugeSemaineTest`, `PlaqueTest`, `SalutationTest`, `ThemeTest`, `AdresseTest`, `VoyageNuitTest`, `RepriseBoussoleTest` (bascule à 4 h).

### 9. Paliers, trophées, 'hizouk, règles de texte

- **Sources** : `Paliers.kt`, `Trophees.kt`, `Confettis.kt` (`Celebrations`), `ChizukRules.kt`, `ChizukBag.kt`, `ChizukCard.kt` (`translationOf`), `LibraryRules.kt`, `Reference.kt`, `MarquesPages.kt`, `Langue.kt`, `LanguesTexte.kt`, `Aeration.kt`, `MelangeMusique.kt`, `DanseMesure.kt`, `Tehilim.kt`, `Tikkun.kt`, `Tefilot.kt`, `Hitbodedut.kt`, `QuestionsBlocage.kt`, `ParcoursActivity.kt` (objet `Parcours`).
- **Critère de fin** : portés et verts : `PaliersTest`, `TropheesTest`, `CheminTropheesTest`, `BilanTropheesTest`, `TropheesTikkunTest`, `ChizukRulesTest`, `ChizukBagTest`, `ChizukCardTest`, `LibraryRulesTest`, `TraductionAffichageTest`, `MarquesPagesTest`, `RegleLangueTest`, `LanguesTexteTest`, `AerationTest`, `MelangeMusiqueTest`, `DanseMesureTest`, `TehilimTest`, `TikkunTest`, `TefilotTest`, `HitbodedutTest`, `QuestionsBlocageTest`, `ParcoursTest`.

### 10. Calendrier juif

- **Sources** : `CalendrierJuif.kt`, `JourAffiche.kt`, `HorairePriere.kt`, `RappelsTefila.kt`.
- **Critère de fin** : les **3 896 entrées** de `vecteurs_kosherjava.json` rendues à l'identique (date, texte hébreu, fêtes, omer, paracha, chômé, conditions) ; portés et verts : `CalendrierJuifTest`, `JourAfficheTest`, `BasculeTest`, `RappelsTefilaTest`, `HemisphereSudTest`.

### 11. Siddour du jour, Levana, halakha, hilloulot

- **Sources** : `SiddurJour.kt`, `Siddur.kt`, `Levana.kt`, `Halakha.kt`, `YalkutYosef.kt`, `Hilloulot.kt`, `SourceDuJour.kt`.
- **Livrable** : les règles ; `tools/vecteurs_kosherjava/VecteursIos.kt` et son fichier (molad, bornes de Birkat haLevana, paracha à venir, Roch 'Hodech), sans toucher au fichier du site.
- **Critère de fin** : portés et verts : `SiddurJourTest`, `MegilaTest`, `IlanotTest`, `LevanaTest`, `HalakhaTest`, `YalkutYosefTest`, `HilloulotTest`, `SourceDuJourTest` ; le fichier de `VecteursIos` rendu à l'identique.

### 12. Logique de la barrière, planificateur, chronologies

- **Sources** : `GateStatus.kt`, `Store.kt` (fenêtre, report, exemptions), `ReminderRule.kt`, `Reminder.kt`, `ChabbatAlerte.kt`, `LevanaAlerte.kt`, `ZmanimWidget.kt`, `ZmanimVignette.kt`.
- **Livrable** : le paquet `Barriere` (état, évaluation, boîte, jours exemptés des deux années à venir) ; `PlanNotifications` ; les chronologies des widgets.
- **Critère de fin** : portés et verts : `ReminderRuleTest`, `ReminderTimesTest`, `ChabbatAlerteTest`, `DixAmeliorationsTest` ; tests neufs : jamais plus de 64 notifications, quels que soient les réglages ; aucune un jour de repos ni la veille après midi ; les rappels du jour disparaissent quand la journée est faite ; les treize états du § 2.1.8 ; report de 5 et de 15 minutes ; fenêtre de nuit un vendredi soir ; une entrée de chronologie par zman et la bascule du jour hébreu à tsét.

### 13. Vol et géographie

- **Sources** : `Vol.kt`, `VolCalendrier.kt`, `VolPriere.kt`, `VolRappels.kt`, `SaisieVol.kt`, `CarteEmbarquement.kt`, `Aeroports.kt`, `RouteVol.kt`, `SuiviVol.kt` (lecture des réponses), `DirectionJerusalem.kt`, `TerritoireIsrael.kt`, `Villes.kt`, `web/src/js/magnetisme.js`.
- **Critère de fin** : les **26 vols** de `vecteurs_vol.json` à deux secondes, mêmes réserves, mêmes dates de ligne ; portés et verts : `VolTest`, `VolRappelsTest`, `SaisieVolTest`, `RouteVolTest` (faux serveur), `DirectionJerusalemTest`, `TerritoireIsraelTest`, `VillePlusProcheTest` ; le modèle magnétique rend les valeurs de `vecteurs_wmm2025.txt`.

## C. Une app utile

Les critères se vérifient par des tests d'interface sur simulateur et par les captures publiées sur la branche `claude/captures-ios` (§ 7.6).

### 14. Système visuel et galerie

- **Sources** : `Apparence.kt`, `res/values*/palettes.xml`, `colors.xml`, `themes.xml`, `dimens.xml`, `Effets.kt`, `Personnage.kt`, `PoliceHebraique.kt`.
- **Livrable** : `Palette` (13 jetons, 36 combinaisons, clair et sombre), les composants (carte, boutons, pastille, ligne de section), `Illustration`, les sept polices, le premier test d'interface « galerie », l'extraction des captures.
- **Critère de fin** : le test de contraste porté de `PaletteTest` est vert (4,5 et 7,0 sur toutes les combinaisons) ; la galerie paraît sur la branche, en français, anglais et hébreu, clair et sombre, iPhone SE et Pro Max ; l'hébreu y est de droite à gauche.

### 15. Accueil, navigation, présentation

- **Sources** : `MainActivity.kt`, `AnneauxDessin.kt`, `AnneauxView.kt`, `Onboarding.kt`, `OnboardingActivity.kt`, `SettingsActivity.kt` (prénom, adresse, apparence, données), `AccueilMoment.kt`, `Dedicace.kt`, `Tips.kt`, `TipsActivity.kt`.
- **Critère de fin** : un test d'interface va de la présentation à l'accueil puis dans les cinq onglets ; il importe un fichier d'or par l'écran des réglages et lit la série attendue ; captures de l'accueil dans ses quatre états (pas encore faite, en cours, faite, jour sans obligation) ; les anneaux ne bougent pas quand « Réduire les animations » est actif.

### 16. Séance, journal, parcours

- **Sources** : `SessionActivity.kt`, `PratiqueCalme.kt`, `SouffleView.kt`, `HitbodedutCard.kt`, `ChizukCard.kt`, `CelebrationActivity.kt`, `Confettis.kt`, `NoteDialog.kt`, `JournalActivity.kt`, `JournalPlus.kt`, `ParcoursActivity.kt`.
- **Critère de fin** : avec une horloge injectée, un test d'interface mène une séance d'une minute jusqu'au bravo, écrit une note, et retrouve la journée au journal ; un abandon montre « 'Hazak ! » et n'inscrit rien ; une séance commencée à 23 h 59 s'inscrit la veille.

### 17. La séance hors de l'app

- **Sources** : `SessionService.kt`, `Notifications.kt` ; § 2.2.1.
- **Livrable** : Live Activity et Dynamic Island, notification de fin, option « minuterie système », actions « Commencer » et « Terminer », réconciliation au retour.
- **Critère de fin** : tests : une séance de 20 minutes constatée trois heures plus tard inscrit 20 minutes au jour de son début ; une séance sans durée oubliée est plafonnée à 240 ; « Terminer » avant une minute pleine n'inscrit rien. Captures de la Live Activity dans ses trois états (reste, écoulé, masqué).

### 18. Musique et ambiances

- **Sources** : `MusicActivity.kt`, `MusicLibrary.kt`, `MusicPlayer.kt`, `MiniLecteur.kt`, `Ambiance.kt`, `MusiquePlay.kt`.
- **Critère de fin** : `AmbianceTest` porté et vert (mêmes échantillons que sur Android) ; test de la file de lecture : suivant, « précédent » qui reprend le morceau après 3 s, aléatoire sans redite, morceau illisible sauté ; un fichier ajouté est copié et survit à un relancement ; captures de l'écran Musique et du mini-lecteur.

### 19. Rappels, alertes, première TestFlight

- **Sources** : `Reminder.kt`, `RemindersActivity.kt`, `ChabbatAlerte.kt`, `LevanaAlerte.kt`, `BootReceiver.kt` ; § 2.2.2.
- **Livrable** : le planificateur branché sur les notifications du système, les actions « Commencer » et « Plus tard », l'écran des rappels, la tâche de rafraîchissement, un écran de diagnostic qui liste les notifications en attente ; la construction `SANS_BARRIERE` en TestFlight interne.
- **Critère de fin** : sur simulateur, les demandes en attente sont exactement celles du plan ; **recette R3** réussie.
- **Où** : macOS, iPhone.

### 20. Paliers et trophées à l'écran

- **Sources** : `PaliersActivity.kt`, `TropheeDessin.kt`, `FicheTrophee.kt`, `AnimationsTrophees.kt`.
- **Critère de fin** : l'analyseur de chemins lit sans erreur les 9 formes et les 11 icônes de `trophees_formes.json` ; captures des 9 formes dans les 5 métaux ; avec un journal forgé, un trophée neuf est fêté une fois à l'accueil, et rien n'est fêté au tout premier passage.

## D. Les textes

### 21. Le lecteur et le siddour

- **Sources** : `SiddurLectureActivity.kt`, `SiddurActivity.kt`, `ReglagesLecture.kt`, `PoliceHebraique.kt`, `RepriseFavoris.kt` ; § 2.2.9.
- **Critère de fin** : captures de Cha'harit un jour ordinaire, un Roch 'Hodech et un jour de jeûne, dans les trois rites, à mettre en regard de `captures-calendrier/` ; un test d'interface ouvre Likoutei Moharan, saute au signet 300, change la taille, et retrouve le même bloc en tête ; la galerie montre un verset vocalisé dans les sept polices ; aucune image dans l'écran de lecture.

### 22. Tehilim, Tikoun, Tefilot, livres, sources, 'hizouk

- **Sources** : `TehilimActivity.kt`, `TehilimLectureActivity.kt`, `TikkunFlowActivity.kt`, `TefilotActivity.kt`, `LibraryActivity.kt`, `LibrarySubSectionActivity.kt`, `LibraryEntryActivity.kt`, `ChizukActivity.kt`.
- **Critère de fin** : un test d'interface lit la portion du jour, pose un marque-page sur un verset et le retrouve ; « J'ai dit le Tikoun en entier » fait gagner le premier trophée du Tikoun ; « Un autre » ne redonne pas le même texte ; un article protégé ne montre que sa fiche.

### 23. Halakha, hilloulot, recherche

- **Sources** : `HalakhaActivity.kt`, `HilloulotActivity.kt`, `RechercheActivity.kt` ; § 2.2.10.
- **Critère de fin** : une recherche rend ses résultats groupés en moins de 300 ms sur simulateur, mesurés par le test ; un résultat par texte, 30 par sorte ; la hilloula du jour s'ouvre avec sa biographie et sa source ; l'écran de la halakha passe au lendemain sans écraser un jour choisi.

## E. Le ciel

### 24. Zmanim, calendrier, lieu, partage

- **Sources** : `ZmanimActivity.kt`, `VueJour.kt`, `CalendrierActivity.kt`, `ChoixLieu.kt`, `Levana.kt` (dessin), `PartageJour.kt`.
- **Critère de fin** : captures des mêmes jours que `captures-calendrier/zmanim-*.png`, mêmes ajouts, mêmes horaires à la minute ; avec la position simulée, le lieu devient « Ma position · près de … » en précision approximative ; l'image de partage est engendrée par un test.

### 25. Boussole et widgets

- **Sources** : `BoussoleActivity.kt`, `BoussoleDessin.kt`, `BoussoleView.kt`, `BoussoleWidget.kt`, `StreakWidget.kt`, `VignetteDecor.kt`, `ZmanimVignette.kt` ; § 2.2.3, § 2.2.5.
- **Critère de fin** : captures des widgets dans les trois familles et sur l'écran verrouillé, en clair, sombre et teinté ; captures de la boussole pour six caps. La boussole réelle se voit en recette R4.

### 26. Vol à l'écran

- **Sources** : `VolActivity.kt`, `LecteurBillet.kt`, `VolAlerte.kt`.
- **Critère de fin** : un test d'interface saisit « El Al Lyon TLV demain 11h » et obtient la carte du vol puis la frise ; un billet PDF d'essai est lu par Vision ; les notifications du vol posées égalent le plan ; sans adresse de relais, aucun élément des services en ligne n'apparaît et aucune requête ne part.

## F. La barrière

### 27. Barrière I : l'app, le bouclier, l'action

- **Sources** : `GateStatus.kt`, `BlockerView.kt`, `AppPickerActivity.kt`, `Divulgation.kt`, `SettingsActivity.kt` (cartes de la barrière) ; § 2.1.
- **Livrable** : l'écran et sa carte d'état, l'explication avant l'autorisation, le sélecteur, les deux magasins, l'extension du bouclier (trois visages, textes lus dans `etat.json`), l'extension d'action (commencer, déjà faite, plus tard), la boîte, l'aide-mémoire de la liste d'Android.
- **Critère de fin** : la réplique du bouclier en captures, trois visages × trois langues ; les tests du paquet `Barriere` restent verts ; la construction de développement s'installe sur l'iPhone et le bouclier « rien de fait » paraît.
- **Où** : macOS, iPhone.

### 28. Barrière II : la surveillance, le diagnostic

- **Livrable** : l'extension de surveillance et ses cinq activités, l'essai réel, le journal de la barrière, les états propres à iOS, la mise à jour de `etat.json` à chaque changement.
- **Critère de fin** : **recette R4** réussie.
- **Où** : iPhone.

## G. Finir

### 29. Accessibilité, iPad, performance

- **Critère de fin** : l'audit d'accessibilité des tests d'interface passe sans défaut sur chaque écran ; chaque élément de l'accueil, de la séance et d'un texte du siddour porte un libellé d'accessibilité dans les trois langues (vérifié par test) ; captures iPad en deux colonnes ; mesures tenues : premier écran en moins de 400 ms, défilement du plus long livre sans image perdue ; l'app pèse moins de 200 Mo.
- **Où** : macOS.

### 30. TestFlight externe, fiche, soumission

- **Livrable** : la fiche (textes, captures engendrées), `PrivacyInfo.xcprivacy` pour l'app et chaque extension, l'écran « Sources et licences » rempli depuis le manifeste, la note à l'examinateur, la voie `release`.
- **Critère de fin** : la construction complète est acceptée en TestFlight externe ; le dossier des écrits du § 6 est complet ; la soumission est prête, et ne part que sur votre accord.
- **Où** : macOS.

---

## Les quatre recettes sur l'iPhone

Chacune tient en moins d'une heure. L'ami renvoie la grille remplie et, pour la barrière, le journal partagé depuis l'app.

### R1. Installer (tâche 3)

| # | Geste | Attendu |
| --- | --- | --- |
| 1 | relever l'identifiant de l'appareil | noter par quel moyen |
| 2 | ouvrir le lien d'installation | l'app s'installe |
| 3 | toucher l'icône | iOS demande le Mode développeur ; **noter où le réglage apparaît** |
| 4 | l'activer, redémarrer | l'app s'ouvre, affiche sa version et son identifiant |
| 5 | poser le widget vide | il paraît |

### R2. La barrière en prototype (tâche 4)

| # | Question | Oui / non, remarque |
| --- | --- | --- |
| 1 | L'autorisation individuelle s'obtient-elle ? | |
| 2 | Le sélecteur rend-il les applications, et l'app montre-t-elle leur nom et leur icône ? | |
| 3 | Le bouclier paraît-il avec notre icône, notre titre, nos couleurs ? | |
| 4 | Le sous-menu du bouton secondaire paraît-il, et ses deux entrées arrivent-elles à l'extension ? | |
| 5 | « Commencer » ouvre-t-il MyHitbodedut ? En combien de temps ? | |
| 6 | Après « déjà faite », le bouclier disparaît-il sans autre geste ? | |
| 7 | Désactiver puis réactiver le magasin suffit-il à lever et remettre le bouclier ? | |
| 8 | Un rendez-vous dans 5 minutes réveille-t-il l'extension à l'heure ? Dans 15 ? | |
| 9 | Le bouclier survit-il à la fermeture de l'app ? Au redémarrage ? | |
| 10 | Le journal écrit par les extensions se lit-il dans l'app ? | |
| 11 | Le nom de l'application retenue se lit-il dans le bouclier ? | |
| 12 | Autorisation retirée dans les Réglages : que montre l'app au retour ? | |

### R3. Une matinée sans barrière (tâche 19, par TestFlight)

| # | Geste | Attendu |
| --- | --- | --- |
| 1 | importer la sauvegarde d'Android | « N journées importées », la série est la bonne |
| 2 | séance de 15 minutes avec musique, écran éteint | la musique tient, s'éteint en fondu, le bravo attend au retour |
| 3 | séance de 5 minutes en silence, téléphone en mode silencieux | la notification de fin paraît ; avec « minuterie système », elle sonne |
| 4 | regarder l'écran verrouillé pendant une séance | le décompte y est ; « Terminer » fonctionne |
| 5 | rappel réglé à dans dix minutes | il arrive ; « Plus tard » le renvoie 30 minutes après |
| 6 | écran de diagnostic | aucune notification prévue un samedi ni un jour fait |

### R4. La barrière complète (tâche 28, construction de développement)

| # | Geste | Attendu |
| --- | --- | --- |
| 1 | « Faire un essai » | le vrai bouclier, « APERÇU, AUCUN EFFET », puis il se lève |
| 2 | fenêtre réglée pour commencer dans 20 minutes | à l'heure, l'application choisie montre le bouclier |
| 3 | « Commencer maintenant » | l'app s'ouvre sur la séance qui démarre |
| 4 | ouvrir l'application retenue pendant la séance | « Hitbodedout en cours » |
| 5 | fin de la séance, app fermée | tout est levé ; la journée est inscrite pour la durée choisie |
| 6 | le lendemain : « Plus tard », 5 puis 15 minutes | le bouclier revient à l'heure, à une minute près |
| 7 | « Je l'ai déjà faite » | levé jusqu'au lendemain ; « Validée sans minuteur » |
| 8 | « Pause aujourd'hui » | levé ; l'état dit « Jour sans obligation » |
| 9 | fenêtre de nuit, 21:00 – 02:00 | la séance de 21 h 30 couvre jusqu'à 2 h |
| 10 | redémarrer le téléphone dans la fenêtre | le bouclier est toujours là |
| 11 | éteindre le mode | plus aucun bouclier |
| 12 | carte d'état, à chaque étape | elle dit vrai ; le journal de la barrière raconte la même histoire |
| 13 | boussole dehors, à plat puis tenue droite ; widgets posés | la direction est stable ; les widgets suivent l'heure |

## Hors de ces trente tâches

- Le vol en direct (relais en ligne, écrits d'OpenSky et d'adsbdb : décision D10).
- La synchronisation entre iPhone et iPad (D7).
- Le passage des trois plateformes à KosherJava 3.x (D4).
- L'extension de l'export d'Android (D8), qui est une demande sur `android/`.
- Spotlight, le filtre de mode de concentration, le Centre de contrôle (§ 2.4) : une session chacun, quand vous le voudrez.
- Apple Watch, Mac.
