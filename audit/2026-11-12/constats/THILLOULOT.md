# THILLOULOT — Contenus — hilloulot, biographies, halakha du jour

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

19 constats — confirmés : 3 · confirmés en partie : 6 · non contre-expertisés (mineurs et cosmétiques) : 9 · réfutés : 1.

## Ce qui a été examiné

Lu en entier : Hilloulot.kt, HilloulotActivity.kt, Halakha.kt, HalakhaActivity.kt, YalkutYosef.kt ; VueJour.kt:170-269 ; web/src/js/halakha.js et yalkut.js ; jour-affiche.js:143-260 ; app.js (écrans halakha et hilloulot, chargement des biographies, recherche globale) ; HilloulotTest.kt ; les en-têtes de HalakhaTest, YalkutYosefTest et LivresTest ; tools/yalkut_kitsour_livre.py ; les en-têtes de ben_ish_hai_construction.py et hilloulot_construction.py ; .github/workflows/source-yalkut.yml ; FEUILLE_DE_ROUTE.md de la ligne 755 à la fin ; PUBLICATION_PLAY_STORE.md §1, §3.3, §6.3-6.4, §7 et §11 ; les chaînes fr, en et he concernées.

Traité par script, sans échantillonnage : les 4 049 entrées de hilloulot.json (doublons du même jour, années, dates impossibles, champ « d », tri, traductions) ; les 2 346 biographies (résidus, coordonnées, mots collés, fins de texte) ; les 1 701 notices (date et année comparées à la clé) ; les 788 se'ifim de la sélection du Yalkut ; les 2 002 halakhot du Ben Ish 'Haï ; le livre complet du Yalkut (structure et décompte seulement). J'ai simulé sur 19 ans, en diaspora et en Israël, le choix quotidien du Yalkut et du Ben Ish 'Haï, avec le code web, identique à la source et équivalent au code Kotlin.

Échantillonné : 42 fiches de hilloulot (3 par groupe de mois, tirage au hasard), lues en entier ; 22 halakhot lues (12 du Yalkut, 10 du Ben Ish 'Haï), plus une vingtaine examinées aux dates de fête.

J'ai réutilisé, après vérification, les copies JS et les simulations du précédent auditeur (OUT/thilloulot/web, identiques aux sources) ; tous mes scripts et listes sont dans OUT/thilloulot2. La seule vérification extérieure est l'en-tête de licence de l'export Sefaria du Ben Ish 'Haï.

Non examiné : le rendu réel à l'écran (aucune capture prise), la vérification des dates contre les sites sources (hyomi, MyTzadik, pages de date de Wikipédia) au-delà de la notice embarquée, la qualité textuelle du Kitsour complet, la visibilité (publique ou non) de la branche claude/source-yalkut, et Nokia, qui n'a ni halakha ni hilloulot.

## Ce qui tient

- Le calendrier des clés est rigoureux et testé. Adar suit le Choul'han Aroukh pour les séfarades et le Rema pour les Ashkénazes, un 30 absent se dit le 29, les années embolismiques sont vérifiées contre KosherJava (HilloulotTest), et chaque jour d'une année a sa hilloula. Les données ne contiennent aucune clé impossible (pas de 30 Iyar, Tamouz, Eloul, Tevet ni Adar II).
- Android et web sont exactement à parité. Les données déployées (hilloulot.json, biographies par mois, yalkut_yosef.json, ben_ish_hai.json) sont identiques octet pour octet à celles de l'APK, et halakha.js, yalkut.js et jour-affiche.js déployés sont identiques aux sources. Une correction faite dans les données vaut donc partout.
- Le Ben Ish 'Haï est sans risque juridique : export Sefaria de Wikisource, licence « Public Domain » vérifiée dans l'en-tête de l'export, texte hébreu verbatim et complet (2 002 halakhot, test à l'appui). Sa source est précise (année, paracha, lettre), les parachiot jointes ou séparées sont traitées, et halachayomit.co.il n'est jamais copié, seulement lié.
- L'attribution est soignée : chaque biographie est suivie de sa source et d'un lien (testé), Wikipédia est crédité avec licence et lien vers l'article, Hidabroot n'apparaît que par un lien, et hyomi ne fournit que des faits.
- Les textes de base sont propres. Les 1 701 notices Wikipédia finissent toutes sur une phrase complète, sans HTML ni balise wiki. Les 788 se'ifim de la sélection du Yalkut (420 caractères au plus) gardent leurs renvois et ne montrent pas de bruit d'OCR (3 signes isolés). Aucune biographie HaMéir n'est tronquée.
- Côté performance, les biographies (6,9 Mo) sont lues hors du fil principal sur Android, et par mois sur le web : la carte du jour reste légère.

## Constats

### THILLOULOT-02 — Halakha du Yalkut hors saison : Soukkot ne montre jamais le loulav, Chavouot montre l'omer, la fin de Pessa'h montre la bedikat 'hamets

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** Dans une fenêtre de fête, le rang avance de deux se'ifim par jour à partir du premier jour, dans l'ordre du fichier. Dès qu'une fenêtre est plus courte que la moitié de sa liste, la fin de la liste n'est jamais atteinte ; dès qu'elle est plus longue, la liste reboucle sur son début. J'ai simulé 19 ans (le même résultat en Israël et en diaspora ; Android et web ont un code identique). À Soukkot, 46 se'ifim sur 72 ne sortent jamais : les 11 de la soukka (תרלט) et les 35 du loulav (תרנא). Du 15 au 23 Tichri, y compris Hochaana Rabba et Chemini Atseret, l'écran ne montre que « ממה צריך להיות הסכך ». À Chavouot (6 et 7 Sivan), il montre les lois de la Sefirat haOmer, alors que celles de Chavouot sortent le 18 Iyar. Le 21 et le 22 Nissan, il montre « דיני בדיקת חמץ ». Le 9 Av, il montre les coutumes générales de Bein haMetsarim. Ne sortent jamais non plus : 4 se'ifim de Kippour, 2 de Ta'anit Esther, 5 de la Se'oudat Pourim, 4 de Birkat haLevana. La promesse « avant et pendant chaque fête les siennes » (FEUILLE_DE_ROUTE.md:877-879) n'est pas tenue ; les tests ne vérifient que le nom des fenêtres.

**Preuve.** YalkutYosef.kt:71-74 (« while (n < 60 && fenetreDu(date.minusDays(n + 1L), israel) == f) n++ ») et :81-85 (« val debut = Math.floorMod(rang.toLong() * PAR_JOUR, …) ») ; web/src/js/yalkut.js:41-54, identique. yalkut_yosef.json periodes.soukkot : indices 0-25 « סימן תרכט - ממה צריך להיות הסכך », 26-36 « סימן תרלט », 37-71 « סימן תרנא - נטילת הלולב וברכתו ». Simulation OUT/thilloulot2/web/sim2.mjs : « soukkot seifim 72 jamais affiches 46 ». 2026-10-02 (21 Tichri) : « תרכט … כח ; … ל ». 2027-06-11 (6 Sivan) : « סימן תפט - הלכות ספירת העומר לז ; לח ». 22 Nissan : « סימן תלג - דיני בדיקת חמץ » (19 années sur 19). 18 Iyar : « סימן תצד - הלכות חג השבועות » (19 sur 19).

