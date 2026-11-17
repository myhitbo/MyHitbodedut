# Audit halakhique de l'app — toute l'année, par noussa'h et par lieu (16/11/2026)

Ce rapport ne modifie rien dans l'app. Chaque point attend une décision avant toute correction.

## Méthode

1. **Deux audits.** Un premier par domaine, un second mois par mois sur toute l'année. Ensemble, ils ont relevé 289 constats.
2. **Dédoublonnage.** Les 289 constats ont été regroupés en 132 groupes.
3. **Vérification adversariale.** Chaque groupe a été contre-vérifié, sous un angle « code-source et portée » et un angle « source halakhique ».
4. **Critique de complétude.** Elle a cherché les domaines oubliés par les deux audits. Les constats qu'elle a trouvés ont été vérifiés un par un.

Les catégories sont les suivantes :

- **Erreur de l'app** : l'app contredit la source de son propre rite.
- **Divergence entre rites** : l'app applique la règle d'un autre rite.
- **Divergence entre poskim** : l'app suit un avis défendable, mais pas celui de la source de référence.
- **Non vérifiable** : la source n'a pas pu être consultée.

Sources de référence :

- **Edot** : Yalkut Yosef (Kitsour).
- **Ashkenaz** : Michna Beroura et Rema.
- **Sfard** : consignes du siddour Sfard, Choul'han Aroukh haRav, Piskei Techouvot.

## Totaux

| Thème | Erreur de l'app | Divergence entre rites | Divergence entre poskim | Non vérifiable | Écartés |
|---|---|---|---|---|---|
| Ta'hanoun | 11 | 0 | 10 | 0 | 2 |
| Amida | 8 | 3 | 3 | 0 | 2 |
| Hallel et Moussaf | 8 | 1 | 2 | 0 | 1 |
| Offices | 14 | 2 | 5 | 0 | 1 |
| Bénédictions | 9 | 1 | 9 | 0 | 2 |
| Calendrier | 6 | 5 | 8 | 0 | 3 |
| Zmanim | 2 | 5 | 6 | 0 | 2 |
| Autres | 0 | 0 | 1 | 0 | 0 |
| Compléments (domaines oubliés) | 25 | 7 | 22 | 1 | 12 |
| **Total** | **83** | **24** | **66** | **1** | **25** |

« Min'ha Sfard : fin de l'office repliée » figure à la fois dans Ta'hanoun et dans les Compléments. C'est le même constat.

### Erreurs de gravité haute

- Min'ha Sfard : le Kaddich, Alénou et la fin de l'office sont repliés les jours sans Ta'hanoun.
- Min'ha Edot : le Kaddich, le psaume final et le psaume du vendredi sont repliés les jours sans Ta'hanoun.
- Amida Edot : la conclusion « העונה לעמו ישראל בעת צרה » s'affiche en clair tous les jours.
- Havdala de Tich'a beAv au motsaé Chabbat : elle s'affiche complète.
- Vendredi de fête : l'allumage de Chabbat est placé après la sortie des étoiles.
- Israël ou diaspora : le statut suit la position du téléphone, et non la résidence du voyageur.
- Bougies de Chabbat (Edot) : la consigne fait bénir après l'allumage.
- Birkat haRoé sur la mer (Edot) : la bénédiction est complète, alors que le Yalkut Yosef l'exclut.

---

## Ta'hanoun et ce qui en dépend

### Min'ha Sfard : le Kaddich, Alénou et la fin de l'office sont repliés les jours sans Ta'hanoun
**Erreur de l'app** · gravité haute · Sfard · tous lieux

- **Ce que fait l'app** : `tools/siddur_annotations.py:152-153` met toute la section « תחנון » de Min'ha Sfard (37 blocs) sous `tahanoun_minha`, et `SiddurJour.kt` (`lignes()`, l. 132-143) comme `web/src/js/app.js:1453` (`corpsDe`) la replient d'un bloc. Le Kaddich complet (2.17-2.23), עלינו (2.24-2.26), le Kaddich yatom (2.27-2.31) et לדוד ה׳ אורי (2.32-2.34) passent donc « pas aujourd'hui » chaque vendredi (2025-11-14), chaque Chabbat (2026-11-21), à Roch 'Hodech (2026-08-14), à 'Hanouka (2026-12-10), en Nissan (2027-04-12) et à Pourim à Jérusalem (2027-03-24). Le jeûne d'Esther (2026-03-02), Avinou malkénou s'affiche après un עלינו replié.
- **Ce que dit la source** : Alénou et le Kaddich yatom suivent chacun des trois offices, sans lien avec le Ta'hanoun. *Michna Beroura 132:7 ; Rema, Choul'han Aroukh O.H. 132:2 ; consigne du siddour Sfard de l'app, Cha'harit S19 b0.* « מ"א כתב בשם האר"י שיאמרוהו אחר כל הג' תפלות » ; « ואומרים אחר סיום התפלה עלינו לשבח מעומד ... ואומרים קדיש יתום אחר עלינו ».
- **Correction proposée** : supprimer l'annotation de section. Mettre `tahanoun_minha` sur les blocs 2.0 à 2.16 seulement (du Vidouï à ואנחנו לא נדע). Mettre les Kaddichim (2.17-2.23, 2.27-2.31) sous `minyan` et laisser עלינו (2.24-2.26) en clair. Mettre לדוד ה׳ אורי (2.32-2.34) sous `ledavid`, comme à Cha'harit, en gardant visible la consigne 2.32 (« מנהג טוב לומר אחר כל תפלה ») : `ledavid` reste plus restrictif que le siddour. Le psaume 49 (2.35-2.36) relève de `beit_avel` ET de `tahanoun_minha`, et pas de `beit_avel` seul, car sa consigne dit « ואחר מנחה בימים שיש בהם תחנון ». Ajouter à `SimulationSiddurTest` une règle qui exige עלינו en clair à toute Min'ha de semaine.

### Min'ha Edot : le Kaddich, le psaume final et le psaume du vendredi sont repliés les jours sans Ta'hanoun
**Erreur de l'app** · gravité haute · Edot · tous lieux

