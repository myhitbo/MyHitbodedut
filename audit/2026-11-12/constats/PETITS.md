# PETITS — Nichmat, Perek Chira, parties liturgiques du Tikkoun, hitbodedout guidée — lecture intégrale FR et EN

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

14 constats — confirmés en partie : 1 · non contre-expertisés (mineurs et cosmétiques) : 13.

> Contre-expertise incomplète pour cette dimension.

## Ce qui a été examiné

Aucun défaut bloquant sur ce corpus : pas de contresens doctrinal ou halakhique, pas de pan non traduit. Le seul défaut d'échelle est l'incohérence des versets cités avec le Rabbinat et JPS.

Balayage mécanique complet (scripts python3 sous OUT/petits : extrait.py, balayage.py, balayage2.py, termes.py, versets.py) sur 245 blocs : Nichmat 9, Perek Chira 99, parties non bibliques du Tikkoun 33 (26 paragraphes, 4 titres, 2 notes, la mention de continuité), guide par sujet 45, chaînes d'interface 59 (dix questions, dix conseils titre et corps, cinq temps de la hitbodedout guidée titre et invitation, dix thèmes, quatre mots du moment, trois salutations, deux étiquettes d'accueil). Les fichiers Kotlin cités ne portent pas de traductions propres, ils renvoient aux chaînes. Résultats du balayage : 0 bloc sans français, sans anglais ou sans hébreu ; 2 chaînes français = anglais, légitimes (Gratitude, Parnassa) ; 0 traduction identique à l'hébreu ; lettres hébraïques dans 3 blocs par langue, voulues (formule du milouy) ; 0 fin de phrase tronquée ; 0 traduction identique pour deux hébreux différents ; 0 balise résiduelle ; 0 mot de l'autre langue hors « mitsva » ; 93 références reportées sans écart ; 54 citations confrontées au Rabbinat et à JPS ; 51 références de Psaumes confrontées au texte hébreu (3 fausses à la source).

Lecture serrée : intégrale, hébreu, français et anglais côte à côte (fichier cote_a_cote.txt du même dossier, 758 lignes lues en entier), soit 245 blocs plus les 8 titres de section.

Français, 245 blocs lus : 3 blocs avec faux sens net (perek_chira s4/b16, prière de Rabbi Natan p5 et p14) ; 0 contresens doctrinal ; 0 omission ; 27 blocs avec défaut léger (9 dans Perek Chira, 13 dans le Tikkoun dont 12 pour le Nom divin, 5 chaînes).

Anglais, 245 blocs lus : 2 blocs avec faux sens net (perek_chira s4/b16, prière p14) ; 0 contresens doctrinal ; 0 omission ; 30 blocs avec défaut léger (7 dans Perek Chira, 16 dans le Tikkoun dont 13 pour le Nom divin, 3 dans le guide, 4 chaînes).

Hébreu comme langue d'arrivée, guide et chaînes, 104 blocs vérifiés contre le français : 0 erreur grave, 1 écart léger (parnassa). Défauts de la source hébraïque relevés au passage : 3 références fausses et un guillemet orphelin (perek_chira s6/b0).

Ces décomptes ne comprennent ni l'incohérence des versets cités (89 versets de Psaumes et de Chir haChirim), ni les défauts typographiques.

Non examiné ou non confirmé : les 39 références d'autres livres bibliques (Isaïe, Proverbes, etc.) sont exactes de mémoire, mais leur traduction n'a pas pu être comparée au Rabbinat ni à JPS, absents de l'application pour ces livres ; la vocalisation de « ונאמר » n'a pas été trouvée dans une édition vocalisée ; l'identification de « פרוגיות » reste incertaine ; le constat sur l'affichage des titres et de la consigne d'arrêt vient de la lecture du code Android et web, pas d'un essai à l'écran. Les copies web de Nichmat, Perek Chira, Tikkoun et guide sont identiques à celles d'Android ; l'application Nokia ne porte aucun de ces textes. Trois recherches web ont servi à vérifier des sources (texte de la prière, noms des créatures), sans aucun nom de projet ni de personne.

## Ce qui tient

