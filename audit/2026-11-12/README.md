# Audit critique des textes et des fonctionnalités — 12/11/2026

**Objet.** Le propriétaire a demandé un audit critique des textes et des fonctionnalités, puis deux ajouts : vérifier les traductions en français et en anglais, et dire si tous les textes sont traduits.

**État audité.** Branche `main`, commit `0274b05` (05/11/2026). Ont aussi été audités le site construit `myhitbodedut-web` (version `10227679bb4f`) et le jar Nokia 1.5.67. L'audit s'est fait en lecture seule : aucun fichier de l'application n'a été modifié.

**Méthode.**
- **Découpage.** 34 dimensions, chacune confiée à un auditeur automatisé : 11 sur les fonctionnalités, 10 sur les textes, 13 sur les traductions. La liste complète est plus bas.
- **Contre-expertise.** Chaque constat bloquant ou majeur a été repris par un second auditeur, chargé de le réfuter en retournant au code, au texte hébreu ou à l'exécution. Les constats mineurs et cosmétiques n'ont pas été contre-expertisés.
- **Corpus de traduction.**
  - Les petits corpus ont été lus en entier : 'hizouk, guide, bibliothèque, Tefila LiChlomo, Nichmat, Perek Chira, Tikkoun.
  - Les grands livres ont été balayés en entier par script, puis lus sur un échantillon tiré au hasard avec une graine fixe.

**Abréviations utilisées dans les constats.**
- `R` désigne la racine du dépôt, `A` le dossier `android/app/src/main`, `K` le dossier `A/java/com/myhitbodedut` et `RAW` le dossier `A/res/raw`.
- `OUT/…` désigne le dossier de travail des auditeurs (scripts, captures, extraits). Il n'est pas versé ici, sauf les scripts de la matrice de couverture (`scripts-couverture/`).

## En bref

| | Nombre |
|---|---:|
| Constats | 654 |
| — bloquants | **14** |
| — majeurs | **139** |
| — mineurs | 417 |
| — cosmétiques | 83 |
| Constats graves contre-expertisés | 201 |
| — confirmés tels quels | 115 |
| — confirmés en partie (gravité, portée ou correction revue) | 85 |
| — réfutés | 1 |

**Les tests passent tous**, et pourtant aucun des 14 bloquants n'est couvert par un test :
- Android : 645 tests, exécutés dans trois fuseaux (Jérusalem, Auckland, Los Angeles) ;
- web : 200 tests ;
- Nokia : 8 tests.

Les bloquants sont presque tous de petites corrections : une condition, une annotation, une phrase traduite. Trois sujets demandent en revanche un vrai chantier :
- la publication sur Google Play ;
- la sauvegarde ;
- la relecture humaine des traductions.

## Les 14 bloquants, en 8 sujets

**1. Erreurs de halakha dans les horaires**
- [FCALENDRIER-01](constats/FCALENDRIER.md) — Quand une fête tombe un vendredi, l'allumage des bougies de Chabbat est annoncé à la sortie des étoiles, donc pendant Chabbat. C'est le cas sur Android et sur le web. Prochains cas : 2e jour de Pessa'h, vendredi 23/04/2027 (diaspora), puis Chavouot, vendredi 11/06/2027 (partout).
- [FCALENDRIER-02](constats/FCALENDRIER.md) — Sur le web, à Sydney (et en Nouvelle-Zélande avec « Ma position »), tous les zmanim sont ceux du lendemain. La sortie de Chabbat peut être annoncée 61 minutes trop tôt. La cause est un défaut de la bibliothèque `kosher-zmanim` ; le correctif a été essayé sur une copie.
- [FVOL-01](constats/FVOL.md) — En vol, au départ d'un aéroport situé au nord d'environ 50,5° en été, la « prière du moment » affiche Cha'harit l'après-midi et la nuit.

**2. Siddour**
- [TSIDDUR-01](constats/TSIDDUR.md) — À Min'ha Edot (le noussa'h par défaut), le sceau de Na'hem s'affiche tous les jours, juste avant « בונה ירושלים » : deux sceaux avec le Nom pour une même bénédiction.
- [TSIDDUR-02](constats/TSIDDUR.md) — Au Moussaf de Roch 'Hodech (Edot et Ashkenaz), la fin de Modim et son sceau sont repliés sous « 'Hanouka — Pas aujourd'hui », onze mois sur douze.

**3. Traductions qui inversent une règle ou un enseignement**
- [YALKUT-01](constats/YALKUT.md) — Talit neuf : l'ordre des deux bénédictions est inversé, en français et en anglais.
- [MIDOT-01](constats/MIDOT.md) — Sefer haMidot : « נזהר לאכול משאלת חכם » est rendu dans le sens contraire, en français et en anglais.
- [HICHT-01](constats/HICHT.md) — Kokhvei Or : la règle sur la boisson est inversée en français (« se garder… de réduire »). Le même calque inverse une seconde consigne ([HICHT-02](constats/HICHT.md)).

**4. Perte de données**
- [FDONNEES-01](constats/FDONNEES.md) — L'export Android, présenté partout comme LA sauvegarde, n'emporte pas :
  - l'humeur, la gratitude et la « chose à travailler » ;
  - le journal du Tikoun ;
  - les favoris et les signets.

  Un aller-retour entre le site et Android efface aussi le journal enrichi.

**5. Publication Google Play : le suivi de vol par OpenSky**
- [TPLAYDOCS-01](constats/TPLAYDOCS.md), [FVOL-02](constats/FVOL.md), [TWEBCONF-01](constats/TWEBCONF.md) — L'AAB Play interroge OpenSky depuis chaque téléphone, ce que les conditions écrites d'OpenSky excluent. La politique de confidentialité repose sur cet accès direct.

**6. Publication Google Play : adresses**
- [TPLAYDOCS-02](constats/TPLAYDOCS.md) — L'URL de la politique de confidentialité et le lien de partage pointent vers le compte d'un ancien propriétaire (`hil123.github.io`).

**7. Publication Google Play : fiche**
- [TPLAYDOCS-03](constats/TPLAYDOCS.md) — La fiche n'est pas rédigée : ni description courte ni description longue, en anglais comme en hébreu, et pas d'image de présentation 1024 × 500. C'était déjà connu.

**8. Barrière du matin**
- [FPRODUIT-01](constats/FPRODUIT.md) — La barrière n'a jamais tourné que sur un émulateur Android 14 lancé à la main, sans aucune vérification automatique. La contre-expertise l'a ramené à majeur parce que c'est connu, mais c'est le premier risque du produit.

## Traductions : tout est-il traduit ?

**Non.** La matrice complète, avec les chiffres par fichier et par champ, est dans [couverture-traductions.md](couverture-traductions.md).

| Périmètre | Français | Anglais |
|---|---:|---:|
| Interface (1 177 chaînes) | 100 % | 100 % |
| Textes à lire, en nombre de blocs (41 792) | 40,3 % | 40,3 % |
| Textes à lire, en volume (10,45 millions de lettres hébraïques) | **23,4 %** | **23,4 %** |

**Entièrement traduit :**
- Tehilim et Tikkoun haKlali ;
- onze des douze livres ;
- la bibliothèque et le 'hizouk ;
- la hitbodedout guidée.

**Pas traduit du tout ou presque :**
- les trois siddourim, consignes comprises : 0 % ([COUV-02](constats/COUV.md)) ;
- la halakha du jour : 0 % ;
- les notices et biographies des hilloulot : 0 %, et 95 % des noms de tsadikim restent en hébreu ([COUV-04](constats/COUV.md)) ;
- le Yalkut Yosef abrégé : 10,4 % ([COUV-01](constats/COUV.md)) ;
- les 16 consignes de Tefila LiChlomo ([TEFILA-02](constats/TEFILA.md)).

