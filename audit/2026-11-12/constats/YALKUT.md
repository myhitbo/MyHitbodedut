# YALKUT — Yalkut Yosef, Ben Ich ’Haï, hilloulot — traductions partielles et contenus en hébreu seul

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

11 constats — confirmés : 2 · confirmés en partie : 2 · non contre-expertisés (mineurs et cosmétiques) : 7.

## Ce qui a été examiné

Balayé en entier par script (scripts et sorties dans OUT/YALKUT) :
- Livre : les 14 303 blocs de RAW/livre_yalkut_yosef_kitsour.json, dont les 1 489 blocs traduits en FR et en EN et les 92 titres. Contrôles passés : blocs sans FR ou sans EN (aucun), FR identique à EN (aucun), traduction identique à l’hébreu (aucune), lettres hébraïques (1 bloc, voulu), balises et nombre de renvois &lt;small> (0 écart), accolades et marqueurs [n] (0), parenthèses non fermées (2, copiées de l’hébreu), fins de phrase coupées (0), doublons (0), numéro du se'if (100 % juste).
- Longueurs : rapports de longueur par bloc et par segment (2 939 segments de 40 caractères ou plus). Lus : les 15 extrêmes de chaque côté, pour chaque langue (60 segments), plus 8 blocs extrêmes et les blocs longs dont le nombre de phrases baisse. Aucune omission trouvée.
- Chiffres : 4 464 références chiffrées (0 erreur réelle) et 706 nombres écrits en toutes lettres en hébreu, dont les 236 non-retrouvés ont été lus (tous des faux positifs).
- Verdicts : comparaison permis/interdit/dispensé/valide/invalide/non quitte sur 2 939 segments ; les 141 alertes lues (0 inversion).
- Termes : une soixantaine de variantes comptées (Nom divin, tefilin, talit, Chéérit Yossef, Chema, lekhat’hila, etc.) ; mots anglais dans le français et l’inverse ; doubles négations ; tournures d’ordre « קודם / תחלה ».
- Rendu : le site construit a été rendu sans interface en fr et en en (59 paragraphes chacun). Android : lu dans le code (SiddurLectureActivity, LanguesTexte, Siddur.kt).
- Hilloulot : les 229 noms traduits de RAW/hilloulot.json (179 FR, 229 EN) lus en entier.

Lu de près :
- L’échantillon : 138 blocs tirés avec random.seed(20261112), au moins un dans chacune des 92 sections traduites, le reste au prorata. Fichier OUT/YALKUT/echantillon.txt, lu en entier, hébreu, FR et EN côte à côte.
- Environ 45 autres blocs lus hors échantillon (extrêmes, alertes de verdict et de chiffres, tournures d’ordre). Total : environ 183 blocs.

Décompte sur l’échantillon de 138 blocs :
- Français : 138 blocs lus. 2 avec erreur grave : n° 38 (sections[24].blocs[0], ordre des berakhot inversé) et n° 12 (sections[4].blocs[55], double négation qui inverse le sens). 5 avec erreur légère : n° 46, 50 et 53 (faux sens « de prime abord ») ; n° 97 (« Certains disent… ses propos ») ; n° 119 (« être passant outre »). Environ 8 autres avec une graphie concurrente seulement (talith, tefillin, hala’ha).
- Anglais : 138 blocs lus. 1 avec erreur grave (n° 38, la même que le français). Aucune erreur légère dans l’échantillon ; hors échantillon, 1 faux sens (sections[1].blocs[2]). Plusieurs blocs avec la graphie concurrente « Sheerit Yosef ».
- Les deux langues : 100 % des blocs traduits s’affichent avec leurs balises en clair, à cause de l’affichage et non de la traduction.

Origine de la sélection : elle n’est documentée nulle part, sauf dans le commit 6e6b4c7 du 04/11. On a traduit dans l’ordre du livre, avec des trous, et le travail s’arrête au bloc 19 de la section 139 (voir constat 10). La présentation au lecteur (aucun avertissement, retour silencieux à l’hébreu bloc par bloc) a déjà été établie dans OUT/COUV/couverture.md ; je l’ai vérifiée dans le code et ne la répète pas.