**Correction proposée.** Répartir chaque fenêtre en proportion de sa durée au lieu d'avancer de 2 par jour depuis le début. periode() renvoie aussi la longueur L de la fenêtre, et du() prend « debut = n * seifs.size / L » (Kotlin et yalkut.js). Les lois de la veille tombent alors au début et celles de la fête à la fin : le loulav arrive à partir du 18 Tichri et Chavouot dans les derniers jours de la fenêtre. En complément, ajouter une fenêtre « chavouot » (1–7 Sivan, siman תצד) distincte de « omer », et un test qui vérifie le 15 Tichri, le 6 Sivan et le 22 Nissan.

**Note du contre-expert.** J'ai relu YalkutYosef.kt:66-85 et yalkut.js (même logique) et l'ordre de yalkut_yosef.json, puis relancé la simulation sur 19 ans avec ma propre copie de web/src/js. Résultats : 46 se'ifim de Soukkot sur 72 ne sortent jamais, תרכט seul du 15 au 21 Tichri, l'omer le 6 Sivan, la bedikat 'hamets le 22 Nissan, les minhaguim généraux le 9 Av, Chavouot le 18 Iyar. YalkutYosefTest ne vérifie que le nom des fenêtres. Nuance : le 21 Nissan montre un se'if des quatre coupes et un de la bedikat 'hamets ; Pessa'h et Bein haMetsarim perdent aussi chacun 2 se'ifim.

### THILLOULOT-03 — Tri « les mieux connus d'abord » inversé : Rachbi, le Rambam, Ra'hel, Aharon et Rabbi Akiva disparaissent de la carte du jour

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : fonction

**Constat.** Le premier critère du tri relègue en fin de liste toute entrée qui porte un champ « d ». Le commentaire et le test parlent de « dates douteuses ». Mais « d » contient aussi des notes qui ne portent pas sur la date : statut (« figure biblique (pas un sage post-biblique) », « vénérée mais pas rabbin », « femme tsadéket — à valider selon les critères »), simple formule de tradition (« « על פי המסורת » », « date « selon la tradition » »), voire un résidu de modèle wiki. Les figures les plus célèbres se retrouvent donc en bas, derrière des noms obscurs. Or la carte du jour n'en montre que cinq. Le jour de Lag baOmer, Rabbi Chimon bar Yo'haï est 15e sur 16. Le 20 Tevet, le Rambam est 7e sur 8, alors que le même Rabbi Yaakov Abou'hatséra figure deux fois parmi les cinq premiers. Ra'hel Iménou est 16e sur 17, Aharon haKohen 8e sur 11 le 1er Av, Rabbi Akiva 15e sur 15, Yaakov Avinou 18e sur 20. Sur les 179 noms jugés assez connus pour recevoir une traduction française, 34 sont hors des cinq premiers, dont 28 à cause de « d ». Les douze femmes annotées sont toutes reléguées.

**Preuve.** Hilloulot.kt:74-80 « d'abord les mieux connus… ceux dont la date est mise en doute en dernier » et « sortedWith(compareBy&lt;Hilloula>({ it.doute != null }, { -it.sources.length }, …)) » ; web/src/js/jour-affiche.js:177-182 identique ; HilloulotTest.kt:87 « les dates douteuses en dernier ». hilloulot.json : 10-20 « רבי משה בן מימון (הרמב"ם) », d = « année donnée par le modèle {{קישור לשנה עברית|4965}} » ; 2-18 « רבי שמעון בר יוחאי », d = « « על פי המסורת », sans année » ; 8-11 « רחל אמנו », d = « matriarche, date « selon une des traditions » » ; 6-8 « מלכה רוקח », d = « Épouse du fondateur de Belz ; vénérée mais pas rabbin ». Cinq premiers du 10-20 : ['רבי יעקב אבוחצירא', 'הרב אליהו אליעזר מישקובסקי', 'חכם אליהו כהן', 'רבי יעקב אביחצירא', 'רבי שלום טויבש'].

**Correction proposée (revue par le contre-expert).** Plus simple, sans refondre les données : faire passer le nombre de sources avant le doute. Kotlin : sortedWith(compareBy&lt;Hilloula>({ -it.sources.length }, { it.doute != null }, { it.description == null })) ; même clé dans hilloulotDuJour (jour-affiche.js). Essai sur les données : Rachbi 2e (2-18), Rambam 2e (10-20), Ra'hel 1re, Aharon 1er, Rabbi Akiva 5e, Yaakov Avinou 5e ; les noms traduits hors des cinq premiers passent de 34 à 10. Retirer en plus le résidu de modèle du « d » du Rambam, mettre à jour le vecteur de HilloulotTest et y ajouter le 18 Iyar (Rachbi parmi les cinq premiers).

**Note du contre-expert.** Chiffres vérifiés : Rachbi 15e sur 16 au 2-18, le Rambam 7e sur 8 au 10-20 à cause d'un résidu de modèle wiki (« {{קישור לשנה עברית|4965}} »), 34 noms traduits hors des cinq premiers, dont 28 à cause de « d ». Mais l'ordre « sûrs d'abord » est un choix du propriétaire (FEUILLE_DE_ROUTE.md:1108), et _meta définit « d » comme un doute sur la « personne, date ou année » : des notes de statut dans « d » sont donc voulues. Ce qui est faux, c'est le commentaire et le test qui ne parlent que de « dates », et un effet contraire au but « les mieux connus d'abord ». Il n'y a pas d'« inversion ».

### THILLOULOT-04 — Au moins 84 tsadikim affichés deux fois le même jour (dont Rabbi Natan de Breslev et Baba Elazar trois fois)

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** L'ajout des listes MyTzadik et HaMéir LaArets n'a pas reconnu les variantes d'orthographe. Ces fiches entrent donc comme des tsadikim distincts, sur le même jour que l'entrée existante. Un script de rapprochement (squelette consonantique, titres retirés, puis validation manuelle) donne 87 paires réelles, dont 79 impliquent une entrée « m » seule. Exemples : le 10 Tevet, « רבי נתן מברסלב » et « רבי נתן שטרנהרץ - מוהרנ"ת », dans une application breslev ; le 27 Tamouz, trois lignes pour Baba Elazar ; le 15 Tichri, « יעקב אבינו » deux fois ; le 20 Tevet, אבוחצירא et אביחצירא tous deux parmi les cinq de la carte du jour. La biographie se trouve souvent sur le doublon, pas sur l'entrée principale : celle de MyTzadik pour Rabbi Natan (3 626 caractères) est sur la 11e ligne. Quand le nom est identique, l'identifiant de dépliage est le même (« $jour|${h.he} »), donc toucher l'une ouvre les deux. Le décompte de « 4 049 hilloulot » est gonflé d'autant. D'autres doublons échappent au script, par exemple עהרנפעלד et ארנפלד le 1er Av, ou לייפער et לייפר le 15 Tichri.

