# HICHT — Hichtapkhout haNefesh et Kokhvei Or — qualité FR et EN

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

16 constats — confirmés : 2 · confirmés en partie : 2 · non contre-expertisés (mineurs et cosmétiques) : 12.

> Contre-expertise incomplète pour cette dimension.

## Ce qui a été examiné

Conventions de preuve : H = android/app/src/main/res/raw/livre_hichtapkhout.json, K = android/app/src/main/res/raw/livre_kokhvei_or.json ; « H72.0 » = textes[0].sections[72].blocs[0] (indices JSON à partir de 0 ; dans H, sections[i] porte le titre « Section i−1 »). Scripts, échantillon et notes : OUT/HICHT/ (s1.py à s13.py, sample.py, echantillon.txt, notes.txt). Aucun fichier modifié hors de ce dossier.

BALAYÉ EN ENTIER PAR SCRIPT : 840 blocs, soit 610 blocs traduits (H 399, K 211 ; 416 000 caractères d'hébreu sans voyelles, 769 000 de français, 731 000 d'anglais), 230 champs c et 121 titres. Contrôles : blocs vides (0) ; français identique à l'anglais (1, « (Ibid.) », légitime) ; traduction identique à l'hébreu (0) ; même traduction pour deux hébreux (0) ; balises et marqueurs (0 balise ; 130 appels de note) ; mots de l'autre langue (0) ; lettres hébraïques dans les traductions (49 blocs, 876 lettres, identiques dans les deux langues : 38 blocs de guématries voulus, 11 blocs de renvois « Lettre מו » non voulus) ; rapports de longueur, avec lecture des 15 cas extrêmes de chaque côté et de chaque langue (une trentaine de blocs distincts) ; fins de blocs (21 sans ponctuation finale : 17 coupures de la source, 3 titres collés, 1 « Rachi ») ; guillemets et parenthèses ; nombres (français et anglais identiques partout sauf trois graphies de livres bibliques ; 211 numéraux entre parenthèses et 365 couples mot-clé + numéral comparés à l'hébreu) ; tables de variantes (Nom divin, tsadik, hitbodedout, Rabbi Na'hman, Rabbi Natan, livres, eulogies, noms propres) ; sonde des « se garder de » du français et sonde de polarité français / anglais phrase à phrase (249 blocs alignables, 47 phrases suspectes lues : rien de plus).

LU DE PRÈS : 110 blocs tirés avec random.seed(20261112), une strate de position par bloc (70 dans H, 40 dans K), après avoir rejoué le tirage de l'auditeur précédent (114 blocs, même graine) pour l'exclure. Cela représente 39 000 + 32 000 caractères d'hébreu, 17 % du texte. Le fichier echantillon.txt (hébreu, français, anglais côte à côte) a été lu en entier.

DÉCOMPTE FRANÇAIS : 110 blocs lus ; 2 avec erreur grave (faux sens sur une notion kabbalistique : H72.0, K5.36) ; 13 avec erreur légère ; 95 sans remarque. Hichtapkhout : 70 lus, 1 grave, 9 légers (H0.24, H0.42, H0.59, H17.0, H41.0, H45.0, H53.0, H95.7, H97.1). Kokhvei Or : 40 lus, 1 grave, 4 légers (K5.4, K5.20, K6.0, K15.15).

DÉCOMPTE ANGLAIS : 110 blocs lus ; 2 avec erreur grave (les deux mêmes) ; 8 avec erreur légère ; 100 sans remarque. Hichtapkhout : 70 lus, 1 grave, 6 légers (H0.42, H17.0, H41.0, H45.0, H89.1, H97.1). Kokhvei Or : 40 lus, 1 grave, 2 légers (K5.4, K5.20).

HORS ÉCHANTILLON : j'ai vérifié sur l'hébreu les signalements laissés par l'auditeur précédent. Confirmés : K15.1 (règle inversée en français, anglais juste), K4.0, H0.33, H93.1, H102.0, K0.1, K5.62, K9.0. Écarté : « Michaël », conforme à la translittération maison. La sonde « se garder de » a trouvé une seconde inversion française (H72.7) dans un bloc qu'il avait noté sans erreur : ses jugements « rien à signaler », que je n'ai pas repris, ne sont donc pas sûrs. En réunissant les deux tirages (224 blocs, 37 % du corpus), on connaît au moins 5 blocs graves en français (K15.1, H72.7, H72.0, K5.36, K4.0) et 3 en anglais (H72.0, K5.36, K4.0). Extrapolation prudente aux 610 blocs : une quinzaine de blocs à corriger sur le fond en français, une huitaine en anglais ; l'intervalle est large.

ORIGINE DES DEUX LANGUES : le français et l'anglais ont été produits ensemble à partir de l'hébreu. Ils partagent les mêmes gloses, les mêmes crochets, les mêmes chiffres et les mêmes faux sens (« espèce amère » / « bitter species », « mon but » / « my purpose », « à pleine bouche » / « with a full mouth », « Lettre מו » / « Letter מו »). Le français n'est pas traduit de l'anglais : il a ses propres erreurs (K15.1, H72.7, « Alef-Hé », « redoutable ») et ses propres réussites (H89.1), et les versets suivent deux traditions distinctes. Conséquence : l'anglais ne peut pas servir de contrôle indépendant du français.

DÉJÀ CONNU : seule la limite générale l'est (« relues automatiquement (clés, balises) ; relecture humaine souhaitable », en tête de tools/traductions_textes.py et dans le champ traduction des deux livres). Aucun des constats ci-dessus ne figure dans FEUILLE_DE_ROUTE.md.

NON EXAMINÉ : environ 460 blocs (75 %) n'ont pas été lus de près, seulement balayés par script. Les notes de bas de page de Kokhvei Or sont absentes de l'application. L'exactitude des translittérations yiddish a été lue sans dictionnaire. Les références de versets ajoutées ont été vérifiées de mémoire (une trentaine), sans recherche web. La lecture de « בשמחת תורה בשבת ויום טוב » en K14.0 (« dans la joie de la Torah » ou « à Sim'hat Torah ») reste douteuse et n'est pas comptée. L'affichage réel sur Android et sur le web n'a pas été essayé ; seuls le code d'affichage des champs c et la présence des mêmes chaînes dans myhitbodedut-web/data/livres/ ont été contrôlés. La présence de ces deux livres dans l'application Nokia n'a pas été vérifiée.

## Ce qui tient