**Ce que voit l'utilisateur.**
- **Une seule lacune est annoncée** : la halakha du jour (« Texte original en hébreu »). Partout ailleurs, l'hébreu remplace la traduction sans un mot.
- **Le menu « אA »** propose « Français » et « English » même pour un texte qui n'a ni l'un ni l'autre.
- **La « source du jour » de l'accueil** s'affiche en hébreu seul, alors que sa traduction est livrée ([BIBLIO-03](constats/BIBLIO.md)).
- **Neuf titres de morceaux** restent en français dans l'interface anglaise ([TEN-03](constats/TEN.md)).

## Traductions : qualité du français et de l'anglais

**Origine des traductions.**
- **Livres, 'hizouk, guide, bibliothèque, Tefila LiChlomo, petits textes** : traductions automatiques de novembre 2026, jamais relues par un humain.
  - Le français et l'anglais sortent de la même passe : ils partagent les mêmes erreurs, et comparer l'un à l'autre ne révèle rien.
  - L'application ne dit nulle part que ces traductions sont automatiques ([COUV-05](constats/COUV.md)).
- **Tanakh** : Bible du Rabbinat (1899) pour le français et JPS (1917) pour l'anglais, alignées verset par verset.

| Corpus | Blocs lus de près | Graves FR | Graves EN | Légers FR | Légers EN |
|---|---:|---:|---:|---:|---:|
| Likoutei Moharan, 1er tiers | 84 (échantillon) + ~170 ciblés | 5 (dont 1 ramené à mineur) | 5 | ~11 % | ~6 % |
| Likoutei Moharan, 2e tiers | 289 | 1 | 1 | 16 (5,5 %) | 12 (4,2 %) |
| Likoutei Moharan, 3e tiers et 411 titres | ~105 | 0 | 2 | 9 | 6 |
| Likoutei Etsot | 270 (21 % du livre) | 1 + 1 | 1 + 1 | 21 (8 %) | 14 (5 %) |
| Sefer haMidot | 263 (échantillon) + 297 ciblés | 6 | 4 | 1,9 % | 1,9 % |
| Hichtapkhout haNefech et Kokhvei Or | 110 + reprises ciblées | 2 + 2 | 2 | 13 | 8 |
| Tehilim, Tikkoun, Esther, Chir haChirim | 781 | 5 | 0 | ~33 | 23 |
| 'Hizouk | 171 (tout) | 1 | 1 | 41 | 19 |
| Guide et bibliothèque | 344 (tout) | 2 | 2 | 36 | 27 |
| Tefila LiChlomo | 147 (tout) | 3 | 2 | 15 | 14 |
| Nichmat, Perek Chira, Tikkoun (hors psaumes), guidage | 245 (tout) | 3 | 2 | 27 | — |
| Yalkut Yosef, partie traduite | 138 | 2 | 1 | 5 | 0 |

Dans la colonne des graves, « 1 + 1 » se lit : 1 erreur trouvée sur l'échantillon, plus 1 trouvée par une recherche ciblée hors échantillon.

**Ce qui ressort.**
- **Le défaut le plus visible n'est pas une erreur de traduction.** Dans environ 1 775 paragraphes traduits par langue, les balises `<b>` et `<small>` s'affichent en toutes lettres, sur le web comme sur Android. Les sept livres touchés : Yalkut Yosef (100 % des blocs traduits), Perek Chira, Likoutei Moharan, le guide, Tefila LiChlomo, Likoutei Etsot et Nichmat ([FWEBLIVE-01](constats/FWEBLIVE.md), [YALKUT-02](constats/YALKUT.md), [TLIVRES-01](constats/TLIVRES.md)). Sur le web, la correction tient en une ligne : `riche(texte)` dans `paraTraduction` (`web/src/js/app.js:796`).
- **Les contresens sont rares mais réels** : de 0,3 % à 2 % des blocs lus, avec des faux sens légers dans 2 à 11 %. Ils reviennent sur trois pièges :
  - le calque « se garder de » (לזהר), qui inverse le sens ([HICHT-01](constats/HICHT.md), [HICHT-02](constats/HICHT.md), [YALKUT-04](constats/YALKUT.md)) ;
  - les homographes : תשובה (« réponse » rendu « repentir »), אומנות (« métier » rendu « foi »), בכסה ([ETSOT-01](constats/ETSOT.md), [LM2-01](constats/LM2.md), [LMTITRES-01](constats/LMTITRES.md)) ;
  - les ellipses de l'hébreu rabbinique ([MIDOT-01](constats/MIDOT.md), [LM1-01](constats/LM1.md), [LM1-03](constats/LM1.md)).
- **Il n'y a pas de glossaire.** La graphie d'un même terme ou d'un même nom change d'un lot de traduction à l'autre :
  - tefilines / tefilin / téfilin ;
  - Moché / Moïse ;
  - ניאוף rendu « adultère » (environ 40 blocs par langue) ;
  - לכתחילה rendu « de prime abord » (23 fois).
- **Tanakh.**
  - Anglais (JPS 1917) : fidèle, aucune erreur grave.
  - Français (édition de 1899) : quatre décalages de versets ([TANAKH-01](constats/TANAKH.md)), quelques omissions et des noms qui contredisent le reste de l'application (Mardochée, Sabbat).
- **Interface.**
  - Pluriels non gérés : « 1 trophées gagnés », « Série : 1 jours sur 3 » ([TFRLANGUE-01](constats/TFRLANGUE.md)) ; « 3 times hitbodedut », « 1 trophies earned » ([TEN-02](constats/TEN.md)).
  - Le Nom écrit en toutes lettres dans une phrase de prose du 'hizouk, et dans un visuel Play hébreu ([THE-02](constats/THE.md), [TPLAYDOCS-05](constats/TPLAYDOCS.md)).

## Ce qu'il faudrait faire, dans l'ordre

1. **Les erreurs de halakha et de prière.** Les deux calendriers, le vol, les deux annotations du siddour et les quatre traductions inversées. Ce sont de petites corrections ; chacune mérite un test.
2. **L'affichage des balises dans les traductions** : une ligne sur le web, `Html.fromHtml` sur Android, et un test qui échoue dès qu'un `<` apparaît à l'écran.
3. **La sauvegarde.**
   - Exporter et importer toutes les clés, sur Android comme sur le web.
   - Rappeler d'exporter.
   - Sur iPhone, prévenir que Safari efface tout après sept jours sans visite si l'application n'est pas installée sur l'écran d'accueil ([FWEBCODE-01](constats/FWEBCODE.md)).
   - Corriger la phrase « Tout est stocké sur ce téléphone uniquement » : elle est fausse dès que la sauvegarde Google est active ([FACCUEIL-07](constats/FACCUEIL.md)).
4. **La publication Play.**
   - Couper le suivi en ligne du vol dans l'AAB Play (la permission Internet disparaît alors).
   - Corriger les URL.
   - Mettre les règles de confidentialité en accord avec le code :
     - le blocage pendant la séance ([FBARRIERE-04](constats/FBARRIERE.md)) ;
     - la sauvegarde Google ;
     - la dédicace envoyée par e-mail ([TWEBCONF-04](constats/TWEBCONF.md)) ;
     - le site, qui n'a aucune politique de confidentialité ([TWEBCONF-08](constats/TWEBCONF.md)).
   - Rédiger la fiche, et refaire les visuels anglais et hébreux depuis l'application Android, et non depuis le site.
