# FCALENDRIER — Android et web — calendrier, zmanim, lune, boussole

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

21 constats — confirmés : 4 · confirmés en partie : 2 · non contre-expertisés (mineurs et cosmétiques) : 15.

## Ce qui a été examiné

Abréviations : R = la racine du dépôt ; K = R/android/app/src/main/java/com/myhitbodedut ; chaînes = R/android/app/src/main/res/values{,-en,-iw}/strings.xml.

Lu en entier : CalendrierJuif.kt, CalendrierActivity.kt, VueJour.kt, JourAffiche.kt, Holidays.kt, Zmanim.kt, ZmanimActivity.kt, ZmanimVignette.kt, ZmanimWidget.kt, HorairePriere.kt, RappelsTefila.kt, Levana.kt, LevanaAlerte.kt, ChabbatAlerte.kt, Villes.kt, ChoixLieu.kt, TerritoireIsrael.kt, BoussoleActivity.kt, BoussoleView.kt, BoussoleWidget.kt, DirectionJerusalem.kt, BootReceiver.kt, AccueilMoment.kt (Adresse.kt lu : il traite du tutoiement tsadik / tsadeket, hors sujet) ; web : calendrier-juif.js, calendrier.js, zmanim.js, jour-affiche.js, boussole.js, magnetisme.js, direction.js ; ZMANIM.md entier ; FEUILLE_DE_ROUTE.md lignes 740 à 1163 ; villes.json (51 villes) ; tests RappelsTefilaTest, ChabbatAlerteTest, LevanaTest en entier.

Échantillonné : app.js (5 524 lignes) — environ 1 100 lignes lues (accueil, siddour, lieu, carte du jour, Levana, zmanim, boussole, calendrier) ; Store.kt (lieu, Israël, Levana, allumage) ; SiddurLectureActivity.kt, MainActivity.kt, SettingsActivity.kt par extraits ; BoussoleDessin.kt survolé ; JourAfficheTest (45 premières lignes), autres tests par recherche ; README.md et PUBLICATION_PLAY_STORE.md par recherche de mots-clés ; chaînes : environ 230 clés de la dimension relues dans les trois langues (français et anglais attentivement, hébreu plus vite), complétude vérifiée par script sur les 1 222 clés.

