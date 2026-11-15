# Faire tourner la CI sur une machine à soi

Un dépôt privé n'a droit qu'à un quota de minutes GitHub Actions par mois ; au-delà, les travaux ne
démarrent plus (le 15/11/2026 : aucun runner attribué, échec en trois secondes). Une machine à soi,
« self-hosted runner », ne compte aucune minute, et le dépôt reste privé.

Les flux fréquents la prennent dès que la variable du dépôt `RUNNER_LINUX` la nomme :
`runs-on: ${{ vars.RUNNER_LINUX || 'ubuntu-24.04' }}`. Sans la variable, rien ne change : c'est la
machine de GitHub. Les flux rares et lourds restent chez GitHub et se lancent à la main : captures
Android sur émulateur, film promo, Play, APK d'essai, Web sur Mac.

## Ce qu'il faut

- Une machine **Linux x64** (Ubuntu 22.04 ou 24.04), allumée quand on pousse, avec 40 Go libres.
- Un utilisateur dédié, par exemple `runner`, qui exécute les flux avec ses seuls droits.
- **Docker**, l'utilisateur dans le groupe `docker` : les travaux Swift tournent dans `swift:6.2-noble`.
- `git`, `curl`, `unzip`, `python3` ; `sudo` sans mot de passe pour `apt-get` (Playwright installe ses
  bibliothèques, le flux Nokia installe `xvfb`).
- Le **SDK Android** (outils en ligne de commande) pour le flux Android :
  `~/android-sdk/cmdline-tools/latest`, licences acceptées (`yes | sdkmanager --licenses`), et
  `ANDROID_HOME=/home/runner/android-sdk` dans le fichier `.env` du dossier du runner.
- Java, Node, Gradle : rien à installer, les flux les téléchargent.

## Les trois gestes

1. GitHub → le dépôt → **Settings → Actions → Runners → New self-hosted runner** → Linux, x64 :
   exécuter, en tant que `runner`, les commandes affichées (téléchargement, puis
   `./config.sh --url https://github.com/myhitbo/MyHitbodedut --token …`). Garder l'étiquette
   proposée, `self-hosted`.
2. Dans le même dossier : `sudo ./svc.sh install runner && sudo ./svc.sh start`. Le runner repart
   seul au démarrage de la machine.
3. **Settings → Secrets and variables → Actions → Variables → New repository variable** :
   nom `RUNNER_LINUX`, valeur `self-hosted`.

Pour revenir aux machines de GitHub (quota revenu, machine éteinte pour longtemps) : supprimer la
variable. Un travail en attente d'une machine éteinte attend jusqu'à 24 heures puis échoue.

## À savoir

- Un runner fait un travail à la fois : les autres attendent leur tour.
- **Seulement pour un dépôt privé sans fork** : une demande de fusion fait tourner son code sur la
  machine. Sur un dépôt public, n'importe qui pourrait le faire.
- Les flux qui libèrent de la place sur la machine de GitHub (`sudo rm -rf /usr/share/dotnet …`) ne le
  font que là (`runner.environment == 'github-hosted'`) : rien n'est effacé chez vous.
