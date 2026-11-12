# FWEBLIVE — Web — essai réel du site construit

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

15 constats — confirmés en partie : 2 · confirmés : 3 · non contre-expertisés (mineurs et cosmétiques) : 10.

## Ce qui a été examiné

J’ai servi le site construit myhitbodedut-web (version 10227679bb4f, construit depuis c9dffcb ; aucun écart dans web/ ni dans les chaînes jusqu’à HEAD) sur 127.0.0.1:8765, puis je l’ai arrêté. Je l’ai piloté avec Playwright 1.63 sous Chromium : WebKit n’est pas installé et je n’ai eu aucun iPhone réel. Scripts, journaux et captures sont dans OUT/web-live/v2/ ; j’ai réutilisé en les relançant les scripts routes.mjs, toucher.mjs et horsligne.mjs de l’auditeur précédent, et corrigé son amorçage, qui réécrasait l’état à chaque nouvel onglet.
Fait en entier :
- premier lancement réel, langue tirée du navigateur, en fr, en et he à 390×844, et en fr à 320×568 ;
- balayage des 45 routes et états (accueil, séance avant, pendant, guidée, blocage, sans durée, confirmations, bravo, abandon, note, Tehilim, psaume, siddour, prière, Tikkoun et ses anciennes adresses, bibliothèque, livres, zmanim avec et sans lieu, vol, boussole, calendrier, paliers, hilloulot, halakha, recherche, ’hizouk, parcours, journal, conseils, tefilot, réglages, musique), en 3 langues sur iPhone et en français à 320 px ;
- « toucher chaque bouton » en 3 langues, à deux niveaux (feuilles comprises) ;
- séance avec horloge accélérée : démarrer, accueil pendant la séance, rechargement, terme, bravo, note, séance sans durée, terminer, abandonner, onglet rouvert après le terme ;
- hors ligne après installation du service worker ;
- export, aller-retour, 7 fichiers piégés à l’import, réinitialisation avec un morceau ajouté ;
- contrastes (20 écrans × 4 thèmes), noms accessibles (20 écrans × 2 langues), flèches rtl, bilan de la semaine, « sans le téléphone », liens profonds suivis du retour.
Échantillonné : ’hizouk, 30 tirages par langue et 12 ouvertures à froid ; mode sombre, 8 écrans ; grand texte à 320 px, 4 écrans ; vol, un vol décrit en texte libre ; recherche, 6 requêtes. Le toucher garde au plus 5 éléments d’une série de plus de 40 boutons semblables (Tehilim : 8 touchés sur 153, Musique : 23 sur 173).
Non examiné ou simulé :
- pause et reprise : la séance web n’a pas de pause (seulement Terminer et Abandonner), et le lecteur de musique n’a été touché que via le test des boutons ;
- simulés : la feuille de partage et le presse-papiers, la géolocalisation (refusée), le capteur de la boussole (« Activer la boussole » sans effet sous Chromium, artefact) et adsbdb (réponse simulée) ;
- non examinés : le mode autonome navigator.standalone (export par la feuille de partage), la mise à jour du service worker en place, la lecture audio réelle, le son des ambiances et Safari / iOS en vrai.
Une recherche web a confirmé le vote de l’ONU de septembre 2026 sur la projection Equal Earth, cité dans la note de la boussole : ce n’est pas une erreur.

## Ce qui tient

