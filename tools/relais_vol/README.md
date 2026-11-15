# Le relais du suivi de vol en direct

`worker.js` est un Cloudflare Worker. L'application ne contient aucune clé :
elle demande au relais la position d'un vol, et le relais interroge OpenSky
Network.

**Android, hors de Google Play** (28/10) : l'édition complète distribuée par
GitHub interroge OpenSky directement, en accès anonyme et gratuit (sans compte
ni clé, 400 crédits par jour et par adresse IP, positions à 10 s près), et
cherche l'indicatif sur le téléphone : seule la zone part. **La construction
Play (`-Pplay=true`) ne le fait jamais** (12/11, `OPENSKY_DIRECT = false`) :
sans ce relais elle n'a pas de suivi en direct, avec lui elle passe par lui.
**Le web en a besoin** : OpenSky n'autorise
pas les appels d'un autre site depuis un navigateur (vérifié le 28/10 : en-tête
`access-control-allow-origin: https://opensky-network.org` seulement).

## Les conditions d'OpenSky (courriel du 28/10/2026, ticket 837455)

Application gratuite, sans publicité, abonnement ni fonction payante, dons
éventuels reversés à une association : usage **non commercial**, compte OpenSky
gratuit enregistré, sans frais. À condition que :

- les données soient demandées **par ce relais**, avec le client OAuth2 du
  compte (secrets du Worker), et **non par chaque téléphone** ;
- les appareils d'une même zone partagent **une réponse en cache**, temporaire,
  sans archive des données brutes (ici : carré calé sur une grille de 0,5°,
  réponse gardée 15 s en mémoire puis effacée) ;
- les données ne soient ni revendues, ni redistribuées, ni proposées par une
  API (le relais ne rend que l'avion demandé) ;
- l'attribution « Données aéronautiques : OpenSky Network
  (opensky-network.org) » figure dans l'application **et sur la page du
  magasin**. OpenSky *conseille* aussi un avertissement « ni navigation ni
  sécurité » : retiré à la demande de l'utilisateur (29/10), ce n'est pas une
  condition.

Publicité, abonnement, fonction payante ou gestion par une entreprise :
licence commerciale (Startup, 99 $/mois selon ce courriel).

Une édition Android construite **sans** relais et hors de Play interroge
encore OpenSky depuis le téléphone, en anonyme : ce n'est pas l'usage accordé.
Pour toute diffusion publique, construire avec `-PrelaisVol=https://…` ; le
flux `play.yml` le fait dès que la variable de dépôt `RELAIS_VOL` existe.

## Décisions du propriétaire (04/11/2026)

- **Réponse à OpenSky** (ticket 837455) : envoyée.
- **Fournisseur payant d'horaires de vol** (AeroDataBox, Aviationstack…) :
  non. Les heures restent saisies à la main ; la route d'un numéro de vol
  vient d'adsbdb.
- **Mise en ligne de ce relais** (compte OpenSky avec client API, compte
  Cloudflare) : possible, pas encore faite.
- **Accès direct d'Android à OpenSky** : à couper dès que le relais est en
  ligne (construire avec `-PrelaisVol=https://…`), pour respecter la première
  condition ci-dessus.

## Ce qui passe par le relais

- **Reçu** : l'indicatif radio du vol (« ELY1 ») et la position estimée sur la
  route, arrondie au dixième de degré. Pas d'identifiant d'appareil, pas de
  compte, pas de nom.
- **Envoyé à OpenSky** : un carré de ±5° autour de cette position (2 crédits,
  4 près du méridien de 180°).
- **Rendu** : la position, l'altitude et l'heure du relevé de l'avion dont
  l'indicatif correspond, ou « introuvable ».
- **Gardé** : la réponse d'OpenSky pour le carré, 15 s en mémoire, puis effacée ; rien d'autre. Cloudflare tient ses propres journaux de
  requêtes ; `observability` est désactivé dans `wrangler.toml`.

## Mettre en ligne (à faire par le propriétaire du compte)

1. **Obligatoire** (conditions d'OpenSky, ci-dessus) : un compte OpenSky
   Network et un client API OAuth2 (identifiant et secret, gardés dans les
   secrets du Worker), pour 4 000 crédits par jour au lieu de 400. Le code
   sait encore passer en anonyme sans eux, mais ce n'est pas l'usage accordé.
   Usage **non commercial** seulement.
2. Créer un compte Cloudflare (offre gratuite : 100 000 requêtes par jour).
   Le relais limite déjà chaque adresse à 20 demandes par minute (`DEBIT_MAX`),
   par instance ; pour une limite ferme, ajouter dans Cloudflare une règle de
   limitation de débit (Security → WAF → Rate limiting rules) sur `/position`.
3. Ici : `npx wrangler login`, puis, si l'on a un client API,
   `npx wrangler secret put OPENSKY_CLIENT_ID` et
   `npx wrangler secret put OPENSKY_CLIENT_SECRET` ; enfin `npx wrangler deploy`.
4. Mettre l'adresse obtenue (`https://myhitbodedut-vol.<compte>.workers.dev`)
   dans la construction :
   - Android, seulement pour passer par le relais plutôt qu'en direct :
     `./gradlew -PrelaisVol=https://… assembleFullRelease` ;
   - web : `RELAIS_VOL=https://… node build.mjs`, et `ORIGINE_WEB` dans
     `wrangler.toml` à l'origine du site.

   - Google Play : la variable de dépôt `RELAIS_VOL` (Settings → Secrets and
     variables → Actions → Variables), que lit `play.yml`.

Sans adresse, l'option reste visible mais inactive sur le web, qui ne fait
aucune requête.

## Avant d'envoyer sur Google Play un AAB qui passe par le relais

Le développeur reçoit alors l'indicatif du vol et la position estimée : ce
qui est écrit pour la version sans suivi en direct devient faux. À reprendre
le même jour, dans cet ordre (`PUBLICATION_PLAY_STORE.md` § 3.1, § 6.2, § 7.1 ;
`play/CONSOLE.md`, « Si le relais arrive ») :

1. `web/src/confidentialite.html`, trois langues : « En bref » et « Les
   vols » (texte prêt au § 3.1) ;
2. le formulaire Sécurité des données : position approximative ;
3. la fiche, deux langues : l'attribution « Aircraft data: OpenSky Network
   (opensky-network.org) », condition d'OpenSky ;
4. la phrase de l'accueil de l'application (`onboarding_private_body`).

## Limites

OpenSky reçoit les signaux ADS-B par des antennes au sol : au-dessus des
océans, loin des côtes, un avion n'est souvent pas vu. L'application revient
alors à la route prévue, ou au GPS.

Tests : `web/test/relais.test.mjs`, avec un faux OpenSky.
