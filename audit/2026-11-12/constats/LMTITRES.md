# LMTITRES — Likoutei Moharan — les 400 titres et le dernier tiers : qualité FR et EN

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

9 constats — confirmés : 1 · confirmés en partie : 1 · non contre-expertisés (mineurs et cosmétiques) : 7.

## Ce qui a été examiné

BALAYÉ PAR SCRIPT (scripts et extraits dans OUT/LMTITRES) :
- les 411 titres dans les 3 langues (titres_verif.py, titres_tous.txt) ;
- tout le livre, soit 411 sections et 7 057 blocs × 2 langues, pour les contrôles suivants : traductions absentes, FR identique à l'EN, traduction identique à l'hébreu, lettres hébraïques restées (80 blocs, presque tous voulus), balises, crochets, parenthèses et guillemets (79 blocs avec balises par langue), fins de phrase, traductions identiques pour des hébreux différents (8 en FR et 7 en EN, toutes justifiées), mots français dans l'anglais et inversement (uniquement des translittérations), ratios de longueur sur 6 871 blocs, renvois (2 408 versets, 535 renvois au Talmud, 141 siman), table d'environ 150 variantes de termes et de 25 noms propres ;
- sur le dernier tiers seulement (sections 274 à 410, de LM I 275 à LM II 125, 1 792 blocs) : les négations (166 candidats, une quinzaine lus, sans omission trouvée).

LU DE PRÈS : 30 blocs tirés avec random.seed(20261112) dans le dernier tiers (10 longs de 363 caractères ou plus, 20 courts répartis en strates : echantillon.txt). S'y ajoutent environ 75 blocs du dernier tiers lus de façon ciblée (LM II 25 et II 92 en entier, II 78:22-23, II 24:0-2, II 12:13-16, I 282:0-1, les 8 occurrences de Ps 81:4, les contextes) et 48 blocs extrêmes pris sur tout le livre.

DÉCOMPTE SUR L'ÉCHANTILLON DE 30 BLOCS :
- FR : 30 blocs lus, 0 erreur grave, 8 erreurs légères (276:27 ajout ; 286:26 et 292:95 balises ; 286:98 renvoi faux ; 290:34 terme impropre ; 293:87 renvoi ambigu ; 356:25 faux sens ; 368:16 translittération).
- EN : 30 blocs lus, 0 erreur grave, 4 erreurs légères (286:26 et 292:95 balises ; 286:98 ; 293:87).

DÉCOMPTE HORS ÉCHANTILLON (lecture ciblée) :
- EN : 2 erreurs graves (286:100 et 290:161, « full moon » qui contredit le texte) et 2 légères (286:0, 290:0).
- FR : 0 erreur grave, 1 légère (346:7).
- Les deux langues sont manifestement traduites de l'hébreu séparément ; leurs divergences restent ponctuelles.

NON EXAMINÉ :
- lecture intégrale des 1 792 blocs du dernier tiers ;
- les citations araméennes du Zohar et des Tikounim, non confrontées à leur source ;
- les versets, non comparés aux éditions du Rabbinat et de JPS ;
- l'hébreu source, non comparé à une édition imprimée ;
- l'affichage des balises, déduit du code (SiddurLectureActivity.kt, app.js) et non vu sur un appareil ;
- les deux premiers tiers, contrôlés par script seulement (confiés aux autres auditeurs).

## Ce qui tient

