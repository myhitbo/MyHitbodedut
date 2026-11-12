# MIDOT — Sefer haMidot — qualité FR et EN

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

16 constats — confirmés : 1 · confirmés en partie : 5 · non contre-expertisés (mineurs et cosmétiques) : 10.

## Ce qui a été examiné

Corpus audité : android/app/src/main/res/raw/livre_sefer_hamidot.json. La copie web, myhitbodedut-web/data/livres/sefer_hamidot.json, a les mêmes 108 sections, identiques à l'octet près. Scripts et sorties : OUT/MIDOT (charge.py, balayage1 à 5, polarite.py, sens.py, abrev.py, echantillon.py, echantillon.txt, lecture2.txt). Les scripts du dossier « midot » laissé par l'auditeur précédent ont été relus puis refaits.

BALAYÉ PAR SCRIPT, EN ENTIER (2 688 blocs, 108 titres, 53 intercalaires) :
- blocs sans FR ou sans EN : 0 ; FR identique à l'EN : 0 ; traduction identique à l'hébreu : 0 ;
- lettres hébraïques dans le FR ou l'EN : 7 blocs, toutes voulues (jeux de lettres), sauf la perte de l'hébreu en 107/93 ;
- numérotation (guématria et séquence) : 2 688 blocs concordants ;
- rapports de longueur : 15 cas extrêmes de chaque côté, par langue, soit 60 lus ; aucune troncature ;
- traductions arrêtées en milieu de phrase : 0 ; même traduction pour des hébreux différents : 0 cas réel ;
- balises et marqueurs : 0 ; guillemets ou parenthèses non appariés : 7 en EN, plus 1 inversé ; mots d'une langue dans l'autre : 0 ;
- références : 36 renvois ajoutés, 1 faux ; nombres : 0 divergence ;
- table des variantes concurrentes des termes clés ; doublons : 121 groupes, 253 blocs ;
- polarité des négations : 143 écarts relus, aucune inversion par négation ; cause et effet : 46 aphorismes, 0 inversion ; portée de « tout / pas tout » : 12 relus, 1 erreur ;
- ניאוף : 41 blocs ; קרי : 24 blocs ; « remède éprouvé » : 10 blocs.

LU DE PRÈS (hébreu, FR et EN côte à côte) : 560 blocs distincts.
- 263 blocs tirés au hasard (random.seed(20261112), stratifiés, 108 sections sur 108) ;
- 297 blocs ciblés : 48 longs, 22 en araméen, 26 avec références, abréviations, écarts de polarité, extrêmes de longueur.

DÉCOMPTE SUR L'ÉCHANTILLON ALÉATOIRE :
- FR : 263 blocs lus, 0 erreur grave, 5 légères (1,9 %) : « adultère » en 27/5, 49/0, 61/62 et 86/161, « remède éprouvé » en 98/2.
- EN : 263 blocs lus, 0 erreur grave, 5 légères (1,9 %) : « adultery » ×4 et un guillemet en 53/118.

