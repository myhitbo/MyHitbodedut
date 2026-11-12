# FBARRIERE — Android — la barrière du matin, rappels, autorisations

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

25 constats — confirmés : 7 · confirmés en partie : 3 · non contre-expertisés (mineurs et cosmétiques) : 15.

## Ce qui a été examiné

Lu en entier (dossier android/app/src/main/java/com/myhitbodedut) : GateStatus, GateService, BlockerView, BootReceiver, AppPickerActivity, Autorisation, Permissions, Divulgation, NePasDeranger, PratiqueCalme, Holidays, ChabbatAlerte, Reminder, ReminderRule, RemindersActivity, Notifications, MyHitbodedutApp, SessionService, SessionRule, Onboarding ; les quatre manifestes (main, full, light, debug), app/build.gradle.kts, res/layout/view_blocker.xml ; tests DivulgationTest, Fiabilite2Test, HolidaysTest, VoyageNuitTest, ChabbatAlerteTest.
Lu par extraits : Store.kt (environ 650 lignes sur 1 641 : journées, addSession, fenetreFaite, jours exemptés, série, fenêtre, report, rappels, séance, export et import), SettingsActivity (l.40-440 et 505-631), MainActivity (quatre extraits, environ 250 lignes sur 1 022), SessionActivity, MusicPlayer, OnboardingActivity, Barres, Apparence, ChoixLieu, VolAlerte, LevanaAlerte, FiabiliteTest, ReminderRuleTest, la structure de activity_settings.xml.
Documents : PUBLICATION_PLAY_STORE.md § 1 à 2.1, § 4, § 6 à 11 et plan de repli en entier ; README (sections Android, autorisations, installation, limites connues) ; FEUILLE_DE_ROUTE (proposition 12, « Ce qui manque », 19/10, 04/11, sujets ouverts) ; la section barrière de web/src/confidentialite.html.
Traductions : présence des 1 222 clés vérifiée par script dans les trois fichiers strings.xml (0 manquante en anglais et en hébreu hors 45 non traduisibles) ; environ 150 chaînes de la barrière, des rappels, des autorisations et de la présentation comparées une à une en français et en anglais ; l'hébreu seulement survolé.
Web (faits extérieurs, sans nom de projet) : changements de comportement d'Android 15 (focus audio, SYSTEM_ALERT_WINDOW, Ne pas déranger), restrictions de démarrage des services en arrière-plan, annonce de politique Play du 29/10/2026 et sa page d'aperçu.
Non examiné : rien n'a été exécuté, ni compilation, ni tests unitaires, ni émulateur ; tous les comportements Android sont déduits du code et de la documentation officielle, et les constats qui en dépendent portent une confiance moyenne ou le disent dans la preuve. Versions web et Nokia hors de cette dimension. Scripts de travail dans OUT/fbarriere ; aucun fichier du dépôt ni des deux sites n'a été modifié.

## Ce qui tient