- **Ce que fait l'app** : la même règle (`tools/siddur_annotations.py:152-153`) met toute la section « וידוי » de Min'ha Edot (23 blocs) sous `tahanoun_minha`. Le Kaddich titkabal (2.9-2.13), le Ps 67 (2.14-2.15), le Ps 93 du vendredi (2.16-2.17), le Ps 102 des jeûnes (2.18-2.19) et le Kaddich יהא שלמא (2.20-2.22) sont donc repliés tous les jours sans Ta'hanoun : chaque vendredi (2025-11-14, 2026-11-20), à Roch 'Hodech (2026-08-14), à 'Hol hamoed (2026-10-01) et le 9 Av (2026-07-23). Le Ps 93 n'est donc jamais en clair le jour où il se dit. À l'inverse, le mardi 2026-11-17, les Ps 93 et 102 s'affichent comme du jour.
- **Ce que dit la source** : le siddour Edot rattache ces psaumes au jour, et le Yalkout Yossef exclut le Vidouï le vendredi. *Consigne du siddour Edot de l'app, Min'ha S2 b16 ; Kitsour Yalkout Yossef 267:1.* « בערב שבת אומרים מזמור ''יהוה מלך'' במקום ''למנצח'' » ; « בתפלת המנחה בערב שבת אין אומרים וידוי, ואין נופלים על פניהם ».
- **Correction proposée** : réduire `tahanoun_minha` aux blocs 2.0 à 2.8. Laisser les Kaddichim 2.9-2.13 et 2.20-2.22 en clair, ou les mettre sous `minyan`. Mettre 2.14-2.15 sous `!jour_6` (en gardant visible la variante de 'Hol hamoed), 2.16-2.17 sous `jour_6` et 2.18-2.19 sous `jeune`, 9 Av compris. Il faut élargir le motif `CONSIGNES_COURTES` « בתענית ציבור:? », qui ne reconnaît pas « בתענית ציבור אומרים ». La consigne 1.105 (« ואחר כך אומר הש''צ חצי קדיש ») annonce un Kaddich que la section 2 ne montre pas. Pour le Ps 102 à Min'ha du jeûne d'Esther et du 9 Av, la règle ne repose que sur la consigne générale du siddour.

### Cha'harit Sfard : שומר ישראל et le demi-Kaddich ne s'affichent que le lundi et le jeudi
**Erreur de l'app** · gravité moyenne · Sfard · tous lieux

- **Ce que fait l'app** : `tools/siddur_annotations.py:154-155` met toute la section 11 « לשני וחמישי » sous `lundi_jeudi`. Le mardi 2025-11-18 (et le 2026-11-17), jour de Ta'hanoun, שומר ישראל, מתרצה et ואנחנו לא נדע (11.20-11.24), le demi-Kaddich (11.25-11.29) et la consigne d'אשרי (11.30) sont repliés. Il en va de même chaque dimanche, mardi, mercredi et vendredi où l'on dit Ta'hanoun. Les jours sans Ta'hanoun (par exemple le 2027-04-15), le demi-Kaddich n'est en clair nulle part, et sa consigne 9.0 est repliée elle aussi avec la section 9.
- **Ce que dit la source** : seul le long והוא רחום est réservé au lundi et au jeudi, et le demi-Kaddich se dit tous les jours. *Siddour Sfard de l'app, Cha'harit, consignes 11.0 et 9.0 ; Rema O.H. 131:1.* « בשני וחמישי יאמר והוא רחום. בשאר ימים שאומרים בהם תחנון יאמר שומר ישראל. » ; « בימים שאין אומרים בהם תחנון יאמר הש״ץ חצי קדיש ».
- **Correction proposée** : supprimer l'annotation de section et annoter bloc par bloc, comme en Ashkenaz :
  - 11.0 sous `tahanoun_chaharit` ;
  - 11.1-11.19 sous `lundi_jeudi`, en coupant juste avant שומר ישראל (b20) et non au premier « יהוה אלהי ישראל » (b9) ;
  - 11.20-11.24 sous `tahanoun_chaharit` ;
  - 11.25-11.29 sous `minyan`, sans condition de jour ;
  - 11.30 en clair.

  Il faut aussi sortir la dernière phrase de 9.0 du repli de la section 9, ou ajouter un renvoi vers 11.25. Les dates de fin de Tichri dépendent du réglage `sansTahanounFinTichri`.

### Cha'harit Edot : les supplications propres au lundi et au jeudi sont présentées comme du jour tous les jours de Ta'hanoun
**Erreur de l'app** · gravité moyenne · Edot · tous lieux

- **Ce que fait l'app** : la section 10 « וידוי » ne porte que `tahanoun_chaharit` (`tools/siddur_annotations.py:152`), et aucun bloc Edot ne porte `lundi_jeudi`. Le mardi 2025-11-18 (et le 2026-11-17), les blocs 10.12 à 10.31 (« בימי שני וחמישי מוסיפים: », אל מלך, מה נאמר, והוא רחום…) s'affichent comme du jour. Le lundi, le Kaddich 10.11, que l'on ne dit pas ce jour-là, reste affiché. Les jours sans Ta'hanoun, le demi-Kaddich est replié avec la section.
- **Ce que dit la source** : ces supplications ne se disent que le lundi et le jeudi. *Kitsour Yalkout Yossef 134:1 et 134:3 ; consigne du siddour Edot, Cha'harit S10 b10.* « נהגו להרבות בתחנונים בשני וחמישי, מפני שהם ימי רצון, ואומרים והוא רחום » ; « בימים שני וחמישי אין אומרים את הקדיש הזה וממשיכים באל מלך ».
- **Correction proposée** : ajouter des annotations de bloc ne suffit pas. Le script fait `continue` au niveau de la section, et les deux moteurs ignorent les blocs d'une section annotée. Il faut donc retirer l'annotation de section et annoter comme pour קריאת התורה :
  - 10.0-10.9 sous `tahanoun_chaharit` ;
  - 10.10-10.11 sous `!lundi_jeudi`, hors de la racine ;
  - 10.12-10.32 sous `lundi_jeudi`.

  Les demi-Kaddichim restent en clair, ou sous `minyan`, les jours sans Ta'hanoun, puisque יהי שם (9.105-9.106) y renvoie. Un vérificateur propose de baisser la gravité à basse, parce que les consignes restent visibles.

### למנצח est proposé pendant 'Hol hamoed en Sfard et en Ashkenaz
**Erreur de l'app** · gravité moyenne · Sfard et Ashkenaz · tous lieux

- **Ce que fait l'app** : `web/src/js/calendrier-juif.js:137-138` et `CalendrierJuif.kt:313-314` n'excluent `lamnatseah` qu'à Roch 'Hodech, à 'Hanouka, les 14-15 Adar, au festin de Jérusalem, le 9 Av, les jours chômés, la veille de Pessa'h et la veille de Kippour. À 'Hol hamoed et à Hochaana Rabba, למנצח (Ashkenaz 6.1-6.2, Sfard 13.1-13.3) et, en Sfard, בית יעקב (14.2) restent donc en clair : 2025-10-09, 2025-10-13 (Hochaana Rabba), 2026-04-05, 2026-04-06, et dès le 16 Tichri en Israël (2025-10-08). Entre 2025 et 2030, cela fait 41 jours en diaspora et 53 en Israël, ou 47 et 59 avec Hochaana Rabba. Edot n'est pas touché.
- **Ce que dit la source** : le siddour Sfard de l'app exclut lui-même למנצח à 'Hol hamoed, et le Ma'hzor Vitry fait de même pour l'Ashkenaz. *Siddour Sfard de l'app, texte « hallel », S0 b27 ; Ma'hzor Vitry, lois des quatre espèces 382:2 ; Rema O.H. 429:2 avec Pri Megadim, Échel Avraham 429:7.* « בראש חודש וביום טוב ובחול המועד ... אשרי ובא לציון ואין אומרים למנצח » ; « ואין מנהג בחול המועד לומ' למנצח. לפי שכת' בו יענך י"י ביום צרה ».
- **Correction proposée** : ajouter `regles.isCholHamoed()`, Hochaana Rabba comprise, aux exclusions de `lamnatseah` dans les deux fichiers, pour Soukkot comme pour Pessa'h. En Sfard, cela replie aussi בית יעקב, comme le veut la consigne 14.0. Ajouter un test (`repli.test.mjs` / `SimulationSiddurTest`) qui vérifie `!lamnatseah` les 2025-10-09, 2025-10-13 et 2026-04-06. La liste du Michna Beroura 131:35 ne nomme pas 'Hol hamoed, mais ce silence ne vaut pas prescription.

### אל ארך אפים est estompé le lundi et le jeudi sans Ta'hanoun alors que למנצח est affiché
**Erreur de l'app** · gravité moyenne · Sfard et Ashkenaz · tous lieux

- **Ce que fait l'app** : `tools/siddur_annotations.py:167` rattache la consigne « אין אומרים אא״א… » et le texte (Ashkenaz Cha'harit 5.0-5.1, Sfard 12.0-12.1) à `tahanoun_chaharit`, alors que למנצח suit `lamnatseah`. Les lundis et jeudis de lecture sans Ta'hanoun, אל ארך אפים s'affiche estompé, hors du jour (`app.js:1463`, `SiddurJour.kt:187`), tandis que למנצח est en clair. Exemples : 2026-02-02 (Tou Bichvat), 2025-09-22 (veille de Roch Hachana), 2026-03-23 (Nissan), 2025-05-12 (Pessa'h Chéni), 2026-05-18 (2 Sivan), 2029-05-03 (Lag baOmer), et l'Isrou 'hag 2025-10-16 en diaspora. Cela fait environ 69 à 71 jours entre 2025 et 2029.
- **Ce que dit la source** : אל ארך אפים et למנצח suivent la même règle. *Michna Beroura 131:35 ; consigne du siddour Sfard de l'app, Cha'harit S13 b1 ; Choul'han Aroukh haRav 429:12.* « עוד כתבו דאל ארך אפים ולמנצח דינם שוה » ; « דכללא הוא דאא״א ולמנצח דינם שוה ».
- **Correction proposée** : en Ashkenaz et en Sfard, annoter 5.0-5.1 et 12.0-12.1 avec « `lamnatseah` ∧ ¬`moed` », ou avec « `tahanoun_chaharit` ∨ (`lamnatseah` ∧ ¬`moed`) », dans le groupe `kriat_hatorah`. Ne pas utiliser `lundi_jeudi`, qui est faux les jours sans Ta'hanoun, le 10 Tévet un mardi (2025-12-30) et le 17 Tamouz un dimanche (2025-07-13). L'usage « ויש נוהגים » peut devenir un réglage. En Sfard, cela règle aussi l'incohérence avec בית יעקב (14.2, sous `lamnatseah`), que la consigne 14.0 lie à אא״א. Rien à changer en Edot.

### Jeûne d'Esther (13 Adar) : Avinou malkénou affiché à Min'ha la veille de Pourim
**Erreur de l'app** · gravité moyenne · Sfard et Ashkenaz · tous lieux

- **Ce que fait l'app** : `SiddurJour.kt:234-238` et `siddur-jour.js:42-46` ajoutent `avinou_malkenou_minha` à tout jeûne qui ne tombe pas un vendredi. Le 13 Adar, `tahanoun_minha` est faux, mais l'Avinou malkénou de Min'ha (Sfard S3, Ashkenaz S2) reste en clair : 2025-03-13, 2026-03-02, 2027-03-22, 2029-02-28 et 2030-03-18. Le jeûne avancé au jeudi (2028-03-09) est traité correctement.
- **Ce que dit la source** : la veille de Pourim, on ne dit à Min'ha ni Ta'hanoun ni Avinou malkénou. *Ohalei Halakha, Pourim, ch. 2, note 11 (renvoi au Michna Beroura 131:33 et au Louah haHalakhot vehaMinhaguim 5777, p. 163).* « אך אין אומרים תחנון ו"אבינו מלכנו", כי הארת פורים הולכת ומאירה מחצות היום ». Pour le Sfard, la règle s'étend par analogie, sur la foi de l'usage 'Habad.
- **Correction proposée** : n'ajouter `avinou_malkenou_minha` que si `tahanoun_minha` est vrai, ou pendant les dix jours. Cela couvre le 13 Adar II et ne change rien au jeûne avancé au jeudi.

### Tsom Guedalia : Avinou malkénou montre à la fois les variantes des jeûnes et celles des dix jours
**Erreur de l'app** · gravité moyenne · Sfard et Ashkenaz · tous lieux

- **Ce que fait l'app** : `tools/siddur_annotations.py:459-479` annote les variantes avec `jeune` et `asseret_yemei_techouva`, qui sont vrais tous les deux ce jour-là. Le 2025-09-25 (comme le 2026-09-14 et le 2024-10-06), l'Ashkenaz affiche du jour à la fois 4.13 « חדש עלינו » et 4.14 « ברך עלינו », ainsi que כתבנו (4.29-4.34) et זכרנו (4.35-4.40). Il en va de même en Sfard (10.4-10.7, 10.22-10.33) et à Min'ha.
- **Ce que dit la source** : à Tsom Guedalia, on ne dit que la série des dix jours. *Matté Efraïm 602:13 (Ashkenaz) ; Machon Halakha 'Habad (Sfard).* « ב"אבינו מלכנו" אומרים "חדש עלינו" » ; « ואף בצום גדליה אומרים נוסח זה ולא את הנוסח 'זכרנו' של ימי התענית ».
- **Correction proposée** : créer une clé dérivée, par exemple `avinou_malkenou_jeune` = `jeune` && !`asseret_yemei_techouva`, et l'employer seulement pour les sous-variantes « בתענית ציבור » d'Avinou malkénou dans `tools/siddur_annotations.py`. L'ajouter à `SOUS`, à `conditionsPour` et à `DERIVEES`, en JS comme en Kotlin. Ne pas toucher à `jeune`, qui sert à עננו et à la bénédiction des Cohanim de Min'ha. Ajouter un test au 3 Tichri.

### Ta'hanoun à Min'ha de la veille de Pessa'h Chéni chez les Edot
**Différence entre poskim** · gravité moyenne · Edot · tous lieux

- **Ce que fait l'app** : l'exception `PESACH_SHENI` de `web/src/js/tefila.js:77` (KosherJava) rend `tahanoun_minha` vrai le 13 Iyar, et la section « וידוי » de Min'ha Edot s'ouvre : 2025-05-11, 2026-04-30, 2027-05-20, 2028-05-09, 2030-05-16.
- **Ce que dit la source** : la règle générale exclut le Vidouï à la Min'ha qui précède un jour sans Ta'hanoun. Le Yalkout Yossef tranche qu'on ne le dit pas le 13 Iyar, tandis que la Halakha Beroura le faisait dire (son auteur s'est ensuite rétracté). *Kitsour Yalkout Yossef 131:38 ; Yalkout Yossef, Sefirat haOmer, p. 536 (cité de seconde main).* « [ולענין ערב פסח שני ראה בהערה ז'] » ; « אין צריך לומר וידוי ונפילת אפיים במנחה של י"ג אייר ».
- **Correction proposée** : pour Edot, retirer `tahanoun_minha` quand le lendemain est le 14 Iyar, ou en faire un choix, avec la mention « Halakha Beroura : on le dit ». Un vérificateur classerait ce point en erreur de l'app, puisque le Yalkout Yossef tranche. Rien à changer en Sfard ni en Ashkenaz.

### Veille de Kippour : le Vidouï de Min'ha est replié et aucun על חטא n'est proposé
**Différence entre poskim** · gravité moyenne · tous · tous lieux

- **Ce que fait l'app** : le 9 Tichri (2025-10-01, 2026-09-20, 2024-10-11), `tahanoun_minha` est faux, et la section de semaine est repliée, à juste titre puisqu'elle contient le Ta'hanoun : « וידוי » en Edot, « תחנון » en Sfard. Aucun des trois siddourim ne contient על חטא, et l'app ne mentionne nulle part ce Vidouï : la halakha du jour cite le Yalkout Yossef 606, pas le 607. Les faits sont confirmés, mais l'app reste défendable : le Ma'hzor de Kippour est un manque que `FEUILLE_DE_ROUTE.md` déclare déjà.
- **Ce que dit la source** : chacun dit le Vidouï après son Amida, avec על חטא comme à Kippour. *Choul'han Aroukh O.H. 607:1 (Rema) ; Kitsour Yalkout Yossef 607:1.* « צריך להתודות במנחה קודם סעודה המפסקת: הגה ויחיד אומרו אחר שגמר תפלתו » ; « ואח״כ יאמר וידוי ו״על חטא״, כמו ביום הכפורים ».
- **Correction proposée** : ne pas rouvrir la section de semaine. Le 9 Tichri, afficher plutôt, avec une condition `erev_kippour` (la fête `erev_yom_kippour` existe déjà), un libellé « Aujourd'hui · Vidouï et על חטא après l'Amida (ma'hzor, absent de l'app) ». En Edot, on peut y ajouter que l'officiant dit Avinou malkénou après la répétition (Yalkout Yossef 607:3). Le constat affirme que « l'Avinou malkénou de Min'ha s'ouvre en Edot » : c'est faux, et la phrase est à retirer.

### Sfard : liste courte des jours sans למנצח, alors que l'usage est partagé
**Différence entre poskim** · gravité basse · Sfard · tous lieux

- **Ce que fait l'app** : la condition `lamnatseah` (`web/src/js/calendrier-juif.js:138`) suit la liste courte de la consigne 13.1 du siddour Sfard, tirée du Derekh ha'Hayim. למנצח est donc ouvert en Nissan (2026-04-13), à Lag baOmer (2026-05-05), à Isrou 'hag (2026-10-05), le 4 Sivan (2026-05-20) et à Tou beAv (2026-07-29). Le cas de 'Hol hamoed est traité dans le constat sur למנצח pendant 'Hol hamoed.
- **Ce que dit la source** : l'usage de l'Admour Hazaken, comme celui du siddour Metsudah, omet le psaume tous les jours sans Ta'hanoun. La consigne du siddour de l'app ne l'omet que les jours de sa liste. *Siddour de l'Admour Hazaken ; siddour Sfard de l'app, Cha'harit S13 b1.* « מנהג ספרד שבכל יום שאין בו תחנון ונפילת אפים אין אומרים למנצח יענך ולא תפלה לדוד » ; « אלו ימים שאין אומרים בהם למנצח ואל ארך אפים. ר״ח חנוכה ופורים ערב פסח וערב יו״כ ותשעה באב ».
- **Correction proposée** : en Sfard, proposer un réglage « למנצח : liste du Derekh ha'Hayim / jours sans Ta'hanoun », sur le modèle de `sansTahanounFinTichri`.

### Ashkenaz : le passage ה׳ אלהי ישראל du lundi et du jeudi est affiché tous les jours de Ta'hanoun
**Erreur de l'app** · gravité basse · Ashkenaz · tous lieux

- **Ce que fait l'app** : la boucle `for k in range(dd, kd)` de `tools/siddur_annotations.py:229-231` met sous `tahanoun_chaharit` tout ce qui va de ויאמר דוד au Kaddich. Le mardi 2025-11-18, les blocs 4.73 à 4.83 (ה׳ אלהי ישראל, הבט משמים, זרים אומרים, חוסה, קולנו, עזרנו) s'affichent donc comme du jour. Le siddour Sfard de l'app range ce même passage sous `lundi_jeudi`.
- **Ce que dit la source** : ce piyout accompagne והוא רחום le lundi et le jeudi. *Aroukh haChoul'han O.H. 134:1-2 ; Wikisource, Siddour Ashkenaz, סדר תחנון.* « ולאחר "והוא רחום" אומרים תחנון ו"ה' אלהי ישראל שוב…", "הבט…", "זרים…" » ; « פיוט לשחרית של שני וחמישי ».
- **Correction proposée** : annoter `lundi_jeudi` sur les blocs 4.73 à 4.83 seulement, du premier « יהוה אלהי ישראל שוב » au bloc qui précède שומר ישראל. Laisser le Ps 6 (4.72) et les blocs 4.84 à 4.88 (שומר ישראל … ואנחנו לא נדע) sous `tahanoun_chaharit`. Retirer le renvoi à l'Encyclopédie Daat, qui n'a pas été lue.

### Ashkenaz : le Vidouï et les treize attributs mis en évidence chaque jour de Ta'hanoun
**Différence entre poskim** · gravité basse · Ashkenaz · tous lieux

- **Ce que fait l'app** : les blocs 4.0 à 4.8 de Cha'harit (אשמנו, ויעבור, י״ג מדות) sont annotés `tahanoun_chaharit` (`tools/siddur_annotations.py:222-224`). Ils sont donc mis en évidence chaque jour de Ta'hanoun, par exemple le mardi 2025-11-18. L'app suit le Metsudah, qui les imprime sans consigne.
- **Ce que dit la source** : c'est la coutume de certaines communautés, et elle se place avant והוא רחום, le lundi et le jeudi. L'usage d'origine (Rödelheim) ne dit pas de Vidouï du tout, et quelques communautés le disent chaque jour. *Michna Beroura 134:1.* « יש מקומות שנוהגין לומר קודם והוא רחום י"ג מדות של רחמים ווידוי ».
- **Correction proposée** : annoter 4.0 à 4.8 avec `lundi_jeudi` et l'étiquette « selon l'usage », ce qui ne risque rien puisque la condition n'existe que les jours de Ta'hanoun. On peut aussi laisser le texte tel quel et ajouter une note qui présente les trois usages.

### Sfard : Avinou malkénou placé après la chute sur la face et, à Min'ha, après עלינו
**Erreur de l'app** · gravité basse · Sfard · tous lieux

- **Ce que fait l'app** : `siddur_sefard.json` reprend l'ordre des nœuds Sefaria. À Min'ha, la section S3 « אבינו מלכנו » vient après la section S2, qui contient le Kaddich titkabal (b17-b23), עלינו (b24-b26), le Kaddich yatom, לדוד et le psaume du deuil. Le jeûne d'Esther (2026-03-02) et le 10 Tévet (2025-12-30), Avinou malkénou s'affiche donc après Alénou.
- **Ce que dit la source** : tous les rites placent Avinou malkénou avant le Kaddich titkabal : avant la chute sur la face selon le Michna Beroura et le Yalkout Yossef, avant ואנחנו לא נדע chez Habad. *Kitsour Yalkout Yossef 582/602:23 ; Michna Beroura 131:17.* « ורק אחר אבינו מלכנו יאמרו וידוי ונפילת אפים » ; « ובימים שאומרים אבינו מלכנו במנחה יוכל לדלג א"מ כדי ליפול מבעוד יום ».
- **Correction proposée** : à Min'ha, afficher Avinou malkénou avant le bloc 2.17 (« הש״ץ אומר קדיש שלם »), avant ou après ואנחנו לא נדע (2.16) selon l'usage suivi. À Cha'harit, il ne s'agit pas d'une erreur : l'app suit la consigne de son siddour (S10 b0, « אומרים כאן אבינו מלכנו »), qui concorde avec l'usage Habad. Une note suffit. Le Michna Beroura et le Yalkout Yossef ne sont pas des sources du rite Sfard.

### Reprise du Ta'hanoun après Chavouot : jusqu'au 12 Sivan, et 13 Sivan en diaspora
**Différence entre poskim** · gravité basse · Sfard et Ashkenaz · tous lieux

- **Ce que fait l'app** : l'app garde les réglages par défaut de `TefilaRules` (`web/src/js/tefila.js` : `tachanunRecitedWeekAfterShavuos=false`, `tachanunRecited13SivanOutOfIsrael=true`). Il n'y a donc pas de Ta'hanoun du 1er au 12 Sivan, et il est dit le 13 Sivan en diaspora (2026-05-29, 2027-06-18, 2025-06-09). L'app suit l'usage « יש מקומות », et non le texte du Rema ni celui du Choul'han Aroukh haRav, qui arrêtent après Isrou 'hag. Edot est conforme au Yalkout Yossef 494:27.
- **Ce que dit la source** : *Michna Beroura 131:36 ; Rema O.H. 494:3 ; Chaarei Techouva O.H. 131:19.* « ויש מקומות נוהגין שלא ליפול כל הששה ימים שאחר שבועות » ; « ואין אומרים תחנון מתחילת ראש חודש סיון עד ח' בו דהיינו אחר אסרו חג » ; « ויש שאין נופלין גם בי"ג משום ספיקא דיומא ».
- **Correction proposée** : aucune n'est obligatoire. Indiquer dans `ZMANIM.md` que l'app suit la coutume « jusqu'au 12 inclus ». On peut proposer, en diaspora, une option « pas de Ta'hanoun le 13 Sivan » (`tachanunRecited13SivanOutOfIsrael=false`).

### Aucun réglage pour supprimer le Ta'hanoun en cas de deuil, de brit ou de 'hatan
**Erreur de l'app** · gravité basse · tous · tous lieux

- **Ce que fait l'app** : le seul réglage lié au Ta'hanoun est `reglage_tahanoun_tichri` (`app.js:2628`, `Store.kt:625`). `beit_avel` est rangé dans `JAMAIS_DU_JOUR` (`app.js:2030`, `SiddurLectureActivity.kt:440`). Le 2026-11-16, le Ta'hanoun et למנצח restent donc en évidence pour qui prie dans une maison en deuil ou à une brit. Les siddourim Edot et Ashkenaz n'ont aucune consigne sur ces circonstances.
- **Ce que dit la source** : *Choul'han Aroukh O.H. 131:4.* « נהגו שלא ליפול על פניהם לא בבית האבל ולא בבית החתן ולא בב"ה ביום מילה ולא כשיש שם חתן ».
- **Correction proposée** : ajouter un réglage ponctuel « pas de Ta'hanoun aujourd'hui », qui tienne compte du rite et de l'office :
  - pour une mila en Ashkenaz, seulement à Cha'harit, sauf pour les ba'alé brit eux-mêmes (Rema 131:4, Michna Beroura 131:25) ; en Edot, toute la journée (Yalkout Yossef 131:26, 28-29) ;
  - pour le 'hatan, sept jours (Michna Beroura 131:26, Yalkout Yossef 131:20) ;
  - pour la bar mitsva, en Edot seulement (Yalkout Yossef 131:24) ;
  - pour le deuil, retirer aussi `lamnatseah` en Sfard et en Ashkenaz (consigne Sfard 13.1 : « גם אין אומרים אותם בבית האבל »), mais pas pour un 'hatan ni une brit ;
  - garder Avinou malkénou pour une mila (Rema 602:1), pas pour un deuil.

  Préciser aussi que l'assemblée où prie l'endeuillé dit le Ta'hanoun (Michna Beroura 131:20). Un vérificateur range ce point parmi les suggestions, hors du périmètre de l'app.

### Ta'hanoun dit les 19 et 20 Kislev en Sfard
**Différence entre poskim** · gravité basse · Sfard · tous lieux

- **Ce que fait l'app** : l'app suit la liste du siddour Sfard (Min'ha 2.0), qui ne nomme pas ces jours. Elle dit donc Ta'hanoun à Min'ha du 18 Kislev (2025-12-08), les 19 et 20 Kislev (2025-12-09, 2025-12-10, 2026-11-29) et le 20 Kislev 5787 (2026-11-30), où s'ajoute `lundi_jeudi`.
- **Ce que dit la source** : chez Habad, on ne dit pas Ta'hanoun ces jours-là, ni à la Min'ha qui les précède. *Compilation des usages 'Habad de Kislev (chabad.info) ; Wikipédia hébreu « חג הגאולה ».* « בימי הגאולה י"ט-כ' כסלו, וכן בתפלת מנחה ביום י"ח כסלו – אין אומרים תחנון » ; « לא אומרים החסידים תחנון, וגם לא במנחה שלפניו, מפני שמחת היום ».
- **Correction proposée** : en option, ajouter un réglage Sfard « usage 'Habad ». Il couvrirait les 19 et 20 Kislev et la Min'ha du 18, mais aussi le 10 Kislev et la Min'ha du 9, ainsi que les 12 et 13 Tamouz. Le 20 Kislev n'est documenté que chez Habad. Pour Edot, l'app est conforme au Yalkout Yossef 131:33.

### Pourim triple : Ta'hanoun du dimanche 16 Adar en Israël (Ashkenaz)
**Différence entre poskim** · gravité basse · Ashkenaz · Israël

- **Ce que fait l'app** : le 2025-03-16, en Israël hors de Jérusalem, l'Ashkenaz n'a ni `tahanoun_chaharit` ni `tahanoun_minha`, mais garde `lamnatseah`. L'app affiche le libellé `ajout_sans_tahanoun_halikhot_chlomo`, qui précise que le Michna Beroura fait dire Ta'hanoun. C'est le choix de l'utilisateur, et il est bien appliqué.
- **Ce que dit la source** : le Michna Beroura limite l'omission aux deux jours de Pourim. Le Halikhot Chlomo, connu seulement par des sources secondaires, l'omet aussi le 16 Adar. *Michna Beroura 131:33 ; feuillet Abir Yaakov citant le Halikhot Chlomo, Moadim II.* « בפורים - היינו בשני ימים » ; « ויש נהגו שלא לומר תחנון ביום זה משום כבודה של ירושלים ».
- **Correction proposée** : aucune. Préciser que le Michna Beroura ne traite pas explicitement ce cas, et que l'avis qui fait dire Ta'hanoun est celui du Maharalbach (§32).

### Pas de Ta'hanoun le jour de Pessa'h Chéni en Sfard et en Ashkenaz
**Différence entre poskim** · gravité basse · Sfard et Ashkenaz · tous lieux

- **Ce que fait l'app** : avec `tachanunRecitedPesachSheni: false` (`web/src/js/tefila.js:18` et `:53`), l'app ne dit pas Ta'hanoun le 14 Iyar, mais garde למנצח. En Sfard, תפלה לדוד est replié. Dates : 2025-05-12, 2026-05-01, 2027-05-21, 2028-05-10, 2029-04-29. La consigne Sfard de Min'ha (S2 b0) ne compte pourtant pas ce jour parmi les jours sans Ta'hanoun.
- **Ce que dit la source** : ni le Choul'han Aroukh ni le Michna Beroura n'en parlent. L'usage séfarade et 'hassidique est de ne pas dire Ta'hanoun, l'ancien usage ashkénaze était de le dire. *Chaarei Techouva O.H. 131:19 ; Wikipédia hébreu « פסח שני ».* « לענין ט"ו באייר אותן שנהגו שלא לו' בי"ד משום פסחא זעירא » ; « אבל באשכנז המנהג הקדום היה לומר תחנון כי בטלה מגילת תענית ».
- **Correction proposée** : rien à changer au comportement. Afficher le 14 Iyar la précision « usage ; ni le Choul'han Aroukh ni le Michna Beroura n'en parlent ; l'ancien minhag Ashkenaz disait Ta'hanoun ».

### Pas de Ta'hanoun à Min'ha de la veille de Lag baOmer (Sfard)
**Différence entre poskim** · gravité basse · Sfard · tous lieux

- **Ce que fait l'app** : avec `tachanunRecitedMinchaErevLagBaomer: false` (`web/src/js/tefila.js:20` et `:78`), la Min'ha du 17 Iyar se dit sans Ta'hanoun : 2025-05-15, 2026-05-04, 2027-05-24, 2029-05-02. L'app suit la consigne de son siddour Sfard (Min'ha S2 b0). Elle est juste pour Edot (Yalkout Yossef 131:38) comme pour l'Ashkenaz (Michna Beroura 131:33).
- **Ce que dit la source** : le Choul'han Aroukh haRav dit Ta'hanoun et ne cite l'omission que comme un usage local. *Choul'han Aroukh haRav O.H. 493:5.* « וְלָכֵן אוֹמְרִים תַּחֲנוּן בִּתְפִלַּת הַמִּנְחָה שֶׁל עֶרֶב ל"ג. וְיֵשׁ מְקוֹמוֹת נוֹהֲגִין שֶׁלֹּא לוֹמַר ».
- **Correction proposée** : aucune n'est obligatoire. Proposer un choix en Sfard, ou une précision « Choul'han Aroukh haRav : on le dit ».

### Avinou malkénou dit le Chabbat chez les Edot, avec les lignes de faute
**Différence entre poskim** · gravité basse · Edot · tous lieux

- **Ce que fait l'app** : l'Avinou malkénou Edot (Cha'harit 9.72-9.104, Min'ha 1.71-1.103) dépend de `asseret_yemei_techouva`. Il est donc ouvert le Chabbat (2025-09-27, 2026-09-12, 2026-09-19, 2024-10-05, 2024-10-12), avec en clair « חטאנו לפניך » et « מחול וסלח לכל עונותינו ». En Sfard et en Ashkenaz, il est replié le Chabbat.
- **Ce que dit la source** : le Yalkout Yossef rapporte deux usages et retient celui de dire Avinou malkénou le Chabbat, en sautant les lignes de faute. *Kitsour Yalkout Yossef 582/602:24 (lois des dix jours).* « אלא שמדלגים חטא ועון, כגון אבינו מלכנו חטאנו לפניך, וכן ״אבינו מלכנו מחול וסלח לכל עוונותינו״ ».
- **Correction proposée** : estomper le Chabbat les lignes 9.73, 9.85 et 9.88 (et peut-être 9.87), ainsi que 1.72, 1.84 et 1.87 (et 1.86), par une variante `!chabbat`, pour Roch Hachana et le Chabbat Chouva. Pour Kippour un Chabbat, la règle reste incertaine : le Yalkout Yossef 620:8 ne parle pas de sauter des lignes. À défaut, une simple mention suffit. Un vérificateur classerait ce point en erreur de l'app.

#### Constats écartés

- **למנצח et תפלה לדוד les jours sans Ta'hanoun : l'app distingue bien les rites** : ces trois constats ne relevaient aucun défaut. Les vérificateurs les jugent incomplets, et ce qu'ils y ajoutent ('Hol hamoed, usage Sfard partagé) est déjà traité plus haut.
- **Ta'hanoun du 23 au 29 Tichri en Sfard et en Ashkenaz** : l'app suit le Rema et le Michna Beroura en Ashkenaz et le Yalkout Yossef en Edot, et le Sfard a déjà un réglage. Un vérificateur note pourtant que la valeur par défaut en Sfard (Ta'hanoun dit) va contre la consigne du siddour : « ומערב יום הכיפורים עד אחר ראש חודש חשון ».


---

## Insertions de la Amida

### Edot : la conclusion « העונה לעמו ישראל בעת צרה » affichée en clair tous les jours
**Erreur de l'app** · gravité haute · Edot · tous lieux
- **Ce que fait l'app** : dans siddur_edot.json, la chatima « ברוך אתה יהוה העונה לעמו ישראל בעת צרה » (Cha'harit 9:15, Min'ha 1:14) n'a aucune annotation. tools/siddur_annotations.py:448-453 ne rattache au groupe de l'officiant que la consigne et le texte d'Anénou, si bien que web/src/js/app.js (corpsDe) et SiddurJour.lignes l'affichent en texte normal. Le 2025-11-18 (jour ordinaire), elle paraît seule entre גואל ישראל et רפאנו, aux deux offices. Les jours de jeûne (2025-12-30, 2026-03-02, 2026-07-23), elle reste hors du groupe de l'officiant, en clair pour le particulier.
- **Ce que dit la source** : cette chatima n'appartient qu'à l'officiant, dans sa répétition, un jour de jeûne public ; le particulier conclut par שומע תפלה. *Yalkut Yosef, Kitsour O.H. 557:3 (section 554, bloc 2) ; aussi 550:29 et 550:33 (section 542, blocs 28 et 32)*. « ולא כמו שנדפס באיזה סידורים החתימה ליחיד "ברוך וכו' העונה לעמו ישראל בעת צרה". ורק שליח צבור האומר עננו בין גואל לרופא, חותם בחתימה זו. »
- **Correction proposée** : dans tools/siddur_annotations.py, rattacher au groupe de l'Anénou de l'officiant le bloc qui le suit quand il commence par « ברוך אתה » et contient « העונה לעמו ישראל » (condition « jeune », libellé ajout_anenou_officiant), avec le même numéro de groupe (g6 à Cha'harit, g2 à Min'ha) pour éviter un pli à part. Régénérer siddur_annotations.json.

### Edot : Na'hem absent d'Arvit et de Cha'harit du 9 Av, et la carte du jour ne dit pas à quelles prières
**Erreur de l'app** · gravité moyenne · Edot (libellé : tous les noussa'h) · tous lieux
- **Ce que fait l'app** : le siddour Edot n'a Na'hem qu'à Min'ha (1:25, annoté ticha_beav). À Arvit (2:22) et à Cha'harit (9:25), « בונה ירושלים » est seul ; SimulationSiddurTest.kt:92 entérine ce choix. La carte du jour affiche « Na'hem » sans dire à quel office (web/src/js/jour-affiche.js:33, JourAffiche.kt:65), alors qu'elle précise l'office pour Anénou. Dates : 2025-08-03, 2026-07-23, 2027-08-12, 2029-07-22 (jeûne repoussé), Arvit de la veille compris.
- **Ce que dit la source** : chez les Edot (usage de Jérusalem), Na'hem se dit à Arvit, Cha'harit et Min'ha, et l'officiant le dit dans sa répétition ; seuls les Ashkénazes le limitent à Min'ha (Rema 557:1). *Yalkut Yosef, Kitsour O.H. 557:1 (section 554, bloc 0)*. « וכן מנהג ירושלים לומר נחם בכל התפלות, ערבית שחרית ומנחה »
- **Correction proposée** : ajouter Na'hem et sa chatima « מנחם ציון בבנין ירושלים » à l'Arvit et à la Cha'harit Edot, annotés ticha_beav (à défaut, au moins une consigne Edot), et étendre à ces offices la règle de SimulationSiddurTest.kt:92. Sur la carte du jour, un libellé par noussa'h, comme pour Anénou : « Na'hem, à Arvit, Cha'harit et Min'ha » (Edot), « Na'hem, à Min'ha seulement » (Sfard, Ashkenaz).

### Na'hem : deux conclusions de bénédiction affichées à Min'ha, et une en trop chaque jour chez les Edot
**Erreur de l'app** · gravité moyenne · Edot, Sfard, Ashkenaz · tous lieux
- **Ce que fait l'app** : tools/siddur_annotations.py:555-561 n'annote que le bloc de Na'hem, pas les conclusions voisines. Edot, Min'ha : un jour ordinaire (2025-11-18, et tout le mois d'Av sauf le 9, par exemple le 2026-07-22), Na'hem (1:25) est replié, mais sa chatima « מנחם ציון בבנין ירושלים » (1:26) reste en clair juste avant « בונה ירושלים » (1:27). Le 9 Av (2026-07-23), 1:26 et 1:27 sont tous deux en clair. Sfard : le renvoi « (את צמח וגו׳) » (1:74) reste visible chaque jour ; le 9 Av, Na'hem (1:73, qui finit par sa propre chatima) puis « בונה ירושלים » (1:75) sont en clair. Ashkenaz, le 9 Av : 1:61 puis 1:62, même double conclusion.
- **Ce que dit la source** : le 9 Av, une seule chatima, celle de Na'hem (« בונה ירושלים » reste valable a posteriori) ; les autres jours, « בונה ירושלים » seulement. *Yalkut Yosef, Kitsour O.H. 557:1 (section 554, bloc 0)* ; pour Sfard et Ashkenaz, le texte du bloc Na'hem des siddourim et Michna Beroura 557:2. « וחותם ברוך אתה ה' מנחם ציון בבנין ירושלים, ואם חתם בונה ירושלים שפיר דמי »
- **Correction proposée** : joindre au groupe ticha_beav les restes de Na'hem, Edot Min'ha 1:26 (groupe g5) et Sfard 1:74 (g16) : c'est le point prioritaire, car il touche les jours ordinaires. Annoter ensuite les chatimot ordinaires (Edot 1:27, Sfard 1:75, Ashkenaz 1:62) en « !ticha_beav » discret, avec un libellé propre (par exemple « ajout_sauf_ticha_beav », à créer), sinon le pli s'intitulerait « ajout du 9 Av ». Les vérificateurs notent que le jour même, chez les Edot et en Sfard, la consigne « את צמח » renvoie déjà au-delà de la chatima ordinaire, ce qui atténue le défaut ; un vérificateur juge ce second repli facultatif.

### Consigne d'oubli de משיב הרוח sans l'exception de qui a dit מוריד הטל
**Erreur de l'app** · gravité moyenne · Sfard, Ashkenaz · Sfard partout, Ashkenaz en Israël (l'Ashkenaz de diaspora est conforme)
- **Ce que fait l'app** : la consigne « טעה ולא אמר בחורף משיב הרוח ומוריד הגשם … צריך לחזור לראש התפלה … בתוך שלושים יום צריך לחזור ולהתפלל » (siddur_sefard.json Cha'harit 8:13, Min'ha 1:13, Arvit 1:13 ; siddur_ashkenaz.json Cha'harit 3:11, Min'ha 1:12, Arvit 3:11) est repliée sous « En cas d'oubli » (web/src/js/app.js:2030), sans exception. Or l'app fait dire מוריד הטל en été au Sfard partout et à l'Ashkenaz en Israël (web/src/js/siddur-jour.js:31, SiddurJour.kt:216 ; vérifié le 2025-07-15). En hiver (2025-12-15), elle leur fait donc refaire l'Amida.
- **Ce que dit la source** : qui a dit מוריד הטל ne recommence pas, et le doute dans les trente jours ne vaut que pour qui ne dit pas le tal. *Choul'han Aroukh O.H. 114:5 ; Kitsour Choul'han Aroukh 19:3 (la source même de la consigne) ; Michna Beroura 114:35 ; Choul'han Aroukh haRav 114:6 et 114:10*. « וה"מ שלא הזכיר טל אבל אם הזכיר טל אין מחזירין אותו »
- **Correction proposée** : ne pas réécrire le texte du siddour (repris du Metsudah 1981), mais ajouter à côté une consigne repliée, conditionnée à morid_hatal, tirée du Kitsour 19:3 : « …ואין צריך לחזר בשביל הזכרת גשם, כיון שכבר זכר טל », en précisant que dans le doute, dans les trente jours, on ne recommence pas non plus.

### Carte du jour : la bénédiction des années annoncée à Yom tov, Roch Hachana et Kippour
**Erreur de l'app** · gravité basse · Edot, Sfard, Ashkenaz · tous lieux
- **Ce que fait l'app** : web/src/js/jour-affiche.js:23-26 et JourAffiche.kt:51-54 n'écartent la neuvième bénédiction que le Chabbat ; la condition « berakha » vient de web/src/js/tefila.js:88, qui ignore les fêtes. La carte « Dans les prières » (app.js:2736, VueJour.kt:165) annonce donc « Barkhénou » (Edot) ou « Vetèn berakha » (Sfard, Ashkenaz) à Roch Hachana (2025-09-23, 2025-09-24, 2026-09-13), Kippour (2025-10-02, 2026-09-21), Soukkot et Chemini Atséret (2025-10-07, 2025-10-14), Pessa'h (2026-04-02, 2026-04-08), Chavouot (2026-05-22) ; en diaspora aussi les 2025-10-08, 2025-10-15, 2026-04-03, 2026-09-27 et 2026-10-04.
- **Ce que dit la source** : l'Amida de Yom tov compte trois premières bénédictions, la sainteté du jour et trois dernières, sans bénédiction des années. *Choul'han Aroukh O.H. 487:1* (Choul'han Aroukh haRav 487:1 ; pour les Edot, Kitsour Yalkut Yosef, « שמחת תורה בחוץ לארץ »). « ערבית ושחרית ומנחה אומר שלש ראשונו' ושלש אחרונו' וקדושת היום באמצע »
- **Correction proposée** : dans ajouts() (JS et Kotlin), écarter la neuvième bénédiction quand chabbat ou yom_tov est vrai (`C.CHABBAT !in c && C.YOM_TOV !in c`) ; yom_tov couvre déjà Roch Hachana, Kippour et le 2ᵉ jour de diaspora, et n'est pas posé à 'Hol hamoed, où la bénédiction doit rester. Ajouter un cas de Yom tov à JourAfficheTest. La mention « sans Ta'hanoun » n'est pas fausse à Yom tov ; la taire relève de la symétrie avec le Chabbat. L'absence d'Amida de fête dans le siddour (et מזמור לתודה non replié en Edot) est une limite de portée d'un siddour de semaine, pas un défaut propre à Yom tov.

### Min'ha d'un jeûne (Ashkenaz) : שלום רב et שים שלום affichés tous les deux
**Erreur de l'app** · gravité basse · Ashkenaz · tous lieux
- **Ce que fait l'app** : dans siddur_ashkenaz.json, Min'ha 1:89 « לתענית ציבור: שים שלום » est annoté « jeune », mais 1:88 « שלום רב » ne l'est pas : la boucle de ברכת כהנים (tools/siddur_annotations.py:394-404) s'arrête sur ce bloc sans l'annoter. Les jours de jeûne (2026-07-02, 2026-07-23, 2026-12-20, 2027-07-22), on voit ברכת כהנים (1:85-87) mise en évidence, puis שלום רב en clair, puis שים שלום mis en évidence.
- **Ce que dit la source** : on dit שים שלום chaque fois qu'on dit ברכת כהנים, donc à Min'ha d'un jeûne public ; sinon שלום רב. *Rema O.H. 127:2 ; Michna Beroura 127:12*. « ונהגו לומר בשחרית שים שלום וכן כל זמן שאומר אלהינו כו' אבל בלאו הכי מתחילין שלום רב »
- **Correction proposée** : annoter 1:88 en « !jeune », discret, dans la boucle de ברכת כהנים, avec un libellé propre (par exemple « hors jeûne public ») : sans libellé, libelle('!jeune') intitulerait le pli « Anénou ». Un vérificateur préfère un simple repère (« si le ש״ץ dit ברכת כהנים : שים שלום »), car qui prie seul garde שלום רב (Michna Beroura 127:12 : « ויחיד המתענה אומר שלום רב »).

### Al hanissim : « על הנסים » sans ו dans les textes Edot et Ashkenaz
**Erreur de l'app** · gravité basse · Edot, Ashkenaz · tous lieux
- **Ce que fait l'app** : Edot : Cha'harit 9:45, Min'ha 1:45, Arvit 2:39, Birkat hamazon 0:17 et Moussaf de Roch 'Hodech 0:17 portent « עַל הַנִּסִּים », sans ו. Ashkenaz : Cha'harit 3:71, Min'ha 1:78, Arvit 3:50 et Moussaf de Roch 'Hodech 5:6 aussi ; son Birkat hamazon (0:25) a le ו, le siddour se contredit donc. Sfard a le ו partout. Dates : 2025-12-17 (Hanoukka), 2026-03-03 (Pourim).
- **Ce que dit la source** : il faut dire « ועל הנסים », mais qui dit sans ו ne se trompe pas. *Yalkut Yosef, Kitsour O.H. 682:4 (section 662, bloc 3)* ; aussi 693:1 (section 680, bloc 0) et Michna Beroura 682:1. « יש לומר "ועל הנסים" בתוספת אות ו' ... ומ"מ האומר על הנסים בלי ו' לא משתבש »
- **Correction proposée** : ajouter le ו (avec nikoud) dans siddur_edot.json (Cha'harit, Min'ha, Arvit, Birkat hamazon, Moussaf de Roch 'Hodech) et dans siddur_ashkenaz.json (Cha'harit, Min'ha, Arvit, Moussaf de Roch 'Hodech, pas le Birkat), ou une note. Un vérificateur y voit plutôt un écart entre siddourim imprimés et lekhat'hila des poskim (Aroukh haChoul'han 682:1 : « ובסידורים כתוב "על הנסים", ונראה שצריך לומר בוי"ו »), donc une correction facultative.

### Edot : aucune consigne d'oubli dans l'Amida
**Erreur de l'app** · gravité basse · Edot · tous lieux
- **Ce que fait l'app** : aucun bloc des Amida Edot (Cha'harit, Min'ha, Arvit) n'est annoté « oubli » dans siddur_annotations.json, contre 8 à 9 par office en Sfard et en Ashkenaz (repliés via web/src/js/app.js:2030). Le siddour Edot source n'en imprime pas ; seule une incise pour l'officiant figure dans le bloc d'Anénou (Cha'harit 9:28, Min'ha 1:30 : « שליח ציבור ששכח לומר בין גואל לרופא יאמר כאן עננו בלי חתימה »). Les 2025-10-23 (יעלה ויבא), 2025-12-05 (טל ומטר) ou 2026-03-03 (על הנסים), rien ne dit au fidèle Edot quoi faire en cas d'oubli, alors que les règles diffèrent des consignes des autres rites (המלך המשפט, טל ומטר, משיב הרוח).
- **Ce que dit la source** : le Yalkut Yosef donne pour chaque insertion la règle d'oubli, par exemple pour טל ומטר. *Yalkut Yosef, Kitsour O.H. 117:6 (section 118, bloc 5)*. « אבל אם סיים פסוק יהיו לרצון האחרון, אף על פי שעדיין לא פסע שלש פסיעות לאחוריו, חוזר לראש התפלה. »
- **Correction proposée** : ajouter au siddour Edot, comme texte propre à l'app, des consignes « oubli » repliées d'après le Kitsour Yalkut Yosef : 114:2-5, 117:6-9, 557:1 et 3, 582:10-12 (section 575) pour המלך המשפט, les se'ifim ט-יד de la section 560 pour Roch Hachana, 682:5, 693:2. Les vérificateurs notent que le Yalkut Yosef n'exige pas ces rappels : c'est une lacune de contenu et une inégalité entre rites plutôt qu'une contradiction.

### Oubli de המלך המשפט : la règle diffère selon le rite
**Différence entre rites** · gravité basse · Edot, Sfard, Ashkenaz · tous lieux
- **Ce que fait l'app** : les siddourim Sfard (Cha'harit 8:68, Min'ha 1:65, Arvit 1:52) et Ashkenaz (3:55, 1:56, 3:37) portent, repliée sous « oubli », la consigne « ואם לאחר כ״ד לא יאמר ואין מחזירין אותו », conforme au Rema. Le siddour Edot (Cha'harit 9:22, Min'ha 1:21, Arvit 2:19) n'a que la variante, sans consigne d'oubli. Vérifié le 2025-09-28 (6 Tichri).
- **Ce que dit la source** : les Edot reviennent à השיבה (Mé'haber 582:1) ; l'usage ashkénaze est de ne pas revenir (Rema 118:1). *Yalkut Yosef, Kitsour O.H. 582:10-11 (section 575, blocs 9-10)*. « חוזר לברכת השיבה, וחותם ״המלך המשפט״ ... ומנהג האשכנזים בחוץ לארץ שמי שטעה ואמר מלך אוהב צדקה ומשפט במקום המלך המשפט, ונזכר לאחר תוך כדי דיבור, אינו חוזר. »
- **Correction proposée** : ajouter au siddour Edot une consigne « oubli » selon le Yalkut Yosef (retour à השיבה ; Amida terminée, la refaire sous condition de nedava). En Sfard, mentionner éventuellement la tefilat nedava, que le Choul'han Aroukh haRav 582:2 conseille sans l'exiger (« טוב שיתפלל עוד פעם בתורת נדבה »).

### Rappel de fin de משיב הרוח identique pour tous, alors que l'Ashkenaz de diaspora cesse à Min'ha
**Différence entre rites** · gravité basse · Ashkenaz · diaspora
- **Ce que fait l'app** : RappelsTefila.kt:89 et web/src/js/app.js:705 affichent pour tous les noussa'h le même rappel rappel_guechem_fin (strings.xml:1152), « à Moussaf du premier jour de Pessa'h, on cesse de dire משיב הרוח », en citant 114:1. Vérifié pour le 2026-04-02 (15 Nissan). Les conditions de ce jour, elles, gardent machiv_harouah pour l'Ashkenaz de diaspora.
- **Ce que dit la source** : en Ashkenaz de diaspora, seul l'officiant cesse à la répétition de Moussaf ; l'assemblée le dit encore dans la Amida silencieuse de Moussaf et cesse à Min'ha. *Rema O.H. 114:3 ; Michna Beroura 114:3*. « אבל הקהל מזכירין ואין פוסקין עד מנחה ששמעו כבר מש"ץ שפסק בתפלת המוסף וכן נוהגין »
- **Correction proposée** : un texte rappel_guechem_fin_ashkenaz, choisi pour l'Ashkenaz hors d'Israël : l'officiant cesse à la répétition de Moussaf, l'assemblée à Min'ha, avec renvoi au Rema 114:3 et au Michna Beroura 114:3. Un vérificateur classerait ce point en erreur de l'app, puisque l'app distingue déjà ce public ailleurs.

### 17 Tamouz : Anénou du particulier, l'app distingue bien les rites
**Différence entre rites** · gravité basse · Edot, Sfard, Ashkenaz · tous lieux
- **Ce que fait l'app** : la carte du jour donne « anenou_particulier_matin_minha » en Edot et « anenou_particulier_minha » en Sfard et Ashkenaz (web/src/js/jour-affiche.js, JourAffiche.kt:55-63). En Edot, l'Anénou du particulier est en clair à Cha'harit (9:28-29) et à Min'ha (1:30-31) ; en Sfard et Ashkenaz, il n'existe qu'à Min'ha (Sfard 1:80-81, Ashkenaz 1:65-66). Dates : 2022-07-17 (reporté), 2025-07-13, 2026-07-02, 2027-07-22. C'est conforme.
- **Ce que dit la source** : le Mé'haber fait dire Anénou au particulier à toutes ses prières des quatre jeûnes ; le Rema, à Min'ha seulement. *Choul'han Aroukh O.H. 565:3 et Rema ; Yalkut Yosef, Kitsour O.H. 557:3 et, pour les jeûnes publics, 550:27 (section 542)*. « אך מנהג אשכנז שהשליח צבור אומר עננו בשחרית ומנחה, והיחיד במנחה בלבד »
- **Correction proposée** : aucune.

### Edot : Anénou du particulier absent d'Arvit la veille des jeûnes autres que le 9 Av
**Différence entre poskim** · gravité basse · Edot · tous lieux
- **Ce que fait l'app** : l'Anénou d'Arvit Edot (2:25-26) n'est annoté que ticha_beav, et ajouts() (web/src/js/jour-affiche.js:31) annonce « Cha'harit et Min'ha » pour les autres jeûnes, « Arvit, Cha'harit et Min'ha » le 9 Av. Le soir du 2026-07-01 (Arvit du 17 Tamouz), l'Anénou est replié ; il reste accessible en dépliant le bloc.
- **Ce que dit la source** : le Yalkut Yosef exige Anénou à Cha'harit et à Min'ha et juge fondé l'usage de le dire aussi à Arvit ; le Michna Beroura lit le Mé'haber comme incluant Arvit ; le Kaf Ha'haïm 565:17 rapporte l'usage séfarade de ne pas le dire à Arvit hors du 9 Av. *Yalkut Yosef, Kitsour O.H. 550:27 (section 542, bloc 26) ; Choul'han Aroukh O.H. 565:3 ; Michna Beroura 565:9*. « ובמקומות שנוהגים לומר "עננו" בשומע תפלה בכל התפלות, גם בערבית של ערב התענית, אף שאין מתענים מהערב, מנהגם נכון על פי ההלכה »
- **Correction proposée** : aucune obligation : l'app suit la règle principale du Yalkut Yosef. Au plus, un bloc facultatif à Arvit les soirs du 17 Tamouz, du 10 Tévèt et du jeûne de Guedalia (le jeûne d'Esther n'est pas visé par « ארבע צומות »).

### Hémisphère sud (Edot) : demande de la pluie, référence de code 117:19 au lieu de 117:20
**Différence entre poskim** · gravité basse · Edot · hémisphère sud
- **Ce que fait l'app** : avec le réglage « sud », l'app fait dire מוריד הטל toute l'année et demande la pluie comme en diaspora, dès le 60ᵉ jour (2025-12-05, 2026-12-05) jusqu'à la veille de Pessa'h (2026-04-01) : c'est la décision (« לדינא ») du Yalkut Yosef. Mais les commentaires de web/src/js/siddur-jour.js:33-34, SiddurJour.kt:218-219 et FEUILLE_DE_ROUTE.md:977 renvoient à « 117:19 … note 19, p. 100 », le se'if d'un autre cas, alors que les tests (HemisphereSudTest.kt:9, web/test/hemisphere-sud.test.mjs:1) citent bien 117:20. L'avis « יש אומרים » (demande seulement dans שומע תפלה pendant l'hiver austral, par exemple du 2026-06-14 au 2026-07-15) n'est pas proposé.
- **Ce que dit la source** : pour le Brésil et l'Australie, le Yalkut Yosef rapporte l'avis de ne jamais demander dans ברכת השנים, puis tranche de suivre la diaspora en gardant מוריד הטל. *Yalkut Yosef, Kitsour O.H. 117:20 (section 118, bloc 19)*. « ולדינא נראה, שבזמן הזה שהגשמים להם היא לסימן ברכה, יש להם לשאול טל ומטר בברך עלינו החל מיום ששים לתקופה »
- **Correction proposée** : aucune sur le comportement. Remplacer la référence par « 117:20 (סעיף כ) ; Yalkut Yosef Tefila II, 117 note כ, p. קא » dans les deux commentaires et dans FEUILLE_DE_ROUTE.md. Une consigne facultative pour שומע תפלה en hiver austral, ou un réglage pour le cas du se'if יט (lieux où la pluie nuit), ne serait qu'une suggestion.

### Ashkenaz, dix jours : conclusion « עושה השלום » donnée seulement à Arvit
**Différence entre poskim** · gravité basse · Ashkenaz · tous lieux
- **Ce que fait l'app** : siddur_ashkenaz.json Arvit 3:58 ajoute « (ברוך אתה יהוה עשה השלום:) » après בספר חיים, sans étiquette ; Cha'harit 3:85 et Min'ha 1:90 ne l'ont pas. La chatima « המברך את עמו ישראל בשלום » reste affichée aux trois offices. Vérifié le 2025-09-28 (6 Tichri). Le constat, d'abord non vérifiable, a été requalifié une fois la source lue.
- **Ce que dit la source** : la chatima reste « המברך » comme le reste de l'année ; certains disent « עושה השלום », mais le particulier, dans l'Amida à voix basse, dit « המברך ». *Maté Efraïm 582:22 ; Aroukh haChoul'han O.H. 582:4*. « וחתימת הברכה יאמר: "ברוך אתה ה' המברך", כמו בשאר השנה, ויש נוהגין לומר "עושה השלום" »
- **Correction proposée** : harmoniser les trois offices : retirer la parenthèse d'Arvit, ou l'ajouter partout avec une note « יש נוהגין » tirée du Maté Efraïm 582:22.

#### Constats écartés
- **Dix jours de pénitence (Edot) : la formule ordinaire reste en avant, sans repère « aujourd'hui »** : l'app affiche « המלך הקדוש » avec la consigne même du siddour (mise en évidence en Sfard et Ashkenaz) et n'omet rien de ce que la source exige ; l'absence de ligne « Aujourd'hui » en Edot est un choix d'ergonomie, et l'exemple du 2025-09-24 tombait à Roch Hachana.
- **Jours de bascule de la pluie : משיב הרוח / מוריד הטל marqués pour toute la journée au lieu de « dès Moussaf »** : le 22 Tichri et le 15 Nissan sont toujours Yom tov, jours où l'Amida de semaine ainsi annotée n'est pas dite, la carte est juste pour la journée entière et le rappel du jour précise déjà le passage à Moussaf.


---

## Hallel et Moussaf

### Roch 'Hodech un Chabbat : l'app renvoie au Moussaf de semaine au lieu de « אתה יצרת »
**Erreur de l'app** · gravité moyenne · Edot, Sfard, Ashkenaz · tous lieux

- **Ce que fait l'app** : le renvoi de Cha'harit vers `moussaf_rosh_hodech` n'a que la condition `roch_hodech` (tools/siddur_annotations.py:961-964). Il s'affiche donc aussi le Chabbat (web/src/js/app.js:1431 ; Android SiddurJour.kt:122), avec la mention « Aujourd'hui · מוסף לראש חודש ». Il mène au Moussaf de semaine, qui conclut « מקדש ישראל וראשי חדשים ». Aucun siddour ne contient « אתה יצרת », et aucune annotation n'utilise `chabbat_roch_hodech`. Dates : 2024-07-06, 2025-03-01, 2025-12-20, 2026-04-18, 2027-01-09, 2027-05-08, 2028-06-24.
- **Ce que dit la source** : le Chabbat Roch 'Hodech, la 4ᵉ bénédiction du Moussaf réunit Chabbat et Roch 'Hodech. Selon le Yalkut Yosef, qui conclut par la seule formule de Roch 'Hodech n'est pas quitte. Le Michna Beroura 425:15 ne traite que de qui conclut par la formule du Chabbat seule. *Kitsour Yalkut Yosef, siman 423 « תפלת מוסף בראש חודש », se'if 10 (Yalkut Yosef Chabbat I p. 374) ; Choul'han Aroukh O.H. 425:3*. « בשבת וראש חודש אין אומרים במוסף תכנת שבת, אלא יש לומר נוסח ״אתה יצרת״ ... אבל אם חתם בשל ר״ח בלבד, לא יצא » ; « כולל במוסף בברכה רביעית שבת ור'"ח וחותם מקדש השבת וישראל וראשי חדשים ».
- **Correction proposée** : ne plus afficher le renvoi Moussaf quand `chabbat_roch_hodech` est vrai. Garder en revanche le renvoi Hallel, qui est juste ce jour-là. Comme `vrai()` (siddur-jour.js:7 et SiddurJour.kt) n'évalue qu'une seule clé, il faut créer une condition dérivée, par exemple `roch_hodech_chol`, dans CalendrierJuif (web et Android), ou bien faire évaluer plusieurs clés aux renvois. Le Chabbat Roch 'Hodech, afficher à la place une consigne : « Moussaf de Chabbat Roch 'Hodech : אתה יצרת (non inclus) ». Ajouter un cas négatif à SimulationSiddurTest et à web/test/calendrier.test.mjs:196.

### Edot : la bénédiction du Hallel partiel n'est pas repliée
**Erreur de l'app** · gravité moyenne · Edot · tous lieux

- **Ce que fait l'app** : dans le Hallel Edot (siddur_edot.json, `hallel`, section 0), les blocs 0 à 3 n'ont aucune annotation : « בימים שגומרים את ההלל אומר החזן », « ברשות מורי ורבותי », « והחזן מברך » et « …וצונו לגמור את ההלל ». La regex de tools/siddur_annotations.py:868 ne reconnaît que les consignes négatives. La bénédiction reste donc affichée en clair tous les jours de Hallel partiel, alors que יהללוך (0:22-23) est replié et que le libellé du jour annonce « Hallel partiel, sans bénédiction » (siddur-jour.js:74 ; SiddurJour.kt:274-279). Dates : 2025-10-23 (Roch 'Hodech), 2025-11-21, 2026-01-19, 2026-04-03 (Israël), 2026-04-05 à 2026-04-08 ('Hol hamoed Pessa'h), 2026-04-09 (diaspora), 2027-02-07/08.
- **Ce que dit la source** : les Séfarades ne bénissent pas sur le Hallel de Roch 'Hodech ni sur celui de 'Hol hamoed Pessa'h. Pour le Choul'han Aroukh, cette bénédiction est prononcée en vain. *Kitsour Yalkut Yosef, siman 422 « קריאת ההלל בראש חודש », se'ifim 2, 14 et 19 ; Choul'han Aroukh O.H. 422:2 ; O.H. 490:4 pour les derniers jours de Pessa'h*. « הספרדים אין מברכים על ההלל בר״ח » ; « ולדעת השלחן ערוך המברך על ההלל בראש חודש נושא שם שמים לבטלה » ; « ומנהגינו לקרוא את ההלל בראשי חדשים בלא ברכה, וכן בחול המועד פסח ».
- **Correction proposée** : ajouter une règle dédiée qui annote ensemble les blocs 0:0 à 0:3 avec `si=hallel_complet`, consigne intermédiaire 0:2 comprise, sans déborder sur 0:4. Ajouter seulement le motif à CONSIGNES_COURTES ou à la regex de la ligne 868 ne suffit pas : pour `hallel_complet`, la prise se limite à une ligne (ligne 504), et la boucle s'arrête à la consigne 0:2. Régénérer siddur_annotations.json. Ajouter ensuite à SimulationSiddurTest la règle `Regle(setOf("hallel"), "לגמור את ההלל", si(C.HALLEL_COMPLET), setOf(Nusah.EDOT))`. Ne pas étendre la correction au Sfard ni à l'Ashkenaz, qui bénissent (Rema 422:2).

### Roch 'Hodech Tévèt et Chabbat de 'Hanouka : le Kaddich titkabal du Hallel est replié
**Erreur de l'app** · gravité moyenne · Edot, Sfard · tous lieux

- **Ce que fait l'app** : tools/siddur_annotations.py:280-291 replie sous `!hanouka` la fin du Kaddich du Hallel (תתקבל, יהא שלמא, עושה שלום) : Edot `hallel` [0:26]-[0:28], Sfard [0:31]-[0:33]. SimulationSiddurTest.kt:98 fige ce comportement. Les jours de 'Hanouka qui ont un Moussaf, il ne reste donc que le demi-Kaddich. En Sfard, la consigne de Cha'harit [13:16] ne prévoit qu'un demi-Kaddich après ובא לציון quand il y a Moussaf : le תתקבל disparaît alors de tout Cha'harit. Dates : 2023-12-13, 2024-12-31, 2025-01-01, 2025-12-20, 2025-12-21, 2026-12-05 (Chabbat 'Hanouka), 2026-12-10/11, 2026-12-12.
- **Ce que dit la source** : tout jour qui a un Moussaf, on dit תתקבל après le Hallel. Le demi-Kaddich de 'Hanouka tient à l'absence de Moussaf. *Kitsour Yalkut Yosef, siman 423 « קריאת התורה בראש חודש », se'if 1 (Yalkut Yosef Chabbat V p. 298) ; Michna Beroura 423:1 ; Kaf ha'Haïm 423:1*. « כל יום שיש בו מוסף אומרים קדיש תתקבל אחר ההלל, שהוא סיום תפלת שחרית » ; « ואם אין בו מוסף (לאפוקי חנוכה) אומר חצי קדיש ».
- **Correction proposée** : créer dans CalendrierJuif.kt et calendrier-juif.js une condition dérivée `hanouka_sans_moussaf` = hanouka ∧ ¬roch_hodech ∧ ¬chabbat. Annoter les blocs Edot 26-28 et Sfard 31-33 avec `!hanouka_sans_moussaf` au lieu de `!hanouka`, puis régénérer siddur_annotations.json. Corriger la règle 98 de SimulationSiddurTest et ajouter des cas pour 2025-12-21, 2025-12-20 et 2026-12-05. L'Ashkenaz relève d'un défaut distinct (constat suivant).

### Ashkenaz : pas de Kaddich titkabal après le Hallel de Roch 'Hodech et de 'Hol hamoed
**Erreur de l'app** · gravité moyenne · Ashkenaz · tous lieux

- **Ce que fait l'app** : le Hallel ashkénaze (siddur_ashkenaz.json, `hallel`) s'arrête à [7:1] « מלך מהלל בתשבחות », sans aucun Kaddich. Au retour dans Cha'harit, après le Ta'hanoun replié, le fidèle trouve [4:89] « ש״ץ אומר חצי קדיש », replié sous `minyan`, puis la lecture de la Torah. Le seul תתקבל de l'office est en [6:19]. Dates : 2025-10-22/23, 2025-12-21 (Roch 'Hodech Tévèt), 2026-04-05 ('Hol hamoed Pessa'h).
- **Ce que dit la source** : tout jour qui a un Moussaf, on dit le Kaddich תתקבל après le Hallel. Le demi-Kaddich vient après la lecture de la Torah. *Choul'han Aroukh O.H. 423:1 ; Michna Beroura 423:1 et 423:4 ; Magen Avraham 423:1 ; Aroukh haChoul'han 423:1*. « אומר קדיש תתקבל וכו' ומוציאין ס"ת וקורים בו ד' » ; « וכלל הוא דכל יום שיש בו מוסף אומרים קדיש תתקבל אחר הלל דהוא סיומא דתפלת שחרית ».
- **Correction proposée** : ajouter au Hallel ashkénaze, ou en consigne, le Kaddich complet, avec la fin תתקבל sous la condition des jours de Moussaf (roch_hodech ou 'Hol hamoed), et non sous `!hanouka`. Roch 'Hodech Tévèt doit être couvert. À défaut, poser sur [4:89] un indice « Aujourd'hui : קדיש תתקבל ». La règle de SimulationSiddurTest doit signaler l'absence de תתקבל en Ashkenaz au lieu de sauter ce cas.

### Soir du Séder : aucun renvoi au Hallel d'Arvit pour les Séfarades
**Différence entre rites** · gravité moyenne · Edot, Sfard · tous lieux

- **Ce que fait l'app** : aucun Arvit, dans aucun siddour, ne renvoie au Hallel. Les seuls renvois Hallel sont dans Cha'harit (tools/siddur_annotations.py:960-964). Pourtant l'Arvit de ces soirs reçoit déjà `hallel_complet` par jourDeLaPriere. Soirs concernés : 2025-04-12 (et 04-13 en diaspora), 2026-04-01 (et 04-02), 2027-04-21 (et 04-22).
- **Ce que dit la source** : les communautés séfarades disent le Hallel complet, avec bénédiction, après l'Amida d'Arvit le premier soir de Pessa'h, et les deux premiers soirs en diaspora. En Ashkenaz, le Rema écarte cet usage ; le Michna Beroura limite ce refus à « ces pays-ci ». Côté Sfard, le Choul'han Aroukh haRav l'écarte aussi, mais l'usage 'hassidique répandu le dit. *Kitsour Yalkut Yosef, siman 487, se'if 5 (Yalkut Yosef Moadim p. 382) ; Choul'han Aroukh et Rema O.H. 487:4 ; Michna Beroura 487:16 ; Choul'han Aroukh haRav 487:8*. « מנהג קהלות ספרד לגמור ההלל בבית הכנסת בליל יום טוב הראשון של פסח [ובחו"ל בשני לילות הראשונים של פסח] אחר העמידה של תפלת ערבית, ומברכים לפניו "לגמור את ההלל" » ; « הגה וכל זה אין נוהגים כן כי אין אנו אומרים בלילה בבהכ"נ ההלל כלל ».
- **Correction proposée** : créer une condition dérivée `leil_pessah` (soir du 15 Nissan, et du 16 en diaspora). En Edot, ajouter un renvoi Arvit vers le Hallel complet avec bénédiction, après l'Amida, ou après ויכולו quand le soir tombe un Chabbat (Kitsour YY 487, se'if 11). Pour Edot, un vérificateur y voit plutôt une omission de l'app. En Sfard, ajouter un renvoi facultatif présenté comme un usage partagé. En Ashkenaz, rien en diaspora ; en Israël, une mention facultative est envisageable. Noter que l'Arvit de l'app n'a pas d'Amida de Yom tov.

### Edot : « ולכפרת פשע » gardé au Moussaf après Nissan en année embolismique
**Erreur de l'app** · gravité basse · Edot · tous lieux

- **Ce que fait l'app** : pour les Edot, kapparat_pecha (tools/siddur_annotations.py:128) rend la condition `embolismique`, posée à tout Roch 'Hodech d'une année embolismique (web/src/js/calendrier-juif.js:145-152 ; CalendrierJuif.kt:321-331). L'indice du Moussaf Edot [0:10] affiche donc « Aujourd'hui : וּלְכַפָּרַת פֶּשַׁע » de Nissan à Eloul, alors que Sfard et Ashkenaz, qui reçoivent `embolismique_avant_nissan`, le retirent. Dates : 2027-04-08, 2027-05-07/08, 2027-06-06, 2027-07-05/06, 2027-08-04, 2027-09-02/03 ; 2024-07-06/07 ; 2022-06-29/30.
- **Ce que dit la source** : l'ajout se dit jusqu'à Roch 'Hodech Adar II inclus, et plus à partir de Nissan. Le Ben Ich 'Haï et le Kaf ha'Haïm 423:18, que suit l'app, le disent toute l'année ; le Yalkut Yosef est toutefois la référence choisie pour les Edot. *Kitsour Yalkut Yosef, siman 423 « תפלת מוסף בראש חודש », se'if 14 (Yalkut Yosef Chabbat V p. 312 et 418) ; « נוסחאות התפלה », se'if 66*. « ויש לומר תוספת זו עד ראש חודש אדר ב', ועד בכלל. אבל מראש חודש ניסן ואילך אין צריך להוסיף תיבות אלה ».
- **Correction proposée** : dans kapparat_pecha (tools/siddur_annotations.py:128), rendre `embolismique_avant_nissan` pour les Edot aussi, puis régénérer siddur_annotations.json. Autre voie : garder l'avis du Ben Ich 'Haï avec une précision affichée, « selon le Yalkut Yosef, à partir de Roch 'Hodech Nissan on ne l'ajoute plus ». Dans les deux cas, corriger les commentaires de calendrier-juif.js:145 et de CalendrierJuif.kt:321. Ajouter un test (Moussaf Edot [0:10] retiré le 2027-04-08) et mettre à jour CalendrierJuifTest:181-186 et calendrier.test.mjs:393.

### 'Hol hamoed : le Moussaf n'est ni proposé ni signalé
**Erreur de l'app** · gravité basse · Edot, Ashkenaz · tous lieux

- **Ce que fait l'app** : le seul renvoi Moussaf dépend de `roch_hodech` (tools/siddur_annotations.py:960-964). En 'Hol hamoed, Cha'harit ne propose que le Hallel, et rien ne signale le Moussaf en Edot ni en Ashkenaz. En Sfard, les consignes du siddour (hallel s0 b27 et chaharit s13 b16) l'annoncent, mais sans texte. Le Moussaf des fêtes est une lacune déclarée (FEUILLE_DE_ROUTE.md:1010), et deux vérificateurs y voient une limite de couverture plutôt qu'une erreur. Dates : 2025-10-08 (Israël), 2025-10-09 à 2025-10-13, 2026-04-03 (Israël), 2026-04-05 à 2026-04-07.
- **Ce que dit la source** : en 'Hol hamoed, on dit le Moussaf de la fête ; la formule varie selon le rite (Rema O.H. 490:3). *Kitsour Yalkut Yosef, siman 490, se'if 2 ('Hazon Ovadia Pessa'h, éd. 5763, p. 89) ; siman 662, se'if 1 ; Choul'han Aroukh O.H. 490:2*. « מתפללים מוסף בחול המועד, ואומרים "את יום מקרא קודש הזה" » ; « ובמוסף מתפלל כדרך שמתפלל במוסף של י"ט ».
- **Correction proposée** : en Edot et en Ashkenaz, afficher une consigne ou un renvoi informatif : « Moussaf de fête : texte absent de l'application ». Comme `vrai()` n'accepte qu'une clé et que `moed` est vrai aussi les jours de Yom tov (CalendrierJuif.kt:319), il faut pour cela une clé dérivée, par exemple `hol_hamoed`. Ne pas réutiliser `moussaf_rosh_hodech`, qui n'est pas le bon texte.

### Edot : ברכי נפשי absent du matin de Roch 'Hodech, et psaume de 'Hanouka placé avant Moussaf
**Erreur de l'app** · gravité basse · Edot · tous lieux

- **Ce que fait l'app** : dans siddur_edot.json, le psaume 104 n'existe qu'à Arvit [0:0-1] (« בליל ראש חודש יש הנוהגים לומר »). `moussaf_rosh_hodech` se termine au Kaddich titkabal (b42-47), puis Cha'harit reprend à « קוה ». Rien ne propose ce psaume le matin, alors que Sfard (s16) et Ashkenaz ([6:50]-[6:57]) l'ont. À Roch 'Hodech Tévèt, le Ps. 30 de 'Hanouka ([15:17-18]) est en clair dans le Chir chel yom, donc avant Moussaf. Dates : 2025-10-23, 2025-11-21, 2025-12-21, 2026-01-19, 2026-06-15/16, 2026-08-13, 2026-11-10/11, 2026-12-10/11.
- **Ce que dit la source** : après la répétition de Moussaf et le Kaddich, on dit ברכי נפשי. À Roch 'Hodech Tévèt, le psaume de 'Hanouka vient ensuite. Le siddour source de l'app (Siddur Edot HaMizrach, Sefaria, « Rosh Hodesh, Barchi Nafshi ») contient ce passage ; c'est l'import (siddur_construction.py:390) qui l'a laissé de côté. *Kitsour Yalkut Yosef, siman 423 « תפלת מוסף בראש חודש », se'if 5 (Yalkut Yosef Chabbat V p. 307) ; siman 683, se'if 11 ; Choul'han Aroukh O.H. 423:3*. « ואחר שסיים חזרת התפלה אומר קדיש תתקבל, ואומר מזמור ברכי נפשי את ה' וכו', משום שנזכר בו עשה ירח למועדים » ; « ובראש חודש טבת אומרים אותו אחר תפלת מוסף, אחר מזמור "ברכי נפשי" ».
- **Correction proposée** : importer le passage Sefaria « Barchi Nafshi » (consigne « אומרים ברכי נפשי », psaume, Kaddich יהא שלמא) à la fin de `moussaf_rosh_hodech` Edot, sous `roch_hodech`. Ne pas simplement renvoyer au bloc d'Arvit, dont la consigne vise le soir. Étendre web/test/repli.test.mjs au matin Edot. Quand `roch_hodech` et `hanouka` sont réunis, déplacer le Ps. 30 après ce psaume. L'emplacement du Ps. 30 relève toutefois d'une différence entre poskim : le siddour source et le Ben Ich 'Haï le placent avant Moussaf. Facultatif : une note sur l'en-tête « השיר שהיו הלוים » à 'Hanouka (Kitsour YY 683:10).

### Kaddich autour de Moussaf à Roch 'Hodech : titkabal après ובא לציון et demi-Kaddich manquant avant Moussaf
**Erreur de l'app** · gravité basse · Edot, Ashkenaz · tous lieux

- **Ce que fait l'app** :
  - En Edot, le Kaddich titkabal qui suit ובא לציון ([13:2]-[13:6]) reste dit à Roch 'Hodech : les blocs [13:4]-[13:6] n'ont aucune annotation. תתקבל est donc dit trois fois (après le Hallel, après ובא לציון, après Moussaf). Seul le Kaddich יהא שלמא [15:26-28] précède Moussaf.
  - En Ashkenaz, le renvoi Moussaf, posé après [6:13], ouvre un Moussaf sans aucun Kaddich devant.
  - En Sfard, la consigne [13:16] prescrit déjà le seul demi-Kaddich ; replier [13:20]-[13:22] n'y serait qu'un confort.
  - Dates : 2025-10-23, 2025-11-21, 2025-12-21, 2026-11-10/11.
- **Ce que dit la source** : on ôte les tefilin après le demi-Kaddich qui précède Moussaf. Les jours de Moussaf, le titkabal se dit après la répétition de Cha'harit et le Hallel. *Kitsour Yalkut Yosef, siman 423 « תפלת מוסף בראש חודש », se'ifim 2 et 5, et siman 132, se'if 7 ; Michna Beroura 423:4 et 423:8*. « ויחלצום אחר אמירת חצי קדיש, ולא קודם הקדיש » ; « ואח"כ אשרי ובא לציון וחצי קדיש בשביל הפסוקים של אשרי ובא לציון ».
- **Correction proposée** : ne viser que `roch_hodech`, puisque l'app n'a pas de renvoi Moussaf pour les jours de fête.
  - En Edot : replier tout le Kaddich [13:2]-[13:6] à Roch 'Hodech, et mettre un demi-Kaddich avant le renvoi Moussaf, à la place du Kaddich יהא שלמא [15:26-28].
  - En Ashkenaz : ajouter un demi-Kaddich (condition `roch_hodech`) avant le renvoi posé après [6:13], ou en tête de `moussaf_rosh_hodech`. Garder [6:14]-[6:21] comme Kaddich d'après Moussaf. La correction initiale, qui déplaçait le renvoi et repliait [6:19], était fausse.

### « ולכפרת פשע » en Sfard et en Ashkenaz : l'app suit l'usage de ses siddourim (jusqu'à Nissan)
**Différence entre poskim** · gravité basse · Sfard, Ashkenaz · tous lieux

- **Ce que fait l'app** : la condition `embolismique_avant_nissan` (web/src/js/calendrier-juif.js:149-151) suit la consigne des deux siddourim, « בשנת העיבור עד חודש ניסן » (Ashkenaz moussaf s3 b4, Sfard b13). L'ajout est dit du 2026-10-11 au 2027-03-10, puis retiré dès le 2027-04-08 et pendant toute l'année simple 5786. Le commentaire du code parle de « deux usages ».
- **Ce que dit la source** : le Michna Beroura rapporte trois usages et laisse chaque lieu suivre le sien. *Michna Beroura 423:6*. « וכן יש אומרים ולכפרת פשע ויש שאינם אומרים רק בשנת העיבור ואפילו בשנת העיבור יש שאינם אומרים אותו אלא עד כלות חודש העיבור דהיינו עד אחר חודש אדר ובכל אלה נהרא נהרא ופשטיה ».
- **Correction proposée** : rien à changer au comportement. Corriger le commentaire (« trois usages ») dans web/src/js/calendrier-juif.js:145-147, CalendrierJuif.kt:321-323 et tools/siddur_annotations.py:108-111. On peut aussi proposer les autres usages en option.

### Sfard : bénédiction du Hallel partiel sans nuance pour qui prie avec un minyan
**Différence entre poskim** · gravité basse · Sfard · tous lieux

- **Ce que fait l'app** : libelleHallel (web/src/js/siddur-jour.js:71-75 ; SiddurJour.kt:274-279) affiche « Hallel partiel, avec bénédiction » en Sfard. La bénédiction « לקרא את ההלל » [0:1] et יהללוך [0:23] restent en clair, sans nuance pour qui prie en minyan. Dates : 2025-10-22, 2026-04-05 à 2026-04-08.
- **Ce que dit la source** : le Siddour Admour, lu en traduction anglaise seulement, veut qu'en minyan seul l'officiant bénisse. Le Choul'han Aroukh haRav (619:8) et l'usage 'hassidique répandu font bénir chacun à voix basse. *Rema O.H. 422:2 ; shulchanaruchharav.com, « Blessing over Hallel », notes 11, 14 et 15 sur O.H. 422:2 ; Choul'han Aroukh haRav O.H. 619:8*. « ויש אומרים דגם יחיד מברך עליו (טור בשם הרא"ש ור"ת) וכן נוהגין במדינות אלו » ; « לָכֵן יְבָרֵךְ כָּל אֶחָד וְאֶחָד לְעַצְמוֹ בְּלַחַשׁ… וְכֵן הַדִּין בְּבִרְכַּת הַלֵּל ».
- **Correction proposée** : aucune n'est nécessaire. On peut ajouter une précision : « en minyan, d'après le Siddour Admour, l'officiant bénit pour tous ».

#### Constats écartés

- **Edot de diaspora : certaines communautés bénissent sur le Hallel de Roch 'Hodech** : l'app suit le Yalkut Yosef, référence choisie pour les Edot, qui ne prévoit pas d'exception pour la diaspora. Le constat lui prêtait une restriction à Israël qu'il ne formule pas. Le vrai défaut, la bénédiction affichée en clair, est traité dans « Edot : la bénédiction du Hallel partiel n'est pas repliée ».


---

## Structure des offices (Cha'harit, Min'ha, Arvit)

### מזמור לתודה affiché la veille de Pessa'h, pendant Pessa'h et la veille de Kippour
**Erreur de l'app** · gravité moyenne · Sfard, Ashkenaz · tous lieux
- **Ce que fait l'app** : la consigne et le psaume (siddur_sefard chaharit S5 b13-14, siddur_ashkenaz chaharit S1 b15-16) n'ont aucune annotation dans siddur_annotations.json. Ils restent donc en clair la veille de Pessa'h (2026-04-01, 2027-04-21), à 'Hol hamoed Pessa'h (2026-04-05 à 04-07 ; 2026-04-03 en Israël) et la veille de Kippour (2025-10-01, 2026-09-20, 2027-10-10), en diaspora, en Israël et à Jérusalem. Pourtant, l'app replie déjà למנצח ces mêmes jours (calendrier-juif.js:137-138).
- **Ce que dit la source** : le Rema exclut le psaume le Chabbat, le Yom tov, pendant Pessa'h, la veille de Pessa'h et la veille de Kippour. Le Choul'han Aroukh haRav dit de même pour le Sfard. Les Edot le disent ces jours-là (Kitsour Yalkut Yosef 51:32, 468:14 et 604:9), et pour eux l'app est conforme. *Choul'han Aroukh O.H. 51:9 (Rema) ; Michna Beroura 51:22 et 604:4 ; Choul'han Aroukh haRav O.H. 51:1*. « או בימי פסח שאין תודה קריבה בהם משום חמץ ולא בערב פסח וע"ל סי' תכ"ט ולא בעיו"כ »
- **Correction proposée** : créer une condition (par exemple `mizmor_letoda`), posée en Sfard et en Ashkenaz seulement. Elle serait fausse le Chabbat, le Yom tov, pendant tout Pessa'h, la veille de Pessa'h et la veille de Kippour. Y rattacher la consigne et le psaume dans tools/siddur_annotations.py, sans rien changer en Edot. Les vérificateurs précisent que la consigne du siddour est un Rema tronqué qui s'arrête à « ולא בערב פסח ». Pour la veille de Kippour, il faut donc s'appuyer sur le Rema et sur le Choul'han Aroukh haRav. C'est d'ailleurs le cas le plus net, puisque rien n'y avertit le lecteur.

### Edot : « שעשה לי כל צרכי » replié le 9 Av et à Kippour, contre le Yalkut Yosef
**Erreur de l'app** · gravité moyenne · Edot · tous lieux
- **Ce que fait l'app** : tools/siddur_annotations.py:273-279 reprend la consigne du siddour Edot (« בתשעה באב ויום הכיפורים אין אומרים ברכה זו (בא״ח וישב ה״ט) »). Il rattache la consigne et la bénédiction (birkot_hachahar s1 b14-15) à `!ticha_beav_kippour` (calendrier-juif.js:128). Les deux sont donc repliées le 9 Av (2026-07-23, 2027-08-12, 2025-08-03, et 2029-07-22 pour le jeûne repoussé) et à Kippour (2026-09-21), dans tous les lieux. L'app suit ainsi le Ben Ich 'Haï, et non le Yalkut Yosef choisi comme référence pour ce rite.
- **Ce que dit la source** : le Yalkut Yosef fait dire la bénédiction ces deux jours. Rav Ovadia Yossef est revenu sur ce qu'il écrivait dans le Yabia Omer (5:25). *Kitsour Yalkut Yosef O.H. 46:12 ; 559:8 ; 620:2*. « לפיכך אפשר לברך ברכה זו גם בתשעה באב וביום הכפורים »
- **Correction proposée** : garder le pli, mais y ajouter « Yalkut Yosef : on la dit (וכן המנהג) ». On peut aussi créer un réglage Edot sur le modèle de `sansTahanounFinTichri`, avec le Yalkut Yosef par défaut. Les vérificateurs nuancent ce point. Le Yalkut Yosef formule une permission (« אפשר לברך ») et rapporte l'usage contraire (« יש נוהגים... אין מברכים »). Le « וכן המנהג » ne figure qu'en 620:2 (Kippour). Un vérificateur classe donc le point en différence entre poskim : le Ben Ich 'Haï (Vayéchev 9, à la suite du Ari) s'oppose au Yalkut Yosef.

### Motsaé Chabbat avant un Yom tov dans la semaine : ויהי נועם et ואתה קדוש affichés
**Erreur de l'app** · gravité moyenne · Sfard, Ashkenaz · tous lieux
- **Ce que fait l'app** : `motsae_chabbat` ne dépend que du dimanche (calendrier-juif.js:116 ; CalendrierJuif.kt:290). Les sections « ערבית למוצאי שבת » (Sfard arvit S2) et « תוספות למוצאי שבת » (Ashkenaz arvit S5) ne dépendent que d'elle (tools/siddur_annotations.py:157). ויהי נועם et ואתה קדוש s'ouvrent donc même quand un Yom tov ou Kippour tombe dans la semaine. Exemples de jours de prière : 2025-09-21, 2025-09-28, 2025-10-05, 2025-10-12, 2026-03-29, 2026-04-05, 2026-05-17 (Chavouot un vendredi), 2026-09-20, 2027-04-18 et 2027-06-06, en diaspora comme en Israël.
- **Ce que dit la source** : en Ashkenaz et en Sfard, on ne dit ni ויהי נועם ni le סדר קדושה dans ce cas, même si le Yom tov tombe un vendredi (MB 295:3 : « היינו אפילו חל ביום וי"ו »). Les Edot les disent (Kitsour Yalkut Yosef 294:7), et pour eux l'app est conforme. *Rema O.H. 295:1 ; Michna Beroura 295:3 ; Choul'han Aroukh haRav O.H. 295:3*. « ובזמן שאין אומרים ויהי נועם כגון שחל יום טוב בשבוע אין אומרים סדר קדושה אבל אומרים ויתן לך »
- **Correction proposée** :
  - Créer une condition `yom_tov_semaine`, vraie si un Yom tov ou Kippour tombe du dimanche au vendredi. Pourim et la veille de Pessa'h ne comptent pas (MB 295:3). Elle doit aussi couvrir le motsaé Chabbat de 'Hol hamoed.
  - En Sfard et en Ashkenaz, n'ouvrir ces passages que sous `motsae_chabbat && !yom_tov_semaine`. En Ashkenaz, cela vise toute la section S5. En Sfard, seulement S2 b0-10 : le titkabal et עלינו (b11-24) restent ouverts.
  - Ne rien changer en Edot.
  - La consigne « במוצאי שבת אומר חצי קדיש... » (Sfard arvit S1 b96, Ashkenaz S4 b0) doit suivre la même condition.
  - Les vérificateurs signalent que ויתן לך ne figure dans aucun siddour de l'app. Il faut soit l'ajouter, soit le signaler.

### Arvit du 9 Av : ויהי נועם affiché un motsaé Chabbat, ואתה קדוש replié en semaine
**Erreur de l'app** · gravité moyenne · tous les noussa'h · tous lieux
- **Ce que fait l'app** : les passages du motsaé Chabbat ne dépendent que de `motsae_chabbat` (tools/siddur_annotations.py:156 et :305). Quand le 9 Av commence au motsaé Chabbat, ויהי נועם et ישב בסתר (avec שובה chez les Edot) s'affichent donc en clair dans les trois rites, à l'Arvit du 2025-08-02 au soir et du 2029-07-21 au soir (10 Av, jeûne repoussé). À l'inverse, ואתה קדוש ne se trouve que dans cette section. Il est donc replié les soirs de 9 Av en semaine (Arvit de 2026-07-23, 2027-08-12 et 2028-08-01).
- **Ce que dit la source** : après Ekha, on dit le סדר קדושה à partir de ואתה קדוש. Si le 9 Av tombe un motsaé Chabbat, on ne dit pas ויהי נועם, et selon le Rema, pas non plus ויתן לך. *Choul'han Aroukh O.H. 559:2 et Rema ; Michna Beroura 559:7 ; Kitsour Yalkut Yosef 556:3*. « ואומר אחר קינות ואיכה סדר קדושה ומתחיל מואתה קדוש ואם חל במ"ש אין אומרים ויהי נועם »
- **Correction proposée** : découper la section en annotations par bloc.
  - ויהי נועם et ישב בסתר (Ashkenaz 5:0-1, Sfard 2:3-4, Edot 2:56-57) : sous `motsae_chabbat && !ticha_beav`.
  - ואתה קדוש et la suite : sous `motsae_chabbat || ticha_beav`, avec un renvoi « après Ekha ».

  Les vérificateurs relèvent deux points. Le repli de ואתה קדוש en semaine tient d'abord à l'absence d'Ekha dans l'app, ce qui le rend moins grave. Et toutes les sources lues ne tranchent pas le sort de ישב בסתר.

### Téfilin affichés à 'Hol hamoed (et à Yom tov) sans réserve
**Erreur de l'app** · gravité moyenne · Edot, Ashkenaz · tous lieux
- **Ce que fait l'app** : la pose des téfilin n'a aucune annotation : Edot chaharit S2 (bénédiction « להניח תפלין ») et Ashkenaz chaharit S0 b17-26 (bénédictions b19 et b21). Elle reste en clair à 'Hol hamoed : 2025-10-09 à 10-13, 2026-04-05 à 04-07, 2026-10-01, et en Israël 2025-10-08 et 2026-04-03. Elle reste aussi en clair à Yom tov (2026-04-09 en diaspora). En Ashkenaz, le matin du 9 Av (2026-07-23), le talit (b13-16) et les téfilin restent en clair eux aussi. Le siddour Sfard n'a pas de section de téfilin.
- **Ce que dit la source** : les Edot ne mettent pas les téfilin à 'Hol hamoed, et qui vient en Israël suit l'usage du pays. Personne ne les met à Yom tov. Le 9 Av au matin, on ne met ni talit ni téfilin (Choul'han Aroukh 555:1). Chez les Edot, l'usage du 9 Av est conforme (Yalkut Yosef 555:1). *Kitsour Yalkut Yosef 31:6 ; Choul'han Aroukh O.H. 31:1-2 et 555:1*. « המנהג פשוט שאין מניחין תפילין בחול המועד »
- **Correction proposée** :
  - Edot : replier S2 (les téfilin) sous `!moed`. Cette condition existe déjà et couvre 'Hol hamoed et Yom tov. Ne pas replier S1 (le talit).
  - Ashkenaz en Israël : replier b17-26 quand `moed` est vrai.
  - Ashkenaz le 9 Av : replier S0 b13-29 sous `!ticha_beav`, avec un renvoi à Min'ha.
  - Ashkenaz en diaspora à 'Hol hamoed : ne pas replier. C'est une différence entre poskim : le Rema fait mettre les téfilin avec bénédiction à voix basse, la Michna Beroura 31:8 dit « דיותר טוב להניחן בלי ברכה ». Ajouter seulement une précision sur les deux bénédictions.

### Chabbat et Yom tov : le siddour de semaine est servi sans avertissement
**Erreur de l'app** · gravité moyenne · tous les noussa'h · tous lieux
- **Ce que fait l'app** : seuls les offices de semaine existent, et rien ne dit qu'ils ne valent pas le Chabbat ou le Yom tov. La carte « Pour cette heure » propose même Cha'harit le Chabbat matin.
  - Mizmor letoda et l'Amida de semaine restent en clair le Chabbat (2026-11-21) et à Yom tov (2026-05-22, 2026-09-21). En Edot, ברכנו s'ouvre même le Chabbat.
  - Le samedi soir qui est Yom tov, אתה חוננתנו et la section du motsaé Chabbat s'ouvrent : soir du Séder 2025-04-12, 2026-09-26 en diaspora, 2029-05-19. La cause : `motsae_chabbat` et `motsae_chabbat_yt` ne dépendent que du jour de la semaine (calendrier-juif.js:116 et 158).
- **Ce que dit la source** : le Chabbat et le Yom tov, on ne dit pas Mizmor letoda (Kitsour Yalkut Yosef 281:6). Un Yom tov qui commence au motsaé Chabbat se prie avec ותודיענו, sans les ajouts d'un soir ouvrable. *Choul'han Aroukh O.H. 491:2 ; Kitsour Yalkut Yosef 281:6*. « יום טוב שחל להיות במוצאי שבת אומר באתה בחרתנו ותודיענו »
- **Correction proposée** :
  - Quand `chabbat` ou `yom_tov` est vrai, afficher en tête des offices « siddour de semaine : texte de Chabbat / Yom tov non fourni ». Ne pas montrer la carte « Pour cette heure » ces jours-là.
  - Ne pas poser `motsae_chabbat` ni `motsae_chabbat_yt` quand le jour est un Yom tov chômé.

  Un vérificateur juge le point hors périmètre et le classerait en gravité basse : l'app n'a pas d'office de fête et se met en pause ces jours-là. En Sfard et en Ashkenaz, la consigne affichée avant Mizmor letoda atténue le défaut. Le même vérificateur relève un vrai défaut connexe : ajouts() (jour-affiche.js:23-26 et 39-42, JourAffiche.kt:51) n'exclut la 9ᵉ bénédiction et le Ta'hanoun que le Chabbat, pas le Yom tov.

### Jeûnes publics : aucune lecture de la Torah ni haftara à Min'ha
**Erreur de l'app** · gravité moyenne · tous les noussa'h · tous lieux
- **Ce que fait l'app** : aucun des trois Min'ha n'a de section ni de renvoi de lecture : Edot [קרבנות, עמידה, וידוי, עלינו], Sfard [קרבנות, עמידה, תחנון, אבינו מלכנו], Ashkenaz [אשרי, עמידה, אחר העמידה, סיום תפילה]. La condition `kriat_hatorah` ne sert qu'à Cha'harit (calendrier-juif.js:121 ; CalendrierJuif.kt:297). Les jours de jeûne, Min'ha ouvre bien עננו et ברכת כהנים, mais ne dit rien de ויחל ni de la haftara : 2025-12-30, 2026-12-20, 2025-01-10 (un vendredi), 2026-03-02, 2026-07-02, et le 9 Av 2026-07-23.
- **Ce que dit la source** : on lit ויחל à Cha'harit et à Min'ha, même un vendredi. Le Rema ajoute la haftara « דרשו » à Min'ha. Les Séfarades ne lisent de haftara à aucun jeûne public, sauf le 9 Av (Kitsour Yalkut Yosef 550:40). *Choul'han Aroukh O.H. 566:1 et Rema ; Kitsour Yalkut Yosef 550:39-40*. « וקורים ויחל בשחרית ובמנחה בין שחל בשני ובחמישי בין שחל בשאר הימים »
- **Correction proposée** : à Min'ha, entre Achré (avec le demi-Kaddich) et l'Amida, ajouter une section ou une consigne repliable sous la condition `jeune`, 9 Av compris. Elle indiquerait « הוצאת ספר תורה – ויחל, trois montées » et renverrait aux bénédictions de la section קריאת התורה de Cha'harit.
  - Haftara « דרשו » en Ashkenaz et en Sfard, les jeûnes autres que le 9 Av. Pour le Sfard, c'est l'usage courant, non vérifié sur une source primaire.
  - Haftara « שובה ישראל » le 9 Av, dans les trois rites.
  - Pas de haftara en Edot les autres jeûnes.

### Sfard : « שעשה לי כל צרכי » reste affiché le 9 Av et à Kippour malgré la consigne du siddour
**Erreur de l'app** · gravité basse · Sfard · tous lieux
- **Ce que fait l'app** : la regex de tools/siddur_annotations.py:275 ne reconnaît que la formule Edot. La consigne Sfard « בט׳ אב ויוה״כ אין אומרים ברכה זו: » (birkot_hachahar s2 b19, chaharit s1 b19) n'est donc pas annotée. La bénédiction (b20) reste en clair le 9 Av (2026-07-23, 2025-08-03, 2029-07-22) et à Kippour (2025-10-02, 2026-09-21, 2024-10-12). La consigne reste affichée juste au-dessus.
- **Ce que dit la source** : le siddour Sfard de l'app exclut la bénédiction ces jours-là. La Michna Beroura 554:31 la permet (« הסכימו הרבה אחרונים שיוכל לברך »). Chez les 'hassidim, l'usage est partagé : Habad l'omet, Breslev la dit le 9 Av d'après une source secondaire. *Consigne du siddour Sfard de l'app (birkot_hachahar S2 b19) ; Michna Beroura 554:31*. « בט׳ אב ויוה״כ אין אומרים ברכה זו »
- **Correction proposée** : étendre la regex à la formule Sfard pour poser un repli discret `!ticha_beav_kippour` sur sefard birkot_hachahar 2:19-20 et chaharit 1:19-20, en signalant l'usage contraire (Michna Beroura, Breslev). Si l'utilisateur ne tranche pas, garder l'affichage actuel avec la précision « usage partagé ». L'Ashkenaz reste en clair. Un vérificateur classe le point en différence entre poskim à l'intérieur du rite Sfard.

### לדוד ה׳ אורי : début le 1er Eloul au lieu du 30 Av, et fin le 21 Tichri au lieu de Chemini Atséret
**Erreur de l'app** · gravité basse · Ashkenaz (et Sfard pour le début) · tous lieux (fin : diaspora)
- **Ce que fait l'app** : la condition `ledavid` vaut pour Eloul et pour Tichri jusqu'au 21 (calendrier-juif.js:139 ; CalendrierJuif.kt:315).
  - Le psaume est donc replié le 30 Av (2026-08-13, 2027-09-02, 2025-08-24).
  - En Ashkenaz, il est replié à Cha'harit du 22 Tichri et à l'Arvit de la veille au soir (2025-10-14, 2026-10-03, 2024-10-24).
  - L'app suit la consigne de son siddour : « ובפרט מר״ח אלול עד הושענא רבא (מורה באצבע סי׳ לז) ».
- **Ce que dit la source** : la Michna Beroura (avec le Maté Efraïm 581:6) le fait dire dès Roch 'Hodech Eloul, jusqu'à Chemini Atséret inclus. Le Kitsour Choul'han Aroukh 128:2 commence au 2ᵉ jour de Roch 'Hodech, le 1er Eloul. 'Habad commence le 30 Av. *Michna Beroura 581:2 ; Kitsour Choul'han Aroukh 128:2*. « ואנו נוהגין לומר עד שמע"צ ועד בכלל »
- **Correction proposée** : corrigée par les vérificateurs.
  - Début : ne pas inclure le 30 Av, car l'app suit le Kitsour Choul'han Aroukh. Tout au plus une précision « usage 'Habad » en Sfard ce jour-là.
  - Fin : poser `ledavid` le 22 Tichri en Ashkenaz de diaspora seulement (conditionsPour, Ashkenaz hors d'Israël), avec une précision, puisque la consigne du siddour dit « עד הושענא רבא ». Ne pas l'étendre en Israël : le Chévèt haLévi (cité de seconde main) et l'usage ashkénaze israélien s'arrêtent à Hochaana Rabba.
  - Autre défaut relevé : en Sfard, le לדוד de Min'ha n'est pas annoté `ledavid`. Il se replie avec la section Ta'hanoun.

### Passages réservés au minyan laissés en clair (Modim derabanan, fin du Kaddich titkabal, réponse à Barekhou)
**Erreur de l'app** · gravité basse · tous les noussa'h · tous lieux
- **Ce que fait l'app** : chaque jour, minyan() (tools/siddur_annotations.py:705-760) laisse en clair quatre types de passages.
  - Modim derabanan en Sfard et en Ashkenaz (chaharit S8 b94-95 et S3 b68-69 ; Min'ha), car leur consigne n'est pas reconnue (:744).
  - La fin du Kaddich titkabal (« תתקבל / יהא שלמא / עושה שלום »), car « תתקבל » manque à la liste KADDICH (:836).
  - La réponse à Barekhou en fin d'Arvit Edot (S2 b70-71).
  - Les Kaddich inclus dans une section du jour : Vidouï Edot, Ta'hanoun de Min'ha, לדוד Ashkenaz S6 b60-66.

  Les Kaddich du Hallel et de Birkat halevana échappent même à minyan() (:668).
- **Ce que dit la source** : ni le Kaddich, ni la Kedoucha, ni Barekhou ne se disent à moins de dix. Modim derabanan n'existe que dans la répétition de l'officiant (Choul'han Aroukh O.H. 127:1). *Choul'han Aroukh O.H. 55:1*. « אומרים קדיש וא"א אותו בפחות מי' זכרים ... וה"ה לקדושה וברכו שאין נאמרין בפחות מעשרה »
- **Correction proposée** : six changements.
  - Ajouter « תתקבל » à KADDICH.
  - Reconnaître la consigne « כשיגיע שליח צבור למודים ».
  - Accepter « והקהל עונים: » et « וחוזרים: » après Barekhou.
  - Permettre une annotation `minyan` à l'intérieur des sections du jour, ce qui suppose d'autoriser une double annotation, ou bien sortir ces Kaddich des sections.
  - Étendre minyan() à birkat_halevana et à hallel.

### Cha'harit du 9 Av : ואני זאת בריתי, פטום הקטורת et le Kaddich titkabal restent affichés
**Erreur de l'app** · gravité basse · tous les noussa'h · tous lieux
- **Ce que fait l'app** : le 9 Av (2026-07-23, 2027-08-12, 2025-08-03, 2029-07-22), ובא לציון forme un seul bloc, affiché en clair avec ואני זאת בריתי (Edot chaharit S13 b0, Sfard S13 b5, Ashkenaz S6 b4). En Ashkenaz, פטום הקטורת de fin d'office (S6 b69-71) et תתקבל (S6 b19) restent aussi en clair. Chez les Edot, תתקבל reste en clair à l'Arvit de la nuit du 9 Av (S2 b62). למנצח, lui, est bien replié.
- **Ce que dit la source** : on saute ואני זאת בריתי dans tous les rites. En Ashkenaz, on ne dit ni תתקבל ni פטום הקטורת (Rema 559:4). Chez les Edot, on omet תתקבל la nuit seulement (Kitsour Yalkut Yosef 559:7). *Kitsour Yalkut Yosef 559:14 ; Kitsour Choul'han Aroukh 124:3 ; Rema O.H. 559:4*. « אחר ההפטרה בשחרית אומרים אשרי ובא לציון, ומדלגין ואני זאת בריתי וכו' עד ואתה קדוש »
- **Correction proposée** :
  - Dans les trois siddourim, ajouter une annotation « indice » sous `ticha_beav` qui retire le verset « ואני זאת בריתי… ».
  - En Ashkenaz, mettre פטום הקטורת (S6 b69-71) et le seul bloc תתקבל (S6 b19) sous `!ticha_beav`. Les blocs b20-21 se disent, car on dit un « קדיש שלם בדלוג תתקבל ».
  - En Edot, replier תתקבל la nuit seulement (arvit S2 b60-62), pas à Cha'harit.

  Les vérificateurs rangent deux points parmi les différences entre poskim : le פטום des korbanot (S0 b112), et le psaume du jour remis à Min'ha (Kitsour Choul'han Aroukh 124:3 et 124:19). En Sfard, l'usage est partagé.

### Motsaé Chabbat (Sfard, Ashkenaz) : la fin d'Arvit et Alénou affichés deux fois
**Erreur de l'app** · gravité basse · Sfard, Ashkenaz · tous lieux
- **Ce que fait l'app** : le samedi soir (jour de prière 2026-11-15), la fin d'Arvit de semaine reste en clair et la section du motsaé s'ouvre en plus. tools/siddur_annotations.py ne traite ce cas que pour les Edot.
  - En Sfard, le titkabal et עלינו paraissent deux fois : S1 b100-102 et b113-115, puis S2 b14 et b17-19.
  - En Ashkenaz, rien n'est doublé, mais תתקבל (S4 b6-8) est mal placé : il reste avant ויהי נועם et manque après ואתה קדוש.
- **Ce que dit la source** : la consigne du siddour de l'app (Sfard arvit S1 b96, Ashkenaz S4 b0) place ויהי נועם et ואתה קדוש juste après le demi-Kaddich. Le Rema le confirme : « ואומרים ויהי נועם וסדר קדושה באריכות ». *Consigne des siddourim Sfard et Ashkenaz de l'app ; Rema O.H. 295:1 ; Michna Beroura 295:2*. « במוצאי שבת אומר חצי קדיש ואחר כך אומרים הקהל ויהי נעם ואתה קדוש »
- **Correction proposée** : ne pas replier sous un simple `!motsae_chabbat`. Il faut une condition « on dit ויהי נועם » : `motsae_chabbat` sans Yom tov dans la semaine, et hors 9 Av (voir les deux constats sur ויהי נועם).
  - Quand elle est vraie : replier Sfard S1 b100-120 et Ashkenaz S4 b6-8, et reprendre le titkabal ashkénaze après S5.
  - Quand elle est fausse : replier S2 et S5.

### Jeûnes publics (Ashkenaz) : la consigne des Seli'hot est repliée avec le Hallel
**Erreur de l'app** · gravité basse · Ashkenaz · tous lieux
- **Ce que fait l'app** : la consigne de Cha'harit s3 b92 (« בר״ח וחולו של מועד וחנוכה אומרים כאן הלל … בת״צ אומרים סליחות ») est annotée `si=hallel` (règle « אומרים כאן הלל », tools/siddur_annotations.py:624). Elle est donc repliée justement les jours de jeûne : 2025-12-30, 2026-12-20, 2026-07-02, 2027-07-22. Sa 3ᵉ phrase (demi-Kaddich les jours sans Ta'hanoun) est aussi repliée les jours sans Hallel ni Ta'hanoun (2026-02-02). En Sfard, la même consigne reste lisible.
- **Ce que dit la source** : aux jeûnes publics, on dit des Seli'hot, et l'usage retenu les place après l'Amida. *Choul'han Aroukh O.H. 566:4 ; Michna Beroura 566:16*. « ויש שאין נוהגין לומר סליחות עד אחר סיום י"ח ברכות »
- **Correction proposée** : découper la consigne en trois annotations (`hallel` / `jeune` / `!tahanoun_chaharit`) ou la laisser en clair, puis régénérer siddur_annotations.json. La citation du Choul'han Aroukh 566:7 est abandonnée : cet usage a cessé (Michna Beroura 566:22).

### Edot : psaume 22 absent d'Arvit la nuit de Pourim
**Erreur de l'app** · gravité basse · Edot · tous lieux
- **Ce que fait l'app** : le psaume 22 ne figure qu'au Chir chel yom de Cha'harit (chaharit s15:19-20, `si='esther_pourim'`), ce qui est conforme pour le jour. L'Arvit Edot ne le contient pas et n'y renvoie pas, les soirs de 2026-03-02, 2026-03-03 (Jérusalem), 2027-03-22, 2025-03-13 et 2029-02-28. Le défaut vient du siddour source, qui ne prévoit pas ce psaume la nuit.
- **Ce que dit la source** : le psaume se dit avant Arvit la nuit de Pourim. *Kitsour Yalkut Yosef O.H. 693:1*. « ואומרים מזמור ״על אילת השחר״ לפני תפלת ערבית שהוא מענין היום »
- **Correction proposée** : ajouter en arvit, section 0, avant le demi-Kaddich, un renvoi vers chaharit s15:20, ou un bloc avec la consigne « בליל פורים אומרים קודם ערבית ».
  - Le placer sous `pourim`, et non sous `esther_pourim`, pour exclure la veille du jeûne d'Esther.
  - Pour Pourim triple à Jérusalem (soir du 2025-03-13), `pourim` ne couvre pas ce soir-là. Il faut s'aligner sur megilaDuMoment ou créer une condition dédiée.

### Edot : לדוד ה׳ אורי affiché toute l'année, sans lien avec Eloul
**Différence entre poskim** · gravité basse · Edot · tous lieux
- **Ce que fait l'app** : le psaume (siddur_edot chaharit S17 b4, après עלינו) n'a ni consigne ni annotation. Il reste en clair toute l'année : 2026-01-15, 2027-01-05, et du 22 au 30 Tichri (2025-10-14 à 10-22). La règle `ledavid` (tools/siddur_annotations.py:344-356) part de la consigne « מנהג טוב… », absente du siddour Edot (Torat Emet), qui imprime le psaume chaque jour.
- **Ce que dit la source** : le Yalkut Yosef en fait un bel usage d'Eloul à Hochaana Rabba, sans l'interdire le reste de l'année. Le 'Hida (Moré beEtsba 37) le recommande après chaque prière toute l'année. *Kitsour Yalkut Yosef, « עוד בהלכות חודש אלול » §2 (après le siman 581)*. « מנהג יפה לומר אחר תפלת שחרית מראש חודש אלול עד הושענא רבא מזמור ״לדוד ה' אורי וישעי ממי אירא״ »
- **Correction proposée** : facultative. Ajouter une règle Edot propre (empreinte « לדוד … יהוה אורי ») qui annote S17 b4 `si='ledavid'` en discret, puis étendre web/test/repli.test.mjs au rite Edot.

### Ashkenaz : second לדוד ה׳ אורי à Arvit seulement, pas à Min'ha
**Différence entre poskim** · gravité basse · Ashkenaz · tous lieux
- **Ce que fait l'app** : le siddour Ashkenaz (Metsudah) n'a le psaume qu'à Cha'harit (S6 b58-66) et à Arvit (S9), sous `ledavid`. Min'ha (S3) se termine par עלינו et le Kaddich. C'est le cas chaque jour d'Eloul (par exemple du 2025-08-25 au 2025-10-13).
- **Ce que dit la source** : la Michna Beroura, à la suite du Maté Efraïm 581:6, place le psaume du soir après Min'ha. D'autres communautés le disent après Arvit, et c'est l'usage que suit l'app. *Michna Beroura 581:2 ; Maté Efraïm 581:6*. « ובערב אחר תפלת המנחה »
- **Correction proposée** : rien d'obligatoire. On peut ajouter un réglage ou une note en fin de Min'ha (« selon la Michna Beroura, après Min'ha »). La référence au Louah Ezras Torah (« after Maariv ») a été lue par un vérificateur, pas par l'autre.

### Edot : le Sefer Torah rendu à l'arche après ובא לציון et non juste après la lecture
**Différence entre poskim** · gravité basse · Edot · tous lieux
- **Ce que fait l'app** : le siddour Edot place « ומחזירין את ספר התורה למקומו ואומרים יהללו » après ובא לציון et le Kaddich titkabal (chaharit S13 b7-8, annoté `kriat_hatorah` par tools/siddur_annotations.py:538). Les jours de lecture, l'ordre affiché est donc : lecture, Achré, ובא לציון, Kaddich, puis retour du Sefer. Le Kaddich titkabal (S13 b2-3) est replié par défaut (minyan).
- **Ce que dit la source** : selon le Yalkut Yosef, on rend le Sefer aussitôt après le Kaddich, comme l'Ari. Certains le font après Achré. L'usage du siddour est attesté ailleurs (Michna Beroura 149:1). *Kitsour Yalkut Yosef 423:6 ; 662:1*. « ומנהגינו על פי דעת האר״י ז״ל להחזיר את הספר תורה למקומו מיד אחר הקדיש, ואחר כך אומרים אשרי ובא לציון »
- **Correction proposée** : ajouter, après le demi-Kaddich de la lecture (S11), un renvoi ou une précision qui cite le Yalkut Yosef 423:6. Ne plus citer le YY 134:14, qui porte sur le Sefer rendu ouvert.

### Hochaana Rabba (Edot) : שיר המעלות ממעמקים replié
**Différence entre poskim** · gravité basse · Edot · tous lieux
- **Ce que fait l'app** : le 21 Tichri (2025-10-13, 2026-10-02, 2024-10-23, 2029-09-30), ה׳ הוא האלהים (chaharit 6:5-6, `techouva_hochaana`) est ouvert. En revanche, ממעמקים (7:18-19, annoté `asseret_yemei_techouva` par tools/siddur_annotations.py:601-610) est replié. L'app suit la consigne de son siddour, « בעשרת ימי תשובה מוסיפים », qui ne nomme pas Hochaana Rabba.
- **Ce que dit la source** : le Yalkut Yosef ajoute ce psaume à Hochaana Rabba. L'Ari (Pri Ets Haïm), le Kaf ha'Haïm 54:8 et l'Aroukh haChoul'han 582:8 ne parlent que des dix jours. *Kitsour Yalkut Yosef 664 §6*. « ובין ישתבח ליוצר יאמרו שיר המעלות ממעמקים, כמו שנוהגים לומר בעשרת ימי תשובה »
- **Correction proposée** : si l'utilisateur veut suivre strictement le Yalkut Yosef, ajouter une règle propre à cette consigne Edot qui rattache 7:18-19 à `techouva_hochaana`, sans toucher à la règle générale des dix jours, et revoir l'étiquette de la consigne. Sinon, une simple précision suffit. En Ashkenaz et en Sfard, le repli est conforme (Michna Beroura 54:4).

### Edot : pas de compte de l'Omer dans Arvit
**Différence entre poskim** · gravité basse · Edot · tous lieux
- **Ce que fait l'app** : l'Arvit Edot (sections ברכו, ק״ש וברכותיה, עמידה, עלינו) n'a ni section de l'Omer ni renvoi vers sefirat_haomer. Les renvois Edot (tools/siddur_annotations.py:961) ne couvrent que le Hallel et le Moussaf. Le Sfard (S3) et l'Ashkenaz (S6), eux, ouvrent leur section de l'Omer. Cela vaut pour tout l'Omer, dès le soir du 15 Nissan (2026-04-02, 2027-04-22, 2025-04-13). La carte du jour affiche « Omer ce soir : N » (VueJour.kt:138), et le siddour source place ספירת העומר juste après עלינו.
- **Ce que dit la source** : le Yalkut Yosef laisse le moment ouvert (« אין אחר המנהג כלום »). L'usage de Jérusalem, que suit l'ordre de l'app, est de compter après עלינו. *Kitsour Yalkut Yosef 489 §כא*. « יש אומרים שנכון לספור מיד אחר קדיש תתקבל של ערבית, אבל בירושלים נוהגים לספור העומר אחר סיום עלינו לשבח »
- **Correction proposée** : c'est une amélioration, pas un correctif. Ajouter à la fin d'Arvit Edot un renvoi « Aujourd'hui · ספירת העומר » sous `omer`, en ajoutant le renvoi dans RENVOIS et en appelant renvois() pour Arvit. Le faire sur Android et sur le web, et mettre en évidence la ligne du jour (`j.omer`).

### Page du compte de l'Omer : texte Edot servi aussi en Sfard et en Ashkenaz
**Différence entre rites** · gravité basse · Sfard, Ashkenaz · tous lieux
- **Ce que fait l'app** : dans les siddourim Ashkenaz et Sfard, la page sefirat_haomer reprend le texte Edot, avec l'étiquette « נוסח ספרדי – עדות המזרח » : לשם יחוד, « לעמר », ordre des mots séfarade. Aucune ligne du jour n'y est mise en évidence. L'Arvit Ashkenaz (S6) dit pourtant « בעמר ». La notification de l'Omer (VolAlerte.kt:83) ouvre cette page pendant tout l'Omer.
- **Ce que dit la source** : le Rema dit « בעומר », et la Michna Beroura note que la plupart des poskim disent « לעומר ». Le Choul'han Aroukh haRav 489:7 admet les deux formules. *Rema O.H. 489:1 ; Michna Beroura 489:8*. « בעומר - וברוב פוסקים הנוסח לעומר »
- **Correction proposée** : point informatif. Depuis la page dédiée, renvoyer à la section de l'Omer de l'Arvit du noussa'h et mettre en évidence le jour (`j.omer`).

### Méguila : bénédictions du jour et de la nuit sans distinction de rite
**Différence entre rites** · gravité basse · tous les noussa'h · tous lieux
- **Ce que fait l'app** : le texte `megila` n'est pas dans TEXTES (tools/siddur_annotations.py:37), donc rien ne s'y replie selon le moment. Le livre meguilat_esther proposé sous Cha'harit et Arvit (SiddurActivity.kt:64-68, app.js:1338) ne contient pas les bénédictions.
  - En Edot, שהחיינו (megila s0:5) reste déplié à Cha'harit de Pourim (2026-03-03, 2027-03-23, 2025-03-14).
  - En Sfard et en Ashkenaz, « אשר הניא » n'est pas replié le jour.
  - Les rites ne se distinguent que par les consignes de chaque siddour.
- **Ce que dit la source** : le Choul'han Aroukh et le Yalkut Yosef ne refont pas שהחיינו le jour. Le Rema le fait dire aussi le jour et réserve « אשר הניא » à la nuit. *Choul'han Aroukh O.H. 692:1 et Rema ; Kitsour Yalkut Yosef 692:1*. « וביום אינו חוזר לברך שהחיינו »
- **Correction proposée** : ajouter `megila` à TEXTES. Créer une condition nuit/jour, qui n'existe pas aujourd'hui. Puis réserver שהחיינו à la nuit en Edot, et « אשר הניא » à la nuit en Ashkenaz et en Sfard. À Pourim, proposer le texte du siddour avec ses bénédictions plutôt que le livre seul.

#### Constats écartés
- **Arvit : les versets ברוך ה׳ לעולם affichés aussi en Israël** : la citation est du Tour, que la Michna Beroura recopie sans prendre position. L'app affiche déjà cet avis contraire juste avant les versets, et l'usage d'Israël n'apparaît pas dans la source citée.


---

## Birkat haMazon et bénédictions

### Havdala du 9 Av au motsaé Chabbat affichée complète
**Erreur de l'app** · gravité haute · Edot, Sfard, Ashkenaz · tous lieux
- **Ce que fait l'app** : dans siddur_annotations.json, la Havdala n'a qu'une annotation (Edot s0:b16, roch_hodech) ; Sfard et Ashkenaz n'en ont aucune. Après la sortie des étoiles, jourDeLaPriere fait passer la Havdala au lendemain, qui porte bien ticha_beav et motsae_chabbat, mais aucun bloc n'en dépend. Le samedi soir 2025-08-02 (et 2029-07-21, 9 Av repoussé), la Havdala s'affiche entière : coupe (consigne Edot b2 « יקח הכוס בידו הימנית והבשמים בשמאלו »), בורא פרי הגפן, bessamim, bougie et המבדיל. Le dimanche soir (2025-08-03, 2029-07-22), bessamim et bougie restent en clair.
- **Ce que dit la source** : le samedi soir, seulement בורא מאורי האש, sans coupe (boire romprait le jeûne) ni bessamim ; à la sortie du jeûne, Havdala sur la coupe sans bougie ni bessamim. *Choul'han Aroukh O.H. 556:1 ; Michna Beroura 556, s.k. א, ד et ה ; Kitsour Yalkut Yosef 556, se'ifim 6 et 8*. « ליל תשעה באב שחל בא' בשבת כשרואה הנר אומר בורא מאורי האש ואין מברך על הבשמים ובליל מוצאי תשעה באב מבדיל על הכוס ואינו מברך לא על הנר ולא על הבשמים »
- **Correction proposée** : le samedi soir, aucune nouvelle condition n'est nécessaire : replier sous « !ticha_beav » la consigne de la coupe, כוס ישועות, סברי, הגפן, les bessamim, המבדיל et la bénédiction finale (Edot b2-b10 et b13-b19 ; Sfard et Ashkenaz b0-b4 et b6), en ne gardant que בורא מאורי האש avec une consigne. Ce repli n'agit que si l'app connaît le lieu (sinon jourDeLaPriere garde le samedi civil). Le dimanche soir, créer une condition dérivée « lendemain d'un 9 Av ou d'un jeûne du dimanche » pour replier la bougie et les bessamim.

### Sfard : formule d'oubli de Roch 'Hodech donnée avec une conclusion de bénédiction
**Erreur de l'app** · gravité moyenne · Sfard · tous lieux
- **Ce que fait l'app** : siddur_sefard.json, birkat_hamazon 0:99 (sous « בראש חודש: », replié sous « En cas d'oubli ») donne « …אֲשֶׁר נָתַן רָאשֵׁי חֳדָשִׁים לְעַמּוֹ יִשְׂרָאֵל לְזִכָּרוֹן: בָּרוּךְ אַתָּה יְהֹוָה מְקַדֵּשׁ יִשְׂרָאֵל וְרָאשֵׁי חֳדָשִׁים: », avec le Nom. C'est ce que lit, le 2025-12-21 ou le 2026-11-11, celui qui a oublié יעלה ויבוא. Le texte vient de Torat Emet 357, qui suit le Ri et le Roch ; l'Ashkenaz (0:89) et le Metsudah Sfard s'arrêtent à « לזכרון ».
- **Ce que dit la source** : à Roch 'Hodech en semaine, pas de חתימה ; elle n'est due que si Roch 'Hodech tombe un Chabbat. *Choul'han Aroukh O.H. 188:7 ; Choul'han Aroukh haRav 188:10 et 13 ; Michna Beroura 188:30*. « וְסָפֵק הוּא אִם הוּא חוֹתֵם "בָּרוּךְ אַתָּה ה' מְקַדֵּשׁ יִשְׂרָאֵל וְרָאשֵׁי חֳדָשִׁים", אִם לָאו, וְסָפֵק בְּרָכָה לְהָקֵל, וְלֹא יַחְתֹּם »
- **Correction proposée** : aligner 0:99 sur le Metsudah Sfard, qui s'arrête à « …לְעַמּוֹ יִשְׂרָאֵל לְזִכָּרוֹן: ». Garder la חתימה combinée de Roch 'Hodech un Chabbat (0:101). Reporter la correction dans tools/siddur_construction.py pour qu'elle survive à une régénération.

### Sfard et Ashkenaz : pas de formule d'oubli pour 'Hol hamoed
**Erreur de l'app** · gravité moyenne · Sfard, Ashkenaz · tous lieux
- **Ce que fait l'app** : les consignes Sfard 0:56 et Ashkenaz 0:45 nomment 'Hol hamoed (« …יעלה ויבא בראש חודש ויום טוב וחול המועד … ראה להלן דיני שכחה »), mais les « דיני שכחה » (Sfard 0:95-0:109, Ashkenaz 0:85-0:97) n'ont aucune formule pour ce jour, ni en semaine ni un Chabbat. La seule proche, « ביו״ט אומר » (Sfard 0:103, Ashkenaz 0:91), finit par la חתימה « מקדש ישראל והזמנים ». Vérifié le 2025-10-09, le 2025-10-11 et le 2026-04-05.
- **Ce que dit la source** : 'Hol hamoed suit la règle de Roch 'Hodech : « אשר נתן מועדים… », sans חתימה. *Choul'han Aroukh O.H. 188:7 ; Michna Beroura 188:27 ; Choul'han Aroukh haRav 188:11*. « וה"ה לענין שאם נזכר קודם שהתחיל הטוב והמטיב אומר בא"י אמ"ה שנתן מועדים לעמו ישראל לששון ולשמחה ואינו חותם כמו בר"ח »
- **Correction proposée** : ajouter, sans חתימה, « בחול המועד: בָּרוּךְ אַתָּה יְהֹוָה אֱלֹהֵינוּ מֶלֶךְ הָעוֹלָם אֲשֶׁר נָתַן מוֹעֲדִים לְעַמּוֹ יִשְׂרָאֵל לְשָׂשׂוֹן וּלְשִׂמְחָה אֶת חַג (פלוני) הַזֶּה » (libellé du Choul'han Aroukh haRav, sans « יום » ; le Michna Beroura s'arrête à « לששון ולשמחה »). Préciser que « ביו״ט אומר » ne vaut pas à 'Hol hamoed. Le Chabbat de 'Hol hamoed reste à sourcer : la formule « ביו״ט שחל בשבת » ne convient pas telle quelle.

### Ashkenaz : formule d'oubli de Roch haChana incomplète
**Erreur de l'app** · gravité basse · Ashkenaz · tous lieux
- **Ce que fait l'app** : siddur_ashkenaz.json, birkat_hamazon 0:95 (sous « בראש השנה: », replié sous « oubli ») dit seulement « …אֲשֶׁר נָתַן יָמִים טוֹבִים לְעַמּוֹ יִשְׂרָאֵל לְזִכָּרוֹן: », sans « את יום הזכרון הזה » ni חתימה. Vérifié les 2025-09-23 et 2026-09-12. Le texte reprend le siddour Metsoudah, qui suit le Maguen Avraham ; il s'écarte même de la formule que la MB prête à celui-ci.
- **Ce que dit la source** : la Michna Beroura rapporte l'avis du Maguen Avraham puis tranche : il faut la חתימה. *Michna Beroura 188:19 ; Kitsour Choul'han Aroukh 44:14*. « אבל הרבה אחרונים הסכימו לדעת כנה"ג וע"כ צריך לחתום בא"י מקדש ישראל ויום הזכרון »
- **Correction proposée** : 0:95 → « …אשר נתן ימים טובים לעמו ישראל את יום הזכרון הזה: ברוך אתה יהוה מקדש ישראל ויום הזכרון: », comme le Sfard 0:107.

### Ashkenaz : מגדיל au lieu de מגדול à Roch 'Hodech
**Erreur de l'app** · gravité basse · Ashkenaz · tous lieux
- **Ce que fait l'app** : tools/siddur_annotations.py:654-657 ne pose le repère « Aujourd'hui : מִגְדּוֹל » que pour chabbat et yom_tov quand la consigne dit « בשבת וביו״ט » ; birkat_hamazon Ashkenaz s0:b74 garde donc « מַגְדִּיל » à Roch 'Hodech en semaine : 2025-11-21, 2025-12-21, 2026-01-19, 2026-02-17/18, 2026-03-19, 2026-04-17, 2026-12-10/11, 2024-12-31, 2025-01-01, 2027-04-08, 2027-05-07, etc. Android lit le même JSON (SiddurJour.kt:165).
- **Ce que dit la source** : מגדול le Chabbat, à Yom tov et à Roch 'Hodech. *Michna Beroura 189:5 ; aussi Maguen Avraham 189 et Aroukh haChoul'han O.H. 189*. « נוהגים לומר בשבת ויו"ט ור"ח מגדול ובחול מגדיל »
- **Correction proposée** : ajouter roch_hodech aux indices « מִגְדּוֹל » de l'Ashkenaz (b74, siddur_annotations.py l. 655), régénérer siddur_annotations.json, et compléter la consigne affichée (« בשבת, ביו״ט ובר״ח ») ou y joindre une note renvoyant au MB 189:5. 'Hol hamoed n'est pas couvert par ces sources : le laisser hors de la correction.

### Sfard : מגדול seulement le Chabbat et à Yom tov, pas à Roch 'Hodech
**Erreur de l'app** · gravité basse · Sfard · tous lieux
- **Ce que fait l'app** : birkat_hamazon Sfard s0:b84 n'a d'indice « מִגְדּוֹל » que pour chabbat et yom_tov (siddur_annotations.py l. 654-657), d'après la consigne du siddour « בשבת וביו״ט אומר: מגדול ». Aucun repère à Roch 'Hodech (2025-11-21, 2025-12-21, 2026-12-10/11) ni à 'Hol hamoed (2026-04-05 en diaspora, 2026-04-03 et 2026-10-01 en Israël).
- **Ce que dit la source** : le posek du rite Sfard compte Roch 'Hodech, et le siddour Admour haZaken ajoute 'Hol hamoed. La Knesset haGuedola, citée par le Kaf ha'Haïm 189:11, ne fait que rapporter l'avis restrictif et retient elle-même מגדול à Roch 'Hodech. *Choul'han Aroukh haRav O.H. 189:7 ; Maguen Avraham 189:1*. « נוֹהֲגִים לוֹמַר בְּשַׁבָּת וְיוֹם טוֹב וְרֹאשׁ חֹדֶשׁ: "מִגְדּוֹל"... וּבְחֹל: "מַגְדִּיל" »
- **Correction proposée** : ajouter roch_hodech à l'indice « מִגְדּוֹל » du Sfard, avec une précision signalant que la consigne imprimée ne nomme que Chabbat et Yom tov ; envisager moed, selon le siddour Admour haZaken.

### Edot : pas de mention de Kippour dans יעלה ויבוא pour qui mange ce jour-là
**Erreur de l'app** · gravité basse · Edot · tous lieux
- **Ce que fait l'app** : le 2026-09-21 (10 Tichri), les conditions yaale_veyavo et kippour sont posées. Le יעלה ויבוא du Birkat Edot (siddur_edot.json, birkat_hamazon s0:b24-b32) s'affiche, mais ses six variantes (b26-b31 : ר״ח, פסח, שבועות, ר״ה, סוכות, שמ״ע) sont repliées et aucune ne vise Kippour. Le texte se lit tronqué : « …וּלְשָׁלוֹם, בְּיוֹם » puis « לְרַחֵם בּוֹ ». Sfard (b54) et Ashkenaz (b43) ont la ligne de Kippour.
- **Ce que dit la source** : le malade ou l'accouchée qui mange à Kippour dit יעלה ויבוא avec le nom du jour ; s'il l'oublie, il ne reprend pas. *Kitsour Yalkut Yosef 618:12 (section 593) et 161:10 (section 173) ; Choul'han Aroukh O.H. 618:10*. « חולה או יולדת שאוכלים ביום הכפורים, צריכים להזכיר יעלה ויבוא בברכת המזון. ואומרים: ״ביום הכפורים הזה, ביום סליחת העון הזה.״ »
- **Correction proposée** : ajouter dans siddur_edot.json, birkat_hamazon s0, entre b31 et b32, la ligne « ביום הכפורים: הכפורים הזה, ביום סליחת העון הזה, », et dans VARIANTES_YAALE (tools/siddur_annotations.py) le motif `^(ב|ל)(יום הכפורים|יוה״כ|יו״כ)` → kippour. Veiller à ne pas doubler le « ביום » final de b25.

### Edot : pas de הרחמן pour qui a oublié על הנסים
**Erreur de l'app** · gravité basse · Edot · tous lieux
- **Ce que fait l'app** : le Birkat Edot (birkat_hamazon 0:16-0:19) ne dit rien de l'oubli d'על הנסים ; ses consignes d'oubli (0:34-0:39) ne visent que רצה et יעלה ויבא. Son seul « הרחמן הוא יעשה לנו נסים » (0:52-0:53) est réservé au Pourim triple et replié les autres jours. Sfard (0:36) et Ashkenaz (0:24) ont la note en clair. Vérifié le 2025-12-16 et le 2025-12-18 ('Hanouka), le 2026-03-03 et le 2027-03-23 (Pourim), le 2026-03-04 (Jérusalem).
- **Ce que dit la source** : on ne reprend pas, et il est bon (recommandation, pas obligation) de le dire dans les הרחמן. *Kitsour Yalkut Yosef 188:18 (section 196), 682:11, 693:2 et 695:6*. « וטוב שיאמרנו בהרחמן, ויאמר: הרחמן הוא יעשה לנו נסים ונפלאות כמו שעשה לאבותינו בימים ההם בזמן הזה בימי מתתיה וכו' »
- **Correction proposée** : ajouter au Birkat Edot une consigne repliée sous « oubli » (ou rattachée à al_hanissim, comme en Sfard et en Ashkenaz) : on ne reprend pas après avoir dit le Nom à la fin de « על הארץ ועל המזון » ; puis deux formules dans les הרחמן, « בימי מתתיה… » pour 'Hanouka et « בימי מרדכי ואסתר… ועשית עמהם נסים ונפלאות ונודה לשמך הגדול סלה » pour Pourim (695:6).

### Psaume d'avant le Birkat : l'app n'indique jamais lequel dire (על נהרות בבל ou שיר המעלות)
**Erreur de l'app** · gravité basse · Ashkenaz (Sfard non vérifié) · tous lieux
- **Ce que fait l'app** : facultatif() (tools/siddur_annotations.py:872-917) range les blocs 0:0-0:3 du Birkat Sfard et Ashkenaz dans un groupe « facultatif » toujours replié, avec les variantes « !chabbat » (על נהרות בבל) et « chabbat » (שיר המעלות). Une fois déplié, le web (app.js, corpsDe) présente על נהרות בבל comme le psaume du jour et estompe à peine שיר המעלות (opacité 0,9, app.css:753) ; Android (SiddurJour.kt, l. 189-190) estompe tout. Vérifié le 2026-03-24 (Nissan), le 2026-04-02 (Pessa'h), le 2025-12-18 et le 2026-12-07 ('Hanouka), le 2026-02-18 (Roch 'Hodech), le 2026-03-03 (Pourim).
- **Ce que dit la source** : שיר המעלות le Chabbat et tous les jours sans Ta'hanoun, Yom tov compris. *Michna Beroura 1:11*. « ובשבת, וכן בימים שאין אומרים בהם תחנון, יאמר "שיר המעלות בשוב ה'" » Pour le Sfard, aucune source du rite n'a été lue ; sa consigne « בחול / בשבת » ne couvre de toute façon pas Yom tov.
- **Correction proposée** : annoter על נהרות בבל « tahanoun_chaharit » et שיר המעלות « !tahanoun_chaharit » (le jour fait foi, pas la Min'ha) ; compléter les consignes (« בימים שאומרים בהם תחנון… » / « בשבת, ביו״ט ובימים שאין אומרים בהם תחנון… ») ; aligner Android sur le web pour distinguer les membres du groupe, et ajouter un repère « Aujourd'hui : שיר המעלות ».

### Birkat haMazon du 9 Av : pas de Na'hem pour qui mange (Ashkenaz)
**Différence entre rites** · gravité basse · Ashkenaz, Edot · tous lieux
- **Ce que fait l'app** : aucun des trois birkat_hamazon n'a de bloc « נחם » et aucune annotation ticha_beav, alors que le 2026-07-23 et le 2027-08-12 les conditions ticha_beav, jeune et ticha_beav_kippour sont posées. Le badge « Na'hem » renvoie à la Amida.
- **Ce que dit la source** : en Ashkenaz, celui qui mange le 9 Av dit Na'hem dans בונה ירושלים (le Chaaré Techouva et le Gra hésitent ; on ne reprend pas en cas d'oubli). En Edot, le Yalkut Yosef ne le fait pas dire, contre le Ben Ich 'Haï (Devarim 27), qui ne le fait dire que si l'on mange à partir de Min'ha guedola : l'app suit le Yalkut Yosef. *Rema O.H. 557:1 ; Michna Beroura 557:5 ; Kitsour Yalkut Yosef, « החייבים בתענית », se'if 5*. « מי שאכל בט"ב יאמר נחם בברכת המזון (מהרי"ל) »
- **Correction proposée** : Ashkenaz : un bloc נחם replié (ticha_beav) dans le Birkat haMazon, avec la consigne « pour qui mange le 9 Av ». Edot : ne rien changer ; au besoin, une note sur l'avis du Ben Ich 'Haï.

### Birkat haMazon après la nuit : les ajouts du jour du repas disparaissent
**Différence entre poskim** · gravité basse · Edot, Sfard, Ashkenaz · tous lieux
- **Ce que fait l'app** : jourDeLaPriere (calendrier-juif.js:191-197 ; CalendrierJuif.kt:377-381) fait passer le Birkat au lendemain dès la sortie des étoiles ; רצה, יעלה ויבוא, על הנסים et le הרחמן du Pourim triple se replient. Exemples : 2026-03-03 et 2026-03-04 à Jérusalem (Pourim, sans al_hanissim), 2025-03-16 à Jérusalem (pourim_triple_festin disparaît), 2025-12-22 ('Hanouka), 2026-04-18 et 2027-05-08 (Chabbat Roch 'Hodech), 2026-06-20 (רצה replié). Le 2025-03-29 (Roch 'Hodech le dimanche), le Birkat Edot montre יעלה ויבוא et replie רצה. C'est un choix assumé (demande du 28/10, commit 071071e) : les blocs restent ouvrables à la main, mais aucune consigne ne signale le cas.
- **Ce que dit la source** : on suit le début du repas, sauf si l'on a prié Arvit ; en Edot, si Roch 'Hodech tombe le dimanche, רצה seul. L'app ne connaît pas l'heure du repas : son réglage horaire est juste pour un repas commencé la nuit. Pour 'Hanouka et Roch 'Hodech, le Ben Ich 'Haï ('Houkat) ne fait rien mentionner, contre le Yalkut Yosef. *Choul'han Aroukh O.H. 188:10 et 695:3 ; Michna Beroura 188:32-34 ; Kitsour Yalkut Yosef 188:16, 188:19, 424:3, 682:12, 695:16 ; Choul'han Aroukh haRav 188:17*. « וכיון שהתחיל סעודתו ביום, אומר מעין המאורע בברכת המזון, אף לאחר כמה שעות. אולם אם התפלל ערבית באמצע סעודתו, אינו מזכיר »
- **Correction proposée** : garder le choix du 28/10 et ajouter, le soir qui suit un jour d'ajouts, sur les blocs repliés, une consigne « אם התחיל הסעודה מבעוד יום ולא התפלל ערבית — מזכיר ». En Edot, la nuance du Roch 'Hodech le dimanche (רצה seul, YY 188:19 et 424:3) ; en Ashkenaz, renvoi à la MB 188:33 (רצה seul si l'on a fini de jour, יעלה ויבוא seul si l'on a mangé du pain la nuit) ; en Sfard, les deux avec un kezayit après la nuit (Choul'han Aroukh haRav). Le vendredi qui passe à Chabbat (2023-12-15, 2026-12-11) n'est pas une erreur : seul רצה se dit (MB 695:15).

### Edot : formule d'oubli de יעלה ויבוא à Yom tov limitée au premier repas
**Différence entre poskim** · gravité basse · Edot · tous lieux
- **Ce que fait l'app** : la consigne du siddour Edot (siddur_edot.json, birkat_hamazon 0:34, repliée sous « oubli ») réserve le שם ומלכות de « אשר נתן » au Chabbat et à la première nuit (deux en diaspora) de Pessa'h et Soukkot. Elle s'applique telle quelle le 2026-09-12 (Roch haChana), le 2026-10-03 (Chemini Atseret) et le 2027-04-22 (Pessa'h).
- **Ce que dit la source** : la consigne suit le Kaf ha'Haïm 188:24-25 (d'après le Ben Ich 'Haï, 'Houkat 20, et le Maguen Avraham) ; le Yalkut Yosef, référence choisie pour les Edot, fait dire « אשר נתן » avec שם ומלכות à tous les repas de Yom tov et à Roch haChana. *Kitsour Yalkut Yosef 188:10, 529:7 et 597:2*. « ואם נזכר לאחר שסיים בונה ירושלים, יאמר ״בשם ומלכות״: ברוך אתה ה' אלוקינו מלך העולם אשר נתן ימים טובים לעמו ישראל »
- **Correction proposée** : sans réécrire la consigne, ajouter une précision : « לדעת הילקוט יוסף (קפח:י; תקכט:ז; תקצז:ב) אומרים בשם ומלכות בכל סעודות יום טוב ובראש השנה ». Pour Roch 'Hodech, sans שם ומלכות (YY 188:9). Pour 'Hol hamoed, le « sans שם ומלכות » n'est appuyé par aucune citation lue : à sourcer avant de l'écrire.

### Birkat haMazon : rien ne dit de reprendre si l'oubli est remarqué après הטוב והמטיב
**Différence entre poskim** · gravité basse · Edot, Sfard, Ashkenaz · tous lieux
- **Ce que fait l'app** : les consignes d'oubli ne traitent que l'oubli remarqué avant הטוב והמטיב : Edot 0:34 (« ונזכר לפני שהתחיל ברכת הטוב והמטיב יאמר »), Sfard 0:56 et Ashkenaz 0:45, dont les « דיני שכחה » ne donnent que des formules. Celui qui a oublié רצה un vendredi soir et a déjà dit « לעד » n'apprend pas qu'il doit reprendre. Les consignes sont statiques, la date importe peu. Rien de faux n'est affiché, et en Edot la règle figure dans le Kitsour Yalkut Yosef et le Ben Ich 'Haï de l'app.
- **Ce que dit la source** : on reprend le Chabbat et à Yom tov, pas à Roch 'Hodech, 'Hol hamoed ni à la troisième seouda. En Edot, à Yom tov, seulement la première nuit de Pessa'h et de Soukkot. *Choul'han Aroukh O.H. 188:6-8 ; Michna Beroura 188:26 ; Kitsour Yalkut Yosef 188:6, 10 et 12*. « אבל אם לא נזכר עד שהתחיל הטוב והמטיב צריך לחזור לראש ברכת המזון »
- **Correction proposée** : sans toucher au texte du siddour, ajouter dans le repli « En cas d'oubli » une note propre à l'app : en Edot, un renvoi au Kitsour Yalkut Yosef 188 (Chabbat, repas 1-2 ; première nuit de Pessa'h ou Soukkot ; la seconde nuit en diaspora est une extension) ; en Ashkenaz et Sfard, la règle du MB 188:26. Roch haChana est disputé (MB 188:19 : le Maguen Avraham ne fait pas reprendre, l'Eliya Rabba si).

### Edot : על הנסים de Pourim conclu par « נס ופלא » au lieu du pluriel
**Différence entre poskim** · gravité basse · Edot · tous lieux
- **Ce que fait l'app** : siddur_edot.json, birkat_hamazon 0:19 (על הנסים de Pourim, en clair le 2025-03-14 et le 2026-03-03) et 0:53 (הרחמן du Pourim triple, en clair le 2025-03-16 à Jérusalem) finissent par « וְעָשִֽׂיתָ עִמָּהֶם נֵס וָפֶֽלֶא ». Le texte vient de Torat Emet 357 ; or la consigne de 0:52 se réclame du Yalkut Yosef. Même fin dans la Amida (cha'harit 9:47, min'ha 1:47, arvit 2:41).
- **Ce que dit la source** : le singulier est la version de la Knesset haGuedola, du Peri 'Hadach et du Chalmei Tsibour (Kaf ha'Haïm 682, s.k. 1) ; le Yalkut Yosef, référence des Edot, l'écarte. *Kitsour Yalkut Yosef 695:7 (section 683) ; aussi 682:21 et נוסחאות התפלה עג*. « בעל הנסים שבתפלה ובברכת המזון, צריך לסיים: ועשית עמהם ״נסים ונפלאות״ בלשון רבים, ולא ״נס ופלא״ »
- **Correction proposée** : pour 0:53, la correction s'impose, puisque sa consigne cite le Yalkut Yosef dont la formule (695:6) finit par « נסים ונפלאות ». Pour 0:19, mettre « נִסִּים וְנִפְלָאוֹת » si l'on admet une retouche du siddour source, ou ajouter une consigne signalant la version du Yalkut Yosef.

### Méèn chaloch : la fin dépend du lieu où l'on mange et non de l'origine du fruit
**Différence entre poskim** · gravité basse · Sfard, Ashkenaz · tous lieux
- **Ce que fait l'app** : les consignes reprises des siddourim sources sont formulées par lieu : Ashkenaz meen_chaloch 0:16-0:21 « (בחו״ל—וְעַל פְּרִי הַגָּֽפֶן) », « (בחו״ל—וְעַל הַפֵּרוֹת) » ; Sfard 0:12-0:15 « (בא״י וְעַל פֵּרוֹתֶיהָ) ». Rien n'est replié selon le lieu (aucune condition de lieu, vérifié le 2026-11-16 en Israël et en diaspora). L'Edot (« של ארץ ישראל ») est conforme.
- **Ce que dit la source** : c'est l'origine du fruit qui compte ; en cas de doute, la MB suit l'Eliya Rabba (« על הפירות », même en Israël), tandis que la consigne Sfard rejoint l'Olat Tamid cité par le Kaf ha'Haïm 208:62. Pour le vin, la règle s'applique par analogie. *Choul'han Aroukh O.H. 208:10 ; Michna Beroura 208:52 et 54*. « ואם בח"ל אוכל מפירות הארץ חותם ג"כ על פירותיה »
- **Correction proposée** : sans réécrire le siddour, ajouter sous ces consignes une note de l'app : « fruit d'Israël, même mangé en diaspora : …פרותיה / פרי גפנה ; fruit de diaspora, même mangé en Israël, ou origine inconnue : …הפרות / פרי הגפן (Choul'han Aroukh 208:10 ; Michna Beroura 208:52-54) ».

### Edot : délai de כדי אכילת פרס donné à 4 minutes pour Boré nefachot
**Différence entre poskim** · gravité basse · Edot · tous lieux
- **Ce que fait l'app** : la consigne Edot de bore_nefachot 0:0, reprise en nehenin 0:10, sans annotation donc toujours en clair (Android et web, app.js:1005), dit « אם אכל כזית בכדי אכילת פרס (4 דקות, וי״א 8 דקות) ». Elle vient mot pour mot du siddour source (Sefaria, « Siddur Edot HaMizrach, Blessings on Enjoyments »). Qui mange un kezayit en 6 minutes se croira dispensé.
- **Ce que dit la source** : les 4 minutes sont un avis reçu chez les A'haronim, mais le Yalkut Yosef fixe environ 7 min 30 pour la berakha a'harona, les 4 minutes n'étant qu'une rigueur pour la Torah. *Kitsour Yalkut Yosef 207:1-2 (section 208) ; voir aussi 184:20*. « ושיעור זה הוא כשבע דקות וחצי. וטוב להחמיר בדברים שהם מן התורה לאכול כזית בארבע דקות »
- **Correction proposée** : ajouter après la consigne une note de l'app « (לדעת הילקוט יוסף: כ-7.5 דקות; ולחומרא בדאורייתא 4 דקות) » dans bore_nefachot 0:0 et nehenin 0:10. Si l'on remplace plutôt le texte, le faire en amont dans tools/siddur_construction.py.

### Havdala : bessamim et flamme non repliés à la sortie d'un Yom tov ou de Kippour
**Différence entre poskim** · gravité basse · Edot, Sfard, Ashkenaz · tous lieux
- **Ce que fait l'app** : la Havdala Edot n'est annotée que pour Roch 'Hodech (s0:b16) ; les bessamim (b10) et la flamme (b12) restent en clair sous la consigne b9 « במוצאי יו״ט שאינו מוצ״ש אין מברכים על הבשמים או על הנר ». En Sfard et Ashkenaz, b4-b5 restent en clair, sans consigne. Sorties de Yom tov : 2026-04-02 et 2026-04-08 au soir en Israël, 2026-04-09 en diaspora. Sorties de Kippour : 2025-10-02, 2026-09-21, 2024-10-12 (un Chabbat), sans aucune précision propre à Kippour. Le ma'hzor de Kippour est déclaré hors champ (FEUILLE_DE_ROUTE.md).
- **Ce que dit la source** : à la sortie d'un Yom tov de semaine, ni flamme ni bessamim. Au motsaé Kippour, pas de bessamim pendant la Havdala, mais il est bon de les bénir après avoir goûté le vin ; la flamme seulement sur « אור ששבת », ou, si Kippour tombait un Chabbat et qu'on n'en a pas, sur une flamme allumée à la sortie. *Choul'han Aroukh O.H. 491:1 et 624:3-5 ; Kitsour Yalkut Yosef 624:4-6*. « מבדילים על הכוס, ואין מברכים על בשמים אפילו אם חל יום הכפורים בשבת »
- **Correction proposée** : ne pas replier les bessamim au motsaé Kippour ; ajouter, sous la condition lendemain_kippour, la consigne « במוצאי יום הכפורים אין מברכים על הבשמים בהבדלה אפילו בשבת, וטוב לברך עליהם אחר הטעימה ; ועל הנר רק על נר ששבת (ובחל בשבת, אם אין, על נר שהודלק עתה) ». Au motsaé Yom tov qui n'est pas un motsaé Chabbat, replier bessamim et flamme (Edot b10-b12, Sfard et Ashkenaz b4-b5), par exemple en les liant à motsae_chabbat.

### Edot : mentions de Pessa'h et de Soukkot de la bénédiction finale de la Havdala affichées toute l'année
**Différence entre poskim** · gravité basse · Edot · tous lieux
- **Ce que fait l'app** : dans la Havdala Edot, b17 (« חוה''מ פסח וְשַׂמְּחֵֽנוּ בְּיוֹם חַג הַמַּצּוֹת הַזֶּה ») et b18 (« חוה''מ סוכות… ») ne sont pas annotés : ils restent en clair toute l'année, et aucun n'est mis en évidence le jour voulu (2026-04-05, 2025-10-12, 2026-09-27 en Israël ; aussi un motsaé Chabbat ordinaire, 2026-11-15). Seul b16 (Roch 'Hodech) se replie. Les motifs MEEN_CHALOCH de tools/siddur_annotations.py ne visent que meen_chaloch et attendent « ״ », pas « '' ». Chaque ligne garde son étiquette du siddour.
- **Ce que dit la source** : on ne mentionne que la fête du jour. *Kitsour Yalkut Yosef, siman 208 (דין ברכה מעין שלש), se'if 25*. « בשבת ובמועדים ובראשי חודשים מזכירין בברכה מעין שלש מעין המאורע »
- **Correction proposée** : dans tools/siddur_annotations.py, reconnaître aussi dans havdala les débuts « חוה''מ פסח » et « חוה''מ סוכות » (accepter '' comme ״), annoter b17 « pessah » et b18 « soukkot » dans un même groupe, comme meen_chaloch b8 et b10, puis régénérer siddur_annotations.json.

### Bein hamétsarim : שהחיינו sans réserve
**Différence entre poskim** · gravité basse · Edot, Sfard, Ashkenaz · tous lieux
- **Ce que fait l'app** : la consigne de שהחיינו du texte nehenin (Edot s0:b18 « וכן מברכים שהחיינו על פרי המתחדש משנה לשנה » ; Sfard et Ashkenaz section 3, bloc 0) n'a aucune réserve et aucune annotation ; aucune condition bein_hametsarim n'existe dans calendrier-juif.js. Seule la carte de halakha du jour en parle, certains jours (2026-07-04, 07-05, 07-06, 07-23). Période touchée : 2026-07-02 → 2026-07-23 et 2027-07-22 → 2027-08-12 (jusqu'au 10 Av en Edot).
- **Ce que dit la source** : c'est un usage de prudence, pas un interdit (le Gra y voit une « חומרא יתירא », MB 551:98) ; permis le Chabbat, sauf un vêtement neuf après Roch 'Hodech Av ; exceptions pour un fruit introuvable après le 9 Av et pour le malade. *Choul'han Aroukh O.H. 551:17 ; Michna Beroura 551:98-99 ; Kitsour Yalkut Yosef 551:9 et 13*. « נוהגים להיזהר שלא לאכול פרי חדש בימים אלה, מליל י"ז בתמוז עד אחרי תשעה באב, כדי שלא יצטרכו לברך עליו "שהחיינו". אבל מותר לברך "שהחיינו" על פרי חדש בשבתות שבינתים »
- **Correction proposée** : facultative : une condition « bein_hametsarim » (17 Tamouz – 9 Av, jusqu'au 10 Av en Edot) et une consigne repliable près de שהחיינו dans nehenin, avec ces nuances.

#### Constats écartés
- **Edot : מגדול non signalé à Pourim, au repas de brit et au motsaé Chabbat** : l'app suit le Yalkut Yosef (Kitsour 300:4, « ורק בשבת או יום טוב וחול המועד או ראש חודש יאמרו ״מגדול״ »), référence des Edot, et laisse visible la consigne du siddour qui reprend l'avis du Ben Ich 'Haï.
- **Festin du 16 Adar à Jérusalem (Pourim triple) : rien en Sfard et en Ashkenaz** : la formule du הרחמן existe bien en Sfard (b36) et en Ashkenaz (b24), et la seule source citée (Rav Mordekhaï Eliyahou) est séfarade, donc ne fonde aucune divergence de rites.


---

## Calendrier, fêtes et jeûnes

### Birkat halevana : le « dernier soir » tombe après la fermeture de la fenêtre
**Erreur de l'app** · gravité moyenne (haute en Edot) · tous · tous
- **Ce que fait l'app** : le dernier soir est calculé comme « fin de la fenêtre − 12 h » (web/src/js/calendrier-juif.js:270 `dernier: local(f.fin - 12 * 3600000)` ; android Levana.kt:57 `fin.minus(Duration.ofHours(12))`), puis l'état est posé à calendrier-juif.js:286 et Levana.kt:137. Quand la fenêtre se ferme entre midi et la nuit, l'app affiche « Dernier soir » un soir déjà hors délai, et la carte d'accueil « Possible ce soir » dès 14 h (app.js:729, AccueilMoment.kt:35). Le vrai dernier soir, la veille, ne reçoit que « Possible ce soir », et aucun rappel Android « dernier soir » ne part ce mois-là. Exemples : Kislev 5786 en Edot, fin le 05/12/2025 à 12:17 à Paris (13:17 à Jérusalem), « Dernier soir » le 05/12, nuit du 16 Kislev ; 02/02/2026 à Jérusalem (Edot, 15 Chevat) ; 14/03/2025 à Jérusalem (Ashkenaz) ; 31/05/2026 à Paris (mi-mois, nuit du 16 Sivan) ; 29/07/2026 à Jérusalem (Sfard). Environ un mois sur quatre, dans tous les lieux.
- **Ce que dit la source** : la fenêtre se ferme au 16e jour depuis le molad, ce jour exclu, ou à la mi-mois selon le Rema ; en Edot, jamais la nuit du 16, sous peine de bénédiction douteuse. *Choul'han Aroukh O.H. 426:3 et Rema ; Kitsour Yalkut Yosef 426, se'if לז*. « עד י"ו מיום המולד ולא י"ו בכלל: (ואין לקדש אלא עד חצי כ"ט י"ב תשצ"ג מן המולד) » ; « אין לו לברך ברכת הלבנה בליל ט״ז לחדש, שיש בזה ספק ברכה לבטלה ». Seule nuance : le Biour Halakha 426:3 (Mor ouKtsia, « אפשר ») tolère a posteriori, en Ashkenaz et en Sfard, un soir encore dans les 15 jours ; cela ne justifie pas « fin − 12 h ».
- **Correction proposée** : prendre D = date locale de la fin ; garder D si la tsét de D précède la fin, sinon prendre D−1. En Edot, ne jamais désigner la nuit du 16 du mois hébraïque (YY 426:37) ; la chki'a ne sert de seuil que dans un mois serré (YY 426:27). Appliquer le même calcul dans Levana.kt (dernierSoir, etat, motsaeChabbat, fenetre) et dans calendrier-juif.js, et ne plus afficher « Possible ce soir » une fois la fin passée. Tests : 2025-12-05, Edot, Paris et Jérusalem → dernier = 2025-12-04 ; 2026-02-02, Jérusalem, Edot → 2026-02-01 ; 2026-05-31, mi-mois, Paris → 2026-05-30.

### Halakha du jour : le jeûne repoussé au 10 Av traité comme un jour ordinaire
**Erreur de l'app** · gravité basse · tous · tous
- **Ce que fait l'app** : la fenêtre « bein_hametsarim » s'arrête à `AV && jour <= 9` (web/src/js/yalkut.js:17, YalkutYosef.kt:49). Le dimanche 22/07/2029 (10 Av 5789, jeûne repoussé), periode() renvoie ['ordinaire', 21752] et la carte affiche « סימן מז - מהלכות ברכות התורה » טז-יז ; même chose le 26/07/2015 (סימן ד', נטילת ידים). Le reste de l'app reconnaît pourtant le jeûne ce jour-là (jeune, ticha_beav).
- **Ce que dit la source** : le jour du jeûne, l'étude de la Torah ordinaire est interdite, et le Yalkut Yosef applique au jeûne repoussé les lois du 9 Av. *Kitsour Yalkut Yosef, סימן תקנד (דברים האסורים בתשעה באב), se'if יג ; סימן תקנא, se'if י*. « ביום תשעה באב אסור לקרות בתורה נביאים וכתובים. וכן אסור לשנות בו במשנה ומדרש וגמרא בהלכות ובאגדות » ; « כשחל תשעה באב בשבת ונדחה התענית ליום ראשון ».
- **Correction proposée** : dans fenetreDu() / periode() (fenetre() ne voit pas le jour de la semaine), rattacher le 10 Av à « bein_hametsarim » quand le calendrier indique TISHA_BEAV, sur Android et sur le web, avec un test sur 2029-07-22. Mieux : un jour ticha_beav, afficher les se'ifim du siman 554. Un vérificateur propose de relever la gravité à moyenne, puisque l'app propose une étude interdite ce jour-là.

### Rappel de la pluie en diaspora annoncé un vendredi soir, alors que l'Amida est celle de Chabbat
**Erreur de l'app** · gravité basse · tous · diaspora (et Edot de l'hémisphère sud)
- **Ce que fait l'app** : la date de début vient de isVeseinTalUmatarRecited (calendrier-juif.js:96), vraie aussi le Chabbat. En 5787, pluie_debut tombe le samedi 05/12/2026 (calendrier-juif.js:314) : la carte affiche « Vendredi soir » le 02/12, « Demain soir » le 03/12 et « Ce soir » le 04/12, « …à la Amida d'Arvit, on commence à demander la pluie » (app.js:692-700 ; RappelsTefila.kt, prochains() et moment(), vers les lignes 139-147). Le rappel est filtré dès le 05/12 (calendrier-juif.js:323, RappelsTefila.kt:64) : rien n'est annoncé pour le motsaé Chabbat, le vrai premier soir. Le cas se présente le mois prochain.
- **Ce que dit la source** : la demande commence à Arvit du 60e jour, mais elle fait partie de ברכת השנים, absente de l'Amida de Chabbat ; la première demande se fait donc au motsaé Chabbat. *Choul'han Aroukh O.H. 117:1 ; KosherJava TefilaRules.java:283 (« Not recited on Friday night »)*. « ומתחילין לשאול מטר בחוצה לארץ בתפלת ערבית של יום ס' אחר תקופת תשרי ».
- **Correction proposée** : reprendre la règle de KosherJava (isVeseinTalUmatarStartDate / isVeseinTalUmatarStartingTonight) : en diaspora, si pluie_debut tombe un Chabbat, la reporter au dimanche. La branche « rappel_motsae » existante affiche alors « Motsaé Chabbat » et le filtre garde la carte jusqu'au samedi soir. Corriger aussi le commentaire et l'assertion de RappelsTefilaTest.kt:26 (date attendue 2026-12-06) et le test web calendrier.test.mjs:371.

### Birkat halevana proposée et rappelée le vendredi soir ou un soir de Yom tov
**Erreur de l'app** · gravité basse · tous · tous
- **Ce que fait l'app** : levana() (calendrier-juif.js:286) et Levana.etat (Levana.kt:132-139) répondent « Possible ce soir » tout soir de la fenêtre, sans regarder Chabbat ni Yom tov ; la carte d'accueil s'affiche dès 14 h (app.js:729), et LevanaAlerte.kt:28 pose le rappel « premier soir » au tsét, donc en plein Chabbat ou Yom tov. Exemples : vendredi 24/04/2026 à Jérusalem, premier soir en Edot et en Sfard ; vendredi 11/06/2027, Chabbat et, en diaspora, 2e soir de Chavouot ; 20/05/2029 à Paris, 2e soir de Chavouot. L'app exclut pourtant déjà le motsaé Chabbat qui est Yom tov (Rema 426:2).
- **Ce que dit la source** : lekhat'hila, on ne bénit pas la lune le soir de Chabbat ni de Yom tov, sauf si le délai va passer. *Kitsour Yalkut Yosef 426, se'if לג ; Michna Beroura 426:12*. « לכתחלה יש לחוש שלא לקדש את הלבנה בליל שבת ובליל יום טוב » ; « ומכ"ש שאין מקדשין אותה בליל שבת … ומ"מ אם לא קידשו עד שבת ויו"ט ויעבור הזמן בודאי מותר ». Pour le Sfard, la règle est déduite (raison kabbalistique du MB) : aucune source propre lue.
- **Correction proposée** : ajouter un paramètre de lieu (enIsrael) à levana() et Levana.kt, le 2e jour de fête ne comptant qu'en diaspora. Un soir de Chabbat ou de Yom tov qui n'est pas le dernier : état « pas ce soir (Chabbat / Yom tov), MB 426:12 ; YY 426:33 », pas de carte d'accueil, rappel PREMIER reporté au soir suivant non chômé ou fondu dans le rappel du motsaé. Ne jamais notifier pendant Chabbat ou Yom tov, sauf pour le dernier soir. Garder « Dernier soir » un soir de Chabbat (ex. vendredi 22/01/2027, conforme) ; signaler la veille comme « dernier soir de semaine » n'est qu'une amélioration.

### Tikkoun 'hatsot proposé les nuits de Chabbat et de fête
**Erreur de l'app** · gravité basse · tous · tous
- **Ce que fait l'app** : momentDuSiddour (web/src/js/jour-affiche.js:89 et 96 ; JourAffiche.kt:128 et 135) ne regarde que l'heure et propose « tikoun_hatsot » de 'hatsot à l'aube toutes les nuits ; sans lieu, SiddurMoment.suggestion (Siddur.kt:139, regles.js:297) fait de même avant 5 h. Cette suggestion devient la carte « Maintenant » de l'accueil (app.js:722, AccueilMoment.kt:27). Exemples à Jérusalem : 05/04/2026 à 01:30 ('Hol hamoed Pessa'h), 13/04/2025 (nuit du Séder), 21/11/2026 (nuit de Chabbat) ; à Paris, 23/05/2026 (2e nuit de Chavouot).
- **Ce que dit la source** : la consigne en tête du texte, identique dans les trois siddourim de l'app, exclut ces nuits, comme le Yalkut Yosef. *Consigne tikoun_hatsot S0 b0 ; Kitsour Yalkut Yosef, דיני תיקון חצות, se'if נה*. « אין אומרים תיקון חצות בליל שבת, ראש השנה, כפור, פסח, שבועות, סוכות, שמיני עצרת, וחול המועד של פסח » ; « ויש זמנים שאין אומרים בהם לא תיקון רחל ולא תיקון לאה, ואלו הם: ליל שבת, ליל יום טוב, פסח, שבועות, סוכות, שמחת תורה, חול המועד פסח ».
- **Correction proposée** : dans momentDuSiddour (JS et Kotlin) et SiddurMoment.suggestion, prendre le jour hébreu de la nuit (après minuit, le jour civil courant ; entre 'hatsot et minuit, le lendemain). Si c'est Chabbat, un Yom tov ou 'Hol hamoed Pessa'h, proposer le Chema du coucher ou rien. Selon un vérificateur, le cas incontestable est celui des nuits de semaine de 'Hol hamoed Pessa'h ; les nuits de Chabbat et de Yom tov comptent moins, l'app n'ayant qu'un siddour de semaine.

### Birkat halevana (Edot) : fin de la fenêtre comptée en 15 jours et non d'après la date du mois
**Erreur de l'app** · gravité basse · Edot · tous
- **Ce que fait l'app** : l'usage Edot par défaut, « sept_quinze » (calendrier-juif.js:225 ; Levana.kt, du()), ferme la fenêtre à molad + 15 jours d'heure à heure, sans regarder la date hébraïque. En Tichri 5785, la fin tombe le 18/10/2024 à 04:00 (Jérusalem) : l'app propose le jeudi 17/10/2024, nuit du 16 Tichri, comme « Dernier soir » (de même à Paris et à New York). À l'inverse, en 'Hechvan 5786 la fin (06/11/2025 à 00:33) coupe la nuit du 15, et en Adar I 5787 à Paris le soir du 21/02/2027 (nuit du 15) est refusé.
- **Ce que dit la source** : le Yalkut Yosef compte selon la date : il interdit la nuit du 16, même avant 15 jours révolus, et permet encore la fin de la nuit du 15. *Kitsour Yalkut Yosef 426, se'if לז et כח*. « אין לו לברך ברכת הלבנה בליל ט״ז לחדש, שיש בזה ספק ברכה לבטלה » ; « ובסוף ליל ט״ו לחודש … לאחר שכבר עלה השחר, קודם הנץ החמה ». L'app suit en fait la Michna Beroura (426:17 : « משעת המולד מנינן דמשעה זו מנינן ט"ו יום מעל"ע »).
- **Correction proposée** : en Edot, fin = min(molad + 15 jours, aube du 16 du mois), ou au moins une mention le soir du 16. Pour la nuit du 15, simple divergence entre poskim : ajouter un usage « jusqu'à la nuit du 15 incluse » (Yalkut Yosef), ou indiquer que « sept_quinze » suit la Michna Beroura ; point à vérifier dans le Yabia Omer (V 36 ; VI 38). On peut aussi signaler que certains louhot des Edot s'arrêtent à la mi-mois.

### Lundi-jeudi-lundi de jeûne (בה״ב) après Soukkot et après Pessa'h ignorés
**Différence entre rites** · gravité basse · Ashkenaz, Sfard · tous
- **Ce que fait l'app** : CalendrierJuif.kt et calendrier-juif.js n'appellent pas isBeHaB(), présente dans web/src/vendor/kosher-zmanim-0.9.0.min.js ; web/test/calendrier.test.mjs:76-80 écarte « BeHaB » comme jeûne volontaire. Ces jours-là, l'app affiche un jour ordinaire, עננו replié, et rien le Chabbat de la bénédiction. Dates : 27/10, 30/10 et 03/11/2025 (Chabbat 25/10/2025) ; 19/10, 22/10 et 26/10/2026 ; 11/11, 14/11 et 18/11/2024 ; en Iyar, 27/04, 30/04 et 04/05/2026.
- **Ce que dit la source** : usage établi en Ashkenaz, attesté par le Choul'han Aroukh haRav pour le Sfard (usage 'hassidique actuel partagé) ; pour les Edot, le Choul'han Aroukh dit seulement « יש נוהגים ». *Rema O.H. 492:1 ; Michna Beroura 492:3 et 566:10*. « ובאשכנז וצרפת נהגו להתענות ועושין אותו כמו תענית צבור לקרות ויחל » ; « ומברכין בבהכ"נ בשבת הראשון שאחר ר"ח למי שיתענה בה"ב » ; ויחל seulement à Min'ha aujourd'hui : « ואין דוחין פרשת השבוע בשחרית ולערב קורין ויחל ».
- **Correction proposée** : une condition informative « behab » tirée d'isBeHaB(), en Ashkenaz et en Sfard seulement, sans toucher à la condition « jeune » : « בה״ב (coutume) : Seli'hot selon la synagogue ; עננו pour qui jeûne ; עננו de l'officiant et ויחל à Min'ha seulement s'il y a dix jeûneurs ». Retirer « Avinou malkénou », qu'aucune source citée ne fonde. Ajouter le rappel du « מי שבירך » le Chabbat précédent, reporté au Chabbat suivant quand ce Chabbat est Roch 'Hodech (Choul'han Aroukh haRav 492:4). Rien pour les Edot.

### Seli'hot d'Eloul : ni texte ni annonce
**Différence entre rites** · gravité basse · tous · tous
- **Ce que fait l'app** : aucun des 38 textes des trois siddourim n'est un texte de Seli'hot ; ajouts() et rappelsTefila() n'annoncent rien (RAPPELS_TEFILA ne connaît que pluie, guechem, dix_jours et omer). Les rites ne sont donc pas distingués. Dates attendues : Edot à partir du 16/08/2026 (2 Eloul 5786 un Chabbat) et du 05/09/2027 ; Ashkenaz et Sfard à partir du 06/09/2026, du 26/09/2027 et, pour Roch Hachana 5786 un mardi, du 14/09/2025.
- **Ce que dit la source** : les Edot disent les Seli'hot dès le 2 Eloul, les Ashkénazes à partir du dimanche avant Roch Hachana, une semaine plus tôt si la fête tombe un lundi ou un mardi. *Kitsour Yalkut Yosef, סימן תקפא (מדיני הסליחות), se'if א ; Rema O.H. 581:1*. « מנהגינו לקום באשמורת הבוקר לומר ״סליחות״, החל מיום ראש חודש אלול עד יום הכפורים … וביום ראש חודש עצמו אין מנהגינו לומר סליחות » ; « ועומדים באשמורת לומר סליחות ביום א' שלפני ר"ה ואם חל ר"ה ב' וג' אז מתחילין מיום א שבוע שלפניו ».
- **Correction proposée** : un libellé du jour « Seli'hot » par noussa'h (Edot dès le 2 Eloul ; Ashkenaz et Sfard dès le dimanche calculé), courant jusqu'à la veille de Kippour pour tous. Présenter « sauf Chabbat » comme l'usage général, non comme une citation, et l'usage Sfard (début selon le Rema) comme non sourcé. Le texte des Seli'hot reste hors périmètre.

### Chofar d'Eloul : aucune mention
**Différence entre rites** · gravité basse · tous · tous
- **Ce que fait l'app** : rien sur le chofar dans ajouts() ni dans les consignes des trois siddourim, pour les trois lieux ; il manque donc aussi le « pas de chofar » du 29 Eloul (11/09/2026, 01/10/2027). Seule la halakha du jour affiche une fois, le 01/09/2026, le se'if du Yalkut Yosef sur l'usage ashkénaze.
- **Ce que dit la source** : les Ashkénazes sonnent après Cha'harit dès Roch 'Hodech ; chez les Edot, certains sonnent pendant les Seli'hot ; personne ne sonne la veille de Roch Hachana. *Rema O.H. 581:1 et 581:3 ; Kitsour Yalkut Yosef, עוד בהלכות חודש אלול se'if א, et מהלכות ערב ראש השנה se'if ה*. « מראש חודש ואילך מתחילין לתקוע אחר התפלה שחרית » ; « ואין תוקעין בערב ראש השנה » ; « האשכנזים תוקעים בכל חודש אלול אחר שחרית » ; « אין תוקעים בשופר בערב ראש השנה ».
- **Correction proposée** : facultatif : un libellé « chofar après Cha'harit » en Ashkenaz et en Sfard du 1er au 28 Eloul (usage Sfard présenté comme courant, non sourcé), et « pas de chofar » le 29 Eloul pour les trois rites. Attribuer « ואין תוקעין בערב ראש השנה » à la glose du Rema, et citer le Yalkut Yosef par section et se'if.

### Pourim katan à Jérusalem : pas de distinction de rite pour le festin
**Différence entre rites** · gravité basse · Edot, Ashkenaz · Jérusalem
- **Ce que fait l'app** : partout, Jérusalem comprise, elle affiche « pourim_katan » le 14 Adar I et « chouchan_pourim_katan » le 15 (ex. 21-22/02/2027), sans indication de festin ; MUREE (calendrier-juif.js:69, CalendrierJuif.kt:232) ne renomme que pourim et chouchan_pourim. Rien d'affiché n'est faux.
- **Ce que dit la source** : pour le Yalkut Yosef, le petit festin se fait le 15 à Jérusalem ; pour la Michna Beroura, le 14 seulement, villes murées comprises. *Kitsour Yalkut Yosef 697, se'if ב ; Michna Beroura 697:4*. « ונכון לנהוג בהם מקצת משתה ושמחה, י״ד לבני פרזים, וט״ו לבני ירושלים » ; « אבל לא בט"ו אף לכרכים המוקפין חומה ».
- **Correction proposée** : aucune. Si l'app ajoute un jour un conseil de festin à Pourim katan, le distinguer par rite et par lieu.

### 7 Adar en année embolismique : l'app distingue bien les rites
**Différence entre rites** · gravité basse · tous · tous
- **Ce que fait l'app** : la hilloula de Moché Rabbénou (clé « adar-7 », jour-affiche.js clesHilloula ; Hilloulot.kt) est placée le 7 Adar I (14/02/2027) en Ashkenaz et le 7 Adar II (16/03/2027) en Edot et en Sfard, en Israël comme en diaspora (app.js:2752 et 2976 ; VueJour.kt:192). L'app ne traite pas le jeûne lui-même.
- **Ce que dit la source** : les Ashkénazes jeûnent en Adar I, les Edot préfèrent Adar II. *Michna Beroura 580:15 ; Kitsour Yalkut Yosef, מהלכות חודש אדר, se'if ד*. « ובשנה מעוברת יש דעות בין האחרונים ועיין בפ"ע וסוגין דעלמא להתענות בראשון » ; « והמנהג האחרון יותר נכון להתענות באדר ב' ».
- **Correction proposée** : aucune pour Edot et Ashkenaz. Le rattachement du Sfard aux Edot n'est pas vérifié.

### Birkat halevana à la sortie du 9 Av : heure fixe de 20 h avant la fin du jeûne, et avis du Rema
**Différence entre poskim** · gravité basse · tous · tous
- **Ce que fait l'app** : `soir(d)` vaut toujours 20:00 heure locale (calendrier-juif.js:249, Levana.kt:147), et la fenêtre d'Av s'ouvre à cette heure le jour du jeûne : « Du jeu. 23 juil., 20:00 au … » (VueJour.kt:119, app.js:2858). Le 23/07/2026, la tsét est à 20:22 à Jérusalem, 22:40 à Paris et 21:07 à New York (à Paris et à New York, 20:00 précède même la chki'a) ; de même les 03/08/2025 et 12/08/2027, et pour Kippour (21/09/2026 à Paris, tsét 20:37). Le libellé dit « Pas avant la sortie de Ticha bèAv (Rema 426:2 ; MB 426:11) », sans parler de manger. Le rappel Android, lui, sonne à la tsét.
- **Ce que dit la source** : le Rema refuse le motsaé 9 Av ; la Michna Beroura rapporte les A'haronim qui le permettent après avoir goûté, et le Yalkut Yosef attend la tsét. *Rema O.H. 426:2 ; Michna Beroura 426:11 ; Kitsour Yalkut Yosef, עוד ממנהגי יום תשעה באב, se'if ג*. « ובמוצאי י"כ מקדשין אותה דאז שורין בשמחה אבל לא במוצאי תשעה באב או שאר תענית » ; « אבל דעת האחרונים בכל זה דמקדשין אפילו במוצאי ט"ב ... אלא דכתבו דצריך לטעום קודם » ; « מקדשים הלבנה במוצאי תשעה באב, אבל צריך להמתין עד שיהיה חושך [צאת הכוכבים] ». L'app suit les A'haronim, ce qui se défend ; l'heure de 20:00 n'est qu'un repère d'affichage.
- **Correction proposée** : prendre comme début la tsét du lieu (comme LevanaAlerte.heure) ; sans lieu, n'afficher que la date. Libellé levana_tisha, facultatif : « dès la sortie du jeûne, de préférence après avoir goûté quelque chose (MB 426:11 ; Kitsour Yalkut Yosef 426:35) ; le Rema ne la dit pas au motsaé 9 Av ». L'attribution actuelle au Rema n'est pas fausse, et le motsaé Chabbat du 12 Av, que la MB 426:11 écarte, n'est pas à proposer.

### Birkat halevana le soir du 10 Tévèt : pas de rappel de manger d'abord
**Différence entre poskim** · gravité basse · Ashkenaz (Edot par déduction) · tous
- **Ce que fait l'app** : levana() ne connaît que Kippour et le 9 Av (calendrier-juif.js, vers les lignes 258-269 ; Levana.kt:90-106). Le soir du 10 Tévèt (30/12/2025, 20/12/2026), l'état est « ce_soir », sans restriction ni mention de goûter avant.
- **Ce que dit la source** : selon le Rema, on attend la nuit du 12 ; selon les A'haronim, on peut bénir à la sortie du jeûne après avoir goûté. *Rema O.H. 426:2 ; Michna Beroura 426:11*. « כגון אם לא קידש בחודש טבת עד התענית אין לו לקדש אחר התענית ... אבל דעת האחרונים בכל זה דמקדשין אפילו במוצאי ט"ב וכ"ש בשאר תענית אלא דכתבו דצריך לטעום קודם ». Le Yalkut Yosef (426:35) ne le dit explicitement que pour le 9 Av.
- **Correction proposée** : le soir du 10 Tévèt et des autres jeûnes, sauf Kippour, une note « après avoir goûté quelque chose » ; en Ashkenaz, mentionner le Rema (attendre la nuit du 12). Retirer les exemples des vendredis (10/01/2025, 22/12/2023), où l'on ne bénit pas de toute façon le soir de Chabbat.

### Birkat halevana de Tichri repoussée après Kippour pour tous
**Différence entre poskim** · gravité basse · tous · tous
- **Ce que fait l'app** : levana() (calendrier-juif.js) et Levana.kt (Restriction.KIPPOUR) font commencer la fenêtre au soir de Kippour pour les trois noussa'h, avec le libellé « Pas avant la sortie de Kippour (Rema 426:2) ». Premiers soirs : 12/10/2024, 02/10/2025, 21/09/2026.
- **Ce que dit la source** : le Rema attend la sortie de Kippour et le Yalkut Yosef en fait « notre usage », tout en admettant l'autre ; plusieurs A'haronim préfèrent avant Kippour. *Kitsour Yalkut Yosef 426 §34 ; Michna Beroura 602:10*. « מנהגינו לברך ברכת הלבנה במוצאי יום הכפורים » ; « אבל דע דכמה אחרונים הסכימו שיותר טוב לקיים המצוה מקודם כדי שמצוה זו יכריעהו לכף זכות ».
- **Correction proposée** : aucune. Au plus, mentionner l'autre usage, et citer en Edot le Yalkut Yosef 426 §34 au lieu du Rema 426:2.

### Tikkoun Ra'hel affiché les jours sans Ta'hanoun, à Roch 'Hodech et pendant l'Omer
**Différence entre poskim** · gravité basse · tous · tous
- **Ce que fait l'app** : le texte tikoun_hatsot n'a aucune entrée dans siddur_annotations.json et ne figure pas dans TEXTES (tools/siddur_annotations.py:37). La section « תיקון רחל » et les psaumes de Tikkoun Léa marqués « בימים שאין אומרים תחנון לא יאמר » (c2, c8) restent en clair, par exemple le 10/05/2027 (Omer), le 16/06/2026 (Roch 'Hodech Tamouz), le 08/04/2026 (Nissan) et le 15/09/2026 (dix jours de techouva). La consigne en tête du texte, qui donne la règle exacte, est affichée en clair.
- **Ce que dit la source** : pas de Tikkoun Ra'hel à Roch 'Hodech, de Roch Hachana à Chemini Atseret, à 'Hanouka, à Pourim, en Nissan et pendant l'Omer. *Kitsour Yalkut Yosef, דיני תיקון חצות, se'if נה ; Ben Ich 'Haï, 1re année, Vayichla'h ה*. « ואלו הם הימים שאין אומרים בהם תיקון רחל: ראש חודש [ובער״ח אחר המולד, אף שמתוודים באותו יום], ומראש השנה עד שמיני עצרת, ימי החנוכה, ימי הפורים, כל חודש ניסן, וכל ימי העומר » ; « אין אומרים תיקון רחל בימי העומר, וכן בעשרת ימי תשובה בחול ». Pour la nuit du 9 Av, le Ben Ich 'Haï et le Yalkut Yosef divergent, et l'app ne tranche pas.
- **Correction proposée** : facultative : ajouter tikoun_hatsot à TEXTES ; replier S1 (תיקון רחל) sous tahanoun_chaharit && !omer && !asseret_yemei_techouva, et en Nissan (la veille de Roch 'Hodech après le molad n'a pas encore de clé) ; replier les psaumes c2 et c8 sous tahanoun_chaharit. Noter qu'en Israël on ne dit pas Tikkoun Ra'hel l'année de chemita (Kitsour Yalkut Yosef, se'if נז). Remplacer la référence non vérifiée au Kaf ha'Haïm 1:11.

### Bein hamétsarim : Tikkoun Ra'hel de midi jamais proposé
**Différence entre poskim** · gravité basse · Edot, Sfard · tous
- **Ce que fait l'app** : momentDuSiddour (jour-affiche.js ; JourAffiche.kt, l. 115-137) renvoie null entre 'hatsot et min'ha guedola, quelle que soit la date : à Jérusalem le 05/07/2026 (20 Tamouz), null à 12:50 et « minha » à 13:20 ; null aussi le 20/07/2026. La consigne « בחצות היום בימי בין המצרים אומרים תיקון רחל » reste affichée dans le texte.
- **Ce que dit la source** : c'est un usage, non une obligation. *Kitsour Yalkut Yosef, דיני תיקון חצות, se'if מה et נז*. « בימי בין המצרים רבים נוהגים לומר תיקון חצות אחר חצות היום. ואומרים את סדר תיקון רחל ». La Michna Beroura (1:9 ; 551) ne prévoit pas de Tikkoun de jour : l'Ashkenaz est hors de cause.
- **Correction proposée** : facultative : du 17 Tamouz au 8 Av (par exemple du 02/07 au 22/07/2026), sauf Chabbat et Roch 'Hodech Av, proposer tikoun_hatsot entre 'hatsot et min'ha guedola, avec seule la section תיקון רחל ouverte ; traiter le 9 Av à part.

### Érouv tavchilin jamais rappelé quand une fête tombe un vendredi
**Différence entre poskim** · gravité basse · tous · tous
- **Ce que fait l'app** : aucune condition ni aucun rappel d'érouv tavchilin dans le code ; le texte erouv_tavchilin existe dans le groupe « occasions » des trois siddourim (tools/siddur_occasions.py:75), mais rien ne le met en avant, alors que d'autres textes le sont selon le jour (SiddurActivity.kt l. 54-67, app.js l. 1330-1337). Rien le 21/05/2026 (veille de Chavouot un vendredi), le 02/10/2024 et le 20/09/2028 (Roch Hachana jeudi-vendredi), ni le 16/10/2024 (Soukkot jeudi-vendredi, diaspora seulement). La règle fait l'unanimité, mais les rappels de l'app se limitent par choix aux changements dans la prière : l'omission se défend.
- **Ce que dit la source** : la veille d'un Yom tov qui tombe un vendredi, on fait l'érouv tavchilin pour cuisiner en vue de Chabbat. *Choul'han Aroukh O.H. 527:1 ; Kitsour Yalkut Yosef 527:1*. « יו"ט שחל להיות בערב שבת לא יבשל בתחלה לצורך שבת בקדירה בפני עצמה » ; « יום טוב שחל להיות בערב שבת אסרו מדברי סופרים לבשל בקדרה בפני עצמה, או לאפות פת לצורך השבת, אלא על ידי עירוב תבשילין ».
- **Correction proposée** : facultative : un rappel « veille de fête », distinct de RappelsTefila, déclenché quand le lendemain et le vendredi suivant sont chômés, avec enIsrael (fêtes de deux jours en diaspora ; en Israël, Roch Hachana jeudi-vendredi et fêtes d'un jour tombant un vendredi), renvoyant au texte erouv_tavchilin. Traiter alors en même temps la recherche et la destruction du 'hamets.

### Yom Kippour katan de la veille de Roch 'Hodech non signalé
**Différence entre poskim** · gravité basse · tous · tous
- **Ce que fait l'app** : isYomKippurKatan() (vendor kosher-zmanim) n'est appelée nulle part, et calendrier.test.mjs:80 écarte « Katan ». Rien n'est signalé le 20/11/2025 (29 'Hechvan 5786), le 09/11/2026, le jeudi 28/11/2024 (avancé, le 29 étant un Chabbat), le 14/07/2026 (29 Tamouz) ni le jeudi 24/07/2025. L'absence de Ta'hanoun à Min'ha de la veille de Roch 'Hodech est conforme.
- **Ce que dit la source** : c'est une coutume facultative, dans les mêmes termes chez les Edot et en Ashkenaz. *Kitsour Yalkut Yosef 417 (תענית בערב ראש חודש), se'if ה ; Michna Beroura 417:4*. « יש נוהגים להתפלל במנחה של ערב ראש חודש תפלת יום כפור קטן » ; « ויש נוהגין לעשות למנחה סדר יוה"כ קטן ».
- **Correction proposée** : facultative : afficher « Yom Kippour katan (pour qui en a l'usage) » les jours où isYomKippurKatan() est vraie, sans toucher aux conditions de prière.

### Lectures des Chabbatot spéciaux (Chekalim, Zakhor, Para, ha'Hodech) non affichées
**Différence entre poskim** · gravité basse · tous · tous (Jérusalem pour Pourim triple)
- **Ce que fait l'app** : jour().paracha ne donne que formatParsha (calendrier-juif.js:167, CalendrierJuif.kt:344) ; getSpecialShabbos() et formatSpecialParsha() ne sont pas utilisés. Le 28/02/2026 (Zakhor), la carte affiche seulement « תצוה » ; le 06/03/2027 (Chekalim), « ויקהל » ; le 15/03/2025 à Jérusalem (Chabbat 15 Adar, Pourim triple), « כי תשא » sans le maftir ויבא עמלק. La paracha affichée est bien lue, et l'app ne couvre aucune lecture de Chabbat : le défaut se défend comme choix de périmètre.
- **Ce que dit la source** : la lecture de Zakhor est une mitsva de la Torah ; à Jérusalem, le Chabbat 15 Adar, on lit ויבא עמלק dans un second Séfer. *Kitsour Yalkut Yosef 685, Zakhor, se'if ג ; Choul'han Aroukh O.H. 688:6*. « אף על פי שקריאת פרשת זכור היא מצוה מן התורה » ; « וביום שבת מוציאין שני ספרים ובשני קורין ויבא עמלק ».
- **Correction proposée** : facultative : afficher HebrewDateFormatter.formatSpecialParsha() à côté de la paracha quand getSpecialShabbos() n'est pas nul, en JS et en Kotlin ; à Jérusalem, le Chabbat 15 Adar, ajouter « מפטיר ויבא עמלק » (getSpecialShabbos() rend 0 ce jour-là). Retirer la mention non vérifiée de Méguila 29a.

#### Constats écartés
- **'Hanouka : ni heure d'allumage, ni nombre de bougies, ni repère du premier soir** : fonction absente, pas une erreur ; l'app affiche la tsét exigée (Kitsour Yalkut Yosef 672:1) et chaque siddour porte sa consigne pour שהחיינו.
- **'Hanouka : ordre de l'allumage le vendredi et au motsaé Chabbat non indiqué** : il n'y a pas d'ordre à imposer, puisque la MB 681:3 laisse le choix à la maison (« ובבית דעביד כמר עביד ודעביד כמר עביד »), que l'usage Sfard est partagé et que la règle du vendredi est commune à tous les rites.
- **Veille de Pessa'h un Chabbat : ni recherche du 'hamets le jeudi soir ni jeûne des premiers-nés signalés** : l'app n'annonce aucune mitsva pratique, le texte bedikat_hamets existe dans les siddourim, et le Yalkut Yosef ne conseille pas de jeûner (« ואין צורך להתענות כלל »).


---

## Horaires halakhiques

### Vendredi de fête : l'allumage de Chabbat placé après la sortie des étoiles
**Erreur de l'app** · gravité haute · tous les noussa'h · tous lieux (Israël, Jérusalem, diaspora)
- **Ce que fait l'app** : quand aujourd'hui et demain sont chômés, `jour-affiche.js:64` et `JourAffiche.kt:100` placent l'« allumage » à tsét 8,5° (méthode `apres_tset`, « pas avant la sortie de la veille ») sans regarder si demain est Chabbat. Aucun allumage n'est donc donné avant la chki'a : Jérusalem, 2026-05-22 (Chavouot), chki'a 19:33, allumage 20:14 ; New York, 2026-04-03 (Pessa'h), 19:22 / 20:04 ; Paris, 2024-10-04 (Roch Hachana), 19:22 / 20:09. Même défaut en vol (`VolCalendrier.kt:53-56`, `vol.js:355`, jalon « commence à tsét (8,5°) »), et autres vendredis touchés : 2022-04-22, 2024-10-18, 2024-10-25, 2027-04-23, 2027-06-11, 2028-09-22, 2028-10-06, 2028-10-13, 2029-04-06, 2030-04-19, 2030-06-07 ; ChabbatAlerte n'est pas touchée.
- **Ce que dit la source** : quand la fête tombe un vendredi, on allume pour Chabbat pendant la fête, avant la chki'a ; la règle vaut pour tous les rites. *Kitsour Choul'han Aroukh Yalkut Yosef 514:7 (« סימן תקיד - דיני הדלקת נרות יום טוב »)* : « וכשחל יום טוב ביום שישי, מדליקין נר שבת ביום טוב כעשרים דקות קודם השקיעה » ; *Michna Beroura 261:23* : « יזהר מאד לגמור הדלקתם קודם שתשקע החמה ».
- **Correction proposée** : dans `horaires` (JS et Kotlin), quand demain est un samedi, placer `Zmanim.allumage(lieu, date, minutes)` avant la chki'a, même si le jour est chômé ; garder `apres_tset` pour fête puis fête et pour Chabbat puis fête. En vol, poser un jalon `ENTREE` à la chki'a avec l'allumage. Ajouter des tests : Jérusalem 2026-05-22, New York 2026-04-03, Paris 2024-10-04. Choul'han Aroukh 527:19 (érouv tavchilin) ne porte pas sur l'heure et passe au second plan.

### Edot : aube calculée en degrés et non en 72 minutes proportionnelles
**Erreur de l'app** · gravité moyenne · Edot · tous lieux
- **Ce que fait l'app** : `Zmanim.kt:70` et `zmanim.js:12` calculent l'aube à 16,1° (`getAlos16Point1Degrees`) pour tous les noussa'h. Écart avec 72 min zmaniyot : Jérusalem 2026-12-19, 05:15:56 contre 05:33:20 (−17,4 min) ; New York 2026-12-25, −32,8 min ; Paris 2026-06-20, 03:00:46 contre 04:09:39 (−68,9 min). L'écart n'est faible qu'aux équinoxes à Jérusalem.
- **Ce que dit la source** : le Yalkut Yosef exige 72 minutes zmaniyot avant le nets et écarte les luhot calculés autrement ; le Biour Halakha 89:1 (Ashkenaz) ne fixe pas de méthode, et les 16,1° y restent conformes. *Kitsour Yalkut Yosef 89:12* : « יש לחשב תמיד זמן ״עמוד השחר״ שבעים ושתים דקות, זמניות, קודם הנץ החמה ».
- **Correction proposée** : rendre le profil dépendant du noussa'h. En Edot, aube = `getAlos72Zmanis`, avec le libellé « 72 דקות זמניות (ילקוט יוסף) » ; garder 16,1° pour Sfard et Ashkenaz.

### Edot : plag hamin'ha calculé selon le Gra et non selon le Yalkut Yosef
**Différence entre rites** · gravité moyenne · Edot · tous lieux
- **Ce que fait l'app** : `Zmanim.kt:80` et `zmanim.js:22` donnent le plag par `getPlagHamincha` (heures saisonnières du lever au coucher) pour tous. Jérusalem, vendredi 2026-06-19 : 18:18:18 contre 18:34:19 selon le Yalkut Yosef (−16 min) ; New York 2026-06-20 : −17,0 min ; Paris 2026-06-20 : −18,2 min ; Jérusalem 2026-12-25 : −11,3 min. Un utilisateur Edot qui allume, accepte Chabbat ou dit Arvit au plag affiché le fait avant le plag de son rite.
- **Ce que dit la source** : pour les Edot, le plag tombe 1¼ heure zmanit avant tsét, lui-même 13,5 min zmaniyot après la chki'a ; le Michna Beroura 233:4 rapporte deux opinions sans trancher. *Kitsour Yalkut Yosef 263:45* : « אין להדליק נרות שבת בעוד היום גדול, שנשאר יותר משעה ורבע לפני צאת הכוכבים, שהוא קודם זמן פלג המנחה » ; *233:5* : « כשלש עשרה דקות וחצי [בדקות זמניות] אחר שקיעה החמה הנראית לעינינו ».
- **Correction proposée** : pour les Edot, plag = (chki'a + 13,5 min zmaniyot) − 1,25 heure zmanit, avec la méthode nommée sous l'horaire ; pour l'Ashkenaz, garder le Gra avec la mention « selon le Gra ». Le vérificateur note que, au regard de 263:45, le point peut se lire comme une erreur de l'app pour les Edot, atténuée parce que l'app nomme sa méthode.

### Edot : fin du Chema « Maguen Avraham » calculée en minutes fixes
**Différence entre rites** · gravité moyenne · Edot · tous lieux
- **Ce que fait l'app** : `Zmanim.kt:73` et `zmanim.js:15` utilisent `getSofZmanShmaMGA`, journée de 72 min fixes (`strings.xml:735`), pour tous. Jérusalem 2026-06-20 : 08:31:19 contre 08:24:38 en 72 min zmaniyot (+6,7 min) ; New York : +9,3 min ; Paris : +12,5 min ; en hiver l'app est plus tôt (Jérusalem 2026-12-25 : −5,8 min).
- **Ce que dit la source** : le Yalkut Yosef compte a priori depuis l'aube, elle-même à 72 min zmaniyot ; le Michna Beroura 58:4 rapporte les deux opinions sans fixer de minutes, et les 72 min fixes côté Ashkenaz relèvent de l'usage. *Kitsour Yalkut Yosef 58:3* : « ולכתחלה יש להחמיר לגבי סוף זמן קריאת שמע, לחשוב משעת עלות השחר » ; *89:12* : « יש לחשב תמיד זמן ״עמוד השחר״ שבעים ושתים דקות, זמניות, קודם הנץ החמה ».
- **Correction proposée** : pour les Edot, journée de 72 min zmaniyot (`getSofZmanShmaMGA72MinutesZmanis`), aussi pour la fin de la Téfila et le 'hamets, et l'écrire sous l'horaire. Selon le vérificateur, le cas peut être classé en erreur de l'app pour les Edot, puisque 89:12 met en garde contre ces luhot.

### Edot : heure de Rabbénou Tam en minutes fixes
**Différence entre rites** · gravité moyenne · Edot · tous lieux
- **Ce que fait l'app** : la ligne « Tsét, Rabbénou Tam » vaut `getTzais72` (72 min fixes) pour tous (`zmanim.js:25`, `Zmanim.kt:83`). Jérusalem 2026-06-20 : 20:59:31 contre 21:12:53 en zmaniyot (−13,4 min) ; New York : 21:42:33 contre 22:01:07 (−18,6 min) ; Paris : −25,1 min ; en hiver l'app est plus stricte (Jérusalem 2026-12-19 : 17:50:28 contre 17:38:56). L'heure de sortie affichée reste tsét 8,5° : le défaut porte sur cette ligne seulement.
- **Ce que dit la source** : le Yalkut Yosef recommande Rabbénou Tam en heures zmaniyot, avec une exception conditionnelle pour l'Europe ; côté Ashkenaz, le Biour Halakha 261:2 dispense des zmaniyot les jours longs. *Kitsour Yalkut Yosef, « סימן רצג - זמן צאת השבת », se'if ג* : « יחמיר על עצמו שלא לעשות מלאכה עד שיעבור שיעור שבעים ושתים דקות [בשעות זמניות] » ; *se'if ז* : « והעיקר לדינא שיש לחשב לפי שעות זמניות ».
- **Correction proposée** : pour les Edot, Rabbénou Tam = `getTzais72Zmanis`, et 72 min fixes seulement là où le Yalkut Yosef l'admet (Europe, sous condition) ; pour l'Ashkenaz, garder 72 min fixes avec la mention du Biour Halakha.

### Edot à Jérusalem : allumage proposé 40 minutes avant le coucher
**Différence entre rites** · gravité moyenne · Edot · Jérusalem
- **Ce que fait l'app** : à Jérusalem (`mukafChoma`), `ZmanimActivity.kt:79-82` et `web/src/js/app.js:4360-4362` proposent à tous, quel que soit le noussa'h, « À Jérusalem, l'usage est d'allumer 40 min avant la chki'a » ; `ZmanimActivity.kt:112-115` et `app.js:2626` libellent les 40 min « coutume de Jérusalem » (« מנהג ירושלים »). La proposition ne dépend d'aucune date, et aucun test ne la couvre.
- **Ce que dit la source** : pour les Séfarades, on allume à Jérusalem aussi environ 20 min avant la chki'a ; les 40 min sont l'usage du calendrier de Rav Tukachinsky. *Kitsour Yalkut Yosef 263:47 (« סימן רסג - זמן ההדלקה »)* : « להדליק את הנר ארבעים דקות קודם השקיעה. שאין לזה כל יסוד בהלכה ».
- **Correction proposée** : réserver la proposition et le libellé « coutume de Jérusalem » aux noussa'h Sfard et Ashkenaz ; pour les Edot, proposer 20 min (déjà dans `ALLUMAGES`) et ajouter un test. Le vérificateur note que la ligne Edot peut être durcie en erreur de l'app, le Yalkut Yosef qualifiant cet usage chez un Séfarade de « מנהג בטעות ».

### Edot : heure de sortie de Chabbat et de fête sans fondement pour ce rite
**Différence entre rites** · gravité basse · Edot · tous lieux
- **Ce que fait l'app** : la sortie de Chabbat ou de fête est toujours tsét 8,5° (`getTzaisGeonim8Point5Degrees`, `JourAffiche.kt:89-103`, `jour-affiche.js:53-66`), sans paramètre de noussa'h ; la bannière d'Arvit part du même tsét. Jérusalem 2026-09-13 : chki'a 18:47, sortie 19:24 (+36 min) ; 2026-06-20 : +42 min ; Kippour 2026-09-21 : sortie 19:13.
- **Ce que dit la source** : pour le Yalkut Yosef, Chabbat sort environ 20 min après la chki'a (Gueonim, 13,5 min zmaniyot), et Rabbénou Tam est recommandé ; les horaires qui ne suivent ni l'un ni l'autre sont sans fondement. Les trois petites étoiles (Michna Beroura 293:3, Choul'han Aroukh 293:2) valent pour tous : les rites divergent sur la façon de les estimer. *Kitsour Yalkut Yosef, « סימן רצג - זמן צאת השבת », se'if ב* : « וזמני צאת השבת המתפרסמים בלוחות רבים, אין להם כל יסוד בהלכה ».
- **Correction proposée** : profil Edot avec tsét = chki'a + 13,5 min zmaniyot et, pour la sortie, Rabbénou Tam en 72 min zmaniyot mis en avant (ou les deux, nommés) ; garder 8,5° pour Ashkenaz et Sfard.

### Jeûnes : ni heure de début ni heure de fin affichées
**Différence entre poskim** · gravité basse · tous les noussa'h · tous lieux
- **Ce que fait l'app** : `horaires()` (`JourAffiche.kt`, `jour-affiche.js`) n'ajoute une entrée ou une sortie que pour les jours chômés : aucune ligne « début du jeûne » ou « fin du jeûne » les 2025-01-10, 2025-03-13, 2025-08-03, 2026-07-23 et 2028-03-09. La veille du 9 Av (2026-07-22) rien n'est signalé, et le samedi 2025-08-02 (9 Av repoussé) seule « Sortie de Chabbat ou de fête 20:14 » apparaît, alors que le jeûne a commencé à la chki'a (19:34).
- **Ce que dit la source** : les textes fixent l'obligation de celui qui jeûne, sans exiger d'affichage ; l'aube, la chki'a et tsét figurent chaque jour à l'écran, et ZMANIM.md ne promet que l'allumage et la sortie des jours chômés. *Choul'han Aroukh O.H. 550:2* : « ואין צריך להפסיק בהם מבעוד יום » ; *Kitsour Yalkut Yosef 550:2* : « חוץ מתשעה באב שצריך להפסיק בו מבעוד יום ».
- **Correction proposée** : amélioration hors portée déclarée, en option : « Début du jeûne » à l'aube, « Fin du jeûne » à tsét, et pour le 9 Av, Chabbat compris, « le jeûne commence à la chki'a » la veille. Ces bornes devraient suivre le rite (Edot : aube à 72 min zmaniyot, tsét environ 20 min après la chki'a).

### Veille de Pessa'h : heures du 'hamets absentes
**Différence entre poskim** · gravité basse · tous les noussa'h · tous lieux
- **Ce que fait l'app** : ni `Zmanim.kt:69-85` (PROFIL), ni `zmanim.js`, ni `strings.xml` n'ont de clé « hamets » ou « biour ». À Jérusalem le 2026-04-01, la fin de la 4e heure n'apparaît que sous « Fin de la Téfila » (MGA 10:14:03, Gra 10:38:03), et la fin de la 5e heure (MGA 11:28:37, Gra 11:40:37) n'apparaît nulle part ; rien non plus le 2027-04-21, ni le vendredi 2025-04-11 quand la veille tombe un Chabbat (2025-04-12).
- **Ce que dit la source** : l'app n'affiche rien que les textes interdisent ; il manque le libellé du jour et la limite du bi'our. *Kitsour Yalkut Yosef 443:1* : « אסור לאכול חמץ ביום י״ד מסוף ארבע שעות ומעלה, דהיינו שליש היום, וחושבים השעות בשעות זמניות מעמוד השחר עד צאת הכוכבים » ; *Choul'han Aroukh O.H. 443:1* : « ומתחלת שעה ששית ולמעל' אסרוהו גם בהנא' ».
- **Correction proposée** : quand `fetes` contient `erev_pessah`, ajouter « fin de la consommation » (4e heure) et « fin du bi'our » (fin de la 5e heure) : pour les Edot, MGA en heures zmaniyot depuis l'aube (10:13 au lieu de 10:14 à Jérusalem le 2026-04-01) ; la ligne Gra pour tous ; quand la veille tombe un Chabbat, prévenir le vendredi.

### Edot en diaspora l'hiver : Cha'harit proposée avant l'aube du Yalkut Yosef
**Différence entre poskim** · gravité basse · Edot · diaspora
- **Ce que fait l'app** : michéyakir est à 11,5° pour tous (`Zmanim.kt:71`, `zmanim.js:13`), et `momentDuSiddour` (`JourAffiche.kt:128-129`) propose Cha'harit dès michéyakir. Paris 2026-12-21 : michéyakir 07:26:45 contre l'aube du Yalkut Yosef 07:51:46, et « chaharit » proposé à 07:30 ; Paris 2026-12-25 : 07:28:31 contre 07:53:24 ; New York 2026-12-25 : 06:15:42 contre 06:22:45. À Jérusalem, michéyakir tombe après l'aube du Yalkut Yosef plus 6 min.
- **Ce que dit la source** : appliqué tel quel hors d'Israël, le Yalkut Yosef place l'aube à 72 min zmaniyot partout ; un autre avis séfarade compte les zmanim aux degrés hors d'Israël, et l'app y est conforme. *Kitsour Yalkut Yosef 89:12* : « יש לחשב תמיד זמן ״עמוד השחר״ שבעים ושתים דקות, זמניות, קודם הנץ החמה » ; *89:10* : « המתפלל קודם עמוד השחר לא יצא ידי חובת תפלת שחרית ».
- **Correction proposée** : suggestion, pas exigence : pour le noussa'h Edot, un réglage « zmanim du Yalkut Yosef / Or ha'Haïm » (aube = nets − 72 min zmaniyot, michéyakir = aube + 6 min zmaniyot, ou une heure avant le nets a priori), avec `momentDuSiddour` borné par cette aube. À défaut, préciser à l'écran que le Yalkut Yosef compte l'aube autrement.

### Hautes latitudes l'été : horaires manquants ou dans le désordre
**Différence entre poskim** · gravité basse · tous les noussa'h · diaspora
- **Ce que fait l'app** : dès environ 50,5° N l'été, l'aube à 16,1° est « absente », sans repli : Londres 2026-07-02 (17 Tamouz), et Manchester, Anvers, Bruxelles autour du 2026-06-21. La ligne « Tsét, Rabbénou Tam » (72 min fixes) tombe avant la sortie à 8,5° : Londres 2026-06-20, sortie 22:36 et Rabbénou Tam 22:33 ; 2026-07-04, 22:32 et 22:31. ZMANIM.md et les commentaires de `Zmanim.kt` et `zmanim.js` ne signalent le problème qu'au-delà de 60° ou du cercle polaire.
- **Ce que dit la source** : la sortie affichée, la plus tardive des deux heures, va dans le sens du Michna Beroura, et le Yalkut Yosef admet l'horloge fixe en Europe ; le repli de l'aube est disputé et aucun texte cité ne l'impose. *Michna Beroura 261:23* : « ובמקומותינו שנוטה לצד צפון העולם מתארך הרבה יותר ע"כ יש ליזהר מאד שלא לעשות מלאכה במוצ"ש » ; *Kitsour Yalkut Yosef 293:7* : « ובפרט בארצות אירופא שהלילה מתאחר, שאז יש להקל לחשב לפי השעון הרגיל ».
- **Correction proposée** : documenter le seuil réel (environ 50,5° N au solstice) dans ZMANIM.md et les commentaires ; en option, un repli déclaré pour l'aube (72 min fixes ou zmaniyot, avec mention) et un signalement quand tsét 8,5° passe après Rabbénou Tam. Les griefs sur michéyakir (même schéma à Paris, mélange de méthodes du profil) et sur le « début du jeûne » (absent partout) sont retirés.

### Ashkenaz : aube en degrés et journée du Maguen Avraham en minutes fixes, sans le dire
**Différence entre poskim** · gravité basse · Ashkenaz · tous lieux
- **Ce que fait l'app** : l'aube affichée est à 16,1° (`Zmanim.kt:70`), mais la journée du Maguen Avraham commence 72 min fixes avant le lever (`Zmanim.kt:73`). New York 2026-06-20 : aube 03:35:32, début de la journée du MGA 04:12:48 (37 min d'écart) ; Paris : 03:00:51 contre 04:34:46 (94 min). L'écran nomme chaque méthode sans dire qu'elles divergent.
- **Ce que dit la source** : le Maguen Avraham compte sa journée depuis l'aube ; le Biour Halakha 261:2 rapporte le débat entre heures fixes (Pri Megadim) et zmaniyot (Min'hat Kohen) sans trancher. *Michna Beroura 58:4* : « ומונין אלו הג' שעות מזמן עמוד השחר כן כתב המ"א » ; *Biour Halakha 89:1* : « קודם הנץ החמה כשיעור שעה וחומש שעה ».
- **Correction proposée** : soit le MGA en 16,1° (`getSofZmanShmaMGA16Point1Degrees`), soit l'aube à 72 min ; à défaut, une note sous la ligne MGA.

### Ashkenaz : plag hamin'ha selon le Gra seulement
**Différence entre poskim** · gravité basse · Ashkenaz · tous lieux
- **Ce que fait l'app** : `Zmanim.kt:80` calcule le plag selon le Gra (`getPlagHamincha`), avec le libellé « heures saisonnières du lever au coucher », qui ne nomme pas le Gra. Jérusalem 2026-06-21 : 18:18:46, contre environ 19:15:45 de l'aube à tsét (72 min) : l'app suit l'avis le plus tôt.
- **Ce que dit la source** : le Michna Beroura rapporte deux opinions sans trancher, en notant que le Mé'haber pose l'avis aube–tsét (« וכך סתם המחבר ») ; en 261:25, il impose seulement de s'en tenir a posteriori à une acceptation faite au plag d'avant la chki'a. *Michna Beroura 233:4* : « די"א דחשבינן מעמוד השחר עד צאת הכוכבים ... וי"א דחשבינן הי"ב שעות מנץ החמה עד שקיעתה ».
- **Correction proposée** : facultative : ajouter « selon le Gra » au libellé, comme pour « Fin du Chema (Gra) ».

#### Constats écartés
- **Heures d'attente (sortie, allumage tardif) tronquées vers le plus tôt** : les secondes coupées (Jérusalem 2026-11-21, 17:15:44 affiché « 17:15 ») ne font jamais tomber l'heure avant le tsét du rite, car la mesure à 8,5° a déjà plusieurs minutes de marge (Yalkut Yosef 293:2 : environ 20 à 30 min ; Michna Beroura 293:3) ; arrondir vers le haut relève du confort d'affichage.
- **Calcul des horaires au niveau de la mer, Jérusalem comprise** : aucune divergence entre poskim n'est établie, car « השקיעה הנראית » du Yalkut Yosef oppose les Gueonim à Rabbénou Tam, et non le relief au niveau de la mer, et le Michna Beroura 89:1 ne dit rien de l'altitude des luhot.


---

## Autres

### Bein hamétsarim : la musique avec instruments reste proposée
**Différence entre poskim** · gravité basse · tous les noussa'h (Edot, Sfard, Ashkenaz) · tous lieux

- **Ce que fait l'app** : Le lecteur de musique (MusiquePlay.kt, web/src/js/musique.js) ne tient compte d'aucune date. Il est actif par défaut (Store.kt:1389, web/src/js/store.js:499) et démarre avec le minuteur de la séance, avec des niggounim joués avec instruments. C'est aussi le cas pendant l'Omer et du 17 Tamouz au 9 Av, par exemple le 9 Av 5786 (2026-07-23). Pourtant, l'app repère déjà la période (YalkutYosef.kt:49 renvoie « bein_hametsarim »). La halakha du jour de cette période n'affiche pas non plus le se'if concerné.
- **Ce que dit la source** : Pendant l'Omer et Bein hamétsarim, on évite d'écouter des chants accompagnés d'instruments, même enregistrés. Seule la réjouissance d'une mitsva fait exception, et elle dépend de l'utilisateur. *Kitsour Choul'han Aroukh Yalkut Yosef 551:ו* : « מכל מקום בימי הספירה וימי בין המיצרים יש להימנע מלשומעם. אפילו דרך הרדיו או טייפ וכדומה ». Pour l'Omer, voir aussi *YY Kitsour 493:ח* : « נכון שיחמירו בימי הספירה שלא לשמוע בהם שירים המלווים עם כלי נגינה ». Les Ashkénazes sont au moins aussi stricts (*YY 551:ו* : « והאשכנזים נוהגים להחמיר » ; *MB 551:16*).
- **Pourquoi « requalifié »** : Les faits sont confirmés. Mais le lecteur est un outil que l'utilisateur règle lui-même, et l'app ne le présente pas comme soumis aux règles du jour. Un vérificateur range donc ce point hors de son champ halakhique.
- **Correction proposée** : C'est une amélioration facultative. Du 17 Tamouz au 9 Av, et pendant l'Omer sauf Lag baOmer, afficher un rappel discret avec la source dans l'écran Musique ou au lancement d'une séance musicale. On peut aussi ajouter le se'if 551:ו à la sélection yalkut_yosef.json de la période bein_hametsarim. Il ne faut pas couper la musique d'office, car l'exception de réjouissance d'une mitsva dépend de l'utilisateur.


---

## Compléments (règles oubliées par les deux premiers audits)

### Le statut Israël ou diaspora suit la position du téléphone, pas la résidence du voyageur
**Erreur de l'app** · gravité haute · tous les noussa'h (Edot, Sfard, Ashkenaz) · tous lieux

- **Ce que fait l'app** : Elle recalcule Israël ou diaspora à chaque changement de lieu. Côté Android, cela passe par Store.setLieuZmanim (Store.kt:487-497) et ChoixLieu.enregistrerPosition (ChoixLieu.kt:225-226). Côté web, par store.setLieu (store.js:260-265) et localiserPosition (app.js:2572). Si le lieu est « ma position », ce calcul se refait automatiquement à chaque ouverture de Zmanim (ZmanimActivity.kt:38) ou de la Boussole (BoussoleActivity.kt:55), et chaque fois que la position date de plus de 6 h (MainActivity.kt:149). Le réglage « Région » (SettingsActivity.kt:128) est donc écrasé sans aucun message. Par exemple, le 2026-10-04, un Israélien à New York voit Sim'hat Torah et l'office de Yom tov, et un visiteur de diaspora en Israël voit Isrou 'hag.
- **Ce que dit la source** : Le statut dépend de la résidence et de l'intention de revenir. *Choul'han Aroukh O.H. 496:3* : « בני ארץ ישראל שבאו לחוצה לארץ אסורים לעשות מלאכה ביו"ט שני ביישוב אפילו דעתו לחזור ». *Michna Beroura 496:13* : « ובן חו"ל שבא לא"י אם דעתו לחזור למקומו צריך לעשות שני ימים יו"ט ». Pour les Edot : *Kitsour YY 496 §ה* : « כמו המקום שיצא משם » ; *Kitsour YY 31 §ג* : « ויניח תפילין בביתו בצינעא ».
- **Correction proposée** : Créer un réglage déclaratif « mon statut pour le Yom tov chéni : Israël ou diaspora » que la position ne modifie jamais. La position sert seulement à proposer un changement, par une question. Le réglage doit couvrir :
  - l'émissaire installé à l'étranger avec sa famille, qui est traité comme un ben 'houts laarets (Kitsour YY 496 §יא, MB 496:13) ;
  - le ben 'houts laarets qui a un logement en Israël et y passe les fêtes, qui peut garder un seul jour (Kitsour YY 496 §לג).

  Le calendrier de prière (jour, conditionsPour, VolCalendrier) suit ce réglage. Pour un ben Erets Israël en diaspora le jour du Yom tov chéni, afficher l'office de semaine avec une note : Amida murmurée, tefillin en privé, pas de melakha. En Ashkenaz, signaler l'avis contraire du 'Hakham Tsvi (un seul jour pour le visiteur) ; l'app suit le MB, qui demande deux jours.

### Bougies de Chabbat (Edot) : la consigne fait bénir après l'allumage
**Erreur de l'app** · gravité haute · Edot · tous lieux

- **Ce que fait l'app** : Dans siddur_edot.json, le texte nerot_chabbat (bloc 0:1) affiche en clair « ואחר הדלקת נרות שבת תברך », chaque vendredi. Le bloc 0:2 dit l'inverse pour le Yom tov. siddur_annotations.json n'a aucune entrée pour nerot_chabbat. Le siddour suit ici le Ben Ich 'Haï.
- **Ce que dit la source** : *Kitsour YY רסג §לג* : « הברכה צריכה להיות קודם ההדלקה … ולכן אשה המברכת לאחר ההדלקה נכנסת בספק ברכה לבטלה לדעת מרן השלחן ערוך ». Au *§לה* : « אין לה לברך לאחר ההדלקה על ידי כך שתניח ידיה כנגד פניה ותברך ». Voir aussi *תרי §ב* et *תקיד*, note כז. De son côté, *Ben Ich 'Haï, 2e année, Noa'h §10* (Sefaria ; index h[9] du JSON) : « ודווקא בשבת כתבנו לברך אחר ההדלקה, אבל ביו"ט מברכין ואח"כ מדליקין ».
- **Correction proposée** : Ne pas modifier le texte. Ajouter un indice permanent en tête du texte : « Consigne du siddour selon l'usage du Ben Ich 'Haï (Noa'h, 2e année, §8 et §10). Le Yalkut Yosef (רסג §לג-לה ; תרי §ב ; תקיד, note כז) : bénir avant d'allumer, le Chabbat comme le Yom tov. Qui a allumé sans bénir ne bénit plus après. » Les numéros §7 et §9 donnés au départ étaient des index JSON qui commencent à 0.

### Birkat haRoé sur la mer (Edot) : bénédiction complète que le Yalkut Yosef exclut
**Erreur de l'app** · gravité haute · Edot · tous lieux

- **Ce que fait l'app** : Le texte « yam » de siddur_edot.json est emprunté au Sfard (Torat Emet 357) par tools/siddur_occasions.py. Il affiche « בָּרוּךְ אַתָּה יְהֹוָה אֱלֹהֵינוּ מֶלֶךְ הָעוֹלָם, עֹשֶׂה אֶת הַיָּם הַגָּדוֹל », sans annotation, tous les jours. Le même bloc figure dans les trois siddourim.
- **Ce que dit la source** : *Kitsour YY, סימן רכח §א* : « מנהגינו שלא לברך ברכת שעשה את הים הגדול על הים הגדול בשם ומלכות, כי יש ספק מה הוא הים הגדול שדיברו בו חכמינו ». Cela vaut pour la Méditerranée comme pour l'océan, une fois tous les trente jours.
- **Correction proposée** : Dans tools/siddur_occasions.py, donner à l'Edot un texte « yam » propre : la consigne « מנהגינו לברך בלי שם ומלכות (ילקו״י רכח) », le Chem et la Malkhout entre parenthèses, et la mention « אחת לשלושים יום ». Ne pas modifier le JSON à la main.

### Min'ha (Sfard) : toute la fin de l'office est repliée sous « Ta'hanoun »
**Erreur de l'app** · gravité haute · Sfard · tous lieux

- **Ce que fait l'app** : siddur_annotations.json (sefard/minha) applique la condition tahanoun_minha à toute la section 2, qui compte 37 blocs :
  - le Ta'hanoun (blocs 0-16) ;
  - le Kaddich titkabel (17-23) ;
  - Alénou (24-26) ;
  - le Kaddich yatom (27-31) ;
  - לדוד ה׳ אורי (32-33) ;
  - למנצח (35-36).

  La cause est tools/siddur_annotations.py:152, qui donne la condition à la section entière dès que son titre est « תחנון ». Le rendu est le même sur le web (app.js:1452) et sur Android (SiddurJour.kt:132-143). Tout est donc replié chaque jour sans Ta'hanoun à Min'ha : le vendredi 2025-09-26, et du 11 au 21 Tichri (2025-10-05, 2025-10-12), justement quand לדוד est requis.
- **Ce que dit la source** : *Piskei haSiddour, סיום תפלת שחרית §13* (Sefaria, éd. Kehot) : « מן ראש חדש אלול עד אחר "הושענא רבה" אחר שיר של יום ובמנחה קדם "עלינו" — אומרים זה: "לדוד ה' אורי גו'" ». Le Kaddich et Alénou ne dépendent pas du Ta'hanoun.
- **Correction proposée** : Mettre tahanoun_minha sur les blocs 0-16 seulement (et sur 35-36, למנצח, dit les jours avec Ta'hanoun), et 'ledavid' sur les blocs 32-33. Ne mettre aucune condition sur les blocs 17-31 et 34. L'ordre de l'app (לדוד après Alénou au lieu d'avant) est un point distinct.

### Chema du coucher (Edot) : le vidui s'affiche tous les soirs
**Erreur de l'app** · gravité moyenne · Edot · tous lieux

- **Ce que fait l'app** : chema_coucher ne figure pas dans la liste TEXTES de tools/siddur_annotations.py. La consigne 0:17 et le vidui 0:18 s'affichent donc chaque soir. Pourtant jourDeLaPriere relie bien chaque soir au bon jour, et les conditions existent : le vendredi 20/11/2026 donne chabbat ; le 08/03/2027 donne roch_hodech ; le samedi 21/11/2026 donne motsae_chabbat ; le 12/09/2026 donne yom_tov. Il ne manque que le lendemain de Roch 'Hodech (11/03/2027).
- **Ce que dit la source** : *Kitsour YY, ק"ש שעל המטה בליל שבת §ב* : « אך אין לומר את הוידוי בלילי שבתות וימים טובים ». La consigne du siddour (0:17) ajoute : « ואין לאומרו בליל שבת ובשאר ימים שאין אומרים בהם תחנון. וכן אין לאומרו במוצ״ש עד חצות הלילה, וכן במוצאי יו״ט ור״ח ».
- **Correction proposée** : Ajouter chema_coucher à TEXTES. Replier 0:17-0:18 avec une condition dérivée « vidui_coucher » : tahanoun_chaharit, sauf motsae_chabbat_yt, sauf lendemain de Roch 'Hodech. Cette dernière condition est à créer dans CalendrierJuif.kt et calendrier-juif.js. Le repli du motsaé Chabbat ne s'arrête pas à 'hatsot : il faut l'écrire dans le libellé ou les tests. Ne pas citer le Ben Ich 'Haï Pekoudé §10 à l'appui : il ne donne que la place du vidui.

### Tikoun 'hatsot proposé les nuits de Chabbat et de fête
**Erreur de l'app** · gravité moyenne · tous les noussa'h · tous lieux

- **Ce que fait l'app** : momentDuSiddour (jour-affiche.js:76-97, JourAffiche.kt:116-137) renvoie 'tikoun_hatsot' de 'hatsot à l'aube sans consulter le calendrier. La carte s'affiche à 01 h 30 à Jérusalem :
  - le 21/11/2026 (Chabbat) ;
  - le 12/09/2026 (Roch Hachana) ;
  - le 21/09/2026 (Kippour) ;
  - le 22/04/2027 (Seder) ;
  - le 25/04/2027 ('Hol hamoed Pessa'h).

  Même chose à Paris.
- **Ce que dit la source** : Consigne du texte lui-même (0:0, identique dans les trois siddourim) : « אין אומרים תיקון חצות בליל שבת, ראש השנה, כפור, פסח, שבועות, סוכות, שמיני עצרת, וחול המועד של פסח ». *Kitsour YY, דיני תיקון חצות §נה* : « ויש זמנים שאין אומרים בהם לא תיקון רחל ולא תיקון לאה, ואלו הם: ליל שבת, ליל יום טוב ».
- **Correction proposée** : Dans momentDuSiddour (Kotlin et JS), passer par jourDeLaPriere('tikoun_hatsot', …). Ne pas proposer le texte si les conditions contiennent chabbat, yom_tov, kippour, roch_hachana ou hol_hamoed_pessah ; Chemini atseret et Sim'hat Torah sont couverts par yom_tov. Ajouter ces cas dans JourAfficheTest et calendrier.test.mjs.

### Bougies de Yom tov (Edot) : le שהחיינו se place entre la bénédiction et l'allumage
**Erreur de l'app** · gravité moyenne · Edot · tous lieux

- **Ce que fait l'app** : Dans nerot_chabbat (Edot), le bloc 0:2 dit « לפני הדלקת נר של יום טוב תברך ». Puis le bloc 0:3 donne la bénédiction, et les blocs 0:4-0:5 le שהחיינו, présenté comme l'usage, sans annotation. Le siddour ne dit jamais quand allumer. Une femme qui suit la page dit donc le שהחיינו avant d'allumer.
- **Ce que dit la source** : *Kitsour YY, סימן תקיד §ג* : « אין למנהגם זה כל יסוד בהלכה, ומן הראוי שיפסיקו לנהוג כן … רק שיברכו ברכה זו אחר שידליקו לפחות נר אחד, כדי שלא יהיה הפסק ». Voir aussi *תמד §מא*. L'usage reproduit est celui de Bagdad (*Ben Ich 'Haï, Noa'h §9* : « ופה עירנו נוהגים הנשים לברך ביו"ט "שהחיינו" בהדלקת הנר »). Le Yalkut Yosef le tolère (« אין למחות בחזקה »).
- **Correction proposée** : Ajouter un indice permanent sur 0:4-0:5 : « Yalkut Yosef (סימן תקיד §ג ; תמד §מא) : mieux vaut s'acquitter du שהחיינו au Kiddouch ; qui le dit le dit après avoir allumé au moins une bougie ». Replier par défaut, avec le libellé « usage (Ben Ich 'Haï) », reste une option. Ne pas attribuer au Ben Ich 'Haï la règle de l'interruption.

### Bougies de Kippour (Edot) : pas de formule de bénédiction
**Erreur de l'app** · gravité moyenne · Edot · tous lieux

- **Ce que fait l'app** : Le texte nerot_chabbat (Edot) donne seulement « להדליק נר של שבת » et « להדליק נר של (שבת ו)יום טוב ». Il n'y a aucune formule pour Kippour, alors que le Sfard et l'Ashkenaz l'ont (blocs 0:7-0:10). Le 2026-09-20 (erev_yom_kippour), une utilisatrice Edot n'a donc que la formule du Yom tov.
- **Ce que dit la source** : *Kitsour YY, סימן תרי §א* : « ובמקומותינו שמדליקין מברכים: אשר קדשנו במצותיו וצונו להדליק נר של יום הכפורים ». Au *§ד* : « אין לברך שהחיינו בשעת הדלקת הנרות בערב יום הכפורים ». Pour la variante d'un Chabbat (« של שבת ויום הכפורים »), voir *Ben Ich 'Haï, 1re année, Vayélekh §8*.
- **Correction proposée** : Ajouter à la main les blocs de Kippour, avec la mention de l'emprunt. En effet, siddur_occasions.py n'emprunte un texte que s'il manque entièrement. Ces blocs doivent être précédés de la consigne « avant l'allumage » (YY תרי §ב) et de la mention « sans שהחיינו (YY תרי §ד) ». Le Ben Ich 'Haï, qui fait dire שהחיינו, ne sert ici que pour la formule.

### Éclairs et tonnerre (Edot) : la consigne fait bénir sans Chem ni Malkhout
**Erreur de l'app** · gravité moyenne · Edot · tous lieux

- **Ce que fait l'app** : Le texte « barakim » de siddur_edot.json (consigne 0:0) dit « המנהג לברך בלי שם ומלכות », et le Chem est mis entre parenthèses aux blocs 0:1 et 0:3. Cette consigne vient du siddour source (Torat Emet 357, de tradition bagdadie) et s'affiche sans condition.
- **Ce que dit la source** : *Kitsour YY, סימן רכז-רכט §א* : « ומברכים בשם ומלכות, שכל הברכות המוזכרות בפרק הרואה במסכת ברכות, כתבו הראשונים שהם בשם ומלכות, וכל ברכה שאין בה שם ומלכות אינה ברכה ». Au *siman 4 §כח* : « [ומה שכתב בכף החיים להרהר הברכה בלבו, אין ראוי לעשות כן ולהפסיד הברכה] ».
- **Correction proposée** : Remplacer la consigne Edot par « מברכים בשם ומלכות, תוך כדי דיבור לראיית הברק או שמיעת הרעם (ילקו״י רכז-רכט, א) » et retirer les parenthèses. On peut ajouter la règle du §ג (« אין לברך יותר מפעם אחת ביום אלא אם כן נתפזרו העננים לגמרי ») et garder en note l'usage de Bagdad (*Ben Ich 'Haï, Ekev §16*).

### Bénédictions des plaisirs : המוציא, מזונות et הגפן manquent
**Erreur de l'app** · gravité moyenne · tous les noussa'h · tous lieux

- **Ce que fait l'app** : En Sfard et en Ashkenaz, le texte « nehenin » ne contient que העץ, האדמה, שהכל, שהחיינו et les parfums. « מיני מזונות » n'apparaît nulle part dans ces siddourim. En Edot, il manque המוציא. Aucun siddour n'a « המוציא לחם » ni la נטילת ידים avant le repas. La cause est que tools/siddur_occasions.py ne va chercher que certains nœuds de Sefaria.
- **Ce que dit la source** : *Choul'han Aroukh O.H. 208:2* : « מברך עליו בורא מיני מזונות ולבסוף על המחיה ». Voir aussi *167:2* : « יברך המוציא לחם מן הארץ », et *202:1* : « חוץ מהיין שמברך עליו בפה"ג ».
- **Correction proposée** :
  - Sfard : reprendre « Mealtime Blessings » et « Birchat HaMazon > Blessing on Foods » de Torat Emet 357.
  - Ashkenaz : prendre Daat « Berachot > Birkat Hanehenin > Eating > Barachot Rishonot », au lieu d'emprunter au Sfard.
  - Edot : trouver une autre source pour נטילת ידים et המוציא. On peut ajouter הנותן ריח טוב בפירות, mais ce point n'a pas été vérifié.

### Omer et Arvit en vol polaire : aucun rappel
**Erreur de l'app** · gravité moyenne · tous les noussa'h · diaspora

- **Ce que fait l'app** : Le jalon OMER (VolCalendrier.jalons) et le rappel d'Arvit (VolRappels.BORNES) ne se déclenchent que sur un tsét à 8,5°. Exemple : vol SFO→LHR du 24/05/2027 (Lag baOmer), qui monte jusqu'à 64,5°N. La chki'a a lieu à 03:01Z, mais il n'y a pas de tsét : la liste des jalons est vide, sans rappel du Omer ni d'Arvit. Le même défaut touche le jalon de sortie de Chabbat.
- **Ce que dit la source** : *Kitsour YY, סימן תפט §יח* : « ולכתחלה נכון לספור אחר צאת הכוכבים ». Le même se'if admet aussi le compte en bein hachmachot. *MB 489:14* : « דמן הדין היה אפשר להקל לספור משתחשך אף קודם צה"כ ». Au *§כד*, la perte de la bénédiction suppose d'avoir oublié la nuit et le jour : le risque est donc réel mais rattrapable.
- **Correction proposée** : Quand le tsét manque mais qu'il y a une chki'a, poser le jalon sur un repli et le dire comme un choix de calcul : en Edot, chki'a + 13,5 min zmaniyot, sinon la chki'a. Ne pas prendre tset_rt, qui est un zman plus strict. Ajouter des tests de vol polaire dans VolRappelsTest et vecteurs_vol.

### Cha'harit en vol : le rappel ignore la fin du Chema
**Erreur de l'app** · gravité moyenne · tous les noussa'h · tous lieux

- **Ce que fait l'app** : VolRappels.BORNES borne Cha'harit de « netz » à « szt_gra ». Les textes des rappels (vol_rappel_priere_texte, vol_rappel_fin_texte) ne nomment que la fin de la Tefila. Exemple : vol JFK→TLV du 16-17/11/2026. Le netz tombe à 08:46Z et la fin du Chema selon le Maguen Avraham à 09:37Z. L'alerte « plus que 30 min » tombe à 09:51Z, après cette fin, et 6 min seulement avant la fin selon le Gra. La frise de l'écran Vol affiche bien la fin du Chema, mais pas les notifications.
- **Ce que dit la source** : *Kitsour YY, סימן פט §ד* : « אך לענין ק״ש שהיא דאורייתא, לכתחלה יש להחמיר לקוראה קודם שיעבור ג' שעות מעמוד השחר ».
- **Correction proposée** : Ajouter une borne « Chema » aux rappels du vol : szks_mga en Edot (avec szks_gra en cas de besoin), szks_gra ailleurs, en mentionnant le MGA. Ajouter une alerte 30 min avant, et « Chema avant HH:MM » dans le texte. Il faut passer le noussa'h à VolRappels.rappels.

### Zmanim de la PWA décalés d'un jour à Sydney, Auckland et Wellington
**Erreur de l'app** · gravité moyenne · tous les noussa'h · hémisphère sud

- **Ce que fait l'app** : La fonction getRawOffset de kosher-zmanim 0.9.0 (web/src/vendor) inverse le signe du décalage horaire dans les fuseaux qui ont une heure d'été. À l'est de 150°E environ, getAntimeridianAdjustment vaut alors 1. Z.jour(Sydney, '2026-11-20') rend le netz du 21. Android (KosherJava 2.5.0) rend bien le 20. Conséquence, app.js:1385 : le vendredi soir après le tsét à Sydney, jourDeLaPriere garde le vendredi, et le Birkat hamazon perd רצה.
- **Ce que dit la source** : Pas de question de halakha ici : c'est un défaut de calcul. La référence est KosherJava 2.5.0, qui donne pour Sydney le 20/11/2026 un netz à 05:40:54.
- **Correction proposée** : Dans zmanim.js, remplacer getRawOffset par le vrai décalage standard du fuseau, ou neutraliser getAntimeridianAdjustment. Ajouter Sydney, Auckland et Wellington aux vecteurs de tools/vecteurs_kosherjava, qui n'ont aujourd'hui que Melbourne, située juste sous le seuil.

### Min'ha du vendredi (Edot) : le psaume 93 n'apparaît jamais en clair
**Erreur de l'app** · gravité moyenne · Edot · tous lieux

- **Ce que fait l'app** : La section 2 « וידוי » de Min'ha (23 blocs) est repliée en entier sous tahanoun_minha, pour la même raison que dans le constat Sfard (tools/siddur_annotations.py:152). Le vendredi 2026-11-20, le Kaddich titkabel (blocs 9-13), le psaume 93 (16-17) et le Kaddich יהא שלמא (20-22) sont donc repliés. Inversement, les jours avec Ta'hanoun, les psaumes 67 et 93 s'affichent tous les deux en clair.
- **Ce que dit la source** : Consigne du siddour Edot (minha s2 b16) : « בערב שבת אומרים מזמור ''יהוה מלך'' במקום ''למנצח'' ».
- **Correction proposée** : Mettre tahanoun_minha sur les blocs 0-8 seulement, « !jour_6 » sur 14-15, « jour_6 » sur 16-17 et « jeune » sur 18-19. Laisser 9-13 et 20-22 en clair.

### אל ארך אפים replié les lundis et jeudis sans Ta'hanoun
**Erreur de l'app** · gravité moyenne · Sfard, Ashkenaz · tous lieux

- **Ce que fait l'app** : Dans la lecture de la Torah (Ashkenaz chaharit s5 b0-1, Sfard s12 b0-1), אל ארך אפים porte la condition tahanoun_chaharit. Entre 2024-09 et 2030-12, il est replié à tort 67 fois en diaspora et 68 fois en Israël. Exemples : le 07/04/2025 (Nissan), le 13/02/2025 (Tou biChvat), le 12/05/2025 (Pessa'h chéni), le 21/04/2025 (Isrou 'hag). Ailleurs, l'app lie pourtant בית יעקב à 'lamnatseah'.
- **Ce que dit la source** : *MB 131:35* : « עוד כתבו דאל ארך אפים ולמנצח דינם שוה ». *Choul'han Aroukh haRav 429:12* : « בכל החדש, אף שאין אומרים תחנון, אומרים "למנצח יענך וגו'", ובשני וחמישי אומרים "אל ארך אפים" ». La consigne des siddourim de l'app ne lie le texte au Ta'hanoun que sous la forme d'un « יש נוהגים ».
- **Correction proposée** : Créer une condition dérivée el_erekh_apayim = lamnatseah ∧ (jour_2 ∨ jour_5) ∧ ¬moed, dans CalendrierJuif et calendrier-juif.js. Sans le ¬moed, il s'afficherait à tort pendant 'Hol hamoed (voir le constat suivant). Garder le « יש נוהגים » comme réglage facultatif.

### למנצח dit à 'Hol hamoed et à Hochaana Rabba (Sfard)
**Erreur de l'app** · gravité moyenne · Sfard · tous lieux

- **Ce que fait l'app** : calendrier-juif.js:136-138 et CalendrierJuif.kt:309-314 ne retirent pas lamnatseah à 'Hol hamoed. Le bloc למנצח (chaharit s13 b3) reste donc déplié le 09/10/2025, le 13/10/2025 (Hochaana Rabba) et le 06/04/2026.
- **Ce que dit la source** : Consigne du siddour Sfard de l'app (hallel, bloc 27) : « בראש חודש וביום טוב ובחול המועד אומר החזן קדיש שלם… אשרי ובא לציון ואין אומרים למנצח ». *Piskei haSiddour* (segments 4-5) : « מנהג ספרד שבכל יום שאין בו תחנון ונפילת אפים — אין אומרים "למנצח יענך" ». La consigne d'Achré (s13 b1, Dérekh ha'Haïm) ne nomme pas 'Hol hamoed : c'est ce qui explique le codage, mais le siddour se contredit.
- **Correction proposée** : Dans conditionsPour, pour le Sfard, retirer lamnatseah quand « moed » est présent. Pour l'Ashkenaz, la question reste ouverte : MB 131:35 ne nomme pas 'Hol hamoed.

### Jeûne d'Esther la veille de Pourim : Avinou malkénou proposé à Min'ha
**Erreur de l'app** · gravité moyenne · Sfard, Ashkenaz · tous lieux

- **Ce que fait l'app** : SiddurJour.avinouMalkenou et conditionsPour ajoutent avinou_malkenou_minha dès qu'il y a un jeûne, sans tenir compte de tahanoun_minha. Le bloc de Min'ha (sefard s3, ashkenaz s2) est donc mis en évidence le 13/03/2025, le 02/03/2026, le 22/03/2027, le 28/02/2029 et le 18/03/2030. Le 09/03/2028, le jeûne est avancé au jeudi, et l'app a raison de garder le bloc.
- **Ce que dit la source** : Louah Ezras Torah 5782, Adar II, p. 104, Min'ha du jeûne d'Esther : « (No אבינו מלכנו and no Tachanun) ». Selon hidabroot.org/article/46396 : « "אבינו מלכנו" נאמר רק בשחרית, אך לא במנחה (מלבד הזמן בו הצום הוקדם ליום חמישי…) ». Le *MB 131:33* le dit pour le Ta'hanoun : « ובכל אלו אין אומרים גם במנחה שלפניו ».
- **Correction proposée** : Ne pas ajouter avinou_malkenou_minha quand esther_pourim ∧ jeune ∧ tahanoun_minha est absent, en Kotlin comme en JS.

### Kaddich après le Hallel de Roch 'Hodech Tévèt et du Chabbat de 'Hanouka
**Erreur de l'app** · gravité moyenne · Edot, Sfard · tous lieux

- **Ce que fait l'app** : Le Kaddich titkabel du Hallel (Edot s0 b26-28, Sfard s0 b31-33) est replié sous « !hanouka » (siddur-jour.js:8, SiddurJour.kt:282). Les 20/12/2025, 21/12/2025 et 10/12/2026 (hanouka + roch_hodech), et tout Chabbat de 'Hanouka, l'app ne montre donc que le demi-Kaddich.
- **Ce que dit la source** : *Kitsour YY, סימן תכג §א* : « כל יום שיש בו מוסף אומרים קדיש תתקבל אחר ההלל, שהוא סיום תפלת שחרית ». *Kaf ha'Haïm 683:2* : « דביום שיש בו מוסף אומרים קדיש שלם אחר ההלל ».
- **Correction proposée** : Sur ces six blocs, remplacer la condition par kaddich_complet_hallel = !hanouka ∨ roch_hodech ∨ chabbat.

### Tefillin à 'Hol hamoed : la bénédiction reste affichée
**Erreur de l'app** · gravité moyenne · Edot partout ; tous les noussa'h en Israël · tous lieux

- **Ce que fait l'app** : Aucune règle et aucune condition « hol_hamoed » n'existe : on n'a que « moed », qui vaut aussi à Yom tov. La section des tefillin (Edot chaharit s2 b0-3, avec la bénédiction en b1 ; Ashkenaz chaharit s0 b17-27) reste en clair à 'Hol hamoed, par exemple le 09/10/2025 et le 05/04/2026. Le siddour Sfard n'a pas de section de mise des tefillin.
- **Ce que dit la source** : *Choul'han Aroukh O.H. 31:2* : « בחוה"מ ג"כ אסור להניח תפילין מהטעם הזה בעצמו שימי חוה"מ גם הם אות ». *Kitsour YY 31:6* : « המנהג פשוט שאין מניחין תפילין בחול המועד ». En Ashkenaz de diaspora, le Rema dit « ולברך עליה' », et le *MB 31:8* : « והאחרונים הסכימו לדעת הט"ז דיותר טוב להניחן בלי ברכה ».
- **Correction proposée** : Créer une condition « hol_hamoed » (moed sans yom_tov). Annoter « !hol_hamoed » sur Edot s2, et sur Ashkenaz s0 b17-27 en Israël seulement. En Ashkenaz de diaspora, ajouter la consigne « sans bénédiction (MB 31:8) ». En Sfard de diaspora, l'usage est partagé. L'abstention 'Habad n'est pas sourcée par le Choul'han Aroukh haRav, qui rapporte qu'on les met.

### Prélèvement de la 'hala : le seuil ashkénaze est celui du Rav Ovadia
**Différence entre rites** · gravité moyenne · Ashkenaz · tous lieux

- **Ce que fait l'app** : Le texte « hala » de l'Ashkenaz est emprunté au Sfard. Sa consigne [0:4] donne « 1560 גר׳ … (שו״ת חזו״ע עמ׳ תקיח). ולשיטת החזו״א השעור הוא 2250 גר׳ ». Le texte Edot (1566,5 g et 2497 g) est conforme au Yalkut Yosef et au Ben Ich 'Haï.
- **Ce que dit la source** : *MB 456:3* : « ישער אותה וכו' - ולא ע"י משקל ». Le Rav Naé compte 520 dirham × 3,2 g, soit environ 1,66 kg (*Kitsour YY 456 §א* : « ושיעור הדרהם כתב הגר"ח נאה, שהוא שלשה גרם וחומש »). OK Kosher donne 1,6 kg avec bénédiction et 1,2 kg sans.
- **Correction proposée** : Consigne ashkénaze propre : « בלי ברכה מ־1.2 ק״ג; בברכה מכ־1.666 ק״ג (שיטת הגר״ח נאה); ולשיטת החזו״א מכ־2.25 ק״ג — וינהג כמנהג רבותיו ». Retirer la référence au חזו״ע. En Sfard, la consigne fait foi ; on peut seulement suggérer « וינהג כרבו ».

### Loulav et soukka : rien n'est dit pour les femmes
**Différence entre rites** · gravité moyenne · surtout Edot (aussi Sfard, Ashkenaz) · tous lieux

- **Ce que fait l'app** : Le texte « loulav », emprunté au Sfard en Edot, donne la bénédiction et « בפעם הראשונה שמברך על הלולב מברך גם שהחיינו » sans aucune consigne pour les femmes. Le texte « soukka » (Edot) ne dit rien non plus pour « לישב בסוכה ». Il n'y a aucune annotation. L'app connaît pourtant le réglage Adresse.FEMME.
- **Ce que dit la source** : *Kitsour YY, דין נשים בנטילת לולב §א* : « לכן אם חפצות הן ליטול הלולב, יטלוהו בלא ברכה ». Pour la soukka, *YY סימן תרמ §א* : « אך אינן רשאות לברך לישב בסוכה ». Pour l'Ashkenaz, *Rema 589:6* : « הגה והמנהג שהנשים מברכות על מצות עשה שהזמן גרמא » (voir aussi *Rema 17:2*).
- **Correction proposée** : Dans « loulav » et « soukka » (Edot), ajouter : « נשים נוטלות בלא ברכה, ונכון שלא יברכו אף שהחיינו (ילקו״י) », éventuellement mis en avant pour l'adresse FEMME. En Ashkenaz et en Sfard, une note facultative « נשים מברכות (רמ״א) » suffit.

### Hagomel après un vol : aucun rappel
**Différence entre rites** · gravité moyenne · tous les noussa'h · tous lieux

- **Ce que fait l'app** : grep 'gomel' ne trouve rien dans le code Kotlin ou JS. VolRappels.kt:21 ne connaît que TEFILAT_HADEREKH, PRIERE, PRIERE_FIN et OMER : aucun rappel ne suit l'atterrissage.
- **Ce que dit la source** : *Kitsour YY, סימן ריט §כ* : « הטס במטוס שיעור שעה ושתים עשרה דקות, כשמגיע למחוז חפצו לשלום יברך ברכת הגומל, אף על פי ששדה התעופה קרוב למקום מגוריו ». Au *§כא*, cela vaut même au-dessus d'un lieu habité. *Choul'han Aroukh O.H. 219:7* : « באשכנז וצרפת אין מברכין כשהולכין מעיר לעיר שלא חייבו אלא בהולכי מדברות ». Selon Kol Torah, les Igrot Moché O.H. 2:50 (souvent cités 2:59, original non lu) exigent Hagomel après un vol.
- **Correction proposée** : Ajouter un rappel « Hagomel dans les trois jours, devant dix (de préférence à la lecture de la Torah) », plutôt qu'une alarme à l'atterrissage. Il serait actif par défaut en Edot pour 72 min de vol ou plus (aller et retour du même jour cumulés). En Ashkenaz et en Sfard, ce serait une mention « selon votre usage », désactivable.

### המפיל (Edot) : sans Chem avant 'hatsot, contre le Yalkut Yosef
**Différence entre poskim** · gravité moyenne · Edot · tous lieux

- **Ce que fait l'app** : Dans chema_coucher (Edot), la consigne 0:4 dit « בברכה זו לא יאמר בשם ומלכות אלא יהרהר בלבו », et le Chem est entre parenthèses au bloc 0:5. Il n'y a aucune annotation. momentDuSiddour propose ce texte à 22 h 45 à Paris comme à Jérusalem, par exemple le 17/11/2026, donc avant 'hatsot.
- **Ce que dit la source** : *Kitsour YY, סימן רלט §א* : « צריך לאומרה בשם ומלכות, אם הולך לישון קודם חצות לילה ». Au *§ו* : « וגם הנשים חייבות בקריאת שמע שעל המטה עם ברכת המפיל בשם ומלכות. אם ישנות קודם חצות ». La consigne du siddour suit le *Ben Ich 'Haï, 1re année, Pekoudé §12* (et non §11) : « אך יש נוהגים שאין מברכים אותה בשם ומלכות וכן מנהגי ומנהג אדוני אבי ז"ל », qui conclut « על כן נראה להורות שכל אחד יעשה כמנהגו בזה ».
- **Correction proposée** : Ne pas modifier le texte. Ajouter un indice sur 0:4-0:5 : « Yalkut Yosef (סי' רלט §א) : avant 'hatsot, avec Chem et Malkhout ; après 'hatsot, sans (comme la consigne). La consigne du siddour suit l'usage du Ben Ich 'Haï, Pekoudé §12 ». On peut le mettre en avant avec une condition « avant_hatsot » calculée sur le chatsot_layla du lieu, et ajouter un cas dans SimulationSiddurTest.

### Acher yatsar (Edot) : délai d'une demi-heure au lieu de 72 minutes
**Différence entre poskim** · gravité moyenne · Edot · tous lieux

- **Ce que fait l'app** : La consigne de siddur_edot.json dit « אם הטיל מים או עשה צרכיו יברך תוך חצי שעה (בא״ח ויצא הי״ב) ». Elle figure à deux endroits, acher_yatsar [0:0] et birkot_hachahar [1:2], et elle est toujours affichée.
- **Ce que dit la source** : *Kitsour YY, סימן ו §ד* : « אם נזכר תוך שיעור פרסה [דהיינו שבעים ושתים דקות], יברך אשר יצר, ואם לאו לא יברך » (repris aux §יב et §יד). *Ben Ich 'Haï, Vayetsé §12* : « אם עבר יותר מחצי שעה לא יברך אשר יצר בשם ומלכות, אבל תוך חצי שעה יברך ».
- **Correction proposée** : Aux deux endroits, écrire : « אם שכח לברך, מברך עד שיעור פרסה (72 דקות) – ילקו״י סי׳ ו ס״ד; ולבא״ח (ויצא הי״ב) רק תוך חצי שעה ».

### Omer et ligne de date : un seul chiffre, sans avertissement
**Différence entre poskim** · gravité moyenne · tous les noussa'h · diaspora

- **Ce que fait l'app** : Vers l'est, sur un vol SYD→LAX du 06/05/2027, le jalon OMER annonce le 14 après le passage de la ligne, alors qu'il a déjà été compté à Sydney. Le texte de la notification est « ce soir, on compte le jour %1$s », sans mention « sans bénédiction ». Vers l'ouest, sur un vol LAX→SYD du 04 au 06/05/2027, la nuit du 14 est sautée sans aucun jalon. L'app suit le compte du lieu sous l'avion.
- **Ce que dit la source** : Selon la synthèse de Kikar haChabbat (06/05/2025), Rav Chlomo Zalman Auerbach dit : « ואם נסע ממזרח למערב ונחסר לו יום אחד – הרי שדילג על יום מספירת העומר, ולכן ימשיך לספור מכאן ואילך ללא ברכה ». La même synthèse cite le Michné Halakhot X, 121, et le Rabbi de Loubavitch (compte personnel), et conclut : « ראוי להימנע ככל האפשר מלעבור את קו התאריך באמצע ימי הספירה ». Pour l'Edot, par analogie : *Kitsour YY 489 §לא* : « יספור מספק את ב' הספירות בזה אחר זה בלי ברכה ».
- **Correction proposée** : Quand une ligne de date tombe pendant le Omer, afficher les deux comptes, le compte personnel N et le compte du lieu M, avec les avis (sans bénédiction selon Rav Auerbach, compte personnel selon le Rabbi) et l'avertissement ci-dessus. Ajouter un rappel même sur les vols sans tsét. Cela reste compatible avec ZMANIM.md, qui ne tranche pas.

### Ligne de date halakhique : l'app suit la ligne internationale, et le vol se règle sur le méridien 180°
**Différence entre poskim** · gravité moyenne · tous les noussa'h · diaspora (Pacifique)

- **Ce que fait l'app** :
  - Au sol, elle suit le jour civil : Chabbat est le samedi civil à Tokyo, Auckland et Honolulu. C'est la position de Rav Frank.
  - En vol, Vol.fuseauNautique et Vol.lignesDate se règlent sur le méridien 180°. Près de la vraie ligne, les deux méthodes se contredisent. Sur un vol AKL→TBU, aucun jalon d'entrée de Chabbat n'est posé le vendredi 20/11/2026. Le même vol le samedi 21 pose une entrée de Chabbat à 06:25:52Z, au moment où l'app au sol, à Tonga, fait sortir Chabbat.
- **Ce que dit la source** : *Kitsour YY 30 §ז* suppose une ligne de date sans la définir : « הנוסע ביום א' מארצות הברית לארץ ישראל דרך המערב, והרי הוא עובר את קו התאריך ». D'après R. Jachter (2018), le 'Hazon Ich, Rav Toukatchinsky et Rav Frank divergent. Rav Ovadia n'a pas traité la question. Rav Chlomo Amar tient que l'approche de Rav Frank a été acceptée, et Rav Khoshkerman conseille la rigueur au Japon, en Nouvelle-Zélande et à Hawaï.
- **Correction proposée** : Il y a deux choses à corriger.
  - Le méridien 180° en vol est une erreur de calcul. Il faut calculer le jour civil avec le fuseau réel du point, en accord avec le sol, et corriger « Jour civil du point sous l'avion », qui est faux près de Tonga.
  - Le choix de la ligne est une divergence de poskim. Il faut une mention sur les écrans des zmanim et du vol pour le Japon, la Nouvelle-Zélande, l'Australie orientale, Hawaï, Tonga et Samoa.

### למנצח les jours sans Ta'hanoun (Sfard) : Dérekh ha'Haïm contre l'Admour
**Différence entre poskim** · gravité moyenne · Sfard · tous lieux

- **Ce que fait l'app** : lamnatseah reste vrai les jours sans Ta'hanoun. Le psaume est déplié le 01/04/2025 (Nissan), le 21/04/2025 (Isrou 'hag), le 12/05/2025, le 16/05/2025 (Lag baOmer), le 05/06/2025, le 22/09/2025, le 05/10/2025, le 02/02/2026 et le 29/07/2026 (Tou beAv). En même temps, אל ארך אפים est replié ces jours-là. Ce mélange ne suit ni le Dérekh ha'Haïm ni l'Admour.
- **Ce que dit la source** : Consigne de l'app (s13 b1, Dérekh ha'Haïm) : « אלו ימים שאין אומרים בהם למנצח ואל ארך אפים. ר״ח חנוכה ופורים ערב פסח וערב יו״כ ותשעה באב… דכללא הוא דאא״א ולמנצח דינם שוה ». *Piskei haSiddour §5-6* : « מנהג ספרד שבכל יום שאין בו תחנון ונפילת אפים — אין אומרים "למנצח יענך" ולא "תפלה לדוד". » ; « דהינו אפלו כל חדש ניסן, ופסח שני שהוא י"ד באיר, ול"ג בעמר… וט"ו באב, וערב ראש השנה, ומערב יום כפורים עד סוף תשרי, וט"ו בשבט ».
- **Correction proposée** : Choisir un usage et s'y tenir. Selon le Dérekh ha'Haïm, למנצח et אל ארך אפים suivent la même liste. Selon l'Admour, en option, pas de למנצח sans Ta'hanoun du matin, mais אל ארך אפים gardé le lundi et le jeudi (Piskei haSiddour §3). Le dire dans ZMANIM.md.

### Nuit du Seder : tout le Chema du coucher s'affiche
**Erreur de l'app** · gravité basse · Ashkenaz (Sfard : usage partagé) · tous lieux

- **Ce que fait l'app** : Le 21/04/2027 à 23 h (15 Nissan), momentDuSiddour propose chema_coucher. Sans annotation, l'Ashkenaz affiche tous les blocs 9 à 36 (de ויהי נועם à אדון עולם), et le Sfard les blocs 8 à 26. En diaspora, c'est la même chose le 22/04/2027 (16 Nissan).
- **Ce que dit la source** : *Rema O.H. 481:2* : « ונוהגים שלא לקרות על מטתו רק פרשת שמע ולא שאר דברים שקורין בשאר הלילות כדי להגן כי ליל שמורים הוא מן המזיקים ». Pour la seconde nuit : « וכל דין ליל ראשון יש ג"כ בליל שני ». *MB 481:4* : « וצריך לברך ברכת המפיל ».
- **Correction proposée** : Créer une condition « leil_haseder » (15 Nissan, et 16 Nissan en diaspora). En Ashkenaz, replier les blocs 9 à 36 avec « !leil_haseder ». En Sfard (Torat Emet, 'hassidique général), appliquer la même règle et signaler que l'usage 'Habad ne la retient que le premier soir (Tehillat Hachem, référence non vérifiée). L'Edot est conforme (*YY תפ §י*).

### המפיל après l'aube : aucune réserve
**Erreur de l'app** · gravité basse · Sfard, Ashkenaz · tous lieux

- **Ce que fait l'app** : Le bloc 0:1 de chema_coucher donne המפיל avec le Chem, sans aucune consigne. momentDuSiddour ne propose ce texte qu'avant 'hatsot, mais le texte ouvert depuis la liste après l'aube reste en clair.
- **Ce que dit la source** : *Biour Halakha 239, ד"ה סמוך למטתו* : « אבל אחר שעלה עה"ש לא מסתפק לי כלל … מ"מ לענין ברכת המפיל נראה דעבר זמן ». Il ajoute : « ועכ"פ נ"ל דאם מסתפק שמא לא יוכל אח"כ לישן בודאי אין כדאי לכתחלה לברך ».
- **Correction proposée** : Ajouter un indice fixe sous המפיל : « après l'aube, sans Chem ni Malkhout ; ne pas bénir si l'on doute de s'endormir (Biour Halakha 239) ». Le système d'annotations ne gère pas l'heure ; une condition horaire demanderait un mécanisme nouveau.

### Tikoun 'hatsot : יענך les jours sans Ta'hanoun et Tikoun Léa le 9 Av
**Erreur de l'app** · gravité basse · tous les noussa'h · tous lieux

- **Ce que fait l'app** : tikoun_hatsot n'est pas dans TEXTES (tools/siddur_annotations.py). Les blocs 2:3 (יענך) et 2:9-2:10 (עד אנה) s'affichent donc le 09/03/2027 (Roch 'Hodech). La section 2 (Tikoun Léa) s'affiche aussi la nuit du 23/07/2026 (9 Av). Le texte, emprunté à l'Edot, est le même dans les trois noussa'h.
- **Ce que dit la source** : Consigne du siddour (2:2) : « בימים שאין אומרים תחנון לא יאמר מזמור זה ». *Kitsour YY, דיני תיקון חצות §נו* : « בליל תשעה באב אומרים בו רק תיקון רחל, ואין אומרים בו תיקון לאה ». Le §נט, qui parle de la maison d'un endeuillé, ne sert que par analogie.
- **Correction proposée** : Ajouter tikoun_hatsot à TEXTES. Annoter les blocs 2:3 et 2:9-2:10 avec « tahanoun_chaharit » (jour de la nuit, via jourDeLaPriere), et la section 2 avec « !ticha_beav », pour les trois noussa'h.

### Vidui avant le Tikoun 'hatsot : rien n'empêche de le dire deux fois de suite
**Erreur de l'app** · gravité basse · Edot (Sfard, Ashkenaz : non vérifiable) · tous lieux

- **Ce que fait l'app** : Le bloc 0:1 de tikoun_hatsot (« אָנָּא … אָשַׁמְנוּ ») est toujours en clair. L'app propose chema_coucher jusqu'à 'hatsot, puis tikoun_hatsot. Or le Chema du coucher en Edot contient lui-même un vidui. Le Chema du coucher Sfard et Ashkenaz n'en a pas.
- **Ce que dit la source** : *Kitsour YY, דיני תיקון חצות §נח* : « בכמה מקומות נוהגים לומר וידוי קודם אמירת תיקון חצות, וכן מנהגינו … וכן אם אומר את התיקון חצות סמוך לוידוי שאמר בקריאת שמע שעל המטה, לא יאמר עוד הפעם וידוי ».
- **Correction proposée** : Garder le bloc 0:1 en clair et ajouter un indice fixe, sans condition du jour : « ne pas dire ce vidui si on vient de le dire au Chema du coucher, si le Tikoun est dit près de Min'ha, ou en Eloul et pendant les dix jours de pénitence près des Seli'hot (Kitsour YY §נח) ».

### « רבונו של עולם » le Chabbat (Edot) : la consigne renvoie à des petits caractères absents
**Erreur de l'app** · gravité basse · Edot · tous lieux

- **Ce que fait l'app** : La consigne 0:2 de chema_coucher dit « אבל בשבתות וימים טובים לא יאמר את מה שמופיע באותיות הקטנות ». Or le bloc 0:3 n'a aucune balise <small>. L'édition source (Sefaria, Shaliehsaboo) n'en a pas non plus. Le passage à omettre le Chabbat est donc introuvable.
- **Ce que dit la source** : *Kitsour YY, ק"ש שעל המטה בליל שבת §ב* : « מותר לומר את הנוסח ״הריני מוחל וסולח לכל מי שהכעיס וכו״' גם בלילי שבתות וימים טובים ». Le *Kaf ha'Haïm 239 §2* omet davantage : « ובשבת ויו"ט לא יאמר רבש"ע ויה"ר רק יתחיל השכיבינו ».
- **Correction proposée** : Rien ne peut être rétabli depuis la source, puisqu'elle n'a pas de balisage. Il faut découper le bloc 0:3 à la main dans siddur_annotations.py : de « רבונו … » à « … בסבתי », toujours affiché ; de « יהי רצון … » à « … וחולאים רעים », replié avec « !chabbat » et « !yom_tov ». Ce découpage est plausible mais n'a pas été vérifié sur une édition imprimée.

### Hilloulot du 30 Adar I mal placées
**Erreur de l'app** · gravité basse · tous les noussa'h (Edot et Sfard les années embolismiques ; Ashkenaz les années simples) · tous lieux

- **Ce que fait l'app** : Hors Ashkenaz, clesHilloula (jour-affiche.js:168) et Hilloulot.cles (Hilloulot.kt:62-71) rangent « adar-30 » en Adar II. Les années embolismiques, les deux entrées « adar-30 » s'affichent donc le 29 Adar II (2027-04-07, 2030-04-03) au lieu du 30 Adar I (2027-03-09, 2030-03-05). Les années simples, dans tous les rites, la règle « un 30 absent devient le 29 » les place au 29 Adar (2025-03-29, 2026-03-18, 2028-03-27, 2029-03-16).
- **Ce que dit la source** : *Kitsour YY, סימן מ §כב* : « מי שאביו או אמו נפטרו בל' אדר א', יש לעשות את האזכרה (לימוד, וברכות) בשנה מעוברת ביום ל' אדר א' ». Pour l'année simple, *MB 568:42* : « אם מת אביו ביום ראשון דר"ח אדר שני יתענה לשנה הבאה שהיתה שנה פשוטה ביום א' דר"ח אדר ולא בכ"ט בו », donc au 30 Chevat.
- **Correction proposée** : Une année embolismique, faire valoir « adar-30 » pour le 30 Adar I (ou renommer la clé « adar1-30 »). Une année simple, poser ces clés au 30 Chevat, au moins en Ashkenaz. Pour l'Edot et le Sfard, le cas de l'année simple n'est pas réglé par une source lue. Signaler aussi dans la note que la date « ל אדר תקמ"ז » (5547, année simple) est impossible.

### Bougies de Chabbat et de Yom tov (Sfard, Ashkenaz) : aucune consigne d'ordre
**Différence entre rites** · gravité basse · Sfard, Ashkenaz · tous lieux

- **Ce que fait l'app** : Le texte nerot_chabbat, identique en Sfard et en Ashkenaz (l'Ashkenaz est emprunté au Sfard, avec l'étiquette affichée), ne donne que les formules : « לשבת: », « ליום טוב: », etc. Il ne dit rien de l'ordre entre la bénédiction et l'allumage, ni de se couvrir les yeux.
- **Ce que dit la source** : *Rema 263:5* : « ומשימין היד לפני הנר אחר ההדלקה ומברכין ואח"כ מסלקין היד וזה מקרי עובר לעשייה וכן המנהג ». *MB 263:27* : « וא"כ ביו"ט דלא שייך זה לכ"ע תברך ואח"כ תדליק ודעת המ"א דלא פלוג ». *Choul'han Aroukh haRav 263:8* : « ואף ביום טוב מדליקין תחלה, כדי שלא לחלק בברכה אחת ».
- **Correction proposée** : Ajouter un indice selon le noussa'h. En Ashkenaz : Rema, avec la divergence au Yom tov selon le MB. En Sfard : Choul'han Aroukh haRav, en précisant que l'usage est partagé. Le même indice vaut pour les formules de Kippour.

### HaGomel : rien n'est dit pour les femmes
**Différence entre rites** · gravité basse · Edot, Ashkenaz (Sfard non vérifié) · tous lieux

- **Ce que fait l'app** : Aucune consigne de « hagomel », dans aucun des trois noussa'h, ne parle des femmes ni de l'accouchement.
- **Ce que dit la source** : *Kitsour YY, סימן ריט §ז* : « נשים חייבות לברך ברכת ״הגומל״ לאחר שנתרפאו ממחלה, או לאחר לידת בן או בת ». Au §ח, il refuse « neuf femmes et un homme » (« ואין לסמוך על דבריו נגד דעת מרן »). *MB 219:3* : « וגם נשים מנהג העולם שאין מברכין ברכה זו ... ויש שכתבו דמ"מ נכון הוא שתברך בפני עשרה עכ"פ בפני נשים ואיש אחד ».
- **Correction proposée** : Ajouter une courte consigne par noussa'h, ou un renvoi vers YY ריט §ז-י et MB ריט ס״ק ג. En Edot : obligation, devant dix hommes. En Ashkenaz : selon le MB 219:3.

### Éclairs et tonnerre : laquelle dire quand ils se suivent
**Différence entre rites** · gravité basse · tous les noussa'h · tous lieux

- **Ce que fait l'app** : Les trois noussa'h donnent les deux bénédictions l'une après l'autre (texte 19, sans annotation). Rien n'indique laquelle préférer, le délai « תוך כדי דיבור », ni la règle d'une seule fois par jour.
- **Ce que dit la source** : *Kitsour YY, סימן רכז-רכט §ב* : « אם ראה ברק עדיף להמתין עד שישמע את הרעמים, ואז יברך שכוחו וגבורתו מלא עולם. ויפטור את הברק ». Le même se'if admet aussi les deux bénédictions (« יש לו על מה שיסמוך »). *MB 227:5* : « ואם לא היו תכופים זה אחר זה מברך תחלה על הברק ... עושה מע"ב ואח"כ על הרעם שכחו וגבורתו מ"ע ».
- **Correction proposée** : Ajouter une ligne par noussa'h, en Edot « עדיף להמתין לרעם ולברך שכוחו בלבד ». Ajouter une ligne commune sur « תוך כדי דיבור » et « פעם אחת ביום אלא אם נתפזרו העבים ». Le Chem en Edot fait l'objet du constat « Éclairs et tonnerre (Edot) » plus haut.

### Arc-en-ciel (Sfard, Ashkenaz) : ni interdiction de regarder, ni usage de ne pas le signaler
**Différence entre rites** · gravité basse · Sfard, Ashkenaz · tous lieux

- **Ce que fait l'app** : Le texte « keshet » ne donne en Sfard et en Ashkenaz que « הרואה קשת צריך לברך ברכה זו: ». La consigne Edot, elle, est conforme.
- **Ce que dit la source** : *Choul'han Aroukh 229:1* : « ואסור להסתכל בו ביותר ». Cette règle vaut pour tous les rites ; son absence est une simple omission. *MB 229:1* : « ואין כדאי להגיד לחבירו שיש קשת מטעם מוציא דבה ». À l'inverse, *Kitsour YY 229 §א* : « אבל מותר לומר לחבירו שיש קשת ».
- **Correction proposée** : Ajouter « ואסור להסתכל בה ביותר » en Sfard et en Ashkenaz, et, en Ashkenaz seulement, « ואין כדאי להגיד לחבירו שיש קשת (מ״ב רכט ס״ק א) ». La position du Choul'han Aroukh haRav n'a pas été lue.

### שהחיינו des femmes aux bougies de Yom tov (Ashkenaz)
**Différence entre poskim** · gravité basse · Ashkenaz (Sfard conforme) · tous lieux

- **Ce que fait l'app** : Les blocs 0:11-0:12 de nerot_chabbat (« ליו״ט (חוץ מז׳ וח׳ של פסח): … שהחיינו ») s'affichent sans réserve. En Sfard, c'est la consigne même du siddour, donc conforme.
- **Ce que dit la source** : *MB 263:23* : « ואין צריך לברך זמן על ההדלקה מיהו במקום שנהגו אין למחות בידן ».
- **Correction proposée** : Facultatif : un indice qui cite seulement le MB 263:23 (« pas obligatoire ; on ne proteste pas là où c'est l'usage »). Retirer la mention « ne le répond pas au Kiddouch », qui ne figure pas dans le MB et n'a pas été vérifiée.

### Chema du coucher (Sfard) : l'usage 'Habad n'est pas signalé
**Différence entre poskim** · gravité basse · Sfard · tous lieux

- **Ce que fait l'app** : Le chema_coucher Sfard (Torat Emet, 27 blocs sans aucune consigne) n'a ni vidui ni אנא בכח. המפיל y est au début (0:1), et « רבונו של עולם » (0:0) n'a aucune réserve pour le Chabbat. Placer המפיל avant le Chema est admis par le *MB 239:2* : « ונראה דלמעשה יתנהג האדם כפי טבעו ».
- **Ce que dit la source** : Le Tehillat Hachem ('Habad, PDF de chabad.org, texte anglais) dit : « On days when Tachanun is not said, continue with We implore » ; « The following paragraph is omitted on Shabbat and festivals. » ; « The following blessing should be recited right before one sleeps. ». Il omet aussi, le Chabbat, la fin de השכיבנו et le psaume 51. Le Choul'han Aroukh haRav 239 n'a pas pu être vérifié.
- **Correction proposée** : Ajouter sur 0:0 un indice « 'Habad : omis le Chabbat et le Yom tov », et une note signalant que l'usage 'Habad ajoute le vidui (les jours avec Ta'hanoun) et אנא בכח. On peut emprunter ces passages à l'Edot, avec une condition tahanoun_chaharit, en marquant l'emprunt. La règle du Seder relève du constat « Nuit du Seder ».

### Tikoun 'hatsot : la consigne exclut les femmes
**Différence entre poskim** · gravité basse · Edot · tous lieux

- **Ce que fait l'app** : La consigne 0:0 de tikoun_hatsot s'affiche telle quelle : « אין הנשים אומרים תיקון חצות ». Elle est identique en Sfard et en Ashkenaz, qui empruntent ce texte.
- **Ce que dit la source** : *Kitsour YY, דיני תיקון חצות §נא* : « וכל אשה יראת ה' הרוצה לומר תיקון חצות, תבוא עליה ברכה, ואין למונעה מכך. וכן עיקר ». Il reconnaît aussi que la plupart des femmes ne le disent pas aujourd'hui.
- **Correction proposée** : Facultatif : un indice citant le YY §נא, en Edot seulement. L'attribution de la consigne au Ben Ich 'Haï ou au Kaf ha'Haïm n'a pas été vérifiée.

### Birkat haIlanot le Chabbat et le Yom tov
**Différence entre poskim** · gravité basse · Edot (Sfard non vérifiable) · tous lieux

- **Ce que fait l'app** : La carte (Siddur.kt:170, app.js:2644) ne teste que le mois. Elle s'affiche pendant tout Nissan, Chabbatot et Yamim tovim compris (2026-03-21, 2026-04-02, 2027-04-10, 2027-05-01), sans aucune précision.
- **Ce que dit la source** : *Kitsour YY, סימן רכו §יג* : « מותר לברך ברכת האילנות בשבת ויום טוב ... אלא שלכתחילה מהיות טוב יש לברך ברכת האילנות בימות החול », sauf à la fin de Nissan. *Kaf ha'Haïm 226:4* : « בשבת ויו"ט אין לברך ברכת האילנות שמא יטלטל האילנות ... וכן עמא דבר ». L'app suit le YY.
- **Correction proposée** : Ajouter une note facultative le Chabbat et le Yom tov, sauf à la fin de Nissan : « לכתחילה עדיף בימות החול (ילקו״י רכו יג) ; יש נמנעים בשבת (כה״ח רכו ד) ». Ne pas masquer la carte en Sfard tant qu'aucune source 'hassidique n'a été vérifiée.

### Birkat haIlanot : pas de rappel en Iyar
**Différence entre poskim** · gravité basse · Edot, Ashkenaz (en Ashkenaz, plutôt une omission) · tous lieux

- **Ce que fait l'app** : Au nord, la carte s'affiche du 1er au 30 Nissan (2026-03-19 → 2026-04-17) et disparaît dès le 1er Iyar (2026-04-18, 2027-05-08). Le texte reste accessible toute l'année. Aucune mémoire « déjà dite » n'existe.
- **Ce que dit la source** : *Kitsour YY, סימן רכו §י* : « אם לא נזדמן לו לברך ברכת האילנות עד שיצא ניסן, רשאי לברך ברכת האילנות בחודש אייר, ולא יאבד ברכה יקרה זו מידו », mais seulement a posteriori. *MB 226:5* : « אבל קודם שגדלו הפירות יוכל לברך ואפילו לא בירך בשעת ראיה ראשונה ». Même le *Kaf ha'Haïm 226:1* permet de bénir après Nissan sans שם ומלכות.
- **Correction proposée** : En Edot et en Ashkenaz, prolonger la carte en Iyar avec « אם לא בירך בניסן ועדיין האילנות בפריחתם ולא גדלו הפירות » (a posteriori en Edot). En Sfard, au plus une mention « בלא שם ומלכות ». En option, un « déjà dite cette année ».

### Soukka (Edot) : l'ordre לישב בסוכה / המוציא
**Différence entre poskim** · gravité basse · Edot · tous lieux

- **Ce que fait l'app** : Le texte « soukka », emprunté au Sfard, a pour consigne [0:1] « ונוהגים שמברכין תחלה המוציא ואחר כך לישב בסוכה קודם שטועם ». C'est l'usage rapporté par le Choul'han Aroukh 643:3 lui-même, pas seulement par le Rema.
- **Ce que dit la source** : *Kitsour YY, דיני ישיבה בסוכה בשאר ימות החג §כז* : « ומכל מקום יותר טוב לברך לישב בסוכה קודם ברכת המוציא לפני שישב על יד השלחן ... ובכל מקום יעשו כמנהגם ».
- **Correction proposée** : Ajouter au texte Edot une note : « לדעת הילקוט יוסף עדיף לברך לישב בסוכה מעומד קודם המוציא (ובימים שיש קידוש – בקידוש); והמברכים אחר המוציא יש להם על מה שיסמוכו ».

### La mer (Sfard, Ashkenaz) : quelle mer, et à quel intervalle
**Différence entre poskim** · gravité basse · Sfard, Ashkenaz · tous lieux

- **Ce que fait l'app** : Le texte « yam » donne « הרואה את הים הגדול מברך: » et « עֹשֶׂה אֶת הַיָּם הַגָּדוֹל », sans dire de quelle mer il s'agit ni à quel intervalle on bénit.
- **Ce que dit la source** : *MB 228:2* : « אבל הרבה אחרונים פליגי על המחבר וס"ל דדוקא על ים אוקינוס ... ודע דכל הברכות האלו אינן אלא כשרואה אותן משלשים יום לשלשים יום ». L'intervalle de trente jours fait l'unanimité (Kitsour Choul'han Aroukh 60:12) : son absence est une simple omission.
- **Correction proposée** : Consigne : « על ים אוקינוס; ויש אומרים אף על הים התיכון (שו״ע רכח א). לדעת הרבה אחרונים על הים התיכון מברך עושה מעשה בראשית (מ״ב רכח ב). ואינו מברך אלא משלשים יום לשלשים יום ». On peut ajouter la variante « שעשה » (MB 228:3). Pour l'Edot, voir le constat « Birkat haRoé sur la mer (Edot) » plus haut.

### Bénédiction finale (Edot) : 4 minutes au lieu de 7,5
**Différence entre poskim** · gravité basse · Edot · tous lieux

- **Ce que fait l'app** : siddur_edot.json, « nehenin », consigne [0:10] : « אם אכל כזית בכדי אכילת פרס (4 דקות, וי״א 8 דקות) ».
- **Ce que dit la source** : *Kitsour YY, סימן רז §א-ב* : « בכדי אכילת פרס, [שהוא כ-7.5 דקות] ... וטוב להחמיר בדברים שהם מן התורה לאכול כזית בארבע דקות ».
- **Correction proposée** : Écrire « (כ־7.5 דקות — ילקו״י ; ובדברים שמן התורה טוב להחמיר 4 דקות) ».

### Birkat haIlanot (Edot) : ordre des psaumes et conditions absentes
**Différence entre poskim** · gravité basse · Edot · tous lieux

- **Ce que fait l'app** : Le texte, tiré tel quel du siddour Edot HaMizra'h de Torat Emet, place les psaumes 29, 126 (« בשוב ») et 148 avant la bénédiction. Il n'a aucune consigne sur les conditions : arbres fruitiers en fleur, deux arbres, une fois l'an. Les siddourim Sfard et Ashkenaz, eux, les ont.
- **Ce que dit la source** : *Kitsour YY, סימן רכו §ד* : « ואחר הברכה יאמרו ״מזמור בשוב ה' את שיבת ציון״, ו״מזמור הללויה הללו את ה' מן השמים״ וכו', ויסיימו באמירת קדיש יהא שלמא ». Le *Kaf ha'Haïm 226:8* suit un troisième ordre.
- **Correction proposée** : Ajouter en tête une consigne : « אין מברכים אלא על אילני מאכל כשיש בהם פרחים, די בשני אילנות, פעם אחת בשנה (ילקו"י רכו א, ה, ו) ». Ajouter une note sur l'ordre selon le YY §ד, sans réordonner le texte imprimé.

### 'Hanouka : l'ordre d'allumage n'est pas indiqué
**Différence entre poskim** · gravité basse · Edot, Ashkenaz · tous lieux

- **Ce que fait l'app** : Le texte 29 (nerot 'Hanouka) en Sfard dit « אחרי שהדליק הנר הראשון משמאל », ce qui est conforme au Choul'han Aroukh 676:5. L'Edot (« אחר שידליק נר אחד יאמר ») et l'Ashkenaz ne disent rien de l'ordre.
- **Ce que dit la source** : *Kitsour YY, סימן תרעו §יט* : « כשמדליק הנר בלילה הראשון, ידליק את הקיצוני מימין ... ובלילה השני ידליק הנר (הנוסף) החדש תחלה ». Le §כ prévoit l'inverse s'il n'y a pas de mezouza à droite. *MB 676:9* rapporte deux avis et conclut : « ודעביד כמר עביד ודעביד כמר עביד ».
- **Correction proposée** : Facultatif : en Edot, une consigne selon le YY §יט-כ ; en Ashkenaz, une consigne qui signale les deux usages admis par le MB. Ce n'est pas une erreur.

### Boussole : grand cercle par défaut pour tous les rites
**Différence entre poskim** · gravité basse · Edot, Ashkenaz · diaspora

- **Ce que fait l'app** : DirectionJerusalem et boussole.js prennent le grand cercle par défaut (Store.kt:594, store.js:282), quel que soit le noussa'h. À Los Angeles, cela donne 23,8°, contre 91,0° en loxodromie. L'écran explique les deux méthodes (boussole_note) et affiche toujours l'autre direction.
- **Ce que dit la source** : *Choul'han Aroukh haRav 94:2* : « וְחֶשְׁבּוֹן זֶה קַל לְהַיּוֹדְעִים דַּרְכֵי הַחֶשְׁבּוֹן בִּמְשֻׁלָּשׁ כַּדּוּרִי ». *Aroukh haChoul'han 94:6* : « והנה כלל ישראל אין עושים כן, ובונים לצד מזרח ועומדים לצד מזרח לגמרי כידוע ». *MB 94:10* : « מ"מ הבא להתפלל שם יתפלל לצד שהצבור מתפללין אך יצדד פניו למזרח ». Le Kitsour YY 94 §א ne tranche pas la méthode.
- **Correction proposée** : Garder le grand cercle par défaut. Quand l'écart entre les deux méthodes dépasse environ 20°, ajouter : « au minyan, priez dans la direction de la communauté et tournez seulement le visage (MB 94:10) ». Le « plein est » des communautés n'est donné par aucune des deux options actuelles.

### Tal oumatar d'un voyageur au 7 'Hechvan
**Différence entre poskim** · gravité basse · tous les noussa'h · tous lieux

- **Ce que fait l'app** : tal_oumatar suit le réglage Israël ou diaspora. Le 2026-10-18, on obtient tal_oumatar avec « Israël » et berakha avec « diaspora ». Un ben Erets Israël à New York ne voit donc pas « ותן טל ומטר ».
- **Ce que dit la source** : *MB 117:5* : « בן א"י בחו"ל או להיפך אם דעתו בתוך שנה לחזור שואל כמקומו » … « דכל אחד ישאל כבני העיר הנמצא בה ». Pour l'Edot, *Kitsour YY 117 §טו* tranche : « ישאל טל ומטר בשומע תפלה ». Voir aussi les §טז et §יז.
- **Correction proposée** : Une fois le réglage de résidence en place (voir le premier constat), en Edot, ajouter une consigne pliée selon le YY 117 §טו-יז ; en Ashkenaz, signaler la divergence du MB 117:5.

### Eilat et la Arava : un seul jour de fête
**Différence entre poskim** · gravité basse · tous les noussa'h · Israël

- **Ce que fait l'app** : TerritoireIsrael met Eilat, Yotvata, Ketoura et Sapir en Israël, avec un seul jour de fête. Taba en est exclue.
- **Ce que dit la source** : *Peninei Halakha, Moadim 9:4, note 3* : « אולם למעשה נפסקה הלכה שאילת בגבולות הארץ ועושים בה יום טוב אחד ». Pour l'Edot, le Kitsour YY (Chevi'it 1:5) dit de même : « אך אין צריך לעשות שם ב' ימים טובים של גלויות ». Le point est donc conforme pour ce rite.
- **Correction proposée** : Aucune correction de règle. Écrire dans TerritoireIsrael.kt et ZMANIM.md : « Eilat et la Arava : un jour (Yalkut Yosef, Chevi'it 1:5 ; Peninei Halakha 9:4) ; certains en doutent, selon l'avis qui place Na'hal Mitsrayim à el-Arich ». Retirer la mention du 'Hazon Ich, qui n'est pas étayée.

### אל ארך אפים un jour de jeûne qui n'est ni lundi ni jeudi
**Différence entre poskim** · gravité basse · Sfard, Ashkenaz · tous lieux

- **Ce que fait l'app** : Le texte est affiché quand kriat_hatorah ∧ tahanoun_chaharit sont vrais. C'est le cas le 06/10/2024 (Guedalia, dimanche), le 30/12/2025 (10 Tévèt, mardi), le 28/02/2029 (Esther, mercredi) et le 12/09/2029. L'app suit la lettre de la consigne de son siddour, qui n'énumère que des exceptions.
- **Ce que dit la source** : *Maté Efraïm 602:12* : « ואם חל ביום חמישי אומרים אחר כך "אל ארך אפים" וכו' ». Ce passage vise en fait un jour de brit mila ; pour le jeûne ordinaire, la restriction se déduit. Le *ShA haRav 429:12* lie le texte au lundi et au jeudi. D'après shulchanaruchharav.com, le Maharil le fait dire tous les jours de jeûne, contre l'usage répandu.
- **Correction proposée** : En faire une option ou un choix documenté dans ZMANIM.md, pas une correction obligatoire. La mention de Rinat Israël n'est pas vérifiable.

### Hilloulot du 30 'Hechvan ou du 30 Kislev quand le mois est court
**Différence entre poskim** · gravité basse · tous les noussa'h · tous lieux

- **Ce que fait l'app** : Ces hilloulot tombent toujours le 29 : le 20/11/2025, le 18/11/2028, le 07/11/2029, et le 06/12/2029 pour le 30 Kislev. Le choix figure dans le commentaire de Hilloulot.cles, sans source.
- **Ce que dit la source** : *MB 568:42* : « ומסיק המ"א דאם שנה ראשונה למיתת אביו השנה היא חסרה… יקבע היא"צ בכ"ט לחודש חשוון… אבל כששנה הראשונה היא ג"כ מלאה… יקבע בר"ח ויש מאחרונים שסוברין דלעולם יקבע בר"ח והעולם נוהגין כהמ"א ».
- **Correction proposée** : Compléter le commentaire de Hilloulot.cles et le README avec la source et la divergence. Puisque le champ « a » donne souvent l'année du décès, on peut appliquer la règle du MA ou afficher les deux dates. Le Yalkut Yosef n'a pas été trouvé sur ce point.

### Ta'hanoun les jours propres à 'Habad
**Différence entre poskim** · gravité basse · Sfard · tous lieux

- **Ce que fait l'app** : En Sfard, Ta'hanoun est dit le 30/11/2025 (10 Kislev), les 09 et 10/12/2025 (19-20 Kislev), le 28/06/2026 (13 Tamouz), ainsi qu'à Min'ha la veille. C'est l'usage Sfard 'hassidique général, que suit l'app ; 'Habad prie dans le noussa'h Ari.
- **Ce que dit la source** : chabad.org, « Tachanun » : « 10 Kislev, the day Rabbi Dov Ber was released from Czarist prison, starting the afternoon before. 19-20 Kislev… 12-13 Tammuz… starting the afternoon before. »
- **Correction proposée** : Si une option « usage 'Habad » est ajoutée, y inclure ces dates. Sinon, le signaler dans ZMANIM.md.

### Avinou malkénou à Min'ha du vendredi des dix jours (Edot)
**Différence entre poskim** · gravité basse · Edot · tous lieux

- **Ce que fait l'app** : En Edot, Min'ha (s1 b71-80) dépend de asseret_yemei_techouva. Avinou malkénou s'affiche donc le vendredi 26/09/2025. En Ashkenaz et en Sfard, il est replié, à juste titre (MB 584:4).
- **Ce que dit la source** : *Kitsour YY, סימן תקפב-תרב §כג* : « אחר תפלת החזרה בעשרת ימי תשובה אומרים ״אבינו מלכנו״ … וכן הדין במנחה ». Il ne dit rien du vendredi. Au *§כד*, on le dit même le Chabbat (« וכן ראוי לנהוג בכל ערי הארץ כמנהג ירושלים »). Le *Kaf ha'Haïm 584:7* rapporte les deux avis.
- **Correction proposée** : Garder le comportement actuel, qui suit la logique du Yalkut Yosef. Vérifier dans 'Hazon Ovadia, Yamim Noraïm, qu'il n'existe pas de décision explicite.

### Zmanim en vol : horizon au sol ou vu de l'altitude
**Non vérifiable** · gravité basse · tous les noussa'h · tous lieux

- **Ce que fait l'app** : Elle calcule les zmanim au sol sous l'avion, au niveau de la mer (Vol.lieuSous, altitude 0 ; vol.js:162, Vol.kt:154), avec les heures saisonnières du point. ZMANIM.md présente ce choix comme non tranché.
- **Ce que dit la source** : Seule une source secondaire a été lue, la FAQ KosherJava des zmanim en vol (en anglais) : « According to most Rabbinic opinions, when flying one should use the times on the ground directly below for sunrise. All opinions agree that for sunset, the times at ground level should be used. » Le Kitsour YY parle de l'avion à propos de la direction, de Tefilat haDerekh, de Hagomel et de Chabbat, mais pas de l'horizon.
- **Correction proposée** : Garder la mention de ZMANIM.md. Si un rite tranche, l'indiquer dans « Détail du calcul ».

#### Constats écartés

- **אנא בכח : le verset de la nuit (Edot)** : l'app affiche les sept versets avec leur étiquette et la consigne de répétition, comme un siddour imprimé ; replier six versets irait même contre « אנא בכח כולה ».
- **Birkat haIlanot dans l'hémisphère sud** : Eloul correspond à la première floraison (MB 226:1 « כל שרואה הלבלוב פעם ראשון מברך »). Il faut garder Eloul ; ajouter 'Hechvan ne serait qu'une amélioration.
- **HaGomel : cas couverts et réponse** : « מי שגמלך טוב » est le nusa'h du Kitsour Choul'han Aroukh 61:1 et du siddour Admour, et « האל שגמלך » celui du Ben Ich 'Haï. Il ne reste qu'à ajouter le trajet ou le vol de 72 min en Edot, ce qui est mineur.
- **Soukka à Chemini Atséret en diaspora** : les rites ne divergent pas, et les textes sont des prières qui ne contredisent rien. C'est une demande de fonction, pas un écart.
- **Tévilat kélim et Téroumot : présentation des textes** : les consignes en <small> suivent la convention des siddourim imprimés. La consigne « טבל ודאי » est juste. Seule reste une coquille de vocalisation (כֶּלִי au lieu de כְּלִי).
- **Tefilat haDerekh en vol de moins de 72 min (Edot)** : la prière est due pour tout vol (YY 110 §ב, §ג). Le texte ouvert donne la condition du Chem, et afficher « sans Chem » d'office contredirait le cumul des trajets du jour.
- **Ligne de date et tefillin** : afficher Min'ha après le passage est juste, ZMANIM.md ne donne volontairement aucun conseil, et l'app n'a aucun rappel de tefillin. C'est au plus une suggestion.
- **Prier dans l'avion (direction, position, minyan)** : tous les rites demandent la même chose : se tourner vers Jérusalem, et rester debout si possible. Le nez ou la queue de l'avion n'est qu'un moyen pratique. Rien ne contredit une source.
- **Début de Cha'harit en vol** : le rappel au netz suit le SA 89:1. La dérogation du SA 89:8 vise celui qui part avant le netz. La carte qui commence à l'aube montre seulement la fenêtre de validité.
- **Atterrir après l'entrée de Chabbat** : le jalon ENTREE peut apparaître alors que l'avion atterrit avant la chki'a de l'aéroport (DXB→LAX, 18/12/2026). Le §ד n'est pas inconditionnel, et l'écran donne le fait sans conseil, par choix validé.
- **ברוך ה׳ לעולם à Arvit (Ashkenaz, Israël)** : la citation du Maassé Rav (MB 236:11) parle du rattrapage après la Amida, pas d'un usage d'Israël. Le SA, le Rema et le MB tiennent ces versets pour un usage établi.
- **Min'ha de la veille de Pessa'h chéni (Edot)** : selon l'école de Rav Ovadia (Halakha Beroura, Chou"t haRichon leTsion II 12), on dit Ta'hanoun à cette Min'ha. L'app est donc conforme à la source qu'elle a choisie pour l'Edot.

#### Règles vérifiées conformes

- jourDeLaPriere rattache chaque nuit au bon jour hébreu pour chema_coucher et tikoun_hatsot (Paris, Bné Brak, Jérusalem). momentDuSiddour propose chema_coucher avant 'hatsot et tikoun_hatsot entre 'hatsot et l'aube.
- Chema du coucher en Edot : המפיל avant le Chema, les trois parachiyot, le Chema aussi le soir de Chabbat, « רבונו של עולם » permis le Chabbat, et pas de Chem après 'hatsot (YY רלט).
- Bougies en Edot : bénir avant d'allumer au Yom tov, formule « (שבת ו)יום טוב », pas de שהחיינו à Kippour. En Sfard et en Ashkenaz : formules de Kippour, et pas de שהחיינו le 7e et le 8e jour de Pessa'h.
- Ashkenaz : המפיל avec le Chem, sans distinction de 'hatsot, et la place de המפיל laissée au choix (MB 239:2).
- Birkat haIlanot au nord : du 1er au 30 Nissan, pas en Adar (SA 226:1 ; YY 226 §ט-י).
- Éclairs et tonnerre en Sfard et en Ashkenaz, arc-en-ciel en Edot, HaGomel en Edot (devant dix, « אודה ה' ») et en Sfard et Ashkenaz (תשלומין, SA 219:6) : conformes.
- 'Hala en Edot (1566,5 g et 2497 g), Loulav (שהחיינו le premier jour), Ouchpizin (ordre du Zohar), Tévilat kélim (verre, כלי/כלים), Mezouza en Edot, prière avant un remède (SA 230:4) : conformes.
- Nerot 'Hanouka (formules Edot, Ashkenaz, Sfard), bedikat et biour 'hamets, érouv tavchilin, riz « מזונות » et רביעית « בבת אחת » en Edot : conformes.
- Tefilat haDerekh en vol, en Ashkenaz et en Sfard : avec Chem pour tout vol (MB 110:30-31 ; ShA haRav 110:8). Rappel de Cha'harit au netz (SA 89:1).
- Boussole : la cible est le Dôme (SA 94:1). Les directions sont justes à Tel Aviv, dans la vieille ville, à Moscou, à Johannesburg et à Paris. Le grand cercle en Sfard suit le ShA haRav 94:2.
- TerritoireIsrael : Golan, Judée-Samarie et Gaza dedans ; Kuneitra, Taba, Aqaba et El-Arich dehors (Peninei Halakha 9:4). En vol, le calendrier suit le réglage de l'application.
- Parité Android et PWA : 46 260 lignes de conditions identiques du 2024-09-01 au 2030-12-31 (4 lieux, 4 réglages). Les tests Gradle passent.
- Sfard : pas de Ta'hanoun du 1er au 12 Sivan, Ta'hanoun à Min'ha la veille de Pessa'h chéni, « לקרא את ההלל », Birkat halevana 7 jours après le molad (Piskei haSiddour ; ShA haRav 488:2).
- Tous rites : pas de Ta'hanoun à Min'ha la veille de Lag baOmer, de Tou beAv et de Tou biChvat.
- Edot : אל ארך אפים lié au Ta'hanoun, et pas d'Avinou malkénou les jours de jeûne hors des dix jours. Ashkenaz : « עושה השלום » pendant les dix jours selon le Maté Efraïm 582:22.


---