- Aucune erreur console, aucune exception de page, aucun 404 ni requête hors du site, sur 45 états × 3 langues (iPhone) et 45 états en français à 320 px. Il en va de même pendant le test « toucher chaque bouton », mené à son terme (35 écrans, 470 touchers et 245 dans les feuilles ouvertes, par langue). Seuls les liens ouverts par l’utilisateur (chabad.org, halachayomit, hyomi) sortent du site.
- Hors ligne : la coquille (172 fichiers, 47,5 Mo, tous les fichiers du site hors musique) s’installe à la première visite. Après coupure du réseau et rechargement, les 21 écrans, une prière, Likoutei Moharan et une biographie s’ouvrent sans erreur.
- Séance robuste : le décompte reste juste après un rechargement. Un onglet fermé puis rouvert 20 minutes plus tard inscrit 5 minutes (la durée prévue, pas le temps écoulé) et montre le bravo. La séance sans durée compte juste (12 min). L’abandon n’inscrit rien, et chaque fin passe par une confirmation claire.
- Import défensif : fichier vide, non-JSON, tableau, autre format et fichier de plus de 2 Mo sont refusés avec le bon message. Les dates futures ou invalides sont ignorées, les minutes bornées à 24 h, et le HTML injecté dans le prénom ou une note s’affiche comme du texte.
- Hébreu soigné : sens rtl complet, flèches de navigation inversées (précédent à droite), chevrons et nombres isolés. Les contrastes mesurés sont au moins de 4,4:1 en clair, sombre, sable et contraste, et chaque contrôle porte un nom accessible.
- Premier lancement en 7 étapes dans les trois langues, langue tirée du navigateur, sans débordement même à 320 px (la page défile quand il le faut). La durée et la forme d’adresse choisies sont bien enregistrées.

## Constats

### FWEBLIVE-01 — Livres : des balises &lt;b> brutes s’affichent dans 1 770 paragraphes traduits (fr et en)

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : web · **Type** : fonction

**Constat.** Dans l’écran de lecture d’un livre, l’hébreu passe par riche() qui interprète &lt;b>, mais la traduction est posée en texte brut par paraTraduction. Les balises s’affichent donc telles quelles (« &lt;b>Les cieux&lt;/b> disent : … »). Sont touchés 7 livres, avec le même nombre de paragraphes en fr et en en : Yalkout Yossef Kitsour (1 489), Perek Chira (86), Likoutei Moharan (75), Guide de la hitbodedout (63), Tefila LiChlomo (35), Likoutei Etsot (13) et Nichmat (9).

**Preuve.** Route #livres > פרק שירה, fr, iPhone 390×844 : OUT/web-live/v2/balises/fr-פרקשירה.png (« &lt;b>Les cieux&lt;/b> disent », « &lt;b>La terre&lt;/b> dit »). L’innerHTML mesuré vaut « &lt;b&gt;Les cieux&lt;/b&gt; ». En anglais, Yalkut Yosef montre « &lt;b>1&lt;/b> We learned in tractate Avot » (59 paragraphes sur 59 dans le premier chapitre ouvert). Code : web/src/js/app.js:796 `const paraTraduction = (langue, texte, seule) => h('p', {...}, texte);` face à app.js:1400 `riche(... aerer(texte ?? b.t))` pour l’hébreu. Comptage sur myhitbodedut-web/data/livres/*.json.

**Correction proposée (revue par le contre-expert).** Web : `const paraTraduction = (langue, texte, seule) => h('p', {...}, riche(texte));` (riche traite déjà &lt;b>, &lt;small> et &lt;br>, et meteg ne touche pas le latin). Android : dans SiddurLectureActivity.kt (vers la ligne 515), remplacer `append(t)` par `append(Html.fromHtml(t, Html.FROM_HTML_MODE_LEGACY))`. Test : échouer dès que /<\/?(b|small|br)>/ apparaît dans le innerText d'un écran de lecture de livre, sur web comme sur Android.

**Note du contre-expert.** Le défaut est confirmé. paraTraduction (app.js:796) pose le texte brut, alors que l'hébreu passe par riche() (app.js:1400), et la capture fr-פרקשירה.png montre bien « &lt;b>Les cieux&lt;/b> ». Le comptage sur myhitbodedut-web/data/livres redonne exactement 1 770 paragraphes avec &lt;b> par langue. La portée est plus large que décrit : les traductions contiennent aussi 4 036 &lt;small> dans Yalkout Yossef et 32 &lt;br> dans Likoutei Etsot et Likoutei Moharan, soit 1 775 paragraphes balisés par langue. Android a le même défaut : SiddurLectureActivity.kt:515 fait append(t) en brut, sur les mêmes fichiers RAW livre_*.json.

