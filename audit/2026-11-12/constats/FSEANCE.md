# FSEANCE — Android — la séance, la musique, le bravo

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

25 constats — confirmés : 5 · confirmés en partie : 1 · non contre-expertisés (mineurs et cosmétiques) : 19.

## Ce qui a été examiné

Lu en entier (dans android/app/src/main/java/com/myhitbodedut) : SessionService, SessionActivity, SessionRule, DureeSeance, AjoutTemps, Hitbodedut, HitbodedutCard, GuideSujets, QuestionsBlocage, CelebrationActivity, Confettis, DanseMesure, Effets, SouffleView, Aeration, MiniLecteur, MusicActivity, MusicLibrary, MusicPlayer, MusiquePlay, MelangeMusique, Ambiance, NoteDialog, plus PratiqueCalme, NePasDeranger, BootReceiver, Notifications ; AndroidManifest.xml (main) ; les gabarits activity_session (portrait en entier, identifiants comparés au paysage : identiques), activity_celebration, item_track, view_hitbodedut ; les règles de sauvegarde ; SessionRuleTest et MusicFilesTest en entier.
Échantillonné : Store.kt (environ 600 lignes sur 1 641 : journées, séance en cours, musique, bravo) ; GateService et MainActivity aux seuls points de jonction avec la séance ; ChizukCard et ChizukBag (tirage) ; les intitulés des tests Fiabilite, Fiabilite2, Hitbodedut ; activity_music (identifiants et libellés) ; README (séance, musique), FEUILLE_DE_ROUTE (lignes 1 à 175 et 1015 à 1163), PUBLICATION_PLAY_STORE (§ 6.6 et lignes sur la musique).
Traductions : script de comparaison des trois strings.xml (1 268 clés françaises, 0 absente en anglais et en hébreu, paramètres comparés) ; 185 chaînes de la séance, de la musique, du bravo, de la note et du guide relues en français et en anglais, l'hébreu relu pour la cohérence seulement ; les 135 cellules de guide_sujets.json relues dans les trois langues ; longueur des 64 textes « blocage » de chizuk.json mesurée.
Non examiné ou non exécuté : aucun appareil ni émulateur, aucune construction ni lancement des tests (lecture seule) ; les comportements du focus audio, du mode Ne pas déranger, de Doze et des services au premier plan sont déduits du code, de la documentation Android et du source AOSP (quatre recherches web génériques, sans nom de projet), d'où la confiance « moyenne » de cinq constats. Web et Nokia hors dimension. Contenu et droits des morceaux non examinés.
Constaté sans en faire un défaut : il n'existe ni pause du minuteur ni prolongation d'une séance en cours (seule la musique se met en pause ; un appel entrant ne suspend pas le décompte). La séance à cheval sur minuit s'inscrit au jour civil de son début, choix documenté et testé ; la sortie des étoiles n'intervient pas dans l'inscription. Le plafond de 240 minutes d'une séance ouverte et son absence de fin automatique sont imposés par des tests.

## Ce qui tient

- L'arithmétique de la séance est isolée dans SessionRule, sans Android, et éprouvée par des tests qui portent chacun la trace d'un bogue réel : une séance minutée ne compte jamais plus que sa durée, elle s'inscrit au jour de son début, une séance orpheline est reprise (reconcilier, cloreLaPrecedente), une relance sans séance n'inscrit pas de journée fantôme.
- La séance minutée tient écran éteint : verrou d'éveil à échéance (il ne peut pas rester pris), tour de service calé sur le terme à 30 ms près, type de service et sous-type déclarés, relance au redémarrage protégée par runCatching ; l'heure d'été et le changement de fuseau sont sans effet sur le décompte.
- La réduction des animations est respectée partout dans la dimension : danse du Bravo, confettis, Effets, lueur de respiration, pratique calme testent tous ValueAnimator.areAnimatorsEnabled ; avec TalkBack rien ne s'efface, et la vue des confettis est exclue de l'accessibilité.
- Les chaînes d'interface sont complètes : 1 268 clés françaises, aucune absente en anglais ni en hébreu, paramètres cohérents (seuls les singuliers hébreux écrits en toutes lettres diffèrent, à raison) ; une seule chaîne en dur dans toute la dimension ; les 135 invitations du guide (9 sujets × 5 temps × 3 langues) sont toutes remplies et bien traduites.
- La hitbodedout guidée cite ses sources avec exactitude et sépare ce qui vient de Likoutei Moharan II, 25 de ce qui vient du Rambam ; l'hébreu affiché correspond au texte du livre embarqué.
- Les ambiances sont calculées, reproductibles et testées, générées hors du fil principal avec un numéro de demande qui écarte un calcul arrivé trop tard ; la lecture aléatoire ne répète aucun morceau avant la fin du tour, y compris à la jonction de deux tours.

## Constats