5. **La barrière du matin.**
   - Recette sur deux vrais téléphones (Samsung et Xiaomi, Android 14 et 16).
   - Retirer `FLAG_KEEP_SCREEN_ON` de l'écran de garde.
   - Lancer le service au retour des réglages.
   - Rétablir « Ne pas déranger » dans tous les cas.
   - Protéger le Téléphone, l'Horloge et les Réglages contre « Tout sélectionner ».
   - Présenter la barrière à l'ouverture, et faire dire la vérité à la pastille de l'accueil ([FPRODUIT-02](constats/FPRODUIT.md)).
6. **Les traductions.**
   - Afficher « Traduction automatique, non relue : l'hébreu fait foi ».
   - Annoncer les textes en hébreu seul, et ne proposer « Français » ou « English » que là où ils existent.
   - Établir un glossaire et l'appliquer par script.
   - Faire relire par un humain, en commençant par Hichtapkhout haNefech (le recueil de la hitbodedout), la partie traduite du Yalkut Yosef (halakha) et le 'hizouk (le texte le plus vu).
   - Traduire les consignes du siddour.
7. **Le reste**, dimension par dimension, dans les fiches ci-dessous.

## Limites de cet audit

- **Android.** Aucun appareil ni émulateur. Les tests unitaires ont été exécutés et un AAB de publication a été construit (89 Mo), mais tout ce qui touche à la barrière, aux services et aux notifications est déduit du code.
- **iPhone.** Pas de Safari : le site a été essayé dans Chromium, sous des gabarits iPhone. Le comportement propre à iOS (effacement à sept jours, son, écran verrouillé) est déduit de la documentation de WebKit.
- **Grands livres.** Ils ont été lus sur échantillon : les taux du tableau sont des estimations, et des contresens restent à trouver dans les blocs non lus. L'hébreu n'a pas été collationné avec des éditions imprimées.
- **Constats mineurs et cosmétiques (500).** Ils n'ont pas été contre-expertisés. Sur les constats graves, la contre-expertise a revu la gravité ou la correction d'environ 4 sur 10 ; la même prudence vaut pour les mineurs.
- **Tests et intégration continue.** Cette dimension n'a pas abouti : les tests ont été exécutés (voir plus haut), mais les workflows de CI et la couverture des tests ne sont pas audités en tant que tels.
- **Couverture de l'audit lui-même.** Elle n'a pas été soumise à une revue critique finale.

## Fichiers

| Fichier | Contenu |
|---|---|
| `constats/<DIMENSION>.md` | Une fiche par dimension : ce qui a été examiné, ce qui tient, puis chaque constat avec sa preuve, la correction proposée et la note du contre-expert |
| `couverture-traductions.md` | Matrice complète « tout est-il traduit ? » |
| `scripts-couverture/` | Les scripts qui ont produit cette matrice |
| `constats.json` | Les 654 constats, lisibles par une machine |

## Toutes les dimensions

| Dimension | Constats | Bloquants | Majeurs | Mineurs | Cosm. | Réfutés |
|---|---:|---:|---:|---:|---:|---:|
| **Fonctionnalités — Android** | | | | | | |
| [FBARRIERE](constats/FBARRIERE.md) — Android — la barrière du matin, rappels, autorisations | 25 | 0 | 8 | 14 | 3 | 0 |
| [FSEANCE](constats/FSEANCE.md) — Android — la séance, la musique, le bravo | 25 | 0 | 5 | 19 | 1 | 0 |
| [FDONNEES](constats/FDONNEES.md) — Android — données, journal, progression, widget | 29 | 1 | 7 | 18 | 3 | 0 |
| [FCALENDRIER](constats/FCALENDRIER.md) — Android et web — calendrier, zmanim, lune, boussole | 21 | 2 | 3 | 13 | 3 | 0 |
| [FVOL](constats/FVOL.md) — Android et web — le mode « En vol » | 19 | 2 | 5 | 12 | 0 | 0 |
| [FLECTURE](constats/FLECTURE.md) — Android — lecture, bibliothèque, recherche, signets | 26 | 0 | 7 | 16 | 3 | 0 |
| [FACCUEIL](constats/FACCUEIL.md) — Android — accueil, premiers pas, réglages, apparence, accessibilité | 27 | 0 | 8 | 16 | 3 | 0 |
| **Fonctionnalités — web, Nokia, produit** | | | | | | |
| [FWEBCODE](constats/FWEBCODE.md) — Web — revue du code (PWA iPhone) | 23 | 0 | 6 | 16 | 1 | 0 |
| [FWEBLIVE](constats/FWEBLIVE.md) — Web — essai réel du site construit | 15 | 0 | 4 | 9 | 2 | 0 |
| [NOKIA](constats/NOKIA.md) — Nokia (Java ME) — textes et fonctions | 25 | 0 | 7 | 14 | 4 | 0 |
| [FPRODUIT](constats/FPRODUIT.md) — Produit — parité entre plateformes et cohérence d’ensemble | 19 | 0 | 6 | 12 | 1 | 0 |
| **Textes — interface** | | | | | | |
| [TFRLANGUE](constats/TFRLANGUE.md) — Interface française — langue, typographie, cohérence | 15 | 0 | 1 | 10 | 4 | 0 |
| [TFRUX](constats/TFRUX.md) — Interface française — clarté, ton, promesses (rédaction UX) | 28 | 0 | 5 | 16 | 7 | 0 |
| [TEN](constats/TEN.md) — Interface anglaise — fidélité et qualité | 15 | 0 | 4 | 8 | 3 | 0 |
| [THE](constats/THE.md) — Interface hébraïque — fidélité et qualité | 20 | 0 | 2 | 13 | 5 | 0 |
| [TMECA](constats/TMECA.md) — Chaînes — contrôles mécaniques sur les trois langues et le code | 13 | 0 | 1 | 7 | 5 | 0 |
| **Textes — contenus et vitrine** | | | | | | |
| [TSIDDUR](constats/TSIDDUR.md) — Contenus — siddour, Tehilim, Tikkoun haKlali et règles d’insertion | 25 | 2 | 6 | 15 | 2 | 0 |
| [TLIVRES](constats/TLIVRES.md) — Contenus — bibliothèque, livres, droits et attributions | 20 | 0 | 8 | 10 | 2 | 0 |
| [THILLOULOT](constats/THILLOULOT.md) — Contenus — hilloulot, biographies, halakha du jour | 19 | 0 | 5 | 10 | 3 | 1 |
| [TWEBCONF](constats/TWEBCONF.md) — Textes du web et politique de confidentialité face au code | 19 | 1 | 6 | 11 | 1 | 0 |
| [TPLAYDOCS](constats/TPLAYDOCS.md) — Vitrine — fiche Google Play, captures, README et documents | 23 | 3 | 10 | 9 | 1 | 0 |
| **Traductions — couverture et qualité** | | | | | | |
| [COUV](constats/COUV.md) — Couverture — tout texte visible est-il traduit en français, en anglais et en hébreu ? | 22 | 0 | 6 | 14 | 2 | 0 |
| [LM1](constats/LM1.md) — Likoutei Moharan — premier tiers : qualité FR et EN | 18 | 0 | 2 | 14 | 2 | 0 |
| [LM2](constats/LM2.md) — Likoutei Moharan — deuxième tiers : qualité FR et EN | 15 | 0 | 1 | 10 | 4 | 0 |
| [LMTITRES](constats/LMTITRES.md) — Likoutei Moharan — les 400 titres et le dernier tiers : qualité FR et EN | 9 | 0 | 1 | 6 | 2 | 0 |
| [ETSOT](constats/ETSOT.md) — Likoutei Etsot — qualité FR et EN | 15 | 0 | 2 | 10 | 3 | 0 |
| [MIDOT](constats/MIDOT.md) — Sefer haMidot — qualité FR et EN | 16 | 1 | 1 | 12 | 2 | 0 |
| [HICHT](constats/HICHT.md) — Hichtapkhout haNefesh et Kokhvei Or — qualité FR et EN | 16 | 1 | 3 | 11 | 1 | 0 |
| [TANAKH](constats/TANAKH.md) — Tehilim, psaumes du Tikkoun, Esther, Chir haChirim — alignement et qualité FR et EN | 19 | 0 | 0 | 18 | 1 | 0 |
| [PETITS](constats/PETITS.md) — Nichmat, Perek Chira, parties liturgiques du Tikkoun, hitbodedout guidée — lecture intégrale FR et EN | 14 | 0 | 0 | 11 | 3 | 0 |
| [CHIZUK](constats/CHIZUK.md) — ’Hizouk — lecture intégrale des 171 textes FR et EN | 16 | 0 | 1 | 14 | 1 | 0 |
| [BIBLIO](constats/BIBLIO.md) — Bibliothèque et guide de la hitbodedout — lecture intégrale FR et EN | 16 | 0 | 3 | 11 | 2 | 0 |
| [TEFILA](constats/TEFILA.md) — Tefila LiShlomo (dix feuillets) — lecture intégrale FR et EN | 16 | 0 | 3 | 12 | 1 | 0 |
| [YALKUT](constats/YALKUT.md) — Yalkut Yosef, Ben Ich ’Haï, hilloulot — traductions partielles et contenus en hébreu seul | 11 | 1 | 2 | 6 | 2 | 0 |