### FWEBLIVE-02 — La note n’est pas proposée après une séance arrivée à son terme, ni après « Je l’ai faite sans le téléphone »

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : web · **Type** : fonction

**Constat.** Sur le web, la note ne suit le bravo qu’après « Terminer maintenant » : seul terminerMaintenant met noteApresBravo à vrai. Les autres cas n’ouvrent rien : la séance minutée qui va à son terme (le cas le plus courant), la séance close au retour dans l’application et la journée déclarée sans le téléphone. Sur Android, tout passe par SessionService.inscrire, puis setPendingCelebration(…, close.date), et CelebrationActivity ouvre NoteDialog au « Continuer ». La présentation web promet pourtant : « Après chaque hitbodedout, une note peut rejoindre votre journal. »

**Preuve.** Essai réel avec horloge accélérée (OUT/web-live/v2/seance.mjs), étape A7 « après bravo » : feuille = null en fr, en et he. Capture OUT/web-live/v2/seance/fr-A7-apres-bravo.png. Après « Terminer maintenant » (B5), la feuille « Note de la hitbodedout » s’ouvre bien. Code : app.js:4947-4951 (`if (cloreSeance({ avantTerme: true })) noteApresBravo = true;`), app.js:5213-5217 et app.js:4573-4576 (declarerHorsTelephone : setPendingCelebration sans note). Android : CelebrationActivity.kt:94-99 et SessionService.kt:402-406.

**Correction proposée (revue par le contre-expert).** Dans cloreSeance, à l'intérieur de `if (inscrite) { … }`, ajouter `noteApresBravo = true;`. Dans declarerHorsTelephone, quand `date === aujourdhui`, poser à la fois `dateNote = date;` et `noteApresBravo = true;`. Sans cela, ecrireNote(dateNote ?? today) reprendrait le jour d'une séance antérieure encore en mémoire. Mieux encore : garder la date avec la fête en attente, comme Android (setPendingCelebration(minutes, date)), pour qu'elle survive à un rechargement.

**Note du contre-expert.** Le code le confirme : seul terminerMaintenant (app.js:4947-4951) met noteApresBravo à vrai. Les autres clôtures n'ouvrent pas la note : le tic (app.js:5035), timeupdate (5052), rendre (5350) et declarerHorsTelephone (4569-4576). La capture fr-A7-apres-bravo.png revient sur l'écran de séance sans feuille. Android propose la note dans tous ces cas : setPendingCelebration(…, date) dans SessionService.kt:405 et MainActivity.kt:282, puis NoteDialog dans CelebrationActivity.kt:94-99. PLAN_DU_SITE.md annonce aussi « Continuer » → Note de la séance. Seul palliatif : le bouton « Écrire une note » de l'accueil.

### FWEBLIVE-03 — Paliers : l’écran s’ouvre défilé, sans titre ni bouton Retour

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : web · **Type** : fonction

**Constat.** À l’ouverture, ecranPaliers fait défiler la liste jusqu’à « Vous êtes ici » (scrollTop ≈ 1 962 px). L’écouteur global de défilement prend ce défilement programmé pour un geste et masque le bandeau (classe bandeau-cache). Le titre et le bouton Retour sortent de l’écran (−8 à 36 px), sous le dessin d’un trophée. L’utilisateur arrive sans moyen visible de revenir, sauf à remonter de 2 000 px. Une PWA lancée depuis l’écran d’accueil de l’iPhone n’a pas de bouton retour de navigateur.

**Preuve.** Route #paliers en fr et he, iPhone 390×844 : scroll 1962, bandeau-cache true, retour [-8,36], élément au point central = &lt;path> (OUT/web-live/v2/paliers.mjs). Capture OUT/web-live/v2/paliers/fr-2500.png. Le test « toucher chaque bouton » échoue en fr, en et he sur « Retour » / « Back » / « חזרה » (« clic impossible … hors écran », OUT/web-live/v2/toucher-*.log). Code : app.js:4148 `d.scrollTop = Math.max(0, ici.offsetTop - d.clientHeight / 3)` et app.js:5516-5523 (masquage dès scrollTop > 8).

