# FWEBCODE — Web — revue du code (PWA iPhone)

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

23 constats — confirmés en partie : 4 · confirmés : 4 · non contre-expertisés (mineurs et cosmétiques) : 15.

## Ce qui a été examiné

Lu en entier : web/src/js/app.js (5 524 lignes, par tranches), store.js, regles.js, seance.js, i18n.js, musique.js, morceaux-perso.js, ambiance.js, paliers.js, trophees.js, tikkun.js, hitbodedut.js, personnage.js, calendrier.js, chizuk.js, relais.js, jour-affiche.js ; sw.js, build.mjs, index.html, manifest.webmanifest, tools/chaines.mjs, tools/serveur.mjs ; web/README.md, web/PLAN_DU_SITE.md ; section française de confidentialite.html (anglais et hébreu par recherche ciblée) ; sections « Ce qui manque », « Reste », « Sujets ouverts » de FEUILLE_DE_ROUTE.md.

Échantillonné : vol.js (120 lignes sur 684 : réseau, adsbdb, relais), boussole.js et siddur-jour.js (extraits) ; app.css par recherche seulement (zoom, focus, polices, 254 tailles) ; tests : noms des 201 tests des 22 fichiers et corps de 3 (séance ouverte, réinitialisation), sans les exécuter. Kotlin comparé : SessionRule.kt et Paliers.kt en entier ; Store.kt (réinitialisation, addSession, série, séance, export/import : environ 350 lignes sur 1 641) ; SessionService.kt (environ 200 lignes) ; seuils de Trophees.kt (identiques au site) ; SourceDuJour.kt ; recherches dans VolActivity, SettingsActivity, LanguesTexte, SiddurLectureActivity.

Non lu : calendrier-juif.js, tefila.js, magnetisme.js, zmanim.js, halakha.js, yalkut.js, aeration.js, direction.js, trophees-formes.js, vendor/kosher-zmanim (calcul pur, couvert par les tests qu'un autre auditeur lance).

Traductions (demande de l'utilisateur), pour ce que le site affiche : script sur les trois strings.xml (1 184 chaînes fr, 1 139 en, 1 139 he ; 36 pluriels et 2 tableaux dans les trois) : les 45 clés absentes en anglais et en hébreu sont des titres de morceaux et des chaînes non traduisibles ; 52 valeurs identiques en français et en anglais parmi les clés utilisées, toutes légitimes (noms propres, formats, « Journal », « Volume ») ; contenus : 'hizouk 171/171 en fr et en, guide par sujet complet en 3 langues, 51 villes en 3 langues, Tikoun et Tehilim traduits, 11 livres sur 12 à 100 %. Les manques sont dans les constats (source du jour, siddour, Yalkout Yossef – Kitsour, hilloulot, halakha). Je n'ai pas relu la qualité rédactionnelle des 1 139 traductions une à une : autre dimension.

Vérifié par exécution : 6 scripts Playwright (Chrome 390×844, site déployé myhitbodedut-web servi en lecture seule, 15 scénarios) et 4 scripts Node, tous dans OUT/fwebcode/ (t1.mjs à t6.mjs, perf.mjs, cles.mjs, donnees.mjs, trad.mjs, serveur.mjs). Site déployé comparé aux sources : identique (seul sw.js diffère, par la version et la liste injectées).

Non examinable ici : un vrai iPhone ou Safari (pas de moteur WebKit) : lecture audio écran verrouillé, Wake Lock en mode installé, effacement à 7 jours (établi par la documentation WebKit, non reproduit), VoiceOver, ambiance Web Audio avec le commutateur silencieux ; les en-têtes réels de GitHub Pages (compression, durée de cache) ; le relais de suivi de vol (absent du site déployé).

## Ce qui tient

- Le temps de séance est tenu par l'horloge, pas par le minuteur : début et terme sont enregistrés (store.js:387-393), chaque rendu et chaque retour au premier plan recalculent (app.js:5350, 5467-5484), et une séance relue longtemps après son terme n'inscrit que sa durée. Vérifié par exécution avec horloge simulée : 5 min inscrites, jamais plus. La musique passe par un élément &lt;audio> (lecture écran verrouillé sur iOS), dont les événements servent d'horloge pour clore la séance (app.js:5050-5056) ; le service worker répond par tranches 206 comme Safari l'exige.
- Aucune surface XSS trouvée : tout le DOM est construit par createElement et createTextNode (h(), app.js:53-67) ; les 4 innerHTML ne reçoivent que des constantes ou du texte échappé (echapper, app.js:3132) ; riche() n'accepte que &lt;b>, &lt;small> et &lt;br> ; CSP stricte (script-src 'self', object-src 'none', form-action 'none') ; le fichier importé est validé champ par champ (dates réelles entre 2000 et 2100, bornes, listes fermées, 2 Mo au plus).
- Chaînes d'interface irréprochables sur la structure : une seule source (strings.xml relu à la construction), 867 clés utilisées par le site toutes présentes en français, 5 seulement absentes en anglais et en hébreu et toutes non traduisibles (app_name, week_shabbat_mark, siddur_tehilim_he, siddur_tikkun_he, boussole_source_titre), 0 écart de paramètres %n$ sur 1 184 chaînes, aucun français dans les valeurs anglaises, lang et dir posés sur la racine et sur chaque bloc hébreu, changement de langue à chaud.
- Hors connexion complet une fois installé : textes, polices, illustrations et données sont dans la coquille, versionnée par empreinte du contenu ; les anciens caches sont supprimés à l'activation ; la page ouverte n'est rechargée après mise à jour que lorsqu'elle passe à l'arrière-plan et jamais pendant une séance (app.js:5493-5498).
- Les feuilles de dialogue sont soignées : role=dialog, aria-modal, piège de focus, Échap, retour du focus à l'élément d'origine (app.js:142-163) ; prefers-reduced-motion respecté partout ; le zoom n'est pas bloqué (viewport sans user-scalable).
- L'export et l'import partagent le format d'Android et préservent, à l'aller-retour par le site, les réglages propres à Android (barrière, rappels) sans les écraser par des valeurs par défaut (store.js:535-539) ; la fusion à l'import ne détruit rien (séance la plus longue, note non vide, sujets réunis).

## Constats

### FWEBCODE-01 — Safari peut effacer tout le journal après sept jours : l'application ne prévient pas et n'invite jamais à s'installer

**Gravité** : majeur (auditeur : bloquant) · **Contre-expertise** : confirmé en partie · **Plateforme** : web · **Type** : fonction

**Constat.** Tout (journal, notes, série, trophées, morceaux ajoutés) vit dans localStorage et IndexedDB. Hors installation sur l'écran d'accueil, WebKit supprime ce stockage après 7 jours d'usage de Safari sans interaction avec le site. Le site se contente d'un persist() muet dont il ne lit pas la réponse : aucun écran ne dit d'installer l'application, aucun ne signale le risque. Trois pertes silencieuses s'y ajoutent : (1) si localStorage est refusé, le site bascule sur un stockage en mémoire sans rien dire, tout disparaît au rechargement ; (2) une écriture refusée (quota) est avalée, la séance est perdue alors que le bravo s'affiche ; (3) l'application installée a un stockage séparé de Safari : qui a commencé dans Safari retrouve un journal vide après l'installation, sans consigne d'export/import. Ironie : la famille de trophées « retour » récompense un retour après au moins sept jours sans pratique, soit exactement le cas où Safari a pu tout effacer.

**Preuve.** web/src/js/app.js:36-50 « } catch { return memoire(); } » puis « navigator.storage?.persist?.().catch(() => {}); » (résultat jamais lu). web/src/js/store.js:66 « catch { /* quota : rien à faire de mieux */ } ». web/src/js/trophees.js:39 « Les retours : un jour de pratique après au moins sept jours sans. ». Recherche de « écran d'accueil », « Home Screen », « installer » dans android/app/src/main/res/values/strings.xml : 0 occurrence ; seul texte lié, strings.xml:33 « Tout est stocké sur ce téléphone uniquement. Exportez de temps en temps. ». Règle WebKit (webkit.org/tracking-prevention) : « ITP deletes all cookies created in JavaScript and all other script-writeable storage after 7 days of no user interaction with the website » ; « The first-party domain of home screen web applications is exempt ». Non reproduit sur iPhone (pas de Safari ici).

**Correction proposée.** 1) Sur iOS hors mode installé (navigator.standalone faux), afficher à l'accueil une carte refermable : FR « Sur iPhone, installez l'application : Partager → « Sur l'écran d'accueil ». Sans cela, Safari peut effacer votre journal après sept jours sans visite. » ; EN « On iPhone, install the app: Share → “Add to Home Screen”. Otherwise Safari may erase your journal after seven days without a visit. » ; HE « באייפון כדאי להתקין את האפליקציה: שיתוף ← ״הוסף למסך הבית״. בלי זה Safari עלול למחוק את היומן אחרי שבעה ימים בלי ביקור. ». 2) Lire navigator.storage.persisted() et le dire quand c'est faux. 3) Bandeau permanent quand le repli memoire() est actif. 4) Faire remonter l'échec d'écriture (ecrit rend faux → message). 5) Garder la date du dernier export et rappeler d'exporter au-delà de 30 jours ; au premier lancement installé avec un journal vide, proposer « Importer ».