## Constats bloquants

**FDONNEES — Android — données, journal, progression, widget**

- [FDONNEES-01](constats/FDONNEES.md) — L'export JSON, seule sauvegarde du journal, n'emporte ni l'humeur, ni la gratitude, ni « à travailler », ni le journal du Tikoun, ni les signets *(transverse, confirmé)*

**FCALENDRIER — Android et web — calendrier, zmanim, lune, boussole**

- [FCALENDRIER-01](constats/FCALENDRIER.md) — Fête un vendredi suivie de Chabbat : l'allumage est annoncé après la sortie des étoiles *(transverse, confirmé)*
- [FCALENDRIER-02](constats/FCALENDRIER.md) — Web : à Sydney (et en Nouvelle-Zélande avec « Ma position »), tous les zmanim sont ceux du lendemain *(web, confirmé)*

**FVOL — Android et web — le mode « En vol »**

- [FVOL-01](constats/FVOL.md) — Prière du moment en vol : « Cha'harit » l'après-midi et la nuit pour tout départ d'un aéroport au nord d'environ 50,5° en été *(transverse, confirmé)*
- [FVOL-02](constats/FVOL.md) — Suivi en direct : la construction par défaut interroge OpenSky depuis chaque téléphone, ce que les conditions reçues d'OpenSky excluent *(play, confirmé, déjà connu)*

**TSIDDUR — Contenus — siddour, Tehilim, Tikkoun haKlali et règles d’insertion**

- [TSIDDUR-01](constats/TSIDDUR.md) — Min'ha Edot : le sceau de Na'hem « מנחם ציון בבנין ירושלים » s'affiche tous les jours, juste avant « בונה ירושלים » *(transverse, confirmé)*
- [TSIDDUR-02](constats/TSIDDUR.md) — Moussaf de Roch 'Hodech (Edot et Ashkenaz) : la fin de Modim et son sceau « הטוב שמך ולך נאה להודות » sont repliés sous « 'Hanouka » *(transverse, confirmé)*

**TWEBCONF — Textes du web et politique de confidentialité face au code**

- [TWEBCONF-01](constats/TWEBCONF.md) — OpenSky : la politique et la construction Play reposent sur l'accès direct que les conditions reçues d'OpenSky excluent ; avec le relais exigé, trois affirmations des règles deviennent fausses *(play, confirmé en partie)*

**TPLAYDOCS — Vitrine — fiche Google Play, captures, README et documents**

- [TPLAYDOCS-01](constats/TPLAYDOCS.md) — L'AAB Play interroge OpenSky depuis chaque téléphone, ce que l'accord écrit d'OpenSky interdit ; ni le cahier ni le flux Play ne le portent *(play, confirmé)*
- [TPLAYDOCS-02](constats/TPLAYDOCS.md) — L'URL de confidentialité et le lien de partage pointent vers le compte d'un ancien propriétaire (hil123.github.io) *(transverse, confirmé)*
- [TPLAYDOCS-03](constats/TPLAYDOCS.md) — Fiche Play : aucune description rédigée (courte et longue, en-US et iw-IL) et pas d'image de présentation 1024 × 500 *(play, confirmé, déjà connu)*

**MIDOT — Sefer haMidot — qualité FR et EN**

- [MIDOT-01](constats/MIDOT.md) — FR+EN — Contresens qui inverse un enseignement : « נזהר לאכול משאלת חכם » rendu « ne manger que selon la consultation d'un sage » *(transverse, confirmé)*

**HICHT — Hichtapkhout haNefesh et Kokhvei Or — qualité FR et EN**

- [HICHT-01](constats/HICHT.md) — FR — Kokhvei Or, partie IV : la règle sur la boisson est inversée (« se garder… de réduire ») *(transverse, confirmé)*

**YALKUT — Yalkut Yosef, Ben Ich ’Haï, hilloulot — traductions partielles et contenus en hébreu seul**

- [YALKUT-01](constats/YALKUT.md) — FR+EN — Yalkout 22:1 (talit neuf) : l’ordre des deux berakhot est inversé *(transverse, confirmé)*

## Constats majeurs

**FBARRIERE — Android — la barrière du matin, rappels, autorisations**

- [FBARRIERE-01](constats/FBARRIERE.md) — Barrière affichée « veille » alors que le service n'a jamais été lancé *(android, confirmé)*
- [FBARRIERE-02](constats/FBARRIERE.md) — L'écran de garde empêche l'écran du téléphone de s'éteindre *(android, confirmé)*
- [FBARRIERE-03](constats/FBARRIERE.md) — « Ne pas déranger » peut rester actif après la séance *(android, confirmé)*
- [FBARRIERE-04](constats/FBARRIERE.md) — La divulgation, la déclaration Play et les règles de confidentialité taisent le blocage pendant toute séance *(play, confirmé)*
- [FBARRIERE-05](constats/FBARRIERE.md) — Aucune application protégée : « Tout sélectionner » bloque aussi le Téléphone, l'Horloge et les Réglages *(android, confirmé en partie)*
- [FBARRIERE-08](constats/FBARRIERE.md) — Accueil : « Avec Hachem : activée » alors que rien n'agit, et la barrière absente de la présentation *(android, confirmé)*
- [FBARRIERE-09](constats/FBARRIERE.md) — § 6.7 : « pas de déclaration » pour la position exacte, contredit par la règle Play annoncée le 29/10/2026 *(play, confirmé)*
- [FBARRIERE-10](constats/FBARRIERE.md) — Note aux examinateurs : un chemin qui n'existe pas ; README périmé sur cinq points de la barrière *(docs, confirmé)*

**FSEANCE — Android — la séance, la musique, le bravo**

