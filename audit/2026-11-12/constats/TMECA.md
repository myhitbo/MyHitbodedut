# TMECA — Chaînes — contrôles mécaniques sur les trois langues et le code

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

13 constats — confirmés : 1 · non contre-expertisés (mineurs et cosmétiques) : 12.

> Contre-expertise incomplète pour cette dimension.

## Ce qui a été examiné

Lu en entier : OUT/traductions/COUV/couverture.md ; les trois strings.xml principaux (1 457, 1 392 et 1 428 lignes) et les trois de l'édition light, par analyse complète ; TraductionTest.kt ; web/tools/chaines.mjs et web/src/js/i18n.js ; Libelles.kt, JaugeSemaine.kt, ZmanimVignette.kt (partie vues), RappelsTefila.kt (cartes), TropheesVue ; web/src/index.html et manifest.webmanifest. Scripts (repris de l'auditeur précédent après relecture, puis complétés) sous OUT/TMECA : parse.py, c1 à c9, m4.py (références par clé), m6.py (doublons croisés), m7.py et mp.py (typographie, ponctuation finale), m8.py, m8b.py, m8c.py (descriptions d'accessibilité), mq.py et mtype.py (quantités et types aux appels), maapt.py (relecture indépendante contre le site déployé), dyn.mjs et dyn2.mjs (clés dynamiques du web et familles de Libelles), java/E.java (dates). Points 1 à 3 : chiffres de l'inventaire confirmés (les 59 valeurs anglaises identiques sont 58 chaînes plus le pluriel partage_minutes) ; ce qu'il n'avait pas vu : l'édition light, les 8 chaînes de debug livrées, l'absence de contrôle des tableaux. Points 4 à 8 : balayage exhaustif des 152 fichiers Kotlin de main, des sources debug et musique_*, de tous les XML de android/app/src, des 29 fichiers de web/src/js et de web/tools, des tests Android et web pour les noms de clés ; chaque site d'ImageView/ImageButton créé en code a été ouvert (14 sites). Échantillonné seulement : la justesse des traductions elles-mêmes (une quarantaine de chaînes lues pour vérifier les signalements automatiques, pas de relecture linguistique d'ensemble) ; les contenus JSON de res/raw (hors de cette dimension, sauf livres_titres.json et bibliotheque.json consultés pour deux vérifications). Non examiné : l'application Nokia (88 textes en dur déjà documentés dans nokia/README.md), le rendu réel à l'écran (aucune compilation ni exécution Android ; les dates ont été rejouées sur JDK 21, dont les données de langue peuvent différer à la marge de celles d'un téléphone), le rapport lint (absent du dépôt), PUBLICATION_PLAY_STORE.md au-delà d'une recherche par mots-clés. Aucun fichier modifié hors de OUT ; aucune recherche web.

## Ce qui tient

- Parité vérifiée par script et conforme à l'inventaire de couverture : 1 184 chaînes en français dont 45 translatable="false", 1 139 en anglais et en hébreu, aucune clé manquante ni en trop ; 36 pluriels (one/other, plus two en hébreu), 2 tableaux de même longueur ; 0 écart de marqueurs entre langues ; 503 appels getString/getQuantityString et 650 appels tr.t/tr.p contrôlés sans écart de nombre d'arguments.
- Aucun texte en dur dans les 54 gabarits (49 layout, 3 layout-land, 2 debug), le menu, res/xml ni le manifeste ; dans les 152 fichiers Kotlin et les 29 fichiers JavaScript, tout texte d'interface passe par les chaînes, hors les quelques libellés hébreux signalés.
- Une seule source pour trois plateformes : le site relit strings.xml à la construction, et les trois tables déployées (1 184 chaînes chacune) sont identiques à une relecture indépendante faite selon les règles d'aapt (0 différence) ; toutes les clés employées par le web, y compris les 31 familles construites dynamiquement, existent.
- Accessibilité des images soignée : les 2 ImageButton et la seule ImageView cliquable des gabarits ont leur description, les images décoratives sont à @null ou importantForAccessibility="no", les boutons-icônes créés en Kotlin (MiniLecteur, ReglagesLecture, VolActivity) reçoivent tous un libellé par getString ; côté web, aucun bouton à icône seule sans aria-label.
- Échappements propres dans les trois fichiers : aucune apostrophe non échappée, aucun « ... » ASCII, aucune espace en tête ou en fin, aucun \n parasite, 26 isolats bidi ouverts pour 26 fermés et 28 paires de guillemets „ ” en hébreu, aucun mot français dans les valeurs anglaises ou hébraïques.
- Tables écrites à la main plutôt que getIdentifier (Libelles.kt, TropheesVue) : les 124 correspondances nom vers ressource sont exactes et la réduction des ressources ne peut rien retirer à tort.

## Constats

### TMECA-01 — Vignettes des zmanim : la fête du jour n'est jamais affichée (clé de libellé sans le préfixe « fete_ »)

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** ZmanimVignette cherche le libellé de la fête avec la clé nue (« pessah », « hanouka », « roch_hodech »), alors que la table Libelles.kt ne connaît que des clés préfixées (37 « fete_… », 61 « ajout_… », 26 « zman_… »). Libelles.res renvoie donc toujours null : la pastille des trois vignettes (2×2, 4×2, 4×4) n'affiche jamais la fête et retombe chaque fois sur « Paracha … » du Chabbat suivant (ou disparaît quand il n'y a pas de paracha, à Pessa'h ou Soukkot). Les quatre autres appels du code (CalendrierActivity.kt:183, PartageJour.kt:37, VolActivity.kt:786, VueJour.kt:158) écrivent bien Libelles.res("fete_$it"). Aucun test ne couvre ce chemin (VoyageNuitTest ne teste que jourHebreuAffiche et prochainChangement).

**Preuve.** android/app/src/main/java/com/myhitbodedut/ZmanimVignette.kt:84-85 : « // La fête du jour, sinon la paracha de la semaine. » puis « val fete = jour.fetes.firstNotNullOfOrNull { Libelles.res(it) }?.let { context.getString(it) } ». CalendrierJuif.kt:134-148 : FETES = « "erev_pessah", "pessah", … » (sans préfixe) ; CalendrierJuif.kt:320 : add("roch_hodech"). Libelles.kt : « else -> null » pour toute clé hors table.

**Correction proposée (revue par le contre-expert).** Écrire « jour.fetes.firstNotNullOfOrNull { Libelles.res("fete_$it") } » à ZmanimVignette.kt:85. Pour le test : le projet n'a pas Robolectric, donc on ne peut pas tester sur la machine virtuelle la pastille d'un RemoteViews. Il faut d'abord sortir le choix du libellé dans une fonction pure, par exemple « fun libelleFete(jour: CalendrierJuif.Jour): Int? ». Il faut ensuite la tester sur un jour de 'Hanouka et sur un Roch 'Hodech (résultat non nul, égal à R.string.fete_hanouka ou R.string.fete_roch_hodech). Il faut aussi vérifier que Libelles.res("fete_$f") est non nul pour chaque valeur de CalendrierJuif.FETES, plus pourim_ailleurs et pourim_jerusalem.

**Note du contre-expert.** Vérifié : ZmanimVignette.kt:85 appelle Libelles.res(it) sur des clés nues. Ces clés viennent de CalendrierJuif.FETES (l.134-169), de MUREE (l.220) et de add("roch_hodech") (l.320). Or Libelles.kt ne contient que des clés préfixées (37 fete_, 61 ajout_, 26 zman_) et finit par « else -> null » : la fête n'est donc jamais trouvée et la pastille des trois vignettes (déclarées dans le manifeste) retombe toujours sur la paracha, ou disparaît. Les quatre autres appels (CalendrierActivity:183, PartageJour:37, VolActivity:786, VueJour:158) utilisent bien "fete_$it". La ligne fautive est là depuis le commit d'origine 4b03703, et aucun test ne passe par ce chemin. CalendrierJuifTest:173 vérifie seulement que strings.xml contient fete_&lt;clé>.

### TMECA-02 — Hébreu : « vol_dans » dit « עד » (jusqu'à) au lieu de « עוד » (encore) pour le temps restant

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Sur la carte « prière du moment » de l'écran Vol, le compte à rebours en gras (22 sp) emploie vol_dans avec une durée. En français « encore %1$s », en anglais « %1$s left », mais en hébreu « עד %1$s », exactement la valeur de vol_jusqua (« jusqu'à %1$s ») affichée juste dessous. Un lecteur hébréophone voit deux lignes « עד … » : « עד 2 שע׳ ו־15 דק׳ » puis « עד 10:42 » ; la première ne dit plus « il reste ». Partout ailleurs la même idée est rendue correctement (widget_reste : « נותרו %s », grade_sous : « עוד %2$d »). Même chaîne sur le web (app.js:3615 et 3632).