- Complétude sans faille sur le corpus : 245 blocs en trois langues, aucun bloc vide, aucune traduction tronquée ni recopiée d'une langue à l'autre, aucun rapport de longueur aberrant (les extrêmes sont des titres courts), balises &lt;b> en nombre identique dans les trois langues, 93 références chiffrées reportées sans une seule erreur de transcription.
- Aucune omission de phrase ni de membre de phrase à la lecture intégrale, y compris dans les longs paragraphes de la prière de Rabbi Natan : les séries de six verbes, les dix sortes de mélodie, les quatre modalités (inadvertance, délibéré, contrainte, plein gré) sont toutes rendues.
- Le français et l'anglais des textes liturgiques sont traduits chacun de l'hébreu, pas l'un de l'autre : leurs divergences sont des choix indépendants et défendables (Isaïe 40:2 « temps d'épreuve » / « time of service », הרווחה « prospérité » / « relief »).
- Notions de kabbale et de 'hassidout bien rendues et glosées : kelipot, sitrin a'hranin, milouy, étincelles saintes ; פגם rendu de façon constante (« atteinte » 12 fois, « blemish » 13 fois) ; abréviations correctement développées (רמ"ח / שס"ה en 248 / 365, ד' יתברך, ע"פ, שליט"א), guematria תפ"ה conservée avec son chiffre.
- Nichmat : 9 blocs sur 9 sans défaut de sens dans les deux langues, registre liturgique tenu.
- Guide par sujet (45 invitations) et dix questions : naturels dans les trois langues, hébreu idiomatique (« שזכיתם לעשות », « קחו תורה על… »), un seul écart de sens sur 45 ; la référence du conseil 9 (Likoutei Moharan II, 25) est exacte dans les trois langues.

## Constats

### PETITS-01 — FR+EN — Versets cités retraduits au lieu de reprendre le Rabbinat / JPS 1917 : le même verset a jusqu'à trois traductions dans l'application

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** Réponse à la question posée : non, les versets cités dans Nichmat, Perek Chira et la liturgie du Tikkoun ne sont pas cohérents avec les Bibles utilisées ailleurs. Ils ont été retraduits. Ce n'est pas une erreur de sens (les retraductions sont justes), c'est une incohérence répétée. Mesure sur Perek Chira, 54 citations ayant leur texte de référence dans l'application (51 Tehilim, 3 Chir haChirim) : FR identique au Rabbinat 4, proche 14, différent 36 (similarité médiane 0,75) ; EN identique à JPS 5, proche 30, différent 19 (médiane 0,87 : c'est du JPS modernisé, thou devenu you). Liturgie du Tikkoun : 33 versets de Psaumes, aucun repris tel quel ; 9 d'entre eux (16:10, 16:11, 32:11, 150:1-6) viennent d'être lus dans les dix psaumes du même écran, dans une autre traduction. Nichmat : 2 versets (35:10, 33:1). Les deux retraductions maison divergent en plus entre elles (Ps 130:1, 150:6 ; en anglais 33:2, 97:11, 150:5).

**Preuve.** 1) Ps 150:6 « כֹּל הַנְּשָׁמָה תְּהַלֵּל יָהּ הַלְלוּ־יָהּ », trois rendus. tikkun_haklali.json psaumes (Tehilim 150) verset 6 : « Que tout ce qui respire loue le Seigneur! Alléluia! » / « Let every thing that hath breath praise the LORD. Hallelujah. » ; même fichier, priere_rabbi_nathan.paragraphes_fr[14] : « Que toute âme loue Yah, Halelouya ! » / paragraphes_en[14] : « Let every soul praise Yah. Halleluyah! » ; livre_perek_chira.json section 5 bloc 6 : « Que tout ce qui respire loue l’Éternel ! Halelouya ! » / « Let every soul praise the LORD. Halleluyah! ». 2) Ps 16:10 « כִּי לֹא־תַעֲזֹב נַפְשִׁי לִשְׁאוֹל » : psaume 16 du Tikkoun « Car tu n’abandonneras pas mon âme au Cheol, tu ne laisseras pas tes fidèles voir l’abîme. » ; priere_rabbi_nathan.paragraphes_fr[6] « car Tu n’abandonneras pas mon âme au Chéol, Tu ne laisseras pas Ton fidèle voir la fosse » ; EN « to the nether-world … Thy godly one to see the pit » contre « to the grave … Your devoted one see destruction ». 3) Ps 130:1 : tehilim.json « Des profondeurs de l’abîme, je t’invoque, ô Éternel! » ; perek_chira s2/b6 « Du fond des abîmes, je T’invoque, Éternel » ; prière p7 « Des profondeurs je T’ai appelé, Hachem ». 4) Ps 33:2 EN : perek_chira s3/b12 « sing praises to Him with the ten-stringed lute » ; prière p0 « sing to Him with the ten-stringed lyre » ; JPS « with the psaltery of ten strings ». Comparaison complète : OUT/petits/versets_compare.txt