- [FSEANCE-01](constats/FSEANCE.md) — « Ne pas déranger » n'est jamais rétabli si le service de séance meurt avant la fin *(android, confirmé)*
- [FSEANCE-02](constats/FSEANCE.md) — Mini-lecteur : « Pause » puis « Lecture » coupe la musique au lieu de la reprendre *(android, confirmé)*
- [FSEANCE-03](constats/FSEANCE.md) — « Écrire » : le Bravo s'ouvre par-dessus la note en cours de saisie, puis en propose une seconde, vide *(android, confirmé)*
- [FSEANCE-04](constats/FSEANCE.md) — La note de séance en cours de saisie est perdue à la moindre recréation de l'écran, et la garde « modifié » ne couvre qu'un champ sur cinq *(android, confirmé)*
- [FSEANCE-05](constats/FSEANCE.md) — Décompte masqué + séance sans durée : « Un son vous préviendra » alors qu'aucun son ne viendra jamais *(android, confirmé)*

**FDONNEES — Android — données, journal, progression, widget**

- [FDONNEES-02](constats/FDONNEES.md) — Mode « Écrire » : au terme de la séance, le bravo s'ouvre par-dessus la note en cours, puis propose une seconde note vide *(android, confirmé)*
- [FDONNEES-03](constats/FDONNEES.md) — Une note en cours de frappe disparaît à la rotation de l'écran et à tout changement de configuration *(android, confirmé)*
- [FDONNEES-04](constats/FDONNEES.md) — Aucun moyen de corriger ou de retirer une journée : une durée saisie par erreur reste à vie *(transverse, confirmé)*
- [FDONNEES-05](constats/FDONNEES.md) — Israël ou diaspora s'applique à tout le passé : un voyage casse la série après coup *(transverse, confirmé)*
- [FDONNEES-06](constats/FDONNEES.md) — La notification d'un trophée annonce un métal que l'écran ne montre jamais (« Platine » au cinquième jour) *(transverse, confirmé en partie)*
- [FDONNEES-08](constats/FDONNEES.md) — Le jour de hitbodedout bascule à minuit alors que le Tikoun bascule à 4 h : une pratique de nuit casse la série *(transverse, confirmé en partie)*
- [FDONNEES-09](constats/FDONNEES.md) — La série du Tikoun ignore Chabbat et fêtes et n'admet aucune saisie après coup *(transverse, confirmé)*

**FCALENDRIER — Android et web — calendrier, zmanim, lune, boussole**

- [FCALENDRIER-03](constats/FCALENDRIER.md) — Birkat haLevana : « Dernier soir » un jour trop tard quand la fenêtre se ferme l'après-midi *(transverse, confirmé)*
- [FCALENDRIER-04](constats/FCALENDRIER.md) — Rappel « demande de la pluie » en diaspora : annoncé pour vendredi soir 4 décembre 2026, soir de Chabbat *(transverse, confirmé)*
- [FCALENDRIER-06](constats/FCALENDRIER.md) — « Israël / diaspora » réécrit sans bruit à chaque reprise de « Ma position » *(transverse, confirmé en partie)*

**FVOL — Android et web — le mode « En vol »**

