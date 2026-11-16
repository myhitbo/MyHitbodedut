# Clé de signature

`myhitbodedut-dev.jks` signe les APK produits par l'intégration continue.

**Ce n'est pas un secret.** Le mot de passe du trousseau et de la clé est
`myhitbodedut`, et il est écrit ici exprès.

> **Le dépôt est public depuis le 15/11/2026 : cette clé l'est donc pour tout le
> monde.** N'importe qui peut signer avec elle un APK qu'Android installera
> par-dessus une MyHitbodedut signée par elle, avec accès au journal. Elle ne
> doit plus signer aucune version distribuée : créer la clé privée et les
> secrets `RELEASE_*` décrits plus bas, puis réinstaller une fois sur chaque
> téléphone (exporter, désinstaller, installer, importer).

## Pourquoi elle est versionnée

Sans clé fixe, Gradle signe chaque compilation avec une clé de débogage
régénérée à neuf sur chaque machine. L'identité de l'application change alors à
chaque build, et Android refuse d'installer la nouvelle version par-dessus
l'ancienne : l'installation échoue sans explication utile.

Une clé stable règle cela. Les mises à jour s'installent par-dessus la version
précédente, et l'historique de pratique est conservé.

## Pour publier sur le Play Store

Ne pas utiliser cette clé. En générer une autre, la garder hors du dépôt, et la
fournir par variables d'environnement, que la configuration Gradle lit en
priorité :

```bash
KEYSTORE_PATH=/chemin/vers/play.jks \
KEYSTORE_PASSWORD=... \
KEY_ALIAS=... \
KEY_PASSWORD=... \
./gradlew assembleRelease
```

En intégration continue, passer ces valeurs par des secrets GitHub.

Une clé de publication est définitive : la perdre interdit toute mise à jour de
l'application sur le Play Store.

## Signer les APK des releases GitHub par une clé privée (audit du 12/11/2026)

Tant que les APK publiés sont signés par la clé de ce dossier, quiconque lit le
dépôt peut signer une « mise à jour » qu'Android installera par-dessus
l'application, avec accès au journal. `android.yml` prend une clé privée dès
que ces quatre secrets existent (Settings → Secrets and variables → Actions) :

```bash
keytool -genkeypair -v -keystore release-myhitbodedut.jks -alias myhitbodedut \
  -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 release-myhitbodedut.jks   # → RELEASE_KEYSTORE_BASE64
```

`RELEASE_KEYSTORE_BASE64`, `RELEASE_KEYSTORE_PASSWORD`, `RELEASE_KEY_ALIAS`,
`RELEASE_KEY_PASSWORD`. Garder le fichier et ses mots de passe hors du dépôt,
avec une copie de secours : la perdre interdit toute mise à jour.

Android refuse une mise à jour signée par une autre clé. Le passage se fait
donc une fois, sur chaque téléphone : exporter (Réglages → Mes données),
désinstaller, installer le nouvel APK, importer.