**Correction proposée (revue par le contre-expert).** Avant `d.scrollTop = …` (app.js:4148), poser `d.dataset.defilementAuto = '1'`. Dans l'écouteur de app.js:5516, faire `if (d.dataset.defilementAuto) { delete d.dataset.defilementAuto; return; }`, et effacer aussi ce drapeau au premier touchstart ou wheel. Ne pas se contenter de retirer bandeau-cache juste après l'écriture : l'événement scroll arrive plus tard et la remet.

**Note du contre-expert.** J'ai relancé l'essai sur le port 8797 et retrouvé les mêmes valeurs : scroll 1962, bandeau-cache vrai, Retour [-8,36], clic impossible, en fr comme en he. Le bandeau est même masqué avec un journal vide (scroll 211), avec 1 jour (388) et avec 3 jours (604) : tous les utilisateurs arrivent donc sans titre ni Retour, et l'écran Paliers n'a pas d'onglets. Le Retour n'est pas exactement « hors écran » : il est rendu invisible et inactif par .bandeau-cache (opacity 0, max-height 0, pointer-events none, app.css:1068). La seconde solution proposée ne marche pas : l'événement scroll part après l'écriture de scrollTop et remettrait aussitôt la classe.

### FWEBLIVE-05 — « Réinitialiser l’application » laisse les morceaux ajoutés, contrairement au texte (« efface tout »)

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : web · **Type** : fonction

**Constat.** La réinitialisation n’efface que les deux clés localStorage. Les morceaux que l’utilisateur a ajoutés sont des copies de ses fichiers audio, gardées dans IndexedDB « myhitbodedut-musique ». Ils restent et réapparaissent dans la bibliothèque musicale après la présentation. Or le texte affiché promet « Efface tout ce que l’application garde sur ce téléphone ».

**Preuve.** OUT/web-live/v2/reinit.mjs, fr, iPhone. Avant : IndexedDB ["mon-morceau"]. Après réinitialisation : localStorage vidé, présentation 1/7 affichée, mais IndexedDB ["mon-morceau"] et morceau toujours listé sur #musique (OUT/web-live/v2/donnees/fr-musique-apres-reinit.png). Code : web/src/js/store.js:124 `reinitialiser: () => { … removeItem(PREFS); removeItem(PREFS_JOURNAL); }` et app.js:4349-4352.

**Correction proposée (revue par le contre-expert).** Ajouter dans morceaux-perso.js une fonction `efface()`. Elle ferme la connexion gardée (`(await base)?.close(); base = null;`), puis attend le onsuccess, ou le onblocked, de `indexedDB.deleteDatabase('myhitbodedut-musique')`. Dans le onConfirme de app.js:4349, faire `await efface(); sessionStorage.clear();` avant location.replace. caches.delete('musique-2') est facultatif : ce cache ne contient que les niggounim fournis par l'application, pas des données de l'utilisateur.

**Note du contre-expert.** J'ai relancé l'essai sur le port 8797. Avant : IndexedDB ["mon-morceau"]. Après la réinitialisation : journal null, présentation affichée, mais IndexedDB toujours ["mon-morceau"] et le morceau encore listé sur #musique. store.reinitialiser (store.js:124) n'efface que les deux clés localStorage, alors que reset_hint promet « Efface tout ce que l'application garde sur ce téléphone ». Sous Chromium, j'ai vérifié qu'un deleteDatabase suivi aussitôt de location.replace vide bien la base, même avec la connexion gardée ouverte par morceaux-perso.js. Je n'ai pas pu vérifier sous WebKit (non installé).

### FWEBLIVE-04 — Texte du ’hizouk coupé sans ellipse : l’ajustement est mesuré avant le chargement de la police hébraïque

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : web · **Type** : fonction