Halakha du jour et notices des hilloulot : yalkut_yosef.json (788 entrées), ben_ish_hai.json (2 002), hilloulot_bios.json et le champ t sont en hébreu seul. Il n’y a donc pas de traduction à juger. Les deux se'ifim erronés ne figurent pas dans la sélection du jour.

Ce que je n’ai pas pu examiner :
- l’affichage sur un vrai téléphone Android (constat établi par la lecture du code) ;
- la comparaison avec une traduction publiée du Yalkout Yossef ;
- la lecture de près des quelque 1 300 blocs traduits restants, couverts seulement par les scripts ;
- la qualité de l’hébreu source lui-même : par exemple, la phrase corrompue de sections[79].blocs[6] est rendue mot à mot dans les deux langues.

## Ce qui tient

- La structure est fidèle à l’hébreu sur les 1 489 blocs, dans les deux langues. Aucun écart de balises ni du nombre de renvois entre crochets, aucune traduction tronquée ou en double. Le numéro du se'if est converti juste à chaque fois. Aucune lettre hébraïque n’est restée par erreur : le seul bloc qui en garde, sections[34].blocs[39] (דכה/דכא), le fait exprès.
- Les références sont exactes. 4 464 renvois chiffrés (siman, se'if, page, note, tome, édition) ont été contrôlés par script, sans aucune erreur. Les coquilles de la source sont corrigées à bon escient (« סי' סכה » rendu siman 25), et les années sont justes (תשס״ד = 5764).
- Les décisions halakhiques et les mesures sont respectées. 2 939 segments ont été comparés par script sur les verdicts (permis, interdit, dispensé, valide, invalide, non quitte), puis les 141 alertes lues : aucun verdict inversé. Mesures et délais justes : 4 coudées, 72 minutes, 13,5 minutes, 30 jours, 24 cm, 70, 66, 30 et 28 lignes. La seule inversion trouvée porte sur un ordre de berakhot (constat 1).
- Le Nom divin suit une règle tenue sur tout le livre. ה' est rendu Hachem en français (203 occurrences) et Hashem en anglais (210) dans la prose et la liturgie ; l’Éternel et the LORD sont réservés aux versets (57 et 56) ; Dieu et God rendent אלהים. Aucune forme D.ieu ou G-d.
- Le vocabulaire technique est bien rendu et glosé : tokh kedé dibour, ’hok tokhot, tsourat hapéta’h, sfek sfeka, bein haperakim, ta’assé velo min he’assouï. Le kaddich araméen est transcrit avec soin. Les deux langues sont traduites de l’hébreu et concordent. L’anglais est très propre : dans l’échantillon, une seule erreur, partagée avec le français.
- Les 92 titres de sections et les 229 noms de tsadikim traduits des hilloulot sont justes.

## Constats

### YALKUT-01 — FR+EN — Yalkout 22:1 (talit neuf) : l’ordre des deux berakhot est inversé

**Gravité** : bloquant · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : texte

**Constat.** Le se'if dit qu’on récite d’abord « lehit’atef betsitsit », puis Chéhé’heyanou. Les deux traductions disent le contraire : Chéhé’heyanou avant lehit’atef. C’est une règle de pratique quotidienne, présentée comme la décision du livre, et elle est rendue à l’envers dans les deux langues. Le bloc fait partie de l’échantillon (n° 38) et a été vérifié ensuite sur trois appuis.

**Preuve.** RAW/livre_yalkut_yosef_kitsour.json, textes[0].sections[24] (« סימן כב - דין ברכת שהחיינו על טלית »).blocs[0]. HE : « על טלית חדשה מברכים ברכת ״שהחיינו״. ומברכים קודם ״להתעטף בציצית״ ». FR : « Sur un talit neuf, on récite la berakha de « Chéhé’heyanou », et on la récite avant « lehit’atef betsitsit ». » EN : « Over a new tallit one recites the berachah “Shehecheyanu,” and one recites it before “lehit’atef betzitzit.” » Trois vérifications. (1) Le Kitsour Choul’han Aroukh Yalkout Yossef est cité ainsi : « על טלית חדשה יש לברך להתעטף בציצית תחילה ואחר כך שהחיינו ». (2) Le Ben Ich ’Haï de l’application, RAW/ben_ish_hai.json annees.1.BERESHIS.h[6] : « יברך שהחיינו אחר ברכת להתעטף ». (3) La même tournure « יברך קודם ברכות התורה » est bien rendue « récitera d’abord les berakhot de la Torah » en sections[53].blocs[3] et blocs[30].

