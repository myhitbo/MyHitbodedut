# TANAKH — Tehilim, psaumes du Tikkoun, Esther, Chir haChirim — alignement et qualité FR et EN

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

19 constats — confirmés en partie : 2 · non contre-expertisés (mineurs et cosmétiques) : 17.

> Contre-expertise incomplète pour cette dimension.

## Ce qui a été examiné

BALAYÉ EN ENTIER PAR SCRIPT (scripts sous OUT/tanakh/v2) : tehilim.json (150 psaumes, 2 527 versets, 3 langues), les dix psaumes de tikkun_haklali.json (164 versets, comparés un à un à tehilim.json), livre_meguilat_esther.json (167 blocs), livre_chir_hachirim.json (117 blocs) ; copies du site (myhitbodedut-web/data) comparées : tehilim et tikkun identiques octet pour octet, sections des deux livres identiques. Contrôles : nombres de versets, versets vides, rapports de longueur traduction/hébreu, ancres (Sélah, 30 noms propres, Tétragramme), cinq détecteurs de décalage (longueurs de versets voisins, association lexicale français-anglais et traduction-hébreu, mots de bord de verset, versets finissant par deux-points, début de discours), balises et caractères, ponctuation, guillemets, orthographe par dictionnaire, formes archaïques, affichage de l'édition dans le code Android et web.

LUS DE PRÈS DANS LES TROIS LANGUES : 781 blocs. Tehilim : 705 versets distincts sur 2 527 (28 %) = 479 pour le contrôle de chaque psaume (premier, milieu, dernier, et les trois premiers des 15 psaumes à suscription longue), 164 du Tikkoun lus en entier, 60 tirés au hasard (graine 20261112), 69 des psaumes 20, 23, 91, 121, 130 et 145 lus en entier, recoupements déduits. Meguilot : 76 versets sur 284 (27 %) = 36 premiers et derniers de chapitre, 40 tirés au hasard (même graine ; 24 d'Esther, 16 du Cantique).

FRANÇAIS — 781 blocs lus : 5 avec erreur grave (Ps 78:20 décalé, Ps 60:2 et 106:1 omissions, Ps 52:2 nom faux, Ps 42:9 faux sens) ; environ 33 avec erreur légère (coquilles, ponctuation perdue, guillemets, Nom mal rendu, Sélah omis). Hors lecture, trouvés par script : 7 autres versets décalés (Ps 11:2-3, 78:19, 98:2-3, 126:2-3 ; 8 versets décalés au total dans 4 psaumes), l'omission d'Esther 1:14, deux autres Sélah omis, 5 Noms au vocatif non traduits.
ANGLAIS — 781 blocs lus : 0 erreur grave ; 23 avec erreur légère (ponctuation orpheline, coquilles, majuscules de révérence mal placées, noms de lettres et capitales). Par script sur tout le corpus : 52 versets à ponctuation orpheline, 22 noms de lettres au psaume 119, 6 mots collés.
Tirage de 60 versets : français 1 grave (78:20) et 2 légères (47:10, 62:11) ; anglais 0 grave et 2 légères (50:19, 73:21) ; aucun écart de sens réel de l'anglais avec l'hébreu.
Alignement : aucun décalage en anglais ; 4 en français, tous internes à deux versets voisins ; aucun dû aux suscriptions.

CE QUE JE N'AI PAS PU EXAMINER : 1 822 versets de Tehilim et 208 versets des meguilot n'ont été couverts que par script, pas lus ; un glissement d'un ou deux mots sans ancre ou une omission d'un mot courant peuvent y rester. Je n'ai pas confronté le texte aux éditions imprimées de 1899 et de 1917 ni à Wikisource : une seule vérification en ligne a été faite (psaume 126 sur l'API publique de Sefaria, sans rien du projet dans la requête), qui montre que le décalage vient de la source ; pour les autres défauts, la part de Sefaria et celle du script reste une déduction. La cause des « . . » anglais n'est pas vérifiée sur le texte brut. Je n'ai pas vu l'affichage réel sur téléphone ni dans le navigateur (constats tirés des données et du code). Les parties liturgiques du Tikkoun, traduites par IA, sont hors de ce volet : je n'y ai regardé que les noms divins. L'application Nokia ne contient aucun texte du Tanakh. Un auditeur précédent avait laissé des scripts dans le même dossier : je les ai consultés comme pistes, tous les chiffres rendus ici viennent de mes propres scripts.

## Ce qui tient

- La numérotation est juste partout : 150 psaumes sur 150 ont le même nombre de versets en hébreu, en français et en anglais (2 527 chacun), aucun verset vide, et le premier et le dernier verset de chaque psaume traduisent bien le verset hébreu dans les deux langues. Les psaumes à suscription longue (3, 7, 18, 30, 34, 51, 52, 54, 56, 57, 59, 60, 63, 102, 142) sont alignés dès les trois premiers versets : la suscription compte bien pour le verset 1 dans les trois textes.
- La copie des dix psaumes du Tikkoun est strictement identique à tehilim.json : 164 versets comparés par script dans les trois langues, zéro différence.
- Esther (10 chapitres, 167 versets) et Chir haChirim (8 chapitres, 117 versets) sont alignés chapitre par chapitre, premier et dernier verset vérifiés à la lecture, aucun bloc sans traduction.
- L'anglais du JPS 1917 est fiable sur le sens : aucun contresens, aucune omission et aucun décalage dans les 781 versets lus ni dans les contrôles par ancres ; le Tétragramme y est « the LORD » dans 621 versets sur 622 et les 71 « Selah » sont tous là.
- Le nettoyage de fond est réussi : aucune balise HTML, aucune entité, aucun texte de note, aucun caractère mal encodé ni invisible dans les 5 622 traductions ; les crochets (152 en français, 36 en anglais) sont tous appariés et sont ceux des traducteurs ; l'apostrophe française est typographique partout.
- Le script exige la licence « Public Domain » pour chaque chapitre téléchargé, s'arrête sur tout écart de nombre de versets, et inscrit édition, licence et source dans chaque fichier : la traçabilité existe dans les données, il ne manque que l'affichage.

## Constats

