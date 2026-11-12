# TFRUX — Interface française — clarté, ton, promesses (rédaction UX)

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

28 constats — confirmés : 4 · confirmés en partie : 4 · non contre-expertisés (mineurs et cosmétiques) : 20.

> Contre-expertise incomplète pour cette dimension.

## Ce qui a été examiné

Lu en entier : A/res/values/strings.xml (1 457 lignes), light/res/values/strings.xml, les manifestes main, full et light, backup_rules.xml et data_extraction_rules.xml. Usage de chaque clé calculé par script sur Kotlin, layouts et sources du site (OUT/tfrux/usage.py et u.sh) : 43 clés hors titres de morceaux ne sont référencées nulle part, je ne les ai donc pas auditées comme textes affichés.

Code lu en entier pour vérifier les affirmations : GateStatus, GateService, BlockerView, Autorisation, Permissions, Divulgation, ReminderRule, Reminder, ChabbatAlerte, Notifications, SessionRule, Onboarding, Adresse, Dedicace, NePasDeranger, DureeSeance, Salutation. Lu par passages : Store (persistance, exemption, série, export et import), MainActivity, SettingsActivity, SessionActivity, SessionService, CelebrationActivity, RechercheActivity, RechercheGlobale, ChizukActivity, TefilotActivity, VolActivity (deux passages), SuiviVol ; layouts activity_settings, activity_main, view_blocker, activity_reminders.

Documents : FEUILLE_DE_ROUTE.md lignes 1-330, 640-770 et 960-1163 lues, le reste interrogé par mots-clés ; PUBLICATION_PLAY_STORE.md lignes 336-356 et par mots-clés ; README par mots-clés. Une recherche web, sans nom de projet, pour vérifier la phrase sur la carte Equal Earth (exacte).

Site : seulement quelles chaînes communes il affiche (web/src/js/app.js par recherche, i18n.js et relais.js lus), et l'adresse du relais sur le site déployé (vide).

Échantillonné sans vérification dans le code : les quelque 180 libellés liturgiques et de calendrier (zman_*, ajout_*, fete_*, levana_*, rappel_pluie_*) et la centaine de chaînes vol_* hors confidentialité et erreurs ; les dix conseils et les cinq temps guidés, lus pour le ton seulement.

Non examiné : les fichiers anglais et hébreu, les textes de l'application Nokia, la fiche Google Play, les contenus JSON. Rien n'a été exécuté sur un appareil ou un émulateur : aucune troncature de bouton ou de titre n'a pu être constatée à l'écran, les longueurs sont mesurées sur les chaînes. Les constats d'autres auditeurs trouvés sous OUT/constats ont servi de pistes ; chaque fait repris ici a été relu dans le code.

## Ce qui tient

