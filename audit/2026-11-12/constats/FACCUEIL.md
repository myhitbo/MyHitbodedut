# FACCUEIL — Android — accueil, premiers pas, réglages, apparence, accessibilité

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

27 constats — confirmés : 6 · confirmés en partie : 3 · non contre-expertisés (mineurs et cosmétiques) : 18.

## Ce qui a été examiné

Lu en entier : MainActivity.kt (1 022 lignes), Onboarding.kt, OnboardingActivity.kt, SettingsActivity.kt (661), RemindersActivity.kt, Apparence.kt, Theme.kt, Personnage.kt, Character.kt, Salutation.kt, AccueilMoment.kt, SourceDuJour.kt, IconeLanceur.kt, IllustrationSouple.kt, Langue.kt, MyHitbodedutApp.kt, GateStatus.kt, Permissions.kt, Barres.kt, AnneauxImage.kt ; les gabarits activity_main, activity_onboarding, activity_settings, item_day, item_permission, item_reminder ; values et values-night (colors, palettes), themes.xml, dimens.xml et ses 7 déclinaisons, values-v31, locales_config, backup_rules, data_extraction_rules ; les tests PaletteTest, DarkModeTest, PersonnageTest. Lu en partie, en suivant les appels : Store.kt (une quinzaine de fonctions sur 1 641 lignes), BlockerView.kt (135 premières lignes), Autorisation.kt, DureeSeance.kt, Langues.kt, AnneauxView.kt et AnneauxDessin.kt, Levana.kt, Siddur.kt, VueJour.kt, StreakWidget.kt, MiniLecteur.kt, BoussoleActivity.kt, activity_reminders.xml, le manifeste principal et ceux des éditions, build.gradle, IconeLanceurTest, HomeTest, OnboardingTest, BackupRulesTest, PlaqueTest ; FEUILLE_DE_ROUTE.md (points 10 et 12, mises à jour du 28/09, « Ce qui manque », 19/10, 04/11, sujets ouverts) et PUBLICATION_PLAY_STORE.md (§ 6.7 et 8). Balayé par script : les 55 gabarits (descriptions, cibles sous 48 dp, left/right, tailles en dp), les 3 fichiers de chaînes (1 268 entrées : clés absentes, paramètres, valeurs identiques, lettres latines en hébreu), dont environ 330 chaînes de la dimension relues dans les trois langues ; contrastes WCAG calculés pour les 6 fonds × 6 accents, jour et nuit, sur une vingtaine de couples texte/fond (scripts et planche des scènes dans OUT/faccueil). Une recherche web, sur le comportement d'Android quand on désactive un activity-alias. Non examiné : aucune exécution sur appareil ou émulateur (ni capture, ni TalkBack réel, ni rendu des dégradés) : les constats sur la fermeture par l'alias, le bandeau en mode sombre et la jauge compacte reposent sur le code et le calcul, d'où leur confiance moyenne. Le gabarit couché de l'accueil n'a été comparé que par ses identifiants ; SettingsTest, ScreenFitTest et LayoutPaysageTest n'ont été lus que par leurs intitulés ; VignetteDecor.kt et les widgets seulement échantillonnés ; l'hébreu a été relu pour le sens et l'accord, sans locuteur natif.

## Ce qui tient

- Traduction complète : sur 1 268 entrées de chaînes, aucune clé ne manque en anglais ni en hébreu, aucun paramètre ne diverge entre les trois langues, et aucun texte d'interface n'est écrit en dur dans les écrans de la dimension (accueil, présentation, réglages, rappels). Les pluriels hébreux, duel compris, sont soignés, et les éditions complète et légère ont chacune leur phrase de confidentialité dans les trois langues.
- Droite-à-gauche et tailles : aucun left/right dans les gabarits de la dimension (start/end partout), chevron autoMirrored, anneaux dessinés avec un sens RTL, toutes les tailles de texte en sp (0 en dp), et aucune ImageView sans contentDescription ni importantForAccessibility sur les 55 gabarits balayés.
- Animations respectueuses : la rotation de la plaque, le saut du hassid, le remplissage et la fête des anneaux, la cascade des cartes testent ValueAnimator.areAnimatorsEnabled() et retombent sur un affichage immédiat.
- Palettes sous test : PaletteTest calcule les contrastes des 36 combinaisons fond × boutons, de jour et de nuit, pour les couples principaux (encre, texte secondaire, titres, bouton, plaques), et DarkModeTest garde les encres des plaques claires. Les défauts relevés sont dans ce que ces tests ne regardent pas encore, pas dans ce qu'ils couvrent.
- Autorisations demandées en contexte : la présentation ne demande que les notifications, et seulement si l'on allume le rappel ; les deux accès spéciaux passent toujours par une fenêtre de divulgation (Divulgation.kt, gardée par un test) ; chaque ligne d'autorisation dit à quoi elle sert ; le journal est exclu de la sauvegarde dans le nuage.
- Petits écrans et fenêtres : marges déclinées par largeur et hauteur disponibles (w360 à w1200, h480 à h720), gabarits couchés pour l'accueil, la séance et la présentation avec les mêmes identifiants (LayoutPaysageTest), présentation défilante avec IllustrationSouple, indice de la présentation et onglet actif conservés à la rotation.

## Constats

### FACCUEIL-01 — Changer d'icône de lancement ferme probablement l'application (Tsadeket à la présentation, couleur des boutons, import)

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** IconeLanceur désactive explicitement (COMPONENT_ENABLED_STATE_DISABLED) l'alias par lequel l'application vient d'être lancée. Android retire alors la tâche dont l'intent de base désigne ce composant, même avec DONT_KILL_APP : l'application se ferme seule quelques secondes après le geste. Cas touchés : choisir « Tsadeket » à l'écran 6 de la présentation (premier lancement, alias Icone_m_vert), changer « Couleur des boutons » ou « Comment vous appeler » dans les réglages, importer une sauvegarde, et le premier lancement après une réinitialisation. Pendant la présentation, finish() n'ayant pas été appelé, elle n'est pas marquée vue : elle repart de l'écran 1 au lancement suivant. Le commentaire du fichier ne signale que le raccourci retiré du bureau, pas la fermeture.

**Preuve.** K/IconeLanceur.kt:43-47 « pm.setComponentEnabledSetting(ComponentName(context, nom), if (oui) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP) » ; :49-50 « regle(voulu, true) / tous().filter { it != voulu }.forEach { regle(it, false) } » ; K/Store.kt:1281-1286 (setAdresse → IconeLanceur.appliquer) et 1322-1325 (setAccent) ; K/OnboardingActivity.kt:94-97 (choisir) et 89-92 (setOnboarded seulement dans finish()) ; A/AndroidManifest.xml:83-94 (Icone_m_vert, seule entrée LAUNCHER active). Comportement Android : composant ni ENABLED ni DEFAULT => tâches lancées par lui retirées (« disabled-package ») ; confirmé par une source tierce (« DONT_KILL_APP flag doesn't work if we disable the currently enabled alias at runtime »). Non exécuté sur appareil.

**Correction proposée.** Ne plus basculer l'alias pendant que l'application est à l'écran : noter le changement voulu et l'appliquer quand la dernière activité passe à l'arrière-plan (ActivityLifecycleCallbacks déjà en place dans Apparence.installer). Remettre à COMPONENT_ENABLED_STATE_DEFAULT (et non DISABLED) les alias déclarés enabled="false". Marquer la présentation vue dès le choix de l'adresse. Éprouver sur un appareil API 29 à 36 avant publication et corriger le commentaire d'IconeLanceur.

**Note du contre-expert.** Code relu (IconeLanceur.kt:41-50, Store.setAdresse/setAccent, OnboardingActivity.finish, manifeste) : conforme à la citation, et Store.reinitialiser ne remet pas l'icône, donc le cas « après réinitialisation » tient aussi. Comportement Android vérifié dans AOSP (branche main) : Task.setIntent garde l'alias comme composant de l'intent de base, et RecentTasks.cleanupDisabledPackageTasksLocked retire la tâche (« disabled-package ») quand ce composant est désactivé, DONT_KILL_APP ou non ; plusieurs sources tierces décrivent la même fermeture. Reste non éprouvé sur appareil (avant Android 10 l'intent de base pointait l'activité cible : le défaut n'y est sans doute pas).