**Preuve.** values-iw/strings.xml:1264 « &lt;string name="vol_jusqua">עד %1$s&lt;/string> » et :1266 « &lt;string name="vol_dans">עד %1$s&lt;/string> » ; values/strings.xml:1294 « encore %1$s » ; VolActivity.kt:878 « getString(R.string.vol_dans, dureeEnMots(minutes)) » suivi en :881 de « getString(R.string.vol_jusqua, deuxHeures(c.plan, limite)) ». Détecté par script : deux clés de même valeur hébraïque dont le français diverge (OUT/TMECA/m6.py).

**Correction proposée.** values-iw : &lt;string name="vol_dans">עוד %1$s&lt;/string> (ou « נותרו %1$s », comme widget_reste).

### TMECA-03 — Nombres sans pluriel : « Série : 1 jours sur 3 », « 1 trophées gagnés », « votre 1ᵉ trophée »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Six chaînes simples portent un nombre devant un nom au pluriel figé alors que la valeur 1 est atteinte en usage normal ; la légende voisine de la semaine, elle, utilise bien un &lt;plurals> (week_gauge). (a) ring_streak_detail, légende de l'anneau de série, premier jour de toute série : fr « Série : 1 jours sur 3 », he « רצף: 1 ימים מתוך 3 » (l'anglais « 1 of 3 days » tient). (b) rings_description (lecteur d'écran) : fr et he, même défaut deux fois dans la phrase. (c) grade_sous, en tête de l'écran Trophées dès le premier trophée : fr « 1 trophées gagnés », en « 1 trophies earned », he « 1 גביעים הושגו ». (d) trophees_autres quand il reste 16 trophées à venir : « … et 1 autres trophées plus loin » (3 langues). (e) grade_partage_texte : « … : 1 trophées » (3 langues). (f) trophee_detail_grade, fiche du premier trophée, français seul : « c'était votre 1ᵉ trophée » (il faut « 1er »). Les mêmes chaînes servent au web (app.js:365, 3949, 4006, 4083, 4130). partage_serie est protégé (serie >= 2), tefilot_count et library_entries_count ne descendent pas à 1 avec les données actuelles.