**Constat.** ajusteLesTextes réduit la taille des cartes de ’hizouk (hauteur fixe, overflow hidden) au moment du rendu. La police « Hebreu Serif » se charge ensuite (font-display: swap), et rien ne relance l’ajustement. La fin du texte hébreu, ou celle de la traduction, est alors cachée sans aucun signe. Le cas se produit à l’ouverture à froid de « J’ai besoin de ’hizouk », sur l’écran de séance et sur l’abandon. À 320 px, le texte est en plus réduit vers 9-10 px.

**Preuve.** 12 ouvertures à froid de #hizouk (OUT/web-live/v2/hizouk-froid.mjs) : 3 cartes coupées. Exemple he, iPhone : « chizuk-he ajuste 16px 173>150 », police chargée (document.fonts.status = loaded), dernier mot « כך! » invisible. Capture OUT/web-live/v2/hizouk/froid-hizouk-0-he-2.png. Exemple en, 14px 170>150 : « וכו’ וכו’. » caché (froid-hizouk-0-en-4.png). Route bravo-abandon, fr, 320×568 : traduction coupée « la porte d’un vestibule » (76>72), OUT/web-live/v2/routes/bravo-abandon-fr-petit-1.png. Code : app.js:4701-4711 (aucun appel après document.fonts), app.css:14 (font-display: swap) et app.css:416-419 (hauteurs fixes, overflow hidden).

**Correction proposée (revue par le contre-expert).** 1) Relancer l'ajustement après chargement des polices : `document.fonts?.ready.then(ajusteLesTextes); document.fonts?.addEventListener?.('loadingdone', ajusteLesTextes);`. Ajouter aussi un écouteur resize/orientationchange, car rien ne relance ajusteLesTextes non plus après une rotation. 2) Traiter le plancher à part : si le texte déborde encore à la taille minimale, passer en -webkit-line-clamp avec « … » et un toucher qui déplie, ou laisser la carte grandir, plutôt que de couper net.

**Note du contre-expert.** Le mécanisme est réel. J'ai relancé l'ouverture à froid de #hizouk : 1 carte coupée sur 12 sans délai, 5 sur 15 avec les polices retardées de 800 ms, et refaire la boucle d'ajustement après document.fonts.ready répare les 5. Mais dans l'usage normal, l'accueil charge déjà « Hebreu Serif » 400 : 0 carte coupée sur 9 en lançant une séance depuis l'accueil. Le cas se limite donc à une ouverture directe sur une route qui porte une carte (rechargement, lien). L'exemple 320×568 de l'abandon relève d'une autre cause : .chizuk-trad s'affiche dans la police système du body, pas dans une police web, et la coupure vient du plancher de 8 px, pas du chargement de la police.

### FWEBLIVE-06 — Hors ligne, morceau jamais écouté : le mini-lecteur affiche « Pause » et « Musique : … » alors que rien ne joue

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** Un morceau n’est gardé hors ligne qu’après une première écoute (sw.js). Hors ligne, une séance avec un morceau jamais écouté affiche un toast bref (« Ce morceau n’a pas pu être lu. »). Mais le mini-lecteur reste en état de lecture : classe joue, bouton « Pause », 0:00 / 0:00. La ligne « Musique : Fire (kamanche) — Noam Shpayer » reste aussi, et rien n’indique quels morceaux sont disponibles hors ligne.

**Preuve.** OUT/web-live/v2/mini-horsligne.mjs, fr et he, iPhone, réseau coupé après installation de la coquille : {"mini":"mini-lecteur joue","aria":"Pause","total":"0:00"} (he : « השהיה »). Capture OUT/web-live/v2/horsligne/mini-fr-2.png. Code : app.js:286-289 (echecLecture ne fait que signale()) et app.js:4882 `const joue = !lecteur.paused && !lecteur.ended;` (paused reste faux après un échec de source).

**Correction proposée.** Dans echecLecture : `lecteur.pause(); lecteur.removeAttribute('src'); majMini();` et masquer la ligne « Musique : … » tant que rien ne joue. Sur l’écran Musique, marquer les morceaux déjà gardés (caches.open('musique-2')) d’un « disponible hors connexion ».

