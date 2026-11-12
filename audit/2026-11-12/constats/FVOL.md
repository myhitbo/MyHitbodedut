# FVOL — Android et web — le mode « En vol »

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

19 constats — confirmés : 7 · confirmés en partie : 3 · non contre-expertisés (mineurs et cosmétiques) : 9.

## Ce qui a été examiné

Lus en entier : Vol.kt, VolActivity.kt (1 270 lignes), SaisieVol.kt, SuiviVol.kt, RouteVol.kt, VolAlerte.kt, VolCalendrier.kt, VolPriere.kt, VolRappels.kt, Aeroports.kt, CarteEmbarquement.kt et LecteurBillet.kt ; web/src/js/vol.js et la partie vol de app.js (lignes 3343 à 3805) ; ZMANIM.md § « En vol » ; PUBLICATION_PLAY_STORE.md § 3.1 ; tools/relais_vol/README.md ; les 137 chaînes vol_* en français (contrôle de leur usage sur Android et sur le web), avec une vingtaine comparées en anglais et en hébreu ; la section « Les vols » de confidentialite.html, telle que déployée ; les extraits de Store.kt, BootReceiver, ZmanimWidget.prochaine, HorairePriere, des manifestes et de build.gradle.kts qui touchent au vol. Échantillonnés : VolTest (une dizaine de tests sur 16), SaisieVolTest et vol.test.mjs (recherche de cas). Exécuté avec Node 22 sur le module web : environ 25 vols scénarisés (prière du moment heure par heure, écarts de retard, réserves, temps de calcul de 110 à 400 ms), 12 textes de billets et 4 cas de vérification. Le jeu des 3 226 aéroports a été contrôlé : doublons, fuseaux, codes de PRINCIPAL (KBP absent). Scripts dans OUT/FVOL2 ; les scripts t1 à t8 de l'auditeur précédent (OUT/fvol) ont été relus puis relancés. Non examinés : rien n'a été exécuté côté Kotlin, ni tests unitaires ni émulateur. Le comportement d'Android est déduit d'un code identique ligne pour ligne, sauf le GPS, les notifications et le billet, lus seulement. Pas d'appel réel à OpenSky ni à adsbdb, pas de décodage ZXing sur de vraies cartes d'embarquement, pas de rendu visuel ni de lecteur d'écran. tools/relais_vol/worker.js, tools/aeroports_construction.py et le contenu détaillé de vecteurs_vol.json n'ont pas été lus. Une recherche systématique des chki'a après minuit nautique aux hautes latitudes a été abandonnée : trop longue, et sans cas trouvé sur l'échantillon de l'auditeur précédent.

## Ce qui tient

