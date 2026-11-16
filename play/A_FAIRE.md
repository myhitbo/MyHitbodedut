# Publier sur Google Play — ce qui reste à faire, dans l'ordre

État au 14/11/2026. L'application, la fiche et les déclarations sont prêtes.
Il reste les gestes que seul le propriétaire peut faire : comptes, paiement,
secrets, écrits. Le détail de chaque formulaire est dans `play/CONSOLE.md`, le
pourquoi dans `PUBLICATION_PLAY_STORE.md`.

## 1. Mettre en ligne les règles de confidentialité (≈ 15 min)

Google exige une page publique avant tout envoi.

1. Compte Cloudflare (gratuit) → *My Profile → API Tokens → Create Token*,
   permission *Account → Cloudflare Pages → Edit*. Noter aussi l'*Account ID*
   (colonne de droite du tableau de bord).
2. GitHub → `myhitbo/MyHitbodedut` → *Settings → Secrets and variables →
   Actions* : créer `CLOUDFLARE_API_TOKEN` et `CLOUDFLARE_ACCOUNT_ID`.
3. Fusionner la PR « Prêt pour Google Play » dans `main`. Le flux *Web*
   publie le site.
4. Depuis un téléphone, ouvrir
   https://myhitbodedut.pages.dev/confidentialite.html#en et vérifier la date
   « Last updated: 16 November 2026 » et la phrase « never queries OpenSky
   Network ». Si le nom `myhitbodedut` est déjà pris sur pages.dev : voir
   `PUBLICATION_PLAY_STORE.md` § 6.1.

## 2. Ranger la clé d'envoi (≈ 10 min)

La clé d'envoi `upload-myhitbodedut.jks` (alias `upload`) et son mot de passe
ont été remis à part, hors du dépôt. Empreinte SHA-256 du certificat :
`E8:61:C4:49:2C:AE:8D:A3:59:6A:27:1E:C1:AB:DD:45:3D:2B:67:EA:9F:4B:30:58:60:BE:56:90:30:77:67:B3`.

1. Les copier à deux endroits hors ligne (clé USB, gestionnaire de mots de
   passe). Ne jamais les mettre dans le dépôt.
2. Secrets GitHub, pour que le flux *Play* construise les versions suivantes :
   `PLAY_KEYSTORE_BASE64` (contenu du fichier `PLAY_KEYSTORE_BASE64.txt`
   remis avec la clé), `PLAY_KEYSTORE_PASSWORD` et `PLAY_KEY_PASSWORD` (le mot
   de passe), `PLAY_KEY_ALIAS` = `upload`.

Avec *Play App Signing*, une clé d'envoi perdue se remplace sur demande à
Google ; la clé de signature finale reste chez Google.

## 3. Compte développeur (1 à 3 jours, côté Google)

**Fait le 16/11** : compte **organisation** au nom de l'association
Hachiveinou letoratekha (n° 8221232760929604341). Reste, `play/CONSOLE.md`
§ 1 : finir les vérifications que la console demande (D-U-N-S, téléphone,
site), statut de commerçant (*Non-trader* pour une association qui publie
gratuitement : déclaration juridique de l'association). Nom public du
développeur : « MyHitbodedut Team ».

## 4. Créer l'application et envoyer la première version (≈ 2 h)

Suivre `play/CONSOLE.md` § 2 à § 5 : contenu de l'application, fiche en-US et
iw-IL, visuels de `play/visuels/en-US` et `play/visuels/iw-IL`.

Première version : `MyHitbodedut-1.0-play.aab` (versionCode 1, versionName
1.0), remise avec `mapping-1.0.txt`. Le flux *Play* produira ensuite le
versionCode 2, 3, … sans collision.

Vidéo à tourner pour la déclaration des services de premier plan
(`play/CONSOLE.md` § 3.9) : une séance lancée, écran verrouillé, la
notification ; puis l'écran « Je suis avec Hachem » sur une application
choisie.

## 5. Avant le test fermé : les écrits sur la musique

`PUBLICATION_PLAY_STORE.md` § 3.2. Trois morceaux livrés n'ont pas
d'accord écrit complet au dossier : « Eshet 'Hayil » et « Arba Bavot » (duos
avec Or Shpayer) et « Zemer bichva'hin (titre incertain) ». Soit une annexe
signée (titres, compositeurs, autorisation « distribution publique gratuite
dans une application mobile, via Google Play, monde entier »), soit les
retirer de la version Play (`MusiquePlay.kt` → `MusiqueHorsPlay.kt`).

## 6. Test interne puis production

Compte **organisation** : pas de test fermé obligatoire (ni 12 testeurs, ni
14 jours). Piste de test interne, recette, puis production directement
(`play/CONSOLE.md` § 6).

Sur la piste interne, passer la recette sur de vrais téléphones
(`PUBLICATION_PLAY_STORE.md` § 8), en particulier la barrière du matin sur un
Samsung et un Xiaomi.
