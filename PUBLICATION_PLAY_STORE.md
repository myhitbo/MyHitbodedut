# Cahier des charges — publication sur Google Play

Rédigé le 29/10/2026, à partir de l'état du dépôt à `e21d72e` et des pages
officielles de Google lues le même jour. Ce fichier existe pour que la
publication ne vive pas dans une conversation.

Chaque affirmation porte un statut :

- **Vérifié** — lu dans le code du dépôt, ou dans une page Google / OpenSky
  citée en fin de document.
- **Déduit** — conséquence raisonnée de ce qui est vérifié, à confirmer dans la
  Play Console au moment de la saisie.
- **Supposé** — hypothèse de travail, à trancher par le propriétaire.

---

## 1. Objet et périmètre

**Objet.** Publier l'application Android `com.myhitbodedut` sur Google Play,
avec toutes ses fonctions, et remplacer à terme la distribution par GitHub
Releases + Obtainium (README, « Mettre à jour »).

**Dans le périmètre** : l'édition **complète** (`full`), barrière du matin
comprise, et ce qu'elle contient (vérifié, `AndroidManifest.xml` et
`src/full/AndroidManifest.xml`) :

| Domaine | Fonctions |
| --- | --- |
| Hitbodedout | Séance minutée en service de premier plan, sujet facultatif, hitbodedout guidée, « je ne sais pas quoi dire », journal, parcours, paliers et trophées, célébration |
| Barrière du matin | `GateService` + `BlockerView` sur les applications choisies (`AppPickerActivity`), fenêtre horaire, report, Shabbat / fête |
| Musique | 26 morceaux livrés dans la version Play (§ 3.2), morceaux ajoutés par le sélecteur de fichiers, lecture écran éteint |
| Textes | Siddour, Tehilim, Tikoun haKlali, Likoutei Tefilot par sujet, 'hizouk, bibliothèque, livres, Halakha (Yalkout Yossef), hilloulot, recherche globale |
| Calendrier | Zmanim (KosherJava), calendrier hébraïque, Birkat haLevana, alerte « Chabbat dans 3 h », boussole vers Jérusalem |
| Vol | Zmanim et prières en vol, rappels (Tefilat haDerekh, Omer), **route d'un numéro de vol (adsbdb)** ; le suivi en direct (OpenSky) n'est pas dans la version Play tant qu'il n'y a pas de relais (§ 3.1) |
| Système | 5 widgets (zmanim ×3, boussole, série), rappels quotidiens, « Ne pas déranger » pendant la séance, partage d'un jour en image, sauvegarde JSON, 3 langues (fr, en, he) |

**Hors périmètre** :

- **Édition `light`** — sa raison d'être est Play Protect hors boutique (README,
  « Deux éditions »). Sur Play, ce motif disparaît. Elle reste un **plan de
  repli** si la revue refuse la barrière (§ 9). *Déduit.*
- **Version web** (`myhitbodedut-web`) — publiable plus tard comme Trusted Web
  Activity, sujet distinct.
- **Version Nokia** (`MyHitbodedut.jar`, J2ME) — ce n'est pas une application
  Android, Google Play ne la distribue pas. *Déduit.*
- Toute monétisation (achat, publicité, abonnement) — voir § 6.3, la licence
  CC BY-NC-SA du Yalkout Yossef l'interdit en pratique.

---

## 2. État des lieux technique