**Correction proposée.** FR : « Sur un talit neuf, on récite la berakha « Chéhé’heyanou » : on récite d’abord « lehit’atef betsitsit », puis « Chéhé’heyanou ». » EN : « Over a new tallit one recites the berachah “Shehecheyanu”: one first recites “lehit’atef betzitzit,” and then “Shehecheyanu.” » Il faut aussi relire à la main les 16 tournures d’ordre (מברך/יברך קודם, תחלה, ואחר כך) relevées par OUT/YALKUT : toutes les autres sont justes.

**Note du contre-expert.** J'ai rouvert sections[24].blocs[0] : l'hébreu, le français et l'anglais sont bien ceux cités. « ומברכים קודם ״להתעטף בציצית״ » se lit « on récite d'abord lehit'atef », comme « יברך קודם ברכות התורה » en 53/3 et 53/30, et comme « יברך קודם אשר יצר ואחר כך בורא נפשות » en 8/8, bien traduits. Le texte en ligne du siman 22:1 est identique, et ses commentateurs le lisent « להתעטף ואחר כך שהחיינו ». Le Ben Ich 'Haï de l'application (Berechit h[6]) va dans le même sens. Mon balayage retrouve exactement 16 tournures d'ordre dans les blocs traduits, et les autres sont justes. La correction FR et EN proposée est fidèle.

### YALKUT-02 — FR+EN — Les balises &lt;b> et &lt;small> s’affichent telles quelles dans toutes les traductions du Yalkout (web et Android)

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : texte

**Constat.** Les 1 489 traductions FR et EN gardent les balises de l’hébreu : &lt;b>N&lt;/b> au début de chaque bloc, et &lt;small>[…]&lt;/small> dans 1 481 blocs. L’hébreu est lu comme du HTML, la traduction non. Le lecteur francophone ou anglophone voit donc, dans chaque paragraphe : « &lt;b>2&lt;/b> L’homme doit… &lt;small>[Yalkout Yossef…]&lt;/small>. ». La note du livre affirme pourtant « relues automatiquement (clés, balises) ».

**Preuve.** RAW/livre_yalkut_yosef_kitsour.json sections[0].blocs[3].fr : « &lt;b>2&lt;/b> L’homme doit avoir pour nature et pour habitude constante… &lt;small>[Yalkout Yossef, Lois du lever matinal, p. 62 ; …]&lt;/small>. » On retrouve la même chose dans myhitbodedut-web/data/livres/yalkut_yosef_kitsour.json. Rendu du site construit en navigateur sans interface (OUT/YALKUT/verif_web.mjs) : 59 paragraphes traduits sur 59 montrent les balises, en fr comme en en ; captures OUT/YALKUT/web_yalkut_fr.png et web_yalkut_en.png. Dans le code web, web/src/js/app.js l.796 : paraTraduction → h() → document.createTextNode. Dans le code Android, K/SiddurLectureActivity.kt l.509-517 : append(t) sans Html.fromHtml, alors que l’hébreu passe par Html.fromHtml (l.505-506). Autres livres touchés (blocs fr avec balises) : guide 63, Perek Chira 86, Likoutei Moharan 79, Tefila LiChlomo 35, Likoutei Etsot 14, Nichmat 9.

**Correction proposée.** Lire la traduction comme l’hébreu : Html.fromHtml sur Android, riche() sur le web, avec la même mise en forme du petit texte. À défaut, convertir par script : « &lt;b>N&lt;/b> » devient « N. » et « &lt;small>[…]&lt;/small> » devient « […] » en petit corps. Ajouter à TraductionTest et aux tests web une vérification qu’aucun texte affiché ne contient « < ».