- Titres des 411 sections : aucune anomalie dans les trois langues. La numérotation hébraïque est canonique (טו et טז respectés) et sa valeur numérique correspond exactement au chiffre de titre_fr et titre_en. Les 286 enseignements de la partie I et les 125 de la partie II se suivent sans saut ni doublon, et le suffixe « – Tinyana » est constant dans les 125 titres de la partie II. Les incipits confirment l'alignement titre/contenu, vérifié notamment sur LM I 1, 3, 52, 64, 205, 282 et LM II 1, 7, 8, 12, 24, 25, 48, 92, 125.
- Couverture complète et sans troncature : les 7 057 blocs ont un français et un anglais. Aucun n'est identique à l'hébreu, aucun n'a le même texte en FR et en EN, et aucune phrase n'est coupée ailleurs qu'aux coupures de l'hébreu. Les rapports de longueur sont serrés (médianes 1,93 en FR et 1,85 en EN, extrêmes de 1,09 à 3,72), et les 48 blocs extrêmes lus s'expliquent tous par des titres courts ou des acronymes glosés.
- Les renvois aux sources ont été vérifiés et souvent corrigés. Sur 2 408 renvois chapitre:verset et 535 renvois daf/amud, les 17 écarts avec l'hébreu sont tous des corrections justifiées de la source : Daniel 4:19, Chemot 23:16, Devarim 33:12, Yirmeya 31:16 et 31:33 selon la numérotation massorétique, Nedarim 32b, 'Haguiga 13a. Les 141 renvois « siman » gardent leur numéro.
- Les abréviations et les guématries sont bien rendues : GeMaPaT [Guemara, Peroush, Tossafot], Atbach, Métat(ron), 'Hidouché Aggadot pour חא"ג, Matnot Kehouna, Rabbénou Yona pour תר"י, Mikdach Mélekh, Chakh (320) ; מחקק = 248, gam = 43, qof-samekh-'het = 'hessed en atbach.
- Les passages de doctrine et de pratique sont rendus fidèlement et chaleureusement : LM II 25 sur la hitbodedout (12 blocs, aucune erreur), LM II 92 et ses dix psaumes (16, 32, 41, 42, 59, 77, 90, 105, 137, 150, exacts), LM II 78 (« il n'y a absolument aucun désespoir au monde », avec le yiddish conservé), LM I 282 (Azamra), LM II 24 et LM II 48.
- Le glossaire des termes centraux est stable et parallèle dans les deux langues : Hachem/Hashem (1 085/1 083), l'Éternel/the LORD dans les versets (711/719), Tsadik(im)/tzaddik(im) (994/989), hitbodedout/hitbodedut, mo'hin/mochin (347/347), techouva/teshuvah. « Juste » n'est employé que dans les versets.

## Constats

### LMTITRES-01 — EN (et FR+EN en LM I 14) : « bakessé » traduit « at the full moon / à la pleine lune », à contresens de la lecture « Roch Hachana, lune couverte » sur laquelle reposent les enseignements

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : texte

**Constat.** Dans Tehilim 81:4, בַּכֶּסֶה est lu par le texte lui-même comme « le jour où la lune est couverte », c'est-à-dire Roch Hachana (jeu de mots כסה / מכסה / התכסיא). L'anglais de LM II 1 et II 5 reprend la traduction JPS « at the full moon ». La phrase en devient contradictoire : « at the full moon … that is, Rosh Hashanah », alors que Roch Hachana tombe à la nouvelle lune. Le jeu de mots que le commentaire construit aussitôt (« tefillin that cover ») disparaît. En LM I 14, le français et l'anglais font la même erreur, alors que la phrase suivante dit « kessé est un terme de dissimulation ». Le même verset reçoit en outre 8 traductions différentes dans le livre : FR « nouvelle lune » ou « néoménie », « au temps fixé » ou « à la pleine lune », « loi/ordonnance » ou « loi/règle », « Dieu de Yaakov » ou « Dieu de Jacob » ; EN « horn » ou « shofar », « full moon » ou « appointed time ». Total : 6 traductions fautives (4 EN dans le dernier tiers, 1 FR + 1 EN en LM I 14, auxquels s'ajoute le 13:0 FR/EN).

**Preuve.** android/app/src/main/res/raw/livre_likoutei_moharan.json (source : android/app/src/main/livres/livres.json).
- textes[0].sections[286].blocs[100] (תנינא תורה א) : HE « ועלידי כל הבחינות אלו – בכסא ליום חגנו; הינו ראש השנה » ; EN « through all these aspects: “at the full moon (bakeseh) for our feast-day,” that is, Rosh Hashanah ».
- sections[290].blocs[161] (תנינא תורה ה) : HE « בכסא – זה בחינת תפלין דמכסין על מחא » ; EN « “At the full moon (ba-keseh) for our feast-day.” Ba-keseh – this is the aspect of the tefillin that cover (de-mechasin) the brain ».
- sections[286].blocs[0] et sections[290].blocs[0] : EN « Blow the horn at the new moon, at the full moon (bakeseh) for our feast-day ».
- sections[13].blocs[47] (תורה יד) : HE « בכסא – זה בחינת יראה … וכסא לשון התכסיא » ; FR « « À la pleine lune (bakessé) » — … et kessé est un terme de dissimulation (itkassia) » ; EN « “At the full moon (bakeseh)” — … keseh is a term of concealment ».
- sections[13].blocs[0] : FR « Sonnez du chofar à la néoménie, à la pleine lune (bakessé), etc. ».
- Divergences sur le même verset : sections[290].blocs[0] FR « une ordonnance du Dieu de Yaakov » contre sections[293].blocs[0] FR « une règle du Dieu de Jacob » ; sections[293].blocs[115] EN « At the appointed time (ba-keseh) ».