### FACCUEIL-02 — Mode sombre : les chiffres de la plaque centrale sont illisibles (1,05 à 2,4:1) dans les 36 combinaisons

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** La plaque au creux des anneaux reste claire la nuit (mhStageSoft, fixe), mais les faces qu'on y affiche en touchant le hassid ou un anneau sont écrites avec des encres qui s'éclaircissent la nuit. Rapports calculés (WCAG) en mode sombre : valeur des faces « plus longue série / total / jours / moyenne » en mhInk : 1,05 à 1,17:1 (invisible) ; face du jour en mhBrand : 1,55 à 1,95 ; semaine (ring_week #6FB7E8) : 1,98 à 2,08 ; série (ring_streak #E8B45C) : 1,72 à 1,80 ; légende en mhMuted (12 sp) : 1,27 à 2,40. DarkModeTest ne le voit pas : il ne contrôle que les vues qui portent elles-mêmes le fond de plaque, pas leurs enfants ni les couleurs posées par le code. La phrase des réglages « Chaque combinaison reste lisible, de jour comme de nuit » (section_appearance_hint, fr:565, en:472, iw:482) est donc fausse.

**Preuve.** A/res/drawable/bg_gauge_plate.xml « &lt;solid android:color="?attr/mhStageSoft" /> » ; A/res/layout/activity_main.xml:140 (fond de hero_plate) et :181 « android:textColor="?attr/mhMuted" » (hero_face_caption) ; K/MainActivity.kt:539-544 « valeur.setTextColor(Apparence.couleur(this, when (vers.anneau) { JOUR -> R.color.brand ; SEMAINE -> R.color.ring_week ; SERIE -> R.color.ring_streak ; null -> R.color.ink })) » ; values-night/colors.xml:16-19,30-31. Calcul : OUT/faccueil/contraste.py.

**Correction proposée (revue par le contre-expert).** Recommandation juste, avec une précision : #2E7DB3 ne donne que 4,06–4,25:1 sur les six plaques (suffisant pour un grand chiffre gras, pas si l'auto-ajustement descend vers 16 sp) ; prendre #2A74A6 (4,6–4,8:1). Le reste tient : face du jour en mhOnPlate (5,2–6,8:1), série #8A5A00 (5,4–5,6:1), faces neutres #172B27 (13,5–14,2:1), légende #5E706A (4,76–5,0:1), en jetons non redéfinis la nuit. Ajouter @drawable/bg_gauge_plate aux plaques de DarkModeTest et y contrôler les enfants ainsi que les setTextColor du code.

**Note du contre-expert.** Rapports recalculés indépendamment sur les 6 plaques et les 6 fonds de nuit : encre 1,05–1,17, marque 1,55–1,95, semaine 1,98–2,08, série 1,72–1,80, légende 1,27–2,40, identiques au constat. bg_gauge_plate (mhStageSoft, fixe) n'est pas dans la liste « plaques » de DarkModeTest, les couleurs sont posées par MainActivity.remplirFace, et le gabarit paysage a le même défaut. Aucune décision de la feuille de route ne le couvre ; la phrase section_appearance_hint est bien présente dans les trois langues.

### FACCUEIL-03 — Tsadeket : le personnage masculin reste sur l'écran de garde, l'état vide de la boussole et cinq scènes

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** Le remplacement du hassid par la tsadeket repose sur PersonnageViewInflater, qui n'agit que dans les écrans AppCompat. (1) L'écran « Je suis avec Hachem » est gonflé par un service, sans l'usine d'AppCompat (le gabarit le dit lui-même pour ses boutons) : ses deux images (blocker_character et chizuk_art) sont des ImageView ordinaires et montrent toujours le hassid. (2) L'état vide de la boussole construit une android.widget.ImageView à la main. (3) Les cinq scènes (scene_nature, scene_sleeping, scene_airport, scene_hanukkah, scene_sukkot) montrent le hassid barbu et n'ont aucune variante féminine : la carte « Pour cette heure » de l'accueil le soir (Chema du coucher), la carte de 'hizouk des Réglages (Moment.LIEU), la notification de vol, les fêtes de la carte du jour. PersonnageTest ne contrôle que les fichiers « char_ ».

**Preuve.** K/BlockerView.kt:39 « LayoutInflater.from(Apparence.contexte(context)).inflate(R.layout.view_blocker, this, true) » puis :76, :93, :122 « art.setImageResource(Character.call()) » ; A/res/layout/view_blocker.xml:36 « &lt;ImageView android:id="@+id/blocker_character" » et :81-82 « cette vue est gonflée par un service, sans l'usine d'AppCompat » ; K/ChizukCard.kt:46 ; K/BoussoleActivity.kt:171-172 « addView(android.widget.ImageView(this@BoussoleActivity).apply { setImageResource(R.drawable.char_standing_back) » ; K/Siddur.kt:191 « "chema_coucher" -> R.drawable.scene_sleeping » ; K/Character.kt (Moment.LIEU -> R.drawable.scene_nature) ; K/Personnage.kt:22-44 (aucune entrée scene_) ; planche de contrôle : OUT/faccueil/scenes.png.

**Correction proposée (revue par le contre-expert).** Dans view_blocker.xml et view_chizuk_compact.xml (c'est lui que l'écran de garde inclut ; view_chizuk.xml n'est gonflé que par des activités), écrire &lt;com.myhitbodedut.PersonnageImageView> en toutes lettres, comme les MaterialButton. Dans BoussoleActivity.etatVide, construire une PersonnageImageView. Pour les cinq scènes : des variantes féminines, ou un repli déclaré dans Personnage.FEMININ. Étendre PersonnageTest aux « scene_ » et interdire « &lt;ImageView » dans les gabarits gonflés hors activité.

**Note du contre-expert.** Vérifié : BlockerView n'est créée que par GateService (un Service), donc sans l'usine d'AppCompat (le gabarit le dit lui-même pour ses boutons), et ses &lt;ImageView> blocker_character et chizuk_art restent ordinaires ; BoussoleActivity:171 construit une android.widget.ImageView ; les cinq scene_* montrent le hassid barbu (planche rouverte) et sont absentes de Personnage.FEMININ, PersonnageTest ne regardant que « char_ ». Aucune décision de la feuille de route n'exclut ces cas. Seule la recommandation se trompe de fichier : l'écran de garde inclut view_chizuk_compact.xml, pas view_chizuk.xml.

### FACCUEIL-04 — La barrière du matin n'est présentée nulle part, et sa pastille d'accueil s'affiche « activée » sans rien armer

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** Dans l'édition complète, la fonction qui définit l'application (bloquer des applications tant que la hitbodedout n'est pas faite) n'apparaît dans aucun des 7 écrans de la présentation. Sur l'accueil, elle se réduit à une pastille « Avec Hachem · désactivée » dont rien ne dit qu'elle bloque des applications. La toucher bascule Store.setEnabled et affiche « activée » sans vérifier les deux autorisations spéciales ni la liste d'applications (vide par défaut), sans rien demander ni expliquer : l'utilisateur croit le mode en place alors que GateStatus vaut MISSING_PERMISSIONS ou NO_APPS_SELECTED. La pastille rouge des Réglages, seul signal, a été retirée le 10/10. PUBLICATION_PLAY_STORE.md § 6.7 demande pourtant de répéter l'argument de la barrière jusque sur « l'écran d'accueil de l'app ».

**Preuve.** K/Onboarding.kt:46-92 (pratique, seance, jours, textes, reglages, adresse, prive : aucun écran sur la barrière ; aucune chaîne onboarding_* ne la mentionne) ; K/MainActivity.kt:186-192 « Store.setEnabled(this, !Store.isEnabled(this)) ; applyServiceState() ; refresh() » ; :371-373 « if (Store.isEnabled(this)) R.string.start_focus_on else R.string.start_focus_off » ; K/GateStatus.kt:26-28 ; chaînes start_focus « Avec Hachem », start_focus_on « activée ».

**Correction proposée.** Ajouter à la présentation de l'édition complète un écran « Je suis avec Hachem » (ce que fait le mode, qu'il est facultatif et coupable à tout instant, qu'il demande deux accès expliqués dans les Réglages). Faire dire à la pastille l'état réel de GateStatus (« à terminer » en couleur d'alerte quand il manque une autorisation ou une application) et, au premier toucher, ouvrir la carte du mode dans les Réglages au lieu de basculer en silence.

**Note du contre-expert.** Vérifié : aucun des 7 écrans d'Onboarding.ECRANS ni aucune chaîne onboarding_* (fr, en) ne parle de la barrière ; MainActivity:186-192 bascule Store.setEnabled sans rien contrôler et :371-373 n'affiche que l'interrupteur, alors que GateStatus.shouldRunService exige les deux accès et que la liste d'applications est vide par défaut. Le changement « d'une touche » est voulu (feuille de route, 22/09) et la pastille des Réglages a bien été retirée le 10/10, mais aucune décision ne couvre l'état « activée » affiché quand rien n'est armé ; PUBLICATION_PLAY_STORE.md § 6.7 demande bien de répéter l'argument sur l'écran d'accueil.

### FACCUEIL-05 — Refus des notifications : rappel laissé « activé » sans un mot, lien mort après deux refus, rappels par défaut muets

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** (1) Présentation, écran 3 : si l'on refuse la demande de notifications, l'interrupteur « Me le rappeler chaque jour » reste allumé (render() ne relit que Store.reminderEnabled) et rien n'avertit que le rappel ne s'affichera jamais. (2) Écran Rappels : la phrase « Touchez ici pour les autoriser » relance la demande système ; après deux refus Android ne montre plus rien et le toucher reste sans effet. Le commentaire annonce le cas « refusées pour de bon » mais la condition ne le couvre pas ; SettingsActivity, elle, a ce repli. (3) Commencer une séance ne demande jamais les notifications (Android 13+) : sans passage par le rappel, ni le décompte ni la fin de séance ne s'affichent téléphone posé. (4) « Rappel de Birkat haLevana » est allumé par défaut et son interrupteur ne vérifie rien : affiché actif, il reste muet sans autorisation.

**Preuve.** K/OnboardingActivity.kt:33 « registerForActivityResult(ActivityResultContracts.RequestPermission()) { render() } » et :131 « .isChecked = Store.reminderEnabled(this) » ; K/RemindersActivity.kt:100-106 « // Coupées dans les réglages du téléphone, ou refusées pour de bon : l'écran système. if (Build.VERSION.SDK_INT < TIRAMISU || checkSelfPermission(...) == PERMISSION_GRANTED) {...} demandeNotifications.launch(...) » contre K/SettingsActivity.kt:531-536 (refuseeDefinitivement -> notificationSettingsIntent) ; K/Store.kt:857 « getBoolean("levana_rappel", true) » ; K/SettingsActivity.kt:338 ; POST_NOTIFICATIONS n'est demandé que dans OnboardingActivity, RemindersActivity, SettingsActivity et VolActivity.

**Correction proposée (revue par le contre-expert).** Une seule fonction partagée par la présentation, Rappels et Réglages : lancer la demande puis, dans le retour, si elle est refusée et que shouldShowRequestPermissionRationale est faux, ouvrir Permissions.notificationSettingsIntent. Le repli actuel de SettingsActivity dépend d'un drapeau propre à l'écran (notificationsDemandees) et laisse encore un premier toucher mort après un refus définitif : ne pas le reprendre tel quel. Présentation : après refus, afficher reminders_permission_missing sous l'interrupteur. Demander les notifications au premier « Commencer », avec une phrase d'explication. Birkat haLevana : même avertissement que l'écran Rappels quand l'autorisation manque.

**Note du contre-expert.** Les quatre points se retrouvent dans le code : le retour de permission de la présentation se réduit à render(), qui relit le seul Store.reminderEnabled ; RemindersActivity:98-107 relance launch() sans repli après un refus définitif, contre son propre commentaire ; POST_NOTIFICATIONS n'est demandé que dans quatre écrans, jamais au départ d'une séance ; levana_rappel vaut true par défaut. Nuances : la fin de séance sonne quand même (Ringtone), et le point 4 est en partie couvert par la ligne « Notifications : manquante » du même écran Réglages.

### FACCUEIL-06 — Réglages : « 4 autorisations à accorder » et « Autorisations manquantes » alors que le mode est éteint

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : android · **Type** : fonction

**Constat.** À l'installation (édition complète, Android 13+), le titre de l'écran Réglages, en 19 sp gras, est « 4 autorisations à accorder. » et la carte « État du mode » montre un bouton plein « Autorisations manquantes, les accorder », alors que « Je suis avec Hachem » est éteint par défaut : GateStatus teste les autorisations avant l'interrupteur. L'utilisateur est poussé vers l'affichage par-dessus les autres applications et l'accès aux données d'utilisation (le couple que Google examine comme celui des logiciels espions) pour une fonction qu'il n'a pas choisie ; la carte s'intitule « Autorisations nécessaires » alors que la batterie sans restriction et ces deux accès sont facultatifs. En édition légère : « 2 autorisations à accorder » pour qui n'a aucun rappel. Le compte en tête des Réglages est voulu (retrait de la pastille le 10/10) ; ce qui ne l'est pas est de compter les accès d'une fonction éteinte.

**Preuve.** K/GateStatus.kt:26-27 « !Permissions.allGranted(context) -> GateState.MISSING_PERMISSIONS / !Store.isEnabled(context) -> GateState.DISABLED » ; K/SettingsActivity.kt:241-246 (renderSummary) et :258-260 (toutes les autorisations de l'édition comptées) ; K/Store.kt:1068 « getBoolean(KEY_ENABLED, false) » ; chaînes permissions_missing, gate_permissions_action, section_permissions « Autorisations nécessaires ».

**Correction proposée (revue par le contre-expert).** Dans GateStatus.evaluate, tester DISABLED avant MISSING_PERMISSIONS. Dans le compte en tête des Réglages : overlay et accès aux données d'utilisation seulement si le mode est activé, batterie jamais ; garder en revanche les notifications dans les deux éditions (elles servent l'affichage de la séance et le rappel de Birkat haLevana, allumé par défaut). Carte : « Autorisations » / “Permissions” / « הרשאות », les deux accès de la barrière marqués « facultatif tant que le mode est éteint ».

**Note du contre-expert.** Faits confirmés : GateStatus.evaluate teste les autorisations avant l'interrupteur (éteint par défaut), renderPermissions compte les quatre autorisations de l'édition, le bouton « Autorisations manquantes, les accorder » s'affiche mode éteint et la carte s'intitule « Autorisations nécessaires » ; aucune décision documentée ne demande de compter les accès d'un mode éteint. À corriger : l'exemple de l'édition légère (« pour qui n'a aucun rappel ») ne tient pas, le rappel de Birkat haLevana étant allumé par défaut et les notifications servant aussi l'affichage de la séance. La recommandation de ne compter les notifications que si un rappel ou le mode est allumé contredit d'ailleurs FACCUEIL-05.

### FACCUEIL-07 — « Tout est stocké sur ce téléphone uniquement » : faux, les réglages partent dans la sauvegarde Google

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : texte

**Constat.** La carte « Mes données » affirme que tout reste sur le téléphone, et le dernier écran de la présentation s'intitule « Rien ne sort d'ici ». Or le fichier des réglages est inclus dans la sauvegarde automatique d'Android (compte Google), et il contient la position enregistrée pour les zmanim (latitude, longitude) et la liste des applications bloquées. Les règles de confidentialité publiées le disent correctement (« seul le fichier des réglages y est inclus ») : c'est le texte de l'application qui contredit sa propre politique.

**Preuve.** section_data_hint (fr:33) « Tout est stocké sur ce téléphone uniquement. Exportez de temps en temps. » ; en:28 « Everything is stored on this phone only. » ; iw:28 « הכול נשמר בטלפון הזה בלבד. » ; onboarding_private (fr:206) « Rien ne sort d’ici » ; A/res/xml/backup_rules.xml « &lt;include domain="sharedpref" path="myhitbodedut.xml" /> » ; data_extraction_rules.xml (cloud-backup, même inclusion) ; K/Store.kt:414-420 (KEY_LIEU_LAT / KEY_LIEU_LON lus dans prefs) ; R/web/src/confidentialite.html:67.

**Correction proposée (revue par le contre-expert).** Garder les trois réécritures et le nouveau titre du dernier écran, mais créer pour le site une variante section_data_hint_web (le site lit aujourd'hui la même clé, app.js:4500), sans quoi l'iPhone parlerait de la sauvegarde Android : « Tout est gardé dans ce navigateur, sur cet appareil. Exportez de temps en temps. » / “Everything is kept in this browser, on this device. Export from time to time.” / « הכול נשמר בדפדפן הזה, במכשיר הזה. כדאי לייצא מדי פעם. » L'autre voie (sortir le lieu et la liste d'applications du fichier sauvegardé) ne suffit pas à rendre vraie la phrase actuelle : les autres réglages partiraient toujours ; il faudrait la reformuler quand même, ou couper la sauvegarde nuage.

**Note du contre-expert.** Vérifié : section_data_hint et onboarding_private dans les trois langues, backup_rules.xml et data_extraction_rules.xml (myhitbodedut.xml inclus dans la sauvegarde nuage), lieu des zmanim (latitude, longitude) et applications bloquées bien écrits dans ce fichier, et confidentialite.html:67 qui dit l'inverse de l'écran. L'envoi des réglages est un choix documenté ; c'est la phrase de l'application qui est fausse. Les trois réécritures sont correctes, mais la chaîne est aussi lue par le site (web/src/js/app.js:4500), ce que la recommandation oublie.

### FACCUEIL-08 — « Source du jour » : un bloc d'hébreu seul sur l'accueil, alors que les 122 paragraphes candidats sont traduits

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : fonction

**Constat.** La carte « Source du jour » de l'accueil affiche jusqu'à 320 caractères d'hébreu, sans traduction, quelle que soit la langue de l'interface et le mode de lecture choisi (LanguesTexte). Pour un utilisateur francophone ou anglophone qui ne lit pas l'hébreu, la plus grosse carte de l'accueil est illisible. Les données portent pourtant paragraphes_fr et paragraphes_en pour les 122 paragraphes candidats (29 sources), et l'écran de lecture de la bibliothèque les affiche. Le site fait de même (app.js:742, lang="he").

**Preuve.** K/SourceDuJour.kt:64-69 « text = extrait(p.texte) … textDirection = View.TEXT_DIRECTION_RTL … layoutDirection = View.LAYOUT_DIRECTION_RTL » ; K/Library.kt:28-30 « val paragraphesFr: List&lt;String> … val paragraphesEn » ; K/LibraryEntryActivity.kt:65 (LanguesTexte.textes(mode, paragraphe, source.paragraphesFr.getOrNull(index), …)) ; comptage sur RAW/bibliotheque.json : 122 candidats de 80 caractères ou plus, 122 traduits en français, 122 en anglais.

**Correction proposée.** Garder l'indice du paragraphe dans Pensee et rendre la carte par LanguesTexte.textes(LanguesTexte.mode(c), he, fr, en) : hébreu suivi de la traduction (ou traduction seule selon le mode), extrait coupé à 320 caractères par langue. Même correction dans web/src/js/app.js.

**Note du contre-expert.** Confirmé : SourceDuJour.carte n'affiche que extrait(p.texte) en hébreu, sans passer par LanguesTexte, alors que l'écran de lecture et la carte de 'hizouk suivent la règle « hébreu + traduction » ; le site fait de même (app.js:742). Seul le compte est à corriger : avec la règle réelle de LibraryRules.paragraphs (forme sans nikkoud pour 24 des 29 sources), il y a 108 candidats de 80 caractères ou plus, et non 122 ; tous ont leur traduction française et anglaise. Aucune décision de la feuille de route ne demande une carte en hébreu seul.

### FACCUEIL-09 — Bandeaux en mode sombre : texte blanc et menthe posé sur un halo devenu clair (2,1 à 3,5:1), surtout en hébreu

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : android · **Type** : fonction

**Constat.** Le dégradé des bandeaux part de mhBrand, qui s'éclaircit la nuit (#6CD3A8, #F2C46B, #8AB8F0…), dans le coin haut droit, et n'est pas retourné en RTL. En mode sombre, sur un bandeau de 360 dp, le blanc tombe à 2,1-2,7:1 à 24 dp du bord droit, 2,8-3,5:1 à 60 dp, et reste sous 4,5:1 jusqu'à environ 100 dp ; la menthe est encore plus basse (1,8-2,2:1 à 24 dp). En français le halo est sous l'illustration, mais la ligne de résumé des Réglages (pleine largeur, blanche) y entre ; en hébreu ce sont les premières lettres de chaque titre de bandeau qui s'y trouvent. PaletteTest ne vérifie le blanc et la menthe que sur mhBrandDark. Le widget évite ce piège de façon explicite (VignetteDecor : « Le dégradé ne part pas de brand, qui s'éclaircit la nuit… mais de day_done »).

**Preuve.** A/res/drawable/bg_hero.xml « android:angle="225" android:centerColor="?attr/mhBrandDark" android:centerX="0.55" … android:startColor="?attr/mhBrand" » ; A/res/layout/activity_settings.xml:13, 26, 37 (mhMint) et 45 (« @color/white », settings_summary) ; values-night/colors.xml:16 ; K/VignetteDecor.kt:14-18. Calcul aux positions du texte : OUT/faccueil/contraste.py. Non rendu sur appareil.

**Correction proposée (revue par le contre-expert).** Dans bg_hero.xml, android:startColor="?attr/mhDayDone" : identique à mhBrand le jour, fixe la nuit (blanc 5,5–7,4:1 et mhMint 4,8–6,0:1 sur les six palettes), ce qui suffit à régler le contraste. Pour que le halo reste du côté de l'illustration en hébreu, ajouter res/drawable-ldrtl/bg_hero.xml avec android:angle="315" (départ en haut à gauche) plutôt qu'autoMirrored. Ajouter à PaletteTest « blanc et mhMint sur la couleur de départ du bandeau ».

**Note du contre-expert.** Géométrie recalculée (angle 225 = du coin haut droit vers le bas gauche, centre à 0,55, bandeau de 360 × 118 dp) : blanc 2,07–2,73:1 à 24 dp du bord droit, 2,76–3,64 à 60 dp, menthe 1,82–2,19 à 24 dp ; les chiffres tiennent, et PaletteTest ne contrôle bien que mhBrandDark. Mais la portée est étroite : mode sombre seulement, surtout en hébreu (en français, la fin des lignes longues des bandeaux sans illustration) ; les titres sont de grands caractères gras (seuil 3:1) dont seules les premières lettres passent dessous, le texte reste déchiffrable et rien n'a été rendu sur appareil : mineur plutôt que majeur. La recommandation est à corriger : android:autoMirrored n'a aucun effet sur un dégradé &lt;shape> (GradientDrawable ne le gère pas, vérifié dans AOSP).

### FACCUEIL-10 — Rappels et Musique rangés sous l'onglet « Bibliothèque », absents des Réglages

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Le seul chemin vers les rappels de hitbodedout est la dernière ligne de l'onglet « Bibliothèque », sous neuf lignes de textes, dans la section « Autour de la hitbodedout ». L'écran Réglages, lui, porte le « Rappel de Birkat haLevana » et l'autorisation « Notifications … le rappel se programme et n'apparaît jamais », mais aucune entrée vers Rappels ni vers Musique. Le code lui-même croit le contraire, et le commentaire de RemindersActivity rappelle qu'un rappel introuvable « était là depuis le début, éteint, et invisible ». La présentation promet « Des rappels vous font signe à l'heure que vous choisissez » sans dire où.

**Preuve.** A/res/layout/activity_main.xml:628-648 (reminders_button, dernière ligne de texts_scroll) ; K/MainActivity.kt:203 (unique « RemindersActivity::class ») ; K/OnboardingActivity.kt:106 « La première heure de rappel ; les autres se règlent dans les réglages. » ; A/res/layout/activity_settings.xml (aucune vue vers RemindersActivity ni MusicActivity) ; nav_texts = « Bibliothèque ».

**Correction proposée.** Ajouter dans Réglages, sous la carte Apparence, une carte « Rappels et musique » avec deux lignes à chevron et leur état (« 2 heures réglées », « Aléatoire, volume 60 % ») ; garder ou retirer les deux lignes de l'onglet Bibliothèque. Corriger le commentaire d'OnboardingActivity.

### FACCUEIL-11 — Accueil surchargé : jusqu'à 15 blocs et 24 cibles tactiles avant les onglets, avec trois doublons

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Le panneau « Aujourd'hui » empile : en-tête (4 lignes), anneaux et plaque, légende, ligne du prochain trophée, « Commencer », 4 pastilles, 7 cases de la semaine, carte de relance, « Écrire une note », « Je l'ai faite sans le téléphone », cartes de rappels de tefila, prière de l'heure, Birkat haLevana, Source du jour, puis « Trophées » et « Mon parcours » : 15 blocs, 24 cibles tactiles, plus 5 onglets. Trois accès sont en double sur le même écran : PaliersActivity (ligne du trophée et bouton « Trophées »), l'ajout hors téléphone (bouton et case du jour), MusicActivity (pastille et ligne de l'onglet Bibliothèque). HomeTest « l'accueil ne porte plus que deux cartes » ne compte que les style="@style/Card" du XML, toutes deux dans le panneau Bibliothèque : les cartes du panneau Aujourd'hui sont construites en code (bg_card) et lui échappent.

**Preuve.** K/MainActivity.kt:175 et :580 (deux ouvertures de PaliersActivity) ; :174 (today_offline) et :857-865 (AjoutTemps sur chaque case) ; :184 et :194 (MusicActivity) ; :325-334 (cartes ajoutées dans accueil_moment) ; android/app/src/test/java/com/myhitbodedut/HomeTest.kt:62-66 « Regex("""style="@style/Card"""").findAll(layout).count() … cartes == 2 ».

**Correction proposée.** Retirer le bouton « 🏆 Trophées » (la ligne du prochain trophée suffit) et le bouton « Je l'ai faite sans le téléphone » au profit de la case du jour, ou l'inverse. Replier Source du jour à trois lignes avec « Lire la suite ». Faire compter à HomeTest les vues à fond bg_card ajoutées par le code.

### FACCUEIL-12 — TalkBack : la semaine se lit « à faire » sept fois, et 16 boutons de réglage ne disent que leur valeur

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** (1) Chaque case de la bande hebdomadaire reçoit une contentDescription réduite à son état (« à faire », « faite · 15 min », « Jour sans obligation »), qui remplace le texte des enfants : le jour et la date ne sont jamais annoncés. (2) Dans les Réglages, les 16 boutons de valeur (style SettingValue) ne sont reliés à aucun intitulé (aucun labelFor dans les 55 gabarits) : TalkBack lit « 06:00, bouton », « 11:00, bouton », « Diaspora, bouton » ; les quatre boutons « Accorder » ne nomment pas leur autorisation. Le correctif du 16/10 (bindSwitch -> libelleDe) ne couvre que les interrupteurs. (3) Aucun titre de carte n'est déclaré comme titre de section sur un écran de 9 cartes.

**Preuve.** K/MainActivity.kt:867-872 « cell.contentDescription = when { day.done -> getString(R.string.week_done) + " · " + … ; else -> getString(R.string.week_todo) } » ; A/res/layout/activity_settings.xml : 16 occurrences de style="@style/SettingValue" (ex. :280-287 window_start / window_end) ; A/res/layout/item_permission.xml:37-41 ; K/SettingsActivity.kt:349-358 ; recherche « labelFor|accessibilityHeading » dans res/layout* : 0 résultat.

**Correction proposée.** Case : contentDescription = jour en toutes lettres + date + état (« lundi 12, à faire »). Réglages : dans bornerValeurs, poser sur chaque bouton de valeur contentDescription = « intitulé : valeur » (libelleDe existe déjà) ; « Accorder : Notifications ». ViewCompat.setAccessibilityHeading(true) sur les CardTitle.

### FACCUEIL-13 — Petit écran et texte agrandi : la jauge compacte cache l'anneau du jour et réduit le hassid à 16 dp de large

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Quand la police système dépasse 1,1 sur un écran de moins de 640 dp de haut (portrait), jaugeCompacte() ramène la jauge à 96 dp et les marges de la plaque à 24 dp. Les anneaux gardent leur géométrie fixe (3 × 8 dp + 2 × 3 dp = 30 dp par côté, trou central de 36 dp) : la plaque de 48 dp recouvre 6 des 8 dp de l'anneau du jour, le plus important. Le rembourrage de la plaque (16 dp de chaque côté, 12 dp en haut, 4 dp en bas) reste celui du gabarit : il ne reste que 16 × 32 dp pour le personnage, et 16 dp de large pour les faces chiffrées. La réduction du 15/10 précède l'échelle des anneaux du 16/10 et n'a pas été reprise. Elle touche précisément les utilisateurs qui ont agrandi le texte.

**Preuve.** K/MainActivity.kt:935-945 « width = (96 * d).toInt(); height = (96 * d).toInt() … setMargins((24 * d).toInt(), …) » ; K/AnneauxView.kt:34 « Geometrie(epaisseur = 8f * densite, ecart = 3f * densite) » ; A/res/layout/activity_main.xml:131 « 32dp (échelle du 16/10) : trois anneaux de 8dp, deux écarts de 3dp » et :141-143 (paddingHorizontal 16dp, paddingTop 12dp, paddingBottom 4dp).

**Correction proposée.** En mode compact : jauge de 128 dp, marge de plaque 32 dp, rembourrage de plaque 6 dp ; ou rendre l'épaisseur des anneaux proportionnelle au côté (comme AnneauxImage : 9 % et 3,5 %). Ajouter le cas à LayoutPaysageTest « la jauge reste petite sur un écran court ».

### FACCUEIL-14 — Réinitialisation : le mode sombre, l'icône et la langue survivent à « Tout effacer »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** confirmerReinitialisation() vide les deux fichiers de préférences puis relance MainActivity dans le même processus, sans réappliquer le mode clair/sombre ni l'icône : une application réglée sur « Sombre » reste sombre alors que les Réglages affichent « Comme le téléphone », jusqu'à ce que le processus meure ; l'icône de la tsadeket ou de la couleur choisie reste jusqu'au lancement suivant (où la bascule d'alias peut fermer l'application, voir le premier constat). La langue choisie, gardée par Android/AppCompat hors des préférences, n'est jamais remise à zéro, alors que le texte annonce l'effacement des « réglages ».

**Preuve.** K/SettingsActivity.kt:184-194 (stopService, GateService.stop, Reminder.cancel, cancelAll, Store.reinitialiser, StreakWidget.refresh, startActivity : ni Apparence.appliquerMode ni IconeLanceur.appliquer ni setApplicationLocales) ; K/Store.kt:191-194 ; K/Apparence.kt:142-144 ; reset_hint « Efface tout ce que l’application garde sur ce téléphone : … réglages et rappels ».

**Correction proposée.** Après Store.reinitialiser : Apparence.appliquerMode(this), AppCompatDelegate.setApplicationLocales(LocaleListCompat.getEmptyLocaleList()), ZmanimWidget.refresh(this), et l'icône par le mécanisme différé du premier constat.

### FACCUEIL-15 — Valeurs limites des réglages : objectif quotidien sans retour à « sans réglage », plage du mode vide acceptée, durée invalide ignorée en silence

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** (1) « Objectif quotidien » : l'aide dit « Sans réglage, c'est la durée d'une hitbodedout », mais une fois réglé on ne peut plus revenir à ce lien ; le choix n'offre que 5 à 90 min ou une durée de 1 à 240, et 0 est impossible. Le bouton affiche la valeur effective, sans dire si elle est liée ou fixée. (2) « Heures du mode » : début = fin est accepté ; la barrière n'arme alors jamais et l'état affiche « Hors de la fenêtre : entre 07:00 et 07:00 ». (3) « Durée réglable… » : une saisie vide ferme la boîte sans message, 0 devient 1 et 999 devient 240 sans le dire. (4) « Région » bascule Israël/Diaspora au premier toucher, sans liste ni confirmation, contrairement à tous les autres boutons de valeur.

**Preuve.** K/SettingsActivity.kt:161-165 (DureeSeance.choisir -> Store.setDailyGoal) ; K/DureeSeance.kt:18-24 « PROPOSEES = intArrayOf(5, 10, 15, 30, 60, 90) … lire(texte) = texte.trim().toIntOrNull()?.coerceIn(MIN, MAX) » et :54-55 ; K/Anneaux.kt:98-99 ; K/Store.kt:707-713 « if (start <= end) minutes >= start && minutes < end » ; K/SettingsActivity.kt:128-131 ; settings_daily_goal_hint (fr:98).

**Correction proposée.** Objectif quotidien : première ligne « Comme la durée d'une hitbodedout » (setDailyGoal(0)) et valeur affichée « 15 min (durée habituelle) ». Plage : refuser début = fin par un message, ou l'interpréter comme « toute la journée ». Durée libre : garder la boîte ouverte avec « De 1 à 240 minutes » en erreur. Région : choisirParmi comme les autres.

### FACCUEIL-16 — « Afficher Birkat haLevana » n'agit pas sur la carte de l'accueil ; la portée des hilloulot est mal dite

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** L'interrupteur « Afficher Birkat haLevana » n'est lu que par l'écran Zmanim et le calendrier : éteint, la carte « Possible ce soir · ברכת הלבנה » continue d'apparaître sur l'accueil les soirs de la fenêtre. À l'inverse, le même réglage des hilloulot, répété au bas de l'écran Hilloulot, dit « Sur la carte du jour, à l'accueil », alors que les hilloulot ne s'affichent que sous les horaires de l'écran Zmanim et dans le calendrier, jamais sur l'accueil.

**Preuve.** K/AccueilMoment.kt:35-37 (aucun appel à Store.levanaAffichee) contre K/VueJour.kt:170 et :185 « if (Store.levanaAffichee(c)) » ; reglage_levana (fr:1052) ; hilloulot_afficher_detail (fr:900) « Sur la carte du jour, à l’accueil », en:836 « On the day card, on the home screen », iw:853 « בכרטיס היום, במסך הבית » ; K/VueJour.kt:192 (seuls ZmanimActivity et le calendrier appellent VueJour).

**Correction proposée.** Conditionner la carte de l'accueil à Store.levanaAffichee(c). hilloulot_afficher_detail : FR « Sous les horaires, à l’écran Zmanim » ; EN “Below the times, on the Zmanim screen” ; HE « מתחת לזמנים, במסך הזמנים ».

### FACCUEIL-17 — « Contraste élevé » : l'icône de l'onglet actif disparaît sur sa pastille (1,2 à 2,1:1)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** La pastille derrière l'onglet actif prend mhLine. Dans la palette « Contraste élevé », mhLine vaut #767676 le jour et #8C8C8C la nuit (« traits marqués ») : l'icône active, en mhBrand, n'a plus que 1,21 à 1,64:1 le jour et 1,59 à 2,06:1 la nuit selon la couleur des boutons, soit les 12 combinaisons de la palette faite pour les malvoyants (seuil des éléments graphiques : 3:1). Dans la même palette, les boutons cerclés créés par le code gardent un filet « @color/line » (#DCE7DF sur blanc, 1,27:1) au lieu des traits marqués : le test « aucun écran ne fige une couleur réglable » ne lit pas values/themes.xml.

**Preuve.** A/res/values/themes.xml:313-315 « &lt;style name="NavIndicator" …> &lt;item name="android:color">?attr/mhLine&lt;/item> » ; A/res/color/nav_item.xml « &lt;item android:color="?attr/mhBrand" android:state_checked="true" /> » ; A/res/values/palettes.xml:152 « &lt;item name="mhLine">#767676&lt;/item> », values-night/palettes.xml:143 « #8C8C8C » ; themes.xml:153 « &lt;item name="strokeColor">@color/line&lt;/item> » (Bouton.Contour, employé par SourceDuJour.kt:89).

**Correction proposée.** Pastille : un attribut propre (mhNavPastille), égal à mhLine dans les cinq autres fonds et à #E6E6E6 (jour) / #2A2A2A (nuit) en Contraste élevé ; Bouton.Contour : strokeColor="?attr/colorOutline". Ajouter à PaletteTest « mhBrand sur la pastille d'onglet : 3:1 au moins ».

### FACCUEIL-18 — De jour : la légende des anneaux en ambre (3,3:1) et en bleu (4,0:1), les jours de la semaine en gris sous 4,5:1 sur trois fonds

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** La légende sous les anneaux (16 sp, non gras) prend la couleur de l'anneau touché. ring_streak #B8780F sur le fond de page donne 3,26 à 3,39:1 selon le fond, ring_week #2E7DB3 3,97 à 4,13:1 : sous le seuil AA de 4,5 pour du texte courant, sur les six fonds. Les abréviations des jours (11 sp, mhMuted) sur les cases « à faire » tombent à 4,25 (Bleu pâle), 4,40 (Sable) et 4,46 (Rose pâle). Ces deux couleurs fixes et le couple mhMuted/mhDayTodo ne figurent pas dans PaletteTest.

**Preuve.** K/MainActivity.kt:643-653 « legende.setTextColor(Apparence.couleur(this, when (quel) { … SEMAINE -> R.color.ring_week ; SERIE -> R.color.ring_streak … })) » ; A/res/values/colors.xml:51-52 ; A/res/layout/item_day.xml:15-16 « android:textColor="?attr/mhMuted" android:textSize="11sp" » ; A/res/values/palettes.xml:125-126, 111-112, 139-140. Calcul : OUT/faccueil/contraste.py.

**Correction proposée.** Garder les couleurs des anneaux pour le trait et écrire la légende en mhInk, avec une puce de la couleur de l'anneau devant ; ou foncer les encres de texte (ambre #8A5A00, bleu #256A9A). mhMuted : #5C6B80 (Bleu pâle), #6E6253 (Sable), #775C62 (Rose pâle). Ajouter ces couples à PaletteTest.

### FACCUEIL-19 — Cibles tactiles sous 48 dp : pastilles de séance (40 dp), anneaux (bandes de 11 dp), cases de la semaine, lien d'autorisation

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Les quatre pastilles sous « Commencer » (Durée, Sujet, Musique, Avec Hachem) font 40 dp de haut. Chaque anneau ne répond que sur son trait de 8 dp plus 1,5 dp de marge de chaque côté, soit trois bandes concentriques de 11 dp. Les cases de la semaine font (largeur − marges) / 7, soit 41 dp sur un écran de 320 dp et 44,6 dp sur 360 dp, sans espace entre elles. Dans Rappels, l'avertissement d'autorisation est un TextView de 13 sp rendu cliquable, sans hauteur minimale ni rôle de bouton.

**Preuve.** A/res/values/themes.xml:284 « &lt;item name="android:minHeight">40dp&lt;/item> » (StartChip) ; K/AnneauxDessin.kt:110-114 « val marge = geometrie.ecart / 2f … depuisBord <= rang * pas + geometrie.epaisseur + marge » ; A/res/layout/item_day.xml:3-6 (layout_weight 1, marge 0) ; A/res/layout/activity_reminders.xml:79-84 et K/RemindersActivity.kt:66-68.

**Correction proposée.** StartChip : minHeight 48dp. Anneaux : garder le toucher du centre comme chemin principal et attribuer tout le disque hors plaque à l'anneau le plus proche (marge = moitié de l'écart de chaque côté, sans trou entre les bandes). Avertissement de Rappels : un bouton texte « Autoriser les notifications ».

### FACCUEIL-20 — « Série : 1 jours sur 3 » : la légende de l'anneau de série et la description des anneaux ne sont pas au pluriel

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** ring_streak_detail et rings_description sont des chaînes simples avec « jours » / « ימים » en dur : pour une série de 1 (ou 0) la légende affiche « Série : 1 jours sur 3 », en hébreu « רצף: 1 ימים מתוך 3 » ; la description lue par TalkBack dit « Semaine : 1 jours sur 6. Série : 1 jours sur 3. ». L'anglais (« 1 of 3 days ») passe. Les autres compteurs de l'accueil sont, eux, des plurals soignés (status_streak, week_gauge, plaque_serie).

**Preuve.** values/strings.xml:105 « &lt;string name="ring_streak_detail">Série : %1$d jours sur %2$d&lt;/string> » ; values-iw/strings.xml:98 « רצף: %1$d ימים מתוך %2$d » ; values/strings.xml:107 (rings_description) ; K/MainActivity.kt:637-640 « getString(if (etat.serie.atteint) R.string.ring_streak_reached else R.string.ring_streak_detail, etat.serie.fait, etat.serie.objectif) ».

**Correction proposée.** En faire un plurals sur %1$d. FR one : « Série : %1$d jour sur %2$d », other : « Série : %1$d jours sur %2$d ». HE one : « רצף: יום אחד מתוך %2$d », two : « רצף: יומיים מתוך %2$d », other : « רצף: %1$d ימים מתוך %2$d ». EN inchangé. Pour rings_description, composer la phrase à partir de week_gauge et de ce nouveau pluriel.

### FACCUEIL-21 — Pastille « Avec Hachem · désactivée » : accord fautif et libellé qui ne dit pas ce qu'il fait

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** Sur l'accueil, la pastille se lit « Avec Hachem activée » / « Avec Hachem désactivée » : féminin sans nom féminin (reste de « la barrière »), alors que les Réglages parlent partout du « mode » au masculin (« Mode désactivé », « le mode se tait »). Lu tel quel, « Avec Hachem : désactivée » (EN “With Hashem: off”) est maladroit pour une application de prière, et le nom diffère de celui des Réglages (« Je suis avec Hachem »). Le nom du mode est une décision du propriétaire (feuille de route, point 12) ; l'accord et la formule de la pastille ne le sont pas.

**Preuve.** values/strings.xml:506-507 « &lt;string name="start_focus_on">activée&lt;/string> / &lt;string name="start_focus_off">désactivée&lt;/string> » ; start_focus « Avec Hachem » / “With Hashem” / « עם השם » ; gate_disabled_title « Mode désactivé » ; section_gate « Je suis avec Hachem ».

**Correction proposée.** Libellé : « Mode du matin » / “Morning mode” / « מצב הבוקר » ; valeurs : « actif » / « éteint », “on” / “off”, « פעיל » / « כבוי ». Ou, pour garder le nom : libellé « Je suis avec Hachem », valeurs « le matin » / « non » (“mornings” / “no” ; « בבוקר » / « לא »).

### FACCUEIL-22 — Anglais : « Simply speaking » ne traduit pas « Parler, simplement »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** Le titre du premier écran de la présentation, « Parler, simplement » (hébreu « פשוט לדבר », juste), est rendu en anglais par « Simply speaking », locution figée qui signifie « pour le dire simplement » : le premier mot que lit un anglophone annonce une explication, pas l'invitation à parler. Dans la même liste, « Tips for Hitbodedut » porte une majuscule alors que les 94 autres occurrences anglaises écrivent « hitbodedut ».

**Preuve.** values-en/strings.xml:188 « &lt;string name="onboarding_practice">Simply speaking&lt;/string> » ; values/strings.xml:204 « Parler, simplement » ; values-iw/strings.xml:189 « פשוט לדבר » ; values-en/strings.xml:285 « &lt;string name="tips_title">Tips for Hitbodedut&lt;/string> ».

**Correction proposée.** onboarding_practice (EN) : “Just talk”. tips_title (EN) : “Tips for hitbodedut”.

### FACCUEIL-23 — Organisation des réglages : la carte « Rythme » fourre-tout, un rappel rangé dans « Écran Zmanim », pas de « Comme le téléphone » pour la langue

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** L'écran Réglages est un seul défilement de 9 cartes et d'environ 35 commandes. La carte « Rythme » en contient 9 sans rapport entre elles : Prénom, Durée, Objectif quotidien, Chabbat et Yom Tov, Région, Masquer le décompte, Ne pas déranger, Hitbodedout guidée, Pause aujourd'hui, puis une carte de 'hizouk. La carte « Écran Zmanim », sous-titrée « Ce qui s'affiche sous les horaires », porte « Rappel de Birkat haLevana » (une notification) et « Birkat haLevana : usage » (un calcul). La langue se choisit parmi עברית / English / Français sans option pour suivre le téléphone : avant Android 13, un choix fait ne se défait plus, alors que le mode clair/sombre a son « Comme le téléphone ».

**Preuve.** A/res/layout/activity_settings.xml:314-472 (carte section_rhythm : name_button, target_length, daily_goal, shabbat_switch, region_button, hide_countdown_switch, ne_pas_deranger_switch, guided_switch, exempt_today_switch, lieu_chizuk) ; :139-214 (levana_rappel_switch et levana_usage_button sous section_zmanim_ecran_hint) ; K/Langues.kt:25-29 (TOUTES : trois langues) ; K/Apparence.kt:33 (Mode.AUTO).

**Correction proposée.** Découper : « Vous » (prénom, comment vous appeler, langue avec « Comme le téléphone »), « La hitbodedout » (durée, objectif, guidée, masquer le décompte, ne pas déranger), « Calendrier » (Chabbat et Yom Tov, région, pause aujourd'hui), « Rappels » (hitbodedout, Birkat haLevana et son usage). Retirer la carte de 'hizouk du milieu des réglages.

### FACCUEIL-24 — Écran d'ouverture : 1,85 s imposées à chaque lancement, sans toucher pour passer

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction · déjà connu ou choix assumé

**Constat.** À chaque création de l'accueil, un voile (photo du tsiyoun et hassid) couvre l'écran 1,5 s puis s'efface en 0,35 s. Il est cliquable pour absorber les touchers : on ne peut pas le passer. Le délai est un postDelayed, donc insensible au réglage système « Supprimer les animations » que le reste de l'accueil respecte. Il s'ajoute à l'écran de démarrage d'Android 12+. Pour une application dont le geste central est « Commencer » le matin, c'est près de deux secondes d'attente par ouverture. Choix du propriétaire (13/10 et 15/10), noté ici comme critiquable.

**Preuve.** K/MainActivity.kt:966 « isClickable = true » ; :1001-1003 « voile.postDelayed({ voile.animate().alpha(0f).setDuration(350).withEndAction { decor.removeView(voile) }.start() }, OUVERTURE_MS) » ; :1011 « const val OUVERTURE_MS = 1500L » ; commentaire :948-955 (« une seconde et demie au démarrage »).

**Correction proposée.** Laisser un toucher fermer le voile (setOnClickListener qui lance le fondu), le ramener à 0 quand ValueAnimator.areAnimatorsEnabled() est faux, et ne le montrer qu'une fois par jour ou au premier lancement.

### FACCUEIL-25 — « Comment vous appeler ? » : le texte ne dit pas que le personnage et l'icône changent, et la question arrive au 6ᵉ écran

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** L'écran promet seulement le choix d'un « mot » de félicitation. Toucher « Tsadeket » change aussi toutes les illustrations et l'icône de lancement sur le bureau du téléphone, ce que rien n'annonce (un lanceur peut retirer le raccourci, selon le commentaire d'IconeLanceur). La question est posée à l'écran 6 sur 7 : une femme voit d'abord cinq écrans illustrés par le hassid.

**Preuve.** onboarding_adresse_body (fr:538) « À la fin de chaque hitbodedout, l’application vous félicite. Choisissez le mot qui vous convient ; vous pourrez le changer dans les réglages. » ; K/Onboarding.kt:79-85 (écran « adresse » en sixième position) ; K/Store.kt:1285 « IconeLanceur.appliquer(context) ».

**Correction proposée.** Placer l'écran en deuxième position. FR : « À la fin de chaque hitbodedout, l’application vous félicite. Choisissez le mot qui vous convient : le personnage et l’icône de l’application le suivront. Vous pourrez le changer dans les réglages. » EN : “At the end of each hitbodedut, the app congratulates you. Pick the word that fits you: the character and the app icon will follow. You can change it in Settings.” HE : « בסוף כל התבודדות האפליקציה מברכת אתכם. בחרו את המילה שמתאימה לכם: הדמות וסמל האפליקציה ישתנו בהתאם. אפשר לשנות זאת בהגדרות. »

### FACCUEIL-26 — Heures : format 24 h imposé dans Réglages et Rappels, format du téléphone dans la présentation

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** La présentation affiche et saisit l'heure du rappel selon le réglage 12/24 h du téléphone (« à 7:00 AM »). L'écran Rappels et les heures du mode imposent ensuite le sélecteur 24 h et affichent « 07:00 » quelle que soit la préférence : la même heure change de forme d'un écran à l'autre pour un utilisateur en 12 h (cas courant en anglais).

**Preuve.** K/OnboardingActivity.kt:116 « DateFormat.is24HourFormat(this)).show() » et :121 « ofPattern(if (DateFormat.is24HourFormat(this)) "HH:mm" else "h:mm a") » ; K/RemindersActivity.kt:114 et :147 (dernier argument « true ») ; K/SettingsActivity.kt:596-603 (« true ») ; K/Store.kt:1628-1629 « String.format(Locale.US, "%02d:%02d", … ) ».

**Correction proposée.** Une seule fonction d'affichage (Store.formatHeure(context, minutes), fondée sur DateFormat.getTimeFormat(context)) et DateFormat.is24HourFormat(context) pour tous les TimePickerDialog.

### FACCUEIL-27 — « Bibliothèque » désigne trois choses différentes

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** L'onglet du bas s'appelle « Bibliothèque » (tous les textes, plus Musique et Rappels). La présentation annonce dans la même phrase « le siddour, les Tefilot…, une bibliothèque », qui est la ligne « Sources de la hitbodedout » de cet onglet. L'état de la musique dit « Aucun morceau dans la bibliothèque. ». Un nouvel utilisateur cherche « la bibliothèque » promise dans un onglet qui porte déjà ce nom. Même glissement en anglais (Library) et en hébreu (ספרייה).

**Preuve.** nav_texts « Bibliothèque » / “Library” / « ספרייה » ; onboarding_texts_body (fr:534) « …les Tefilot classées par sujet, une bibliothèque et des conseils pour la hitbodedout… » ; library_title « Sources de la hitbodedout » ; music_none_summary « Aucun morceau dans la bibliothèque. ».

**Correction proposée.** onboarding_texts_body : remplacer « une bibliothèque » par « des sources sur la hitbodedout » (EN “sources on hitbodedut” ; HE « מקורות על ההתבודדות »). music_none_summary : « Aucun morceau pour l’instant. » / “No track yet.” / « אין עדיין ניגונים. ».