| Élément | Valeur dans le dépôt | Exigence Play | Statut |
| --- | --- | --- | --- |
| `targetSdk` | **36** depuis le 29/10 (était 35) | **36** pour toute nouvelle app depuis le 31/08/2026 ; prolongation possible jusqu'au 01/11/2026 seulement | **Fait** — compilé et testé ; reste l'essai sur appareil (§ 2.1) |
| `compileSdk` | 36, avec le plugin Android 8.11.1 (était 8.7.3) | ≥ `targetSdk` | **Fait** |
| `minSdk` | 26 | aucune contrainte | OK |
| Format | APK pour GitHub ; **AAB** pour Play (`-Pplay=true bundleFullRelease`, flux `play.yml`) | **AAB** obligatoire pour une nouvelle app | **Fait** — AAB construit le 29/10 (28,5 Mo avec 3 morceaux) ; à reconstruire avec les 26 morceaux du 03/11 et sa taille réelle à noter |
| Taille | `res/raw` ≈ 110 Mo (82 Mo d'audio AAC pour la version GitHub, 30 Mo de JSON) ; version Play : 26 morceaux, environ 70 Mo d'audio (état du 03/11) ; version GitHub et site : 56 morceaux, environ 146 Mo | Module de base ≤ 500 Mo compressés ; au-delà de 200 Mo, avertissement non bloquant en données mobiles | OK — vérifié |
| Bibliothèques natives | aucune `.so` | page mémoire 16 Ko exigée pour les `.so` ciblant API 35+ | Sans objet — vérifié |
| Signature | clé de dev pour GitHub ; `play.yml` exige la clé d'envoi (secrets `PLAY_*`) et refuse un AAB signé par la clé de dev | clé d'envoi privée + Play App Signing | **Reste à faire par le propriétaire** : créer la clé et les secrets (§ 5.1, § 5.2) |
| `versionCode` | `1 + github.run_number` | strictement croissant | OK, à garder |
| R8 / réduction | activés en release | — | OK ; garder le fichier de correspondance (§ 5.4) |
| Écran de relecture | masqué hors `BuildConfig.DEBUG` | pas de fonction cachée en production | OK — vérifié |
| `usesCleartextTraffic` | `false` (full) | — | OK |

### 2.1 Passage à `targetSdk 36` — ce qu'il faut éprouver

Changer le chiffre ne suffit pas : Android 16 modifie des comportements que
l'application utilise. À tester sur un appareil Android 16 réel, en plus de la
liste déjà notée dans la feuille de route (proposition 12) :

- l'affichage bord à bord, imposé sans possibilité de s'y soustraire *(déduit
  des notes de version Android 15/16, à vérifier écran par écran)* ;
- les grands écrans : Android 16 ignore les restrictions d'orientation et de
  redimensionnement au-delà de 600 dp ; `CelebrationActivity` déclare des
  `configChanges`, à vérifier en tablette et en fenêtre libre ;
- les services de premier plan `specialUse` et `mediaPlayback` démarrés depuis
  une notification ou une alarme ;
- l'overlay `TYPE_APPLICATION_OVERLAY` et la lecture `UsageStatsManager`
  après redémarrage, économie de batterie, autorisation retirée en cours de
  séance.

**Fait le 29/10** (vérifié par compilation, 570 tests unitaires et lint) :

- **Plein écran** : `Barres.kt`, posé pour tous les écrans par
  `Apparence.installer`. Chaque écran est affiché sous les barres sur toutes
  les versions d'Android, puis reçoit en marge intérieure la place des barres,
  de la découpe et du clavier ; la bande du haut garde la couleur de barre
  d'état de la palette. La dérogation `values-v35/themes.xml` est retirée, et
  `FiabiliteTest` interdit son retour.
- **Geste retour** : `android:enableOnBackInvokedCallback="false"` sur
  `<application>`, pour que l'écran de garde continue de recevoir la touche
  retour. Dérogation temporaire selon Google, à remplacer un jour par
  `OnBackInvokedCallback`.
- **Grands écrans** : rien à faire, l'application ne verrouille aucune
  orientation.

**Pas encore vérifié** : le rendu sur un appareil ou un émulateur Android 16.
Aucun émulateur n'était disponible ; c'est le premier point de la recette du
§ 8, avec un œil sur chaque écran (titres sous la barre d'état ? boutons
sous la barre de gestes ? clavier qui cache un champ ?).

**Critère d'acceptation** : `./gradlew -Pplay=true testFullDebugUnitTest
bundleFullRelease` passe (vrai le 29/10), et la recette du § 8 passe sur
Android 13, 14, 15 et 16.

---

## 3. Points bloquants hors code

Trois sujets empêchent une publication propre tant qu'ils ne sont pas tranchés.
Ils viennent avant tout le reste.

### 3.1 Suivi de vol en direct — licence OpenSky **(bloquant)**

Hors de Play, `SuiviVol.kt` interroge
`https://opensky-network.org/api/states/all` en accès anonyme. Les conditions
d'utilisation d'OpenSky (vérifié, page citée) :

> « Use of the REST API in any operational capacity — including integration
> into a live product, service, or automated system […] — requires a previous
> written agreement, even for non-profit or governmental entities. »

Une application publiée sur Google Play est un produit en service : il faut
l'accord écrit d'OpenSky.

**Réponse d'OpenSky (courriel du 28/10, ticket 837455)**, consignée dans
`tools/relais_vol/README.md` : usage gratuit et non commercial accordé, à
quatre conditions :

- [x] les données sont demandées **par le relais**, avec le client OAuth2 du
      compte, **et non par chaque téléphone** : l'accès anonyme que fait
      `SuiviVol.OpenSkyAnonyme` n'est **pas** couvert ;
- [x] les appareils d'une même zone partagent une réponse en cache,
      temporaire, sans archive (le relais : grille de 0,5°, 15 s) ;
- [x] pas de revente, de redistribution ni d'API (le relais ne rend que
      l'avion demandé) ;
- [ ] l'**attribution** « Données aéronautiques : OpenSky Network
      (opensky-network.org) » dans l'application (`vol_source_opensky`, fait)
      **et sur la fiche du magasin** (description complète, § 7.1).

**Décision appliquée le 12/11 (audit, TPLAYDOCS-01, FVOL-02).** La
construction Play (`-Pplay=true`) n'interroge jamais OpenSky depuis le
téléphone (`BuildConfig.OPENSKY_DIRECT = false`). `play.yml` passe la
variable de dépôt `RELAIS_VOL` en `-PrelaisVol` : tant que le relais n'est pas
en ligne, l'AAB n'a **pas de suivi en direct** (le bouton disparaît, la route
adsbdb reste, et l'écran d'accueil ne nomme plus OpenSky). Le jour où le relais
est en ligne, corriger `confidentialite.html` (l'indicatif part vers le relais :
« il n'a pas de serveur pour cette application » devient faux), la phrase
`onboarding_private_body` (« sans envoyer l'indicatif ») et les § 6.1 et 6.2,
avant d'envoyer l'AAB.

**Texte prêt pour les règles de confidentialité, le jour du relais** (audit
du 12/11, TWEBCONF-01). Il remplace le point « Suivi en direct » de la section
« Les vols », dans les trois langues ; dans « En bref », « il n'a pas de
serveur pour cette application » devient « sauf ce que reçoit le relais du
suivi de vol, décrit plus bas ».

- FR : « Suivi en direct, via un relais du développeur puis OpenSky Network
  (opensky-network.org) : lancé par un bouton. Le téléphone envoie au relais
  (un service hébergé chez Cloudflare et tenu par MyHitbodedut Team)
  l’indicatif du vol et la position estimée de l’avion, arrondie au dixième de
  degré. Le relais demande à OpenSky les avions de cette zone et ne renvoie
  que la position de l’avion cherché. Il ne garde ni l’indicatif ni la
  position envoyés : seulement la réponse d’OpenSky pour la zone, 15 secondes
  en mémoire. Cloudflare tient ses propres journaux techniques, dont l’adresse
  IP. »
- EN: “Live tracking, through a relay run by the developer, then OpenSky
  Network (opensky-network.org): started with a button. The phone sends the
  relay (a service hosted by Cloudflare and operated by MyHitbodedut Team) the
  flight’s callsign and the aircraft’s estimated position, rounded to a tenth
  of a degree. The relay asks OpenSky for the aircraft in that area and
  returns only the position of the aircraft you are looking for. It keeps
  neither the callsign nor the position you sent: only OpenSky’s answer for
  the area, for 15 seconds in memory. Cloudflare keeps its own technical logs,
  including the IP address.”
- HE : „מעקב בזמן אמת, דרך ממסר של המפתח ולאחר מכן OpenSky Network
  ‏(opensky-network.org): מתחיל בלחיצה על כפתור. הטלפון שולח לממסר (שירות
  המתארח ב־Cloudflare ומופעל בידי MyHitbodedut Team) את אות הקריאה של הטיסה
  ואת המיקום המשוער של המטוס, מעוגל לעשירית מעלה. הממסר מבקש מ־OpenSky את
  המטוסים באזור הזה ומחזיר רק את מיקום המטוס המבוקש. הוא אינו שומר את אות
  הקריאה ואת המיקום שנשלחו, אלא רק את תשובת OpenSky לאזור, 15 שניות בזיכרון.
  ל־Cloudflare יומנים טכניים משלה, ובהם כתובת ה־IP.”

Le même jour : § 6.2 (position approximative), l'attribution OpenSky sur la
fiche (§ 7.1) et l'en-tête de `play/CONSOLE.md`.

Conserver l'écrit hors dépôt, avec ceux des ayants droit (§ 3.2) : Google ou
OpenSky peuvent le demander.

**Route d'un numéro de vol (adsbdb) — décision du 29/10 : conservée, après
vérification.** Ce qu'on a trouvé le 29/10 (vérifié, adsbdb.com et dépôt
GitHub `mrjackwills/adsbdb`) :

- pas de conditions d'utilisation publiées : API publique, gratuite, sans
  compte, seulement des limites de débit (512 requêtes par minute avant
  blocage de 60 s). `RouteVol` ne fait qu'une requête par toucher, loin du
  seuil ;
- le logiciel est sous licence MIT ;
- **les routes elles-mêmes** sont l'œuvre de David J. Taylor et Jim Mason, et
  « may not be copied, published, or incorporated into other databases
  without the explicit permission of David J Taylor ».

Afficher à l'utilisateur la route du vol qu'il demande n'est ni une copie de
la base ni une base concurrente. `RouteVol` ne stocke aucune route, et
l'attribution est déjà affichée (`vol_source_adsbdb`). *Déduit : lecture
raisonnable, pas un avis juridique.* Deux règles en découlent :

- ne jamais ajouter de cache ou de liste de routes embarquée construite à
  partir d'adsbdb ;
- facultatif mais prudent : un courriel au mainteneur d'adsbdb décrivant
  l'usage (une requête au toucher, attribution affichée), dont la réponse
  rejoint les autres écrits.

**Conséquence pour Play.** L'édition complète garde la permission
`INTERNET`. Tant qu'il n'y a pas de relais, le formulaire Sécurité des données
déclare le seul envoi du numéro de vol à adsbdb (§ 6.2), et les règles de
confidentialité le décrivent (§ 6.1).

### 3.2 Droits sur la musique livrée **(bloquant à la revue)**

56 morceaux sont embarqués dans la version GitHub et le site (26 dans la version Play, environ 70 Mo ; 146 Mo en tout), dont des enregistrements du Yanuka, d'Ishay Ribo,
Motty Steinmetz, MBD (feuille de route, lignes 242–243). Les autorisations
sont **déclarées** par le propriétaire (« j'ai obtenu les autorisations
légales des ayants droit »), mais aucun écrit n'est dans le dépôt.

Google Play retire une application sur simple réclamation d'un ayant droit, et
peut suspendre le compte en cas de récidive. *Déduit de la politique de
propriété intellectuelle de Play.* La distribution passe d'un cercle restreint
(dépôt privé) au public mondial : c'est une diffusion plus large que celle
pour laquelle les droits ont été évoqués, la même remarque que la feuille de
route faisait au sujet d'un hébergement public.

**Exigence** : pour chaque morceau livré, un écrit de l'ayant droit couvrant
« distribution publique gratuite dans une application mobile, via Google
Play, monde entier », conservé hors dépôt et produit à la première demande de
Google. À défaut, retirer le morceau de la version Play ; l'utilisateur peut
toujours l'ajouter depuis son téléphone (`MusicActivity` → `OpenDocument`).

**Décision du 29/10.** Le propriétaire a l'accord du Yanuka. La provenance
des 30 niggounim sans titre (`niggoun_01` à `niggoun_33`) est inconnue : leurs
noms hébreux ont été perdus au transfert. *המלך בשדה* est déclaré libre de
droits ; l'autorisation d'Ishay Ribo et de MBD n'a pas été demandée. D'où, **pour la version Play seulement** :

| Morceau livré | Version Play | Version GitHub |
| --- | --- | --- |
| `yanuka_nigoun_3` — ניגון — הינוקא (3) | **Livré** (accord du Yanuka, à conserver par écrit) | Livré |
| `niggoun_01` … `niggoun_33` (30 fichiers) | **Retirés** tant que la provenance n'est pas établie | Livrés |
| `hamelech_basade` — המלך בשדה | **Livré** — déclaré libre de droits par le propriétaire (29/10) ; voir la réserve ci-dessous | Livré |
| `ribo_sans_titre` — Ishay Ribo | **Retiré** — autorisation non demandée (29/10), comme pour MBD | Retiré partout le 29/10 (application et site) |
| `shpayer_beyond` — Beyond — נעם שפייר | **Livré** (accord écrit, 29/10) | Livré |
| `shpayer_*` (9 autres morceaux, dont 2 avec Or Shpayer) et `ianir_*` (14 morceaux) — **נעם שפייר** et **יניר קילינסקי** | **Livrés** le 03/11 (accord écrit du 29/10 couvrant toutes leurs musiques) | Livrés, ainsi que dans la version web |

**Réserve sur המלך בשדה.** Une mélodie traditionnelle peut être libre alors
que son **enregistrement** ne l'est pas : l'interprète et le producteur ont
leurs propres droits. Noter d'où vient ce fichier (interprète, source, date)
et ce qui le rend libre ; c'est ce que Google demanderait en cas de
réclamation.

**נעם שפייר et יניר קילינסקי** : accord écrit couvrant toutes leurs musiques,
à conserver hors dépôt avec les autres écrits. Les fichiers sont à fournir
par le propriétaire (dossier `musique/`, avec le titre de chaque morceau) ;
ils entrent dans l'app, version Play comprise, et dans la version web.

**Ishay Ribo, MBD, Motty Steinmetz, Shmuel** : autorisation non demandée.
Hors de la version Play ; le propriétaire décide de leur place dans la
version GitHub, qui est elle aussi une diffusion.

Audio de la version Play : 26 morceaux, environ 70 Mo (Yanuka 1, המלך בשדה 1,
Noam Shpayer 10, Ianir 14), contre 56 morceaux et environ 146 Mo pour GitHub et le
site (état du 03/11 ; `tools/inventaire_musique.py`). Un morceau
retiré revient par simple mise à jour dès que son écrit existe ; si un
niggoun s'avère être du Yanuka, il rentre sous le même accord. Pour cela, il
faut retrouver les titres hébreux d'origine (fichiers sources reçus le
22/09).

**Mise en œuvre — faite le 29/10.** `main/res/raw` ne contient plus que les
morceaux livrés par Play, déclarés dans `MusiquePlay.kt`. Les autres (30 niggounim sans titre et d'autres) sont
dans `src/musique_hors_play/` (fichiers et liste `MusiqueHorsPlay.kt`), que
seule la construction GitHub ajoute ; avec `-Pplay=true`, Gradle prend
`src/musique_play/`, où la même liste est vide. Vérifié sur l'AAB : il ne
contenait que `hamelech_basade.m4a`, `yanuka_nigoun_3.m4a` et `shpayer_beyond.m4a` (AAC 96 kb/s depuis le 29/10) ; s'y ajoutent le 03/11 les 23 morceaux `shpayer_*` et `ianir_*`, soit environ 70 Mo d'audio pour la version Play (26 morceaux au total). `MusicFilesTest`
tient la liste ; `play.yml` recontrôle l'AAB lui-même.

**Règle (13/11, audit du 12/11, FPRODUIT-05).** Ce qui n'entre pas dans Play
n'entre pas non plus dans le site ni dans le jar. Le site est public : c'est
une diffusion, au même titre que Play. `web/build.mjs` ne lit plus que
`MusiquePlay.kt` (`web/tools/musique.mjs`, tenu par
`web/test/musique-livree.test.mjs`), et le service worker retire de son cache
les morceaux que le site ne livre plus. Reste à faire : le jar Nokia embarque
encore `niggoun_33` (`nokia/app/genere-musique.sh`, constat NOKIA-20).

**Ajouter un morceau autorisé** (נעם שפייר, יניר קילינסקי) : le fichier dans
`main/res/raw`, sa ligne dans `MusiquePlay.kt`, son titre dans
`values/strings.xml` — ce que fait `tools/ajoute_musique.py`. Il entre alors
dans les deux versions et dans le site. `tools/echange_musique.py`, qui
recomposait une liste unique, est suspendu.

### 3.3 Droits sur les textes

Complété le 14/11 (audit du 12/11, TLIVRES-10 et THILLOULOT-07). « Déclaré »
veut dire : affirmé par le propriétaire, sans écrit versé au dépôt. Chaque
écrit se conserve hors dépôt, comme au § 3.2, et doit dire sa portée :
reproduction, **traduction**, diffusion dans l'application et sur le site.

| Source | Licence ou accord | Action |
| --- | --- | --- |
| Tanakh, Likoutei Moharan, Sefer haMidot, Siddour Edot haMizra'h, Perek Chira | Domaine public (via Sefaria) | Aucune |
| Traductions du Rabbinat et de la JPS | Domaine public | Aucune |
| Siddour, traduction Metsudah | CC-BY | Mention au pied du siddour |
| Kitsour Choul'han Aroukh Yalkout Yossef (Torat Emet) | **CC BY-NC-SA 2.5** + licence reçue | Application **gratuite, sans publicité ni achat** ; crédit affiché (au pied de la liste des livres et dans Réglages › Sources et licences) ; garder l'écrit de la licence. La déclaration du 19/10 couvre le livre entier ; **à obtenir** : un écrit qui couvre aussi la diffusion sur le site et la traduction automatique, partielle (92 chapitres sur 1 048), sinon retirer la traduction |
| Torat Emet, Seder haDorot (hilloulot) | CC BY-NC-SA 2.5 | Crédit affiché ; mêmes conditions que le Yalkout Yossef |
| Livres du Yanuka (מכון ים שלמה) | « כל הזכויות שמורות », autorisation déclarée | Écrit à conserver, comme 3.2 |
| Bisdei Yaar, Rav Shalom Arush (breslev.co.il) : 86 des 171 textes de 'hizouk (`chizuk.json`) | Autorisation déclarée le 22/09 | **Écrit à conserver** ; portée à faire préciser : reproduction, traduction, site web |
| or-breslev.co.il | Accord déclaré le 13/10 | Écrit à conserver ; faire préciser s'il couvre la vocalisation de l'éditeur |
| Traductions automatiques du 04/11 d'œuvres protégées (Yalkout Yossef, Tefila LiChlomo) | Œuvres dérivées : permises seulement si l'accord de l'œuvre d'origine couvre la traduction | Le faire écrire dans chaque accord |
| Guide de la hitbodedout | Texte du propriétaire, déclaré auteur le 22/09 | Aucune |
| Hilloulot : Wikipédia en hébreu, 1 701 extraits | CC BY-SA 4.0 | Auteur, lien et licence affichés |
| Hilloulot : biographies de MyTzadik (2 213, YETEV 4 LTD) et de המאיר לארץ (133), reprises mot pour mot | Accord déclaré le 12/10, aucun écrit au dépôt | **Écrit à obtenir** et à conserver. Biographie d'adar-9 (réserve expresse de l'institut de Stefanesti : pas d'usage sans accord écrit) : à retirer, ou obtenir cet accord. Aux 11-8 et 2-16 : retirer la ligne de crédit des photos, que l'application ne reprend pas |
| Hilloulot : החכם היומי, Hidabroot | Faits et liens seulement | Aucune |
| Ben Ish 'Haï (Wikisource via Sefaria) | Domaine public | Aucune |
| Villes (GeoNames) | CC BY 4.0, attribution au pied des écrans Zmanim, Calendrier et Boussole | OK — vérifié |
| Polices (6 × OFL) | `assets/licences/` | OK — vérifié |
| KosherJava 2.5.0 (zmanim, Android) et kosher-zmanim (site) | **LGPL 2.1** | Texte dans `assets/licences/LGPL-2.1-KosherJava.txt`, affiché dans Réglages › Sources et licences ; source du code de l'application sur demande écrite (LGPL § 6) — à remplacer par l'adresse publique tant que le dépôt reste public |
| ZXing core 3.5.3 ; AndroidX et Material Components | Apache 2.0 | Texte dans `assets/licences/Apache-2.0-ZXing.txt`, même écran |
| Si'hot haRan, Chiv'hei haRan, Likoutei Etsot (rabenubook), Likoutei Tefilot (Maleh Vigadish 2021) — les 7 anciennes entrées `"unknown"` | Œuvres de Rabbi Natan (m. 1844), domaine public ; licence des éditions non déclarée par Sefaria (vérifié le 29/10) | **Tranché le 29/10** : affichées en texte seul, licence réécrite « Public Domain (texte seul) » ; `LicencesEditionsTest` interdit le retour d'un « unknown ». L'audit du 12/11 (TLIVRES-03) avait trouvé la vocalisation de l'éditeur encore dans `bibliotheque.json` et `chizuk.json` (APK et site) : elle en est retirée, et les relevés vocalisés sont rangés hors de `res/raw` et du site (`android/app/src/main/livres/editions_vocalisees.json`). `LicencesEditionsTest` interdit désormais tout signe de vocalisation dans ces deux fichiers pour les éditions en texte seul, et tout champ `*_sans_nikkoud` |

## 4. Compte développeur

| Étape | Détail | Statut |
| --- | --- | --- |
| Créer le compte | play.google.com/console, compte Google dédié recommandé | — |
| Frais d'inscription | **25 USD, une fois**, carte non prépayée | Vérifié |
| Type de compte | **Personnel** (nom réel affiché) ou **Organisation** (exige un numéro D-U-N-S, mais dispense du test fermé ci-dessous) | **Tranché le 29/10 : personnel, nouveau** |
| Vérification d'identité | pièce d'identité, adresse ; nom public du développeur | Vérifié |
| Vérification d'appareil | accès à un appareil Android via l'appli Play Console | Vérifié |
| **Test fermé obligatoire** (compte personnel créé après le 13/11/2023) | **12 testeurs inscrits sans interruption pendant 14 jours**, puis demande d'accès à la production | Vérifié |
| **Statut de commerçant** (*trader status*) | à déclarer dans la Play Console, à la création du compte (exigé depuis novembre 2026 ; les comptes existants ont jusqu'au 01/02/2027). Commerçant ou non au sens du droit européen : déclaration juridique du propriétaire ; sur un compte personnel, « commerçant » rend l'adresse et un téléphone publics | Vérifié ; **à trancher par le propriétaire** (`play/CONSOLE.md` § 1) |
| Vérification développeur Android | enregistrer le nom de paquet `com.myhitbodedut` (obligatoire depuis le 30/09/2026 au Brésil, en Indonésie, à Singapour et en Thaïlande, puis élargi) | Vérifié pour la date ; extension mondiale à suivre |

L'enregistrement du nom de paquet sert aussi la distribution hors boutique :
sans lui, les APK des GitHub Releases finiront par ne plus s'installer sur les
appareils certifiés des régions concernées. *Déduit.*

---

## 5. Construction et signature

### 5.1 Clés

1. Générer une **clé d'envoi** neuve, jamais versionnée :
   ```bash
   keytool -genkeypair -v -keystore upload-myhitbodedut.jks \
     -keyalg RSA -keysize 4096 -validity 10000 -alias upload
   ```
2. Activer **Play App Signing** au premier envoi : Google garde la clé de
   signature finale, la clé d'envoi perdue se remplace sur demande.
3. Sauvegarder la clé d'envoi et ses mots de passe à deux endroits hors ligne.
4. La clé de dev (`keystore/myhitbodedut-dev.jks`) reste pour les éditions
   GitHub. Conséquence : **une installation GitHub ne se met pas à jour par
   Play** (signatures différentes). Il faudra exporter le JSON, désinstaller,
   installer depuis Play, réimporter. À écrire dans la note de version et dans
   le README. *Déduit.*

### 5.2 Intégration continue

Flux `.github/workflows/play.yml` **(fait le 29/10)**, lancé à la main
(Actions → Play → Run workflow) ou par une étiquette `play-v*` :

- secrets GitHub à créer : `PLAY_KEYSTORE_BASE64` (la clé d'envoi en base64,
  `base64 -w0 upload-myhitbodedut.jks`), `PLAY_KEYSTORE_PASSWORD`,
  `PLAY_KEY_ALIAS`, `PLAY_KEY_PASSWORD`. Sans eux le flux s'arrête ;
- `./gradlew -Pplay=true testFullDebugUnitTest`, puis
  `-Pplay=true bundleFullRelease` signé avec la clé d'envoi ;
- contrôle de l'AAB : seuls les morceaux de `MusiquePlay.kt`, et pas de
  signature par la clé de développement ;
- artefact `play-N` (30 jours) : `MyHitbodedut-N.aab` et `mapping-N.txt` ;
- envoi vers la piste de test interne : optionnel, par l'API Google Play
  Developer avec un compte de service. À défaut, envoi manuel dans la console.

### 5.3 Numérotation

`versionCode = 1 + run_number` convient tant qu'**un seul** flux produit les
AAB Play. Ne jamais réutiliser un `versionCode` déjà envoyé, même refusé.
`versionName` : garder `1.N`.

### 5.4 Fichier de correspondance R8

Envoyer `mapping.txt` avec chaque AAB (Play Console → App bundle explorer),
sinon les plantages remontés par Android vitals sont illisibles.

---

## 6. Rubrique « Contenu de l'application » (Play Console)

Tout est obligatoire avant le premier envoi en test fermé.

### 6.1 Règles de confidentialité

**Rédigées le 31/10** : `web/src/confidentialite.html`, en français, anglais et
hébreu (ancres `#fr`, `#en`, `#he`). `web/build.mjs` copie `web/src` en entier
dans le site (vérifié : la page sort identique dans `web/dist`, et le service
worker la garde hors connexion). URL à saisir dans la Play Console, une fois
la branche fusionnée sur `main` et le site remis en ligne par `web.yml` (Cloudflare Pages depuis le 13/11, secrets `CLOUDFLARE_API_TOKEN` et `CLOUDFLARE_ACCOUNT_ID`) :

**https://myhitbodedut.pages.dev/confidentialite.html#en** (la fiche n'existe qu'en anglais et en hébreu : l'ancre ouvre la section anglaise ; si la console la refuse, placer la section anglaise en tête de page et passer `<html lang="en">`)

**Hébergement (tranché le 13/11) : Cloudflare Pages**, projet `myhitbodedut`,
gratuit, public, adresse indépendante du nom du compte GitHub (l'ancienne
`hil123.github.io/…` est morte depuis le changement de nom en `myhitbo`).
`web.yml` déploie `web/dist` avec `wrangler pages deploy` ; le dépôt
`myhitbodedut-web` n'est plus alimenté et peut être archivé. Secrets du dépôt
`myhitbo/MyHitbodedut` : `CLOUDFLARE_API_TOKEN` (jeton d'API, permission
*Account → Cloudflare Pages → Edit*) et `CLOUDFLARE_ACCOUNT_ID`. L'adresse est
la même dans `CelebrationActivity.LIEN_WEB`, `web/src/js/app.js` et
`ConfidentialiteTest`, qui échoue si l'une dérive. *Si le nom `myhitbodedut`
est déjà pris sur pages.dev, changer `CLOUDFLARE_PROJET` dans `web.yml` et partout
ci-dessus.* Les morceaux non autorisés (§ 3.2) ne sont plus dans ce site public
depuis le 13/11 : il ne livre que ceux de la version Play.

Lien dans l'application : Réglages → carte « Mes données » → « Règles de
confidentialité » (trois langues), qui ouvre la page à la langue de
l'interface. Contenu au 14/11 (audit du 12/11, TWEBCONF-01 à 06), relu dans le
code et tenu en partie par `ConfidentialiteTest` (faits listés dans le test) :

- ni compte, ni publicité, ni analyse d'audience, ni rapport d'erreur ; aucun
  serveur du développeur ; il ne reçoit que les e-mails que l'utilisateur
  choisit de lui écrire (question, dédicace) ;
- stockage local en `SharedPreferences`, deux fichiers : réglages
  (`myhitbodedut.xml`, dont le lieu des zmanim, les détails d'un vol, les
  lectures — favoris, marque-pages, jours du Tikoun — et la liste des apps de
  la barrière) et journal (`myhitbodedut-journal.xml` : hitbodedout, notes,
  humeur, gratitude, prénom) ;
- sauvegarde dans le nuage d'Android : réglages seuls, **journal, notes et
  prénom exclus** ; transfert d'appareil : réglages **et** journal sous
  Android 12 et plus (`backup_rules.xml`, `data_extraction_rules.xml`) ;
  désinstaller n'efface pas la copie des réglages gardée par Google ;
- export JSON à l'initiative de l'utilisateur (sans la position) ;
- position approximative pour zmanim et boussole, exacte pour le seul GPS en
  vol, utilisées sur l'appareil ; l'édition Play ne les envoie jamais ;
- barrière : ce que lisent les deux accès spéciaux, **y compris pendant toute
  hitbodedout en cours, à n'importe quelle heure** (FBARRIERE-04), et comment
  la couper ;
- vol : un seul interrupteur, **désactivé par défaut**, sous les résultats du
  vol (« Préciser la position »). La loupe est toujours visible : services
  éteints, elle demande l'accord, et l'accepter les allume pour de bon.
  **L'édition Play n'a qu'un service en ligne** : à adsbdb, le numéro de vol
  saisi (au toucher de la loupe, ou quand un vol est rempli avec un numéro
  sans son trajet), avec l'adresse IP et les en-têtes techniques que voit tout
  serveur. Le suivi en direct par OpenSky n'existe que dans l'édition
  distribuée hors de Play, et la page le dit ;
- billet importé : lu sur le téléphone, sans connexion ; ni le nom du passager
  ni le numéro de réservation ne sont gardés ;
- dédicace : ce que l'équipe reçoit par e-mail, pour quoi faire, combien de
  temps, et comment en demander l'effacement.

**Contact (02/11)** : éditeur « MyHitbodedut Team », adresse
**myhitbodedut26@gmail.com**, dans la page (trois langues). La même adresse
est à saisir comme e-mail de contact de la fiche (Play Console → Grow →
Store presence → Store settings), où elle est publique ; le nom de
développeur affiché sur Play doit être « MyHitbodedut Team », celui que la
page nomme.

### 6.2 Sécurité des données

Réécrit le 14/11 (audit du 12/11, TWEBCONF-03). Pour Google, « collecter »
veut dire faire sortir une donnée du téléphone, même vers un tiers et même si
le développeur ne la reçoit jamais ; une donnée n'est pas « partagée » quand
son envoi suit un geste de l'utilisateur, averti et d'accord. *Vérifié, aide
Play « Data safety ».*

**Version Play actuelle (pas de suivi en direct)** — une seule donnée :

| Donnée | Réponse |
| --- | --- |
| Activité dans l'application → **Historique des recherches dans l'application** (le numéro de vol envoyé à adsbdb) | collectée, **non partagée**, **facultative** (interrupteur éteint par défaut, accord demandé), finalité **Fonctionnement de l'application**, traitement éphémère **non coché** (adsbdb est un tiers dont on ne maîtrise pas la conservation) |
| Position, infos personnelles, applications installées, identifiants, diagnostics | **non déclarées** : l'application n'en transmet rien à personne. Le lieu des zmanim et la liste des applications de la barrière ne sortent du téléphone que dans la sauvegarde Android de l'utilisateur, faite par le système vers son propre compte Google et décrite dans les règles de confidentialité (examen du 14/11, constat 6) |

Questions générales : l'application collecte des données = **oui** ;
chiffrement en transit = **oui** (HTTPS seulement) ; création de compte =
**aucune** ; demande de suppression = **non**, le développeur ne détenant
aucune donnée venue de l'application (ce que garde le téléphone s'efface par
les réglages ou en désinstallant).

L'e-mail de dédicace n'est pas une collecte par l'application : l'utilisateur
l'écrit et l'envoie dans sa propre messagerie. Les règles de confidentialité
disent ce que l'équipe en fait (§ 6.1).

**Si le relais du suivi en direct est mis en ligne** (§ 3.1) : ajouter
Position → **Position approximative** (la position estimée de l'avion,
arrondie, envoyée au relais avec l'indicatif), collectée, facultative, même
finalité, et relire toute la rubrique.

Les réponses exactes, écran par écran : `play/CONSOLE.md` § 3.6.

### 6.3 Publicités, achats

Aucune publicité, aucun achat intégré. Prix : **gratuit**. Une application
gratuite ne peut plus devenir payante sur Play. *Règle Play connue, non relue
ce jour.*

### 6.4 Public cible et contenu

- **Tranche d'âge : 18 ans et plus** *(tranché le 29/10)*. Cocher une tranche
  inférieure à 13 ans fait entrer l'app dans le programme Familles, avec des
  exigences supplémentaires sans bénéfice ici.
- Classification du contenu (questionnaire IARC) : contenu religieux, aucune
  violence, aucun contenu généré par d'autres utilisateurs, aucun partage de
  position avec d'autres utilisateurs. Classement attendu : tout public.
  *Déduit.*
- Application d'actualités : non. Application gouvernementale : non.
  Fonctionnalités financières : non.
- **Applications de santé** : « aucune fonction de santé » — l'application est
  un outil de prière, sans conseil ni promesse de bien-être. Réserve : Google
  range la « méditation » sous *Stress management, relaxation, mental
  acuity*. Depuis le 14/11 le manifeste dit « personal prayer session
  (hitbodedut) » et non plus « meditation session » (§ 6.6) ; reste la note
  d'humeur. Au propriétaire de trancher si Google conteste (`play/CONSOLE.md`
  § 3.8) ; dans tous les cas, la fiche ne promet aucun effet sur la santé.

### 6.5 Accès à l'application

Rubrique « Sign-in details » de la console (ex-« App access »). Aucune
connexion requise : toutes les fonctionnalités sont disponibles sans
restriction. C'est aussi le seul endroit où laisser des instructions aux
examinateurs : y coller la note du § 7.3, qui dit comment voir la barrière à
n'importe quelle heure par le bouton d'aperçu des réglages.

### 6.6 Services de premier plan — déclaration

Requise pour toute app ciblant Android 14+ (vérifié). Deux services, deux
types (`specialUse` pour les deux, `mediaPlayback` pour la séance), donc deux
déclarations : la console en demande une par **type**, pas par service, et le
bloc `specialUse` porte à la fois la séance et la barrière (examen du 14/11,
constat 1) :

| Service | Type | Ce que dit la description (anglais, identique dans le manifeste et dans la console) | Vidéo |
| --- | --- | --- | --- |
| `SessionService` | `specialUse` | Texte du manifeste, à coller tel quel : « Runs the countdown of a user-started personal prayer session (hitbodedut) and shows the remaining time, so the phone can be put down. » | Bloc `specialUse`, vidéo unique : la séance (lancer, verrouiller l'écran, montrer la notification), puis la barrière |
| `SessionService` | `mediaPlayback` | Lecture du morceau ou de l'ambiance choisis par l'utilisateur pendant sa séance, écran éteint. Demandé par le code tant que la musique ou une ambiance est allumée, ajouté à `specialUse` ; refusé (relance au démarrage du téléphone, Android 15+), la séance reste sous `specialUse` seul (examen du 14/11). | Même vidéo |
| `GateService` | `specialUse` | Texte du manifeste, à coller tel quel : « Interposes a confirmation screen over user-selected apps during a user-defined morning window, until the user confirms their daily practice, and during any user-started session until it ends. » | Même bloc `specialUse`, même vidéo, seconde séquence : choisir une app, l'ouvrir, voir l'écran, valider |

Les textes à saisir sont en anglais et reprennent mot pour mot les
`PROPERTY_SPECIAL_USE_FOREGROUND_SERVICE_SUBTYPE` des manifestes : la cohérence
entre manifeste et déclaration compte. Pour chaque type, la console demande
aussi le cas d'usage (« Other » pour `specialUse`, « Media Playback » pour la
musique), l'effet pour l'utilisateur si la tâche est différée ou interrompue,
et le lien d'une vidéo. *Vérifié, aide Play « Understanding foreground service
requirements » (« For each foreground service type you declare »).* Tout est
prêt à coller dans `play/CONSOLE.md` § 3.9. Vidéo : YouTube non répertoriée,
chaque séquence en moins de 2 minutes. *Format supposé.*

### 6.7 Autorisations sensibles — argumentaire

| Autorisation | Déclaration Play | Argument |
| --- | --- | --- |
| `SYSTEM_ALERT_WINDOW` | pas de formulaire, examinée en revue | Écran de garde volontaire, configuré par l'utilisateur |
| `PACKAGE_USAGE_STATS` | pas de formulaire, examinée en revue (politique « stalkerware ») | Ne surveille que **l'utilisateur lui-même**, à sa demande ; rien n'est transmis ; icône et notification permanentes, jamais cachée |
| `ACCESS_COARSE_LOCATION` | pas de déclaration (premier plan, sauf la dernière position connue relue au changement de fuseau, effective seulement sous Android 8 et 9, faute d'autorisation d'arrière-plan) | Zmanim et boussole : demandée seule au toucher de « Ma position » ; ville de la liste sans autorisation ; tant que « Ma position » reste choisie, relue sans geste à l'ouverture de l'accueil (au plus toutes les six heures), des zmanim, de la boussole, et après un changement de fuseau. Position gardée arrondie au centième de degré, moins d'1 km (examen du 14/11). **Fait le 31/10** (`ChoixLieu`) — vérifié par `PositionApprocheeTest` |
| `ACCESS_FINE_LOCATION` | **déclaration Play Console exigée à compter du 27/01/2027** (règle annoncée en avril 2026, précisée le 29/10/2026 ; formulaire ouvert en novembre 2026) : justifier pourquoi ni la position approximative ni le bouton de position d'Android ne suffisent | **Seulement** le GPS des zmanim en vol (`VolActivity`), au toucher de « Position réelle (GPS) » : sans réseau en avion, seul le GPS donne une position, et sous Android 8 à 11 ce fournisseur exige la position exacte. Sous Android 12 et plus, l'approximative est floutée et ses relevés ralentis : trop pour un avion. Un relevé par toucher, jamais envoyé. Ni les zmanim au sol ni la boussole ne la demandent depuis le 31/10 ; une fois accordée, « Ma position » peut s'en servir, mais n'en garde qu'une position arrondie à moins d'1 km (examen du 14/11). Texte de la déclaration : `play/CONSOLE.md` § 3.10 |
| `ACCESS_NOTIFICATION_POLICY` | aucune | « Ne pas déranger » pendant la séance, accordé dans Android |
| `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK` | aucune | Rappels, reprise après redémarrage, séance minutée |
| `QUERY_ALL_PACKAGES` | **non demandée** — `<queries>` limité aux apps lançables | Évite le formulaire le plus restrictif — vérifié |
| `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` | **non demandée** — alarmes inexactes | Évite une déclaration — vérifié (README) |
| `AccessibilityService` | **non utilisé** | Évite le motif de retrait le plus fréquent — vérifié (README) |

Le couple overlay + données d'utilisation est celui des logiciels espions : la
revue s'y attardera. L'argument tient en une phrase, à répéter partout (fiche,
déclaration, note aux examinateurs, écran d'accueil de l'app) : **une barrière
que l'utilisateur installe sur son propre téléphone, contre ses propres
habitudes, qu'il peut couper à tout instant.**

**Divulgation bien visible — faite le 31/10** (`Divulgation.kt`) : avant
d'ouvrir les réglages Android de chacune des deux autorisations spéciales,
une fenêtre propre à chacune dit quelle donnée est utilisée (l'application
au premier plan ; l'affichage par-dessus les autres), pourquoi (la barrière
du matin choisie par l'utilisateur), que rien n'est envoyé ni partagé, et
comment couper la barrière (Réglages → interrupteur « Je suis avec Hachem »).
« Continuer » ouvre les réglages, « Pas maintenant » ferme. C'est le seul
chemin vers ces deux écrans : la ligne d'autorisation des réglages et
l'aperçu de l'écran de garde y passent ; `DivulgationTest` échoue si un appel
la contourne. L'accueil et l'onboarding n'ouvrent aucun de ces deux écrans
(vérifié). *Référence : politique « Données utilisateur », section
divulgation bien visible.*

**À prévoir pour Android 17.** Le jour où l'application cible l'API 37, une
demande ponctuelle au toucher, comme le GPS en vol, devra passer par le bouton
de position d'Android (`LocationButton`, permission marquée
`onlyForLocationButton`). Tant qu'elle cible l'API 36, la demande d'autorisation
habituelle reste admise, avec la déclaration ci-dessus. *Vérifié, aide Play
« Minimum Scope: Foreground Location Access and the Location Button ».*

Limite connue de la position approximative : à moins d'une cinquantaine de
kilomètres de Har haBayit, 3 km d'écart peuvent dépasser la tolérance de la
boussole (±4°) ; au-delà de 200 km, l'écart reste sous 1°, et les zmanim
bougent de moins d'une minute (`PositionApprocheeTest`).

---

## 7. Fiche Play Store

### 7.1 Textes (× 2 langues : en-US par défaut, iw-IL)

**Tranché le 29/10 : pas de fiche en français.** La fiche Play existe en
anglais et en hébreu seulement ; un téléphone en français (ou toute autre
langue) voit la fiche anglaise, langue par défaut. L'interface de
l'application garde ses trois langues.

| Champ | Limite | Proposition |
| --- | --- | --- |
| Titre | 30 caractères, **un par langue** | he : `MyHitbodedut – התבודדות` (23) · en : `MyHitbodedut – Hitbodedut` (25) *(tranché le 29/10)* |
| Description courte | 80 caractères | **Rédigée le 12/11** : `play/fiche/en-US/short_description.txt` (77, avec « התבודדות ») · `play/fiche/iw-IL/short_description.txt` (75) |
| Description complète | 4 000 caractères | **Rédigée le 12/11, reprise le 14/11** : `play/fiche/<langue>/full_description.txt` (en : 2 705, he : 2 084). La pratique · la hitbodedout (durées de 5 min à 1 h 30, sujet, niggoun, « chaque minute s'ajoute à votre journée et à votre parcours ») · le journal · la barrière du matin (argument de 6.7, **y compris pendant toute hitbodedout en cours**) · textes (avec « traduction automatique, non relue : l'hébreu fait foi ») · zmanim, calendrier, boussole · widgets · vie privée (journal sur le téléphone, un seul service de vol facultatif) · attribution |

**Ce que la fiche ne doit pas promettre** (audit du 12/11, TPLAYDOCS-08) : ni
« la journée validée par le temps vraiment passé » (une journée se déclare
aussi sans minuteur), ni une durée par défaut qui n'est pas celle du code
(15 minutes), ni le suivi de vol en direct, ni un morceau absent de la
version Play, ni un bienfait pour la santé (§ 6.4). Vocabulaire de
l'interface : hitbodedut, length, subject, streak, « I am with Hashem » ; pas
de « session ».

**Attributions dans la description complète** (dernière ligne, deux langues) :

- routes de vol, **présente** : en « Flight routes: adsbdb.com (data by David
  J. Taylor and Jim Mason). » · he « מסלולי טיסה: adsbdb.com (נתונים של David
  J. Taylor ו־Jim Mason). » ;
- OpenSky, **obligatoire le jour où le suivi en direct passe par le relais**
  (condition du courriel du 28/10, § 3.1 ; audit TPLAYDOCS-09), à placer avant
  la précédente : en « Aircraft data: OpenSky Network (opensky-network.org). »
  · he « נתוני כלי טיס: OpenSky Network ‏(opensky-network.org). » Tant que la
  version Play n'interroge pas OpenSky, ne pas l'écrire : la fiche décrirait
  une fonction absente.

**Recherche en hébreu.** Play affiche la fiche dans la langue du téléphone
et indexe titre, description courte et description longue ; une traduction
automatique n'est pas indexée. Google ne dit pas si un mot hébreu tapé sur un
téléphone en français trouve la fiche hébraïque. D'où : « התבודדות » dans la
description courte anglaise, et les graphies latines (hitbodedut,
hisbodedus) dans une phrase de chaque description longue, y compris
l'hébraïque. *Vérifié pour l'indexation des champs (aide Play
« Get discovered on Google Play search ») ; déduit pour le reste.*

Interdits : classement ou récompense (« n° 1 », « meilleure »), emojis
répétés, mots-clés empilés. *Vérifié (bonnes pratiques Play).*

### 7.2 Visuels

| Élément | Spécification | Source dans le dépôt |
| --- | --- | --- |
| Icône | 512 × 512, PNG 32 bits avec alpha, ≤ 1 Mo | **Prête** : `play/icone-512.png` (313 Ko), à envoyer telle quelle. Original en 1024 × 1024 : `play/icone-1024.png`. Même personnage que l'icône de l'appli, en plein cadre ; Google arrondit lui-même les coins |
| Image de présentation | 1024 × 500, JPEG ou PNG 24 bits sans alpha | **Faite le 12/11** : `play/fiche/<langue>/images/featureGraphic.png` (RGB, sans alpha) : personnage + היכל הציון (`scene_ouverture_tombe.webp`) |
| Captures téléphone | 2 minimum, **8 maximum**, 320–3 840 px, 16:9 ou 9:16 | **À refaire sur la construction Play** (`-Pplay=true`), en anglais puis en hébreu. Huit écrans, dans cet ordre : accueil, choix de la durée, écran « Je suis avec Hachem », siddour, zmanim, textes, boussole, parcours (les trophées ; le journal, protégé contre les captures d'écran par `FLAG_SECURE`, ne peut pas y figurer). Captures prises par l'étape 27 de `.github/captures/captures.py`, composées par `tools/visuels_play.mjs`. Titres et phrases : `play/visuels/legendes.json` (clés `accueil`, `seance`, `barriere`, `siddour`, `zmanim`, `textes`, `boussole`, `parcours`), tenu par `web/test/fiche-play.test.mjs` |
| Captures tablette 7" et 10" | recommandées (l'app gère les grands écrans) | À produire, ou ne rien envoyer |
| Vidéo | facultative, YouTube | Laisser vide ; les vidéos du § 6.6 ne sont pas des vidéos de fiche |

Les captures doivent montrer l'interface réelle de la version envoyée.

**Les jeux de `play/visuels/{fr,en,he}` ne sont pas à envoyer** (audit du
12/11, TPLAYDOCS-04 à 08, TEN-01, THE-03). Ce sont des captures du site web,
antérieures à l'interface actuelle : dix par langue pour une limite de huit,
sans la barrière en anglais ni en hébreu, avec une liste de morceaux que la
version Play ne livre pas (visuel 10), une légende que le code ne tient pas
(visuel 05) et, dans le visuel hébreu 04, le Nom écrit en toutes lettres hors
d'un verset. Ils restent au dépôt comme modèle d'habillage (fond, cadre) et
sont à supprimer dès que les nouveaux visuels sont composés.

À vérifier à l'œil sur chaque nouveau visuel, surtout en hébreu : aucun Nom en
toutes lettres hors verset ; aucun morceau ni aucune fonction absents de la
version Play (pas de suivi de vol en direct) ; une légende qui dit ce que
l'écran montre.

### 7.3 Note aux examinateurs (Play Console → « Sign-in details »)

Réécrite le 14/11 (audit du 12/11, TPLAYDOCS-11, FBARRIERE-10, TEN-04) :
l'ancienne note était en français et décrivait un chemin qui n'existe pas
(« Accueil → autorisations »). La note à coller est **en anglais**, avec les
libellés exacts de `values-en/strings.xml` : elle est dans
**`play/CONSOLE.md` § 3.2**, seul exemplaire à tenir à jour. Le chemin qu'elle
décrit, tel que l'application l'affiche :

1. premier lancement : « Skip » ferme la présentation ;
2. barre du bas → **Settings** → carte **Mode status** → bouton **Preview the
   “I am with Hashem” screen now** (`action_preview_gate`) ;
3. la première fois, la fenêtre de divulgation **Display over other apps** →
   **Continue** → accorder l'accès dans Android → revenir et toucher le bouton
   de nouveau ;
4. l'écran de garde s'affiche à toute heure avec le bandeau **PREVIEW, NO
   EFFECT** ;
5. pour la voir agir : carte **Permissions** → **Grant** (deux
   accès) ; carte **I am with Hashem** → interrupteur, **Choose apps**,
   **Mode hours** autour de l'heure courante ; puis ouvrir l'application
   choisie. Chabbat et Yom Tov : la barrière se tait par défaut (carte
   **Rhythm**).

Si un de ces libellés change dans `values-en`, la note change avec lui.

### 7.4 Catégorie et coordonnées

- Catégorie : **Style de vie** (*Lifestyle*) *(tranché le 29/10)*.
- Tags : à choisir dans la liste de Google, au plus près de religion, prière,
  calendrier. Éviter « Meditation » tant que la déclaration « Health apps »
  dit « aucune fonction de santé » (§ 6.4).
- Adresse e-mail de contact : **myhitbodedut26@gmail.com**, obligatoire et
  publique. Téléphone : aucun.
- Site web : facultatif. À laisser vide tant que le site public livre des
  morceaux dont les droits ne sont pas établis (§ 3.2, § 6.1).

Saisie complète, écran par écran : `play/CONSOLE.md`.

---

## 8. Recette avant soumission

À passer sur l'AAB signé, installé via la piste de test interne (pas en
local) :

- [ ] Installation propre depuis Play, sur Android 13, 14, 15, 16 dont au
      moins un Samsung et un Xiaomi (surcouches constructeur, README
      « Limites connues »)
- [ ] Barrière : armée, déclenchée sur une app choisie, validée, report,
      Shabbat, après redémarrage, après retrait d'autorisation en cours
- [ ] Séance de 60 min écran éteint, musique jusqu'au bout, fondu final
- [ ] Rappels, alerte Chabbat, Birkat haLevana : déclenchés en veille profonde
- [ ] Zmanim : ville de la liste sans autorisation ; « Ma position » avec la
      seule position approximative (Android 12+ : choisir « Approximative ») ;
      mode avion ; GPS en vol (position exacte)
- [ ] Divulgation : les deux fenêtres s'affichent avant les réglages Android
      (ligne d'autorisation et aperçu de l'écran de garde) ; « Pas
      maintenant » n'ouvre rien
- [ ] Réglages → « Règles de confidentialité » ouvre la page publique dans
      les trois langues
- [ ] Les 5 widgets (zmanim ×3, boussole, série) posés et mis à jour
- [ ] Export / import JSON entre l'édition GitHub et l'édition Play
- [ ] Trois langues dans l'app, droite-à-gauche en hébreu
- [ ] Tablette, fenêtre libre, Chromebook (écran tactile non requis)
- [ ] Pré-lancement Play Console (rapport automatique) : aucun plantage,
      aucun avertissement d'accessibilité bloquant
- [ ] Réseau (proxy ou statistiques de données d'Android) : aucun appel tant
      que les services en ligne sont éteints ; allumés, le seul hôte contacté
      est `api.adsbdb.com` ; jamais `opensky-network.org`

---

## 9. Déroulé et calendrier

| # | Étape | Durée | Dépend de |
| --- | --- | --- | --- |
| 1 | Décisions § 3 : vol en direct, écrits des ayants droit, 7 licences inconnues | propriétaire | — |
| 2 | Compte développeur, paiement, vérifications | 1–3 jours | — |
| 3 | `targetSdk 36`, flux `play.yml`, musique de la version Play — **fait le 29/10** ; clé d'envoi et secrets — propriétaire | 1 jour | 1 |
| 4 | Règles de confidentialité en ligne — **rédigées le 31/10** ; en ligne (Cloudflare Pages, 13/11) ; contact : myhitbodedut26@gmail.com (02/11) | 1 jour | 1 |
| 5 | Contenu de l'application (§ 6), fiche (§ 7), vidéos | 2–3 jours | 3, 4 |
| 6 | Piste de test interne, recette § 8 | 3–5 jours | 3 |
| 7 | **Test fermé : 12 testeurs, 14 jours sans interruption** | **14 jours minimum** | 5, 6 |
| 8 | Demande d'accès à la production | quelques jours *(supposé)* | 7 |
| 9 | Revue de la version de production | de quelques jours à plus d'une semaine *(supposé)* | 8 |
| 10 | Déploiement progressif : 20 % → 50 % → 100 % | 1–2 semaines | 9 |

**Délai réaliste : 5 à 7 semaines**, dont deux incompressibles pour le test
fermé. Recruter les 12 testeurs dès l'étape 2 : il faut leurs adresses Gmail,
et chacun doit rester inscrit les 14 jours.

### Plan de repli si la revue refuse la barrière

1. Lire le motif exact. Répondre par le formulaire de recours avec la vidéo
   et l'argument de 6.7.
2. En cas de refus maintenu : publier l'édition **`light`**
   (`com.myhitbodedut.light`) — sans overlay ni données d'utilisation —
   comme application Play, et garder l'édition complète en distribution
   GitHub. La `light` est une **nouvelle application** : nouveau test fermé
   de 14 jours. *Déduit — l'exigence s'applique par application.*

---

## 10. Après la publication

- Chaque mise à jour : `targetSdk` au niveau exigé par Google chaque 31 août.
- Android vitals : taux de plantage < 1,09 %, ANR < 0,47 % *(seuils de
  mauvais comportement connus de Play, à reconfirmer)*.
- Répondre aux avis, surtout ceux qui concernent la barrière.
- README : remplacer la section « Publier sur Google Play » par le lien de la
  fiche, et documenter la migration GitHub → Play (§ 5.1, point 4).
- Garder les écrits des ayants droit et des licences accessibles : une
  réclamation peut arriver des mois après.

---

## 11. Décisions attendues du propriétaire

1. ~~**Suivi de vol en direct**~~ — **tranché le 29/10, appliqué le 12/11** :
   l'accord d'OpenSky exige un relais ; sans relais, la version Play n'a pas
   de suivi en direct (§ 3.1). Route adsbdb conservée.
2. ~~**Musique**~~ — **tranché le 29/10** : la version Play livre le niggoun
   du Yanuka et המלך בשדה (puis, le 03/11, 10 morceaux de Noam Shpayer et 14 d'Ianir : 26 en tout) ; les 30 niggounim sans titre restent hors de Play, Ishay Ribo est retiré partout (§ 3.2).
3. ~~**7 textes de licence inconnue**~~ — **tranché le 29/10** : domaine
   public, texte seul sans vocalisation (§ 3.3).
4. ~~**Compte personnel ou organisation**~~ — **tranché le 29/10** : compte
   **personnel, nouveau**. Test fermé obligatoire : 12 testeurs, 14 jours
   (§ 4, § 9 étape 7). Recruter les testeurs dès la création du compte.
5. ~~**Titre, catégorie, tranche d'âge**~~ — **tranchés le
   29/10** : Style de vie, 18 ans et plus, un titre par langue (§ 7.1).
6. ~~**Édition `light` sur Play**~~ — **tranché le 29/10** : non, gardée
   en réserve (plan de repli du § 9) ; elle reste distribuée par GitHub.

---

## Sources lues le 29/10/2026

- Exigences de niveau d'API cible — support.google.com/googleplay/android-developer/answer/11926878
- Test obligatoire des nouveaux comptes personnels — support.google.com/googleplay/android-developer/answer/14151465
- Limites de taille Play — support.google.com/googleplay/android-developer/answer/9859372
- Android App Bundle — developer.android.com/guide/app-bundle
- Types de services de premier plan et déclaration Play — developer.android.com/develop/background-work/services/fgs/service-types ; support.google.com/googleplay/android-developer/answer/13392821
- Bonnes pratiques de fiche (titre 30, description courte 80, longue 4 000) — support.google.com/googleplay/android-developer/answer/13393723
- Frais d'inscription et étapes du compte — support.google.com/googleplay/android-developer/answer/6112435 ; answer/14659200
- Vérification développeur Android (30/09/2026, quatre pays) — developer.android.com/developer-verification, cité par un article du 29/08/2026 ; la page Google elle-même n'a pas été relue
- Conditions d'utilisation OpenSky — opensky-network.org/about/terms-of-use
- Position exacte, bouton de position et déclaration (lu le 14/11/2026) — support.google.com/googleplay/android-developer/answer/17033915 ; annonce du 29/10/2026 : answer/18100766
- Statut de commerçant (lu le 14/11/2026) — support.google.com/googleplay/android-developer/answer/17594752
- Déclaration « Health apps » (lu le 14/11/2026) — support.google.com/googleplay/android-developer/answer/14738291
- Formulaire « Data safety » (lu le 14/11/2026) — support.google.com/googleplay/android-developer/answer/10787469
- Instructions d'accès pour la revue, « Sign-in details » (lu le 14/11/2026) — support.google.com/googleplay/android-developer/answer/9859455
- Spécifications des visuels (icône, image de présentation, captures) — recoupées entre deux guides tiers datés de 2026 ; la page Google correspondante (answer/9866151) ne les détaille pas dans l'extrait lu