**Correction proposée (revue par le contre-expert).** Les corrections anglaises et celles de 13:0 sont justes. Pour 13:47 FR, éviter « Au jour couvert », qui fait penser à un ciel couvert. Écrire plutôt : « « Quand [la lune] est couverte (bakessé) » — c'est l'aspect de la crainte, qui est la racine de la gloire ; et kessé est un terme de dissimulation (itkassia)… ». Pour la mise en cohérence du français, « au temps fixé » (Rachi, Rabbinat) n'est pas faux. Il faut le remplacer en priorité là où le commentaire joue sur כסה (290:161, 293:115, 293:120), pour garder le jeu de mots avec « recouvrent » et « cacherai-je ».

**Note du contre-expert.** J'ai rouvert les 12 blocs du livre qui contiennent בכסא/בכסה. On trouve 6 « full moon » en anglais (13:0, 13:47, 286:0, 286:100, 290:0, 290:161) et 2 « pleine lune » en français (13:0, 13:47), soit 8 traductions fautives, comme le dit le constat. La traduction JPS « at the full moon » est copiée à l'identique (je l'ai comparée avec tehilim.json). Elle contredit la lecture du texte : 286:100 dit « הינו ראש השנה », 13:47 dit « כסא לשון התכסיא », 290:161 dit « דמכסין » ; c'est la lecture du Talmud en Roch Hachana 8a-b (« le mois où la lune est couverte »). Aucun choix documenté ne couvre cette traduction : l'en-tête de tools/traductions_textes.py ne parle que de l'usage « l'Éternel / the LORD ». Le « au temps fixé » français de 286, 290 et 293 suit Rachi et le Rabbinat 1899 (« au jour fixé »). Ce n'est pas une faute, et l'auditeur ne le compte d'ailleurs pas.

### LMTITRES-02 — FR+EN : balises &lt;b>…&lt;/b> et &lt;br> et appels de note [10], [11] recopiés dans les traductions et affichés en clair à l'écran

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** Les traductions recopient le balisage de l'hébreu : les numéros de paragraphe &lt;b>א&lt;/b> deviennent &lt;b>1&lt;/b>, les &lt;br> sont gardés tels quels. Or seul l'hébreu passe par l'interpréteur HTML. Sur Android, SiddurLectureActivity ajoute la traduction en texte brut (append(t)) ; sur le web, paraTraduction passe par h(), c'est-à-dire document.createTextNode. Le lecteur voit donc littéralement « &lt;b>1&lt;/b> Car l'homme d'Israël… ». Cela touche 79 blocs par langue, soit 158 traductions, dont 75 blocs dans le dernier tiers : LM II 1, 2, 4, 5, 7 et 8 (les plus longues leçons de Tinyana, découpées en paragraphes numérotés), LM II 20 et 26, et dans le premier tiers LM I 16, 19, 59 et 63. Quatre blocs gardent en plus des appels de note orphelins [10] et [11], issus des [י] et [יא] de l'hébreu, dont 2 dans le dernier tiers. Le contrôle automatique annoncé (« relues automatiquement (clés, balises) ») s'est assuré que les balises étaient bien recopiées, sans vérifier qu'elles s'affichaient.

**Preuve.** android/app/src/main/res/raw/livre_likoutei_moharan.json :
- sections[286].blocs[1] : HE « &lt;b>א&lt;/b> כי איש הישראלי נברא » ; FR « &lt;b>1&lt;/b> Car l'homme d'Israël a été créé… » ; EN « &lt;b>1&lt;/b> For the man of Israel… ».
- sections[287].blocs[0] : FR « &lt;b>1&lt;/b> Les jours de ‘Hanouka sont des jours de remerciement ».
- sections[292].blocs[95] : FR « &lt;b>12&lt;/b> Et c'est l'aspect de l'équilibre du poumon ».
- sections[293].blocs[64] : FR « &lt;b>10&lt;/b> Et lorsqu'aura lieu le renouvellement du monde ».
- sections[305].blocs[0] : FR « Querelle (meriva), lettre י&lt;br>Par la controverse… ».
- sections[311].blocs[0] : FR « Ivresse, lettre ד&lt;br>Il faut s'éloigner de l'ivresse ».
- sections[58].blocs[0] : FR « Paroles de Rabbénou, de mémoire bénie&lt;br>1. Celui qui s'efforce ».
- sections[371].blocs[4] : FR « « Qui a causé aux Tsadikim, etc. » [10] ».
- sections[372].blocs[0] : FR « du Ari, de mémoire bénie [11]) ».
Code : android/app/src/main/java/com/myhitbodedut/SiddurLectureActivity.kt (seul l'hébreu passe par Html.fromHtml ; la traduction passe par append(t)) ; web/src/js/app.js l.796 (paraTraduction, puis h(), puis createTextNode).
Mesure : 79 blocs avec balise en FR et 79 en EN (scan1.py).

**Correction proposée (revue par le contre-expert).** La solution la plus sûre est de rendre fr et en comme l'hébreu : Html.fromHtml sur Android, riche() sur le web. Si l'on corrige plutôt les données, l'expression « ^&lt;b>(\d+)&lt;/b> » ne suffit pas : elle manque « &lt;b> 16&lt;/b> » (290:137), les « &lt;b> &lt;/b> » vides (289:75, 292:80), le gras en milieu de phrase (18:89) et le titre entièrement en gras (62:0). Il faut alors retirer toutes les balises &lt;b>/&lt;/b>, après avoir changé « &lt;b>N&lt;/b> » en « N. », et remplacer &lt;br> par un saut de ligne. Le test à ajouter doit seulement refuser « < » dans fr et en. Une règle sur « [chiffre] » échouerait à tort sur 28:13 et 56:51. Pour 371:4 et 372:0, garder [10] et [11] comme l'hébreu, ou les supprimer dans les deux langues à la fois.

**Note du contre-expert.** Le décompte est juste : 79 blocs à balises par langue, dont 75 dans les sections 286 à 311 (LM II 1, 2, 4, 5, 7, 8, 20, 26) ; dans le premier tiers, LM I 16, 19, 59 et 63. Le rendu est bien du texte brut. Sur Android, la traduction passe par append(t) sans Html.fromHtml (SiddurLectureActivity.kt, l. 516). Sur le web, elle passe par paraTraduction, puis h() et createTextNode, sur le site construit aussi. Deux points sont surestimés. (1) La gravité : c'est un défaut d'affichage sans effet sur le sens, qui touche environ 1 % des 7 057 blocs traduits ; il est donc mineur, pas majeur. (2) Les appels de note : seuls 2 blocs les contiennent, 371:4 [10] et 372:0 [11], tous deux dans le dernier tiers, et non 4. Les crochets de 28:13 (« vingt-huit [28] ») et de 56:51 (« Zekharia [8] ») ne sont pas des appels de note. Quant à [10] et [11], ils rendent fidèlement les [י] et [יא] de l'hébreu, eux aussi sans note.

### LMTITRES-03 — FR+EN : renvois de sources faux ou ambigus (« Tikoun 21 et 49 », « Yirmeya 10, 51 », « Yecha'ya 48, 57 »)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le contrôle par script de 2 408 renvois chapitre:verset, 535 renvois au Talmud (daf et amud) et 141 « siman » ne relève aucune altération dans le dernier tiers : les 17 écarts trouvés sur tout le livre sont des corrections justifiées de l'hébreu source. En revanche, des renvois dont les chiffres ne sont pas séparés ont été mal interprétés. « תקון כא מט » signifie « Tikoun 21, page 49 » : le Tikoun 21 couvre les pages 43 à 60, et le livre rend lui-même « תיקון כ"א דף מט » par « Tikoun 21, page 49 » en 290:90, sur le même thème du cœur. Il a pourtant été traduit « Tikoun 21 et 49 ». Les doubles renvois à deux livres prophétiques sont laissés sous la forme « 10, 51 », que le lecteur prend pour chapitre 10, verset 51. En tout, 3 cas sur l'ensemble du livre, dont 2 dans le dernier tiers.

**Preuve.** livre_likoutei_moharan.json :
- sections[286].blocs[98] (LM II 1) : HE « (זהר פנחס דף רטז רכא ועיין תיקונים תקון כא מט) » ; FR « (Zohar Pin'has, pages 216 et 221 ; et voir les Tikounim, Tikoun 21 et 49) » ; EN « (… and see the Tikkunim, Tikkun 21 and 49) ». Point de comparaison : sections[290].blocs[90], HE « (ע' תיקון כ"א דף מט) », FR « (voir Tikoun 21, page 49) ».
- sections[293].blocs[87] (LM II 8) : HE « (ירמיה י נא): הבל המה מעשה תעתעים » ; FR « (Yirmeya 10, 51) » ; EN « (Jeremiah 10, 51) ». Le verset se trouve en Jr 10:15 et 51:18.
- sections[26].blocs[20] (LM I 27) : HE « אין שלום אמר לרשעים (ישעיה מח נז) » ; FR « (Yecha'ya 48, 57) » ; EN « (Isaiah 48, 57) ». Le verset se trouve en Is 48:22 et 57:21.

**Correction proposée.** Corrections :
- 286:98 FR : « (Zohar Pin'has, pages 216 et 221 ; et voir les Tikounim, Tikoun 21, page 49) » ; EN : « (Zohar Pinchas, pages 216 and 221; and see the Tikkunim, Tikkun 21, page 49) ».
- 293:87 FR : « (Yirmeya 10:15 ; 51:18) » ; EN : « (Jeremiah 10:15; 51:18) ».
- 26:20 FR : « (Yecha'ya 48:22 ; 57:21) » ; EN : « (Isaiah 48:22; 57:21) ».
Mesure : rechercher par script les renvois de la forme « (Livre N, M) » et « Tikoun N et M », puis les vérifier un par un.

### LMTITRES-04 — FR : faux sens, ajout, terme impropre et faute de langue isolés relevés en lecture serrée du dernier tiers

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** La lecture serrée relève quatre défauts du français que l'anglais n'a pas, ce qui montre que les deux langues ont été rédigées séparément. Il s'agit d'un faux sens sur une citation du Talmud (Sanhédrin 24a), d'un ajout interprétatif, d'un emploi de « Éternel » pour קדמון alors que le mot rend partout ailleurs le Tétragramme (711 occurrences) et d'une tournure fautive. Dans l'échantillon tiré, cela représente 3 blocs sur 30 ; une relecture humaine en trouverait d'autres du même ordre, à raison de 1 bloc sur 10 environ.

**Preuve.** livre_likoutei_moharan.json :
- sections[356].blocs[25] (LM II 71) : HE « בחינת נעם, שמנעימים בהלכה » ; FR « l'aspect de la douceur, de ceux qui se rendent la halakha agréable ». Faux sens : selon Sanhédrin 24a, ce sont ceux « qui se rendent agréables l'un à l'autre dans la halakha » ; l'anglais le rend juste : « of those who are pleasant to one another in halachah ».
- sections[276].blocs[27] (LM I 277) : HE « רגל הוא רפואה להראה, כידוע לחכמי הרפואות » ; FR « Le pied (de bête) est un remède pour le poumon ». « (de bête) » est ajouté sans appui dans l'hébreu ; l'anglais dit simplement « Foot is a remedy for the lung ».
- sections[290].blocs[34] (LM II 5) : HE « שיש יחיד קדמון יתברך » ; FR « qu'il existe un Unique Éternel (Ya'hid Kadmon) ».
- sections[346].blocs[7] (LM II 61) : HE « כל הזמן שעבר עליו » ; FR « tout le temps qui lui sera passé ».

**Correction proposée.** Corrections :
- 356:25 FR : « …c'est-à-dire l'aspect des mo'hin, l'aspect de la douceur (noam) : ceux qui se rendent agréables l'un à l'autre dans la halakha, comme on l'a dit plus haut. »
- 276:27 FR : « Le pied (reguel) est un remède pour le poumon, comme le savent les savants médecins. »
- 290:34 FR : « …qu'il existe un Unique primordial (Ya'hid Kadmon), béni soit-Il… »
- 346:7 FR : « …tout le temps qui aura passé sur lui depuis le jour de la création du monde… »
Mesure : relecture humaine ciblée des citations talmudiques expliquées dans le texte (les formules « שאמרו רבותינו » et « כמו שדרשו »).

### LMTITRES-05 — FR : noms propres bibliques en deux systèmes concurrents (Moïse/Moché, Jacob/Ya'akov/Yaakov, Joseph/Yossef…), avec une bascule vers les formes latines dans le dernier tiers

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le français mélange les formes hébraïques et les formes françaises classiques. Le changement se fait par lots de sections : les deux premiers tiers emploient surtout les formes hébraïques, le dernier tiers surtout les formes latines. Un même verset peut ainsi porter deux noms différents. L'anglais est homogène (Moses 412, Jacob 253…). Décompte sur tout le livre, entre parenthèses pour le dernier tiers :
- Moïse 186 (123) / Moché 238 (27) ;
- Abraham 75 (27) / Avraham 87 (1) ;
- Jacob 105 (45) / Ya'akov 154 (7) / Yaakov 103 (7) ;
- Joseph 69 (26) / Yossef 44 (0) ;
- Isaac 22 (18) / Yits'hak 60 (0) / Its'hak 4 (4) ;
- terre d'Israël 224 (109) / Erets Israël 51 (0) ;
- Égypte 86 / Mitsraïm 3 ;
- Jérémie 3 / Yirmeya 65 ; Isaïe 2 / Yecha'ya 337 ; Josué 8 / Yehochoua 52 ;
- Melakhim 24 / Rois 13 ; Psaume(s) 11 / Tehilim 745.

**Preuve.** livre_likoutei_moharan.json (décompte : noms.py) :
- Même verset (Ps 81:5) : sections[290].blocs[0] FR « une ordonnance du Dieu de Yaakov » ; sections[293].blocs[0] FR « une règle du Dieu de Jacob ».
- sections[290].blocs[133] FR « ce que même Moché, de son vivant, n'a pas saisi » ; sections[292].blocs[3] FR « ce n'est que Moïse notre maître » ; sections[292].blocs[4] FR « Car Moïse notre maître avait une compassion véritable ».
- sections[356].blocs[25] FR « c'est l'aspect de Jacob … c'est l'aspect de Joseph », alors que les deux premiers tiers écrivent Ya'akov et Yossef.
- sections[300].blocs[9] FR « comme l'a dit le prophète Jérémie », contre « Yirmeya » 65 fois ailleurs.
- sections[292].blocs[58] FR « (Yecha'ya …) », alors que sections[292] cite ailleurs « Isaïe ».

**Correction proposée.** Fixer une règle de glossaire et l'appliquer par script avec bornes de mot. Les formes hébraïques sont majoritaires dans le livre et dans le reste de l'application : Moché, Avraham, Yits'hak, Ya'akov, Yossef, Aharon, Eliyahou, Erets Israël, Mitsraïm, Yirmeya, Yecha'ya, Yehochoua, Tehilim. Exemples de correction :
- 293:0 FR : « …car c'est une loi pour Israël, une ordonnance du Dieu de Ya'akov » (Tehilim 81).
- 292:3 FR : « Or un tel être compatissant, ce n'est que Moché notre maître ».
- 300:9 FR : « comme l'a dit le prophète Yirmeya ».
Relire ensuite les versets, où le nom est parfois glosé.

### LMTITRES-06 — FR : translittérations concurrentes (« Che'hina » contre « Chekhina », « 'h » mis pour le kaf, orthographes anglaises « tefillin », « Midrash »)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le français emploie ailleurs « kh » pour le כ et « 'h » pour le ח, mais ne s'y tient pas, et certaines sections du dernier tiers reprennent l'orthographe anglaise. « Che'hina » (22 occurrences, toutes dans le dernier tiers : LM II 67, 77, 83, 84, 91) note un ח qui n'existe pas, face à « Chekhina » 144. Autres paires concurrentes :
- Bera'hot 9 / Berakhot 170 ;
- hala'ha 20 / halakha 28 ; hala'hot 14 / halakhot 31 ;
- Ho'hma 10 / Hokhma 40 ; Ei'ha 14 / Eikha 30 ; Mi'ha 8 / Mikha 9 ;
- Mela'him 7 / Melakhim 24 ; Mala'hi 7 / Malakhi 19.
À cela s'ajoutent des orthographes anglaises en français : « tefillin » 9 fois (LM II 67, 72, 77) contre « tefilines/tefilin » ; « Midrash » 10 contre « Midrach » 76. Restent d'autres doublets : Roch HaChana 10 / Roch Hachana 71 ; tsédaka 59 / tsedaka 294 ; Ba'al Chem Tov 3 / Baal Chem Tov 11 ; Chir haChirim 8 / Chir HaChirim 69 / Cantique 6 ; kelipot 76 / klipot 13 ; Sitra A'hra 69 / sitra a'hra 10. Les variantes se regroupent par sections, ce qui trahit des lots de traduction distincts.

**Preuve.** livre_likoutei_moharan.json :
- sections[352].blocs[4] : HE « כי שכינה במערב (ב"ב כה) » ; FR « car la Che'hina est à l'occident (Baba Batra 25) ».
- sections[368].blocs[16] : HE « השכינה מכסה דמהון באהבה » ; FR « la Che'hina couvre leur sang avec l'amour ».
- sections[362].blocs[6] : FR « le passage de la lanière) des tefillin ».
- sections[286].blocs[12] : FR « (Midrash Rabba, Vayéra, section 56 ».
Décompte complet : termes.py et le script de translittération.

**Correction proposée.** Règle de glossaire : « kh » pour כ, « 'h » pour ח, formes françaises pour les mots courants. Corrections :
- 352:4 FR : « car la Chekhina est à l'occident (Baba Batra 25a) » ;
- 368:16 FR : « la Chekhina couvre leur sang avec l'amour » ;
- 362:6 FR : « des tefilines » ;
- 286:12 FR : « (Midrach Rabba, Vayéra, section 56 ».
Remplacer ensuite par script : Che'hina → Chekhina, Bera'hot → Berakhot, hala'ha(ot) → halakha(ot), Ho'hma → Hokhma, Ei'ha → Eikha, Mi'ha → Mikha, Mela'him → Melakhim, Mala'hi → Malakhi, tefillin → tefilines, Midrash → Midrach, Roch HaChana → Roch Hachana, tsédaka → tsedaka, Ba'al Chem Tov → Baal Chem Tov.

### LMTITRES-07 — FR+EN : les 411 titres sont justes, mais leur nom (« Enseignement 25 – Tinyana ») ne correspond ni aux renvois du reste de l'application (« Likoutei Moharan II, 25 ») ni à ceux du texte (« siman 25 », « Likouté Moharan »)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les titres de sections sont irréprochables en eux-mêmes (voir les points forts). En revanche, ils ne permettent pas de retrouver une leçon citée ailleurs. Le 'hizouk et la bibliothèque renvoient à « Likoutei Moharan II, 25 » (24 occurrences de « Likoutei Moharan II » dans chizuk.json, 18 dans bibliotheque.json, 10 et 8 de « LM II »). Le livre, lui, n'emploie jamais « II » et nomme la leçon « Enseignement 25 – Tinyana » ou « Lesson 25 – Tinyana ». La partie I n'a aucune marque. À l'intérieur du texte, les renvois disent « siman N » (FR 76, EN 55), mêlés à « Enseignement/Lesson N » (FR 6, EN 7). Le français écrit encore 22 fois « Likouté Moharan », et une fois « Likouté Tinyana », alors que le titre du livre dans l'application est « Likoutei Moharan ». Un lecteur qui suit l'invitation du guide à lire « Likoutei Moharan II, 25 » doit deviner que Tinyana veut dire II.

**Preuve.** livre_likoutei_moharan.json :
- sections[310] : titre « תנינא תורה כה », titre_fr « Enseignement 25 – Tinyana », titre_en « Lesson 25 – Tinyana ».
- res/raw/chizuk.json : « Likoutei Moharan II, 25 » (7 fois), « LM II, 25 ».
- sections[377].blocs[0] : FR « comme il est expliqué dans le premier livre (siman 205) », pour une section intitulée « Enseignement 205 ».
- sections[297].blocs[13] : FR « (voir Likouté Moharan I, 19) ».
- sections[168].blocs[4] : FR « (Vois à ce sujet dans Likouté Tinyana, siman 2.) ».
Décompte : titres_verif.py et grep sur RAW.

**Correction proposée.** - Titres : titre_fr « Enseignement 25 (II – Tinyana) » et titre_en « Lesson 25 (II – Tinyana) » ; pour la partie I, « Enseignement 282 (I) » et « Lesson 282 (I) ». Le changement se fait par script sur livres.json.
- Dans le texte français : remplacer « Likouté Moharan » par « Likoutei Moharan » (22 blocs) et « Likouté Tinyana » par « Likoutei Moharan II (Tinyana) ».
- Renvois internes : soit garder « siman » et ajouter au glossaire « siman = enseignement », soit écrire « enseignement 205 » et « Lesson 205 » partout.
- Dans chizuk et bibliotheque, écrire « Likoutei Moharan II (Tinyana), 25 ».

### LMTITRES-08 — EN : translittérations concurrentes localisées dans quelques sections (Shekhinah/Shechinah, Malkhut/Malchut, Chokhmah/Chochmah, Arukh/Aruch, Moshe/Moses, Messiah/Mashiach)

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** L'anglais est bien plus homogène que le français, mais des lots de sections changent de système. Paires concernées :
- Shechinah 162 / Shekhinah 4, toutes en LM II 1 et 2 ;
- Malchut 274 / Malkhut 7 et Chochmah 43 / Chokhmah 7, tous dans un seul bloc de LM I 280 ;
- Rosh Hashanah 79 / Rosh HaShanah 4 ;
- Shulchan Aruch 4 / Shulchan Arukh 1 ;
- Moses 412 / Moshe 13 ; Mashiach 75 / Messiah 10 ;
- tzaddik 722 / Tzaddik 13 (majuscule hors début de phrase) ;
- « horn » / « shofar » pour le même verset (Ps 81:4).

**Preuve.** livre_likoutei_moharan.json :
- sections[286].blocs[91] : EN « the Divine Presence (Shekhinah) ».
- sections[279].blocs[9] : EN « [Chokhmah, Binah, Da'at] of Asiyah … and Malkhut of Asiyah ».
- sections[286].blocs[93] : EN « Shulchan Arukh, Orach Chaim, siman 393 ».
- sections[286].blocs[0] : EN « Blow the horn » ; sections[293].blocs[0] : EN « Blow the shofar ».

**Correction proposée.** Remplacer par script : Shekhinah → Shechinah ; Malkhut → Malchut ; Chokhmah → Chochmah ; Rosh HaShanah → Rosh Hashanah ; Shulchan Arukh → Shulchan Aruch ; horn → shofar dans Ps 81:4. Par exemple, 279:9 EN : « [Chochmah, Binah, Da'at] of Asiyah … and Malchut of Asiyah ».

### LMTITRES-09 — FR+EN : lettres hébraïques nues dans deux intertitres (« lettre י », « lettre ד ») illisibles pour qui ne lit pas l'hébreu

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Sur les 80 blocs dont la traduction garde des lettres hébraïques (14 dans le dernier tiers), presque tous le font à dessein, pour des guématries ou des acronymes glosés : c'est justifié. Seuls les intertitres du « nouvel Alef-Beit » gardent une lettre seule, sans son nom.

**Preuve.** livre_likoutei_moharan.json :
- sections[305].blocs[0] : HE « מריבה אות י » ; FR « Querelle (meriva), lettre י » ; EN « Strife (merivah), letter י ».
- sections[311].blocs[0] : HE « שכרות אות ד' » ; FR « Ivresse, lettre ד » ; EN « Drunkenness, letter ד ».

**Correction proposée.** - 305:0 FR : « Se rattache au nouvel Alef-Beit – Querelle (meriva), lettre Youd (י) » ; EN : « …letter Yud (י) ».
- 311:0 FR : « …Ivresse, lettre Dalet (ד) » ; EN : « …letter Dalet (ד) ».