Exécuté (tout sous OUT/fcalendrier) : 15 scripts node sur une copie du web (web/t1.mjs à t15.mjs) avec @hebcal/core 6.14.1 installé dans la copie ; 2 programmes Java (java/V.java, java/W.java) sur le jar public zmanim-2.5.0.jar ; la correction proposée pour Sydney essayée dans web-corrige/ ; tests web du calendrier relancés dans la copie (34 réussis). Deux recherches web pour des faits extérieurs (article cité par la boussole, résolution de l'ONU, référence du Maguen Avraham), sans rien du projet.

Non examiné : le code Kotlin n'a pas été compilé ni lancé (la logique Android est lue, et recalculée par le moteur web ou par KosherJava) ; aucun essai sur téléphone — capteur de la boussole, alarmes en veille profonde, rendu des vignettes, demande d'autorisation ; mises en page XML ; Vol.kt, VolCalendrier.kt et vol.js (hors dimension, cités seulement parce qu'ils reprennent la règle d'allumage) ; l'application Nokia (sans zmanim).

## Ce qui tient

- Les deux moteurs disent la même chose presque partout : contre-calcul indépendant du moteur web contre KosherJava 2.5.0 sur les 51 villes × 43 dates × 16 valeurs (35 088 horaires), écart maximal 0,010 s hors Sydney ; fêtes, jeûnes repoussés, Yom haAtsmaout déplacé, Pourim des deux Adar, 'Hanouka en Tévet comparés à Hebcal jour par jour de 2025 à 2060, Israël et diaspora (25 812 jours) : seul écart, la convention de Hebcal qui place « 1re bougie » le 24 Kislev.
- Chaque horaire nomme sa méthode à l'écran (degrés, minutes, Gra ou Maguen Avraham, niveau de la mer), aucun « profil de communauté » caché sur l'écran Zmanim ; un événement qui n'a pas lieu (« absent ») est distingué d'une erreur de calcul ; l'algorithme NOAA est imposé et testé contre deux références indépendantes.
- Fuseaux et changements d'heure solides côté calcul : demi-heures et quarts d'heure (Adélaïde, Calcutta, Katmandou, Terre-Neuve), jours de bascule à Paris, New York, Jérusalem, Melbourne — accord avec Hebcal à moins de 30 s sur lever, coucher, tsét, aube, fins du Chema et de la Téfila.
- Le lieu n'est jamais deviné : sans lieu, une carte « Choisir le lieu » et aucune alerte programmée ; « Ma position » ne demande que la localisation approximative, au toucher, avec un repli dit clairement (« Position indisponible : choisissez une ville », « Pas de position fraîche ») ; une position périmée par un changement de fuseau neutralise les alertes plutôt que de sonner à l'heure de l'endroit quitté.
- Boussole sérieuse : nord vrai sur les deux plateformes (GeomagneticField sur Android, modèle WMM2025 recopié et testé contre les valeurs officielles sur le web), capteur absent géré par une rose fixe et un message, les deux méthodes (grand cercle et loxodromie) affichées avec leurs sources ; les références citées (article Chabad.org : 54°, Mor ouKetsia 150, Levouch 94 ; résolution de l'ONU du 4 septembre 2026 sur Equal Earth) ont été retrouvées.
- Traductions complètes dans la dimension : les 1 177 clés traduisibles existent en français, en anglais et en hébreu (0 manquante, 0 en trop), paramètres %1$s / %d concordants, pluriels hébreux avec la forme duelle ; aucun texte français codé en dur dans les écrans web Zmanim, boussole et calendrier.

## Constats

### FCALENDRIER-01 — Fête un vendredi suivie de Chabbat : l'allumage est annoncé après la sortie des étoiles

**Gravité** : bloquant · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** JourAffiche.horaires traite tout « jour chômé suivi d'un autre » comme le cas Chabbat puis fête : il supprime l'allumage d'avant la chki'a et affiche « Allumage des bougies » à tsét 8,5°, avec la mention « pas avant la sortie de la veille ». Quand la fête (ou son deuxième jour) tombe un vendredi, les bougies de Chabbat s'allument AVANT le coucher, d'une flamme existante ; les allumer à l'heure affichée, c'est allumer pendant Chabbat. Android et web ont la même règle (VolCalendrier la reprend). 11 vendredis en diaspora et 5 en Israël d'ici 2031 ; les premiers : 23/04/2027 (2e jour de Pessa'h, diaspora) et 11/06/2027 (Chavouot, partout). Aucun test ne couvre ce cas, et ZMANIM.md ne décrit que « deuxième jour de fête, Chabbat puis fête ».

**Preuve.** K/JourAffiche.kt:90-94 : « if (z.cle == "chkia" && demain && !aujourdhui) sortie += Zmanim.allumage(...) » puis « if (aujourdhui && demain) sortie += tset.copy(cle = "allumage", methode = Zmanim.Methode("apres_tset", "")) » ; R/web/src/js/jour-affiche.js:56-60 identique. Exécution du moteur web (copie) : Paris, vendredi 2027-06-11 (Chavouot) → « chkia 21:53 | tset 22:58 | allumage/apres_tset 22:58 », aucune ligne avant la chki'a ; Jérusalem (Israël) même jour → allumage 20:26 ; vendredi 2028-09-22 (2e jour de Roch Hachana) → 20:34. Liste complète jusqu'en 2031 (script t13.mjs) : 2027-04-23, 2027-06-11, 2028-09-22, 2028-10-06, 2028-10-13, 2029-04-06, 2030-04-19, 2030-06-07, 2031-09-19, 2031-10-03, 2031-10-10. JourAfficheTest.kt:33-41 ne teste que samedi 12 → dimanche 13/09/2026. ZMANIM.md:53-54.

**Correction proposée.** Dans JourAffiche.horaires (Kotlin et JS) : si aujourd'hui et demain sont chômés ET que la date est un vendredi, insérer avant la chki'a Zmanim.allumage(lieu, date, minutes) (méthode avant_chkia) et ne pas ajouter la ligne apres_tset ; garder apres_tset pour Chabbat → fête et pour 1er → 2e jour hors vendredi. Ajouter aux deux suites de tests les vendredis 2027-04-23 (diaspora), 2027-06-11 et 2028-09-22 ; corriger de même VolCalendrier / jalons de vol.js ; compléter ZMANIM.md (« fête un vendredi : allumage de Chabbat avant la chki'a, d'une flamme existante »).

**Note du contre-expert.** Code relu (K/JourAffiche.kt:90-94, web/src/js/jour-affiche.js:56-60) et moteur web relancé sur une copie neuve : Paris vendredi 2027-06-11 (Chavouot) ne donne aucune ligne avant la chki'a (21:53) et « allumage/apres_tset 22:58 », Jérusalem 20:26, vendredi 2028-09-22 20:34 ; la liste des 11 vendredis en diaspora et 5 en Israël jusqu'en 2031 est reproduite à l'identique. L'affichage (VueJour.kt:286, app.js:3055) reprend la ligne telle quelle sous « Allumage des bougies », les tests (JourAfficheTest.kt:33-41, calendrier.test.mjs:217-219) ne couvrent que samedi 12 → dimanche 13/09/2026, et ni ZMANIM.md (l. 49-58, « Limites déclarées ») ni la feuille de route n'en font un choix délibéré ; VolCalendrier.kt:56 et vol.js:355 portent la même règle (« … commence à tsét »). Annoncer l'allumage de Chabbat après la sortie des étoiles est une erreur religieuse sérieuse : la gravité tient.

### FCALENDRIER-02 — Web : à Sydney (et en Nouvelle-Zélande avec « Ma position »), tous les zmanim sont ceux du lendemain

**Gravité** : bloquant · **Contre-expertise** : confirmé · **Plateforme** : web · **Type** : fonction

**Constat.** kosher-zmanim 0.9.0 (bibliothèque embarquée) inverse le signe du décalage standard des fuseaux à heure d'été ; pour Sydney (151,2° E) le « décalage au temps moyen local » vaut 20,08 h au lieu de 0,08 h et la bibliothèque avance la date d'un jour. Le site rend donc, pour Sydney — une des 51 villes proposées — les horaires du lendemain. Conséquences mesurées : (1) tout ce qui compare des instants est faux tous les jours : la « prière du moment » propose le Chema du coucher à 10 h, 15 h et 20 h 30 ; le passage au jour hébreu à tsét ne se fait jamais ; (2) la veille d'un changement d'heure, tout est décalé d'une heure : samedi 03/04/2027, « Sortie de Chabbat » affichée 18:24 au lieu de 19:25 ; samedi 03/10/2026, tout était affiché une heure trop tard (fin du Chema comprise). Même défaut pour « Ma position » en Nouvelle-Zélande et à l'est de 150° E en Nouvelle-Galles du Sud. Android (KosherJava) est juste : c'est une divergence Android/web que les vecteurs ne voient pas (ils ne couvrent que Jérusalem, Paris, New York, Melbourne, Tromsø ; Melbourne est à 19,66 h, juste sous le seuil de 20 h).

**Preuve.** R/web/src/vendor/kosher-zmanim-0.9.0.min.js, getRawOffset : « let l=Math.max(o.offset,u.offset);h=l<0?0-l:0-Math.min(o.offset,u.offset) » ; getAntimeridianAdjustment : « return t>=20?1:t<=-20?-1:0 » → 1 pour Sydney. Contre-calcul (scripts W.java + t12.mjs) : moteur web contre KosherJava 2.5.0 sur les 51 villes × 43 dates × 16 valeurs (35 088) : écart maximal 0,010 s partout, sauf Sydney : 688 valeurs sur 688 à ≈ 86 400 s. Sydney 2026-06-21 : web « netz 2026-06-22 07:00 », KosherJava « 2026-06-21T06:59:57 ». Samedi 2027-04-03 : web « sortie=18:24 [instant dim. 04/04 18:24] », KosherJava « tset 2027-04-03T19:25:21 », Hebcal 19:25. momentDuSiddour(Sydney) vendredi 13/11/2026 à 10:00, 15:00, 20:30 → 'chema_coucher' (Melbourne aux mêmes instants : chaharit, minha, null). Fichiers déployés identiques aux sources (cmp sur myhitbodedut-web/js/zmanim.js et vendor/).

**Correction proposée.** Dans web/src/js/zmanim.js, calendrier() : créer le GeoLocation à part et remplacer son ajustement — « const decalage = (m) => DateTime.fromObject({ year, month: m, day: 1, zone: lieu.fuseau }).offset; const h = lieu.longitude / 15 - Math.min(decalage(1), decalage(7)) / 60; geo.getAntimeridianAdjustment = () => (h >= 20 ? 1 : h <= -20 ? -1 : 0); ». Essayé sur une copie : les 51 villes concordent alors avec KosherJava à 0,010 s, Auckland et Wellington aussi, et test/calendrier.test.mjs passe (17/17). Ajouter Sydney et Auckland à tools/vecteurs_kosherjava et un test « chaque zman tombe le jour civil demandé » pour toutes les villes de villes.json.

**Note du contre-expert.** Reproduit sur une copie neuve des sources web (identiques au site déployé, vérifié par cmp sur zmanim.js, jour-affiche.js, app.js et le vendor) : sur les 51 villes, seule Sydney rend un nets hors du jour demandé (2026-06-21 → 22/06 07:00) ; samedi 2027-04-03 la sortie s'affiche 18:24 alors que KosherJava 2.5.0, relancé à part, donne 19:25:21 (ajustement d'antiméridien 0) ; momentDuSiddour rend « chema_coucher » à 10 h, 15 h et 20 h 30, et Auckland est décalée de même, quel que soit le fuseau de l'appareil. Le code cité de getRawOffset et getAntimeridianAdjustment est exact, et le correctif proposé, appliqué sur une copie, rend Sydney et Auckland à la seconde de KosherJava avec 17 tests sur 17 (la bibliothèque embarque luxon 1.28.1 : la syntaxe « zone » dans l'objet est la bonne). La portée se limite à Sydney et aux positions de Nouvelle-Zélande ou à l'est de 150° E, mais une sortie de Chabbat annoncée 61 minutes trop tôt justifie la gravité.