- Divulgation avant chaque accès spécial : un seul chemin vers les deux écrans Android, « Pas maintenant » n'ouvre rien, et DivulgationTest échoue si un appel la contourne ou si l'un des mots attendus manque dans l'une des trois langues.
- Choix qui réduisent le risque Play, tenus dans le code : ni AccessibilityService, ni QUERY_ALL_PACKAGES (élément &lt;queries> limité aux applications lançables), ni alarme exacte ; les deux permissions sensibles et le service de la barrière ne sont déclarés que dans le manifeste de l'édition complète.
- Reprises bien pensées : BootReceiver couvre redémarrage, mise à jour, changement d'heure et de fuseau (quatre cas qu'Android exempte des restrictions de démarrage en arrière-plan), filtre les actions reçues, et le démarrage de séance depuis l'écran de garde est protégé par runCatching.
- Rappels : règle pure et testée (heure d'été, heure inexistante, veille, plusieurs heures), une seule alarme reprogrammée, bouton « Commencer » qui ouvre l'écran directement (contrainte d'Android 12), notifications coupées détectées sur toutes les versions et signalées à l'écran.
- GateStatus donne une raison explicite à chaque état inactif, avec des pluriels corrects dans les trois langues (duel hébreu compris) ; toutes les chaînes de la barrière, des rappels et des autorisations sont traduites, sans texte en dur.
- Chabbat et Yom Tov par le calendrier hébraïque (KosherJava), deuxième jour de diaspora distingué d'Israël, vérifié par des tests sur Tichri 5787 ; la fenêtre qui passe minuit a sa règle et ses tests pour « déjà faite ».

## Constats

### FBARRIERE-01 — Barrière affichée « veille » alors que le service n'a jamais été lancé

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** Si l'on active la barrière avant d'avoir accordé les deux accès spéciaux (ordre naturel quand on part de la pastille « Avec Hachem » de l'accueil), le service n'est pas lancé à ce moment-là, faute d'autorisations. Au retour des écrans Android, l'écran des réglages se contente de se redessiner : la carte « État du mode » passe à « Je suis avec Hachem veille, N applications sont bloquées », mais rien n'appelle GateService.start. Quitter les réglages par le bouton Accueil laisse la barrière inerte (ni notification, ni écran de garde) jusqu'à la prochaine ouverture de l'accueil de l'application, un redémarrage ou un changement d'heure. Plus largement, GateStatus ignore si le service tourne : après un arrêt par le système, une surcouche constructeur ou le gestionnaire de tâches, l'état affiché reste « veille ».

**Preuve.** android/app/src/main/java/com/myhitbodedut/SettingsActivity.kt:74-77 « override fun onResume() { super.onResume() ; refresh() } » ; seul l'interrupteur touche au service, l.312-316 « Store.setEnabled(this, checked) … applyServiceState() » ; android/app/src/main/java/com/myhitbodedut/MainActivity.kt:128-133 est le seul onResume qui appelle « applyServiceState() » ; android/app/src/main/java/com/myhitbodedut/GateStatus.kt:25-34 : evaluate() ne teste que réglages et autorisations, jamais la vie du service.

**Correction proposée.** Appeler applyServiceState() dans SettingsActivity.onResume. Ajouter à GateService un drapeau « enMarche » (comme SessionService.enMarche) et, dans GateStatus, un état distinct quand tout est réglé mais que le service ne tourne pas, avec relance au toucher.

**Note du contre-expert.** Vérifié dans le code : SettingsActivity.onResume (l.74-77) ne fait que refresh(), et GateService.start n'est appelé que par applyServiceState (interrupteur l.312-316, import l.590, MainActivity l.31/133/190) et par BootReceiver ; GateStatus.evaluate ne regarde jamais si le service vit, donc la carte passe bien à « veille » sans lancement. Le cas est d'autant plus courant que la carte de l'interrupteur (activity_settings.xml l.253) précède celle des autorisations (l.475), et qu'en quittant par Accueil la tâche garde SettingsActivity au sommet : MainActivity.onResume n'est pas rejoué à la réouverture.

### FBARRIERE-02 — L'écran de garde empêche l'écran du téléphone de s'éteindre

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** La fenêtre de l'écran de garde porte FLAG_KEEP_SCREEN_ON. Tant qu'elle est affichée, le téléphone ne se met plus en veille de lui-même. Cas central du produit : on ouvre une application bloquée, l'écran « Avez-vous fait votre hitbodedout ? » apparaît, on pose le téléphone pour aller la faire sans rien toucher ; l'écran reste allumé jusqu'à la fin de la fenêtre (06:00–11:00 par défaut, soit jusqu'à cinq heures) ou, en mode « Hitbodedout en cours », jusqu'à la fin de la séance. Aucun commentaire ne justifie ce drapeau.

**Preuve.** android/app/src/main/java/com/myhitbodedut/GateService.kt:158-161 « WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS » ; la vue n'est retirée que par evaluate() (l.93-97) quand l'application au premier plan change ou que la barrière n'est plus armée.

**Correction proposée.** Retirer FLAG_KEEP_SCREEN_ON des paramètres de la fenêtre (GateService.kt:159).

**Note du contre-expert.** Le drapeau est bien posé sur la fenêtre de l'écran de garde (GateService.kt l.159), sans commentaire ni mention dans la feuille de route, et la vue ne part que par evaluate() ou un bouton ; FLAG_KEEP_SCREEN_ON vaut pour toute fenêtre visible, TYPE_APPLICATION_OVERLAY compris. Nuance : il faut laisser l'écran affiché sans toucher ni un bouton, ni Accueil, ni marche/arrêt, donc « cas central » est un peu fort, mais un téléphone qui reste allumé et déverrouillé jusqu'à la fin de la fenêtre (ou sans limite pendant une séance sans durée) justifie « majeur ».

### FBARRIERE-03 — « Ne pas déranger » peut rester actif après la séance

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** Le réglage promet « puis revient comme avant » ; quatre chemins laissent le téléphone en mode « priorité ». (a) Séance interrompue par la mort du processus ou un redémarrage, puis échue : reconcilier() la clôt sans rétablir le mode. (b) « Tout effacer » pendant une séance : le service est arrêté sans rétablir, puis les préférences, dont le mode d'avant, sont effacées. (c) Android 15 et plus (targetSdk 36) : setInterruptionFilter n'agit plus sur l'état global, il active une règle propre à l'application, que seul INTERRUPTION_FILTER_ALL désactive ; retablir() repose la valeur lue avant la séance : si « Ne pas déranger » était déjà actif au début (mode coucher à l'aube, par exemple), la règle de l'application reste active après la séance et chaque séance suivante la reconduit. (d) Une séance sans durée oubliée ne se clôt jamais tant que le service vit, donc le mode reste posé.

**Preuve.** android/app/src/main/java/com/myhitbodedut/SessionService.kt:425-429 « if (echue) { val theme = Store.sessionTheme(context) ; val close = Store.endSession(context) ; if (close.minutes > 0) inscrire(context, close, theme) ; StreakWidget.refresh(context) } » : aucun NePasDeranger.retablir, dont le seul appel est l.307 (stopSelfAndClear) ; onDestroy l.138-145 ne rétablit rien ; SettingsActivity.kt:185-189 « stopService(Intent(this, SessionService::class.java)) … Store.reinitialiser(this) » ; NePasDeranger.kt:24-25 « Store.setFiltreAvantSeance(context, nm.currentInterruptionFilter) » puis l.31 « nm(context).setInterruptionFilter(avant) » ; SessionRule.kt:50-51 « if (estOuverte(debutMillis, duree)) true » ; values/strings.xml:1086 « puis revient comme avant ». Règle Android 15 relue le 12/11/2026 (developer.android.com, behavior-changes-15, « Changes to when apps can modify the global state of Do Not Disturb mode »). Chemins a, b, d lus dans le code ; chemin c déduit de la règle, non exécuté.

**Correction proposée (revue par le contre-expert).** Comme proposé, avec une précision : à partir d'Android 15 (SDK_INT ≥ 35), garder tout de même un témoin « c'est l'application qui a posé le mode » à la place du filtre d'avant, pour que retablir() sache qu'il doit appeler setInterruptionFilter(INTERRUPTION_FILTER_ALL) ; avant Android 15, continuer de reposer le filtre mémorisé. Appeler retablir() dans reconcilier(), dans SessionService.onDestroy et avant Store.reinitialiser ; clore dans le service la séance sans durée arrivée à 240 min.

**Note du contre-expert.** Chemins a et b lus dans le code : reconcilier() (SessionService l.425-429) clôt sans retablir(), et « Tout effacer » (SettingsActivity l.185-189) arrête le service, dont onDestroy ne rétablit rien, puis efface le mode mémorisé. Chemin c confirmé par la page behavior-changes-15 relue aujourd'hui (règle implicite que seul INTERRUPTION_FILTER_ALL désactive), mais non exécuté ; c'est le plus courant (mode coucher encore actif au début d'une séance du matin). Chemin d réel mais plus discutable : la séance sans durée est encore « en cours », seul le commentaire de PLAFOND_OUVERTE dit qu'elle s'arrête à 240 min.

### FBARRIERE-04 — La divulgation, la déclaration Play et les règles de confidentialité taisent le blocage pendant toute séance

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : play · **Type** : texte

**Constat.** Les deux fenêtres de divulgation, la page de confidentialité, le sous-type du service et le texte du § 6.6 disent que l'écran s'affiche et que l'application au premier plan est lue « pendant la plage horaire … tant que la pratique du jour n'est pas faite ». Le code lit aussi les données d'utilisation et pose l'écran pendant toute séance en cours, à n'importe quelle heure, y compris hors fenêtre, un jour de Chabbat ou de pause, et après validation de la journée. Un examinateur qui lance une séance à 15 h et ouvre une application choisie voit un comportement que la divulgation n'annonce pas. Même contradiction dans « Plus rien ne sera retenu aujourd'hui » (gate_done_detail). Les chaînes existent bien dans les trois langues ; c'est leur contenu qui est incomplet.

**Preuve.** android/app/src/main/java/com/myhitbodedut/GateService.kt:81-82 « val running = Store.isSessionRunning(this) ; val armed = GateStatus.isArmed(this) || (running && GateStatus.shouldRunService(this)) » ; android/app/src/main/res/values/strings.xml:1419 et 1421 (divulgation_overlay_texte, divulgation_usage_texte : « Pendant la plage horaire que vous avez fixée, et tant que la pratique du jour n’est pas faite ») ; values-en/strings.xml:1354 et 1356 ; android/app/src/full/AndroidManifest.xml:44 « during a user-defined morning window, until the user confirms their daily practice » ; PUBLICATION_PLAY_STORE.md:416 ; web/src/confidentialite.html:83 et 142.

**Correction proposée (revue par le contre-expert).** Textes français et anglais proposés : corrects. Hébreu, à accorder au futur de la phrase voisine (« יופיע ») et plus naturel : « הוא יופיע לפניהן גם במהלך כל התבודדות שהתחלתם, בכל שעה, עד שתסתיים. » / « היא בודקת זאת גם במהלך כל התבודדות שהתחלתם, בכל שעה. » Ajouter la phrase aux trois langues de web/src/confidentialite.html (l.83, 142, 201), au sous-type du manifeste et au § 6.6 comme proposé, et revoir gate_done_detail (« Plus rien ne sera retenu aujourd’hui »).

**Note du contre-expert.** Vérifié : GateService.evaluate (l.81-82) arme l'écran et lit les événements d'utilisation pendant toute séance dès que le mode est activé et autorisé, quelle que soit l'heure ; les deux divulgations (fr l.1419/1421, en l.1354/1356, iw l.1390/1392), le sous-type du manifeste (full l.44), le § 6.6 (l.416) et la page de confidentialité dans ses trois langues (l.83, 142, 201) ne parlent que de la plage horaire tant que la pratique n'est pas faite. Aucune autre chaîne de l'application n'annonce ce blocage pendant la séance.

### FBARRIERE-05 — Aucune application protégée : « Tout sélectionner » bloque aussi le Téléphone, l'Horloge et les Réglages

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : android · **Type** : fonction

**Constat.** La liste propose toutes les applications lançables sauf MyHitbodedut, et « Tout sélectionner » les coche d'un geste, sans exclusion ni avertissement : Téléphone, Messages, Horloge, Réglages, voire un lanceur tiers qui expose une icône. Le service bloque tout paquet de la liste sans exception. Pendant une séance en cours, l'écran posé sur le Téléphone n'offre qu'une issue, « Revenir à la hitbodedout » ; le bouton retour est avalé. Pour passer un appel urgent, il faut revenir dans l'application, toucher une première fois pour réveiller l'écran calme, toucher « Terminer », confirmer, puis rouvrir le Téléphone, et si la séance a duré moins d'une minute, répondre encore à l'écran « Avez-vous fait… », qui renvoie à l'accueil du téléphone. L'écran d'appel d'un Téléphone ainsi choisi est couvert de la même façon.

**Preuve.** android/app/src/main/java/com/myhitbodedut/AppPickerActivity.kt:39-41 « selected.clear() ; entries.forEach { selected.add(it.packageName) } » et l.70-73 (seul filtre : « .filter { it.packageName != packageName } ») ; GateService.kt:89-91 « current != packageName && Store.blockedApps(this).contains(current) » ; BlockerView.kt:115-118 « primary.setText(R.string.blocker_back_to_session) … secondary.visibility = View.GONE ; snooze.visibility = View.GONE » et l.134-138 (retour avalé) ; SessionService.kt:189 « if (close.minutes > 0 || !early) ».

**Correction proposée (revue par le contre-expert).** Exclure de la liste et de « Tout sélectionner » le composeur par défaut (TelecomManager.getDefaultDialerPackage), l'application d'accueil par défaut et les Réglages, et ne jamais poser l'écran sur le composeur par défaut même s'il figure dans une liste importée ; à défaut, avertir au moment de « Tout sélectionner ». Ne pas ajouter de bouton « Terminer » à l'écran de garde sans décision du propriétaire (issue unique voulue) : rappeler plutôt sur cet écran que la notification de la séance permet de la terminer.

**Note du contre-expert.** Les faits sont exacts (AppPickerActivity l.39-41 et 70-73, GateService l.89-91, BlockerView l.115-118 et 134-138 ; aucun avertissement dans activity_apps.xml). Deux corrections : l'issue décrite pour un appel urgent est exagérée, car la notification de séance porte l'action « Terminer maintenant » (SessionService l.371-377) accessible depuis le volet, et l'appel d'urgence de l'écran verrouillé n'est pas une application de la liste ; le recouvrement de l'écran d'appel est déduit du code, non essayé sur appareil. Le bouton « Terminer » demandé sur l'écran de garde contredit un choix écrit (« la seule issue est d'y retourner », BlockerMode et README l.26-27).

### FBARRIERE-08 — Accueil : « Avec Hachem : activée » alors que rien n'agit, et la barrière absente de la présentation

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** Le seul accès à la barrière depuis l'accueil est une pastille qui bascule le réglage d'un toucher, sans confirmation, et affiche « activée » ou « désactivée » d'après ce seul réglage. Sans autorisation accordée ni application choisie, elle affiche « activée » alors que la barrière ne fait rien ; aucune ligne de l'accueil ne dit ce qui manque (le diagnostic est dans les Réglages, quatrième carte). Les sept écrans de présentation du premier lancement ne mentionnent pas la barrière, présentée ailleurs comme le cœur du produit. Un second toucher par mégarde la coupe sans avertir.

**Preuve.** android/app/src/main/java/com/myhitbodedut/MainActivity.kt:186-191 « Store.setEnabled(this, !Store.isEnabled(this)) ; applyServiceState() ; refresh() » et l.371-373 « if (Store.isEnabled(this)) R.string.start_focus_on else R.string.start_focus_off » ; l.19 commentaire périmé « diagnostic de la barrière » (GateStatus n'apparaît qu'en l.920) ; Onboarding.kt:46-91 : pratique, seance, jours, textes, reglages, adresse, prive ; values/strings.xml:504-507.

**Correction proposée (revue par le contre-expert).** Comme proposé, avec un libellé corrigé et l'hébreu manquant. Valeur de la pastille quand il manque une autorisation ou une application : FR « à régler », EN « needs setup » (« set up » se lit aussi « déjà réglée »), HE « נדרשת הגדרה » ; le toucher ouvre alors les Réglages sur la carte au lieu de basculer. Écran de présentation, édition complète seulement ; textes français et anglais proposés corrects ; hébreu : « מחסום הבוקר » / « אם תרצו, האפליקציות שתבחרו ימתינו להתבודדות שלכם: בשעות שתקבעו, מסך ישאל קודם אם היא כבר נעשתה. מפעילים בהגדרות, ואפשר לכבות בכל רגע. »

**Note du contre-expert.** Vérifié : la pastille (MainActivity l.186-191 et 371-373) bascule et s'affiche d'après Store.isEnabled seul, sans demande d'autorisation ni renvoi vers les réglages ; MainActivity ne se sert de GateStatus que pour lancer le service (l.920), et aucun des sept écrans d'Onboarding.ECRANS ne parle de la barrière. Le retrait de la pastille d'alerte sur l'onglet Réglages est une demande du propriétaire (feuille de route, 07/10), ce qui ne justifie pas d'afficher « activée » quand rien n'agit ; l'ajout d'un écran de présentation reste une proposition, pas un défaut.

### FBARRIERE-09 — § 6.7 : « pas de déclaration » pour la position exacte, contredit par la règle Play annoncée le 29/10/2026

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : play · **Type** : texte

**Constat.** Le cahier de publication affirme que ACCESS_FINE_LOCATION ne demande aucune déclaration. La règle Play « Permissions and APIs that Access Sensitive Information », annoncée en avril et précisée le 29/10/2026 (le jour même où le cahier dit avoir lu ses sources), impose à compter du 27/01/2027 une déclaration dans la Play Console justifiant pourquoi la position approximative ne suffit pas. Le calendrier du cahier (cinq à sept semaines) mène à cette date. La même annonce exige depuis novembre 2026 la déclaration du statut de commerçant (trader status) dans la Play Console, absente du § 4.

**Preuve.** PUBLICATION_PLAY_STORE.md:429 « | `ACCESS_FINE_LOCATION` | pas de déclaration (premier plan seulement) ; la position exacte doit se justifier quand l'approximative suffirait | » ; aucune occurrence de « trader » ni de « 27/01 » dans le fichier. Sources lues le 12/11/2026 : support.google.com/googleplay/android-developer/answer/18100766 (« Apps using ACCESS_FINE_LOCATION must complete a Play Console declaration to justify why coarse location or the location button is insufficient » ; « Starting in November 2026, you must declare your trader status ») et answer/16909972 (« Effective January 27, 2027 »).

**Correction proposée (revue par le contre-expert).** Cellule : « déclaration Play Console exigée à compter du 27/01/2027 (règle annoncée en avril 2026, précisée le 29/10/2026) : justifier pourquoi ni la position approximative ni le bouton de position d'Android ne suffisent ». Noter aussi que pour une application ciblant Android 17 (API 37), une demande ponctuelle au toucher, comme le GPS en vol, devra passer par ce bouton de position. Le reste comme proposé : ligne « Statut de commerçant : à déclarer dans la Play Console (exigé depuis novembre 2026) » au § 4, et les deux pages ajoutées aux sources.

**Note du contre-expert.** La ligne 429 du cahier se lit telle que citée, et le fichier ne contient ni « trader », ni « commerçant », ni « 27/01 ». Les deux pages Google relues aujourd'hui (answer/18100766 et answer/16909972) disent bien : déclaration Play Console pour ACCESS_FINE_LOCATION, obligatoire le 27/01/2027 (règle annoncée en avril, précisée le 29/10/2026), et statut de commerçant à déclarer à partir de novembre 2026.

### FBARRIERE-10 — Note aux examinateurs : un chemin qui n'existe pas ; README périmé sur cinq points de la barrière

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : docs · **Type** : texte

**Constat.** La note du § 7.3 envoie l'examinateur vers « Accueil → autorisations → choisir une application → bouton » : l'accueil n'a ni autorisations ni bouton d'aperçu, tout est dans l'onglet Réglages. Un examinateur qui ne trouve pas la fonction déclarée est un motif de refus classique. Le README décrit par ailleurs un état ancien : durée par défaut « soixante minutes » (c'est 15) ; « validée par le temps réellement passé, pas par une simple déclaration » (deux boutons déclarent sans séance) ; « l'écran principal affiche en permanence l'état de la barrière » et « contient la liste et un bouton vers chaque écran système » (c'est l'écran des réglages) ; « la détection se fait par le jour de la semaine » (c'est le calendrier hébraïque, Yom Tov compris, Israël ou diaspora).

**Preuve.** PUBLICATION_PLAY_STORE.md:504-508 « Accueil → autorisations (affichage par-dessus les autres applications, accès aux données d'utilisation) → choisir une application → bouton » ; android/app/src/main/res/layout/activity_settings.xml:216-249 (card_gate_state, preview_gate) et 475-487 (card_permissions) ; README.md:23-24, 31-32, 38-40, 131-132 ; Store.kt:174 « const val DEFAULT_TARGET = 15 » ; GateService.kt:139 « Store.addSession(this, 0) » ; Holidays.kt:20-21 « isAssurBemelacha ».

**Correction proposée.** Note, en anglais : « No account is needed. To see the gate: “Settings” tab (bottom bar) → “Mode status” card → “Preview the “I am with Hashem” screen now”. A dialog explains the access; “Continue” opens Android’s “Display over other apps” setting; come back and tap the button again: the screen shows at any time, with no effect. To turn the gate on for real: “Required permissions” card → “Grant” (display over other apps, usage access); “I am with Hashem” card → switch on, “Choose apps”; then open a chosen app during the “Mode hours”. The gate is a self-discipline tool the user sets up and can switch off at any time. No usage data leaves the device. » README : « par défaut quinze minutes » ; « validée par une séance ou par une déclaration » ; « l'écran des réglages affiche… » ; « Chabbat et Yom Tov d'après le calendrier hébraïque, par date civile ».

**Note du contre-expert.** Le § 7.3 se lit tel que cité (l.504-508) alors que MainActivity n'a ni liste d'autorisations ni bouton d'aperçu : preview_gate et card_permissions sont dans activity_settings.xml, ouvert par l'onglet Réglages. Les libellés anglais de la note proposée correspondent tous à values-en (Settings, Mode status, Preview the “I am with Hashem” screen now, Continue, Required permissions, Grant, Choose apps, Mode hours). Les cinq points du README sont périmés comme décrit (DEFAULT_TARGET = 15, déclaration par addSession(…, 0), diagnostic et autorisations dans les réglages, Holidays.isRestDay par KosherJava) ; seuls, ils seraient mineurs : c'est la note aux examinateurs qui porte la gravité.

### FBARRIERE-06 — Relance du service par Android : startForeground sans garde, plantage probable sous Android 15 et 16

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : android · **Type** : fonction

**Constat.** GateService rend START_STICKY et appelle startForeground sans try/catch dès onStartCommand. Quand Android tue le processus puis relance le service, l'application est en arrière-plan. Jusqu'à Android 14, détenir SYSTEM_ALERT_WINDOW suffisait à l'en exempter ; pour une application qui cible Android 15 ou plus (ici 36), il faut en plus une fenêtre par-dessus visible à cet instant, ce qui n'est pas le cas. La seule autre exemption est la batterie sans restriction, que la barrière n'exige pas et dont le texte ne parle que du rappel. Sans elle, startForeground lève ForegroundServiceStartNotAllowedException, non rattrapée : plantage, puis barrière morte jusqu'à la prochaine ouverture de l'application. SessionService prend déjà cette précaution pour son propre démarrage (« on ne parie pas dessus »).

**Preuve.** android/app/src/main/java/com/myhitbodedut/GateService.kt:56-57 « override fun onStartCommand(…): Int { startInForeground() », l.64 « return START_STICKY », l.219-220 « startForeground(Notifications.ID_GATE, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE) » ; Permissions.kt:88-89 « canDrawOverlays(context) && hasUsageAccess(context) » (batterie absente) ; values/strings.xml:123 « Sans elle, Android peut retarder le rappel de plusieurs heures ». Pages Android relues le 12/11/2026 : restrictions-bg-start (« the app must currently have a visible overlay window ») et behavior-changes-15. Non exécuté sur appareil.

**Correction proposée (revue par le contre-expert).** Entourer startInForeground() d'un runCatching/try-catch (c'est le conseil de Google dans l'issue 307329994 : attraper ForegroundServiceStartNotAllowedException puis stopSelf()), et relancer le service à la prochaine ouverture ou prévenir par une notification ordinaire. Ne pas rendre la batterie sans restriction obligatoire pour la barrière sur cette base : rien n'établit qu'elle évite ce plantage. Si l'on veut dire qu'elle protège aussi la surveillance (le README le dit déjà), il faut une chaîne propre à l'édition complète, permission_battery_why servant aussi à l'édition légère, et dans les trois langues. FR : « Sans elle, Android peut arrêter la surveillance du mode « Je suis avec Hachem » et retarder le rappel de plusieurs heures. » EN : « Without it, Android may shut down the “I am with Hashem” mode in the background and hold the reminder back for hours. » HE : « בלעדיה אנדרואיד עלול להפסיק את פעולת מצב „אני עם השם” ברקע ולעכב את התזכורת בשעות. »

**Note du contre-expert.** Le code est bien tel que cité (START_STICKY l.64, startForeground sans garde l.217-224, batterie absente de allGranted) et les deux règles Android relues sont exactes, mais elles ne s'appliquent pas à ce cas : le Javadoc de START_STICKY et l'ingénieur de Google (Issue Tracker 307329994, commentaire 100) disent que la restriction ne touche pas la relance d'un service collant, qui n'a donc besoin d'aucune exemption. Le plantage à la relance existe pourtant en pratique sur Android 12 à 15 (issues 295196436 et 307329994, fermées « Won't Fix », difficile à reproduire, signalé même batterie sans restriction) : risque réel mais occasionnel, non « probable », et non essayé ici sur appareil.

### FBARRIERE-07 — Fenêtre de nuit : jour exempté, pause et série restent au jour civil et basculent à minuit en pleine fenêtre

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : android · **Type** : fonction

**Constat.** Depuis le 02/11, une fenêtre qui passe minuit (21:00–02:00, cas testé) « appartient au soir où elle commence » pour savoir si elle est honorée. Le reste de la décision est resté au jour civil. Vendredi 21:00–24:00 : barrière armée, Chabbat déjà entré ; samedi 00:00–02:00 : exemptée. Samedi 21:00–24:00 : exemptée ; dimanche 00:00 : elle s'arme d'un coup pour deux heures, au milieu de la même nuit. « Pause aujourd'hui » cochée à 22 h cesse à minuit. Une séance ou un « Je l'ai déjà faite » à 0 h 30 est inscrit au nouveau jour civil : qui alterne 22 h un soir et 0 h 30 le lendemain a honoré chaque nuit selon la barrière, mais garde un jour vide au journal et perd sa série.

**Preuve.** android/app/src/main/java/com/myhitbodedut/GateStatus.kt:30 « Store.isExempt(context, LocalDate.now()) -> GateState.EXEMPT_DAY » ; Store.kt:362-363 « val jour = if (minutes < end) maintenant.toLocalDate().minusDays(1) else maintenant.toLocalDate() » (règle appliquée à fenetreFaite seulement) ; SettingsActivity.kt:341-342 « Store.togglePausedDate(this, Store.today()) » ; GateService.kt:139 « Store.addSession(this, 0) » (date = today()) ; Store.kt:643-659 (série au jour civil). android/app/src/test/java/com/myhitbodedut/VoyageNuitTest.kt ne couvre que fenetreFaite.

**Correction proposée (revue par le contre-expert).** Calculer une fois le « jour de la fenêtre » (règle de fenetreFaite) et l'appliquer à la pause : « Pause aujourd’hui » couvre la fenêtre en cours jusqu'à sa fin. Ne pas l'appliquer tel quel à Chabbat et Yom Tov : la barrière serait armée toute la nuit du vendredi et exemptée toute celle du samedi ; exempter plutôt la fenêtre de nuit dont le soir est une veille de jour chômé (Store.isEveOfRestDay, déjà utilisé par Reminder) et, si un lieu de zmanim est réglé, borner par l'allumage et la sortie des étoiles ; sans lieu, garder la règle actuelle. La date inscrite au journal après minuit relève de la règle du 29/09 : la soumettre au propriétaire plutôt que la changer d'office.

**Note du contre-expert.** Les lectures de code sont exactes (GateStatus l.30, Store l.362-363, 631-634 et 643-659, SettingsActivity l.341-342, GateService l.139) et le basculement à minuit est réel. Mais la détection de Chabbat par date civile est une limite écrite (README l.38-40 : « exact pour une fenêtre située le matin »), l'inscription au jour civil du début est une décision commentée (Store.addSession, revue du 29/09), et la veille reste déclarable depuis l'accueil (MainActivity l.251-273), ce qui tempère « perd sa série ». Tout ne touche qu'une fenêtre non par défaut qui passe minuit : mineur ; seule la pause qui cesse à minuit est un défaut neuf.

### FBARRIERE-11 — « Je l'ai déjà faite » : journée inscrite à 0 minute, vignette et rappel non mis à jour

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Sur l'écran de garde, « Je l'ai déjà faite » valide la journée avec 0 minute, sans rien demander. Le même geste depuis l'accueil (« Je l'ai faite sans le téléphone ») demande le jour et la durée, rafraîchit la vignette de série et déclenche la célébration. Ici : anneau du jour vide alors que la journée est « validée », minutes réelles perdues pour les totaux, vignette de l'écran d'accueil du téléphone inchangée jusqu'à minuit ou la prochaine ouverture, et la notification de rappel reste dans le volet (elle n'est retirée que si minutes > 0).

**Preuve.** android/app/src/main/java/com/myhitbodedut/GateService.kt:138-142 « onAlreadyDone = { Store.addSession(this, 0) ; hideOverlay() ; goHome() } » ; Store.kt:321 « if (minutes > 0) runCatching { …cancel(Notifications.ID_REMINDER) } » ; MainActivity.kt:277-285 « DureeSeance.choisir(this, R.string.offline_how_long) { minutes -> Store.addSession(this, minutes, theme = null, date = date) … StreakWidget.refresh(this) » .

**Correction proposée.** Après « Je l'ai déjà faite », ouvrir l'application sur le même choix de durée que « Je l'ai faite sans le téléphone » ; à défaut, appeler StreakWidget.refresh et retirer la notification de rappel aussi pour 0 minute.

### FBARRIERE-12 — Chabbat et veille décidés par date civile alors que le lieu des zmanim existe ; rappel coupé dès midi sans le dire

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction · déjà connu ou choix assumé

**Constat.** Choix documenté, devenu critiquable. Le README le justifiait par l'absence de localisation ; depuis le 10/10 l'application connaît un lieu et calcule l'allumage (l'alerte « Chabbat dans 3 h » s'en sert). La règle du rappel accepte une heure de coucher du soleil, et un test le prouve, mais le receveur lui passe toujours null avec un commentaire devenu faux : tout rappel du vendredi et des veilles de fête après 12:00 est supprimé, même en juin quand Chabbat entre vers 21 h, un jour qui compte pourtant pour la série. L'écran des rappels ne le dit pas.

**Preuve.** android/app/src/main/java/com/myhitbodedut/Reminder.kt:126-127 « // Aucune ville n'est réglée : on s'en tient à la limite de midi. sunsetMinutes = null » ; ReminderRule.kt:17 « const val NO_SUNSET_CUTOFF_MINUTES = 12 * 60 » ; ChabbatAlerte.kt:53-55 « val lieu = Store.lieuAlertes(context) … Zmanim.allumage(lieu, d, minutes) » ; android/app/src/test/java/com/myhitbodedut/ReminderRuleTest.kt:59 « veille de fete avec ville, le coucher du soleil fait foi » ; values/strings.xml:454 ; README.md:40-42.

**Correction proposée.** Dans ReminderReceiver, passer l'heure d'allumage du jour quand Store.lieuAlertes n'est pas null. Sans lieu, le dire. FR : « Une ou plusieurs heures dans la journée. Rien ne sonne un jour de repos, ni la veille à partir de midi, ni une fois la hitbodedout faite. » EN : « One or several times a day. Nothing rings on a rest day, on its eve from noon, or once the hitbodedut is done. »

### FBARRIERE-13 — Alerte « Chabbat dans 3 h » : aucun interrupteur, canal partagé, aucun contrôle du jour ni de l'heure

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Dès qu'un lieu de zmanim est choisi, une notification part chaque vendredi. Aucun réglage ne la coupe (Birkat haLevana et les rappels en vol ont le leur), et elle utilise le canal « Rappels » : la couper dans Android coupe aussi le rappel de hitbodedout et la fin de séance. Le receveur l'affiche sans rien vérifier : un vendredi de Yom Tov, alors que le rappel se tait ces jours-là ; en retard si l'alarme inexacte a été retenue, avec un texte toujours « dans 3 h » ; et la veille d'un Kippour tombant Chabbat (29/09/2028, 26/09/2031) avec « double repas ».

**Preuve.** android/app/src/main/java/com/myhitbodedut/ChabbatAlerte.kt:49-56 (seule condition : « val lieu = Store.lieuAlertes(context) ?: return ») ; l.70 « Notification.Builder(context, Notifications.CHANNEL_REMINDER) » ; l.61-82 : onReceive notifie sans test ; aucune référence à ChabbatAlerte hors BootReceiver.kt:30 et MainActivity.kt:923 ; values/strings.xml:1025 « Double neshama, double simha et double repas ! ». Dates de Kippour calculées par script.

**Correction proposée.** Ajouter un interrupteur « Me prévenir trois heures avant Chabbat » (EN « Remind me three hours before Shabbat ») dans la carte des zmanim. Dans le receveur : ne rien afficher si aujourd'hui est exempté, si l'allumage est passé, ou si demain est Kippour.

### FBARRIERE-14 — Sondage toutes les 900 ms en permanence, avec le journal entier relu deux fois par tour sur le fil principal

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** La boucle tourne jour et nuit dès que le service vit, y compris hors fenêtre, journée faite ou jour exempté. Chaque tour évalue deux fois l'état complet ; chaque évaluation relit et analyse tout le journal JSON (toutes les journées, notes jusqu'à 4 000 caractères), fait quatre appels au système pour les autorisations et construit un calendrier hébraïque. Tout cela sur le fil principal, donc aussi pendant qu'on fait défiler un texte dans l'application. La lecture des événements n'avance que barrière armée : la première du matin couvre tout l'intervalle depuis la veille (environ 19 h d'événements) d'un seul bloc.

**Preuve.** android/app/src/main/java/com/myhitbodedut/GateService.kt:39-43 « evaluate() ; handler.postDelayed(this, POLL_MS) », l.245 « POLL_MS = 900L », l.79 « rafraichirNotification() » puis l.82 « GateStatus.isArmed(this) » (deux evaluate), l.104 « usage.queryEvents(lastQuery - QUERY_OVERLAP_MS, now) » avec lastQuery mis à jour l.114 seulement ; GateStatus.kt:29 « Store.fenetreFaite(context) » ; Store.kt:203-224 : days() fait « JSONObject(raw) » à chaque appel, sans cache.

**Correction proposée.** Évaluer une fois par tour et réutiliser le résultat. Hors état armé et hors séance, reprogrammer le tour à la prochaine échéance utile (début de fenêtre, fin de report, minuit), au plus une fois par minute. Garder en mémoire le « fait aujourd'hui » et l'invalider à l'écriture. Borner la première lecture à quelques minutes en arrière.

### FBARRIERE-15 — Écran de garde sans marges système : boutons sous la barre de navigation, haut sous la barre d'état

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Le traitement des barres du système (Barres.kt) ne s'applique qu'aux activités. L'écran de garde est une fenêtre posée par un service, en plein écran sans limites, avec un simple remplissage de 24 dp. Dès que le contenu dépasse la hauteur (illustration de 190 dp, titre sur deux lignes, carte de 'hizouk, trois boutons : environ 760 dp, soit la hauteur d'un téléphone courant, et davantage avec une police agrandie), le bas défile jusqu'à 24 dp du bord : « Plus tard » se retrouve à moitié sous une barre de navigation à trois boutons (48 dp), et le haut sous la barre d'état. Pas de variante paysage.

**Preuve.** android/app/src/main/java/com/myhitbodedut/GateService.kt:155-163 (MATCH_PARENT, « FLAG_LAYOUT_IN_SCREEN or FLAG_LAYOUT_NO_LIMITS ») ; android/app/src/main/res/layout/view_blocker.xml:2-15 (ScrollView, « android:paddingVertical="24dp" », aucun fitsSystemWindows) ; Barres.kt:32 « fun installer(activity: Activity) », appelé depuis Apparence.kt:159 dans un ActivityLifecycleCallbacks ; un seul fichier res/layout/view_blocker.xml. Estimation de hauteur calculée, non mesurée sur appareil.

**Correction proposée.** Dans BlockerView, poser un écouteur d'insets (ViewCompat.setOnApplyWindowInsetsListener) qui ajoute en marge intérieure les barres du système et la découpe, comme Barres.marges ; retirer FLAG_LAYOUT_NO_LIMITS.

### FBARRIERE-16 — Type mediaPlayback déclaré au manifeste et au § 6.6, jamais demandé par le code

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : play · **Type** : fonction

**Constat.** SessionService déclare les types specialUse et mediaPlayback, la permission FOREGROUND_SERVICE_MEDIA_PLAYBACK est demandée, et le § 6.6 prévoit une déclaration Play avec vidéo pour mediaPlayback. Le code ne démarre jamais le service qu'en specialUse, musique comprise : Android ne voit donc jamais de service de lecture. La déclaration Play porterait sur un type qui ne sert pas, tandis que la musique joue sous un type « usage spécial » dont le sous-type ne parle que du compte à rebours. (La musique fonctionne : Android 15 n'exige qu'un service de premier plan, quel que soit son type, pour obtenir le focus audio.)

**Preuve.** android/app/src/main/AndroidManifest.xml:7 « android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK » et l.368 « android:foregroundServiceType="specialUse|mediaPlayback" » ; android/app/src/main/java/com/myhitbodedut/SessionService.kt:380-381 « startForeground(Notifications.ID_SESSION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE) » (seule occurrence avec GateService.kt:220) ; PUBLICATION_PLAY_STORE.md:415.

**Correction proposée.** Soit passer SPECIAL_USE or MEDIA_PLAYBACK quand la musique est active, sauf à la reprise depuis BootReceiver (Android 15 interdit ce type depuis BOOT_COMPLETED) ; soit retirer le type et la permission du manifeste, et la ligne du § 6.6, en ajoutant la musique au sous-type déclaré.

### FBARRIERE-17 — Fenêtre dont le début égale la fin : jamais active, sans avertissement

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Les deux heures se règlent séparément, sans contrôle. Début = fin (06:00–06:00, que l'on choisirait pour « toute la journée ») donne une barrière qui ne s'arme jamais ; l'état affiche « Le mode agit entre 06:00 et 06:00. En dehors, rien n'est retenu. » sans signaler que la plage est vide.

**Preuve.** android/app/src/main/java/com/myhitbodedut/Store.kt:712-713 « return if (start <= end) minutes >= start && minutes < end else minutes >= start || minutes < end » ; SettingsActivity.kt:137-147 : « Store.setWindow(this, it, Store.windowEnd(this)) » sans vérification.

**Correction proposée.** Traiter début = fin comme « toute la journée », ou refuser le choix avec un message. FR : « Le début et la fin sont identiques : le mode n’agirait jamais. » EN : « Start and end are the same: the mode would never act. »

### FBARRIERE-18 — Applications désinstallées ou importées comptées comme « bloquées » et impossibles à décocher une à une

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** La sélection garde les noms de paquets tels quels. Une application désinstallée, ou venue d'une sauvegarde faite sur un autre téléphone (l'import fusionne les listes), reste dans l'ensemble : elle n'apparaît plus dans la liste, donc ne peut pas être décochée seule, mais elle est comptée dans « N applications bloquées » (réglages, sélecteur, notification) et suffit à faire passer l'état à « veille » alors qu'aucune application présente n'est choisie.

**Preuve.** android/app/src/main/java/com/myhitbodedut/AppPickerActivity.kt:31 « selected.addAll(Store.blockedApps(this)) », l.56 « Store.setBlockedApps(this, selected) », l.60-61 (compte = selected.size) ; Store.kt:1618-1621 « val apps = blockedApps(context).toMutableSet() ; for (i in 0 until array.length()) apps.add(array.optString(i)) » ; GateStatus.kt:28 et 57.

**Correction proposée.** Au chargement de la liste, réduire la sélection aux paquets présents (selected.retainAll(noms trouvés)) ; faire le même filtrage après un import.

### FBARRIERE-19 — Aucun test ne couvre la décision de la barrière

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** La séance, le rappel, le calendrier et la divulgation ont leurs règles pures et leurs tests. La barrière, jamais essayée sur un vrai téléphone, n'en a aucun : ni l'ordre des états de GateStatus.evaluate, ni la condition d'armement pendant une séance, ni le suivi de l'application au premier plan, ni l'écran de garde. Les défauts ci-dessus (jour exempté à minuit, fenêtre vide, état « veille » sans service, ordre report / fenêtre) auraient été pris par des tests de règle.

**Preuve.** Recherche dans android/app/src/test/java/com/myhitbodedut de « GateStatus|GateService|BlockerView|BlockerMode|AppPicker|BootReceiver » : une seule occurrence, TraductionAffichageTest.kt:117 (langue du service). GateStatus.kt:25 « fun evaluate(context: Context) » dépend d'un contexte Android, donc n'est pas testable tel quel.

**Correction proposée.** Extraire une règle pure (GateRule.etat(autorisations, activé, nombre d'apps, fait, exempté, reporté, dans la fenêtre) et GateRule.armee(etat, séance en cours)), sur le modèle de SessionRule et ReminderRule, et la tester : ordre des états, fenêtre de nuit autour de minuit, début = fin, séance en cours.

### FBARRIERE-20 — Contournements propres à l'implémentation, non listés au README

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction · déjà connu ou choix assumé

**Constat.** Le README assume que la barrière est « un ralentisseur, pas un verrou » et cite les applications récentes, le redémarrage, la désactivation. Quatre autres, plus simples, n'y figurent pas. (1) Écran partagé : une seule application « au premier plan » est retenue, la dernière passée en avant, alors qu'Android 10 et plus garde les deux moitiés actives ; ouvrir en dernier une application non bloquée dans l'autre moitié lève l'écran et laisse l'application bloquée utilisable. (2) Avancer l'horloge au-delà de la fin de fenêtre. (3) « Plus tard » sans limite de nombre. (4) La pastille de l'accueil coupe la barrière d'un toucher.

**Preuve.** android/app/src/main/java/com/myhitbodedut/GateService.kt:109-110 « if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) { foregroundPackage = event.packageName } » ; Store.kt:708 « val now = LocalTime.now() » ; Store.kt:724-726 (snooze sans compteur) ; MainActivity.kt:189 ; README.md:282-285 « Contournable, et c'est voulu ». Le point 1 est déduit du comportement multi-fenêtres d'Android, non exécuté.

**Correction proposée.** Compléter « Limites connues » du README avec ces quatre cas. Si le propriétaire veut un ralentisseur plus ferme : plafonner les reports par fenêtre (trois, par exemple) et, en écran partagé, considérer bloquée toute application de la liste passée en avant depuis moins de quelques secondes.

### FBARRIERE-21 — Paramètres restreints d'Android : l'application n'en dit rien, seul le README l'explique

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** Pour une application installée hors boutique (la distribution actuelle : GitHub et Obtainium), Android refuse d'accorder l'accès aux données d'utilisation tant que l'on n'a pas autorisé les « paramètres restreints ». Le README le dit. Dans l'application, après « Continuer », l'utilisateur tombe sur un interrupteur grisé, puis revient sur une ligne « Manquante » sans aucune piste.

**Preuve.** README.md:252-255 « le système interdit d'accorder l'accès aux données d'utilisation à une application installée hors boutique tant que l'on n'a pas levé la restriction : informations sur l'application, menu à trois points, « Autoriser les paramètres restreints » » ; aucune occurrence de « restreint » ni de « restricted » dans android/app/src/main/res/values/strings.xml et values-en/strings.xml.

**Correction proposée.** Dans la construction hors Play, ajouter aux deux fenêtres de divulgation une ligne. FR : « Interrupteur grisé ? Informations sur l’application → menu ⋮ → « Autoriser les paramètres restreints », puis revenez ici. » EN : « Switch greyed out? App info → ⋮ menu → “Allow restricted settings”, then come back here. » HE : « המתג אפור? פרטי האפליקציה ← תפריט ⋮ ← „אישור הגדרות מוגבלות”, ואז חזרו לכאן. »

### FBARRIERE-22 — Reprise de la position au changement de fuseau : chemin mort en arrière-plan

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Au changement de fuseau, le receveur demande la dernière position connue pour recaler le lieu des zmanim. L'application n'a pas la localisation en arrière-plan et le service de la barrière n'est pas de type « location » : Android ne rend alors aucune position à une application sans écran visible. Le repli (attendre l'ouverture de l'application) est donc le seul chemin réel, et pendant ce temps l'alerte de Chabbat n'est plus programmée (lieu périmé). Le commentaire promet une reprise qui n'a lieu que si l'application est déjà à l'écran.

**Preuve.** android/app/src/main/java/com/myhitbodedut/BootReceiver.kt:26-28 « reprise si Android en connaît une récente … if (intent.action == Intent.ACTION_TIMEZONE_CHANGED) ChoixLieu.reprendreEnFond(context) » ; ChoixLieu.kt:238-240 « lm.allProviders.mapNotNull { runCatching { lm.getLastKnownLocation(it) }.getOrNull() } » ; android/app/src/main/AndroidManifest.xml:16-20 : ACCESS_COARSE_LOCATION et ACCESS_FINE_LOCATION seulement ; Store.kt:443 « if (lieuPerime(context)) null else lieuZmanim(context) ». Non exécuté.

**Correction proposée.** Retirer l'appel du receveur et corriger le commentaire, ou afficher à ce moment une notification « Vous avez changé de fuseau : ouvrez l'application pour mettre à jour le lieu des zmanim ».

### FBARRIERE-23 — Traductions de la barrière : complètes dans les trois langues, cinq libellés à reprendre

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** Vérification demandée : les 1 222 chaînes françaises ont toutes leur équivalent anglais et hébreu (0 manquante hors les 45 marquées non traduisibles ; les 59 identiques au français sont des mots communs ou des formats), et les fichiers de la barrière, des rappels et des autorisations ne contiennent aucun texte en dur. Cinq écarts. (1) EN « Rest day » pour « Jour sans obligation » et « Rest day today » pour « Pause aujourd'hui », alors que le détail anglais dit « a pause ». (2) EN « get ready to enjoy! », verbe sans complément. (3) FR « activée / désactivée » sur l'accueil, « Mode désactivé » dans les réglages : deux genres pour la même fonction. (4) « le matin », « avant le reste de la journée » alors que la fenêtre est libre et qu'une fenêtre du soir est prévue. (5) « N applications bloquées » sert de compteur de sélection même mode éteint.

**Preuve.** android/app/src/main/res/values-en/strings.xml:65 « Rest day », l.102 « Rest day today », l.960 « Shabbat in 3 hours, get ready to enjoy! », l.115 « over the app you open in the morning » ; android/app/src/main/res/values/strings.xml:506-507 « activée » / « désactivée », l.65 « Mode désactivé », l.124 « que vous ouvrez le matin », l.138 « avant le reste de la journée », l.246 (apps_selected). Comparaison par script des trois fichiers strings.xml.

**Correction proposée.** (1) EN gate_exempt_title : « No obligation today » ; settings_exempt_today : « Pause today ». (2) EN : « Shabbat in 3 hours: get ready to enjoy it! ». (3) FR start_focus_on / off : « activé » / « désactivé ». (4) FR permission_overlay_why : « …par-dessus l’application que vous ouvrez pendant les heures du mode. » EN : « …over the app you open during the mode hours. » ; FR blocker_subtitle : « Un moment à l’écart avant le reste. » EN : « A moment alone before everything else. » (5) FR apps_selected : « %d application choisie » / « %d applications choisies » ; EN : « %d app selected » / « %d apps selected ».

### FBARRIERE-24 — Diagnostic : « Report en cours » affiché après la fin de la fenêtre, « reprendra demain » pour une fenêtre de nuit

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** L'état « report » est testé avant l'état « hors fenêtre ». Un report de 60 min demandé à 10:30 pour une fenêtre finissant à 11:00 affiche jusqu'à 11:30 « Report en cours. Le mode reprend à la fin du report. », alors qu'il ne reprendra pas ce jour-là. Pour une fenêtre de nuit honorée à 0 h 30, « Le mode reprendra demain » est faux : il reprend le soir même.

**Preuve.** android/app/src/main/java/com/myhitbodedut/GateStatus.kt:31-32 « Store.isSnoozed(context) -> GateState.SNOOZED ; !Store.inWindow(context) -> GateState.OUTSIDE_WINDOW » ; android/app/src/main/res/values/strings.xml:74 « Le mode reprend à la fin du report. » et l.70 « Le mode reprendra demain. »

**Correction proposée.** Tester la fenêtre avant le report dans evaluate(). FR gate_done_detail : « Plus rien ne sera retenu d’ici la prochaine fenêtre. » EN : « Nothing will be held back until the next window. » HE : « דבר לא יעוכב עד החלון הבא. »

### FBARRIERE-25 — Écran de garde en séance : temps restant figé ; écran calme : le seul bouton visible ne répond pas au premier toucher

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** « Il reste 45 min » est calculé à la création de la vue, et la vue n'est pas recréée tant que le mode ne change pas : le texte reste figé aussi longtemps que l'écran de garde est affiché. Dans l'écran de séance, le mode calme efface tout sauf le minuteur et le bouton principal, puis avale le premier toucher où qu'il tombe « pour qu'on ne touche pas un bouton qu'on ne voyait pas » : le bouton de fin, lui, était visible et ne réagit qu'au second toucher.

**Preuve.** android/app/src/main/java/com/myhitbodedut/GateService.kt:121 « if (overlay != null && overlayMode == mode) return » ; BlockerView.kt:106-112 (sous-titre calculé dans init) ; PratiqueCalme.kt:82-84 « avale = calme ; if (calme) sortir(anime = true) » ; SessionActivity.kt:96-99 : la liste des vues effacées ne contient pas session_primary.

**Correction proposée.** Rafraîchir le sous-titre à chaque tour quand le mode est SESSION_RUNNING (méthode BlockerView.actualiser()). Dans PratiqueCalme.toucher, ne pas avaler un toucher qui tombe sur une vue restée visible.