### FWEBLIVE-07 — Neuf titres de morceaux restent en français dans l’interface anglaise et hébraïque

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Neuf titres marqués translatable="false" contiennent du français (du, de, « titre incertain », guillemets français, transcriptions françaises « Chpola », « ’Houppa »). Ils s’affichent tels quels en anglais et en hébreu : liste Musique, ligne de séance, mini-lecteur.

**Preuve.** Routes #musique en/he, iPhone (OUT/web-live/v2/routes/rapport-frenhe-iphone.json, div.nom) : « Niggoun du Baal Chem Tov — Ianir », « Zemer bichva'hin (titre incertain) — Ianir », « Kol baYa'ar (Niggoun du Saba de Chpola) — Ianir ». android/app/src/main/res/values/strings.xml:334, 338, 339, 340, 341, 342, 344, 347, 348 (track_shpayer_ki_hine_kahomer, track_ianir_baal_shem_tov, _zemer_bishvahin, _berditchev, _kol_bayaar, _yohanan_hasandlar, _houppa, _kabbalat_chabbat, _bessarabie). Absents de values-en et values-iw.

**Correction proposée.** Ôter translatable="false" sur ces 9 clés et les traduire. En : « Niggun “Ki hineh kachomer” — Noam Shpayer », « Baal Shem Tov Niggun — Ianir », « Zemer bishvachin (uncertain title) — Ianir », « Berditchev Niggun — Ianir », « Kol baYa’ar (Niggun of the Shpoler Zeide) — Ianir », « Niggun of Rabbi Yochanan HaSandlar — Ianir », « Chuppah Niggun — Ianir », « Kabbalat Shabbat Niggun (live) — Ianir », « Bessarabian Niggun — Ianir ». He : « ניגון ״כי הנה כחומר״ — נועם שפייר », « ניגון הבעל שם טוב — יניר », « זמר בשבחין (שם לא ודאי) — יניר », « ניגון ברדיצ׳ב — יניר », « קול ביער (ניגון הסבא משפולה) — יניר », « ניגון רבי יוחנן הסנדלר — יניר », « ניגון חופה — יניר », « ניגון קבלת שבת (הופעה חיה) — יניר », « ניגון בסרביה — יניר ».

### FWEBLIVE-08 — Réglages du site : des textes d’Android parlent de « mode », de « rappels » et du « téléphone », absents du web

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : texte

**Constat.** Le site reprend tels quels des textes d’Android, en trois langues. Il n’a pourtant ni barrière (« le mode »), ni rappels, et la présentation web dit lui-même que tout reste « dans ce navigateur ». Quatre textes sont concernés : settings_shabbat_hint (« le mode se tait, pas de rappel »), reset_hint et reset_confirm_text (« … réglages et rappels ») et section_data_hint (« Tout est stocké sur ce téléphone uniquement »).

**Preuve.** Route #reglages en fr, en et he, iPhone (textes relevés dans OUT/web-live/v2/toucher/textes-*-iphone.json) : « Ces jours-là : le mode se tait, pas de rappel, et la série reste intacte. », « On those days: the mode is silent, no reminder… », « בימים אלה: המצב שותק, אין תזכורת… ». strings.xml : values:109, 936, 939, 33 ; values-en:101, 872, 875, 28 ; values-iw:102, 889, 892, 28. Code : app.js:4415, 4348-4349, 4500.

**Correction proposée.** Créer des variantes _web, comme onboarding_private_body_web. settings_shabbat_hint_web : « Ces jours-là, la série reste intacte. » / « On those days, your streak stays intact. » / « בימים אלה הרצף נשמר. » reset_hint_web : « Efface tout ce que ce navigateur garde sur cet appareil : journal, hitbodedout, séries, trophées, réglages et morceaux ajoutés. Exportez d’abord vos données si vous voulez les garder. » section_data_hint_web : « Tout est gardé dans ce navigateur, sur cet appareil seulement : effacer les données du navigateur l’efface aussi. Exportez de temps en temps. »