**Note du contre-expert.** Par script : les 1 489 blocs traduits (sur 14 390) ont tous des balises en FR comme en EN. Tous commencent par &lt;b>N&lt;/b>, et 1 481 contiennent &lt;small>. Dans le site construit, les données sont identiques et paraTraduction (app.js l.796) passe le texte à h(), qui crée un nœud texte, alors que l'hébreu passe par riche(). Sur Android, SiddurLectureActivity, qui ouvre aussi les livres (recueil() puis Data.livre), fait append(t) sans Html.fromHtml (l.509-517), alors que l'hébreu y passe (l.505-506). La capture le montre. Les comptes des autres livres sont exacts (guide 63, Perek Chira 86, Likoutei Moharan 79, Tefila LiChlomo 35, Etsot 14, Nichmat 9) : ce sont des &lt;b> et quelques &lt;br>.

### YALKUT-03 — FR — לכתחילה traduit par « de prime abord » (faux sens) : 23 occurrences dans 20 blocs (sections 27 à 32)

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** « De prime abord » veut dire « à première vue ». Dans tout le lot des tefilin (simanim 25 à 30), לכתחלה (a priori, en première intention) est rendu ainsi. Le lecteur comprend « à première vue c’est interdit, mais en fait non ». Partout ailleurs le même mot est rendu « a priori » (99 occurrences). L’anglais est juste dans ces passages (ab initio, ideally).

**Preuve.** RAW/livre_yalkut_yosef_kitsour.json. sections[27].blocs[55] : HE « ולכתחלה אסור להפסיק אפילו לצורך התפילין », FR « De prime abord, il est interdit d’interrompre même pour les besoins des tefilines ». sections[32].blocs[3] : HE « סוף זמן הנחת תפילין הוא לכתחלה עד השקיעה », FR « La fin du temps de la mise des tefilines est, de prime abord, jusqu’au coucher du soleil ». sections[27].blocs[64] : HE « לכתחלה אין להפסיק בין הנחת תפילין של יד לתפילין של ראש », FR « De prime abord, on ne doit pas interrompre entre la mise des tefilines de la main et celle des tefilines de la tête ». sections[32].blocs[4] : HE « ויבואו להניח תפילין לכתחלה אחר השקיעה », FR « qu’on n’en vienne pas à mettre les tefilines de prime abord après le coucher du soleil ». sections[29].blocs[19] : HE « שלכתחלה בודאי שראוי », FR « Mais de prime abord, il convient certainement que le gaucher… ». Les autres occurrences sont en sections 27, 29, 30 et 32 (20 blocs, liste dans OUT/YALKUT).

**Correction proposée (revue par le contre-expert).** Remplacer les 23 occurrences par « a priori » (« De prime abord, » devient « A priori, » ; en milieu de phrase, « de prime abord » devient « a priori »), sans toucher au reste de la phrase. Exemple, 32/4 : « …qu'on n'en vienne pas à mettre les tefilines a priori après le coucher du soleil… il lui est permis de rester avec eux même a priori. »

**Note du contre-expert.** Le cœur du constat est exact. Je recompte 23 « de prime abord » dans 20 blocs, aux sections 27 (9 blocs), 29 (5), 30 (2) et 32 (4), et chacun répond à un לכתחלה. Les citations sont exactes et l'anglais (ideally, ab initio) est juste. Le sens est faussé : en 32/4, « permis de rester avec eux même de prime abord » n'a pas de sens. Le chiffre annexe est faux : ailleurs, לכתחלה est rendu 131 fois par « a priori » (et non 99), et aussi 2 fois par « au départ » et 1 fois par « d'emblée ». La correction proposée est juste ; son passage à « tefilin » et « du bras » n'est qu'un choix de style, car le livre mélange déjà « tefilines » (671) et « tefilin » (627).

### YALKUT-04 — FR — Yalkout 4:55 : « garde-toi de ne pas aller au cimetière », une double négation qui inverse l’avertissement

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** La citation du Gaon de Vilna interdit d’aller au cimetière. « Se garder de ne pas aller » veut dire « veiller à y aller » : la phrase française dit le contraire de l’hébreu. C’est la seule occurrence de ce tour dans le corpus (balayage « garde-toi de ne pas »). L’anglais est juste. Le bloc fait partie de l’échantillon (n° 12).

