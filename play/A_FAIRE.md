# Publier sur Google Play — ce qui reste à faire, dans l'ordre

État au 23/11/2026. L'application, la fiche, les déclarations, la page des
règles de confidentialité, la clé d'envoi, le compte et la vidéo sont prêts.
Il reste les gestes que seul le propriétaire peut faire, presque tous dans la
Play Console, depuis un ordinateur. Le détail de chaque formulaire est dans
`play/CONSOLE.md`, le pourquoi dans `PUBLICATION_PLAY_STORE.md`.

## Publier aujourd'hui : ce qui est possible

- **Envoyer l'application à Google aujourd'hui : oui**, si le compte n'attend
  plus de vérification (§ 2). Tout le reste est prêt ; il faut compter deux à
  trois heures de saisie (§ 3 à § 5).
- **La voir sur le Play Store aujourd'hui : non.** Une première version passe
  par l'examen de Google, qui annonce jusqu'à sept jours, parfois plus pour un
  compte neuf, et qu'on ne peut pas accélérer. La barrière du matin (affichage
  par-dessus les autres applications, accès aux données d'utilisation) est de
  celles que l'examen regarde de près.
- **L'installer depuis Play aujourd'hui, par un lien : oui**, sur la piste de
  test interne (jusqu'à 100 testeurs invités) : la version y arrive en quelques
  minutes, le lien peut mettre quelques heures la première fois.
- Tout nouvel envoi pendant l'examen remet l'application en fin de file : on
  envoie une fois, la bonne version.

## Ce qui est fait

| Quoi | Depuis | Où le vérifier |
| --- | --- | --- |
| Règles de confidentialité en ligne | 16/11 | https://myhitbodedut.pages.dev/confidentialite.html#en (« Last updated: 16 November 2026 ») |
| Clé d'envoi et secrets `PLAY_*` | 15/11 | flux *Vérification des secrets* vert ; empreinte ci-dessous |
| Compte développeur **organisation** | 16/11 | HACHIVEINOU LÉTORATEKHA, n° 8221232760929604341 |
| Droits sur la musique | 16/11 | la version Play livre 23 morceaux (`MusiquePlay.kt`) |
| Fiche en-US et iw-IL, 8 visuels par langue | 17/11 | `play/fiche/`, `play/visuels/` |
| Recette sur émulateurs, Android 13 à 16 | 22/11 | ci-dessous |
| Six corrections trouvées par la recette | 22/11 | PR #50 « Recette avant Google Play », reprise dans la branche du 23/11 (§ 1) |
| PR #48, #49 et #50 réunies, relecture du code, vingt et une corrections | 23/11 | branche `ccr-95e5794e-1ej68l` ; ci-dessous |
| AAB signé `play-7` (versionCode 8, version 1.7) | 23/11 | construit sur cette branche, avec toutes les corrections : § 1. **Ne pas envoyer** `play-3` (17/11, aucune correction), `play-4` et `play-5` (23/11, construits avant la contre-relecture), ni `play-6` (23/11, construit sur `main` : les trois PR, mais **aucune** des corrections du 23/11, dont les trois plantages) |
| Note aux examinateurs, rejouée mot pour mot | 22/11 | `play/CONSOLE.md` § 3.2 |
| Vidéo des services de premier plan | 22/11 | `MyHitbodedut-foreground-services.mp4`, `play/CONSOLE.md` § 3.9 |

Empreinte SHA-256 du certificat d'envoi (`upload-myhitbodedut.jks`, alias
`upload`), à comparer à celle que la Play Console affichera :
`E8:61:C4:49:2C:AE:8D:A3:59:6A:27:1E:C1:AB:DD:45:3D:2B:67:EA:9F:4B:30:58:60:BE:56:90:30:77:67:B3`.
La clé et son mot de passe restent à deux endroits hors ligne, jamais dans le
dépôt. Avec *Play App Signing*, une clé d'envoi perdue se remplace sur demande
à Google.

### La relecture du 23/11

Les PR #48 (check-up du 11/11), #49 (rond du hassid, הרחמן) et #50 (recette)
sont réunies sur la branche `ccr-95e5794e-1ej68l`, sans conflit, et
fusionnées dans `main` le même jour. Le code a
ensuite été relu en quatre passes (services et arrière-plan ; données et
réglages ; accueils et séance ; vol, lieu, zmanim et textes), à la recherche
de ce qu'un parcours d'émulateur ne voit pas. Chaque constat a été vérifié
dans le code avant d'être corrigé. Sur la construction Play : 939 tests,
lint sans erreur ; 353 tests du site.