**Correction proposée (revue par le contre-expert).** Garder les retraductions maison : elles sont justes, emploient le même nom divin que la prière (Hachem / You) et collent parfois mieux à l'hébreu que le Rabbinat ou JPS. Il faut ensuite trois choses. (1) Une seule version maison par verset dans Perek Chira, Nichmat et la liturgie du Tikkun : 130:1, 150:6, 150:5 et 33:2 ; 97:11 est seulement à vérifier, son anglais étant déjà identique (« Light is sown for the righteous »). Il faut aussi accorder FR et EN dans un même bloc : perek_chira s5/b6 dit « tout ce qui respire » en FR mais « every soul » en EN. (2) Dans le Tikkun, pour les 9 versets relus dans la prière (16:10, 16:11, 32:11, 150:1-6), soit les aligner, soit assumer l'écart par une note. (3) Récrire l'en-tête de tools/traductions_textes.py pour décrire le choix réel : versets cités traduits dans le ton du texte, Hachem/Hashem dans la liturgie du Tikkun. Si le propriétaire choisit malgré tout l'option A, il ne faut jamais remplacer d'après la seule référence. Deux références de Perek Chira sont fausses : s3/b16 « תהילים צז יב » cite en réalité 97:11, et s5/b2 « קמה טו » cite 145:14. Le fichier de l'auditeur relève lui-même 7 citations partielles ou divergentes. Trois versets sont à traiter à part. 16:10, prière p6 : garder « Tu ne laisseras pas Ton fidèle voir la fosse » / « Thy godly one ». L'hébreu affiché porte le qere חֲסִידְךָ, au singulier, alors que le Rabbinat écrit « tes fidèles », au pluriel. La correction proposée pour p6 est donc moins fidèle que le texte actuel. 123:2 : le Rabbinat écrit « mes yeux » pour עֵינֵינוּ (« nos yeux »). 87:7 dans Perek Chira : ne pas reprendre le JPS « all my thoughts are in Thee », qui fait disparaître מַעְיָנַי (« mes sources »), le mot qui rattache le verset au chant des sources. Enfin, insérer « l'Éternel / le Seigneur » ou « Thou / hath » au milieu d'une prière qui dit Hachem / You crée une nouvelle incohérence de ton.

**Note du contre-expert.** J'ai rouvert toutes les citations : tikkun p0, p6, p7 et p14 ; perek_chira s2/b6, s3/b12 et s5/b6 ; Nichmat s0/b2 et s0/b3. J'ai refait le décompte par script : Perek Chira compte 95 références, dont 51 Tehilim, 3 Chir et 39 d'autres livres. En FR, 4 citations sont identiques au Rabbinat (médiane 0,76) ; en EN, la médiane face à JPS est de 0,87. Avec un seuil de 0,8, 19 citations FR et 34 EN sont proches, ce qui recoupe les 18 et 35 du constat. La liturgie contient environ 31 versets entiers et 2 ou 3 partiels. TikkunFlowActivity affiche bien la traduction des psaumes puis celle de la prière, donc 16:10, 16:11, 32:11 et 150:1-6 apparaissent deux fois, traduits différemment. Ps 150:6 a bien trois rendus FR. Aucun choix documenté ne couvre ces retraductions : l'en-tête de tools/traductions_textes.py annonce « l'Éternel / the LORD », alors que la liturgie écrit Hachem/Hashem. En revanche, la gravité est surévaluée. Le constat reconnaît lui-même qu'il n'y a aucune erreur de sens. Retraduire un verset cité dans une prière ou dans Perek Chira, dans le ton du texte, est l'usage courant des siddourim. Le défaut visible se limite donc aux 9 versets répétés dans le même parcours du Tikkun et aux écarts entre les deux versions maison. Enfin, l'option A proposée est dangereuse telle qu'elle est écrite.

### PETITS-02 — FR+EN — Perek Chira : deux créatures mal identifiées (זרזיר, צבי) et quatre noms laissés en translittération

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Six blocs sur 99. Le mot זרזיר revient deux fois : parmi les oiseaux (chapitre 4) c'est l'étourneau, mais au chapitre 5, entre le renard et le chat, c'est le lévrier (זרזיר מתנים, Michlé 30:31) ; la traduction met un oiseau au milieu des bêtes sauvages. צבי est la gazelle, pas le cerf (אייל). Quatre noms sont seulement translittérés, sans glose, alors que tous les autres sont traduits : le lecteur ne sait pas de quoi il s'agit. Identifications vérifiées sur une traduction anglaise publiée de Perek Shirah (Hound, Gazelle, Swift, Stormy Petrel, Laughing Dove).

**Preuve.** livre_perek_chira.json. Section 4 bloc 16 : « זַרְזִיר אוֹמֵר. רַנְּנוּ צַדִּיקִים בַּיְיָ » (après שׁוּעַל au bloc 15, avant עַכְבָּר et חָתוּל) → « L’étourneau dit » / « The starling says » ; le même mot à la section 3 bloc 20, parmi les oiseaux, est déjà « L’étourneau ». Section 4 bloc 10 : « צְבִי אוֹמֵר » → « Le cerf dit » / « The deer says ». Section 3 bloc 15 : « טַסִּית » → « La tassit » / « The tassit ». Bloc 16 : « צִיָּה » → « La tsiya » / « The tziyah ». Bloc 17 : « רְצִפִי » → « Le retsifi » / « The retzifi ». Bloc 23 : « פְרוֹגִיוֹת » → « Les prougiyot » / « The prugiyot ».

