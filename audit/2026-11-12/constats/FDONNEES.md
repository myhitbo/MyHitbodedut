# FDONNEES — Android — données, journal, progression, widget

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

29 constats — confirmés : 6 · confirmés en partie : 3 · non contre-expertisés (mineurs et cosmétiques) : 20.

## Ce qui a été examiné

Lu en entier : Store.kt (1 641 lignes), Json.kt, JournalActivity.kt, JournalPlus.kt, NoteDialog.kt, ParcoursActivity.kt, Paliers.kt, PaliersActivity.kt, Trophees.kt, FicheTrophee.kt, BilanSemaine.kt, JaugeSemaine.kt, Anneaux.kt, Barres.kt, StreakWidget.kt, WidgetTaille.kt, PartageJour.kt, MarquesPages.kt, RepriseFavoris.kt, Plaque.kt, Holidays.kt, SessionRule.kt, AjoutTemps.kt, BootReceiver.kt, backup_rules.xml, data_extraction_rules.xml, widget_streak_info.xml, BackupRulesTest.kt, web/src/js/store.js et paliers.js, la version française de confidentialite.html, les sections « Ce qui manque », 19/10 et 04/11 de FEUILLE_DE_ROUTE.md.

Lu en partie, en suivant les appels : MainActivity.kt (environ 400 lignes sur 1 022), SettingsActivity.kt (réinitialisation, pause, export/import), Confettis.kt (Celebrations et notification), GateService.kt et GateStatus.kt (boucle et état), SessionService.kt (clôture), SessionActivity.kt (boucle, « Écrire »), CelebrationActivity.kt, ChoixLieu.kt (position), ChabbatAlerte.kt, AnneauxView.kt (80 lignes sur 222), AnneauxImage.kt, trophees.js (80 lignes sur 212), app.js (« Mes données », message de trophée), AndroidManifest.xml, PUBLICATION_PLAY_STORE.md (§5.1, confidentialité, liste de contrôle), ConfidentialiteTest.kt, JournalCarnetTest.kt.

Chaînes : les 1 222 clés comparées par script entre values, values-en et values-iw (clés manquantes, restes de français en anglais, références dans Android, site et Nokia) ; environ 230 chaînes du périmètre (journal, notes, trophées, paliers, grades, anneaux, widget, bilan, parcours, partage, export/import, réinitialisation, favoris, marque-pages) relues côte à côte en français et en anglais. L'hébreu n'a été contrôlé que pour la présence des clés, pas pour sa qualité.

Exécuté : deux scénarios Node sur web/src/js/store.js et trophees.js (série avant/après bascule Israël et Chabbat ; métal par rang ; trophées « nouveaux » avec liste vide), plus trois scripts d'analyse des chaînes, tous sous OUT/fdonnees.

Non examiné ou non exécuté : AnneauxDessin.kt, AnimationsTrophees.kt, TropheeDessin.kt (dessin pur, seulement balayés pour des textes en dur) ; PaliersTest, TropheesTest, WidgetTest (parcourus par recherche seulement). Aucun code Android n'a été compilé ni lancé (pas de Robolectric dans le projet, pas d'appareil) : les comportements Android (perte de la note à la rotation, bravo par-dessus la note, FLAG_SECURE des fenêtres de dialogue, transfert d'appareil sous Android 8 à 11, coût des relectures du journal) sont établis par lecture du code et par le fonctionnement documenté d'Android, sans mesure sur téléphone. Les versions anglaise et hébraïque de la politique de confidentialité n'ont été lues qu'en partie.

## Ce qui tient

- Séparation nette des données : journal, notes et prénom dans un second fichier exclu de la sauvegarde nuage et inclus au transfert d'appareil (Android 12+), avec déplacement automatique d'un prénom resté dans les réglages ; BackupRulesTest et ConfidentialiteTest tiennent cette garantie.
- Règles de progression écrites sans Android (Paliers, Trophees, Plaque, JaugeSemaine, BilanSemaine, SessionRule, MarquesPages, WidgetTaille), donc testables, et portées à l'identique sur le site : échelles des paliers et seuils des onze familles de trophées strictement égaux entre Paliers.kt/Trophees.kt et paliers.js/trophees.js.
- Import défensif : fichier plafonné à 2 Mo, format vérifié, dates mal formées ou à venir rejetées, minutes bornées à 24 h, notes tronquées à NOTE_MAX, chaque réglage ramené dans ce que l'écran permet, journées fusionnées (jamais écrasées) et sujets réunis.
- Inscription des séances robuste : une séance minutée ne compte jamais plus que sa durée, une séance ouverte est plafonnée à 240 min, la date est celle du début et jamais dans l'avenir, une séance orpheline est reprise après la mort du service ; une note seule ne valide pas la journée.
- Widget soigné : alarme de minuit reprogrammée à chaque dessin, rafraîchi après séance, ajout de temps, réglages, redémarrage, changement d'heure et de fuseau ; compteur tenu par le lanceur (Chronometer) ; trois tailles et description vocale des anneaux.
- Traductions complètes dans le périmètre : 1 222 clés présentes dans les trois langues (0 manquante en anglais et en hébreu), aucune phrase française résiduelle dans values-en, aucun texte en dur dans les gabarits du journal, des trophées et des widgets, dates formatées dans la langue de l'application.

## Constats

### FDONNEES-01 — L'export JSON, seule sauvegarde du journal, n'emporte ni l'humeur, ni la gratitude, ni « à travailler », ni le journal du Tikoun, ni les signets

**Gravité** : bloquant · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** Store.exportJson n'écrit que les journées (minutes, note, sujets, note_seule), 21 réglages, les jours de pause et les applications de la barrière. Manquent : le journal enrichi (clé journal_plus : humeur avant/après, gratitude, chose à travailler, donc des textes écrits par l'utilisateur), le journal du Tikoun (tikkun_journal, qui porte les 20 niveaux des deux familles de trophées du Tikoun), les favoris, les 'hizouk gardés, les marque-pages, le noussa'h, les réglages de lecture. Store.importJson ne lit pas journal_plus, que le site exporte et réimporte. Or ce fichier est présenté comme LA sauvegarde : le journal est exclu du nuage, reset_hint dit « Exportez d'abord vos données si vous voulez les garder », la politique de confidentialité dit que l'export « contient le journal », et le cahier Play en fait le passage obligé de l'édition GitHub à l'édition Play. Qui suit ces consignes perd sans avertissement gratitudes, humeurs, trophées du Tikoun et signets. Un aller-retour site → Android → site efface aussi le journal enrichi, alors que app.js:4420 promet « Un fichier exporté du site s'importe sur le téléphone, et l'inverse ».