### TANAKH-01 — FR : quatre décalages de versets dans Tehilim (Ps 11, 78, 98, 126) — la traduction d'un demi-verset est affichée sous le verset voisin

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** Le nombre de versets est juste partout (2 527 = 2 527), mais dans quatre psaumes la coupure française ne tombe pas au même endroit que la coupure hébraïque : une proposition du verset N est rangée dans le verset N+1 (Ps 11, 78, 126) ou une proposition du verset N+1 dans le verset N (Ps 98). En lecture hébreu+français, le lecteur voit sous un verset une traduction amputée et sous le suivant une traduction qui commence par autre chose. Étendue : une proposition à chaque fois, 8 versets touchés, aucun décalage qui se propage au reste du psaume. Origine : la segmentation de la version « Bible du Rabbinat 1899 [fr] » de Sefaria (vérifié en ligne pour le Ps 126 : l'API renvoie déjà ce découpage) ; le script ne contrôle que le nombre de versets. L'anglais JPS n'a aucun décalage.

**Preuve.** RAW/tehilim.json, traductions.fr.psaumes (indices à partir de 0).
• [125][1]-[125][2] Ps 126:2-3. Hébreu 126:2 « אז ימלא שחוק פינו ולשוננו רנה אז יאמרו בגוים הגדיל יהוה לעשות עם אלה » ; FR 126:2 « Alors notre bouche s’emplit de chants joyeux et notre langue d’accents d’allégresse. » (la seconde moitié manque) ; FR 126:3 « Alors on s’écria parmi les peuples: "Le Seigneur a fait de grandes choses pour ces gens!" Oui, l’Éternel a fait de grandes choses à notre égard, profonde est notre joie. » pour l'hébreu « הגדיל יהוה לעשות עמנו היינו שמחים ».
• [77][18]-[77][19] Ps 78:19-20. Hébreu 78:19 « וידברו באלהים אמרו היוכל אל לערך שלחן במדבר » ; FR 78:19 « Ils tinrent des propos contre Dieu, disant: » ; FR 78:20 commence par « "Dieu pourra-t-il dresser une table dans le désert? Sans doute il a frappé un rocher… ».
• [10][1]-[10][2] Ps 11:2-3. Hébreu 11:2 « …כוננו חצם על יתר לירות במו אפל לישרי לב » ; FR 11:2 s'arrête à « fixent leur flèche sur la corde, » ; FR 11:3 « pour la lancer, dans les ténèbres, contre les cœurs droits. Si les fondements sont renversés, que peut faire le juste?" ».
• [97][1]-[97][2] Ps 98:2-3. Hébreu 98:3 commence par « זכר חסדו ואמונתו לבית ישראל » ; FR 98:2 se termine par « …il a manifesté sa justice. Il s’est souvenu de sa grâce » (sans ponctuation) et FR 98:3 commence par « et de sa bonté pour la maison d’Israël; ».

**Correction proposée.** Corriger à la main dans tehilim.json (aucun de ces psaumes n'est dans le Tikkoun) et consigner les corrections dans une table du script, puisque la source en ligne porte l'erreur :
• 126:2 « Alors notre bouche s’emplit de chants joyeux et notre langue d’accents d’allégresse. Alors on s’écria parmi les peuples: "Le Seigneur a fait de grandes choses pour ces gens!" » ; 126:3 « Oui, l’Éternel a fait de grandes choses à notre égard, profonde est notre joie. »
• 78:19 « Ils tinrent des propos contre Dieu, disant: "Dieu pourra-t-il dresser une table dans le désert? » ; 78:20 « Sans doute il a frappé un rocher, et les eaux ont jailli, des torrents se sont précipités: pourra-t-il aussi donner du pain? Sera-t-il capable d’apprêter de la viande à son peuple?" »
• 11:2 « Car voici que les méchants bandent leur arc, fixent leur flèche sur la corde, pour la lancer, dans les ténèbres, contre les cœurs droits. » ; 11:3 « Si les fondements sont renversés, que peut faire le juste?" »
• 98:2 « L’Éternel a fait éclater son secours; aux yeux des nations, il a manifesté sa justice. » ; 98:3 « Il s’est souvenu de sa grâce et de sa bonté pour la maison d’Israël; toutes les extrémités de la terre ont été témoins du secours de notre Dieu. »
Mesure d'ensemble : une relecture humaine du français verset contre verset reste nécessaire pour les 1 800 versets que je n'ai couverts que par script (les petits glissements d'un ou deux mots échappent aux détecteurs).

**Note du contre-expert.** J'ai rouvert tehilim.json. Les quatre décalages sont exacts tels que cités : Ps 11:2-3, 78:19-20, 98:2-3 et 126:2-3, 8 versets en tout. Ils ne se propagent pas (11:4, 78:21, 98:4 et 126:4 sont alignés), les totaux font bien 2 527 = 2 527, et un balayage des longueurs FR/EN/HE ne trouve aucun autre décalage, ni en français ni en anglais. Tehilim.traduction() affiche bien la traduction verset par verset, et traductions_tanakh.py ne redécoupe rien : il ne fait que propre() et typo(), donc le défaut vient forcément de la source. En revanche la gravité « majeur » est surévaluée : aucun mot ne manque, le sens n'est pas altéré, le texte se lit correctement d'un verset à l'autre, et le cas est isolé (4 sur 2 527). Les corrections proposées sont justes.

### TANAKH-02 — FR : mots du texte hébreu absents de la traduction (Ps 60:2, 106:1, Esther 1:14, trois « Sélah », Ps 56:8, Esther 5:2)

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** Huit versets où un élément du texte massorétique n'est pas traduit en français, alors que l'anglais le rend. Trois omissions portent sur du contenu (un peuple, une proposition, un titre), trois sur « Sélah » (68 en français pour 71 en hébreu et 71 en anglais), deux sur un mot isolé. Relevé par ancres (noms propres, Sélah) sur tout le corpus et par lecture de 781 versets ; d'autres omissions de mots sans ancre sont probables dans les 2 030 versets non lus.

**Preuve.** • RAW/tehilim.json traductions.fr.psaumes[59][1] (Ps 60:2) : hébreu « בהצותו את ארם נהרים ואת ארם צובה » ; FR « à l’occasion de sa guerre avec les Syriens de Çoba, lorsque Joab… » — ארם נהרים manque.
• [105][0] (Ps 106:1) : hébreu « הללויה הודו ליהוה כי טוב כי לעולם חסדו » ; FR « Alléluia! Rendez hommage à l’Éternel, car sa grâce dure à jamais. » — « כי טוב » manque (présent en 107:1, 118:1, 136:1).
• RAW/livre_meguilat_esther.json textes[0].sections[0].blocs[13] (Esther 1:14) : hébreu « שבעת שרי פרס ומדי ראי פני המלך » ; FR « les sept seigneurs qui avaient accès auprès de la personne du roi » — « פרס ומדי » manque.
• Sélah : [19][3] Ps 20:4 « …ועולתך ידשנה סלה » / « …et fasse bon accueil à tes holocaustes! » ; [20][2] Ps 21:3 ; [45][3] Ps 46:4.
• [55][7] Ps 56:8 : « באף עמים הורד אלהים » / « avec indignation jette à bas ces peuples. » — אלהים manque.
• Esther 5:2 (sections[4].blocs[1]) : « את אסתר המלכה » / « Lorsque le roi aperçut Esther debout dans la cour » — המלכה manque.

**Correction proposée (revue par le contre-expert).** Les corrections proposées pour Ps 60:2, 106:1, 20:4, 21:3, 46:4, 56:8 et Esther 5:2 sont bonnes. Pour Esther 1:14, il ne faut pas ajouter de point final : « et ceux qui l’approchaient de plus près, c’étaient Carchena, Chêtar, Admata, Tarchich, Mérés, Marsena, Memoukhan, les sept seigneurs de Perse et de Médie, qui avaient accès auprès de la personne du roi et tenaient le premier rang dans le royaume » (la phrase se poursuit en 1:15). Les corrections sont à consigner dans une table de tools/traductions_tanakh.py, sans quoi une nouvelle extraction depuis Sefaria les effacerait. Il faut aussi faire pointer ce script vers android/app/src/main/livres/livres.json : il lit et écrit aujourd'hui RAW/livres.json, qui n'existe plus depuis le découpage du 04/11.

**Note du contre-expert.** J'ai vérifié les huit versets dans tehilim.json et livre_meguilat_esther.json : il manque bien en français ארם נהרים (60:2), כי טוב (106:1), פרס ומדי (Esther 1:14), אלהים (56:8) et המלכה (Esther 5:2), et l'anglais rend chaque fois le mot. Recompté par script, « Sélah » apparaît 71 fois en hébreu (y compris les deux formes liées par un maqaf en 62:5 et 82:2), 71 en anglais et 68 en français ; les trois manquants sont 20:4, 21:3 et 46:4. Ce sont des omissions réelles mais ponctuelles : un nom, un vocatif, un titre, trois Sélah sans contenu sémantique. Aucune n'inverse le sens, donc c'est mineur et non majeur. La correction d'Esther 1:14 est fautive : elle ajoute un point final, alors que dans cette traduction la phrase continue au verset 15 (« le roi demanda… »).

### TANAKH-03 — FR : faux sens dans le Tikkoun, Ps 42:9 — « לאל חיי » rendu par « au Dieu vivant »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le verset dit « prière au Dieu de ma vie » (חַיָּי, avec suffixe de première personne). Le français reprend l'expression du verset 3 (« אל חי », Dieu vivant), qui n'est pas celle du verset 9. L'anglais est juste (« the God of my life »). Le verset est lu à chaque Tikkoun haKlali.

**Preuve.** RAW/tikkun_haklali.json psaumes[3].versets[8] et RAW/tehilim.json traductions.fr.psaumes[41][8] : hébreu « יוֹמָם יְצַוֶּה יְהוָה חַסְדּוֹ וּבַלַּיְלָה שִׁירוֹ עִמִּי תְּפִלָּה לְאֵל חַיָּי » ; FR « …que la nuit un cantique en son honneur soit sur mes lèvres, ma prière au Dieu vivant! » ; EN « even a prayer unto the God of my life ».

**Correction proposée.** « Puisse l’Éternel chaque jour mettre sa grâce en œuvre! que la nuit un cantique en son honneur soit sur mes lèvres, ma prière au Dieu de ma vie! » — à corriger dans les deux fichiers (la copie du Tikkoun est identique à celle de Tehilim).

### TANAKH-04 — FR : Ps 52:2 — « Abimélec » pour אֲחִימֶלֶךְ (Ahimélec), un autre personnage

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** La suscription du psaume 52 nomme le prêtre Ahimélec de Nov (I Samuel 22). Le français écrit « Abimélec », nom du roi philistin du psaume 34:1 (où il est juste). Erreur de fait sur le verset ; l'anglais porte « Ahimelech ».

**Preuve.** RAW/tehilim.json traductions.fr.psaumes[51][1] : hébreu « בָּא דָוִד אֶל־בֵּית אֲחִימֶלֶךְ » ; FR « "David est entré dans la maison d’Abimélec." » ; EN « 'David is come to the house of Ahimelech.' ». À comparer avec [33][0] (Ps 34:1) « לפני אבימלך » / « devant Abimélec ».

**Correction proposée.** « lorsque Doëg l’Iduméen fut venu faire un rapport à Saül en lui disant: "David est entré dans la maison d’Ahimélec." »

### TANAKH-05 — FR : le Nom adressé à Dieu n'est pas traduit dans cinq versets, et s'écrit en minuscule en Ps 4:7

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Sur les 622 versets du corpus qui portent le Tétragramme (sans אדני), cinq le perdent entièrement en français quand il est au vocatif : la phrase reste correcte mais l'invocation a disparu. L'anglais le rend dans les cinq cas (« O LORD »). S'y ajoutent Ps 130:3 (deux Noms en hébreu, un seul en français) et Ps 4:7 où le Nom est écrit « seigneur » sans majuscule.

**Preuve.** RAW/tehilim.json traductions.fr.psaumes :
• [39][11] Ps 40:12 « אתה יהוה לא תכלא רחמיך ממני » / « Toi, non plus, ne me refuse pas ta clémence; »
• [53][7] Ps 54:8 « אודה שמך יהוה כי טוב » / « je louerai ton nom, car il signifie bonté. »
• [85][10] Ps 86:11 « הורני יהוה דרכך » / « Instruis-moi dans tes voies, »
• [118][32] Ps 119:33 « הורני יהוה דרך חקיך » / « Enseigne-moi le chemin de tes préceptes, »
• [138][20] Ps 139:21 « הלוא משנאיך יהוה אשנא » / « A coup sûr, je déteste ceux qui te haïssent, »
• [3][6] Ps 4:7 « אור פניך יהוה » / « la lumière de ta face, ô seigneur! »
• [129][2] Ps 130:3 « אם עונות תשמר יה אדני מי יעמד » / « Si tu tenais compte de [nos] fautes, Seigneur, qui pourrait subsister [devant toi?] »

**Correction proposée.** • 40:12 « Toi non plus, Éternel, ne me refuse pas ta clémence; que ta grâce et ta bonté me protègent sans cesse! »
• 54:8 « De tout cœur je veux t’offrir des sacrifices; je louerai ton nom, Éternel, car il est bon. »
• 86:11 « Instruis-moi, Éternel, dans tes voies, je veux marcher dans ta vérité; dispose mon cœur à révérer ton nom. »
• 119:33 « Enseigne-moi, Éternel, le chemin de tes préceptes, je veux en suivre les traces. »
• 139:21 « A coup sûr, Éternel, je déteste ceux qui te haïssent, j’ai en horreur ceux qui se dressent contre toi. »
• 4:7 « …la lumière de ta face, ô Seigneur! »
• 130:3 « Si tu tenais compte de [nos] fautes, ô Dieu, Seigneur, qui pourrait subsister [devant toi]? »
Contrôle par script à garder : tout verset dont l'hébreu porte יהוה et dont le français n'a ni « Éternel », ni « Seigneur », ni « Dieu ».

### TANAKH-06 — EN+FR : résidus du retrait des notes de Sefaria — 52 versets anglais à ponctuation orpheline, appels de note collés aux mots, lettre hébraïque et guillemets parasites en français

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Aucune balise, entité ni note de bas de page ne subsiste, mais le retrait a laissé des traces visibles. Anglais : 52 versets se terminent par un signe isolé après une espace (« . . », « ; . », « ; : », « Selah . », « — . ») ou en portent un au milieu (111:1) ; deux appels de note « a » sont restés collés au mot suivant ; quatre génitifs ont perdu leur espace. Français : une lettre hébraïque « י » isolée termine deux versets, et deux guillemets droits flottent au milieu de Ps 60:9-10 (absents du doublet Ps 108:9-10). Cause probable côté script : propre() retire &lt;i class="footnote">…&lt;/i> de façon non gourmande et laisse ce qui suit une balise &lt;i> imbriquée (non vérifié sur le texte brut, inaccessible).

**Preuve.** RAW/tehilim.json traductions.en.psaumes — 50 versets : 12:6, 18:4, 18:21, 19:8, 25:19, 27:5, 35:7, 35:26, 44:21, 45:12, 47:2, 48:14, 49:20, 50:19, 51:15, 56:1, 61:6, 63:3, 67:4, 68:14, 69:13, 69:31, 71:8, 73:21, 77:4, 78:4, 78:43, 78:64, 79:10, 80:16, 85:3, 86:11, 88:6, 89:27, 89:31, 96:4, 102:22, 103:13, 104:11, 107:14, 111:1, 115:7, 119:7, 119:52, 119:75, 119:163, 132:7, 136:1, 139:1, 139:20 ; plus Chir 1:15 et 7:7. Exemples : Ps 19:8 « making wise the simple. . » ; Ps 89:31 « in Mine ordinances; : » ; Ps 111:1 « with my whole heart, . In the council of the upright » ; Ps 77:4 (Tikkoun) « my spirit fainteth. Selah . ».
• Appels collés : Ps 132:6 « in the field of athe wood. » (hébreu בשדי יער) ; Esther 9:25 « but when ashe came before the king ».
• Espaces perdues : Esther 3:10 et 9:10 « the Jews’enemy » ; Chir 1:8 « the shepherds’tents » ; Chir 4:8 « the lions’dens ».
• FR : Ps 39:12 « …n’est qu’un souffle! Sélah! י » ; Ps 109:18 « …dans ses membres. י » ; Ps 60:9 « Ephraïm " est la puissante sauvegarde de ma tête » ; Ps 60:10 « sur Edom, " je jette ma sandale ».

**Correction proposée.** Correction par script puis contrôle : supprimer en fin de verset tout signe isolé précédé d'une espace (expression « \s+[.;:,]+$ ») ; 111:1 → « with my whole heart, In the council of the upright, and in the congregation. » ; 132:6 → « We found it in the field of the wood. » ; Esther 9:25 → « but when she came before the king » ; « the Jews’ enemy », « the shepherds’ tents », « the lions’ dens ». Français : retirer « י » en 39:12 et 109:18 ; 60:9 → « Ephraïm est la puissante sauvegarde de ma tête, Juda est mon sceptre. » ; 60:10 → « sur Edom, je jette ma sandale. » Corriger propre() (retirer les notes avec un analyseur HTML, pas une expression non gourmande) et ajouter au script un test qui échoue sur ces motifs. Les psaumes du Tikkoun (77:4) sont à corriger dans les deux fichiers.

### TANAKH-07 — EN : coquilles et majuscules de révérence mal placées, dont trois dans le Tikkoun (Ps 42:4, 42:11, 77:2) et trois dans le psaume 91

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le JPS 1917 réserve la majuscule aux pronoms qui désignent Dieu. Dans cinq versets relevés, elle est appliquée à un homme, ce qui change le référent : en Ps 42 l'ennemi demande au psalmiste « où est ton Dieu », en Ps 91 c'est le fidèle qui est protégé. S'y ajoutent une coquille dans le Tikkoun, un Tétragramme en minuscules et un pluriel manquant.

**Preuve.** RAW/tikkun_haklali.json et RAW/tehilim.json (traductions.en) :
• Ps 42:4 et 42:11 (psaumes[3].versets[3] et [10]) : « איה אלהיך » / « 'Where is Thy God?' »
• Ps 77:2 (psaumes[5].versets[1]) : « קולי אל אלהים ואצעקה » / « I will lift up my voice unto God, an cry; »
• Ps 91:7 ([90][6]) : « יפל מצדך אלף ורבבה מימינך » / « A thousand may fall at Thy side, And ten thousand at Thy right hand; »
• Ps 91:16 ([90][15]) : « ואראהו בישועתי » / « And make Him to behold My salvation.' »
• Ps 68:27 ([67][26]) : « ברכו אלהים יהוה » / « Even the Lord » (seul verset sur 622 où יהוה n'est pas « the LORD »).
• Esther 2:12 : « וששה חדשים בבשמים » / « and six month with sweet odours ».

**Correction proposée.** • 42:4 et 42:11 : « 'Where is thy God?' »
• 77:2 : « I will lift up my voice unto God, and cry; »
• 91:7 : « A thousand may fall at thy side, And ten thousand at thy right hand; It shall not come nigh thee. »
• 91:16 : « With long life will I satisfy him, And make him to behold My salvation.' »
• 68:27 : « Even the LORD, ye that are from the fountain of Israel. »
• Esther 2:12 : « and six months with sweet odours ».
Une relecture anglaise ciblée sur Thou/Thee/Thy/Him adressés à un homme reste à faire sur les versets non lus : ce défaut ne se détecte pas par script.

### TANAKH-08 — FR : coquilles de numérisation (I/l confondus, accents, lettres parasites) — 19 relevées

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le texte français porte les fautes typiques d'une reconnaissance optique non relue : « I » majuscule pour « l » minuscule et l'inverse, accents faux, signes transformés. Relevé par dictionnaire et motifs sur les 2 811 versets, complété par la lecture ; les fautes qui donnent un mot existant (« ta » pour « la ») ne se trouvent qu'à la lecture, il en reste donc.

**Preuve.** RAW/tehilim.json (traductions.fr) : Ps 2:12 « n’alliez a votre perte » ; 4:7 « ô seigneur! » ; 22:32 « IIs viendront » ; 23:5 « tu parfumes d’huile ma tète » ; 34:22 « Là perversité cause la mort du pécheur » ; 62:1 « Sur ledouthoun » (39:1 et 77:1 : « Iedouthoun ») ; 62:6 « car en lul est mon espoir » ; 62:11 « et dans! a rapine ne placez pas » ; 64:5 « sur l’homme intègre, la visant soudainement » ; 77:11 « [à mon égard ] » ; 81:17 « la mœlle du froment » ; 105:19 (Tikkoun) « jusqu’à ce que s’accomplit sa prédiction » ; 140:12 « dans le pays l Que l’homme de violence ».
RAW/livre_meguilat_esther.json : 2:6 « II avait été déporté » ; 6:4 « qu’on pendit Mardochée » ; 6:11 « par la grande place de ta ville, en s’écriant devant lui: « Voilà ce qui, se fait » ; 8:7 « dit à Ia reine Esther ».
RAW/livre_chir_hachirim.json : 4:11 « coulent sous ta -langue ».

**Correction proposée.** « à votre perte » ; « ô Seigneur! » ; « Ils viendront » ; « ma tête » ; « La perversité » ; « Sur Iedouthoun » ; « car en lui est mon espoir » ; « et dans la rapine ne placez pas un vain espoir » ; « le visant soudainement » ; « [à mon égard] » ; « la moelle du froment » ; « jusqu’à ce que s’accomplît sa prédiction » ; « dans le pays! Que l’homme de violence » ; « Il avait été déporté » ; « qu’on pendît Mardochée » ; « par la grande place de la ville, en s’écriant devant lui: « Voilà ce qui se fait pour l’homme que le roi veut honorer! » » ; « dit à la reine Esther » ; « sous ta langue ». Mesure d'ensemble : passer tout le français au correcteur orthographique avec une liste blanche des noms propres, puis relecture humaine.

### TANAKH-09 — FR : ponctuation perdue — aucun tiret dans tout le français, phrases soudées, 14 versets sans ponctuation finale

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le texte français ne contient pas un seul tiret (0 « — » contre 51 en anglais) : les incises que l'édition marque par des tirets sont soudées à la phrase, qui devient incorrecte ou ambiguë. Plusieurs points-virgules manquent ou sont mal placés. 14 versets se terminent sans aucun signe.

**Preuve.** RAW/tehilim.json (traductions.fr) :
• Ps 124:1 « "Si l’Éternel n’avait été avec nous peut bien dire Israël » ; Ps 129:1 « "Violemment on m’a persécuté dès ma jeunesse peut bien dire Israël » (hébreu « יאמר נא ישראל », incise).
• Ps 55:13 « je pourrais le supporter ce n’est pas un adversaire haineux qui me traite de haut, je pourrais me mettre à l’abri contre lui »
• Ps 51:18 « je les offrirais volontiers tu ne prends point plaisir aux holocaustes: » ; Ps 51:21 « holocaustes et victimes parfaites alors on présentera des taureaux »
• Ps 47:10 « Que les plus nobles d’entre les nations s’assemblent le peuple du Dieu d’Abraham! »
• Ps 118:14 « Il est ma force et ma gloire, l’Éternel il a été un sauveur pour moi. » ; Ps 135:1 « Louez le nom de l’Éternel louez-le, serviteurs de l’Éternel, »
• Esther 9:1 « …prendre le dessus sur eux ce fut le contraire qui eut lieu » ; Esther 3:15 « et dans Suse, la capitale; l’édit fut [aussi] publié » ; Esther 5:14 « parle au roi; pour qu’on y pende Mardochée » ; Esther 7:2 « Fais connaître ta demande; reine Esther ».
• Sans signe final : Ps 37:16, 44:16, 48:14, 51:1, 55:13, 98:2, 103:17, 124:1, 129:1, 130:3 ; Esther 1:14, 2:12 (plus 39:12 et 109:18, voir les résidus).

**Correction proposée.** • 124:1 « Cantique des degrés. De David. "Si l’Éternel n’avait été avec nous — peut bien dire Israël — » ; 129:1 « Cantique des degrés. "Violemment on m’a persécuté dès ma jeunesse — peut bien dire Israël — »
• 55:13 « Car ce n’est pas un ennemi qui m’outrage: je pourrais le supporter; ce n’est pas un adversaire haineux qui me traite de haut: je pourrais me mettre à l’abri contre lui; »
• 51:18 « Car tu ne souhaites pas de sacrifices — je les offrirais volontiers —, tu ne prends point plaisir aux holocaustes: » ; 51:21 « …holocaustes et victimes parfaites; alors on présentera des taureaux sur ton autel. »
• 47:10 « Que les plus nobles d’entre les nations s’assemblent, le peuple du Dieu d’Abraham! »
• 118:14 « Il est ma force et ma gloire, l’Éternel; il a été un sauveur pour moi. » ; 135:1 « Alléluia! Louez le nom de l’Éternel, louez-le, serviteurs de l’Éternel, »
• Esther 9:1 « …prendre le dessus sur eux, ce fut le contraire qui eut lieu, » ; 3:15 « et dans Suse, la capitale, l’édit fut [aussi] publié. » ; 5:14 « parle au roi, pour qu’on y pende Mardochée. » ; 7:2 « Fais connaître ta demande, reine Esther, »
Ajouter le point final manquant (37:16, 44:16, 103:17, Esther 1:14 et 2:12…). Les tirets d'origine sont à reprendre sur l'édition imprimée ou sur Wikisource, que je n'ai pas pu consulter.

### TANAKH-10 — FR+EN : guillemets désappariés et de trois sortes selon le livre

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Français : guillemets droits " dans Tehilim et Chir haChirim (247), guillemets français « » dans Esther, où l'on compte 36 ouvrants pour 31 fermants ; deux discours se ferment par un guillemet ouvrant, un autre n'est jamais ouvert. Dans Tehilim, quatre psaumes et un chapitre du Cantique ont un nombre impair de guillemets. Anglais : apostrophe droite ' dans Tehilim (290), guillemets courbes ‘ ’ dans Esther et le Cantique, et mélange des deux dans un même verset.

**Preuve.** • Esther 2:4 (sections[1].blocs[3]) : « qu’elle devienne reine à la place de Vasthi! « La chose fut approuvée par le roi » ; Esther 7:6 : « Cet homme, répliqua Esther, cruel et acharné; c’est ce méchant Aman que voilà! « Aman fut atterré » ; Esther 6:10 : « Va vite, dit le roi à Aman, … tout ce que tu as proposé. » » (fermé sans avoir été ouvert) ; Esther 7:5 : discours ouvert, jamais fermé.
• Tehilim : Ps 24:8 « Qui donc est ce roi de gloire?" L’Éternel fort et puissant » (pas d'ouvrant ; 24:10 en a un) ; Ps 31:23 « "Je suis banni loin de tes yeux! Mais tu as entendu… » (jamais fermé) ; nombres impairs aux Ps 24, 31, 60, 91 et en Chir 7 (7:9).
• EN : Ps 27:8 « ‘Seek ye My face'; » ; Ps 14:4 « ’Shall not all the workers of iniquity know it… the LORD?' » ; Ps 110:1 « ‘Sit thou at My right hand… thy footstool.' ».

**Correction proposée.** • Esther 2:4 « …à la place de Vasthi! » La chose fut approuvée par le roi, et il en décida ainsi. » ; 7:6 « « Cet homme, répliqua Esther, cruel et acharné, c’est ce méchant Aman que voilà! » Aman fut atterré en présence du roi et de la reine. » ; 6:10 « « Va vite, dit le roi à Aman, … » » ; 7:5 fermer après « d’agir de la sorte? ».
• Ps 24:8 « "Qui donc est ce roi de gloire?" L’Éternel fort et puissant, l’Éternel, héros dans la guerre. » ; Ps 31:23 « "Je suis banni loin de tes yeux!" Mais tu as entendu ma voix suppliante… »
• EN : 27:8 « 'Seek ye My face'; » ; 14:4 « 'Shall not… » ; 110:1 « 'Sit thou… ».
Règle d'ensemble : une seule sorte de guillemets par langue (« » en français comme le reste de l'application, ‘ ’ en anglais), appliquée par script, avec un test de parité par chapitre.

### TANAKH-11 — FR+EN : l'édition et la licence des traductions ne sont affichées nulle part ; l'anglais de 1917 (thou, thee, hath dans 65 % des versets) n'est pas annoncé

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les fichiers portent bien l'édition (« Bible du Rabbinat 1899 (dir. Zadoc Kahn) — via Sefaria », « The Holy Scriptures: A New Translation (JPS 1917) — via Sefaria », licence Public Domain, source), mais aucun écran ne la montre : Tehilim.kt ne lit que traductions.&lt;langue>.psaumes, Tikkun.kt ne lit que l'édition hébraïque, et les fichiers de livres du site n'ont même plus la clé « traductions ». Aucune chaîne d'interface ne contient « Rabbinat », « JPS », « 1899 » ou « 1917 ». Le lecteur anglais passe sans avertissement de l'anglais moderne des textes de l'application (« Hashem », « you ») à un anglais biblique ancien : 1 839 versets sur 2 811 (65 %) portent au moins une forme archaïque, 4 173 formes au total (thy 863, thou 600, unto 548, thee 337, hath 182, hast 176, ye 124, verbes en -eth/-est). Le français de 1899 se lit sans peine mais garde un vocabulaire daté (« chef des chantres », « Cantique des degrés », « cilice », « vindictes », imparfaits du subjonctif). Le domaine public n'oblige à rien ; c'est une information due au lecteur, qui expliquerait aussi les crochets [ ] des traducteurs (152 en français, 36 en anglais).

**Preuve.** RAW/tehilim.json traductions.fr.edition et traductions.en.edition (présents) ; K/Tehilim.kt lignes 38-43 (« trad.optJSONObject(l)?.optJSONArray("psaumes") », l'édition n'est pas lue) ; K/Tikkun.kt lignes 95-105 (seule _meta.edition, hébraïque) ; recherche sans résultat de « Rabbinat|JPS|1917|1899 » dans A/res/values*/strings.xml, K et web/src. Exemples d'anglais : Ps 1:1 « HAPPY IS the man that hath not walked… » ; Ps 42:6 « Why art thou cast down, O my soul? And why moanest thou within me? » ; Ps 90:13 « And let it repent Thee concerning Thy servants. »

**Correction proposée.** Afficher sous le titre de Tehilim, du Tikkoun, d'Esther et de Chir haChirim, quand une traduction est visible, une ligne lue dans le JSON. Français : « Traduction : Bible du Rabbinat (1899), domaine public. Les mots entre crochets sont ajoutés par les traducteurs. » Anglais : « Translation: The Holy Scriptures, Jewish Publication Society, 1917 (public domain), in the English of its time (thou, thee, hath). Words in brackets are supplied by the translators. » Hébreu : « תרגום צרפתי: Bible du Rabbinat, 1899 · תרגום אנגלי: JPS, 1917 (נחלת הכלל) ». Remettre la clé « traductions » dans les fichiers de livres du site.

### TANAKH-12 — FR+EN : le Nom est rendu de trois façons sur le même écran du Tikkoun, et le français emploie « Éternel », « Seigneur » et « Dieu » sans correspondance fixe avec l'hébreu

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** 1) Sur l'écran du Tikkoun, les versets de l'ouverture et de la clôture (traduction du 04/11) disent « Hachem » / « Hashem » (5 fois, plus 14 dans la prière de Rabbi Natan), les dix psaumes disent « l’Éternel », « le Seigneur » / « the LORD ». L'en-tête de tools/traductions_textes.py annonce pourtant que « les versets cités suivent l'usage des éditions du domaine public (l'Éternel / the LORD) », et la feuille de route (relecture du 22/09) avait posé la règle inverse d'un seul rendu, « Hachem », dans toute l'application. 2) En anglais la convention est tenue : יהוה = « the LORD » dans 621 versets sur 622, אדני = « Lord », « GOD » quand יהוה est vocalisé Elohim. En français elle ne l'est pas : יהוה est « Éternel » dans 449 des 622 versets, « Seigneur » environ 160 fois (mot qui traduit aussi אדני), « Dieu » ailleurs ; inversement אלהים et אדני deviennent parfois « l’Éternel ». Le lecteur français ne peut pas savoir quel Nom porte le verset. C'est un trait de l'édition de 1899, non une faute de copie.

**Preuve.** • RAW/tikkun_haklali.json ouverture.paragraphes_fr[1] (Ps 95:1) « Venez, chantons avec allégresse pour Hachem » contre RAW/tehilim.json traductions.fr.psaumes[94][0] « Allons, glorifions le Seigneur par nos chants » ; cloture.paragraphes_fr[0] (Ps 14:7) « Quand Hachem ramènera les captifs de Son peuple » contre [13][6] « Quand le Seigneur ramènera les captifs de son peuple » ; en anglais « Hashem » contre « the LORD ».
• יהוה rendu « Seigneur » : Ps 3:2 « יהוה מה רבו צרי » / « Seigneur, que mes ennemis sont nombreux! » ; Ps 126:3 (alors que 126:1 dit « l’Éternel »).
• יהוה rendu « Dieu » : Ps 115:9-10 « בטח ביהוה » / « confie-toi à Dieu! » ; Ps 133:3 « כי שם צוה יהוה » / « c’est là que Dieu a placé la bénédiction ».
• אלהים rendu « l’Éternel » : Ps 60:8 et 108:8 « אלהים דבר בקדשו » / « L’Éternel l’a annoncé » ; Ps 68:29 « צוה אלהיך עזך » / « L’Éternel a décrété ta victoire » ; Ps 50:2.
• אדני / אלהי rendus « l’Éternel » : Ps 90:17 (Tikkoun) « ויהי נעם אדני אלהינו » / « la bienveillance de l’Éternel, notre Dieu » ; Ps 40:18 « אלהי אל תאחר » / « Éternel, n’attends pas trop longtemps ».

**Correction proposée.** Décision du propriétaire à inscrire dans la feuille de route, puis à appliquer partout : soit « l’Éternel / the LORD » dans tous les versets, y compris ceux de l'ouverture et de la clôture du Tikkoun (« Venez, chantons avec allégresse pour l’Éternel, acclamons le Rocher de notre salut. » / « O come, let us sing unto the LORD »), soit « Hachem / Hashem » partout par remplacement contrôlé de « l’Éternel », « Éternel », « the LORD ». Dans les deux cas, règle de glossaire française : יהוה = l’Éternel, אדני = le Seigneur, אלהים = Dieu. Corrections correspondantes : 90:17 « Que la bienveillance du Seigneur, notre Dieu, soit avec nous! » ; 40:18 « mon Dieu, n’attends pas trop longtemps. » ; 60:8 et 108:8 « Dieu l’a annoncé en son sanctuaire » ; 68:29 « Ton Dieu a décrété ta victoire » ; 115:9 « Israël, confie-toi à l’Éternel! » ; 133:3 « c’est là que l’Éternel a placé la bénédiction ».

### TANAKH-13 — FR : écarts de sens de l'édition de 1899 face au texte massorétique, que l'anglais affiché à côté contredit (Ps 2:12, 105:25, 16:8, 145:12, 9:16)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** La Bible du Rabbinat traduit librement. Dans les 781 versets lus, cinq s'écartent du sens simple de l'hébreu au point qu'un relecteur les reprendrait, et en mode français+anglais les deux traductions disent des choses différentes. Le plus sensible pour le public de l'application est Ps 2:12, où « בר » est rendu par « le fils », lecture que Rachi et Radak écartent et que le JPS de 1917 ne suit pas. En Ps 105:25 (Tikkoun) le sujet du verbe change : l'hébreu dit que Dieu a tourné leur cœur. Je ne compte pas ici les simples choix entre deux lectures reçues (Ps 16:4, 48:15, 59:16, Chir 5:4).

**Preuve.** RAW/tehilim.json (traductions.fr / traductions.en) :
• [1][11] Ps 2:12 « נַשְּׁקוּ־בַר פֶּן־יֶאֱנַף » / FR « Rendez hommage au fils, de peur qu’il ne s’indigne » / EN « Do homage in purity, lest He be angry ».
• [104][24] Ps 105:25 (aussi tikkun_haklali.json psaumes[7].versets[24]) « הָפַךְ לִבָּם לִשְׂנֹא עַמּוֹ » / FR « Leur cœur changea jusqu’à prendre son peuple en haine » / EN « He turned their heart to hate His people ».
• [15][7] Ps 16:8 (Tikkoun) « כִּי מִימִינִי בַּל־אֶמּוֹט » / FR « s’il est à ma droite, je ne chancellerai pas » / EN « Surely He is at my right hand, I shall not be moved ».
• [144][11] Ps 145:12 « גְּבוּרֹתָיו וּכְבוֹד הֲדַר מַלְכוּתוֹ » (3e personne) / FR « tes hauts faits et l’éclat glorieux de ton règne ».
• [8][15] Ps 9:16 « טָבְעוּ גוֹיִם בְּשַׁחַת עָשׂוּ » (accompli) / FR « Que les peuples s’enfoncent dans la fosse qu’ils ont creusée » / EN « The nations are sunk down in the pit that they made ».

**Correction proposée.** • 2:12 « Attachez-vous à la pureté, de peur qu’il ne s’indigne, et que vous n’alliez à votre perte; car bien vite sa colère prend feu: heureux tous ceux qui s’abritent en lui! »
• 105:25 « Il changea leur cœur jusqu’à leur faire prendre son peuple en haine, et ourdir des machinations contre ses serviteurs. »
• 16:8 « Je fixe constamment mes regards sur le Seigneur; puisqu’il est à ma droite, je ne chancellerai pas. »
• 145:12 « pour faire connaître aux fils de l’homme ses hauts faits et l’éclat glorieux de son règne. »
• 9:16 « Les peuples se sont enfoncés dans la fosse qu’ils avaient creusée, leur pied s’est pris dans le filet qu’ils avaient dissimulé. »
Toute retouche fait sortir le texte de l'édition annoncée : le dire dans la mention d'édition (« texte revu »), ou laisser tel quel et l'assumer. Faire trancher 2:12 par le propriétaire.

### TANAKH-14 — FR : noms propres et termes de 1899 qui contredisent la graphie du reste de l'application (Mardochée, Aman, Sabbat, Cheol, Cebaot, « amant »)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les autres textes français de l'application écrivent « Mordekhaï » (38 fois dans Likoutei Moharan), « Haman » (34), « Chéol » (37), « Tsevaot », « Chabbat ». La Méguila et les psaumes disent « Mardochée » (55), « Aman » (53), « Assuérus » (28), « Vasthi », « Suse », « Cheol » (14), « Cebaot » (14), « Sabbat », « Alléluia » (22). À l'intérieur même du corpus, des graphies doubles : « Coré » (7) et « Koré » (4), « Cebaot » et « Cébaot », et dans le Cantique « דודי » rendu 28 fois par « bien-aimé » mais 6 fois par « amant » dans trois versets voisins.

**Preuve.** RAW/livre_meguilat_esther.json sections[1].blocs[4] (2:5) « ושמו מרדכי » / « portant le nom de Mardochée » ; sections[2].blocs[0] (3:1) « את המן בן המדתא האגגי » / « Aman, fils de Hamedata, l’Agaghite ». RAW/tehilim.json traductions.fr.psaumes[91][0] (Ps 92:1) « ליום השבת » / « pour le jour du Sabbat » ; [5][5] (Ps 6:6) « בשאול » / « dans le Cheol » ; [23][9] « L’Éternel-Cebaot » contre [79][14] « O Dieu-Cébaot! » ; [41][0] « les fils de Coré » contre [83][0] « les fils de Koré ». RAW/livre_chir_hachirim.json 5:8 « את דודי » / « mon bien-aimé » puis 5:9 « מה דודך מדוד » / « En quoi ton amant est-il supérieur aux autres amants », 5:10 « Mon amant est blanc et vermeil », 5:16 « Tel est mon amant ».

**Correction proposée.** Règle de glossaire appliquée par script, si le propriétaire veut un seul usage : Mardochée → Mordekhaï, Aman → Haman, Assuérus → A’hachvéroch, Vasthi → Vachti, Suse → Chouchan, Sabbat → Chabbat, Cheol → Chéol, Cebaot/Cébaot → Tsevaot, Koré → Coré (ou l'inverse). Cantique 5:9 « En quoi ton bien-aimé est-il supérieur aux autres bien-aimés, ô la plus belle des femmes? En quoi ton bien-aimé est-il supérieur aux autres bien-aimés, pour que tu nous conjures de la sorte? » ; 5:10 « Mon bien-aimé est blanc et vermeil, distingué entre dix mille. » ; 5:16 « Tel est mon bien-aimé, tel est mon ami, ô filles de Jérusalem! ». Sinon, garder l'édition intacte et l'annoncer.

### TANAKH-15 — FR+EN : les 18 titres de chapitres d'Esther et de Chir haChirim ne sont pas traduits, et les versets n'ont pas de numéro quand l'hébreu est masqué

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Dans ces deux livres, chaque section n'a qu'un titre hébreu (« פרק א »…), sans titre_fr ni titre_en, alors que Perek Chira, construit de la même façon, porte « Chapitre 1 ». Dans les modes de lecture « fr », « en » et « fr+en », le titre reste donc en hébreu. Le numéro de verset n'existe que dans le texte hébreu (« (א) », « (ב) ») : dans ces mêmes modes, les 284 versets s'affichent sans aucun repère. Tout le reste est traduit : 167 + 117 blocs, aucun fr ni en vide.

**Preuve.** RAW/livre_meguilat_esther.json textes[0].sections[0] = {"titre": "פרק א", "blocs": […]} (10 sections sans titre_fr / titre_en) ; RAW/livre_chir_hachirim.json : 8 sections de même. Comparaison : RAW/livre_perek_chira.json sections[0].titre_fr = « Chapitre 1 ». Bloc type : {"t": "(א) וַיְהִי בִּימֵי אֲחַשְׁוֵרוֹשׁ…", "fr": "Ce fut au temps d’Assuérus…", "en": "NOW IT came to pass…"}. Modes : web/src/js/regles.js, LanguesTexte.MODES = ['he','fr','en','he+fr','he+en','fr+en'].

**Correction proposée.** Ajouter dans la source main/livres/livres.json titre_fr « Chapitre 1 » … « Chapitre 10 » et titre_en « Chapter 1 » … « Chapter 10 » (Esther), « Chapitre 1 » … « Chapitre 8 » / « Chapter 1 » … « Chapter 8 » (Chir haChirim), puis redécouper. Faire porter le numéro par la traduction quand l'hébreu n'est pas affiché : « 1. Ce fut au temps d’Assuérus… » / « 1. Now it came to pass… », par le code de préférence (numéro tiré du rang du bloc) plutôt que dans les données.

### TANAKH-16 — EN : les noms des lettres du psaume 119 et trois débuts en capitales sont restés dans le texte des versets

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les 22 intertitres de l'édition anglaise du psaume 119 (ALEPH, BETH… TAV) ont été aspirés dans le premier verset de chaque strophe ; le français et l'hébreu n'en ont pas, de sorte que la traduction anglaise de 119:1 commence par un mot qui ne traduit rien. Les translittérations sont celles de 1917 (JOD, CAPH, KOPH, SCHIN, AIN, ZAIN). Trois livres commencent par deux mots tout en capitales, reste de la lettrine de l'édition.

**Preuve.** RAW/tehilim.json traductions.en.psaumes[118] : [0] « ALEPH. Happy are they that are upright in the way » ; [8] « BETH. Wherewithal… » ; [72] « JOD. Thy hands have made me » ; [96] « MEM. O how love I Thy law! » ; [160] « SCHIN. Princes have persecuted me » ; [168] « TAV. Let my cry come near » (22 versets : 1, 9, 17, 25, 33, 41, 49, 57, 65, 73, 81, 89, 97, 105, 113, 121, 129, 137, 145, 153, 161, 169). Débuts : Ps 1:1 « HAPPY IS the man » ; Esther 1:1 « NOW IT came to pass » ; Chir 1:1 « THE song of songs ».

**Correction proposée.** Retirer par script le préfixe « ^[A-Z]+\. » des 22 versets (« Happy are they that are upright in the way, who walk in the law of the LORD. ») ; si l'on veut garder les strophes, les afficher comme intertitres dans les trois langues à partir de la lettre hébraïque. Ps 1:1 « Happy is the man that hath not walked… » ; Esther 1:1 « Now it came to pass in the days of Ahasuerus… » ; Chir 1:1 « The song of songs, which is Solomon’s. »

### TANAKH-17 — Hébreu d'Esther et de Chir haChirim : 16 mots affichés deux fois, ketiv puis qere entre crochets, contre la convention de Tehilim

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Constat annexe aux traductions, relevé en cherchant les crochets venus de Sefaria. tehilim.json et tikkun_haklali.json déclarent « le qere est retenu : c'est la forme lue » et n'ont aucun crochet. Les deux meguilot gardent le ketiv sans voyelles suivi du qere vocalisé entre crochets : 12 fois dans Esther, 4 dans le Cantique. Pour qui suit la lecture de la Méguila, le mot apparaît en double, et les traductions n'en rendent qu'un. Deux crochets sont en outre mal formés.

**Preuve.** RAW/livre_meguilat_esther.json : 1:16 « מומכן [מְמוּכָן] » ; 3:4 « באמרם [כְּאָמְרָם] » ; 4:7 « ביהודיים [בַּיְּהוּדִים] » ; 8:1, 8:13 (deux), 9:15, 9:18 ; 9:19 « הפרוזים [הַפְּרָזִים] » ; 9:27 « וקבל [וְקִבְּלוּ] » ; 8:7 « ביהודיים [בַּיְּהוּדִים׃] » (sof pasouq à l'intérieur du crochet) ; 10:1 « אחשרש [אֲחַשְׁוֵרוֹשׁ ] » (espace avant le crochet fermant). RAW/livre_chir_hachirim.json : 1:17 « רחיטנו [רַהִיטֵנוּ] » ; 2:11 « הסתו [הַסְּתָיו] » ; 2:13 « לכי [לָךְ] » ; 4:9 « באחד [בְּאַחַת] ».

**Correction proposée.** Appliquer la convention de Tehilim : ne garder que le qere (« מְמוּכָן », « כְּאָמְרָם », « בַּיְּהוּדִים », « הַפְּרָזִים », « וְקִבְּלוּ », « אֲחַשְׁוֵרוֹשׁ », « רַהִיטֵנוּ », « הַסְּתָיו », « לָךְ », « בְּאַחַת »), sof pasouq hors crochet, par le même traitement que tools/tehilim_conversion.py, dans la source livres.json. Faire valider par le propriétaire pour la lecture de la Méguila.

### TANAKH-18 — Outil : tools/traductions_tanakh.py ne contrôle que le nombre de versets, ne peut plus être relancé (chemin livres.json périmé) et nettoie mal les notes

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : docs · **Type** : texte

**Constat.** Trois limites du script expliquent les défauts ci-dessus et gêneront leur correction. 1) Son seul contrôle est « len(fr) == len(he) » par chapitre : il a laissé passer les quatre décalages internes, les omissions et les résidus, et son en-tête présente ce contrôle comme la garantie d'alignement (« alignées verset par verset… un écart arrête tout »). 2) Il lit et réécrit RAW/livres.json, fichier qui n'existe plus : la source a été déplacée dans main/livres/livres.json et découpée par tools/livres_decoupe.py. Relancé tel quel, il réécrit tehilim.json et tikkun_haklali.json puis s'arrête sur une erreur à la ligne 104, sans toucher aux meguilot. 3) Les corrections faites à la main dans les JSON seraient écrasées par une nouvelle exécution : il n'y a ni cache du texte téléchargé ni table de corrections dans le dépôt.

**Preuve.** tools/traductions_tanakh.py : lignes 90-92 « assert len(ch[l]) == len(teh["psaumes"][i]) » (seul contrôle) ; ligne 104 « livres = json.load(open(RAW + "livres.json", encoding="utf-8")) » alors que RAW ne contient que livre_*.json et que tools/livres_decoupe.py ligne 24 donne SOURCE = android/app/src/main/livres/livres.json ; lignes 65-69 propre() : « re.sub(r"&lt;sup[^>]*>.*?&lt;/sup>|&lt;i class=\"footnote\">.*?&lt;/i>", "", t) ». Aucun cache : recherche de « Song of Songs » dans les JSON du dépôt, seuls les livres eux-mêmes répondent.

**Correction proposée.** Corriger le chemin (main/livres/livres.json, puis livres_decoupe.py) ; écrire les trois fichiers seulement quand tout a réussi ; conserver le texte brut téléchargé dans tools/ ; ajouter une table CORRECTIONS {(livre, chapitre, verset, langue): texte} appliquée après le téléchargement et qui échoue si le texte d'origine a changé ; ajouter les contrôles qui ont servi à cet audit : Sélah et noms propres présents des deux côtés, rapport de longueur hébreu/traduction par verset, ponctuation orpheline, mots hors dictionnaire, parité des guillemets. Reformuler l'en-tête : « nombre de versets vérifié ; la coupure interne des versets est celle de Sefaria, non vérifiée ».

### TANAKH-19 — FR : capitales tantôt accentuées, tantôt non (« Eternel » une fois contre « Éternel » 522 fois ; « Etre », « Elevez », « O Dieu »)

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** « Éternel », « Égypte », « Écoute » portent leur accent, mais 26 autres mots en début de phrase ne l'ont pas, ni les 25 « O » vocatifs ni les 34 « A » prépositions. Le Nom lui-même est écrit une fois sans accent.

**Preuve.** RAW/tehilim.json traductions.fr.psaumes : [141][5] Ps 142:6 « je crie vers toi, ô Eternel » ; [76][14] Ps 77:15 (Tikkoun) « l’Etre tout-puissant » ; [12][3] Ps 13:4 « Eclaire mes yeux » ; [133][1] Ps 134:2 « Elevez vos mains » ; Ps 119:29 « Eloigne », 119:39 « Ecarte », 62:9 « Epanchez », 107:5 « Eprouvés », 36:11 « Etends » ; « Ethiopie » (3), « Ephraïm » (5), « Edom » (7) ; Ps 25:22 « O Dieu! Délivre Israël » ; Ps 3:5 « A pleine voix ».

**Correction proposée.** Remplacement par script, liste fermée : Eternel → Éternel ; Etre → Être ; Eclaire → Éclaire ; Elevez → Élevez ; Eloigne → Éloigne ; Ecarte → Écarte ; Epanchez → Épanchez ; Eprouvés → Éprouvés ; Etends → Étends ; Ethiopie → Éthiopie ; Ephraïm → Éphraïm ; Edom → Édom ; « O » vocatif en début de phrase → « Ô » ; « A » préposition en début de phrase → « À ».