**Correction proposée.** s4/b16 : « &lt;b>Le lévrier&lt;/b> dit : » / « &lt;b>The hound&lt;/b> says: ». s4/b10 : « &lt;b>La gazelle&lt;/b> dit : » / « &lt;b>The gazelle&lt;/b> says: ». s3/b15 : « &lt;b>Le martinet&lt;/b> (tassit) dit : » / « &lt;b>The swift&lt;/b> (tasit) says: ». s3/b16 : « &lt;b>Le pétrel&lt;/b> (tsiya) dit : » / « &lt;b>The storm petrel&lt;/b> (tziyah) says: ». s3/b17 : « &lt;b>La tourterelle&lt;/b> (retsifi) dit : » / « &lt;b>The laughing dove&lt;/b> (retzifi) says: ». s3/b23 : identification incertaine ; garder la translittération avec une glose, « &lt;b>Les prougiyot&lt;/b> (oiseaux) disent : » / « &lt;b>The prugiyot&lt;/b> (birds) say: », ou suivre une édition de référence. Faire relire la liste des 80 noms de créatures par quelqu'un qui dispose d'une édition annotée.

### PETITS-03 — FR+EN — Prière de Rabbi Natan : « ונאמר » lu « et nous dirons » au lieu de « et il est dit »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le mot qui introduit le psaume 150 à la fin de la prière est la formule de citation וְנֶאֱמַר (« et il est dit »), comme « כמו שכתוב » au paragraphe précédent. Les deux traductions l'ont lu וְנֹאמַר (futur, première personne du pluriel). Les éditions complètes de la prière enchaînent d'ailleurs « כאמור: … ונאמר: הללויה » (vérifié sur une édition en ligne, non vocalisée : la vocalisation elle-même n'a pas pu être confirmée, d'où la confiance moyenne).

**Preuve.** tikkun_haklali.json, priere_rabbi_nathan.paragraphes[14] : « ונאמר: "הללויה, הללו אל בקדשו, הללוהו ברקיע עזו… » ; paragraphes_fr[14] : « Et nous dirons : « Halelouya ! Louez Dieu dans Son sanctuaire… » ; paragraphes_en[14] : « And let us say: “Halleluyah! Praise God in His sanctuary… ».

**Correction proposée.** FR : « Et il est dit : « Halelouya ! Louez Dieu dans Son sanctuaire… » ». EN : « And it is said: “Halleluyah! Praise God in His sanctuary… ».

### PETITS-04 — FR — Faux sens ponctuels propres au français (4 passages dans 3 blocs) ; l'anglais est juste aux mêmes endroits

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Quatre endroits où le français s'écarte de l'hébreu alors que l'anglais le rend correctement. (a) מקרה, la pollution nocturne, est rendu « accident » sans glose : la phrase se lit comme une demande de protection contre les accidents en général. (b) חוקים et משפטים sont intervertis par rapport à l'usage (statuts / lois). (c) « מלפני המקום » : le serment émane de Dieu, il n'est pas prononcé devant Lui. (d) Chemot 22:8 : « האלהים » désigne ici les juges selon la lecture reçue (Rachi, Sanhédrin 3b), que suit le Rabbinat (« tribunal », « juges ») ; le français écrit « Dieu » deux fois. L'anglais dit aussi « God », mais c'est le texte de JPS 1917.

**Preuve.** (a) tikkun_haklali.json priere_rabbi_nathan[5] : « וְתִשְׁמְרֵנִי וְתַצִּילֵנִי מִמִּקְרֶה בֵּין בַּיּוֹם וּבֵין בַּלַּיְלָה » → « garde-moi et sauve-moi de tout accident, de jour comme de nuit » (EN : « from any emission »). (b) même paragraphe : « אֲשֶׁר בְּחֻקֶּיךָ אֵלֵךְ וְאֶת מִשְׁפָּטֶיךָ אֶשְׁמֹר » → « que je marche selon Tes lois et que j’observe Tes statuts » (EN : « walk in Your statutes and keep Your ordinances »). (c) livre_perek_chira.json section 5 bloc 8 : « שְׁבוּעָה הִיא מִלִּפְנֵי הַמָּקוֹם בָּרוּךְ הוּא » → « C’est un serment prononcé devant le Tout-Présent, béni soit-Il » (EN : « an oath from before the Omnipresent »). (d) section 4 bloc 14 : « עַד הָאֱלֹהִים יָבֹא דְּבַר שְׁנֵיהֶם אֲשֶׁר יַרְשִׁיעֻן אֱלֹהִים » → « la cause des deux parties viendra devant Dieu ; celui que Dieu condamnera paiera le double ».