### FCALENDRIER-03 — Birkat haLevana : « Dernier soir » un jour trop tard quand la fenêtre se ferme l'après-midi

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** Le dernier soir est calculé « fin − 12 h ». Quand la fin tombe entre midi et la tombée de la nuit, le jour désigné est celui où la fenêtre est déjà fermée avant la nuit : le vrai dernier soir (la veille) s'affiche « Possible ce soir », sans alerte de dernier soir, et le lendemain l'écran dit « Dernier soir » alors qu'on ne peut plus bénir. Sur Android le rappel « dernier soir » n'est alors jamais envoyé (l'heure de tsét dépasse la fin, la boucle l'écarte), et la carte de l'accueil « Possible ce soir » reste affichée après la fermeture. Fréquence mesurée de novembre 2026 à 2028 : 7 à 11 fenêtres sur 27 selon la ville et l'usage. Cas imminent : Kislev 5787, la mi-mois est mardi 24/11/2026 à 15:28 (Paris) ; l'application annoncera « Dernier soir » le 24, le vrai dernier soir est lundi 23.

**Preuve.** K/Levana.kt:57 : « fun dernierSoir(zone: ZoneId): LocalDate = fin.minus(Duration.ofHours(12)).atZone(zone).toLocalDate() » ; R/web/src/js/calendrier-juif.js:261 : « dernier: local(f.fin - 12 * 3600000) ». K/LevanaAlerte.kt:45 : « if (quand.isAfter(maintenant) && !quand.toInstant().isAfter(f.fin)) return quand to soir ». K/AccueilMoment.kt:35 et R/web/src/js/app.js:729 : carte dès 14 h sans comparer à la fin. Exécution (t2.mjs) : « paris sept_mi_mois … DERNIER 2026-11-24: fin=mar. 24/11/2026 15:28 < tset=mar. 24/11/2026 17:53 » ; KosherJava : « mi-mois 2026-11-24T15:28:15 », « Paris tset 24/11/2026 17:53:15 ». Autres : 22/01/2027 (fin 16:56, tsét 18:23), New York 22/03/2027 (fin 13:24).