- [FVOL-03](constats/FVOL.md) — Saisie rapide et billet : le vol se calcule et s'enregistre seul sur une arrivée devinée ou sur la date de l'ancien vol, et le message qui le disait disparaît aussitôt *(transverse, confirmé)*
- [FVOL-04](constats/FVOL.md) — Lecture des heures d'un billet collé : la durée du vol devient l'heure de départ, « 4h 25m » devient un numéro de vol, « gate » efface l'heure de départ *(transverse, confirmé)*
- [FVOL-05](constats/FVOL.md) — Carte « Prière du moment » : « Min'ha » affiché avant 'hatsot, alors que le rappel du même écran annonce Min'ha à min'ha guedola *(transverse, confirmé)*
- [FVOL-06](constats/FVOL.md) — Rappel « Tefilat haDerekh » : la notification tranche (« le moment de dire »), contrairement à ZMANIM.md, avec un risque de berakha répétée *(android, confirmé)*
- [FVOL-09](constats/FVOL.md) — Hébreu : le compte à rebours de la carte principale dit « עד » (jusqu'à) au lieu de « encore », et « 1 שעות » *(transverse, confirmé)*

**FLECTURE — Android — lecture, bibliothèque, recherche, signets**

- [FLECTURE-01](constats/FLECTURE.md) — L'écran s'éteint pendant la prière : aucun écran de lecture ne le garde allumé *(android, confirmé)*
- [FLECTURE-02](constats/FLECTURE.md) — Recherche : un seul résultat par livre ou par prière, et le toucher n'ouvre pas à l'endroit trouvé *(android, confirmé)*
- [FLECTURE-03](constats/FLECTURE.md) — Livres de 411 et 1 048 chapitres sans sommaire : la seule navigation est une bande horizontale de pastilles *(android, confirmé)*
- [FLECTURE-04](constats/FLECTURE.md) — Tehilim : le psaume en cours est perdu dès que l'écran se recrée (rotation, choix des langues, passage au thème sombre) *(android, confirmé)*
- [FLECTURE-05](constats/FLECTURE.md) — Un résultat « Ben Ish 'Haï » de la recherche mène à un écran qui ne le contient pas *(android, confirmé)*
- [FLECTURE-06](constats/FLECTURE.md) — Likoutei Moharan (10,1 Mo) et Yalkut Yosef (11,2 Mo) lus et analysés sur le fil principal à l'ouverture, puis gardés en mémoire sans limite *(android, confirmé)*
- [FLECTURE-07](constats/FLECTURE.md) — Recherche globale : 9,5 millions de caractères re-normalisés à chaque frappe, sans annulation ni indicateur *(android, confirmé en partie)*

**FACCUEIL — Android — accueil, premiers pas, réglages, apparence, accessibilité**

- [FACCUEIL-01](constats/FACCUEIL.md) — Changer d'icône de lancement ferme probablement l'application (Tsadeket à la présentation, couleur des boutons, import) *(android, confirmé)*
- [FACCUEIL-02](constats/FACCUEIL.md) — Mode sombre : les chiffres de la plaque centrale sont illisibles (1,05 à 2,4:1) dans les 36 combinaisons *(android, confirmé)*
- [FACCUEIL-03](constats/FACCUEIL.md) — Tsadeket : le personnage masculin reste sur l'écran de garde, l'état vide de la boussole et cinq scènes *(android, confirmé)*
- [FACCUEIL-04](constats/FACCUEIL.md) — La barrière du matin n'est présentée nulle part, et sa pastille d'accueil s'affiche « activée » sans rien armer *(android, confirmé)*
- [FACCUEIL-05](constats/FACCUEIL.md) — Refus des notifications : rappel laissé « activé » sans un mot, lien mort après deux refus, rappels par défaut muets *(android, confirmé)*
- [FACCUEIL-06](constats/FACCUEIL.md) — Réglages : « 4 autorisations à accorder » et « Autorisations manquantes » alors que le mode est éteint *(android, confirmé en partie)*
- [FACCUEIL-07](constats/FACCUEIL.md) — « Tout est stocké sur ce téléphone uniquement » : faux, les réglages partent dans la sauvegarde Google *(android, confirmé)*
- [FACCUEIL-08](constats/FACCUEIL.md) — « Source du jour » : un bloc d'hébreu seul sur l'accueil, alors que les 122 paragraphes candidats sont traduits *(transverse, confirmé en partie)*

**FWEBCODE — Web — revue du code (PWA iPhone)**

- [FWEBCODE-01](constats/FWEBCODE.md) — Safari peut effacer tout le journal après sept jours : l'application ne prévient pas et n'invite jamais à s'installer *(web, confirmé en partie)*
- [FWEBCODE-02](constats/FWEBCODE.md) — « Le décompte est masqué. Un son vous préviendra. » : le site n'émet aucun son de fin *(web, confirmé)*
- [FWEBCODE-04](constats/FWEBCODE.md) — La sauvegarde n'est pas complète : Tikoun, marque-pages, favoris et réglages de lecture perdus à la restauration *(transverse, confirmé)*
- [FWEBCODE-05](constats/FWEBCODE.md) — Réglages → « Lieu » : à la première ouverture, la liste des villes est vide *(web, confirmé en partie)*
- [FWEBCODE-07](constats/FWEBCODE.md) — « Réinitialiser l'application » n'efface pas tout : les morceaux ajoutés et les caches restent *(web, confirmé)*
- [FWEBCODE-08](constats/FWEBCODE.md) — « Source du jour » : en hébreu seul à l'accueil, en français comme en anglais, alors que sa traduction est livrée *(transverse, confirmé)*

**FWEBLIVE — Web — essai réel du site construit**

- [FWEBLIVE-01](constats/FWEBLIVE.md) — Livres : des balises &lt;b> brutes s’affichent dans 1 770 paragraphes traduits (fr et en) *(web, confirmé en partie)*
- [FWEBLIVE-02](constats/FWEBLIVE.md) — La note n’est pas proposée après une séance arrivée à son terme, ni après « Je l’ai faite sans le téléphone » *(web, confirmé)*
- [FWEBLIVE-03](constats/FWEBLIVE.md) — Paliers : l’écran s’ouvre défilé, sans titre ni bouton Retour *(web, confirmé)*
- [FWEBLIVE-05](constats/FWEBLIVE.md) — « Réinitialiser l’application » laisse les morceaux ajoutés, contrairement au texte (« efface tout ») *(web, confirmé)*

**NOKIA — Nokia (Java ME) — textes et fonctions**

- [NOKIA-01](constats/NOKIA.md) — Yom Tov ignoré : rappel les jours de fête et série cassée, alors qu'Android les exempte *(nokia, confirmé)*
- [NOKIA-02](constats/NOKIA.md) — Journal : une lecture ratée efface tout l'historique, une écriture ratée passe sous silence *(nokia, confirmé)*
- [NOKIA-03](constats/NOKIA.md) — Rappel refusé par le téléphone : l'accueil continue d'annoncer « Chaque jour à 20 h 00 » *(nokia, confirmé)*
- [NOKIA-04](constats/NOKIA.md) — registerAlarm appelé à chaque ouverture et à chaque fin de hitbodedout, même rappel désactivé *(nokia, confirmé)*
- [NOKIA-05](constats/NOKIA.md) — Le rappel « chaque jour » ne se reprogramme que si l'application est ouverte *(nokia, confirmé)*
- [NOKIA-06](constats/NOKIA.md) — Fin de moins d'une minute : « Vous avez parlé avec Hachem » au-dessus de « rien n'est noté », titre coupé en « Hache… » *(nokia, confirmé en partie)*
- [NOKIA-07](constats/NOKIA.md) — Journal vide : promet « sa note si vous en écrivez une », alors que le Nokia n'a pas de notes *(nokia, confirmé)*

**FPRODUIT — Produit — parité entre plateformes et cohérence d’ensemble**

- [FPRODUIT-01](constats/FPRODUIT.md) — La barrière du matin, cœur du produit, n'a jamais tourné ailleurs que sur un émulateur API 34 lancé à la main, sans aucune assertion *(android, confirmé en partie, déjà connu)*
- [FPRODUIT-02](constats/FPRODUIT.md) — La promesse centrale est invisible : absente de la présentation, pastille d'accueil « activée » qui ment, diagnostic relégué en 4ᵉ carte des Réglages *(android, confirmé)*
- [FPRODUIT-04](constats/FPRODUIT.md) — « Commencer » n'a pas le même sens d'un écran ou d'une plateforme à l'autre : sur Android, « Sans durée » et « Commencer simplement » sont hors du chemin principal *(transverse, confirmé)*
- [FPRODUIT-05](constats/FPRODUIT.md) — 30 niggounim de provenance inconnue, retirés de Play pour cette raison, sont diffusés en public sur le site et l'un d'eux dans le jar Nokia *(transverse, confirmé, déjà connu)*
- [FPRODUIT-07](constats/FPRODUIT.md) — Aucune sauvegarde automatique ni rappel d'export, sur aucune plateforme : un téléphone perdu emporte tout le journal *(transverse, confirmé en partie, déjà connu)*
- [FPRODUIT-08](constats/FPRODUIT.md) — Promesse de confidentialité du web fausse : elle cite un suivi en direct impossible et tait l'envoi réel à adsbdb.com *(web, confirmé)*

**TFRLANGUE — Interface française — langue, typographie, cohérence**

- [TFRLANGUE-01](constats/TFRLANGUE.md) — Pluriels et ordinal non gérés : « 1 trophées gagnés », « Série : 1 jours sur 3 », « votre 1ᵉ trophée » dès la première hitbodedout *(transverse, confirmé en partie)*

**TFRUX — Interface française — clarté, ton, promesses (rédaction UX)**

- [TFRUX-02](constats/TFRUX.md) — « Je suis avec Hachem » : les textes limitent le blocage à la plage horaire et au jour non fait, le code bloque aussi pendant toute hitbodedout *(android, confirmé)*
- [TFRUX-03](constats/TFRUX.md) — « Tout est stocké sur ce téléphone uniquement » : faux, et contredit par les règles de confidentialité de l'application *(transverse, confirmé)*
- [TFRUX-04](constats/TFRUX.md) — « Exportez », « Sauvegarde enregistrée », « Exportez d'abord vos données si vous voulez les garder » : l'export n'emporte qu'une partie de ce qu'on écrit *(transverse, confirmé en partie)*
- [TFRUX-05](constats/TFRUX.md) — Réglages au premier lancement : « 4 autorisations à accorder », « Autorisations nécessaires », « Autorisations manquantes » alors que rien n'est activé *(android, confirmé)*
- [TFRUX-07](constats/TFRUX.md) — « Je l'ai faite sans le téléphone » inscrit le temps sur HIER sans le dire quand aujourd'hui est déjà fait *(android, confirmé)*

**TEN — Interface anglaise — fidélité et qualité**

- [TEN-01](constats/TEN.md) — Visuels Play anglais : captures antérieures à l'interface actuelle et légendes qui contredisent l'écran *(play, confirmé en partie)*
- [TEN-02](constats/TEN.md) — Compteurs en anglais fautif : « 3 times hitbodedut », « First 3 times hitbodedut », « 1 trophies earned » *(transverse, confirmé)*
- [TEN-03](constats/TEN.md) — Neuf titres de morceaux livrés restent en français dans l'interface anglaise, dont la note « (titre incertain) » *(transverse, confirmé, déjà connu)*
- [TEN-04](constats/TEN.md) — Fiche Play anglaise : description courte et longue non rédigées, note aux examinateurs en français seulement *(play, confirmé, déjà connu)*

**THE — Interface hébraïque — fidélité et qualité**

- [THE-02](constats/THE.md) — Le Nom en toutes lettres dans une phrase de prose du 'hizouk, contre la règle du 04/11 ; deux règles contradictoires dans le même fichier *(transverse, confirmé en partie)*
- [THE-03](constats/THE.md) — Visuels Play hébreux : le Tétragramme dans une image de fiche, un compteur d'étape brouillé, des libellés que l'application n'affiche plus *(play, confirmé)*

**TMECA — Chaînes — contrôles mécaniques sur les trois langues et le code**

- [TMECA-01](constats/TMECA.md) — Vignettes des zmanim : la fête du jour n'est jamais affichée (clé de libellé sans le préfixe « fete_ ») *(android, confirmé)*

**TSIDDUR — Contenus — siddour, Tehilim, Tikkoun haKlali et règles d’insertion**

- [TSIDDUR-03](constats/TSIDDUR.md) — Fin d'office repliée avec le Ta'hanoun : Alénou absent de Min'ha Sfard, Kaddich et psaumes de Min'ha Edot, « שומר ישראל » de Cha'harit Sfard *(transverse, confirmé)*
- [TSIDDUR-04](constats/TSIDDUR.md) — Moussaf de Roch 'Hodech ashkénaze : « ברוך אתה ה׳ האל הקדוש » affiché deux fois à qui prie seul *(transverse, confirmé)*
- [TSIDDUR-05](constats/TSIDDUR.md) — Hallel Edot : la bénédiction « לגמור את ההלל » reste dépliée les jours de Hallel partiel, que l'application annonce « sans bénédiction » *(transverse, confirmé)*
- [TSIDDUR-06](constats/TSIDDUR.md) — Dix jours de techouva et 9 Av : le sceau ordinaire reste affiché normalement à côté du sceau du jour *(transverse, confirmé)*
- [TSIDDUR-07](constats/TSIDDUR.md) — Cha'harit Edot : les supplications du lundi et du jeudi sont surlignées « Aujourd'hui · Ta'hanoun » tous les jours de Ta'hanoun *(transverse, confirmé)*
- [TSIDDUR-08](constats/TSIDDUR.md) — « Aujourd'hui · Lamnatséa'h » à 'Hol hamoèd (Sfard, Ashkenaz) *(transverse, confirmé)*

**TLIVRES — Contenus — bibliothèque, livres, droits et attributions**

- [TLIVRES-01](constats/TLIVRES.md) — Les traductions des livres affichent leurs balises HTML en clair (1 775 paragraphes par langue) *(transverse, confirmé)*
- [TLIVRES-02](constats/TLIVRES.md) — Yalkout Yossef : le livre entier et sa traduction automatique sont diffusés sans les mentions de la licence, et l'application dit encore « une sélection, non le livre entier » *(transverse, confirmé en partie)*
- [TLIVRES-03](constats/TLIVRES.md) — La vocalisation d'éditeur déclarée « non reprise » est bel et bien livrée dans l'APK et publiée sur le site *(transverse, confirmé)*
- [TLIVRES-04](constats/TLIVRES.md) — Hichtapkhout HaNefech et Sefer HaMidot : vocalisation cassée, le holam manque presque partout *(transverse, confirmé)*
- [TLIVRES-05](constats/TLIVRES.md) — Yalkout Yossef annoncé traduit : 11 % seulement l'est, avec des trous, et le lecteur ne le dit jamais *(transverse, confirmé en partie)*
- [TLIVRES-07](constats/TLIVRES.md) — Guide de la hitbodedout : les deux phrases clés annoncées par « : » ont disparu à la construction *(transverse, confirmé)*
- [TLIVRES-09](constats/TLIVRES.md) — Aucun écran « Sources et licences » : ni la provenance des livres, ni l'origine des traductions, ni les licences ne sont affichées *(transverse, confirmé en partie)*
- [TLIVRES-10](constats/TLIVRES.md) — Cahier Play § 3.3 « Droits sur les textes » incomplet et dépassé ; le README ne dit rien des textes *(play, confirmé en partie)*

**THILLOULOT — Contenus — hilloulot, biographies, halakha du jour**

- [THILLOULOT-02](constats/THILLOULOT.md) — Halakha du Yalkut hors saison : Soukkot ne montre jamais le loulav, Chavouot montre l'omer, la fin de Pessa'h montre la bedikat 'hamets *(transverse, confirmé)*
- [THILLOULOT-03](constats/THILLOULOT.md) — Tri « les mieux connus d'abord » inversé : Rachbi, le Rambam, Ra'hel, Aharon et Rabbi Akiva disparaissent de la carte du jour *(transverse, confirmé en partie)*
- [THILLOULOT-04](constats/THILLOULOT.md) — Au moins 84 tsadikim affichés deux fois le même jour (dont Rabbi Natan de Breslev et Baba Elazar trois fois) *(transverse, confirmé)*
- [THILLOULOT-05](constats/THILLOULOT.md) — Dates et années de décès démenties par la notice Wikipédia affichée juste en dessous *(transverse, confirmé)*
- [THILLOULOT-07](constats/THILLOULOT.md) — Le cahier Play (§3.3) ignore toutes les sources des hilloulot, dont 2 346 biographies reprises mot pour mot sur un accord oral *(play, confirmé en partie)*

**TWEBCONF — Textes du web et politique de confidentialité face au code**

- [TWEBCONF-02](constats/TWEBCONF.md) — Règles de confidentialité périmées depuis le 04/11 sur les services de vol : loupe toujours visible, accord qui allume les services pour de bon, interrupteur enfoui, envoi sans toucher la loupe, import du billet passé sous silence *(play, confirmé)*
- [TWEBCONF-03](constats/TWEBCONF.md) — Formulaire « Sécurité des données » (§ 6.2) : contredit par la politique (« elle n'en collecte de personne »), par le README (« aucune donnée collectée ») et rangé dans une catégorie qui n'existe pas *(play, confirmé)*
- [TWEBCONF-04](constats/TWEBCONF.md) — Dédicace : l'équipe reçoit par e-mail un nom et une intention (guérison, défunt, zivoug), alors que les règles disent que le développeur « ne reçoit aucune de vos données » et taisent ce qu'il en fait *(transverse, confirmé)*
- [TWEBCONF-06](constats/TWEBCONF.md) — Sauvegarde : le fichier « réglages » envoyé dans le nuage contient l'historique du Tikoun, les lectures et le choix Tsadik/Tsadeket ; le journal décrit oublie humeur et gratitude ; le transfert et l'effacement promis ne tiennent pas partout *(android, confirmé en partie)*
- [TWEBCONF-07](constats/TWEBCONF.md) — « Tout est stocké sur ce téléphone uniquement » : faux dès que la sauvegarde Google est active, et contredit par les règles elles-mêmes ; le résumé « En bref » a le même défaut *(transverse, confirmé)*
- [TWEBCONF-08](constats/TWEBCONF.md) — Le site n'a aucune règle de confidentialité : la seule page publiée « s'applique à l'application Android », les réglages du site n'y mènent pas, et la promesse de la présentation décrit un envoi qui n'existe pas *(web, confirmé)*

**TPLAYDOCS — Vitrine — fiche Google Play, captures, README et documents**

- [TPLAYDOCS-04](constats/TPLAYDOCS.md) — Le visuel « Musique » (fr, en, he) montre des niggounim « livrés avec l'application » que l'AAB Play ne contient pas *(play, confirmé)*
- [TPLAYDOCS-05](constats/TPLAYDOCS.md) — Le visuel hébreu 04 affiche le Tétragramme en toutes lettres dans un texte de prose, contre la demande du propriétaire du 04/11 *(play, confirmé)*
- [TPLAYDOCS-06](constats/TPLAYDOCS.md) — Les 10 visuels anglais et les 10 hébreux sont des captures du site web, pas de l'application Android soumise *(play, confirmé)*
- [TPLAYDOCS-07](constats/TPLAYDOCS.md) — La barrière du matin n'apparaît dans aucun visuel anglais ou hébreu, et chaque jeu dépasse la limite de 8 captures *(play, confirmé en partie)*
- [TPLAYDOCS-08](constats/TPLAYDOCS.md) — « La journée est validée par le temps vraiment passé » : promesse du visuel 05 (trois langues) et du README que le code ne tient pas *(play, confirmé)*
- [TPLAYDOCS-09](constats/TPLAYDOCS.md) — L'attribution OpenSky exigée « sur la page du magasin » ne figure pas dans le cahier de la fiche *(play, confirmé)*
- [TPLAYDOCS-10](constats/TPLAYDOCS.md) — README et ZMANIM.md affirment encore « aucun accès réseau » et « aucune donnée collectée », à l'inverse du manifeste et du § 6.2 *(docs, confirmé)*
- [TPLAYDOCS-11](constats/TPLAYDOCS.md) — Note aux examinateurs : chemin faux (« Accueil → autorisations ») et texte en français pour une fiche en-US *(play, confirmé en partie)*
- [TPLAYDOCS-12](constats/TPLAYDOCS.md) — Le README présente un suivi d'habitudes générique comme « la version web » et ignore le site iPhone, le .jar Nokia et le dossier play/ *(docs, confirmé)*
- [TPLAYDOCS-13](constats/TPLAYDOCS.md) — Aucune notice de licence pour KosherJava (LGPL 2.1) ni pour ZXing dans l'application Android ni dans le cahier *(android, confirmé en partie)*

**COUV — Couverture — tout texte visible est-il traduit en français, en anglais et en hébreu ?**

- [COUV-01](constats/COUV.md) — FR+EN — Yalkout Yossef – Kitsour Choul'han Aroukh : 89,6 % du livre n'est pas traduit, et rien ne le dit *(transverse, confirmé en partie)*
- [COUV-02](constats/COUV.md) — FR+EN — Les trois siddourim ne sont pas traduits du tout, consignes comprises, sans aucune annonce *(transverse, confirmé)*
- [COUV-04](constats/COUV.md) — FR+EN — Hilloulot : 95 % des tsadikim n'ont que leur nom hébreu, et les 4 047 notices et biographies sont en hébreu seul *(transverse, confirmé en partie)*
- [COUV-05](constats/COUV.md) — FR+EN — L'origine des traductions n'est affichée nulle part : ni l'édition, ni le fait qu'elles n'ont pas été relues *(transverse, confirmé en partie)*
- [COUV-06](constats/COUV.md) — FR+EN — Erreur isolée, Yalkout Yossef siman 54 : la translittération contredit la règle de prononciation qu'elle énonce *(transverse, confirmé)*
- [COUV-08](constats/COUV.md) — FR+EN — « La source du jour », sur l'accueil, n'affiche que l'hébreu alors que ses 124 paragraphes sont traduits *(transverse, confirmé)*

**LM1 — Likoutei Moharan — premier tiers : qualité FR et EN**

- [LM1-01](constats/LM1.md) — FR+EN — Enseignement 39 : causalité inversée (la discorde « vient de » la faim, alors qu’elle l’amène) *(transverse, confirmé)*
- [LM1-03](constats/LM1.md) — FR+EN — Enseignement 25 : l’énigme de Bekhorot 8b traduite à contresens (« un objet qui ne vaut pas qu’on le détruise ») *(transverse, confirmé)*

**LM2 — Likoutei Moharan — deuxième tiers : qualité FR et EN**

- [LM2-01](constats/LM2.md) — FR+EN — Contresens : « הָאֻמָּנוּת » (le métier) traduit par « la foi / faith » (Enseignement 177, intentions du Kaddich) *(transverse, confirmé en partie)*

**LMTITRES — Likoutei Moharan — les 400 titres et le dernier tiers : qualité FR et EN**

- [LMTITRES-01](constats/LMTITRES.md) — EN (et FR+EN en LM I 14) : « bakessé » traduit « at the full moon / à la pleine lune », à contresens de la lecture « Roch Hachana, lune couverte » sur laquelle reposent les enseignements *(transverse, confirmé)*

**ETSOT — Likoutei Etsot — qualité FR et EN**

- [ETSOT-01](constats/ETSOT.md) — FR+EN — « Mélodie » § 9 : « hérésie pour laquelle il n’y a pas de techouva » (תשובה = réponse, pas repentir) *(transverse, confirmé en partie)*
- [ETSOT-02](constats/ETSOT.md) — FR+EN — « Les fêtes de Hachem », Yom Tov § 6 : « הולך ונחלק ונופל » (marche, glisse et tombe) rendu « va en déclinant, en se dispersant » *(transverse, confirmé)*

**MIDOT — Sefer haMidot — qualité FR et EN**

- [MIDOT-05](constats/MIDOT.md) — FR+EN — « ניאוף » rendu partout par « adultère / adultery », y compris dans le titre de la section 61 *(transverse, confirmé en partie)*

**HICHT — Hichtapkhout haNefesh et Kokhvei Or — qualité FR et EN**

- [HICHT-02](constats/HICHT.md) — FR — Hichtapkhout, Section 71 : même calque « se garder de », consigne sur la pensée inversée *(transverse, confirmé)*
- [HICHT-03](constats/HICHT.md) — FR+EN — Notions de kabbale et de 'hassidout mal rendues (mêmes faux sens dans les deux langues) *(transverse, confirmé en partie)*
- [HICHT-04](constats/HICHT.md) — FR+EN — Le vocabulaire central change selon les lots de traduction (לפרש שיחתו, להתבודד, שיחה, אדמו"ר…) *(transverse, confirmé en partie)*

**CHIZUK — ’Hizouk — lecture intégrale des 171 textes FR et EN**

- [CHIZUK-01](constats/CHIZUK.md) — FR+EN — by-13-2 : promesse à la première personne (« Voici ce que j’ai obtenu auprès du Saint, béni soit-Il ») affichée sans son locuteur *(transverse, confirmé)*

**BIBLIO — Bibliothèque et guide de la hitbodedout — lecture intégrale FR et EN**

- [BIBLIO-01](constats/BIBLIO.md) — FR+EN — Guide : les balises &lt;b> s'affichent en toutes lettres dans 63 paragraphes traduits sur 143 *(transverse, confirmé)*
- [BIBLIO-02](constats/BIBLIO.md) — FR+EN (et hébreu) — Guide infidèle à l'original : la phrase-thèse et la phrase de conclusion ont disparu *(transverse, confirmé en partie)*
- [BIBLIO-03](constats/BIBLIO.md) — FR+EN — « Source du jour » : hébreu seul sur l'accueil, alors que les 124 paragraphes sont traduits *(transverse, confirmé)*

**TEFILA — Tefila LiShlomo (dix feuillets) — lecture intégrale FR et EN**

- [TEFILA-01](constats/TEFILA.md) — FR+EN : balises &lt;b>…&lt;/b> affichées en clair dans 35 blocs traduits (tout 'Havakouk 3, toute la prière de 'Hizkiyahou, trois titres, la formule du la'hach) *(transverse, confirmé)*
- [TEFILA-02](constats/TEFILA.md) — FR+EN : les 16 lignes de consigne et de crédit restent en hébreu seul — dont les 6 modes d'emploi (« à dire 7 fois de suite », « chaque jour et à l'allumage des bougies ») *(transverse, confirmé)*
- [TEFILA-03](constats/TEFILA.md) — FR : Tehilim 32:6 cité dans la Prière redoutable — « רַק » rendu par « seul », le verset dit autre chose que l'hébreu, que l'anglais et que le Rabbinat de l'application *(transverse, confirmé)*

**YALKUT — Yalkut Yosef, Ben Ich ’Haï, hilloulot — traductions partielles et contenus en hébreu seul**

- [YALKUT-02](constats/YALKUT.md) — FR+EN — Les balises &lt;b> et &lt;small> s’affichent telles quelles dans toutes les traductions du Yalkout (web et Android) *(transverse, confirmé)*
- [YALKUT-03](constats/YALKUT.md) — FR — לכתחילה traduit par « de prime abord » (faux sens) : 23 occurrences dans 20 blocs (sections 27 à 32) *(transverse, confirmé en partie)*
