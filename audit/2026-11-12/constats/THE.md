# THE — Interface hébraïque — fidélité et qualité

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

20 constats — confirmés en partie : 2 · confirmés : 1 · non contre-expertisés (mineurs et cosmétiques) : 17.

> Contre-expertise incomplète pour cette dimension.

## Ce qui a été examiné

Lu en entier : android/app/src/main/res/values-iw/strings.xml (1 428 lignes, 1 259 formes) apparié clé par clé à values/strings.xml (fichier d'appariement : OUT/the/fr_he.txt), avec l'anglais pour 23 clés douteuses ; les 45 invitations hébraïques de res/raw/guide_sujets.json ; la section hébraïque de web/src/confidentialite.html ; les passages de FEUILLE_DE_ROUTE.md sur l'hébreu, le Nom et les manques.

Contrôles par script (dossier OUT/the) : caractères spéciaux, guillemets, maqaf, mots latins, paramètres et ponctuation finale FR/HE, formes singulières ou genrées, comparaison avec la table du site déployé (myhitbodedut-web/data/strings.he.json, identique). Simulation de l'algorithme bidi sur une quarantaine de chaînes (bibliothèque python-bidi laissée par l'auditeur précédent ; elle ne gère pas les isolats, que j'ai retirés pour ces cas). Formats de date vérifiés par exécution : JVM 21 en locale he et Node Intl.

Code suivi : une quarantaine d'appels Kotlin (VolActivity, VolCalendrier, VueJour, Levana, MainActivity, PaliersActivity, FicheTrophee, MiniLecteur, Adresse, Reference, SaisieVol, Hitbodedut, ChabbatAlerte, Reminder) et leurs équivalents dans web/src/js (app.js, i18n.js) ; tools/noms_divins.py, tools/noms_abreges.py, NomsDivinsTest.kt.

Échantillonné : chizuk.json (171 textes) pour les seules graphies du Nom, pas pour la qualité du texte ; bibliotheque.json (12 occurrences du Nom, toutes des versets) ; visuels Play hébreux : 8 sur 11 ouverts (01, 02, 03, 04, 05, 07, 09, 10 et l'aperçu), plus 2 captures du site en hébreu faites par un autre auditeur.

Non examiné : le rendu réel sur un appareil ou un émulateur Android (les constats de sens d'écriture reposent sur la règle du premier caractère fort et sur la simulation, d'où la confiance moyenne) ; les layouts XML ligne à ligne ; le contenu hébreu des livres, du siddour, des hilloulot et de la halakha ; l'anglais. Nokia n'a pas d'interface hébraïque (documenté dans nokia/README.md). Aucune recherche web n'a été nécessaire. Aucun fichier modifié hors du dossier de travail.

## Ce qui tient

- Typographie hébraïque tenue de bout en bout : aucun guillemet ni apostrophe ASCII dans les 1 428 lignes, 51 maqaf, 43 guershayim et 13 guéresh aux bons endroits (דק׳, שע׳, ק״מ, מג״א, גר״א), 26 paires d'isolats LRI/PDI autour des degrés et des mesures, flèches choisies selon le sens de lecture (VolActivity.kt:196).
- Pluriels hébreux complets : 36 formes « two » avec le duel écrit (יומיים, פעמיים, שתי אפליקציות), le singulier en toutes lettres, et le même mécanisme sur le web (Intl.PluralRules avec repli sur « other »).
- Le Nom dans l'interface : « השם » partout (29 occurrences, aucune autre graphie dans strings.xml), pronoms sobres (אליו, לפניו), en accord avec « Hachem » du français.
- Vocabulaire liturgique et halakhique idiomatique, pas traduit : « הלל בדילוג », « לשאול גשמים », « שיר של יום », « עננו של היחיד », « הנץ החמה », « משיכיר » ; chiffres hébreux générés avec ט״ו/ט״ז et les inversions d'usage (Reference.kt:73-98).
- Adresse inclusive cohérente : pluriel ou infinitif dans toute l'interface (aucun impératif singulier), paires genrées חזק/חזקי et צדיק/צדקת, phrases recomposées plutôt que calquées quand le sens l'exige (dedicace_corps_demande avec « את… », vol_route_introuvable tourné pour commencer par l'hébreu).
- Parité et synchronisation : aucune chaîne traduisible manquante en hébreu (les 45 absentes sont toutes translatable=false), paramètres identiques clé par clé, table hébraïque du site déployé identique au dépôt ; les exemples de saisie de vol affichés en hébreu sont ceux que le parseur sait lire et que les tests couvrent (SaisieVolTest.kt:43-49).

## Constats

### THE-02 — Le Nom en toutes lettres dans une phrase de prose du 'hizouk, contre la règle du 04/11 ; deux règles contradictoires dans le même fichier

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** La règle du projet (décision du propriétaire, 04/11/2026) : dans les livres et le 'hizouk, le Nom est abrégé ה' hors des versets cités. Le texte by-48-2 (Bisdei Yaar chap. 48, moment « blocage », relu = true, donc publié et affiché quand on touche « המילים לא באות לי ») garde pourtant le Tétragramme entier dans une phrase d'auteur contemporain qui n'est pas un verset. Cause : l'heuristique « au bord du paragraphe, trois mots suffisent » de tools/noms_abreges.py l'a pris pour une citation ; le test ne contrôle que les formes suivies de « יתברך ». Le fichier porte en outre deux règles opposées : _meta.noms_divins (abrégé hors versets, 04/11) et editions.by.noms_divins (« développés en toutes lettres… décision du 04/10 »). Enfin trois graphies coexistent à l'écran : « השם » dans toute l'interface, « ה' » avec apostrophe ASCII dans le 'hizouk (37 textes), « ה׳ » (guéresh) dans le guide du propriétaire.

**Preuve.** android/app/src/main/res/raw/chizuk.json:3952 (id by-48-2, l. 3943) : « …שבה יעמוד וירצה ויכסוף לדבר עם יהוה. » ; :10 « noms_divins : abrégé ה' hors des versets ; en toutes lettres dans les versets cités (décision du propriétaire, 04/11/2026 ; tools/noms_abreges.py) » ; :252 « ה׳ / ה’ du texte de l'éditeur développés en toutes lettres (tools/noms_divins.py)… (décision du 04/10) ». tools/noms_abreges.py:116 « Au bord du paragraphe… trois mots suffisent ». android/app/src/test/java/com/myhitbodedut/NomsDivinsTest.kt:64 (seule vérification : le Nom entier devant יתברך). Comptage par script : 14 textes du 'hizouk contiennent le Nom entier, dont 12 versets de Tehilim, lm1-112 (citation « ה' הושיעה », gardée exprès) et by-47-1 (verset annoncé par « כמו שכתוב ») ; by-48-2 est le seul hors verset.

**Correction proposée (revue par le contre-expert).** by-48-2 (he et he_sans_nikkoud) : « …ויכסוף לדבר עם ה'. ». Supprimer ou mettre à jour editions.by.noms_divins. Dans NomsDivinsTest, exiger que tout Nom entier du 'hizouk et de la bibliothèque appartienne à une liste blanche d'identifiants de versets (les 9 Tehilim, lm1-112, by-47-1). Unifier le signe d'abréviation (ה׳ ou ה') reste facultatif, et il faudrait alors adapter le test qui cherche « ה' יתברך ».

**Note du contre-expert.** Le défaut principal est confirmé : chizuk.json, by-48-2 (he et he_sans_nikkoud, statut verifie_texte, relu=true, moment blocage, donc publiable) se termine par « ויכסוף לדבר עם יהוה. » dans une phrase d'auteur, contre la règle du 04/11 (_meta l.10, commit 416369c). La note périmée editions.by.noms_divins (« décision du 04/10 ») est bien présente, et le test ne contrôle que « יהוה יתברך ». En revanche, le comptage cité est faux : mon script trouve 12 items avec le Nom entier, dont 9 versets de Tehilim, et non 14 dont 12. La cause (règle des trois mots au bord du paragraphe) est plausible mais invérifiable sans l'export du Tanakh. ה׳ n'est pas « le reste de l'interface » : l'interface écrit השם, et ה׳ n'apparaît que dans livre_guide_hitbodedut.json. Les points sur la note de _meta et les trois graphies sont cosmétiques.

### THE-03 — Visuels Play hébreux : le Tétragramme dans une image de fiche, un compteur d'étape brouillé, des libellés que l'application n'affiche plus

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : play · **Type** : texte

**Constat.** Quatre des onze visuels hébreux ne montrent pas l'interface actuelle. (1) 04-seance-question-he.png (repris dans apercu-he.png) affiche un 'hizouk en prose avec le Nom en toutes lettres, alors que le texte livré dit aujourd'hui « מאת ה' » : c'est l'état d'avant la décision du 04/11, figé dans une image destinée à la fiche publique. (2) 01-presentation-he.png montre la pastille d'étape « 1 7 מתוך » (les deux chiffres côte à côte, le mot à droite) ; le site actuel rend correctement « 1 מתוך 7 ». (3) Son titre écrit « רגע לבד עם ה׳ » alors que l'interface, sur la même image, écrit « השם ». (4) 10-musique-he.png montre « Beyond — נעם שפייר » ; l'application affiche maintenant « Beyond — Noam Shpayer ». Par ailleurs le titre du visuel 02 emploie « תרגול », mot absent de l'interface (qui rend « pratique » par « התבודדות »).

**Preuve.** play/visuels/he/04-seance-question-he.png : « …וגם דבר זה מכוון מאת יהוה הרוצה בכיסופים… » sous « בשדי יער, פרק י״ד » ; texte livré, android/app/src/main/res/raw/chizuk.json id by-14-3 : « מכוון מאת ה' הרוצה ». play/visuels/he/01-presentation-he.png (pastille agrandie : OUT/the/chip01.png) contre la capture du site en cours, OUT/the/chip_web.png (« 1 מתוך 7 » correct). play/visuels/he/10-musique-he.png contre android/app/src/main/res/values/strings.xml:325 « Beyond — Noam Shpayer » (translatable=false). Visuels du commit 7145e65 (04/11), antérieur au commit 416369c « Le Nom abrégé ה' hors des versets cités ».

**Correction proposée (revue par le contre-expert).** Refaire les onze visuels hébreux sur la version envoyée, après correction des chaînes. Pour le visuel 04, il n'est pas nécessaire de changer de texte : refaite aujourd'hui, la capture montre « מאת ה' ». Titres facultatifs : 01 « רגע לבד עם השם », 02 « התבודדות, יום אחרי יום ».

**Note du contre-expert.** Images rouvertes : 04-seance-question-he.png (reprise dans apercu-he.png) montre « מכוון מאת יהוה הרוצה » sous « בשדי יער, פרק י״ד », alors que by-14-3 livré dit « מאת ה' » ; la pastille de 01 affiche « 1 7 מתוך » ; 10-musique-he.png montre « Beyond — נעם שפייר » et « ניגון 01… », alors que track_shpayer_beyond vaut « Beyond — Noam Shpayer » depuis d37226a (03/11) ; « תרגול » n'apparaît nulle part dans values-iw. PUBLICATION_PLAY_STORE.md §7.2 exige que les captures montrent « l'interface réelle de la version envoyée », d'où majeur. Une nuance : 7145e65 (04/11 20:56) est postérieur en date à 416369c (05:45), mais sur une branche qui ne le contient pas, et les captures sont même antérieures à d37226a, pourtant ancêtre de ce commit. Les remarques sur les titres de 01 et 02 restent cosmétiques.

### THE-01 — Compte à rebours de la prière en vol : « עד » (jusqu'à) au lieu de « נותרו » (encore), et « 1 שעות »

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** vol_dans (FR « encore %1$s », EN « %1$s left ») est traduit « עד %1$s », mot pour mot comme vol_jusqua. Sur la carte « Prière du moment » de Zmanim en vol, la ligne en gras (22 sp) affiche donc une durée précédée de « jusqu'à » : « עד 1 שע׳ ו־11 דק׳ », suivie d'une seconde ligne « עד &lt;heure> ». Deux « jusqu'à » de suite, le premier portant une durée : contresens sur une échéance de prière. À 60 minutes pile, vol_duree_heures donne en plus « 1 שעות » (pluriel avec 1). Android et web (même table de chaînes, site déployé identique).

**Preuve.** android/app/src/main/res/values-iw/strings.xml:1266 « vol_dans = עד %1$s » ; :1264 « vol_jusqua = עד %1$s » ; :1212 « widget_reste = נותרו %s » (même sens FR « encore %s », bien traduit) ; :1223 « vol_duree_heures = %1$s שעות ». Appels : android/app/src/main/java/com/myhitbodedut/VolActivity.kt:878-881 (vol_dans puis vol_jusqua, l'une sous l'autre) et :894 (minutes % 60 == 0 → vol_duree_heures) ; web/src/js/app.js:3615 et 3632 ; myhitbodedut-web/data/strings.he.json : vol_dans = « עד %1$s ».

**Correction proposée (revue par le contre-expert).** vol_dans → « עוד %1$s » (fidèle à « encore », et juste pour tous les cas : « עוד דקה אחת », « עוד 25 דקות », « עוד 1 שע׳ ו־11 דק׳ ») ; vol_duree_heures → « %1$s שע׳ » (aligné sur vol_duree_heures_minutes et duration_hours).

**Note du contre-expert.** J'ai vérifié values-iw/strings.xml : l.1266 vol_dans = « עד %1$s », identique à vol_jusqua (l.1264), alors que le FR dit « encore %1$s » et l'EN « %1$s left ». VolActivity.kt:878-881 les affiche l'un sous l'autre, et à 60 ou 120 minutes pile dureeEnMots (l.894) donne « 1 שעות ». Le site fait de même (app.js:3415, 3631-3632, strings.he.json déployé). Le défaut est réel, mais ce n'est pas un contresens sur l'échéance : « עד 1 שע׳ ו־11 דק׳ » se lit « jusqu'à 1 h 11 » et reste cohérent avec la ligne « עד &lt;heure> ». C'est une traduction maladroite, donc mineur. La réécriture « נותרו %1$s » crée par ailleurs une faute d'accord à une minute (« נותרו דקה אחת » au lieu de « נותרה דקה אחת »).

### THE-04 — Carte Birkat haLevana en hébreu : « מוצאי שבת שבת », « מ־יום », pourcentage à la française

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Trois défauts propres à l'hébreu sur la même carte. (1) levana_motsae reçoit la date du samedi formatée « EEE d MMM » ; en hébreu le jour abrégé est « שבת », d'où « מומלץ: מוצאי שבת שבת 14 נוב׳ (…) » : le mot est doublé. (2) levana_fenetre « מ־%1$s עד %2$s » reçoit une date qui commence par un mot hébreu : « מ־יום ה׳ 12 נוב׳, 16:05 עד … » ; le maqaf ne se met que devant un chiffre ou un mot latin. (3) Le pourcentage est fabriqué dans le code avec l'espace français (« 45 % ») : en paragraphe RTL le signe se détache et passe à gauche du nombre (« % 45 »), alors que le reste du fichier écrit « %1$d%% » sans espace.

**Preuve.** android/app/src/main/res/values-iw/strings.xml:1029 « מומלץ: מוצאי שבת %s (שו״ע תכ״ו, ב ורמ״א) » ; :999 « מ־%1$s עד %2$s » ; :1026 « הלבנה הערב: %1$s מוארת, %2$s ». android/app/src/main/java/com/myhitbodedut/VueJour.kt:93-94 (motifs « EEE d MMM » et « EEE d MMM, HH:mm »), :114 (« ${…} % »), :119-120 ; Levana.kt:120-125 (motsaeChabbat rend la date du samedi). Sortie d'une JVM en locale he : « יום ה׳ 12 נוב׳, 16:05 » et « שבת 14 נוב׳ » ; Node Intl (web, app.js:2786-2798) : « שבת, 14 בנוב׳ ». Simulation bidi : « תאלמתמ ,תראומ % 45 :ברעה הנבלה ».

**Correction proposée.** levana_motsae (he) → « מומלץ: במוצאי %s (שו״ע תכ״ו, ב ורמ״א) » ; levana_fenetre (he) → « מ%1$s עד %2$s » ; pourcentage : le produire selon la langue (NumberFormat.getPercentInstance(locale) sur Android, Intl.NumberFormat(langue, {style:'percent'}) sur le web), ce qui donne « 45% » en hébreu.

### THE-05 — « צריך חיזוק » : seule forme genrée de l'interface, au masculin, même pour une utilisatrice qui a choisi « צדקת »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le genre n'est exploité que pour trois paires (צדיק/צדקת, כל הכבוד…, חזק!/חזקי!). Tout le reste de l'interface contourne proprement la question par le pluriel et l'infinitif, sauf chizuk_demande_title : phrase à la première personne (« J'ai besoin de 'hizouk ») rendue au masculin singulier « צריך חיזוק ». Elle sert de titre de carte sur l'accueil, de titre d'écran et de libellé de moment ; une femme y lit une phrase d'homme. Recherche par script : aucune autre forme singulière ou genrée visant l'utilisateur dans les 1 259 formes.

**Preuve.** android/app/src/main/res/values-iw/strings.xml:1134 « chizuk_demande_title = צריך חיזוק » ; android/app/src/main/res/layout/activity_main.xml:537, layout/activity_chizuk.xml:32, android/app/src/main/java/com/myhitbodedut/Chizuk.kt:56 ; web/src/js/app.js:2125, 2286, 4689. android/app/src/main/java/com/myhitbodedut/Adresse.kt:20 : le genre ne porte que celebration_*, adresse_*, annulation_*. Visible sur play/visuels/he/09-textes-he.png.

**Correction proposée.** Forme épicène : « אני רוצה חיזוק » (רוצה s'écrit de même aux deux genres). Ou deux chaînes choisies par Adresse, comme pour חזק/חזקי : « צריך חיזוק » / « צריכה חיזוק », et la forme épicène quand rien n'est choisi.

### THE-06 — Accords de genre fautifs : « כבוי » pour la musique, « שבת מתחיל », « אושר » sous « ההתבודדות נעשתה »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Cinq accords ne suivent pas le nom auquel ils se rapportent. (1) music_off_short « כבוי » (FR « Désactivée ») sert de titre au mini-lecteur quand la musique (מוזיקה, féminin) est coupée. (2) vol_jalon_enchainement « %1$s מתחיל בצאת הכוכבים » reçoit « שבת » quand un Chabbat suit un Yom Tov : « שבת מתחיל… » (masculin) ; faux aussi pour « שמחת תורה ». (3) today_declared « אושר בלי טיימר » s'affiche juste sous le titre « ההתבודדות נעשתה היום » (FR « Validée », féminin). (4) week_done « בוצע » (description de la case du jour) contre widget_done « נעשתה היום ». (5) zmanim_absent « אינו מתרחש היום » s'écrit sous des zmanim en majorité féminins (שקיעה, עלות השחר, צאת הכוכבים, מנחה גדולה).

**Preuve.** android/app/src/main/res/values-iw/strings.xml:273 « music_off_short = כבוי » (MiniLecteur.kt:211 ; web app.js:4884) ; :1289 « %1$s מתחיל בצאת הכוכבים (⁦8.5°⁩): %2$s » (VolActivity.kt:783-791 : nom = « שבת » si j.chabbat ; VolCalendrier.kt:56 : jalon ENCHAINEMENT avec le jour suivant) ; :18 « today_declared = אושר בלי טיימר » (MainActivity.kt:802-808, sous status_done) ; :282 « week_done = בוצע » (MainActivity.kt:868) ; :638 « zmanim_absent = אינו מתרחש היום » (VueJour.kt:308).

**Correction proposée.** music_off_short → « כבויה » ; vol_jalon_enchainement → « תחילת %1$s בצאת הכוכבים (⁦8.5°⁩): %2$s » ; today_declared → « נעשתה בלי טיימר » ; week_done → « נעשתה » ; zmanim_absent → « אין היום ».

### THE-07 — Android : une phrase hébraïque qui commence par un mot latin est mise en page de gauche à droite (vol_route_trouvee, music_on_summary)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Les TextView gardent la direction par défaut (premier caractère fort). Deux chaînes hébraïques commencent par un paramètre latin : vol_route_trouvee (numéro de vol, toujours latin) et music_on_summary (titre de morceau, latin pour 34 morceaux livrés). Le paragraphe devient LTR : aligné à gauche dans un écran RTL, et les segments hébreux s'enchaînent de gauche à droite. Pour vol_route_trouvee, sur plusieurs lignes, la fin de phrase se lit avant son début (« …ולפעמים אינו מעודכן… » à droite de « adsbdb.com », « המסלול ידוע ל־ » à gauche). Le web n'est pas touché (dir=rtl sur la racine). Les autres chaînes du même écran ont été tournées pour commencer par de l'hébreu (vol_route_introuvable, vol_route_autre_depart) : celle-ci a échappé.

**Preuve.** android/app/src/main/res/values-iw/strings.xml:1240 « %1$s: %2$s. המראה %3$s, נחיתה %4$s. המסלול ידוע ל־adsbdb.com… » ; :276 « %1$s, עוצמה %2$d%% ». android/app/src/main/java/com/myhitbodedut/VolActivity.kt:1042-1046 (n.uppercase() en premier argument) et :244-246 (affichage par VueJour.texte) ; VueJour.kt:56-64 (aucun textDirection) ; MainActivity.kt:705. Simulation de l'algorithme bidi avec base LTR : « LY81: El Al. הארמה TLV, התיחנ CDG. ־ל עודי לולסמהadsbdb.com סיטרכה לומ קודבל שי :ןכדועמ וניא םימעפלו. » (ordre visuel).

**Correction proposée.** vol_route_trouvee (he) → « טיסה %1$s של %2$s: המראה %3$s, נחיתה %4$s. המסלול ידוע ל־adsbdb.com ולפעמים אינו מעודכן: יש לבדוק מול הכרטיס. » ; music_on_summary (he) → préfixer d'une marque RLM : « ‏%1$s, עוצמה %2$d%% ».

### THE-08 — vol_rapide_rien : guillemets français et marques LRM ; le guillemet ouvrant tombe au milieu de l'exemple

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le message « rien de reconnu » est la seule chaîne hébraïque à garder des guillemets « » (toutes les autres : „…”, 28 paires), encadrés de deux marques LRM. Le premier LRM range « «LY 382 » dans un segment gauche-droite : à l'écran le guillemet ouvrant apparaît entre « LY 382 » et « פריז », et le fermant, retourné par le sens RTL, prend la même forme. L'exemple semble commencer à « פריז » ; le numéro de vol reste dehors.

**Preuve.** android/app/src/main/res/values-iw/strings.xml:1408 « לא זוהה דבר. נסו למשל: [LRM]«LY 382 פריז תל אביב 12.11 בשעה 9:40»[LRM]. » (U+200E vérifiés par script). Ordre visuel simulé : « .«9:40 העשב 12.11 ביבא לת זירפ «LY 382 :לשמל וסנ ». Affiché par VolActivity.kt:392 et web app.js:3448.

**Correction proposée.** « לא זוהה דבר. נסו למשל: „LY 382 פריז תל אביב 12.11 בשעה 9:40”. », sans aucune marque (simulation : « .”9:40 … LY 382„ :לשמל וסנ », guillemets aux deux bouts).

### THE-09 — Textes de partage : « 14 » collé du mauvais côté de « MyHitbodedut », barre finale du lien déplacée

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Deux textes envoyés tels quels à d'autres applications se lisent mal en hébreu. grade_partage_texte : un nombre placé après un mot latin et « : » rejoint le segment latin ; à l'écran « 14 » se retrouve contre « ב־ » et « MyHitbodedut » contre « גביעים » (« דרגת זהב ב־14 :MyHitbodedut גביעים »). partage_lien : le lien se termine par « / », qui, en fin de paragraphe RTL, s'affiche devant « https ».

**Preuve.** android/app/src/main/res/values-iw/strings.xml:1090 « דרגת %1$s ב־MyHitbodedut: %2$d גביעים, יום אחר יום. » (PaliersActivity.kt:351, EXTRA_TEXT) ; :898 « נסו גם אתם, בחינם: %1$s » avec CelebrationActivity.kt:203 LIEN_WEB = « https://hil123.github.io/myhitbodedut-web/ » (:195, et ChizukActivity.kt:107). Ordres visuels simulés : « .םוי רחא םוי ,םיעיבג MyHitbodedut: 14־ב בהז תגרד » et « /https://example.org/app :םניחב ,םתא םג וסנ ».

**Correction proposée.** grade_partage_texte → « %2$d גביעים ודרגת %1$s ב־MyHitbodedut, יום אחר יום. » ; partage_lien → « נסו גם אתם, בחינם:\n%1$s » (le lien seul sur sa ligne forme un paragraphe gauche-droite).

### THE-10 — Bibliothèque musicale en hébreu : 24 titres en transcription française, avec des mots français

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les titres des morceaux de Noam Shpayer (10) et de Ianir (14) sont marqués translatable=false et écrits pour un lecteur français : l'interface hébraïque (et anglaise) affiche « Niggoun du Baal Chem Tov — Ianir », « Niggoun de 'Houppa — Ianir », « Zemer bichva'hin (titre incertain) — Ianir », « Niggoun « Ki hiné ka'homer » — Noam Shpayer ». Neuf titres contiennent des mots français (du, de, titre incertain, live) ; les autres sont des mots hébreux en graphie française (Hit'hadchout, Kenout, Chabbat). Les « Niggoun 01 » à « 33 » sont, eux, traduits (« ניגון 01 »). Le nom hébreu de l'artiste existait (« Beyond — נעם שפייר ») et a été remplacé lors de l'ajout des 23 morceaux.

**Preuve.** android/app/src/main/res/values/strings.xml:325-348, par exemple :338 « Niggoun du Baal Chem Tov — Ianir », :339 « Zemer bichva\'hin (titre incertain) — Ianir », :334 « Niggoun « Ki hiné ka\'homer » — Noam Shpayer » ; aucune entrée dans values-iw. myhitbodedut-web/data/strings.he.json : track_ianir_baal_shem_tov = « Niggoun du Baal Chem Tov — Ianir ». Historique : commit d37226a (remplacement de « Beyond — נעם שפייר », encore visible sur play/visuels/he/10-musique-he.png).

**Correction proposée.** Rendre ces 24 chaînes traduisibles et donner les titres hébreux d'origine, à confirmer par les deux artistes ; par exemple « ניגון הבעל שם טוב — יניר », « ניגון ברדיטשוב — יניר », « קול ביער (ניגון הסבא משפולה) — יניר », « ניגון רבי יוחנן הסנדלר — יניר », « ניגון חופה — יניר », « ניגון קבלת שבת (הופעה חיה) — יניר », « ניגון בסרביה — יניר », « אזמר בשבחין (שם לא ודאי) — יניר », « ניגון „כי הנה כחומר” — נעם שפייר », « אשת חיל — אור ונעם שפייר ». En anglais, retirer au moins les mots français.

### THE-11 — « grade » et « niveau » rendus par le même mot « דרגה »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le français et l'anglais distinguent le grade global (Bronze à Platine, selon le nombre de trophées) du niveau d'un trophée (1 à n). L'hébreu dit « דרגה » pour les deux : la fiche d'un trophée porte « דרגה 2 מתוך 5 » puis « ב[מתכת]: זה היה הגביע ה־12 שלכם », et la fête enchaîne « גביע „הרצף”: דרגה 2, … » et « דרגה חדשה: כסף ». « הדרגה הבאה: » existe deux fois avec deux sens (grade_prochain et trophee_prochain). Six chaînes de niveau sont concernées, dont deux affichées aujourd'hui.

**Preuve.** android/app/src/main/res/values-iw/strings.xml:868 « grade_titre = דרגת %1$s », :877 « דרגה חדשה: %1$s », :878 « הדרגה הבאה: %1$s, בגביע ה־%2$d. » ; :980 « trophee_niveau = דרגה %1$d מתוך %2$d · %3$s », :981 « דרגה %1$d מתוך %2$d », :984 « גביע „%1$s”: דרגה %2$d, %3$s! », :985 « הדרגה הבאה: %1$s », :986, :982. Affichage : FicheTrophee.kt:73, Confettis.kt:158, PaliersActivity.kt:77, 402, 406 ; web app.js:3944, 4169-4170. FR : « Niveau %1$d sur %2$d » / « Grade %1$s ».

**Correction proposée.** Garder « דרגה » pour le grade et rendre le niveau par « רמה » : :980 « רמה %1$d מתוך %2$d · %3$s » ; :981 « רמה %1$d מתוך %2$d » ; :984 « גביע „%1$s”: רמה %2$d, %3$s! » ; :985 « הרמה הבאה: %1$s » ; :986 « הרמה הגבוהה ביותר הושגה » ; :982 « כל גביע עולה מרמה לרמה: ארד, כסף, זהב ופלטינה. מתחת לכל אחד: הרמה שלכם, מה דורשת הבאה, וכמה כבר עשיתם. ».

### THE-12 — Nombres non accordés et maqaf devant un mot : « 1 גביעים הושגו », « רצף: 1 ימים », « ב־יומיים »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Cinq chaînes hébraïques reçoivent un nombre sans passer par un pluriel, alors que le fichier soigne ailleurs le singulier et le duel (36 formes « two »). Dès le premier trophée (gagné à la première séance) l'écran des trophées dit « 1 גביעים הושגו · עוד 9 לכסף » ; au premier jour de série, la légende de l'anneau dit « רצף: 1 ימים מתוך 3 ». bilan_minutes insère un pluriel déjà formé après « ב־ » : correct devant un chiffre (« ב־5 ימים »), faux devant un mot (« ב־יום אחד », « ב־יומיים »). Les quatre premières chaînes ont le même défaut en français et en anglais ; le maqaf est propre à l'hébreu.

**Preuve.** android/app/src/main/res/values-iw/strings.xml:869 « %1$d גביעים הושגו · עוד %2$d ל%3$s » et :870 (PaliersActivity.kt:78, n = 1 atteignable, SEUILS_GRADES = 0, 10, 25, 50) ; :98 « רצף: %1$d ימים מתוך %2$d » (MainActivity.kt:637-639) ; :876 « … ועוד %1$d גביעים בהמשך » (PaliersActivity.kt:147) ; :1096 « נשארו רק %1$d ל„%2$s”. » (Reminder.kt:141) ; :1092 « %1$s של התבודדות, ב־%2$s. » avec MainActivity.kt:600-601 (second argument = pluriel palier_n_jours : « יום אחד », « יומיים », « %1$d ימים »).

**Correction proposée.** Passer grade_sous, grade_sous_max, ring_streak_detail, trophees_autres et rappel_trophee_proche en plurals, avec en hébreu : one « גביע אחד הושג · עוד %2$d ל%3$s », two « שני גביעים הושגו · … », other inchangé ; one « רצף: יום אחד מתוך %2$d », two « רצף: יומיים מתוך %2$d » ; one « … ועוד גביע אחד בהמשך » ; one « נשאר רק 1 ל„%2$s”. ». bilan_minutes → « %1$s של התבודדות במשך %2$s. ».

### THE-13 — levana_kippour : la source citée en hébreu n'est pas celle du français et de l'anglais

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le français et l'anglais attribuent la règle « pas avant la sortie de Kippour » au seul Rema (426:2). L'hébreu reprend la parenthèse de la ligne précédente (levana_motsae) et l'attribue au Choul'han Aroukh et au Rema. La chaîne voisine levana_tisha cite bien le Rema seul, mais dans une autre forme (sans virgule, « יא » sans guershayim).

**Preuve.** android/app/src/main/res/values-iw/strings.xml:1030 « לא לפני מוצאי יום הכיפורים (שו״ע תכ״ו, ב ורמ״א) » ; :1029 « מומלץ: מוצאי שבת %s (שו״ע תכ״ו, ב ורמ״א) » ; :1031 « (רמ״א תכ״ו ב; משנה ברורה תכ״ו יא) ». android/app/src/main/res/values/strings.xml : « Pas avant la sortie de Kippour (Rema 426:2) » ; values-en : « (Rema 426:2) ».

**Correction proposée.** :1030 → « לא לפני מוצאי יום הכיפורים (רמ״א תכ״ו, ב) » ; :1031 → « לא לפני מוצאי תשעה באב (רמ״א תכ״ו, ב; משנה ברורה תכ״ו, י״א) ».

### THE-14 — Calques du français : « מעוכב », « המצב שותק », « היום אושר », et quelques tournures plaquées

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le vocabulaire de la barrière suit le français mot à mot. « retenir » devient « לעכב » (retarder, détenir) dans trois chaînes alors que le reste dit « לחסום » ; « le mode se tait » devient « המצב שותק » (deux chaînes) ; « journée validée » devient « היום אושר », le verbe des autorisations (approuvé). La même fonction s'appelle « המצב » dans l'écran d'état et « המחסום » dans les deux textes de divulgation. Six autres tournures sont des décalques : « לעבוד על » (préposition en suspens), « זמן שנעשה » (du temps « fait »), « אות קריאה צפוי: » (« Indicatif attendu : »), « מחשב… » seul (se lit « ordinateur… »), « צאת היום הקודם », « לעכב… בשעות ». vol_frise_retard a perdu sa virgule et son point final.

**Preuve.** android/app/src/main/res/values-iw/strings.xml:63 « אין מה לעכב. בחרו לפחות אפליקציה אחת. » ; :65 « היום כבר לא יעוכב דבר. המצב יחזור מחר. » ; :71 « …מחוץ לזה דבר לא מעוכב. » ; :67 « …המצב שותק והרצף נשמר. » ; :102 « בימים אלה: המצב שותק… » ; :64 « היום אושר » ; :147 « …והיום יאושר. » ; :1390 « מחסום הבוקר, מצב „אני עם השם” » ; :1145 « לעבוד על » ; :1099 « להוסיף זמן שנעשה בלי הטלפון » ; :1306 « אות קריאה צפוי: שלוש אותיות… » ; :1257 « מחשב… » ; :690 « לא לפני צאת היום הקודם (⁦8.5°⁩) » ; :115 « …לעכב את התזכורת בשעות… » ; :1231 « אם הטיסה תתעכב הזמנים ישתנו בהתאם ».

**Correction proposée.** :63 « אין מה לחסום. בחרו לפחות אפליקציה אחת. » ; :65 « היום כבר לא ייחסם דבר. המצב יחזור מחר. » ; :71 « המצב פועל בין %1$s ל־%2$s. מחוץ לשעות האלה דבר אינו נחסם. » ; :67 « שבת, יום טוב או הפסקה: המצב מושבת והרצף נשמר. » ; :102 « בימים אלה: המצב מושבת, אין תזכורת, והרצף נשמר. » ; :64 « היום הושלם » ; :147 « הזמן שכבר עבר יישמר והיום ייחשב. » ; :1145 « על מה לעבוד » ; :1099 « להוסיף התבודדות שנעשתה בלי הטלפון » ; :1306 « יש להזין שלוש אותיות ואחריהן המספר, לדוגמה ELY1. » ; :1257 « החישוב מתבצע… » ; :690 « לא לפני צאת הכוכבים של אמש (⁦8.5°⁩) » ; :115 « …לעכב את התזכורת בכמה שעות… » ; :1231 « אם הטיסה תתעכב, הזמנים ישתנו בהתאם. ». Choisir un seul nom pour la fonction (« המצב » ou « המחסום ») et l'employer dans les divulgations aussi.

### THE-15 — Registre : l'alerte de Chabbat en argot (« תתכוננו לכיף! », « נשמה כפולה ») dans une interface au registre soutenu

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** Le fichier tient un hébreu soigné (אינו, ותו לא, נא לכתוב, impératifs בחרו / הקישו). La notification « Chabbat dans 3 h » en sort : « תתכוננו » est un futur employé comme impératif (seule occurrence du fichier), « לכיף » est familier et sonne léger pour l'entrée de Chabbat, là où le français dit « préparez-vous à en profiter ». Le texte calque « double neshama » en « נשמה כפולה » ; la notion s'appelle en hébreu « נשמה יתרה », et « סעודה כפולה » n'évoque rien de connu (le terme reçu est « לחם משנה »). Même relâchement, plus léger, dans « קל לפספס ».

**Preuve.** android/app/src/main/res/values-iw/strings.xml:989 « שבת בעוד 3 שעות, תתכוננו לכיף! » ; :990 « נשמה כפולה, שמחה כפולה וסעודה כפולה! נסו התבודדות כפולה. » ; :373 « …תזכורת אחת קל לפספס. ». Affichage : android/app/src/main/java/com/myhitbodedut/ChabbatAlerte.kt:69-73.

**Correction proposée.** :989 « שבת בעוד 3 שעות: התכוננו ליהנות ממנה! » ; :990, si le propriétaire tient à la figure du « double » : « נשמה יתרה, שמחה כפולה ולחם משנה! נסו גם התבודדות כפולה. » ; :373 « …תזכורת אחת קל להחמיץ. ».

### THE-16 — Nikoud partiel : les 14 chaînes de l'écran Tefilot sont vocalisées, seules de toute l'interface

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Titre, sous-titre, compteur, avertissement et les dix sujets de l'écran Tefilot portent leurs voyelles ; aucune autre chaîne d'interface n'en a. Sur l'accueil et dans la liste « ספרייה », la ligne « תְּפִלּוֹת » vocalisée est entourée de « סידור », « תהילים », « התיקון הכללי », « ספרים » sans voyelles. Les mêmes mots existent ailleurs sans nikoud (« תפילות » dans la recherche et la présentation, « פרנסה », « זיווג », « הודיה » parmi les thèmes). Aucun choix documenté.

**Preuve.** android/app/src/main/res/values-iw/strings.xml:430-443, par exemple :430 « תְּפִלּוֹת », :431 « עֲשָׂרָה עִנְיָנִים, עֶשְׂרִים וְאַחַת תְּפִלּוֹת. רַבִּי נָתָן מִבְּרֶסְלֶב. », :439 « פַּרְנָסָה » contre :401 « פרנסה », :1056 « תפילות », :451 « …תפילות לפי נושא… ». android/app/src/main/res/layout/activity_main.xml:473-477. Visible sur play/visuels/he/09-textes-he.png.

**Correction proposée.** Retirer le nikoud des 14 chaînes : « תפילות », « עשרה עניינים, עשרים ואחת תפילות. רבי נתן מברסלב. », « %d תפילות », « התורה הנזכרת עוסקת בעניין אחר; הבקשה בתוך התפילה. », « התבודדות », « שמחה », « אומן, ראש השנה », « קדושה », « זרע של קיימא », « פרנסה », « שמירת הברית », « גאולה », « זיווג », « רפואה שלמה ».

### THE-17 — Terminologie flottante : un même mot français, deux ou trois mots hébreux

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Huit notions changent de nom d'une chaîne à l'autre. Morceau : « ניגון » (7 chaînes), « שיר » (3, mini-lecteur), « קובץ » (2). D'affilée : « ברצף » et « ברציפות » (9 lignes). Sans durée : « בלי זמן קצוב », « בלי הגבלת זמן », « התבודדות פתוחה ». Facultatif : « (לא חובה) » et « (רשות) ». Toucher : « הקישו » (5), « לחצו » (2), « נגיעה » (2). Android : en latin (2) et « אנדרואיד » (4). Kippour : « יום כיפור » (2) et « יום הכיפורים » (2). Note du journal : « הערה » partout, « רשומה » dans le trophée de la plume.

**Preuve.** android/app/src/main/res/values-iw/strings.xml : 251, 255, 275 (ניגון) contre 262, 263, 265 (« השיר הבא », « השיר הקודם », « מיקום בשיר ») et 256, 257 (קובץ) ; 218-220 (ברצף) contre 897, 934-936, 972-974 (ברציפות) ; 152-153, 447, 193 ; 43 contre 393 et 1222 ; 92, 195, 254 contre 854, 1041 contre 607, 1357 ; 1390, 1392 contre 115, 206, 1052, 1325 ; 770-771 contre 715, 1030 ; 76, 200 contre 958-961.

**Correction proposée.** Retenir : « ניגון » (:262 « הניגון הבא », :263 « הניגון הקודם », :265 « מיקום בניגון ») ; « ברצף » ; « בלי זמן קצוב » (:447 « …או התבודדות בלי זמן קצוב… », :193 « התבודדות בלי זמן קצוב, כבר %1$s. הטלפון יכול לחכות. ») ; « (לא חובה) » (:393 « נושא: ללא (לא חובה) », :1222 « מספר טיסה (לא חובה) ») ; « הקישו » (:854 « הקישו על שם כדי לקרוא את תולדותיו. », :1041 « הקישו לפתיחת הנוסח. ») ; « אנדרואיד » ; « יום הכיפורים » ; « הערה » (:958 « הערה אחת ביומן », :960-961 « %1$d הערות ביומן »).

### THE-18 — Restes typographiques : chiffres hébreux sans guershayim, tiret long isolé, troisième style de guillemets

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** La typographie est par ailleurs irréprochable, ce qui rend ces écarts visibles. Quatre nombres en lettres sont écrits sans guershayim (« צד » deux fois, « קנ », « יא ») alors que le fichier écrit « תכ״ו », « כ״ה », « ק״נ » et que Reference.lettres les met toujours. Les abréviations des points cardinaux « מז » et « מע » n'ont pas de signe. Un seul tiret cadratin face à cinq demi-cadratins. Une chaîne emploie les guershayim comme guillemets (״…״) au lieu de „…”.

**Preuve.** android/app/src/main/res/values-iw/strings.xml:1355 « …שולחן ערוך הרב (אורח חיים צד, ב), המור וקציעה לרבי יעקב עמדן (קנ)… הלבוש (אורח חיים צד)… » ; :1031 « משנה ברורה תכ״ו יא » ; :581 « כל ק״נ המזמורים » ; :1373 « מז », :1375 « מע » ; :170 « …במה להמשיך — על פי… » contre :47, 598, 807, 816, 996 (–) ; :461 « להסיר את ״%1$s״? ». android/app/src/main/java/com/myhitbodedut/Reference.kt:73-88.

**Correction proposée.** :1355 « (אורח חיים צ״ד, ב) », « (ק״נ) », « (אורח חיים צ״ד) » ; :1031 « תכ״ו, י״א » ; :1373 « מז׳ », :1375 « מע׳ » (et « צ׳ », « ד׳ » si la place le permet) ; :170 « חמישה שלבים, כדי לדעת במה להמשיך – על פי… » ; :461 « להסיר את „%1$s”? ».

### THE-19 — Android : dates civiles hébraïques construites sur le gabarit français (« יום חמישי 12 נובמבר 2026 »)

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Les dates longues sont produites par un motif fixe « EEEE d MMMM yyyy », pensé pour le français. En hébreu il donne « יום חמישי 12 נובמבר 2026 », sans la virgule ni le « ב » du mois. La même application écrit « 12 בנובמבר 2026 » là où elle passe par le format localisé (date d'un trophée), et le site écrit « יום שלישי, 29 בספטמבר 2026 ». Trois formes pour la même date selon l'écran et la plateforme.

**Preuve.** android/app/src/main/java/com/myhitbodedut/VueJour.kt:74, JournalActivity.kt:80, PartageJour.kt:43 (motif « EEEE d MMMM yyyy ») ; FicheTrophee.kt:77 et PaliersActivity.kt:192-193 (FormatStyle.LONG). Sortie d'une JVM en locale he : « EEEE d MMMM yyyy => יום חמישי 12 נובמבר 2026 », FormatStyle.LONG => « 14 בנובמבר 2026 ». Web : play/visuels/he/07-zmanim-he.png « יום שלישי, 29 בספטמבר 2026 ».

**Correction proposée.** Remplacer le motif fixe par le format de la langue : DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL).withLocale(locale), ou android.text.format.DateFormat.getBestDateTimePattern(locale, "EEEEdMMMMyyyy").

### THE-20 — FEUILLE_DE_ROUTE : la description du registre hébreu ne correspond plus au fichier

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : docs · **Type** : texte

**Constat.** Le journal des décisions affirme que le registre hébreu alterne le singulier pour l'interface et le pluriel pour l'enseignement, et en fait un système. Le fichier actuel ne contient aucun impératif singulier : l'interface parle au pluriel (בחרו, הקישו, הפעילו) ou à l'infinitif (להתחיל, לסיים), comme les conseils. Un relecteur qui suivrait la règle écrite introduirait des formes singulières genrées.

**Preuve.** FEUILLE_DE_ROUTE.md:460-462 « le registre hébreu alterne le singulier pour l'interface et le pluriel pour l'enseignement, ce qui est un système et non une négligence ». Recherche par script dans android/app/src/main/res/values-iw/strings.xml des formes בחר, הקש, לחץ, הזן, בדוק, נסה, שלך, אתה, תוכל, תרצה : zéro occurrence.

**Correction proposée.** Corriger la phrase : « l'hébreu s'adresse partout au pluriel (בחרו, הקישו) ou à l'infinitif pour les boutons ; les seules formes genrées sont צדיק/צדקת et חזק/חזקי ».
