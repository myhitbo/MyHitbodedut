# TSIDDUR — Contenus — siddour, Tehilim, Tikkoun haKlali et règles d’insertion

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

25 constats — confirmés : 8 · non contre-expertisés (mineurs et cosmétiques) : 17.

> Contre-expertise incomplète pour cette dimension.

## Ce qui a été examiné

Lu en entier : Siddur.kt, SiddurJour.kt, SiddurLectureActivity.kt, CalendrierJuif.kt, Tehilim.kt, Tikkun.kt, Tefilot.kt, web/src/js/siddur-jour.js, la fonction jour() de calendrier-juif.js et le rendu du siddour dans app.js (lignes 1376-1500), ZMANIM.md lignes 1-240, FEUILLE_DE_ROUTE.md lignes 720-1163, PoliceHebraique.kt. Lu en partie : SiddurActivity.kt (liste), tools/siddur_annotations.py (environ 300 lignes sur 931 : sections entières, consignes courtes, Al hanissim, Avinou malkénou, minyan, carte « seul »), intitulés de SiddurJourTest et SiddurTest, test des emprunts.

Par script, sur la totalité : les trois siddourim (38 textes chacun, tous les blocs), les 1 572 annotations, tehilim.json (2 527 versets, deux traductions), tikkun_haklali.json, inventaire des caractères et des graphies du Nom, couverture des polices (fontTools), comparaison md5 dépôt / site déployé.

Par exécution : un portage JavaScript de SiddurJour.lignes branché sur les vrais modules web (calendrier-juif.js, siddur-jour.js, kosher-zmanim) et sur les fichiers res/raw, lancé sur environ 40 dates (ordinaire été et hiver, vendredi, Roch 'Hodech, 'Hanouka, 10 Tévet, jeûne d'Esther, Pourim et Jérusalem, 'hol hamoèd, 9 Av, dix jours, veille de Kippour, samedis soir) pour les trois noussa'h ; contrôle des 19 sceaux de l'Amida dans le texte visible. Scripts dans OUT/tsiddur (sim.mjs, show.mjs, hatimot.mjs, grid.mjs, groupes.py, dump2.py, noms.py).

Échantillonné : les incipits de tous les groupes annotés de Cha'harit, Min'ha, Arvit, Birkat haMazon, Méèn chaloch, Hallel, Moussaf et Havdala dans les trois noussa'h ; les consignes ; Tikoun 'hatsot, Chema du coucher, Méguila, Séfirat haOmer ; quatre paragraphes de la prière de Rabbi Natan.

Non examiné : le corps des prières mot à mot (environ 2,2 millions de caractères) et leur nikoud ligne à ligne ; les 21 bénédictions des occasions au-delà de leur structure ; le rendu réel sur téléphone ou navigateur (polices, signes) ; l'exécution des tests Gradle et web ; TehilimTest et TikkunTest ; tefila.js ligne à ligne (couvert par les vecteurs du projet). L'application Nokia n'a pas de siddour. Aucune recherche web : les points de halakha (Lamnatséa'h à 'Hol hamoèd, Vayehi noam, Baroukh Hachem léolam en Israël, Avinou malkénou à Min'ha) reposent sur l'usage des siddourim courants et sont à confirmer par le propriétaire avant correction ; les constats de texte et d'affichage, eux, sont vérifiés par exécution.

## Ce qui tient

- Tehilim : 150 psaumes, 2 527 versets ; le nombre de versets de chaque psaume est identique à la table massorétique (contrôle par script, 0 écart) ; chaque verset finit par son sof pasouq ; les traductions française (Rabbinat 1899) et anglaise (JPS 1917) sont alignées verset à verset, sans verset vide ; les découpages par jour du mois (119 coupé à 96/97, mois de 29 jours) et de la semaine sont ceux de l'usage.
- Tikoun haKlali : les dix psaumes 16, 32, 41, 42, 59, 77, 90, 105, 137, 150, complets et dans l'ordre (164 versets), strictement identiques à tehilim.json ; ouverture et clôture conformes ; les réserves (un seul témoin pour la liturgie) sont écrites dans le fichier.
- Annotations solides sur le plan technique : 1 572 annotations, toutes les empreintes désignent encore leur bloc et tous les passages « retire » se retrouvent mot pour mot dans leur bloc (0 écart) ; le texte source n'est jamais modifié ; les données et les modules de règles du site déployé sont identiques à ceux du dépôt et d'Android (md5).
- Calendrier des ajouts : cas fins justes à l'exécution — Pourim à Jérusalem (14 sans Al hanissim ni Ta'hanoun, 15 avec), Arvit rattaché au jour hébreu suivant (omer, Ya'alé véyavo, Ata 'honantanou des sorties de fête), Tal oumatar, veille de Roch Hachana sans Ta'hanoun, Morid hatal ashkénaze hors d'Israël, Hallel complet ou partiel, Anénou de l'officiant et du particulier selon le noussa'h, bénédiction des pluies Edot remplacée en entier.
- Transparence envers le lecteur : une note en tête de chaque office donne la date hébraïque et la région retenues et rappelle que les ajouts sont indicatifs ; un ajout hors du jour est replié, jamais supprimé, et se rouvre d'un geste.
- Chéva bérakhot : l'ordre signalé le 28/10 est bien corrigé dans les trois noussa'h ; les emprunts de noussa'h sont marqués dans les données et verrouillés par un test (SiddurTest, « les emprunts sont marques »).

## Constats

### TSIDDUR-01 — Min'ha Edot : le sceau de Na'hem « מנחם ציון בבנין ירושלים » s'affiche tous les jours, juste avant « בונה ירושלים »