### FSEANCE-01 — « Ne pas déranger » n'est jamais rétabli si le service de séance meurt avant la fin

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** Avec l'option « Ne pas déranger pendant la hitbodedout » (éteinte par défaut), le mode d'avant n'est rétabli qu'à un seul endroit : SessionService.stopSelfAndClear(). Si le processus disparaît pendant la séance (redémarrage, batterie vide, bouton « Arrêter » du gestionnaire de tâches d'Android 13+, arrêt forcé, tueur de batterie du constructeur, plantage), la séance est close plus tard par reconcilier() ou cloreLaPrecedente(), qui inscrivent les minutes mais ne rétablissent rien : le téléphone reste en mode « priorité » (appels et notifications coupés) jusqu'à la fin normale d'une séance suivante. Second cas, Android 15+ (targetSdk 36) : setInterruptionFilter n'agit plus sur l'état global mais sur une règle implicite de l'application ; « rétablir » un mode d'avant autre que ALL (l'utilisateur était déjà en Ne pas déranger) laisse cette règle active après la séance (ce second cas : confiance moyenne, d'après la note de version Android 15).

**Preuve.** K/SessionService.kt:425-430 « if (echue) { val theme = Store.sessionTheme(context); val close = Store.endSession(context); if (close.minutes > 0) inscrire(context, close, theme); StreakWidget.refresh(context) } » : aucun retablir. Seul appel dans tout K : SessionService.kt:307 « NePasDeranger.retablir(this) » (dans stopSelfAndClear). K/NePasDeranger.kt:24 « if (Store.filtreAvantSeance(context) != null) return » ; :32 « if (accesAccorde(context)) runCatching { nm(context).setInterruptionFilter(avant) } ». android/app/build.gradle.kts:13 « targetSdk = 36 ».

**Correction proposée (revue par le contre-expert).** Celle de l'auditeur, complétée par deux chemins qu'elle ne nomme pas : appeler NePasDeranger.retablir() aussi dans onStartCommand quand le service relancé ne trouve plus de séance (SessionService.kt:81-84, stopSelf() nu), et dans « Tout effacer » avant Store.reinitialiser (SettingsActivity.kt:185-189 : stopService n'appelle pas retablir, puis l'effacement des préférences supprime filtre_avant_seance, sans retour possible). Dans activer(), n'agir que si le filtre courant est INTERRUPTION_FILTER_ALL ; retablir() remet alors toujours INTERRUPTION_FILTER_ALL, ce qui est correct avant comme après Android 15. Garder les appels dans reconcilier() (branche échue), dans cloreLaPrecedente() et à l'ouverture de l'application quand filtre_avant_seance est posé sans séance inscrite.

**Note du contre-expert.** Vérifié : NePasDeranger.retablir() n'a qu'un appelant (SessionService.kt:307, stopSelfAndClear) ; la branche échue de reconcilier() (425-430, appelée par BootReceiver, MainActivity.onResume et SessionActivity.onResume) et cloreLaPrecedente() closent sans rétablir, et le service relancé par START_STICKY tombe alors sur un stopSelf() nu (lignes 81-84). Le second cas, donné en confiance moyenne, est confirmé dans le source AOSP (NotificationManagerService.setInterruptionFilter → ZenModeHelper.applyGlobalZenModeAsImplicitZenRule, actif dès targetSdk 35) : seul le filtre ALL désactive la règle implicite, donc « rétablir » PRIORITY la laisse active, et comme currentInterruptionFilter (état global) reste alors différent de ALL, les séances suivantes ne la lèvent jamais ; cas réaliste d'une séance du matin commencée sous le mode Coucher. Réserves sans effet sur le verdict : lignes de NePasDeranger.kt décalées d'une (23 et 31, pas 24 et 32), et un simple plantage est en général rattrapé par START_STICKY, qui rétablit à la fin.

### FSEANCE-02 — Mini-lecteur : « Pause » puis « Lecture » coupe la musique au lieu de la reprendre

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** reprendre() redemande le focus audio avec un nouvel AudioFocusRequest et un nouvel écouteur, sans abandonner celui posé par start(). Pour Android ce sont deux clients distincts de la même application : le premier reçoit AUDIOFOCUS_LOSS, et son écouteur appelle stop(fade = false), qui libère le lecteur qu'on vient de relancer et abandonne le nouveau focus. Effet : après une pause, le premier appui sur Lecture donne un instant de son puis le silence ; le second appui passe par ensureMusic() et repart du début du morceau (ou tire un autre morceau en lecture aléatoire). La position est perdue. Déduit du code et du source d'Android, non exécuté sur appareil ; aucun test ne couvre MusicPlayer.

**Preuve.** K/MusicPlayer.kt:41-44 « fun reprendre() { enPause = false; if (player != null && requestFocus()) runCatching { player?.start() } } » ; :145-155 requestFocus() : « val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)….setOnAudioFocusChangeListener { change -> when (change) { AudioManager.AUDIOFOCUS_LOSS -> stop(fade = false) … » puis « focusRequest = request » sans abandon du précédent. K/SessionService.kt:272 « } else if (music.charge) music.reprendre() else ensureMusic() ». AOSP, FocusRequester.frameworkHandleFocusLoss : « the focus change is within the same app, so let the dispatching happen as if the framework was not involved ».

**Correction proposée.** Un seul AudioFocusRequest par MusicPlayer : le construire une fois (champ), le réutiliser dans start() et reprendre() ; ou appeler abandonFocus() avant tout nouveau requestFocus(). Ajouter un test instrumenté pause → reprise → position conservée.

**Note du contre-expert.** Code relu (MusicPlayer.kt:41-44 et 144-162, SessionService.kt:268-273, MiniLecteur) et source AOSP téléchargé pour trancher : l'identifiant de client est AudioManager.toString() + listener.toString() (AudioManager.getIdForAudioFocusListener), donc la lambda neuve de chaque requestFocus() est un client distinct ; MediaFocusControl.propagateFocusLossFromGain_syncAf envoie AUDIOFOCUS_LOSS à l'ancien, et FocusRequester.frameworkHandleFocusLoss le laisse bien distribuer quand le gagnant a le même uid. L'ancien écouteur, toujours enregistré puisque focusRequest a été écrasé sans abandon, appelle stop(fade = false), qui libère le lecteur tout juste relancé et abandonne la nouvelle demande ; le second appui passe par ensureMusic() et repart du début (ou tire un autre morceau en aléatoire). Enchaînement déterministe à la lecture du code, non exécuté sur appareil ; le seul test qui touche MusicPlayer (MelangeMusiqueTest) lit le fichier comme texte et ne couvre pas reprendre().

### FSEANCE-03 — « Écrire » : le Bravo s'ouvre par-dessus la note en cours de saisie, puis en propose une seconde, vide

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** « Commencer simplement → Écrire » démarre la séance et ouvre NoteDialog sur l'écran de séance. Un dialogue ne met pas l'écran en pause : render() repasse chaque seconde et, au terme de la séance (15 min par défaut), lance CelebrationActivity par-dessus la note qu'on est en train d'écrire. « Continuer » ouvre alors un second NoteDialog pour le même jour, prérempli avec la note enregistrée, donc vide ; le texte tapé est resté dans le premier, sous le Bravo. Enregistrer dans l'un puis dans l'autre écrase la note et les humeurs (Store.setNote et JournalPlus.ecrire remplacent).

**Preuve.** K/SessionActivity.kt:138-140 « findViewById&lt;View>(R.id.simplement_ecrire).setOnClickListener { demarrer { NoteDialog.show(this, Store.today(), onSaved = {}) } } » ; :271 « if (!running) CelebrationActivity.showIfPending(this) » (aucun test d'un dialogue ouvert) ; K/CelebrationActivity.kt:98 « NoteDialog.show(this, dateNote, onSaved = {}, onClosed = { finish() }) » ; K/NoteDialog.kt:43 « val initiale = Store.record(activity, date)?.note.orEmpty() ».

**Correction proposée.** Garder dans SessionActivity la référence du dialogue ouvert par « Écrire » ; tant qu'il est affiché, ne pas appeler showIfPending (le Bravo attend sa fermeture), puis ouvrir le Bravo sans EXTRA_NOTE_DATE puisque la note vient d'être proposée.

**Note du contre-expert.** Vérifié : SessionActivity.kt:138-140 ouvre NoteDialog sur l'écran de séance, le tick n'est retiré que dans onPause (un dialogue de la même activité ne la met pas en pause), et la ligne 271 lance le Bravo sans aucun garde ; « Continuer » (CelebrationActivity.kt:98) ouvre un second NoteDialog relu depuis Store, et Store.setNote comme JournalPlus.ecrire remplacent. Le commentaire de confirmFinish (lignes 432-433, revue du 29/09) montre que le propriétaire avait déjà corrigé ce même empilement pour « Terminer » : le mode « Écrire » du 19/10 le réintroduit, sur son chemin nominal (écrire jusqu'au terme des 15 min par défaut). Précisions : rien n'est perdu d'office, le texte réapparaît dans le premier dialogue à la fermeture du Bravo, et « donc vide » suppose qu'aucune note n'était déjà enregistrée ce jour-là.

### FSEANCE-04 — La note de séance en cours de saisie est perdue à la moindre recréation de l'écran, et la garde « modifié » ne couvre qu'un champ sur cinq

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** NoteDialog est un AlertDialog construit à la main, sans DialogFragment ni brouillon. Toute recréation de l'écran hôte le détruit avec ce qui a été tapé (jusqu'à 4 000 caractères, deux humeurs, gratitude, « à travailler ») : rotation sur SessionActivity (mode « Écrire »), MainActivity et JournalActivity, qui ne déclarent aucun configChanges ; bascule clair/sombre ou changement de taille de police, y compris sur CelebrationActivity dont les configChanges ne couvrent ni uiMode ni fontScale ; mort du processus en arrière-plan. La protection du 29/09 ne surveille que le champ principal : avec seulement une humeur, une gratitude ou « à travailler » saisies, le retour ferme sans rien garder et le bouton dit encore « Plus tard ».

**Preuve.** K/NoteDialog.kt:107-119 « val dialog = AlertDialog.Builder(activity) … .create(); dialog.setCanceledOnTouchOutside(false); dialog.show() » ; :120-128 « input.addTextChangedListener(… val change = s.toString().trim() != initiale.trim(); dialog.setCancelable(!change) … » (seul input est écouté ; gratitude, travail et humeurs ne le sont pas). A/AndroidManifest.xml:240 configChanges="orientation|screenSize|smallestScreenSize|screenLayout|keyboardHidden" sur CelebrationActivity seule ; :244 SessionActivity sans configChanges. Aucune occurrence de « brouillon » ni « draft » dans K.

**Correction proposée.** Enregistrer un brouillon par date à chaque frappe (dans le fichier du journal, hors sauvegarde nuage), le reprendre à la réouverture, l'effacer à l'enregistrement ; passer NoteDialog en DialogFragment ; étendre la garde « modifié » aux humeurs, à la gratitude et à « à travailler ».

**Note du contre-expert.** Vérifié : NoteDialog est un AlertDialog nu (NoteDialog.kt:107-119), aucune occurrence de brouillon ni de draft dans K, aucune orientation verrouillée (ni screenOrientation ni setRequestedOrientation) et aucun configChanges hors CelebrationActivity (manifeste:240, sans uiMode ni fontScale) ; MainActivity.kt:57-66 écrit même qu'« une rotation ne la rouvre pas ». Le TextWatcher (120-129) n'écoute que le champ principal : humeurs, gratitude et « à travailler » partent au retour, bouton resté « Plus tard ». Gravité tenue : le mode « Écrire » fait de ce dialogue un lieu d'écriture longue, resizeableActivity="true" ajoute le redimensionnement de fenêtre aux causes de recréation, et la recommandation respecte la règle du dépôt (le fichier du journal est hors sauvegarde nuage, xml/data_extraction_rules.xml).

### FSEANCE-05 — Décompte masqué + séance sans durée : « Un son vous préviendra » alors qu'aucun son ne viendra jamais

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : texte

**Constat.** Quand « Masquer le décompte » est actif, une séance « Sans durée » affiche la même légende qu'une séance minutée : « Le décompte est masqué. Un son vous préviendra. » Or une séance ouverte ne s'arrête que par le geste de l'utilisateur, et le son n'est joué que pour une fin naturelle. Celui qui pose le téléphone en attendant le son attend indéfiniment ; rien à l'écran ni dans la notification ne dit que la séance est sans durée.

**Preuve.** K/SessionActivity.kt:292 « SessionRule.Compteur.MASQUE -> getString(R.string.session_hidden_caption) » ; K/SessionRule.kt:37-39 « masque -> Compteur.MASQUE ; ouverte -> Compteur.ECOULE » (le masquage l'emporte) ; :50-51 « if (estOuverte(debutMillis, duree)) true » ; K/SessionService.kt:197 « if (!early && Store.hideCountdown(this)) chime() ». values/strings.xml:168 « Le décompte est masqué. Un son vous préviendra. » ; values-en/strings.xml:156 « The countdown is hidden. A sound will tell you. »

**Correction proposée.** Nouvelle chaîne session_open_hidden_caption, choisie quand Store.isSessionOpen : FR « Sans durée, décompte masqué : vous arrêtez quand vous arrêtez. » ; EN « No set length, countdown hidden: you stop when you stop. » ; HE « בלי זמן קצוב, הספירה מוסתרת: מפסיקים כשמפסיקים. » Même distinction pour session_running_hidden dans la notification.

**Note du contre-expert.** Vérifié : SessionRule.compteur fait passer le masquage avant la séance ouverte (37-39), SessionActivity.kt:292 affiche alors session_hidden_caption dans tous les cas, une séance ouverte reste « en cours » tant que le service vit (SessionRule.kt:50-51, le plafond de 240 min n'est appliqué que par reconcilier()), et chime() n'est appelé que pour une fin naturelle (SessionService.kt:197) : la phrase « Un son vous préviendra » est donc fausse pendant toute la séance, dans les trois langues. Portée étroite (deux choix non par défaut, et l'utilisateur vient de toucher « Sans durée »), mais c'est un texte faux et une promesse non tenue au sens du barème. Les trois réécritures sont correctes et reprennent le vocabulaire déjà en place ; variante plus simple, sans nouvelle chaîne : réutiliser session_open_caption quand Store.isSessionOpen.

### FSEANCE-06 — Le signal de fin de séance n'est pas fiable : émis avant la levée du « Ne pas déranger », dépendant du canal « Rappels », muet en silencieux

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : android · **Type** : fonction

**Constat.** La séance minutée n'a pas de signal de fin à elle. (a) Avec « Ne pas déranger », la notification de fin et le son partent avant que le mode d'avant soit rétabli : ils sont donc émis en mode « priorité », sans son. (b) Hors décompte masqué, le seul son est celui de la notification, postée sur le canal « Rappels » partagé avec le rappel quotidien : notifications refusées (Android 13+) ou canal coupé parce que les rappels gênent, et une séance sans musique se termine sans rien, téléphone posé. (c) Décompte masqué : le « son discret » promis est la sonnerie de notification jouée par Ringtone, muette en mode silencieux ou vibreur, sans vibration de repli ; quand elle sonne, elle double celle de la notification. (d) La notification « Vous avez parlé avec Hachem aujourd'hui » est aussi postée, avec son, quand on termine soi-même dans l'application, Bravo déjà à l'écran. L'ordre des appels est vérifié dans le code ; l'effet sonore découle du comportement d'Android, non mesuré sur appareil.

**Preuve.** K/SessionService.kt:189-199 « inscrire(this, close, theme = theme); notifyCompleted(close) } … if (!early && Store.hideCountdown(this)) chime(); StreakWidget.refresh(this); stopSelfAndClear() » ; :306-307 « relacherEveil(); NePasDeranger.retablir(this) » ; :327 « Notification.Builder(this, Notifications.CHANNEL_REMINDER) » ; :209 « RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION) ». values/strings.xml:227 « Rappel quotidien et fin de hitbodedout. » ; :167 « Rien à l’écran pendant la hitbodedout, un son discret à la fin. »

**Correction proposée (revue par le contre-expert).** Dans finishSession, appeler NePasDeranger.retablir(this) avant notifyCompleted() et chime() : une ligne, qui supprime la course. Quand chime() joue, poster la notification de fin sans son (canal « session », déjà en IMPORTANCE_LOW, ou setSilent à partir de l'API 30) pour ne pas doubler le son. Quand la séance est terminée depuis l'écran de l'application (finishNow appelé par SessionActivity, à distinguer par un extra du bouton de la notification), ne pas poster la notification de fin ou la poster sans son, et annuler ID_COMPLETED à l'ouverture du Bravo ou de la note. Un signal de fin propre (son embarqué ou vibration, réglable), indépendant de l'autorisation de notifications, est une décision de produit à soumettre au propriétaire, pas une correction de bogue.

**Note du contre-expert.** Les lignes citées sont exactes (notifyCompleted et chime avant retablir, canal CHANNEL_REMINDER, Ringtone TYPE_NOTIFICATION, notification postée aussi quand early = true et jamais annulée : aucun cancel de ID_COMPLETED dans K), mais l'effet (a) n'est pas établi : dans le source AOSP, l'interception « Ne pas déranger » est réévaluée à l'affichage (PostNotificationRunnable → extractSignals → ZenModeExtractor, jusqu'à 200 ms après notify() quand un assistant de notifications est actif), donc le plus souvent après retablir(), et Ringtone joue en USAGE_NOTIFICATION_RINGTONE, que le mode priorité ne coupe que si appels et rappels répétés sont bloqués. (c) est en partie le comportement attendu d'un téléphone en silencieux, et en vibreur la notification vibre par repli (NotificationAttentionHelper) ; (b) est un choix écrit dans la description du canal (« Rappel quotidien et fin de hitbodedout »), et le son choisi pour chime() est motivé dans son commentaire. Restent des défauts réels mais mineurs : ordre fragile, double son quand le décompte est masqué, notification sonore alors qu'on termine dans l'application, aucun signal de fin si les notifications sont refusées et sans musique ; avec les réglages par défaut le signal fonctionne.

### FSEANCE-07 — Écran Musique pendant une séance : l'aperçu coupe la musique de la séance, le choix d'un morceau et le volume ne sont pas appliqués

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Pendant une séance, l'écran Musique (accueil → Musique) reste ouvert à tout. (a) « Écouter » crée un second MusicPlayer qui demande le focus audio : celui de la séance reçoit AUDIOFOCUS_LOSS et se libère ; l'aperçu fini, rien ne relance la musique de la séance (ensureMusic n'est appelé que dans onStartCommand). L'aperçu d'ambiance, lui, est bien interdit en séance. (b) Choisir un autre morceau n'avertit pas le service (sauf en sortant de l'aléatoire) : l'ancien continue, mais la ligne « Musique : … » de l'écran de séance affiche le nouveau, pendant que le mini-lecteur affiche l'ancien. (c) Le curseur de volume n'agit pas sur le morceau en cours (seule l'ambiance suit) : le service ne rappelle jamais setVolume.

**Preuve.** K/MusicActivity.kt:195-196 « val player = MusicPlayer(this); val started = player.start(track, Store.musicVolume(this), loop = false) » sans test de séance, contre :127 « if (Store.isSessionRunning(this) || a == Ambiance.SILENCE) return » ; :278 « Store.setMusicTrackId(this@MusicActivity, track.id) » sans musicChanged ; :93-94 « Store.setMusicVolume(this@MusicActivity, value); preview?.setVolume(value) ». K/MusicPlayer.kt:149 « AudioManager.AUDIOFOCUS_LOSS -> stop(fade = false) ». K/SessionService.kt:217 « if (!Store.musicEnabled(this) || music.isPlaying || music.charge) return ». K/SessionActivity.kt:411-416 (hors aléatoire, la ligne affiche MusicLibrary.selected, pas Store.musicNow).

**Correction proposée.** En séance, faire jouer l'aperçu par le service (le morceau touché devient le morceau en cours) ou le désactiver comme l'aperçu d'ambiance. Appeler SessionService.musicChanged depuis select() et onStopTrackingTouch ; dans ACTION_MUSIC, appliquer music.setVolume(Store.musicVolume) et relancer si Store.musicTrackId diffère de Store.musicNow. Dans renderMusicLine, afficher Store.musicNow dans tous les modes.

### FSEANCE-08 — Pratique calme : le premier toucher est avalé même sur les boutons restés visibles

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Après six secondes sans toucher, l'écran passe en mode calme et le geste suivant est avalé en entier, où qu'il tombe. La justification écrite (« on ne touche pas un bouton qu'on ne voyait pas ») ne vaut pas pour ce qui reste affiché : « Terminer maintenant », les boutons « Précédent / Suivant » de la hitbodedout guidée, « Question suivante », le disque et la barre de position du mini-lecteur. En hitbodedout guidée, où l'on touche « Suivant » toutes les quelques minutes, chaque passage demande deux appuis ; un glissé sur la barre de position est perdu.

**Preuve.** K/PratiqueCalme.kt:49-57 « if (e.actionMasked == MotionEvent.ACTION_DOWN) { avale = calme; if (calme) sortir(anime = true) … } val garde = avale … return garde » ; K/SessionActivity.kt:246-247 « override fun dispatchTouchEvent(ev: MotionEvent): Boolean = calme.toucher(ev) || super.dispatchTouchEvent(ev) » ; :97-98 la liste des vues effacées ne contient ni session_primary, ni session_hitbodedut, ni session_questions, ni le mini-lecteur.

**Correction proposée.** N'avaler le geste que s'il tombe sur une vue de la liste effaces() (test de zone à ACTION_DOWN) ; sur une vue restée visible, réveiller l'écran et laisser passer le geste.

### FSEANCE-09 — Pratique calme : le texte de 'hizouk de « Je n'arrive pas à parler » s'efface six secondes après être apparu

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction · déjà connu ou choix assumé

**Constat.** Choix délibéré du 16/10 (tout s'efface sauf le minuteur, « Terminer » et le guide), mais critiquable pour ce qui se lit : la carte de 'hizouk et le bouton « Je n'arrive pas à parler » sont dans la liste des vues effacées. Les 64 textes du moment « blocage » font de 12 à 157 mots en français (la plupart entre 40 et 100), plus l'hébreu : celui qui lit sans toucher l'écran voit le texte disparaître au bout de six secondes, et le bouton d'aide lui-même n'est retrouvable qu'après un premier toucher avalé. Même sort pour le mot d'ouverture.

**Preuve.** K/SessionActivity.kt:97-98 « listOf(R.id.session_titre, R.id.session_scene, R.id.session_caption, R.id.session_music, R.id.session_secondary, R.id.session_theme, R.id.session_chizuk, R.id.session_stuck) » ; K/PratiqueCalme.kt:132 « const val DELAI_MS = 6_000L » ; RAW/chizuk.json : 64 items de moment « blocage », 12 à 157 mots (champ fr).

**Correction proposée.** Retirer session_chizuk et session_stuck de la liste tant qu'un texte « blocage » ou « ouverture » vient d'être tiré : ne relancer le délai qu'après un temps proportionné à la longueur du texte (par exemple 6 s + 0,4 s par mot), ou garder la carte jusqu'au toucher suivant.

### FSEANCE-10 — Une rotation en pleine séance remplace le texte affiché par un nouveau mot d'ouverture

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** SessionActivity ne déclare pas de configChanges : rotation, écran partagé ou bascule de thème rejouent onCreate. Le commentaire annonce que le guide et le mot de clôture ne sont pas retirés une seconde fois, mais drawOpening() est appelé sans condition : la carte de 'hizouk qu'on lisait (texte « blocage », mot de clôture) est remplacée par un mot d'ouverture nouvellement tiré, et le sac d'ouverture est entamé à chaque rotation. Le mini-lecteur déplié se replie aussi (deplie n'est pas conservé).

**Preuve.** K/SessionActivity.kt:102-104 « Sans cela, le guide repartirait au premier temps et le mot de clôture serait tiré une seconde fois. » ; :149 « drawOpening() » hors de tout test de savedInstanceState, alors que :154 « if (savedInstanceState == null) lireDemande(intent) » ; K/ChizukCard.kt:30 « val item = ChizukBag.draw(context, moment, chizuk, BuildConfig.DEBUG) ».

**Correction proposée.** Conserver dans onSaveInstanceState l'identifiant et le moment du texte affiché et le reposer par ChizukCard.bind ; n'appeler drawOpening() dans onCreate que si savedInstanceState == null.

### FSEANCE-11 — Rien de ce qui s'inscrit ne se corrige : temps ajouté par erreur, séance sans durée oubliée (240 min), « Terminer » de la notification sans confirmation

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Les minutes ne font que s'ajouter et aucune commande ne les retire. (a) « Ajouter du temps fait hors du téléphone » inscrit aussitôt, sur n'importe quel jour passé, sans annulation : 90 au lieu de 9 reste au journal, dans le total, la série et les trophées. Store.unmarkToday existe mais n'a aucun appelant. (b) Une séance « Sans durée » oubliée n'offre que deux sorties : « Abandonner » (les vraies minutes sont perdues) ou « Terminer », qui inscrit le plafond de 240 minutes ; le plafond est voulu (FiabiliteTest), pas l'impossibilité de dire la durée réelle. Pendant ce temps le compteur et la notification affichent le temps total, pas ce qui sera inscrit. (c) L'action « Terminer maintenant » de la notification clôt la séance sans la confirmation que l'écran demande : un toucher dans le volet inscrit 3 minutes sur 60 et valide la journée, sans reprise possible.

**Preuve.** K/AjoutTemps.kt:31-32 « DureeSeance.choisir(activity, R.string.offline_how_long) { m -> Store.addSession(activity, m, theme = null, date = iso) » ; K/Store.kt:338 « fun unmarkToday(context: Context) » (seule occurrence dans android/app/src) ; K/SessionRule.kt:75 « return if (finMillis > 0L) minutes else minutes.coerceAtMost(PLAFOND_OUVERTE) » ; K/SessionService.kt:359-363 « PendingIntent.getService(this, 1, Intent(this, SessionService::class.java).setAction(ACTION_FINISH), … » contre K/SessionActivity.kt:427-438 confirmFinish().

**Correction proposée.** Dans la fiche du jour (AjoutTemps.ouvrir), ajouter « Corriger la durée » qui remplace les minutes (0 = journée retirée, avec confirmation). À la clôture d'une séance ouverte de plus de deux heures, demander la durée réelle au lieu d'inscrire le plafond. Faire ouvrir par l'action de la notification l'écran de séance sur sa confirmation.

### FSEANCE-12 — « Le temps déjà écoulé sera enregistré et la journée validée » : faux avant une minute ; « la journée restera à faire » : faux si elle est déjà faite

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** Le dialogue « Terminer la hitbodedout ? » promet l'enregistrement et la validation. Arrêtée avant 60 secondes, la séance n'inscrit rien : pas de journée, pas de Bravo, pas de message, seulement un mot de clôture. Les secondes sont tronquées dans tous les cas (14 min 59 s comptent 14 min). À l'inverse, « Abandonner » annonce « la journée restera à faire » même quand une séance précédente l'a déjà validée.

**Preuve.** K/SessionService.kt:189 « if (close.minutes > 0 || !early) { inscrire(this, close, theme = theme) » ; K/SessionRule.kt:74 « val minutes = ((borne - debutMillis) / 60_000L).toInt().coerceAtLeast(0) ». values/strings.xml:158 « Le temps déjà écoulé sera enregistré et la journée validée. » ; :160 « Rien ne sera enregistré et la journée restera à faire. » ; values-en/strings.xml:146 et :148.

**Correction proposée.** Avant une minute, autre message : FR « Moins d’une minute s’est écoulée : rien ne sera enregistré. » ; EN « Less than a minute has passed: nothing will be recorded. » ; HE « עברה פחות מדקה: דבר לא יישמר. » Pour l'abandon quand la journée est déjà faite : FR « Rien ne sera enregistré pour cette hitbodedout. » ; EN « Nothing will be recorded for this hitbodedut. » ; HE « דבר לא יישמר מההתבודדות הזאת. »

### FSEANCE-13 — Tout le décompte repose sur l'horloge murale : avancer l'heure clôt la séance et crédite la durée entière

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Début et fin sont des System.currentTimeMillis() ; rien n'utilise elapsedRealtime. Avancer l'heure du téléphone de la durée choisie fait finir la séance au tour suivant, avec toutes ses minutes et le Bravo. La reculer allonge le décompte affiché (une séance de 15 min peut afficher 75:00) alors que le verrou d'éveil, calculé au départ, expire à l'ancienne échéance. BootReceiver reçoit TIME_SET mais reconcilier() sort aussitôt si le service tourne : rien n'est recalé. L'heure d'été, le fuseau et le redémarrage sont sans effet (bon point). La fraude n'a pas d'enjeu puisque la journée peut aussi être déclarée, mais le README affirme le contraire (constat suivant).

**Preuve.** K/Store.kt:1167-1171 « val now = System.currentTimeMillis() … .putLong(KEY_SESSION_END, if (ouverte) 0L else now + minutes * 60_000L) » ; K/SessionRule.kt:73 « val borne = if (finMillis > 0L) minOf(maintenant, finMillis) else maintenant » ; K/SessionService.kt:150 « val duree = (fin - System.currentTimeMillis()).coerceAtLeast(0L) + MARGE_EVEIL_MS » ; :417 « if (enMarche || !Store.hasSessionRecord(context)) return ». Aucune occurrence de elapsedRealtime dans les fichiers de la séance.

**Correction proposée.** Garder à côté du début mural le SystemClock.elapsedRealtime() du départ (et le compteur de démarrages) : tant que le téléphone n'a pas redémarré, calculer le temps passé et le reste sur cette horloge ; ne retomber sur l'horloge murale qu'après un redémarrage.

### FSEANCE-14 — README : « La journée est validée par le temps réellement passé, pas par une simple déclaration » est contredit par le code et par le paragraphe précédent

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : docs · **Type** : texte

**Constat.** Trois chemins valident une journée sans aucun temps mesuré : « Je l'ai déjà faite » sur l'écran de garde (0 minute), « Je l'ai faite sans le téléphone » et « Ajouter du temps » (durée déclarée). Une journée compte dès qu'elle a une ligne qui n'est pas une note seule. Le même README cite d'ailleurs, quatre lignes plus haut, l'issue « déclarer qu'elle est déjà faite ».

**Preuve.** README.md:24 « La journée est validée par le temps réellement passé, pas par une simple déclaration. » ; README.md:18 « déclarer qu'elle est déjà faite » ; K/GateService.kt:138-139 « onAlreadyDone = { Store.addSession(this, 0) » ; K/Store.kt:43 « val faite: Boolean get() = !noteSeule ».

**Correction proposée.** Réécrire : « La journée est validée par une séance faite dans l'application, pour le temps réellement passé, ou par une déclaration : “Je l'ai déjà faite” sur l'écran de garde, ou du temps ajouté à la main pour une hitbodedout faite sans le téléphone. »

### FSEANCE-15 — Documents en retard sur la séance et la musique : mini-lecteur « non commencé » alors qu'il est livré, durée par défaut, nombre de morceaux

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : docs · **Type** : texte

**Constat.** État réel du mini-lecteur : il existe (MiniLecteur.kt, 330 lignes, branché sur l'écran de séance : disque tournant, pochette ou hassid à la guitare, barre de position, précédent, lecture, suivant, aléatoire), sur Android et sur le seul écran de séance, sans aucun test (ni MiniLecteur, ni les commandes du service, ni MusicPlayer ne sont cités dans src/test). La feuille de route le range pourtant dans « non commencé », et le code le date du 19/10 quand la feuille de route le date du 04/11. Quatre autres affirmations sont périmées : durée par défaut « soixante minutes » (15 dans le code) ; « un morceau livré avec l'application » (26 dans la version Play, 56 dans la version GitHub) ; « 33 morceaux livrés (130 Mo) » ; « version Play bien moins lourde (2 morceaux) » (26 morceaux, environ 71 Mo dans res/raw).

**Preuve.** FEUILLE_DE_ROUTE.md:1156-1159 « Reste à faire, demandé par l'utilisateur, non commencé : … 3. Mini-lecteur de musique pendant la hitbodedout » ; K/MiniLecteur.kt:29 « Le mini-lecteur de la pratique (demande du 19/10) » ; K/SessionActivity.kt:113 « miniLecteur = MiniLecteur(this) ». README.md:23 « par défaut soixante minutes » contre K/Store.kt:174 « const val DEFAULT_TARGET = 15 » ; README.md:72-73 « un morceau livré avec l'application » ; PUBLICATION_PLAY_STORE.md:31 « 33 morceaux livrés (130 Mo) » et :59 « version Play bien moins lourde (2 morceaux) » contre K/MusiquePlay.kt (26 lignes Bundled).

**Correction proposée.** Feuille de route : déplacer le mini-lecteur dans « Fait » avec sa date réelle et ce qui manque (tests, pause/reprise à corriger, absent hors de l'écran de séance). README : « par défaut quinze minutes » ; « des morceaux livrés avec l'application (26 dans la version Play) ». PUBLICATION_PLAY_STORE.md lignes 31 et 59 : reprendre les chiffres du § 3.2.

### FSEANCE-16 — Le type de service « mediaPlayback » est déclaré au manifeste et dans la déclaration Play, mais le service ne démarre jamais avec lui

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : play · **Type** : fonction

**Constat.** Le manifeste déclare specialUse|mediaPlayback et la permission FOREGROUND_SERVICE_MEDIA_PLAYBACK, et le cahier de publication prévoit pour Play une déclaration et une vidéo pour chacun des deux types. Le code ne passe que SPECIAL_USE à startForeground, musique ou non. La déclaration mediaPlayback décrit donc un usage que l'application n'exerce pas sous ce type, et la lecture de musique tourne sous un type « usage spécial » que Google réserve à ce qu'aucun autre type ne couvre : deux motifs de question à l'examen.

**Preuve.** A/AndroidManifest.xml:7 « android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK » ; :368 « android:foregroundServiceType="specialUse|mediaPlayback" » ; K/SessionService.kt:381 « startForeground(Notifications.ID_SESSION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE) » (seul appel) ; PUBLICATION_PLAY_STORE.md:415 « SessionService | mediaPlayback | Lecture du morceau choisi par l'utilisateur pendant sa séance, écran éteint. »

**Correction proposée.** Quand un morceau joue, passer FOREGROUND_SERVICE_TYPE_SPECIAL_USE or FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK (sauf à la relance depuis BOOT_COMPLETED, où Android 15 interdit mediaPlayback : y rester en SPECIAL_USE et ne lancer la musique qu'au retour à l'écran). Sinon, retirer mediaPlayback du manifeste, la permission et la ligne du § 6.6.

### FSEANCE-17 — Relance START_STICKY : startForeground n'est pas protégé, plantage probable sous Android 12+ quand le service est relancé en arrière-plan

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Si le processus est tué pendant une séance puis relancé par Android (intent nul), onStartCommand appelle startForegroundNow() sans try/catch. Depuis Android 12, une application en arrière-plan ne peut plus passer un service au premier plan : l'appel lève ForegroundServiceStartNotAllowedException et l'application plante une seconde fois. reconcilier(), lui, protège bien son startForegroundService par runCatching. Par ailleurs la fin de séance n'a aucun filet hors processus (pas d'alarme) : service mort, ni son ni notification à l'échéance, la séance n'est constatée qu'à la prochaine ouverture.

**Preuve.** K/SessionService.kt:81-84 (seul garde : « if (intent == null && !Store.hasSessionRecord(this)) { stopSelf(); return START_NOT_STICKY } ») ; :124 « startForegroundNow() » ; :380-384 « startForeground(Notifications.ID_SESSION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE) » hors de tout runCatching ; :431-433 « runCatching { context.startForegroundService(Intent(context, SessionService::class.java)) } ».

**Correction proposée.** Entourer startForeground d'un try/catch : en cas de refus, stopSelf() sans toucher à la séance inscrite (reconcilier la reprendra). Poser à beginSession une alarme (setAlarmClock ou setExactAndAllowWhileIdle) à l'échéance, qui inscrit la séance et poste le signal de fin même si le service est mort.

### FSEANCE-18 — Morceau du téléphone devenu illisible : séance muette, sans repli ni signalement dans la bibliothèque

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Un morceau ajouté n'est qu'une adresse content:// et une permission persistante. La liste part dans la sauvegarde Android et le transfert d'appareil (fichier de réglages inclus en entier), pas la permission : après restauration ou réinstallation, ou si le fichier a été supprimé, le morceau reste dans la bibliothèque et peut rester « le » morceau des séances. Hors lecture aléatoire, la séance démarre alors sans musique, avec un simple message fugitif, sans repli sur un morceau livré ; la bibliothèque ne marque pas le morceau cassé. En aléatoire, trois tirages illisibles de suite arrêtent la musique jusqu'à la fin. Retirer un morceau ne rend pas non plus la permission (releasePersistableUriPermission absent).

**Preuve.** K/SessionService.kt:224-229 « val track = MusicLibrary.selected(this) ?: return … if (!music.start(track, Store.musicVolume(this))) { Toast.makeText(this, R.string.music_play_failed, Toast.LENGTH_LONG).show() } » ; :246-248 (trois essais) ; A/res/xml/backup_rules.xml « &lt;include domain="sharedpref" path="myhitbodedut.xml" /> » avec K/Store.kt:155 « KEY_MUSIC_USER = "music_user_tracks" » ; K/MusicLibrary.kt:68-77 removeUserTrack sans libération de permission.

**Correction proposée.** Dans MusicLibrary.userTracks, comparer à contentResolver.persistedUriPermissions et marquer les morceaux sans accès (« introuvable : le choisir à nouveau ») ; dans ensureMusic, si le morceau retenu échoue, jouer le premier morceau livré et le dire ; appeler releasePersistableUriPermission dans removeUserTrack.

### FSEANCE-19 — L'écran reste allumé en permanence sur l'écran de séance, même sans séance, et plusieurs boucles tournent sans nécessité

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** FLAG_KEEP_SCREEN_ON est posé une fois pour toutes dans onCreate : l'écran ne s'éteint jamais tant que l'écran de séance est devant, y compris au repos (choix de la durée) ou après la fin. Un téléphone laissé là se vide. Pendant la séance, écran allumé plus lueur animée en continu plus disque tournant, alors que le service a été conçu « pour que le téléphone puisse être posé ». S'y ajoutent : la notification reconstruite et repostée toutes les 5 secondes alors que son texte change une fois par minute ; la boucle à 250 ms du mini-lecteur déplié, qui n'est arrêtée qu'à la destruction de l'écran (elle continue écran éteint tant que le verrou d'éveil tient) ; MusicLibrary.all() recalculée jusqu'à trois fois par seconde par render(). Le verrou d'éveil sur toute la séance est, lui, un choix documenté (revue du 29/09).

**Preuve.** K/SessionActivity.kt:73 « window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) » (jamais retiré) ; K/SessionService.kt:173 « startForegroundNow() » dans refresh(), avec :388 « TICK_MS = 5_000L » ; K/MiniLecteur.kt:69-73 « maj(); if (deplie) handler.postDelayed(this, 250L) » et :236-237 fermer() appelé du seul onDestroy (SessionActivity.kt:241), onPause (:232-237) ne l'arrête pas.

**Correction proposée.** Lier le drapeau à l'état : addFlags quand running, clearFlags sinon, et proposer un réglage « Laisser l'écran s'éteindre pendant la séance ». Ne reposter la notification que lorsque son texte change (ou setUsesChronometer avec setChronometerCountDown). Arrêter suivi dans onPause et le relancer dans onResume.

### FSEANCE-20 — Neuf titres de morceaux livrés restent en français pour les lecteurs anglais et hébreux, dont une note de travail « (titre incertain) »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** Toutes les clés de chaînes existent dans les trois langues (0 manquante sur 1 268), mais 26 titres de morceaux de la version Play sont marqués translatable="false". Neuf contiennent du français, affiché tel quel en anglais et en hébreu : « Niggoun de… », « du Baal Chem Tov », « du Saba de Chpola », et la note interne « (titre incertain) ». Les anciens titres « Niggoun 01 », eux, sont bien traduits (« Niggun 01 », « ניגון 01 ») : la convention existe, ces neuf-là y échappent. La translittération française ('Houppa, Chabbat, Yo'hanan) y est aussi imposée à l'anglais.

**Preuve.** values/strings.xml:334 « Niggoun « Ki hiné ka\'homer » — Noam Shpayer » ; :338 « Niggoun du Baal Chem Tov — Ianir » ; :339 « Zemer bichva\'hin (titre incertain) — Ianir » ; :340 « Niggoun de Berditchev — Ianir » ; :341 « Kol baYa\'ar (Niggoun du Saba de Chpola) — Ianir » ; :342 « Niggoun de Rabbi Yo\'hanan HaSandlar — Ianir » ; :344 « Niggoun de \'Houppa — Ianir » ; :347 « Niggoun de Kabbalat Chabbat (live) — Ianir » ; :348 « Niggoun de Bessarabie — Ianir », toutes translatable="false" ; values-en/strings.xml:501 « Niggun 01 ».

**Correction proposée.** Retirer translatable="false" de ces neuf clés et les traduire. EN : « Niggun “Ki hineh kachomer” — Noam Shpayer », « Niggun of the Baal Shem Tov — Ianir », « Zemer bishvachin — Ianir », « Berditchev niggun — Ianir », « Kol baYa’ar (niggun of the Saba of Shpola) — Ianir », « Niggun of Rabbi Yochanan HaSandlar — Ianir », « Chuppah niggun — Ianir », « Kabbalat Shabbat niggun (live) — Ianir », « Bessarabian niggun — Ianir ». HE : « ניגון „כי הנה כחומר” — נעם שפייר », « ניגון הבעל שם טוב — יניר », « זמר בשבחין — יניר », « ניגון ברדיטשוב — יניר », « קול ביער (ניגון הסבא משפולי) — יניר », « ניגון רבי יוחנן הסנדלר — יניר », « ניגון חופה — יניר », « ניגון קבלת שבת (הופעה חיה) — יניר », « ניגון בסרביה — יניר ». Supprimer « (titre incertain) » du titre français ou trancher le titre.

### FSEANCE-21 — Accessibilité de la séance : humeurs annoncées « 1/5 » sans état, notes « ♪ » du Bravo exposées au lecteur d'écran, boutons du guide trop petits

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** (a) Dans la note, les cinq humeurs sont des TextView à émoji dont la description est le texte en dur « 1/5 » … « 5/5 », seule chaîne non traduite de la dimension ; la sélection ne se voit qu'à l'opacité (1 contre 0,35) et n'est ni annoncée ni exposée comme état. (b) Sur le Bravo, chaque note ou étoile qui monte est un TextView ajouté à la scène toutes les 660 ms sans importantForAccessibility : TalkBack peut s'y arrêter et reçoit un flot de changements, alors que la vue des confettis, elle, est correctement exclue. (c) « Précédent » et « Suivant » de la hitbodedout guidée sont des TextView de 14 sp avec 8 dp de marge verticale, soit environ 35 dp de haut, sous les 48 dp requis, et sans rôle de bouton.

**Preuve.** K/NoteDialog.kt:67-68 « alpha = if (initiale == i + 1) 1f else 0.35f ; contentDescription = "${i + 1}/5" » ; K/CelebrationActivity.kt:163-168 « val note = TextView(this).apply { text = SIGNES[Random.nextInt(SIGNES.size)] … } » contre K/Confettis.kt:46 « importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO » ; A/res/layout/view_hitbodedut.xml « android:id="@+id/hitbodedut_previous" … android:paddingVertical="8dp" … android:textSize="14sp" ».

**Correction proposée.** Humeurs : des boutons à bascule avec libellés traduits (FR « Humeur 1 sur 5, très lourde » … « 5 sur 5, très légère » ; EN « Mood 1 of 5, very heavy » … « 5 of 5, very light ») et isSelected tenu à jour. Notes du Bravo : importantForAccessibility = NO. Guide : minHeight 48dp et style de bouton texte.

### FSEANCE-22 — Lecteur de musique : ressources non libérées ou non bornées (4 cas)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** (1) Si setDataSource ou prepare lève une exception, le MediaPlayer à moitié construit n'est jamais libéré : un par morceau illisible, jusqu'à trois d'affilée en aléatoire. (2) Fin de fondu : release() abandonne le focus courant, pas celui du lecteur qu'on libère ; couper puis rallumer la musique en moins de 0,6 s (durée du fondu) retire le focus au morceau qui vient de démarrer, qui ne réagit plus aux appels ni aux autres lecteurs. (3) L'aperçu de l'écran Musique n'a pas d'écouteur de fin : le morceau terminé, le bouton reste sur « pause » et le MediaPlayer reste alloué jusqu'à la sortie de l'écran. (4) Mini-lecteur : la pochette intégrée est décodée en pleine taille (une image de 3000 × 3000 pèse 36 Mo en mémoire) pour un disque de 64 dp, et gardée dans une table sans limite.

**Preuve.** K/MusicPlayer.kt:64-77 « val created = runCatching { MediaPlayer().apply { … prepare() } }.onFailure { … }.getOrNull() ?: return false » ; :130-134 « private fun release(target: MediaPlayer) { … runCatching { target.release() }; abandonFocus() } » avec :113-127 (dix pas de 60 ms) ; K/MusicActivity.kt:196 « player.start(track, Store.musicVolume(this), loop = false) » (onEnd nul, donc aucun OnCompletionListener, MusicPlayer.kt:80-82) ; K/MiniLecteur.kt:274 « embeddedPicture?.let { BitmapFactory.decodeByteArray(it, 0, it.size) } » et :44 « private val pochettes = HashMap&lt;String, Bitmap?>() ».

**Correction proposée.** (1) Créer le MediaPlayer hors du runCatching et le release() dans onFailure. (2) Associer chaque AudioFocusRequest à son lecteur et n'abandonner que celui-là. (3) Passer à l'aperçu un onEnd qui appelle stopPreview(). (4) Décoder avec inSampleSize pour viser 128 px et borner la table (LruCache de quelques entrées).

### FSEANCE-23 — Préparation du morceau sur le fil principal : risque de blocage (ANR) avec un fichier venu d'un fournisseur distant

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** MusicPlayer.start appelle MediaPlayer.prepare(), synchrone, depuis onStartCommand du service et depuis le bouton d'aperçu, donc sur le fil principal. Le sélecteur de fichiers ouvert en « audio/* » propose aussi les fournisseurs distants (stockage en nuage) : pour un tel document, prepare() attend le téléchargement par le fournisseur et peut geler l'application au démarrage de chaque séance, ou à chaque enchaînement en lecture aléatoire. La lecture de la pochette, elle, est bien faite hors du fil principal.

**Preuve.** K/MusicPlayer.kt:72-74 « setDataSource(context, track.uri!!) } prepare() » ; appelé de K/SessionService.kt:227 et :243 (onStartCommand → ensureMusic) et de K/MusicActivity.kt:196 ; K/MusicActivity.kt:48 « pickAudio.launch(arrayOf("audio/*")) ».

**Correction proposée.** prepareAsync() avec OnPreparedListener (démarrage, volume et focus dans le rappel) et OnErrorListener pour l'échec ; ou, à l'ajout, copier le fichier dans le stockage privé de l'application, ce qui règle aussi la permission perdue.

### FSEANCE-24 — L'ambiance ne demande jamais le focus audio et ne suit pas la pause du mini-lecteur

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** AmbiancePlayer joue son AudioTrack sans demander le focus et sans écouteur. Musique coupée et ambiance choisie, la pluie se superpose à ce que joue une autre application sans la faire taire, contrairement à ce que dit le README (« L'application demande le focus audio, ce qui fait taire les autres lecteurs »). Quand la musique perd le focus (autre lecteur, message vocal), elle s'arrête mais l'ambiance continue par-dessus. « Pause » du mini-lecteur ne met en pause que le morceau : l'ambiance continue, et aucune commande de l'écran de séance ne permet de l'arrêter. Enfin l'écran Musique affiche « Aucune musique pendant les hitbodedout. » alors qu'une ambiance jouera.

**Preuve.** K/Ambiance.kt:158-171 (jouer() : AudioTrack.Builder()… t.play(), aucun requestAudioFocus dans le fichier) ; K/SessionService.kt:267 « CMD_PAUSE -> music.pause() » ; :108 « ambiance.start(AmbiancePlayer.choisie(this), Store.musicVolume(this)) » avant le test de musicEnabled ; README.md:78-80.

**Correction proposée.** Faire porter l'ambiance par le même focus que la musique (un seul AudioFocusRequest au niveau du service, demandé dès qu'un des deux joue) et la mettre en pause sur perte de focus et sur CMD_PAUSE. Résumé de l'écran Musique quand la musique est coupée mais qu'une ambiance est choisie : FR « Pas de morceau, ambiance : %1$s. » ; EN « No track, ambience: %1$s. »

### FSEANCE-25 — Anglais de la séance : translittérations et vocabulaire incohérents (5 points)

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** Les traductions françaises et anglaises de la dimension (185 chaînes relues, plus les 135 invitations du guide par sujet) sont justes et complètes ; restent des incohérences. (1) « Tsadik / Tsadeket » (graphie française) sur le Bravo anglais, alors que le reste de l'anglais écrit « tzaddik », « Chazak », « chizuk », « niggun ». (2) « mitsva » dans le guide anglais, « mitzvah » dans les textes de 'hizouk anglais. (3) hitbodedut_previous traduit « Back », qui se confond avec le retour : le français dit « Précédent ». (4) La séance « sans durée » a deux noms en anglais (« No set length », « open hitbodedut ») et trois en hébreu (« בלי זמן קצוב », « התבודדות פתוחה », « בלי הגבלת זמן »). (5) duration_hours_minutes anglais garde le zéro de tête français : « 1 h 05 min ». En hébreu, « השיר הבא / הקודם » du mini-lecteur côtoie « ניגון » partout ailleurs.

**Preuve.** values-en/strings.xml:465 « Well done, Tsadik! » contre :818 « Search for a tzaddik » ; RAW/guide_sujets.json:184 « Which mitsva have you let slip these last days? » et :199 ; values-en/strings.xml:171 « &lt;string name="hitbodedut_previous">Back&lt;/string> » ; :151 « No set length » contre :192 « Open hitbodedut, %1$s so far. » et :437 « an open hitbodedut » ; :536 « %1$d h %2$02d min ».

**Correction proposée.** EN : « Well done, Tzaddik! » / « Well done, Tzadeket! » (et adresse_tsadik, adresse_tsadeket) ; « Which mitzvah have you let slip these last days? » / « Give thanks for every mitzvah you were able to do. » ; hitbodedut_previous « Previous » ; blocker_session_open_subtitle « No set length, %1$s so far. The phone can wait. » et onboarding « or a hitbodedut with no set length » ; duration_hours_minutes « %1$d h %2$d min ». HE : « התבודדות בלי זמן קצוב » partout ; lecteur_suivant « הניגון הבא », lecteur_precedent « הניגון הקודם », lecteur_position « מיקום בניגון ».