- Le calcul est pur et vérifiable. Vol.kt ne dépend que de Zmanim.kt et vol.js le reprend ligne pour ligne. Des vecteurs communs (tools/vecteurs_vol, test « les vecteurs du web sont ceux de Vol ») imposent l'accord à 2 s. Avant le décollage, le calcul rend exactement les zmanim de l'aéroport (VolTest « au sol, le calcul rend les zmanim du moteur »).
- Les heures se saisissent à l'heure locale de chaque aéroport, et l'étiquette de la tuile le dit (« Décollage prévu, heure de Lyon »). Les fuseaux IANA viennent de timezone-boundary-builder, contre-vérifiés par GeoNames, avec l'heure d'été contrôlée sur 729 aéroports. instant() traite le trou du passage à l'heure d'été comme LocalDateTime.atZone. Un fuseau inconnu de l'appareil est refusé proprement (FUSEAU_INCONNU).
- La vie privée est protégée par défaut. Le calcul est hors ligne, et les services en ligne sont éteints par défaut, derrière un accord explicite. OpenSky anonyme ne reçoit qu'un carré de 10° : l'indicatif reste sur le téléphone. Le billet passe par le sélecteur de fichiers du système, sans permission caméra ni stockage, et le nom comme le PNR ne sont pas extraits du code BCBP. Le GPS n'est demandé qu'au toucher.
- L'écran est honnête sur une bonne partie des limites. Il affiche l'étiquette « Estimation sur la route prévue » et les réserves haute latitude, à rebours, erreur moteur et ligne de date (méridien de 180°, dates de part et d'autre). La note des rappels dit qu'ils ne suivent pas le retard, et la route adsbdb est annoncée « parfois ancienne ».
- Le réseau est traité avec soin : HTTPS seulement, sans redirection, avec délais. Les erreurs sont des codes traduits (quota 429 distingué, plus de français affiché en anglais ou en hébreu). Sur Android, la lecture des 3 226 aéroports, le calcul, le décodage du billet et le réseau tournent hors du fil principal.

## Constats

### FVOL-01 — Prière du moment en vol : « Cha'harit » l'après-midi et la nuit pour tout départ d'un aéroport au nord d'environ 50,5° en été

**Gravité** : bloquant · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** Quand aucune aube (alot, 16,1°) n'a eu lieu dans la fenêtre de calcul, Vol.horaires ne garde plus le jour en cours. Il prend « le prochain » de chaque zman après maintenant. ZmanimWidget.prochaine reçoit alors la fin de la Téfila du lendemain et répond « Cha'harit » jusqu'à la prochaine aube sur la route : pendant tout l'après-midi, le soir et la nuit, souvent même après l'atterrissage. C'est la carte principale de l'écran, en grand, avec son compte à rebours. Le code ne vise que les routes polaires (« route polaire »), mais il suffit d'un départ de Londres, d'Amsterdam, de Berlin, de Varsovie, de Manchester, de Dublin, de Copenhague, de Moscou ou de Stockholm entre mai et août. Exécuté avec vol.js, dont l'algorithme est le même ligne pour ligne que Vol.kt : Londres → Tel-Aviv, le 20/06/2027, de 16:00 à 23:00. À 17:00, 20:00 et 22:00 (heure de Londres), puis à 00:00, l'écran dit « Cha'harit » jusqu'au 21/06 à 07:19 UTC (10:19 à Tel-Aviv). Londres → Tel-Aviv, le 08/07/2027 à 22:30 : « Cha'harit » à 01:30 en pleine nuit. Londres → New York, le 20/06/2027 à 11:00 : « Cha'harit » de 11:00 à 22:00. Absence de l'aube dans les données de l'application (balayage 2027) : LHR du 4/6 au 8/7, AMS et BER du 29/5 au 15/7, MAN et DUB du 23/5 au 20/7, CPH et DME du 13/5 au 31/7, ARN du 29/4 au 14/8. Ni VolTest ni vol.test.mjs ne couvrent ce cas.

**Preuve.** android/.../Vol.kt:352-358 : « Sans aube passée (route polaire), les prochains de chaque zman » ; « val alot = ev.lastOrNull { it.cle == "alot" && !it.instant.isAfter(maintenant) }?.instant » ; « val apres = alot ?: maintenant ». web/src/js/vol.js:324-325 : « const apres = alot ?? maintenant; ». ZmanimWidget.kt:29 : « val limites = listOf("chaharit" to horaires["szt_gra"], … ». Exécution : OUT/FVOL2/p1.mjs donne « LHR->TLV 2027-06-20T16:00 … dim. 20 22:00 => chaharit lun. 21 08:19 » (heure de Londres) et « LHR->TLV 2027-07-08T22:30 … ven. 9 01:30 => chaharit ven. 9 08:24 ». Balayage : OUT/fvol/t8.mjs (« LHR 51.47 2027-06-04 -> 2027-07-08 »…). Témoin : CDG → TLV le même jour, CDG étant à 49°, donne bien minha puis arvit.

**Correction proposée (revue par le contre-expert).** Dans Vol.horaires et dans horaires() de vol.js, ancrer la journée sur le repère d'aube passé le plus récent parmi alot, misheyakir et netz, et non sur une chaîne de priorité « alot ?: misheyakir ?: netz », qui pourrait reprendre l'alot d'un jour précédent pris à une autre latitude. Prendre ensuite szt_gra, chkia et chatsot_layla après ce repère. Ne garder « les prochains après maintenant » que si la fenêtre n'a aucun de ces trois repères. Ajouter le test : LHR → TLV le 20/06/2027 à 16:00 donne « minha » à 17:00 et « arvit » à 22:00 (heure de Londres), sur Android et sur le web.

**Note du contre-expert.** Vol.kt:355-366 et vol.js:322-328 font la même chose : sans alot passé, ils prennent le prochain szt_gra, qui est celui du lendemain. VolPriere.kt:19 envoie ce résultat à ZmanimWidget.prochaine pour la grande carte. J'ai relancé OUT/FVOL2/p1.mjs : LHR→TLV le 20/06/2027 affiche « chaharit » de 13:00 à 00:00 (heure de Londres), jusqu'au 21/06 à 08:19 ; LHR→TLV le 08/07 l'affiche de 19:30 à 06:30, et LHR→JFK toute la journée, alors que CDG→TLV passe bien de minha à arvit. VolTest (l. 180-202) ne couvre aucune route sans aube, et afficher Cha'harit en pleine nuit, avant l'aube, est une erreur religieuse sérieuse.

### FVOL-02 — Suivi en direct : la construction par défaut interroge OpenSky depuis chaque téléphone, ce que les conditions reçues d'OpenSky excluent

**Gravité** : bloquant · **Contre-expertise** : confirmé · **Plateforme** : play · **Type** : fonction · déjà connu ou choix assumé

**Constat.** Sans -PrelaisVol, l'édition complète, celle du Play Store, appelle OpenSky en anonyme depuis l'appareil. Or le courriel d'OpenSky (ticket 837455), consigné dans ZMANIM.md et tools/relais_vol/README.md, exige que les données passent par le relais, avec le client OAuth2 du compte, « et non par chaque téléphone ». Le relais n'est pas en ligne : sur le site déployé, relais.js vaut « '' ». Rien dans la construction n'empêche de publier cet accès direct. Le cahier Play (§ 3.1) laisse ouverte la question « il autorise l'accès anonyme ? », alors que la réponse est déjà écrite ailleurs. Le README du relais se contredit aussi : il dit le client API « Facultatif », alors que c'est une condition.

**Preuve.** android/app/build.gradle.kts:164-168 : « Sans -PrelaisVol=https://…, OpenSky en accès anonyme et gratuit (SuiviVol) » ; « val relais = (project.findProperty("relaisVol") as String?).orEmpty() ». SuiviVol.kt:185 : « if (relais.startsWith("https://")) Relais(relais) else OpenSkyAnonyme ». tools/relais_vol/README.md : « Accès direct d'Android à OpenSky : à couper dès que le relais est en ligne » et « Mise en ligne de ce relais … possible, pas encore faite ». ZMANIM.md:331-333 : « L'accès direct depuis le téléphone (Android sans relais) ne suit pas la deuxième condition ». myhitbodedut-web/js/relais.js : « export const RELAIS_VOL = ''; ». PUBLICATION_PLAY_STORE.md:133 : « [ ] il autorise l'accès anonyme que fait SuiviVol.kt ».

**Correction proposée.** Dans build.gradle.kts, faire échouer bundleFullRelease et assembleFullRelease si relaisVol est vide. À défaut, quand RELAIS_VOL est vide, retirer le bouton « Position en direct » dans VolActivity (fournisseur nul) au lieu de basculer sur OpenSkyAnonyme. Corriger § 3.1 avec les conditions du ticket 837455 (relais obligatoire, client OAuth2, cache par zone, attribution sur la fiche) et retirer le mot « Facultatif » du README du relais.

**Note du contre-expert.** Toutes les preuves sont là. build.gradle.kts:163-168 retombe sur OpenSky en anonyme si relaisVol est vide, et SuiviVol.kt:185 fait de même ; la construction -Pplay=true ne contrôle pas relaisVol. Le relais déployé est vide (relais.js : RELAIS_VOL = ''). Le README du relais pose comme condition « par ce relais […] et non par chaque téléphone », mais dit « Facultatif » au point 1 de sa mise en ligne (l. 66). § 3.1 garde ouverte la case « il autorise l'accès anonyme ». Le défaut est connu (« à couper dès que le relais est en ligne ») et n'est toujours pas corrigé.

### FVOL-03 — Saisie rapide et billet : le vol se calcule et s'enregistre seul sur une arrivée devinée ou sur la date de l'ancien vol, et le message qui le disait disparaît aussitôt

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** Le bouton s'appelle « Remplir le vol », mais il lance calculer() dès que les quatre champs sont pleins. Il enregistre alors le vol et programme les rappels, actifs par défaut. Le formulaire et la carte de saisie rapide sont aussitôt remplacés par le résumé. « Compris : … » et « Arrivée estimée d'après la distance : corrigez-la avec l'heure du billet » ne sont plus visibles. Le drapeau d'arrivée estimée n'est ni enregistré ni repris dans le résumé : l'estimation, distance à 820 km/h plus 30 min, passe pour l'heure du billet. Si le texte, ou le code-barres d'un billet, donne une date sans heure alors qu'un vol existait déjà, la date lue ne va que dans dateSeule. L'ancien décollage reste, le sélecteur d'heure ne s'ouvre pas, et le calcul part sur l'ancienne date. Exemple : le vol aller du 15/11 à 10:35 est enregistré ; on touche « Modifier », on écrit « Tel Aviv Paris le 20/11 » ou on importe la carte du retour. TLV → CDG est alors calculé et enregistré pour le 15/11 à 10:35, rappels compris.

**Preuve.** VolActivity.kt:399-401 : « val jour = p.date ?: decollage?.toLocalDate() / if (jour != null && p.heureDepart != null) decollage = … / else if (jour != null) dateSeule = jour ». VolActivity.kt:415-417 (arrivée estimée), puis 443 : « depart != null && arrivee != null && decollage != null && atterrissage != null -> calculer() ». VolActivity.kt:171-172 : « formulaireOuvert = garde == null || modifier / if (formulaireOuvert) contenu.addView(carteRapide()) ». Store.kt:528 : rappels « actifs par défaut ». Web, même logique : app.js:3452-3453 (« const jour = p.date ?? v.decollage?.slice(0, 10); if (jour && p.heureDepart) v.decollage = … »), 3468-3474 (estimation), 3482 (« return calculer(); ») et 3797 (le résumé remplace la carte de saisie).

**Correction proposée.** Ne jamais appeler calculer() depuis appliquer() ni remplir() quand une valeur a été estimée ou reprise. Remplir les tuiles et ouvrir celle qui manque. Si le texte donne une date sans heure, vider decollage et atterrissage puis ouvrir le sélecteur d'heure sur cette date. Enregistrer avec le vol un indicateur « arrivée estimée » (Store et store.js) et l'afficher dans la carte résumé : « Arrivée estimée d'après la distance : touchez « Modifier » pour mettre l'heure du billet. »

**Note du contre-expert.** Le chemin se vérifie sur Android. VolActivity.kt:399-401 met la date seule dans dateSeule et garde l'ancien décollage. La ligne 443 lance calculer(), qui enregistre (Store.setVol), remet modifier à false, puis appelle lancer() et VolAlerte.enregistrer. À l'affichage suivant, afficherFormulaire (l. 171-172) remplace la carte rapide et son message par carteResume (l. 186-197), qui n'indique pas que l'arrivée est estimée. Le web fait de même (app.js:3452-3482, puis la ligne 3797 remplace la carte par le résumé), mais il n'a pas de rappels de vol : ce point ne concerne qu'Android.

### FVOL-04 — Lecture des heures d'un billet collé : la durée du vol devient l'heure de départ, « 4h 25m » devient un numéro de vol, « gate » efface l'heure de départ

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** heures() prend dans l'ordre toute forme « 4h25 » ou « 4 h 25 », y compris la durée qu'impriment la plupart des billets électroniques. La première heure trouvée devient le départ, la deuxième l'arrivée. Le motif du numéro de vol accepte « chiffre + lettre » : « 4h 25m » donne le numéro « 4H25M » et la compagnie « 4H ». L'heure est écartée si « gate » ou « porte » figure dans les 24 caractères qui précèdent, ce qui touche aussi l'heure de départ qui suit « gate B12 ». Comme le vol se calcule alors seul (constat précédent), ces erreurs partent directement dans les zmanim et les rappels.

**Preuve.** Exécuté (OUT/FVOL2/p6.mjs, lirePhrase de vol.js) : « Vol AF1620 · Durée 4h25 · Paris-Charles de Gaulle (CDG) 10:35 → Tel Aviv (TLV) 16:00 » donne « heureDepart":"04:25","heureArrivee":"10:35" ». « Flight time 4h 25m. Departs CDG 10:35 arrives TLV 16:00 on 15 Nov » donne « numero":"4H25M","compagnie":"4H",…"heureDepart":"04:25" ». « Boarding 5:20 gate B12 Departure 6:05 BUD TLV 15 Nov » donne « numero":"B12",…"heureDepart":null ». Expressions identiques dans SaisieVol.kt:108 (numéro) et 228-232 (heures, « boarding|embarquement|gate|porte… » sur 24 caractères). SaisieVolTest ne contient aucun cas de durée.

**Correction proposée (revue par le contre-expert).** Dans heures() (SaisieVol.kt) et heuresPhrase() (vol.js) : écarter une heure précédée de près par « durée|duration|flight time|temps de vol|משך|זמן טיסה », ou suivie de « m », « mn » ou « min » ; ne lire « 4h25 » ou « 4 h 25 » comme heure que si le texte ne contient aucune forme « HH:MM » ; ignorer les chiffres qui appartiennent au numéro de vol déjà reconnu (« 6H 123 »). Pour l'embarquement, garder le regard en arrière, mais l'arrêter au mot de départ ou à l'heure qui précède : une heure précédée de « départ|departure|dep|המראה » plus près que « gate » ou « porte » est gardée. Ne pas le réduire au seul mot précédent : « Boarding time 5:20 » et « porte fermée 5h45 » ne seraient plus écartés. Dans le motif du numéro, ne pas refuser tout code « chiffre + h », puisque 6H est Israir. Refuser seulement une correspondance « chiffre + h + deux chiffres » suivie de m/min ou précédée d'un mot de durée, sauf si le code est dans COMPAGNIES. Ajouter aux tests Android et web les trois phrases, « Israir 6H 123 TLV ATH 15/11 10:35 13:00 » et « Porte fermée 5h45, départ 6h05 BUD TLV 15/11 ».

**Note du contre-expert.** J'ai relancé p6.mjs : les trois sorties citées sont exactes. SaisieVol.kt:108 et 228-232 utilisent les mêmes expressions, et SaisieVolTest n'a aucun cas de durée. Mon essai OUT/contre_fvol/c4.mjs trouve en plus « Israir 6H 123 … 10:35 » → heureDepart 06:00, et « Porte fermée 5h45 » → numéro 5H45. En revanche, la recommandation casserait les numéros Israir : le code 6H figure dans l'application (SaisieVol.kt:36). Elle casserait aussi « Boarding time 5:20 » et « porte fermée 5h45 ».

### FVOL-05 — Carte « Prière du moment » : « Min'ha » affiché avant 'hatsot, alors que le rappel du même écran annonce Min'ha à min'ha guedola

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** En vol, la prière du moment vient de ZmanimWidget.prochaine. Celle-ci passe à « Min'ha » dès la fin du temps de la Téfila (Gra), donc avant 'hatsot du jour. Les rappels du même vol font commencer Min'ha à min'ha guedola, comme HorairePriere. Le commentaire de VolRappels affirme que ZmanimWidget.prochaine suit ces mêmes bornes, ce qui est faux. Exécuté sur CDG → TLV, le 15/11/2026 à 10:35 : à 11:00, 11:30 et 12:00 (heure de Paris), la grande carte dit « Min'ha » jusqu'à 15:40. Or 'hatsot tombe à 11:50 et min'ha guedola à 12:05, heure à laquelle la notification dit « Le temps de Min'ha commence sous l'avion ». Le défaut est commun avec la vignette, mais ici il occupe la carte principale de l'écran.

**Preuve.** ZmanimWidget.kt:29 : « val limites = listOf("chaharit" to horaires["szt_gra"], "minha" to horaires["chkia"], … ». VolRappels.kt:12-13 : « Les bornes des prières sont celles de l'application (HorairePriere, ZmanimWidget.prochaine) : Min'ha de min'ha guedola à la chki'a » ; VolRappels.kt:38 : « Triple("minha", "minha_gedola", "chkia") ». HorairePriere.kt:23 : « "minha" -> { val a = h("minha_gedola") … ». OUT/FVOL2/p10.mjs : « szt_gra dim. 15 10:51 », « minha_gedola dim. 15 12:05 », « 11:00 Paris => minha dim. 15 15:40 ».

**Correction proposée.** Passer min'ha guedola à prochaine, dans Vol.horaires comme dans horaires() de vol.js. Entre szt_gra et minha_gedola, n'afficher aucune prière ouverte : « Prochaine prière : Min'ha à 12:05 » (nouvelle chaîne vol_prochaine, %1$s = prière, %2$s = heure). Corriger la règle à la racine, dans ZmanimWidget.prochaine, pour la vignette aussi, et le commentaire de VolRappels.

**Note du contre-expert.** ZmanimWidget.kt:29 passe à Min'ha dès szt_gra. VolRappels.kt:38 (BORNES) et HorairePriere.kt:23 ouvrent Min'ha à minha_gedola, et le commentaire VolRappels.kt:12-13 attribue à tort ces bornes à prochaine. J'ai relancé p10.mjs : CDG→TLV le 15/11/2026, szt_gra à 10:51, minha_gedola à 12:05, et la carte affiche « minha » dès 11:00, 11:30 et 12:00 (heure de Paris), donc avant 'hatsot (11:50).

### FVOL-06 — Rappel « Tefilat haDerekh » : la notification tranche (« le moment de dire »), contrairement à ZMANIM.md, avec un risque de berakha répétée

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : texte

**Constat.** ZMANIM.md écrit que l'application « ne tranche pas » entre les cas. Selon ses propres sources, si l'aéroport est hors de la ville, on dit Tefilat haDerekh en route vers l'aéroport et elle couvre le vol. La notification, elle, affirme à chacun que c'est « le moment de dire » la prière, cinq minutes après le décollage prévu. Elle peut donc tomber au sol en cas de retard, et chez quelqu'un qui l'a déjà dite. La prière se termine par une berakha avec le Nom : la redire sans raison pose la question d'une berakha levatala. Le même sens figure en anglais et en hébreu.

**Preuve.** values/strings.xml:1355 : « Cinq minutes après le décollage prévu : le moment de dire Tefilat haDerekh. » ; values-en : « Five minutes after the scheduled takeoff: time to say Tefilat HaDerech. » ; values-iw : « חמש דקות אחרי ההמראה המתוכננת: הזמן לומר תפילת הדרך. » ZMANIM.md:341-350 : « si l'aéroport est hors de la ville, on la dit en route vers l'aéroport et elle couvre le vol […] L'application ne tranche pas entre ces cas. »

**Correction proposée.** FR : « Décollage prévu il y a cinq minutes. Tefilat haDerekh, si vous ne l’avez pas déjà dite pour ce voyage. » EN : « Scheduled takeoff was five minutes ago. Tefilat HaDerech, if you have not already said it for this journey. » HE : « ההמראה המתוכננת הייתה לפני חמש דקות. תפילת הדרך, אם עדיין לא אמרתם אותה לנסיעה זו. »

**Note du contre-expert.** Les trois chaînes vol_rappel_derekh_texte (FR:1355, EN:1291, HE:1327) disent bien « le moment de dire » sans réserve. ZMANIM.md:341-350 dit pourtant que, si l'aéroport est hors de la ville, la prière dite en route couvre le vol, et que l'application « ne tranche pas ». Seuls le rappel et son délai de cinq minutes sont des choix documentés du propriétaire, pas cette formulation. vol_rappels_note confirme qu'un retard ne décale pas la notification : elle peut tomber au sol. Les réécritures proposées sont correctes dans les trois langues.

### FVOL-09 — Hébreu : le compte à rebours de la carte principale dit « עד » (jusqu'à) au lieu de « encore », et « 1 שעות »

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : texte

**Constat.** Sous le nom de la prière, en 22 sp, vol_dans affiche en hébreu « עד 13 שע׳ ו־19 דק׳ » : « jusqu'à 13 h 19 », un non-sens. La ligne suivante répète « עד » avec l'heure (vol_jusqua). Pour une heure pile, vol_duree_heures donne « 1 שעות » (et « 2 שעות » au lieu de « שעתיים »). Les mêmes chaînes servent au web (tools/chaines.mjs).

**Preuve.** values-iw/strings.xml:1266 : « &lt;string name="vol_dans">עד %1$s&lt;/string> » (FR : « encore %1$s », EN : « %1$s left ») ; values-iw:1223 : « &lt;string name="vol_duree_heures">%1$s שעות&lt;/string> ». Utilisées par VolActivity.kt:878 et 891-896 et par app.js:3412-3415 et 3632.

**Correction proposée (revue par le contre-expert).** vol_dans (HE) : « עוד %1$s », correct au singulier comme au pluriel (« עוד דקה אחת », « עוד שעתיים », « עוד 13 שע׳ ו־19 דק׳ »). Faire de vol_duree_heures une ressource plurals : one « שעה אחת », two « שעתיים », many et other « %1$s שעות » (garder many pour les appareils dont les règles CLDR l'utilisent encore). Côté web, utiliser la même forme plurielle.

**Note du contre-expert.** La preuve est exacte : values-iw:1266 contient vol_dans « עד %1$s », alors que le français dit « encore » et l'anglais « left » ; values-iw:1223 contient vol_duree_heures « %1$s שעות ». Ces chaînes servent à VolActivity.kt:83, 878 et 894 et à app.js:3412-3415 et 3632 ; le web gère les pluriels (Intl.PluralRules, i18n.js:43). « עד » est sans doute une coquille pour « עוד ». La réécriture « נותרו %1$s » introduit cependant une faute d'accord avec « דקה אחת » (vol_duree_une_minute) et avec « שעה אחת ».

### FVOL-07 — L'écran ne dit pas que les choix halakhiques du calcul ne sont pas tranchés (horizon vu de l'avion, journée de référence)

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** ZMANIM.md recense quatre choix de calcul qu'il dit non tranchés. Il chiffre aussi l'écart dû à l'altitude : à 11 000 m, le soleil se lève plus tôt et se couche plus tard, « de l'ordre d'un quart d'heure ou plus ». À l'écran, tout cela se réduit à « Zmanim du point sous l'avion, au niveau de la mer », derrière le pli « Comment c'est calculé ? ». L'écran ne mentionne pas l'écart de l'horizon vu de la cabine : le passager voit encore le soleil après la « chki'a » affichée. Il ne dit pas non plus que les heures saisonnières sont celles de la journée du point sous l'avion et non de la journée vécue à bord, ni que la question est à poser à un rav. La carte principale, la frise et les notifications présentent des horaires sans réserve.

**Preuve.** values/strings.xml:1305 vol_fiabilite : « Estimation sur la route prévue (grand cercle, vitesse constante entre les heures saisies), pas la position réelle de l’avion. Zmanim du point sous l’avion, au niveau de la mer, calculés sur l’appareil, sans réseau. » (repliée, VolActivity.kt:1122-1124 ; web app.js:3644). ZMANIM.md:282-293 : « Choix de calcul (aucune règle n'est tranchée ici) : 1. le zman du sol sous l'avion […] À 11 000 m, l'horizon s'abaisse d'environ 3,4° […] 2. les heures saisonnières […] Laquelle compte n'est pas tranché ».

**Correction proposée (revue par le contre-expert).** Compléter vol_fiabilite, qui reste dans le pli « Comment c'est calculé ? », sans renvoi à un rav. FR : « … Zmanim du point sous l’avion, au niveau de la mer : vu de l’avion, vers 11 000 m, le soleil se lève plus tôt et se couche plus tard, d’un quart d’heure ou plus aux latitudes moyennes. Les heures saisonnières sont celles de la journée de ce point, pas de la journée vécue à bord. » EN : « … Zmanim of the point below the aircraft, at sea level: seen from the aircraft, around 11,000 m, the sun rises earlier and sets later, by a quarter of an hour or more at mid-latitudes. Seasonal hours follow the day at that point, not the day as lived on board. » HE : « … זמני הנקודה שמתחת למטוס, בגובה פני הים: מהמטוס, בגובה כ־11,000 מ׳, השמש זורחת מוקדם יותר ושוקעת מאוחר יותר, ברבע שעה או יותר בקווי רוחב בינוניים. השעות הזמניות הן לפי היום בנקודה זו, ולא לפי היום שעובר על הנוסעים במטוס. »

**Note du contre-expert.** Il est exact que l'écran ne mentionne ni l'horizon vu de la cabine ni la journée de référence (vol_fiabilite, l. 1305, dans le pli). Mais deux choix documentés pèsent contre le reste du constat. FEUILLE_DE_ROUTE.md:763-764 : le 29/10, toutes les mentions « à valider / demander à un Rav » ont été retirées. ZMANIM.md:418-426 : l'écran, validé par l'utilisateur, déplie le détail du calcul. La réécriture, qui ajoute « demandez à votre rav » et sort le texte du pli, va donc contre ces décisions. Reste une lacune d'information défendable mais mineure, puisque « au niveau de la mer » est déjà écrit.

### FVOL-08 — Effet d'un retard : l'écart médian n'est jamais affiché, seule la ligne qui s'en écarte l'est, et la phrase d'en-tête promet une mise à jour qui n'existe pas

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** ZMANIM.md promet que l'écran dit « de combien chaque horaire bouge si le départ a 30 minutes de retard ». En fait, la frise calcule l'écart médian sans jamais l'afficher. Elle ne chiffre que les lignes qui s'en éloignent de 5 min ou plus. Sur JFK → TLV du 10/11/2026 à 23:00, onze horaires bougent de 9 à 14 min sans aucun chiffre. Seule Plag hamin'ha porte « +8 min si le départ a 30 min de retard » : c'est l'horaire qui bouge le moins, et il paraît être le seul à bouger. Sur CDG → TLV, seule la fin du Chema (Maguen Avraham) porte « +1 min », alors que les autres bougent de 7 à 11 min. L'en-tête dit « les horaires changeront en conséquence », ce qui laisse croire que l'écran se recale seul. Or rien ne suit le retard réel, et les rappels ne bougent pas (vol_rappels_note).

**Preuve.** values/strings.xml:1259 : « Si le vol est retardé, les horaires changeront en conséquence. » (HE, ligne 1231, sans point final). VolActivity.kt:1165-1167 (médiane calculée, seule la phrase s'affiche) ; VolActivity.kt:1179 : « e.ecartSiRetard?.takeIf { median != null && it.minus(median).abs() >= Duration.ofMinutes(5) } ». app.js:3677-3698, même règle. Exécution OUT/fvol/t3.mjs : « JFK->TLV … median=13 min », toutes les lignes « cache » sauf « plag … ecart 8 AFFICHE ».

**Correction proposée (revue par le contre-expert).** Mettre la médiane, avec son signe (comme ecart() : +13, −38), dans la phrase partagée, sans parler des rappels : vol_rappels_note le dit déjà sur Android, et le web n'en a pas. FR : « Calculé pour les heures saisies. Avec 30 min de retard au départ, la plupart de ces horaires bougent d’environ %1$s min ; l’écran ne se recale pas seul : modifiez l’heure de décollage. » EN : « Calculated for the times entered. With a 30-min late departure, most of these times move by about %1$s min; the screen does not adjust by itself: edit the takeoff time. » HE : « מחושב לפי השעות שהוזנו. אם ההמראה מתעכבת ב־30 דק׳, רוב הזמנים האלה זזים בכ־⁦%1$s⁩ דק׳; המסך אינו מתעדכן מעצמו: ערכו את שעת ההמראה. » Prévoir une variante pour un relevé GPS ou en direct (« Avec 30 min de retard à l’arrivée… »). Garder le chiffre des lignes qui s'écartent, en l'écrivant par rapport à la médiane.

**Note du contre-expert.** Les faits se vérifient. La médiane est calculée sans être affichée (VolActivity.kt:1165-1167, app.js:3677-3698) ; t3.mjs relancé donne, pour JFK→TLV, une médiane de 13 min, et seule la ligne plag porte un chiffre (+8). Mais ZMANIM.md:422-426 consigne un écran « validé écran par écran par l'utilisateur » le 29/10, où la phrase du retard est dite une fois et où une ligne ne porte un chiffre que si elle s'écarte de 5 min de la médiane : le constat ne le dit pas. Ce qui reste défendable, c'est le flou de « changeront en conséquence » et le chiffre absolu d'une ligne isolée, qui induit en erreur ; la recommandation est en outre fausse en mode GPS (l'écart est alors celui de l'arrivée) et sur le web (pas de rappels), et ne gère pas une médiane négative.

### FVOL-10 — Place de la fonction : la partie en ligne (OpenSky, adsbdb) coûte un blocage de publication, la permission INTERNET et des déclarations Play, pour un gain faible

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : fonction · déjà connu ou choix assumé

**Constat.** Le mode « En vol » pèse environ 10 % de l'application : 2 724 lignes Kotlin sur 25 857 (douze fichiers), 684 lignes de vol.js et environ 460 de app.js, 137 chaînes sur 1 184 en français (fois trois langues), 552 Ko de données et un relais Cloudflare à tenir. Le calcul hors ligne, sur la route prévue et recalé par le GPS, a une vraie valeur pour le voyageur. La partie en ligne, elle, est seule responsable : 1) de la permission INTERNET de l'édition complète (seuls SuiviVol et RouteVol ouvrent une connexion) ; 2) du point bloquant § 3.1 (OpenSky) ; 3) des déclarations « position » et « identifiants » de la fiche Sécurité des données ; 4) d'un relais à mettre en ligne. Son gain est faible : OpenSky ne voit « souvent rien » au-dessus des océans, le suivi exige le Wi-Fi de bord, et le bouton GPS recale la même route sans réseau. adsbdb ne fait que remplir l'aéroport d'arrivée.

**Preuve.** android/app/src/full/AndroidManifest.xml:2-6 : « l'accès Internet du suivi de vol en direct (28/10) […] et de la route d'un numéro de vol » ; grep « openConnection » : seuls SuiviVol.kt et RouteVol.kt. ZMANIM.md:320-322 : « OpenSky ne voit les avions que près de ses antennes au sol : au-dessus des océans, souvent rien ». PUBLICATION_PLAY_STORE.md:127 : « Décision du 29/10 : fonction conservée » ; ligne 375 : « Déclarer Position approximative […] et Autres identifiants ». tools/relais_vol/README.md : « Mise en ligne de ce relais […] pas encore faite ».

**Correction proposée (revue par le contre-expert).** Respecter les décisions du 29/10 et du 04/11. Si le relais n'est pas en ligne à la première publication, appliquer l'option A déjà décrite aux § 3.1 et § 6.2 au seul suivi en direct : pas de fournisseur quand RELAIS_VOL est vide (FVOL-02). Garder RouteVol (adsbdb), que le propriétaire a conservé. Réintroduire le suivi quand le relais sera en ligne avec le client OAuth2.

**Note du contre-expert.** Les chiffres se vérifient : 2 724 lignes sur 25 857, 684 lignes de vol.js, 137 chaînes vol_ sur 1 184, 552 Ko d'aéroports. Seuls SuiviVol.kt et RouteVol.kt ouvrent une connexion, et full/AndroidManifest.xml n'utilise INTERNET que pour eux. Mais le constat demande de retirer deux fonctions que le propriétaire a explicitement gardées le 29/10 (PUBLICATION_PLAY_STORE.md:127 et 145, « conservée ») ; l'option « vol en direct retiré » est déjà écrite au § 6.2, et le README du relais (04/11) prévoit sa mise en ligne. C'est une critique de produit défendable, que le constat reconnaît (déjà connu), et non un défaut ; son seul point bloquant fait double emploi avec FVOL-02.

### FVOL-11 — Réserve « absent » : sur Londres–Tel-Aviv en juin, l'écran parle de « soleil de minuit ou nuit polaire » sans dire quel zman manque

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** La réserve s'affiche dès qu'un zman manque en un point du vol. Sous 66° de latitude, la cause n'est ni le soleil de minuit ni la nuit polaire. L'aube à 16,1° disparaît au-delà d'environ 50,5° autour du solstice, la sortie des étoiles à 8,5° au-delà d'environ 58°. Sur un Londres → Tel-Aviv de juin, l'écran affiche donc une explication fausse, sans nommer le zman en cause, alors que c'est justement celui qui fausse la prière du moment (premier constat).

**Preuve.** values/strings.xml:1307 : « Certains zmanim n’ont pas lieu sur une partie de la route (soleil de minuit ou nuit polaire). » OUT/fvol/t1.mjs, LHR → TLV le 20/06/2027 : « reserves [ 'absent' ] ». VolActivity.kt:1138-1146 et app.js:3649 l'affichent hors de tout pli.

**Correction proposée.** FR : « Certains zmanim n’ont pas lieu sur une partie de la route : au-delà d’environ 50° de latitude en été, le soleil ne descend pas assez pour l’aube (16,1°) ou la sortie des étoiles (8,5°) ; plus près des pôles, soleil de minuit ou nuit polaire. » Faire suivre la liste des zmanim manquants, à partir des clés que signale occurrences().

### FVOL-12 — Aucune vérification de vraisemblance : 3 284 km en 25 min ou en 16 h 25 sont acceptés

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** verifier() n'écarte que trois cas : même aéroport, arrivée avant départ, plus de 22 h. Le commentaire dit vouloir attraper les erreurs de date et d'AM/PM, mais une inversion AM/PM sur un vol de 4 h donne 16 h, ce qui passe. Une heure d'arrivée saisie dans le mauvais fuseau donne 25 min, ce qui passe aussi. Tout le calcul, les rappels et les jalons de Chabbat portent alors sur une route impossible.

**Preuve.** Vol.kt:74-83 : « /** Plus long qu'aucun vol régulier : une erreur de saisie (date d'arrivée, AM/PM). */ val DUREE_MAX = Duration.ofHours(22) ». OUT/FVOL2/p8.mjs : « CDG TLV 2026-11-15T22:35 2026-11-16T16:00 -> null h 16.42 km 3284 km/h 200 » ; « CDG TLV 2026-11-15T10:35 2026-11-15T12:00 -> null h 0.42 km 3284 km/h 7881 ».

**Correction proposée.** Ajouter Invalide.INVRAISEMBLABLE dans Vol.kt et dans vol.js : vitesse moyenne au-delà de 1 100 km/h, ou durée supérieure à 2 × dureeEstimee + 2 h. Message FR : « La durée ne correspond pas à la distance (%1$s km en %2$s) : vérifiez les dates et l’AM/PM, à l’heure de chaque aéroport. » En faire un avertissement que l'on peut passer outre, pour les escales techniques.

### FVOL-13 — Envois à adsbdb sans toucher la loupe, règles de confidentialité périmées, et explications OpenSky laissées en chaînes mortes

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Une fois l'accord donné, le numéro part chez adsbdb tout seul après « Remplir le vol » ou l'import d'un billet dont les aéroports manquent. Les règles écrivent pourtant « quand vous touchez la loupe […] (elle n’apparaît que services en ligne activés) », alors que la loupe est toujours visible depuis le 04/11. Deux commentaires de code sont faux. RouteVol.kt dit que la loupe « n'apparaît qu'une fois les services en ligne activés ». VolActivity.kt dit que l'interrupteur « figure dans le formulaire » : il n'existe que sous « Préciser la position », donc seulement après un calcul. Allumé, l'écran ne dit plus ce qui part vers OpenSky : vol_direct_explication_opensky et vol_direct_explication existent mais ne sont jamais affichées, comme vol_route_aide, vol_route_explication, vol_fiabilite_titre et vol_direct_titre (six chaînes mortes, dans les trois langues).

**Preuve.** VolActivity.kt:439 : « BuildConfig.SUIVI_VOL && numero.isNotEmpty() && (depart == null || arrivee == null) -> loupe() » ; app.js:3481 : « if (v.numero && (!v.depart || !v.arrivee)) { rendre(); return loupeVol(v); } ». myhitbodedut-web/confidentialite.html:92 : « quand vous touchez la loupe à côté du numéro de vol (elle n’apparaît que services en ligne activés) ». RouteVol.kt:10-11 ; VolActivity.kt:988-991 « Il figure dans le formulaire et sous les résultats », alors que ajouterInterrupteurEnLigne n'est appelée qu'en 966. Recherche d'usage : vol_route_aide, vol_route_explication, vol_fiabilite_titre, vol_direct_titre, vol_direct_explication, vol_direct_explication_opensky sont « android=0 web=0 ».

**Correction proposée.** Règles, FR : « Route d’un numéro de vol, via adsbdb (api.adsbdb.com) : quand vous touchez la loupe, ou, services en ligne activés, quand « Remplir le vol » ou l’import d’un billet trouve un numéro sans ses aéroports. Le téléphone envoie le numéro de vol (et, s’il le faut, le code de la compagnie), rien d’autre. » Afficher vol_direct_explication_opensky sous l'interrupteur allumé, mettre l'interrupteur aussi dans le formulaire, supprimer les quatre autres chaînes mortes et corriger les deux commentaires.

### FVOL-14 — Pied « Méthode et sources » : « La méthode est écrite sous chaque horaire » est faux dans la frise du vol

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** L'écran du vol reprend le pied de l'onglet Zmanim. Mais la frise n'écrit sous chaque horaire que la position et parfois l'écart. Aucune méthode n'y figure : « Alot hacha’har » sans 16,1°, « Tsét hakokhavim » sans 8,5°, Fin du Chema sans la base des heures. Seuls les jalons de Chabbat précisent « tsét (8,5°) ».

**Preuve.** values/strings.xml:690 : « La méthode est écrite sous chaque horaire. Calcul au niveau de la mer, sur l’appareil, sans réseau. » ; affichée par VolActivity.kt:495 et app.js:3802 (« ...piedZmanim().slice(0, 1) »). VolActivity.kt:1180-1181 : détail de ligne « listOfNotNull(position(e), ecartLigne) » ; app.js:3693-3694, même chose.

**Correction proposée.** Ajouter la méthode au détail de chaque ligne de la frise (zman_methode_*, comme sur l'onglet Zmanim). À défaut, remplacer le pied par une chaîne propre au vol : « Méthodes : aube 16,1°, Michéyakir 11,5°, tsét 8,5° sous l’horizon ; Rabbénou Tam 72 min ; heures saisonnières du lever au coucher (Gra) ou de 72 min avant à 72 min après (Maguen Avraham) ; au niveau de la mer, sur l’appareil, sans réseau. »

### FVOL-15 — GPS en vol : les « 90 s au plus » sont coupés par Android, qui limite getCurrentLocation à moins d'une minute

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** À partir d'Android 11, releverGps passe par getCurrentLocation. La documentation d'Android précise que le système plafonne cette requête à « une valeur raisonnable (moins d'une minute par exemple) » avant de rendre null. Le délai de 90 s de l'application n'est donc jamais atteint. En mode avion, sans assistance réseau et derrière un hublot, une première position GPS demande souvent plus longtemps : l'écran conclut « Pas de position GPS » trop tôt.

**Preuve.** VolActivity.kt:907-909 : « Un relevé du GPS seul […], 90 s au plus » ; 934 : « delai.postDelayed({ conclure(null) }, GPS_MS) » ; 937 : « lm.getCurrentLocation(LocationManager.GPS_PROVIDER, annulation, mainExecutor) { conclure(it) } ». developer.android.com, LocationManager.getCurrentLocation : « The system will always cap the maximum amount of time a request for current location may run to some reasonable value (less than a minute for example) before the request is failed. »

**Correction proposée.** Utiliser requestLocationUpdates(GPS_PROVIDER, 1000, 0f, écouteur, Looper.getMainLooper()) sur toutes les versions, avec le délai propre de l'application (90 à 180 s), removeUpdates dans conclure(), et garder getCurrentLocation pour les seules versions où l'écouteur n'est pas disponible.

### FVOL-16 — Rappels en vol : Tefilat haDerekh et les rappels de prière partagent un seul identifiant de notification, l'un efface l'autre

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Le récepteur affiche d'un coup tous les rappels dus, ceux qui tombent dans la minute ou ont jusqu'à 20 min de retard. Les alarmes inexactes sont regroupées, surtout en Doze, téléphone en veille dans l'avion. Tous les types sauf le Omer utilisent ID_VOL : si Tefilat haDerekh et « Min'ha dans l'avion » arrivent dans le même lot, seule la dernière notification reste, et la première est perdue sans avoir été vue.

**Preuve.** VolAlerte.kt:117-133 : « dus.forEach { r -> … manager.notify(if (r.type == VolRappels.Type.OMER) Notifications.ID_VOL_OMER else Notifications.ID_VOL, n) } » ; VolAlerte.kt:53 : « t <= maintenant + 60_000L && t > maintenant - TOLERANCE_MS » ; Notifications.kt:22 : « const val ID_VOL = 8 ».

**Correction proposée.** Donner à chaque type son identifiant (par exemple ID_VOL + r.type.ordinal, avec une plage réservée). Ou bien réunir les rappels d'un même lot en une seule notification InboxStyle.

### FVOL-17 — Import du billet : jusqu'à quatre pages rendues ensemble en 2 400 px ARGB, mémoire épuisée confondue avec « aucun code-barres »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** pages() rend en mémoire, en ARGB_8888, toutes les pages du PDF, jusqu'à quatre, avant d'en décoder une seule. Une page A4 à 2 400 px fait environ 16 Mo. S'y ajoutent la copie tournée de 90° (jamais recyclée) et les tableaux de pixels : une centaine de Mo au pire. Un OutOfMemoryError est avalé par runCatching, et l'utilisateur lit « Aucun code-barres de carte d’embarquement trouvé », alors que le billet en a un.

**Preuve.** LecteurBillet.kt:25 : « PAGES_MAX = 4 » ; 40-54 : « (0 until minOf(pdf.pageCount, PAGES_MAX)).map { i -> … Bitmap.createBitmap(…, Bitmap.Config.ARGB_8888) … } » ; 33-34 : « val r = decoder(b) ?: decoder(tourner(b)) / b.recycle() » (le résultat de tourner(b) n'est pas recyclé). VolActivity.kt:455 : « runCatching { LecteurBillet.code(this, uri) }.getOrNull() », puis 460 : vol_rapide_billet_sans_code.

**Correction proposée.** Rendre et décoder page par page, et s'arrêter au premier code trouvé. Rendre en niveaux de gris, ou en RGB_565 via une copie. Recycler l'image tournée. Distinguer l'échec de lecture du fichier (« Le billet n’a pas pu être ouvert. ») de l'absence de code.

### FVOL-18 — Un seul tronçon à la fois : une correspondance n'est ni gérée ni signalée

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** L'application ne garde qu'un vol. Le code-barres n'est lu que pour son premier tronçon, la route adsbdb ne retient que le tronçon qui part de l'aéroport choisi, et la saisie rapide garde les deux premiers aéroports. Pour TLV → HKG → SYD, seul TLV → HKG est calculé, et les rappels du second vol n'existent que si l'on ressaisit tout à l'escale. Rien ne le dit à l'utilisateur.

**Preuve.** Store.kt:507-525 (une seule série de clés KEY_VOL_*). CarteEmbarquement.kt:8 : « On n'en lit que le premier tronçon ». RouteVol.kt:44 : « le tronçon qui part de `depart` (IATA) s'il est donné, sinon le premier ». OUT/FVOL2/p6.mjs : « TLV-HKG-SYD 15/11 21:00 » donne « depart":"TLV","arrivee":"HKG" ».

**Correction proposée.** Le dire sous le formulaire. FR : « Un tronçon à la fois : pour une correspondance, saisissez le vol suivant à l’escale ; le calcul marche sans réseau. » Si plusieurs tronçons sont reconnus (« TLV-HKG-SYD », code-barres M2), le signaler dans « Compris : … ».

### FVOL-19 — Saisie rapide et import du billet (04/11) absents de toute la documentation ; ZXing (Apache-2.0) embarqué sans sa licence

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** Ni ZMANIM.md (§ « En vol »), ni README, ni PUBLICATION_PLAY_STORE.md, ni les règles de confidentialité ne mentionnent la saisie rapide, la lecture d'un billet PDF ou d'une photo, ce qu'on en garde ou la bibliothèque ZXing. ZXing est ajouté aux dépendances, mais le dossier des licences embarquées ne contient que les six licences OFL des polices. La licence Apache 2.0 demande d'en remettre une copie avec l'œuvre redistribuée.

**Preuve.** android/app/build.gradle.kts:225 : « implementation("com.google.zxing:core:3.5.3") ». ls android/app/src/main/assets/licences : six fichiers « OFL-*.txt » seulement. grep « rapide|billet|code-barres|zxing » sur README.md, ZMANIM.md, PUBLICATION_PLAY_STORE.md et FEUILLE_DE_ROUTE.md : aucune mention de cette fonction. grep « billet » sur confidentialite.html : rien.

**Correction proposée.** Ajouter assets/licences/Apache-2.0-ZXing.txt et la citer avec les crédits. Ajouter à ZMANIM.md un paragraphe « Saisie rapide et billet » (format BCBP, premier tronçon, estimation de l'arrivée). Ajouter aux règles : « Un billet que vous importez est lu sur le téléphone ; seuls les aéroports, la compagnie, le numéro et le jour du vol sont retenus ; le nom et le numéro de réservation ne sont pas lus. »