DÉCOMPTE SUR LA LECTURE CIBLÉE (297 blocs à risque) :
- FR : 6 erreurs graves (90/3 inversion, 39/9 portée de la négation, 107/93 compte des lettres, 21/85 référence, 8/132 et 90/1 keri pris pour semence en vain) ; environ 20 légères relevées à la lecture (72/9, 71/3, 8/62, 3 calques « fille d'un dieu étranger », Nom divin dans des versets ; les cas de « remède éprouvé » et « adultère » de ce lot sont comptés dans les totaux par script).
- EN : 4 erreurs graves (90/3, 107/93, 21/85, 90/1) ; environ 15 légères (72/9, 16/17, 81/27, guillemets, calques).

TOTAUX MESURÉS PAR SCRIPT :
- ניאוף rendu « adultère / adultery » : environ 40 blocs par langue, plus un titre ;
- « remède éprouvé » : 10 blocs FR ;
- guillemets EN mal orientés : 8 ;
- intercalaires « חלק שני » non traduits : 53.

ESTIMATION : sur les aphorismes courts, presque aucune erreur grave. Elles se concentrent dans les blocs longs, elliptiques ou porteurs d'une consigne pratique (2 à 3 % de ce sous-ensemble). Il reste probablement 10 à 30 blocs graves par langue non trouvés.

NON EXAMINÉ :
- les quelque 2 130 autres blocs n'ont pas été lus un à un ;
- les traductions des versets cités sans référence n'ont pas été comparées au Rabbinat ni à la JPS ;
- parmi les sentences talmudiques, seule Houlin 37b a été vérifiée en ligne ;
- aucune capture d'écran n'a été faite ;
- ambiguïtés non tranchées, non comptées : 107/48 (נעצר : peut-être « constipé »), 25/5 (תכף לתלמידי חכמים ברכה), 54/10 (sujet de « שלומדים תנ"ך »), 9/5 (דפרע קנאה), 53/104.

## Ce qui tient

- La couverture est complète et propre : les 2 688 blocs et les 108 titres ont tous un FR et un EN. Aucun bloc n'est vide ou identique à l'hébreu, aucun FR n'est identique à l'EN. Il ne reste aucune balise, accolade ni appel de note, et aucune traduction ne s'arrête au milieu d'une phrase. Parmi les 60 blocs aux rapports de longueur les plus extrêmes, aucun n'est tronqué ni gonflé à tort : les écarts viennent de gloses entre parenthèses.
- La numérotation est fidèle partout : les 2 688 numéros FR et EN concordent avec la numérotation hébraïque (guématria), séquence comprise. Les nombres concordent entre l'hébreu, le FR et l'EN, sans divergence entre les deux langues.
- Les références ajoutées sont sérieuses : 36 renvois bibliques ou mishnaïques dans 26 blocs, identiques en FR et en EN, dont 35 sont justes (seule 21/85 est fausse). Les listes de psaumes sont exactes, par exemple les dix psaumes du Tikkoun en 90/15.
- Les jeux de lettres sont bien expliqués : initiales, finales et guématria sont correctement développées et calculées, par exemple 4/22 (ביין avec ses lettres = 76 = א+ה+ע), 21/32 (בכי), 24/49 et 34/0 (נמלה par les lettres finales), 97/14 (מחקק = 248), 107/98 (נביא), 53/115 (רעב).
- La terminologie est très stable sur le cœur du lexique : Hachem/Hashem (106), Tsadik/tzaddik (283), Chekhina/Shechinah (16), Machia'h/Mashiach (25), « le Saint, béni soit-Il » / « the Holy One, blessed be He » (178). Les dictons talmudiques araméens sont bien rendus (80/9, 81/9, 21/7, 107/37, 86/3), et la typographie française est soignée (espaces fines insécables, guillemets français).
- Sur les aphorismes courts tirés au hasard, la qualité est réelle : aucune erreur grave sur 263 blocs dans l'une ou l'autre langue, et la plupart des tournures elliptiques sont bien résolues, par exemple 107/40 « נזהר לומר » → « prend garde de ne pas prononcer ».

## Constats

### MIDOT-01 — FR+EN — Contresens qui inverse un enseignement : « נזהר לאכול משאלת חכם » rendu « ne manger que selon la consultation d'un sage »

**Gravité** : bloquant · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : texte

**Constat.** L'hébreu est elliptique : « נזהר לאכול » veut dire « prendre garde à manger », c'est-à-dire s'en abstenir, comme en 107/40, que le traducteur a bien rendu. La source est Houlin 37b : Ye'hezkel dit « שלא אכלתי מבהמה שהורה בה חכם », il n'a jamais mangé d'une bête permise seulement sur décision d'un sage. Le même passage relie cette rigueur à la pureté nocturne (« לא מטמאה »). Les deux traductions retournent l'enseignement : au lieu d'éviter ce qui n'a été permis que sur consultation, il faudrait ne manger que sur consultation. C'est une pratique de piété présentée à l'envers.

**Preuve.** android/app/src/main/res/raw/livre_sefer_hamidot.json (copie identique : myhitbodedut-web/data/livres/sefer_hamidot.json), textes[0].sections[90] (קרי).blocs[3] — HE : « מי שנזהר. לאכל משאלת חכם, הוא נצול מטמאת קרי. » — FR : « 4. Celui qui veille à ne manger que selon la consultation d'un sage est préservé de l'impureté de keri. » — EN : « 4. One who is careful to eat only according to a sage's ruling is saved from the impurity of keri. » Source vérifiée : Bavli Houlin 37b (« ובשר פגול לא בא בפי – שלא אכלתי מבהמה שהורה בה חכם »).

**Correction proposée.** FR : « 4. Celui qui prend garde de ne pas manger de ce qui n'a été permis que par la décision d'un sage (après consultation) est préservé de l'impureté de keri. » EN : « 4. One who is careful not to eat from what was permitted only by a sage's ruling is saved from the impurity of keri. » Mesure d'ensemble : relire toutes les tournures elliptiques נזהר/יזהר/שומר + infinitif (balayage : 2/8, 2/9, 4/19, 11/3, 11/12, 12/10, 90/3, 107/40) en vérifiant à chaque fois la source talmudique.

**Note du contre-expert.** J'ai rouvert le bloc 90/3 : l'hébreu « מי שנזהר. לאכל משאלת חכם » et les deux traductions sont bien ceux cités. La source a été vérifiée sur Sefaria, Houlin 37b : « שלא הרהרתי ביום לבא לידי טומאה בלילה… שלא אכלתי מבהמה שהורה בה חכם ». Le מ partitif (« manger de la she'elat 'hakham ») et l'usage elliptique de נזהר + infinitif, rendu correctement en 107/40, imposent le sens de l'abstention. FR et EN inversent donc l'enseignement. C'est un bloc unique, mais il correspond exactement à la définition de « bloquant » (sens d'un enseignement inversé). La liste de relecture proposée existe bien ; la plupart de ses blocs emploient מ־ et sont justes.

### MIDOT-05 — FR+EN — « ניאוף » rendu partout par « adultère / adultery », y compris dans le titre de la section 61

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** Chez Rabbi Na'hman, ניאוף (et surtout תאות ניאוף) désigne l'immoralité sexuelle en général, le désir sexuel étant l'une des trois grandes convoitises. La section 61 traite d'ailleurs de l'émission de semence en vain, du regard porté sur les femmes et de l'atteinte à l'alliance. « Adultère » ne vise que la relation d'une personne mariée hors de son mariage : il restreint et fausse la portée d'environ 40 aphorismes. L'épreuve du célibataire, le désir sexuel et la vigilance des jeunes filles se retrouvent tous réduits à l'adultère. De plus, le même mot hébreu donne « débauche » en FR et « adultery » en EN en 23/17.

**Preuve.** livre_sefer_hamidot.json — balayage complet : 41 blocs contiennent ניאוף/נואפים, rendus « adultère(s) » en FR dans 39 et « adultery/adulterers » en EN dans environ 37. Exemples : sections[61].titre_fr « Nioufe – Adultère » / titre_en « Ni'uf – Adultery » ; [61/62] HE « נתבטל תאות נאוף » → FR « le désir de l'adultère s'annule » / EN « the lust of adultery is nullified » ; [61/8] HE « תאות נאוף אינו נרחק… אלא עלידי הרחקת ראות העין » → FR « Le désir de l'adultère ne s'éloigne… » ; [61/36] HE « בזכות שהנקבות נזהרים מנאוף » → FR « Par le mérite des femmes qui se gardent de l'adultère » ; [54/3] HE « העומד בנסיון של נאוף » → FR « l'épreuve de l'adultère » / EN « the trial of adultery » ; [49/0] HE « הם יהיו נואפים » → FR « seront des adultères ».

**Correction proposée (revue par le contre-expert).** Garder le glossaire proposé (ניאוף = « immoralité sexuelle » / « sexual immorality » ; תאות ניאוף = « le désir sexuel » / « sexual lust » ; נואפים = « les débauchés » / « the sexually immoral »), mais l'appliquer bloc par bloc sur les 44 blocs, pas par un script aveugle. Là où le contexte vise l'épouse (61/15 : FR « L'infidélité (nioufe) d'une femme détruit la maison » / EN « A woman's adultery destroys the home »), garder « adultère / adultery ». Aligner l'EN de 23/17 sur le FR : « One who sits among immoral people, or in a place where there was immorality… ».

**Note du contre-expert.** Le défaut est réel et même plus étendu qu'annoncé. Recompté par script (hébreu sans nikoud, נאוף/ניאוף/נואף/נואפים/מנאף) : 44 blocs, dont 43 avec « adultère » en FR (seul 23/17 dit « débauche ») et 44 avec « adultery/adulterer(s) » en EN, au lieu de 41/39/~37. Le titre 61 et les exemples 61/62, 61/8, 61/36, 54/3 et 49/0 sont conformes. La section 61 traite bien de la semence en vain (61/25, 61/40, 61/47), du regard (61/76) et de l'alliance ; « תאות ניאוף » (la convoitise sexuelle en général) rendu par « désir de l'adultère » est une restriction de sens qui se répète. Réserve : quelques occurrences peuvent légitimement viser l'adultère (61/15 « נאוף של אשה מחריב את הבית »), ce qui exclut une substitution aveugle par script.

### MIDOT-02 — FR — Erreur de portée de la négation : « לאו כל החדושין… מותר לו לכתב » rendu comme une interdiction totale d'écrire les 'hidouchim

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** L'hébreu dit : « Il n'est pas permis d'écrire TOUS les 'hidouchim ». La phrase française dit : « Toutes les innovations…, il ne lui est pas permis de les écrire », donc aucune ne peut être écrite. Elle contredit ensuite sa propre suite (« car il en est qui… ») et la conclusion (« celui qui sait lesquelles écrire »). L'anglais est juste (« Not all the insights… is he permitted to write »).

**Preuve.** livre_sefer_hamidot.json, sections[39] (חדושין דאוריתא).blocs[9] — HE : « לאו כל החדושין שאדם מחדש בתורה מתר לו לכתב, כי יש שלא נתן לכתב אףעלפי שנתנו לדרש » — FR : « 10. Toutes les innovations qu'un homme fait dans la Torah, il ne lui est pas permis de les écrire, car il en est qui n'ont pas été données pour être écrites… ». Contrôle « tout / pas tout » sur tout le corpus : 12 blocs revus, seul celui-ci est faux.

**Correction proposée.** FR : « 10. Il n'est pas permis à l'homme d'écrire tous les 'hidouchim qu'il innove dans la Torah, car certains n'ont pas été donnés pour être écrits, bien qu'ils aient été donnés pour être exposés. Et celui qui sait lesquels écrire et lesquels non sait reconnaître un Juif parmi mille [milliers] des nations. »

**Note du contre-expert.** Le bloc 39/9 est conforme à la citation et l'EN est juste. Le FR « Toutes les innovations…, il ne lui est pas permis de les écrire » est ambigu, et non faux à coup sûr : en français, la portée de la négation avec « tous… ne… pas » est notoirement double, et la suite immédiate (« car il en est qui… », « celui qui sait lesquelles écrire ») impose la lecture « pas toutes ». Le lecteur n'est donc pas induit à croire qu'aucun 'hidouch ne peut être écrit ; c'est une formulation maladroite à corriger, pas un contresens majeur. La correction proposée est juste.

### MIDOT-03 — FR+EN — Ségoula faussée : on compte les lettres de « Donne-moi des enfants » / « Give me children » au lieu de « תן לי בנים »

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** La consigne est de donner autant de pièces que la requête hébraïque « תן לי בנים » compte de lettres, soit 8. Les deux traductions remplacent l'hébreu par la traduction dans la proposition finale : le lecteur compte alors 18 lettres en français et 14 en anglais. Le doublon du même texte (85/84) garde l'hébreu et est juste. Les deux versions se contredisent donc dans le même livre.

**Preuve.** livre_sefer_hamidot.json, sections[107] (תפילה).blocs[93] — HE : « …צריך לתן צדקה כמספר אותיות "תן לי בנים" » — FR : « …il faut donner à la tsedaka selon le nombre des lettres de « Donne-moi des enfants ». » — EN : « …according to the number of letters of “Give me children.” » ; comparer sections[85].blocs[84] : FR « …selon le nombre de lettres de « תן לי בנים » ».

**Correction proposée (revue par le contre-expert).** FR : « …il faut donner à la tsedaka autant de pièces qu'il y a de lettres dans « תן לי בנים » (huit). » EN : « …one must give charity according to the number of letters in “תן לי בנים” (eight). »

**Note du contre-expert.** En 107/93, FR et EN reprennent bien la traduction (« Donne-moi des enfants » / « Give me children ») dans la proposition finale, alors que 85/84 garde « תן לי בנים ». Les décomptes 8/18/14 sont exacts, et la liste des 7 blocs contenant de l'hébreu est vérifiée. Mais le même paragraphe vient de donner l'hébreu entre parenthèses (« Donne-moi des enfants » (תן לי בנים)), ce qui désambiguïse largement. Il s'agit d'une incohérence entre doublons, pas d'une « contradiction » entre deux enseignements ; la gravité est surévaluée. La correction FR proposée (« autant de pièces que les lettres de ») est bancale.

### MIDOT-04 — FR+EN — Référence fausse : « (שמות כו,לו) » rendu « Chemot 26:36 / Exodus 26:36 » pour les onze tentures de poil de chèvre

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** Le renvoi hébreu « כו,לו » désigne deux chapitres : le chapitre 26, où les tentures sont ordonnées (26:7-13), et le chapitre 36, où elles sont confectionnées (36:14-18). La traduction en a fait un verset, 26:36, qui parle du rideau de l'entrée de la Tente. Le texte est une consigne (« dis la section… ») : le lecteur qui suit la référence récitera le mauvais passage. Les 35 autres références ajoutées dans 26 blocs ont été vérifiées : elles sont justes.

**Preuve.** livre_sefer_hamidot.json, sections[21] (המתקת דין).blocs[85] — HE : « תאמר הפרשה של אחתעשרה יריעות עזים (שמות כו,לו) » — FR : « dis la section des onze tentures de poils de chèvre (Chemot 26:36) » — EN : « the eleven curtains of goats' hair (Exodus 26:36) ». Shemot 26:7 : « עשתי עשרה יריעת » ; 36:14 : « ויעש יריעת עזים… עשתי עשרה » ; 26:36 : « ועשית מסך לפתח האהל ».

**Correction proposée (revue par le contre-expert).** FR : « (Chemot 26:7-13 et 36:14-18) » ; EN : « (Exodus 26:7–13 and 36:14–18) ». Ajouter une note signalant que l'édition hébraïque porte « כו,לו », qui renvoie aux chapitres 26 et 36 et non au verset 26:36.

**Note du contre-expert.** Le bloc 21/85 est conforme et 26:36 désigne bien le rideau de l'entrée (26:7 et 36:14 : les onze tentures de poil de chèvre). Mais la même édition hébraïque note chapitre,verset avec une virgule (53/96 : « יד,י » = II Chroniques 14:10, rendu 14:10 à juste titre). Selon cette convention, « כו,לו » se lit 26:36 : la référence fautive ou ambiguë vient donc du texte hébreu lui-même, que la traduction a reproduit mécaniquement ; il ne s'agit pas d'une erreur propre au traducteur. Comme le texte nomme correctement « la section des onze tentures », le lecteur peut retrouver le passage : la gravité est mineure. Les ensembles 26:7-13 et 36:14-18 sont justes.

### MIDOT-06 — FR (+EN) — Keri (émission involontaire) confondu avec la semence émise en vain (faute volontaire)

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : transverse · **Type** : texte

**Constat.** La doctrine breslev distingue nettement le keri (מקרה לילה, accident involontaire, réparé par le Tikkoun haKlali) de הוצאת זרע לבטלה (faute volontaire). Deux blocs ajoutent « en vain » (לבטלה), qui n'est pas dans l'hébreu, et font d'un accident une faute grave : pour l'un, les enfants meurent « à cause d'émissions de semence en vain ». Son doublon exact (90/14) dit « émission nocturne », d'où deux enseignements contradictoires dans le même livre. Ailleurs, קרי reçoit cinq rendus différents : émission nocturne, pollution nocturne, keri, impureté de keri, semence en vain.

**Preuve.** livre_sefer_hamidot.json — [8/132] HE « הבנים מתים, חס ושלום, עלידי ראית קרי » → FR « Les enfants meurent, Dieu préserve, à cause d'émissions de semence en vain » (EN « through seminal emissions », vague) ; doublon [90/14] FR « à cause de l'émission nocturne » ; [90/1] HE « מי שמוציא קרי, לסוף הולך ערום » → FR « Celui qui émet de la semence en vain finit par aller nu » / EN « One who emits seed in vain ends up going naked ».

**Correction proposée (revue par le contre-expert).** 8/132 FR « 24. Les enfants meurent, Dieu préserve, à cause du keri (émission nocturne). » / EN « 24. Children die, God forbid, through experiencing keri (nocturnal emission). » ; 90/1 FR « 2. Celui qui émet du keri (de la semence) finit par aller nu. » / EN « 2. One who emits keri (seed) ends up going naked. » ; 90/0 FR « 1. Le keri vient… ». Glossaire : קרי = « keri (émission nocturne) » ; הוצאת זרע לבטלה = « émission de semence en vain » / « wasting seed ».

**Note du contre-expert.** Vérifié : en 8/132, le FR ajoute « en vain », absent de l'hébreu (« ראית קרי »), alors que son doublon 90/14 dit « émission nocturne ». Les cinq rendus sont confirmés : 3/28 et 90/2 « émission nocturne », 54/13 et 74/14 « pollution nocturne », 90/5-13 « keri », 90/0 « impureté de keri » sans טומאה dans l'hébreu, 8/132 et 90/1 « semence en vain ». L'EN de 8/132 (« seminal emissions ») n'est pas faux. Le cadrage doctrinal est exagéré : le livre lui-même, en 90/15, appelle le mikré « עוון זה » (« cette faute » dans le FR), donc l'opposition « accident non fautif / faute grave » ne tient pas telle quelle. En 90/1, « מוציא קרי » est un verbe actif ; « Celui qui a un keri » perd cette nuance.

### MIDOT-07 — FR+EN — Traduction IA non relue présentée au lecteur sans aucune mention

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le fichier Android porte la note « FR et EN originales (Claude, 04/11/2026)… relecture humaine souhaitable ». Aucun écran ne l'affiche : le Kotlin ne lit pas le champ « traduction » et le fichier web n'en contient pas. Le lecteur francophone ou anglophone reçoit donc comme fiable un texte où l'on trouve au moins un enseignement inversé (90/3) et une consigne de ségoula faussée (107/93). Le statut non relu est une limite assumée dans tools/traductions_textes.py ; ce qui n'est pas documenté, c'est l'absence d'avertissement au lecteur.

**Preuve.** android/app/src/main/res/raw/livre_sefer_hamidot.json textes[0].traduction = « FR et EN originales (Claude, 04/11/2026), relues automatiquement (clés, balises) ; relecture humaine souhaitable. » ; aucune lecture de ce champ dans android/app/src/main/java/com/myhitbodedut/*.kt ; myhitbodedut-web/data/livres/sefer_hamidot.json ne contient que les clés « id » et « sections » ; strings.xml n'a aucune chaîne qui signale une traduction automatique.

**Correction proposée.** Afficher sous le titre du livre, en FR et en EN : « Traduction française produite par IA, non relue ; l'hébreu fait foi. » / « English translation produced by AI, not yet reviewed; the Hebrew is authoritative. » Puis faire relire en priorité les blocs longs, elliptiques ou porteurs d'une consigne pratique.

### MIDOT-08 — FR — Ajout systématique « remède éprouvé » pour סגולה / מסוגל (10 blocs)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Dans le dernier lot (sections 88 à 107), la ségoula est rendue par « remède éprouvé » : le texte affirme alors une efficacité vérifiée que l'hébreu n'énonce pas (סגולה = propriété, vertu). L'anglais garde « segulah » partout, et le titre de la section 72 dit « Remède spirituel ». C'est un ajout qui change la portée du texte, et il rompt la cohérence avec les 77 occurrences de « ségoula ».

**Preuve.** Balayage : 10 blocs — [88/9], [91/1], [93/15], [94/2], [94/3], [98/2], [101/2], [103/2], [105/58], [107/91]. Ex. [94/2] HE « קדוש החדש מסגל לרפאות חלושי הראות » → FR « …est un remède éprouvé pour guérir ceux qui ont la vue faible » ; [98/2] HE « אמירת הלל וצדקה מסגלין לחן בעיני השר » → FR « …sont un remède éprouvé pour trouver grâce aux yeux du ministre » ; [93/15] HE « סגלה להסיר העצבות » → FR « Remède éprouvé pour écarter la tristesse : la miséricorde » ; [107/91] HE « אמירת תהלים סגלה להוריד גשמים » → FR « …est un remède éprouvé pour faire descendre la pluie ».

**Correction proposée.** Remplacer par script « remède éprouvé » par « ségoula » : 94/2 « …est une ségoula pour guérir ceux qui ont la vue faible » ; 98/2 « …sont une ségoula pour trouver grâce aux yeux du dignitaire » ; 93/15 « Une ségoula pour écarter la tristesse : la compassion » ; 107/91 « La récitation des Tehilim est une ségoula pour faire descendre la pluie… ».

### MIDOT-09 — FR+EN — Titres des 108 sections : trois formats différents, divergences FR/EN, quelques faux sens

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les titres ont visiblement été traduits en trois lots. Les sections 0 à 43 suivent le modèle « Translittération – L'article + nom », les sections 44 à 85 omettent l'article, et 22 sections (58, 62, 86 à 107) n'ont aucune translittération (« Malédiction », « Jalousie », « Prière »). D'autres irrégularités s'y ajoutent : « Klipa – écorce » en minuscule, « Émission nocturne – keri » dans l'ordre inverse, et en EN 10 titres en Title Case (« Lashon Hara – Evil Speech ») contre « Emet – Truth » ailleurs. Divergences FR/EN : 22 « L'isolement » / « Secluded prayer » (la section contient « השיחה שאדם משיח בינו לבין קונו », c'est-à-dire la prière), 56 « Massor » / « Moser ». Faux sens ou ambiguïtés : 39 « Les innovations dans la Torah » (lu comme une modification de la Torah ; le corps du texte dit aussi « 'hidouchim de Torah ») ; 98 « Ministres » pour שרים (les dignitaires ; ailleurs « notables », « princes ») ; 61 « Adultère » (voir le constat ניאוף).

**Preuve.** livre_sefer_hamidot.json, sections[*].titre_fr / titre_en — classement par script : FR « translit. – article+nom » 44 (0-43), « sans article » 40 (44-85), « sans translit. » 22, « minuscule » 2 (88, 90) ; ex. [22] « Hitbodedout – L'isolement » / « Hitbodedut – Secluded prayer » ; [39] « 'Hidouchin de-Oraïta – Les innovations dans la Torah » ; [98] « Ministres » / « Officials » ; [88] « Klipa – écorce » ; [90] « Émission nocturne – keri ».

**Correction proposée.** Un seul modèle : FR « Translittération – L'article + nom », EN « Transliteration – Noun ». Exemples : 22 FR « Hitbodedout – L'isolement et la prière solitaire » / EN « Hitbodedut – Seclusion and private prayer » ; 39 FR « 'Hidouchin de-Oraïta – Les 'hidouchim (interprétations nouvelles) de la Torah » ; 56 EN « Masor – The informer » ; 61 FR « Nioufe – L'immoralité sexuelle » / EN « Ni'uf – Sexual immorality » ; 88 FR « Klipa – L'écorce » ; 90 FR « Keri – L'émission nocturne » / EN « Keri – Nocturnal emission » ; 98 FR « Sarim – Les dignitaires » / EN « Sarim – Officials » ; 107 FR « Tefila – La prière » / EN « Tefillah – Prayer ».

### MIDOT-10 — FR+EN — 53 intercalaires « חלק שני » jamais traduits, affichés en hébreu dans les modes français et anglais

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les 53 blocs « c » qui ouvrent la seconde partie de chaque section ne contiennent que l'hébreu. Android et le web les affichent tels quels, quelle que soit la langue de lecture. Le lecteur FR ou EN voit un mot hébreu, puis la numérotation repartir à 1 sans explication. Le choix de « חלק שני » est documenté dans tools/livres_construction.py, mais pas l'absence de traduction.

**Preuve.** livre_sefer_hamidot.json : 53 blocs {"c": "חלק שני"} sans fr/en (ex. sections[0].blocs[51], sections[86].blocs[209]) ; android/.../SiddurLectureActivity.kt l. 505-509 : une consigne affiche l'hébreu, avec « textes = emptyList() » ; web/src/js/app.js l. 1400 : paragraphe « consigne » en lang he à partir de b.c.

**Correction proposée.** Ajouter c_fr « Deuxième partie » et c_en « Part Two » (par script sur les 53 blocs) et afficher la consigne dans la langue de lecture, comme pour les blocs « t ».

### MIDOT-11 — FR+EN — Un même hébreu traduit différemment d'une section à l'autre, termes clés non harmonisés

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le Sefer haMidot répète beaucoup d'aphorismes : 121 groupes d'hébreu identique couvrent 253 blocs. Chaque occurrence a été traduite à part ; 17 groupes divergent fortement en FR et 18 en EN, dont certains sur le fond (voir 72/9 et 8/132). Les termes clés manquent aussi d'harmonie : תלמיד חכם donne « érudit » (35) mais « disciple des sages » dans les 8 cas de la section 86, et « talmid 'hakham » (1) ; חס ושלום donne « Dieu préserve » (13) ou « à Dieu ne plaise » (16) ; התבודדות donne « isolement » dans sa propre section mais « hitbodedout » en 44/2 et 48/34 ; מרקוליס donne « Mercure (l'idole) » en 50/42 et « Markolis (une idole) » en 86/13. En EN, on trouve « Tehillim » (72/3) et « Tehilim » (107/91), et « Al haSheminis », prononciation ashkénaze isolée (53/36). En revanche, Hachem/Hashem (106), Tsadik/tzaddik (283), Chekhina/Shechinah (16), Machia'h/Mashiach (25) et Saint béni soit-Il / Holy One (178) sont constants.

**Preuve.** Balayage (balayage5.py, balayage4.py) : [39/7] FR « Les innovations dans la Torah et la tsedaka » vs [85/79] (même hébreu « החדושין דאוריתא והצדקה ») FR « Les 'hidouchim de Torah et la tsedaka » ; [74/41] FR « par la compassion » vs [93/15] (même hébreu) « la miséricorde » ; [50/42] « Mercure (l'idole) » vs [86/13] « Markolis (une idole) » ; [22/1] HE « עלידי התבודדות » → « Par l'isolement » vs [48/34] HE « התבודדות שאינו כראוי » → « une hitbodedout qui n'est pas comme il convient » ; [53/36] EN « Al haSheminis ».

**Correction proposée.** Établir un glossaire et l'appliquer par script : תלמיד חכם = « érudit (talmid 'hakham) » / « Torah scholar » ; חס ושלום = « à Dieu ne plaise » / « God forbid » ; התבודדות = « hitbodedout (isolement) » / « hitbodedut (seclusion) » ; מרקוליס = « Markolis (Mercure, une idole) » ; EN « Al haSheminit », « Tehillim ». Pour les 121 groupes de doublons, choisir la meilleure traduction et la recopier dans toutes les occurrences.

### MIDOT-12 — FR+EN — מגורותיהם rendu « leurs fourreaux / their sheaths » en 72/9, mais « leurs demeures / their dwellings » dans le doublon 9/25

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Dans le signe de la ségoula de la maison neuve (Béréchit 49:5), l'hébreu glose מכרותיהם par « חרבותיהם, מגורותיהם » : leurs épées, ou bien leurs lieux de séjour, selon la seconde explication de Rachi (« בארץ מגורתם »). La section 9 traduit correctement par « demeures », la section 72 par « fourreaux », sens que מגורות n'a pas.

**Preuve.** livre_sefer_hamidot.json — [72/9] HE « כ'לי ח'מס מ'כרותיהם; חרבותיהם מגורותיהם » → FR « (מכרותיהם signifie) leurs épées, leurs fourreaux » / EN « their swords, their sheaths » ; [9/25] même hébreu → FR « leurs épées, leurs demeures » / EN « their swords, their dwellings ».

**Correction proposée.** 72/9 FR « …(מכרותיהם signifie) leurs épées ; ou : leurs lieux de séjour. » EN « …(מכרותיהם meaning) their swords; or: their dwelling places. »

### MIDOT-13 — EN — « segulah for pride / for fear » : le lecteur comprend un moyen d'obtenir l'orgueil ou la peur (le FR dit « contre »)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** L'hébreu « סגלה ל + défaut » signifie une ségoula contre ce défaut. Le FR traduit « contre » ; l'EN calque « for », ce qui fait comprendre l'inverse, et les deux langues divergent. Même écart de lecture en 23/17 : le même mot ניאוף y donne « débauche » en FR et « adultery » en EN.

**Preuve.** livre_sefer_hamidot.json — [16/17] HE « סגלה לגאוה – שיסתכל על השמים » → FR « Une ségoula contre l'orgueil » / EN « A segulah for pride is to gaze at the heavens » ; [81/27] HE « אור הנר סגלה לפחד » → FR « une ségoula contre la peur » / EN « Candlelight is a segulah for fear ».

**Correction proposée.** EN 16/17 « 18. A segulah against pride: to gaze at the heavens. » ; 81/27 « 28. Candlelight is a segulah against fear. »

### MIDOT-14 — FR+EN — Faux sens et calques ponctuels (« renouvelé », « estrade », « fille d'un dieu étranger »)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Trois défauts ponctuels qu'un relecteur corrigerait. 71/3 : נתחדש (le livre « est venu au jour ») devient en FR « a été renouvelé », alors que l'EN dit bien « originated ». 8/62 : לפני העמוד, le pupitre de l'officiant, devient en FR « devant l'estrade », qui désigne la bima ; l'EN dit « prayer stand ». 23/82, 61/0 et 63/18 : בת אל נכר est calqué sans glose en « la fille d'un dieu étranger » / « the daughter of a foreign god », et le lecteur ne comprend pas qu'il s'agit d'une femme non juive (Malakhi 2:11).

**Preuve.** livre_sefer_hamidot.json — [71/3] HE « הבכיה שעלידו נתחדש זה הספר » → FR « les pleurs par lesquels ce livre a été renouvelé » ; [8/62] HE « התפלה שמתפללין לפני העמוד בנגינה » → FR « la prière que l'on dit devant l'estrade avec mélodie » ; [61/0] HE « מי שמהרהר בבת אל נכר » → FR « Celui qui a des pensées au sujet de la fille d'un dieu étranger » / EN « about the daughter of a foreign god » (de même [23/82], [63/18]).

**Correction proposée.** 71/3 FR « …les pleurs par lesquels ce livre est venu au jour… » ; 8/62 FR « …la prière que l'officiant dit devant l'amoud avec mélodie… » ; 61/0 FR « 1. Celui qui a des pensées au sujet d'une femme non juive (« fille d'un dieu étranger », Malakhi 2:11), par cela ses enfants ne seront pas des hommes d'étude. » EN « 1. One who has thoughts about a gentile woman (“the daughter of a foreign god,” Malachi 2:11)… » ; même glose en 23/82 et 63/18.

### MIDOT-15 — FR+EN — Nom divin rendu « Hachem / Hashem » dans des versets cités, contre la règle « l'Éternel / the LORD »

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** L'en-tête de tools/traductions_textes.py pose que les versets cités suivent les éditions du domaine public (l'Éternel / the LORD), règle appliquée dans 8 blocs FR et 6 blocs EN. Quelques versets gardent pourtant « Hachem/Hashem ». Or Tehilim 68:20 porte אֲדֹנָי, pas le Tétragramme : le Rabbinat traduit « Béni soit le Seigneur ».

**Preuve.** livre_sefer_hamidot.json — [12/21] et [23/63] HE « "ברוך ה' יום יום" » → FR « « Béni soit Hachem, jour après jour » (Tehilim 68:20) » / EN « “Blessed be Hashem day by day” » ; [24/13] HE « מי שה' אלקיו עמו » (Bamidbar 23:21) → FR « Celui avec qui est Hachem son Dieu ».

**Correction proposée.** 12/21 et 23/63 FR « « Béni soit le Seigneur, jour après jour » (Tehilim 68:20) » ; EN « “Blessed be the Lord day by day” (Psalms 68:20) ». 24/13 FR « 14. Celui avec qui est « l'Éternel son Dieu » (Bamidbar 23:21) aura une ascension. » EN « 14. One with whom “the LORD his God is” (Numbers 23:21) will have an ascent. »

### MIDOT-16 — EN — Guillemets anglais mal orientés (8 blocs)

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Dans 7 blocs, un guillemet ouvrant « “ » sert de guillemet fermant après un mot ou une ponctuation ; un huitième bloc a ses guillemets inversés. Le français n'a aucune faute de ce type : guillemets français et espaces fines insécables sont corrects partout.

**Preuve.** livre_sefer_hamidot.json — [50/96] et [53/118] « …when it was morning“; “And in the morning there was a layer of dew“; » ; [50/107] « makes his face shine“) » ; [53/115] « (“eye“) » ; [71/1] « generations of man“; » ; [71/3] « spell “weeping“) » ; [72/9] « (מכרותיהם)“; » ; [94/8] « (er'elam, also read ”I will see them“) ».

**Correction proposée.** Correction par script : remplacer « “ » par « ” » quand il suit une lettre ou une ponctuation et précède un espace, « ; », « , », « ) » ou la fin de chaîne. Pour 94/8 : « (er'elam, also read “I will see them”) ».