**Gravité** : bloquant · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** Dans l'Amida de Min'ha du noussa'h Edot (le noussa'h par défaut), seul le paragraphe de Na'hem (bloc 25) est annoté « ticha_beav ». Le bloc 26, qui porte sa conclusion, n'a aucune annotation : il reste affiché en texte normal 365 jours par an. Le lecteur lit donc « תשכון… » → [Na'hem replié] → « ברוך אתה ה׳ מנחם ציון בבנין ירושלים » → « ברוך אתה ה׳ בונה ירושלים » : deux sceaux avec le Nom pour la même bénédiction, dont un qui ne se dit que le 9 Av. Le 9 Av, les deux sceaux restent visibles aussi. Android et web lisent les mêmes fichiers (md5 identiques, site déployé compris).

**Preuve.** android/app/src/main/res/raw/siddur_edot.json, texte minha, section 1 (עמידה), bloc 26 : « &lt;small>בָּרוּךְ אַתָּה יְהֹוָה, מְנַחֵם צִיּוֹן בְּבִנְיַן יְרוּשָׁלַיִם: &lt;br>&lt;small>וממשיכים "את צמח" וכו׳&lt;/small>&lt;/small> » ; bloc 27 : « בָּרוּךְ אַתָּה יֻהֻוֻהֻ, בּוֹנֵה יְרוּשָׁלָיִם: ». android/app/src/main/res/raw/siddur_annotations.json:1630-1638 : unique annotation ticha_beav de Min'ha Edot, « "b": 25, "empreinte": "בתשעה באב אומרים: נחם יהוה אלהינו את אבל" ». Exécution (portage de SiddurJour.lignes branché sur les modules web réels, OUT/tsiddur/show.mjs edot minha 2026-11-13) : « [1.24] NORMAL תשכון… / &lt;replie> ajout_ticha_beav / [1.26] NORMAL ברוך אתה יהוה, מנחם ציון בבנין ירושלים / [1.27] NORMAL ברוך אתה יהוה, בונה ירושלים ». Contrôle des 19 sceaux (hatimot.mjs) : « edot minha : yerushalayim×2 » sur les 10 jours-types testés.

**Correction proposée (revue par le contre-expert).** Dans tools/siddur_annotations.py, règle « בתשעה באב אומרים: נחם » (l. 500-502) : prendre aussi le bloc suivant quand il commence par « ברוך אתה … מנחם ציון » (même groupe ticha_beav). Cela suffit à corriger le défaut quotidien. Pour replier « בונה ירושלים » le 9 Av, « !ticha_beav » ne suffit pas en l'état : SiddurJour.libelle donnerait « ajout_ticha_beav » (« Na’hem »), d'où « Aujourd'hui · Na’hem » en surbrillance au-dessus de « בונה ירושלים » toute l'année, et « Na’hem — Pas aujourd’hui » le 9 Av. Il faut un libellé propre en trois langues (« Sauf le 9 Av » / « Except on Tisha B’Av » / « חוץ מתשעה באב »), ou mieux, un moteur (Kotlin et web) qui affiche un groupe nié vrai en NORMAL, sans étiquette. Rattacher de même « העונה לעמו ישראל בעת צרה » au groupe Anénou de l'officiant. Régénérer res/raw/siddur_annotations.json et ajouter un test sur les sceaux visibles.

**Note du contre-expert.** J'ai vérifié dans siddur_edot.json : Na'hem (bloc 25) finit sur le verset, sans sceau. Le bloc 26 « ברוך… מנחם ציון בבנין ירושלים / וממשיכים את צמח » n'a aucune annotation ; seul le bloc 25 porte ticha_beav. Le portage relancé (fidèle à SiddurJour.lignes) montre chaque jour [1.26] puis [1.27] en NORMAL, et les md5 sont identiques sur le site déployé. Même défaut, non relevé : le sceau d'Anénou de l'officiant, « ברוך… העונה לעמו ישראל בעת צרה » (Edot Cha'harit [9.15], Min'ha [1.14]), reste affiché tous les jours hors du groupe « jeune ».

### TSIDDUR-02 — Moussaf de Roch 'Hodech (Edot et Ashkenaz) : la fin de Modim et son sceau « הטוב שמך ולך נאה להודות » sont repliés sous « 'Hanouka »

**Gravité** : bloquant · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** La règle « consigne courte » de l'outil d'annotation prend tous les blocs qui suivent « בחנוכה אומרים » jusqu'à la consigne suivante. Dans le Moussaf, elle avale la suite de la bénédiction : « ועל כולם יתברך… ברוך אתה ה׳ הטוב שמך ולך נאה להודות ». Tout Roch 'Hodech hors 'Hanouka (11 mois sur 12), le lecteur passe de « מעולם קוינו לך » à « שים שלום » ; la conclusion de la bénédiction est cachée derrière un bandeau « 'Hanouka — Pas aujourd'hui · toucher pour lire ». Le Moussaf Sfard n'est pas touché (blocs 23-24 non annotés).

**Preuve.** siddur_annotations.json:3483-3491 (edot, moussaf_rosh_hodech) : « "si": "hanouka", "b": 19, "empreinte": "ועל כלם יתברך, ויתרומם, ויתנשא, תמיד, שמ" » ; le bloc 19 de siddur_edot.json finit par « בָּרוּךְ אַתָּה יֻהֻוֻהֻ, הַטּוֹב שִׁמְךָ וּלְךָ נָאֶה לְהוֹדוֹת: ». siddur_annotations.json:14077-14103 (ashkenaz) : blocs 11, 12, 13 de la section 5 en « hanouka », dont « "empreinte": "ברוך אתה יהוה. הטוב שמך ולך נאה להודות:" ». Cause : tools/siddur_annotations.py:452-465, « while j < n and not cons[j] and (…): prend(j, c, lib) ». Exécution au 2026-11-11 (1er Kislev) : Edot « [0.14] מודים… / &lt;replie> ajout_minyan / &lt;replie> fete_hanouka n=4 / &lt;replie> ajout_minyan n=13 / [0.33] שים שלום » ; Ashkenaz « [5.2] הטוב כי לא כלו… / &lt;replie> fete_hanouka n=9 / &lt;titre> ברכת כהנים ». hatimot.mjs : « edot moussaf_rosh_hodech : hodaa×0 », « ashkenaz moussaf_rosh_hodech : hodaa×0 ».

**Correction proposée (revue par le contre-expert).** Dans la boucle des consignes courtes (l. 461), arrêter la prise au premier bloc qui commence par « ועל כלם / ועל כולם ». Ne pas recopier la règle Al hanissim des l. 392-404 : elle couperait aussi « ואתה ברחמיך » et « ואחר כן באו » (Ashkenaz 5.9-5.10), qui appartiennent au texte de 'Hanouka. Résultat attendu : Edot, bloc 19 hors du groupe ; Ashkenaz, blocs 11-13 hors du groupe, 5-10 dedans. Régénérer et tester.

**Note du contre-expert.** J'ai vérifié les annotations citées (l. 3483-3491 ; 14077-14103) : le bloc 0.19 d'Edot, de « ועל כלם » à « הטוב שמך ולך נאה להודות », et les blocs 5.11-5.13 d'Ashkenaz sont dans le groupe hanouka, via la règle des consignes courtes (l. 452-465). Le portage au 1er Kislev passe de « מעולם קוינו לך » à « שים שלום » dans les deux noussa'h. En Sfard, « ועל כלם » n'est pas annoté. Une Amida privée du sceau de Hodaa est à reprendre : bloquant justifié.

### TSIDDUR-03 — Fin d'office repliée avec le Ta'hanoun : Alénou absent de Min'ha Sfard, Kaddich et psaumes de Min'ha Edot, « שומר ישראל » de Cha'harit Sfard

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** Trois sections reçoivent une condition d'un bloc, d'après leur seul titre, alors qu'elles contiennent la suite de l'office. (a) Sfard, Min'ha, section « תחנון » (37 blocs) : les blocs 17-36 — Kaddich chalem, עלינו לשבח, אל תירא, Kaddich, לדוד ה׳ אורי — se replient avec le Ta'hanoun : chaque vendredi, Roch 'Hodech, 'Hanouka, tout Nissan, Min'ha s'arrête après l'Amida, sans Alénou ; de plus la section « אבינו מלכנו » vient après Alénou. (b) Edot, Min'ha, section « וידוי » (23 blocs) : les blocs 9-22 — Kaddich titkabal, למנצח בנגינות (Ps 67), ה׳ מלך (Ps 93), Kaddich — se replient les jours sans Ta'hanoun, donc tous les vendredis, où la consigne demande justement le Ps 93. (c) Sfard, Cha'harit, section « לשני וחמישי » (31 blocs) : « שומר ישראל », « ואנחנו לא נדע » et le demi-Kaddich (blocs 20-29) sont cachés sous « Lundi et jeudi — Pas aujourd'hui » les dimanche, mardi, mercredi et vendredi, alors que la consigne du bloc 0 dit le contraire.

**Preuve.** siddur_annotations.json:6442-6447 (sefard, minha) « "sorte": "section", "s": 2, "si": "tahanoun_minha", "empreinte": "תחנון" » ; :2240-2245 (edot, minha) « "s": 2, "si": "tahanoun_minha", "empreinte": "וידוי" » ; :4864-4869 (sefard, chaharit) « "s": 11, "si": "lundi_jeudi" ». tools/siddur_annotations.py:147-150 : « if titre in ("תחנון", "וידוי") and office: cond = "tahanoun_" + office / elif titre == "לשני וחמישי": cond = "lundi_jeudi" ». Consignes dans les sections repliées : siddur_edot.json minha [2.16] « בערב שבת אומרים מזמור ''יהוה מלך'' במקום ''למנצח'' » ; siddur_sefard.json chaharit [11.0] « בשני וחמישי יאמר והוא רחום. בשאר ימים שאומרים בהם תחנון יאמר שומר ישראל. ». Exécution vendredi 2026-11-13 : Sfard Min'ha finit par « &lt;titre> תחנון / &lt;replie> ajout_tahanoun / &lt;titre> אבינו מלכנו / &lt;replie> ajout_avinou_malkenou » (aucun עלינו) ; Edot Min'ha : « [1.105] יהי שם… / &lt;titre> וידוי / &lt;replie> ajout_tahanoun / &lt;titre> עלינו ». Mardi 2026-11-17, Sfard Cha'harit : « [9.13] יהוה אל באפך… / &lt;replie> ajout_avinou_malkenou / &lt;titre> לשני וחמישי / &lt;replie> ajout_lundi_jeudi / &lt;titre> קריאת התורה ».

**Correction proposée (revue par le contre-expert).** Remplacer les trois annotations de section par des annotations de blocs. Sfard Min'ha : blocs 0-16 en tahanoun_minha ; les règles existantes (minyan, ledavid, beit_avel) traiteront alors le Kaddich, « לדוד ה׳ אורי » et « למנצח לבני קרח » ; עלינו et אל תירא restent ouverts. Placer Avinou malkénou avant le Kaddich chalem, au même endroit qu'à Cha'harit dans ce siddour (après « ה׳ אל באפך », avant « שומר ישראל »), en vérifiant dans la source. Edot Min'ha : blocs 0-8 en tahanoun_minha ; [2.16-2.17] (Ps 93) liés au vendredi ; [2.18-2.19] en jeune. Sfard Cha'harit : [11.1-11.19] en lundi_jeudi, [11.20-11.24] en tahanoun_chaharit, demi-Kaddich en minyan.

**Note du contre-expert.** Les trois annotations de section existent (l. 6442, 2240, 4864) et viennent de la règle sur le titre (l. 146-149). Sfard Min'ha [2.17-2.31] contient Kaddich chalem, עלינו, אל תירא et Kaddich ; Edot Min'ha [2.9-2.22] contient Kaddich titkabal, Ps 67, Ps 93 et Kaddich ; Sfard Cha'harit [11.20-11.29] contient שומר ישראל, ואנחנו לא נדע et le demi-Kaddich. Les trois essais (vendredi 13/11, mardi 17/11) se reproduisent. Seul point discutable : la place proposée pour Avinou malkénou. Ce même siddour le met, à Cha'harit, après la chute sur la face et avant « שומר ישראל », pas avant le Ta'hanoun.

### TSIDDUR-04 — Moussaf de Roch 'Hodech ashkénaze : « ברוך אתה ה׳ האל הקדוש » affiché deux fois à qui prie seul

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** La Kedoucha de l'officiant est repliée (« Avec minyan »), mais son sceau final (bloc 8, après « לדור ודור ») n'est pas dans le groupe : il reste affiché, suivi de « אתה קדוש » et du sceau du particulier (bloc 10). Le lecteur dit deux fois la conclusion de la troisième bénédiction, chaque Roch 'Hodech.

**Preuve.** android/app/src/main/res/raw/siddur_ashkenaz.json, moussaf_rosh_hodech, section 2 (קדושה) : bloc 7 « לש״ץ - לְדור וָדור נַגִּיד גָּדְלֶךָ… », bloc 8 « בָּרוּךְ אַתָּה יְהֹוָה הָאֵל &lt;small>בעשי״ת הַמֶּלֶךְ&lt;/small> הַקָּדושׁ: », bloc 10 « בָּרוּךְ אַתָּה יְהֹוָה הָאֵל הַקָּדושׁ: ». siddur_annotations.json:13915-13986 : blocs 0 à 7 en « minyan » ; :13987-13995 : le bloc 8 n'a qu'un « indice ». Exécution au 2026-11-11 : « &lt;replie> ajout_minyan n=8 / [2.8] NORMAL ברוך אתה יהוה האל הקדוש: / [2.9] אתה קדוש ושמך קדוש… / [2.10] NORMAL ברוך אתה יהוה האל הקדוש: ». hatimot.mjs : « ashkenaz moussaf_rosh_hodech : kedusha×2 ».

**Correction proposée (revue par le contre-expert).** Dans la passe minyan (l. 658-664), après un bloc « לדור ודור » de la Kedoucha, prendre aussi le bloc suivant s'il commence par « ברוך אתה יהוה האל », à condition que le bloc d'après commence par « אתה קדוש » (le sceau du particulier suit). Sinon, on replierait le seul sceau du texte. Effet ici : le bloc 8 rejoint le groupe minyan g 2.

**Note du contre-expert.** Dans siddur_ashkenaz.json (moussaf_rosh_hodech, section 2), les blocs 0-7 sont en minyan. Le bloc 8 « ברוך… האל (בעשי״ת המלך) הקדוש » n'a qu'un indice, puis viennent 9 « אתה קדוש » et 10 « ברוך… האל הקדוש ». Le portage au 1er Kislev affiche [2.8], [2.9] et [2.10] : deux sceaux pour qui prie seul (« minyan » n'est jamais vrai, l. 617). Cha'harit et Min'ha ne sont pas touchés : leur sceau d'officiant est dans le bloc « לדור ודור ».

### TSIDDUR-05 — Hallel Edot : la bénédiction « לגמור את ההלל » reste dépliée les jours de Hallel partiel, que l'application annonce « sans bénédiction »

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** À Roch 'Hodech, Cha'harit Edot affiche « Aujourd'hui · Hallel partiel, sans bénédiction » et ouvre le Hallel. Dans ce texte, la bénédiction finale « יהללוך » est bien repliée (« Hallel complet — Pas aujourd'hui »), mais les quatre premiers blocs — l'appel « ברשות מורי ורבותי » et la bénédiction d'ouverture — restent en texte normal. La règle écrite dans ZMANIM.md et dans le code n'est donc appliquée qu'à moitié, et le lecteur est conduit à dire une bénédiction que l'application elle-même dit ne pas se dire.

**Preuve.** siddur_edot.json, hallel, bloc 0 (consigne) « בימים שגומרים את ההלל אומר החזן: », bloc 3 « &lt;b>בָּרוּךְ&lt;/b> אַתָּה יְהֹוָה, אֱלֹהֵינוּ מֶלֶךְ הָעוֹלָם, אֲשֶׁר קִדְּשָׁנוּ בְּמִצְוֹתָיו, וְצִוָּנוּ לִגְמוֹר אֶת הַהַלֵּל: ». siddur_annotations.json:3355-3408 : les seules annotations du Hallel Edot portent sur les blocs 6, 7, 9, 10, 22, 23 (hallel_complet). android/app/src/main/java/com/myhitbodedut/SiddurJour.kt:256 « nusah == "edot" -> "ajout_hallel_partiel_sans_berakha" » ; ZMANIM.md:83 « sans bénédiction, même en communauté ». Exécution au 2026-11-11 : « 1 [0.0] NORMAL C / 2 [0.1] NORMAL ברשות מורי ורבותי / 4 [0.3] NORMAL ברוך אתה יהוה… וצונו לגמור את ההלל ».

**Correction proposée.** Annoter les blocs 0 à 3 du Hallel Edot en hallel_complet (un groupe, comme « יהללוך »).

**Note du contre-expert.** Le Hallel Edot a [0.0] « בימים שגומרים את ההלל אומר החזן », [0.1] « ברשות », [0.2] (consigne) et [0.3] la bénédiction « לגמור את ההלל », tous sans annotation. La regex hallel_complet ne couvre que la forme négative « בימים שאין גומרים ». Au 1er Kislev, le portage montre ces quatre blocs en NORMAL, alors que Cha'harit annonce « Hallel partiel, sans bénédiction » (SiddurJour.kt:256, ZMANIM.md:83). La consigne hébraïque atténue le risque sans lever la contradiction.

### TSIDDUR-06 — Dix jours de techouva et 9 Av : le sceau ordinaire reste affiché normalement à côté du sceau du jour

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** Pour les variantes qui s'excluent, seule la variante du jour est annotée. Pendant les dix jours, en Sfard et Ashkenaz (Cha'harit, Min'ha, Arvit), « ברוך אתה ה׳ האל הקדוש » et « מלך אוהב צדקה ומשפט » s'affichent en texte normal, puis vient, surligné, « המלך הקדוש » / « המלך המשפט » : deux sceaux à la suite, alors que dire « האל הקדוש » ces jours-là oblige à reprendre l'Amida (la consigne du siddour le rappelle juste dessous). Même défaut à Min'ha du 9 Av : Na'hem, qui finit par « מנחם ציון ובונה ירושלים », est suivi de « ברוך אתה ה׳ בונה ירושלים » en texte normal. Pour l'été et l'hiver, au contraire, la formule hors saison est bien repliée.

**Preuve.** siddur_ashkenaz.json chaharit [3.18] « בָּרוּךְ אַתָּה יְהֹוָה הָאֵל הַקָּדוֹשׁ: » (sans annotation) puis [3.19] « &lt;small>בעשי״ת מסיים:&lt;/small> בָּרוּךְ אַתָּה יְהֹוָה הַמֶּֽלֶךְ הַקָּדוֹשׁ: » (asseret_yemei_techouva). Exécution au 2027-10-05 (4 Tichri), Ashkenaz Arvit : « [3.18] NORMAL ברוך אתה יהוה האל הקדוש: / &lt;etiquette> ajout_asseret_yemei_techouva / [3.19] DU_JOUR … המלך הקדוש », « [3.35] NORMAL … מלך אהב צדקה ומשפט: / [3.36] DU_JOUR … המלך המשפט ». Au 2027-08-12 (9 Av), Ashkenaz Min'ha : « [1.61] DU_JOUR נחם… / [1.62] NORMAL ברוך אתה יהוה בונה ירושלים: ». hatimot.mjs : « sefard chaharit/minha/arvit : kedusha×2, mishpat×2 ← ayt », « ashkenaz … kedusha×2 ← ayt », « sefard minha, ashkenaz minha : yerushalayim×2 ← ticha_beav ».

**Correction proposée (revue par le contre-expert).** La condition niée est lue par le moteur (SiddurJour.vrai), mais SiddurJour.libelle/libelleJour (Kotlin et web) la nommeraient d'après la clé positive. On verrait alors toute l'année « Aujourd'hui · Dix jours de techouva » (ou « · Na’hem ») en surbrillance au-dessus du sceau ordinaire, et « Dix jours de techouva — Pas aujourd’hui » pendant les dix jours. Il faut donc d'abord que le moteur affiche un groupe nié vrai en NORMAL, sans étiquette, et le replie quand il est faux sous un libellé propre (nouvelles chaînes, p. ex. « Remplacé aujourd’hui » / « Replaced today » / « מוחלף היום »). Ensuite, annoter « !asseret_yemei_techouva » sur « האל הקדוש » et « מלך אוהב צדקה ומשפט », et « !ticha_beav » sur « בונה ירושלים » de Min'ha (Sfard, Ashkenaz). Rattacher enfin « (את צמח וגו׳) » [Sfard 1.74] au groupe ticha_beav.

**Note du contre-expert.** Ashkenaz Cha'harit et Arvit [3.18] « האל הקדוש » ([3.35] « מלך אהב צדקה ומשפט » en Arvit), Sfard [8.35] et [1.62] : tous sans annotation, suivis de la variante annotée ; à Min'ha du 9 Av, Ashkenaz [1.62] et Sfard [1.75] « בונה ירושלים » suivent Na'hem, qui porte déjà son sceau. Je reproduis tout au 5 Tichri et au 9 Av. En plus, en Sfard Min'ha, le renvoi « (את צמח וגו׳) » [1.74], qui appartient à Na'hem, reste affiché tous les jours juste avant « בונה ירושלים ».

### TSIDDUR-07 — Cha'harit Edot : les supplications du lundi et du jeudi sont surlignées « Aujourd'hui · Ta'hanoun » tous les jours de Ta'hanoun

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** La section « וידוי » d'Edot est annotée d'un seul bloc (tahanoun_chaharit). Elle contient, après la consigne « בימי שני וחמישי מוסיפים: », vingt blocs longs (אל מלך, אנשי אמונה, תמהנו מרעות, והוא רחום, environ 11 000 caractères) qui ne se disent que lundi et jeudi. Dimanche, mardi, mercredi et vendredi, ils sont affichés et surlignés comme ajout du jour. La condition lundi_jeudi existe et sert en Sfard et en Ashkenaz, mais aucune annotation Edot ne l'emploie.

**Preuve.** siddur_annotations.json:896-901 (edot, chaharit) « "sorte": "section", "s": 10, "si": "tahanoun_chaharit", "empreinte": "וידוי" » ; aucune entrée « lundi_jeudi » dans le bloc « edot » du fichier. siddur_edot.json chaharit [10.12] : consigne « בימי שני וחמישי מוסיפים: ». Exécution mardi 2026-11-17 : « &lt;etiquette> ajout_tahanoun / … / [10.12] DU_JOUR C: בימי שני וחמישי מוסיפים: / [10.15] DU_JOUR אנשי אמונה אבדו… / [10.25] DU_JOUR והוא רחום… ».

**Correction proposée (revue par le contre-expert).** Remplacer l'annotation de section par des groupes : blocs 0-8 en tahanoun_chaharit ; [10.9] en jeune ; Kaddich [10.10-10.11] et [10.32] en minyan ; blocs 12-31 en lundi_jeudi, dans leur propre groupe (racine lundi_jeudi, comme « והוא רחום » ashkénaze) pour qu'ils se replient les autres jours de Ta'hanoun.

**Note du contre-expert.** La section 10 « וידוי » d'Edot Cha'harit n'a qu'une annotation de section (l. 896-901), et aucune annotation Edot n'emploie lundi_jeudi. Les blocs 10.12-10.31, de la consigne « בימי שני וחמישי מוסיפים » à « הפותח יד », sortent en DU_JOUR le mardi 17/11. Ils font environ 10 300 caractères avec les voyelles (5 900 sans), un peu moins que les « 11 000 » annoncés. La recommandation ne replierait rien : un bloc lundi_jeudi rangé sous la racine tahanoun_chaharit s'affiche estompé (HORS) mais visible, pas replié.

### TSIDDUR-08 — « Aujourd'hui · Lamnatséa'h » à 'Hol hamoèd (Sfard, Ashkenaz)

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** La condition lamnatseah, écrite à la main d'après la liste du siddour Sfard, oublie 'Hol hamoèd (et Hochaana Rabba) : seuls Chabbat et Yom tov sont exclus par isAssurBemelacha. Les jours ouvrables de Pessa'h et de Souccot, le psaume 20 est mis en évidence comme ajout du jour en Sfard (avec « בית יעקב ») et en Ashkenaz, sur la même page que Ya'alé véyavo et le Hallel. Les siddourim courants omettent ce psaume à 'Hol hamoèd.

**Preuve.** android/app/src/main/java/com/myhitbodedut/CalendrierJuif.kt:291-292 : « if (!(regles.isRoshChodesh || regles.isChanukah || adar1415 || regles.isTishaBav || regles.isAssurBemelacha || index == JewishCalendar.EREV_PESACH || index == JewishCalendar.EREV_YOM_KIPPUR)) add(C.LAMNATSEAH) » ; même règle dans web/src/js/calendrier-juif.js:128-129. Exécution au 2027-04-26 (19 Nissan, 'hol hamoèd) : conditions « … hallel … lamnatseah moed … pessah yaale_veyavo » ; Ashkenaz Cha'harit « +ajout_yaale_veyavo@3.62 … >hallel … +ajout_lamnatseah@6.1 » ; Sfard « +ajout_lamnatseah@13.1 | +ajout_lamnatseah@14.2 ».

**Correction proposée (revue par le contre-expert).** Ajouter regles.isCholHamoed (Android) et regles.isCholHamoed() (web ; kosher-zmanim y inclut Hochaana Rabba) aux exclusions de LAMNATSEAH. Ajouter une date de 'Hol hamoèd (p. ex. 2027-04-26) et Hochaana Rabba (2027-10-22) aux assertions lamnatseah existantes de BasculeTest.kt et web/test/repli.test.mjs.

**Note du contre-expert.** CalendrierJuif.kt:291-292 et calendrier-juif.js:128-129 n'excluent pas 'Hol hamoèd, et isAssurBemelacha ne le couvre pas. Au 19 Nissan, lamnatseah est dans les conditions et « Aujourd'hui · Lamnatséa'h » sort en Ashkenaz [6.1] et en Sfard [13.1], [14.2]. L'usage d'omettre le Ps 20 à 'Hol hamoèd se confirme (note anglaise du Siddur Sefard de Sefaria ; Ma'hzor Vitry). La liste hébraïque du siddour reprise par l'outil ne le nomme pas, mais elle pose que למנצח suit אל ארך אפים, et rien dans la FEUILLE_DE_ROUTE n'en fait un choix. Les tests existants sur lamnatseah sont dans BasculeTest.kt et web/test/repli.test.mjs.

### TSIDDUR-09 — Avinou malkénou surligné à Min'ha les jours où il ne s'y dit pas (jeûne d'Esther, vendredis, veille de Kippour un vendredi)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** avinouMalkenou ne distingue pas Cha'harit de Min'ha. Le jeûne d'Esther tombant le 13 Adar (2026, 2027, 2029, 2030), Min'ha affiche « Aujourd'hui · Avinou malkénou » alors que Ta'hanoun n'y est pas dit (veille de Pourim). Même chose le vendredi après-midi des dix jours, et à Min'ha de la veille de Kippour quand elle tombe un vendredi (le code cite pourtant le Rema pour Cha'harit seulement). Le commentaire du code ne déclare que la nuance « veille de Chabbat ».

**Preuve.** android/app/src/main/java/com/myhitbodedut/SiddurJour.kt:231-232 : « if (c.EREV_KIPPOUR_VENDREDI in conditions) return true / if (c.JEUNE in conditions && c.TICHA_BEAV !in conditions) return true » ; lignes 225-226 : « les nuances de Min'ha (veille de Chabbat) ne sont pas codées ». Même fonction dans web/src/js/siddur-jour.js:53-59. Exécution : 2027-03-22 (13 Adar II), conditions sans tahanoun_minha, Ashkenaz Min'ha « +ajout_avinou_malkenou@2.0 », Sfard « @3.0 » ; 2027-10-08 (vendredi 7 Tichri) Min'ha « +avinou_malkenou » ; 2028-09-29 (veille de Kippour, vendredi) Min'ha « +avinou_malkenou ».

**Correction proposée.** Créer une condition dérivée pour Min'ha (avinou_malkenou_minha = avinou_malkenou et tahanoun_minha, sans le cas erev_kippour_vendredi) et l'utiliser comme racine du groupe de Min'ha dans les annotations Sfard et Ashkenaz.

### TSIDDUR-10 — « ויהי נועם » surligné tous les samedis soir, y compris les semaines de fête et à 'Hol hamoèd (Sfard, Ashkenaz)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** La section d'Arvit de motsaé Chabbat dépend de la seule clé motsae_chabbat (= dimanche). L'usage ashkénaze (Rema, O.H. 295) omet « ויהי נועם » et « ואתה קדוש » quand une fête tombe dans la semaine, et à motsaé Chabbat 'Hol hamoèd ; l'application les marque « Aujourd'hui · Motsaé Chabbat » ces soirs-là. La section ashkénaze n'a aucune consigne qui le rappelle.

**Preuve.** tools/siddur_annotations.py:149-150 « elif "מוצאי שבת" in titre: cond = "motsae_chabbat" » ; CalendrierJuif.kt:269 « if (semaine == DayOfWeek.SUNDAY) add(C.MOTSAE_CHABBAT) ». Exécution : samedi soir 2027-04-17 (11 Nissan, Pessa'h le jeudi suivant), Arvit Ashkenaz et Sfard « +motsae_chabbat » ; samedi soir 2027-04-24 ('hol hamoèd Pessa'h) « +yaale_veyavo +motsae_chabbat +omer ».

**Correction proposée.** Ajouter une clé dérivée (vayehi_noam : motsaé Chabbat sans Yom tov du dimanche au vendredi suivant, hors 'Hol hamoèd) pour les sections Sfard et Ashkenaz ; garder motsae_chabbat pour Edot.

### TSIDDUR-11 — Arvit Sfard et Ashkenaz : « ברוך ה׳ לעולם אמן ואמן… יראו עינינו » affiché de la même façon en Israël

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** Le lieu « Israël » ne sert qu'à Morid hatal ashkénaze et au calendrier. La bénédiction ajoutée après Hachkivénou (avec son sceau), que l'usage d'Israël omet, est un bloc ordinaire sans annotation dans les deux noussa'h : un utilisateur réglé sur « Israël » la lit comme le reste. Aucune clé de condition ne porte la région.

**Preuve.** siddur_ashkenaz.json arvit [2.21] « &lt;b>בָּרוּךְ&lt;/b> יְהֹוָה לְעוֹלָם אָמֵן וְאָמֵן: … » et [2.22] « יראו עינינו… » ; siddur_sefard.json arvit [0.27], [0.28] : aucune annotation sur ces quatre blocs. SiddurJour.kt:205 : seule utilisation de enIsrael, « if (nusah == "ashkenaz" && !enIsrael) c = c - CalendrierJuif.C.MORID_HATAL ». CalendrierJuif.kt:29-127 : aucune clé de région.

**Correction proposée.** Ajouter une condition dérivée « diaspora » dans SiddurJour.conditionsPour et annoter ces blocs (replis « Hors d'Israël ») dans les Arvit Sfard et Ashkenaz.

### TSIDDUR-12 — Hallel ashkénaze : psaumes bruts, sans les répétitions ni les réponses

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le Hallel ashkénaze (source Daat) donne les psaumes 113-118 tels qu'ils sont dans la Bible : « אודך כי עניתני » et les versets suivants une seule fois, « אנא ה׳ הושיעה נא » et « אנא ה׳ הצליחה נא » une seule fois dans la même phrase, pas de reprise de « הודו לה׳ כי טוב ». Les Hallel Edot et Sfard ont ces doublements. Seule consigne du texte : « בראש חודש מדלגים זה: ».

**Preuve.** siddur_ashkenaz.json, hallel, section 6 (תהילים קיח), bloc 0 (1 537 caractères) : « …אוֹדְךָ כִּי עֲנִיתָנִי וַתְּהִי לִי לִישׁוּעָה. אֶבֶן מָאֲסוּ… אָנָּא יְהוָה הוֹשִׁיעָה נָּא אָנָּא יְהוָה הַצְלִיחָה נָּא. בָּרוּךְ הַבָּא… ». Comptage par script sur le texte sans nikoud : « אודך כי עניתני » ashkenaz 1, sefard 2, edot 2 ; « אנא יהוה הושיעה נא » ashkenaz 1, sefard 2, edot 2 ; « הודו ליהוה כי טוב » ashkenaz 2, sefard 7.

**Correction proposée.** Reprendre le Hallel du siddour ashkénaze Metsudah (déjà source de Cha'harit) ou doubler les versets 21 à 29 du psaume 118 et « אנא ה׳ », avec les consignes de réponse.

### TSIDDUR-13 — Textes ashkénazes de source Daat : le 'holam manque sur le vav (186 mots dans le Moussaf de Roch 'Hodech)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Dans le Moussaf de Roch 'Hodech, le Kaddich et la Soukka du noussa'h Ashkenaz (source « Siddur Ashkenaz, Daat »), le vav 'holam n'a pas son point : on lit « לְעולָם », « קָדושׁ », « שָׁלום », « אֲבותֵינוּ ». Les offices tirés du Metsudah n'ont pas ce défaut (Cha'harit : 18 cas douteux pour 5 949 'holam).

**Preuve.** siddur_ashkenaz.json moussaf_rosh_hodech [5.11] « וְעַל כֻּלָּם יִתְבָּרַךְ וְיִתְרומַם שִׁמְךָ מַלְכֵּנוּ תָּמִיד לְעולָם וָעֶד: », [5.13] « הַטּוב שִׁמְךָ וּלְךָ נָאֶה לְהודות: ». Comptage par script des vav sans voyelle entre deux consonnes : moussaf_rosh_hodech 186 mots (שָׁלום ×8, אֲבותֵינוּ ×6, לְעולָם ×5, קָדושׁ ×5…) pour 30 'holam présents ; soukka 34 (יוסֵף ×7) ; kaddich 7 (בְּחַיֵּיכון, וְיִתְרומַם, הַשָּׁלום).

**Correction proposée.** Corriger dans tools/siddur_nikkud.py : poser U+05B9 sur ces vav dans les textes de source Daat, puis faire relire le Moussaf ; ou reprendre le Moussaf du Metsudah.

### TSIDDUR-14 — Compte de l'omer : Sfard et Ashkenaz reçoivent le texte Edot alors que leur propre Arvit contient leur formule

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le texte « ספירת העומר » (occasions) des noussa'h Sfard et Ashkenaz est emprunté aux Edot : appel « ברשות מורי ורבותי… שמים », formule « שבעה ימים לעמר, שהם שבוע אחד ». Or l'Arvit ashkénaze de la même application a sa section propre, « היום שבעה ימים שהם שבוע אחד בעמר ». Deux formules différentes pour le même noussa'h selon l'écran ouvert, et le rappel d'omer mène au texte emprunté. L'emprunt n'est signalé que par le nom du noussa'h prêteur mis à la place du noussa'h choisi (« Noussa'h séfarade (Edot HaMizra'h) »), sans le mot « emprunté » ; 19 des 38 textes ashkénazes sont dans ce cas.

**Preuve.** siddur_ashkenaz.json, sefirat_haomer : « "nusah": {"fr": "Noussa’h séfarade (Edot HaMizra’h)"} », bloc 22 « שבעה ימים לעמר, שהם שבוע אחד: » ; arvit, section 6 (ספירת העומר), bloc 11 « &lt;small>כ״ב ניסן &lt;/small>&lt;br>7. היום שבעה ימים שהם שבוע אחד בעמר: ». android/app/src/main/java/com/myhitbodedut/SiddurLectureActivity.kt:205 « (texte.emprunt ?: siddur.nusah).forLanguage(langue) » ; web/src/js/app.js:1376.

**Correction proposée.** Construire sefirat_haomer des noussa'h Sfard et Ashkenaz à partir de la section d'Arvit de leur propre siddour ; afficher l'emprunt en clair : « Texte emprunté au noussa'h séfarade (Edot HaMizra'h) » / « Text borrowed from the Sephardi nusach (Edot HaMizrach) » / « נוסח שאול מנוסח עדות המזרח ».

### TSIDDUR-15 — Signes du siddour Metsudah (cheva na', séparation des mots) rendus comme des signes de cantillation, sans légende

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les siddourim Sfard et Ashkenaz gardent deux marques de l'édition Metsudah codées avec des caractères de cantillation : U+0592 (accent « segol ») pour le cheva na' et U+05AF (cercle massorétique) dans le Chema. Avec la police par défaut (Noto Serif Hebrew, qui les dessine), des groupes de points et de petits cercles apparaissent au-dessus de milliers de lettres. Rien ne les explique en Ashkenaz ; en Sfard, une seule consigne en hébreu parle du cercle. Le siddour Edot n'en a pas. Sur Android, les quatre polices sans té'amim masquent ces signes ; sur le web, seul le meteg est masqué.

**Preuve.** Comptage par script : U+0592 = 1 525 (siddur_sefard.json) et 1 253 (siddur_ashkenaz.json, dont Cha'harit 810) contre 24 dans siddur_edot.json ; U+05AF = 155 et 228. Exemples : birkot_hachahar [1.0] « קִדְּ֒שָֽׁנוּ », chaharit [0.96] « בְּכָל֯־לְ֯בָבְ֒ךָ ». siddur_sefard.json chaharit [7.16] : « כל מקום שנרשם עגול כזה (°) הוא כדי להורות לתת ריוח… ». android/app/src/main/java/com/myhitbodedut/PoliceHebraique.kt:89-90 « Police.SERIF to Masque("ֽ"), Police.RACHI to Masque("ֽ") » ; web/src/js/app.js:76 ne remplace que /ֽ/. Rendu réel non observé sur téléphone.

**Correction proposée.** Retirer U+0592 et U+05AF des deux siddourim à la construction (tools/siddur_construction.py), ou les garder avec une légende trilingue en tête de Cha'harit ; sur le web, masquer les té'amim pour frank, david, miriam et arrondie comme PoliceHebraique.ABSENTS.

### TSIDDUR-16 — Tikoun haKlali : la prière de Rabbi Natan est vocalisée pour moitié, avec des fautes de nikoud

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Sur les 16 paragraphes de la prière finale, les 8 premiers sont vocalisés et les 8 derniers (3 084 lettres) ne le sont pas ; le passage se fait au milieu d'une phrase (« רִבּוֹנוֹ של עולם! »). La partie vocalisée porte des fautes reprises de la page fournie : « לִפָנֶיךָ » deux fois pour לְפָנֶיךָ, « מַלֵּא בּוּשָׁה » pour מָלֵא, « גּוֹאֲלֵי » pour גּוֹאֲלִי, « וְשִחַתְתִּי מַה שְּׁשִּׁחַתְתִּי », « אֶשָּעֵן » (point du shin absent). L'ouverture et la kavana mêlent aussi mots vocalisés et nus. Le fichier reconnaît que cette liturgie n'a qu'un témoin.

**Preuve.** android/app/src/main/res/raw/tikkun_haklali.json:1244 « הִנְנִי לִפָנֶיךָ בְּאַשְׁמָה רַבָּה, הִנְנִי לִפָנֶיךָ מַלֵּא בּוּשָׁה וּכְלִמָּה » ; :1243 « אָבִי אָבִי, גּוֹאֲלֵי וּפוֹדִי … וְשִחַתְתִּי מַה שְּׁשִּׁחַתְתִּי » ; :1247 « בָּהֶם אֶשָּעֵן וְאֶסָּמֵךְ » ; :1249 « רִבּוֹנוֹ של עולם! פתח פיך לאלם כמוני » ; :1169 « הריני מזמן את פי להודות וּלְהלל וּלְשבח את בוראי. לְשֵם יִחוּד קוּדְשָא… ». Script : paragraphes 0-7, 74 à 85 % de lettres vocalisées ; paragraphes 8-15, 0 à 1 %. _meta.verification.liturgie : « UN SEUL TEMOIN ».

**Correction proposée.** Reprendre la prière sur une édition vocalisée de Likoutei Tefilot ou d'un Tikoun imprimé, ou retirer tout le nikoud pour un texte homogène ; corriger au minimum les six formes citées : לְפָנֶיךָ (×2), מָלֵא בּוּשָׁה, גּוֹאֲלִי וּפוֹדִי, וְשִׁחַתְתִּי מַה שֶּׁשִּׁחַתְתִּי, אֶשָּׁעֵן.

### TSIDDUR-17 — Cinq blocs conditionnels restés sans annotation ou mal rattachés (Edot surtout)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** Restent affichés tous les jours, en texte de prière : (1) Edot Min'ha [1.67], la formule d'acceptation d'un jeûne individuel, alors que le bloc voisin « ביום תענית יאמר » est replié ; (2) Edot Havdala [0.17] et [0.18], les lignes de 'Hol hamoèd de la bénédiction finale, alors que celle de Roch 'Hodech [0.16] est repliée ; (3) Sfard Cha'harit [1.19], consigne « בט׳ אב ויוה״כ אין אומרים ברכה זו », sans effet le 9 Av. À l'inverse, (4) Edot Arvit [2.26], « נוסח עננו בג׳ צומות » (la version des trois autres jeûnes), est surligné le soir du 9 Av avec la version du 9 Av ; (5) Edot Cha'harit [9.28] et [9.29], les deux versions d'Anénou sont surlignées ensemble à chaque jeûne.

**Preuve.** siddur_edot.json minha [1.67] « הרוצה להתענות תענית יחיד למחר, יקבל על עצמו את התענית בתפילת מנחה בנוסח זה &lt;br>רבון העולמים, הריני לפניך על תנאי בתענית נדבה למחר… » (aucune annotation ; exécution au 2026-11-13 : « [1.67] NORMAL »). havdala [0.17] « חוה''מ פסח ושמחנו ביום חג המצות הזה… » ; siddur_annotations.json:3629-3637 : seule annotation de la Havdala, « "b": 16 ». siddur_annotations.json:2447-2456 (edot, arvit) : « "si": "ticha_beav", "b": 26, "empreinte": "נוסח עננו בג׳ צומות (סנסן ליעיר ג:ט) עננ" ».

**Correction proposée.** Annoter Edot Min'ha [1.67] en « facultatif » (libellé « Avant un jeûne individuel ») ; Havdala [0.17] en pessah, [0.18] en soukkot ; retirer Edot Arvit [2.26] du groupe ticha_beav ; à Cha'harit et Min'ha Edot, donner au bloc « בג׳ צומות » la condition « !ticha_beav » dans le groupe jeune.

### TSIDDUR-18 — Aucun test ne contrôle le texte réellement affiché un jour donné

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** SiddurJourTest (10 tests) vérifie que chaque annotation désigne son bloc, que les libellés existent et quelques replis précis ; SiddurTest vérifie la présence des textes. Rien ne vérifie le résultat lu : les 19 sceaux de l'Amida présents une seule fois, Alénou visible, la bénédiction de Modim fermée. Les défauts ci-dessus (sceau doublé, sceau caché, fin d'office repliée) passent donc la CI. Un contrôle de ce type, écrit pour cet audit, les trouve en une exécution.

**Preuve.** android/app/src/test/java/com/myhitbodedut/SiddurJourTest.kt:19-180, intitulés des tests : « chaque annotation designe encore son bloc », « les conditions existent et chaque libelle est traduit », « les ajouts principaux sont annotes dans les trois nusah », « roch hodech - chaharit renvoie au hallel puis au moussaf », … Sortie de OUT/tsiddur/hatimot.mjs (3 noussa'h × 4 offices × 10 jours-types) : « edot minha : yerushalayim×2 », « edot moussaf_rosh_hodech : hodaa×0 », « ashkenaz moussaf_rosh_hodech : kedusha×2, hodaa×0 », « sefard chaharit : kedusha×2, mishpat×2 ← ayt ».

**Correction proposée.** Ajouter à SiddurJourTest et à web/test un invariant : pour chaque noussa'h, office (Cha'harit, Min'ha, Arvit, Moussaf) et jour-type (ordinaire été et hiver, vendredi, Roch 'Hodech, 'Hanouka, jeûne, dix jours, 'hol hamoèd, 9 Av, Pourim), le texte non replié contient chaque sceau de l'Amida exactement une fois et se termine par עלינו.

### TSIDDUR-19 — 'Hol hamoèd et jeûnes : l'office de semaine renvoie à des textes absents (Moussaf de fête, Seli'hot, « תעניות ואבילות »)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte · déjà connu ou choix assumé

**Constat.** La liste « Ce qui manque » annonce déjà l'absence des offices de Chabbat et de fête. Conséquence concrète non dite à l'utilisateur : à 'Hol hamoèd (jours où le téléphone sert), Cha'harit affiche Ya'alé véyavo et « Aujourd'hui · הלל › », puis rien pour le Moussaf de la fête (le renvoi n'existe que pour Roch 'Hodech), sans un mot d'avertissement. Plusieurs consignes renvoient aussi à des parties qui n'existent pas dans l'application.

**Preuve.** FEUILLE_DE_ROUTE.md:1010-1013 « Les offices de Chabbat et des fêtes (… Amida des fêtes, Hallel des fêtes, Kiddouch), le Ma'hzor…, les Seli'hot… rien n'est encore dans l'application ». Exécution au 2027-04-26 ('hol hamoèd) : un seul renvoi, « >hallel ». Renvois sans cible : siddur_edot.json chaharit [10.9] « בתעניות ציבור אומרים כאן תחנונים נוספים שנמצאים ב״תעניות ואבילות" », [11.17] « ברכת הגומל נמצא בסדר קריאת התורה של שבת » ; megila (Sfard, Ashkenaz) [0.50] « …תמצא לעיל אחר תפלת ערבית ».

**Correction proposée.** En attendant les textes, afficher à 'Hol hamoèd, après le Hallel, une note trilingue (« Le Moussaf de la fête n'est pas encore dans l'application ») et retirer ou adapter les trois renvois sans cible (HaGomel : renvoyer au texte « hagomel » du groupe des occasions).

### TSIDDUR-20 — Carte « Si l'on prie seul » : une coutume du Ben Ich 'Haï insérée dans les siddourim Ashkenaz et Sfard, en hébreu seulement

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte · déjà connu ou choix assumé

**Constat.** Choix délibéré (demande du 19/10), mais critiquable. La braïta « חיה אחת », à dire à la place de Barekhou, et sa consigne sont des textes rédigés par l'application ; ils s'affichent dans les trois noussa'h. L'utilisateur ashkénaze reçoit, sans mention d'origine dans sa langue, un usage séfarade sourcé « בן איש חי… הרב עובדיה יוסף ». Les deux phrases de consigne ne sont ni vocalisées ni traduites (seul le titre « Si l'on prie seul » l'est), et la première carte, placée à Barekhou, dit seulement de ne pas dire la braïta ici.

**Preuve.** tools/siddur_annotations.py:701-709 : « # Qui prie seul, à la place de Barekhou (demande du 19/10) » ; « BARAITA_CONSIGNE = "המתפלל ביחיד אומר במקום ברכו, בלי להזכיר את השם (בן איש חי, ויגש י״ח; חיד״א, צפורן שמיר):" » ; « BARAITA_RENVOI = "המתפלל ביחיד אינו אומר כאן את הברייתא „חיה אחת“, שאין להפסיק בין ישתבח ליוצר; אומרה לפני עלינו לשבח…" ». siddur_annotations.json : 9 entrées « seul », dont ashkenaz chaharit [2.4] et [6.85], ashkenaz arvit [1.3].

**Correction proposée.** Limiter la carte au noussa'h Edot, ou la garder partout en la présentant comme coutume séfarade ; déplacer les deux consignes dans strings.xml : « Qui prie seul dit ceci à la place de Barekhou, sans prononcer le Nom (coutume séfarade : Ben Ich 'Haï, 'Hida) » / « One praying alone says this in place of Barechu, without pronouncing the Name (Sephardi custom: Ben Ish Chai, Chida) ».

### TSIDDUR-21 — Chéva bérakhot : l'ordre est corrigé, mais le zimoun propre au repas de noces manque

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les sept bénédictions sont maintenant dans le bon ordre dans les trois noussa'h (« שהכל ברא לכבודו » en tête, « בורא פרי הגפן » à la fin). Le zimoun du repas de noces (« דוי הסר… », « נברך אלהינו שהשמחה במעונו ») n'apparaît nulle part : le zimoun affiché est celui de tous les jours, et la consigne du groupe ne le mentionne pas.

**Preuve.** grep « שהשמחה במעונו » : 0 occurrence dans siddur_edot.json, siddur_sefard.json et siddur_ashkenaz.json. siddur_ashkenaz.json birkat_hamazon [0.76] « בסעודת שבע ברכות, אחר ברכת המזון: », [0.77] « …שֶׁהַכֹּל בָּרָא לִכְבוֹדוֹ. », [0.84] « …בּוֹרֵא פְּרִי הַגָּפֶן. ».

**Correction proposée.** Ajouter au groupe zimun de Birkat haMazon, sous une consigne « בסעודת שבע ברכות », les répliques « דוי הסר… » et « נברך אלהינו שהשמחה במעונו ושאכלנו משלו » (tools/siddur_cheva_berakhot.py).

### TSIDDUR-22 — Documentation en retard sur le code : ZMANIM.md (trois affirmations), feuille de route, notes internes des fichiers

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : docs · **Type** : texte

**Constat.** (1) ZMANIM.md affirme qu'« aucune règle n'est écrite à la main », alors que CalendrierJuif.kt en compte une quinzaine (lamnatseah, ledavid, kriat_hatorah, bascule_pluie, embolismique, avinou_malkenou…) — et c'est là que se trouvent les erreurs de Lamnatséa'h et d'Avinou malkénou. (2) Il dit « volontairement non annotés » Avinou malkénou Sfard et Ashkenaz, le Ta'hanoun ashkénaze et le Chir chel yom, tous annotés aujourd'hui. (3) Il décrit encore la variante enchâssée comme un repère « Aujourd'hui : … », remplacé le 28/10 par un repli. (4) La feuille de route garde « ordre des Sheva Berakhot » dans le reste à faire non commencé, alors que c'est fait. (5) tehilim.json dit que le Tikoun « garde les formes substituées » ; tikkun_haklali.json dit l'inverse.

**Preuve.** ZMANIM.md:63-64 « Chacune renvoie à une méthode de KosherJava, et aucune règle n'est écrite à la main » ; CalendrierJuif.kt:272-314 (règles dérivées). ZMANIM.md:155-157 « Volontairement non annotés, donc toujours dépliés : Avinou malkénou dans les noussa'him Sfard et Ashkenaz…, le Ta'hanoun du siddour ashkénaze…, le Chir chel yom » ; siddur_annotations.json : avinou_malkenou ×39, tahanoun_chaharit ×30 (ashkenaz), jour_1 à jour_6. ZMANIM.md:152-153. FEUILLE_DE_ROUTE.md:1160-1161 « Lot du 28/10 : … ordre des Sheva Berakhot ». tehilim.json:17 « le Tikoun, lui, garde les formes substituées » ; tikkun_haklali.json:21 « Écrits en toutes lettres ».

**Correction proposée.** Réécrire ZMANIM.md § « Les ajouts de prière » et § « Dans le siddour » : lister les conditions dérivées écrites à la main avec leur source, supprimer le paragraphe « Volontairement non annotés », décrire le repli des variantes ; rayer les Sheva Berakhot du reste à faire ; aligner les deux _meta.

### TSIDDUR-23 — Tehilim du jour : « Jour N du mois » change à minuit civil, alors que la date hébraïque de l'application change à la sortie des étoiles

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction · déjà connu ou choix assumé

**Constat.** Choix documenté dans le code. Depuis que le bandeau et le calendrier passent au jour hébreu suivant à tsét, l'écran Tehilim peut afficher le soir « Jour 7 du mois : … » pendant que le reste de l'application est déjà au 8. Le découpage lui-même est juste (30 portions, psaume 119 coupé à 96/97, mois de 29 jours qui finit le livre le 29).

**Preuve.** android/app/src/main/java/com/myhitbodedut/Tehilim.kt:101-108 « Le jour du mois hébraïque et la longueur de ce mois, pour la date civile : le jour change ici à minuit, pas au coucher du soleil. » ; TehilimActivity.kt:50-51 « val aujourdhui = LocalDate.now() / val (jour, longueur) = CycleTehilim.jourHebreu(aujourdhui) » ; strings.xml:627 « Jour %1$s du mois : %2$s ». FEUILLE_DE_ROUTE.md:1100 « date hébraïque à la tset ».

**Correction proposée.** Passer par la même date que le bandeau (jour hébreu à tsét quand un lieu est connu), dans TehilimActivity, MainActivity:724 et web/src/js/app.js:815-838.

### TSIDDUR-24 — Nom divin : sept formes substituées ou abrégées subsistent dans des prières, et deux vocalisations coexistent

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les fichiers annoncent le Nom « en toutes lettres » dans les prières. Il reste : « השם » à la place du Nom dans l'appel du oleh (Edot), l'abréviation « וַיָי » (Hallel Sfard), « אלקא דמאיר » deux fois dans l'allumage des bougies (Sfard, repris en Ashkenaz). Le Tétragramme est vocalisé tantôt « יְהֹוָה », tantôt « יְהוָה » dans un même siddour. Les vocalisations de kavana (יוּהוּווּהוּ, יִהִוִהִ…) sont voulues (test « les hatimot de la amida sfard portent le nikkoud des kavanot ») mais ne sont expliquées nulle part à l'écran.

**Preuve.** siddur_edot.json chaharit [11.8] « ואומר העולה: הַשֵּׁם עִמָּכֶם: », [11.9] « ועונים הקהל: יְבָרֶכְךָ הַשֵּׁם: » ; siddur_sefard.json hallel [0.25] « וַיָי בֵּרַךְ אֶת אַבְרָהָם בַּכֹּל » ; nerot_chabbat [0.15] et [0.18] « אלקא דמאיר ענני » (Sfard et Ashkenaz). Comptage (noms.py) : Ashkenaz « יְהֹוָה » 947, « יְהוָה » 58 ; Edot 1 036 et 19. _meta.noms_divins : « En toutes lettres : les abréviations des sources… sont développées dans les prières ».

**Correction proposée.** Développer ces sept formes (יְהֹוָה עִמָּכֶם, יְבָרֶכְךָ יְהֹוָה, וַיהֹוָה בֵּרַךְ, אֱלָהָא דְמֵאִיר) dans tools/noms_divins.py, unifier la vocalisation, et ajouter une ligne d'explication des noms de kavana (lecture inchangée).

### TSIDDUR-25 — Consignes saisies comme du texte de prière et guillemets typographiques à la place du guerchayim

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Quelques consignes sont des blocs « t » : elles s'affichent en grand, comme une prière, au milieu de Birkat haMazon ou de l'Amida. Dans le Kaddich ashkénaze, « בעשי”ת » porte un guillemet anglais (U+201D) au lieu de ״.

**Preuve.** siddur_ashkenaz.json birkat_hamazon [0.24] et siddur_sefard.json birkat_hamazon [0.36], blocs « t » : « בחנוכה ופורים אומרים כאן על הניסים. ואם לא אמרו אין מחזירין אותו. ומכל מקום יוכל לאמרו בתוך שאר הרחמן… » (exécution : « [0.24] NORMAL ») ; siddur_edot.json minha [1.53], [1.56], [1.68] commencent par une consigne non balisée (« אם יש יותר מכהן אחד קורא להם החזן: »). siddur_ashkenaz.json kaddich [0.4] « &lt;small>בעשי”ת: לעלא לעלא מכל&lt;/small> », [0.6] « &lt;small>בעשי”ת: השלום&lt;/small> ».

**Correction proposée.** Passer ces blocs en « c » (ou scinder consigne et texte) dans tools/siddur_construction.py ; remplacer U+201D par U+05F4 dans le Kaddich ashkénaze.
