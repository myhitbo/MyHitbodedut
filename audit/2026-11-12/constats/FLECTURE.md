# FLECTURE — Android — lecture, bibliothèque, recherche, signets

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

26 constats — confirmés : 6 · confirmés en partie : 1 · non contre-expertisés (mineurs et cosmétiques) : 19.

> Contre-expertise incomplète pour cette dimension.

## Ce qui a été examiné

Lu en entier (30 fichiers de la mission) : SiddurActivity, SiddurLectureActivity, TehilimActivity, TehilimLectureActivity, TikkunFlowActivity, TefilotActivity, TipsActivity, LibraryActivity, LibraryEntryActivity, LibrarySubSectionActivity, HalakhaActivity, ChizukActivity, ChizukCard (avec l'objet Data), ChizukBag, ChizukRules, RechercheActivity, RechercheGlobale, ReglagesLecture, MarquesPages, RepriseFavoris, BandeauDefilant, IndicateurDefilement, PoliceHebraique, Langue, Langues, LanguesTexte, Reference, Dedicace, Plaque, LivresBruts. En suivant les appels : SiddurJour, Aeration, Tehilim, Tikkun, Tefilot, LibraryRules en entier ; Store, Siddur, Halakha, YalkutYosef, HilloulotActivity, MainActivity, Json, VueJour, SettingsActivity par extraits ; AndroidManifest (toutes les activités). Layouts lus : activity_siddur_lecture, activity_tehilim_lecture, activity_tikkun_flow, activity_library_entry, activity_recherche en entier ; activity_library, activity_tehilim, activity_chizuk, activity_settings par extraits (9 sur 49). Chaînes : les clés françaises de la dimension (lecture, Tehilim, Tikoun, recherche, marque-pages, dédicace, bibliothèque, 'hizouk) ; anglais et hébreu seulement pour la dédicace et quelques clés. FEUILLE_DE_ROUTE.md lignes 990-1163 ; README et PUBLICATION_PLAY_STORE par recherche de mots.

Données analysées par script (toutes) : les 12 livres, les 3 siddourim, siddur_annotations, tehilim, tikkun_haklali, chizuk, bibliotheque, ben_ish_hai, yalkut_yosef, hilloulot (noms français), et les 7 polices de res/font.

Mesures : JVM de bureau uniquement (org.json, OpenJDK 21). Scripts et bancs sous OUT/flecture/v2 (stats.py, fonts.py, Bench.java repris de l'auditeur précédent, Bench2.java, Bench3.java, Bench4.java).

Non examiné : rien n'a tourné sur téléphone ni émulateur. Les durées sur appareil sont des extrapolations, signalées par une confiance moyenne ; aucun rendu vu à l'écran (mélange de polices, fond noir partiel, ordre bidi, ce dernier vérifié par calcul) ; TalkBack non essayé ; BandeauDefilant lu mais non exercé. Tests unitaires listés et lus pour partie (LectureTest, MarquesPagesTest, DedicaceTest), non exécutés. Il n'existe pas de défilement automatique dans le code : rien à auditer sur ce point. Le site web et le Nokia sont hors de cette dimension ; la recherche du web a seulement été comparée (même calcul, donc mêmes limites). Les constats de traduction manquante (siddour, Yalkut Yosef à 10 %) relèvent de l'audit de couverture et ne sont repris ici que par leurs effets sur la barre de lecture et la recherche.

## Ce qui tient

- Le lecteur du siddour est solide sur l'essentiel : liste recyclée pour des prières de 350 à 580 paragraphes, DiffUtil pour déplier un ajout sans perdre sa place, place enregistrée à chaque onPause et rendue après une recréation, et une prière restée ouverte jusqu'au lendemain qui se redessine pour le jour (onRestart, règle des trois heures).
- Le masquage des signes absents des polices est exact. Vérifié avec fontTools sur les sept fichiers de res/font et sur tous les textes : chaque point ou ta'am utilisé et absent d'une police est masqué (aucun oubli), par un remplacement de même longueur qui ne décale ni signets ni positions. Le point « police (signes absents) » du lot du 28/10 est traité pour les signes combinants.
- Les règles sont séparées d'Android et testées (MarquesPages, LanguesTexte, ChizukBag, Aeration, SiddurJour, RechercheGlobale.nu) ; la normalisation de recherche couvre nikoud, te'amim, maqaf, paseq, guillemets, accents latins et apostrophes typographiques.
- Les Tehilim sont justes dans leurs données et leurs cycles : 2 527 versets, traductions française et anglaise alignées verset par verset sans aucun vide, et les deux découpages (mois, semaine) couvrent le livre exactement une fois (sommes recalculées : 2 527 chacune), avec le cas du mois de 29 jours.
- La recherche globale tourne hors du fil de l'interface avec un délai de frappe et un arrêt propre (onDestroy), et ChizukActivity comme HalakhaActivity sauvent leur état à la rotation.
- Plusieurs attentions d'accessibilité réelles : action d'accessibilité pour faire revenir le bouton masqué sans double toucher, descriptions sur tous les boutons de la barre, état annoncé pour la lune, cibles de 48 dp sur la bande de signets et dans la grille des 150 Tehilim.

## Constats

### FLECTURE-01 — L'écran s'éteint pendant la prière : aucun écran de lecture ne le garde allumé

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** Ni le siddour, ni les Tehilim, ni le Tikoun, ni les livres, ni les sources ne posent FLAG_KEEP_SCREEN_ON (ni android:keepScreenOn dans les layouts). Avec la mise en veille par défaut (30 s sur la plupart des téléphones), l'écran s'assombrit puis se verrouille au milieu d'un paragraphe de la Amida ou d'un psaume lu lentement ; il faut déverrouiller le téléphone en pleine prière. L'application sait pourtant le faire pour la séance, et le Tikoun revendique lui-même une lecture « sans interruption ».

**Preuve.** Recherche de KEEP_SCREEN_ON|keepScreenOn dans A/java et A/res : deux occurrences seulement, K/SessionActivity.kt:73 « window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) » et K/GateService.kt:159. Rien dans SiddurLectureActivity, TehilimLectureActivity, TikkunFlowActivity, LibraryEntryActivity. K/TikkunFlowActivity.kt:16 : « להמשיך מזה לזה ברצף אחד, ללא הפסק ».