**Preuve.** RAW/livre_yalkut_yosef_kitsour.json sections[4].blocs[55]. HE : « וכתב הגאון מוילנא: ״ותשמור שלא תלך לבית הקברות כלל וכלל כי שם מתדבקין בקליפות מאד, וכל שכן בנשים… ». FR : « Le Gaon de Vilna a écrit : « Et garde-toi de ne pas aller du tout au cimetière, car là on s’attache beaucoup aux kelipot… » ». EN : « And be careful not to go to the cemetery at all ».

**Correction proposée.** FR : « Et garde-toi bien de jamais aller au cimetière, car là on s’attache beaucoup aux kelipot, et à plus forte raison les femmes ; et tous les malheurs et les fautes viennent de là. »

**Note du contre-expert.** Le bloc 4/55 est bien cité et l'hébreu « ותשמור שלא תלך לבית הקברות כלל וכלל » est une défense. « Se garder de ne pas aller », pris à la lettre, veut dire le contraire : c'est une faute réelle, et l'unique occurrence de tout RAW. Mais le sens n'est pas renversé pour le lecteur : la phrase d'avant (« il ne faut pas multiplier les visites au cimetière ») et la raison qui suit (kelipot, malheurs) imposent la lecture prohibitive. Je ramène donc la gravité à mineur. La correction proposée est correcte et fidèle.

### YALKUT-05 — FR+EN — Termes et noms sans glossaire : une graphie différente selon le lot de traduction

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le texte a été traduit par lots successifs, sans glossaire commun. La graphie d’un même terme ou d’un même livre change d’une section à l’autre, et parfois dans un même bloc. Pour les tefilin, même le genre grammatical varie. Il n’y a pas de faux sens, mais un relecteur unifierait.

**Preuve.** Occurrences dans les 1 489 blocs et les 92 titres. FR : « tefilines » 642 (sections 0 à 32 et 87), « tefilin » 597 (27 à 108), « téfilin » 9, et « tefillin », graphie anglaise, 3 (sections[4].blocs[29] et [69]). Genre flottant : « des tefilines… achetés » en sections[27].blocs[13], « les tefilin… enlevées » en sections[41].blocs[0]. « talit » 329, « talith » 51 (sections 27 à 32 seulement, par exemple sections[27].blocs[26] « avec le talith »). Le livre le plus cité porte trois graphies : « Che’erit Yossef » 239, « Chéérit Yossef » 157 (sections 9 à 26), « Che’érit Yossef » 494 (sections 33 à 108). « Sefer Torah » 162, « Séfer Torah » 55. « Chema’ » 156, « Chema » 232, « Chéma » 44. « Cohen » 13, « Kohen » 9. « Erets Israël » 10, « Terre d’Israël » 17. « hala’ha » au lieu de « halakha » en sections[0].blocs[14] et sections[99].blocs[12]. EN : « She’erit Yosef » 733, « Sheerit Yosef » 157. « Keriat Shema » 283, « Kriat Shema » 12. לכתחילה rendu « ab initio » 51, « ideally » 43, « initially » 15, « lechatchilah » 7. « Rabbeinu Tam » 85, « Rabbenu Tam » 2. Le titre de sections[7] porte « Elokai Neshamah », le corps du texte « Elohai neshamah ».

**Correction proposée.** Fixer un glossaire unique et l’appliquer par script. FR : tefilin (féminin), talit, Chéérit Yossef, Séfer Torah, Chema, Kohen, halakha. EN : She’erit Yosef, Keriat Shema, une seule traduction de לכתחילה (ab initio ou ideally), Rabbeinu Tam, Elohai.

### YALKUT-06 — FR — « Certain dit », « être passant outre » : fautes de langue et calques ponctuels

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le singulier יש מי שאומר / שכתב est calqué en « Certain dit » ou « Certain a écrit » : l’adjectif est employé sans nom. On relève aussi un accord pluriel/singulier incohérent et un participe calqué de l’hébreu. Il y a 7 occurrences de ce type au total.

