# ETSOT — Likoutei Etsot — qualité FR et EN

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

15 constats — confirmés en partie : 4 · confirmés : 1 · non contre-expertisés (mineurs et cosmétiques) : 10.

## Ce qui a été examiné

Corpus : RAW/livre_likoutei_etsot.json (55 sections, 1 308 blocs). La copie du site (myhitbodedut-web/data/livres/likoutei_etsot.json) est identique bloc à bloc ; le livre n’apparaît pas dans R/nokia. Scripts et sorties dans OUT/etsot (scan1 à scan4, echantillon.py, extraits lus).

Balayé en entier par script (1 308 blocs et 55 titres) :
- blocs sans FR ou sans EN : 0 ; FR identique à EN : 0 ; traduction identique à l’hébreu : 0 ; fins de phrase suspectes : 0 ;
- lettres hébraïques dans la traduction : 2 blocs FR, 1 bloc EN (voulues) ;
- rapports de longueur : les 15 extrêmes de chaque côté et de chaque langue lus, plus 24 extrêmes FR/EN ; aucune troncature ;
- doublons : 1 paire (doublon de la source) ; balises : 14 blocs ;
- numéros de paragraphe (1 295) et références finales (1 294) comparés à l’hébreu ;
- références bibliques ajoutées (64, dans 49 blocs) ; renvois entre sections (130 FR, 131 EN) ;
- tables de variantes des termes clés et noms propres ; mélange de langues ; typographie ;
- recherche ciblée d’homographes sur tout le livre (תשובה, נחלק, שנה, חיות, דמים, שער, הודאה, כלה, etc.).

Lu de près, hébreu, français et anglais côte à côte : 270 blocs distincts (20,6 % du livre).
- Échantillon imposé (graine 20261112) : 122 blocs, les 55 sections représentées.
- Lectures ciblées : section « Hitbodedout » en entier (23 blocs), « Guérison », « Minuit », « Mikvé », « Pidyon », « Mariage » en entier, 63 des 82 blocs des fêtes, 19 blocs à acrostiches et guématries.
- Complément tiré au hasard (graine 20261113) : 26 blocs des grandes sections.

Décompte, échantillon imposé (122 blocs) :
- Français : 0 bloc avec erreur grave ; 10 blocs avec erreur légère (8 %).
- Anglais : 0 bloc avec erreur grave ; 6 blocs avec erreur légère (5 %).

Décompte, ensemble des 270 blocs lus :
- Français : 1 bloc avec erreur grave (33/27) ; 21 blocs avec erreur légère (8 %).
- Anglais : 1 bloc avec erreur grave (33/27) ; 14 blocs avec erreur légère (5 %).
La recherche d’homographes a ajouté un contresens hors lecture (34/8), commun aux deux langues. Ordre de grandeur pour le livre entier : 5 à 10 contresens, dont 2 localisés ; une centaine de blocs français et une soixantaine de blocs anglais avec erreur légère. Les incohérences de terminologie et de présentation sont comptées à part.

Nature des deux traductions : produites ensemble à partir de l’hébreu (mêmes gloses, mêmes ajouts, mêmes erreurs de lecture dans les deux langues). Le français n’est pas traduit de l’anglais (erreurs propres à chaque langue), mais comparer FR et EN ne détecte pas les contresens communs.

Non examiné :
- 1 038 blocs (79 %) n’ont pas été lus de près ; ils n’ont subi que les contrôles mécaniques.
- Pas de comparaison systématique de chaque paragraphe avec la leçon de Likoutei Moharan qu’il résume (faite sur 6 passages ; c’est le contrôle le plus rentable à automatiser).
- Affichage non vérifié sur appareil : le constat sur les balises repose sur la lecture du code.
- Si’hot HaRan et ’Hayé Moharan absents du dépôt : une seule vérification externe (Si’hot HaRan 86, Wikisource hébreu).

Remarque hors traduction : la section « Guérison » (sections[45].blocs[1] et blocs[10]) dit, fidèlement à l’hébreu, que « les médecins nuisent plus qu’ils n’aident » et qu’il faut « beaucoup s’éloigner des docteurs ». La feuille de route a écarté des prières de Likoutei Tefilot pour ce motif ; ici le texte est livré sans avertissement. Décision éditoriale à prendre par le propriétaire.

## Ce qui tient

- Couverture complète et texte intègre : les 1 308 blocs et les 55 titres ont un français et un anglais ; aucun bloc vide, aucune traduction identique à l’hébreu ou à l’autre langue, aucune phrase inachevée, aucune troncature ni gonflement parmi les cas extrêmes lus (rapport de longueur FR/hébreu médian 1,75, EN/hébreu 1,68, très réguliers). Les 55 titres de section sont justes.
- Numéros et références exacts : sur 1 295 numéros de paragraphe et 1 294 références finales comparés par script à l’hébreu (לק"א, לק"ת, שם, Si’hot HaRan, ’Hayé Moharan), aucun chiffre faux dans aucune des deux langues ; les deux seuls écarts sont des coquilles de la source que le traducteur a rectifiées à bon escient.
- Nom divin tenu d’un bout à l’autre selon la décision du propriétaire : Hachem / Hashem pour ה' et השם (679 et 672 occurrences), « le Saint, béni soit-Il », Dieu / God réservés à אלקים, l’Éternel / the LORD dans les versets ; ni D.ieu, ni G-d, ni Seigneur.
- Pièges d’un hébreu non vocalisé le plus souvent déjoués : שנה = sommeil (avec le jeu chana / chéna expliqué pour Roch Hachana), חיות tour à tour vitalité, bêtes féroces et ’hayot célestes, משא ומתן באמונה = « commerce fait avec probité », חלי נופל = épilepsie, אחר = A’her, כ"ח אתוון = vingt-huit lettres ; acrostiches et guématries exacts (פזר נתן לאביונים → נפל ; אמונה = בנים).
- Les quelque 64 références bibliques et michnaïques ajoutées (sections 40 à 54) sont identiques en français et en anglais, et la cinquantaine contrôlée est exacte ; l’araméen du Zohar et la plupart des gloses yiddish sont bien rendus (« Torah de l’Ancien caché », « chlimazelnik », « iber-trakhtn », « akhtsn oun krekhtsn »).
- Typographie française homogène et sans faute (espaces insécables, guillemets, apostrophes), aucun mot anglais resté dans le français ; les longs paragraphes (jusqu’à 2 000 signes) sont suivis phrase à phrase sans omission.

