# NOKIA — Nokia (Java ME) — textes et fonctions

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

25 constats — confirmés : 6 · confirmés en partie : 2 · non contre-expertisés (mineurs et cosmétiques) : 17.

## Ce qui a été examiné

Lu en entier : les 10 fichiers Java (MyHitbodedut, Minuteur, Journal, JournalEcran, Regles, Textes, Ecran, Menu, Lecture, Musique), textes.mjs, genere-textes.mjs, genere-personnages.mjs, genere-musique.sh, build.sh, test.sh, test/Pilote.java, test/TestsRegles.java, test/textes.test.mjs, test/personnages.test.mjs, nokia/README.md, depot/README.md, le README public, version.txt, .github/workflows/nokia.yml, et les parties « Nokia », droits et musique de FEUILLE_DE_ROUTE.md et PUBLICATION_PLAY_STORE.md. Les 21 captures publiées ont toutes été ouvertes. Le .jar publié a été copié sous OUT, son manifeste et son contenu lus. textes.bin a été régénéré sous OUT (6 moments, 171 textes, identique à celui du .jar) puis décodé. Avec les métriques de la police de l'émulateur (SansSerif 12/15/18), j'ai mesuré la largeur des titres, des références et des chaînes d'interface et simulé la coupure de tous les textes (scripts OUT/nokia/Mesure.java, Tronque.java, Coupe.java, Mesure2.java). Côté Android, comparé à SessionRule.kt, ReminderRule.kt, Reminder.kt, Store.kt (streak, isExempt, addSession, joursFaits), Holidays.kt, SessionService.kt (finishSession, inscrire, reconcilier), CelebrationActivity.kt, Adresse.kt, DureeSeance.kt et aux chaînes françaises utiles. Jours chômés calculés avec web/src/js/calendrier-juif.js. Deux recherches web, sans aucun nom du projet : prise en charge Java du 3310 3G, autorisation PushRegistry pour une MIDlet non signée. Non fait : les tests n'ont pas été lancés (consigne) ; le .jar n'a tourné ni dans MicroEmulator ni sur un vrai téléphone. Le comportement réel de PushRegistry, la politique d'autorisation, le tas disponible, la taille de .jar admise, les polices et la lecture MP3/AMR du Nokia 3310 3G restent donc non vérifiés (d'où la confiance moyenne des constats sur le rappel et la compatibilité). La consommation de batterie du minuteur (tic toutes les 500 ms) n'a pas été mesurée. Aucun travail d'un auditeur précédent n'a été trouvé sous OUT : aucun dossier Nokia.

## Ce qui tient

- Minuteur calé sur l'horloge et non sur le nombre de tics (Minuteur.java:8-10, 60-67) : pas de dérive sur un téléphone lent, les pauses sont exclues, le temps restant est arrondi au supérieur (testé : « 0:01 » pour 1 ms), et destroyApp inscrit tout de suite les minutes faites.
- Textes jamais recopiés : genere-textes.mjs relit chizuk.json et strings.xml avec les règles de publication de l'application (ChizukRules.publiable : relevé de la source ET relu). Les tests vérifient que chaque ’hizouk publiable part une seule fois, sous son premier moment. La construction échoue sur tout caractère hors Latin-1 (textes.mjs:28-29). Le textes.bin du .jar publié est identique octet pour octet à celui régénéré aujourd'hui.
- Règles de journée alignées sur Android pour l'essentiel : le jour de début reçoit une hitbodedout qui passe minuit (MyHitbodedut.java:214), un Chabbat vide ne casse pas la série, le rappel est coupé le vendredi après midi, les jours sont comptés depuis midi pour éviter le piège de l'heure d'été (Journal.ilYa, Regles.prochain). Des tests datés couvrent ces cas (TestsRegles.java:73-92).
- Clavier robuste : getGameAction protégé contre les exceptions des S40 (Ecran.java:16-23), action au relâchement pour les téléphones qui avalent l'appui central, sans double déclenchement d'un écran à l'autre, raccourcis 1 à 9 sur chaque carte.
- Chaîne de construction soignée : pré-vérification CLDC par ProGuard, MIDlet-Version bornée à 0-99 après le refus de 1.0.361 (build.sh:54-56), parcours de 21 écrans en 240×320 avec contrôle que chaque touche change l'écran, refus de publication rendu visible dans le résumé du run (nokia.yml).
- Journal RMS versionné, avec migration de la v1 (sans « Vous appeler ») à la v2 testée (Journal.java:111-125, TestsRegles.java:52-66).

## Constats

### NOKIA-01 — Yom Tov ignoré : rappel les jours de fête et série cassée, alors qu'Android les exempte

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : nokia · **Type** : fonction

**Constat.** Le Nokia ne connaît que le samedi. Le rappel ne saute que le samedi et le vendredi après midi. La série ne tolère que le samedi. Android exempte tout jour « assur bemelakha » (Chabbat et Yom Tov, dont Kippour) et coupe aussi le rappel l'après-midi de leur veille. Conséquences sur le .jar publié, avec l'heure proposée par défaut (20 h) : le téléphone ouvre l'application le soir de Kippour (le rappel du dimanche 20/09/2026 tombe pendant Kol Nidre ; celui du lundi 21/09, avant la sortie de la fête) et le soir du Séder (mercredi 21/04/2027). Une fête passée sans téléphone remet la série à 0. Cela arrive 9 fois par an en diaspora hors samedi, selon le calendrier du projet (13/09, 21/09, 27/09, 04/10/2026, 22-23/04, 28-29/04, 11/06/2027). Le commentaire qui annonce le même comportement qu'Android est faux.

**Preuve.** nokia/app/src/myhitbodedut/Regles.java:47 « Pas de rappel le Chabbat, ni le vendredi après midi (comme ReminderRule sur Android) » ; :65-66 « if (jour == Calendar.SATURDAY) continue; if (jour == Calendar.FRIDAY && minutesApresMinuit >= 12 * 60) continue; » ; Journal.java:52 « un Chabbat sans hitbodedout ne casse pas la série (comme Android) », :79 « else if (!chabbat(j)) break; ». Côté Android : K/Store.kt:633 « return shabbatMode(context) && Holidays.isRestDay(date, inIsrael(context)) », K/Holidays.kt:20-21 « isRestDay … isAssurBemelacha », K/Reminder.kt:124-125 « todayIsRestDay = Store.isExempt(…), tomorrowIsRestDay = Store.isEveOfRestDay(…) ». Dates calculées avec web/src/js/calendrier-juif.js jour(iso,false).chome.

**Correction proposée (revue par le contre-expert).** Garder la proposition : genere-textes.mjs écrit dans textes.bin la liste des jours chômés hors samedi, avec jour(iso, enIsrael).chome. Journal.chome(jour) sert dans serie() et dans Regles.prochain, qui saute le jour chômé et sa veille dès 12 h. Tests : le 20/09/2026 à 20 h donne mardi 22, et le 21/04/2027 donne dimanche 25. Corriger les deux commentaires. Ajouter le choix Israël/diaspora, que le Nokia ne règle pas : écrire les deux listes et choisir par fuseau, comme Holidays.defaultInIsrael (TimeZone.getDefault().getID() parmi Asia/Jerusalem, Asia/Tel_Aviv et Israel). Couvrir au moins 10 ans (le .jar est reconstruit à chaque modification).

**Note du contre-expert.** Vérifié : Regles.java:47 et :65-66 ne sautent que le samedi et le vendredi après 12 h, et Journal.serie() (:79) ne tolère que chabbat(). Android, lui, exempte tout jour assur bemelakha (Store.isExempt, Holidays.isRestDay) et se tait après midi la veille (ReminderRule.shouldNotify). Recalculé avec calendrier-juif.js : 9 jours chômés hors samedi en 5787, exactement aux dates citées, et 10 en 5788. Le 20/09/2026 n'est pas chômé mais c'est la veille de Kippour, et le Nokia y sonne à 20 h. Les dates de Tichri 2026 sont déjà passées ; les prochaines concernées sont en avril 2027.

### NOKIA-02 — Journal : une lecture ratée efface tout l'historique, une écriture ratée passe sous silence

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : nokia · **Type** : fonction

**Constat.** Si la lecture du journal échoue pour une raison quelconque (enregistrement tronqué après une coupure de batterie, erreur RMS passagère, format inattendu), Journal.lit() rend un journal vide sans rien dire. La prochaine écriture (fin de hitbodedout, réglage du rappel ou de « Vous appeler ») écrase alors l'enregistrement 1 : toutes les journées, la série et le total sont perdus pour de bon. À l'inverse, si l'écriture échoue (mémoire pleine : RecordStoreFullException), l'exception est avalée. L'écran dit « Bravo ! 20 min de hitbodedout. », mais rien n'est gardé.

**Preuve.** nokia/app/src/myhitbodedut/Journal.java:131-134 « if (rs.getNumRecords() > 0) return depuisOctets(rs.getRecord(1)); } catch (Exception e) { // Un journal illisible ne doit pas empêcher la hitbodedout. » puis :137 « return new Journal(); » ; :145-148 « else rs.setRecord(1, b, 0, b.length); } catch (Exception e) { // Rien à faire : le téléphone refuse d'écrire. » ; MyHitbodedut.java:255-256 « journal.ajoute(jourDebut, minutes); journal.ecrit(); » puis :261, le bravo sans condition.

**Correction proposée.** Dans lit(), distinguer « pas d'enregistrement » de « enregistrement illisible ». Dans le second cas, retenir illisible = true, copier les octets bruts dans un enregistrement de secours (rs.addRecord) et n'écraser jamais l'enregistrement 1 sans cette copie. Prévenir l'utilisateur : « Le journal n'a pas pu être relu ; l'ancien est gardé à part. » Faire rendre un booléen à ecrit(). En cas d'échec, afficher sur l'écran de fin « Le téléphone n'a pas pu enregistrer cette hitbodedout (mémoire pleine ?). » au lieu du seul bravo.

**Note du contre-expert.** Vérifié dans Journal.java. lit() (:127-138) avale toute exception et rend un Journal vide. ecrit() (:140-152) fait ensuite setRecord(1, ...) sans condition au premier appel (termine, enregistreRappel, enregistreAppel ou destroyApp), et ses propres erreurs sont avalées ; termine() (:255-261) affiche le bravo sans condition. La perte est réelle mais suppose d'abord une lecture ratée, d'où majeur plutôt que bloquant.

### NOKIA-03 — Rappel refusé par le téléphone : l'accueil continue d'annoncer « Chaque jour à 20 h 00 »

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : nokia · **Type** : fonction

**Constat.** Quand PushRegistry refuse l'alarme, enregistreRappel() garde journal.rappel. Le refus n'apparaît que dans une alerte de 3 secondes. Le message est long et cite un chemin de menu non vérifié pour le téléphone visé. Ensuite, la carte « Rappel » de l'accueil affiche « Chaque jour à 20 h 00 » et le formulaire garde la case cochée, alors qu'aucun rappel ne viendra. La promesse affichée est fausse.

**Preuve.** nokia/app/src/myhitbodedut/MyHitbodedut.java:388 « journal.rappel = c.get(Calendar.HOUR_OF_DAY) * 60 + … » puis :393 « String resultat = reprogrammeRappel(); » ; :396 « a.setTimeout(3000); » ; :407-408 « catch (Throwable t) { return "Ce téléphone refuse les rappels d'application. Règle plutôt son alarme (Menu > Extras)."; } » ; :130 « journal.rappel >= 0 ? "Chaque jour à " + Regles.heure(journal.rappel) : "Pas de rappel" ».

**Correction proposée (revue par le contre-expert).** Dans MyHitbodedut, garder un champ rappelRefuse, non enregistré, recalculé à chaque reprogrammeRappel (au démarrage aussi). Un champ dans Journal obligerait à passer le format en version 3, et un refus ne serait jamais levé. Avec rappelRefuse vrai, la carte de l'accueil affiche « Refusé par le téléphone ». Alerte en Alert.FOREVER, avec l'heure choisie et non 20 h 00 en dur : « Ce téléphone n'autorise pas les rappels d'application. Réglez plutôt son réveil à » + Regles.heure(journal.rappel) + « . » Sans chemin de menu tant qu'il n'est pas vérifié. Ligne 379 : « Le téléphone ouvre MyHitbodedut à l'heure choisie. S'il le refuse, réglez plutôt son réveil. »

**Note du contre-expert.** Vérifié : enregistreRappel garde journal.rappel (:388) avant reprogrammeRappel (:393), l'alerte dure 3000 ms (:396), et metAJourAccueil (:130) affiche « Chaque jour à … » quel que soit le résultat. Le refus n'est jamais signalé non plus au démarrage, où startApp ignore le résultat de reprogrammeRappel. Le texte du formulaire (:379) et l'alerte (:408) tutoient (« règle »), alors que le reste de l'application vouvoie.

### NOKIA-04 — registerAlarm appelé à chaque ouverture et à chaque fin de hitbodedout, même rappel désactivé

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : nokia · **Type** : fonction

**Constat.** reprogrammeRappel() appelle PushRegistry.registerAlarm sans condition, avec 0 pour « pas de rappel ». L'appel a lieu à chaque démarrage de l'application et à chaque fin de hitbodedout. Pour une MIDlet non signée (c'est le cas du .jar), le lancement automatique fait partie des fonctions soumises à l'autorisation de l'utilisateur. Selon la politique du téléphone, une demande « Autoriser le lancement automatique ? » peut donc surgir à chaque ouverture et juste après chaque hitbodedout, y compris chez qui n'a jamais réglé de rappel. Rien n'a été essayé sur un vrai téléphone.

**Preuve.** nokia/app/src/myhitbodedut/MyHitbodedut.java:403-405 « long quand = journal.rappel >= 0 ? Regles.prochain(…) : 0; PushRegistry.registerAlarm(getClass().getName(), quand); », appelé depuis startApp (:81 « reprogrammeRappel(); ») et termine (:257) ; build.sh:64 « MIDlet-Permissions-Opt: javax.microedition.io.PushRegistry ».

**Correction proposée (revue par le contre-expert).** Garder dans le journal l'heure de l'alarme posée (long, 0 si aucune) plutôt qu'un booléen. N'appeler registerAlarm que si l'heure calculée diffère de l'heure gardée, ou si l'heure gardée est déjà passée (l'alarme a servi). Ne jamais l'appeler avec 0 quand rien n'a été posé. Après une SecurityException, ne plus redemander pendant la session. Essayer l'installation non signée sur un vrai 3310 3G et noter dans le README les demandes qui apparaissent.

**Note du contre-expert.** Vérifié : reprogrammeRappel (:401-410) appelle registerAlarm(…, 0) même sans rappel, depuis startApp (:81) et termine (:257). Le .jar publié n'est pas signé (aucun fichier de signature dans META-INF), et son manifeste déclare PushRegistry en Permissions-Opt. Selon la politique de sécurité MIDP 2.0.1 (addendum GSM/UMTS), PushRegistry relève de « Application Auto Invocation ». Pour une suite non signée, cette fonction demande l'accord en mode oneshot (à chaque appel) ou session (à chaque lancement de la suite). La conséquence décrite est donc plausible, mais elle reste non éprouvée sur le 3310, comme le constat le dit lui-même.

### NOKIA-05 — Le rappel « chaque jour » ne se reprogramme que si l'application est ouverte

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : nokia · **Type** : fonction

**Constat.** Une alarme PushRegistry ne sert qu'une fois. Le code ne la repose qu'au démarrage, à la fin d'une hitbodedout ou au réglage. La chaîne s'arrête donc si le lancement automatique est refusé ce jour-là. Elle s'arrête aussi si l'application tourne déjà à l'heure dite : la norme prévoit qu'une MIDlet en marche gère l'heure elle-même par TimerTask, ce que le code ne fait pas. Enfin, startApp() ne fait rien au retour d'une pause. Le rappel annoncé « chaque jour » cesse sans prévenir.

**Preuve.** nokia/app/src/myhitbodedut/MyHitbodedut.java:400 « /** Une alarme ne sonne qu'une fois : on la reprogramme à chaque ouverture. */ » ; :70 « if (display != null) return; // retour d'une pause » ; aucun Timer de rappel dans les 10 fichiers ; :412-418, appeleParRappel() limité à « ecart >= 0 && ecart <= 2 ».

**Correction proposée (revue par le contre-expert).** Reposer l'alarme en quittant : « Quitter » appelle notifyDestroyed sans passer par destroyApp, il faut donc appeler reprogrammeRappel() avant notifyDestroyed(), ainsi que dans destroyApp. Reposer aussi dans startApp au retour d'une pause. Tant que l'application tourne, poser un TimerTask à l'heure du rappel, qui affiche l'alerte puis pose l'alarme du lendemain. Texte du réglage : « Le rappel ne vient que si le téléphone l'autorise ; s'il manque un jour, réglez plutôt son réveil. »

**Note du contre-expert.** Vérifié : le rappel n'est reposé qu'au démarrage, dans termine et au réglage, et startApp s'arrête dès la ligne 70 au retour d'une pause. Aucun Timer de rappel n'existe. La javadoc de registerAlarm dit bien qu'une application en marche doit utiliser un TimerTask, et l'AMS ignore l'alarme d'une suite déjà lancée. À préciser : le lancement par l'alarme repose lui-même l'alarme suivante, et la chaîne reprend à la prochaine ouverture à la main. Elle ne casse que lorsqu'un lancement n'a pas lieu : refus, application déjà ouverte, ou téléphone éteint, un cas non cité.

### NOKIA-06 — Fin de moins d'une minute : « Vous avez parlé avec Hachem » au-dessus de « rien n'est noté », titre coupé en « Hache… »

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : nokia · **Type** : texte

**Constat.** Un arrêt avant une minute ouvre l'écran de fin avec le titre session_done_title (« Vous avez parlé avec Hachem aujourd'hui »), puis « Moins d'une minute : rien n'est noté. ». Les deux phrases se contredisent. Android ne montre aucun bravo dans ce cas (rien n'est inscrit) et, après un abandon, dit « ’Hazak ! » ou « Courage ! ». De plus, à 240 px, le titre est coupé en plein mot : « Vous avez parlé avec Hache... » (309 px mesurés pour 224 disponibles).

**Preuve.** capture Nokia-my-hitbodedut-app/captures/09-arret.png : bandeau « Vous avez parlé avec Hache... », accroche « Moins d'une minute : rien n'est noté. » ; nokia/app/src/myhitbodedut/MyHitbodedut.java:261-262 « … : "Moins d'une minute : rien n'est noté."; fin = new Lecture(textes.mot("session_done_title"), … » ; Android K/SessionService.kt:189 « if (close.minutes > 0 || !early) { inscrire(…) » ; strings.xml annulation_neutral « Courage ! ».

**Correction proposée (revue par le contre-expert).** Minutes > 0 : bandeau court « Hitbodedout », et la phrase entière, qui passe à la ligne, en tête de l'accroche : « Vous avez parlé avec Hachem aujourd'hui. » puis « Bravo ! 20 min de hitbodedout. ». Minutes == 0 : bandeau « Hitbodedout arrêtée », aucune mention de « parlé avec Hachem ». L'accroche reprend Android selon l'adresse (« 'Hazak ! », « 'Hizki ! » ou « Courage ! ») suivie de « Moins d'une minute : rien n'est noté. ». Le texte vient du moment « relance » au lieu de « cloture », et le personnage reste « walking ».

**Note du contre-expert.** Capture 09-arret.png et code (:261-262) confirmés : le titre « Vous avez parlé avec Hache... » surmonte « Moins d'une minute : rien n'est noté. ». Sur Android, un arrêt avant une minute n'inscrit rien et n'affiche pas de bravo (SessionService:189). Mais la coupure du bandeau touche chaque fin de hitbodedout, pas seulement l'arrêt avant une minute. Surtout, la réécriture « Hitbodedout faite » supprime une phrase choisie par le propriétaire : FEUILLE_DE_ROUTE, 19/10, proposition 12, « la séance se clôt par « Vous avez parlé avec Hachem aujourd'hui » ».

### NOKIA-07 — Journal vide : promet « sa note si vous en écrivez une », alors que le Nokia n'a pas de notes

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : nokia · **Type** : texte

**Constat.** La chaîne Android journal_empty est reprise telle quelle. Elle annonce une note par hitbodedout, une fonction qui n'existe pas dans le .jar : pas de saisie, pas de champ note dans Journal. C'est le premier écran Journal que voit tout nouvel utilisateur, et la promesse ne peut pas être tenue.

**Preuve.** capture Nokia-my-hitbodedut-app/captures/17-journal.png : « Aucune hitbodedout enregistrée pour l'instant. Chaque hitbodedout faite s'inscrit ici, avec sa note si vous en écrivez une. » ; nokia/textes.mjs:17 « CLES_INTERFACE = ['chizuk_stuck', 'journal_empty', … » ; MyHitbodedut.java:352 « new JournalEcran(journal, textes.mot("journal_empty")) » ; Journal.java ne garde que « jour (aaaammjj) -> minutes ».

**Correction proposée (revue par le contre-expert).** Garder le texte proposé : « Aucune hitbodedout enregistrée pour l'instant. Chaque hitbodedout faite s'inscrit ici. » Le mettre de préférence dans JournalEcran, ou dans une constante Java. Une nouvelle clé dans strings.xml ne servirait ni à Android ni au web, et il faudrait la traduire en anglais et en hébreu.

**Note du contre-expert.** Capture 17-journal.png confirmée. CLES_INTERFACE exporte journal_empty (textes.mjs:17), et MyHitbodedut.java:352 l'affiche. Journal.java ne garde que jour → minutes, et le .jar n'a aucune saisie de note. La promesse n'est donc pas tenue, même si ce n'est qu'un écran d'état vide.

### NOKIA-08 — Compatibilité « Nokia 3310 3G » annoncée sans aucun essai de ce .jar sur le téléphone

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : docs · **Type** : fonction

**Constat.** Le dépôt public affirme que l'application s'installe sur le Nokia 3310 3G (2017). Seule preuve citée : le téléphone accepte des applications Java en général (Wikipédia, Stack Overflow). Rien ne montre que MyHitbodedut.jar y ait été installé. Les tests tournent dans MicroEmulator, avec la police SansSerif du PC et sans la mémoire ni la politique d'autorisations du téléphone. La musique attend explicitement « le résultat sur le 3310 ». Au dehors, un fil r/dumbphones (« TA-1030 cell phone does not support Java app? ») signale qu'une variante du 3310 3G refuse les applications Java. Un projet J2ME connu pour ce téléphone (next-caltrain-j2me) s'installe par un .jad, que ce projet ne livre pas.

**Preuve.** Nokia-my-hitbodedut-app/README.md:3 « dont le **Nokia 3310 3G de 2017** » et :15 « Nokia 3310 3G de 2017 (Smart Feature OS) : accepte les applications Java. » ; nokia/README.md:24 « Selon le résultat sur le 3310, on ajoute d'autres niggounim… » ; nokia/app/test/appareil240/device.xml:57-75 (polices SansSerif 12/15/18) ; aucun .jad dans le dépôt publié.

**Correction proposée (revue par le contre-expert).** Dépôt public : « Prévu pour le Nokia 3310 3G des premières séries (2017, Smart Feature OS) ; pas encore essayé sur un vrai téléphone. Les 3310 3G fabriqués à partir de 2019 n'acceptent pas les applications Java. » Ne pas citer le TA-1030 parmi les 3310 3G. Faire l'essai sur un vrai 3310 3G (installation, polices, rappel et demandes d'autorisation, musique), puis noter le type (TA-1022, TA-1036 ou TA-1006) et le micrologiciel. Publier un .jad seulement si l'essai montre qu'il en faut un.

**Note du contre-expert.** Constat principal juste : aucune trace d'essai de ce .jar sur un vrai 3310 3G, et le README attend encore « le résultat sur le 3310 ». Mais la preuve extérieure est fausse. Le TA-1030 est le Nokia 3310 (2017) 2G double SIM (Series 30+, MT6260), pas une variante 3G, et un développeur rapporte une MIDlet qui tourne sur un TA-1030. Le vrai risque sur le 3G, ce sont les séries fabriquées à partir de 2019, sans Java, et le README les signale déjà. Le .jad n'est pas démontré nécessaire : un .jar posé sur la carte s'ouvre depuis le gestionnaire de fichiers du 3310 3G.

### NOKIA-09 — La hitbodedout en cours n'est pas gardée : batterie à plat ou plantage, et elle disparaît

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : nokia · **Type** : fonction

**Constat.** Le début, la durée et les pauses de la hitbodedout ne vivent qu'en mémoire. Si la machine Java s'arrête sans destroyApp (batterie retirée ou vide, OutOfMemoryError, arrêt forcé par le système), une hitbodedout de 55 minutes sur 60 n'est pas inscrite. Android garde la séance et la reprend à la relance (reconcilier, cloreLaPrecedente).

**Preuve.** nokia/app/src/myhitbodedut/MyHitbodedut.java:217-222 lance() ne fait aucune écriture RMS ; seuls termine() (:255-256) et destroyApp() (:98-101) inscrivent. Android : K/SessionService.kt:409-416 « Reprend une séance restée inscrite après la mort du service … fun reconcilier ».

**Correction proposée.** Dans lance(), écrire un second enregistrement RMS {jourDebut, debut, duree} et le mettre à jour à chaque pause. Dans startApp, s'il existe : inscrire min(maintenant - debut - pauses, duree) en minutes (règle SessionRule.minutesAInscrire), puis l'effacer.

### NOKIA-10 — Pas de « Je l'ai faite sans le téléphone » ni d'ajout après coup : la série casse pour qui prie dehors sans le téléphone

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : nokia · **Type** : fonction

**Constat.** La série et la semaine (le cœur de l'accueil Nokia) ne comptent que les minutes chronométrées par le .jar. Android permet de valider la journée sans minuteur et d'ajouter du temps après coup. Le Nokia ne permet ni l'un ni l'autre, et ne permet pas non plus de corriger ou d'effacer un jour. Une hitbodedout faite dans les champs, téléphone laissé à la maison, remet la série à 0.

**Preuve.** Android : strings.xml:13 « action_done_offline » = « Je l’ai faite sans le téléphone », branché dans res/layout/activity_main.xml:306 ; K/GateService.kt:139 « Store.addSession(this, 0) » ; K/AjoutTemps.kt:32. Nokia : Journal.java:67-68 « void ajoute(int jour, int mins) { if (mins <= 0) return; » ; aucun autre chemin d'écriture dans MyHitbodedut.java.

**Correction proposée.** Ajouter au menu Durée une 8e carte « Je l'ai faite sans le téléphone ». Elle marque le jour fait (valeur spéciale, par exemple -1, comptée par serie() et minutesDu()>0) et propose de saisir des minutes. Dans l'écran Journal, ajouter une commande « Ajouter à hier ».

### NOKIA-11 — Musique : le parcours accepte un échec, la capture publiée montre l'erreur et des exceptions Java brutes

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : nokia · **Type** : fonction

**Constat.** test.sh se contente de vérifier que l'écran 19 diffère de l'écran 18. L'échec complet de la lecture passe donc le test et part dans le dépôt public, présenté comme « le parcours testé à chaque construction ». Le message montre à l'utilisateur des noms d'exceptions Java. Il n'est pas coupé, alors que l'écran Musique ne défile pas : sur la capture, la dernière ligne touche déjà la barre des touches.

**Preuve.** capture Nokia-my-hitbodedut-app/captures/19-musique-lecture.png : « Ce téléphone ne joue ni le MP3 ni l'AMR depuis une application. MP3 : accepté mais muet. MP3 : java.lang.NullPointerException. AMR : java.lang.NullPointerException. » ; nokia/app/test.sh:43 « 18-musique:19-musique-lecture » (seul contrôle) ; Musique.java:55 « "Lecture impossible : " + e.toString() », :85 « .append(e.toString()) » ; dépôt public README.md:25.

**Correction proposée.** Faire échouer le parcours quand l'écran 19 montre la couleur WARNING (0xC66B2D) dans la zone d'état. Sinon, ne pas publier la capture 19 tant que la lecture n'est pas prouvée. Remplacer les exceptions par « MP3 : refusé par le téléphone. » ou « AMR : refusé par le téléphone. ». Couper le message avec Ecran.tronque, ou rendre l'écran défilant.

### NOKIA-12 — Le niggoun tourne en boucle pendant toute la hitbodedout, sans moyen de l'arrêter

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : nokia · **Type** : fonction

**Constat.** La musique est lancée en boucle infinie depuis l'écran Musique, inaccessible pendant le décompte. La touche centrale du minuteur met la hitbodedout en pause, pas la musique, et aucune commande du minuteur ne touche au lecteur. Pour faire silence au milieu d'une hitbodedout d'une heure, il faut l'arrêter. Android a un mini-lecteur dans la séance (pause, reprise).

**Preuve.** nokia/app/src/myhitbodedut/Musique.java:75 « p.setLoopCount(-1); // tourne en boucle pendant la hitbodedout » ; MyHitbodedut.java:220 « ecoute(minuteur, new Command[] {pause, bloque, arreter}); » ; Android K/SessionService.kt:261-267 « Le mini-lecteur de la pratique … CMD_PAUSE -> music.pause() ».

**Correction proposée.** Quand musique.joue(), ajouter au minuteur une commande « Musique : pause/lecture » (Command.SCREEN) qui appelle musique.bascule(), ou réserver la touche 0 à cet usage. Arrêter aussi la boucle à la fin de la hitbodedout.

### NOKIA-13 — Titres de moments et références coupés à 240 px : le numéro de chapitre disparaît

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : nokia · **Type** : texte

**Constat.** Deux titres de moments dépassent le bandeau (224 px) et les cartes (187 px) : « Quand les mots ne viennent pas » (234 px) et « Avant de reprendre le téléphone » (236 px). Dans les listes, 13 références perdent ce qui les distingue. Par exemple, « Likoutei Etsot, Hitbodedout 4 » et « … 16 » deviennent tous deux « Likoutei Etsot, Hitbode... », et les cinq « Hit'hazkout 2/4/5/11/42 » s'affichent tous « Likoutei Etsot, Hit'hazk... ». Mesure faite avec la police de l'émulateur (SansSerif gras 15, appareil240/device.xml) ; une police de téléphone plus large en couperait davantage.

**Preuve.** captures 07-bloque.png, 13-liste.png, 14-texte.png : « Quand les mots ne viennent ... » ; 11-moments.png : « Quand les mots ne vien... », « Avant de reprendre le t... » ; Ecran.java:159 « tronque(titre, place, GRASSE) », Menu.java:138 « tronque(items[i], place, GRASSE) » ; mesure par script dans OUT/nokia/Tronque.java (refs Rambam 1:2 et 1:3, Likoutei Etsot Hitbodedout 2/4/16/20/23, Hit'hazkout 2/4/5/11/42).

**Correction proposée.** Dans textes.mjs, des titres courts pour le Nokia : blocage → « Quand les mots bloquent » (182 px), porte → « Avant le téléphone » (138 px). Pour les références des listes, abréger le titre du livre (« L. Etsot, Hitbodedout 16 », 174 px ; « Rambam, Tefila 1:2 », 140 px). Ajouter à test.sh une mesure qui échoue au-delà de 187 px.

### NOKIA-14 — Tutoiement dans trois phrases, vouvoiement partout ailleurs (et dans Android)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : nokia · **Type** : texte

**Constat.** L'application vouvoie (« Comment vous appeler ? », « l'application vous félicite », journal_empty), comme Android (« Parlez dans votre langue, comme on parle à quelqu’un »). Trois phrases tutoient pourtant, dont la consigne affichée en permanence pendant le décompte.

**Preuve.** nokia/app/src/myhitbodedut/Minuteur.java:124 « "Parle à Hachem, dans ta langue, comme à quelqu'un." » ; MyHitbodedut.java:379 « S'il le refuse, règle plutôt son alarme. » ; :408 « Règle plutôt son alarme (Menu > Extras). » ; Android strings.xml:190 hitbodedut_sihah_invite « Parlez dans votre langue, comme on parle à quelqu’un. ».

**Correction proposée.** Minuteur.java:124 → « Parlez à Hachem dans votre langue, comme à quelqu'un. » ; MyHitbodedut.java:379 → « S'il refuse, réglez plutôt son réveil. » ; :408 → « Ce téléphone n'autorise pas les rappels d'application. Réglez plutôt son réveil. »

### NOKIA-15 — « Chaque jour à 20 h 00 » : faux le Chabbat, le vendredi soir et les jours déjà faits

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : nokia · **Type** : texte

**Constat.** Le réglage, la confirmation et l'accueil promettent un rappel « chaque jour ». Le code le supprime le samedi, le vendredi après midi et une fois la hitbodedout faite. Un utilisateur qui ne reçoit rien le vendredi croira à une panne. Android l'écrit : « Rien ne sonne un jour de repos, ni une fois la hitbodedout faite. »

**Preuve.** nokia/app/src/myhitbodedut/MyHitbodedut.java:361 « Me rappeler chaque jour » ; :406 « "Rappel chaque jour à " + … » ; :130 « "Chaque jour à " + Regles.heure(journal.rappel) » ; Regles.java:58-66 (saut si faitAujourdhui, samedi, vendredi après 12 h) ; Android strings.xml:454 reminders_hint.

**Correction proposée.** :361 → « Me rappeler la hitbodedout » ; :130 → « À " + heure + ", sauf Chabbat » ; :406 → « Rappel à 20 h 00. Rien ne sonne le Chabbat, les fêtes, ni une fois la hitbodedout faite. »

### NOKIA-16 — Durée au choix : 180 min au plus (Android : 240), saisie hors bornes ignorée sans message

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : nokia · **Type** : fonction

**Constat.** La saisie libre accepte 3 chiffres. 0, 200 ou 999 sont refusés en silence : on appuie sur OK et rien ne se passe. Le maximum de 180 minutes diffère de celui d'Android (240, valeur ramenée dans les bornes). Rien ne justifie l'écart.

**Preuve.** nokia/app/src/myhitbodedut/MyHitbodedut.java:193 « new TextBox("Minutes (1 à 180)", "20", 3, TextField.NUMERIC) » ; :479 « if (m >= 1 && m <= 180) prepare(m); » (pas de else) ; Android K/DureeSeance.kt:21 « const val MAX = 240 » et « coerceIn(MIN, MAX) ».

**Correction proposée.** Titre « Minutes (1 à 240) ». Remplacer :479 par « if (m >= 1) prepare(Math.min(240, m)); else display.setCurrent(new Alert("Durée", "Entre 1 et 240 minutes.", null, AlertType.WARNING), auChoix); ».

### NOKIA-17 — « Arrêter » coupe la hitbodedout sans confirmation, et il n'y a pas d'« Abandonner »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : nokia · **Type** : fonction

**Constat.** Sur un clavier, une fausse manœuvre dans le menu des options (« Je n'arrive pas à parler » est juste au-dessus) termine la hitbodedout tout de suite. Android demande confirmation et distingue « Terminer maintenant » (les minutes comptent) de « Abandonner » (rien n'est noté). Le libellé Nokia « Arrêter » ne correspond à aucun des deux.

**Preuve.** nokia/app/src/myhitbodedut/MyHitbodedut.java:44 « new Command("Arrêter", Command.STOP, 3) » ; :485 « else if (c == arreter) minuteur.arrete(); » ; capture 06-menu.png ; Android strings.xml:155-159 « Terminer maintenant », « Abandonner », « Terminer la hitbodedout ? » et K/SessionActivity.kt confirmFinish/confirmCancel.

**Correction proposée.** Renommer la commande « Terminer » et passer par un écran de confirmation « Terminer la hitbodedout ? » (Terminer maintenant / Retour) avant minuteur.arrete().

### NOKIA-18 — Bande de la semaine : le Chabbat apparaît comme un jour manqué

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : nokia · **Type** : fonction

**Constat.** L'accueil et le journal colorent tout jour sans minutes en « à faire », samedi compris, alors que la série ignore ce samedi. Android marque les jours exemptés (« — », fond bg_day_exempt) et montre la semaine du dimanche au samedi. Le Nokia montre les 7 derniers jours, sans repère pour le Chabbat. Le README parle pourtant de « la semaine en carrés ».

**Preuve.** nokia/app/src/myhitbodedut/MyHitbodedut.java:167 « g.setColor(fait ? Ecran.BRAND : Ecran.DAY_TODO); » ; JournalEcran.java:78 « g.setColor(minutes[k] > 0 ? BRAND : DAY_TODO); » ; Android K/MainActivity.kt:851 « day.exempt -> "—" », :890 « R.drawable.bg_day_exempt » ; nokia/README.md:12.

**Correction proposée.** Pour un jour chômé non fait (Journal.chabbat, puis la liste des fêtes), dessiner un trait « — » sur fond MINT au lieu du carré DAY_TODO, comme Android.

### NOKIA-19 — Minutes d'un arrêt non plafonnées à la durée choisie

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : nokia · **Type** : fonction

**Constat.** Une fin normale inscrit exactement la durée. En revanche, « Arrêter » et la fermeture par le téléphone inscrivent le temps écoulé brut. Si le décompte a été retardé (machine Java ralentie ou suspendue, horloge du téléphone avancée), une hitbodedout de 20 min peut en inscrire 60. C'est le défaut qu'Android a corrigé le 29/09 (« 20 minutes choisies devenaient 60 »).

**Preuve.** nokia/app/src/myhitbodedut/Minuteur.java:79 « return (int) (ecoule() / 60000L); » ; :86 « : (int) (ecoule() / 60000L); » ; Android K/SessionRule.kt minutesAInscrire « Une seance minutee ne compte jamais plus que sa duree … 20 minutes choisies devenaient 60 (revue du 29/09) ».

**Correction proposée.** Minuteur.java:79 et :86 : remplacer ecoule() par Math.min(ecoule(), duree).

### NOKIA-20 — Le niggoun d'essai est un morceau de provenance non établie, et son script de génération est cassé

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : nokia · **Type** : fonction · déjà connu ou choix assumé

**Constat.** Le .jar public diffuse le Niggoun 33. Il fait partie des 30 niggounim sans titre retirés de la version Play le 29/10, faute de provenance connue ; la version GitHub les garde par choix du propriétaire. Des morceaux couverts par un accord écrit existent pourtant (yanuka_nigoun_3, shpayer_beyond). Par ailleurs, genere-musique.sh lit un fichier qui n'existe plus : la source est passée en .m4a dans musique_hors_play.

**Preuve.** PUBLICATION_PLAY_STORE.md:195 « La provenance des 30 niggounim sans titre (niggoun_01 à niggoun_33) est inconnue » et :202 « Retirés tant que la provenance n'est pas établie » ; nokia/app/genere-musique.sh:11 « SRC="$ICI/../../android/app/src/main/res/raw/niggoun_33.mp3" », absent (seul existe android/app/src/musique_hors_play/res/raw/niggoun_33.m4a) ; Musique.java:18 « TITRE = "Niggoun 33" ».

**Correction proposée.** Prendre comme morceau d'essai un enregistrement couvert par écrit (yanuka_nigoun_3 ou shpayer_beyond), régénérer res/m, mettre Musique.TITRE à jour. Faire pointer genere-musique.sh sur la source réelle et le faire échouer clairement si elle manque.

### NOKIA-21 — README Nokia : chiffres périmés, langue non annoncée au dépôt public

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : docs · **Type** : texte

**Constat.** Le README annonce « environ 600 Ko » : le .jar en fait 686 208 octets, dont 512 Ko pour le même niggoun en deux formats, soit 75 % du fichier. Il annonce aussi « 85 » textes, quand l'accueil en affiche 171. Le README du dépôt public ne dit nulle part que l'interface n'existe qu'en français, sans anglais ni hébreu, alors que l'application Android est trilingue. Seul le README interne le dit (« Absents : l'hébreu »).

**Preuve.** nokia/README.md:5 « (environ 600 Ko, dont 510 Ko pour le niggoun d'essai) » ; :11 « (85 au 11/10, relus à chaque construction) » ; ls : MyHitbodedut.jar 686208 octets, m/niggoun.mp3 334306 + m/niggoun.amr 178086 ; capture 01-accueil.png « 171 textes, moment par moment » ; Nokia-my-hitbodedut-app/README.md:3, qui ne mentionne que « textes de ’hizouk en français ».

**Correction proposée.** nokia/README.md:5 → « (686 Ko, dont 512 Ko pour le niggoun d'essai en MP3 et en AMR) » ; :11 → « les textes publiés, en français (171 au 12/11 ; le nombre exact s'affiche à l'accueil) » ; dépôt public, ajouter : « Interface et textes en français seulement (ni anglais ni hébreu). » Une fois le format retenu, ne garder qu'une version du niggoun pour alléger le .jar.

### NOKIA-22 — Ponctuation orpheline en début de ligne (espace insécable perdue)

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : nokia · **Type** : texte

**Constat.** latin1() remplace l'espace insécable U+00A0, qui fait pourtant partie de Latin-1, ainsi que U+202F et U+2009, par une espace ordinaire. Ecran.coupe() coupe sur chaque espace : « : », « ; », « ! », « ? » et « » » peuvent donc ouvrir une ligne, et « « » peut la fermer. Avec la police de l'émulateur à 208 px, on compte 16 lignes ouvertes par une ponctuation et 10 lignes fermées par « « ».

**Preuve.** nokia/textes.mjs:21 « [/[   ]/g, ' '] » (U+00A0, U+202F, U+2009) ; Ecran.java:188 « int j = paragraphe.indexOf(' ', i); » ; simulation OUT/nokia/Coupe.java : « Bisdei Yaar, chap. 42 » ligne « : « Et il arrivera… », « Tehilim 55:23 » ligne « ; jamais Il ne laissera », « Bisdei Yaar, chap. 15 » ligne « ». C'est-à-dire… ».

**Correction proposée.** Dans latin1(), remplacer /[  ]/g par ' ', garder  , puis appliquer s.replace(/ ([:;!?»])/g, ' $1').replace(/« /g, '« '). coupe() ne coupe que sur ' ', donc la ponctuation reste collée au mot.

### NOKIA-23 — Bande des 7 jours : un jour sauté la nuit du passage à l'heure d'été

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : nokia · **Type** : fonction

**Constat.** L'accueil et le journal remontent les jours en retirant 24 h à l'instant présent. Entre minuit et 1 h, après un jour de 23 h (passage à l'heure d'été : le vendredi en Israël, le dimanche en Europe), on retombe sur l'avant-veille : un jour manque et la veille est comptée deux fois. Journal.ilYa() évite justement ce piège en partant de midi, mais ces deux écrans ne l'utilisent pas.

**Preuve.** nokia/app/src/myhitbodedut/MyHitbodedut.java:164 « cal.setTime(new Date(System.currentTimeMillis() - (6 - k) * 86400000L)); » ; JournalEcran.java:64 « c.setTime(new Date(System.currentTimeMillis() - n * 86400000L)); » ; contre Journal.java:41 « (compté depuis midi : l'heure d'été ne saute aucun jour) ».

**Correction proposée.** Utiliser Journal.ilYa(6 - k) dans les deux boucles et tirer le jour de la semaine d'un Calendar placé à midi de ce jour.

### NOKIA-24 — Alerte du rappel : le titre répété mot pour mot comme message

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : nokia · **Type** : texte

**Constat.** Ouverte par le rappel, l'application affiche une alerte dont le titre et le texte sont la même phrase (« C'est l'heure de la hitbodedout » / « C'est l'heure de la hitbodedout. »). Android a un texte à part (reminder_text).

**Preuve.** nokia/app/src/myhitbodedut/MyHitbodedut.java:83 « new Alert(textes.mot("reminder_title"), textes.mot("reminder_title") + ".", null, AlertType.INFO) » ; strings.xml:221 reminder_text « Une hitbodedout de %1$s vous attend. ».

**Correction proposée.** Texte de l'alerte : « La hitbodedout du jour n'est pas encore faite. Touche centrale : commencer. » Associer l'alerte au menu Durée plutôt qu'à l'accueil.

### NOKIA-25 — Petites incohérences d'écriture : « à faire » / « À faire », « Série : 0 jour »

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : nokia · **Type** : texte

**Constat.** Le même état s'écrit « À faire » à l'accueil et « à faire » dans le journal. « Série : 0 jour » s'affiche au premier lancement, quand Android dit « Pas encore de série ».

**Preuve.** nokia/app/src/myhitbodedut/MyHitbodedut.java:152 « "À faire" » ; JournalEcran.java:39 « "à faire" » ; MyHitbodedut.java:157 « "Série : " + s + (s > 1 ? " jours" : " jour") » ; captures 01-accueil.png et 17-journal.png ; Android strings.xml:12 status_streak_first « Pas encore de série ».

**Correction proposée.** JournalEcran.java:39 → « À faire ». MyHitbodedut.java:157 → s == 0 ? « Pas encore de série » : « Série : » + s + (s > 1 ? « jours » : « jour »).