**Preuve.** RAW/livre_yalkut_yosef_kitsour.json. sections[38].blocs[1] : HE « יש מי שאומר שפעמים שאף לכתחילה מותר… », FR « Certain dit que parfois, même a priori, il est permis… ». sections[39].blocs[18] : HE « [ויש מי שאומר שיקדור כל השם…] », FR « [Certain dit qu’il faut découper le Nom entier, « Elohékha »] ». sections[36].blocs[11] : HE « ויש מי שכתב שאם הבתים… », FR « Certain a écrit que si les boîtiers… ». Même faute en sections[36].blocs[14] et sections[37].blocs[8]. sections[62].blocs[8] : HE « ויש מי שאומר שהיא חומרא יתירא… ואין דבריו מוכרחים », FR « Certains disent que c’est une rigueur excessive…, mais ses propos ne s’imposent pas ». sections[82].blocs[11] : HE « האחת, להיות מעביר על מדותיו ועלוב », FR « la première, être passant outre à ses susceptibilités et humble ».

**Correction proposée.** « Un avis dit que parfois, même a priori… » (tournure déjà employée 24 fois dans le livre). « [Un avis dit qu’il faut découper le Nom entier, « Elohékha »] ». « Un décisionnaire a écrit que si les boîtiers… ». « Un avis dit que c’est une rigueur excessive…, mais ses propos ne s’imposent pas ». « la première : savoir passer outre à ses susceptibilités et être humble ».

### YALKUT-07 — FR+EN — « יש מי שאומר » (un avis isolé) rendu au pluriel : « Certains disent », « Some say »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Dans la langue du Choul’han Aroukh, que le Yalkout Yossef reprend, « יש מי שאומר » désigne un avis unique, souvent suivi faute de contradicteur, et se distingue de « יש אומרים ». Sur 37 segments, la traduction le met au pluriel 7 fois en FR et 2 fois en EN. Le lecteur ne voit plus qu’il s’agit d’un avis isolé.

**Preuve.** RAW/livre_yalkut_yosef_kitsour.json. sections[66].blocs[8] : HE « ויש מי שאומר שיוצא ידי חובה בעל כרחו », FR « Certains disent qu’on s’en acquitte malgré soi » ; l’EN, « There is one who says », est juste. sections[53].blocs[8] : HE « ויש מי שאומר שחייב לחזור ולברך », FR « certains disent qu’il doit réciter de nouveau », EN « some say that he must recite… ». sections[42].blocs[7] : HE « יש מי שכתב », FR « Certains ont écrit », EN « Some have written ». Même cas en sections[65].blocs[19] et sections[62].blocs[8].

**Correction proposée.** FR : « Un avis dit qu’on s’en acquitte malgré soi » ; « un avis dit qu’il doit réciter de nouveau les berakhot de la Torah ». EN : « one authority holds that he must recite the berachot of the Torah again ». À inscrire au glossaire : יש מי שאומר → « un avis dit » / « there is one who says » ; יש אומרים → « certains disent » / « some say ».

### YALKUT-08 — EN — Yalkout, Tikoun ’Hatsot (sections[1].blocs[2]) : « the greatest part » au lieu d’une part infime

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Dans la parole de la Présence divine rapportée au Choul’han Aroukh, l’hébreu parle d’une fraction infime de la douleur. L’anglais écrit « the greatest part », ce qui contredit le sens de la phrase. Le français est juste.

**Preuve.** RAW/livre_yalkut_yosef_kitsour.json sections[1].blocs[2]. HE : « ואילו הייתם משערים אחד מאלף אלפי אלפים ורוב רבי רבבות מהצער אשר אני שרויה בו ». EN : « And if you could gauge one thousandth of a thousandth of a thousandth, and the greatest part of myriads of myriads, of the pain in which I dwell ». FR, juste : « un millième d’un milliardième, et la plus infime partie des myriades de myriades ».

**Correction proposée.** EN : « And if you could gauge even one part in a thousand thousand thousands, in myriads upon myriads, of the pain in which I dwell… »

### YALKUT-10 — FR+EN — Traduction du Yalkout non documentée, et note d’origine trompeuse

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : docs · **Type** : texte