## Constats

### ETSOT-01 — FR+EN — « Mélodie » § 9 : « hérésie pour laquelle il n’y a pas de techouva » (תשובה = réponse, pas repentir)

**Gravité** : majeur (auditeur : bloquant) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** Le mot תשובה, qui désigne ici la « réponse » à une objection, est lu « techouva / teshuvah ». Le français et l’anglais affirment donc qu’il n’existe pas de repentir pour l’hérésie, ce que le texte ne dit pas (Likoutei Moharan I, 64 parle des questions du ‘halal hapanouï auxquelles on ne peut pas répondre) et qui heurte l’enseignement central du livre (on peut toujours revenir). La même phrase hébraïque est traduite correctement treize sections plus haut : l’erreur vient de l’absence de relecture, pas d’un choix.

**Preuve.** RAW/livre_likoutei_etsot.json, sections[34] « נגינה », blocs[8]. HE : « [ט]. על ידי הנגון של הצדיק הגדול האמתי, הוא מעלה את הנשמות שנפלו לאפיקורסות שאין עליה תשובה ». FR : « 9. Par la mélodie du grand et vrai Tsadik, il élève les âmes tombées dans l’hérésie, pour laquelle il n’y a pas de techouva. » EN : « …the souls that have fallen into the heresy for which there is no teshuvah. » Contre-épreuve, même fichier, sections[20].blocs[10] (même phrase) : « …l’hérésie mentionnée plus haut, pour laquelle il n’y a pas de réponse » / « for which there is no answer » ; sections[20].blocs[8] : « questions… pour lesquelles il est impossible de trouver une réponse ».

**Correction proposée.** FR : « 9. Par la mélodie du grand et vrai Tsadik, celui-ci élève les âmes tombées dans l’hérésie à laquelle il n’y a pas de réponse. (Likouté Moharan I, 64:5) » EN : “9. Through the melody of the great and true tzaddik, he raises up the souls that have fallen into the heresy for which there is no answer. (Likutei Moharan I, 64:5)” Mesure d’ensemble : règle de glossaire « תשובה près de קשיא / אפיקורסות / תרוץ = réponse / answer » (la recherche par script sur tout le livre n’a trouvé que cette occurrence fautive).

**Note du contre-expert.** Blocs 34/8 et 20/10 rouverts, conformes aux citations ; la leçon source dans l'application (livre_likoutei_moharan.json, sections[63].blocs[7] et [11] : « כי אין שום תשובה על האפיקורסות הזאת », rendu « aucune réponse (techouva) ») confirme que תשובה = réponse, et mon balayage des 184 occurrences de תשובה du livre ne trouve que ce bloc fautif. Le défaut est réel et la correction proposée est juste. Gravité ramenée à majeur : contresens net mais isolé (un mot, un bloc, deux langues), la phrase dit elle-même que le Tsadik relève ces âmes, et la leçon applique à cette hérésie « nul n'en revient / perdu à jamais » (20/8 et 20/9, bien traduits), donc l'enseignement n'est pas inversé ; détail : l'écart est de 14 sections, non 13.

### ETSOT-02 — FR+EN — « Les fêtes de Hachem », Yom Tov § 6 : « הולך ונחלק ונופל » (marche, glisse et tombe) rendu « va en déclinant, en se dispersant »

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : texte

**Constat.** Contresens né de l’hébreu non vocalisé : נחלק (« il glisse ») est lu « il se divise », et הולך ו… est pris pour une tournure progressive. Le conseil (celui qui glisse dans la rue et dont on rit a manqué à la joie de la fête) devient une phrase abstraite sans rapport. L’application se contredit : sa propre traduction de la leçon source (Likoutei Moharan I, 235) est juste.

**Preuve.** RAW/livre_likoutei_etsot.json, sections[33] « מועדי ה' », blocs[27]. HE : « ו. מי שהולך ונחלק ונופל והעולם שוחקין ממנו, והוא מתביש על ידי זה, כל זה בא לו על ידי שפגם בשמחת יום טוב ». FR : « 6. Celui qui va en déclinant, en se dispersant et en tombant, et dont le monde se moque, de sorte qu’il en a honte… » EN : « 6. One who keeps diminishing, becoming divided and falling, and whom the world laughs at… » Contre-épreuve : RAW/livre_likoutei_moharan.json, sections[234] « תורה רלה », blocs[0] : « Sache que celui qui marche, glisse et tombe, et qu’alors les gens se moquent de lui… » / « one who walks and slips and falls ».

**Correction proposée.** FR : « 6. Celui qui, en marchant, glisse et tombe, et dont les gens se moquent au point qu’il en a honte : tout cela lui arrive parce qu’il a porté atteinte à la joie du Yom Tov. (Likouté Moharan I, 235) » EN : “6. One who is walking and slips and falls, so that people laugh at him and he is put to shame — all this comes upon him because he blemished the joy of Yom Tov. (Likutei Moharan I, 235)” Mesure d’ensemble : Likoutei Etsot résume des leçons de Likoutei Moharan déjà traduites dans l’application ; rapprocher par script chaque paragraphe de la leçon citée en fin de bloc et relire ceux où les deux traductions divergent.