### FWEBLIVE-09 — La sauvegarde exportée perd les marque-pages, les favoris, le noussa’h, le lieu et la langue

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** « Exporter » ne garde que les journées, quelques réglages, les jours exemptés et le journal enrichi. Un aller-retour vers un navigateur vide perd donc le reste : marque-pages (marques_pages), favoris de textes et de ’hizouk, noussa’h, lieu des zmanim, région, langue, journal du Tikoun, réglages de lecture et morceaux ajoutés. Le format suit Android, mais le web y ajoute déjà journal_plus : l’ajout de clés ignorées par Android est donc possible.

**Preuve.** OUT/web-live/v2/donnees.mjs, fr, en et he. Export de 2 049 octets, réglages = 15 clés. Import dans un navigateur vierge : « 10 journées importées | prénom Avi | nusah undefined | marques null | langue undefined | lieu undefined » (fichier OUT/web-live/v2/donnees/export-fr.json). Code : web/src/js/store.js:509-547.

**Correction proposée.** Ajouter à exportJson une clé web_extra { marques_pages, favoris, chizuk_favoris, siddur_nusah, lieu_zmanim, in_israel, langue_app, tikkun_journal, lecture_* }, ignorée par Android et relue par importJson avec les mêmes contrôles de type. Sinon, dire sous « Mes données » ce que la sauvegarde ne contient pas.

### FWEBLIVE-10 — Aucun lien vers les règles de confidentialité dans le site

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** La page confidentialite.html (trois langues) est publiée avec le site, et la clé settings_confidentialite existe dans les trois langues. Mais app.js ne l’emploie nulle part : aucun écran du site, réglages compris, ne mène à cette page. Android a son bouton (SettingsActivity.kt:173).