**Preuve.** values/strings.xml:105 « Série : %1$d jours sur %2$d » ; :107 « Semaine : %3$d jours sur %4$d. Série : %5$d jours sur %6$d. » ; :916 « %1$d trophées gagnés · encore %2$d pour %3$s » ; :923 « … et %1$d autres trophées plus loin » ; :1117 « En %1$s : c'était votre %2$dᵉ trophée. » ; :1123 « %2$d trophées ». values-iw:98 « רצף: %1$d ימים מתוך %2$d ». Appels : MainActivity.kt:637-640 (etat.serie.fait), PaliersActivity.kt:78 (n = trophées gagnés), :147 (futurs.size - MONTRES), FicheTrophee.kt:81 (rangGlobal).

**Correction proposée.** Passer ring_streak_detail, grade_sous, trophees_autres et grade_partage_texte en &lt;plurals>. Français : one « Série : %1$d jour sur %2$d », « %1$d trophée gagné · encore %2$d pour %3$s », « … et %1$d autre trophée plus loin ». Anglais : one « %1$d trophy earned · %2$d more for %3$s », « … and %1$d more trophy further on ». Hébreu : one « רצף: יום אחד מתוך %2$d », two « רצף: יומיים מתוך %2$d », one « גביע אחד הושג · עוד %2$d ל%3$s », « … ועוד גביע אחד בהמשך ». trophee_detail_grade (fr) : « En %1$s : c'était votre trophée n° %2$d. » rings_description : reprendre les formes de week_gauge et de status_streak au lieu de « %d jours ».