**Note du contre-expert.** Bloc 33/27 et contre-épreuve (livre_likoutei_moharan.json, sections[234].blocs[0]) rouverts, conformes aux citations. L'hébreu vocalisé de la leçon (« שֶׁהוֹלֵךְ וְנֶחֱלָק וְנוֹפֵל … רַגְלוֹ מוֹעֲדָה וְנָפַל ») impose « marche, glisse et tombe » : le français et l'anglais d'Etsot (« va en déclinant, en se dispersant » / « keeps diminishing, becoming divided ») sont un contresens net qui vide le conseil de son sens. Un seul bloc, gravité majeure justifiée, corrections proposées fidèles et sans faute.

### ETSOT-03 — FR+EN — Balises &lt;b> et &lt;br> affichées telles quelles dans 14 paragraphes traduits (intertitres des fêtes, « Mariage », « Volonté et aspirations », « Réprimande »)

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** Quatorze blocs français et anglais commencent par un intertitre balisé recopié de l’hébreu. L’hébreu passe par un rendu HTML ; la traduction est ajoutée comme texte brut : le lecteur voit les chevrons. Cela touche l’ouverture de chaque fête (Roch ’Hodech, Pessa’h, Roch Hachana, Yom Kippour, Souccot, ’Hanouka, Pourim…). Dans deux blocs le titre est en plus collé au texte, y compris en hébreu. Constat tiré de la lecture du code, non observé sur appareil.

**Preuve.** RAW/livre_likoutei_etsot.json : sections[33].blocs[21, 22, 30, 34, 39, 41, 45, 59, 63, 76, 80], sections[21].blocs[0], sections[44].blocs[0], sections[50].blocs[0]. Ex. sections[33].blocs[21] FR : « &lt;b>Les fêtes de Hachem – Roch ’Hodech&lt;/b>&lt;br>1. La racine de la techouva est Roch ’Hodech. » EN : « &lt;b>The Festivals of Hashem – Rosh Chodesh&lt;/b>&lt;br>1. The root of teshuvah… ». sections[21].blocs[0] HE : « &lt;b>חתון&lt;/b>א. על ידי תפלה בכח זוכה לזווגו » ; FR : « &lt;b>Mariage&lt;/b>1. Par une prière faite avec force… » ; EN : « &lt;b>Marriage&lt;/b>1. Through praying… ». Rendu : K/SiddurLectureActivity.kt l. 505-514 (hébreu : Html.fromHtml ; traduction : append(t)) ; R/web/src/js/app.js l. 796 (paraTraduction : nœud texte) contre l. 1400 (hébreu : riche()).

**Correction proposée (revue par le contre-expert).** Corriger d'abord le rendu, qui est la cause : interpréter &lt;b>, &lt;small> et &lt;br> dans les traductions comme dans l'hébreu (Android, SiddurLectureActivity.kt l. 514 : passer la traduction par Html.fromHtml ; web, app.js l. 796 : paraTraduction avec riche(texte)), ce qui règle Etsot et les autres livres d'un coup. Dans les données, retirer seulement le titre redondant collé au texte de sections[21].blocs[0] et sections[44].blocs[0] (he, fr, en) : « 1. Par une prière faite avec force, on mérite de trouver son conjoint. (Likouté Moharan I, 9:2) » / “1. Through praying with strength one merits to find his match. (Likutei Moharan I, 9:2)”, et rendre le &lt;br> facultatif dans l'expression de tools/livres_construction.py (fonction etsot). Ne pas transformer les intertitres en blocs « c » sans modifier le code : un bloc « c » ne porte aujourd'hui ni fr ni en (Siddur.kt l. 96, et le rendu vide les traductions des consignes) ; il resterait en hébreu seul.

**Note du contre-expert.** Recompté par script : 14 blocs fr/en avec balises, exactement ceux cités (11 dans la section 33, plus 21/0, 44/0, 50/0), et le code confirme l'affichage brut (SiddurLectureActivity.kt l. 505-514 : Html.fromHtml pour l'hébreu, append(t) pour la traduction ; app.js l. 796 : nœud texte ; même fonction dans le site construit). Défaut réel mais sans perte de sens et limité à 14 blocs sur 1 308 (1,1 %) : mineur à l'échelle d'Etsot. La cause est le rendu et non les données d'Etsot : le même mécanisme touche les traductions balisées d'autres livres (blocs fr/en avec balises : guide 63, Perek Chira 86, Nichmat 9, Likoutei Moharan 79, Tefila LiShlomo 35, Yalkout Yossef abrégé 1 489), ce qui relève d'un constat transversal plus lourd et rend la correction proposée mal ciblée.

### ETSOT-04 — FR+EN — Durée quotidienne de la hitbodedout : « une heure / quelques heures » en français, « a set time / some time » en anglais, « un moment » ailleurs en français

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** Sur la pratique qui donne son nom à l’application, les deux langues ne disent pas la même chose, et le français se contredit d’une section à l’autre. L’hébreu parle d’heures (שעה מיוחדת, איזה שעות) ; la leçon source, traduite dans l’application, dit « au moins une heure ou davantage ». L’anglais affaiblit quatre fois en « time », le français deux fois en « moment ». En affichage FR+EN les deux consignes se lisent l’une sous l’autre.