Trois plantages :

1. **Ouman et Kiev, Android 8 et 9** : leur fuseau portait un nom récent
   (`Europe/Kyiv`) que ces téléphones ne connaissent pas. L'écran des zmanim
   tombait au choix de la ville, puis l'application à chaque lancement.
2. **Appareil sans vignettes** (Chromebook, Android Go) : l'accueil tombait à
   chaque retour.
3. **Ambiance sonore** sur un téléphone à faible mémoire audio : l'application
   tombait, puis à chaque reprise de la séance.

Vie privée :

4. **Verrou du journal** : le carnet du bravo préremplissait la page du jour
   (note, gratitude, humeur) sans demander le code.
5. Plantage du verrou après une demande de code restée sans réponse.

Comportement :

6. Accueils Sérénité, Bento, Instant et Pile : les zmanim ignoraient le profil
   du rite (Edot par défaut) ; « tsét » n'avait pas la même heure que sur
   l'écran des zmanim et les vignettes.
7. Ces accueils montraient la traduction française en espagnol et en arabe
   tunisien, et ignoraient le choix « hébreu seul ».
8. Un trophée gagné n'y ouvrait jamais sa fiche.
9. Le réglage « Écran d'ouverture », sans effet hors du Classique, ne s'y
   montre plus.
10. Chaque toucher d'une notification ou de la vignette de la série posait un
    accueil de plus sur ceux déjà ouverts.
11. La note d'une ancienne séance se reproposait à chaque retour depuis les
    Récents.
12. Rappels en vol : la notification de la fin du Chema donnait une heure
    trente minutes trop tôt, toujours « selon le Gra ».
13. Vol : « arrivée estimée » se perdait à la rotation de l'écran.
14. Vol : un long billet collé figeait l'écran pendant sa lecture.
15. Séance : si le système tue l'application avant la fin, « Ne pas déranger »
    restait allumé jusqu'à la prochaine ouverture. Une alarme au terme prévu
    clôt maintenant la séance et le rétablit.
16. « Tout effacer » pendant une séance laissait la musique tourner.
17. Après « Tout effacer », un téléphone dans une langue non livrée passait en
    français jusqu'au redémarrage.
18. Musique ajoutée : le sélecteur ne propose plus que les fichiers du
    téléphone (un fichier resté dans un nuage figeait l'écran à l'écoute).
19. « Mon parcours » relisait tout le journal une fois par jour d'historique.
20. Le partage du grade pouvait faire tomber l'écran (cache plein).
21. Fiche Play : elle annonçait trois langues ; l'application en parle cinq.

Ces corrections ont ensuite été relues par un relecteur qui ne les avait pas
écrites, à la recherche de ce qu'elles auraient cassé. Il n'a trouvé ni
plantage ni perte de données, et trois retouches à faire, faites dans
`play-7` :

- la correction 4 fermait la page du carnet en pleine saisie quand l'écran du
  bravo était recréé (passage au thème sombre, taille du texte, application
  tuée en arrière-plan), journal verrouillé : ce qui était tapé restait au
  brouillon, sans être enregistré. La page se décide maintenant une fois par
  bravo ;
- la correction 10 valait aussi pour l'icône, sur les accueils Sérénité,
  Bento, Instant et Pile : quand l'application avait été ouverte par une
  notification, toucher l'icône fermait l'écran en cours (une saisie de vol
  non enregistrée avec lui). Elle ne vaut plus que pour les notifications et
  la vignette ;
- la correction 15 annonçait un trophée dans la langue du téléphone, et non
  celle de l'application, avant Android 13.

Relevé, **non corrigé** : décisions du propriétaire, ou trop peu sûr pour un
changement de dernière heure.

- Les accueils Sérénité, Bento, Instant et Pile affichent le texte de la
  dernière note quand le journal n'est pas verrouillé : elle paraît donc dans
  les captures d'écran et l'aperçu des applications récentes, ce que l'écran
  du journal interdit. Soit ne plus l'afficher, soit interdire la capture de
  ces accueils.
