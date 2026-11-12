# TPLAYDOCS — Vitrine — fiche Google Play, captures, README et documents

[← Retour à la synthèse](../README.md)

Abréviations : voir la synthèse (R, A, K, RAW, OUT).

23 constats — confirmés : 10 · confirmés en partie : 3 · non contre-expertisés (mineurs et cosmétiques) : 10.

> Contre-expertise incomplète pour cette dimension.

## Ce qui a été examiné

Lu en entier : PUBLICATION_PLAY_STORE.md (628 lignes), README.md (305), nokia/README.md, nokia/depot/README.md et le README du dépôt Nokia publié (identiques), web/README.md, tools/relais_vol/README.md, .github/workflows/play.yml, les trois manifestes Android, build.gradle.kts, MusiquePlay.kt et MusiqueHorsPlay.kt. Lu en partie : FEUILLE_DE_ROUTE.md (lignes 225-265, 480-600 et 1000-1163), ZMANIM.md (survol : lignes 1-24, 161-180, 320-340), web/PLAN_DU_SITE.md (110 premières lignes), nokia.yml et web.yml (étapes de publication), la section française de confidentialite.html. Visuels : les 4 planches d'aperçu, puis 14 des 34 visuels ouverts en pleine taille (fr 11, 12, 13 ; en 02, 09, 10 ; he 01, 02, 03, 04, 07, 08, 10) et des recadrages de fr 05, 08, 09, 10, 14 et he 05, 09 ; 1 des 5 captures brutes Android ; les 7 promo-screenshots. Pages héritées : index.html (en-tête, titres, liens externes) et tikkun_haklali.html (texte extrait, début et fin). Vérifié par mesure ou par le code : dimensions de toutes les images de play/ et promo-screenshots/, nombre et poids des morceaux (Play, hors Play, site déployé), contenu du .jar Nokia, valeurs par défaut de Store.kt, emplacement du bouton d'aperçu, validation d'une journée par déclaration, origines git des trois dépôts. Une recherche extérieure, sans nom de projet : la documentation GitHub sur le transfert d'un dépôt. Non examiné : captures-calendrier/ (11 images), maquettes-dedicaces/ (8), images/, le dossier musique/ au-delà de sa liste ; le rendu réel de l'application Android (aucun émulateur) ; l'accessibilité en ligne des URL publiques (interdit d'y mettre le nom du projet) ; les règles Google Play n'ont pas été relues en ligne (limites 30/80/4 000 et 8 captures reprises du cahier). Aucun texte de description de fiche n'existe : les limites de longueur n'ont pu être contrôlées que sur les deux titres. Mes scripts et recadrages sont sous OUT/tplaydocs.

## Ce qui tient

- Le cahier PUBLICATION_PLAY_STORE.md distingue chaque affirmation (Vérifié, Déduit, Supposé), date ses décisions et cite ses sources Google : on sait ce qui a été lu et ce qui a été supposé, ce qui rend ses erreurs repérables.
- Des garde-fous automatiques tiennent la vitrine au code : play.yml refuse un AAB signé par la clé de développement et recompte les morceaux livrés dans le fichier lui-même ; ConfidentialiteTest lie la page publique, en trois langues, à ce que le code fait réellement.
- Les deux titres respectent la limite (23 et 25 caractères pour 30), sans superlatif ni emoji, et l'adresse de contact est la même partout : 23 occurrences de la seule adresse en vigueur, l'ancienne n'étant citée qu'une fois, comme historique.
- Les autorisations qui déclenchent les formulaires les plus lourds sont réellement évitées, vérifié dans les manifestes : pas de QUERY_ALL_PACKAGES, pas d'alarme exacte, pas de service d'accessibilité, pas de REQUEST_IGNORE_BATTERY_OPTIMIZATIONS ; les sous-types des services de premier plan sont rédigés en anglais dans le manifeste.
- Les visuels forment un jeu homogène et au bon format (1080 × 1920, PNG sans alpha, légendes sobres) ; l'hébreu y est correctement composé de droite à gauche, à une pastille près ; l'icône 512 × 512 est conforme (alpha, 313 Ko).
- Les quatre visuels de la barrière viennent d'un vrai Android et portent les libellés actuels (« Je suis avec Hachem », « État du mode », « Heures du mode ») ; leurs légendes annoncent des valeurs exactes (6 h à 11 h par défaut, report de 5 minutes à 1 heure).

## Constats

### TPLAYDOCS-01 — L'AAB Play interroge OpenSky depuis chaque téléphone, ce que l'accord écrit d'OpenSky interdit ; ni le cahier ni le flux Play ne le portent

**Gravité** : bloquant · **Contre-expertise** : confirmé · **Plateforme** : play · **Type** : fonction

**Constat.** Les conditions reçues d'OpenSky le 28/10 (ticket 837455) imposent que les données soient demandées par le relais, « et non par chaque téléphone ». Or le flux Play construit l'AAB sans -PrelaisVol : RELAIS_VOL reste vide et l'application retombe sur l'accès direct anonyme. Le cahier de publication (§ 3.1, § 5.2) est resté à l'état du 29/10 : il parle d'un accord « déjà reçu » et laisse à cocher « il autorise l'accès anonyme ». La décision de fond (« à couper dès que le relais est en ligne ») n'est écrite que dans tools/relais_vol/README.md, où l'on lit aussi que le relais n'est pas en ligne. Rien n'empêche donc d'envoyer sur Play un AAB contraire à l'accord.

**Preuve.** .github/workflows/play.yml:70 « run: ./gradlew --no-daemon -Pplay=true bundleFullRelease » (aucun -PrelaisVol). android/app/build.gradle.kts:166 « val relais = (project.findProperty("relaisVol") as String?).orEmpty() ». SuiviVol.kt:185 « if (relais.startsWith("https://")) Relais(relais) else OpenSkyAnonyme ». tools/relais_vol/README.md:20-21 « demandées **par ce relais** […] et **non par chaque téléphone** », :37 « pour une diffusion publique, la construire avec `-PrelaisVol=https://…` », :47 « possible, pas encore faite », :70-71 « une publication sur le Play Store […] est à revoir avec les conditions d'OpenSky ». PUBLICATION_PLAY_STORE.md:127-134.

**Correction proposée (revue par le contre-expert).** Dans play.yml, passer -PrelaisVol=${{ vars.RELAIS_VOL }} et faire échouer le flux si la variable est vide, sauf si la construction désactive explicitement le seul suivi OpenSky. Pour cela, ajouter une propriété dédiée (par exemple -PsuiviDirect=false) plutôt que SUIVI_VOL=false : SUIVI_VOL coupe aussi la route adsbdb (VolActivity:223 et :1016) alors que src/full/AndroidManifest.xml garde INTERNET. Réécrire le § 3.1 avec les quatre conditions du courriel du 28/10. Le jour où le relais est en ligne, corriger confidentialite.html (« il n'a pas de serveur pour cette application ») ainsi que les § 6.1 et 6.2.

**Note du contre-expert.** Vérifié : play.yml:70 construit sans -PrelaisVol, build.gradle.kts:166-168 laisse RELAIS_VOL vide et SuiviVol.fournisseur("") rend OpenSkyAnonyme (VolRappelsTest:131 le fige). Les conditions d'OpenSky (relais OAuth2, « non par chaque téléphone ») sont consignées depuis le 28/10 (b161755) dans tools/relais_vol/README.md:20-29, et la décision du 04/11 (:48-50) dit de couper l'accès direct une fois le relais en ligne, ce qui n'est pas fait (:46-47). Le § 3.1 du cahier, lui, en reste au 29/10 avec la case « accès anonyme » non cochée. Le suivi est désactivé par défaut, mais une fois activé l'AAB contrevient à l'accord écrit.

### TPLAYDOCS-02 — L'URL de confidentialité et le lien de partage pointent vers le compte d'un ancien propriétaire (hil123.github.io)

**Gravité** : bloquant · **Contre-expertise** : confirmé · **Plateforme** : transverse · **Type** : fonction

**Constat.** Les trois dépôts locaux ont aujourd'hui pour origine le compte myhitbo. Le code et les documents nomment encore deux autres comptes : hil123 (dépôt principal, site, URL publique) et avrahamohayon02102001 (dépôt Nokia). GitHub redirige les adresses github.com d'un dépôt transféré, mais pas son site Pages. Si le site est désormais servi sous le nouveau compte, trois choses mènent à une page introuvable : l'URL de confidentialité à saisir dans la Play Console, le bouton Réglages → « Règles de confidentialité », et le lien joint à chaque partage (« Essayez, vous aussi, gratuitement : … »). Une politique de confidentialité inaccessible fait refuser la fiche. ConfidentialiteTest impose l'ancienne adresse. Je n'ai pas ouvert l'URL (pas de nom de projet dans une requête extérieure) : le transfert est déduit des origines git.

**Preuve.** git remote -v : « origin https://github.com/myhitbo/MyHitbodedut », « …/myhitbo/myhitbodedut-web », « …/myhitbo/Nokia-my-hitbodedut-app ». CelebrationActivity.kt:203 « const val LIEN_WEB = "https://hil123.github.io/myhitbodedut-web/" » ; SettingsActivity.kt:655 ; web/src/js/app.js:5236 (identique dans le site déployé) ; PUBLICATION_PLAY_STORE.md:336 ; ConfidentialiteTest.kt:40 ; web.yml:120 « CIBLE: hil123/myhitbodedut-web » ; nokia.yml:88 « CIBLE: avrahamohayon02102001/Nokia-my-hitbodedut-app » ; README.md:170 et 224. 15 lignes citent hil123 et 4 avrahamohayon02102001 (hors feuille de route). Documentation GitHub « Transferring a repository » : « we don't redirect GitHub Pages associated with the repository ».

**Correction proposée.** Choisir une adresse publique durable (un domaine propre, sinon https://myhitbo.github.io/myhitbodedut-web/) et la porter partout : LIEN_WEB (Android et web), ConfidentialiteTest, PUBLICATION § 6.1, CIBLE de web.yml et de nokia.yml avec leurs jetons, README, nokia/README.md, nokia/depot/README.md, tools/apk_codespace.sh. Ouvrir ensuite la page de confidentialité depuis un téléphone avant toute saisie dans la Play Console.

**Note du contre-expert.** Les origines git et la liste des dépôts accessibles à cette session (list_repos) placent les trois dépôts sous myhitbo, et myhitbodedut-web y est public. Son dernier envoi (04/11 22:00) vient encore du flux qui visait hil123 : le transfert est donc postérieur. GitHub ne redirige pas un site Pages après transfert ou renommage. Or LIEN_WEB (CelebrationActivity:203, app.js:5236), LIEN_CONFIDENTIALITE (SettingsActivity:655), le § 6.1 du cahier, ConfidentialiteTest et web.yml:120/137 visent toujours hil123.github.io. Je n'ai pas ouvert l'URL (règle de non-divulgation).

### TPLAYDOCS-03 — Fiche Play : aucune description rédigée (courte et longue, en-US et iw-IL) et pas d'image de présentation 1024 × 500

**Gravité** : bloquant · **Contre-expertise** : confirmé · **Plateforme** : play · **Type** : texte · déjà connu ou choix assumé

**Constat.** Le § 7.1 ne contient que les deux titres et un plan. Les descriptions courtes sont « à rédiger », la description complète n'est qu'une liste de rubriques, et l'image de présentation obligatoire est « à créer » : aucun fichier 1024 × 500 n'existe sous play/. Il n'y a donc rien à auditer sur les limites de 80 et 4 000 caractères. Les deux titres, eux, sont conformes : 23 caractères (12 latins, 8 hébreux, 3 autres) et 25 caractères (22 latins, 3 autres), pour une limite de 30.

**Preuve.** PUBLICATION_PLAY_STORE.md:474 « Description courte | 80 caractères | en : à rédiger, avec « התבודדות » · he : à rédiger » ; :475 « Description complète | 4 000 caractères | Plan : la pratique · la séance · … » ; :494 « Image de présentation | 1024 × 500 […] | À créer ». Dimensions relevées sous play/ : 34 visuels en 1080 × 1920, 4 aperçus (1660 × 1172, 1950 × 970, 1326 × 576), 2 icônes.

**Correction proposée.** Descriptions courtes proposées (comptées). en-US, 77 caractères : « Daily hitbodedut (התבודדות): timer, journal, siddur, zmanim, morning app gate ». iw-IL, 75 caractères : « התבודדות יומית: טיימר, יומן, סידור, זמני היום ומחסום בוקר לאפליקציות שבחרתם ». Rédiger les deux descriptions longues selon le plan, avec l'argument du § 6.7 dès le paragraphe sur la barrière, les graphies « hitbodedut, hisbodedus » et la ligne d'attribution OpenSky (voir le constat dédié). Produire l'image 1024 × 500.

**Note du contre-expert.** PUBLICATION_PLAY_STORE.md:474-475 et :494 portent bien « à rédiger », un simple plan et « À créer ». Aucun fichier 1024 × 500 n'existe dans le dépôt (dimensions relevées sur tous les PNG de play/). C'est un reste-à-faire documenté, pas une erreur, mais ces trois champs sont obligatoires pour publier. Les deux descriptions courtes proposées font bien 77 et 75 caractères et reprennent les termes de l'app (Journal, Siddur, Zmanim ; יומן, טיימר, זמני היום).

### TPLAYDOCS-04 — Le visuel « Musique » (fr, en, he) montre des niggounim « livrés avec l'application » que l'AAB Play ne contient pas

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : play · **Type** : texte

**Constat.** Le visuel 10 affiche, sous « Beyond », quatre lignes « Niggoun 01 » à « Niggoun 04 — Livré avec l'application ». Ces 30 niggounim sans titre sont précisément ceux que la version Play retire, faute de provenance établie. Dans l'AAB, la liste se poursuit après « Beyond » par les morceaux de Noam Shpayer et de Ianir. La fiche montrerait donc un contenu absent du produit, et afficherait publiquement des morceaux dont le cahier dit lui-même que les droits ne sont pas établis.

**Preuve.** play/visuels/en/10-musique-en.png : « Niggun 01 / Shipped with the app », 02, 03, 04 ; mêmes lignes dans fr/10-musique.png et he/10-musique-he.png (« ניגון 01 … מגיע עם האפליקציה »). MusiquePlay.kt : 26 morceaux, « shpayer_beyond » suivi de « shpayer_eshet_hayil ». MusiqueHorsPlay.kt:13-42 : niggoun_01 à niggoun_33, ajoutés seulement hors -Pplay=true (build.gradle.kts : « if (!play) res.srcDir »). PUBLICATION_PLAY_STORE.md:202 « niggoun_01 … niggoun_33 (30 fichiers) | **Retirés** tant que la provenance n'est pas établie ».

**Correction proposée.** Refaire le visuel 10 dans les trois langues à partir d'une construction -Pplay=true (ou du site limité aux 26 morceaux) : la liste doit montrer המלך בשדה, le niggoun du Yanuka, puis les titres de Noam Shpayer et de Ianir.

**Note du contre-expert.** Les trois visuels 10 (fr, en, he) affichent « Niggoun/Niggun/ניגון 01 » à 04 avec « Livré avec l'application » sous Beyond. MusiquePlay.kt (26 entrées) enchaîne shpayer_beyond puis shpayer_eshet_hayil, et les niggoun_NN ne sont ajoutés que hors -Pplay=true (build.gradle.kts, « if (!play) res.srcDir »). Le § 3.2 du cahier les dit retirés de Play faute de provenance établie.

### TPLAYDOCS-05 — Le visuel hébreu 04 affiche le Tétragramme en toutes lettres dans un texte de prose, contre la demande du propriétaire du 04/11

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : play · **Type** : texte

**Constat.** Sur le visuel destiné à la fiche hébraïque, la carte de 'hizouk (Bisdei Yaar) porte « וגם דבר זה מכוון מאת יהוה ». Le propriétaire a demandé le 04/11 que le Nom soit abrégé ה' hors des versets cités ; les données ont été corrigées le même jour et un test l'impose. Le visuel, commité aussi le 04/11, vient d'un état antérieur. Il exposerait le Nom en clair, dans de la prose, sur une image publicitaire visible de tout le public religieux hébréophone. La même capture est en outre mal cadrée : elle s'ouvre sur les boutons « לסיים עכשיו » (coupé) et « לוותר » d'une séance en cours.

**Preuve.** play/visuels/he/04-seance-question-he.png : « …וגם דבר זה מכוון מאת יהוה הרוצה בכיסופים… בשדי יער, פרק י״ד ». android/app/src/main/res/raw/chizuk.json, items[115].he : « וגם דבר זה מכוון מאת ה' הרוצה בכיסופים » (identique dans le site déployé). Commit 416369c du 04/11 « Livres : le Nom abrégé ה' hors des versets cités ». NomsDivinsTest.kt:9-12 « il est abrégé ה' hors des versets cités (demande du 04/11/2026) ».

**Correction proposée.** Recapturer he/04 sur les données actuelles, cadré comme fr/04 et en/04 (carte « כשהמילים לא באות » en haut), et vérifier à l'œil chaque visuel hébreu avant envoi : aucun Nom en toutes lettres hors verset.

**Note du contre-expert.** J'ai rouvert he/04 : la carte porte « מכוון מאת יהוה הרוצה בכיסופים » (Bisdei Yaar 14, de la prose). chizuk.json porte aujourd'hui « מאת ה' » depuis 416369c (04/11 05:45), et NomsDivinsTest impose l'abréviation hors des versets. Les visuels ont été commités le même jour à 20:56, à partir d'un état antérieur. Le cadrage diffère aussi de en/04 : « לסיים עכשיו » est coupé en haut et suivi de « לוותר ».

### TPLAYDOCS-06 — Les 10 visuels anglais et les 10 hébreux sont des captures du site web, pas de l'application Android soumise

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : play · **Type** : fonction

**Constat.** Les captures brutes 01 à 10 font 780 × 1688 px, sans barre d'état : c'est le gabarit iPhone du site (390 × 844 doublé). Seul le sous-dossier « android » contient de vraies captures Android, cinq, toutes de la barrière et toutes en français. Les jeux en et he, seuls destinés à une fiche, ne montrent donc à aucun endroit l'application que Google recevra. Le cahier pose pourtant la règle inverse. Le visuel 09 le trahit : ses deux lignes grisées « à venir » sont un mécanisme propre au site. Je n'ai pas pu lancer l'application Android pour mesurer l'écart écran par écran.

**Preuve.** play/visuels/fr/captures-brutes/01-presentation.png … 10-musique.png : 780 × 1688, PNG sans alpha. play/visuels/fr/captures-brutes/android/23b … 23f : 1080 × 2400, avec barre d'état « 8:33 ». web/src/js/app.js:756-757 « function ligne({ nom, etat, onclick, aVenir = false … class: `ligne${aVenir ? ' a-venir' : ''}` ». PUBLICATION_PLAY_STORE.md:499 « Les captures doivent montrer l'interface réelle de la version envoyée. »

**Correction proposée.** Refaire les captures des deux langues publiées sur l'AAB lui-même (-Pplay=true, variante verifR8 ou release), en réutilisant le parcours de tools/promo_screenshots.sh réglé en clair, en-US puis he ; garder l'habillage actuel (fond, légende, cadre).

**Note du contre-expert.** Les captures brutes font 780 × 1688, sans barre d'état, avec la barre de navigation à 4 onglets du site (Aujourd'hui, Bibliothèque, Zmanim, Réglages), alors que nav_main.xml d'Android en a 5, Journal compris. Les lignes grisées Tefilot et Conseils viennent d'un ancien état du site (aVenir retiré par 75dfaa0 le 02/11) ; sur Android, TefilotActivity et TipsActivity étaient actives depuis le 19/10 au moins. Seules les cinq captures android/ (1080 × 2400, « 8:33 ») viennent de l'application, et elles sont en français.

### TPLAYDOCS-07 — La barrière du matin n'apparaît dans aucun visuel anglais ou hébreu, et chaque jeu dépasse la limite de 8 captures

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : play · **Type** : texte

**Constat.** Les quatre visuels de la barrière (11 à 14) n'existent qu'en français, langue pour laquelle le cahier a tranché qu'il n'y aurait pas de fiche. Les jeux en et he comptent 10 captures chacun, sans la fonction qui donne son sens à l'application et qui sera la plus regardée en revue ; le cahier demande pourtant de répéter l'argument de la barrière « partout (fiche, …) ». Play n'accepte que 8 captures de téléphone : il faut en retirer deux par langue, davantage si l'on ajoute la barrière. Le jeu le plus complet (14 visuels) est donc celui qui n'a pas de destination. Les visuels 13 et 14 montrent en outre une boîte de dialogue sur un écran grisé aux libellés coupés (« Ryt », « Prén », « Duré »).

**Preuve.** play/visuels/fr : 01 à 14 ; play/visuels/en et he : 01 à 10 seulement. PUBLICATION_PLAY_STORE.md:466 « **Tranché le 29/10 : pas de fiche en français.** » ; :495 « Captures téléphone | 2 minimum, 8 maximum » ; :437-438 « L'argument tient en une phrase, à répéter partout (fiche, déclaration, note aux examinateurs, écran d'accueil de l'app) ».

**Correction proposée.** Arrêter 8 visuels par langue publiée, par exemple : accueil, écran « Je suis avec Hachem », réglage du mode (applications, heures, report), séance, « les mots ne viennent pas », siddour, zmanim, boussole. Produire les visuels 11 et 12 en anglais et en hébreu ; abandonner 13 et 14. Si le jeu français doit servir, rouvrir la décision du 29/10 : l'application est d'abord écrite en français.

**Note du contre-expert.** Réel : les jeux en et he n'ont que les visuels 01 à 10, sans la barrière ; seuls fr/11 à 14 la montrent, et le français n'aura pas de fiche (cahier:466). Play limite à 8 captures (cahier:495). Trois points de description sont à corriger : seul le visuel 13 a des libellés coupés (« Ryt », « Prén », « Duré »), le 14 garde « Rythme » et « Prénom » lisibles. La citation « à répéter partout (fiche, …) » vise l'argumentaire écrit, pas les visuels. Et l'examinateur juge l'application installée, pas les captures.

### TPLAYDOCS-08 — « La journée est validée par le temps vraiment passé » : promesse du visuel 05 (trois langues) et du README que le code ne tient pas

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : play · **Type** : texte

**Constat.** Le visuel 05 et le README affirment que seule la durée réellement passée valide la journée, « pas une simple déclaration ». Le code valide pourtant la journée sur déclaration, par deux chemins : le bouton « Je l'ai déjà faite » de l'écran de garde inscrit une séance de 0 minute, et « Je l'ai faite sans le téléphone » à l'accueil inscrit la durée que l'on déclare (libellé « Validée sans minuteur »). Le visuel 11 du même jeu montre d'ailleurs le bouton « Je l'ai déjà faite ».

**Preuve.** play/visuels/fr/05-bravo.png « La journée est validée par le temps vraiment passé. » ; en/05 « Your day is marked by the time you really spent. » ; he/05 « היום נרשם לפי הזמן שעבר באמת. ». README.md:24-25 « La journée est validée par le temps réellement passé, pas par une simple déclaration. ». GateService.kt:138-139 « onAlreadyDone = { Store.addSession(this, 0) ». MainActivity.kt:174 et 251 (declarerHorsTelephone). values/strings.xml:141 « Je l’ai déjà faite », :13 « Je l’ai faite sans le téléphone », :22 « Validée sans minuteur ».

**Correction proposée (revue par le contre-expert).** Légende du visuel 05 : fr « Chaque minute s'ajoute à votre journée et à votre parcours. » ; en « Every minute counts toward your day and your path. » ; he « כל דקה מצטרפת ליום שלכם ולדרך שלכם. » (les termes de « Mon parcours », « My path », « הדרך שלי »). README:24-25 : « La journée est validée à la fin de la séance ; on peut aussi la déclarer faite (« Je l’ai déjà faite » sur l’écran de garde, « Je l’ai faite sans le téléphone » à l’accueil). »

**Note du contre-expert.** Les visuels 05 disent bien « validée par le temps vraiment passé », et README:24-25 « pas par une simple déclaration ». Le README se contredit lui-même : sa ligne 18 cite « déclarer qu'elle est déjà faite ». Dans le code, GateService:138-139 appelle Store.addSession(this, 0), qui rend la journée « faite » (noteSeule=false, Store:43). declarerHorsTelephone (MainActivity:251) inscrit de même une durée déclarée. La légende anglaise proposée dit « journey » alors que l'app dit « My path » (parcours_title).

### TPLAYDOCS-09 — L'attribution OpenSky exigée « sur la page du magasin » ne figure pas dans le cahier de la fiche

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : play · **Type** : texte

**Constat.** Le courriel d'OpenSky du 28/10 pose comme condition que l'attribution figure dans l'application et sur la page du magasin. Le § 3.1 du cahier ne retient que l'attribution dans l'application (« à aligner sur le libellé exigé s'il y en a un ») et le § 7.1 ne prévoit qu'une rubrique générique « crédits et licences ». Une fiche rédigée d'après ce cahier omettrait la mention et romprait l'accord dès la mise en ligne.

**Preuve.** tools/relais_vol/README.md:27-29 « l'attribution « Données aéronautiques : OpenSky Network (opensky-network.org) » figure dans l'application **et sur la page du magasin** » ; ZMANIM.md:326-328 (même condition). PUBLICATION_PLAY_STORE.md:138-140 et :475 : aucune occurrence de « magasin » dans le fichier.

**Correction proposée.** Ajouter au § 7.1 une ligne obligatoire pour les deux descriptions longues, reprise des chaînes de l'application. en-US : « Aircraft data: OpenSky Network (opensky-network.org). Flight routes: adsbdb.com (data by David J. Taylor and Jim Mason). » ; iw-IL : « נתוני כלי טיס: OpenSky Network ‏(opensky-network.org). מסלולי טיסה: adsbdb.com (נתונים של David J. Taylor ו־Jim Mason). »

**Note du contre-expert.** tools/relais_vol/README.md:27-29 et ZMANIM.md (paragraphe sur les conditions d'OpenSky) exigent l'attribution dans l'application « et sur la page du magasin ». Le mot « magasin » est absent de PUBLICATION_PLAY_STORE.md : le § 3.1 ne parle que de l'attribution dans l'app, et le § 7.1 d'une rubrique générique « crédits et licences ». Les réécritures proposées reprennent mot pour mot vol_source_opensky et vol_source_adsbdb en anglais et en hébreu.

### TPLAYDOCS-10 — README et ZMANIM.md affirment encore « aucun accès réseau » et « aucune donnée collectée », à l'inverse du manifeste et du § 6.2

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : docs · **Type** : texte

**Constat.** Quatre passages décrivent une application sans réseau qui n'existe plus dans l'édition complète. Le README annonce INTERNET « pour une seule fonction » alors qu'il y en a deux, et dit que l'indicatif reste sur le téléphone alors que le numéro de vol est envoyé à adsbdb. Il présente l'absence d'accès réseau comme une propriété actuelle. Sa liste Play demande de remplir le formulaire Sécurité des données par « aucune donnée collectée », quand le § 6.2 du cahier impose de déclarer la position approximative et le numéro de vol : suivre le README mènerait à une déclaration fausse, motif classique de rejet. ZMANIM.md répète que l'application « ne déclare toujours aucune permission Internet ».

**Preuve.** README.md:152 « ### Aucune donnée ne sort de l'appareil », :156-159 « déclare INTERNET pour une seule fonction […] l'indicatif du vol reste sur le téléphone », :229-230 « une propriété que l'application tient aujourd'hui, ne demander aucun accès réseau », :272 « Formulaire Sécurité des données, à remplir « aucune donnée collectée » ». ZMANIM.md:19-20. android/app/src/full/AndroidManifest.xml:17 INTERNET ; RouteVol.kt:19 « https://api.adsbdb.com/v0 », :79 « demande("callsign/…") ». PUBLICATION_PLAY_STORE.md:375.

**Correction proposée.** README § à renommer « Ce qui sort de l'appareil » : « Rien par défaut. L'édition complète déclare INTERNET pour deux services de vol, derrière un seul interrupteur désactivé par défaut : le suivi en direct (OpenSky : une zone d'environ 10°, l'indicatif reste sur le téléphone) et la route d'un numéro de vol (adsbdb : le numéro saisi est envoyé). » Ligne 229-230 : supprimer « ne demander aucun accès réseau ». Ligne 272 : « Formulaire Sécurité des données : position approximative et numéro de vol, facultatifs (PUBLICATION_PLAY_STORE.md § 6.2) ». ZMANIM.md:19-20 : « l'édition Light ne déclare aucune permission Internet ; l'édition complète ne la déclare que pour les services de vol ».

**Note du contre-expert.** Les passages cités sont tous là : README:152 (titre), :156 (« pour une seule fonction ») et :159 (« l'indicatif reste sur le téléphone », sans un mot d'adsbdb), :229-230 et :272 (« aucune donnée collectée »), ZMANIM.md:19-20 (« aucune permission Internet »). Le manifeste full déclare INTERNET, et RouteVol envoie le numéro saisi à api.adsbdb.com (callsign/…). Le § 6.2 du cahier impose de déclarer la position approximative et le numéro de vol.

### TPLAYDOCS-11 — Note aux examinateurs : chemin faux (« Accueil → autorisations ») et texte en français pour une fiche en-US

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : play · **Type** : texte

**Constat.** La note du § 7.3 envoie l'examinateur à l'accueil, où il n'y a ni autorisations, ni choix d'applications, ni bouton d'aperçu : tout est dans l'onglet Réglages. Elle demande aussi d'accorder l'accès aux données d'utilisation et de choisir une application, alors que l'aperçu n'exige que l'affichage par-dessus les autres applications. Elle est rédigée en français, avec un libellé français, pour une fiche dont la langue par défaut est l'anglais. Un examinateur qui ne trouve pas la fonction déclarée refuse ou retarde la revue. Le § 6.5 et le README portent la même localisation périmée.

**Preuve.** PUBLICATION_PLAY_STORE.md:504-508 « Accueil → autorisations (affichage par-dessus les autres applications, accès aux données d'utilisation) → choisir une application → bouton « Voir l’écran « Je suis avec Hachem » maintenant » ». activity_settings.xml:216-249 (carte « État du mode », bouton preview_gate), :306, :475-487. SettingsActivity.kt:220-229 : previewGate ne vérifie que Permissions.canDrawOverlays. README.md:31-36 « L'écran principal affiche en permanence l'état de la barrière […] Un bouton affiche l'écran de blocage ».

**Correction proposée (revue par le contre-expert).** No account or login is needed. To see the gate at any time of day: open the Settings tab, card “Mode status”, and tap “Preview the ‘I am with Hashem’ screen now”. The first time, an in-app disclosure explains the permission: tap “Continue”, allow “Display over other apps” in Android, come back and tap the button again. The screen then appears with the badge “PREVIEW, NO EFFECT”. To see it act for real: in Settings, under “Required permissions”, grant “Display over other apps” and “Usage access”; turn on “I am with Hashem”; tap “Choose apps” and pick one app; set “Mode hours” around the current time; then open that app. The gate is a self-discipline tool that users set up on their own phone and can switch off at any time. No usage data leaves the device.

**Note du contre-expert.** Le chemin est bien faux. activity_main.xml n'a ni état du mode, ni autorisations, ni aperçu : tout est dans Réglages (section_gate_state:218, preview_gate:244, section_permissions:477), et previewGate (SettingsActivity:220-229) n'exige que l'affichage par-dessus. README:31-36 porte la même localisation périmée. En revanche, le reproche d'une note « en français » est à retirer : le cahier (:512-513) prévoit déjà de la traduire en anglais. La note proposée omet aussi le bouton « Continue » de la divulgation.

### TPLAYDOCS-12 — Le README présente un suivi d'habitudes générique comme « la version web » et ignore le site iPhone, le .jar Nokia et le dossier play/

**Gravité** : majeur · **Contre-expertise** : confirmé · **Plateforme** : docs · **Type** : texte

**Constat.** Le README s'ouvre sur « Deux applications » : android/ et index.html. Or index.html est une page « Suivi d'habitudes intelligent » sans une seule occurrence de « hitboded », qui charge Tailwind, Lucide et Google Fonts depuis trois domaines tiers. La vraie version web (web/, application installable sur iPhone, déployée dans son propre dépôt) n'est mentionnée nulle part, pas plus que nokia/ ni play/. La dernière « limite connue » dit « Android uniquement ». Un lecteur du README se fait une idée fausse du produit : il y a aujourd'hui quatre livrables (Android complet, Android Light, site iPhone, .jar Nokia).

**Preuve.** README.md:3 « Deux applications autour d'une même pratique quotidienne. », :8 « `index.html` | Version web autonome : suivi d'habitudes dans le navigateur », :293 « **Android uniquement.** », :296-305. index.html:6 « &lt;title>Suivi d’habitudes intelligent&lt;/title> » ; 0 occurrence de « hitboded ». web/README.md:1 « # MyHitbodedut pour iPhone » ; nokia/README.md:1 « # MyHitbodedut pour téléphone à touches ».

**Correction proposée (revue par le contre-expert).** Réécrire l'en-tête comme proposé, avec android/ (éditions complète et Light), web/, nokia/, play/ et tools/. Remplacer « Android uniquement » par « La barrière n'existe que sur Android ». Proposer au propriétaire, plutôt que l'imposer, la suppression de index.html et de la section « La version web », car ce fichier orphelin peut avoir une raison d'être non documentée.

**Note du contre-expert.** README:3 et :8 présentent bien deux applications, dont index.html, qui porte le titre « Suivi d’habitudes intelligent », ne contient aucune occurrence de « hitboded », appelle cdn.tailwindcss.com, cdn.jsdelivr.net et fonts.googleapis.com, et qu'aucun flux ne référence. Le README ne nomme ni web/, ni nokia/, ni play/ ; le site n'y apparaît qu'en passant (« Le web, lui, passe par un relais », :160). Le dépôt principal étant désormais public, ce README est en vitrine.

### TPLAYDOCS-13 — Aucune notice de licence pour KosherJava (LGPL 2.1) ni pour ZXing dans l'application Android ni dans le cahier

**Gravité** : majeur · **Contre-expertise** : confirmé en partie · **Plateforme** : android · **Type** : texte

**Constat.** L'application Android embarque KosherJava (LGPL 2.1) et ZXing (Apache 2.0). Le dossier des licences de l'APK ne contient que les six polices, aucun écran ne cite KosherJava, et le § 3.3 du cahier, qui passe en revue les droits, ne traite que des textes, des villes et des polices. La LGPL demande au minimum une mention visible de la bibliothèque et le texte de sa licence. Elle demande aussi de pouvoir remplacer la bibliothèque, ce que la version publiée, réduite et renommée par R8 dans un dépôt privé, ne permet pas. Le site web, lui, a fait le nécessaire. La portée exacte de la LGPL sur une application Android réduite par R8 se discute ; l'absence de toute mention, elle, est un fait.

**Preuve.** android/app/build.gradle.kts : « implementation("com.kosherjava:zmanim:2.5.0") », « implementation("com.google.zxing:core:3.5.3") », release « isMinifyEnabled = true ». android/app/src/main/assets/licences : 6 fichiers OFL-*.txt seulement. Zmanim.kt:29 « const val MOTEUR = "KosherJava 2.5.0, NOAACalculator" », jamais lu pour l'affichage. ZMANIM.md:14 « LGPL 2.1 / LGPL 3.0 ». myhitbodedut-web/vendor/LICENCES.txt : « Le fichier reste un module séparé, remplaçable ». PUBLICATION_PLAY_STORE.md:247-255.

**Correction proposée (revue par le contre-expert).** Ajouter assets/licences/LGPL-2.1-KosherJava.txt et Apache-2.0-ZXing.txt (avec le NOTICE de ZXing s'il existe). Ajouter une ligne dans Réglages : « Calendrier et zmanim : KosherJava (LGPL 2.1) ; lecture des codes-barres : ZXing (Apache 2.0) », reprise dans la rubrique « crédits et licences » de la fiche, et compléter le § 3.3 par un tableau des bibliothèques. Pour la LGPL, indiquer dans la notice l'adresse publique du code source de l'application, tant que le dépôt reste public. S'il redevient privé, offrir le source sur demande écrite (LGPL 2.1 § 6) ; exclure KosherJava de R8 ne suffit pas.

**Note du contre-expert.** L'absence de mention est réelle. build.gradle.kts:217 et :225 embarquent KosherJava 2.5.0 et ZXing 3.5.3 ; assets/licences ne contient que six OFL ; aucune chaîne ni mise en page ne cite KosherJava, ZXing, la LGPL ou Apache, et Zmanim.MOTEUR n'est jamais affiché. Le site, lui, fournit vendor/LICENCES.txt. Un point est en revanche dépassé : le dépôt n'est plus privé (list_repos : myhitbo/MyHitbodedut « public »), ce qui donne accès au source complet et répond en bonne partie à l'exigence de remplacement de la LGPL 2.1. Le -keep R8 proposé n'apporte rien à cette exigence.

### TPLAYDOCS-14 — README : onze affirmations vérifiables périmées (durée par défaut, musique, illustrations, autorisations, SDK…)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : docs · **Type** : texte

**Constat.** Confrontées au code, onze affirmations du README sont fausses aujourd'hui. (1) Durée par défaut « soixante minutes » : 15. (2) Question de l'écran « Tu as fait ta hitbodedout ? » : « Avez-vous fait votre hitbodedout ? ». (3) État de la barrière, liste des autorisations et bouton d'aperçu sur « l'écran principal » : ils sont dans Réglages. (4) Chabbat détecté « par le jour de la semaine » : le calendrier hébraïque détecte aussi les fêtes. (5) « Un morceau livré », 9,3 Mo en 320 kbps, non réencodé : 26 morceaux (56 hors Play), AAC, 2,98 Mo pour celui-là. (6) « Vingt images, 492 Ko » : 50 fichiers, 1,54 Mo. (7) Tableau des autorisations sans la position exacte, « Ne pas déranger » ni INTERNET. (8) « plateforme 35 » : 36. (9) Édition Light, permissions sensibles « Aucune » : elle hérite de la localisation approximative et exacte. (10) Case « Politique de confidentialité en ligne » non cochée : la page est rédigée et présente dans le site construit. (11) « Rappel quotidien », au singulier : plusieurs heures de rappel. La fenêtre 06:00–11:00 et le sondage à 900 ms sont exacts.

**Preuve.** README.md:23, :17, :31-36 et :131-132, :40, :73 et :86-87, :93, :121-128, :183, :190, :270-271, :44. Store.kt:168-174 « DEFAULT_START = 6 * 60 … DEFAULT_TARGET = 15 » ; values/strings.xml:137 ; Store.kt:633 « Holidays.isRestDay(date, inIsrael(context)) » ; main/res/raw/hamelech_basade.m4a : 2 976 053 octets ; res/drawable-nodpi : 50 fichiers, 1 541 132 octets ; main/AndroidManifest.xml:10, :16, :20 ; build.gradle.kts « compileSdk = 36 » ; GateService.kt:245 « POLL_MS = 900L ».

**Correction proposée.** Corriger les onze points d'après les valeurs ci-dessus, et retirer du README les chiffres qui dérivent (tailles, nombres de fichiers) au profit d'un renvoi au code ou à un test.

### TPLAYDOCS-15 — Musique : nombres de morceaux et tailles contradictoires dans le cahier Play et trois autres documents

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : docs · **Type** : texte

**Constat.** État réel : la version Play livre 26 morceaux (70,3 Mo d'audio), la version GitHub et le site 56 (146,2 Mo). Le cahier donne, selon l'endroit, « 33 morceaux (130 Mo) », « 2 morceaux », « environ 16 Mo », « environ 78 Mo », un AAB « de 28,5 Mo », et sa décision n° 2 dit encore que Play ne livre que le niggoun du Yanuka et המלך בשדה. Il annonce « 31 autres » morceaux hors Play (30) et un morceau d'Ishay Ribo « livré » sur GitHub alors qu'il a quitté l'application et le site le 29/10. Le plan du site parle de 33 niggounim, le README Nokia de 124 Mo, musique/README.md de 85 Mo. Le cahier sert de base aux déclarations de droits : son tableau doit dire ce que l'AAB contient.

**Preuve.** PUBLICATION_PLAY_STORE.md:31, :58-59, :204, :223-224, :231, :235, :236-237, :602-604. web/PLAN_DU_SITE.md:68 « 33 niggounim » ; nokia/README.md:22 « Les 124 Mo de musique » ; musique/README.md:7 « de 130 à 85 Mo ». Mesures : main/res/raw, 26 fichiers .m4a, 70,3 Mo ; src/musique_hors_play/res/raw, 30 fichiers, 75,9 Mo ; myhitbodedut-web/musique, 56 fichiers, 146,2 Mo ; MusiqueHorsPlay.kt:5-6 « Ishay Ribo, sans accord, a quitté l'application et le site le 29/10 ».

**Correction proposée.** Dans le cahier, remplacer chaque chiffre par l'état du 03/11 : « Play : 26 morceaux (Yanuka 1, המלך בשדה 1, Noam Shpayer 10, Ianir 14), environ 70 Mo ; GitHub et site : 56 morceaux, environ 146 Mo » ; corriger la ligne Ribo (« Retiré partout le 29/10 ») et la décision n° 2 ; reconstruire l'AAB et noter sa taille réelle. Aligner les trois autres documents ou y renvoyer à tools/inventaire_musique.py.

### TPLAYDOCS-16 — Visuels montrant un état antérieur de l'interface : lignes grisées de la bibliothèque (3 langues) et bouton gris de l'écran de garde

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : play · **Type** : texte

**Constat.** Le visuel 09 montre « Tefilot » et « Conseils pour la hitbodedout » grisés, comme indisponibles, dans les trois langues. Le site a activé ces deux entrées le 02/11 et l'application Android les a toujours eues : la fiche sous-vendrait le produit. Le visuel français 11 montre l'écran de garde avec un bouton principal gris, rectangulaire, en majuscules, et « Je l'ai déjà faite » sans contour ; le code a corrigé ce défaut le 02/11 et le dit en commentaire. Les visuels, commités le 04/11, n'ont pas été refaits.

**Preuve.** play/visuels/en/09-textes-en.png : « Tefilot » et « Tips for Hitbodedut » estompés (idem fr/09 et he/09). web/src/app.css:235 « .a-venir { opacity: 0.45; pointer-events: none; } » ; plus aucun « aVenir: true » dans web/src/js/app.js depuis le commit 75dfaa0 du 02/11 « Site : livres rapides, Journal, Conseils, Tfilot… ». play/visuels/fr/11-ecran-je-suis-avec-hachem.png : « COMMENCER MAINTENANT, 15 MIN ». view_blocker.xml:80-82 « MaterialButton en toutes lettres (02/11) […] un &lt;Button> restait le bouton gris d'Android, en majuscules ».

**Correction proposée.** Refaire 09 dans les langues publiées et 11 sur une construction actuelle ; noter dans le cahier, à côté de chaque jeu de visuels, le commit dont il est tiré.

### TPLAYDOCS-17 — Premier visuel hébreu : le compteur d'étape est brouillé (« מתוך 7 1 » au lieu de « 1 מתוך 7 »)

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : play · **Type** : texte

**Constat.** Sur le premier visuel de la fiche hébraïque, la pastille d'étape place le mot « מתוך » à droite et les chiffres « 1 7 » à gauche. Un lecteur hébréophone lit « מתוך 7 1 ». Le site actuel affiche correctement « 1 מתוך 7 » (capture Chromium du jour faite par un autre auditeur) : le défaut vient de la fabrication du visuel, rendu dans un contexte de gauche à droite, et non de l'application.

**Preuve.** play/visuels/he/01-presentation-he.png, pastille en haut à droite du cadre (recadrage : …/audit/tplaydocs/he01-badge.png). values-iw/strings.xml:184 « %1$d מתוך %2$d ». Rendu correct du site : …/audit/web-live/premier/iphone-he-p1.png (recadrage : …/audit/tplaydocs/he-p1-badge-actuel.png).

**Correction proposée.** Recapturer he/01 sur l'application réglée en hébreu (document en dir="rtl"), puis relire les dix visuels hébreux à la recherche de nombres déplacés.

### TPLAYDOCS-18 — Cahier Play : « 6 widgets » (il y en a 5), source des captures périmée, textes des services « mot pour mot » qui sont des traductions

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : docs · **Type** : texte

**Constat.** Trois inexactitudes dans le cahier lui-même. Il annonce deux fois « 6 widgets », dont une case de recette « Les 6 widgets posés et mis à jour » impossible à cocher : le manifeste en déclare cinq. Le § 7.2 donne encore captures-calendrier/ comme source des captures « à compléter », alors que play/visuels existe depuis le 04/11. Le § 6.6 affirme que ses descriptions de services de premier plan reprennent « mot pour mot » celles des manifestes : les manifestes sont en anglais, le cahier en donne une traduction française, et celle de la barrière perd « morning ». La déclaration se saisit en anglais.

**Preuve.** PUBLICATION_PLAY_STORE.md:35 « 6 widgets », :543 « Les 6 widgets posés et mis à jour », :495 « `captures-calendrier/`, à compléter », :418-419 « reprennent mot pour mot ». main/AndroidManifest.xml : 5 « android.appwidget.provider » (ZmanimWidget, ZmanimPetitWidget, ZmanimGrandWidget, BoussoleWidget, StreakWidget) ; :371 « Runs the countdown of a user-started meditation session and shows the remaining time, so the phone can be put down. » ; full/AndroidManifest.xml « …during a user-defined morning window, until the user confirms their daily practice. »

**Correction proposée.** Écrire « 5 widgets (zmanim ×3, boussole, série) » aux deux endroits ; § 7.2 : « play/visuels/en et play/visuels/he » ; § 6.6 : coller dans le tableau les deux phrases anglaises des manifestes.

### TPLAYDOCS-19 — promo-screenshots : sept captures du 28/09 aux libellés abandonnés, fusionnées le 05/11

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : docs · **Type** : texte

**Constat.** Les captures du « film promo » ont été produites le 28/09 et fusionnées telles quelles le 05/11. Elles montrent le mot « session » partout (« Start a 20 min session », « Another session », « 34 sessions »), remplacé depuis par « hitbodedut », et une barre de quatre onglets « Today, Texts, Journal, Settings » alors que l'application en a cinq (« Library », plus « Zmanim »). Un film monté dessus montrerait une application qui n'existe plus.

**Preuve.** promo-screenshots/01-home-start.png « Start a 20 min session », onglets « Today / Texts / Journal / Settings » ; 05-session-running.png « 20 min session » ; 07-home-done.png « Another session ». values-en/strings.xml:72 « Start a %1$s hitbodedut », :73 « Another hitbodedut », :142 « %1$s hitbodedut », :401 « Library » ; res/menu/nav_main.xml : cinq entrées dont nav_zmanim. Historique : « ac089e2 2026-09-28 Promo screenshots from run 5 ».

**Correction proposée.** Relancer tools/promo_screenshots.sh sur main avant tout montage, ou supprimer le dossier ; le script demande encore la plateforme Android 35 dans promo-screenshots.yml.

### TPLAYDOCS-20 — tikkun_haklali.html : page héritée orpheline, avec une note de travail et une consigne de récitation qu'elle dit elle-même non vérifiée

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : docs · **Type** : texte

**Constat.** Cette page hébraïque à la racine n'est citée par aucun document ni publiée par aucun flux. Elle garde en tête une note de travail adressée à un lecteur précis, à la première personne, qui reconnaît que la seule pause indiquée « n'a pas été vérifiée de façon indépendante ». Elle insère pourtant cette pause au milieu d'un verset du psaume 32, avec une référence présentée comme source. L'application, depuis le 04/11, donne le Tikoun d'un seul tenant sur des textes vérifiés : la page contredit le produit et ne sert plus. Elle charge aussi des polices depuis Google.

**Preuve.** tikkun_haklali.html:283 « אין כאן "הפסקות לכוונה" בין המזמורים כפי שאולי ציפית […] נקודת ההפסק היחידה שמצאתי מתועדת […] ומקורה לא אומת באופן עצמאי » ; :326 « אַתָּה סֵתֶר לִי ⏸ הפסק מִצַּר תִּצְּרֵנִי » ; :331 « מקור: ליקוטי מוהר"ן ח"א סימן רי"ג (מובא באתרי ברסלב) » ; :7-9 fonts.googleapis.com. Aucune occurrence de « tikkun_haklali.html » dans README, FEUILLE_DE_ROUTE, PUBLICATION ni .github. FEUILLE_DE_ROUTE.md:1111 « Tikkoun haKlali d'un seul tenant ».

**Correction proposée.** Supprimer tikkun_haklali.html du dépôt (l'historique git la conserve).

### TPLAYDOCS-21 — READMEs Nokia : dépôt cible d'un autre compte, lien public vers un dépôt privé, tailles dépassées

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : nokia · **Type** : texte

**Constat.** Le README du dossier nokia/ nomme comme dépôt de publication un compte (avrahamohayon02102001) qui n'est ni celui du dépôt principal qu'il cite (hil123) ni l'origine actuelle du clone (myhitbo). Le README publié avec le .jar, lisible par tous, renvoie à hil123/MyHitbodedut : ce dépôt est privé, le lien donne une page introuvable à tout lecteur. Deux tailles sont dépassées : le .jar pèse 670 Ko et non « environ 600 Ko », et la musique de l'application 146 Mo et non 124. Le .jar publié est à jour (1.5.67, manifeste MIDP 2.0 / CLDC 1.1 conforme au README).

**Preuve.** nokia/README.md:3 « [avrahamohayon02102001/Nokia-my-hitbodedut-app](https://github.com/avrahamohayon02102001/…) […] comme le site iPhone l'est dans hil123/myhitbodedut-web », :5 « environ 600 Ko, dont 510 Ko pour le niggoun d'essai », :22 « Les 124 Mo de musique ». Nokia-my-hitbodedut-app/README.md:5 « reconstruit automatiquement depuis [hil123/MyHitbodedut](https://github.com/hil123/MyHitbodedut) » ; README.md:169 « dépôt privé ». MyHitbodedut.jar : 686 208 octets ; origine du clone : github.com/myhitbo/Nokia-my-hitbodedut-app.

**Correction proposée.** nokia/depot/README.md : « Il est reconstruit automatiquement à chaque modification de l'application ; ne pas le modifier à la main. » (sans lien vers le dépôt privé). nokia/README.md : nommer le dépôt réel, écrire « environ 670 Ko » et « La musique de l'application (146 Mo) ».

### TPLAYDOCS-22 — La version Play portera un numéro sans rapport avec la version GitHub du même code

**Gravité** : mineur · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : play · **Type** : fonction

**Constat.** Les deux flux tirent le numéro de version de github.run_number, qui est un compteur propre à chaque flux. Le premier AAB Play s'appellera donc « 1.1 » alors que l'APK GitHub du même commit porte un numéro bien plus élevé (le README cite déjà v1.12 en septembre). Le § 5.3 du cahier juge la numérotation correcte « tant qu'un seul flux produit les AAB Play » et demande de « garder 1.N » sans voir que N diffère. Conséquences : l'écran Réglages affichera une version « plus ancienne » sur Play, ce qui brouille le support et la note de migration GitHub → Play prévue au § 5.1.

**Preuve.** .github/workflows/android.yml:66 et play.yml:65 « VERSION_CODE: ${{ github.run_number }} » ; android.yml:120 « gh release create "v1.${{ github.run_number }}" » ; build.gradle.kts:18-19 « versionCode = 1 + build / versionName = "1.$build" » ; SettingsActivity.kt:87-89 (affichage de VERSION_NAME) ; PUBLICATION_PLAY_STORE.md:313-315.

**Correction proposée.** Donner au flux Play un nom de version explicite et lisible, par exemple versionName « 2.N » (ou « 1.N-play ») par une propriété Gradle, en gardant versionCode = 1 + run_number ; l'écrire au § 5.3.

### TPLAYDOCS-23 — Légendes françaises : « Tikkoun » et « Nigounim » ne suivent pas l'orthographe de l'interface montrée dans la même image

**Gravité** : cosmétique · **Contre-expertise** : non contre-expertisé (mineur) · **Plateforme** : play · **Type** : texte

**Constat.** Deux légendes du jeu français s'écartent des graphies de l'application visibles juste en dessous. Le visuel 09 écrit « Tikkoun HaKlali » au-dessus d'un écran qui affiche « Tikoun HaKlali ». Le visuel 10 écrit « Nigounim » au-dessus d'une liste de « Niggoun 01, 02… » ; les chaînes françaises emploient « niggoun » 40 fois et jamais « nigoun ». Les légendes anglaises et hébraïques sont cohérentes avec leur interface.

**Preuve.** play/visuels/fr/09-textes.png « Siddour, Tehilim, Tikkoun HaKlali, livres de Rabbi Na’hman. » ; play/visuels/fr/10-musique.png « Nigounim livrés avec l’application, qui s’arrêtent en fondu à la fin. ». values/strings.xml:445 « Tikoun HaKlali », :294 « Niggoun 01 ».

**Correction proposée.** Légende 09 : « Siddour, Tehilim, Tikoun HaKlali, livres de Rabbi Na’hman. » Légende 10 : « Niggounim livrés avec l’application, qui s’arrêtent en fondu à la fin. »