**Preuve.** RAW/livre_likoutei_etsot.json, sections[15] « התבודדות ». blocs[12] : HE « לקבע לו על זה איזה שעות ביום » → FR « se fixer pour cela quelques heures par jour » / EN « set aside for this some time each day » ; HE « שעה מיחדת בכל יום ויום » → FR « une heure particulière chaque jour » / EN « a set time every day ». blocs[15] : HE « לקבע שעה מיחדת בכל יום » → « une heure particulière » / « a special time every day ». blocs[22] : HE « ליחד רק איזה שעות ביום » → « quelques heures par jour » / « only some time each day ». Français incohérent : sections[19].blocs[8] HE « רק בשעה מיחדת » → « à un moment fixé » ; sections[46].blocs[31] HE « איזה שעה לב נשבר » → « à un certain moment ». Référence interne : RAW/livre_likoutei_moharan.json, sections[310] « תנינא תורה כה » : « se fixer au moins une heure ou davantage » / « at least an hour or more ».

**Correction proposée (revue par le contre-expert).** Corriger seulement l'anglais des deux pluriels : 15/12 “Each person must set aside for this a few hours each day…” ; 15/22 “…therefore one must set aside only a few hours a day to pour out one’s conversation with a broken heart…”. Laisser « a set time » / « une heure particulière » / « à un moment fixé » pour שעה מיחדת (au plus harmoniser sur « une heure fixe » / “a set time”, formule de Likoutei Moharan II, 25 dans l'application). Facultatif, 46/31 en français : « …il lui est plus facile d’avoir, une heure durant, le cœur brisé… ».

**Note du contre-expert.** Les six blocs cités (15/12, 15/15, 15/22, 19/8, 46/31) existent tels quels. Mais שעה signifie aussi « moment, temps » : « a set time » / « à un moment fixé » pour שעה מיחדת est un rendu légitime, que la référence interne invoquée emploie elle-même (Likoutei Moharan II, 25, sections[310].blocs[3] : « à une heure fixe » / “at a set time”), et « à un certain moment » n'est pas une contradiction du français. Le seul affaiblissement réel est l'anglais « some time each day » pour le pluriel איזה שעות ביום (15/12 et 15/22) : écart de rendu entre les deux langues, pas contresens, donc mineur.

### ETSOT-05 — FR+EN — Notions clés rendues par plusieurs mots concurrents : da’at, mo’hin, tikoun, Tikoun HaKlali, נאוף

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** Aucun glossaire n’a été tenu : la même notion change de nom d’un paragraphe à l’autre, y compris quand elle sert de titre de section ou de nom de fonction dans l’application. Mesures sur tout le livre. דעת (164 occ.) : FR connaissance 136, discernement 36, da’at 17, daat 15, conscience 4 ; EN knowledge 116, da’at 73, understanding 27, awareness 4. מחין (68) : FR intelligences 21, mo’hin 20, facultés 14, intellects 6 ; EN mentalities 28, mochin 20, mental faculties 4. תקון (275) : FR réparation 109, Tikoun 83, remède 65 (« Tikoun de l’alliance » 31 contre « réparation de l’Alliance » 26) ; EN rectification 149, remedy 43, Tikkun 33. תקון הכללי : FR « Tikoun général » 11, « réparation générale » 3 ; EN « general rectification » 14, « Tikkun HaKelali » 1 — alors que l’interface écrit « Tikoun HaKlali » / « Tikkun HaKlali ». נאוף (51) : FR débauche 35, adultère 19 ; EN immorality 30, adultery 21, lust 17. Sur 8 paragraphes hébreux répétés à l’identique dans le livre, 5 ont deux traductions françaises différentes.

**Preuve.** RAW/livre_likoutei_etsot.json. דעת : sections[13].blocs[46] « L’essentiel de l’homme est la connaissance » ; sections[33].blocs[32] HE « כי הקול מעורר הדעת » → « la voix éveille le discernement » ; sections[45].blocs[3] « Selon l’accroissement du daat » (EN : knowledge / da’at / da’at). תקון הכללי : sections[7].blocs[25] HE « על ידי תקון הכללי יש לו פרנסה בלי טרח » → « Par le Tikoun général… » / « Through the general rectification… » ; interface : A/res/values/strings.xml « Tikoun HaKlali ». Même hébreu, deux traductions : sections[7].blocs[8] HE « הוא תקון קרי » → « est un Tikoun pour l’émission nocturne » ; sections[53].blocs[14] (même phrase) → « c’est une réparation pour l’impureté nocturne (keri) ». Comptages : OUT/etsot/scan3.out et scan4.out.

**Correction proposée (revue par le contre-expert).** Glossaire appliqué à la relecture, bloc par bloc, et non par remplacement automatique : דעת et תקון ont des emplois idiomatiques à préserver (ישוב הדעת, חסרון דעת, « והתקון לזה » = « le remède à cela » / “the remedy for this”). Priorités : une seule graphie « da’at » (supprimer les 16 « daat / Daat ») et « mo’hin » ; un seul rendu par notion et par langue — דעת : « connaissance (da’at) » comme le titre de section, donc remplacer « discernement » dans les sections 30-35 (33/32 : « car la voix éveille la connaissance (da’at) ») ; תקון הברית : « réparation de l’Alliance » / “rectification of the Covenant” ; נאוף : « débauche » / “immorality” ; aligner les paires de même hébreu (7/8 sur 53/14 : « …est une réparation pour l’impureté nocturne (keri) » ; 41/7 sur 28/16 : « la réparation générale du commerce »). Pour תקון הכללי dans « L’alliance », garder le sens et donner le nom de l'interface à la première occurrence : 7/23 « le Tikoun général (Tikoun HaKlali) » / “the general rectification (Tikkun HaKlali)” au lieu de “Tikkun HaKelali”.