- Le bilan de la semaine ne s'ouvre que sur l'accueil Classique.
- En arabe tunisien, quelques nombres (coordonnées, kilomètres de la boussole
  et du vol) peuvent s'écrire en chiffres arabes orientaux. À voir sur un
  téléphone.
- La recherche dans tous les livres relit 28 Mo de textes à chaque requête :
  lente, et peut-être vide de résultats sur un téléphone très modeste.
- La durée d'une séance suit l'horloge du téléphone : la changer en cours de
  séance la raccourcit ou l'allonge.

### La recette du 22/11

La construction Play telle qu'elle est publiée (release, R8, `-Pplay=true`) a
été passée sur des émulateurs Android 13, 14, 15 et 16 par
`.github/captures/recette.py` (flux *QA Android (émulateurs)*), chaque capture
regardée ; puis rejouée en entier sur le code corrigé de la PR #50 :
11 émulateurs, 2 053 captures, les contrôles automatiques sur chaque écran et,
à l'œil, tout ce que les corrections touchent.

- **Aucun plantage, aucun « l'application ne répond pas »**, sur aucune version.
- **Le chemin de l'examinateur** (application neuve, en anglais) : sans faute
  sur les quatre versions.
- **La séance** : le service tourne au premier plan sous les deux types
  déclarés (usage spécial et lecture de média), écran éteint compris.
- **La barrière** : l'écran de garde se pose sur l'application choisie, la
  touche retour ne le contourne pas, le report le retire, il ne se pose ni
  sur les Réglages d'Android ni sur le Téléphone ; après un **vrai
  redémarrage**, le service repart seul et retient encore, sur les quatre
  versions.
- **Les écrans** : français, hébreu, espagnol, arabe tunisien ; clair et
  sombre ; navigation par gestes et à trois boutons ; téléphone couché,
  tablette debout et couchée, pliant ; les cinq versions de l'application, de
  jour et le soir.

Six défauts trouvés, corrigés dans la PR #50 « Recette avant Google Play »,
tests à l'appui :

1. **Séance** : « Une question » coupé au milieu du mot sous « Commencer
   simplement ».
2. **Accueil Classique, écran couché** : la colonne de l'en-tête réduite à
   150 dp, le titre coupé lettre par lettre, les anneaux sous le pli.
3. **Présentation** : elle annonçait trois langues ; l'application en parle
   cinq.
4. **Accueils Bento, Instant et Sérénité, chaque soir** : après le dernier zman
   du jour ils proposaient « Choisir un lieu », lieu choisi ou non. Ils
   montrent maintenant le dernier repère du jour et son heure.
5. **Accueils Pile, Bento, Instant et Sérénité** : dans la dernière minute avant
   un zman ils annonçaient « dans 0 min ».
6. **Accueil Instant, Android 15 et 16** : à l'ouverture de l'écran, debout,
   l'émulateur lui-même s'arrêtait — pas l'application : aucun plantage dans
   ses journaux, c'est le programme de l'émulateur qui disparaissait. Quatorze
   essais ont isolé la cause : les dégradés du paysage du ciel, peints à
   chaque trame par le rendu logiciel d'OpenGL. Le paysage est maintenant
   peint une seule fois dans une image ; l'accueil Instant s'ouvre sur les
   quatre versions d'Android, debout, couché, sur tablette, de jour et de
   nuit.

**Aucune n'est dans `play-3`.** La sixième suffit à ne pas l'envoyer tel
quel : le premier lancement propose les cinq versions de l'application, et les
tests de Google peuvent passer par des appareils virtuels (Firebase Test Lab,
qui fait tourner le rapport de pré-lancement, en propose). Elles sont toutes
dans `play-7`.