### TMECA-04 — 45 chaînes mortes traduites en trois langues, dont 3 exigées par des tests et 5 textes d'information sur les envois en ligne

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Sur 1 222 entrées (1 184 chaînes, 36 pluriels, 2 tableaux), 54 clés n'ont aucune référence : ni R.string/R.plurals dans les sources Kotlin (main, debug, musique_*), ni @string dans les XML, ni nom littéral ou gabarit dynamique dans web/src/js et web/tools (31 gabarits « prefixe_${…} » vérifiés un à un), ni Nokia. 11 sont une réserve voulue et commentée (track_niggoun_08, track_shmuel_one_prayer, 9 track_yanuka_*). Restent 43 clés réellement mortes (42 chaînes, 1 pluriel), plus 2 autres masquées par la table Libelles.kt qui les « référence » sans que rien ne les demande (ajout_hallel, ajout_chol) : 45 clés, 135 traductions entretenues pour rien et livrées dans les trois strings.&lt;langue>.json du site. Trois tests imposent même la présence de chaînes mortes : SettingsTest.kt:141 (action_open), WidgetTest.kt:319 (widget_resume), TipsTest.kt:26 (tips_open). Cinq de ces chaînes sont les explications précises de ce qui part en ligne (vol_route_aide, vol_route_explication, vol_direct_titre, vol_direct_explication, vol_direct_explication_opensky) : seul vol_en_ligne_aide, plus bref, est affiché. reminders_hint (« Rien ne sonne un jour de repos, ni une fois la hitbodedout faite ») n'est plus montré non plus. Par ailleurs 8 chaînes proofread_* ne servent qu'à src/debug mais sont dans le strings.xml principal, traduites en anglais et en hébreu et livrées en version publiée.

**Preuve.** Script OUT/TMECA/m4.py puis grep de contrôle sur tout le dépôt. Clés mortes : action_journal, ring_day, ring_week, ring_streak, action_open, widget_resume, settings_music, music_open_library, tips_open, chizuk_debug_notice, library_open, reminders_hint, reminders_open, zmanim_omer, paliers_title, paliers_sous_titre, palier_prochain, palier_atteints, trophees_titre, trophees_prochain, trophees_gagnes, trophees_a_venir, trophees_aucun_gagne, trophees_compte, trophee_niveau, trophees_explication, trophee_a_venir, trophee_prochain, trophee_sommet, trophee_vedette, trophee_vedette_aucune, trophee_a_gagner, widget_zmanim_jusqua, widget_zmanim_chkia, source_du_jour_commencer, parcours_moyenne, parcours_jours (pluriel, remplacé par parcours_unite_jours), vol_route_aide, vol_route_explication, vol_fiabilite_titre, vol_direct_titre, vol_direct_explication, vol_direct_explication_opensky ; ajout_hallel et ajout_chol (seule occurrence : Libelles.kt). Réserve commentée : values/strings.xml:350-351 « En reserve : ces morceaux sont dans musique/, hors de l'APK. »