**Preuve.** Store.kt:1484-1522 (exportJson : aucune mention de journal_plus ni de tikkun_journal) ; Store.kt:1525-1624 (importJson idem) ; Store.kt:949 « fun journalPlusBrut(context: Context): String? = journalPrefs(context).getString("journal_plus", null) » ; web/src/js/store.js:543 « // Le journal enrichi (02/11) : une clé de plus, qu'Android ignore à l'import. » ; PUBLICATION_PLAY_STORE.md:291 « Il faudra exporter le JSON, désinstaller, installer depuis Play, réimporter. » ; chaîne reset_hint.

**Correction proposée (revue par le contre-expert).** Recommandation juste, à compléter : fusionner à l'import le journal du Tikoun, les favoris et les signets par réunion sans doublon (journal_plus : garder ce qui est déjà noté, comme store.js) ; mettre à jour la liste de ce que contient l'export dans web/src/confidentialite.html (français, anglais, hébreu) et dans ConfidentialiteTest, puisque la politique énumère le contenu du fichier ; ne pas diffuser la consigne « exporter, désinstaller, réimporter » du cahier Play tant que l'export n'est pas complet.

**Note du contre-expert.** Store.kt 1484-1624 relu : ni exportJson ni importJson ne touchent journal_plus (fichier du journal, hors nuage ; backup_rules.xml écrit « Ils ne voyagent que par l'export JSON »), tikkun_journal, favoris, chizuk_favoris, marques_pages ni siddur_nusah, alors que reinitialiser() vide les deux fichiers et que PUBLICATION_PLAY_STORE.md:291 impose exporter → désinstaller → réimporter ; le site exporte et relit journal_plus (store.js:543-592) mais pas tikkun_journal. Aucune décision du propriétaire n'exclut ces données de l'export (la FEUILLE dit au contraire, 22/09, que ce qui est inscrit part dans l'export). Deux nuances sans effet sur le verdict : app.js:4420 est un commentaire de code, pas une promesse affichée ; tikkun_journal, favoris et signets vivent dans le fichier des réglages, que la sauvegarde nuage d'Android inclut, et ne se perdent donc que par la réinitialisation ou le passage GitHub → Play.

### FDONNEES-02 — Mode « Écrire » : au terme de la séance, le bravo s'ouvre par-dessus la note en cours, puis propose une seconde note vide

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** « Écrire » lance la séance et ouvre NoteDialog sur SessionActivity. La boucle d'une seconde de cet écran continue sous la fenêtre ; au terme du minuteur, render() appelle CelebrationActivity.showIfPending, qui lance l'écran du bravo par-dessus la note en cours de frappe, non enregistrée. « Continuer » y ouvre un second NoteDialog pour le même jour, prérempli avec la note stockée, donc vide : le texte écrit pendant toute la séance semble perdu. Il ne reparaît qu'au retour sur l'écran de séance ; deux fenêtres portent alors deux versions de la même note et la dernière enregistrée écrase l'autre. Lu dans le code, non exécuté.

**Preuve.** SessionActivity.kt:138-140 « demarrer { NoteDialog.show(this, Store.today(), onSaved = {}) } » ; SessionActivity.kt:63-66 (tick toutes les 1 000 ms) et :271 « if (!running) CelebrationActivity.showIfPending(this) » ; CelebrationActivity.kt:98 « NoteDialog.show(this, dateNote, onSaved = {}, onClosed = { finish() }) » ; NoteDialog.kt:43 « val initiale = Store.record(activity, date)?.note.orEmpty() ».

**Correction proposée.** Tant qu'un NoteDialog est ouvert sur SessionActivity, différer showIfPending jusqu'à sa fermeture et ne pas rouvrir la note depuis le bravo. Enregistrer le brouillon à chaque frappe (clé par date dans le fichier du journal) pour que toute fenêtre de note reparte du même texte.

**Note du contre-expert.** Chemin tracé dans le code : l'AlertDialog de NoteDialog ne met pas SessionActivity en pause, le tick d'une seconde continue (l.63-67), le service clôt la séance à son terme (SessionService.finishSession → inscrire → setPendingCelebration avec la date), render() l.271 lance donc le bravo par-dessus la note, et « Continuer » (CelebrationActivity:98) ouvre un second NoteDialog rempli depuis Store.record, donc vide. Rien ailleurs n'empêche l'enchaînement ; non exécuté (pas d'émulateur), mais c'est le cas nominal du mode « Écrire » (écrire jusqu'à la fin du minuteur).

### FDONNEES-03 — Une note en cours de frappe disparaît à la rotation de l'écran et à tout changement de configuration

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** NoteDialog est un AlertDialog simple, attaché à l'activité, sans DialogFragment ni état sauvegardé. MainActivity, SessionActivity et JournalActivity n'ont ni android:configChanges ni orientation figée (un dossier layout-land existe) : une rotation, le passage automatique au thème sombre, un redimensionnement de fenêtre ou un changement de taille de police recrée l'écran, détruit la fenêtre et tout ce qui y était tapé (note jusqu'à 4 000 caractères, gratitude, chose à travailler, humeurs), sans message. Seule CelebrationActivity résiste à la rotation, pas au changement de thème. Le commentaire de NoteDialog affirme le contraire.

**Preuve.** NoteDialog.kt:107-119 « AlertDialog.Builder(activity) … .create() … dialog.show() » ; NoteDialog.kt:19 « Ce qu'on a écrit ne se perd plus d'un geste (revue du 29/09) » ; AndroidManifest.xml:59-62, 243-252 (aucun configChanges) et :240 (CelebrationActivity : « orientation|screenSize|smallestScreenSize|screenLayout|keyboardHidden », sans uiMode) ; MainActivity.kt:59-60 « Lue une seule fois : une rotation ne la rouvre pas. »

**Correction proposée.** Passer NoteDialog en DialogFragment (date en argument, champs restaurés par onSaveInstanceState), ou au minimum enregistrer un brouillon à chaque frappe et le reprendre à la réouverture.

**Note du contre-expert.** Vérifié : NoteDialog est un AlertDialog sans état sauvegardé ni brouillon (aucun DialogFragment dans K), le manifeste ne donne configChanges qu'à CelebrationActivity (l.240, sans uiMode), aucune orientation n'est figée et layout-land existe ; toute recréation de MainActivity, SessionActivity ou JournalActivity détruit donc la fenêtre et ce qui y était tapé. Seule retouche : le commentaire de NoteDialog (l.19-22) ne promet que la protection contre le toucher à côté et le retour, il n'« affirme pas le contraire » pour la rotation.

### FDONNEES-04 — Aucun moyen de corriger ou de retirer une journée : une durée saisie par erreur reste à vie

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** Les minutes ne font que s'ajouter (addSession), l'import garde le maximum, et la seule fonction de retrait, Store.unmarkToday, n'a aucun appelant. « Ajouter du temps fait hors du téléphone » accepte jusqu'à 240 minutes sur n'importe quel jour passé, sans annulation. Une faute de frappe (200 au lieu de 20), un mauvais jour choisi ou un toucher sur « J'ai dit le Tikoun en entier » par erreur faussent définitivement le total, les records (« Meilleure journée »), la série et les trophées (« 180 minutes en un jour » gagné d'un coup). Seule issue : tout réinitialiser. Le site a la même limite (store.js n'a aucune suppression de journée).

**Preuve.** Store.kt:338 « fun unmarkToday(context: Context) » : 0 appelant dans le dépôt (grep sur *.kt, *.xml, *.js) ; Store.kt:304 « minutes = (existing?.minutes ?: 0) + minutes.coerceAtLeast(0) » ; Store.kt:1555 « maxOf(existing.minutes, incoming.minutes) » ; AjoutTemps.kt:30-32 ; TikkunFlowActivity.kt:105 (ajout seul ; resetTikkun et setTikkunDone(…, false) sans appelant Android).

**Correction proposée.** Dans la fiche d'un jour (AjoutTemps) et dans le journal : « Corriger la durée » (remplace les minutes) et « Retirer cette journée » avec confirmation ; un bouton « Annuler » dans le message qui suit un ajout ; de même pour le Tikoun du jour. Reporter sur le site.

**Note du contre-expert.** Vérifié : unmarkToday (Store.kt:338) n'a aucun appelant, addSession additionne (l.304), l'import garde le maximum (l.1555), DureeSeance.choisir inscrit dès le toucher d'une durée sans confirmation, et ni resetTikkun ni setTikkunDone(…, false) ne sont appelés sur Android ; store.js n'a aucune suppression de journée non plus. Aucune décision de la FEUILLE ne dit que c'est voulu (elle acte seulement, le 16/10, que les minutes s'ajoutent) ; la seule issue est bien la réinitialisation complète.