**Preuve.** Parcours de toutes les routes et « toucher chaque bouton » en fr, en et he : aucun lien vers confidentialite.html (seuls liens externes relevés : chabad.org, halachayomit.co.il, hyomi.org.il). grep « confidentialite » dans myhitbodedut-web/js/*.js : 0 occurrence. strings.xml:1426 settings_confidentialite = « Règles de confidentialité ».

**Correction proposée.** Ajouter une ligne dans la carte de la présentation des réglages (app.js:4344) : `ligne({ nom: tr.t('settings_confidentialite'), onclick: () => window.open('confidentialite.html#' + tr.langue, '_blank') })`. La page est dans la coquille, donc elle s’ouvre aussi hors ligne.

### FWEBLIVE-11 — Recherche : en français ou en anglais, seuls les titres sont cherchés, et 0 résultat s’affiche sans explication

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** dansRecueil ne cherche dans le corps des textes que le champ hébreu (x.t), jamais les traductions fr ou en. « joie » renvoie un écran nu « RÉSULTATS : 0 », et « hitbodedout » un seul titre, alors que les livres et le Tikoun ont des traductions françaises. L’indice « Rechercher dans le siddour, les livres, la halakha, les hilloulot » ne dit pas que la recherche porte sur l’hébreu.

**Preuve.** OUT/web-live/v2/recherche.mjs : fr « joie » → 0 (capture OUT/web-live/v2/recherche/fr-joie.png), fr « zzqx » → 0, en « joy » → 1 titre (« Blessings on enjoyments »), he « שמחה » → 94. Code : app.js:1578-1581 (`s.blocs.find((x) => x.t && nuRecherche(x.t).includes(q))`) et app.js:1606 (aucun message pour total = 0).

**Correction proposée.** Chercher aussi dans b.fr ou b.en selon la langue de l’interface. À défaut, afficher pour 0 résultat : « Aucun résultat. Les textes se cherchent en hébreu ; en français, seuls les titres et les hilloulot. » Indice : « Rechercher en hébreu dans le siddour, les livres, la halakha ; les titres aussi en français ».

### FWEBLIVE-12 — À 320 px, le bouton « Partager » de l’écran ’hizouk sort de l’écran

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** Les trois boutons (« Un autre », « Garder », « Partager ») ont flex: 1 sans min-width: 0. Leur largeur minimale dépasse un tiers de 320 px : « Partager » déborde à droite (bord coupé), et « Un autre » passe sur deux lignes. Les contrôles automatiques du dépôt (captures.mjs, LARGEUR=320) ne visitent pas cet écran.

**Preuve.** Route #hizouk, fr, 320×568 : « &lt;button class="secondaire"> « Partager » 220–335 » (contrôle « sortis », OUT/web-live/v2/routes/rapport-fr-petit.json), aussi en grand texte (grand.mjs). Capture OUT/web-live/v2/routes/hizouk-fr-petit-1.png. Code : web/src/app.css:1397-1398.

**Correction proposée.** app.css:1398 : `.hizouk-actions button { flex: 1 1 0; min-width: 0; padding-inline: 8px; }`, ou `.hizouk-actions { flex-wrap: wrap; }`. Ajouter #hizouk aux captures à 320 px.

### FWEBLIVE-13 — Vol : l’interrupteur promet le « suivi en direct », puis répond « pas encore en service »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : texte

**Constat.** Dès qu’un vol est saisi, l’interrupteur « Services en ligne : route du vol et suivi en direct » apparaît. L’activer affiche seulement « Le relais du suivi n’est pas encore en service dans cette version. » Le relais est vide dans la version publiée : c’est une fonction « à venir » visible. La présentation promet en plus l’envoi d’« une position approchée si vous activez le suivi en direct », ce qui ne peut pas arriver.

**Preuve.** Route #vol, fr et he, iPhone, vol décrit en texte libre puis interrupteur activé (OUT/web-live/v2/vol.mjs) : « Services en ligne : route du vol et suivi en direct / Le relais du suivi n’est pas encore en service dans cette version. » (he : « שרת הממסר של המעקב עדיין אינו פעיל בגרסה זו. »). Capture OUT/web-live/v2/planches/vol.png. Code : myhitbodedut-web/js/relais.js:4 `export const RELAIS_VOL = '';` et app.js:3567. Chaînes vol_direct_inactif (strings.xml:1346) et vol_direct_activer.

**Correction proposée.** Tant que RELAIS_VOL est vide, intituler l’interrupteur « Services en ligne : route du vol (adsbdb) » et ne plus afficher vol_direct_inactif. Dans onboarding_private_body_web, remplacer la fin par « … sauf le numéro d’un vol, si vous activez les services en ligne. »

### FWEBLIVE-14 — Cibles tactiles de 24 px de haut : « Partager ma hitbodedout » et « et 4 autres › »

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** Deux liens-boutons font 24 px de haut, loin des 44 points conseillés sur iPhone. Le premier est le partage du bravo (195×24 en fr), le second « et 4 autres › » (hilloulot du jour) sur les écrans Zmanim et Calendrier.

**Preuve.** Routes bravo (fr, en, he) et zmanim / calendrier (fr, en, he), iPhone : « petite cible 195×24 : &lt;button class="lien-bouton bravo-partage"> », « petite cible 82×24 : &lt;button class="jour-hilloula-reste lien-bouton"> » (he : 47×24), OUT/web-live/v2/routes/rapport-frenhe-iphone.json.

**Correction proposée.** Donner à .lien-bouton un min-height de 44px (padding vertical 10px) sans changer la taille du texte.

### FWEBLIVE-15 — Siddour : le sélecteur de noussa’h est tronqué en « Noussa’h séfarade (Edot Ha… »

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : texte

**Constat.** Le libellé du noussa’h choisi dépasse la pastille de l’en-tête. Il est coupé avec une ellipse à 390 px (239 > 206 px), et bien plus à 320 px (239 > 136 px).

**Preuve.** Routes #siddur, #textes et #priere, fr et en, iPhone : ellipses « Noussa’h séfarade (Edot HaMizra’h) » [239>206], « Sephardi nusach (Edot HaMizrach) » [230>206] ; 320 px : [239>136]. Captures OUT/web-live/v2/routes/siddur-fr-iphone-0.png et siddur-fr-petit-0.png.

**Correction proposée.** Afficher dans la pastille un libellé court (« Edot HaMizra’h », « Sfard », « Ashkenaz ») et garder le libellé complet dans la feuille de choix.