**Correction proposée.** Supprimer les 45 clés dans values, values-en et values-iw (et leurs deux lignes de Libelles.kt), retirer « action_open », « widget_resume » et « tips_open » des trois tests, déplacer les 8 proofread_* dans src/debug/res/values/strings.xml. Avant de supprimer vol_direct_explication_opensky, décider si son contenu (« un carré de 10° autour de la position estimée ; l'indicatif reste sur le téléphone ») doit rejoindre vol_en_ligne_aide. Ajouter un test « toute clé de strings.xml est référencée par Kotlin, un XML ou web/src/js », avec une liste d'exceptions nommée pour la réserve musicale.

### TMECA-05 — Musique de l'édition Play : une note de travail « (titre incertain) » affichée comme titre, et un test qui ne garde rien

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** Le morceau ianir_zemer_bishvahin, livré dans toutes les éditions (MusiquePlay.kt:31) et sur le site (data/musique.json), s'affiche sous le titre « Zemer bichva'hin (titre incertain) — Ianir » dans les trois langues : la remarque d'atelier est restée dans une chaîne translatable="false". Le test « aucun titre de morceau ne reste en francais » ne cherche que la suite de caractères « titre à préciser » : il passe alors que 9 titres non traduisibles sont rédigés en français (« Niggoun de Berditchev », « Niggoun de 'Houppa »…, déjà relevés par l'inventaire de couverture) et que cette note est visible. Les 8 seules apostrophes droites du fichier français sont dans ces titres, quand le reste de l'application emploie « ’ » (403 occurrences).

**Preuve.** values/strings.xml:339 « &lt;string name="track_ianir_zemer_bishvahin" translatable="false">Zemer bichva\'hin (titre incertain) — Ianir&lt;/string> » ; TraductionAffichageTest.kt:96-98 « fun `aucun titre de morceau ne reste en francais`() … contains("titre à préciser") » ; apostrophes droites aux lignes 326, 331, 333, 334, 339, 341, 342, 344.

**Correction proposée.** Titre : « Zemer bichva’hin — Ianir » une fois confirmé auprès de l'artiste, sinon un titre neutre (« Zemer — Ianir »). Rendre traduisibles les 9 titres descriptifs (« Niggun of Berditchev — Ianir », « ניגון ברדיצ׳ב — יניר »…) ou les écrire dans une langue unique assumée. Remplacer les 8 « \' » par « ’ ». Faire échouer le test sur « incertain|à préciser|à vérifier » et sur tout titre translatable="false" commençant par « Niggoun d ».

### TMECA-06 — Dates écrites par motifs figés à la française : fausses en anglais et en hébreu, et différentes du web

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Huit endroits construisent la date avec un motif en dur dans l'ordre français (« EEEE d MMMM yyyy », « EEE d MMM »…), appliqué tel quel aux trois langues. Résultat exécuté (JDK 21, mêmes données CLDR) : anglais « Thursday 12 November 2026 » au lieu de « Thursday, November 12, 2026 » ; hébreu « יום חמישי 12 נובמבר 2026 » au lieu de « יום חמישי, 12 בנובמבר 2026 » (la préposition ב et la virgule manquent). Le web, lui, passe par Intl.DateTimeFormat (app.js:2243, 2661, 2689, 3929, 4588) et rend la forme correcte : les deux plateformes n'écrivent pas la même date. Android n'est pas cohérent avec lui-même non plus : AjoutTemps.kt:24, FicheTrophee.kt:77 et PaliersActivity.kt:193 utilisent ofLocalizedDate et sont justes.

**Preuve.** JournalActivity.kt:80 « DateTimeFormatter.ofPattern("EEEE d MMMM yyyy", langue) » ; PartageJour.kt:43 et VueJour.kt:74 (même motif) ; VueJour.kt:93-94 « "EEE d MMM" », « "EEE d MMM, HH:mm" » ; VolActivity.kt:423, 564 (« "EEE d MMM yyyy · HH:mm" »), 1147. Sortie de OUT/TMECA/java/E.java : « en | motif: Thursday 12 November 2026 | FULL: Thursday, November 12, 2026 », « he | motif: יום חמישי 12 נובמבר 2026 | FULL: יום חמישי, 12 בנובמבר 2026 ».

**Correction proposée.** Dates longues : DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL).withLocale(locale), comme AjoutTemps.kt:24. Dates courtes : android.text.format.DateFormat.getBestDateTimePattern(locale, "EEEdMMM") (et "EEEdMMMHHmm") à la place des motifs écrits à la main. Un test de trois lignes par langue sur le 12/11/2026 fige le résultat attendu.

### TMECA-07 — TraductionTest laisse passer la plupart des façons d'écrire un texte en dur

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Le test censé garantir qu'« aucun texte ne peut échapper à la traduction » a cinq angles morts. (1) Il ne lit que res/layout : ni layout-land (3 gabarits), ni menu, ni res/xml. (2) Dans le code, son motif exige un point devant « text = » ; or l'application construit ses écrans par « TextView(c).apply { text = … } » (156 affectations sans point contre 111 avec) et par VueJour.texte(contexte, …) (139 appels), qu'il ne regarde pas. Rejoué par script, il ne voit aucune des 11 affectations littérales actuelles (ReglagesLecture.kt:132 « text = "אב" », RepriseFavoris.kt:151 « text = "$titre  ›" », NoteDialog.kt:68 « contentDescription = "${i + 1}/5" »…) : elles sont légitimes aujourd'hui, mais un « text = "Bonjour" » passerait de la même façon. (3) Le motif des marqueurs ignore les formats à largeur : « %2$02d » de duration_hours_minutes n'est pas comparé entre langues. (4) Les &lt;string-array> (boussole_cardinaux, boussole_points) ne sont lus par aucun contrôle de parité ; un élément manquant en hébreu donnerait un dépassement d'indice. (5) Rien ne détecte une chaîne jamais référencée. Le premier test s'appelle encore « les quatre langues » pour trois.