### FDONNEES-05 — Israël ou diaspora s'applique à tout le passé : un voyage casse la série après coup

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** isExempt juge chaque jour passé avec le réglage in_israel du moment. Or ce réglage bascule tout seul : avec « Ma position », enregistrerPosition le recalcule au changement de fuseau (BootReceiver) et à l'ouverture de l'application (rafraichirSiBesoin, toutes les 6 h) ; choisir une ville le change aussi. Un utilisateur de diaspora qui atterrit en Israël voit ses deuxièmes jours de fête passés (16 et 23 Tichri…) devenir des jours manqués : série, meilleure série et trophées de série tombent, puis reviennent au retour (et sont refêtés). C'est le défaut que la revue du 01/10 disait avoir corrigé. Vérifié par exécution des règles du site, identiques : une série de 84 jours tenue en diaspora du 03/08 au 12/11/2026 tombe à 34 dès que in_israel passe à vrai, et revient à 84 au retour. Couper l'interrupteur « Chabbat et Yom Tov » a le même effet rétroactif (84 → 5).

**Preuve.** Store.kt:631-634 « return shabbatMode(context) && Holidays.isRestDay(date, inIsrael(context)) » ; ChoixLieu.kt:226 « Store.setInIsrael(context, TerritoireIsrael.contient(position.latitude, position.longitude)) » ; BootReceiver.kt:28 ; MainActivity.kt:149 « choixLieu.rafraichirSiBesoin() » ; Store.kt:392-394 « sans cela, un voyage changeait le deuxième jour de fête après coup, et pouvait casser une série (revue du 01/10) » ; exécution Node de web/src/js/store.js : « diaspora : serie 84 … israel : serie 34 … retour : serie 84 … chabbat off : serie 5 ».

**Correction proposée.** Dater les changements : garder l'historique (date d'effet, valeur) de in_israel et de pause_shabbat et évaluer isExempt(date) avec la valeur en vigueur ce jour-là ; à défaut, figer chaque jour exempté dans une liste écrite au fil des jours. Même règle dans store.js.

**Note du contre-expert.** Vérifié dans Store.kt:631-634 (isExempt lit in_israel et pause_shabbat du moment pour tout le passé), ChoixLieu.kt:226, Store.kt:473, BootReceiver.kt:28 et MainActivity.kt:149 (bascule automatique avec « Ma position »). Essai relancé sur web/src/js/store.js : 84 jours tenus en diaspora du 03/08 au 12/11/2026 donnent série 84, puis 34 (meilleure 45) dès in_israel = vrai, 84 au retour, et 5 interrupteur Chabbat coupé ; comme setTropheesVus remplace la liste par les trophées du moment (Confettis.kt:184), ceux qui reviennent sont bien refêtés. Le commentaire de Store.kt:392-394 présente ce défaut comme corrigé le 01/10.