**Preuve.** hilloulot.json 10-10 : [1] « רבי נתן מברסלב » s=wil, [10] « רבי נתן שטרנהרץ - מוהרנ"ת » s=m. 4-27 : [2] « הרב אלעזר אבוחצירה » hwi, [8] « הבבא אלעזר – רבי אלעזר אבוחצירא » l, [9] « בבא אלעזר - רבי אלעזר אביחצירא » m. 7-15 : [9] « יעקב אבינו » wi, [13] « יעקב אבינו » m. HilloulotActivity.kt:197 « ligne(h, "$jour|${h.he}", …) ». Liste complète : OUT/thilloulot2/doublons_vrais.json (87 paires) ; script OUT/thilloulot2/doublons.py.

**Correction proposée (revue par le contre-expert).** Comme proposé, mais n'appliquer les paires de doublons_vrais.json qu'après relecture une à une. Exclure au moins la paire 2-9 « הרב משה הגר » (rosh yeshiva mort en 5759, distinct du premier rabbi de Chats-Vizhnitz) et ne pas fusionner la paire 3-25 sans source. Ne retirer י, ו, א que pour proposer des candidats, jamais pour fusionner automatiquement.

**Note du contre-expert.** Vérifié dans hilloulot.json : au 10-10, Rabbi Natan en [1] (wil) et en [10] (m, qui porte la biographie MyTzadik) ; au 4-27, trois lignes pour Baba Elazar ; au 7-15, יעקב אבינו deux fois et Leifer deux fois. L'identifiant « $jour|${h.he} » (HilloulotActivity.kt:197) sert à deplies/replies. Le rapprochement voulu (apparier() dans hilloulot_construction.py) a échoué : ce n'est pas un choix. La liste doublons_vrais.json n'est pas sûre à 100 % : au 2-9, « הרב משה הגר » (1926-1999, rosh yeshiva) n'est pas « רבי משה הגר » (1863-1926), et la paire du 3-25 (חכם חיים הכהן / רבי חיים כהן) n'est pas vérifiée.

### THILLOULOT-05 — Dates et années de décès démenties par la notice Wikipédia affichée juste en dessous

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : texte

**Constat.** J'ai comparé par script la clé (jour hébreu) et l'année « a » de chaque entrée avec la date de décès que donne sa propre notice, celle qui s'affiche quand on la déplie. Les jours concordent dans 696 cas et divergent dans 16 cas. Onze divergences ne sont signalées nulle part. La plus grave : Rav Baroukh Mandelbaum est commémoré le jour et l'année de sa naissance (22 Tevet 5594) alors qu'il est mort le 17 Iyar 5665. Sept années affichées sous « Décès : » contredisent la notice, d'un an à trois siècles d'écart.

**Preuve.** Sont listés : clé ou « a », puis la notice (t). Dates : 10-22 « הרב ברוך מנדלבאום », a=ה'תקצ"ד ; t « כ"ב בטבת תקצ"ד … – י"ז באייר תרס"ה ». 1-27 « הרב משה דב וולנר » ; t « – כ"א באב ה'תשס"ז ». 10-9 « הרב אברהם חיים שור » ; t « נפטר בי"ט בטבת ». 11-1 « הרב שלום עמנואל מויאל » ; t « נפטר בא' באדר ב' ה'תר"ע ». 4-10 « הרב יהושע קניאל » ; t « י"א בתמוז ». 5-7 « רבי אלעזר רוזנפלד » ; t « כ"ז בתמוז תש"ג ». 4-29 « רבי אליהו בעל שם מוורמייזא » ; t « כ"א בתמוז ». 3-21 « הרב נחום אש » ; t « י"ט בסיוון ». 5-11 « רבי חיים מקרסנה » ; t « נפטר י"ד באב ». 2-25 « שבע ברכה ארנסטר » ; t « כ"ו באייר ». 3-20 « רבי יחיאל מיכל מנמירוב » ; t « כ"ב בסיוון ». Années : 1-15 « הרב שלמה מיידנצ'יק », a=ה'תס"ד ; t ה'תשס"ד. adar1-7 « הרב צבי הירש למפרט », a=ה'תרפ"ה ; t « ז' באדר א' תרס"ה ». adar1-2 « רבי יוסף דוב הלוי סולובייצ'יק », a=ה'תש"ם ; t « ב' באדר א' ה'תשמ"א ». 9-21 « הרב צבי פסח פרנק », a=ה'תש"ך ; t « כ"א בכסלו ה'תשכ"א ». 4-20 « חכם אברהם חיים נאה », a=תרי"ד ; t ה'תשי"ד. adar-25 « רבי בצלאל יאיר דנציגר », a=ה'תרצ"ה ; t תרצ"ד. 3-30 « רבי יחיאל יעקב הופשטיין », a=ה'תרכ"ז ; t ה'תרכ"ו. Scripts : OUT/thilloulot2/dates_wiki.py et annee_vs_notice.py.

**Correction proposée.** Corriger dans hilloulot_construction.py (tables RETIRES et ANNEES). Mandelbaum passe en 2-17 avec a=ה'תרס"ה ; Wollner en 5-21 ; Shor en 10-19 ; Moyal en adar2-1 ; Kaniel en 4-11 ; Rosenfeld en 4-27 ; Eliyahou Baal Chem en 4-21 ; Ash en 3-19 ; Krasna en 5-14 ; Ernster en 2-26. Années : ה'תשס"ד, ה'תרס"ה, ה'תשמ"א, ה'תשכ"א, ה'תשי"ד, ה'תרצ"ד, ה'תרכ"ו. Si une page de date est jugée plus sûre que la notice, garder la date mais le dire à l'écran. Ajouter à la construction une vérification qui échoue quand la clé ou l'année diffère de la dernière date de la notice et qu'aucun doute n'est consigné.

**Note du contre-expert.** J'ai rouvert les 18 cas dans hilloulot.json : la clé ou « a » contredit bien la notice « t » affichée. Mandelbaum est commémoré à sa date de naissance (22 Tevet 5594) alors qu'il est mort le 17 Iyar 5665. Le champ « d » n'est jamais affiché (aucun usage dans Kotlin ni dans le web) : même Meidanchik et Naeh, dont « d » relève l'anomalie, montrent l'année fausse sous « Décès : ». Seul Nemirov (20 Sivan, date traditionnellement liée au massacre) est défendable, et l'auditeur ne propose pas de le changer.