**Note du contre-expert.** Faits vérifiés : app.js:36-50 (repli memoire() muet, persist() jamais lu), store.js:66, aucune invitation à installer dans les chaînes, règle WebKit des sept jours et exemption de l'écran d'accueil confirmées sur webkit.org ; sous-constat 2 rejoué sous Chrome (OUT/contre-fwebcode/c4.mjs) : « Bravo ! 5 minutes » s'affiche alors que l'écriture du journal est refusée et que rien n'est inscrit. La gravité est à ramener à majeur : la perte n'est pas reproduite (pas d'iPhone) et reste conditionnelle — onglet Safari non installé et sept jours d'utilisation de Safari sans toucher au site ; l'usage quotidien et l'application installée (mode prévu par web/README.md) y échappent, et les réglages disent déjà « Exportez de temps en temps ». Le risque reste à traiter en premier côté web, la carte d'installation coûtant peu.

### FWEBCODE-02 — « Le décompte est masqué. Un son vous préviendra. » : le site n'émet aucun son de fin

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : web · **Type** : texte

**Constat.** Avec « Masquer le décompte », l'écran de séance du site affiche la légende d'Android qui promet un son. Le site n'en joue aucun : la clôture arrête la musique, relâche l'écran et tire un 'hizouk, rien d'autre. Sans musique, celui qui ferme les yeux en attendant le son promis ne sera jamais prévenu. Les réglages du site ont d'ailleurs retiré l'indice qui parlait du son, mais pas cette légende.

**Preuve.** web/src/js/app.js:4969 « if (mode === 'masque') return { texte: '', legende: tr.t('session_hidden_caption') }; ». android/app/src/main/res/values/strings.xml:168 « Le décompte est masqué. Un son vous préviendra. » (EN : « The countdown is hidden. A sound will tell you. »). web/src/js/app.js:4926-4944 (cloreSeance : aucun son) contre SessionService.kt:197 « if (!early && Store.hideCountdown(this)) chime() ». app.js:4412 « ligneInterrupteur(tr.t('settings_hide_countdown'), null, … » (indice omis). Exécution Chrome (OUT/fwebcode/t1.mjs) : légende affichée = « Le décompte est masqué. Un son vous préviendra. », musique coupée.

**Correction proposée (revue par le contre-expert).** Préférer le carillon : amorcer un élément &lt;audio> dans le geste « Commencer » et le jouer à la clôture arrivée à son terme. À défaut, une chaîne propre au site qui ne suppose pas que la musique joue (celle proposée est fausse quand la musique est coupée) : FR « Le décompte est masqué. À la fin, l’écran change ; la musique s’arrête si elle jouait. » ; EN « The countdown is hidden. At the end the screen changes, and the music stops if it was playing. » ; HE « הספירה מוסתרת. בסיום המסך מתחלף, והמוזיקה נעצרת אם התנגנה. »

**Note du contre-expert.** Relu (app.js:4969 ; cloreSeance, demarreTic et l'écouteur timeupdate ne jouent rien ; indice retiré en 4412) et rejoué sous Chrome avec un espion sur play(), Web Audio et vibrate (OUT/contre-fwebcode/c1.mjs) : la légende affiche « Le décompte est masqué. Un son vous préviendra. » et aucun son n'est émis au terme, musique coupée ou non. La même promesse est faite en anglais et en hébreu (« צליל יודיע על הסיום ») ; rien dans FEUILLE_DE_ROUTE.md n'en fait un choix.

### FWEBCODE-04 — La sauvegarde n'est pas complète : Tikoun, marque-pages, favoris et réglages de lecture perdus à la restauration

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** « Exportez de temps en temps » est le seul filet contre la perte du stockage, mais le fichier ne contient que les journées, quinze réglages, les jours de pause, les applications de la barrière et (web seul) le journal enrichi. N'y sont pas : le journal du Tikoun (tikkun_journal, qui nourrit deux familles de trophées, jusqu'à 200 lectures), les marque-pages (jusqu'à 60), les favoris, les 'hizouk gardés, les noms donnés aux morceaux, le nusah, la police et la taille de lecture, les langues de lecture, le lieu. Après restauration, les trophées « tikkun » et « tikkun_serie » retombent à zéro. Côté Android, exportJson n'écrit pas journal_plus et importJson l'ignore : humeur, gratitude et « chose à travailler » sont perdues d'un téléphone à l'autre et du site vers Android.

**Preuve.** web/src/js/store.js:509-546 : racine = format, version, exported_at, days, settings{target_minutes … apparence_accent}, paused_dates, blocked_apps, journal_plus. store.js:485 « set('tikkun_journal', … » jamais exporté ; store.js:183 marques_pages, 168 favoris, 177 chizuk_favoris, 505 music_names : idem. store.js:543 « Le journal enrichi (02/11) : une clé de plus, qu'Android ignore à l'import. ». android/…/Store.kt:1484-1521 (exportJson) : aucune clé journal_plus ni tikkun_journal ; Store.kt:949 journal_plus n'est lu que par journalPlusBrut.

**Correction proposée.** Passer le format en version 2 sur les deux plateformes et y ajouter : tikkun_journal, journal_plus (export et import Android), marques_pages, favoris, chizuk_favoris, music_names, siddur_nusah, lecture_echelle, lecture_police, lecture_langues. À l'import, fusionner (union des dates du Tikoun, des marque-pages et des favoris). Ajouter un test d'aller-retour qui échoue dès qu'une clé du stockage n'est ni exportée ni inscrite dans une liste d'exclusions voulues (lieu, sacs de 'hizouk, marques « vus »).

**Note du contre-expert.** Relu store.js:509-546 et Store.kt:1484-1623 : tikkun_journal, marques_pages, favoris, chizuk_favoris, music_names, nusah, réglages de lecture et lieu ne sont ni exportés ni importés, et Android n'écrit ni ne lit journal_plus (store.js:543 le dit) ; les trophées tikkun et tikkun_serie se calculent bien sur tikkun_journal (app.js:3855). Nuance : sur Android le transfert d'appareil à appareil (data_extraction_rules.xml) emporte le fichier du journal, journal_plus compris, et la sauvegarde nuage emporte les réglages ; la perte ne vaut donc que par le fichier d'export, qui est le seul filet du site.

### FWEBCODE-05 — Réglages → « Lieu » : à la première ouverture, la liste des villes est vide

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : web · **Type** : fonction

**Constat.** choisirLieu() lance le chargement de villes.json puis construit aussitôt la feuille avec « villes ?? [] ». Depuis l'écran Réglages (qui ne précharge pas les villes), la feuille ne montre que « Ma position » et la mention des sources : aucune ville. Elle ne se complète pas quand le fichier arrive ; il faut la fermer et la rouvrir. C'est le chemin naturel après la présentation. Conséquence annexe : « Ma position » choisie dans cette première feuille n'a pas de ville proche (nom « Ma position », altitude 0).

**Preuve.** web/src/js/app.js:2541-2550 « function choisirLieu() { chargeVilles(); feuille(tr.t('zmanim_choisir_lieu'), (f, fermer) => { … for (const v of villes ?? []) { » ; app.js:4294 (Réglages : « onclick: choisirLieu » sans chargeVilles() au rendu). Exécution Chrome (…/audit/fwebcode/t2.mjs) : première ouverture = 1 choix ; 1,5 s plus tard, même feuille = 1 choix ; seconde ouverture = 52 choix.

**Correction proposée (revue par le contre-expert).** Faire rendre une promesse à chargeVilles() et remplir la liste de la feuille à son arrivée (un conteneur, « Chargement… » en attendant, un message si le fichier échoue) ; appeler aussi chargeVilles() au rendu des Réglages, comme le fait ecranZmanim. Attendre cette promesse dans localiserPosition est facultatif : la ville proche est déjà trouvée en pratique.

**Note du contre-expert.** Défaut principal reproduit sous Chrome (OUT/contre-fwebcode/c1.mjs) : depuis Réglages → « Lieu des zmanim », la première feuille ne montre que « Ma position », toujours 1 choix après 3 s, 52 à la réouverture ; depuis l'écran Zmanim, qui précharge les villes, 52 d'emblée. La « conséquence annexe » est fausse : « Ma position » touchée aussitôt dans cette première feuille donne « Ma position · près de Paris » (c2.mjs), car poser() lit la liste à l'arrivée de la position et non à l'ouverture de la feuille ; et toutes les altitudes de villes.json valent déjà 0.

### FWEBCODE-07 — « Réinitialiser l'application » n'efface pas tout : les morceaux ajoutés et les caches restent

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : web · **Type** : fonction

**Constat.** Le texte promet d'effacer « tout ce que l'application garde sur ce téléphone ». Le site ne retire que deux clés de localStorage. Restent : les fichiers audio personnels copiés dans IndexedDB (base myhitbodedut-musique), qui réapparaissent dans la bibliothèque après la réinitialisation ; le cache de musique (jusqu'à 153 Mo) et la coquille (47,5 Mo) ; la clé myhitbodedut-calibrage-livres. Le texte cite aussi des « rappels » que le site n'a pas. Le test existant ne vérifie que les deux clés.

**Preuve.** web/src/js/store.js:124 « reinitialiser: () => { try { stockage.removeItem(PREFS); stockage.removeItem(PREFS_JOURNAL); } catch { … } } » ; web/src/js/app.js:4349-4352 ; strings.xml:936 « Efface tout ce que l'application garde sur ce téléphone : journal, hitbodedout, séries, trophées, réglages et rappels. » ; web/test/personnalisation.test.mjs:25-34. Exécution Chrome (…/audit/fwebcode/t1.mjs) : après confirmation, IndexedDB contient toujours « Mon morceau privé », réaffiché dans #musique ; myhitbodedut-calibrage-livres = « 1.234 ».

**Correction proposée (revue par le contre-expert).** Vider le magasin « morceaux » par une transaction clear() et attendre sa fin avant location.replace (indexedDB.deleteDatabase serait bloqué par la connexion que morceaux-perso.js garde ouverte) ; retirer myhitbodedut-calibrage-livres et vider sessionStorage ; effacer le cache musique-2 reste au choix du propriétaire (contenu livré, pas donnée personnelle). Deux chaînes propres au site, sans « rappels ». reset_hint_web : FR « Efface ce que l’application garde dans ce navigateur : journal, hitbodedout, séries, trophées, réglages et morceaux ajoutés. Exportez d’abord vos données si vous voulez les garder. » ; EN « Erases what the app keeps in this browser: journal, hitbodedut days, streaks, trophies, settings and added tracks. Export your data first if you want to keep it. » ; HE « מוחק את מה שהאפליקציה שומרת בדפדפן הזה: יומן, התבודדויות, רצפים, גביעים, הגדרות וניגונים שהוספתם. כדאי לייצא את הנתונים לפני כן אם רוצים לשמור אותם. ». reset_confirm_text_web : FR « Le journal, les hitbodedout, les séries, les trophées, les réglages et les morceaux ajoutés seront effacés de ce navigateur. Cela ne peut pas être annulé. » ; EN « The journal, hitbodedut days, streaks, trophies, settings and added tracks will be erased from this browser. This cannot be undone. » ; HE « היומן, ההתבודדויות, הרצפים, הגביעים, ההגדרות והניגונים שהוספתם יימחקו מהדפדפן הזה. אי אפשר לבטל זאת. »

**Note du contre-expert.** Relu (store.js:124 ne retire que deux clés ; ni IndexedDB ni caches ne sont touchés par la réinitialisation, app.js:4349-4352) et rejoué sous Chrome (OUT/contre-fwebcode/c1.mjs) : après « Tout effacer », la base myhitbodedut-musique contient toujours « Mon morceau privé », réaffiché dans la bibliothèque, et myhitbodedut-calibrage-livres reste. Sur Android la réinitialisation vide les préférences, donc les morceaux ajoutés disparaissent : l'écart est propre au site ; les caches ne tiennent que du contenu livré, leur maintien est discutable mais pas une fuite.

### FWEBCODE-08 — « Source du jour » : en hébreu seul à l'accueil, en français comme en anglais, alors que sa traduction est livrée

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : texte

**Constat.** La carte « Source du jour » de l'accueil affiche jusqu'à 320 caractères d'hébreu sans traduction, chaque jour, à tous les utilisateurs français et anglais. Or les 29 sources de la bibliothèque ont leurs paragraphes traduits (paragraphes_fr et paragraphes_en, alignés un à un) et l'écran de la source, lui, les affiche. Même défaut sur Android. Exemple du 12/11/2026 : Likoutei Tefilot II, 22, affiché « ותרחם עלי ותפתח את פי בכל עת… » alors que « Aie pitié de moi et ouvre ma bouche en tout temps… » est dans le fichier.

**Preuve.** web/src/js/app.js:742 « h('p', { class: 'source-du-jour-texte', lang: 'he', dir: 'rtl' }, SourceDuJour.extrait(p.texte)) » ; android/…/SourceDuJour.kt:66-67 « text = extrait(p.texte) ». Données (…/audit/fwebcode/donnees.mjs) : 29 sources, 29 avec paragraphes_fr, 29 avec paragraphes_en, longueurs alignées ; 108 paragraphes candidats.

**Correction proposée.** Faire porter à SourceDuJour.candidats l'indice du paragraphe ({ source, texte, indice }) et afficher la carte par LanguesTexte.textes(mode, hébreu, source.paragraphes_fr[indice], source.paragraphes_en[indice]), comme carteChizuk : l'hébreu puis la traduction par défaut, selon le choix « אA ». Même changement dans SourceDuJour.kt.

**Note du contre-expert.** Relu (app.js:742, SourceDuJour.kt:66-67) et affiché sous Chrome au 12/11/2026, en français puis en anglais (OUT/contre-fwebcode/c1.mjs) : la carte ne porte que l'hébreu de Likoutei Tefilot II, 22, alors que les 29 sources ont paragraphes_fr et paragraphes_en alignés et que l'écran de la source les affiche (app.js:2171, LibraryEntryActivity.kt:65). Aucun choix écrit de l'hébreu seul : la carte date du 19/10, les traductions du 04/11 (commit 7d05dcd), elle n'a simplement pas suivi, et la carte de 'hizouk voisine applique déjà LanguesTexte.

### FWEBCODE-03 — Hors connexion : 47,5 Mo téléchargés d'office (annoncés « ~24 Mo »), et retéléchargés en entier à chaque mise à jour

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : web · **Type** : fonction

**Constat.** À la première visite, le service worker met en cache 172 fichiers pesant 47,5 Mo (environ 14 Mo transférés en gzip), sans rien demander, y compris en données mobiles : 28,4 Mo de livres (dont Yalkout Yossef 11,5 Mo et Likoutei Moharan 10,4 Mo) et 6,9 Mo de biographies que la plupart n'ouvriront jamais. Le nom du cache porte l'empreinte de tout le contenu : la moindre chaîne corrigée crée un nouveau cache que addAll remplit de zéro, donc chaque déploiement refait télécharger les 47,5 Mo à chaque utilisateur. addAll est tout ou rien : un seul des 172 téléchargements en échec et rien n'est gardé, tout repart au chargement suivant. L'enregistrement part dès le chargement du module et concurrence le premier affichage.

**Preuve.** web/src/sw.js:3 « La coquille (code, chaînes, textes, illustrations, livres et biographies : ~24 Mo) » ; sw.js:18 « caches.open(CACHE_COQUILLE).then((c) => c.addAll(COQUILLE)).then(() => self.skipWaiting()) » ; web/build.mjs:174-184 (tout dist sauf sw.js et musique/). Mesure sur myhitbodedut-web/sw.js : 172 entrées, 47 520 657 octets (data/livres 28,43 Mo ; data/hilloulot_bios 6,90 Mo). Exécution Chrome (…/audit/fwebcode/t3.mjs) : après 2,2 s, cache « coquille-10227679bb4f » = 172 entrées, navigator.storage.estimate().usageDetails.caches = 47 580 635.

**Correction proposée (revue par le contre-expert).** 1) Corriger le chiffre de sw.js (environ 48 Mo gardés, 15 Mo transférés). 2) Avant d'écrire une reprise fichier par fichier, mesurer sur le site en ligne si une mise à jour rend des 304 pour les fichiers inchangés ; si ce n'est pas le cas, reprendre de l'ancienne coquille les fichiers dont l'empreinte (table écrite par build.mjs) n'a pas changé. 3) Dans install, demander chaque fichier avec { cache: 'no-cache' } : sous Chrome avec max-age=600, un fichier changé moins de dix minutes après un chargement entre périmé dans la nouvelle coquille sans aucune requête (OUT/contre-fwebcode/c3.mjs). 4) Sortir livres et biographies de la coquille est une décision du propriétaire (poids contre lecture hors connexion) ; s'ils y restent, enregistrer le service worker après le premier rendu.

**Note du contre-expert.** Mesures confirmées sur myhitbodedut-web (172 entrées, 47 520 657 octets, environ 14,6 Mo en gzip ; « ~24 Mo » périmé dans sw.js:3), mais garder livres et biographies d'office est un choix écrit du propriétaire (sw.js:3-5 « pour que tout se lise hors connexion » ; build.mjs n'écarte que la musique, jugée trop lourde). Le « tout retéléchargé à chaque déploiement » n'a pas été essayé par l'auditeur (serveur « no-store », aucune mise à jour simulée) : rejoué sous Chrome avec des ETag stables (OUT/contre-fwebcode/c2.mjs), une nouvelle version donne 172 réponses 304 et 0,01 Mo téléchargé ; sur GitHub Pages cela dépend des validateurs servis après un déploiement, non vérifié ici, et porterait au pire sur environ 14,6 Mo compressés. Ni bogue visible ni promesse rompue (le chiffre faux est un commentaire de code) : mineur.

### FWEBCODE-06 — Un seul fichier en échec au démarrage : écran vide, sans message ni « Réessayer » ; aucune garde autour du rendu

**Gravité** : mineur (auditeur : majeur) · **Contre-expertise** : confirmé en partie · **Plateforme** : web · **Type** : fonction

**Constat.** demarrer() attend quatre téléchargements sans try/catch et est appelé sans .catch : si strings, musique.json, tikkun_haklali.json ou chizuk.json échoue (réseau instable à la première visite, alors que 47 Mo se téléchargent en parallèle), l'écran d'ouverture s'efface et #app reste vide pour toujours. De même, rendre() vide l'écran (app.replaceChildren()) avant de construire le suivant : toute exception d'un écran laisse une page blanche, sans onglets ni retour (et tr.t lève une exception pour toute clé inconnue). Trois chargements différés n'ont aucun .catch (Tehilim, siddour, bibliothèque) : hors ligne avant la fin de l'installation, l'écran reste vide sans explication, alors que les livres, eux, ont message et bouton.

**Preuve.** web/src/js/app.js:5437-5443 « const [m, t, c, p] = await Promise.all([ fetch('data/musique.json').then((r) => r.json()), … » ; app.js:5500 « demarrer(); » ; app.js:5378 « app.replaceChildren(); » avant les ecranX() ; app.js:810, 1005, 2083 « fetch(…).then((r) => r.json()).then((d) => { …; rendre(); }); » sans catch ; web/src/js/i18n.js:46 « throw new Error(`Chaîne inconnue : ${nom}`) ». Exécution Chrome (…/audit/fwebcode/t2.mjs, data/chizuk.json servi en 503) : document.getElementById('app').innerHTML.length = 0, aucun texte visible, erreur « SyntaxError: Failed to execute 'json' on 'Response' ».

**Correction proposée (revue par le contre-expert).** Garder les trois points, avec deux précisions : le message de secours de demarrer() doit être écrit en dur dans les trois langues, choisi d'après navigator.languages, car tr n'existe pas quand strings.&lt;langue>.json est le fichier en échec ; pour le bouton, reprendre les libellés déjà livrés de livres_reessayer_web (« Réessayer », « Try again », « לנסות שוב »).

**Note du contre-expert.** Reproduit sous Chrome (OUT/contre-fwebcode/c1.mjs, captures c06_*.png) : strings.fr.json, musique.json ou chizuk.json en 503 laisse #app vide, écran d'ouverture retiré, sans message ; demarrer() n'a ni try/catch ni .catch (app.js:5435-5500). Portée à corriger : ces fichiers sont dans la coquille, donc le cas ne se présente que sur une panne réseau avant la fin de la première installation du service worker, et un rechargement suffit ; les trois chargeurs différés ne laissent pas un écran vide (bandeau, retour et parties fixes restent, capture c06b_bibliotheque.png) et redemandent le fichier à chaque rendu ; l'exception de rendu est une hypothèse dont aucun cas n'est montré. Mineur plutôt que majeur.

### FWEBCODE-09 — Tous les textes ne sont pas traduits : le bouton de langues « אA » reste sans effet et sans avis sur le siddour et sur 90 % du Yalkout Yossef

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : transverse · **Type** : texte

**Constat.** Les chaînes d'interface sont complètes (voir couverture), mais pas les contenus. Siddour : 0 bloc traduit sur 1 321 (Edot), dont 354 consignes en hébreu seul ; le bouton « אA » y propose pourtant « Français » et « English », sans effet et sans message. Yalkout Yossef – Kitsour : 1 489 blocs traduits sur 14 303 (10 %) ; en mode « Français », 90 % du livre reste en hébreu sans explication, car l'avis « Ce texte n'a pas encore de traduction » n'apparaît que si le livre n'a aucune traduction. Halakha du jour et notices des hilloulot : hébreu seul ; noms des hilloulot traduits pour 179 (fr) et 229 (en) sur 4 049 ; la carte du jour (Zmanim, calendrier) n'affiche que le nom hébreu même quand la traduction existe.

**Preuve.** web/src/js/app.js:1473 « const sansTraduction = livre && LanguesTexte.manque(languesLecture(), x.sections.some((s) => s.blocs.some((b) => b.fr || b.en))); » ; web/src/js/regles.js:76 « manque: (mode, aTraduction) => !aTraduction && … » ; même règle dans SiddurLectureActivity.kt:254. app.js:2921 « liste.slice(0, 5).map((x) => h('div', {}, x.he)) ». Comptes sur myhitbodedut-web/data : siddur_edot.json 1 321 blocs, 0 avec fr/en ; livres/yalkut_yosef_kitsour.json 14 303 blocs, 1 489 fr, 1 489 en ; les onze autres livres traduits à 100 %.

**Correction proposée.** 1) Afficher l'avis pour tout texte sans traduction, siddour compris (retirer « livre && »), ou masquer « אA » sur ces écrans. 2) Livre partiellement traduit : nouvel avis FR « Ce livre n'est traduit qu'en partie : le reste s'affiche en hébreu. » ; EN « Only part of this book is translated: the rest is shown in Hebrew. » ; HE « הספר מתורגם רק בחלקו: השאר מוצג בעברית. ». 3) Carte du jour : sous le nom hébreu, nomTraduitHilloula(x) quand il existe.

### FWEBCODE-10 — Les feuilles de dialogue survivent au retour arrière ; restée ouverte au terme de la séance, « Abandonner » remplace le bravo par « Courage ! »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** Les feuilles sont posées sur document.body et rien ne les retire quand l'historique recule : après le geste de retour (bord de l'écran sur iPhone, bouton sur Android), la feuille « Terminer la hitbodedout ? » flotte au-dessus de l'accueil. Autre incohérence : si « Abandonner ? » est ouverte quand la séance atteint son terme, la séance est bien inscrite (5 min) et le bravo poussé, mais confirmer la feuille périmée affiche l'écran d'abandon (« Courage ! », « La prochaine fois sera meilleure. ») à la place.

**Preuve.** web/src/js/app.js:161 « document.body.append(voile); » ; app.js:5319-5323 (popstate : seulement rendre()) ; app.js:4953-4962 (annulerSeance ne vérifie pas store.isSessionRunning()). Exécution Chrome : t1.mjs → après history.back(), hash vide, écran « avec-onglets », feuille « Terminer la hitbodedout ? » toujours présente ; t2.mjs → journal {"2026-11-10":{"minutes":5}}, puis titre affiché « Courage ! ».

**Correction proposée.** Dans le gestionnaire popstate et au début de cloreSeance(), fermer toute feuille ouverte (document.querySelectorAll('.voile').forEach((v) => v.remove())). Dans annulerSeance() et terminerMaintenant(), sortir sans rien faire si la séance n'est plus inscrite (store.sessionStartedAt() === 0).

### FWEBCODE-11 — Page rechargée pendant une séance : la fin n'est vue qu'au toucher suivant, l'écran n'est plus gardé allumé

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** Quand iOS recharge la page pendant une séance (onglet déchargé, application relancée sur l'accueil), le drapeau etaitEnCours repart à faux : l'horloge tourne mais ne clôt plus la séance à son terme. L'accueil reste sur « Hitbodedout en cours » et « Revenir à la hitbodedout en cours » jusqu'au prochain toucher, qui inscrit alors la séance et montre le bravo. Le verrou d'écran n'est redemandé qu'au lancement d'une séance ou au retour de visibilité, pas au démarrage. La correction de l'audit du 16/10 ne couvre donc pas ce cas.

**Preuve.** web/src/js/app.js:5033-5038 « if (etaitEnCours && !store.isSessionRunning()) { cloreSeance({ avantTerme: false }); rendre(); return; } » ; etaitEnCours n'est posé qu'en 4908 et 5131 ; gardeEcranAllume() n'est appelé qu'en 4911 et 5482 ; commentaire app.js:5363-5364 « sinon sa fin n'était vue qu'au toucher suivant (audit du 16/10) ». Exécution Chrome (…/audit/fwebcode/t6.mjs) : six minutes après le rechargement d'une séance de 5 min, statut « Hitbodedout en cours », séance encore inscrite, journal nul, wakeLock.request appelé 0 fois ; après un toucher : #bravo, journal 5 min.

**Correction proposée.** Dans le tic, remplacer la condition par « if (store.isSessionOver()) » (elle ne dépend d'aucun drapeau en mémoire). Dans demarrer(), si store.isSessionRunning() : appeler gardeEcranAllume() et proposer de relancer la musique au premier toucher.

### FWEBCODE-12 — L'adresse ne dit pas quel texte est ouvert : après un rechargement, #priere, #lecture et #source retombent sur la liste

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** Le texte ouvert (prière, livre, psaume, source) n'existe que dans une variable en mémoire ; l'adresse reste « #priere ». Tout rechargement le perd : onglet Safari déchargé au retour d'une autre application, ou rechargement voulu par le site après une mise à jour. Le lecteur de Cha'harit ou d'un livre revient sur la liste du siddour. Le commentaire du code affirme le contraire. Aucun lien ne peut non plus mener à un texte précis.

**Preuve.** web/src/js/app.js:924 « let priere = null; » ; app.js:5299-5303 (ecranCourant ne lit que le nom de l'écran) ; app.js:1373-1374 « Rouvert directement sur #priere, sans texte choisi : la liste. » ; app.js:5489-5492 « On recharge au prochain retour sur l'application … l'écran ouvert est gardé dans l'historique, la place dans le livre aussi. » ; app.js:5497 « location.reload() ». Exécution Chrome (…/audit/fwebcode/t2.mjs) : « בִּרְכוֹת הַשַּׁחַר » ouvert, rechargement, hash « #priere », écran affiché = liste « Siddour ».

**Correction proposée.** Porter l'identifiant dans l'adresse : #priere/chaharit, #priere/livre:likoutei_moharan, #lecture/23, #source/&lt;id>. ecranCourant() lit la première partie, les écrans lisent la seconde au lieu des variables priere, lecture et entreeBiblio. À défaut : au démarrage, rouvrir store.derniereLecture() quand le hash est #priere.

### FWEBCODE-13 — Feuilles à retardement : le bilan de la semaine et les fiches de trophées s'ouvrent par-dessus un autre écran ; huit fiches à la suite après un import

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** L'accueil arme deux minuteurs à chaque rendu (bilan de la semaine à 1,4 s, fête des trophées à 0,6 s) qui ne vérifient pas que l'accueil est encore affiché. Le dimanche, qui touche « Commencer » dans la seconde voit « Votre semaine » s'ouvrir sur l'écran de séance et intercepter ses touchers. Après l'import d'une sauvegarde sur une installation neuve, tous les trophées sont « nouveaux » : huit fiches modales avec confettis s'enchaînent (une par famille).

**Preuve.** web/src/js/app.js:5424 « if (accueil && !document.querySelector('.presentation')) setTimeout(bilanDeLaSemaine, 1400); » ; app.js:4177-4179 (seule garde : « .presentation ») ; app.js:3839 « if (trophee) setTimeout(() => feterTrophees(tropheesNeufs), 600); ». Exécution Chrome (…/audit/fwebcode/t5.mjs) : dimanche 08/11/2026, écran « ecran seance », feuille « feuille-bilan : Votre semaine » par-dessus ; après import de 299 jours : 8 fiches (« 250 jours de pratique », « 100 jours d'affilée », « 40 semaines pleines… », « 150 notes au journal », …).

**Correction proposée.** Au déclenchement des deux minuteurs, sortir si ecranCourant() !== 'accueil', si onglet !== 'aujourdhui', si une feuille est déjà ouverte ou si une séance est en cours (le bilan attend alors la prochaine ouverture : ne poser bilan_vu qu'à l'affichage). Après importJson, appeler store.setTropheesVus(Trophees.gagnes(pratique())) et store.setPaliersVus(…) pour ne rien fêter d'ancien.

### FWEBCODE-14 — Les aperçus sonores cassent le son de la séance : l'ambiance coupée après 5 s, la musique perdue après « Écouter »

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** Choisir une ambiance hors séance lance un aperçu et un minuteur de 5 s qui l'arrête. Si la séance commence dans ces 5 s, elle reprend la même source sans la relancer et le minuteur, jamais annulé, coupe l'ambiance de la séance, qui ne revient plus. De même, « Écouter » un morceau depuis l'écran Musique pendant une séance remplace la musique de séance ; à la fin de l'aperçu rien ne la relance.

**Preuve.** web/src/js/app.js:2377 « else { joueAmbiance(AMBIANCES[i], store.musicVolume()); clearTimeout(apercuAmbiance); apercuAmbiance = setTimeout(arreteAmbiance, 5000); } » ; app.js:4733 « joueAmbiance(store.ambiance(), store.musicVolume()); » ; web/src/js/ambiance.js:80 « if (type === courante && source) return; » ; app.js:299-309 (ecouter : « lecteur.src = m.fichier; lecteur.loop = false; lectureAuHasard = false; »). Exécution Chrome (…/audit/fwebcode/t5.mjs, start/stop de AudioBufferSourceNode tracés) : un seul start (aperçu), séance commencée 1 s après, puis un stop pendant la séance, aucun nouveau start.

**Correction proposée.** Dans demarreMusique() : clearTimeout(apercuAmbiance) avant joueAmbiance. Dans ecouter() : pendant une séance, relancer demarreMusique() à la fin ou à l'arrêt de l'aperçu (ou masquer « Écouter » tant que store.isSessionRunning()).

### FWEBCODE-15 — Changement de langue : le nom du lieu reste dans l'ancienne langue, les libellés du mini-lecteur aussi

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : texte

**Constat.** Le nom du lieu est enregistré déjà traduit au moment du choix (« Jérusalem », « près de Lyon ») : après un passage à l'anglais ou à l'hébreu, Réglages, Zmanim et Boussole continuent d'afficher le nom français. Le mini-lecteur de séance est construit une seule fois : ses libellés d'accessibilité (ouvrir, replier, précédent, suivant, aléatoire, position) restent dans la langue de sa première construction jusqu'au rechargement.

**Preuve.** web/src/js/app.js:2554 « store.setLieu({ nom: titreTexte(v.nom), … » ; app.js:2506 « nom: proche ? tr.t('zmanim_position_pres', titreTexte(proche.nom)) : tr.t('zmanim_position') » ; app.js:4837, 4842, 4846 (aria-label posés par tr.t dans construireMini, appelé une fois : app.js:4878 « if (!mini) construireMini(); »). Exécution Chrome (…/audit/fwebcode/t2.mjs) : ville choisie en français, langue passée à English → lignes « Language | English », « Zmanim location | Jérusalem », « Region | Israel ».

**Correction proposée.** Ne garder que l'identifiant de la ville et le mode (ville ou position proche) ; calculer le nom à l'affichage (titreTexte(ville.nom), ou tr.t('zmanim_position_pres', …)). Au changement de langue : mini?.remove(); mini = null; pour le reconstruire.

### FWEBCODE-16 — Accueil : plus de 1 400 lectures et analyses du stockage par rendu au bout de deux ans de journal

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** Chaque accès du store relit et réanalyse tout le JSON (réglages ou journal). Le rendu de l'accueil appelle plusieurs fois streak(), meilleureSerie() (qui parcourt chaque jour depuis le premier et appelle isExempt, soit trois analyses des réglages par jour), anneaux(), minutesParJour(), et écrit deux fois les réglages (paliers et trophées vus) même sans changement. Le coût croît avec l'ancienneté : chaque action de l'accueil (durée, sujet, retour d'une feuille, retour au premier plan) refait tout.

**Preuve.** web/src/js/store.js:62-69 « const lit = (nom) => { try { return JSON.parse(stockage.getItem(nom) || '{}') … » et « const get = (cle, defaut) => { const v = prefs()[cle]; … » ; store.js:301-304, 307-321 ; web/src/js/app.js:3841-3842 « store.setPaliersVus(…); store.setTropheesVus(new Set(gagnes)); » à chaque rendu. Mesure Node (…/audit/fwebcode/perf.mjs, mêmes appels que panneauAujourdhui et lignePaliers) : 30 jours → 152 lectures ; 730 jours → 1 427 lectures, 10,9 Mo de JSON analysés, 133 ms ; 1 500 jours → 3 701 lectures, 222 ms. Chrome, journal de 730 jours (…/t4.mjs) : rendu de l'accueil 84 à 159 ms, et 192 à 628 ms processeur ralenti 4 fois.

**Correction proposée.** Dans creeStore, garder en mémoire l'objet analysé de chaque entrée (invalidé par ecrit et par l'événement « storage »), et mémoriser joursFaits, streak et meilleureSerie pour la durée d'un rendu. N'écrire paliers_vus et trophees_vus que si l'ensemble a changé.

### FWEBCODE-17 — Musique : chaque morceau est téléchargé deux fois à la première écoute, et le cache ne se vide jamais

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** À la première écoute, le service worker lance deux requêtes réseau pour le même fichier : la lecture (par tranches) et une copie entière pour le cache. Un morceau de 2,7 Mo en moyenne coûte donc environ le double en données mobiles. Les morceaux gardés (jusqu'à 153 Mo pour les 56) ne sont jamais retirés : ni limite, ni bouton, ni la réinitialisation. L'ajout d'un morceau personnel lit le fichier entier en mémoire sans limite de taille.

**Preuve.** web/src/sw.js:65-66 « e.waitUntil(fetch(cle).then((r) => (r.ok && r.status === 200 ? cache.put(cle, r) : null)).catch(() => {})); return fetch(e.request); » ; sw.js:14-15 et 21-27 (seuls les caches d'un autre nom sont supprimés) ; web/src/js/app.js:2426 « entree.blob = new Blob([await fichier.arrayBuffer()], … » ; myhitbodedut-web/data/musique.json : 56 morceaux, 153 339 927 octets.

**Correction proposée.** Première écoute : une seule requête entière dans le service worker (fetch(cle)), mise en cache, puis réponse par tranche() depuis cette même réponse ; ou ne mettre en cache qu'une fois la lecture finie. Ajouter dans Musique une ligne « Morceaux gardés hors connexion : N (X Mo) · Vider ». Refuser un fichier ajouté au-delà d'une taille raisonnable (par exemple 50 Mo) avec music_add_quota_web.

### FWEBCODE-18 — Accessibilité : tailles de texte figées en pixels, marque-pages au seul appui long, rôles ARIA incohérents

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** 1) Sur 254 tailles de police, 231 sont en pixels fixes (corps à 15 px, libellés à 10, 10,5 et 11 px) : le réglage « Texte plus grand » d'iOS n'a aucun effet sur l'interface ; seuls les textes de lecture suivent l'échelle propre à l'application. 2) Poser un marque-page n'est possible que par appui long de 550 ms (ou clic droit) : aucun bouton, donc rien au clavier ni avec VoiceOver. 3) Les feuilles de choix donnent role="menuitemradio" à des boutons sans parent role="menu". 4) La présentation et la fête de grade sont des dialogues modaux sans piège de focus ni Échap. Le zoom par pincement n'est pas bloqué.

**Preuve.** web/src/app.css:36 « font: 15px/1.4 -apple-system, … » ; décompte : 230 « font-size: Npx » + 1 « !important », 19 « calc(Npx * var(--echelle…)) », 4 en em, 0 en rem ; app.css:1198 « .onglet { font-size: 10px; … } », 192 « .jour .nom { … font-size: 11px; } ». web/src/js/app.js:881-883 et 1419-1421 (contextmenu et touchstart + setTimeout 550) ; app.js:168 « class: 'choix', role: 'menuitemradio' » dans une feuille role="dialog" ; app.js:4525 « h('div', { class: 'presentation', role: 'dialog', 'aria-modal': 'true' }) » sans gestion du clavier.

**Correction proposée.** 1) Passer le corps à « font: -apple-system-body » (ou 1rem) et les tailles en rem, pour suivre le réglage du téléphone. 2) Ajouter « Marquer ce paragraphe » à la liste des marque-pages du bandeau (paragraphe du haut de l'écran), utilisable au clavier et au lecteur d'écran. 3) Mettre les options de choisirDans dans un conteneur role="radiogroup" avec role="radio", comme choisirNusah. 4) Réutiliser le piège de focus et Échap de feuille() pour la présentation et la fête de grade.

### FWEBCODE-19 — Confidentialité côté site : la phrase de la présentation est inexacte, et le site n'a ni règles propres ni lien vers elles

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : texte

**Constat.** La présentation du site dit que rien ne part « sauf l'indicatif d'un vol et une position approchée si vous activez le suivi en direct ». Dans le site en ligne, le suivi en direct est inactif (relais vide) ; ce qui part réellement, après accord, est le numéro de vol envoyé à api.adsbdb.com par la loupe, que la phrase ne cite pas. Par ailleurs confidentialite.html, servi par le site, ne « s'applique » qu'à l'application Android (SharedPreferences, sauvegarde Google, barrière) : rien sur localStorage, IndexedDB ou Safari, et les réglages du site n'ont aucun lien vers ces règles alors qu'Android en a un.

**Preuve.** strings.xml:548 (onboarding_private_body_web) « … rien n'est envoyé nulle part, sauf l'indicatif d'un vol et une position approchée si vous activez le suivi en direct. » ; myhitbodedut-web/js/relais.js « export const RELAIS_VOL = ''; » ; web/src/js/vol.js:430 « Ce qui part de l'appareil : le numéro du vol, vers api.adsbdb.com » ; web/src/index.html:10 « connect-src 'self' https://api.adsbdb.com » ; web/src/confidentialite.html:50 « S'applique à l'application Android MyHitbodedut (com.myhitbodedut) » ; ecranReglages (app.js:4279-4354) sans lien, contre SettingsActivity.kt:173 « R.id.privacy_policy ».

**Correction proposée.** Réécrire onboarding_private_body_web : FR « Ce que vous écrivez reste dans ce navigateur, sur cet appareil. Rien n'est envoyé, sauf si vous activez les services en ligne des zmanim en vol : le numéro du vol part alors vers adsbdb.com quand vous touchez la loupe. » ; EN « What you write stays in this browser, on this device. Nothing is sent, unless you turn on the online services of in-flight zmanim: the flight number then goes to adsbdb.com when you tap the magnifier. » ; HE « מה שתכתבו נשאר בדפדפן הזה, במכשיר הזה. שום דבר לא נשלח, אלא אם תפעילו את השירותים המקוונים של זמנים בטיסה: אז מספר הטיסה נשלח אל adsbdb.com כשנוגעים בזכוכית המגדלת. ». Ajouter à confidentialite.html une section « Version web » (stockage du navigateur, effacement possible par Safari, position, adsbdb) et, dans les réglages du site, une ligne « Règles de confidentialité » ouvrant confidentialite.html#fr, #en ou #he.

### FWEBCODE-20 — Règles de confidentialité : « la loupe n'apparaît que services en ligne activés » est faux depuis le 04/11

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : play · **Type** : texte

**Constat.** Les règles de confidentialité (datées du 2 novembre, celles que Google Play référence) affirment dans les trois langues que la loupe du numéro de vol n'apparaît que lorsque les services en ligne sont activés. Depuis le 04/11, sur Android comme sur le site, la loupe est toujours visible et demande l'accord au premier toucher. L'engagement de fond tient (rien ne part sans accord), mais la phrase ne décrit plus le code, contrairement à ce que promet l'en-tête du fichier.

**Preuve.** web/src/confidentialite.html:92 « quand vous touchez la loupe à côté du numéro de vol (elle n'apparaît que services en ligne activés) » ; :151 « (it only appears once online services are on) » ; :210 « (היא מופיעה רק כשהשירותים המקוונים פעילים) » ; en-tête :8-11 « Chaque phrase décrit le code … Toute évolution de ces fichiers se reporte ici. ». android/…/VolActivity.kt:224 et web/src/js/app.js:3775 « La loupe est toujours là (04/11) ; services en ligne éteints, elle demande d'abord l'accord. »

**Correction proposée.** Remplacer la parenthèse dans les trois langues et mettre la date à jour. FR « quand vous touchez la loupe à côté du numéro de vol ; tant que les services en ligne sont éteints, elle vous demande d'abord votre accord. » ; EN « when you tap the magnifier next to the flight number; while online services are off, it first asks for your consent. » ; HE « כשתגעו בזכוכית המגדלת ליד מספר הטיסה; כל עוד השירותים המקוונים כבויים, היא מבקשת קודם את הסכמתכם. »

### FWEBCODE-21 — Écarts avec Android que les documents ne listent pas : 24 fiches d'articles, signal de fin de séance, lien de confidentialité, et autres

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** PLAN_DU_SITE.md ne réserve à Android que les rappels et notifications, la barrière du matin et les vignettes (connu). Manquent aussi au site, sans être documentés : (1) les 24 fiches d'articles de la bibliothèque (résumés traduits en trois langues, livrés dans bibliotheque.json mais jamais affichés ; le site ne montre que les 29 sources) ; (2) tout signal de fin de séance écran verrouillé et sans musique (Android : notification « Vous avez parlé avec Hachem aujourd'hui » et carillon si le décompte est masqué) ; (3) le lien « Règles de confidentialité » des réglages ; (4) la carte de 'hizouk du moment « lieu » (réglages Android) ; (5) « Ne pas déranger » pendant la séance ; (6) les rappels Birkat haLevana, « Chabbat dans 3 h » et les rappels en vol ; (7) la lecture du code-barres d'une carte d'embarquement (le site n'a que la saisie rapide). Règle différente, voulue et imposée par un test : une séance « Sans durée » oubliée ne se clôt jamais sur le site (« 1800:00 » et « Hitbodedout en cours » après 30 h), là où Android la tient pour échue à 240 min quand son service est mort.

**Preuve.** web/src/js/app.js:2076-2078 « Sur le web, les sources seulement … Les articles … attendent leur fiche. » ; bibliotheque.json : 24 entrées « type: article », 29 « source » ; android : LibraryEntryActivity.kt:107 bindArticle, SessionService.kt:191 notifyCompleted et :197 chime(), SettingsActivity.kt:71 « ChizukCard.show(findViewById(R.id.lieu_chizuk), Moment.LIEU) », :173 privacy_policy, :319 ne_pas_deranger_switch, LevanaAlerte.kt, ChabbatAlerte.kt, VolAlerte.kt, LecteurBillet.kt ; SessionRule.kt:83-89 estEchue (absent de web/src/js/seance.js) ; web/test/seance.test.mjs:169-178 ; exécution Chrome (…/audit/fwebcode/t2.mjs) : décompte « 1800:00 », statut « Hitbodedout en cours ». Connu : web/PLAN_DU_SITE.md:11-12.

**Correction proposée.** Porter les fiches d'articles (titre, résumé de la langue, mention des droits, lien : tout est déjà dans bibliotheque.json) et le lien de confidentialité. Tenir dans PLAN_DU_SITE.md la liste exacte ci-dessus de ce qui reste propre à Android. Pour la séance ouverte : au démarrage et au retour de visibilité, clore à 240 min une séance « Sans durée » plus vieille que le plafond, comme SessionService.reconcilier.

### FWEBCODE-22 — Documents du site périmés : le plan, la feuille de route, le README et deux commentaires disent autre chose que le code

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : docs · **Type** : texte

**Constat.** 1) PLAN_DU_SITE.md, mise à jour du 02/11 : « Restent propres à Android : … humeur et gratitude dans la note, hitbodedout guidée, ajout de sa propre musique » ; les trois sont dans le site. Le corps du plan garde ses ⏳ (présentation, Textes, Journal, réglages) et « 33 niggounim » (56 livrés). 2) FEUILLE_DE_ROUTE.md, 04/11 : « toujours valables : la liste « Reste » du 19/10 », liste qui dit que le journal, la carte de la hitbodedout guidée et les Tefilot manquent au web ; ils y sont. « Ce qui manque » (14/10) dit la même chose avec « à venir ». 3) web/README.md : « Aucune requête ne sort du site … La politique de sécurité de la page l'interdit » ; la CSP autorise api.adsbdb.com et le site l'appelle après accord. 4) sw.js annonce « ~24 Mo » (47,5 mesurés) ; build.mjs « livres.json pèse 16 Mo » (28,4 Mo découpés). Aucune mention « à venir » n'est plus affichée dans l'application : seuls les documents en parlent.

**Preuve.** web/PLAN_DU_SITE.md:11-12, :24, :63, :68, :71, :75 ; web/src/js/app.js:4637-4656 (humeurs et gratitude dans ecrireNote), 5091 (carteGuide), 2417 (ajouteMorceau), 2237 (ecranJournal), 2199 (ecranTefilot) ; FEUILLE_DE_ROUTE.md:1090-1091 « web : le journal (donc 5 et l'humeur de 6), la carte de la hitbodedout guidée (donc 2), les Tefilot ; », :1137 « toujours valables : la liste « Reste » du 19/10 ci-dessus », :1038-1039 ; web/README.md:43 ; web/src/index.html:10 ; web/src/sw.js:3 ; web/build.mjs:116.

**Correction proposée.** Réécrire PLAN_DU_SITE.md d'après les écrans réels (25 routes de ecranCourant) et supprimer les ⏳. Rayer dans FEUILLE_DE_ROUTE.md les trois points web faits. README : « Aucune requête ne sort du site, sauf le numéro de vol envoyé à api.adsbdb.com quand l'utilisateur active les services en ligne et touche la loupe. » Corriger les deux poids dans sw.js et build.mjs.

### FWEBCODE-23 — Code mort et doublons dans app.js

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : web · **Type** : fonction

**Constat.** Restes à retirer : carteBoussole() et carteVol() ne sont appelées nulle part ; formulaireVolOuvert est écrite, jamais lue ; le paramètre aVenir de ligne() et la classe CSS .a-venir n'ont plus d'appelant ; CHAINES_LECTURE et le repli de tl() sont inutiles (les neuf clés existent en fr, en et he) ; store.resetTikkun n'est appelée par personne ; quatre constantes de store.js (DEFAULT_START, DEFAULT_END, DEFAULT_SNOOZE, DEFAULT_REMINDER) ne servent à rien sur le site. L'en-tête du fichier et un commentaire décrivent un état révolu. Trois fonctions identiques testent prefers-reduced-motion (plus deux tests en ligne), et trois fabriques SVG locales doublent s().

**Preuve.** web/src/js/app.js:3117 « function carteBoussole() », :3367 « function carteVol() » (une seule occurrence de chaque nom dans le fichier) ; :3556 et :3793 formulaireVolOuvert ; :756-757 « aVenir = false » et web/src/app.css:235 « .a-venir { opacity: 0.45; pointer-events: none; } » ; :1021-1034 CHAINES_LECTURE ; web/src/js/store.js:490 resetTikkun, :15-17 et :35 ; app.js:1-4 « ce qui n'existe pas encore est montré, mais inerte (classe « a-venir ») », :2281 « Les textes arrivent à l'étape 4. » ; app.js:386 sansMouvement, :611 moinsDeMouvement, :3923 moinsAnime, :3859 et :5255 ; :1629, :2752, :3900.

**Correction proposée.** Supprimer ces définitions, garder une seule fonction pour prefers-reduced-motion et s() pour tout le SVG, mettre à jour l'en-tête. Profiter du passage pour découper app.js (5 524 lignes, 327 Ko, un seul module chargé au démarrage) par écran, en import() différé pour le vol, la boussole et les trophées.