**Correction proposée.** Dans onCreate de SiddurLectureActivity, TehilimLectureActivity, TikkunFlowActivity et LibraryEntryActivity : window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON), retiré après une dizaine de minutes sans toucher (pour ne pas vider la batterie d'un téléphone posé), avec un interrupteur « Garder l'écran allumé pendant la lecture » dans les réglages, activé par défaut.

**Note du contre-expert.** Une recherche de KEEP_SCREEN_ON/keepScreenOn dans A/java et A/res ne trouve que SessionActivity.kt:73 et GateService.kt:159. Le web, lui, ne pose wakeLock que pour la séance (app.js:4722). Aucun écran de lecture (siddour, Tehilim, Tikoun, sources, livres) ne garde donc l'écran allumé. Seule nuance : la phrase « ללא הפסק » de TikkunFlowActivity.kt:16 est un commentaire qui cite la source, et le sous-titre « sans interruption » a été retiré exprès le 12/10 ; cet argument d'appui est donc forcé, mais le défaut reste entier.

### FLECTURE-02 — Recherche : un seul résultat par livre ou par prière, et le toucher n'ouvre pas à l'endroit trouvé

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** La recherche ne garde, pour chaque texte, que le premier paragraphe qui contient le mot. Or un livre entier est un seul « texte » : Likoutei Moharan (411 chapitres, 7 057 paragraphes) ne peut donner qu'un résultat. Mesuré sur les données : « שמחה » figure dans 557 paragraphes des livres, la recherche en montre 11 ; « התבודדות », 164 paragraphes, 6 résultats. De plus le résultat ne porte que l'identifiant du texte : le toucher ouvre le livre ou la prière à la place de lecture enregistrée (ou au début), jamais au paragraphe dont l'extrait est affiché. Pour Cha'harit (359 à 583 paragraphes) ou un livre, l'utilisateur ne retrouve pas ce qu'il vient de voir.

**Preuve.** K/RechercheGlobale.kt:35-36 « t.sections.asSequence().flatMap { it.blocs.asSequence() }.firstOrNull { !it.consigne && nu(it.texte).contains(q) }?.let { Resultat(sorte, t.id, titre, extrait(it.texte, q)) } » ; K/RechercheGlobale.kt:13 « data class Resultat(val sorte: Sorte, val id: String, val titre: String, val extrait: String) » ; K/RechercheActivity.kt:119-120 « SiddurLectureActivity.ouvrir(context, r.id) » / « SiddurLectureActivity.ouvrirLivre(context, r.id) ». Comptages : script stats sur RAW/livre_*.json (12 livres, un texte chacun).

**Correction proposée.** Rendre toutes les occurrences (par exemple 5 par texte, puis « n autres dans ce livre »), ajouter section et paragraphe à Resultat, afficher le titre du chapitre dans la ligne, et ouvrir avec l'extra MARQUE déjà géré par SiddurLectureActivity (« section:bloc », allerA) pour arriver sur le paragraphe.

**Note du contre-expert.** RechercheGlobale.kt:32-37 s'arrête au premier paragraphe trouvé de chaque texte, et chaque livre_*.json ne contient qu'un seul texte : 411 sections et 7 057 paragraphes pour Likoutei Moharan. J'ai recompté avec la même normalisation : 557 paragraphes et 11 textes pour « שמחה », 164 et 6 pour « התבודדות ». Resultat ne porte que l'id, et ouvrir/ouvrirLivre ne passent pas MARQUE : le lecteur reprend donc à Store.positionLecture ou au début (SiddurLectureActivity.kt:90-92).

### FLECTURE-03 — Livres de 411 et 1 048 chapitres sans sommaire : la seule navigation est une bande horizontale de pastilles

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** Un livre s'ouvre directement dans le lecteur du siddour, d'un seul tenant. Pour aller à un chapitre, il n'existe que la bande de signets du haut, qui reçoit une pastille par chapitre : 411 pour Likoutei Moharan, 1 048 pour le Yalkut Yosef (108 Sefer HaMidot, 105 Hichtapkhout, 55 Likoutei Etsot). Pas de liste des chapitres, pas de « aller à », l'indicateur de défilement ne se saisit pas, et la recherche n'y conduit pas (constat précédent). Atteindre « Torah 282 » ou un siman du milieu du Yalkut Yosef revient à faire défiler des centaines de pastilles ou des milliers de paragraphes. Ces 1 048 vues sont en outre recréées à chaque changement de taille ou de fond.

**Preuve.** K/LibraryActivity.kt:129 « view.setOnClickListener { SiddurLectureActivity.ouvrirLivre(this@LibraryActivity, texte.id) } » ; K/SiddurLectureActivity.kt:317-318 « debuts.forEachIndexed { i, position -> rang.addView(TextView(this).apply { » (appelé par afficher() à chaque réglage) ; K/IndicateurDefilement.kt:17 « il ne prend aucun toucher ». Données : RAW/livre_likoutei_moharan.json 411 sections, RAW/livre_yalkut_yosef_kitsour.json 1 048 sections.

**Correction proposée.** Pour un livre : ouvrir d'abord (ou proposer par un bouton « Chapitres ») une liste verticale des chapitres avec filtre par numéro ou par mot, qui mène au chapitre par allerA ; au-delà d'une quarantaine de sections, remplacer la bande par ce bouton. Rendre l'indicateur de défilement saisissable.

**Note du contre-expert.** Les livres ne s'ouvrent que par ouvrirLivre (LibraryActivity:129, recherche, favoris). bande() ajoute une pastille par titre de section (SiddurJour.kt:125, SiddurLectureActivity.kt:317) et se reconstruit à chaque afficher(). Il n'y a ni liste des chapitres ni fastScroll dans les layouts, et IndicateurDefilement est non cliquable (isClickable=false). J'ai vérifié 411 et 1 048 sections dans les données.

### FLECTURE-04 — Tehilim : le psaume en cours est perdu dès que l'écran se recrée (rotation, choix des langues, passage au thème sombre)

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** TehilimLectureActivity ne retient le psaume affiché que dans une variable relue de l'intent : après « Psaume suivant », toute recréation de l'activité ramène au psaume d'origine (ou au verset du marque-page d'ouverture). Or le bouton « אA » de la barre de lecture recrée lui-même l'activité, comme la rotation (aucun écran de lecture n'est verrouillé en portrait) ou la bascule automatique clair/sombre. Même cause, autres pertes : Tikoun, Tehilim et sources retrouvent le même décalage en pixels dans un texte dont la hauteur a doublé (hébreu → hébreu + français), donc un autre passage, contrairement au commentaire ; le siddour ouvert depuis un marque-page y retourne ; les ajouts dépliés se referment ; la recherche globale perd sa saisie, ses résultats et son filtre (champ sans identifiant).

**Preuve.** K/TehilimLectureActivity.kt:33-35 « portion = Portion( debut = intent.getIntExtra(DEBUT, 1)… » et :40 « afficher(Portion(portion.debut + 1, portion.debut + 1)) », aucun onSaveInstanceState dans le fichier ; K/ReglagesLecture.kt:271-272 « // Le texte lui-même change : l'écran se refait (il garde sa place de défilement). (contexte as? Activity)?.recreate() » ; K/SiddurLectureActivity.kt:90-91 (MARQUE relu à chaque onCreate) et :52 « private val ouverts = mutableSetOf&lt;String>() » ; K/RechercheActivity.kt:35 « addView(EditText(context).apply { » sans id ; AndroidManifest.xml : ni configChanges ni screenOrientation sur ces activités.

**Correction proposée.** TehilimLectureActivity : onSaveInstanceState (début, fin, versets, premier verset visible) et restauration avant afficher. Pour le choix des langues, redessiner sur place au lieu de recreate(), ou mémoriser un repère (psaume/verset, indice de paragraphe) et y revenir. Ne suivre MARQUE que si savedInstanceState == null ; sauver « ouverts » ; donner un id au champ de recherche et sauver la portée.

**Note du contre-expert.** TehilimLectureActivity relit DEBUT/FIN dans l'intent à chaque onCreate et n'a pas d'onSaveInstanceState. choisirLangues appelle recreate() (ReglagesLecture.kt:271-272), et le manifeste ne déclare ni configChanges ni screenOrientation pour ces activités. Le reste est exact aussi : les ScrollView à id restaurent leur scrollY en pixels, MARQUE est relu à chaque onCreate, « ouverts » n'est pas sauvé, et l'EditText de RechercheActivity n'a pas d'id tandis que les chips reçoivent un generateViewId() nouveau à chaque création.

### FLECTURE-05 — Un résultat « Ben Ish 'Haï » de la recherche mène à un écran qui ne le contient pas

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** La recherche globale interroge toujours les deux livres de halakha. Le toucher d'un résultat ouvre l'écran Halakha avec le mot recherché, mais cet écran ne cherche que dans le livre choisi dans ses réglages, qui est par défaut le Yalkut Yosef seul. Exemple calculé sur les données : « מזוזה » donne 26 résultats Ben Ish 'Haï et 2 Yalkut Yosef ; en touchant l'un des 26, on arrive sur « Résultats : 2 », sans la halakha touchée.

**Preuve.** K/RechercheGlobale.kt:68 « if (Sorte.HALAKHA in s) benIshHai?.let { b -> addAll(Halakha.recherche(b, texte).take(PAR_SORTE)… » ; K/RechercheActivity.kt:121 « startActivity(Intent(context, HalakhaActivity::class.java).putExtra(EXTRA_RECHERCHE, r.id)) » ; K/HalakhaActivity.kt:122 « val trouves = if (source.benIshHai) Halakha.recherche(livre, recherche) else emptyList() » ; K/Store.kt:832 « … ?: SourceHalakha.YALKUT ».

**Correction proposée.** Quand HalakhaActivity est ouverte avec EXTRA_RECHERCHE, chercher dans les deux livres (ou passer le livre du résultat dans l'intent et l'afficher en tête) ; à défaut, limiter la recherche globale au livre choisi.

**Note du contre-expert.** RechercheGlobale.kt:67-68 interroge toujours les deux livres. HalakhaActivity.remplir() (l.121-122) filtre selon Store.sourceHalakha, qui vaut YALKUT par défaut (Store.kt:832). J'ai recalculé « מזוזה » sur yalkut_yosef.json et ben_ish_hai.json : 2 résultats Yalkut Yosef et 26 Ben Ish 'Haï, comme annoncé. L'utilisateur peut changer de livre sur l'écran, mais le résultat touché n'y figure pas tant qu'il ne l'a pas fait.

### FLECTURE-06 — Likoutei Moharan (10,1 Mo) et Yalkut Yosef (11,2 Mo) lus et analysés sur le fil principal à l'ouverture, puis gardés en mémoire sans limite

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : android · **Type** : fonction

**Constat.** Le découpage du 04/11 a fait un fichier par livre, pas par chapitre : ouvrir Likoutei Moharan lit 10,1 Mo et construit 7 057 paragraphes dans onCreate, sur le fil de l'interface, sans indicateur. Mesuré sur une JVM de bureau, à froid : 72 ms de lecture + 202 ms d'analyse (Yalkut Yosef : 74 + 228 ms), 53 Mo de tas occupés pendant l'analyse, 20 Mo gardés ensuite par livre. Un téléphone d'entrée de gamme étant plusieurs fois plus lent, l'écran reste figé une à plusieurs secondes à la première ouverture (non mesuré sur appareil). Chaque livre ouvert reste ensuite en mémoire jusqu'à la mort du processus ; après une recherche globale, les douze y sont (environ 50 Mo), sans onTrimMemory.

**Preuve.** K/SiddurLectureActivity.kt:189 « private fun recueil(): Siddur = if (livre) Data.livre(this, id) ?: … », appelé par afficher() depuis onCreate (:88) ; K/ChizukCard.kt:232 « return SiddurLoader.parse(Json.readRaw(context.applicationContext, brut)).also { livresLus[id] = it } » et :216 « private val livresLus = java.util.concurrent.ConcurrentHashMap&lt;String, Siddur>() » ; K/Json.kt:43 « openRawResource(id).bufferedReader().use { it.readText() } ». Mesures : Bench4.java sous OUT/flecture/v2. FEUILLE_DE_ROUTE.md:1044 ne citait que « livres.json (6,9 Mo) à découper si l'ouverture est lente ».

**Correction proposée.** Charger le livre hors du fil principal (exécuteur + indicateur « Chargement… »), puis afficher. Mieux : un fichier par chapitre (ou par dizaine) et un index, pour ne lire que ce qu'on ouvre. Borner le cache à un ou deux livres et le vider dans onTrimMemory.

**Note du contre-expert.** Data.livre est appelé de façon synchrone depuis onCreate → afficher() → recueil(). Le cache livresLus est sans borne, et il n'existe ni onTrimMemory ni onLowMemory. J'ai relancé Bench4 : 107 + 244 ms avec JIT et environ 4,9 s en interprété sur ce poste ; les chaînes retenues font à peu près 16 Mo pour Likoutei Moharan, 15 Mo pour le Yalkut Yosef et 40 Mo pour les douze livres. Les « 20 Mo par livre » ne valent que pour ces deux gros livres, et le temps sur téléphone reste une estimation.

### FLECTURE-07 — Recherche globale : 9,5 millions de caractères re-normalisés à chaque frappe, sans annulation ni indicateur

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : android · **Type** : fonction

**Constat.** Chaque requête repasse nu() (NFD + 5 expressions régulières recompilées à chaque appel) sur tous les paragraphes, jusqu'à 27 615. Sur JVM de bureau : 765 ms pour charger les douze livres à la première recherche, puis environ 550 ms par requête sans résultat (375 ms pour « התבודדות »). Sur téléphone, compter plusieurs secondes par requête (non mesuré sur appareil). Les requêtes ne s'annulent pas : l'exécuteur à un fil traite l'une après l'autre toutes celles lancées à plus de 300 ms d'intervalle, et l'écran reste vide sans dire qu'il cherche. Les livres sont chargés même quand le filtre est « Hilloulot » ou « Halakhot ». Avec un index normalisé une fois (555 ms), la même requête prend 8 ms.

**Preuve.** K/RechercheGlobale.kt:21 « fun nu(t: String): String = java.text.Normalizer.normalize(t, …).replace(Regex("[̀-ͯ’‘]"), "").replace(Regex("<[^>]+>"), " ")… » ; K/RechercheActivity.kt:86-88 « fil.execute { val r = runCatching { RechercheGlobale.chercher(texte, langue, Data.siddur(c), Data.livres(c), YalkutYosef.livre(c), Halakha.livre(c), Hilloulot.table(c), ou) » (arguments évalués quelle que soit la portée ; le contrôle « n != demande » n'a lieu qu'avant execute et à l'affichage). Mesures : Bench2.java sous OUT/flecture/v2.

**Correction proposée (revue par le contre-expert).** Garder par livre la liste des paragraphes déjà normalisés, calculée une fois hors du fil principal ; sortir les Regex en constantes ; vérifier « n != demande » dans la boucle pour abandonner une requête dépassée ; ne charger les livres que si la portée les inclut ; au lancement de chaque requête, vider la liste ou y afficher « Recherche… », pour ne pas laisser croire que les résultats précédents répondent à la nouvelle saisie.

**Note du contre-expert.** Le cœur du constat est exact. nu() compile ses Regex à chaque appel, une tâche déjà confiée à l'exécuteur n'est jamais annulée (le contrôle n != demande n'a lieu qu'avant execute et à l'affichage), et les cinq sources sont évaluées quelle que soit la portée, mais à la première recherche seulement puisqu'elles restent ensuite en cache. J'ai relancé Bench2 : 0,46 à 0,85 s par requête, puis 8 ms une fois l'index normalisé. Correction : l'écran n'est vide qu'à la première recherche ; ensuite, ce sont les résultats de la requête précédente qui restent affichés, sans aucun signe qu'une recherche est en cours, ce qui est plus trompeur.

### FLECTURE-08 — Marque-page impossible sur 21 à 27 paragraphes du siddour (Amida, Kaddich), sans aucun message

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Hors des dix jours de pénitence, les paragraphes qui contiennent une variante (« בעשי״ת… », « מוריד הטל / משיב הרוח ») sont remplacés à l'affichage par une copie sans la variante. La table des places est indexée par identité d'objet : la copie n'y est pas. L'appui long ne fait donc rien (ni marque, ni message) sur ces paragraphes : 26 en Edot (dont la 1re bénédiction de la Amida, « מכלכל חיים », « אתה קדוש »), 21 en Sefard, 27 en Ashkenaz ; 4 paragraphes Edot et 1 Sefard ne sont jamais marquables. Un marque-page posé pendant les dix jours n'est plus dessiné ensuite, et son ouverture retombe sur le début de la section.

**Preuve.** K/SiddurJour.kt:151-152 « val reduit = horsJour.fold(bloc.texte) { t, v -> t.replaceFirst(v.retire!!, "") }.trim() / if (reduit != bloc.texte) bloc = bloc.copy(texte = reduit) » ; K/SiddurLectureActivity.kt:262-263 « places = java.util.IdentityHashMap&lt;SiddurBloc, Pair&lt;Int, Int>>().apply { texte.sections.forEachIndexed { si, s -> s.blocs.forEachIndexed { bi, b -> put(b, si to bi) } } » ; :136 « val (si, bi) = places[bloc] ?: return ». Comptage sur RAW/siddur_annotations.json (indices avec « retire » présents dans le bloc).

**Correction proposée.** Porter la place dans la ligne : Ligne.Bloc(bloc, style, section, indice), rempli dans SiddurJour.lignes, et s'en servir dans marquee, basculerMarque et allerA à la place de la table par identité. Ajouter le cas à SiddurJourTest.

### FLECTURE-09 — Les marque-pages posés dans un autre noussa'h sont listés et s'ouvrent sur un mauvais paragraphe

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Un marque-page du siddour retient son noussa'h, car les paragraphes diffèrent. La feuille « Marque-pages » (accueil, siddour) liste pourtant ceux de tous les noussa'h, et l'ouverture ne transmet que « section:paragraphe » : après un changement de noussa'h, la ligne montre l'aperçu de l'ancien texte et conduit, dans le texte courant, à un autre paragraphe (ou au début de la section). Dans la lecture, ce marque-page n'est ni dessiné ni listé, et le compteur « Marque-pages · n » ne correspond pas à ce que le texte montre.

**Preuve.** K/RepriseFavoris.kt:42 « val marques = Store.marques(c).filter { (recueil == null || it.cle.startsWith("$recueil:")) && titre(c, it.cle) != null } » (aucun filtre sur it.nusah) ; K/SiddurLectureActivity.kt:695-696 « Intent(context, SiddurLectureActivity::class.java).putExtra(ID, m.cle.substringAfter(':')).putExtra(MARQUE, "${m.section}:${m.bloc}") » ; :132 « MarquesPages.duTexte(Store.marques(this), cle(), nusahMarques()) ».

**Correction proposée.** Dans la feuille, ne garder que les marque-pages du noussa'h courant (et ceux des livres), ou afficher le noussa'h sur la ligne et ouvrir la lecture dans ce noussa'h (extra supplémentaire).

### FLECTURE-10 — Marque-pages repérés par numéros de section et de paragraphe, sans contrôle : faux sans le dire après une mise à jour des textes, et impossibles à supprimer depuis la liste

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Un marque-page est (texte, noussa'h, section, paragraphe) plus un aperçu qui ne sert qu'à l'affichage. Si une mise à jour ajoute, retire ou déplace un paragraphe (les textes changent encore : ordre des Sheva Berakhot à revoir, découpes), le marque-page désigne un autre paragraphe pendant que la liste montre l'ancien aperçu. Les annotations du siddour ont une « empreinte » pour ce cas ; les marque-pages n'en font rien. Par ailleurs : on ne retire un marque-page qu'en retrouvant le paragraphe et en le pressant longuement, aucune suppression depuis la liste ; un marque-page dont le texte a disparu est masqué mais compte toujours dans le plafond de 60 ; au-delà de 60, les plus anciens tombent sans avertissement.

**Preuve.** K/MarquesPages.kt:15 « data class Marque(val cle: String, val nusah: String, val section: Int, val bloc: Int, val apercu: String) » et :21 « const val MAX = 60 » ; K/SiddurLectureActivity.kt:145-146 « val i = lignesAffichees.indexOfFirst { it is SiddurJour.Ligne.Bloc && places[it.bloc] == (si to bi) } / val repli = if (i >= 0) i else lignesAffichees.indexOfFirst { … >= si } » (l'aperçu n'est jamais comparé) ; K/SiddurJour.kt:24 « Le début du texte annoté, pour vérifier qu'il n'a pas bougé. »

**Correction proposée.** À l'ouverture, comparer MarquesPages.apercu(bloc.texte) à m.apercu ; s'ils diffèrent, chercher le paragraphe de même aperçu dans la section puis dans le texte, le recaler, sinon l'annoncer et proposer de le retirer. Ajouter un retrait depuis la liste (appui long ou croix) et un message quand le plafond fait tomber un ancien.

### FLECTURE-11 — Barre de lecture : la lune et « אA » n'ont aucun effet sur Halakha et Hilloulot, « אA » aucun dans le siddour

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** La barre pose toujours les mêmes boutons. Sur Halakha et Hilloulot, l'écran ne se redessine qu'en taille et en police : toucher la lune change le réglage global (le bouton s'allume, le siddour sera noir à la prochaine ouverture) sans rien changer à l'écran ; choisir une langue recrée l'écran à l'identique et efface le champ de recherche. Dans le siddour, où aucun paragraphe n'est traduit (0 dans les trois noussa'h), le menu des six langues recrée l'écran, referme les ajouts dépliés, et ne dit rien : l'avis « pas encore de traduction » n'est affiché que pour un livre.

**Preuve.** K/ReglagesLecture.kt:116-127 (lune) et :139-150 (« אA ») ajoutés sans condition ; K/HalakhaActivity.kt:80 « ReglagesLecture.installer(this, findViewById(R.id.halakha_defile)) { afficher() } » et :111-114 « private fun afficher() { remplir() ReglagesLecture.retailler(liste) } » (idem K/HilloulotActivity.kt:88, 119-122 ; ni rendu ni LanguesTexte dans ces deux fichiers) ; K/SiddurLectureActivity.kt:254 « val sansTraduction = if (livre && LanguesTexte.manque(langues, traduit)) … ».

**Correction proposée.** Ajouter à ReglagesLecture.installer deux options (avecNuit, avecLangues) et les couper pour Halakha et Hilloulot tant que ces écrans n'appliquent ni le fond noir ni les traductions ; dans le siddour, masquer « אA » ou afficher l'avis lecture_sans_traduction aussi pour une prière.

### FLECTURE-12 — Tikoun : « J'ai dit le Tikoun en entier » est sous le pouce dès la première ligne, sans confirmation ni retour possible

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Le bouton n'est pas à la fin du texte : il est fixe sous la zone de défilement, visible dès l'ouverture, juste sous la pastille « Aa ». Un toucher involontaire marque les dix psaumes, inscrit le jour au journal du Tikoun (trophées) et ferme l'écran. Rien ne permet de corriger : setTikkunDone n'est plus jamais appelé avec false. La progression psaume par psaume a disparu avec la liste (04/11) : le commentaire qui la promet est faux, et la chaîne « Tehilim dits aujourd'hui : n sur 10 » ne peut plus s'afficher. Aucune reprise non plus : après un Retour au 8e psaume, on repart du début.

**Preuve.** A/res/layout/activity_tikkun_flow.xml : « &lt;Button android:id="@+id/flow_done" … » placé après &lt;/ScrollView> ; K/TikkunFlowActivity.kt:103-106 « setOnClickListener { tikkun.psaumes.forEach { Store.setTikkunDone(this@TikkunFlowActivity, it.numero, true) } finish() } » (seul appel de setTikkunDone dans K) ; K/Store.kt:1418-1420 « la progression est gardee pour qu'un appel ou un enfant ne renvoie pas au premier psaume » ; A/res/values/strings.xml:448 tikkun_progress.

**Correction proposée.** Mettre le bouton à la fin du contenu (dernier enfant de flow_content, après la prière de Rabbi Natan) ou n'activer le bouton fixe qu'une fois les versets de clôture atteints ; après le toucher, une barre « Tikoun noté pour aujourd'hui — Annuler » qui rappelle setTikkunDone(…, false). Garder la place de défilement du jour. Retirer tikkun_progress et corriger le commentaire de Store.

### FLECTURE-13 — Reprise de lecture : absente pour les Tehilim et le Tikoun, approximative ailleurs

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** La feuille de route annonce « Favoris (étoile) et reprise de lecture à la place laissée : oui ». Seul le lecteur du siddour et des livres le fait. Les Tehilim (portion de la semaine : 323 à 393 versets) et le Tikoun n'enregistrent rien : un Retour, et l'on repart du premier verset ; ni étoile ni « Reprendre » pour eux. Dans le siddour, la place gardée est un indice de ligne affichée : elle compte les ajouts dépliés, qui sont refermés à la réouverture (on atterrit plus loin que là où l'on était), et la reprise se fait toujours en haut du paragraphe (jusqu'à 8 257 caractères dans Kokhvei Or). La ligne d'accueil « Reprendre la lecture » reste affichée pour une prière de la veille, qu'elle ouvre au début.

**Preuve.** FEUILLE_DE_ROUTE.md:1000 ; K/TehilimLectureActivity.kt et K/TikkunFlowActivity.kt : aucun onPause ni appel à Store.setPositionLecture ; K/SiddurLectureActivity.kt:162-163 « val p = (liste.layoutManager as LinearLayoutManager).findFirstVisibleItemPosition() / if (p >= 0) Store.setPositionLecture(this, cle(), p, pauseA) » et :92 « scrollToPositionWithOffset(p, 0) » ; K/RepriseFavoris.kt:33.

**Correction proposée.** Tehilim : enregistrer (portion, psaume, verset en haut de l'écran) dans onPause et proposer « Reprendre : Tehilim 23, verset 4 ». Tikoun : garder la place pour le jour (jourTikkun). Siddour : enregistrer (section, paragraphe) et le décalage en pixels plutôt que l'indice de ligne. N'afficher « Reprendre » que si la reprise est encore valable.

### FLECTURE-14 — Tehilim avec traduction : un millier de vues reconstruites à chaque réglage et à chaque marque-page

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** En français et en anglais, le mode par défaut est hébreu + traduction : chaque verset devient un conteneur et deux textes, tous créés d'un coup dans une ScrollView (aucun recyclage). La portion du dimanche (Tehilim 1 à 29, 393 versets) fait environ 1 180 vues, celle du vendredi 1 130. Chaque toucher sur A−, A+, la lune, la police, et chaque marque-page posé ou retiré vide tout et reconstruit tout sur le fil principal. Saccade probable d'une demi-seconde à une seconde sur un téléphone moyen (non mesuré sur appareil).

**Preuve.** K/LanguesTexte.kt:30-33 (défaut HE_FR / HE_EN) ; K/TehilimLectureActivity.kt:97-98 « contenu.addView(if (mode == LanguesTexte.Mode.HE) texte(…) else texteTraduit(…)) », :88 « contenu.removeAllViews() », :42-43 (réglage → afficher(portion, garderPlace = true)), :248 (marque-page → afficher). Versets par portion de la semaine calculés sur RAW/tehilim.json : 393, 387, 352, 368, 323, 376, 328.

**Correction proposée.** Passer la lecture des Tehilim à une RecyclerView (une ligne par verset), comme le siddour ; à défaut, ne mettre à jour que le verset touché pour un marque-page et retailler les vues existantes (ReglagesLecture.appliquer) pour la taille et le fond.

### FLECTURE-15 — Les boutons marque-pages et favori disparaissent avec la banderole dès qu'on lit

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Dans le lecteur du siddour et des livres, les deux boutons (liste des marque-pages du texte, étoile) sont dans la banderole, qui s'efface après un défilement d'une hauteur et ne revient que tout en haut du texte. Au milieu de Cha'harit ou d'un livre, on ne peut ni sauter à un autre marque-page ni mettre le texte en favori sans remonter au début et perdre sa place.

**Preuve.** A/res/layout/activity_siddur_lecture.xml : siddur_lecture_marques et siddur_lecture_favori sont enfants du LinearLayout android:tag="bandeau" ; K/BandeauDefilant.kt:83-84 « if (descendu && !cache && decalage() > h + marge(defile) && reste(defile) > h + marge(defile)) { cache = true » et :88 « } else if (!descendu && cache) { » (retour seulement quand la liste ne peut plus remonter).

**Correction proposée.** Sortir ces deux boutons de la banderole : à l'extrémité de la bande de signets (qui reste visible) ou dans la barre « Aa » dépliée.

### FLECTURE-16 — Résultats coupés sans le dire : 40 + 40 cartes pour un total annoncé en entier (Halakha), compteur plafonné (recherche globale)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Écran Halakha : l'en-tête annonce le nombre total de halakhot trouvées, mais seules les 40 premières de chaque livre sont affichées, sans « suite » ni mention (« שבת » : 115 + 444 trouvées, 80 visibles). Recherche globale : chaque sorte est coupée à 30 et l'en-tête affiche la somme des listes coupées, qui passe pour le total. La recherche de l'écran Halakha tourne en outre sur le fil principal à chaque frappe, sans délai (2 002 halakhot du Ben Ish 'Haï renormalisées avec deux Regex recompilées par halakha ; 30 à 50 ms sur JVM de bureau), et reconstruit jusqu'à 80 cartes au texte sélectionnable.

**Preuve.** K/HalakhaActivity.kt:123-125 « getString(R.string.hilloulot_resultats, yy.size + trouves.size) … yy.take(40).forEach { … } trouves.take(40).forEach { … } » et :73 « override fun afterTextChanged(s: Editable?) { recherche = s?.toString().orEmpty(); afficher() } » ; K/RechercheGlobale.kt:15 « const val PAR_SORTE = 30 » ; K/RechercheActivity.kt:98 « getString(R.string.hilloulot_resultats, resultats.size) » ; K/Halakha.kt:111.

**Correction proposée.** Afficher « 80 premiers résultats sur 559 » et un bouton « Afficher la suite » ; dans la recherche globale, « 30 premiers » par groupe quand la liste est coupée. Écran Halakha : délai de 300 ms et calcul hors du fil principal, comme RechercheActivity.

### FLECTURE-17 — La recherche « globale » ignore les Tehilim, le Tikoun, les Likoutei Tefilot, les sources, le 'hizouk et toutes les traductions

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Seuls le siddour du noussa'h courant, les douze livres, les deux livres de halakha et les hilloulot sont interrogés, et dans les livres seul le champ hébreu. Un verset de Tehilim (2 527 versets), une prière de Rabbi Natan ou un texte de 'hizouk ne se trouvent pas. Un francophone qui tape « joie » obtient 0 résultat alors que 367 paragraphes traduits des livres contiennent le mot : en français et en anglais, la recherche ne trouve que des titres. Détail : nu() ne retire pas U+200D, présent dans 26 mots du siddour Edot (יְרוּשָׁלַ‍ִם) et 52 de Likoutei Moharan (עֲו‍ֹן), que la recherche ne trouve donc jamais.

**Preuve.** K/RechercheGlobale.kt:56-70 (paramètres : siddur, livres, yalkut, benIshHai, hilloulot ; ni Data.tehilim, ni Data.tikkun, ni Data.library, ni Data.chizuk) ; :35 « nu(it.texte).contains(q) » (jamais it.fr ni it.en) ; :21 (classe retirée : « [֑-ׇ\"'״׳] »). Comptages : scripts sur RAW/livre_*.json. PUBLICATION_PLAY_STORE.md:32 annonce « recherche globale ». La partie traductions est aussi relevée par l'audit de couverture.

**Correction proposée.** Ajouter les Tehilim (résultat « Tehilim 23, 4 », ouvert par ouvrirMarque), le Tikoun, la sous-section tefilot-lt et les sources de la bibliothèque ; chercher aussi dans fr et en selon la langue de l'interface ; retirer [‌-‏͏] dans nu().

### FLECTURE-18 — Dédicace : le texte ne dit pas ce que la demande produit ; « Autre intention » part sans intention ; la saisie se perd

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** La carte « Dédicace » explique le circuit (un e-mail à l'équipe) mais pas le résultat : rien n'indique ce que l'équipe fait du nom (mention quelque part, étude, prière, réponse ?), ni quand. Rien n'apparaît jamais dans l'application. L'utilisateur envoie le nom d'un défunt ou d'un malade sans savoir à quoi il s'engage. Trois défauts de saisie : avec « Autre intention », l'e-mail ne contient aucune intention (le seul champ libre est « Un mot pour l'équipe (facultatif) ») ; sans messagerie, un message de quelques secondes donne l'adresse puis la boîte se ferme et efface le nom et le mot ; la boîte disparaît aussi à la rotation.

**Preuve.** A/res/values/strings.xml:36 « Pour dédier votre hitbodedout ou votre étude, la demande passe par l’équipe MyHitbodedut. Elle s’écrit dans votre messagerie, adressée à myhitbodedut26@gmail.com : rien ne part sans vous. » ; K/Dedicace.kt:36 « AUTRE(R.string.dedicace_autre, null) » et :45 « add(listOfNotNull(formule, nom.trim()).joinToString(" ")) » ; :133-134 « if (!ouvert) Toast.makeText(activite, R.string.dedicace_sans_messagerie, Toast.LENGTH_LONG).show() / dialogue.dismiss() ».

**Correction proposée.** Réécrire section_dedicace_hint, la partie entre crochets étant à fixer par le propriétaire : « Vous pouvez demander à l’équipe MyHitbodedut de dédier votre hitbodedout ou votre étude à quelqu’un. [Ce que l’équipe fait du nom et sous quel délai.] Le message se prépare dans votre messagerie, adressé à myhitbodedut26@gmail.com : rien ne part sans vous, et l’application n’en garde rien. » Pour « Autre intention » : rendre le mot obligatoire avec l'indice « Précisez l’intention ». Sans messagerie : laisser la boîte ouverte, afficher l'adresse dans la boîte et copier le message dans le presse-papiers.

### FLECTURE-19 — Barre de lecture : des boutons de 30 dp de large sur un téléphone courant

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** La largeur des boutons est calculée en divisant la place par un bouton de trop (9 avec le noussa'h alors qu'il y en a 8 ; 8 sinon alors qu'il y en a 7). Sur un écran de 360 dp, dans le siddour : (360 − 102) / 9 = 28, relevé à 30 dp ; sur 411 dp : 34 dp. La hauteur est de 44 dp. Huit cibles serrées de 30 × 44 dp (A−, A+, lune, police, langues, noussa'h, masquer, replier), sous les 48 dp recommandés, avec « Masquer le bouton » collé à « Replier ».

**Preuve.** K/ReglagesLecture.kt:62-63 « val nombre = if (avecNusah) 9 else 8 / (((largeur - 24 - 48 - 18 - 12) / nombre).toInt()).coerceIn(30, 44) » ; boutons réellement créés aux lignes 103, 114, 116, 128, 139, 151, 153, 154 ; hauteur « dp(44) » (:117, :130, :141, :200, :211).

**Correction proposée.** Corriger le compte (8 et 7), porter la hauteur à 48 dp, et quand la largeur calculée passe sous 40 dp, mettre la barre sur deux rangs (taille en haut, le reste en bas) ou ranger « Masquer » et « Replier » dans un menu.

### FLECTURE-20 — Lien qui ne s'ouvre pas : le message parle d'un « écran de réglages »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : texte

**Constat.** Quand « Ouvrir sur Sefaria » ou « Lire sur le site » échoue (aucun navigateur), l'écran d'une source ou d'un article affiche une chaîne faite pour les réglages système.

**Preuve.** K/LibraryEntryActivity.kt:178-180 « runCatching { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }.onFailure { Toast.makeText(this, R.string.settings_screen_missing, Toast.LENGTH_LONG) » ; A/res/values/strings.xml:112 « Cet écran de réglages n’existe pas sur ce téléphone. »

**Correction proposée.** Nouvelle chaîne lien_impossible — FR : « Impossible d’ouvrir ce lien : aucun navigateur sur ce téléphone. » EN : « This link can’t be opened: no browser on this phone. » HE : « אי אפשר לפתוח את הקישור: אין דפדפן בטלפון הזה. » L'employer aussi dans HalakhaActivity.ouvrir, qui échoue en silence (K/HalakhaActivity.kt:187-188).

### FLECTURE-21 — TalkBack : poser un marque-page n'est pas annoncé, et dans les Tehilim en hébreu le verset marqué dépend du dernier toucher

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Le marque-page ne passe que par un appui long sans libellé d'action : TalkBack annonce un appui long générique, et un paragraphe marqué n'est signalé que par un trait et une icône, sans description. Dans les Tehilim en hébreu seul, tout le psaume est une seule vue et le verset est déduit des dernières coordonnées du doigt : déclenché par un lecteur d'écran ou un contacteur, l'appui long marque le verset du dernier toucher, ou le coin de la vue (coordonnées 0,0) s'il n'y en a pas eu.

**Preuve.** K/SiddurLectureActivity.kt:547 « setOnLongClickListener { basculerMarque(ligne.bloc); true } » (contentDescription remis à null à la ligne 455) ; K/TehilimLectureActivity.kt:170-174 « var x = 0f / var y = 0f / setOnTouchListener { _, e -> x = e.x; y = e.y; reglages?.toucher(e); false } / setOnLongClickListener { val o = getOffsetForPosition(x, y) ».

**Correction proposée.** ViewCompat.replaceAccessibilityAction(vue, ACTION_LONG_CLICK, « Poser un marque-page » / « Retirer le marque-page », null) et stateDescription « marqué » sur les paragraphes marqués ; pour les Tehilim, une vue par verset (voir le constat sur la RecyclerView) ou une action d'accessibilité par verset.

### FLECTURE-22 — 'Hizouk : le partage et les « Textes gardés » ignorent les langues de lecture choisies

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** La carte de 'hizouk suit le choix « אA » (par exemple l'anglais seul dans une interface en français). « Partager » envoie pourtant l'hébreu et la traduction de la langue de l'interface, et la liste « Textes gardés » affiche cette même langue : ce qui part n'est pas ce qui est à l'écran.

**Preuve.** K/ChizukCard.kt:51-53 « val mode = LanguesTexte.mode(card.context) / val textes = LanguesTexte.textes(mode, ChizukRules.hebrew(chizuk, item), item.fr.ifBlank { null }, item.en.ifBlank { null }) » ; K/ChizukActivity.kt:104-105 « ChizukRules.hebrew(Data.chizuk(this), item), ChizukCard.translationOf(item, ChizukCard.language(this)), » et :82.

**Correction proposée.** Dans partager() et rendreFavoris(), partir de LanguesTexte.textes(LanguesTexte.mode(this), …) : partager les textes affichés (l'hébreu toujours joint si l'on veut garder la source).

### FLECTURE-23 — Portion de Tehilim « du jour » : le jour hébreu change à minuit civil, pas à la sortie des étoiles

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction · déjà connu ou choix assumé

**Constat.** Choix écrit dans le code, mais qui contredit le reste de l'application depuis que la date hébraïque et les prières basculent à la tset (28/10, 04/11) : entre la sortie des étoiles et minuit, l'accueil affiche déjà le nouveau jour hébreu alors que les Tehilim annoncent « Jour N du mois » de la veille et sa portion ; le soir de Roch 'Hodech, on lit encore la fin du livre. La portion de la semaine garde de même celle du Chabbat jusqu'à minuit à la sortie de Chabbat.

**Preuve.** K/Tehilim.kt:102-104 « Le jour du mois hébraïque et la longueur de ce mois, pour la date civile : le jour change ici à minuit, pas au coucher du soleil. » ; K/TehilimActivity.kt:50-51 « val aujourdhui = LocalDate.now() / val (jour, longueur) = CycleTehilim.jourHebreu(aujourdhui) » ; à comparer à K/SiddurLectureActivity.kt:242-246 (apresSortie).

**Correction proposée.** Avec un lieu réglé, prendre le jour hébreu de JourAffiche (après la tset : celui de demain) pour la portion du mois, comme pour les prières ; sans lieu, garder minuit. Décision du propriétaire à inscrire dans la feuille de route.

### FLECTURE-24 — Police par défaut sans lettres accentuées : deux polices dans le même mot pour les intertitres français et les noms des résultats

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** La police hébraïque par défaut (Noto Serif Hebrew réduite) contient l'alphabet latin sans accents (A–Z, a–z) mais ni é è ê à ç î ô û œ ni « ». Là où elle est posée sur un texte français, Android prend les lettres accentuées dans la police du téléphone : « Prière », « véritable », « 'Haïm » mêlent empattements et bâtons. Touchés : les intertitres traduits des livres (185 des 823 titres français ont un accent), affichés par défaut en français, et les titres des résultats de recherche (86 des 179 noms français de hilloulot). Non vu sur appareil : déduit de la table des glyphes.

**Preuve.** Mesure fontTools sur A/res/font/hebreu_serif_regular.ttf : 247 glyphes, latin = ASCII seul. A/res/font/hebreu_serif.xml : « Réduite à l'hébreu vocalisé, à la ponctuation et aux chiffres. » ; K/SiddurLectureActivity.kt:479-487 (PoliceHebraique.appliquer(this) puis le titre traduit ajouté sans TypefaceSpan, alors que les paragraphes traduits en reçoivent un à la ligne 517) ; K/RechercheActivity.kt:114.

**Correction proposée.** Dans Ligne.Titre, poser TypefaceSpan("serif") sur les titres non hébreux, comme pour les paragraphes ; dans RechercheActivity, n'appliquer PoliceHebraique que si le titre contient de l'hébreu (test déjà écrit dans K/SiddurActivity.kt:225). Ou retirer les lettres latines du sous-ensemble de la police.

### FLECTURE-25 — « ‹  Marque-pages · 3 » : en français et en anglais, le chevron passe à gauche et pointe vers l'arrière

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Les lignes de reprise, de favoris et de marque-pages forcent le sens droite-à-gauche. C'est juste pour un titre hébreu ; pour le libellé « Marque-pages · n » (accueil, siddour, Tehilim, livres), le « › » final passe à gauche du texte et se retourne en « ‹ », ce qui se lit comme une flèche de retour. Vérifié par l'algorithme bidi d'Unicode.

**Preuve.** K/RepriseFavoris.kt:44 « return ligne(c, null, "${c.getString(R.string.marques_titre)} · ${marques.size}", "", … » ; :151-153 « text = "$titre  ›" / textSize = … / textDirection = View.TEXT_DIRECTION_RTL ». Calcul (python-bidi, base RTL) : 'Marque-pages · 3  ›' → '‹  Marque-pages · 3'.

**Correction proposée.** Remplacer le caractère « › » par le dessin ic_chevron en fin de ligne (setCompoundDrawablesRelative, déjà utilisé pour l'icône) et ne forcer TEXT_DIRECTION_RTL que si le titre contient de l'hébreu (sinon FIRST_STRONG).

### FLECTURE-26 — Lecture sur fond noir : dans les sources et les Tefilot, seule la carte du texte noircit

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : android · **Type** : fonction

**Constat.** Sur l'écran d'une source (dont les 21 prières de Rabbi Natan), la lune ne teinte que la carte des paragraphes : la page autour, la banderole et le bouton restent clairs. Un rectangle noir sur une page claire ne remplit pas l'office d'une lecture de nuit. Non vu sur appareil : lu dans le code.

**Preuve.** K/LibraryEntryActivity.kt:78-80 « ReglagesLecture.marquer(container, ReglagesLecture.Role.FOND) / ReglagesLecture.installer(this, defilement) { ReglagesLecture.appliquer(container) } / ReglagesLecture.appliquer(container) » (container = entry_paragraphs, la carte ; entry_scroll garde android:background="?attr/mhPaper").

**Correction proposée.** Marquer aussi entry_scroll en Role.FOND et appliquer sur lui (ReglagesLecture.appliquer(defilement)), comme le fait TikkunFlowActivity (K/TikkunFlowActivity.kt:96-99).