**Note du contre-expert.** Exemples vérifiés (13/46, 33/32, 45/3, 7/25, 7/8 et 53/14, strings.xml) et l'absence de glossaire est réelle : alignés sur l'hébreu, les 100 blocs où דעת est un nom donnent connaissance 60, discernement 19 (sections 30-35), da’at 18, daat 8 (sections 40-45) ; מחין : mo’hin 13 blocs, facultés 11, intelligences 10 ; תקון הברית : Tikoun 24 / réparation 20 ; נאוף : débauche 24 / adultère 15. Mais les chiffres du constat sont des fréquences brutes non alignées qui gonflent la dispersion : « lust » rend תאוה (4 blocs seulement avec נאוף), la moitié des « remède » rendent רפואה ou סגלה et les autres surtout « והתקון לזה » (rendu correct), je compte 185 תקון (217 avec les formes fléchies) et non 275, et 11 paragraphes hébreux répétés dont 6 diffèrent en français, par le style seulement. Aucun contresens, et תקון הכללי désigne ici la notion de Likoutei Moharan I, 29 (le paragraphe des dix psaumes, 7/67, ne porte pas ce nom en hébreu) : défaut de cohérence, mineur.

### ETSOT-06 — FR+EN — Faux sens lexicaux isolés, communs aux deux langues (pourvoyeurs, se déguisent, mauvais œil, festen, Vienne omis)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le français et l’anglais ont été produits ensemble : quand un mot hébreu est mal compris, l’erreur figure dans les deux langues et la comparaison FR/EN ne la révèle pas. Relevé : 4 blocs sur les 122 de l’échantillon (3 %), soit de l’ordre de 30 à 40 blocs dans le livre.

**Preuve.** RAW/livre_likoutei_etsot.json. (1) sections[26].blocs[21] HE « כשפרנסי הדור ומנהיגי הדור נתגאים » → FR « les pourvoyeurs de la génération » / EN « the providers of the generation » ; פרנס = notable communautaire ; la leçon source dans l’application (livre_likoutei_moharan.json, sections[94]) dit « les dirigeants de la génération » / « the leaders ». (2) sections[21].blocs[2] HE « וכן מה שהבדחנים מהפכין עצמן » → « que les amuseurs se déguisent » / « the jesters’ disguising themselves » ; il s’agit de culbutes (Si’hot HaRan 86 : « שהתחתונים עלו למעלה והעליונים ירדו למטה »). (3) sections[8].blocs[6] HE « על ידי רע עין לא יזכה להניח בן זכר » → « À cause du mauvais œil, on ne mérite pas de laisser un fils » / « Through an evil eye… » : se lit comme un mauvais œil subi, alors qu’il s’agit de celui qui regarde autrui avec envie (LM I, 54, Avchalom). (4) sections[39].blocs[3] HE « במדינות קיר"ה (הקיסר ירום הודו) דווין » → « dans les pays de l’Empereur (que sa majesté soit exaltée) » / « in the lands of the Emperor… » : « דווין » (de Vienne) omis. (5) sections[15].blocs[20] HE « (שקורין פעסטין) » → « festen » dans les deux langues ; le yiddish est pesten. (6) FR seul, sections[50].blocs[0] HE « מוכיחי הדור » → « Les moralisateurs de la génération » (péjoratif ; sections[47].blocs[2] dit « Ceux qui exhortent la génération »).

**Correction proposée.** (1) « Lorsque les notables (parnassim) et les dirigeants de la génération s’enorgueillissent… » / “When the communal leaders (parnasim) and the guides of the generation become arrogant…”. (2) « …et de même que les amuseurs font des culbutes, etc. » / “…and likewise the jesters’ turning somersaults, etc.”. (3) « 7. Celui qui porte un regard envieux (un mauvais œil) sur autrui ne méritera pas de laisser un fils. » / “7. One who has a begrudging (evil) eye will not merit leaving behind a son.”. (4) « …dans les pays de l’empereur de Vienne (que sa majesté soit exaltée)… » / “…in the lands of the Emperor of Vienna (may his majesty be exalted)…”. (5) « (ce qu’on appelle en yiddish “pesten”) » / “(what is called in Yiddish pesten)”. (6) « 1. Ceux qui réprimandent la génération… ». Mesure d’ensemble : relecture humaine par un lecteur d’hébreu rabbinique, en partant des mots de métier et des gloses yiddish (13 gloses « שקורין », toutes listées dans OUT/etsot).

### ETSOT-07 — FR — Section « Hitbodedout » : « se juge et se condamne », « prétextes », et la même image du fils rendue de deux façons

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Trois écarts du français dans la section centrale du livre pour cette application ; l’anglais est juste sur les deux premiers.

**Preuve.** RAW/livre_likoutei_etsot.json, sections[15]. (1) blocs[0] HE « וידין וישפט את עצמו בכל עת על כל עסקיו ומעשיו » → FR « qu’il se juge et se condamne lui-même en tout temps » (deux fois dans le bloc) ; EN « judge and evaluate himself ». ישפט = juger, examiner ; « condamner » ajoute une sévérité absente et contraire à l’esprit du passage. (2) blocs[12] HE « בטענות ואמתלאות ודברי רצוי ותחנונים » → FR « en arguments et en prétextes » ; EN « with arguments and pleas » ; la leçon source dans l’application (livre_likoutei_moharan.json, sections[310]) : « avec des arguments et des raisons ». (3) HE « כבן המתחטא לפני אביו » → blocs[20] « comme un fils qui cajole son père », blocs[22] « comme un fils qui supplie son père ».

**Correction proposée.** (1) « …qu’il se juge et s’examine lui-même en tout temps sur toutes ses affaires et toutes ses actions… », et plus bas « qu’il se juge et s’examine lui-même sur toutes ses affaires et ses actions ». (2) « …qu’il le confie à Hachem, béni soit-Il, avec des arguments et des justifications, des paroles de conciliation et des supplications… ». (3) une seule formule aux deux endroits : « comme un enfant qui se fait câlin devant son père ».