Ce que la recette ne remplace pas : un vrai téléphone — le son, la veille
profonde, les surcouches Samsung et Xiaomi qui arrêtent les services — et,
pour le point 6, l'accueil Instant vu une fois sur un téléphone Android 15 ou
16 (*Réglages › Version de l'app › Instant*) : un émulateur qui s'arrête ne
dit rien d'un vrai processeur graphique, dans un sens comme dans l'autre.

## 1. Récupérer le paquet et fusionner (≈ 10 min)

1. **Le paquet à envoyer** : GitHub → *Actions → Play* → l'exécution n° 7 →
   artefact `play-7` : `MyHitbodedut-7.aab` (versionCode 8, version 1.7) et
   `mapping-7.txt`. Il est construit sur la branche `ccr-95e5794e-1ej68l`, qui
   réunit les PR #48, #49 et #50 et les corrections du 23/11 ; le flux a refait
   les tests et signé avec la clé d'envoi. Un artefact se garde 30 jours.
2. **Fusionner cette branche dans `main`**, pour que `main` soit le code de la
   version envoyée. Les PR #48, #49 et #50 y sont fusionnées depuis le 23/11 ;
   les corrections du 23/11, elles, ne sont encore que sur cette branche. Tant
   qu'elle n'est pas fusionnée, une construction lancée sur `main` ne les a
   pas : c'est le cas de `play-6`.
3. Avant de l'envoyer en production, lire le bilan de la recette du 23/11 sur
   émulateurs (branches `claude/qa-api33-relecture` à
   `claude/qa-api36-relecture`, fichier `fautes.txt`).

Pour reconstruire plus tard : *Actions → Play → Run workflow* sur `main`,
une fois cette branche fusionnée. Le numéro de version suit celui de
l'exécution ; ne jamais renvoyer un versionCode déjà envoyé à Google.

## 2. Finir le compte (côté Google, 1 à 3 jours)

`play/CONSOLE.md` § 1 : les vérifications que la console demande encore
(D-U-N-S, téléphone, site de l'organisation), et le statut de commerçant —
*Non-trader* pour une association qui publie gratuitement, hors de toute
activité commerciale : c'est une déclaration juridique de l'association. Nom
public du développeur : « MyHitbodedut Team ».

## 3. Mettre la vidéo en ligne (≈ 5 min, possible depuis le téléphone)

Le fichier est sur la branche `claude/video-play` du dépôt (GitHub → branche
`claude/video-play` → `MyHitbodedut-foreground-services.mp4` → *Download*).
YouTube → *Créer → Importer une vidéo* → `MyHitbodedut-foreground-services.mp4`,
visibilité **Non répertoriée**, « pas conçue pour les enfants ». Titre et
description : `play/CONSOLE.md` § 3.9. Garder le lien : il va dans les deux
déclarations de service.

## 4. Créer l'application et tout saisir (≈ 2 h, sur un ordinateur)

Suivre `play/CONSOLE.md` § 2 à § 5, dans l'ordre : création, contenu de
l'application (règles de confidentialité, note aux examinateurs, publicités,
classification, public, sécurité des données, identifiant publicitaire,
services de premier plan avec le lien de la vidéo, position exacte), fiche
en-US et iw-IL, visuels, catégorie.

Avec Chrome ouvert sur la Play Console et l'extension Claude connectée, une
session Claude peut remplir ces formulaires avec le propriétaire, écran par
écran ; l'envoi pour examen reste son geste.

## 5. Test interne, vrais téléphones, production

Compte **organisation** : pas de test fermé obligatoire (ni 12 testeurs, ni
14 jours).

1. *Internal testing* : envoyer l'AAB, puis `mapping-N.txt`
   (`play/CONSOLE.md` § 6).
2. Installer **depuis Play** sur de vrais téléphones et passer la recette de
   `PUBLICATION_PLAY_STORE.md` § 8 — en premier la barrière du matin et la
   séance écran éteint sur un Samsung et un Xiaomi, la musique qu'on entend,
   et l'accueil Instant sur un Android 15 ou 16.
3. Lire le rapport de pré-lancement de la console (plantages, accessibilité).
4. *Production* : tous les pays, déploiement progressif à 20 %, *Send changes
   for review*.

## 6. Dons (plus tard, avec la version Play)

Décidé le 17/11 : la page de dons viendra avec la version Play. Il faudra :

1. HelloAsso : l'association s'inscrit avec son numéro RNA, ajoute son IBAN, fait
   vérifier le compte (pièce d'identité du président, statuts), puis crée un
   « Formulaire de don » (« Soutenir MyHitbodedut »). Garder le lien du formulaire.
2. Site : page `don.html` (fr, en, he) avec le bouton vers ce lien.
3. Application : bouton « Soutenir l'app » dans les Réglages, qui ouvre la page
   dans le navigateur, jamais dans l'application ; jamais le paiement de Google
   Play pour un don. Avoir les statuts de l'association sous la main au cas où
   l'examen de Google demande la preuve du caractère non lucratif.