**Constat.** Aucun script et aucune entrée de la feuille de route ne décrivent la traduction du Yalkout : ni ce qui a été traduit, ni comment, ni ce qui reste. L’en-tête de tools/traductions_textes.py énumère le guide, Nichmat, Perek Chira, le Tikoun et la bibliothèque, pas le Yalkout. tools/yalkut_kitsour_livre.py ne traite que l’hébreu. Les fichiers d’entrée {clé: {fr, en}} ne sont pas versés au dépôt. La seule trace est le commit 6e6b4c7 du 04/11 : « 1 581 paragraphes sur 14 390 (simanim 1 à 50 environ, et une partie des suivants) ; le reste s'affiche en hébreu seul ». Les 1 581 paragraphes correspondent à 1 489 blocs et 92 titres. La sélection suit donc l’ordre du livre, avec des trous, jusqu’à l’interruption au bloc 19 de la section 139. La note du livre ne dit ni que 90 % du texte reste en hébreu, ni que les balises s’affichent telles quelles.

**Preuve.** RAW/livre_yalkut_yosef_kitsour.json textes[0].traduction : « FR et EN originales (Claude, 04/11/2026), relues automatiquement (clés, balises) ; relecture humaine souhaitable. » R/tools/traductions_textes.py, lignes 3 à 8 : liste sans le Yalkout. R/FEUILLE_DE_ROUTE.md : aucune mention de la traduction du Yalkout (recherche « Yalkut », « kitsour », « traduction »). git show 6e6b4c7 : le message de commit cité ci-dessus.

**Correction proposée.** Consigner dans FEUILLE_DE_ROUTE.md et dans l’en-tête de traductions_textes.py le périmètre traduit : sections 0 à 60, 62 à 68, 72 à 82, 85 à 87, 94 à 101 et 108, plus la section 139 jusqu’au bloc 19. Y ajouter la date, la méthode et l’absence de relecture humaine, et verser les fichiers d’entrée. Corriger la note : « Traduction partielle : 1 489 se'ifim sur 14 303 (simanim 1 à 107 environ), FR et EN produites par IA le 04/11/2026, non relues par un humain. »

### YALKUT-09 — FR+EN — Psaume 16:8 cité deux fois, avec deux rendus du Nom divin

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** La règle annoncée veut que les versets cités suivent les éditions du domaine public : l’Éternel en français, the LORD en anglais. Elle est respectée partout sauf ici : le même verset est rendu une fois avec l’Éternel, une fois avec Hachem, dans les deux langues.

**Preuve.** RAW/livre_yalkut_yosef_kitsour.json. sections[47].blocs[1] : HE « שויתי ה' לנגדי תמיד », FR « « J’ai placé Hachem devant moi constamment » », EN « “I have set Hashem before me always” ». sections[0].blocs[42] : HE « שויתי ה' וגו' », FR « « J’ai placé l’Éternel, etc. » », EN « “I have set the LORD, etc.” ». La règle figure dans l’en-tête de R/tools/traductions_textes.py.

**Correction proposée.** FR : « « J’ai placé l’Éternel devant moi constamment » ». EN : « “I have set the LORD always before me” ».

### YALKUT-11 — FR — Hilloulot : un même prénom transcrit de plusieurs façons dans les noms traduits

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les 229 noms traduits sont justes. La transcription varie toutefois pour un même prénom, et un titre est isolé (« Rabbin »). L’anglais mêle aussi « Reb » et « Rabbi » pour les maîtres breslev.

**Preuve.** RAW/hilloulot.json. jours["10-29"][6] : « Rav Yits'hak Kadouri ». jours["4-19"][1] : « Rav Its'hak Isaac Halévi Herzog ». jours["7-25"][8] : « Rabbi Lévi Its'hak de Berditchev ». jours["5-5"][0] : « Rabbi Isaac Louria (le Ari) ». jours["8-20"][0] : « Rabbin Jonathan Sacks », seul « Rabbin » de la liste, ailleurs « Rav ». jours["10-10"][1] : FR « Rabbi Nathan de Breslev », EN « Reb Noson of Breslov ».

**Correction proposée.** « Rav Yits'hak Isaac Halévi Herzog », « Rabbi Lévi Yits'hak de Berditchev », « Rav Jonathan Sacks ». Transcrire יצחק « Yits'hak » partout, sauf les noms consacrés en français (Isaac Louria, Isaac Abravanel).