**Correction proposée (revue par le contre-expert).** Garder la recommandation (dernier soir = dernier jour dont le tsét du lieu précède la fin ; sans lieu, fin − 20 h ; carte de l'accueil seulement si maintenant < fin), en précisant le test : Kislev 5787 à Paris avec les usages TROIS_MI_MOIS et SEPT_MI_MOIS, dernier soir attendu le 23/11/2026 ; avec SEPT_QUINZE à Paris la fin est à 21:06 et le dernier soir reste le 24/11, alors qu'à New York (fin 15:06) il devient le 23/11. Vérifier aussi que Levana.fenetre et LevanaAlerte.soirs, qui s'appuient sur dernierSoir, passent alors à la fenêtre suivante dès le 24.

**Note du contre-expert.** Levana.kt:57 et calendrier-juif.js:261 sont bien « fin − 12 h » ; exécution web et KosherJava : Kislev 5787, mi-mois le mardi 24/11/2026 à 15:28 (Paris), tsét à 17:53, l'état est « ce_soir » le 23 et « dernier » le 24, puis fenêtre suivante le 25. Recomptage de novembre 2026 à fin 2028 : 7 à 11 fenêtres sur 27 selon la ville et l'usage (Paris 11 et 8, New York 8 et 10, Jérusalem 7 et 9) ; LevanaAlerte.kt:45 écarte bien le rappel dont le tsét dépasse la fin, et AccueilMoment.kt:35 comme app.js:729 ne comparent pas à la fin. Aucun test ni aucune décision de la feuille de route ne couvre ce cas ; précision : à Paris, le cas du 24/11/2026 vaut pour les deux usages « mi-mois » (défaut Ashkenaz et Sefard), pas pour « 15 jours » (fin à 21:06).

### FCALENDRIER-04 — Rappel « demande de la pluie » en diaspora : annoncé pour vendredi soir 4 décembre 2026, soir de Chabbat

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** Le rappel prend le premier jour civil où KosherJava dit « ותן טל ומטר » (samedi 5/12/2026) et annonce le changement « à la Amida d'Arvit » du soir précédent, vendredi 4/12 : or la Amida de Chabbat n'a pas cette bénédiction, on commence à motsaé Chabbat. La carte de l'accueil dira donc du 2 au 4 décembre 2026 « Vendredi soir / Demain soir / Ce soir, à la Amida d'Arvit, on commence à demander la pluie », puis disparaîtra le samedi 5, le soir précisément où le changement a lieu. KosherJava a la bonne date (isVeseinTalUmatarStartDate : dimanche 6/12 ; isVeseinTalUmatarStartingTonight : samedi 5/12), l'application ne s'en sert pas. Même défaut en 2031 (6/12 un samedi). Le test fige la date sans regarder le jour de la semaine.

**Preuve.** K/RappelsTefila.kt:55 : « if (pluie in j.conditions && pluie !in veille.conditions) res += Rappel(Type.PLUIE_DEBUT, d) » et :117-121 (« soir = r.date.minusDays(1) … soir == aujourdhui -> rappel_ce_soir ») ; R/web/src/js/calendrier-juif.js:305 et app.js:695-699 identiques. Exécution web : « 2026-12-04 [{"type":"pluie_debut","date":"2026-12-05"}] », « 2026-12-05 [] ». KosherJava 2.5.0 : « 2026-12-05 SATURDAY recited=true startDate=false startingTonight=true », « 2026-12-06 SUNDAY startDate=true ». Chaîne rappel_pluie_debut : « %1$s, à la Amida d’Arvit, on commence à demander la pluie ». RappelsTefilaTest.kt:27-29 : « Premier jour le 5 décembre : on commence à Arvit du 4 au soir ».

**Correction proposée (revue par le contre-expert).** Garder la recommandation (si le premier jour d est un samedi, dater PLUIE_DEBUT de d + 1 : la phrase devient « Motsaé Chabbat, à la Amida d’Arvit… » et reste affichée le samedi), et corriger en même temps les deux assertions qui figent le 5 décembre : RappelsTefilaTest.kt:27-29 et web/test/calendrier.test.mjs:350, date attendue 2026-12-06 ; ajouter 2031 (premier jour samedi 06/12, rappel attendu au 07/12).

**Note du contre-expert.** RappelsTefila.kt:55 et 117-124, calendrier-juif.js:305 et app.js:695-699 relus ; exécution web : les 2, 3 et 4/12/2026 rendent pluie_debut daté du samedi 2026-12-05 (donc « Vendredi soir / Demain soir / Ce soir, à la Amida d'Arvit… »), et le 5/12 ne rend plus rien. KosherJava 2.5.0 relancé à part : samedi 05/12 startingTonight=true, dimanche 06/12 startDate=true ; même cas le samedi 06/12/2031 (et le 05/12/2037). La mention « diaspora le 5 décembre 2026 » de la feuille de route (14/10) vise la bascule du siddour, pas l'annonce d'un Arvit de vendredi soir : ce n'est pas un choix délibéré.

### FCALENDRIER-06 — « Israël / diaspora » réécrit sans bruit à chaque reprise de « Ma position »

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : fonction

**Constat.** Avec « Ma position » comme lieu, chaque reprise silencieuse de la position (ouverture de Zmanim ou de la boussole, retour sur l'accueil après six heures, toutes les cinq minutes sur le web) réécrit le réglage Israël / diaspora d'après le contour du territoire. Le choix fait à la main dans les réglages est donc effacé à l'ouverture suivante, alors que le code renvoie justement à ce réglage pour les cas limites ; et un voyageur change de régime (un ou deux jours de fête) en passant la frontière, ce qui modifie le calendrier, les ajouts du siddour et les jours chômés de la série — le risque que Store.inIsrael disait avoir écarté le 01/10. Que la région suive la position est une décision documentée (16/10) ; l'écrasement du choix manuel ne l'est pas.

**Preuve.** K/ChoixLieu.kt:226 : « Store.setInIsrael(context, TerritoireIsrael.contient(position.latitude, position.longitude)) », appelé par rafraichir() (ZmanimActivity.kt:38, BoussoleActivity.kt:55, MainActivity.kt:149) ; R/web/src/js/app.js:2511 : « store.setInIsrael(dansIsrael(p.coords.latitude, p.coords.longitude)) », appelé par rafraichirPosition (2534). Réglage manuel : K/SettingsActivity.kt:129, app.js:4296-4298. K/TerritoireIsrael.kt:10 : « le réglage « Israël / diaspora » reste là pour ça ». K/Store.kt:392-394 : « sans cela, un voyage changeait le deuxième jour de fête après coup, et pouvait casser une série ».

**Correction proposée (revue par le contre-expert).** Corriger seulement l'écrasement : mémoriser que la région a été choisie à la main (clé « in_israel_manuel », à inclure dans l'export et l'import de Store) et ne plus la réécrire lors des reprises silencieuses de la position (ChoixLieu.enregistrerPosition, localiserPosition du web) ; un choix explicite de lieu (une ville, ou le bouton « Utiliser ma position ») efface ce drapeau et redéduit la région, conformément à la décision du 16/10. Mettre à jour le commentaire de Store.inIsrael, et tester sur les deux plateformes : bascule manuelle puis reprise silencieuse, la région ne bouge pas. En option, à faire décider par le propriétaire : demander au lieu d'imposer quand le territoire détecté change, avec les deux sens — FR « Vous êtes en Israël : un jour de fête ou deux ? » et « Vous avez quitté Israël : un jour de fête ou deux ? » / EN “You are in Israel: one day of Yom Tov or two?” and “You have left Israel: one day of Yom Tov or two?” / HE « אתם בישראל: יום טוב אחד או שניים? » et « יצאתם מישראל: יום טוב אחד או שניים? ».

**Note du contre-expert.** Le cœur est vérifié : avec « Ma position », rafraichir() (ZmanimActivity.kt:38, BoussoleActivity.kt:55, MainActivity.kt:149 après six heures) aboutit à enregistrerPosition, qui réécrit Store.setInIsrael (ChoixLieu.kt:226), et localiserPosition fait de même sur le web (app.js:2511), alors que le réglage manuel existe (SettingsActivity.kt:129) et que app.js:4295 le dit « déduite du lieu, et corrigeable à la main » (02/11). À corriger dans le constat : le changement de régime du voyageur est la décision documentée du 16/10 (ZMANIM.md:171-173, « la région suit la position ») et ne compte pas comme défaut, le commentaire de Store.kt:392-394 étant simplement périmé ; sur le web la reprise n'a pas lieu « toutes les cinq minutes » mais à l'ouverture de Zmanim ou de la boussole et au retour sur la page, au plus une fois par cinq minutes. La seconde moitié de la recommandation (« proposer au lieu d'imposer ») revient sur cette décision du propriétaire : à lui soumettre comme option, pas comme correction.

### FCALENDRIER-05 — Vignettes Zmanim : la fête du jour ne s'affiche jamais

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : android · **Type** : fonction

**Constat.** La pastille en tête des trois vignettes doit montrer « la fête du jour, sinon la paracha de la semaine ». Le code cherche le libellé avec la clé nue de la fête (« hanouka », « pessah »), alors que la table Libelles ne connaît que « fete_&lt;clé> » : le résultat est toujours null. La vignette montre donc la paracha même à 'Hanouka, Pourim ou Roch 'Hodech, et rien du tout une semaine dont le Chabbat est jour de fête. Aucun test ne lit la pastille.

**Preuve.** K/ZmanimVignette.kt:85 : « val fete = jour.fetes.firstNotNullOfOrNull { Libelles.res(it) }?.let { context.getString(it) } » ; K/Libelles.kt : seules des clés « ajout_… », « fete_… », « zman_… », puis « else -> null » ; K/VueJour.kt:158 fait bien « Libelles.res("fete_$it") ». Commentaire de ZmanimVignette.kt:25 : « La date hébraïque et la fête du jour, ou la paracha de la semaine, en tête ».

**Correction proposée (revue par le contre-expert).** Écrire Libelles.res("fete_$it") et passer Store.mukafChoma(context) à CalendrierJuif.jour. Pour le test, sortir le choix de la pastille dans une fonction pure (par exemple ZmanimVignette.clePastille(jour) qui rend « fete_hanouka » ou null) et vérifier sur la machine virtuelle qu'elle rend, pour 2026-12-06 ('Hanouka), une clé que Libelles.res connaît ; ajouter à LibellesTest que chaque valeur de CalendrierJuif.FETES, préfixée de « fete_ », est dans la table.

**Note du contre-expert.** Le défaut est réel : ZmanimVignette.kt:85 appelle Libelles.res(it) avec la clé nue, alors que les 35 clés de CalendrierJuif.FETES n'ont aucune entrée commune avec les 124 clés de Libelles (toutes préfixées ajout_, fete_ ou zman_) et que les quatre autres appelants écrivent « fete_$it » ; la pastille ne montre donc jamais la fête. Gravité à ramener à mineur : rien de faux ne s'affiche (la paracha est juste, ou la pastille est masquée), et la fête n'est promise que dans le commentaire du code et le message de commit du 28/10, pas dans les descriptions de vignettes vues par l'utilisateur. Le test proposé n'est pas exécutable tel quel : WidgetTest ne peut pas rendre de RemoteViews (pas de Robolectric dans build.gradle).

### FCALENDRIER-07 — « Chabbat dans 3 h » : notification hebdomadaire sans interrupteur

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Dès qu'un lieu est choisi, l'alerte du vendredi est programmée ; aucun réglage ne permet de la couper (le rappel de Birkat haLevana a le sien, pas elle), et elle part même si le rappel quotidien est désactivé. La seule issue est de couper tout le canal « reminder » d'Android, donc aussi les autres rappels.

**Preuve.** K/ChabbatAlerte.kt:49-57 : programmer() ne lit aucune préférence (« val lieu = Store.lieuAlertes(context) ?: return ») ; à comparer à K/LevanaAlerte.kt:67 : « if (!Store.levanaRappel(context)) return ». Recherche de « chabbat » dans res/layout/activity_settings.xml : aucune ligne ; seul levana_rappel_switch existe (ligne 168). Notification sur Notifications.CHANNEL_REMINDER (ChabbatAlerte.kt:70).

**Correction proposée.** Ajouter un interrupteur à côté de celui de la Levana (Réglages → Écran Zmanim) et « if (!Store.chabbatAlerte(context)) return » en tête de programmer(). Libellés : FR « Alerte « Chabbat dans 3 h » » / EN “‘Shabbat in 3 hours’ alert” / HE « התראת „שבת בעוד 3 שעות” ».

### FCALENDRIER-08 — Six villes de la liste perdent l'aube 22 à 80 jours par an : la prière du moment retombe sur des heures fixes

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** À Bruxelles (22 j), Anvers (30 j), Londres (36 j), Berlin (50 j), Manchester (60 j) et Moscou (80 j, plus 28 j sans michéyakir), le soleil ne descend pas à 16,1° autour du solstice : « Alot hacha'har — n'a pas lieu ce jour ». momentDuSiddour exige les sept zmanim et, dès qu'un seul manque, abandonne tous les autres pour les heures fixes : à Londres le 21/06/2027 il propose Arvit à 18 h 45 (chki'a 21:21, plag 19:37) et Tikoun 'hatsot à 0 h 30 (hatsot de la nuit 01:02) ; la vignette Android, sans aube, affiche « Cha'harit » dès minuit. Le repli est documenté, mais pour le « soleil de minuit » seulement. Autre effet visible à ces latitudes : « Tsét, Rabbénou Tam » (22:33) précède « Tsét hakokhavim » (22:36).

**Preuve.** K/JourAffiche.kt:117-118 : « val cles = listOf("alot", "misheyakir", "chatsot", "minha_gedola", "chkia", "tset", "chatsot_layla") ; if (cles.any { z[it] == null } || …) return SiddurMoment.suggestion(local.toLocalTime()) » ; R/web/src/js/jour-affiche.js:81-82 identique ; K/ZmanimWidget.kt:25-30 (branche de nuit conditionnée à « alot != null »). Exécution (t9.mjs, t14.mjs) : « Londres alot: 36 j (2027-06-04 → 2027-07-09) », « Moscou alot: 80 j … misheyakir: 28 j » ; Londres 2027-06-21 « 18:45 => arvit », « 00:30 => tikoun_hatsot », Paris au même instant « minha ». ZMANIM.md:127-128 : « sans zmanim (soleil de minuit), les heures fixes d'avant ».

**Correction proposée.** Ne retomber sur les heures fixes que si le zman nécessaire à la branche manque : remplacer une aube absente par « alot ?: misheyakir ?: netz » dans momentDuSiddour (Kotlin et JS) et dans ZmanimWidget.prochaine ; garder le repli complet quand chki'a ou tsét manquent. Test : Londres, 21/06, 18 h 45 → minha. Corriger la phrase de ZMANIM.md (voir le constat sur la documentation).

### FCALENDRIER-09 — Les heures sont tronquées à la minute, y compris la sortie de Chabbat

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** Tous les horaires sont formatés en HH:mm par simple troncature des secondes. C'est le bon sens pour les heures limites (fin du Chema, de la Téfila, chki'a, allumage), mais c'est le sens indulgent pour les heures de début : aube, michéyakir, nets, min'ha guedola, tsét, Rabbénou Tam, « Sortie de Chabbat ou de fête », allumage « après tsét » s'affichent jusqu'à 59 s trop tôt. L'usage des calendriers (Hebcal notamment) est d'arrondir la sortie vers le haut. Le sens de l'arrondi n'est écrit nulle part dans ZMANIM.md.

**Preuve.** K/VueJour.kt:284 et :298 : « DateTimeFormatter.ofPattern("HH:mm") … z.local!!.format(heure) » ; K/ZmanimVignette.kt:48 ; K/HorairePriere.kt:19 ; R/web/src/js/zmanim.js:93-95 (Intl hour/minute). Exécution (t10.mjs) : Paris 2026-11-28 « sortie: affiché 17:50 (réel 17:50:50) » ; Jérusalem 2026-11-21 « sortie: affiché 17:15 (réel 17:15:44) », « minha_gedola: affiché 11:50 (réel 11:50:50) ».

**Correction proposée.** Arrondir à la minute supérieure les zmanim « pas avant » (alot, misheyakir, netz, minha_gedola, tset, tset_rt, sortie, allumage apres_tset, chatsot_layla) : « local.plusSeconds(59).truncatedTo(ChronoUnit.MINUTES) » ; garder la troncature pour les heures limites. Même règle dans heure() du web, puis une ligne dans ZMANIM.md (« arrondi du côté de la rigueur »).

### FCALENDRIER-10 — Birkat haLevana : rappel du « premier soir » avant l'ouverture de la fenêtre, et ouverture fixée à 20 h à la sortie de Kippour et du 9 Av

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** Deux bornes ignorent l'heure réelle. (1) Android : le rappel « premier soir » part à tsét du jour où la fenêtre s'ouvre, même si elle n'ouvre que plus tard dans la nuit, alors que l'application compte elle-même « d'heure à heure ». Ce soir même (12/11/2026, usage 3 jours) : rappel à 18:04 à Paris, fenêtre ouverte à 21:06 ; à Jérusalem 17:19 contre 22:06 ; jusqu'à 6 h d'avance (14/01/2027). 5 à 7 fenêtres sur 27. (2) Android et web : après Kippour et Tich'a bèAv, le début affiché est 20 h fixe et non la sortie des étoiles du lieu : jeudi 12/08/2027 à Paris, « Du jeu. 12 août, 20:00 » alors que le jeûne finit à 22:05 ; Kippour 30/09/2028, 20:00 contre 20:17.

**Preuve.** K/LevanaAlerte.kt:44-45 : « val quand = heure(d) ; if (quand.isAfter(maintenant) && !quand.toInstant().isAfter(f.fin)) » — aucune comparaison à f.debut. K/Levana.kt:99 : « val sortie = soir(j, zone) » et :147 « date.atTime(LocalTime.of(20, 0)) » ; calendrier-juif.js:240 et :256. Exécution (t2.mjs, t15.mjs) : « PREMIER 2026-11-12: debut=jeu. 12/11/2026 21:06 > tset=jeu. 12/11/2026 18:04 (182 min) » ; « jer … PREMIER 2027-01-14: debut 23:34 > tset 17:35 (359 min) » ; « restriction tisha_beav début affiché jeu. 12/08/2027 20:00 | tsét ce jour-là 22:05 ».

**Correction proposée.** Dans LevanaAlerte.prochain : « val quand = maxOf(heure(d), f.debut) » (comparer les instants). Dans Levana.du et levana() : prendre pour la sortie de Kippour et du 9 Av le tsét du lieu quand il est connu (passer le lieu ou une fonction « sortie du jour »), 20 h seulement sans lieu.

### FCALENDRIER-11 — Birkat haLevana proposée et rappelée un soir de Chabbat ou de Yom Tov, sans réserve

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** L'application applique le Rema 426:2 (Kippour, 9 Av, préférence pour motsaé Chabbat) mais pas la suite de la même règle : on ne dit pas Birkat haLevana le soir de Chabbat ni de Yom Tov, sauf si le temps va passer (Rema 426:2 pour motsaé Chabbat qui est Yom Tov ; Maguen Avraham 426:7 : « à plus forte raison le soir de Chabbat »). L'écran dit « Possible ce soir » et Android envoie « Birkat haLevana : premier soir » un vendredi soir ou un soir de fête. Premiers soirs concernés : 09/04/2027 et 31/12/2027 (usage 3 jours), 11/06/2027 (vendredi et Chavouot), 03/03/2028, 31/05/2028 (soir de Chavouot), 24/11/2028 (usage 7 jours).

**Preuve.** K/Levana.kt:132-140 (etat ne regarde ni le jour de la semaine ni la fête) ; K/LevanaAlerte.kt:28-32 (soirs) ; chaînes levana_ce_soir « Possible ce soir », levana_rappel_premier « Birkat haLevana : premier soir ». Exécution (t15.mjs, Paris) : « trois_mi_mois premier 2027-04-09(ven) premier 2027-12-31(ven) », « sept_mi_mois premier 2027-06-11(ven) premier 2028-03-03(ven) premier 2028-05-31(mer) premier 2028-11-24(ven) ». En-tête de Levana.kt:23-26 : seules les règles Kippour, 9 Av et motsaé Chabbat y figurent.

**Correction proposée.** Quand le soir est celui d'un jour chômé (CalendrierJuif.jour(date + 1).chome) et que ce n'est pas le dernier soir, afficher une réserve et repousser le rappel au soir suivant. Texte : FR « Soir de Chabbat ou de fête : on attend, sauf si c'est le dernier soir (Maguen Avraham 426:7) » / EN “Shabbat or Yom Tov night: one waits, unless it is the final night (Magen Avraham 426:7)” / HE « ליל שבת או יום טוב: ממתינים, אלא אם זה הלילה האחרון (מגן אברהם תכ״ו, ז) ».

### FCALENDRIER-12 — Carte « Dans les prières » : la 9e bénédiction de semaine annoncée les jours de Yom Tov et à Kippour

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** La ligne « Barkhénou / Barekh alénou » (Edot) ou « Vetèn berakha / Vetèn tal oumatar » n'est retirée que le Chabbat. Un Yom Tov ou un Kippour en semaine, où la Amida n'a pas non plus cette bénédiction, la carte du jour la nomme, suivie de « Pas de Ta'hanoun ».

**Preuve.** K/JourAffiche.kt:51 : « if (C.CHABBAT !in c) add(if (nusah == "edot") … ) » et :70 ; R/web/src/js/jour-affiche.js:23 et :39. Exécution (t11.mjs) : jeudi 2027-04-22 (15 Nissan) Edot → « ajout_machiv_harouah · ajout_morid_hatal · ajout_barkhenou · ajout_yaale_veyavo · ajout_hallel_complet · ajout_sans_tahanoun » ; lundi 2026-09-21 (Kippour) Ashkenaz → « … ajout_berakha · ajout_yaale_veyavo · ajout_sans_tahanoun ».

**Correction proposée.** Remplacer les deux tests par « if (C.CHABBAT !in c && C.YOM_TOV !in c) » (la condition yom_tov vient de isYomTovAssurBemelacha, qui couvre Kippour), en Kotlin et en JS ; ajouter le 15 Nissan et Kippour à JourAfficheTest et au test web.

### FCALENDRIER-13 — Après la sortie des étoiles, l'onglet Zmanim garde la date hébraïque de la veille alors que la vignette et le siddour ont changé de jour

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Depuis le 02/11 la vignette passe au jour hébreu suivant à tsét, et le siddour annonce ses ajouts pour le jour qui commence. L'écran Zmanim, lui, prend le jour civil du téléphone : le vendredi soir il n'affiche ni Chabbat ni sa date, le samedi soir il garde l'illustration et la paracha de Chabbat jusqu'à minuit. On touche la vignette qui dit le 3 du mois, l'écran qui s'ouvre dit le 2. La feuille de route donne « date hébraïque à la tset » pour fait (04/11) ; seul le widget l'a.

**Preuve.** K/ZmanimActivity.kt:49 et :54 : « val aujourdhui = LocalDate.now() … VueJour.carteJour(this, aujourdhui, israel, complet = false) » ; K/ZmanimVignette.kt:61-62 : « if (tset != null && !maintenant.isBefore(tset)) maintenant.toLocalDate().plusDays(1) » ; K/SiddurLectureActivity.kt:243-250 (jourDeLaPriere avec apresSortie, date hébraïque du lendemain dans la note). FEUILLE_DE_ROUTE.md:1100. Le web a la même carte (app.js:3072) mais pas de vignette.

**Correction proposée.** Sur la carte du jour de l'onglet Zmanim, après tsét du lieu, ajouter sous la date civile la date du jour qui commence (ZmanimVignette.jourHebreuAffiche est déjà là) : FR « Depuis la sortie des étoiles : %1$s » / EN “Since nightfall: %1$s” / HE « מצאת הכוכבים: %1$s ». Même ligne sur le web.

### FCALENDRIER-14 — Vignette : « Min'ha jusqu'à… » dès la fin du temps de Cha'harit, « Arvit » dès la chki'a

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction · déjà connu ou choix assumé

**Constat.** La « prière du moment » de la vignette passe à Min'ha dès la fin du temps de la Téfila (Gra), soit deux à trois heures avant min'ha guedola, et à Arvit dès le coucher du soleil, avant tsét. L'écran du siddour (momentDuSiddour) dit au même moment Cha'harit jusqu'à 'hatsot, puis rien, et la bannière de Min'ha dit « De min'ha guedola au coucher ». La limite de Cha'harit est celle du Gra sans que la vignette le nomme, alors que l'écran Zmanim nomme chaque méthode. Choix écrit dans le commentaire du code et figé par un test (13 h seulement) ; il reste trompeur entre 10 h et 12 h 30.

**Preuve.** K/ZmanimWidget.kt:21 : « Cha'harit jusqu'au sof zman tefila (GRA), Min'ha jusqu'à la chki'a, Arvit jusqu'à minuit » et :29-30 : « val limites = listOf("chaharit" to horaires["szt_gra"], "minha" to horaires["chkia"], "arvit" to horaires["chatsot_layla"]) » ; K/JourAffiche.kt:124-127 (« avant("chatsot") -> "chaharit" ; avant("minha_gedola") -> null ; … avant("tset") -> null ») ; K/HorairePriere.kt:23. DixAmeliorationsTest.kt:35-38 ne teste que 7 h, 13 h, 19 h, 23 h 50.

**Correction proposée.** Dans ZmanimWidget.prochaine, entre szt_gra et minha_gedola rendre (« minha », début = minha_gedola) et entre chki'a et tsét (« arvit », début = tset), et afficher alors « dès %s » au lieu de « jusqu'à %s ». Nouvelle chaîne widget_des : FR « dès %s » / EN “from %s” / HE « מ־%s ».

### FCALENDRIER-15 — « pas avant la sortie de la veille » : la mention sous l'allumage du deuxième soir désigne le mauvais jour

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Sous « Allumage des bougies » d'un jour chômé suivi d'un autre, la méthode dit « la sortie de la veille » (EN « the previous day », HE « היום הקודם »). La ligne figure dans les horaires du jour lui-même (par exemple le samedi de Roch Hachana) : « la veille » y désigne le vendredi. Il s'agit de la sortie du jour affiché.

**Preuve.** Clé zman_methode_apres_tset — res/values/strings.xml:740 « pas avant la sortie de la veille (8,5°) » ; values-en:676 « not before the previous day ends (8.5°) » ; values-iw:690 « לא לפני צאת היום הקודם (⁦8.5°⁩) ». Affichée par K/VueJour.kt:306-307 sous la ligne ajoutée en K/JourAffiche.kt:94.

**Correction proposée.** FR : « pas avant la sortie des étoiles de ce jour (8,5°) » — EN : “not before nightfall today (8.5°)” — HE : « לא לפני צאת הכוכבים של היום (⁦8.5°⁩) ».

### FCALENDRIER-16 — Calendrier : « ce soir », « today » et « Dans N jours » pour un jour qui n'est pas aujourd'hui

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le détail d'un jour touché dans le calendrier réutilise les textes de l'écran du jour : « Possible ce soir », « Lune ce soir : … », « Omer ce soir : jour N », « Dans 4 jours » se rapportent au jour choisi, pas à aujourd'hui, sans le dire. En anglais et en hébreu, un zman absent se lit « does not occur today » / « אינו מתרחש היום » même pour un autre jour (le français dit « ce jour »).

**Preuve.** K/CalendrierActivity.kt:195 et :207 (« VueJour.carteJour(this, choisi, israel) », « VueJour.horaires(this, choisi, …) ») ; K/VueJour.kt:109-116, :161 ; web app.js:4266-4269. Clés : levana_ce_soir (values:1035), levana_lune (values:1060), zmanim_omer_ce_soir (values:781), levana_dans ; zmanim_absent values-en:624 « does not occur today », values-iw:638 « אינו מתרחש היום ».

**Correction proposée.** zmanim_absent — EN : “does not occur on this day” ; HE : « אינו מתרחש ביום זה ». Pour un jour autre qu'aujourd'hui, variantes : levana_ce_soir → FR « Possible ce soir-là » / EN “Possible that night” / HE « אפשר לברך באותו לילה » ; levana_lune → FR « Lune ce soir-là : %1$s éclairée, %2$s » / EN “Moon that night: %1$s lit, %2$s” ; zmanim_omer_ce_soir → FR « Omer ce soir-là : jour %1$d » / EN “Omer that night: day %1$d” ; levana_dans → FR « %d jours plus tard » / EN “%d days later”.

### FCALENDRIER-17 — ZMANIM.md en retard sur le code : trois affirmations fausses

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : docs · **Type** : texte

**Constat.** (1) « Les bénédictions du repas suivent le jour civil » : depuis le 28/10 ils passent au jour suivant à la sortie des étoiles du lieu. (2) « Actualiser ma position … approximative seulement depuis le 31/10 (ChoixLieu.maPosition, web localiserPosition) » : le web demande toujours la haute précision. (3) Le repli sur les heures fixes est attribué au « soleil de minuit », alors qu'il se déclenche 22 à 80 jours par an dans six villes de la liste.

**Preuve.** ZMANIM.md:136-138 contre K/CalendrierJuif.kt:348-358 (« Les autres textes … passent au jour suivant à la sortie des étoiles du lieu », « else -> if (apresSortie) date.plusDays(1) else date »). ZMANIM.md:459-460 contre R/web/src/js/app.js:2519 : « { enableHighAccuracy: true, maximumAge: 60_000, timeout: 20_000 } ». ZMANIM.md:127-128 contre l'exécution de t9.mjs (Londres 36 j, Moscou 80 j).

**Correction proposée.** (1) Remplacer par : « Les bénédictions du repas et les autres textes passent au jour hébreu suivant à la sortie des étoiles du lieu (tsét 8,5°) ; sans lieu, ils suivent le jour civil. Min'ha garde le jour civil ; les ajouts restent ouvrables à la main. » (2) Soit passer « enableHighAccuracy: false » dans localiserPosition, soit écrire : « sur le web, la position est demandée en haute précision ». (3) « Sans lieu, ou quand un des zmanim manque (aube absente autour du solstice à Londres, Berlin, Moscou… ; soleil de minuit), les heures fixes d'avant. »

### FCALENDRIER-18 — Boussole : l'avertissement de calibrage disparaît à chaque redessin de l'écran

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Le texte « Boussole peu précise : dessinez un 8… » est recréé caché à chaque appel d'afficher(), et la dernière précision du capteur n'est pas mémorisée. Avec « Ma position », la reprise silencieuse lancée à l'ouverture rappelle afficher() quelques secondes plus tard : l'avertissement affiché s'efface alors que le capteur est toujours imprécis, et ne revient qu'au prochain changement de précision. Idem après « Direction suivie » ou « Affichage ». Le comportement du capteur sur un vrai téléphone n'a jamais été vérifié (ZMANIM.md:474-475).

**Preuve.** K/BoussoleActivity.kt:104-105 : « precision = VueJour.texte(this, getString(R.string.boussole_calibrer), …).apply { visibility = android.view.View.GONE … } » dans afficher() ; :246-250 : onAccuracyChanged est le seul endroit qui le montre ; :33 « ChoixLieu(this) { afficher() } » et :54-55 « afficher() ; choixLieu.rafraichir() ».

**Correction proposée.** Garder la dernière précision dans un champ (« private var peuPrecis = false », mis à jour dans onAccuracyChanged) et créer le texte avec « visibility = if (peuPrecis) VISIBLE else GONE ».

### FCALENDRIER-19 — Le nom du lieu reste dans la langue du jour où il a été choisi

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** Le nom de la ville (ou « Ma position · près de … ») est enregistré en texte, dans la langue de l'application au moment du choix. Si l'on change de langue ensuite, le bandeau Zmanim, la boussole, les réglages et la lecture de la vignette boussole gardent « Jérusalem » en hébreu ou « ירושלים » en français, jusqu'à ce qu'on rechoisisse le lieu.

**Preuve.** K/ChoixLieu.kt:54 : « Store.setLieuZmanim(activite, ville.lieu(langue), ville) » ; K/Store.kt:465 : « .putString(KEY_LIEU_NOM, lieu.nom) » et :419 (relu tel quel) ; R/web/src/js/app.js:2554 : « store.setLieu({ nom: titreTexte(v.nom), … }, v) ».

**Correction proposée.** À l'affichage, quand lieuVille ≠ -1, reprendre le nom dans villes.json par l'identifiant GeoNames et la langue courante ; pour une position, recomposer « zmanim_position_pres » avec la ville la plus proche.

### FCALENDRIER-20 — Petites incohérences de texte : chaînes mortes, description de vignette périmée, références et typographie

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** (1) Trois clés ne sont plus lues nulle part (9 chaînes avec les trois langues) : zmanim_omer, widget_zmanim_jusqua, widget_zmanim_chkia. (2) widget_zmanim_description promet « la chki'a » ; la vignette moyenne montre les trois prochains zmanim. (3) levana_kippour cite « Rema 426:2 » en français et en anglais, « שו״ע תכ״ו, ב ורמ״א » en hébreu (la règle est du Rema). (4) boussole_note (fr) écrit deux fois « Ora’h ‘Haïm » avec une apostrophe ouvrante, contre « ’Haïm » partout ailleurs. (5) zman_methode_milieu_chatsot : « milieu entre deux ’hatsot du jour » / « midpoint between two middays » sont vagues, l'hébreu dit « celui de demain ». (6) « 12 % » garde l'espace française en anglais (VueJour.kt:114, app.js:2796).

**Preuve.** res/values/strings.xml:693, :1083, :1084 (aucune référence dans K, res/layout*, res/xml ni web/src/js) ; :1079 « La date hébraïque, la prière du moment, la chki’a et la série. » contre K/ZmanimVignette.kt:127-132 (PROCHAINS) ; values:1064 et values-en:1000 contre values-iw:1030 ; values:1383 ; values:738, values-en:674, values-iw:688.

**Correction proposée.** (1) Supprimer les trois clés dans les trois fichiers. (2) FR « La date hébraïque, la prière du moment, les trois prochains zmanim et la série. » / EN “The Hebrew date, the prayer of the moment, the next three zmanim and the streak.” / HE « התאריך העברי, התפילה של השעה, שלושת הזמנים הבאים והרצף. » (3) HE « לא לפני מוצאי יום הכיפורים (רמ״א תכ״ו, ב) ». (4) « Ora’h ’Haïm ». (5) FR « milieu entre ’hatsot du jour et celui du lendemain » / EN “midpoint between today’s and tomorrow’s midday”. (6) Formater le pourcentage avec NumberFormat.getPercentInstance(locale) / Intl.NumberFormat(langue, { style: 'percent' }).

### FCALENDRIER-21 — Cases du calendrier : la date est lue au format « 2026-11-12 » par TalkBack et VoiceOver

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** La description accessible de chaque case commence par la date ISO brute, dans les trois langues, au lieu de la date en toutes lettres que l'application sait déjà écrire.

**Preuve.** K/CalendrierActivity.kt:182 : « contentDescription = listOf(d.toString(), j.dateHebraique).plus(…).joinToString(" · ") » ; R/web/src/js/app.js:4261 : « 'aria-label': `${d} · ${j.dateHebraique}…` ».

**Correction proposée.** Android : remplacer d.toString() par VueJour.dateCivile(this, d). Web : new Intl.DateTimeFormat(tr.langue, { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' }).format(new Date(`${d}T12:00:00Z`)).