### FDONNEES-06 — La notification d'un trophée annonce un métal que l'écran ne montre jamais (« Platine » au cinquième jour)

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** Le message « Trophée « %1$s » : niveau %2$d, %3$s ! » prend le métal de l'ancien système (un quart de la famille par métal), alors que l'écran des trophées colore chaque trophée selon le grade global (bronze jusqu'au 9e trophée, argent dès le 10e). Pour « Premier pas » (5 niveaux), tout utilisateur reçoit au 3e jour « niveau 3, Argent », au 4e « Or », au 5e « Platine », puis ouvre une fiche en bronze qui dit « En Bronze : c'était votre 8ᵉ trophée ». Vérifié par exécution de trophees.js : rangs 1 à 5 = bronze, bronze, argent, or, platine ; grade(8) = bronze. Le site construit le même message.

**Preuve.** Confettis.kt:158-159 « c.getString(R.string.trophee_niveau_gagne, TropheesVue.nom(c, trophee.famille), trophee.rang, TropheesVue.metal(c, trophee.metal)) » ; Trophees.kt:50-54 (metal : « (rang - 1) * 4 / f.seuils.size ») ; FicheTrophee.kt:44 « val m = if (gagne) Trophees.grade(rangGlobal) else null » ; web/src/js/app.js:3835.

**Correction proposée (revue par le contre-expert).** Retirer le métal du message dans les trois langues et passer deux arguments au lieu de trois dans Confettis.kt:158-159. FR : « Trophée « %1$s » : niveau %2$d ! » ; EN : « “%1$s” trophy: level %2$d! » ; HE : « גביע „%1$s”: דרגה %2$d! ». Supprimer aussi la construction morte du même message dans web/src/js/app.js:3835. Si Niveau.metal est retiré, remplacer le tri de Trophees.nouveaux (Kotlin et trophees.js) par un ordre explicite, par exemple le coût décroissant (Trophees.cout), et corriger l'en-tête de Trophees.kt qui décrit encore le métal par famille.

**Note du contre-expert.** Réel sur Android : Confettis.kt:158-159 est le seul texte visible qui prend encore le métal par famille (Trophees.kt:50-54), tout le reste suit le grade global ; simulation sur trophees.js : jour 3 « Premier pas, niveau 3, argent », jour 5 « niveau 5, platine » avec 8 trophées gagnés, donc grade bronze. Portée à corriger : ce n'est pas transverse, le site construit ce message (app.js:3835) mais ne l'affiche jamais quand un trophée est neuf (il ouvre la fiche ; « signale » ne sert qu'au palier) ; le texte faux n'apparaît que dans la notification Android de fin de séance. La recommandation oublie l'hébreu.

### FDONNEES-08 — Le jour de hitbodedout bascule à minuit alors que le Tikoun bascule à 4 h : une pratique de nuit casse la série

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : fonction

**Constat.** Une séance compte pour le jour civil où elle commence. Qui fait sa hitbodedout chaque nuit autour de 'hatsot (avant ou après minuit selon la saison) inscrit lundi 23 h 40 sur lundi, puis la nuit suivante 0 h 10 sur mercredi : mardi reste vide, la série tombe et l'accueil dit « Série à relancer » alors que rien n'a été manqué. Le même défaut a été corrigé le 02/11 pour le Tikoun (bascule à 4 h) et pour la barrière (fenêtre de nuit), pas pour le journal ni la série. Trois conventions coexistent : minuit (série, widget, paliers), 4 h (Tikoun), sortie des étoiles (date hébraïque affichée). Le seul recours est de déclarer « hier » à la main.

**Preuve.** Store.kt:161-163 « Le jour du Tikoun bascule à 4 h, pas à minuit : commencé à 23 h 45, il se finit après minuit (bug du 02/11) » ; Store.kt:1189 « val date = if (started > 0L) minOf(dateOf(started), today()) else today() » ; Store.kt:645-646 (streak part de LocalDate.now()) ; Store.kt:346-352 (fenetreFaite : « à 0 h 30, c'est encore la nuit de la veille ») ; web/src/js/store.js:78-81.

**Correction proposée (revue par le contre-expert).** Au choix du propriétaire : soit écrire la règle « jour civil » dans FEUILLE_DE_ROUTE.md et proposer d'office « hier » quand une séance commence avant 4 h et qu'hier n'est ni fait ni exempté ; soit une fonction unique jourDePratique(instant) = jour civil de (instant − 4 h) pour endSession, la série, la semaine, le widget et son alarme, sur Android et dans store.js. Dans ce second cas, décider d'abord si une séance de 0 h 30 honore encore la barrière du matin : aujourd'hui oui, car pour une fenêtre de jour fenetreFaite repose sur isDone du jour civil ; il faudrait alors la faire reposer sur l'instant de la dernière séance (KEY_FAIT_A), revoir l'annulation du rappel du jour, et ne pas redater les journées déjà inscrites.

**Note du contre-expert.** Réel : la séance s'inscrit au jour civil de son début (Store.kt:1189), la série part de LocalDate.now() (l.645-646), alors que le Tikoun bascule à 4 h (l.161-163) et que la barrière connaît la fenêtre de nuit ; aucune décision de la FEUILLE ne fixe minuit pour le journal, et la pratique après 'hatsot est le cas type du public visé. À corriger dans la description : la série ne casse que si l'heure de début passe d'avant à après minuit d'une nuit à l'autre (une pratique toujours après minuit ne casse rien), et le recours n'est pas seulement « hier » : AjoutTemps permet d'inscrire n'importe quel jour passé depuis la bande de la semaine ou le calendrier. La première option recommandée a un effet de bord non signalé sur la barrière.

### FDONNEES-09 — La série du Tikoun ignore Chabbat et fêtes et n'admet aucune saisie après coup

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** La famille « La harpe de David » (3, 7, 10, 18, 30, 40, 70, 100 jours de Tikoun d'affilée) compte des jours strictement consécutifs. La série de hitbodedout saute Chabbat et Yom Tov ; celle-ci non. Le Tikoun ne s'inscrit que pour le jour en cours (bascule à 4 h) : celui de Chabbat ne peut être validé qu'entre la sortie de Chabbat et 4 h du matin, et le premier jour d'une fête de deux jours ne peut jamais l'être. Pour qui ne touche pas son téléphone le Chabbat, 7 des 8 niveaux dépendent de ce geste que rien n'indique, et la suite est rompue à chaque fête de deux jours.

**Preuve.** Trophees.kt:96 « Famille.TIKKUN_SERIE -> plusLongueSuite(p.tikkun) » ; Trophees.kt:63-71 (suite : écart d'un jour exactement, sans exemption) ; Trophees.kt:39 « intArrayOf(3, 7, 10, 18, 30, 40, 70, 100) » ; Store.kt:1436-1438 (inscription au seul jourTikkun()) ; TikkunFlowActivity.kt:105 ; web/src/js/trophees.js (plusLongueSuite, même règle).

**Correction proposée.** Calculer la suite du Tikoun comme Plaque.meilleureSerie (un jour exempté ne compte pas et ne casse pas) et permettre d'inscrire un Tikoun dit hier ou le Chabbat, comme AjoutTemps le fait pour la hitbodedout.

**Note du contre-expert.** Vérifié : Trophees.plusLongueSuite (l.63-71) exige un écart d'un jour exactement, sans exemption, alors que la série de hitbodedout saute Chabbat et Yom Tov (Plaque.meilleureSerie, datesGain) ; setTikkunDone n'inscrit que jourTikkun() (Store.kt:1436-1442) et son seul appelant Android est TikkunFlowActivity:105, donc un Tikoun de Chabbat ne s'inscrit qu'entre la sortie de Chabbat et 4 h et le premier de deux jours chômés jamais. Sans ce geste la suite plafonne à 6 jours, soit un seul des huit niveaux (3, 7, 10, 18, 30, 40, 70, 100) ; trophees.js applique la même règle et aucune décision documentée ne la justifie.

### FDONNEES-07 — Le journal entier est redécodé à chaque lecture : deux fois toutes les 0,9 s par la barrière, au moins 25 fois par affichage de l'accueil

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : android · **Type** : fonction

**Constat.** Store.days() relit et décode toute la chaîne JSON du journal (toutes les journées et toutes les notes, jusqu'à 4 000 caractères chacune) à chaque appel, sans cache. GateService tourne en permanence dès que la barrière est réglée, même hors plage : chaque tour de 900 ms appelle GateStatus.evaluate deux fois, et evaluate interroge fenetreFaite (donc days()) avant de regarder la plage horaire, soit environ 8 000 décodages complets par heure d'écran allumé, sur le fil principal, et un coût qui grandit avec l'ancienneté du journal. L'accueil en fait au moins 25 par onResume (renderToday 3, renderWeek 1, renderGauge 7, apresRemplissage 3, renderPaliers et Celebrations.ecran 11). « Mon parcours » redécode tout journal_plus une fois par journée (quadratique), et la liste du journal une fois par ligne affichée. Les durées n'ont pas été mesurées ; les comptes viennent de la lecture du code.

**Preuve.** GateService.kt:245 « POLL_MS = 900L », :79 « rafraichirNotification() » (→ :212 « GateStatus.evaluate(this) ») et :82 « GateStatus.isArmed(this) » ; GateStatus.kt:29 « Store.fenetreFaite(context) -> GateState.ALREADY_DONE » placé avant :32 « !Store.inWindow(context) » ; Store.kt:283-284 et :203-210 « val root = JSONObject(raw) » ; ParcoursActivity.kt:57 « Parcours.humeur(jours.keys.map { JournalPlus.lire(this, it) }) » ; JournalPlus.kt:31-34 ; JournalActivity.kt:108.

**Correction proposée (revue par le contre-expert).** Garder en mémoire la carte décodée des journées et celle de journal_plus (invalidées dans writeDays, setJournalPlusBrut, importJson et reinitialiser) ; n'appeler GateStatus.evaluate qu'une fois par tour de GateService et réutiliser l'état ; lire journal_plus une seule fois par écran (Parcours, liste du journal). Ne pas changer l'ordre des tests de GateStatus.evaluate : il fixe aussi l'état affiché sur l'accueil et dans la notification (« Fait pour aujourd'hui » passe avant « hors plage »). Mesurer sur un vrai téléphone avec un journal d'un an avant de reclasser plus haut.

**Note du contre-expert.** Les faits sont exacts : days() redécode tout sans cache (Store.kt:203-237), GateService évalue GateStatus deux fois par tour de 900 ms sur le fil principal (l.79 et 82), ParcoursActivity:57 et JournalActivity:108 redécodent journal_plus à chaque jour ou ligne. Mais aucun effet visible n'est établi : mon essai sur JVM de bureau donne environ 0,7 ms par décodage pour un an sans notes et 2,8 ms pour un an de notes de 300 caractères, soit un coût latent qui ne devient sensible qu'avec un journal long et très annoté ; de plus, avec une fenêtre de nuit et l'heure de la dernière séance connue, fenetreFaite ne lit pas le journal. C'est une inefficacité à corriger, pas un bogue visible : mineur.

### FDONNEES-10 — Trophées fêtés deux fois, et pluie de fiches après un import

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** La liste des trophées déjà fêtés est remplacée, à chaque passage, par les trophées gagnés à cet instant. Un trophée qui disparaît puis revient est donc refêté avec fiche et confettis : note effacée puis réécrite (« La plume »), interrupteur Chabbat coupé puis rallumé, région changée. Et la règle « pas de pluie de vieux trophées » ne tient que si la liste est nulle : après un premier affichage de l'accueil elle vaut l'ensemble vide, si bien qu'un import d'historique sur un téléphone neuf ouvre à la suite une fiche par famille (jusqu'à 11). readBackup ne marque rien comme vu. Vérifié sur trophees.js : nouveaux(gagnés, null) rend 0 trophée, nouveaux(gagnés, ensemble vide) en rend 8 pour 200 jours de pratique.

**Preuve.** Confettis.kt:184 « Store.setTropheesVus(activity, r.trophees) » ; PaliersActivity.kt:189 ; Trophees.kt:254-256 « if (vus == null || (vus.isNotEmpty() && vus.none { ':' in it })) return emptyList() » ; SettingsActivity.kt:577-589 (après importJson : ni setTropheesVus, ni Celebrations.marquerNotifies).

**Correction proposée.** Garder l'union (vus + gagnés) au lieu de remplacer ; après importJson, poser tropheesVus, paliersVus, gradeVu et les listes « notifiés » sur l'état importé.

### FDONNEES-11 — L'import écrase les réglages sans prévenir ; son message compte des journées qui n'ont pas changé

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Dès le fichier choisi, importJson fusionne les journées mais remplace sans confirmation la plage de la barrière, la durée, les rappels, Chabbat, Israël ou diaspora (donc la série), l'apparence et le prénom par ceux du fichier ; un prénom vide dans le fichier (export du site sans prénom) efface celui du téléphone. En cas de conflit, la note du fichier est abandonnée en silence si le téléphone en a déjà une. Le message « %d journées importées » compte toutes les entrées valides du fichier, même identiques : réimporter le même fichier annonce de nouveau tout le journal. Le champ « version » n'est pas lu : un fichier d'un format plus récent passe sans avertissement.

**Preuve.** SettingsActivity.kt:577 « val imported = Store.importJson(this, text) » (aucun dialogue avant) ; Store.kt:1594 « if (settings.has("first_name")) setFirstName(context, settings.optString("first_name")) » ; Store.kt:1556 « existing.note.ifBlank { incoming.note } » ; Store.kt:1561 « imported++ » (hors de tout test de changement) ; Store.kt:1527 (seul « format » est vérifié).

**Correction proposée.** Avant d'importer, un dialogue qui résume le fichier (date d'export, nombre de journées, dont nouvelles) et propose « Journal seulement » ou « Journal et réglages » ; ne compter que les journées ajoutées ou modifiées ; ignorer un prénom vide ; refuser ou signaler version > version connue.

### FDONNEES-12 — La fenêtre où s'écrit la note n'est pas protégée des captures, et le journal n'a aucun verrou

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** FLAG_SECURE est posé sur la seule fenêtre de JournalActivity. NoteDialog, où la note entière est affichée et tapée, est une fenêtre à part qui n'hérite pas de ce drapeau : elle reste visible dans les captures, l'enregistrement d'écran et la diffusion, et elle s'ouvre aussi depuis l'accueil, le bravo et l'écran de séance, qui n'ont aucun drapeau. Par ailleurs rien ne verrouille le journal (ni code, ni empreinte : aucune référence à BiometricPrompt ou KeyguardManager) et l'export est en clair. L'intention écrite dans le code n'est donc tenue que pour la liste.

**Preuve.** JournalActivity.kt:23-28 « Les notes sont ce qu'il y a de plus intime : ni capture d'écran, ni aperçu dans les applications récentes (revue du 01/10) » ; NoteDialog.kt:107-119 (aucun window.addFlags) ; appels : MainActivity.kt:63 et :242, CelebrationActivity.kt:98, SessionActivity.kt:139.

**Correction proposée.** Dans NoteDialog.show, avant dialog.show() : dialog.window?.addFlags(WindowManager.LayoutParams.FLAG_SECURE). Proposer en option un verrou du journal par le verrouillage de l'appareil (BiometricPrompt avec DEVICE_CREDENTIAL).

### FDONNEES-13 — Gratitude, « à travailler » et humeurs se perdent d'un Retour, sans avertissement

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** La protection contre la fermeture accidentelle ne surveille que le champ de la note. Si l'on ne remplit que la gratitude, la chose à travailler ou les humeurs, Retour ferme la fenêtre et le bouton reste « Plus tard » au lieu de « Ne pas enregistrer » : la saisie est perdue.

**Preuve.** NoteDialog.kt:120-129 : « input.addTextChangedListener(…) { val change = s.toString().trim() != initiale.trim() ; dialog.setCancelable(!change) … } » ; aucun écouteur sur gratitude (l.81-86), travail (l.88-93) ni sur les humeurs.

**Correction proposée.** Calculer « change » sur l'ensemble (note, gratitude, travail, avant, après) et brancher le même écouteur sur les trois champs et sur les boutons d'humeur.

### FDONNEES-14 — Humeur et gratitude orphelines : gardées mais invisibles quand le jour n'a pas de ligne

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** NoteDialog écrit JournalPlus même quand Store.setNote ne crée ou ne garde aucune journée : « Écrire » puis séance annulée avec seulement une humeur ou une gratitude ; ou note seule vidée alors que la gratitude reste (la ligne est supprimée). Le journal et « Mon parcours » ne parcourent que Store.days : ces entrées ne s'affichent plus et ne peuvent plus être modifiées. Le site a corrigé le second cas, pas Android.

**Preuve.** Store.kt:330 « existing?.noteSeule == true && note.isBlank() -> all.remove(date) » et :333 « else -> return » ; NoteDialog.kt:111-112 (setNote puis JournalPlus.ecrire, sans condition) ; web/src/js/store.js:223-224 « Un jour sans séance dont la note est vidée disparaît, sauf s'il garde humeur ou gratitude. »

**Correction proposée.** Dans setNote, garder ou créer une journée note_seule dès que JournalPlus n'est pas vide pour cette date (même règle que store.js) ; au chargement, rattacher les entrées orphelines existantes.

### FDONNEES-15 — « J'ai déjà fait » depuis la barrière : ni le widget ni le rappel affiché ne suivent

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Ce bouton de l'écran de garde valide la journée (0 minute) puis renvoie à l'écran d'accueil du téléphone, sans redessiner la vignette : elle y affiche encore « Pas encore aujourd'hui » et la flamme éteinte, jusqu'à la mise à jour horaire ou l'ouverture de l'application. Et comme addSession ne retire la notification de rappel que si minutes > 0, le rappel « il est temps » reste dans le volet alors que la journée est faite.

**Preuve.** GateService.kt:138-142 « onAlreadyDone = { Store.addSession(this, 0) ; hideOverlay() ; goHome() } » (aucun StreakWidget.refresh) ; Store.kt:320-321 « // La journée est faite : le rappel … ne reste pas dans le volet … if (minutes > 0) runCatching { … cancel(Notifications.ID_REMINDER) } ».

**Correction proposée.** Dans onAlreadyDone : StreakWidget.refresh(this) et Reminder.reschedule(this) ; dans addSession, retirer le rappel quelle que soit la durée.

### FDONNEES-16 — Une date aberrante importée (« 0202-… ») fait recalculer dix-huit siècles à chaque affichage ; corrigé sur le site, pas sur Android

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Le site borne les dates entre 2000 et 2100 depuis le 02/11. Sur Android, dateValide accepte toute date ISO : une sauvegarde retouchée ou abîmée avec une année fausse entre au journal, et Plaque.meilleureSerie parcourt alors jour par jour du premier au dernier jour fait (un calendrier hébraïque par jour), trois fois par affichage de l'accueil. Comme aucune journée ne peut être retirée, seule la réinitialisation en sort.

**Preuve.** web/src/js/store.js:29-31 « Ni avant 2000 ni après 2100 (relecture du 02/11) : une sauvegarde retouchée avec « 0202 » faisait remonter le calcul de la meilleure série sur dix-huit siècles, à chaque affichage. » ; Store.kt:268-270 (dateValide sans borne) ; Store.kt:1537-1538 ; Plaque.kt:44-58 (boucle de faits.min() à faits.max()).

**Correction proposée.** Dans Store.dateValide : « ?.takeIf { it.year in 2000..2100 } », comme le site.

### FDONNEES-17 — La copie d'un journal illisible n'est jamais relue ni signalée

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Si le JSON du journal ne se décode plus, days() en garde une copie sous days_corrompu, puis la prochaine écriture remplace le journal par la seule journée du jour. Rien ne lit cette clé : ni écran, ni export, ni message. L'utilisateur voit sa série et son journal vides sans savoir pourquoi ni comment récupérer, alors que le commentaire dit que le journal n'est pas « écrasé en silence ».

**Preuve.** Store.kt:66-67 « Copie d'un journal illisible, gardée pour qu'il ne soit pas écrasé en silence. » ; Store.kt:229 « if (!p.contains(KEY_DAYS_CORROMPU)) p.edit().putString(KEY_DAYS_CORROMPU, raw).apply() » ; seules occurrences de la clé : Store.kt:67 et :229.

**Correction proposée.** Tant que la clé existe, afficher dans Réglages → Mes données « Un journal illisible a été mis de côté » avec « Enregistrer la copie » (fichier brut) et « Oublier » ; joindre la copie à l'export.

### FDONNEES-18 — « Semaine pleine » : l'anneau et le trophée ne suivent pas la même règle

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** La jauge et l'anneau de la semaine retirent des jours dus les jours exemptés (Chabbat, Yom Tov, pause) : une semaine avec un Yom Tov en semaine se ferme à 5/5 et est fêtée. Le trophée « Semaines pleines » exige les six jours du dimanche au vendredi, tous faits, sans exemption : la même semaine ne compte pas. Les semaines qui contiennent un Yom Tov en semaine sont hors d'atteinte pour qui observe la fête, sans que rien ne le dise.

**Preuve.** JaugeSemaine.kt:28-31 « dus = jours.count { it.done || !it.exempt } » ; Trophees.kt:74-75 « d.dayOfWeek == DayOfWeek.SUNDAY && (0L..5L).all { d.plusDays(it) in jours } » ; chaîne trophee_semaines_desc « %1$d semaines pleines, du dimanche au vendredi ».

**Correction proposée.** Donner à semainesPleines le prédicat « exempt » (un jour de Yom Tov entre dimanche et vendredi n'est pas exigé, la semaine doit garder au moins un jour fait), dans Trophees.kt, datesGain et trophees.js.

### FDONNEES-19 — La pause ne se déclare que le jour même : après coup, seule une fausse déclaration sauve la série

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** « Pause aujourd'hui » ne porte que sur la date du jour. Un malade qui n'ouvre pas l'application ce jour-là ne peut plus, le lendemain, marquer la journée comme pause ; la seule façon de garder sa série est « Ajouter du temps fait hors du téléphone », c'est-à-dire déclarer une hitbodedout qui n'a pas eu lieu. À l'inverse la pause du jour est sans limite : la poser chaque jour manqué garde la série indéfiniment et ferme l'anneau de la semaine.

**Preuve.** SettingsActivity.kt:341-342 « bindSwitch(R.id.exempt_today_switch, Store.pausedDates(this).contains(Store.today())) { Store.togglePausedDate(this, Store.today()) » ; AjoutTemps.kt:9-13 (ajout sur n'importe quel jour passé) ; web/src/js/app.js:4416.

**Correction proposée.** Dans la fiche d'un jour passé (bande de la semaine, calendrier), à côté de « Ajouter du temps » : « Marquer comme pause » et « Retirer la pause », limités par exemple aux sept derniers jours.

### FDONNEES-20 — Confidentialité : le transfert d'appareil n'emporte pas le journal sur Android 8 à 11, et le fichier « réglages » sauvegardé contient plus que la liste annoncée

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : play · **Type** : texte

**Constat.** 1) La politique affirme que le transfert d'appareil emporte « les réglages et le journal ». C'est vrai sous Android 12 et plus (data_extraction_rules.xml). Sous Android 8 à 11 (minSdk 26), c'est backup_rules.xml qui régit aussi le transfert, et il n'inclut que les réglages : le journal n'est pas transféré. 2) Le fichier des réglages, envoyé dans le nuage, contient aussi des traces de pratique que la liste ne cite pas : tikkun_journal (chaque jour où le Tikoun a été dit), paused_dates, paliers_vus et trophees_vus (seuils atteints), seance_faite_a, favoris, marque-pages. 3) La chaîne section_data_hint dit « Tout est stocké sur ce téléphone uniquement », ce qui est faux dès que la sauvegarde Android est active. Après une restauration depuis le nuage, l'application revient sans journal, présentation sautée, sans inviter à importer.

**Preuve.** web/src/confidentialite.html (« Transfert d'appareil … : les réglages et le journal, notes et prénom compris ») ; res/xml/backup_rules.xml (un seul include : myhitbodedut.xml) ; build.gradle:12 « minSdk = 26 » ; Store.kt:158-159 (KEY_TIKKUN_JOURNAL dans prefs(), pas journalPrefs()) ; Store.kt:618-625 ; chaîne section_data_hint.

**Correction proposée.** Politique : « Transfert d'appareil (Android 12 et plus) : les réglages et le journal… ; sous Android 8 à 11, les réglages seuls : exportez votre journal. » Déplacer tikkun_journal dans le fichier du journal. section_data_hint FR : « Votre journal reste sur ce téléphone. Exportez de temps en temps. » EN : « Your journal stays on this phone. Export from time to time. »

### FDONNEES-21 — Journal : ni recherche, ni filtre, ni export lisible

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** JournalActivity n'est qu'une liste de toutes les journées, de la plus récente à la plus ancienne : pas de recherche dans les notes, pas de filtre par sujet ou par mois, pas de saut à une date. La seule sortie est le fichier JSON technique ; aucune version lisible (texte) des notes. Aucun de ces points ne figure dans « Ce qui manque » ni « Reste à faire ».

**Preuve.** JournalActivity.kt:41-44 « rows.addAll(Store.days(this).values.sortedByDescending { it.date }) » (seule source de l'écran) ; SettingsActivity.kt:167-169 (seul export : « myhitbodedut-${Store.today()}.json ») ; FEUILLE_DE_ROUTE.md:1007-1052 (rien sur le journal Android).

**Correction proposée.** Un champ de recherche en tête de liste (note, gratitude, sujet) et un bouton « Exporter mes notes en texte » (date, durée, sujets, note, gratitude, à travailler) par le même sélecteur de fichier.

### FDONNEES-22 — Pluriels fautifs : « 1 trophées gagnés », « Série : 1 jours sur 7 », « votre 1ᵉ trophée »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Sept chaînes françaises et quatre anglaises portent un nombre sans forme au singulier. Elles s'affichent dès le premier jour (un seul trophée après une séance de moins de 10 minutes, série de 1 jour, fiche du premier trophée). FR : grade_sous, grade_sous_max, grade_partage_texte, trophees_autres, ring_streak_detail, rings_description, trophee_detail_grade. EN : grade_sous, grade_sous_max, grade_partage_texte, trophees_autres.

**Preuve.** values/strings.xml : grade_sous « %1$d trophées gagnés · encore %2$d pour %3$s » ; grade_sous_max « %1$d trophées gagnés » ; trophees_autres « … et %1$d autres trophées plus loin » ; ring_streak_detail « Série : %1$d jours sur %2$d » ; trophee_detail_grade « En %1$s : c'était votre %2$dᵉ trophée. » ; values-en : grade_sous « %1$d trophies earned · %2$d more for %3$s ». Usages : PaliersActivity.kt:78-79, :147, :341, :351 ; MainActivity.kt:638 ; FicheTrophee.kt:81.

**Correction proposée.** Passer en &lt;plurals>. FR one : « %1$d trophée gagné · encore %2$d pour %3$s », « %1$d trophée gagné », « Grade %1$s sur MyHitbodedut : %2$d trophée, jour après jour. », « … et %1$d autre trophée plus loin », « Série : %1$d jour sur %2$d ». rings_description : « Anneaux. Aujourd'hui : %1$s sur %2$s. Semaine : %3$d sur %4$d jours. Série : %5$d sur %6$d jours. » trophee_detail_grade : « En %1$s : votre trophée n° %2$d. » EN one : « %1$d trophy earned · %2$d more for %3$s », « %1$d trophy earned », « %1$s grade on MyHitbodedut: %2$d trophy, day after day. », « … and %1$d more trophy further on ».

### FDONNEES-23 — Anglais fautif dans le journal, les trophées et le widget : « 3 times hitbodedut », « First 3 times hitbodedut », « Not expected today. »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Trois chaînes anglaises ne sont pas de l'anglais correct ou ne disent pas la même chose que le français. journal_summary et trophee_premier_pas_desc collent « times » à « hitbodedut » ; widget_rest (« Repos aujourd'hui. ») est rendu par « Not expected today. », sans sujet, alors que les réglages disent « Rest day ». De plus journal_summary, dans les deux langues, annonce des « hitbodedout » alors que le nombre est celui des jours faits, et « Premier pas » compte aussi des jours.

**Preuve.** values-en/strings.xml : journal_summary « %1$d time hitbodedut, %2$s in total » / « %1$d times hitbodedut, %2$s in total » ; trophee_premier_pas_desc (other) « First %1$d times hitbodedut » ; widget_rest « Not expected today. » ; JournalActivity.kt:53 « val faites = rows.count { it.faite } » ; Trophees.kt:86 « Famille.PREMIER_PAS -> jours.size.coerceAtMost(5) ».

**Correction proposée.** EN journal_summary : « %1$d day of hitbodedut, %2$s in total » / « %1$d days of hitbodedut, %2$s in total ». FR : « %1$d jour de hitbodedout, %2$s au total » / « %1$d jours de hitbodedout, %2$s au total ». EN trophee_premier_pas_desc (other) : « Your first %1$d days of hitbodedut » ; FR : « %1$d premiers jours de hitbodedout ». EN widget_rest : « Rest day today. »

### FDONNEES-24 — Favoris, « Reprendre la lecture » et marque-pages : titres en hébreu seul, quelle que soit la langue

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** En tête de la Bibliothèque, les lignes de reprise, de favoris et la feuille des marque-pages n'affichent que le titre hébreu du texte, sans la traduction que la liste du siddour montre juste en dessous. Les traductions existent dans les données (42 titres sur 42 ont un français et un anglais dans siddur_edot.json). Un lecteur francophone ou anglophone ne peut pas reconnaître ses favoris.

**Preuve.** RepriseFavoris.kt:19-25 « /** Le titre hébreu d'une clé « s:id » ou « l:id », ou null. */ … return recueil.texte(id)?.titre?.he » ; à comparer à SiddurActivity.kt:86-89 « val traduction = texte.titre.forLanguage(langue).takeIf { it != texte.titre.he } ».

**Correction proposée.** Dans RepriseFavoris.ligne et signet, ajouter sous le titre hébreu la traduction « titre.forLanguage(ChizukCard.language(c)) » quand elle diffère de l'hébreu, comme SiddurActivity.

### FDONNEES-25 — Grande vignette : le texte du jour reste en hébreu seul pour les lecteurs français et anglais (choix voulu)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte · déjà connu ou choix assumé

**Constat.** La grande vignette affiche trois lignes de 'hizouk en hébreu et sa référence, sans traduction, alors que ChizukCard.translationOf fournit le français et l'anglais de chaque texte. C'est un choix écrit dans le gabarit et tenu par un test ; il laisse un tiers de la grande vignette illisible à qui ne lit pas l'hébreu, soit le public des deux langues à vérifier.

**Preuve.** StreakWidget.kt:530 « views.setTextViewText(R.id.widget_text, ChizukRules.hebrew(chizuk, item)) » ; res/layout/widget_large.xml:555 « À droite quelle que soit la langue de l'écran d'accueil : c'est de l'hébreu. » ; WidgetTest.kt:134 « le texte du jour est en hebreu a empattements sans police de l application ».

**Correction proposée.** En français et en anglais, montrer la traduction (ChizukCard.translationOf, deux à trois lignes) à la place ou sous une ligne d'hébreu ; garder l'hébreu seul quand l'application est en hébreu.

### FDONNEES-26 — Trois échelles différentes pour la série, dont deux s'appellent « palier »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** L'anneau et la plaque visent 7, 14, 30, 60, 100, 180, 365 (« prochain palier 30 ») ; les paliers, qui n'ont plus d'écran mais annoncent encore par message et notification, suivent 3, 7, 14, 18, 21, 30, 40… (« Palier atteint : Jours d'affilée — 21 jours ! ») ; les trophées suivent 3, 5, 7, 10, 15, 18, 20, 30… À 21 jours, l'utilisateur lit « Palier atteint : 21 jours » alors que l'anneau affiche « Série : 21 jours sur 30 ».

**Preuve.** Anneaux.kt:23 « val PALIERS = intArrayOf(7, 14, 30, 60, 100, 180, 365) » ; Paliers.kt:27 « Piste.SERIE to (intArrayOf(3, 7, 14, 18, 21, 30, 40, 50, 70, 100, 150, 180, 250, 365) to 365) » ; Trophees.kt:31 (SERIE : 3, 5, 7, 10, 15, 18, 20, 30…) ; chaînes plaque_serie, ring_streak_reached, palier_nouveau.

**Correction proposée.** Une seule échelle : faire viser à l'anneau le prochain seuil du trophée « La série » et retirer la piste SERIE des paliers ; sinon réserver « palier » à l'anneau et dire « étape » ailleurs.

### FDONNEES-27 — Journal : « Gratitude : » à la française en anglais, et humeurs annoncées « 1/5 » par TalkBack

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** JournalPlus.resume assemble « libellé : texte » avec une espace avant les deux-points, en dur : en anglais le journal affiche « Gratitude : … » et « To work on : … ». Les cinq boutons d'humeur ont pour description « 1/5 » à « 5/5 », non traduite et sans dire de quoi il s'agit.

**Preuve.** JournalPlus.kt:54-55 « "$gratitude : $it" » et « "$travail : $it" » ; NoteDialog.kt:68 « contentDescription = "${i + 1}/5" ».

**Correction proposée.** Deux chaînes : journal_ligne (FR « %1$s : %2$s », EN « %1$s: %2$s ») et journal_humeur_n (FR « Humeur %1$d sur 5 », EN « Mood %1$d of 5 »).

### FDONNEES-28 — 25 chaînes du périmètre ne sont plus utilisées nulle part, mais restent traduites en trois langues

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Vingt-cinq clés des trophées, paliers, parcours, anneaux et widget n'ont aucune référence ni dans le code Android, ni dans le site, ni dans Nokia : restes de l'écran « Mes paliers » et de l'ancien système à métaux par famille. Certaines décrivent un fonctionnement qui n'existe plus (trophees_explication : « Chaque trophée monte de niveau en niveau, du bronze à l'argent… »). Soit 75 textes morts à maintenir.

**Preuve.** Recherche de R.string/R.plurals/@string et des clés entre guillemets dans android/app/src, web/src, web/tools, nokia/src : 0 occurrence pour paliers_title, paliers_sous_titre, palier_prochain, palier_atteints, trophees_titre, trophees_prochain, trophees_gagnes, trophees_a_venir, trophees_aucun_gagne, trophees_compte, trophee_niveau, trophees_explication, trophee_a_venir, trophee_prochain, trophee_sommet, trophee_vedette, trophee_vedette_aucune, trophee_a_gagner, parcours_moyenne, parcours_jours, widget_resume, ring_day, ring_week, ring_streak, action_journal.

**Correction proposée.** Supprimer ces 25 clés des trois fichiers strings.xml.

### FDONNEES-29 — Jour exempté : trois noms en français, trois en anglais ; le widget dit « Série à relancer » à qui n'a jamais commencé

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le même état s'appelle « Jour sans obligation » (barrière), « Pause aujourd'hui » (réglages) et « Repos aujourd'hui. » (widget) ; en anglais « Rest day », « Rest day today », « Not expected today. ». L'indice de la pause cite « un Yom Tov » alors que les Yom Tov sont déjà exemptés par l'interrupteur du dessus. La description de la pastille du widget dit « Série à relancer » dès que la série vaut 0, même pour un nouvel utilisateur, ce que l'accueil évite expressément. En anglais, « To win », « To earn » et « Earned » se côtoient pour gagner un trophée.

**Preuve.** Chaînes gate_exempt_title, settings_exempt_today, widget_rest, settings_exempt_today_hint « Pour un Yom Tov, un voyage, une maladie : la journée ne compte pas contre vous. » ; StreakWidget.kt:321 « if (etat.streak == 0) context.getString(R.string.status_streak_none) » ; MainActivity.kt:784-788 « « Série à relancer » ne se dit qu'à qui en a déjà eu une ».

**Correction proposée.** Un seul terme : FR « Jour de pause » / « Pause aujourd'hui » partout ; EN « Rest day » / « Rest day today ». settings_exempt_today_hint FR : « Pour un voyage, une maladie, un jour empêché : la journée ne compte pas contre vous. » EN : « For a trip, illness or a day you cannot manage: the day does not count against you. » Widget : status_streak_first quand Store.aDejaPratique est faux.