**Preuve.** TraductionTest.kt:135 « File("src/main/res/layout").listFiles » ; :151 « Regex("""\.(text|hint|contentDescription)\s*=\s*"([^"]{2,})"""") » ; :58 « Regex("""%\d+\$[sd]|%[sd]|%%""") » ; :40-43 seuls "string" et "plurals" sont lus ; :61 « `les quatre langues portent le meme jeu de cles` ». Simulation : OUT/TMECA (script en ligne, 0 faute vue par le test, 11 affectations non vues).

**Correction proposée.** Parcourir src/*/res/layout*, menu et xml ; remplacer le motif par « (?&lt;![\w.])?(text|hint|contentDescription)\s*=\s*"[^"$]*\p{L}{2,} » sans exiger le point, et ajouter « VueJour\.texte\([^,]+,\s*" » ; marqueurs : « %(\d+\$)?[-0,+ ]*\d*(\.\d+)?[a-zA-Z%] » ; comparer la longueur de chaque string-array dans les trois langues ; renommer le test « les trois langues… ».

### TMECA-08 — Libellés hébreux écrits dans le code : source de la halakha du jour et date des hilloulot, hors traduction

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Seuls littéraux affichés qui échappent à strings.xml, en double sur Android et sur le web : la ligne de source de la halakha du jour (« בן איש חי · שנה ראשונה · … · אות א », « ילקוט יוסף · … · סעיף ב ») et les 14 noms de mois de la date d'une hilloula. Un utilisateur en français ou en anglais lit ces repères en hébreu seul, alors que la même application sait écrire « Ben Ish ’Haï » (halakha_source_bih) et « Yalkut Yosef » (halakha_source_yalkut) dans ses réglages. Point déjà vu par l'inventaire de couverture ; il n'est consigné ni comme choix ni comme manque dans FEUILLE_DE_ROUTE.md.

**Preuve.** HalakhaActivity.kt:196 « listOf("בן איש חי", if (h.annee == 1) "שנה ראשונה" else "שנה שנייה", h.section, "אות ${Reference.lettres(h.numero)}") » ; YalkutYosef.kt:101 et :105 « "ילקוט יוסף" … "סעיף ${s.lettre}" » ; Hilloulot.kt:114-116 (MOIS) ; web/src/js/halakha.js:88, yalkut.js:70 et 73, jour-affiche.js:226.

**Correction proposée.** Composer la source à partir de chaînes : halakha_source_bih, halakha_source_yalkut, et quatre nouvelles clés (fr « 1re année » / « 2e année », « lettre %1$s », « paragraphe %1$s » ; en « Year 1 » / « Year 2 », « letter %1$s », « se’if %1$s » ; he tel quel). Pour les mois, passer par le formateur du calendrier déjà traduit ou 14 clés mois_*.

### TMECA-09 — Même notion, plusieurs graphies ou plusieurs noms selon la clé

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Relevé par script des clés de même valeur dans une langue et de valeurs différentes dans une autre, et des variantes de translittération. Anglais : « Tsadik » / « Tsadeket » (adresse_tsadik, adresse_tsadeket, celebration_tsadik, celebration_tsadeket) contre « tzaddik » / « tzaddikim » (hilloulot_recherche, hilloulot_nombre) ; trois noms pour le même écran : « Halacha Yomit » (halakha_yomit_titre), « Halacha of the day » (halakha_title), « Daily halacha » (zmanim_bouton_halakha) ; « Fold away » (lecture_replier) contre « Collapse » (siddur_replier) pour le même « Replier ». Français : « Tefila » (settings_hitbodedut_hint), « Téfila » (zman_szt_mga, zman_szt_gra), « téfila » (ajout_anenou_particulier), « tefila » (banniere_chaharit) ; « Compte de l'Omer » (rappel_omer_titre, ajout_omer) contre « Sefirat haOmer » (vol_rappel_omer_titre) ; le livre s'appelle « Yalkut Yosef, Kitsour Choul’han Aroukh » dans strings.xml (halakha_livre, halakha_yalkut_source, halakha_source_yalkut) et « Yalkout Yossef – Kitsour Choul'han Aroukh » dans livres_titres.json. Hébreu : un même bouton tantôt nom, tantôt infinitif (« שיתוף » / « לשתף », « המשך » / « להמשיך », « להמשך קריאה » / « להמשיך לקרוא »).

**Preuve.** values-en/strings.xml:462 « Tsadik », :818 « Search for a tzaddik », :788, :840, :993, :587, :742 ; values/strings.xml:185, :720, :775, :1160, :1149, :1362, :909 ; res/raw/livres_titres.json « "fr":"Yalkout Yossef – Kitsour Choul'han Aroukh" ». Scripts OUT/TMECA/c6.py, m6.py, c6b.py.

**Correction proposée.** Anglais : « Tzaddik » / « Tzaddeket » (« Well done, Tzaddik! ») ; « Halacha Yomit » sur les trois clés ; « Collapse » pour lecture_replier. Français : « Tefila » partout (comme « Tefilot », « Tefilat haDerekh ») ; « Compte de l'Omer » pour vol_rappel_omer_titre ; une seule graphie du livre, celle de la bibliothèque : « Yalkout Yossef ». Hébreu : l'infinitif pour les boutons d'action (« לשתף », « להמשיך », « להמשיך לקרוא »).

### TMECA-10 — Typographie : 22 valeurs françaises sans espace insécable, une apostrophe ouvrante, une phrase hébraïque sans point

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Le fichier français suit une règle nette (171 valeurs avec espace insécable devant « : ; ? ! » et dans les guillemets), mais 22 valeurs, toutes parmi les ajouts récents, ont une espace ordinaire : la ligne peut se couper juste avant « ? » ou « : ». Clés (ponctuation) : section_dedicace_hint, dedicace_quoi, dedicace_nom, dedicace_sans_messagerie, dedicace_corps_demande, music_remove_confirm_web, music_remove_message_web, ajout_facultatif_avant, ajout_facultatif_apres, vol_direct_activer, divulgation_overlay_texte, divulgation_usage_texte, vol_en_ligne_aide, vol_en_ligne_titre, vol_rapide_exemple, vol_rapide_rien, vol_rapide_compris, vol_rapide_estimee, vol_rapide_estimee_court, vol_rapide_manque, lecture_sans_traduction ; guillemets : track_shpayer_ki_hine_kahomer et quatre des précédentes. Autres écarts isolés : boussole_note écrit « Ora’h ‘Haïm » avec une apostrophe ouvrante U+2018 (ailleurs « Ora’h ’Haïm », rappel_source) ; trophees_paliers a deux espaces après l'émoji, qu'Android ramène à une seule ; en hébreu, vol_frise_retard est la seule phrase sans point final ni virgule, et vol_rapide_rien la seule à employer « » au lieu de „ ”.

**Preuve.** values/strings.xml:38 « Que dédiez-vous ? » (espace ordinaire) ; :1383 « (Ora’h ‘Haïm 94, 2) » ; :932 « 🏆  Trophées » ; values-iw/strings.xml:1231 « אם הטיסה תתעכב הזמנים ישתנו בהתאם » ; :1408 « ‎«LY 382 פריז תל אביב 12.11 בשעה 9:40»‎ ». Comptes : OUT/TMECA/m7.py et mp.py.

**Correction proposée.** Remplacer l'espace par U+00A0 dans les 22 valeurs ; « Ora’h ’Haïm » ; une seule espace dans trophees_paliers (ou l'écrire entre guillemets si l'écart est voulu) ; hébreu : « אם הטיסה תתעכב, הזמנים ישתנו בהתאם. » et « „LY 382 פריז תל אביב 12.11 בשעה 9:40” ». Ajouter au test de typographie : en français, aucune espace ordinaire devant « ; : ? ! » ni à l'intérieur de « ».

### TMECA-11 — Ponctuation française et unités latines collées dans le code, identiques dans les trois langues

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : fonction

**Constat.** Quelques assemblages de texte se font dans le code avec des séparateurs propres au français. (a) « Aujourd'hui : … » : l'espace devant les deux-points est en dur, donc « Today : … » et « היום : … » à l'écran de lecture du siddour, sur Android et sur le web ; même chose dans quatre libellés d'accessibilité du web et un d'Android. (b) JaugeSemaine.dureeCourte écrit « 1h20 » et « 25′ » avec un « h » latin dans la bande de la semaine, quand l'hébreu dit « שע׳ » partout ailleurs (choix de compacité du 14/10, non décliné par langue). (c) Les boutons d'humeur n'ont pour libellé d'accessibilité que « 1/5 » … « 5/5 » (Android et web).

**Preuve.** SiddurLectureActivity.kt:562 « text = getString(R.string.siddur_aujourdhui) + " : " + ligne.texte » ; web/src/js/app.js:1447 « `${tr.t('siddur_aujourdhui')} : ` » ; app.js:1154, 1340, 3075, 3256 (« … : … » dans aria-label) ; SiddurActivity.kt:44 ; JaugeSemaine.kt:24-25 « minutes % 60 == 0 -> "${minutes / 60}h" », « "${minutes / 60}h%02d".format(minutes % 60) » ; NoteDialog.kt:68 « contentDescription = "${i + 1}/5" » ; app.js:4639.

**Correction proposée.** Une chaîne à marqueurs pour l'étiquette : fr « %1$s : %2$s » (avec insécable), en « %1$s: %2$s », he « %1$s: %2$s » (tehilim_week_state a déjà exactement ces trois formes et peut servir). Deux chaînes courtes pour la bande : fr/en « %1$dh%2$02d », he « %1$d:%2$02d ». Humeur : « Humeur %1$d sur 5 » / « Mood %1$d of 5 » / « מצב רוח %1$d מתוך 5 ».

### TMECA-12 — « 1 h 05 min » en anglais et en hébreu : minutes à deux chiffres suivies de leur unité

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** duration_hours_minutes garde le format à zéro initial du français (« 1 h 05 », où il remplace l'unité) mais y ajoute l'unité en anglais et en hébreu : « 1 h 05 min », « 1 שע׳ 05 דק׳ ». L'écran Vol, lui, écrit sans zéro (vol_duree_heures_minutes : « %1$s h %2$s min »). C'est la seule chaîne à largeur fixe des trois fichiers.

**Preuve.** values/strings.xml:596 « %1$d h %2$02d » ; values-en/strings.xml:536 « %1$d h %2$02d min » ; values-iw/strings.xml:547 « %1$d שע׳ %2$02d דק׳ ».

**Correction proposée.** Anglais : « %1$d h %2$d min ». Hébreu : « %1$d שע׳ %2$d דק׳ ». Français inchangé.

### TMECA-13 — Web : table de repli française morte, et échantillon de police en dur portant le Nom

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** Deux restes dans app.js, seul endroit du site où un texte ne vient pas de strings.xml. (1) CHAINES_LECTURE : neuf libellés français de secours « tant qu'Android ne les a pas encore » ; les neuf clés existent depuis longtemps dans les trois langues, la table ne sert donc plus, et la fonction tl() qui l'emploie afficherait le nom brut de la clé pour toute autre chaîne manquante au lieu de signaler l'erreur. (2) Le choix de la police montre sept fois le verset « בְּרֵאשִׁית בָּרָא אֱלֹהִים » comme exemple, écrit en dur ; Android n'affiche aucun exemple (simple menu). Afficher un Nom pour un essai de caractères est une affaire de sensibilité plus que de règle, mais rien ne l'impose ici.

**Preuve.** web/src/js/app.js:1020-1034 « /** Les chaînes nouvelles, tant qu'Android ne les a pas encore : le français. */ const CHAINES_LECTURE = { lecture_reglages: 'Réglages de lecture', … } » et « catch { return formate(CHAINES_LECTURE[cle] ?? cle, args); } » ; app.js:1278 « h('span', { class: 'choix-police-exemple', lang: 'he', dir: 'rtl', … }, 'בְּרֵאשִׁית בָּרָא אֱלֹהִים') ».

**Correction proposée.** Supprimer CHAINES_LECTURE et remplacer les 16 appels tl( par tr.t(. Pour l'exemple de police, un texte vocalisé sans Nom, par exemple « אַשְׁרֵי יוֹשְׁבֵי בֵיתֶךָ ».
