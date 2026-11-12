# TEN — Interface anglaise — fidélité et qualité

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

15 constats — confirmés en partie : 1 · confirmés : 3 · non contre-expertisés (mineurs et cosmétiques) : 11.

> Contre-expertise incomplète pour cette dimension.

## Ce qui a été examiné

Lu en entier : values-en/strings.xml (1 392 lignes, 1 223 entrées en comptant formes plurielles et tableaux) en regard de values/strings.xml, clé par clé ; la surcharge de l'édition légère (1 clé) ; les 45 invites anglaises de guide_sujets.json ; les titres courts de livres_titres.json (12) et des trois siddur_*.json (une quarantaine) ; TraductionTest.kt (parties anglaises) et TraductionAffichageTest.kt ; les 10 visuels de play/visuels/en et leur aperçu ; une capture de promo-screenshots (journal).

Lu en partie : la version anglaise de web/src/confidentialite.html (environ les trois quarts, jusqu'au paragraphe OpenSky) ; PUBLICATION_PLAY_STORE.md § 6.5-7.4 ; FEUILLE_DE_ROUTE.md (passages sur les traductions, « Ce qui manque », « Reste », « Sujets ouverts »).

Vérifié dans le code ou par exécution : l'usage d'une soixantaine de clés (MainActivity, JournalActivity, PaliersActivity, BlockerView, GateStatus, RemindersActivity, OnboardingActivity, Dedicace, RappelsTefila, MusiquePlay, Reference, SaisieVol, Store, Langue) ; les formats de date et d'heure exécutés en Java 21 avec la locale « en » ; l'analyseur de vol exécuté par son portage web (node) sur six phrases anglaises ; l'historique git en lecture (5f88a86, a899bb5, c9c571f, 7145e65).

Contrôles automatiques (scripts de l'auditeur précédent relancés et complétés, sorties sous OUT/TEN/v2 : pairs.tsv, pairs.txt, checks.out, terms.out, json_short_en.txt) : marqueurs, nombres, ponctuation française, guillemets, longueurs, variantes terminologiques, orthographe US/UK.

Seulement balayé au script, pas lu : les longs contenus anglais (chizuk.json, environ 54 000 caractères ; les livres, environ 5,5 millions ; biographies des hilloulot) pour y chercher des résidus français — ils relèvent des audits de traduction.

Non examiné : l'hébreu (values-iw) ; le rendu réel sur téléphone ou émulateur (troncatures, retours à la ligne) ; l'application Nokia (français seulement) ; les visuels fr et he. Les réécritures proposées évitent « session », interdit à l'affichage par TraductionAffichageTest ; aucune des chaînes à modifier n'est figée par un test, sauf « Refua shelema » (tefila_refua), que la proposition conserve.

## Ce qui tient

- Fidélité mécanique sans faille : 1 223 entrées anglaises pour 1 268 françaises ; les 45 absentes sont toutes translatable="false" ; aucune clé en trop ; marqueurs de format, nombres, mots hébreux, adresses et noms de domaine identiques entre fr et en (vérifié au script). Le site déployé porte exactement les mêmes chaînes anglaises que le dépôt.
- Typographie anglaise propre : aucun guillemet « », aucune espace insécable ni espace avant : ; ! ?, guillemets et apostrophes courbes partout, « … » en un caractère, « 60% » sans espace, décimales au point (« 8.5° », « 31.7781° N »), points cardinaux localisés (O→W, SO→SW).
- Casse cohérente : sentence case partout, noms propres capitalisés, un seul écart (« Tips for Hitbodedut »). La translittération « ch » du 04/11 (Shacharit, Mincha, Chatzot, chizuk, nusach) est appliquée aux chaînes, aux données, aux tables de références Android et web et aux outils de construction.
- Anglais concis et souvent idiomatique : 10 % plus court que le français au total, donc aucun risque de débordement repéré. Exemples : « Latest Shema », « %1$s so far », « the 6 hours either side », « Each milestone leads to the next », « The streak so far, and one tap to begin. »
- Les textes à enjeu réglementaire sont exacts : les deux divulgations avant les accès spéciaux (divulgation_overlay_texte, divulgation_usage_texte), les sous-types de service du manifeste et la politique de confidentialité anglaise citent mot pour mot les libellés de l'interface (« Reset the app », « Real position (GPS) », « Online services: flight route and live tracking »).
- Garde-fous réels : TraductionTest (mêmes clés, pluriels, marqueurs, aucun texte en dur, « God » interdit là où la source dit השם), références de sources localisées par Reference.kt, repli sur l'anglais pour un téléphone sans langue livrée (LangueApp.repli, langueInitiale côté web). « Hashem » 34 fois, « Him » et « He » en capitale, formule neutre prévue (« Well done! », « Take heart! »).

## Constats

### TEN-01 — Visuels Play anglais : captures antérieures à l'interface actuelle et légendes qui contredisent l'écran

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : play · **Type** : texte

**Constat.** Les 10 visuels anglais de la fiche (play/visuels/en, commit 7145e65 du 04/11) montrent une interface qui n'existe plus : 6 libellés périmés sur 4 visuels, dont un bouton « Exact position » sur la boussole que l'application a retiré le 31/10 et que la politique de confidentialité anglaise dément. Le visuel Musique montre des morceaux que la version Play ne livre pas. Six légendes emploient un autre vocabulaire que l'écran qu'elles surmontent, dont « session », mot que le propriétaire a banni de l'affichage. PUBLICATION_PLAY_STORE.md § 7.2 exige pourtant « l'interface réelle de la version envoyée » et ne signale pas ces visuels comme à refaire.

**Preuve.** Captures : 06-siddour-en.png « Sephardi nusah (Edot HaMizr… », « Shaharit » (2 fois), « Minha » (aujourd'hui « Sephardi nusach », « Shacharit », « Mincha », commit 5f88a86) ; 09-textes-en.png « I need hizuk » (values-en/strings.xml:1103 « I need chizuk ») ; 08-boussole-en.png bouton « Exact position » (chaîne retirée par c9c571f « Position exacte limitée au GPS en vol » ; confidentialite.html : précise « requested only on the “Zmanim in flight” screen ») ; 10-musique-en.png « Beyond — נעם שפייר » (aujourd'hui « Beyond — Noam Shpayer ») et « Niggun 01 … 04 / Shipped with the app », absents de MusiquePlay.kt:14-41. Légendes : 03 « Pick a duration… with a topic… From 5 minutes to 1 h 30 » au-dessus de « Pick a length », « Subject: none (optional) », « 1 h 30 min » ; 05 « Every session counts » (TraductionAffichageTest, « on ne dit plus seance ni session ») ; 07 « hilulot » au-dessus du bouton « Hillulot » ; 09 « Tehilim » au-dessus de « Tehillim » ; 04 « Rabbi Nachman’s advice » au-dessus d'un texte signé « Bisdei Yaar, ch. 21 » ; 06 « The siddur for this hour ».

**Correction proposée (revue par le contre-expert).** Refaire les captures anglaises depuis l'APK Play actuel (variante musique_play), en en gardant 8 au plus (limite rappelée au § 7.2), puis inscrire play/visuels au § 7.2 comme source à tenir à jour. Légendes à corriger : 03 “Pick a length, put the phone down” / “From 5 minutes to 1 h 30 min, with a subject and soft music if you like.” ; 04 “Advice and questions to help you begin.” ; 05 “Every hitbodedut counts” ; 07 “Today’s times, Hebrew calendar, halacha and hillulot.” ; 09 “Siddur, Tehillim, Tikkun HaKlali, Rabbi Nachman’s books.”. La légende 06 “The siddur for this hour” peut rester : elle reprend « For this hour » de l'écran.

**Note du contre-expert.** J'ai rouvert les PNG de play/visuels/en (commit 7145e65 du 04/11 à 20:56, après c9c571f du 31/10 et 5f88a86 du 04/11 à 05:52). Ils montrent bien « Exact position » (aujourd'hui boussole_actualiser_position « Update my location »), « Sephardi nusah », « Shaharit », « Minha », « I need hizuk » et « Beyond — נעם שפייר », ainsi que « Niggun 01…04 », qui sont seulement dans src/musique_hors_play (la variante musique_play rend une liste vide), et la légende « Every session counts » (règle du 29/09, TraductionAffichageTest). Il faut toutefois corriger un exemple : la légende 06 « The siddur for this hour » reprend justement « FOR THIS HOUR » de l'écran, et 04 pose un problème d'attribution, pas de vocabulaire. L'auditeur oublie aussi deux choses : le jeu compte 10 captures 1080×1920 alors que le § 7.2 fixe un maximum de 8, et ce § ne cite même pas play/visuels (il renvoie à captures-calendrier/).

### TEN-02 — Compteurs en anglais fautif : « 3 times hitbodedut », « First 3 times hitbodedut », « 1 trophies earned »

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : texte

**Constat.** L'en-tête du Journal, vu à chaque ouverture, affiche « 3 times hitbodedut, 1 h 05 min in total » ; quatre des cinq niveaux du trophée « First step » affichent « First N times hitbodedut ». Ces tournures ne sont pas de l'anglais. Elles viennent du commit a899bb5, qui a retiré « sessions » pour satisfaire TraductionAffichageTest sans chercher une tournure correcte. Or les deux chaînes comptent des jours (JournalActivity.kt:53 « Les journées faites seulement » ; Trophees.kt:86 `jours.size`). S'y ajoutent trois chaînes sans pluriel : un utilisateur dont la première hitbodedut dure moins de 10 min lit « 1 trophies earned · 9 more for Silver » (même défaut en français).

**Preuve.** values-en/strings.xml:237-238 « %1$d time hitbodedut, %2$s in total » / « %1$d times hitbodedut, %2$s in total » (JournalActivity.kt:66) ; :902 « First %1$d times hitbodedut » (PaliersActivity.kt:504) ; :852 « %1$d trophies earned · %2$d more for %3$s », :853 « %1$d trophies earned » (PaliersActivity.kt:78-79, n = faits.size) ; :859 « … and %1$d more trophies further on » ; :929 « Coming back %1$d time after a week’s break ».

**Correction proposée.** Sans « session » (règle du 29/09) : journal_summary one “%1$d day of hitbodedut, %2$s in total”, other “%1$d days of hitbodedut, %2$s in total” ; trophee_premier_pas_desc other “First %1$d days of hitbodedut” ; grade_sous “Trophies earned: %1$d · %2$d more for %3$s” ; grade_sous_max “Trophies earned: %1$d” ; trophees_autres “… and %1$d more further on” ; trophee_retour_desc one “Coming back once after a week’s break”.

**Note du contre-expert.** Les chaînes sont bien dans values-en/strings.xml : 237-238 « %1$d time(s) hitbodedut », 902 « First %1$d times hitbodedut », 852-853 « %1$d trophies earned », 859 et 929. JournalActivity.kt compte des journées (faites = rows.count { it.faite }) et Trophees.kt:86 compte jours.size ; le site affiche les mêmes chaînes (app.js:2265, 4083). PaliersActivity.kt:57 donne n = faits.size et SEUILS_GRADES = 0, 10, 25, 50 : une première hitbodedut de moins de 10 min, hors vendredi et sans note, n'obtient que Premier pas 1, d'où « 1 trophies earned · 9 more for Silver ». Le français et l'hébreu disent « N hitbodedout » et « N התבודדויות », donc seul l'anglais est agrammatical. Les réécritures proposées sont correctes et n'emploient pas « session ».

### TEN-03 — Neuf titres de morceaux livrés restent en français dans l'interface anglaise, dont la note « (titre incertain) »

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : texte · déjà connu ou choix assumé

**Constat.** Sur les 26 morceaux de la version Play, 9 titres contiennent du français et sont marqués translatable="false" : ils s'affichent tels quels en anglais dans la bibliothèque musicale, la ligne « Music: … » de la hitbodedut, le mini-lecteur et sur le site. Quatre autres gardent une translittération française (’H, ou). Choix documenté (commentaire « Titres non traduits : ce sont des noms propres », message du commit 5f88a86), mais critiquable : « Niggoun de… », « du… », « (titre incertain) » et les guillemets « » ne sont pas des noms propres, et le test nommé « aucun titre de morceau ne reste en francais » (TraductionAffichageTest) ne vérifie que « titre à préciser ». Le propriétaire s'était plaint du français en anglais le 28/09.

**Preuve.** values/strings.xml:292 (commentaire) ; :334 « Niggoun « Ki hiné ka\'homer » — Noam Shpayer » ; :338 « Niggoun du Baal Chem Tov — Ianir » ; :339 « Zemer bichva\'hin (titre incertain) — Ianir » ; :340 « Niggoun de Berditchev » ; :341 « Kol baYa\'ar (Niggoun du Saba de Chpola) » ; :342 « Niggoun de Rabbi Yo\'hanan HaSandlar » ; :344 « Niggoun de \'Houppa » ; :347 « Niggoun de Kabbalat Chabbat (live) » ; :348 « Niggoun de Bessarabie ». Translittérations : :327 « Eshet \'Hayil », :329 « Afilou », :330 « Kenout », :332 « Hit\'hadchout ». Site déployé : myhitbodedut-web/data/strings.en.json, track_ianir_zemer_bishvahin = « Zemer bichva'hin (titre incertain) — Ianir ».

**Correction proposée (revue par le contre-expert).** Retirer translatable="false" de ces 13 titres et ajouter dans values-en (et un équivalent dans values-iw) : “Niggun “Ki Hineh KaChomer” — Noam Shpayer” ; “Niggun of the Baal Shem Tov — Ianir” ; “Zemer Bishvachin (title uncertain) — Ianir”, à garder tant que l'artiste n'a pas confirmé le titre (il s'agit probablement du piyyout de l'Ari « Azamer Bishvachin », אזמר בשבחין, à vérifier avant de retirer la mention) ; “Berditchev Niggun — Ianir” ; “Kol BaYa’ar (Niggun of the Shpoler Zeide) — Ianir” ; “Niggun of Rabbi Yochanan HaSandlar — Ianir” ; “Chuppah Niggun — Ianir” ; “Kabbalat Shabbat Niggun (live) — Ianir” ; “Bessarabian Niggun — Ianir” ; “Eshet Chayil — Or &amp; Noam Shpayer” ; “Afilu (Even) — Noam Shpayer” ; “Kenut (Sincerity) — Noam Shpayer” ; “Hitchadshut (Awakening) — Noam Shpayer”. Étendre le test aux mots « Niggoun », « de », « du », « titre » et aux guillemets « » dans les titres de morceaux affichés en anglais.

**Note du contre-expert.** Les 26 morceaux de MusiquePlay.kt sont vérifiés : les 9 titres en français (values/strings.xml:334, 338-342, 344, 347, 348) sont translatable="false" et n'ont aucune version en ou iw, et le site déployé affiche « Zemer bichva'hin (titre incertain) — Ianir » dans strings.en.json. Le test « aucun titre de morceau ne reste en francais » ne contrôle que « titre à préciser » et Niggun 01. La plainte du 28/09 est attestée par le commentaire en tête de TraductionAffichageTest. Seule réserve : les numéros de ligne des 4 translittérations sont décalés de 1 (Eshet 'Hayil 326, Afilou 328, Kenout 329, Hit'hadchout 331). La réécriture « Zemer Bishvachin » supprime la mention d'incertitude, contrairement à la règle « on ne nomme que ce qu'on entend ».

### TEN-04 — Fiche Play anglaise : description courte et longue non rédigées, note aux examinateurs en français seulement

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : play · **Type** : texte · déjà connu ou choix assumé

**Constat.** L'anglais est la langue par défaut de la fiche (tranché le 29/10), mais seul le titre existe. La description courte et la description complète sont « à rédiger » ; la note aux examinateurs n'existe qu'en français, avec la mention « le traduire pour la note en anglais ». Point déjà inscrit au cahier de publication ; retenu ici parce que c'est le premier texte anglais que lira un examinateur ou un utilisateur.

**Preuve.** PUBLICATION_PLAY_STORE.md § 7.1 : « Description courte | 80 caractères | en : à rédiger, avec « התבודדות » » ; « Description complète | 4 000 caractères | Plan : … » ; § 7.3 : « Libellé repris de `action_preview_gate` (`values/strings.xml`) ; le traduire pour la note en anglais. »

**Correction proposée.** Description courte (78 caractères) : “Daily hitbodedut (התבודדות): timer, morning app gate, siddur, Tehillim, zmanim”. Note aux examinateurs, avec les libellés exacts de values-en : “No account is needed. To see the gate: Home → Settings → “Required permissions” (grant “Display over other apps” and “Usage access”) → “Choose apps” → tap “Preview the “I am with Hashem” screen now” (works at any time of day, with no effect). The gate is a self-discipline tool that users set up on their own phone and can switch off at any time. No usage data leaves the device.” Description complète : suivre le plan du § 7.1 avec le vocabulaire de l'interface (hitbodedut, length, subject, streak, “I am with Hashem”), sans « session ».

**Note du contre-expert.** Dans PUBLICATION_PLAY_STORE.md, le § 7.1 indique bien « en : à rédiger » pour la description courte et ne donne qu'un plan pour la complète ; le § 7.3 n'a la note qu'en français, avec « le traduire pour la note en anglais ». Aucun autre texte de fiche n'existe dans le dépôt. Le point est déjà connu, l'auditeur le reconnaît, et il reste nécessaire avant l'envoi. J'ai vérifié la réécriture : 78 caractères avec התבודדות, et des libellés identiques à values-en (Settings, « Required permissions », « Display over other apps », « Usage access », « Choose apps », action_preview_gate), le terme « morning gate » venant lui aussi de l'interface (divulgation_overlay_texte).

### TEN-05 — Translittérations françaises restées en anglais : « Tsadik », « Tsadeket », « Asher Yatsar », « Likutei Etsot », « mitsva »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Depuis le 04/11 l'anglais écrit « tz » partout (Chatzot, Netz, Motzaei, Kitzur, Atzeret, tzaddik). Cinq graphies françaises en « ts » subsistent, 14 occurrences. La plus visible : le bravo de fin de chaque hitbodedut dit « Well done, Tsadik! » (il figure sur le visuel Play 05) alors que l'écran des hilloulot écrit « tzaddik ». Le même livre s'appelle « Likutei Etzot » dans les Livres et « Likutei Etsot » sous les textes de chizuk ; le test « en anglais une reference ne garde aucune graphie francaise » ne cherche pas « Etsot ».

**Preuve.** values-en/strings.xml:462 « Tsadik », :463 « Tsadeket », :465 « Well done, Tsadik! », :466 « Well done, Tsadeket! » face à :818 « Search for a tzaddik », :833-834 « %1$d tzaddik on this day » / « tzaddikim ». Reference.kt:24-26 et web/src/js/regles.js:39-41 « Likutei Etsot, Strengthening », « …, Hitbodedut », « …, Prayer » face à livres_titres.json « Likutei Etzot ». siddur_edot.json, siddur_sefard.json, siddur_ashkenaz.json : titre « Asher Yatsar ». guide_sujets.json:184 « Which mitsva have you let slip these last days? », :199 « every mitsva ». chizuk.json:415 « a true tsadik », :583 « famous tsadikim ».

**Correction proposée.** “Tzaddik”, “Tzadeket”, “Well done, Tzaddik!”, “Well done, Tzadeket!” ; “Likutei Etzot, Strengthening ”, “Likutei Etzot, Hitbodedut ”, “Likutei Etzot, Prayer ” (Reference.kt et regles.js) ; “Asher Yatzar” (tools/siddur_construction.py puis reconstruction) ; “Which mitzvah have you let slip these last days?”, “Give thanks for every mitzvah you were able to do.” ; “a true tzaddik”, “famous tzaddikim”. Ajouter « Etsot|Tsadi|mitsva|Yatsar » à l'expression du test.

### TEN-06 — Faux amis et mots à double sens : « not a trial », « Thanksgiving », « Simply speaking », « Open hitbodedut »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Quatre calques se lisent autrement en anglais. « Regret before Him is not a trial » : « trial » se comprend d'abord comme « épreuve », le contraire de l'apaisement voulu par « procès ». « Thanksgiving » en titre d'étape évoque la fête américaine. « Simply speaking », titre du premier écran de présentation (visuel Play 01), est une locution qui veut dire « pour faire simple ». « Open hitbodedut, 12 min so far » sur l'écran de blocage se lit comme l'impératif « Ouvrez », et ce mode s'appelle « No set length » sur le bouton qui le lance.

**Preuve.** values-en/strings.xml:176 « Say what you regret, and say it plainly. Regret before Him is not a trial. » (fr : « n’est pas un procès ») ; :181 « Thanksgiving » (fr : « L’action de grâce ») ; :188 « Simply speaking » (fr : « Parler, simplement » ; Onboarding.kt:49) ; :192 « Open hitbodedut, %1$s so far. The phone can wait. » (BlockerView.kt:102) ; :437 « Pick a length, or an open hitbodedut, … » face à :151 « No set length ».

**Correction proposée.** :176 “Say what you regret, and say it plainly. Regret before Him is not putting yourself on trial.” ; :181 “Giving thanks” ; :188 “Just talk” ; :192 “Hitbodedut with no set length, %1$s so far. The phone can wait.” ; :437 “Pick a length, or none at all, and a subject if you like. …” (reste inchangé).

### TEN-07 — Heures : horloge de 24 h codée en dur partout, sauf la présentation qui suit le téléphone

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Sur un téléphone réglé en 12 h (cas courant en anglais américain), la présentation propose « Remind me every day at 7:00 AM » avec un sélecteur en 12 h ; le même rappel s'affiche ensuite « 07:00 » dans l'écran Rappels, dont le sélecteur est forcé en 24 h. Tous les autres horaires ignorent aussi le réglage du téléphone : zmanim, widgets, heures du mode, bannière des prières, vol. Aucune décision ne le documente (FEUILLE_DE_ROUTE.md, ZMANIM.md). Le site, lui, est cohérent : `hourCycle: 'h23'` partout.

**Preuve.** OnboardingActivity.kt:116 `DateFormat.is24HourFormat(this)` et :121 `if (DateFormat.is24HourFormat(this)) "HH:mm" else "h:mm a"` ; Store.kt:1629 `String.format(Locale.US, "%02d:%02d", …)` employé par RemindersActivity.kt:140, SettingsActivity.kt:373-374, GateStatus.kt:62 et 73-74 ; sélecteurs forcés à `true` : RemindersActivity.kt:114 et 147, SettingsActivity.kt:602 ; `ofPattern("HH:mm")` : ZmanimVignette.kt:48, HorairePriere.kt:19, VueJour.kt:284, VolAlerte.kt:58. Exécution Java 21 : « 07:00 vs 7:00 AM ».

**Correction proposée.** Une seule fonction d'affichage de l'heure, qui suit le téléphone : `DateFormat.getTimeFormat(context)`, ou `ofPattern(if (DateFormat.is24HourFormat(c)) "HH:mm" else "h:mm a", locale)`. La brancher dans Store.formatMinutes (en lui passant le contexte), ZmanimVignette.HEURE, HorairePriere, VueJour et VolAlerte ; passer `DateFormat.is24HourFormat(this)` aux trois TimePickerDialog. À défaut, écrire le choix du 24 h dans la feuille de route et aligner OnboardingActivity.

### TEN-08 — Dates : ordre français codé en dur à côté de dates localisées, d'où deux ordres dans l'interface anglaise

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Le journal, la vue du jour, l'image de partage et l'écran de vol composent la date avec un motif fixe jour-mois (« Thursday 12 November 2026 », « Thu 12 Nov »). La fiche d'un trophée, les paliers et l'ajout de temps emploient le format localisé (« November 12, 2026 », « Thursday, November 12, 2026 »). Avec l'application en anglais, les deux ordres coexistent, et Android diffère du site, qui passe par Intl (« Tuesday, September 29, 2026 » sur le visuel Play 07).

**Preuve.** Motifs fixes : JournalActivity.kt:80 et PartageJour.kt:43 et VueJour.kt:74 `ofPattern("EEEE d MMMM yyyy", …)` ; VueJour.kt:93-94 `"EEE d MMM"`, `"EEE d MMM, HH:mm"` ; VolActivity.kt:204, 423, 564, 1147 ; VolAlerte.kt:57. Localisés : FicheTrophee.kt:77 et PaliersActivity.kt:193 `ofLocalizedDate(FormatStyle.LONG)` ; AjoutTemps.kt:24 `FormatStyle.FULL`. Exécution Java 21, locale « en » : « Thursday 12 November 2026 » / « November 12, 2026 » / « Thursday, November 12, 2026 ». promo-screenshots/03-journal.png : « Wednesday 30 September 2026 ».

**Correction proposée.** Remplacer chaque motif fixe par le motif de la langue : `DateTimeFormatter.ofPattern(android.text.format.DateFormat.getBestDateTimePattern(locale, "EEEEdMMMMyyyy"), locale)` (squelettes « EEEdMMM » et « EEEdMMMHHmm » pour les formes courtes), ou `ofLocalizedDate(FormatStyle.FULL).withLocale(locale)` là où la date est entière.

### TEN-09 — Calques du français dans 26 libellés : « Day confirmed », « For this hour », « Like the phone », « Streak to restart »…

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Vingt-six chaînes suivent le français mot à mot et sonnent traduites. Plusieurs sont très exposées : « FOR THIS HOUR » et « AROUND THE HITBODEDUT » figurent sur les visuels Play 02, 06 et 09 ; « Mode status » coiffe une carte placée avant celle qui nomme le mode (activity_settings.xml:218 puis :263). Les applications sont « blocked » dans 5 chaînes et « held back » dans 3. La notification de Chabbat s'arrête sur un verbe sans complément.

**Preuve.** values-en/strings.xml:7 « Streak to restart » ; :18 « Confirmed without a timer » ; :21 « Mode status » ; :60 « …switch for the mode to act. » ; :62 « The mode has nothing to hold back. » ; :63 « Day confirmed » ; :64 « Nothing will be held back today. The mode returns tomorrow. » ; :69 « Outside the window » ; :70 « The mode acts between %1$s and %2$s. Outside that, nothing is held back. » ; :113 « …shows nothing once the phone is down. » ; :146 « …and the day confirmed. » ; :180 « …ask to reach it yourself. » ; :288 « Choose a quiet, separate place » ; :298 « Ask yourself inward questions » ; :329 « Read on the site » ; :403 « Around the hitbodedut » ; :474 « Like the phone » ; :587 « Fold away » (ailleurs « Collapse », :253 et :742) ; :599 « For this hour » ; :617 « No fresh location: the last known one is used. » ; :844 « The whole halacha of the day › » ; :960 « Shabbat in 3 hours, get ready to enjoy! » ; :1068 « Add time done away from the phone » ; :1096 « …end of the time for prayer » ; :1178 « The prayer of the moment and when it closes. » (aussi :1015, :1180 ; ailleurs « Current prayer », :1227) ; :1294-1295 « The time of %1$s begins… ».

**Correction proposée.** :7 “Start a new streak” ; :18 “Marked done without a timer” ; :21 “I am with Hashem: status” ; :60 “Turn on the “I am with Hashem” switch to activate the mode.” ; :62 “The mode has nothing to block. Choose at least one app.” ; :63 “Done for today” ; :64 “Nothing more will be blocked today. The mode resumes tomorrow.” ; :69 “Outside mode hours” ; :70 “The mode is active between %1$s and %2$s. Outside those hours, nothing is blocked.” ; :113 “Without them, the reminder is scheduled but never appears, and nothing shows during hitbodedut once you put the phone down.” ; :146 “The time elapsed so far will be recorded and the day will count as done.” ; :180 “Take a teaching you heard today, and ask to live up to it yourself.” ; :288 “Choose a quiet, secluded place” ; :298 “Ask yourself searching questions” ; :329 “Read on the website” ; :403 “For your hitbodedut” ; :474 “Same as phone” ; :587 “Collapse” ; :599 “Right now” ; :617 “Couldn’t get a new location. Using the last known one.” ; :844 “Full halacha of the day ›” ; :960 “Shabbat in 3 hours: get ready to enjoy it!” ; :1068 “Add time spent away from the phone” ; :1096 “Until %1$s · latest Tefillah” ; :1178 “The current prayer and when its time ends.” (et “the current prayer” en :1015, :1180) ; :1294-1295 “The time for %1$s begins below the aircraft.”

### TEN-10 — Table des variantes : une même notion sous plusieurs noms ou plusieurs graphies

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Treize notions changent de nom ou de graphie d'un écran à l'autre. Le lien « Read Birkat HaLevana › » ouvre un texte titré « Blessing of the moon » ; le rappel « time to say Tefilat HaDerech » renvoie à « Traveler’s prayer ». Le réglage s'appelle « Rest day today » mais l'état du mode parle de « a pause ». La halakha du jour porte quatre noms. Les sujets gardent « Parnassa » et « Zivug » (test) mais les questions disent « livelihood » et « a match ». Le propriétaire a demandé « Tehillim » au lieu de « psalms » (19/10) : 10 « psalm(s) » restent.

**Preuve.** Halakha : :788 « Halacha Yomit », :993 « Daily halacha », :840 « Halacha of the day », :789 « Today’s halacha ». Jour chômé : :667 « End of Shabbat or holiday », :723 « Festivals », :1248 « festivals » face à « Yom Tov » (6). Repos : :102 « Rest day today », :65 « Rest day », :66 « a pause », :163 « Not expected today. ». Omer : :718 et :1085 « Counting the Omer », :1298 « Sefirat HaOmer », :1254 « Omer count ». Refoua : :38 « Refuah shelemah », :433 « Refua shelema » (imposé par TraductionTest). Téfila : « Tefillah » (:169, :656, :657) face à « Tefilot » (:420, :441). Décollage : :1192 « Take-off », :1289 et :1291 « takeoff », :1216 « Scheduled departure ». Calcul : « computed » (:1184, :1241, :1264, :1283) face à « calculated » (13). Siddour : « Birkat HaLevana » (8 chaînes) et :1290 « Tefilat HaDerech » face aux titres « Blessing of the moon », « Traveler’s prayer » de siddur_*.json. « Rabbi Natan of Breslov » (:421) face à « Reb Noson of Breslov » (hilloulot.json). Particule : « Alot hashachar », « Plag hamincha », « Mashiv haruach » face à « Birkat HaLevana », « Chol HaMoed ». « Barech alenu » (:683), « Barchenu » (:684) face à « Aneinu », « Avinu Malkeinu ». Article : « the hitbodedut » 14 fois, dont :244 « Play during the hitbodedut » face à :268 « No music during hitbodedut. ». Casse : :285 « Tips for Hitbodedut », seul titre en capitales.

**Correction proposée.** Retenir une forme par notion : “Daily halacha” (:788, :840, :841, :843, :844) ; “End of Shabbat or Yom Tov” (:667), “Yom Tov” (:723), “Shabbat, Yom Tov and Omer during the flight” (:1248) ; “Shabbat, Yom Tov or a rest day: the mode is silent and the streak stays intact.” (:66), “Rest day today.” (:163) ; “Counting the Omer” (:1298), “Counting the Omer, day %1$s, from nightfall (8.5°): %2$s” (:1254) ; “Refua shelema (לרפואה שלמה)” (:38) ; “Tefillot” (:420, :441) ; “Takeoff %1$s” (:1192) ; “calculated” à la place de “computed” ; titres du siddour “Birkat HaLevana”, “Tefilat HaDerech” ; “Rabbi Natan of Breslov” ; “Alot HaShachar”, “Plag HaMincha”, “Mashiv HaRuach” ; “Barech Aleinu”, “Barcheinu” ; “Tips for hitbodedut” ; “hitbodedut” sans article quand il désigne la pratique (“Play during hitbodedut”, “Nothing on screen during hitbodedut…”). :1143 “What do you need: parnassa, health, peace at home, a shidduch?”

### TEN-11 — Saisie d'un vol : l'exemple anglais montre « 12/11 » et la lecture est toujours jour/mois

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** L'aide anglaise propose « 12/11 at 9:40 ». Android et le site lisent toute date chiffrée comme jour/mois, quelle que soit la langue. Un utilisateur américain qui écrit 11/12 pour le 12 novembre obtient le 11 décembre, et 3/4 devient le 3 avril. La ligne « Understood: … » permet de s'en apercevoir, mais l'exemple lui-même enseigne une notation ambiguë, alors que « Nov 12 » est compris. S'y ajoute la graphie britannique « recognised » dans une interface en orthographe américaine.

**Preuve.** values-en/strings.xml:1372 « Nothing recognised. Try for example: “LY 382 Paris Tel Aviv 12/11 at 9:40”. » ; SaisieVol.kt:186-188 `([0-9]{1,2})[/.]([0-9]{1,2})…` puis `val j = groupValues[1]`, `val mo = groupValues[2]`. Exécution du portage web (web/src/js/vol.js, `lirePhrase`, aujourd'hui = 2026-11-12) : « …11/12 at 9:40 » → date 2026-12-11 ; « …on 3/4 at 9:40 pm » → 2027-04-03 ; « …Nov 12 at 9:40 » → 2026-11-12.

**Correction proposée.** :1372 “Nothing recognized. Try for example: “LY 382 Paris Tel Aviv Nov 12 at 9:40”.” Laisser la lecture jour/mois (billets européens et israéliens), mais afficher le mois en lettres dans « Understood: … » si ce n'est pas déjà le cas, pour que l'inversion saute aux yeux.

### TEN-12 — « grade » pour le rang des trophées : calque peu idiomatique dans 7 chaînes

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** « Bronze grade », « New grade: Silver », « Share my grade » : en anglais « grade » évoque d'abord une note scolaire ou une qualité de matériau. Le palier d'un jeu de trophées se dit « rank » ou « tier » (« level » est déjà pris par les niveaux de chaque trophée). Le texte partagé hors de l'application porte ce mot. « In Bronze: it was your trophy no. 3. » calque en plus « En %1$s ».

**Preuve.** values-en/strings.xml:851 « %1$s grade » ; :854 « %1$s grade reached » ; :860 « New grade: %1$s » ; :861 « Next grade: %1$s, at trophy %2$d. » ; :1053 « In %1$s: it was your trophy no. %2$d. » ; :1058 « Share my grade » ; :1059 « %1$s grade on MyHitbodedut: %2$d trophies, day after day. » (PaliersActivity.kt:77, 339, 353, 372 ; MainActivity.kt:579).

**Correction proposée.** :851 “%1$s rank” ; :854 “%1$s rank reached” ; :860 “New rank: %1$s” ; :861 “Next rank: %1$s, at trophy %2$d.” ; :1053 “%1$s rank: this was trophy no. %2$d.” ; :1058 “Share my rank” ; :1059 “%1$s rank on MyHitbodedut: %2$d trophies, day after day.”

### TEN-13 — Libellés courts tronqués ou ambigus : « next 7 », « 3 times set. », « 1 h 05 min »

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Quatre libellés perdent un mot ou se lisent de travers. La face « série » de l'anneau dit « days in a row · next 7 » : le mot « palier » a disparu. « 3 times set. » se lit « réglé trois fois ». La durée garde le zéro de la notation horaire française (« 1 h 05 min ») alors que « min » a été ajouté. « today, of 20 min » sous le chiffre du jour est bancal.

**Preuve.** values-en/strings.xml:553-554 « day in a row · next %2$d » / « days in a row · next %2$d » (fr : « prochain palier %2$d » ; MainActivity.kt:524) ; :376-377 « %1$d time set. » / « %1$d times set. » ; :536 « %1$d h %2$02d min » (Store.kt:1639 ; exécution Java : « 1 h 05 min ») ; :546 « today, of %1$s ».

**Correction proposée.** :553-554 “day in a row · next milestone: %2$d” / “days in a row · next milestone: %2$d” ; :376-377 “%1$d reminder time set.” / “%1$d reminder times set.” ; :536 “%1$d h %2$d min” ; :546 “today, out of %1$s”.

### TEN-14 — Anglais américain et britannique mêlés

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** L'interface suit l'orthographe américaine (color, favorites, toward, criticizing) mais garde des formes britanniques : 2 dans les chaînes, 2 dans les invites de la hitbodedut guidée, et une date jour-mois dans la politique de confidentialité.

**Preuve.** Américain : values-en/strings.xml:443 et :472 « colors », :477 et :483 « color », :1030, :1031 et :1033 « favorites », :1304, :1305 et :1319 « toward », :303 « criticizing ». Britannique : :293 « turn towards Hashem », :1372 « Nothing recognised » ; guide_sujets.json « ask to fulfil it », « the road already travelled » ; confidentialite.html « Last updated: 2 November 2026 ».

**Correction proposée.** Trancher pour l'américain, cohérent avec la fiche en-US : :293 “to turn toward Hashem” ; :1372 “Nothing recognized.” ; guide_sujets.json “ask to fulfill it”, “the road already traveled” ; confidentialite.html “Last updated: November 2, 2026”.

### TEN-15 — Habitudes de ponctuation et de nombre françaises : deux-points entre deux propositions (40 chaînes), « No » + singulier (6)

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** La typographie est propre, mais la syntaxe garde deux tics du français. Le deux-points relie deux propositions dans 40 chaînes, là où l'anglais met un point, un tiret ou « so ». « Aucun » + singulier est rendu par « No » + singulier dans 6 chaînes, alors que l'anglais met le pluriel pour un dénombrable.

**Preuve.** Deux-points, lignes de values-en/strings.xml : 31, 46, 66, 101, 103, 124, 152, 289, 305, 307, 371, 455, 615, 617, 743, 865, 888, 1126, 1184, 1199, 1203, 1204, 1206, 1207, 1224, 1225, 1242, 1245, 1246, 1288, 1289, 1291, 1299, 1305, 1316, 1317, 1364, 1375, 1376, 1385. Exemples : :615 « Location unavailable: choose a city. » ; :888 « Text copied: paste it wherever you like. » ; :1385 « This text has no translation yet: it stays in Hebrew. ». Singulier : :61 « No app selected » ; :124 « No app selected: nothing will be blocked. » ; :269 « No track in the library. » ; :865 « No trophy yet: … » ; :1035 « No bookmark in this text. » ; :1215 « No airport found. ».

**Correction proposée.** Modèles : :615 “Location unavailable. Choose a city.” ; :888 “Text copied. Paste it wherever you like.” ; :1385 “This text has no translation yet, so it stays in Hebrew.” ; :371 “Notifications are blocked, so the reminder will not appear. Tap here to allow them.” Pluriels : :61 “No apps selected” ; :124 “No apps selected, so nothing will be blocked.” ; :269 “No tracks in the library.” ; :865 “No trophies yet. The first comes with your first hitbodedut.” ; :1035 “No bookmarks in this text. Long-press a paragraph to add one; long-press again to remove it.” ; :1215 “No airports found.”