- Un seul mot pour la pratique : « hitbodedout » partout, jamais « séance » dans l'interface (0 occurrence dans strings.xml), et un vouvoiement tenu d'un bout à l'autre.
- Le premier écran de la présentation explique la hitbodedout à quelqu'un qui n'en sait rien, en deux phrases sans jargon (« Pas de formule à réciter, pas de niveau à atteindre »).
- L'écran de blocage et les rappels ne culpabilisent pas : « Le téléphone peut attendre », « Une hitbodedout de %1$s vous attend », « Série à relancer » réservé à qui a déjà eu une série (K/MainActivity.kt:783-789), et un texte « Reprendre la route » plutôt qu'un reproche après une série rompue.
- Les deux divulgations des accès spéciaux sont construites comme il faut (ce qui est lu, pourquoi, rien d'envoyé, comment éteindre) et exactes sur ce qui est lu : seule la dernière application au premier plan, gardée en mémoire (K/GateService.kt:102-117). Leur seul défaut est le cas de la séance en cours.
- Les gestes destructeurs sont bien écrits : la réinitialisation énumère ce qui sera effacé et son bouton redit l'action (« Tout effacer »), et le bouton négatif de la note devient « Ne pas enregistrer » dès qu'on a écrit quelque chose (K/NoteDialog.kt:127).
- Plusieurs messages d'échec du vol disent ce qui reste possible (« Les aéroports se choisissent aussi à la main », « Le calcul reste sur la route prévue »), et les états vides du journal, des zmanim, des marque-pages et du parcours indiquent le geste suivant ; l'édition Light corrige la promesse de confidentialité pour rester vraie.

## Constats

### TFRUX-02 — « Je suis avec Hachem » : les textes limitent le blocage à la plage horaire et au jour non fait, le code bloque aussi pendant toute hitbodedout

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : texte

**Constat.** Sept textes décrivent quand l'écran s'interpose : pendant la plage horaire, tant que la pratique du jour n'est pas faite. Le service s'arme aussi dès qu'une hitbodedout est en cours, à n'importe quelle heure, journée déjà validée, jour de Chabbat ou de pause compris ; l'écran n'offre alors ni « Plus tard » ni « Je l'ai déjà faite », seulement « Revenir à la hitbodedout ». Quelqu'un qui lance une hitbodedout d'une heure à 20 h, mode réglé de 6 h à 11 h, voit ses applications bloquées alors que la carte d'état affiche « Hors de la fenêtre… En dehors, rien n'est retenu » ou « Plus rien ne sera retenu aujourd'hui ». Les deux divulgations exigées par Google Play disent la même chose inexacte.

**Preuve.** K/GateService.kt:83 `val armed = GateStatus.isArmed(this) || (running && GateStatus.shouldRunService(this))` ; K/BlockerView.kt:17 « Une séance est en cours : la seule issue est d'y retourner. ». strings.xml:28 « Les applications choisies restent fermées tant que la pratique n’est pas faite. » ; :70 « Plus rien ne sera retenu aujourd’hui. Le mode reprendra demain. » ; :76 « Le mode agit entre %1$s et %2$s. En dehors, rien n’est retenu. » ; :72 ; :124 « …par-dessus l’application que vous ouvrez le matin. » ; :1419 et :1421 « pendant la plage horaire que vous avez fixée… jusqu’à ce que la pratique du jour soit faite ».

**Correction proposée (revue par le contre-expert).** Garder le code : le blocage pendant une séance est un choix documenté (README.md:25-26, « Si une application bloquée est ouverte pendant la séance… ne propose que d'y retourner »). Corriger les textes comme proposé, divulgations overlay et usage comprises (« Il s'affiche aussi, à toute heure, tant qu'une hitbodedout est en cours. »). Ajouter un état « séance en cours » à GateStatus, utilisé par la carte d'état et par la notification permanente : titre « Hitbodedout en cours », détail « Les applications choisies restent bloquées jusqu'à la fin de la hitbodedout. ».

**Note du contre-expert.** Vérifié : GateService.kt:82 arme le service dès qu'une séance tourne (`running && shouldRunService`), hors plage, journée faite ou jour exempté compris, et l'écran SESSION_RUNNING (BlockerView.kt:18 et 92-118) n'offre que le retour à la séance. Les sept textes cités (strings.xml:28, 70, 72, 76, 124, 1419, 1421) parlent tous seulement de la plage horaire ou du jour non fait. C'est pire que décrit : la notification permanente (GateService.kt:235-237) affiche « Hors de la fenêtre… En dehors, rien n'est retenu » au moment même où elle bloque. Ce comportement est voulu (README.md:25-26), c'est donc le texte qu'il faut corriger, divulgations Play comprises.

### TFRUX-03 — « Tout est stocké sur ce téléphone uniquement » : faux, et contredit par les règles de confidentialité de l'application

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : texte

**Constat.** La carte « Mes données » affirme que tout reste sur le téléphone. Le fichier des réglages part pourtant dans la sauvegarde Google d'Android quand elle est active, et il contient le lieu des zmanim (latitude, longitude), les détails et relevés GPS d'un vol et la liste des applications bloquées. Le cahier de publication décrit exactement ce comportement : la phrase affichée contredit donc les règles de confidentialité vers lesquelles le bouton d'à côté renvoie. Sur le site, la même chaîne s'affiche telle quelle (« ce téléphone ») alors que les données sont dans un navigateur.

**Preuve.** strings.xml:33 « Tout est stocké sur ce téléphone uniquement. Exportez de temps en temps. » (activity_settings.xml:513 ; web/src/js/app.js:4500). A/res/xml/data_extraction_rules.xml : `<cloud-backup><include domain="sharedpref" path="myhitbodedut.xml" />`. K/Store.kt:72 KEY_APPS, :103-104 lieu_latitude / lieu_longitude, :110-118 vol_*, tous lus par prefs() (fichier « myhitbodedut »). PUBLICATION_PLAY_STORE.md:344-349 « réglages (myhitbodedut.xml, dont le lieu des zmanim, les détails d'un vol, la liste des apps de la barrière)… sauvegarde dans le nuage d'Android : réglages seuls ».

**Correction proposée.** Android : « Votre journal, vos notes et votre prénom restent sur ce téléphone. Vos réglages, dont le lieu des zmanim, peuvent partir dans la sauvegarde Google du téléphone si elle est activée. » Site (nouvelle chaîne section_data_hint_web) : « Tout est gardé dans ce navigateur, sur cet appareil. Exportez de temps en temps. » Ou bien sortir le lieu, le vol et la liste des applications du fichier sauvegardé, et garder la phrase.

**Note du contre-expert.** Vérifié : data_extraction_rules.xml (`cloud-backup` inclut myhitbodedut.xml) et backup_rules.xml envoient dans la sauvegarde Android le fichier où Store.kt range blocked_apps, lieu_latitude/longitude, vol_releve_*, mais aussi tikkun_journal et les favoris. Les règles de confidentialité le disent (confidentialite.html:67 et 76 ; PUBLICATION_PLAY_STORE.md:344-349), alors que la carte proclame « Tout est stocké sur ce téléphone uniquement » (strings.xml:33). Le site reprend la même chaîne telle quelle (app.js:4500), alors qu'il a déjà des variantes `_web` pour ce genre de cas.

### TFRUX-04 — « Exportez », « Sauvegarde enregistrée », « Exportez d'abord vos données si vous voulez les garder » : l'export n'emporte qu'une partie de ce qu'on écrit

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** Trois textes présentent l'export comme la sauvegarde de ses données, dont celui qui précède l'effacement complet. Le fichier ne contient que les journées (minutes, note, sujets), une vingtaine de réglages, les jours de pause et les applications bloquées. Ni l'humeur avant et après, ni la gratitude, ni « À travailler » (des phrases écrites par l'utilisateur), ni le journal du Tikoun, ni les favoris, ni les marque-pages n'y figurent. Qui suit le conseil de l'écran « Réinitialiser » perd ces écrits sans avoir été prévenu.

**Preuve.** strings.xml:33 « Exportez de temps en temps. » ; :230 « Sauvegarde enregistrée. » ; :936 « Exportez d’abord vos données si vous voulez les garder. ». K/Store.kt:1484-1522 exportJson : « days », « settings », « paused_dates », « blocked_apps », rien d'autre ; :949-952 « journal_plus » (humeur, gratitude, travail) et :159 KEY_TIKKUN_JOURNAL ne sont jamais écrits dans l'export.

**Correction proposée (revue par le contre-expert).** Android : ajouter `journal_plus` à Store.exportJson, avec la clé et le format que le site écrit déjà (store.js:543), et le relire dans importJson. Y ajouter aussi tikkun_journal, les favoris et les marque-pages, ou bien le dire. En attendant, ne pas toucher à section_data_hint, partagée avec le site dont l'export contient l'humeur et la gratitude. Compléter reset_hint (Android seul) : « Attention : l'export ne contient pas encore l'humeur, la gratitude, « À travailler », le Tikoun, les favoris ni les marque-pages. » ; export_ok : « Fichier d'export enregistré. ».

**Note du contre-expert.** Pour Android, c'est vérifié : Store.exportJson (Store.kt:1484-1522) n'écrit ni journal_plus (humeur, gratitude, « À travailler »), ni tikkun_journal, ni les favoris, ni les marque-pages ; importJson ne les lit pas ; reinitialiser (Store.kt:191-193) vide les deux fichiers, et reset_hint (strings.xml:936) conseille d'exporter avant. Le constat a tort de se dire transverse : l'export du site contient `journal_plus: journalPlusTout()` (web/src/js/store.js:543), et le site n'utilise pas reset_hint. La réécriture proposée pour section_data_hint, chaîne partagée avec le site, y deviendrait donc fausse.

### TFRUX-05 — Réglages au premier lancement : « 4 autorisations à accorder », « Autorisations nécessaires », « Autorisations manquantes » alors que rien n'est activé

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : texte

**Constat.** Sur une installation neuve de l'édition complète, mode éteint par défaut et rappel éteint, l'écran des réglages s'ouvre sur « 4 autorisations à accorder. », puis la carte « État du mode » montre le bouton « Autorisations manquantes, les accorder » et la phrase « Accordez l'affichage par-dessus les autres applications et l'accès aux données d'utilisation, plus bas. », enfin une carte « Autorisations nécessaires » où chaque ligne est marquée « Manquante » en orange. Aucune n'est nécessaire : le commentaire du code dit lui-même que deux d'entre elles « ne servent qu'à la barrière ». L'état « autorisations manquantes » est évalué avant « mode désactivé », si bien qu'on réclame deux accès sensibles à quelqu'un qui n'a pas activé la fonction, et avant toute explication de ce qu'elle est (la carte « Je suis avec Hachem » vient après). « plus bas » subsiste alors que le bouton y fait défiler. Pour la batterie, « Accorder » ouvre la liste générale d'optimisation d'Android sans dire quoi y faire.

**Preuve.** K/GateStatus.kt:26-27 `!Permissions.allGranted(context) -> GateState.MISSING_PERMISSIONS` avant `!Store.isEnabled(context) -> GateState.DISABLED` ; K/Store.kt:1068 mode éteint par défaut ; K/SettingsActivity.kt:241-246 et :304 « Amène la carte des autorisations sous les yeux, plutôt que « plus bas » » ; K/Autorisation.kt:13-16 ; K/Permissions.kt:86 `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`. strings.xml:30 « Autorisations nécessaires », :64, :127 « Manquante », :371 « Autorisations manquantes, les accorder », :472-475 « %1$d autorisations à accorder. », :117 « Batterie sans restriction ».

**Correction proposée.** Évaluer DISABLED avant MISSING_PERMISSIONS et ne compter les deux accès de la barrière que mode activé. Textes : section_permissions « Autorisations » ; section_permissions_hint « Aucune n'est obligatoire. Chacune sert une fonction précise, et se retire à tout moment dans les réglages d'Android. » ; permission_missing « Non accordée » ; permissions_missing « %1$d autorisation utile non accordée. » / « %1$d autorisations utiles non accordées. » ; gate_permissions_detail « Pour fonctionner, « Je suis avec Hachem » a besoin de deux accès : l'affichage par-dessus les autres applications et l'accès aux données d'utilisation. » ; gate_permissions_action « Voir les deux accès » ; permission_battery_why « Sans elle, Android peut retarder le rappel de plusieurs heures. Dans la liste qui s'ouvre, cherchez MyHitbodedut et choisissez « Ne pas optimiser ». ».

**Note du contre-expert.** Vérifié : GateStatus.kt:26-27 évalue MISSING_PERMISSIONS avant DISABLED, si bien que la carte d'état réclame les deux accès sensibles (bouton « Autorisations manquantes, les accorder ») alors que le mode est éteint. renderPermissions/renderSummary (SettingsActivity.kt:241-279) comptent les quatre autorisations sous « Autorisations nécessaires » avec « Manquante » en orange, alors qu'Autorisation.kt:13-16 reconnaît que deux d'entre elles ne servent qu'à la barrière. Seules précisions : « 4 » suppose Android 13 ou plus avec les notifications pas encore accordées, et « plus bas » reste exact (la carte est bien plus bas), c'est donc cosmétique.

### TFRUX-07 — « Je l'ai faite sans le téléphone » inscrit le temps sur HIER sans le dire quand aujourd'hui est déjà fait

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** Le bouton de l'accueil reste affiché quand la journée est faite mais qu'hier ne l'est pas. Dans ce cas il ne pose pas la question « Quel jour ? » : il ouvre directement « Combien de temps ? » et ajoute la durée à la journée d'hier. Ni le libellé du bouton ni le titre du dialogue ne nomment le jour, et aucun bravo ne suit (il est réservé à aujourd'hui). Quelqu'un qui veut ajouter une seconde hitbodedout faite aujourd'hui loin du téléphone crédite donc hier, répare sa série sans le savoir, et ne peut pas corriger ensuite.

**Preuve.** K/MainActivity.kt:258-267 `aujourdhuiOuvert && hierOuvert -> … offline_which_day` ; `hierOuvert -> choisirDureeHorsTelephone(hier)` ; :277 `DureeSeance.choisir(this, R.string.offline_how_long)` ; :282 bravo seulement `if (date == Store.today())` ; :813-814 bouton visible `if ((!done || hierOuvert()) && !Store.isSessionRunning(this))`. strings.xml:13 « Je l’ai faite sans le téléphone » ; :17 « Combien de temps ? ».

**Correction proposée.** Toujours nommer le jour. Quand seul hier est ouvert, libellé du bouton : « Inscrire la hitbodedout d'hier » ; titre du dialogue de durée : « Hier : combien de temps ? » (et « Aujourd'hui : combien de temps ? » dans l'autre cas) ; confirmation après l'ajout : « Ajouté à hier : %1$s. ». Quand aujourd'hui est fait, proposer aussi « Aujourd'hui » dans « Quel jour ? ».

**Note du contre-expert.** Vérifié : MainActivity.kt:257-266 envoie directement vers choisirDureeHorsTelephone(hier) quand aujourd'hui est fait et hier ouvert, sans « Quel jour ? ». Le libellé du bouton est fixe (seul l'écouteur est posé, ligne 174), le titre du dialogue est « Combien de temps ? », et le bravo n'est réservé qu'à aujourd'hui (ligne 282). La visibilité `(!done || hierOuvert())` est voulue et tenue par Fiabilite2Test:88 ; le défaut tient à ce que le jour n'est jamais nommé. Aucune fonction ne retire du temps à un jour passé (unmarkToday n'est jamais appelée).

### TFRUX-01 — Dédicace : « Léïlouy nichmat » coché d'office, quatre intentions sans un mot de français, rien sur ce que devient la demande

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** Le dialogue « Dédicace » (Android et site) présélectionne la première intention, « Léïlouy nichmat (לעילוי נשמת) », formule réservée à un défunt. Les quatre intentions ne sont libellées qu'en translittération et en hébreu, et le champ suivant donne pour exemple « Moché ben Sarah ». Qui veut dédier sa hitbodedout à la guérison d'un proche et ne lit pas l'hébreu laisse le choix par défaut : l'e-mail préparé porte « לעילוי נשמת » devant le nom d'un vivant, en hébreu seul, donc impossible à relire. Le texte d'introduction, lui, est affiché deux fois (carte des réglages, puis en tête du dialogue) et dit par où passe la demande, jamais ce que l'équipe en fait : où et quand la dédicace paraît, si c'est gratuit. La maquette du dépôt décrit d'ailleurs autre chose (« Dédier un jour, un livre ou le Tikoun aide à faire vivre l'application ») que ce que le dialogue propose (« Ma hitbodedout / Mon étude »).

**Preuve.** strings.xml:36 « Pour dédier votre hitbodedout ou votre étude, la demande passe par l’équipe MyHitbodedut… rien ne part sans vous. » ; :42-45 « Léïlouy nichmat (לעילוי נשמת) », « Refoua chéléma (לרפואה שלמה) », « Hatsla’ha (להצלחה) », « Zivoug hagoun (לזיווג הגון) » ; :47 « Nom (ex. : Moché ben Sarah) ». K/Dedicace.kt:31 LEILOUY en tête de l'énumération, :79 `check(idsIntentions[0])`, :93 le texte d'introduction rajouté dans le dialogue alors qu'il est déjà à activity_settings.xml:498. web/src/js/app.js:4434 `let objet = 0, intention = 0;`. maquettes-dedicaces/fr-5-page-dedicaces.png.

**Correction proposée (revue par le contre-expert).** Ne cocher aucune intention d'avance (Android : retirer `check(idsIntentions[0])` ; site : `intention = -1`, aucun `aria-checked="true"`) ; « Écrire l'e-mail » refuse tant qu'aucune n'est choisie, avec une nouvelle chaîne « Choisissez une intention. ». Libellés, le français d'abord : « Pour l'élévation de l'âme (léïlouy nichmat) », « Pour une guérison complète (refoua chéléma) », « Pour la réussite (hatsla'ha) », « Pour trouver le bon conjoint (zivoug hagoun) », « Autre intention » ; en anglais : « For the elevation of the soul (le'ilui nishmat) », « For a complete recovery (refuah shelemah) », « For success (hatzlachah) », « For finding one's match (zivug hagun) » ; l'hébreu reste inchangé. Le texte d'introduction ne s'affiche qu'une fois, dans le dialogue ; la carte des réglages garde une phrase courte (« Dédiez votre hitbodedout ou votre étude, par l'intermédiaire de l'équipe. »). Ne rien promettre sur la publication (lieu, durée, gratuité) tant que le propriétaire n'en a pas décidé.

**Note du contre-expert.** Vérifié : Dedicace.kt:78 `check(idsIntentions[0])` et app.js:4434 `intention = 0` présélectionnent bien « Léïlouy nichmat », les libellés n'ont que translittération + hébreu, et le texte d'introduction s'affiche deux fois (activity_settings.xml:498 puis Dedicace.kt:93). En revanche, l'argument de la maquette est faux : le commit 4bd01df dit « sept emplacements de dédicace… (à choisir) ; rien n'est branché », ce n'est donc pas une promesse de l'application. Quant au scénario « ne lit pas l'hébreu », il est exagéré : les translittérations (« Refoua chéléma »…) sont l'usage courant du public visé. Le défaut est réel (un choix par défaut délicat), mais ce n'est ni un texte faux ni un bogue : mineur.

### TFRUX-06 — Présentation : ni la barrière du matin ni l'onglet Zmanim, et un dernier écran « Rien ne sort d'ici » qui parle d'OpenSky et d'adsbdb

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : android · **Type** : texte

**Constat.** Les sept écrans de la présentation décrivent la hitbodedout, la séance, la série, les textes, les réglages, le bravo et la confidentialité. La fonction qui donne son identité à l'édition complète, le blocage du matin, n'y est pas, et l'un des trois onglets (Zmanim : horaires, calendrier, boussole, vol) non plus. Le dernier écran porte un titre absolu, « Rien ne sort d'ici », que son propre corps dément dès la première phrase, et ce corps détaille le suivi d'un vol auprès d'OpenSky Network et l'envoi d'un numéro à adsbdb.com : c'est la première fois que le mot « vol » apparaît, le lecteur ne sait pas que l'application a un tel écran. 62 mots de précisions techniques pour une fonction marginale, là où il fallait une promesse simple et un renvoi.

**Preuve.** K/Onboarding.kt:47-93, sept écrans : « pratique », « seance », « jours », « textes », « reglages », « adresse », « prive ». strings.xml:206 « Rien ne sort d’ici » ; :207 « L’application ne se connecte à Internet que si vous le demandez vous-même : le suivi d’un vol en direct demande à OpenSky Network les avions d’une zone approchée, sans envoyer l’indicatif du vol ; la recherche d’un numéro de vol envoie ce numéro seul à adsbdb.com. Ce que vous écrivez reste sur ce téléphone… » ; :534 (aucune mention des zmanim) ; :673 « Zmanim ». FEUILLE_DE_ROUTE.md:1036 puis :1085 (le point 12 est tenu pour fait par le seul changement de nom).

**Correction proposée (revue par le contre-expert).** Titre du dernier écran : « Ce que vous écrivez reste ici ». Corps (il doit garder les mots exigés par OnboardingTest) : « Ce que vous écrivez reste sur ce téléphone, et n'en sort que si vous l'exportez ou le partagez vous-même. L'application ne va sur Internet que si vous le demandez, dans « Zmanim en vol » : le suivi d’un vol en direct interroge OpenSky Network sans envoyer l'indicatif du vol, et la recherche d'un numéro de vol envoie ce numéro seul à adsbdb.com. ». Mentionner l'onglet Zmanim dans un écran existant : « L'onglet Zmanim donne les horaires du jour, le calendrier hébraïque et la direction de Jérusalem, pour la ville que vous choisissez. ». Écran de la barrière (édition complète, après l'essai sur un vrai téléphone, et en passant OnboardingTest de 7 à 8 écrans) : « Le matin d'abord » / « Si vous le voulez, un écran se pose le matin devant les applications de votre choix tant que votre hitbodedout n'est pas faite : c'est « Je suis avec Hachem ». Il est éteint au départ et s'active dans les Réglages. ».

**Note du contre-expert.** Vérifié : les sept écrans (Onboarding.kt:47-93) ne parlent ni de « Je suis avec Hachem » ni de l'onglet Zmanim, et le titre « Rien ne sort d'ici » est plus absolu que son corps. Mais le détail réseau du dernier écran est un choix délibéré, verrouillé par un test : OnboardingTest exige « suivi d’un vol en direct » et « adsbdb.com » dans onboarding_private_body (« sa phrase le dit », 28/10). Le point 12 de la feuille de route vise le nom de la barrière, pas la présentation, et la barrière, jamais éprouvée sur un vrai téléphone, est volontairement « pas encore habillée » (FEUILLE_DE_ROUTE.md:593). Il s'agit d'une omission et d'un titre trop absolu, pas d'un texte faux : mineur.

### TFRUX-08 — Le blocage du matin porte cinq noms et trois verbes, et son écran n'affiche jamais « Je suis avec Hachem »

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : android · **Type** : texte

**Constat.** La même fonction s'appelle « Je suis avec Hachem » (carte, canal de notification), « le mode » (huit textes d'état, « Heures du mode », « État du mode »), « la barrière du matin » (les deux divulgations, qui disent aussi « couper la barrière »), « Avec Hachem » (pastille de l'accueil, suivie de « activée » ou « désactivée », ce qui se lit comme un jugement sur la personne) et « l'écran « Je suis avec Hachem » » (autorisation, bouton d'aperçu). Or cet écran s'intitule « Avez-vous fait votre hitbodedout ? » : les mots « Je suis avec Hachem » n'y figurent nulle part, l'aperçu ne permet donc pas de faire le lien. L'effet est dit par trois verbes : « bloquées », « retenu / retenir », « restent fermées ». La plage se dit « Heures du mode », « fenêtre », « plage horaire ». Le titre d'état « « Je suis avec Hachem » veille » se lit aussi « en veille », c'est-à-dire l'inverse. « %d applications bloquées » s'affiche comme un fait dans les réglages même mode éteint. « Durée du report » ne dit pas qu'il s'agit du bouton « Plus tard ».

**Preuve.** strings.xml:26 « État du mode », :27 et :222 « Je suis avec Hachem », :58 « « Je suis avec Hachem » veille », :60-61 « sont bloquées », :65-76 « Mode désactivé », « Le mode n’a rien à retenir », « Hors de la fenêtre », :28 « restent fermées », :84 « Voir l’écran « Je suis avec Hachem » maintenant » (47 caractères sur un bouton), :94 « Heures du mode », :95 « Durée du report », :137 « Avez-vous fait votre hitbodedout ? », :246-249 « %d applications bloquées », :504-507 « Avec Hachem » / « activée » / « désactivée », :1419 « la barrière du matin, le mode « Je suis avec Hachem » ». K/BlockerView.kt:76 (titre de l'écran) ; K/MainActivity.kt:371-373 ; K/SettingsActivity.kt:404-411 ; activity_settings.xml:278-286 (deux heures nues, sans « de… à… »).

**Correction proposée (revue par le contre-expert).** Garder « Je suis avec Hachem » comme seul nom affiché (décision du point 12) et ne pas introduire « Blocage du matin » dans l'interface. Pastille de l'accueil : « Avec Hachem » suivi de « activé » / « éteint » (au masculin). gate_armed_title : « « Je suis avec Hachem » est actif ». section_gate_state : « État de « Je suis avec Hachem » ». settings_window : « Plage horaire », avec « de » et « à » devant les deux heures. gate_window_title : « Hors de la plage horaire ». settings_snooze : « Durée de « Plus tard » ». apps_selected : « %d application choisie » / « %d applications choisies ». action_preview_gate : « Aperçu de l'écran ». Sur l'écran de garde, une ligne « Je suis avec Hachem » au-dessus de la question. Un seul verbe dans les textes d'état, « bloquer », à la place de « retenir » et de « restent fermées ».

**Note du contre-expert.** Vérifié : l'écran de garde (BlockerView.kt:76 et 122, view_blocker.xml) ne porte jamais « Je suis avec Hachem », alors que le bouton (strings.xml:84) et l'autorisation y renvoient. Sont aussi exacts : « %d applications bloquées » affiché même mode éteint (SettingsActivity.kt:405-411), « Heures du mode » suivi de deux heures nues, et « Avec Hachem » + « activée » au féminin alors que « mode » est masculin. En revanche, les « cinq noms » sont surtout des reprises normales (« le mode « Je suis avec Hachem » ») ; la lecture de « veille » comme « en veille » et le « jugement sur la personne » sont subjectifs. Surtout, la recommandation d'un nom commun « Blocage du matin », jusque sur la pastille de l'accueil, va contre la décision du propriétaire de nommer la fonction « Je suis avec Hachem » plutôt que « blocage » (FEUILLE_DE_ROUTE.md:158-162 et :1085).

### TFRUX-09 — Mots hébreux sans glose aux points d'entrée : 26 chaînes, dont le deuxième écran de la présentation

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le premier écran explique la hitbodedout à un débutant complet ; le deuxième lui parle aussitôt de « niggoun » et de « ’hizouk » sans les définir, le quatrième aligne « Tikoun HaKlali, Tehilim, siddour, Tefilot ». Même défaut là où l'on doit choisir : trois sujets de séance sur dix (« Zivoug », « Parnassa », « Avodat Hachem »), les neuf autres sujets de prières (« Zéra chel kayama », « Chmirat habrit », « Guéoula »…), deux questions d'aide (« parnassa, chalom bayit, un chidoukh », « émouna »), l'écran d'abandon (« ’Hazak ! », « ’Hizki ! »), un conseil (« ’hechbon nefech »), et des titres d'écran (« Zmanim », « Hilloulot », « Halakha yomit », « Birkat haLevana », « Noussa’h »). Aucun lexique dans l'application. Le choix de « Tehilim » plutôt que « psaumes » est une décision consignée (19/10) : il ne s'agit pas de retirer les mots, mais de les faire suivre une fois de leur sens.

**Preuve.** strings.xml:530 « Un niggoun peut vous accompagner. Un mot de ’hizouk ouvre et clôt la hitbodedout » ; :534 ; :484-486 ; :518-526 ; :1207 « parnassa, santé, chalom bayit, un chidoukh » ; :1208 ; :588-589 ; :392 ; :1167 « J’ai besoin de ’hizouk » ; :673, :880, :1057, :1033, :664. K/MainActivity.kt:303-306 (la liste des sujets est un simple choix de libellés). FEUILLE_DE_ROUTE.md:1062-1063.

**Correction proposée.** Gloser à la première rencontre. onboarding_session_body : « …Une mélodie (niggoun) peut vous accompagner. Un court texte d'encouragement (’hizouk) ouvre et clôt la hitbodedout… » ; onboarding_texts_body : « Le Tikoun HaKlali (les dix psaumes choisis par Rabbi Na'hman), les Tehilim (Psaumes), le siddour (livre de prières), des prières de Rabbi Natan classées par sujet, une bibliothèque et des conseils, à ouvrir quand vous voulez. » ; sujets : « Zivoug (trouver son conjoint) », « Parnassa (subsistance) », « Avodat Hachem (servir Hachem) » ; prières : « Sim'ha (joie) », « Kedoucha (sainteté) », « Zéra chel kayama (avoir des enfants) », « Chmirat habrit (pureté) », « Guéoula (délivrance) », « Refoua chelema (guérison) » ; question_besoins : « De quoi avez-vous besoin : subsistance (parnassa), santé, paix du foyer (chalom bayit), rencontrer votre conjoint (chidoukh) ? » ; question_force : « …foi (émouna), joie, patience ? » ; annulation : « ’Hazak, courage ! » / « ’Hizki, courage ! » ; tip_6 : « un vrai bilan de l'âme (’hechbon nefech) » ; titres : « Zmanim : horaires du jour », « Hilloulot (anniversaires des tsadikim) », « Birkat haLevana (bénédiction de la lune) », « Rite (noussa'h) ».

### TFRUX-10 — Site et édition Light : des aides communes parlent du « mode », des rappels et de « ce téléphone », qui n'y existent pas

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le site relit les chaînes d'Android. Seule la présentation a reçu des variantes « _web » ; cinq aides des réglages s'affichent telles quelles. Le site n'a ni blocage ni rappels, et pourtant : « Ces jours-là : le mode se tait, pas de rappel… », « …réglages et rappels » dans les deux textes de réinitialisation, « ce téléphone » dans trois textes, « Il ne quitte pas le téléphone ». Dans l'édition Light d'Android, les cartes de la barrière sont masquées mais l'aide de « Chabbat et Yom Tov » dit toujours « le mode se tait » : le mot ne renvoie plus à rien.

**Preuve.** web/src/js/app.js:4415 `tr.t('settings_shabbat_hint')`, :4348-4349 `reset_hint` et `reset_confirm_text`, :4401 `settings_name_hint`, :4500 `section_data_hint` ; aucune occurrence de `reminders_` ni de `section_gate` dans app.js. strings.xml:109 « Ces jours-là : le mode se tait, pas de rappel, et la série reste intacte. » ; :936 et :939 « …les réglages et les rappels seront effacés de ce téléphone » ; :509. K/SettingsActivity.kt:511-515 (Light : cartes card_gate_state et card_gate_settings masquées) alors qu'activity_settings.xml:373 garde l'aide ; light/res/values/strings.xml ne redéfinit que onboarding_private_body.

**Correction proposée.** Variantes : settings_shabbat_hint_web « Ces jours-là, rien n'est attendu et la série reste intacte. » ; pour Light (light/res/values/strings.xml) « Ces jours-là : pas de rappel, et la série reste intacte. » ; reset_hint_web « Efface tout ce que l'application garde dans ce navigateur : journal, hitbodedout, séries, trophées et réglages. Exportez d'abord vos données si vous voulez les garder. » ; reset_confirm_text_web « Le journal, les hitbodedout, les séries, les trophées et les réglages seront effacés de ce navigateur. Cela ne peut pas être annulé. » ; settings_name_hint_web « Pour que l'accueil vous salue. Il ne quitte pas cet appareil. ».

### TFRUX-11 — Le bouton et l'écran qu'il ouvre ne portent pas le même nom : sept fonctions concernées

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** « Halakha yomit » (bouton de l'onglet Zmanim, titre de la carte) ouvre « Halakha du jour » (titre d'écran, réglage « Afficher la halakha du jour », lien « Toute la halakha du jour »). « Boussole prière » ouvre « Vers Jérusalem », dont la vignette s'appelle « Direction de Jérusalem ». « En vol » ouvre « Zmanim en vol ». Le bouton « Trophées » ouvre « Trophées et paliers », dont le canal de notification s'appelle « Paliers et trophées ». « Bibliothèque » désigne l'onglet des textes, la liste des morceaux de musique, et « une bibliothèque » dans la présentation, tandis que l'écran des sources s'intitule « Sources de la hitbodedout ». L'écran « Tehilim » navigue par « Psaume précédent / Psaume suivant » et le siddour annonce « Psaume du dimanche », contre la décision du 19/10 (huit chaînes). Enfin trois façons de mettre de côté : « Garder » / « Textes gardés » ('hizouk), « Favoris », « Marque-pages ».

**Preuve.** strings.xml:1057 et :852 « Halakha yomit » / :904 « Halakha du jour » (K/ZmanimActivity.kt:59, activity_halakha.xml:29) ; :684 « Boussole prière » / :1368 « Vers Jérusalem » / :1384 « Direction de Jérusalem » ; :683 « En vol » / :1247 « Zmanim en vol » ; :932 / :913 « Trophées et paliers » / :933 « Paliers et trophées » ; :494 « Bibliothèque », :267 « Bibliothèque », :410 « Sources de la hitbodedout » ; :634-635 et :758-763 « Psaume… » contre FEUILLE_DE_ROUTE.md:1062 ; :1170-1174 « Garder », « Textes gardés » / :1094-1098 « Favoris », « Marque-pages ».

**Correction proposée.** Aligner sur le titre de l'écran : zmanim_bouton_halakha et halakha_yomit_titre « Halakha du jour » ; zmanim_bouton_boussole et boussole_widget_label « Vers Jérusalem » ; zmanim_bouton_vol « Zmanim en vol » ; trophees_paliers et channel_celebration « Trophées et paliers » ; nav_texts « Textes » (c'est le nom de sa clé) ; music_library « Morceaux » ; tehilim_previous / tehilim_next « Tehilim précédent » / « Tehilim suivant », ajout_jour_1 à 6 « Tehilim du dimanche »… ; chizuk_garder « Ajouter aux favoris », chizuk_garde « Dans les favoris », chizuk_favoris « Favoris ».

### TFRUX-12 — Messages d'échec : cinq ne disent pas quoi faire, un sixième s'affiche pour une autre panne que la sienne

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** « Cet écran de réglages n'existe pas sur ce téléphone. » sert pour tout lancement raté, y compris l'ouverture des règles de confidentialité quand aucun navigateur ne répond : le message est alors faux, et dans tous les cas il n'indique aucun autre chemin. « Le fichier n'a pas pu être lu. » couvre aussi le refus d'un fichier de plus de 2 Mo. « L'export a échoué. » s'arrête là. « Ce fichier n'a pas pu être ajouté durablement. » emploie un mot de développeur (la permission persistante). « Aucune messagerie trouvée : écrivez à… » s'affiche pendant que le dialogue de dédicace se ferme, texte saisi perdu. « L'appareil ne connaît pas le fuseau horaire de cet aéroport. » ne propose rien.

**Preuve.** K/SettingsActivity.kt:624-630 (`safeStart` appelé pour LIEN_CONFIDENTIALITE, toast settings_screen_missing), :566 et :572-574 (`total > IMPORT_MAX_OCTETS` puis import_failed), :547-551 ; K/MusicActivity.kt:156-165 ; K/Dedicace.kt:132-133 (toast puis `dialogue.dismiss()`). strings.xml:112, :231, :232, :270, :51, :1290.

**Correction proposée.** settings_screen_missing : « Impossible d'ouvrir cet écran d'ici. Passez par les Paramètres d'Android, Applications, MyHitbodedut. » et, pour le lien, une chaîne propre : « Aucun navigateur n'a pu ouvrir la page. » ; import_failed : « Ce fichier n'a pas pu être lu. Choisissez le fichier .json créé par « Exporter » (2 Mo au plus). » ; export_failed : « L'export a échoué. Choisissez un autre dossier, par exemple Téléchargements, puis réessayez. » ; music_add_failed : « Ce morceau n'a pas pu être ajouté. Copiez-le dans la mémoire du téléphone, puis réessayez. » ; dédicace : garder le dialogue ouvert et afficher « Aucune application d'e-mail sur ce téléphone. Écrivez à myhitbodedut26@gmail.com. » ; vol_invalide_fuseau_inconnu : « Fuseau horaire inconnu pour cet aéroport : choisissez un aéroport voisin. ».

### TFRUX-13 — Recherche : l'invite promet « le siddour, les livres, la halakha », le calcul ne lit que les titres et l'hébreu, et l'échec s'affiche « Résultats : 0 »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** Le champ invite à « Rechercher dans le siddour, les livres, la halakha, les hilloulot ». Le corps des textes n'est comparé qu'à l'hébreu (champ `texte`) ; les traductions françaises et anglaises des blocs (`fr`, `en`) ne sont pas interrogées. Un lecteur français qui tape « guérison » ou « joie » obtient « Résultats : 0 », sans phrase d'état vide ni indication de ce qui est cherchable. Le compteur réutilise la chaîne des hilloulot et n'est pas accordé (« Résultats : 1 »).

**Preuve.** strings.xml:1088 « Rechercher dans le siddour, les livres, la halakha, les hilloulot » ; :885 « Résultats : %1$d ». K/RechercheGlobale.kt:30-33 : titre, puis `firstOrNull { !it.consigne && nu(it.texte).contains(q) }` ; K/Siddur.kt:12 `SiddurBloc(val texte: String, val consigne: Boolean, val fr: String? = null, val en: String? = null)` ; K/RechercheActivity.kt:98.

**Correction proposée.** Tant que les traductions ne sont pas interrogées : recherche_indice « Un titre, ou un mot en hébreu » ; état vide (nouvelle chaîne) « Aucun résultat. La recherche porte sur les titres et sur le texte hébreu : essayez un titre (« Cha'harit », « Likoutei ») ou un mot en hébreu. » ; compteur en pluriel : « %1$d résultat » / « %1$d résultats ».

### TFRUX-14 — Rappels : « Plus tard » sans durée, silence du vendredi après-midi jamais dit, canal mal décrit, interrupteur « Me le rappeler »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** Sur la notification de rappel, « Plus tard » repousse de 30 minutes sans l'annoncer, alors que l'écran de blocage écrit « Plus tard (15 min) » : même libellé, deux durées, une seule affichée. Le rappel se tait aussi la veille d'un Chabbat ou d'une fête à partir de midi ; l'écran des rappels ne le dit pas (la seule phrase qui parlait des jours de repos, reminders_hint, n'est plus référencée nulle part), et les réglages disent seulement « Ces jours-là… pas de rappel ». Un rappel unique réglé à 14 h ne sonne donc jamais le vendredi, sans explication. Le canal « Rappels », décrit « Rappel quotidien et fin de hitbodedout. », porte aussi l'annonce de Chabbat, Birkat haLevana et les rappels en vol : on ne peut pas couper l'une sans l'autre et la description est inexacte. Dans la présentation, l'interrupteur « Me le rappeler chaque jour » n'a pas d'antécédent pour « le ».

**Preuve.** K/Reminder.kt:35 `const val SNOOZE_MINUTES = 30`, :193 ; strings.xml:466 « Plus tard » contre :142 « Plus tard (%1$d min) ». K/ReminderRule.kt:17 `NO_SUNSET_CUTOFF_MINUTES = 12 * 60`, :68-79 ; activity_reminders.xml:70 et :112 (seules aides affichées) ; strings.xml:454 (0 référence), :457. K/ChabbatAlerte.kt:70, K/LevanaAlerte.kt:87, K/VolAlerte.kt:123, K/SessionService.kt:327 : tous sur CHANNEL_REMINDER ; strings.xml:227. :539 « Me le rappeler chaque jour ».

**Correction proposée.** reminder_action_later « Dans 30 min » ; reminders_enable_hint « Un rappel aux heures réglées, tant que la hitbodedout du jour n'est pas faite. Rien ne sonne le Chabbat et les jours de fête, ni la veille à partir de midi. » ; channel_reminder_description « Rappel de la hitbodedout, fin de hitbodedout, annonce de Chabbat, Birkat haLevana, rappels en vol. » (mieux : un canal « Annonces du calendrier » à part) ; onboarding_rappel « Me rappeler ma hitbodedout chaque jour ».

### TFRUX-15 — Notification du vendredi : « Double neshama, double simha et double repas ! Tentez une double hitbodedout. »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** Trois défauts dans deux lignes envoyées chaque vendredi dès qu'un lieu est choisi. Le vocabulaire : « neshama » et « simha » ne sont ni expliqués ni écrits comme ailleurs dans l'application (« Sim’ha », « nichmat »). Le fond : la tradition parle d'une âme supplémentaire et de deux pains ; « double repas » ne correspond à aucun usage (les repas de Chabbat sont trois). La cohérence : l'alerte invite à une « double hitbodedout » alors que, le lendemain, l'accueil affiche « Pas de hitbodedout attendue aujourd’hui » et que le mode comme les rappels se taisent ; on ne sait pas si l'invitation vaut pour l'après-midi ou pour Chabbat. Le titre annonce « Chabbat dans 3 h » alors que l'alarme est calée trois heures avant l'allumage des bougies. Ton de réclame (« préparez-vous à en profiter ! », trois points d'exclamation) qui tranche avec le reste.

**Preuve.** strings.xml:1024 « Chabbat dans 3 h : préparez-vous à en profiter ! » ; :1025 « Double neshama, double simha et double repas ! Tentez une double hitbodedout. » ; :518 « Sim’ha » ; :42 « Léïlouy nichmat » ; :10 « Pas de hitbodedout attendue aujourd’hui ». K/ChabbatAlerte.kt:16-19 « trois heures avant l'allumage des bougies du vendredi », :64-75.

**Correction proposée.** Titre : « Allumage des bougies dans 3 heures ». Texte : « Encore le temps d'une hitbodedout avant Chabbat. Chabbat chalom ! ». Si l'image de l'âme supplémentaire tient au propriétaire : « Chabbat apporte une âme de plus (nechama yetera) : accueillez-le par une hitbodedout avant l'allumage. ».

### TFRUX-16 — Ton : « Jour sans obligation », « ne compte pas contre vous », « Abandonner », « La prochaine fois sera meilleure »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte · déjà connu ou choix assumé

**Constat.** L'application est dans l'ensemble bienveillante, mais cinq textes installent une logique de dette. « Jour sans obligation » (titre d'état, et libellé lu pour chaque case de pause de la semaine) suppose que les autres jours en sont une. « la journée ne compte pas contre vous » suppose que les jours manqués comptent contre vous ; la même aide cite « un Yom Tov », déjà géré tout seul par l'interrupteur placé juste au-dessus, ce qui laisse croire qu'il faut le déclarer. « Pas de hitbodedout attendue aujourd'hui » se lit comme une règle religieuse (on ne ferait pas hitbodedout le Chabbat) alors que seule l'application se met en retrait. Le bouton « Abandonner » et son titre « Abandonner la hitbodedout ? » chargent un geste banal. Après l'abandon, « La prochaine fois sera meilleure. » dit que celle-ci était mauvaise. Cette dernière phrase et le principe « n'attend rien » sont des choix consignés du propriétaire.

**Preuve.** strings.xml:71 « Jour sans obligation » (K/MainActivity.kt:870) ; :111 « Pour un Yom Tov, un voyage, une maladie : la journée ne compte pas contre vous. » avec :108-109 ; :10 ; :156 et :159 ; :591 « Pour tout ce que vous avez fait jusqu’ici. La prochaine fois sera meilleure. ». FEUILLE_DE_ROUTE.md:697-700 (phrase demandée le 28/09) ; K/MainActivity.kt:771-773 (revue du 30/09).

**Correction proposée.** gate_exempt_title « Jour de pause » ; settings_exempt_today_hint « Voyage, maladie, journée impossible : aujourd'hui n'est pas compté et votre série est préservée. » ; status_rest « Jour de pause : votre série est préservée » ; session_cancel « Arrêter sans enregistrer », session_cancel_title « Arrêter sans enregistrer ? » ; annulation_subtitle « Ce que vous avez fait jusqu'ici reste acquis. Vous reprendrez quand vous voudrez. ».

### TFRUX-17 — « Comment vous appeler ? » ne demande pas le prénom, et « Tsadik / Tsadeket / Pas choisi » n'est jamais expliqué

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** La question « Comment vous appeler ? » (6e écran de la présentation, puis ligne des réglages) fait attendre un champ de prénom ; elle ouvre un choix entre « Tsadik » et « Tsadeket ». Le prénom, lui, se saisit ailleurs, sous « Rythme ». Le corps parle d'un « mot qui vous convient » sans dire que ce mot signifie « juste », que le choix est celui du masculin ou du féminin, ni qu'il change aussi le personnage et l'icône de l'application. Dans les réglages, la troisième valeur s'appelle « Pas choisi », libellé d'état et non d'option.

**Preuve.** strings.xml:537 « Comment vous appeler ? » ; :538 « À la fin de chaque hitbodedout, l’application vous félicite. Choisissez le mot qui vous convient ; vous pourrez le changer dans les réglages. » ; :555-557 « Tsadik », « Tsadeket », « Pas choisi » ; :562 ; :508 « Prénom ». K/Onboarding.kt:79-85 ; K/SettingsActivity.kt:391 et :453 ; AndroidManifest.xml (« L'icône de lancement suit le choix צדיק / צדקת »).

**Correction proposée.** onboarding_adresse « Tsadik ou Tsadeket ? » ; onboarding_adresse_body « À la fin de chaque hitbodedout, l'application vous félicite : « Bravo, Tsadik ! » au masculin, « Bravo, Tsadeket ! » au féminin (le mot veut dire « juste »). Le personnage et l'icône suivent ce choix. Vous pouvez aussi passer : le bravo restera neutre. » ; settings_adresse « Bravo au masculin ou au féminin » ; adresse_none « Neutre ».

### TFRUX-18 — Trophées : cinq notions (trophée, niveau, grade, palier, record) et la seule phrase qui les expliquait n'est plus affichée

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** L'écran « Trophées et paliers » manie des trophées, des niveaux, des grades nommés par des métaux, des paliers et des records, sans jamais dire comment ils s'articulent. La chaîne qui l'expliquait (trophees_explication) n'a plus aucune référence dans le code. Il en reste des phrases opaques : « En Bronze : c'était votre 3ᵉ trophée. », « Grade Bronze ». Dans le rappel quotidien et sur l'accueil, la distance au prochain trophée est donnée sans unité : « Plus que 2 pour « 30 minutes en un jour ». », « Prochain trophée : … · encore 2 ». Le bouton « Partager mon grade » envoie « Grade Bronze sur MyHitbodedut : 3 trophées, jour après jour. », formule de classement appliquée à une prière solitaire.

**Preuve.** strings.xml:1017 « Chaque trophée monte de niveau en niveau, du bronze à l’argent, à l’or puis au platine… » (0 référence dans K et web/src) ; :915 « Grade %1$s » ; :1117 « En %1$s : c’était votre %2$dᵉ trophée. » ; :1019 ; :865 ; :870 ; :1129 « Plus que %1$d pour « %2$s ». » (K/Reminder.kt:140-141) ; :1121 ; :1123.

**Correction proposée.** Réafficher une explication en tête d'écran : « Un trophée se gagne niveau par niveau. Votre grade (bronze, argent, or, platine) monte avec le nombre de trophées gagnés. Les paliers sont les objectifs du jour, de la semaine et du mois. » ; trophee_detail_grade « Votre %2$dᵉ trophée, gagné au grade %1$s. » ; rappel_trophee_proche « Un trophée est tout proche : « %2$s » (il en manque %1$d). » ; accueil_prochain_trophee « Prochain trophée : %1$s (il en manque %2$d) ».

### TFRUX-19 — « Bon après-midi, Prénom » à l'accueil : une formule d'au revoir, contre la règle écrite dans le code

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** De 12 h à 18 h, l'accueil salue par « Bon après-midi, %1$s ». En français cette formule se dit en quittant quelqu'un, pas en l'accueillant. Le commentaire de la règle le sait : « Le français dit « bonjour » jusqu'au soir, puis « bonsoir » ; l'anglais et l'hébreu distinguent aussi l'après-midi… chaque langue les nomme à sa façon dans ses chaînes. » La chaîne française n'a pas suivi.

**Preuve.** strings.xml:491 « Bon après-midi, %1$s ». K/Salutation.kt:6-9 et :21 `in 12 until 18 -> Partie.APRES_MIDI`.

**Correction proposée.** hero_greeting_afternoon : « Bonjour, %1$s ».

### TFRUX-20 — Écran de séance : cinq textes inexacts ou bancals

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** « Le temps déjà écoulé sera enregistré et la journée validée. » est faux avant une minute pleine : rien n'est inscrit. « Fait aujourd'hui : %1$s. Le chiffre ci-dessus est la durée de la prochaine. » explique l'écran au lieu de le rendre clair, et donne « Fait aujourd'hui : 0 min. » après « Je l'ai déjà faite ». « Sans durée : vous arrêtez quand vous arrêtez. » est une tautologie, et tait le plafond de quatre heures. « Durée réglable… » pour dire « autre durée » ; sa consigne « De 1 à 240 minutes » est invisible parce que le champ est prérempli, et une valeur hors bornes est ramenée sans message. « Rien à l'écran pendant la hitbodedout, un son discret à la fin. » : seul le décompte disparaît (personnage, textes et boutons restent), et le son est la sonnerie de notification du téléphone, qui n'a rien de discret si elle ne l'est pas.

**Preuve.** strings.xml:158 ; K/SessionService.kt:189 `if (close.minutes > 0 || !early)`. :152 ; K/SessionActivity.kt:322-323 ; K/GateService.kt:144 `Store.addSession(this, 0)`. :164 ; K/SessionRule.kt:88 `PLAFOND_OUVERTE = 240`. :597, :599 ; K/DureeSeance.kt:24 `coerceIn(MIN, MAX)`, :44-45 `hint = …duration_custom_hint` puis `setText(…)`. :167 ; K/SessionService.kt:207-211 `RingtoneManager.TYPE_NOTIFICATION`.

**Correction proposée.** session_finish_message « Les minutes entières déjà écoulées seront enregistrées et la journée validée. Avant une minute, rien n'est enregistré. » ; session_idle_done « Déjà %1$s aujourd'hui. Durée de la prochaine : ci-dessus. » (et « Journée déjà validée. » quand le total est nul) ; session_open_caption « Sans durée : vous terminez quand vous voulez (4 h au plus). » ; duration_custom « Autre durée… » ; duration_custom_title « Durée, en minutes (de 1 à 240) » ; settings_hide_countdown_hint « Le décompte disparaît de l'écran et de la notification ; la sonnerie de notification du téléphone signale la fin. ».

### TFRUX-21 — Zmanim en vol : le texte qui recueille l'accord ne dit pas ce qu'OpenSky reçoit, et les phrases précises sont du code mort

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** Le dialogue « Chercher la route en ligne ? » et la ligne sous l'interrupteur « Services en ligne » affichent le même texte. Il commence par une phrase d'état qui n'a pas sa place dans une demande d'accord (« Désactivés par défaut : rien ne quitte le téléphone. ») et dit du suivi seulement qu'il « interroge OpenSky Network ». Or la demande envoie un carré de 10° autour de la position estimée de l'avion, donc de l'utilisateur. Une fois l'interrupteur activé, plus aucun texte ne s'affiche. Les trois chaînes qui décrivaient exactement ce qui part ne sont référencées nulle part.

**Preuve.** strings.xml:1429 « Désactivés par défaut : rien ne quitte le téléphone. Activés, la loupe 🔍 envoie le seul numéro de vol à adsbdb.com pour remplir l’arrivée, et le suivi en direct interroge OpenSky Network. » ; K/VolActivity.kt:476-480 (message du dialogue), :999 `if (!actif) carte.addView(… vol_en_ligne_aide …)`. K/SuiviVol.kt:110 `DEMI_COTE = 5.0`, :125-128 `lamin… lomax`. strings.xml:1267, :1331, :1364 « …les avions vus dans un carré de 10° autour de la position estimée ; l’indicatif reste sur le téléphone… » : 0 référence.

**Correction proposée.** Message du dialogue et ligne permanente sous l'interrupteur, actif ou non : « Avec les services en ligne, deux choses peuvent partir, et seulement quand vous touchez le bouton : la loupe envoie le numéro de vol, seul, à adsbdb.com ; « Position en direct » demande à OpenSky Network les avions d'une zone de 10° autour de la position estimée de l'avion. L'indicatif reste sur le téléphone. » (version à adapter si l'édition est construite avec un relais, qui reçoit alors l'indicatif).

### TFRUX-22 — Annuler se dit « Retour » dans onze dialogues, « Annuler » dans trois

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** Le bouton négatif des dialogues est « Retour » onze fois (prénom, langue, durée, dédicace, choix de liste, « Terminer la hitbodedout ? », « Abandonner la hitbodedout ? »…), « Annuler » dans la réinitialisation, et le « Annuler » du système dans deux dialogues du vol. Devant « Abandonner la hitbodedout ? [Abandonner] [Retour] », « Retour » peut se lire « retour à l'accueil », soit l'inverse de l'intention.

**Preuve.** `setNegativeButton(R.string.action_back` : 11 occurrences dans K (dont K/SessionActivity.kt:436 et :450, K/SettingsActivity.kt:216, :446, :461, :506, K/DureeSeance.kt, K/Dedicace.kt:105) ; `R.string.reset_confirm_no` : 1 ; `android.R.string.cancel` : 2. strings.xml:91 « Retour » ; :941 « Annuler ».

**Correction proposée.** « Annuler » partout où l'on renonce à un réglage ; dans les deux dialogues de séance, un bouton qui dit ce qui se passe : « Continuer la hitbodedout ».

### TFRUX-23 — « Ne pas déranger » : « mode « priorité » » est du vocabulaire d'Android, et l'aide ne dit pas ce qui passe encore

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** L'aide annonce que « le téléphone passe en mode « priorité » », terme interne d'Android que l'écran système français n'emploie pas. Elle ne dit pas ce que l'utilisateur veut savoir avant d'activer : les alarmes et les appels qu'il a marqués prioritaires continuent de passer. Activer l'interrupteur ouvre aussitôt un écran d'Android sans dire quoi y faire.

**Preuve.** strings.xml:1086 « Le téléphone passe en mode « priorité » le temps de la hitbodedout, puis revient comme avant. Android demande une autorisation la première fois. ». K/NePasDeranger.kt:7-9 « les alarmes et les appels prioritaires passent, comme l'utilisateur les a réglés » ; K/SettingsActivity.kt:321-323.

**Correction proposée.** « Pendant la hitbodedout, les notifications sont coupées ; les alarmes et les appels que vous avez marqués prioritaires passent toujours. Le téléphone revient ensuite à son réglage d'avant. La première fois, Android ouvre un écran : autorisez-y MyHitbodedut. ».

### TFRUX-24 — Boussole : une note de 139 mots d'un seul bloc, avec une digression, et « le hassid » jamais présenté

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** « Deux façons de calculer » tient en un paragraphe de 139 mots (815 caractères) en petit corps : deux méthodes, quatre références, deux exemples chiffrés, les coordonnées du lieu visé, et une phrase sur la carte Equal Earth et l'ONU qui n'aide pas à s'orienter (le fait est exact, vérifié : résolution du 4 septembre 2026). Quatre textes de la boussole parlent du « hassid » comme d'un terme connu ; nulle part l'application ne dit que c'est le nom de son personnage.

**Preuve.** strings.xml:1383 (K/BoussoleActivity.kt:160, taille 13) « …La carte Equal Earth, que l’ONU recommande depuis septembre 2026, sert à comparer la surface des continents ; elle ne donne pas de direction… » ; :1369 « Choisissez un lieu : le hassid se tourne vers Jérusalem. » ; :1385 ; :1396 « Le hassid se tourne (par défaut) ».

**Correction proposée.** Couper en quatre paragraphes et retirer la phrase sur Equal Earth : « Deux façons de calculer la direction de Jérusalem.\n\nLa direction réelle (grand cercle), suivie par défaut : le Choul'han Aroukh haRav (Ora'h 'Haïm 94, 2) et le Mor ouKetsia (150) la tiennent pour préférable. De New York : environ 54°.\n\nLa ligne droite sur une carte de Mercator (cap constant), qu'on lit par exemple dans le Levouch (Ora'h 'Haïm 94). De New York : environ 96°.\n\nVous choisissez dans « Direction suivie » ; l'autre reste affichée pour information. Calculé sur l'appareil, vers Har haBayit, déclinaison magnétique corrigée. » ; boussole_carte_sous « Choisissez un lieu : le personnage se tourne vers Jérusalem. » ; boussole_affichage_hassid « Le personnage se tourne (par défaut) ».

### TFRUX-25 — Partage : « Essayez, vous aussi, gratuitement » ajouté d'office, y compris sous un texte de 'hizouk

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte · déjà connu ou choix assumé

**Constat.** Le bravo de fin de séance propose en bonne place « Partager ma hitbodedout », et chaque partage se termine par une invitation rédigée à la place de l'utilisateur : « Essayez, vous aussi, gratuitement : » suivie du lien. La même ligne est collée sous un texte de 'hizouk partagé, où elle se lit comme la suite de la citation. Le lien joint au partage est une demande du propriétaire ; la formule, elle, peut être plus sobre.

**Preuve.** strings.xml:945 « Essayez, vous aussi, gratuitement : %1$s » ; :942-943. K/CelebrationActivity.kt:192-196 ; K/ChizukActivity.kt:107 `getString(R.string.partage_lien, CelebrationActivity.LIEN_WEB)`.

**Correction proposée.** Après une séance : « L'application : %1$s ». Sous un texte de 'hizouk, une chaîne distincte : « Lu dans MyHitbodedut : %1$s ».

### TFRUX-26 — Sept tournures obscures dans des aides et des invites

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** « Cinq temps pour savoir par quoi continuer » ne dit pas ce que fait l'option. « Ce qui est monté, ce qui a été demandé… » : « monté » sans complément n'est pas compris. « Pas de position fraîche » : on ne dit pas d'une position qu'elle est fraîche. « Sans elles, le rappel se programme et n'apparaît jamais, et la hitbodedout n'affiche rien quand le téléphone est posé. » : la seconde moitié est incompréhensible. « Ce que l'anneau du jour mesure. Sans réglage, c'est la durée d'une hitbodedout. » : on ne sait pas ce qu'est « l'anneau du jour » avant de l'avoir vu. « La série en cours, et de quoi commencer d'un geste. » (description de la vignette). « La leçon citée traite d'un autre sujet ; c'est la prière qui porte cette demande. » : mention voulue par la feuille de route, mais illisible sans savoir qu'une prière de Rabbi Natan naît d'une leçon.

**Preuve.** strings.xml:185, :217, :681, :122, :98, :172, :516 (FEUILLE_DE_ROUTE.md:231-233 pour cette dernière).

**Correction proposée.** settings_hitbodedut_hint « Pendant la hitbodedout, cinq étapes s'affichent une à une : se confier, regretter, demander, prier sur son étude, remercier. D'après Likoutei Moharan II, 25 et le Rambam (Hilkhot Tefila 1, 2). » ; note_hint « Ce que vous avez dit, ressenti, demandé… » ; zmanim_position_ancienne « Position actuelle introuvable : la dernière connue est utilisée. » ; permission_notifications_why « Pour afficher le rappel du jour, et le décompte pendant la hitbodedout. Sans elles, rien n'apparaît. » ; settings_daily_goal_hint « Le temps de hitbodedout visé chaque jour. Sans réglage : la durée d'une hitbodedout. » ; widget_description « Votre série, et un bouton pour commencer. » ; tefilot_warning « Cette prière vient d'une leçon de Likoutei Moharan sur un autre sujet ; la demande, elle, est bien dans la prière. ».

### TFRUX-27 — « Région : Israël / Diaspora » sans un mot sur ce que le réglage change

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** La ligne « Région » n'a pas d'aide. Placée sous « Chabbat et Yom Tov », elle décide du deuxième jour de fête, donc des jours où la série est préservée et le rappel coupé ; mais « Région » fait penser au lieu des zmanim, qui se règle ailleurs. Un voyageur ne sait pas s'il doit y toucher.

**Preuve.** strings.xml:373 « Région », :374-375 ; activity_settings.xml:384 (libellé seul, aucune ligne d'aide) ; K/Store.kt:390 « Israël ou diaspora : décide du deuxième jour de fête. ».

**Correction proposée.** settings_region « Jours de fête » ; valeurs « Israël (un jour) » et « Diaspora (deux jours) » ; aide : « Décide du deuxième jour de Yom Tov. À ne pas changer pour un simple voyage. ».

### TFRUX-28 — « Mon parcours » puis « vos hitbodedout », « Mes données » puis « Exportez » : première et deuxième personne mêlées dans un même bloc

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les boutons parlent à la première personne et c'est cohérent (« Je l'ai faite sans le téléphone », « J'ai besoin de ’hizouk », « Me rappeler la hitbodedout »). Les titres, eux, hésitent : « Mon parcours » est suivi de « Ce que vos hitbodedout disent de votre chemin. », « Mes données » de « Exportez de temps en temps. », tandis que d'autres titres de même rang sont à la deuxième personne (« Votre semaine », « Vos sujets les plus fréquents », « votre plus longue série »).

**Preuve.** strings.xml:1181 « Mon parcours » et :1182 ; :32 « Mes données » et :33 ; :1124 « Votre semaine » ; :1189 ; :610.

**Correction proposée.** Règle unique : première personne pour ce que l'utilisateur dit ou fait (boutons, interrupteurs), deuxième pour tout ce que l'application lui dit (titres, aides). Donc « Votre parcours », « Vos données ».