### THILLOULOT-07 — Le cahier Play (§3.3) ignore toutes les sources des hilloulot, dont 2 346 biographies reprises mot pour mot sur un accord oral

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : play · **Type** : texte

**Constat.** Le tableau des droits sur les textes de PUBLICATION_PLAY_STORE.md ne mentionne ni MyTzadik (2 213 biographies), ni HaMéir LaArets (133 biographies, jusqu'à 24 640 caractères chacune), ni Wikipédia (1 701 extraits CC BY-SA 4.0), ni le Ben Ish 'Haï, ni החכם היומי, ni Hidabroot, ni le Seder haDorot de Torat Emet. L'accord MyTzadik et HaMéir du 12/10 n'existe que dans _meta et la feuille de route, sans aucun écrit. Il ne figure pas non plus dans « Droits et sources en attente », qui ne cite que l'accord du 13/10. Surtout, trois biographies contiennent la réserve d'un tiers qui interdit la copie, ce que l'accord d'un site ne peut pas couvrir.

**Preuve.** PUBLICATION_PLAY_STORE.md:245-257 : les lignes du tableau citent Tanakh, Yalkout, Yanuka, or-breslev, GeoNames, polices et rabenubook ; aucune occurrence de « MyTzadik », « Wikip », « Ben Ish », « hyomi », « Hidabroot » dans le fichier (grep vide). hilloulot.json _meta.sources : « MyTzadik, mytzadik.com (YETEV 4 LTD) : reprise autorisée avec mention, accord reçu par le propriétaire de l'app le 12/10/2026 ». Biographies 11-8 « חכם יצחק טייב » et 2-16 « חכם יצחק חי טייב » : « כל הזכויות שמורות לדניאל טייבואין להעתיק כמו כל התמונות שבאתר! » ; adar-9 : « כל הזכויות שמורות לפי כל דין. ».

**Correction proposée (revue par le contre-expert).** Ajouter au §3.3 les lignes proposées. Biographies : « accord déclaré le 12/10, aucun écrit au dépôt » au lieu d'« oral ». Retirer la biographie d'adar-9 (ou obtenir l'accord écrit de l'institut de Stefanesti). Aux 11-8 et 2-16, retirer seulement la ligne de crédit des photos. Reporter l'accord du 12/10 dans « Droits et sources en attente ».

**Note du contre-expert.** Le §3.3 (PUBLICATION_PLAY_STORE.md:245-257) omet bien MyTzadik, HaMéir et Wikipédia. Comptes vérifiés : 2 213 biographies m, 133 l, 1 701 notices. En revanche, rien ne dit que l'accord du 12/10 soit « oral » : les documents disent « accord reçu », sans préciser sa forme. La plus longue biographie de HaMéir fait 34 846 caractères. Des trois réserves, seule celle d'adar-9 interdit de reprendre l'information (« אין להשתמש בחומר זה … ללא אישור בכתב ממכון תורת אמת שטפנשט ») ; aux 11-8 et 2-16, « ואין להעתיק כמו כל התמונות שבאתר » vise les photos de D. Taïeb, que l'application ne reprend pas.

### THILLOULOT-06 — Coordonnées personnelles de tiers (courriels, téléphones, adresses) recopiées dans 159 biographies

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** Les biographies MyTzadik reprises « mot pour mot » contiennent les bas de page du site : adresses gmail de particuliers (descendants, musée, généalogistes), numéros de téléphone de guides et d'artistes, adresses postales. Elles sont livrées dans l'APK et servies publiquement par le site. C'est de la donnée personnelle de tiers republiée hors de son contexte, sans rapport avec la hilloula, et parfois publicitaire (« מדריך במסעות לקברי צדיקים … טלפון »). Une même adresse revient 17 fois.

**Preuve.** Script OUT/thilloulot2/bios_credits.py : « courriel: 72 bios » (71 gmail.com), téléphone dans 87 biographies, adresse postale dans 15, au total 159 biographies distinctes. Exemples (adresses masquées ici) : 1-18 « רבי יהודה מונסונייגו » « מוזיאון "קהילות ישראל"⏎דוא"ל: hilel26@… » ; 10-17 « רבי יעקב קרנץ » « מדריך במסעות לקברי צדיקים באירופה טלפון 052-76… » ; 3-23 « המקובל רבי שלום אהרון שמואלי » « … WhatsAppרחוב שילה 6 ת. ד. 1884 ירושליםדוא"ל: m6222… » ; 6-23 « התמונה באדיבות מדריך הטיולים למרוקו מר משה צרפתי 3700173 – 972-52 ».

**Correction proposée (revue par le contre-expert).** À la construction, couper du marqueur de crédit ou de contact (« התמונה/התמונות/תמונת/תמונות … באדיבות », « המידע באדיבות », « דוא"ל », « טלפון », « WhatsApp ») jusqu'à la fin de la ligne, au lieu de supprimer toute la ligne. Retirer ensuite les adresses électroniques et les numéros restants par motif. Ajouter un test qui interdit « @ » et les motifs de téléphone dans hilloulot_bios.json.

**Note du contre-expert.** Les coordonnées existent, toutes dans des biographies MyTzadik, et une même adresse revient 50 fois, pas 17. Ce sont surtout les crédits de photos que l'application ne montre pas : contacts professionnels (musée, guides, artiste) que ces personnes ont publiés elles-mêmes sur le site source. Le risque est faible ; c'est surtout un résidu éditorial, qui recoupe THILLOULOT-08. La recommandation est dangereuse : 189 crédits sur 577 sont collés au milieu d'une ligne (sauts de ligne perdus à l'extraction). Supprimer la ligne entière effacerait du contenu, par exemple la liste des livres au 1-18 « מספריו:• … (ק1/ק2)תמונת הציון באדיבות … דוא"ל: … ».

### THILLOULOT-08 — Biographies MyTzadik : marqueurs de liens « (ק) », crédits de photos absentes, « [להאזנה] » et dédicaces recopiés tels quels

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** La copie mot pour mot a gardé l'appareil du site d'origine, qui n'a aucun sens dans l'application. On trouve les renvois vers des liens de téléchargement « (ק) » et « (ק1/ק2/…) » derrière les titres de livres, des « [להאזנה] » (« à écouter ») sans lecteur, et une ligne de crédit pour des photos que l'application ne montre pas. On trouve aussi des dédicaces pour des particuliers : la même, « לעילוי נשמת איתן בן יצחק רפאל ז"לשנפטר … באדיבות משפחתו », est collée dans 25 biographies. Ce défaut est distinct des mots collés et n'est consigné nulle part.

**Preuve.** Script OUT/thilloulot2/bios_residus.py : « marqueur (ק)/(ק1/ק2) : 930 bios, 2453 occurrences » ; « [להאזנה] : 26 bios, 44 occurrences ». Classement des fins de texte : 586 biographies MyTzadik se terminent par une ligne « … באדיבות … », par exemple 1-1 « התמונות באדיבות K. Bielawski », 1-11 « תמונת הציון באדיבות קברים.קום ». 1-13 « רבי מנחם מנדל שניאורסון » : « ימין ה' [להאזנה] כאייל תערוג [להאזנה] ואשרי איש [להאזנה] ». 1-1 « רבי שמואל הלוי קעלין » : « מחצית השקל (ק1/ק2/ק3/ק4/ק5/ק6/ק7) ».

**Correction proposée (revue par le contre-expert).** Retirer « \s*\(ק\d*(?:/ק\d*)*\) » et « \s*\[ל(?:האזנה|צפייה|קריאה)\] » comme proposé. Pour les crédits et les dédicaces, couper du marqueur (« התמונה|התמונות|תמונת|תמונות … באדיבות », « המידע באדיבות », « לעילוי נשמת », « לזכות ») jusqu'à la fin de la ligne, où qu'il se trouve, et pas seulement en début de ligne. Ajouter le test d'interdiction de ces motifs.

**Note du contre-expert.** Résidus vérifiés : marqueurs (ק) dans 933 biographies (2 463 occurrences), [להאזנה] dans 22, 586 biographies MyTzadik qui finissent par un crédit « באדיבות », la dédicace « איתן בן יצחק רפאל » plus de 25 fois. Ils sont réels mais n'altèrent ni l'exactitude ni la lisibilité du texte : mineur plutôt que majeur. La règle « lignes qui commencent par » laisse passer les 189 crédits collés au milieu d'une ligne (par exemple « …אנשי חילהתמונה באדיבות תיירות חברון »).

### THILLOULOT-09 — Ben Ish 'Haï : une semaine sur deux ans, la « halakha du jour » est la note de l'auteur disant qu'il n'a pas écrit de halakhot

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : fonction

**Constat.** Pour Vayéchev, la deuxième année du Ben Ish 'Haï ne contient qu'une phrase. L'auteur y explique qu'il n'a pas écrit de halakhot dans cette paracha, parce qu'il y enseigne chaque année les lois de 'Hanouka. Halakha.choix trouve cette section « non vide », ne passe pas à l'autre année et, comme elle compte moins de 7 éléments, la sert telle quelle chaque jour de la semaine. Les années paires du calendrier (année 2 du livre), l'écran de la halakha et la carte du jour, si le Ben Ish 'Haï est choisi, montrent donc cette phrase comme « halakha » pendant 6 à 7 jours : 9 années sur 19.

**Preuve.** ben_ish_hai.json annees["2"]["VAYESHEV"].h = [« בפרשה זו לא כתבתי הלכות בשנה שניה יען כי לדרוש בפרשה זו בהלכות חנוכה בכל שנה ושנה: »]. Halakha.kt:77 « if (items.size < parts) return listOf(items[jour % items.size]) » et :93-96 (on ne passe à l'autre année que si la section est absente ou vide). Simulation OUT/thilloulot2/web/vayeshev.mjs : « 2027: 6 j (2027-12-19 → 2027-12-24) ; 2029: 7 j (2029-11-25 → 2029-12-01) ; 2031: 7 j … » (9 années sur 19).

**Correction proposée.** Dans tools/ben_ish_hai_construction.py, ne pas garder une section dont l'unique texte commence par « בפרשה זו לא כתבתי ». Halakha.choix (et halakha.js) prend alors Vayéchev de la première année. Ou bien, comme l'auteur l'indique, envoyer Vayéchev de la deuxième année vers la section « הלכות חנוכה ». Ajouter au test HalakhaTest que chaque jour de 2027-12-19 à 2027-12-24 ne renvoie pas ce texte.

**Note du contre-expert.** Données (annees["2"]["VAYESHEV"].h, un seul élément) et logique (Halakha.kt:77 et :93-96) vérifiées. Simulation relancée : 9 années sur 19, 6 à 7 jours chacune. Mais seule l'option non par défaut est touchée (Store.sourceHalakha vaut YALKUT par défaut), et le texte est une note authentique de l'auteur, pas une halakha fausse : mineur.

### THILLOULOT-10 — Hilloulot presque entièrement en hébreu pour un utilisateur français ou anglais, et la carte du jour ignore même les traductions qui existent

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : fonction

**Constat.** Seuls 179 noms sur 4 049 (4,4 %) ont une forme française et 229 une forme anglaise. Les 1 701 notices et les 2 346 biographies sont toutes en hébreu. La carte du jour, à l'accueil et sous les zmanim, affiche uniquement « it.he » / « x.he », même pour les 179 noms traduits : un francophone voit « רבי נחמן מברסלב » et non « Rabbi Na'hman de Breslev ». L'invite « Touchez un nom pour lire sa biographie » promet un texte qu'un utilisateur francophone ne pourra pas lire. La recherche en français ne trouve pas Moché Rabbénou (« Moïse » : 0 résultat, l'entrée adar-7 n'a pas de nom français), ni David haMelekh. Pour la halakha, l'hébreu seul est un choix assumé et affiché (halakha_note) ; pour les hilloulot, rien ne l'annonce.

**Preuve.** Script : « total 4049 fr 179 en 229 ». VueJour.kt:200 « hilloulot.take(5).joinToString("\n") { it.he } » ; web/src/js/app.js:2921 « liste.slice(0, 5).map((x) => h('div', {}, x.he)) ». strings.xml:901 « Touchez un nom pour lire sa biographie. » ; values-en:837 « Tap a name to read the biography. ». OUT/thilloulot2/web/rech.mjs : « Moïse 0 », « Moshe Rabbenou 0 ». strings.xml:910 « Texte original en hébreu, verbatim. » (halakha, choix documenté).

**Correction proposée (revue par le contre-expert).** Dans VueJour.blocHilloula, reprendre la règle de HilloulotActivity : val t = if (langue.startsWith("en")) it.en else if (langue.startsWith("fr")) it.fr ?: it.en else null. Afficher le nom hébreu, suivi de t quand il existe (la vue est en RTL avec la police hébraïque : mettre la traduction dans un isolat ou sur sa propre ligne). Web : nomTraduitHilloula(x). Ajouter « Moïse » comme forme de recherche de משה רבנו. Chaînes : fr « Touchez un nom pour lire sa biographie (en hébreu). » ; en « Tap a name to read the biography (in Hebrew). » ; he inchangé.

**Note du contre-expert.** Vérifié : 179 noms en français et 229 en anglais. La carte du jour n'affiche que .he (VueJour.kt:200, app.js:2921), alors que l'écran des hilloulot (HilloulotActivity, nomTraduitHilloula) montre la traduction. Mais l'entrée wie d'adar-7 a bien « Moché Rabbénou » / « Moses (Moshe Rabbeinu) » : seul le doublon m n'en a pas. « Moïse » échoue parce que la forme retenue est « Moché », et « David » trouve « le roi David ». L'expression Kotlin proposée afficherait le nom français à un utilisateur en hébreu (branche else), et « notice » est faux en anglais.

### THILLOULOT-11 — Mots collés dans les biographies : au moins 295 jonctions dans 174 biographies, mesurées

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte · déjà connu ou choix assumé

**Constat.** J'ai mesuré le défaut signalé le 28/10. La source est le moissonnage de MyTzadik : les sauts de ligne y ont été retirés sans espace avant d'être copiés mot pour mot (le fichier brut tools/hilloulot/mytzadik.json est déjà collé). Règles sûres (titre de livre suivi d'une ligne de crédit ou de généalogie, parenthèse suivie d'une lettre, année suivie d'un mot, « ז"ל » suivi d'un mot, hébreu collé à du latin, chiffre suivi d'une lettre) et 64 candidats lexicaux validés à la main : au moins 295 jonctions dans 174 biographies. 167 des 2 213 biographies MyTzadik sont touchées (281 jonctions) et 7 des 133 de HaMéir (14). Aucune des 1 701 notices Wikipédia ne l'est. C'est une borne basse : les collages sans marqueur échappent aux règles.

**Preuve.** Script OUT/thilloulot2/colles_mesure.py : « jonctions … {'m': 281, 'l': 14} ; fiches touchees {'m': 167, 'l': 7} ». Exemples : adar2-13 « ופרשת השבועתמונת הציון » ; 1-1 « תפלות לכל ימי השבועלזכותישראל ינון בן דודובני ביתו » ; 25 biographies « ז"לשנפטר בט"ז אייר ה'תשע"בבאדיבות משפחתו » ; 10-14 « Cimetiere juif Marrakechתמונת הצדיק » ; HaMéir 8-18 « היה רבנומקבל את משכורתו », « לאחר פטירתויצאו » ; 9-19 « היהתלמיד חכם ». FEUILLE_DE_ROUTE.md:1161 « mots collés dans les biographies ».

**Correction proposée.** Moissonner MyTzadik de nouveau en remplaçant &lt;br> et &lt;/p> par « \n ». À défaut, à la construction : insérer « \n » devant « התמונה|התמונות|תמונת|לעילוי נשמת|לזכות|מספריו:|אשתו:|בנו:|בתו: » quand ils suivent une lettre, insérer une espace après « ) » suivi d'une lettre et après « ז"ל » suivi d'un mot. Corriger à la main les 13 cas HaMéir de la liste. Garder colles_mesure.py comme test (zéro jonction attendue).

### THILLOULOT-12 — Dates hébraïques impossibles : Adar I ou II une année non embolismique, 30 'Hechvan d'une année à 29 jours, « 30 Adar »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les clés ne contiennent aucun 30 Iyar, Tamouz, Eloul, Tevet ou Adar II. En revanche, croisées avec leur année, huit entrées décrivent un jour qui n'a pas existé. Six portent une clé adar1 ou adar2 pour une année qui n'avait qu'un Adar. Une porte le 30 'Hechvan 5472, année où 'Hechvan comptait 29 jours. Une porte « adar-30 » pour 5547, année non embolismique. Autre problème : « חכם ד"ר דוד פראטו » (30 Adar I 5711) est rangé sous « adar-30 » au lieu de « adar1-30 ». Les années embolismiques, l'application le montre donc le 29 Adar II aux séfarades, au lieu du 30 Adar I qui existe ces années-là. Enfin, 58 entrées « adar » sans précision ont une année de décès embolismique : on ignore si c'était Adar I ou II, et la règle du Choul'han Aroukh 568:7 ne s'applique pas à leur cas.

**Preuve.** Script OUT/thilloulot2/annees.py. adar1-2 « רבי יוסף דוב הלוי סולובייצ'יק » 5740 ; adar1-13 « הרב חיים יעקב נפתלי זילברברג » 5690 (notice « י״ג באדר תר"ץ », d « mois précisé (אדר א') ») ; adar1-7 « הרב צבי הירש למפרט » 5685 ; adar1-11 « חכם דוד כהן » 5751 ; adar2-20 « חכם יהושע יהודה אמאדו » 5545 ; adar2-25 « חכם יוסף בן אדהאן » 5606 ; 8-30 « חכם משה חפץ » תע"ב ; adar-30 « חכם עובדיה מזרחי הלוי » תקמ"ז, d « hyomi indique « ל אדר » : ce jour n'existe qu'en Adar I (année embolismique) ». Hilloulot.kt:62-70 (adar-30 n'est montré que via le 29).

**Correction proposée.** Silberberg passe en adar-13 ; Pratto en adar1-30 ; les années de Lampert et de Soloveitchik sont corrigées (constat sur les dates contredites). Les cinq faits de hyomi seulement reçoivent un « dd » qui l'explique. Ajouter à HilloulotTest : pour toute année hébraïque connue, une clé adar1 ou adar2 exige embolismique(y), et un jour 30 exige que le mois ait 30 jours cette année-là (JewishCalendar(y, m, 1).daysInJewishMonth == 30).

### THILLOULOT-13 — Ben Ish 'Haï à Soukkot : la section de Hochaana Rabba et Sim'hat Torah n'est jamais montrée, Berechit l'est à sa place

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** La section de la première année « וזאת הברכה » (18 halakhot sur Hochaana Rabba et la joie de la Torah) ne sort jamais, puisque KosherJava ne donne jamais VZOS_HABERACHA comme paracha d'un Chabbat. Du 15 au 22 Tichri, la paracha « qui vient » est Berechit : on lit le tsitsit (année 1) ou le Kiddouch (année 2) le jour même de Hochaana Rabba, où l'auteur avait placé ses lois. Les sections de Mikets, toujours couvertes par 'Hanouka, perdent aussi 11 halakhot (4 et 7).

**Preuve.** Simulation sur 19 ans, OUT/thilloulot2/web/sim3.mjs : « jamais 29 {"1|מקץ":4,"1|וזאת הברכה":18,"2|מקץ":7} ». Le 2026-10-02 (21 Tichri) : « BIH: 1 בראשית … אין להקפיד להניח סימן בטלית ». ben_ish_hai.json annees["1"]["VZOS_HABERACHA"].h[0] : « מרבים בתפילות ותחנונים בהושענא רבה… ». Halakha.kt:104 « cal.parshah.takeIf { it != NONE } ?: cal.upcomingParshah ».

**Correction proposée.** Dans Halakha.pour et dans halakha.js, du 15 au 23 Tichri, prendre la section VZOS_HABERACHA (année 1, partagée sur 9 jours) au lieu de la paracha qui vient. Ajouter le test : le 21 Tichri 5787 renvoie « וזאת הברכה ».

### THILLOULOT-14 — Les doutes consignés ne sont jamais montrés : 73 « hilloulot » du 7 Adar à date conventionnelle, et Yehochoua aux trois dates possibles

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** Le champ « d » (526 entrées) sert seulement au tri. L'utilisateur ne voit jamais qu'une date est traditionnelle, contestée ou conventionnelle. Le 7 Adar présente 80 noms, dont 73 que les données elles-mêmes décrivent comme rangés à la date de la mort de Moïse faute de date connue. Ils s'affichent comme de vraies hilloulot, avec « Décès : année ». Yehochoua bin Noun apparaît le 26 Nissan, le 28 Nissan et le 18 Iyar sans que rien ne dise que ce sont trois traditions.

**Preuve.** Hilloulot.kt:22 « val doute: String? », utilisé seulement à la ligne 80 (tri) ; rien dans HilloulotActivity.kt ni dans app.js:2938-2980. hilloulot.json adar-7 : 80 entrées, 73 avec d « hyomi liste ~75 sages au 7 Adar (date traditionnelle de la mort de Moché) ; pour beaucoup, la date réelle de décès semble inconnue — à vérifier ». 1-26, 1-28 et 2-18 « יהושע בן נון ».

**Correction proposée.** Sous le nom, afficher une mention traduite quand le doute porte sur la date : fr « Date selon la tradition » / en « Traditional date » / he « לפי המסורת ». Pour le 7 Adar, fr « Date inconnue : rappelé le 7 Adar » / en « Date unknown: remembered on 7 Adar » / he « יום פטירתו אינו ידוע; נזכר בז' באדר ». Ces mentions reposent sur le champ « dd » proposé pour le tri.

### THILLOULOT-15 — Halakha séfarade servie par défaut, quel que soit le noussa'h choisi, sous le titre générique « Halakha du jour »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** Le livre par défaut est le Yalkut Yosef, pour tous les utilisateurs, y compris ceux qui ont choisi Ashkenaz ou Sefard. Le Ben Ish 'Haï, seule alternative, est lui aussi séfarade. L'application connaît pourtant le noussa'h, puisqu'elle l'utilise pour la règle d'Adar des hilloulot. Plusieurs se'ifim de la sélection prescrivent explicitement la coutume séfarade contre celle des 'hassidim et des Ashkénazes. Pour une application breslev, cela peut être lu comme « la » halakha.

**Preuve.** Store.kt:832 « … ?: SourceHalakha.YALKUT » ; web/src/js/store.js:159 « get('halakha_source', 'yalkut') » ; VueJour.kt:192 (le noussa'h est utilisé pour les hilloulot) et VueJour.kt:220-224 (il ne l'est pas pour la halakha). yalkut_yosef.json, ordinaire, « סימן ח' - מהלכות ציצית » אות מז : « …יחזרו למנהג רבותינו הספרדים ויכניסו את הציציות מתחת לבגדיהם » ; אות סט : « מנהגינו … להניח תפילין של יד מיושב ».

**Correction proposée.** Nommer le psak dans le libellé. strings.xml halakha_livre : « Yalkut Yosef, Kitsour Choul’han Aroukh (coutume séfarade) » ; en : « Yalkut Yosef, Kitzur Shulchan Aruch (Sephardic custom) » ; he : « ילקוט יוסף, קיצור שולחן ערוך (מנהג הספרדים) ». Au premier affichage de la carte, proposer le choix du livre au lieu d'imposer le Yalkut.

### THILLOULOT-16 — Les données MyTzadik sont mal exploitées : 883 années de décès perdues, 65 « biographies » réduites à la formule de décès, 147 noms sans source

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** 1 500 entrées n'ont pas d'année, donc pas de ligne « Décès : ». Pour 883 d'entre elles, leur propre biographie donne pourtant l'année (« בשנת ה'… השיב את נשמתו ליוצרה »). 65 « biographies » ne contiennent que cette formule, mais elles déclenchent le chevron et l'invite « lire sa biographie ». 147 entrées « m » sans biographie ni notice s'affichent comme un nom nu : ni année ni mention de MyTzadik, alors que la source n'est affichée qu'après une biographie.

**Preuve.** Script : « sans annee 1500 dont recuperables depuis la bio 883 » ; « bios reduites a la formule du deces: 65 » ; « entree m seule sans bio ni notice: 147 ». Échantillon : #37 adar1-1 « אדמו"ר רבי מרדכי טברסקי מקורוסטישיב » a="" , biographie (34 caractères) « בשנת ה'תרע"ו השיב את נשמתו ליוצרה. » ; #4 10-24 « רבי יוסף מיאמפולה », même formule. HilloulotActivity.kt:311-334 (la source n'est ajoutée qu'avec une biographie).

**Correction proposée.** À la construction : remplir « a » avec « (?:בשנת|שנת)\s+(ה['׳]ת[א-ת"״]{1,4})\s+השיב » quand il est vide ; ne pas créer de biographie si son texte, crédits retirés, se réduit à cette formule. Dans fiche(), afficher la source MyTzadik dès que « m » est dans h.sources, même sans biographie.

### THILLOULOT-17 — Typographie des sources de halakha : '' au lieu de ״ (1 532 fois) et titres de sections du Ben Ish 'Haï abîmés

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** La sélection du Yalkut garde la double apostrophe de la saisie Torat Emet (ילקו''י, עכו''ם, ט''ו בשבט), alors que l'outil du livre complet la convertit. Deux titres de sections du Ben Ish 'Haï, affichés dans la ligne de source de chaque halakha, sont fautifs. Tazria-Metsora est réduit à « תזריע », précédé d'une espace. Behar-Be'houkotaï devient « בא"ח שנה שניה  בהר », ce qui répète l'année déjà écrite dans la ligne.

**Preuve.** Script : « '' (double apostrophe au lieu de ״): 1532 dans 477 se'ifim » sur 788, et 9 titres de siman (« מהלכות ומנהגי ט''ו בשבט »). tools/yalkut_kitsour_livre.py:27 « .replace("''", "״") » (absent de la sélection). ben_ish_hai.json annees["1"]["TAZRIA_METZORA"].he = « תזריע » (avec une espace en tête) ; annees["2"]["BEHAR_BECHUKOSAI"].he = « בא"ח שנה שניה  בהר ». HalakhaActivity.kt:195-197 affiche « בן איש חי · שנה שנייה · בא"ח שנה שניה  בהר · אות א ».

**Correction proposée.** Dans tools/yalkut_yosef_construction.py, appliquer .replace("''", "״") aux champs s et t. Dans ben_ish_hai_construction.py, fixer les titres : « תזריע־מצורע » et « בהר־בחוקותי ».

### THILLOULOT-18 — Années de décès : formes fautives et années civiles mêlées aux années hébraïques

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** La ligne « Décès : %1$s » affiche l'année telle quelle. 115 entrées issues de hyomi portent une année grégorienne (« Décès : 1987 ») au milieu d'années hébraïques. Sept années hébraïques sont mal formées (apostrophe manquante, lettres dans le désordre) ; une autre contient une glose.

**Preuve.** Script OUT/thilloulot2/annees.py : « annee civile: 115 », par exemple 5-1 « חכם יהודה קיסוס » a=1987. Formes fautives : 1-22 « התר"ץ », 10-17 « התרס"ד », 6-5 « התש"ב », 7-10 « התשע"א », adar-16 « תרח"ץ », 9-30 « תיע"ה », adar-7 « הש"ס ». 1-13 « ה'ש"ס (לפי זאב וילנאי ה'שנ"ג) ». strings.xml:883 « Décès : %1$s ».

**Correction proposée.** Normaliser à la construction : « ה'תר"ץ », « ה'תרס"ד », « ה'תש"ב », « ה'תשע"א », « תרצ"ח », « ה'ש"ס », et vérifier « תיע"ה » auprès de la source. Convertir les années civiles en années hébraïques quand le jour hébreu est connu (calcul KosherJava). Sinon, les afficher en clair, par exemple « Décès : 1987 (civil) ».

### THILLOULOT-19 — Web : l'invite « Touchez un nom… » oublie les biographies

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** Le web décide d'afficher l'invite sans tenir compte des biographies (x.b), alors qu'Android les compte (aDesDetails). Les jours où seules des biographies existent, l'invite manque sur le web : 14 clés, surtout en Adar.

**Preuve.** web/src/js/app.js:3019 « const detaillees = liste.some((x) => x.t || x.w || x.i); » contre HilloulotActivity.kt:230-231 « h.description != null || h.bios.isNotEmpty() || h.hidabroot != null || h.article != null ». Script : 14 clés, par exemple adar-19, adar-24, adar1-9.

**Correction proposée.** Remplacer par « const detaillees = liste.some((x) => x.t || x.b?.length || x.w || x.i); ».

## Constats réfutés par la contre-expertise

### THILLOULOT-01 — Yalkut Yosef : le livre entier (14 303 se'ifim) est livré dans l'APK et publié sur le web, alors que l'écran affirme « une sélection, non le livre entier »

**Gravité** : mineur (auditeur : bloquant) · **Contre-expertise** : réfuté · **Plateforme** : transverse · **Type** : fonction

**Constat.** Le seul accord consigné pour le Yalkut Yosef date du 13/10 et pose une condition : « droits reçus si textes non copiés dans leur entièreté ». Or, depuis le 19/10, le Kitsour complet est dans la Bibliothèque : 1 048 simanim, 14 303 se'ifim, 5,33 millions de caractères. Il est aussi en ligne dans le site public, à data/livres/yalkut_yosef_kitsour.json (11,5 Mo). Le livre porte pourtant la mention « כל הזכויות שמורות … אסור להעתיק ». Pendant ce temps, l'écran de la halakha affiche dans les trois langues « une sélection, non le livre entier ». YalkutYosef.kt dit « Jamais le livre entier », yalkut_yosef.json dit « textes non copiés dans leur entièreté », et la décision du 29/10 (« l'accord suffit… la sélection reste telle quelle ») repose sur cette prémisse fausse. De plus, le workflow source-yalkut.yml pousse le HTML intégral de Torat Emet sur la branche claude/source-yalkut du dépôt. L'absence de toute pièce écrite est déjà connue. La contradiction ne l'est pas : la licence du 19/10 n'existe que dans une docstring d'outil, et le texte affiché à l'utilisateur est faux.

**Preuve.** res/values/strings.xml:1031 « …(texte de Torat Emet, CC BY-NC-SA 2.5) : une sélection, non le livre entier. » (même texte en values-en:967 et values-iw:996). LivresBruts.kt:21 « "yalkut_yosef_kitsour" to R.raw.livre_yalkut_yosef_kitsour ». LivresTest.kt:62-63 « Les 1 048 simanim du Kitsour Yalkut Yosef ». Script : 1 048 sections, 14 303 se'ifim. FEUILLE_DE_ROUTE.md:866 « droits reçus si textes non copiés dans leur entièreté » ; :875-876 « Une **sélection** — jamais le livre entier » ; :1049-1051 « l'accord suffit ; la sélection reste telle quelle. Aucune pièce écrite n'est versée au dépôt. ». tools/yalkut_kitsour_livre.py:9-12 « Licence reçue par le propriétaire… (déclaration du 19/10/2026) ». YalkutYosef.kt:13-14 « Jamais le livre entier : une dizaine de pour cent ». myhitbodedut-web/data/livres/yalkut_yosef_kitsour.json (11 493 541 octets). .github/workflows/source-yalkut.yml:23-27 (git push -f … claude/source-yalkut).

**Correction proposée (revue par le contre-expert).** Ne rien retirer. Consigner la licence du 19/10 (livre entier) dans FEUILLE_DE_ROUTE.md, sous « Droits et sources en attente », avec l'écrit à verser. Facultatif, pour lever l'ambiguïté avec la Bibliothèque : fr « Yalkut Yosef – Kitsour Choul’han Aroukh, Rav Yitzhak Yosef (texte de Torat Emet, CC BY-NC-SA 2.5) : deux halakhot choisies chaque jour ; le livre entier est dans la Bibliothèque. » ; en « Yalkut Yosef – Kitzur Shulchan Aruch, Rav Yitzchak Yosef (Torat Emet text, CC BY-NC-SA 2.5): two halakhot chosen for each day; the full book is in the Library. » ; he « ילקוט יוסף – קיצור שולחן ערוך, מו״ר הרב יצחק יוסף (הוכן מתוכנת תורת אמת, CC BY-NC-SA 2.5): שתי הלכות נבחרות לכל יום; הספר המלא נמצא בספרייה. »

**Note du contre-expert.** Le livre entier est livré à dessein, sous une licence déclarée le 19/10. Elle n'est pas consignée que dans la docstring de l'outil : on la trouve aussi dans le champ « source » du livre et dans _meta.sources de livre_yalkut_yosef_kitsour.json (« licence reçue par le propriétaire… (19/10/2026) »), et dans PUBLICATION_PLAY_STORE.md:250 (« CC BY-NC-SA 2.5 + licence reçue … garder l'écrit de la licence » ; la citation « texte intégral + sélection » n'y figure pas). La chaîne halakha_yalkut_source n'apparaît que sur l'écran de la halakha du jour (HalakhaActivity.kt:154, app.js:2885) et y décrit la sélection yalkut_yosef.json, ce qui est exact ; la note du 29/10 porte sur cette même sélection, et le livre affiche le crédit qu'exige la mention « ללא ציון המקור ». Reste une lacune mineure : la feuille de route ne consigne pas la licence du 19/10. La réécriture proposée (« באישור המחבר בכתב ») affirmerait une autorisation écrite qui n'existe pas.
