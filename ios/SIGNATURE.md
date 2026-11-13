# Signer et installer sans Mac (tâche 3)

Ce qui est prêt dans le dépôt, et ce qui ne peut se faire que par vous, dans l'ordre.
Le pourquoi : `PORTAGE.md` § 7.4 et § 7.5.

## Ce qui est prêt

- `ios/project.yml` : l'app, les widgets et les trois extensions de la barrière (vides), le groupe
  d'apps `group.com.myhitbodedut`, les entitlements ; `ios/project-sans-barriere.yml` : la
  construction `SANS_BARRIERE` (l'app et les widgets, sans Family Controls) pour TestFlight.
- `codemagic.yaml`, à la racine :
  - `ios-verification` : compile les deux variantes sur simulateur, sans signature ni compte Apple,
    à chaque envoi sur une branche `claude/ios-*` qui touche l'app ou ses extensions ;
  - `ios-dev` : l'archive de développement signée, lancée à la main ; elle vérifie que l'archive
    contient les quatre extensions et que l'app et les trois extensions de la barrière portent
    Family Controls.

## Vos gestes

1. **P1, le compte.** Adhérer à l'Apple Developer Program, en individuel (décision D1).
2. **Le portail** (developer.apple.com, Certificates, Identifiers & Profiles) :
   1. *Identifiers*, type *App Groups* : créer `group.com.myhitbodedut`.
   2. *Identifiers*, type *App IDs* : créer les cinq identifiants
      `com.myhitbodedut`, `com.myhitbodedut.widgets`, `com.myhitbodedut.surveillance`,
      `com.myhitbodedut.bouclier`, `com.myhitbodedut.bouclier-action`.
      Cocher *App Groups* sur les cinq (avec le groupe ci-dessus) et *Family Controls (Development)*
      sur tous sauf `com.myhitbodedut.widgets`.
   3. *Devices* : enregistrer l'iPhone de l'ami par son identifiant (UDID, P4). Noter comment
      l'identifiant a été obtenu : c'est le geste 1 de la recette R1.
3. **P2, la clé d'API.** App Store Connect, *Utilisateurs et accès*, *Intégrations*, *App Store
   Connect API*, onglet des **clés d'équipe** (une clé individuelle ne donne pas accès aux profils) :
   créer une clé au rôle *Admin*, télécharger le fichier `.p8` (une seule fois possible), noter
   l'identifiant de la clé et celui de l'émetteur.
4. **Codemagic**, réglages de l'équipe :
   1. *Integrations*, *Developer Portal* : ajouter la clé, sous le nom exact **`MyHitbodedut`**
      (c'est le nom que `codemagic.yaml` appelle).
   2. *Code signing identities* : *iOS certificates*, engendrer un certificat de développement
      avec cette clé ; puis *iOS provisioning profiles*, *Fetch profiles* pour les cinq identifiants.
5. **La construction.** Codemagic, *Start new build*, workflow `ios-dev`. Critère : l'étape
   « Les quatre extensions et Family Controls » est verte et l'archive `.ipa` est dans les artefacts.
6. **P3.** Demander à Apple l'entitlement Family Controls de **distribution** pour l'app et les trois
   extensions de la barrière (décision D3) ; le délai va d'un jour à plus d'un mois.

## Le point encore ouvert : le lien d'installation

Codemagic livre l'archive brute. Pour l'installer sur un iPhone sans Mac, il faut un lien
`itms-services` vers un manifeste servi en HTTPS, ou un service d'installation. Comme convenu
(décision D15), le lien sera envoyé en message privé à l'ami ; reste à choisir où l'archive sera servie,
au moment de la recette R1.

## Ce que je ne vois pas

Les constructions Codemagic ne sont pas lisibles depuis la session de travail : le résultat de
`ios-verification` et de `ios-dev` (vert ou rouge, et en cas d'échec les dernières lignes du journal)
est à me transmettre.