### ETSOT-08 — FR+EN — Renvois « voir … » vers d’autres sections sous un nom qui n’est pas le titre affiché

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le livre renvoie sans cesse d’une section à l’autre. Sur 130 renvois nommés en français et 131 en anglais (relevé par script), 46 et 43 ne reprennent pas le titre de la section tel que l’application l’affiche ; une vingtaine par langue emploient un autre mot, si bien que le lecteur ne retrouve pas la section. L’unité du renvoi varie aussi : FR « § » 198, « n° » 46, « paragraphe » 15, ou rien ; EN « § » 114, « section » 41, « no. » 46, « paragraph » 18.

**Preuve.** RAW/livre_likoutei_etsot.json. FR : « Souvenir » (sections[33].blocs[77], HE « עין זכרון אות ד' » ; sections[38].blocs[4]) pour « Mémoire » ; « Renforcement » (46/28, 49/75, 33/44) pour « Se renforcer » ; « Charité » (33/29) pour « Tsédaka » ; « Discernement » (33/42) et « Daat » (42/4) pour « Connaissance (Da’at) » ; « Déplacements et voyages » (32/2) pour « Errance et voyages » ; « Pensées et réflexions » (7/68) et « Pensées et rêveries » (49/84) pour « Pensées et mauvaises pensées » ; « Compréhensions » (16/43) pour « Perceptions de la Divinité… ». EN : “Remembrance” (33/77, 38/4) pour “Memory” ; “Strengthening” (46/28, 49/75) et “Encouragement” (33/44) pour “Strengthening Oneself” ; “Thoughts and Fantasies” (7/68, 49/84) pour “Thoughts and Stray Thoughts” ; “Philosophical Inquiry” (40/102) pour “Philosophical Speculation and Secular Wisdom” ; “Wandering and Travels” (32/2). Liste complète : OUT/etsot/scan4.out.

**Correction proposée.** Script : remplacer chaque nom cité par le titre exact de la section visée et unifier la forme. Exemples corrigés : 33/77 « Voir « Mémoire », § 4. » / “See “Memory,” § 4.” ; 46/28 « (voir aussi « Se renforcer », § 26) » / “(see also “Strengthening Oneself,” § 26)” ; 33/29 « (voir « Tsédaka ») » ; 33/42 « (voir « Connaissance (Da’at) ») » / “(see “Knowledge (Da’at)”)” ; 32/2 « [Voir aussi « Errance et voyages », § 8, au sujet du mikvé.] » / “[See also “Wandering and Travel,” § 8, concerning the mikveh.]” ; 7/68 et 49/84 « Pensées et mauvaises pensées » / “Thoughts and Stray Thoughts”.

### ETSOT-09 — FR+EN — Calque « épancher sa conversation » / “pour out his conversation” pour לפרש שיחתו, avec trois rendus concurrents

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** L’expression qui définit la hitbodedout est calquée mot à mot : on n’« épanche » pas une conversation en français, et “pour out one’s conversation” n’est pas de l’anglais. Mesure : FR « épancher sa conversation » 16 fois (12 blocs), à côté de « épancher son cœur » 5 et « épancher sa parole » 3 ; EN “pour out … conversation” 14 fois (11 blocs), à côté de “pour out … heart” 10 et “pour out … words” 3. L’autre livre de l’application sur le sujet (Hichtapkhout HaNefech) dit « épancher ses paroles » / “pour out one’s words”.

**Preuve.** RAW/livre_likoutei_etsot.json. sections[15].blocs[19] HE « יוכל לפרש שיחתו לפני השם יתברך כאשר ידבר איש אל רעהו » → FR « on peut épancher sa conversation devant Hachem, béni soit-Il, comme un homme parle à son prochain » / EN « a person can pour out his conversation before Hashem ». sections[15].blocs[10] HE « ומפרש שיחתו וצערו » → « épanche sa conversation et sa douleur » / « pours out his conversation and his pain ». sections[33].blocs[64] (même hébreu) → « épancher sa parole ».

**Correction proposée.** Formule unique, remplaçable par script : FR « épancher ses paroles devant Hachem » ; EN “pour out his words before Hashem”. Exemples : 15/19 « …on peut épancher ses paroles devant Hachem, béni soit-Il, comme un homme parle à son prochain. » / “…a person can pour out his words before Hashem, blessed be He, as a man speaks to his friend.” ; 15/10 « …épanche ses paroles et sa peine devant Hachem… » / “…pours out his words and his pain before Hashem…”.

### ETSOT-10 — FR+EN — Ajouts du traducteur fondus dans le texte, inégaux selon les lots, dont des gloses inexactes

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le traducteur ajoute des références et des explications sans les distinguer des parenthèses et crochets de l’auteur, et pas partout. Les 64 références bibliques et michnaïques ajoutées se trouvent toutes dans les sections 40 à 54 (49 blocs) et dans deux blocs isolés ; les sections 2 à 39 citent les mêmes versets sans référence. Les références contrôlées (une cinquantaine) sont exactes ; le défaut est l’inégalité et l’absence de marque. Quelques gloses sont en revanche discutables ou fausses.

**Preuve.** RAW/livre_likoutei_etsot.json. Inégalité : sections[36].blocs[3] « car la joie de l’Éternel est votre force » sans référence ; sections[46].blocs[4], même verset, « (Né’hémia 8:10) ». Gloses : sections[0].blocs[0] HE « תרי"ג עטין » → « six cent treize conseils (jeu de mots : tariag mitsvot / tariag eitin) » / « (a play on words…) » : ce n’est pas un jeu de mots, עטין est le mot araméen du Zohar pour « conseils ». sections[21].blocs[2] HE « על פי תורת אמת » → « selon la Torah de vérité (la Kabbale) » / « (the Kabbalah) » : précision absente de l’hébreu. sections[49].blocs[66] HE « יכול למשל בתפלתו » → « peut, pour ainsi dire, gouverner par sa prière » / « can, so to speak, rule » : « pour ainsi dire » ajouté. sections[41].blocs[26] : glose et référence « Tehilim 112:9 » insérées à l’intérieur des crochets de l’auteur.

**Correction proposée.** Règle unique : toute intervention du traducteur entre crochets et en fin de phrase, références de versets partout ou nulle part (les compléter dans les sections 2 à 39). Corrections : 0/0 « six cent treize conseils (en araméen : tariag eitin) » / “six hundred and thirteen counsels (in Aramaic: taryag eitin)” ; 21/2 « selon la Torah de vérité » / “according to the Torah of truth” ; 49/66 « Chaque homme d’Israël peut gouverner par sa prière et accomplir ce qu’il veut » / “Every Jew can rule through his prayer and bring about what he wishes”.

### ETSOT-11 — FR+EN (et hébreu) — Défauts de structure du livre : paragraphe en double, numérotation perdue, sous-titre fondu dans un paragraphe

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Trois défauts hérités de la construction du livre, visibles dans les trois langues. (1) Un long paragraphe de « Réprimande » est présent deux fois de suite, traductions comprises. (2) La section « Hitbodedout » a perdu les numéros de ses sept premiers paragraphes dans les trois langues, alors que d’autres sections y renvoient par numéro. Dans « Tsadik », l’hébreu a perdu les numéros 1 à 16 (le seizième commence par un « ט » orphelin) tandis que les traductions les ont rétablis : en lecture bilingue, l’hébreu et sa traduction ne se répondent plus. (3) Le sous-titre de « Réprimande » est dans le même bloc que le § 1.

**Preuve.** RAW/livre_likoutei_etsot.json. (1) sections[50].blocs[20] et blocs[21] : même hébreu « אתה המעין, אל יבהלוך רעיוניך… », même français « Toi qui étudies, que tes pensées ne t’effraient pas… », même anglais. (2) sections[15].blocs[0..6] sans numéro (blocs[7] commence par « ח. » / « 8. ») ; sections[40].blocs[0] HE « צריך כל אחד לכון בתפלתו… » contre FR « 1. Chacun doit avoir l’intention… » ; sections[40].blocs[15] HE « ט צדיקי אמת הם מעלין את התפלה » contre « 16. Les vrais Tsadikim… ». (3) sections[50].blocs[0] FR : « Ce chapitre comprend aussi ce que chacun doit parler avec son prochain de crainte du Ciel&lt;br>1. Les moralisateurs de la génération… ».

**Correction proposée.** Supprimer sections[50].blocs[21]. Rétablir la numérotation : en hébreu « א. » à « טז. » dans sections[40].blocs[0..15] (et retirer le « ט » orphelin) ; « א. » à « ז. » en hébreu et « 1. » à « 7. » en français et en anglais dans sections[15].blocs[0..6]. Scinder sections[50].blocs[0] : sous-titre « Ce chapitre comprend aussi ce dont chacun doit parler avec son prochain en matière de crainte du Ciel » / “It also includes what each person should speak about with his fellow concerning fear of Heaven”, puis le § 1.

### ETSOT-12 — FR+EN — « Likouté Moharan » 763 fois alors que le livre s’appelle « Likoutei Moharan » dans l’application ; autres orthographes concurrentes

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** La référence qui clôt presque chaque paragraphe français écrit « Likouté Moharan », alors que la bibliothèque de l’application intitule ce livre « Likoutei Moharan » et celui-ci « Likoutei Etsot ». D’autres translittérations flottent. FR : tsédaka 108 / tsedaka 19 / charité 2 ; téfilines 13 / tefilin 12 / tefilines 7 / tefillin 2 (titre de section : « Téfilines ») ; Alliance 33 / alliance 124 ; Autre Côté 30 / autre côté 21 / sitra a’hra 4 ; écorces 27 / kelipot 10 / klipot 8 ; monde à venir 50 / monde futur 25 ; Géhenne 5 / Guéhinom 3 ; terre d’Israël 80 / Terre d’Israël 19 ; souccah / soucca ; « ’H » 724 fois contre « ‘H » 9 fois, dont le titre « Minuit (‘Hatsot) » ; Né’hémia / Ne’hemia. EN : Moses 11 / Moshe 6 ; Chayey Moharan 5 / Chayei 1 ; Covenant 33 / covenant 124 ; kelipot 24 / husks 12 / klipot 5 ; Other Side 41 / sitra achra 12 ; « siman » 11 fois en anglais à côté de « section ».

**Preuve.** RAW/livre_likoutei_etsot.json : textes[0].titre.fr = « Likoutei Etsot » ; RAW/livre_likoutei_moharan.json : titre.fr = « Likoutei Moharan » ; corps du texte, ex. sections[2].blocs[5] « (Likouté Moharan I, 9:1) ». sections[22].titre_fr = « Minuit (‘Hatsot) » contre sections[33].blocs[21] « Roch ’Hodech ». sections[2].blocs[52] « La foi est considérée comme la tsedaka » contre sections[41].blocs[4] « La tsédaka que l’on donne… ». sections[42].blocs[4] « les tsitsit précèdent les tefilin » contre sections[51].blocs[4] « Par les téfilines… ». sections[33].blocs[66] « souccah » contre sections[49].blocs[45] (même hébreu) « soucca ». EN : sections[0].blocs[0] « the extension of Moses » contre sections[40].blocs[111] « Moshe Rabbeinu ». Comptages : OUT/etsot/scan3.out, scan4.out.

**Correction proposée.** Script de normalisation : Likouté → Likoutei ; tsedaka → tsédaka ; tefilin / tefilines / tefillin → téfilines ; « alliance » (pour ברית) → « Alliance » ; autre côté → Autre Côté ; klipot / kelipot → kelipot ; monde futur → monde à venir ; Guéhinom → Géhenne ; soucca → souccah ; « ‘H » / « ‘h » → « ’H » / « ’h », dont le titre « Minuit (’Hatsot) » ; Ne’hemia → Né’hémia. EN : Moshe → Moses (sauf « Moshe Rabbeinu », à garder partout) ; Chayei → Chayey ; covenant (ברית) → Covenant ; klipot → kelipot ; siman → section.

### ETSOT-13 — FR+EN — Deux références de l’hébreu corrigées en silence dans la traduction : l’hébreu affiché dit « première partie », la traduction « II »

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Sur 1 294 références finales comparées par script, deux seulement diffèrent entre l’hébreu et les traductions. Dans les deux cas la traduction a raison et la source hébraïque porte une coquille (לק"א au lieu de לק"ת) ; mais en lecture bilingue le lecteur voit deux références contradictoires.

**Preuve.** RAW/livre_likoutei_etsot.json. sections[13].blocs[46] HE « (לק"א סי' ז' אות ב' ג') » → FR « (Likouté Moharan II, 7, §§ 2, 3) » / EN « (Likutei Moharan II, 7:2, 3) » ; le passage « חיה בדמות אדם » est bien dans RAW/livre_likoutei_moharan.json, sections[292] « תנינא תורה ז », et les blocs voisins citent LM II, 2 et LM II, 10. sections[28].blocs[47] HE « (לק"א סי' א' אות ד' ה' ו' ח') » → « (Likouté Moharan II, 1:4, 5, 6, 8) » ; le même enseignement est cité « לק"ת סי' א' » en sections[33].blocs[28].

**Correction proposée.** Corriger l’hébreu des deux blocs : « (לק"ת סי' ז' אות ב' ג') » et « (לק"ת סי' א' אות ד' ה' ו' ח') », en notant la correction dans tools/livres_construction.py ; les traductions restent telles quelles.

### ETSOT-14 — FR+EN — Conventions de présentation différentes d’un lot de traduction à l’autre (Ibid., format des références, crochets)

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le livre a été traduit par lots et chaque lot a ses usages. « Ibid. » avec majuscule (350 blocs) dans la plupart des sections, « ibid. » (150 blocs) dans les sections 12 à 16 et 49 à 54. Références au format « I, 28:1-3 » ici, « I, 15, §§ 1, 2, 3, 4 » là en français, « 15:1, 2, 3, 4 » en anglais. Les numéros que l’hébreu met entre crochets (337 blocs) ne gardent leurs crochets que dans 43 traductions (dont 35 dans « Joie ») et les perdent dans 294. Seuls deux blocs contiennent des lettres hébraïques dans la traduction, dont un en français seulement.

**Preuve.** RAW/livre_likoutei_etsot.json. sections[2].blocs[14] « (Likouté Moharan I, 28:1-3) » contre sections[15].blocs[0] « (Likouté Moharan I, 15, §§ 1, 2, 3, 4) » / « (Likutei Moharan I, 15:1, 2, 3, 4) ». sections[12].blocs[5] « (ibid.) » contre sections[2].blocs[24] « (Ibid.) ». sections[46].blocs[22] HE « [כג]. » → « [23]. » contre sections[29].blocs[17] HE « [יח]. » → « 18. ». sections[29].blocs[17] FR « « Ma » (מ"ה, « quoi ») » alors que l’anglais écrit « “Mah” (“what”) ». Tableau par section : OUT/etsot/scan4.out.

**Correction proposée.** Script d’unification : « Ibid. » partout en tête de parenthèse ; format unique « I, 15:1-4 » dans les deux langues ; crochets des numéros conservés partout (ils signalent les ajouts de la seconde édition) ou supprimés partout ; 29/17 FR : « dans l’aspect de « Ma » (« quoi ») ».

### ETSOT-15 — FR — Fautes de langue et maladresses ponctuelles

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Français généralement correct et soigné, avec quelques fautes et calques qu’un relecteur corrigerait. Relevé dans l’échantillon : environ 3 blocs sur 122.

**Preuve.** RAW/livre_likoutei_etsot.json. sections[33].blocs[55] : « Par là on mérite un beau etrog » (deux lignes plus bas : « un bel etrog »). sections[50].blocs[0] : « ce que chacun doit parler avec son prochain de crainte du Ciel ». sections[26].blocs[26] HE « צריך לזהר מאד מהתמנות » → « Il faut se garder énormément des nominations ». sections[7].blocs[26] : « Tu n’iras pas colportant parmi ton peuple ». sections[9].blocs[3] HE « מבטח בוגד » → « la confiance du perfide ». sections[33].blocs[27] et sections[46].blocs[26] : « dont le monde se moque », « si le monde est éloigné de Hachem » pour העולם au sens de « les gens » (rendu « les gens » en sections[13].blocs[47] et sections[33].blocs[50]).

**Correction proposée.** 33/55 « Par là on mérite un bel etrog. » ; 50/0 « ce dont chacun doit parler avec son prochain en matière de crainte du Ciel » ; 26/26 « Il faut se garder soigneusement d’accepter une fonction d’autorité, en particulier celui qui a la crainte du Ciel… » ; 7/26 « Tu n’iras pas colporter de médisances parmi ton peuple » ; 9/3 « la confiance placée dans un traître » ; 46/26 « Car si les gens sont éloignés de Hachem, béni soit-Il… ».