**Correction proposée.** (a) « garde-moi et sauve-moi de toute pollution (mikré), de jour comme de nuit ». (b) « que je marche selon Tes statuts et que j’observe Tes lois ». (c) « C’est un serment émanant du Tout-Présent, béni soit-Il ». (d) « la cause des deux parties sera portée devant les juges ; celui que les juges condamneront paiera le double à son prochain ».

### PETITS-05 — FR+EN — Nom divin : la règle écrite du projet (« l'Éternel / the LORD » dans les versets cités) n'est pas appliquée dans la liturgie du Tikkoun

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** L'en-tête de tools/traductions_textes.py pose la règle : « Les versets cités suivent l'usage des éditions du domaine public (l'Éternel / the LORD) ». Nichmat et Perek Chira la suivent (63 « Éternel », 63 « LORD », 0 « Hachem »). La liturgie du Tikkoun fait l'inverse : les 19 Tétragrammes de l'hébreu sont tous rendus « Hachem » / « Hashem » (13 paragraphes sur 26), dont 14 à l'intérieur de versets cités. Sur le même écran, les dix psaumes disent « l'Éternel » ou « le Seigneur » / « the LORD » : le lecteur passe trois fois d'un Nom à l'autre. Variantes secondaires : יה est « Yah » dans la prière (3 fois) et « l'Éternel » / « the LORD » dans Perek Chira ; « d’Hachem » (chaîne tip_6_body) contre « de Hachem » (prière, 2 fois).

**Preuve.** tikkun_haklali.json ouverture.paragraphes[1] : « לְכוּ נְרַנְּנָה לַיהוָה » → « Venez, chantons avec allégresse pour Hachem » / « Come, let us sing joyfully to Hashem ». cloture[1] : « וּתְשׁוּעַת צַדִּיקִים מֵיְהוָה » → « Le salut des justes vient de Hachem » / « is from Hashem ». priere_rabbi_nathan[0], Ps 33:2 : « Rendez grâce à Hachem avec la harpe » ; le même verset dans livre_perek_chira.json section 3 bloc 12 : « Rendez grâce à l’Éternel avec la harpe ». Comptage par script : OUT/petits/termes.py

**Correction proposée.** Appliquer la règle par script sur les 13 paragraphes : FR « pour Hachem » → « pour l’Éternel », « de Hachem » → « de l’Éternel », « en Hachem » → « en l’Éternel », vocatif « Hachem » → « Éternel » ; EN « Hashem » → « the LORD », vocatif « O LORD ». Exemples : « Venez, chantons avec allégresse pour l’Éternel, acclamons le Rocher de notre salut. » / « Come, let us sing joyfully to the LORD; let us shout for joy to the Rock of our salvation. » ; « Le salut des justes vient de l’Éternel » / « The salvation of the righteous is from the LORD ». Si le propriétaire préfère « Hachem » dans la prose de Rabbi Natan (5 occurrences hors versets), l'écrire dans l'en-tête du script. Unifier « de Hachem » (sans élision) dans les chaînes.

### PETITS-06 — FR+EN (et hébreu) — Perek Chira : trois références de Psaumes fausses ou incomplètes, recopiées de la source sans contrôle

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les 93 références chiffrées de l'hébreu sont toutes reportées à l'identique en français et en anglais (0 écart de transcription). Mais confrontées au texte de tehilim.json, trois références de la source sont fausses, et les traductions les reproduisent. Un bloc cite aussi trois versets sans aucune référence.

**Preuve.** livre_perek_chira.json. Section 3 bloc 16 : « אוֹר זָרֻעַ לַצַּדִּיק וּלְיִשְׁרֵי לֵב שִׂמְחָה: (תהילים צז יב) » → « (Tehilim 97:12) » / « (Psalms 97:12) » ; c'est 97:11, le verset 12 est « שִׂמְחוּ צַדִּיקִים בַּיהוָה ». Section 5 bloc 2 : « סוֹמֵךְ יְיָ לְכָל הַנֹּפְלִים… (תהילים קמה טו) » → « (Tehilim 145:15) » / « (Psalms 145:15) » ; c'est 145:14, le verset 15 est « עֵינֵי־כֹל אֵלֶיךָ יְשַׂבֵּרוּ ». Section 3 bloc 1 : le texte commence par « זֶה דּוֹר דֹּרְשָׁו… » (24:6) mais porte « (תהילים כד ז-ח) » → « (Tehilim 24:7-8) » / « (Psalms 24:7-8) ». Section 3 bloc 22 : « קוֹל קוֹרֵא בַּמִּדְבָּר… » et « אָרוּר הַגֶּבֶר… בָּרוּךְ הַגֶּבֶר… » sans référence.

**Correction proposée.** Corriger dans les trois langues. s3/b16 : « (תהילים צז יא) », « (Tehilim 97:11) », « (Psalms 97:11) ». s5/b2 : « (תהילים קמה יד) », « (Tehilim 145:14) », « (Psalms 145:14) ». s3/b1 : « (תהילים כד ו-ח) », « (Tehilim 24:6-8) », « (Psalms 24:6-8) ». s3/b22, facultatif : ajouter « (Yecha’ya 40:3) » / « (Isaiah 40:3) » et « (Yirmeya 17:5, 7) » / « (Jeremiah 17:5, 7) ». Ajouter au contrôle automatique la confrontation des références Tehilim au texte de tehilim.json (script fourni : versets.py dans le dossier de l'audit).

### PETITS-07 — FR+EN — Tikkoun : la consigne d'arrêt du psaume 32 n'existe qu'en hébreu, et les titres des parties ne s'affichent qu'en hébreu

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Seul texte du corpus sans traduction : la consigne placée dans le psaume 32, verset 7 (marquer une pause avant « מִצַּר »). Elle n'a ni français ni anglais, et elle n'est affichée que si l'hébreu l'est : en mode « français seul » ou « anglais seul » elle disparaît. Par ailleurs les titres des quatre parties liturgiques sont affichés en hébreu seulement, dans tous les modes ; les traductions « Avant de commencer », « Après les dix psaumes », « Prière après le Tikoun (Rabbi Natan) » existent dans le fichier mais ne sont jamais montrées, pas plus que la note d'ouverture « Bon à dire, mais non indispensable ». Constat tiré de la lecture du code, non d'un essai sur appareil.

**Preuve.** tikkun_haklali.json, psaumes[1] (Tehilim 32), versets[6].arret.note : « כאן צריך להפסיק מעט. (עין בליקוטי מוהר"ן חלק א' סימן רי"ג). », sans clé fr ni en. Affichage : android/app/src/main/java/com/myhitbodedut/TikkunFlowActivity.kt lignes 57-66 (dans « if (avecHebreu) ») et 176-178 (« text = arret.note ») ; web/src/js/app.js ligne 2047. Titres : TikkunFlowActivity.kt lignes 45, 78, 85 (« titre(bloc.titre.he…) ») ; web/src/js/app.js lignes 2038, 2054, 2057 ; la note n'est lue que pour la kavana et la prière (ligne 86, web/src/js/tikkun.js lignes 51-56).

**Correction proposée.** Ajouter à arret.note les deux traductions et les afficher dans la langue de lecture : FR « Ici, marquer une courte pause (voir Likoutei Moharan I, 213). » ; EN « Pause briefly here (see Likutei Moharan I, 213). ». Sous chaque titre hébreu, afficher le titre traduit quand le mode de lecture comporte une traduction, et afficher la note d'ouverture comme l'est déjà celle de la prière.

### PETITS-08 — FR+EN — Dix conseils : « בורא עולם » rendu « Hachem / Hashem », contre la décision du 22/09 ; une question du conseil 6 infléchie

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Pour les dix conseils l'hébreu est la source (FEUILLE_DE_ROUTE.md, relecture du 22/09), et la décision consignée est : « בורא עולם » reste « Créateur », qui est un descriptif et non un nom. Les deux traductions actuelles écrivent « Hachem » / « Hashem » aux deux endroits où l'hébreu dit « בורא עולם » ; ni « Créateur » ni « Creator » ne figure plus dans les chaînes. Dans le conseil 6, « מה יקרב אותי אל השם? » (qu'est-ce qui me rapprochera) devient une question sur le ressenti.

**Preuve.** android/app/src/main/res/values-iw/strings.xml, tip_4_body : « …להתחבר בצורה טובה יותר לעצמכם ולבורא עולם » ; values/strings.xml : « …mieux vous vous reliez à vous-même et à Hachem » ; values-en : « …connect to yourself and to Hashem ». tip_7_body : « …כנים עם עצמכם ועם בורא עולם » → « sincère avec vous-même et avec Hachem » / « honest with yourself and with Hashem ». tip_6_body : « מה יקרב אותי אל השם? » → « Comment puis-je me sentir plus proche d’Hachem ? » / « How can I feel closer to Hashem? ». Décision : FEUILLE_DE_ROUTE.md lignes 437-441.

**Correction proposée.** tip_4_body : « …mieux vous vous reliez à vous-même et au Créateur. » / « …the better you will connect to yourself and to the Creator. ». tip_7_body : « …sincère avec vous-même et avec le Créateur. » / « …honest with yourself and with the Creator. ». tip_6_body : « Qu’est-ce qui me rapprochera de Hachem ? » / « What will bring me closer to Hashem? ».

### PETITS-09 — EN — Anglais dérivé du français dans les notes et le guide : translittération française, calques

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les grands textes anglais sont traduits de l'hébreu, mais les petites notes et le guide par sujet viennent visiblement du français. « mitsva » (graphie française) apparaît 2 fois dans l'anglais du guide, contre « mitzvah » 128 fois et « mitsva » 0 fois dans le reste des contenus anglais. Trois notes du Tikkoun sont des calques peu compréhensibles ; le titre de la kavana dit « filling » quand le paragraphe juste dessous dit « full spelling (milui) », et il omet, comme le français, les deux Noms du titre hébreu.

**Preuve.** guide_sujets.json avoda/harata EN : « Which mitsva have you let slip these last days? » ; avoda/hodaa EN : « Give thanks for every mitsva you were able to do. ». tikkun_haklali.json priere_rabbi_nathan.note : « נאמרת אחרי התיקון; אינה מעכבת. » → EN « Said after the Tikkun; it does not condition it. ». kavana.titre : « כוונת המילוי — אֵ"ל אֱלֹהִי"ם » → EN « The kavanah of the filling », FR « La kavana du milouy ». ouverture.note : « טוב לומר, אך לא הכרחי. » → EN « Good to say, but not indispensable. ». guide_sujets.json famille/sihah EN : « Speak to Him of each of your family, by name. ». values-en/strings.xml tip_1_title : « Choose a quiet, separate place ».

**Correction proposée.** « Which mitzvah have you let slip these last days? » ; « Give thanks for every mitzvah you were able to do. » ; « Said after the Tikkun; the Tikkun is valid without it. » ; « The kavanah of the milui (full spelling) — El, Elohim » et en français « La kavana du milouy — El, Élohim » ; « Good to say, but not required. » ; « Speak to Him about each member of your family, by name. » ; « Choose a quiet, secluded place ».

### PETITS-10 — FR — Interface : « Bon après-midi » employé comme salutation d'accueil, et une question mal tournée

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** En français « Bon après-midi » se dit en quittant quelqu'un, pas en l'accueillant. Le commentaire de Salutation.kt le dit lui-même (« Le français dit « bonjour » jusqu'au soir, puis « bonsoir » »), mais la chaîne de l'après-midi n'a pas suivi. La question 6 du blocage, « Où avez-vous été bien », se comprend comme « où étiez-vous à l'aise ».

**Preuve.** android/app/src/main/res/values/strings.xml ligne 491, hero_greeting_afternoon : « Bon après-midi, %1$s » (hébreu « צהריים טובים, %1$s », anglais « Good afternoon, %1$s ») ; android/app/src/main/java/com/myhitbodedut/Salutation.kt lignes 6-9. question_bilan : « איפה הייתם טובים היום? » → « Où avez-vous été bien aujourd’hui ? Où avez-vous trébuché ? » (EN : « Where did you do well today? »).

**Correction proposée.** hero_greeting_afternoon : « Bonjour, %1$s ». question_bilan : « En quoi avez-vous bien agi aujourd’hui ? Où avez-vous trébuché ? ».

### PETITS-11 — HE — Guide par sujet (parnassa) : l'hébreu dit « dans la dignité et l'abondance », le français et l'anglais « honnête et suffisante »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Seul écart de sens relevé entre les trois langues sur les 45 invitations du guide. Le français (langue de rédaction) et l'anglais demandent une subsistance honnête et suffisante ; l'hébreu emploie la formule traditionnelle « בכבוד ובשפע », qui demande la dignité et l'abondance. Ce n'est pas la même prière.

**Preuve.** guide_sujets.json, sujets.parnassa.bakasha : fr « Demandez une parnassa honnête et suffisante, et la confiance qu’elle vient de Lui. » ; en « Ask for an honest, sufficient livelihood, and trust that it comes from Him. » ; he « בקשו פרנסה בכבוד ובשפע, וביטחון שהיא באה ממנו. »

**Correction proposée.** Choisir un sens et aligner. Si le français fait foi : « בקשו פרנסה ביושר ובמידה מספקת, וביטחון שהיא באה ממנו. ». Si la formule hébraïque traditionnelle est voulue : « Demandez une parnassa digne et abondante, et la confiance qu’elle vient de Lui. » / « Ask for a dignified and plentiful livelihood, and trust that it comes from Him. ».

### PETITS-12 — FR — Typographie : espaces ordinaires devant « : ; ! ? » et dans les guillemets dans Perek Chira, Nichmat et le guide (225 occurrences)

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le Tikkoun et les chaînes d'interface utilisent des espaces insécables devant la ponctuation haute (70 et 22 occurrences). Perek Chira, Nichmat et le guide par sujet utilisent des espaces ordinaires : sur un écran étroit, un deux-points, un point d'interrogation ou un guillemet fermant peut passer seul à la ligne.

**Preuve.** Comptage par script sur le français : livre_perek_chira.json 198 espaces ordinaires (193 devant « : ; ! ? » », 5 après « « »), par exemple section 0 bloc 0 « Les cieux disent : Les cieux racontent… » ; livre_nichmat.json 18 ; guide_sujets.json 9, par exemple emotions/harata « …que vous regrettez ? » ; tikkun_haklali.json et chaînes : 0 espace ordinaire.

**Correction proposée.** Correction par script dans les trois fichiers : remplacer l'espace ordinaire par une espace insécable (U+00A0) devant « : » et « » » et après « « », et par une espace fine insécable (U+202F) devant « ; », « ! », « ? », comme dans tikkun_haklali.json.

### PETITS-13 — FR+EN — Graphies concurrentes des titres et de quelques termes

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Variantes relevées par le tableau des termes. FR : « Perek Chira » (titre du livre, chaîne livres_hint) contre « Pérek Chira » (titre de section et deux blocs) ; « Nichmat kol 'haï » avec apostrophe droite (titre du livre) contre « Nichmat kol ’haï » (titre de section) ; « Halelouya » dans la prière contre « Alléluia » dans le psaume 150 du même écran. EN, entre Perek Shira et la prière de Rabbi Natan pour les mêmes versets : lute / lyre, clanging / clashing, « gladness for the upright in heart » / « joy for the upright of heart » ; « Halleluyah » contre « Hallelujah » (JPS).

**Preuve.** livre_perek_chira.json textes[0].titre.fr « Perek Chira » ; sections[6].titre_fr « Prière après la récitation de Pérek Chira » ; section 6 blocs 0 et 1 « Pérek Chira ». livre_nichmat.json textes[0].titre.fr « Nichmat kol 'haï » ; sections[0].titre_fr « Nichmat kol ’haï ». Ps 150:5 EN : perek_chira s3/b27 « clanging cymbals », priere_rabbi_nathan[14] « clashing cymbals ». Ps 97:11 EN : perek_chira s3/b16 « gladness for the upright in heart », priere_rabbi_nathan[15] « joy for the upright of heart ».

**Correction proposée.** Règle de glossaire : « Perek Chira » partout (trois remplacements), « Nichmat kol ’haï » avec apostrophe typographique dans titre.fr. Les variantes de versets disparaissent si le constat sur les versets cités est traité ; sinon retenir une seule forme : « ten-stringed lyre », « clanging cymbals », « gladness for the upright in heart ».

### PETITS-14 — FR+EN — Nichmat : dernier bloc terminé sur « Et ainsi : » sans suite, et gras d'acrostiche sans objet en traduction

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le texte hébreu repris s'arrête sur « וּבְכֵן », premier mot du passage suivant du siddour (Yichtaba'h), absent du livre : les traductions se terminent sur une annonce sans suite. Dans les blocs 4 à 7, l'hébreu met en gras les lettres des acrostiches יצחק et רבקה ; les traductions reportent le gras sur des mots entiers, où il ne signifie plus rien, sans mention des acrostiches. Aucun défaut de sens : les 9 blocs sont justes dans les deux langues.

**Preuve.** livre_nichmat.json section 0 bloc 8 : « …דָּוִד בֶּן יִשַׁי עַבְדְּךָ מְשִׁיחֶךָ: וּבְכֵן » → « …Ton serviteur, Ton oint. Et ainsi : » / « …Your servant, Your anointed. And so: ». Bloc 4 : « &lt;b>בּפִי&lt;/b> &lt;b>יְ&lt;/b>שָׁרִים תִּתְ&lt;b>ר&lt;/b>וֹמָם, » → « &lt;b>Par la bouche&lt;/b> des &lt;b>hommes droits&lt;/b> Tu es &lt;b>exalté&lt;/b>, » / « &lt;b>By the mouth&lt;/b> of the &lt;b>upright&lt;/b> You are &lt;b>exalted&lt;/b>, ».

**Correction proposée.** Retirer « וּבְכֵן » / « Et ainsi : » / « And so: » de la fin du bloc 8 (ou ajouter le passage suivant). Blocs 4 à 7 : ne garder en gras que l'incipit « Par la bouche » / « By the mouth », et signaler une fois les acrostiches, par exemple à la fin du bloc 7 : « (En hébreu, les initiales forment les noms Yits’hak et Rivka.) » / « (In the Hebrew, the initials spell Yitzchak and Rivkah.) ».