- Couverture complète : les 610 blocs de texte (399 + 211) ont un français et un anglais ; aucun bloc vide, aucune traduction recopiée de l'hébreu, aucun doublon, aucune balise résiduelle, aucun mot de l'autre langue. Les longueurs sont régulières (médiane 1,86 fois l'hébreu en français, 1,77 en anglais) et la trentaine de cas extrêmes lus ne montre ni troncature ni invention : les blocs « courts » sont du Zohar araméen ou du yiddish dont la glose hébraïque a été fondue à bon escient.
- Chiffres fiables : toutes les valeurs numériques de l'hébreu (guématries de Kokhvei Or) sont reprises à l'identique dans les deux langues ; les 211 numéraux hébraïques de références entre parenthèses sont convertis sans erreur, et les deux fautes de la source (Moèd Katan 25, Tehilim 57) sont corrigées avec raison ; la trentaine de références de versets ajoutées que j'ai vérifiées sont justes.
- Passages difficiles bien traités : yiddish translittéré puis traduit (H29.0, K3.4, K3.70, K2.90), jeux de mots rendus lisibles par la translittération (K1.24 mit'hayev / me'houyav, H72.6 se'orim / se'arot, H66.0 keva, K4.6 acrostiche d'Amalek), lacune de la source comblée entre crochets (K2.90), libellé parasite du site repéré et isolé (K4.28).
- Convention du Nom divin tenue d'un bout à l'autre : « Hachem » / « Hashem » en prose (590 fois dans chaque langue), « l'Éternel » / « the LORD » dans les versets (environ 176), « béni soit-Il » stable (748), jamais « D.ieu » ni « G-d » ; « tsadik », « techouva », « hitbodedout » gardent une seule graphie par langue.
- Les récits de Kokhvei Or (parties I et II) sont fluides et exacts : sur les 40 blocs lus, 35 n'appellent aucune remarque en français et 37 en anglais ; sur l'ensemble des 110 blocs lus, 86 % sont sans remarque en français et 91 % en anglais.
- Les citations talmudiques et midrachiques sont reconnues et traduites comme telles (Avoda Zara 5, Yoma 86, Midrach Rabba, Tana Dévé Éliyahou), les versets français et anglais suivent chacun une tradition identifiable et, pour l'essentiel, la même formulation d'une occurrence à l'autre (Hochéa 14:3 identique dans six blocs).

## Constats

### HICHT-01 — FR — Kokhvei Or, partie IV : la règle sur la boisson est inversée (« se garder… de réduire »)

**Gravité** : bloquant · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : texte

**Constat.** Le français prescrit le contraire de l'hébreu. « Se garder de + infinitif » signifie « s'abstenir de » : la phrase dit donc qu'il faut soigneusement éviter de réduire l'alcool, y compris le Chabbat, les fêtes et Sim'hat Torah, alors que l'auteur demande de le réduire le plus possible. L'anglais est juste. C'est un calque de לזהר ל… ; le même calque fait une seconde victime en H72.7 (constat suivant).

**Preuve.** android/app/src/main/res/raw/livre_kokhvei_or.json, textes[0].sections[15].blocs[1] (« Partie IV – Allégresse et Joie », premier paragraphe après les prières). HE : « כי מאד צריכין לזהר למעט בשתית משקין המשכרין בכל האפשרות גם בשבת ויום טוב, [ואפלו בשמחת תורה ולא כטועים בזה] ». FR : « Car il faut se garder très soigneusement de réduire autant que possible la consommation de boissons enivrantes, même le Chabbat et les jours de fête [et même à Sim’hat Torah (121), et non comme ceux qui se trompent à ce sujet] ». EN (juste) : « For one must take great care to minimize the drinking of intoxicating beverages as much as possible ». Même chaîne dans myhitbodedut-web/data/livres/kokhvei_or.json et dans android/app/src/main/livres/livres.json.

**Correction proposée (revue par le contre-expert).** FR : « Car il faut veiller très soigneusement à réduire autant que possible la consommation de boissons enivrantes, même le Chabbat et les jours de fête [et même à Sim’hat Torah (121), et non comme ceux qui se trompent à ce sujet], et à plus forte raison les jours profanes ». Corriger dans livres.json, puis relancer la découpe et le build web.

**Note du contre-expert.** J'ai rouvert livre_kokhvei_or.json, sections[15].blocs[1] : l'hébreu dit « צריכין לזהר למעט בשתיית משקין המשכרין » (veiller à réduire). Le français porte bien « se garder très soigneusement de réduire », qui prescrit l'inverse, et la même chaîne se trouve dans livres.json et dans la copie web kokhvei_or.json. Un relevé par script des « se garder » dans les deux livres donne 6 occurrences, dont 2 fautives (K15.1 et H72.7), ce qui confirme qu'il y en a deux. La correction proposée est juste, mais elle supprime l'appel de note « (121) » (קכא), qu'il faut garder.

### HICHT-02 — FR — Hichtapkhout, Section 71 : même calque « se garder de », consigne sur la pensée inversée

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : texte

**Constat.** Le français dit de « se garder… de saisir sa pensée », c'est-à-dire de s'en abstenir, alors que l'hébreu demande de veiller à tenir sa pensée pour qu'elle ne s'échappe pas (enseignement sur la pureté de la pensée pendant la prière). L'anglais est maladroit mais non inversé. Bloc que l'auditeur précédent avait noté sans erreur.

**Preuve.** android/app/src/main/res/raw/livre_hichtapkhout.json, textes[0].sections[72].blocs[7] (titre « Section 71 »). HE : « ולהמשיך על עצמו קדשה שישמר את עצמו מעתה על כל פנים לתפס מחשבתו לבל תצא לחוץ ». FR : « et d’attirer sur soi une sainteté, pour se garder désormais, en tout cas, de saisir sa pensée afin qu’elle ne sorte pas au-dehors ». EN : « to guard oneself from now on at least to grasp one’s thought so that it does not stray outside ».

**Correction proposée.** FR : « et d’attirer sur soi une sainteté, afin de veiller désormais, à tout le moins, à tenir sa pensée pour qu’elle ne s’échappe pas au-dehors ». EN : « and to draw holiness upon oneself, so that from now on one at least takes care to hold on to one’s thought, so that it does not stray outside ».

**Note du contre-expert.** Dans livre_hichtapkhout.json, sections[72] (« Section 71 »), blocs[7], l'hébreu « שישמר את עצמו מעתה על כל פנים לתפוס מחשבתו לבל תצא לחוץ » demande de veiller à retenir sa pensée. Le français « se garder désormais, en tout cas, de saisir sa pensée » dit qu'il faut s'en abstenir, ce qui contredit la fin de la phrase. L'anglais est gauche mais pas inversé. Les corrections FR et EN proposées sont fidèles.

### HICHT-03 — FR+EN — Notions de kabbale et de 'hassidout mal rendues (mêmes faux sens dans les deux langues)

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** Six expressions techniques sont mal comprises ; cinq le sont à l'identique en français et en anglais, ce qui montre que les deux langues sortent d'une même lecture de l'hébreu et ne se contrôlent pas l'une l'autre. Mesure : 2 blocs sur les 110 de mon échantillon (H72.0, K5.36) plus K5.4 en français seul ; 3 autres dans l'échantillon de l'auditeur précédent, vérifiés sur l'hébreu (K4.0, H102.0, K9.0). Ordre de grandeur pour 610 blocs : une quinzaine de cas.

**Preuve.** Clés : H = livre_hichtapkhout.json, K = livre_kokhvei_or.json, « H72.0 » = textes[0].sections[72].blocs[0].
(a) H72.0 (Section 71, d'après Likouté Moharan I, 50) : « על-ידי פגם הברית הוא בבחינת מין מרירין » → FR « il est dans l’aspect d’« espèce amère » », EN « in the aspect of “a bitter species” ». מין = מיין (araméen) : les eaux amères, opposées à la douceur de la prière dont parle la phrase.
(b) K5.36 : « בליל שבת עת קבלת המלכות מֵאוֹרָהּ הנפלא, להיות מכנה על ידי זה בשם "שדה תפוחים" » → FR « au moment de l’accueil de la Royauté, sa lumière merveilleuse, elle qui est alors appelée « le champ des pommiers » », EN « at the time of receiving the Kingship, her wondrous light, she being called thereby “the field of apples” ». מֵאוֹרָהּ = « de sa lumière » : c'est la Malkhout qui reçoit de la lumière de Bina.
(c) K4.0 : « ראשי התנינים שעליהם המטמאים והמתעבים שמני הדעת… (כל אשר יחכם יותר נכרכים אחריו יותר) » → FR « les têtes des monstres marins sur lesquels se trouvent ceux qui souillent et rendent abominables les huiles du savoir… (plus quelqu’un devient sage, plus elles s’attachent à lui) », EN « the heads of the sea-monsters upon which are those who defile… ». Les monstres sont sur les eaux (Tehilim 74:13) et ce sont eux qui souillent.
(d) H102.0 (Section 101) : « ספר המדות… אות ישועה סימן ג'… ועין שם גם אות התבודדות » → FR « lettre « Yechoua » [salut], § 3 … lettre « Hitbodedout » », EN « the letter “Yeshuah” … the letter “Hitbodedut” ». אות désigne ici une rubrique du Sefer HaMidot.
(e) K5.4, FR seul : « נון שין מם הא » → « Noun Chin Mem Alef-Hé » (EN « Nun Shin Mem Hei », juste).
(f) K9.0 : « החשך המחשיך אנפי בריתא » → « les ténèbres qui assombrissent la face du monde » / « the face of the world ».

**Correction proposée (revue par le contre-expert).** (a) Garder la correction « eaux amères (mayin meririn) » / « bitter waters », et l'étendre à Likouté Etsot, sections[7].blocs[43] : « eaux amères, eaux impures, semence impure… eaux douces, eaux pures, semence sainte » / « bitter waters, impure waters, impure seed… sweet waters, pure waters, holy seed ». Faire de même dans sections[49].blocs[47]. (b) Lever l'ambiguïté de « sa » : FR « que l’on récite le vendredi soir, moment où la Malkhout (Royauté) reçoit de la lumière merveilleuse de celle-ci [la Mère, Bina] et prend de ce fait le nom de « champ des pommiers » » ; EN « recited on Friday night, when Malkhut (Kingship) receives from her [the Mother’s, Binah’s] wondrous light and is thereby called “the field of apples” ». (c), (d) et (e) : garder les corrections proposées ; (d) est de gravité mineure. (f) : supprimer ce point.

**Note du contre-expert.** Trois cas sont réels. (a) H72.0 : l'hébreu est vocalisé מַיִן (patah, yod, hiriq : mayin, « eaux »), donc « espèce amère » est un faux sens ; il se répète dans likoutei_etsot (sections[7].blocs[43], six fois « espèce », et sections[49].blocs[47]). (b) K5.36 : מֵאוֹרָהּ veut dire « de sa lumière », il ne s'agit pas d'une apposition. (c) K4.0 : la lecture qui rattache les monstres aux eaux (Ps 74:13) est la meilleure. En revanche, (d) « lettre » pour אות est un calque bibliographique mineur, pas une notion de kabbale ; (e) « Alef-Hé » est une erreur de transcription en français seul ; et (f) est réfuté, car בְּרִיָתָא peut désigner la création, ce qui rend « la face du monde » défendable. Il reste donc 3 cas de faux sens communs aux deux langues, et non 5 ; quant à l'estimation d'« une quinzaine » de cas, aucun chiffre ne l'étaye.

### HICHT-04 — FR+EN — Le vocabulaire central change selon les lots de traduction (לפרש שיחתו, להתבודד, שיחה, אדמו"ר…)

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** Les deux livres ont été traduits par lots sans glossaire commun : Hichtapkhout a trois coutures nettes (sections[0–72], [73–103], [104]), Kokhvei Or trois aussi (sections[0–2], [3–4], [5–15]). L'expression qui donne son titre au recueil, לפרש שיחתו (72 occurrences dans Hichtapkhout), est rendue de quatre façons, dont deux boiteuses en français. Le lecteur ne reconnaît plus qu'il s'agit du même geste.

**Preuve.** Comptages par script sur les 610 blocs.
• לפרש שיחתו — FR : « épancher ses paroles » 26 (H0–H5), « épancher sa conversation » 24 (H8–H72, K1–K3), « exprimer son entretien » 18 (H75–H103), « exposer sa parole » 2 (H104). EN : « pour out his words » 28, « pour out his conversation » 27, « express his conversation » 18, « set out his words » 2. Ex. H8.0 « lorsqu’on épanche sa conversation devant Hachem » ; H76.3 « exprimant son entretien devant Lui ».
• להתבודד — FR « s’isoler » 24 fois (H0.54 : cinq fois « s’isolait / s’isoler » là où l'anglais dit « practice hitbodedut »), « faire hitbodedout » (H19.0, H29.0), « pratiquer la hitbodedout » ; « la hitbodedout » 112 contre « l’hitbodedout » 11 (K1–K3, ex. K3.44).
• שיחה — « conversation » 53 (H0–72) puis « entretien » 49 (H73–103). בחינת — « aspect de » puis « selon l’idée de » 32 fois (H73–98 seulement). עין — « Voir » 40 (H0–72), « Voyez » 25 (H73–103), « Vois » 17 (K5–15).
• אדמו"ר — « Rabbénou » (K1), « notre maître » (K2, 88 fois), « notre maître (Admour) » (K5, K15) ; רבנו dans H : « notre Rabbi » 25 / « Rabbénou » 28. מוהרנ"ת — « Rabbi Natan » (K0–4) puis « Moharnat » (K5–15). אנשי שלומנו — « nos compagnons » (K1.48), « les hommes de notre communauté » (K2.28), « les membres de notre cercle » (K3.0).
• סטרא אחרא — « Autre Côté » 20, « autre côté » 10 (H73–103), « sitra a’hra » 4.
• EN : « Likutey Moharan » 51 (H0–72 et K) / « Likutei Moharan » 32 ; « Chayei / Chayey Moharan » 14 / 6 ; « God forbid » 92 / « Heaven forbid » 16 (H104, K3–4) ; « Mashiach » 26 / « Messiah » 9.

**Correction proposée (revue par le contre-expert).** Garder le glossaire proposé, en priorité pour les termes de fond : לפרש שיחתו, שיחה, בחינת, אדמו"ר/רבנו, מוהרנ"ת, סטרא אחרא. Les variantes de graphie et de formule (Likutey/Likutei, God/Heaven forbid, Voir/Voyez/Vois) relèvent d'une passe cosmétique séparée. Dans les récits, « s’isolait » peut rester acceptable, mais « pratiquait la hitbodedout » reste préférable pour que le lecteur reconnaisse le terme technique.

**Note du contre-expert.** Les décomptes refaits par script sur les 610 blocs traduits concordent pour l'essentiel : « épancher ses paroles » 26 (H0–H5), « épancher sa conversation » 26, « exprimer son entretien » 19 (H75–H103), « exposer sa parole » 2 (H104). אדמו"ר donne « Rabbénou » en K1 mais « notre maître » 78 fois en K2 ; « selon l’idée de » apparaît 31 fois, uniquement en H73–98 ; aucun glossaire n'est documenté dans R/tools ni dans R/FEUILLE_DE_ROUTE.md. Il faut toutefois nuancer. Les « coutures » sont plus nombreuses et moins nettes qu'annoncé : une rupture après H5, et des « épancher » isolés en H73–104. « Voyez » apparaît 13 fois, pas 25. « s’isoler » pour להתבודד est littéralement juste. Enfin, les variantes Voir/Voyez/Vois, Likutey/Likutei, God/Heaven forbid et Mashiach/Messiah sont cosmétiques.

### HICHT-05 — FR (4 cas) et FR+EN (3 cas) — Faux sens locaux nés d'un mot à mot

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Un mot ou une tournure est pris à contre-emploi sans renverser l'enseignement. Le français en compte environ deux fois plus que l'anglais. Mesure : 3 blocs dans mes lectures (H97.1, H53.0, H73.0) et 3 signalés par l'auditeur précédent, confirmés sur l'hébreu (H93.1, H0.33, K5.62) ; ordre de grandeur : 3 % des blocs en français, 1,5 % en anglais.

**Preuve.** (a) H97.1, FR+EN : « מה יהיה התכלית ממני לעולם הבא » → « Que deviendra mon but dans le monde à venir ? » / « What will become of my purpose in the World to Come? ».
(b) H93.1, FR : « הוא מתחזק בזה להאמין גם בעצמו שיש לו כח לפעל בתפלתו » → « pour croire, de lui-même aussi, qu’il a la force d’obtenir par sa prière » (« de lui-même » = spontanément).
(c) H0.33, FR : « שראוי לבזותו ולשקצו ולהסתיר פניו ממנו » → « qu’il mériterait d’être méprisé, dédaigné, et qu’on lui cache la face ».
(d) H53.0 (deux fois) et H79.2, FR : « וידין וישפט את עצמו » → « qu’il se juge et se condamne lui-même » ; EN « judge and evaluate himself ». Se juger n'est pas se condamner, nuance qui compte dans ce livre.
(e) K5.62, FR+EN : « "מקרב אחיהם כמוך" הכתובים שם מקדם » → « écrits là un peu plus loin » / « written there further on ». L'hébreu dit « auparavant » ; le traducteur a suivi l'ordre réel des versets (Devarim 18:15 puis 18:18) sans le dire.
(f) H73.0, FR+EN, Rachi sur Béréchit 30:8 : « וגם יכלתי שהסכים על ידי » → « et j’ai même réussi, puisqu’Il y a consenti à travers moi » / « for He consented through me ».

**Correction proposée.** (a) « Qu’adviendra-t-il de moi, au bout du compte, dans le monde à venir ? » / « What will ultimately become of me in the World to Come? ».
(b) « alors il se fortifie par là pour croire aussi en lui-même, croire qu’il a la force d’obtenir par sa prière ».
(c) « qu’il mériterait d’être méprisé, dédaigné, et qu’Il lui cache Sa face ».
(d) H53.0 « qu’il se juge et s’examine lui-même sur toutes ses affaires et ses actes » (les deux fois) ; H79.2 « on se juge et s’examine soi-même, et l’on se réprimande ».
(e) « écrits là auparavant [en réalité plus loin : Devarim 18:18] » / « written there earlier [in fact further on: Deuteronomy 18:18] ».
(f) « et j’ai aussi eu gain de cause : Il a accédé à ma demande » / « and I also prevailed: He acceded to my plea ».

### HICHT-06 — FR+EN — Renvois internes illisibles : « Lettre מו » / « Letter מו » (13 occurrences) et quatre systèmes concurrents

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Dans Hichtapkhout, les sections s'intitulent « Section 1 » à « Section 102 », mais treize renvois de l'auteur vers ses propres sections sont rendus « Lettre » ou « Letter » suivi du numéral hébraïque laissé tel quel. Ce sont les seules lettres hébraïques non voulues de tout le corpus. S'y ajoutent trois autres rendus du même renvoi, et à partir de sections[92] le mot « section » sert aussi pour les simanim du Likouté Moharan, juste à côté des renvois internes.

**Preuve.** livre_hichtapkhout.json, 11 blocs : sections[17].blocs[0] (deux fois), [24][1], [32][0], [40][0], [45][0], [48][0] (deux fois), [49][5], [50][3], [59][1], [62][0], [70][2]. Ex. H17.0 : « (וכמבאר מזה לעיל בסימן ט') … ומובא לקמן באות ס"ז » → « (comme expliqué plus haut, Lettre ט) … rapporté plus bas, Lettre סז » / « (as explained above, Letter ט) … brought below in Letter סז ». H24.1 « (et voir plus bas, Lettre מו) ». H70.2 « (voir plus bas, Lettre ק) ».
Autres rendus du même renvoi : « section 49 » (H0.31), « siman 34 » (H21.0, pour « ועין עוד לקמן סימן ל"ד »), « section 58 » (H73.0).
Ambiguïté : H92.0 « (Likouté Moharan I, section 2) … (voyez plus haut, section 47) » ; H103.7 « (Likouté Moharan II, section 73), recopié au début de ce livre, section 1 ».

**Correction proposée.** Correction par script dans les deux langues : Lettre ט → section 9 ; סז → 67 ; מו → 46 ; נט → 59 ; כג → 23 ; צג → 93 ; ב → 2 ; נו → 56 ; טז → 16 ; צא → 91 ; מה → 45 ; ל → 30 ; ק → 100 (EN « section 9 », etc.). H21.0 : « voir encore plus loin, section 34 ». Réserver « siman » au Likouté Moharan : H92.0 « (Likouté Moharan I, siman 2) », H103.7 « (Likouté Moharan II, siman 73) … (Likouté Moharan II, siman 25) », EN « siman 2 », « siman 73 », « siman 25 ».

### HICHT-07 — FR+EN — Kokhvei Or : 130 appels de note sans notes, changés en chiffres qui se mêlent aux guématries

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** L'hébreu de Kokhvei Or porte 130 appels de note en lettres, de (א) à (קל), le numéro 40 manquant dans la source ; les notes elles-mêmes ne sont pas dans l'application. Les traductions les ont convertis en (1)…(130). Dans la partie III, faite de valeurs numériques, l'appel devient indiscernable d'une guématrie : 55 appels dans 23 blocs, dont 15 blocs où appel et valeur se côtoient. En hébreu la confusion n'existe pas (lettres contre chiffres) : elle est créée par la traduction. Par ailleurs, le marquage des lettres par apostrophes (15 blocs) est tantôt expliqué, tantôt perdu.

**Preuve.** livre_kokhvei_or.json. K5.20 (sections[5].blocs[20]) : « בינה הוא בסוד "הוא" כי על כן הי ויו(נח) אלף במספר נחמן (148) » → « Hé, Vav (58), Alef (הי ויו אלף) a la valeur de Na’hman (148) » / « Hei, Vav (58), Alef (הי ויו אלף) equals Nachman (148) ». K5.4 : « — (51), avec le kolel, a aussi la valeur de « Na’hman ben Sim’ha » (553) ». K0.0 : « nos yeux de chair(1) … des machines(2) » (16 appels collés au mot, 113 précédés d'une espace). K15.5 : « Une femme vaillante (125), qui la trouvera ? ».
Lettres marquées perdues : K5.82 « כי נ'ח'ם ה' ציון' נ'ח'ם כל ח'רב'ותיה… ששון' ו'ש'מ'ח'ה » rendu comme un verset ordinaire ; K5.66 « ה'א'ו'ר כי ט'ו'ב » ; K15.5 « ב'ת ש'ב'ע », « ש'ל'מ'ה » ; K4.28 « בעק'ב'ו'ת משיחא ». Bien traitées en revanche : K4.6 (acrostiche d'Amalek glosé), K5.88 (initiales de Chimon), K5.78.

**Correction proposée.** Tant que les notes ne sont pas livrées, retirer les 130 appels des deux traductions (et de l'hébreu) par script sur les positions connues ; s'ils doivent rester, les mettre en exposant ou entre crochets [n. 58], jamais entre parenthèses. Exemples : K5.20 « Hé, Vav, Alef (הי ויו אלף) a la valeur de Na’hman (148) » / « Hei, Vav, Alef (הי ויו אלף) equals Nachman (148) » ; K5.4 « — « Noun Chin Mem Hé » (נון שין מם הא) —, avec le kolel, a aussi la valeur de « Na’hman ben Sim’ha » (553) » ; K0.0 « nos yeux de chair … des machines ». Pour K5.82, K5.66 et K15.5 : redonner entre parenthèses les mots hébreux avec leurs lettres marquées et dire que ce sont elles qui portent l'allusion, comme en K4.6.

### HICHT-08 — FR+EN — Défauts de la source reproduits ou maquillés par les traductions (blocs coupés, titres collés, numéro avalé, libellé du site)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le découpage hérité de la page d'or-breslev.co.il passe tel quel dans les deux traductions, et deux fois la traduction invente un raccord au lieu de signaler l'accident.

**Preuve.** (a) 17 blocs de Hichtapkhout s'arrêtent en pleine phrase, l'hébreu finissant par un point artificiel : sections[0].blocs[27], [0][37], [0][60], [1][47], [1][60], [4][1], [6][0], [8][0], [18][0], [53][0], [73][2], [78][2], [80][2], [95][0], [103][4], [104][22], [104][34]. Ex. H0.27 : « וזה יכול. » → « et cela, on peut » / « and this one can » ; H8.0 finit par « (Taanit » ; H104.22 finit par « l’aspect de Roch » et H104.23 commence par « ’Hodech, comme on l’a dit ». Conséquence : guillemets déséquilibrés dans 13 blocs par langue, parenthèses dans 11.
(b) Trois titres de partie collés en fin de bloc : K1.0 « …]. Anché Moharan », K5.0 « … l’une après l’autre. Sagesse et Compréhension », K6.0 « … ni le cœur concevoir. Allégresse et Joie ».
(c) K5.88 : le numéro de paragraphe 45 (« מה » ; les intertitres sautent de מד à מו) est resté dans le texte, « מה בינה הוא בסוד נשר », et a été traduit par un connecteur inventé : « De même, Bina est dans le mystère de l’aigle » / « Likewise, Binah is in the mystery of the eagle ».
(d) K4.28 : un libellé du site est entré dans l'hébreu, « ממלכותו ואמונתו- מנוקד עם באר היטב, כי זה כל תקונו », et il est traduit : « [mention : « vocalisé, avec Be’er Hétev »] » / « [note: “vocalized, with Be’er Heitev”] ». Seul cas du corpus (recherche par script).
(e) H0.42 : dittographie de la source reproduite, d'où une phrase absurde : « pour que Hachem, béni soit-Il, lui accorde des prières, des supplications et des requêtes venant de son cœur, dans une langue qu’il comprend, pour que Hachem, béni soit-Il, lui accorde le mérite de Le servir » (même chose en anglais).

**Correction proposée.** Corriger à la source (tools/livres_construction.py, fonctions hishtapchut et kokhvei_or, puis livres.json) : (a) recoller les 17 paires et retraduire la phrase de jonction ; (b) sortir les trois titres des blocs ; (c) créer l'intertitre « מה » et écrire « Bina est dans le mystère de l’aigle (נשר) » / « Binah is in the mystery of the eagle (נשר) » ; (d) ôter « מנוקד עם באר היטב » des trois langues : « … de sa royauté et de sa foi, car c’est là toute sa réparation » / « … from his kingship and his faith, for this is his entire rectification » ; (e) « … d’avoir l’habitude de prier devant Hachem, béni soit-Il, des prières, des supplications et des requêtes venant de son cœur, dans une langue qu’il comprend, pour que Hachem, béni soit-Il, lui accorde le mérite de Le servir » / « … prayers, supplications and requests from his heart, in a language he understands, that Hashem, blessed be He, grant him the merit to serve Him ».

### HICHT-09 — FR+EN — Titres de Kokhvei Or incohérents ; 230 intertitres (champs c) restés en lettres hébraïques

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les 105 titres de Hichtapkhout sont réguliers (« אות א » → « Section 1 », identique en anglais). Les 16 titres de Kokhvei Or rendent le même hébreu de trois façons et changent de numérotation en cours de livre. Les 230 champs c (35 dans H, 195 dans K) n'ont ni c_fr ni c_en : en lecture française ou anglaise seule, l'intertitre s'affiche « לז », alors que les traductions y renvoient par « § 8 » ou « section 8 ».

**Preuve.** livre_kokhvei_or.json, titre_fr / titre_en : sections[1] « חלק א' אנשי מוהר"ן · פתיחה » → « Première partie : Anché Moharan · Ouverture » / « Part One: Anshei Moharan · Opening » ; sections[2] (même partie) → « Première partie – Les disciples de Rabbi Na’hman · Avant-propos » / « Part One – The Disciples of Rebbe Nachman · Preface » ; sections[3] → « Première partie – Les disciples de Rabbénou · *** » / « Part One – Rebbe Nachman’s Disciples · *** » ; sections[4] « חלק ב' אמת ואמונה · פתיחה » → « Deuxième partie – Émet ve-Emouna (Vérité et foi) · Introduction » (פתיחה = « Ouverture » ailleurs) ; sections[5] → « Partie III – Sagesse et Compréhension · Introduction » ; sections[6–15] → « Partie IV – Allégresse et Joie ». Dans le texte, K0.1 traduit autrement : « ’Hokhma ouVina (Sagesse et intelligence) », « Anché Moharan (Les hommes de Moharan) ».
Champs c : 230 blocs {"c": "אות א"}, {"c": "לז"}… ; affichage en hébreu seul (Siddur.kt ligne 96, SiddurBloc(c, true) ; web/src/js/app.js ligne 1400). Renvoi : K2.84 « (עין לעיל אות ח') » → « (voir plus haut, section 8) ».

**Correction proposée.** Titres FR : « Première partie – Anché Moharan (Les hommes de Moharan) · Ouverture », « … · Avant-propos », « … · *** » ; « Deuxième partie – Émet ve-Emouna (Vérité et foi) · Ouverture » ; « Troisième partie – ’Hokhma ou-Vina (Sagesse et intelligence) · Introduction » ; « Quatrième partie – Sasson ve-Sim’ha (Allégresse et joie) · Ouverture », « … · Prière 1 » à « Prière 8 ». Titres EN : « Part One – Anshei Moharan (The Men of Moharan) · Opening / Preface / *** » ; « Part Two – Emet ve-Emunah (Truth and Faith) · Opening » ; « Part Three – Chochmah u-Vinah (Wisdom and Understanding) · Introduction » ; « Part Four – Sasson ve-Simchah (Gladness and Joy) · Opening / Prayer 1…8 ». Champs c : ajouter c_fr et c_en chiffrés (« 1 », « 2 »… ; « Section 1 » pour « אות א » dans la fin de Hichtapkhout), générés par script depuis la valeur de la lettre, et les afficher selon la langue de lecture.

### HICHT-10 — FR (et EN) — Formules d'eulogie fautives et instables (זכר צדיק לברכה, זצ"ל, זצל"הה)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** « De mémoire juste et bénie » n'est pas du français : c'est le tsadik qui est juste, pas la mémoire. La même formule hébraïque reçoit cinq rendus selon le lot, et dans Kokhvei Or la distinction que fait l'auteur entre ז"ל et זצ"ל disparaît à partir de sections[3].

**Preuve.** זכר צדיק לברכה (51 fois dans H) et זכר צדיק וקדוש לברכה (12) — FR : « de mémoire juste et bénie » 31 (H0–H2 ; ex. H0.24 « attribué à l’Ari, de mémoire juste et bénie »), « de mémoire sainte et bénie » 18 (H9–H70 ; ex. H45.0), « de mémoire juste et sainte bénie » 4 (H0.39), « que le souvenir du juste soit une bénédiction » 5 (H80–H104). EN : « of blessed memory », « of blessed and saintly memory » 18, « of righteous and holy blessed memory » 4 (H0.39).
זצ"ל (137 fois dans K) : « de sainte mémoire » / « of saintly memory » 119 fois en sections[0–2], puis « de mémoire bénie » / « of blessed memory », comme ז"ל.
הריני כפרת משכבו : « puissé-je être l’expiation de son repos » 27 (K2) / « de sa couche » 7.
K0.1 : « שמו הקדוש זצל"הה » → « que le souvenir du juste et saint soit pour la vie du monde futur » / « may the memory of the holy tzaddik be for the life of the World to Come » (« saint » ajouté, « bénédiction » omise).

**Correction proposée.** Règle : זכרונו לברכה et ז"ל = « de mémoire bénie » / « of blessed memory » ; זכר צדיק לברכה et זצ"ל = « de sainte mémoire » / « of saintly memory » dans le fil du récit, ou en toutes lettres « que le souvenir du juste soit une bénédiction » / « may the memory of the righteous be a blessing ». Exemples : H0.24 « attribué à l’Ari, de sainte mémoire » ; H0.39 « notre seigneur, maître et Rabbi, que le souvenir du juste et du saint soit une bénédiction » / « may the memory of the righteous and holy be a blessing » ; K0.1 « que le souvenir du juste soit une bénédiction pour la vie du monde futur » / « may the memory of the righteous be a blessing for the life of the World to Come » ; partout « puissé-je être l’expiation de son repos ».

### HICHT-11 — FR — « redoutable » pour נורא : 50 occurrences, 36 blocs

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** נורא (54 occurrences) est rendu presque mécaniquement par « redoutable », qui en français veut dire « qu'il faut craindre, dangereux ». Appliqué à Rabbi Na'hman, aux tsadikim, aux conseils ou aux aspirations, le mot est impropre. L'anglais « awesome » (49 fois) convient.

**Preuve.** K6.0 : « רבנו הנורא ותלמידו הקדוש » → « Notre redoutable Rabbi et son saint disciple ». K15.15 : « שהיו צדיקים נוראים כאלה » → « des Tsadikim si redoutables ». H0.59 : « בגעגועים וכסופין גדולים ונוראים מאד מאד » → « des aspirations et des désirs immenses et extrêmement redoutables ». H95.7 : « אור חדש נורא ונשגב כזה » → « une lumière nouvelle si redoutable et si sublime ». H63.0 : « un conseil merveilleux et redoutable ». H0.63 : « des secrets redoutables et extrêmement sublimes ». Ailleurs le même traducteur écrit correctement « des conseils extraordinaires et merveilleux » (H0.28).

**Correction proposée.** « Notre Rabbi prodigieux et son saint disciple » ; « des Tsadikim si prodigieux » ; « des aspirations et des désirs immenses et prodigieux » ; « une lumière nouvelle si prodigieuse et si sublime » ; « un conseil merveilleux et prodigieux » ; « des secrets prodigieux et extrêmement sublimes ». Passer en revue les 50 occurrences (regex \bredoutables?\b) et ne garder « redoutable » que là où il s'agit de crainte (K0.0 « ce spectacle grandiose et redoutable », K4.6 « l’attribut de rigueur saint et redoutable »).

### HICHT-12 — FR+EN — Calques qui obscurcissent le sens (בפה מלא, בפנים, פושעי ישראל…)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Plusieurs tournures sont décalquées de l'hébreu au point de dire autre chose, ou rien, en français et en anglais.

**Preuve.** (a) « בפה מלא » → « à pleine bouche » / « with a full mouth » : 7 occurrences, 5 blocs (H18.2, H57.1, H96.0, H97.1…). Ex. H96.0 « qu’il dise tel ou tel psaume à pleine bouche » / « with a full mouth ». En anglais, la tournure évoque une bouche pleine de nourriture.
(b) H41.0 : « ועין בפנים כל הענין » → « Voir à l’intérieur tout le sujet » / « See the whole matter inside ».
(c) H0.24 : « שצריך האדם להתבודד בינו לבין קונו » → « l’homme doit s’isoler entre lui et son Créateur » / « seclude himself between himself and his Maker ».
(d) H1.42 : « פושעי ישראל » → « fauteurs d’Israël » (« fauteur(s) » 3 fois ; en français, un fauteur est un instigateur).
(e) H95.7 : « ומחזיקנו ברחמיו בשבעה משיבי טעם כאלה » → « par de tels conseils pleins de sagesse » / « with such wise counsels » : l'allusion à Michlé 26:16 et le chiffre sept disparaissent.
(f) K2.18 : « קפיצת הארץ » glosé « (kefitsat haderekh) » / « (kefitzat haderech) » : ce n'est pas le mot du texte.

**Correction proposée.** (a) « à voix haute, en toutes lettres » / « out loud, in so many words » ; H96.0 « qu’il dise tel ou tel psaume à voix haute ». (b) « Voir tout le passage dans le texte d’origine » / « See the whole passage in the original text ». (c) « l’homme doit se retirer seul à seul avec son Créateur » / « a person must seclude himself, alone with his Maker ». (d) « les pécheurs d’Israël ». (e) « par ces « sept qui répondent avec sagesse » (Michlé 26:16) » / « with these “seven who answer wisely” (Proverbs 26:16) ». (f) « (kefitsat haarets) » / « (kefitzat haaretz) ».

### HICHT-13 — FR+EN — Appareil de références hétérogène ; références de versets ajoutées dans un seul lot, sans marque d'ajout

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le contenu chiffré des références est fiable (voir points forts), mais leur forme change selon le lot, et un lot ajoute chapitre et verset à des citations que l'hébreu laisse sans référence, sans le signaler.

**Preuve.** • סימן : « siman » 147 fois ; « section » pour le Likouté Moharan dans H76.5 et H92–H103 (11 fois) et pour Si’hot HaRan / ’Hayé Moharan en K2 ; « § » 30 fois en K ; rien en K4 (« Likouté Moharan I, 10 »). Dans un même bloc (H104.19) le français dit « siman 6 » et l'anglais « section 6 ».
• חלק א' : « tome I » 24 (H0–72), « première partie » 13, « Likouté Moharan I » 38.
• הלכות : « lois de » 47 / « Hilkhot » 21 (H73–103) ; « loi N » 18 / « halakha N » 38 / « hala’ha » 9 (H45.0, H57.2, H72.6) ; EN « Law 5 » 5 / « halachah » 54.
• דף rendu « page » 13 fois (H0.24 « Zohar, paracha Nasso, page 124 »).
• Références chapitre:verset absentes de l'hébreu : 112 en H73–H103, 14 en K3–K4, aucune ailleurs (109 dans l'anglais de H73–103). Une trentaine vérifiées de mémoire, toutes justes ; une discutable : H89.0 « כצאן לטבח יובל » → « (Yirmeya 11:19) », alors que la formule « לטבח יובל » est celle de Yecha’ya 53:7.
• Deux erreurs de la source corrigées sans marque : H1.26 « (מועד קטן כ"ה) » → « (Moèd Katan 28) » ; H1.48 « (תהלים נ"ז) » → « (Tehilim 27) ». Les deux corrections sont exactes.
• Livres bibliques : FR « Chmouel » 20 / « Chemouel » 8, « Tehilim » 152 / « Psaume(s) » 4, « Deutéronome » 1 ; EN « Psalms » 148 / « Tehillim » 5, « Shmuel » 20 / « Samuel » 8, « Vayikra » 2, « Bereshit » 1.

**Correction proposée.** Règle unique, appliquée par script puis relue : « Likouté Moharan I, 2 » / « Likutey Moharan I, 2 » ; « Likouté Halakhot, lois de …, halakha 5, § 22 » / « Likutey Halachot, Laws of …, halachah 5, § 22 » ; דף = « folio 124 » / « folio 124 » ; un seul nom par livre biblique (« Chmouel », « Tehilim » ; « Psalms », « Samuel »). Mettre entre crochets tout ce que le traducteur ajoute ou corrige : « [Hochéa 14:3] », « (Moèd Katan [28a ; le texte porte 25]) », « (Tehilim [27 ; le texte porte 57]) ». H89.0 : « [cf. Yecha’ya 53:7 ; Yirmeya 11:19] ». Étendre les références de versets aux autres lots ou les retirer partout.

### HICHT-14 — FR+EN — Noms bibliques et toponymes différents d'un livre à l'autre

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Hichtapkhout et Kokhvei Or ne suivent pas la même convention de noms propres. En anglais le partage est presque complet : formes anglaises dans le premier livre, formes hébraïques dans le second. Les villes d'Ukraine ont deux graphies.

**Preuve.** FR : « Moché » 86 / « Moïse » 8 (K2–K4) ; « Éliyahou » 11 / « Élie » 9 (K3–K4) ; « Yaakov » 37 / « Ya’akov » 11 (H0–49) / « Jacob » 1 ; « Its’hak » 51 / « Isaac » 5 / « Yits’hak » 2 ; « Chelomo » 7 / « Chlomo » 1 ; « Medjibojh » (H0.54) / « Medjybij » (K2.28) ; « Ladijin » 5 / « Ladyjine » 1 ; « Tcherin » 12 / « Tchéhrine » 2 ; « Toultchine » 2 / « Toultchin » 1.
EN : « Moses » 54 / « Moshe » 41 ; « Abraham » 17 / « Avraham » 18 ; « Jacob » 43 / « Yaakov » 6 ; « Isaac » 20 / « Yitzchak » 39 ; « Elijah » 17 / « Eliyahu » 3 ; « Shlomo » 5 / « Solomon » 3 ; « Berdichev » 9 / « Berditchev » 3 ; « Ladizhin » 5 / « Ladyzhin » 1 ; « Tcherin » 12 / « Chehrin » 2.
Remarque : « Michaël » pour מישאל (H0.19, H0.20) est conforme à la translittération maison (ch = ש) mais se lit en français comme le nom de l'ange.

**Correction proposée.** Glossaire unique. FR : « Moché », « Éliyahou », « Yaakov », « Its’hak », « Avraham », « Chlomo », « Medjibojh », « Ladijin », « Tcherin », « Toultchin » ; écrire « Michaèl » pour מישאל. EN : choisir une seule série pour les deux livres, par exemple « Moses, Abraham, Isaac, Jacob, Solomon, Elijah » pour les personnages bibliques et « Yitzchak », « Shlomo » pour les seuls disciples ; « Berdichev », « Ladizhin », « Tcherin ». Remplacement par script, en vérifiant chaque « Isaac / Yitzchak » (patriarche ou disciple).

### HICHT-15 — EN (et FR à la marge) — Versets : registre archaïque et moderne mêlés, même verset rendu de deux façons, une citation qui casse la démonstration

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les versets anglais suivent tantôt la langue de la JPS 1917 (thou, unto, hath : 56 blocs, 26 dans H et 30 dans K), tantôt un anglais moderne, parfois pour le même verset. Une fois, la formulation JPS fait disparaître le mot sur lequel repose l'enseignement.

**Preuve.** Tehilim 27:14 : H1.48 « be strong, and let your heart take courage; and wait for the LORD » contre H10.2 « let thy heart take courage; yea, wait thou for the LORD ». Yona 2:3 : H31.0 « Out of the belly of the netherworld cried I » contre H77.0 « Out of the belly of Sheol I cried ». Hochéa 14:3 : « return to the LORD » (5 blocs) contre H104.75 « return unto the LORD ».
H89.1 : « קרקעות הם בחינת תפלה שהיא בחינת אמונה שנקראת ארץ, כמו שכתוב: "שכן ארץ ורעה אמונה" » → « Dwell in the land and cherish faithfulness » : le lien avec « faith », objet de la phrase, est perdu (le français « nourris-toi de foi » le garde).
FR : Ekha 3:22, H10.3 « Ce sont les bontés de l’Éternel qui font que nous ne sommes pas anéantis » contre H98.2 « les bontés de l’Éternel ne sont pas épuisées » ; Tehilim 102:1, « Prière du pauvre, quand il est accablé » (H0.32 à H1.54) contre « la prière du pauvre quand il défaille » (H98.2).

**Correction proposée.** Un seul registre pour les versets anglais, le moderne (You / Your), déjà majoritaire. H10.2 : « Wait for the LORD; be strong, and let your heart take courage; and wait for the LORD » ; H31.0 : « Out of the belly of Sheol I cried » ; H104.75 : « return to the LORD » ; H89.1 : « Dwell in the land and feed on faith (emunah) ». FR : H10.3 « les bontés de l’Éternel ne sont pas épuisées, Ses miséricordes ne sont pas à bout » ; H98.2 « la prière du pauvre quand il est accablé ». Mesure d'ensemble : lister par script les 56 blocs à archaïsmes (\b(thee|thou|thy|unto|hath|ye)\b) et les réécrire.

### HICHT-16 — FR+EN — Scories typographiques (espace double avant « : », deux-points orphelins, graphies)

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Petits défauts mécaniques, tous corrigeables par script.

**Preuve.** • FR, 11 blocs de H : espace ordinaire puis espace insécable avant les deux-points, ex. H0.54 « siman 162  : », H1.1 « Avoda Zara 5  : », H0.24 « page 124  : ».
• Deux-points de fin de paragraphe de la source conservés après la ponctuation finale : 11 blocs FR, 10 EN (K3.4 « … tous les jours de ta vie. » : » / « …all the days of your life.”: » ; K3.6, K3.10, K3.12, K3.16, K3.28, K3.30, K5.82, K5.84, K10.0 ; H3.7 en français).
• H92.2 : « (hitoukh) » sans apostrophe pour ח, à côté de « ’Hodech », « ’hassid ».
• « d’Hachem » 12 fois (K3–K4) contre « de Hachem » 130.
• K6.0 : « dans la Mahadoura, Section 3 » avec majuscule.

**Correction proposée.** Script sur les champs fr et en : remplacer « espace + espace insécable + : » par « espace insécable + : » ; supprimer le « : » final qui suit « . », « » », « ” » ou « ) » ; « (’hitoukh) » ; « de Hachem » partout ; « section 3 ».
