# Publier sur Google Play — ce qui reste à faire, dans l'ordre

État au 22/11/2026. L'application, la fiche, les déclarations, la page des
règles de confidentialité, la clé d'envoi, le compte et la vidéo sont prêts.
Il reste les gestes que seul le propriétaire peut faire, presque tous dans la
Play Console, depuis un ordinateur. Le détail de chaque formulaire est dans
`play/CONSOLE.md`, le pourquoi dans `PUBLICATION_PLAY_STORE.md`.

## Ce qui est fait

| Quoi | Depuis | Où le vérifier |
| --- | --- | --- |
| Règles de confidentialité en ligne | 16/11 | https://myhitbodedut.pages.dev/confidentialite.html#en (« Last updated: 16 November 2026 ») |
| Clé d'envoi et secrets `PLAY_*` | 15/11 | flux *Vérification des secrets* vert ; empreinte ci-dessous |
| Compte développeur **organisation** | 16/11 | HACHIVEINOU LÉTORATEKHA, n° 8221232760929604341 |
| Droits sur la musique | 16/11 | la version Play livre 23 morceaux (`MusiquePlay.kt`) |
| Fiche en-US et iw-IL, 8 visuels par langue | 17/11 | `play/fiche/`, `play/visuels/` |
| AAB signé `play-3` (versionCode 4, version 1.3) | 17/11 | contrôlé le 22/11 : signé par la clé d'envoi, `targetSdk 36`, les mêmes sous-types de service que `play/CONSOLE.md` § 3.9, 23 morceaux, ni `AD_ID` ni `QUERY_ALL_PACKAGES`. **À remplacer** par l'AAB reconstruit après la fusion (§ 1) |
| Recette sur émulateurs, Android 13 à 16 | 22/11 | ci-dessous |
| Six corrections trouvées par la recette | 22/11 | PR #50 « Recette avant Google Play », à fusionner (§ 1) |
| Note aux examinateurs, rejouée mot pour mot | 22/11 | `play/CONSOLE.md` § 3.2 |
| Vidéo des services de premier plan | 22/11 | `MyHitbodedut-foreground-services.mp4`, `play/CONSOLE.md` § 3.9 |

Empreinte SHA-256 du certificat d'envoi (`upload-myhitbodedut.jks`, alias
`upload`), à comparer à celle que la Play Console affichera :
`E8:61:C4:49:2C:AE:8D:A3:59:6A:27:1E:C1:AB:DD:45:3D:2B:67:EA:9F:4B:30:58:60:BE:56:90:30:77:67:B3`.
La clé et son mot de passe restent à deux endroits hors ligne, jamais dans le
dépôt. Avec *Play App Signing*, une clé d'envoi perdue se remplace sur demande
à Google.

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
qui fait tourner le rapport de pré-lancement, en propose).

Ce que la recette ne remplace pas : un vrai téléphone — le son, la veille
profonde, les surcouches Samsung et Xiaomi qui arrêtent les services — et,
pour le point 6, l'accueil Instant vu une fois sur un téléphone Android 15 ou
16 (*Réglages › Version de l'app › Instant*) : un émulateur qui s'arrête ne
dit rien d'un vrai processeur graphique, dans un sens comme dans l'autre.

## 1. Fusionner et reconstruire (≈ 20 min)

1. Fusionner la PR #50 « Recette avant Google Play » dans `main`.
2. GitHub → *Actions → Play → Run workflow* sur `main`. Le flux refait les
   tests, signe avec la clé d'envoi et dépose l'artefact `play-N` :
   `MyHitbodedut-N.aab` et `mapping-N.txt`. C'est ce fichier-là qu'on envoie.

Les PR #48 (check-up du 11/11) et #49 (rond du hassid, הרחמן) sont ouvertes
elles aussi : au propriétaire de dire si elles partent avec la première
version. Vérifié le 22/11 : elles se fusionnent sans conflit avec la #50, dans
cet ordre ; tous les tests passent sur l'ensemble ; et la recette passée sur
les trois réunies (branches `claude/qa-api33-tout-*` à `claude/qa-api36-tout-*`)
ne relève rien — chemin de l'examinateur, séance, barrière, redémarrage,
écrans, sous Android 13 à 16. La #48 touche aux deux services de premier
plan : c'est alors sur `main`, les trois fusionnées, qu'on relance le flux
*Play*.

## 2. Finir le compte (côté Google, 1 à 3 jours)

`play/CONSOLE.md` § 1 : les vérifications que la console demande encore
(D-U-N-S, téléphone, site de l'organisation), et le statut de commerçant —
*Non-trader* pour une association qui publie gratuitement, hors de toute
activité commerciale : c'est une déclaration juridique de l'association. Nom
public du développeur : « MyHitbodedut Team ».

## 3. Mettre la vidéo en ligne (≈ 5 min, possible depuis le téléphone)

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
