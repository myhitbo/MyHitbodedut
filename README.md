# MyHitbodedut

Une même pratique quotidienne, la hitbodedout, sur plusieurs supports.

| Dossier | Ce que c'est |
| --- | --- |
| `android/` | L'application Android native, en deux éditions : **complète** (barrière du matin, zmanim en vol) et **Light** (sans barrière ni Internet). C'est l'édition complète qui va sur Google Play |
| `web/` | Le site jumeau, pour iPhone et navigateur : JavaScript sans framework, construit par `web/build.mjs` à partir des ressources Android, publié sur Cloudflare Pages (<https://myhitbodedut.pages.dev/>) avec les règles de confidentialité |
| `nokia/` | `MyHitbodedut.jar`, la version pour téléphone à touches (Java ME), un produit à part : `nokia/README.md` |
| `play/` | La publication sur Google Play : textes de la fiche (`play/fiche/`), icône, légendes des visuels, et `play/CONSOLE.md`, le pas-à-pas de la saisie |
| `tools/` | Les outils de construction des données (textes, hilloulot, aéroports, musique, images) et le relais du suivi de vol (`tools/relais_vol`) |
| `index.html` | Un ancien prototype sans lien avec l'application : voir la fin de ce fichier |

Documents : `PUBLICATION_PLAY_STORE.md` (cahier de la publication), `ZMANIM.md`
(calculs, méthodes et sources), `FEUILLE_DE_ROUTE.md`.

## L'application Android

Inspirée du fonctionnement de קודם תפילין, qui verrouille le téléphone le matin
jusqu'à confirmation de la mise des tefillin.

**Le principe.** Pendant une fenêtre horaire que vous définissez, par défaut
06:00 à 11:00, l'ouverture d'une application que vous avez désignée fait
apparaître un écran plein : « Tu as fait ta hitbodedout ? ». Trois issues :
commencer la séance tout de suite, déclarer qu'elle est déjà faite, ou reporter
de quelques minutes. Une fois la journée validée, la barrière se tait jusqu'au
lendemain.

**La séance.** Un minuteur tourne dans un service d'arrière-plan, pour que le
téléphone puisse être posé. La durée est réglable, par défaut quinze minutes.
La journée est validée à la fin de la séance ; on peut aussi la déclarer faite
(« Je l’ai faite sans le téléphone », sur l’écran de garde comme à l’accueil ;
sur l’écran de garde, sans durée : la journée est validée à 0 minute). Si une application bloquée est ouverte pendant la
séance, à n'importe quelle heure, l'écran rappelle le temps restant et ne
propose que d'y retourner.

**Le journal.** Chaque séance peut recevoir une note libre. L'historique garde
la durée et la note, jour par jour.

**Pourquoi la barrière n'agit pas.** L'écran des réglages affiche en permanence
l'état de la barrière et, si elle n'agit pas, la raison exacte : autorisation
manquante, blocage éteint, aucune application choisie, journée déjà validée,
jour sans obligation, report en cours, ou heure hors de la fenêtre. Un bouton
affiche l'écran de blocage à la demande, à n'importe quelle heure et sans
aucun effet, pour vérifier qu'il fonctionne.

**Chabbat et fêtes.** Chabbat et Yom Tov, reconnus d'après le calendrier
hébraïque, par date civile : la barrière se met en pause et la série n'est pas
cassée. Un interrupteur permet de déclarer le jour courant comme jour de
pause. La date civile est exacte pour une fenêtre située le matin ; une
fenêtre qui traverserait le coucher du soleil demanderait un calcul de zmanim.

**Rappel quotidien.** Une notification à l'heure choisie, tant que la pratique
du jour n'est pas faite. L'alarme est volontairement inexacte : elle se
déclenche même en veille profonde sans exiger la permission d'alarme exacte,
que Google Play restreint.

**Sauvegarde.** Export et import d'un fichier JSON par le sélecteur de fichiers
du système, sans aucune permission de stockage. À faire de temps en temps :
sinon un téléphone perdu emporte l'historique.

### Comment le blocage fonctionne

| Élément | Rôle |
| --- | --- |
| `GateStatus` | Source unique de vérité : la barrière est-elle armée, et sinon pourquoi |
| `GateService` | Service au premier plan, interroge `UsageStatsManager` pour connaître l'application affichée |
| `BlockerView` | Écran plein en `TYPE_APPLICATION_OVERLAY`, intercepte le bouton retour |
| `SessionService` | Décompte de la séance, notification avec le temps restant |
| `Store` | `SharedPreferences` : journées, durées, notes, réglages, sauvegarde JSON |
| `Reminder` | Rappel quotidien par alarme inexacte |
| `BootReceiver` | Relance la surveillance et le rappel après un redémarrage |

Le choix de `UsageStatsManager` plutôt qu'un `AccessibilityService` est
délibéré. L'accessibilité détecterait les changements d'application
instantanément, mais Google Play en restreint l'usage aux applications
d'accessibilité, et s'en servir pour autre chose expose à un retrait.

### La musique

Une séance peut se dérouler en musique. La section Musique rassemble la
bibliothèque : des morceaux livrés avec l'application (26 dans la version Play), plus ceux que l'on ajoute
depuis le téléphone. On choisit celui qui accompagnera les séances, on règle le
volume, et on peut écouter chaque morceau avant de décider. Appui long pour
renommer, ou retirer un morceau ajouté.

La lecture tourne dans le service de séance, donc elle continue écran éteint.
L'application demande le focus audio, ce qui fait taire les autres lecteurs, et
s'arrête en fondu plutôt que de couper net.

Les morceaux ajoutés passent par le sélecteur de fichiers du système, avec une
permission d'accès persistante : aucune permission de stockage n'est demandée,
et le fichier reste à sa place.

Le morceau livré, המלך בשדה, pèse 9,3 Mo en 320 kbps, ce qui explique la taille
de l'APK. Il n'a pas été réencodé, pour ne pas dégrader l'original.

### Les illustrations

Le personnage vient d'une planche de seize portraits et de quatre rendus pleins.
La planche est découpée en une grille de 4 par 4, chaque vignette est détourée,
puis exportée en WebP dans `res/drawable-nodpi`. Vingt images, 492 Ko au total.

Le détourage mérite une note. Le fond des rendus est mesuré entre 254 et 255,
et la chemise blanche du personnage atteint elle aussi 255 : un seuil de
luminosité trouerait le vêtement. `tools/decoupe_planche.py` identifie donc le
fond par connexité depuis le bord de l'image, ce qui laisse intacte toute zone
claire enfermée dans la silhouette.

Il subsiste un liseré clair le long des contours, inévitable sur un fond blanc.
Les écrans sombres posent donc les personnages sur un panneau clair, où ce
liseré ne se voit pas.

L'écran d'ouverture (15/10) pose le 'hassid debout (`char_debout.webp`, détouré
par connexité depuis le bord, seuil 249 : la chemise plafonne à 245) devant le
tsiyoun de Rabbi Na'hman à Ouman (`scene_ouverture_tombe.webp`) : la matséva,
l'aron et le drap, photographiés par Lord Mountbatten en mai 2010
(« Rabbi Nahman Tomb (Uman, Ukraine).JPG », Wikimedia Commons, domaine public :
aucun crédit exigé), recadrés et fondus dans un fond uni (#1E3A30) par
`tools/ouverture_tziyoun.py` depuis `tools/sources-images/tombe_rabbi_nahman_uman.jpg`.
Elle remplace (29/10, audit 1.390) une photo de la façade retouchée qui portait
le filigrane d'une banque d'images (retirée), choix du porteur.

`Character.kt` répartit les images par moment : accueil, appel à la pratique,
pendant la séance, après la séance. Le choix est stable sur une journée entière
et change le lendemain.

### Autorisations demandées

| Autorisation | Pourquoi |
| --- | --- |
| Affichage par-dessus les autres applications | Afficher l'écran de garde |
| Accès aux données d'utilisation | Savoir quelle application est au premier plan |
| Notifications | Android impose une notification permanente aux services au premier plan |
| Batterie sans restriction | Éviter que le système suspende la surveillance |
| Démarrage automatique | Reprendre après un redémarrage |
| Localisation approximative | Seulement si l'on choisit « Ma position » comme lieu des zmanim, et demandée à ce moment-là ; une ville de la liste n'en a pas besoin |

Les deux premières se donnent à la main dans les Réglages, Android ne permet pas
de les accorder par une simple boîte de dialogue. L'écran principal contient la
liste et un bouton vers chaque écran système.

La visibilité des autres applications passe par un élément `<queries>` limité
aux applications lançables, et non par `QUERY_ALL_PACKAGES`, dont Google Play
réserve l'usage à une courte liste de cas approuvés.

### Calendrier hébraïque, zmanim et ajouts de prière

L'onglet **Zmanim** montre la date hébraïque, les fêtes, ce que le jour change
aux prières, et tous les horaires de la journée, chacun avec sa méthode. Le
bouton **Calendrier** ouvre la grille d'un mois ; le jour touché montre son
détail. Le lieu est une ville de la liste (GeoNames) ou la position du
téléphone.

Dans le siddour, les ajouts du jour sont mis en évidence (Ya'alé véyavo, Al
hanissim, Tal oumatar, Anénou, Ta'hanoun…). Les autres sont repliés derrière
une flèche, jamais retirés.

Moteurs, méthodes, sources, limites, tests et maintenance : **ZMANIM.md**.

### Ce qui sort de l'appareil

Rien par défaut. Tout est dans les `SharedPreferences` locales ; pas de
compte, pas d'analytique. L'édition **Light** ne déclare aucune permission
Internet. L'édition complète déclare INTERNET pour deux services de vol,
derrière un seul interrupteur désactivé par défaut : le suivi en direct
(OpenSky : une zone d'environ 10°, l'indicatif reste sur le téléphone) et la
route d'un numéro de vol (adsbdb : le numéro saisi est envoyé).

La construction Play (`-Pplay=true`) n'a que la route adsbdb : les conditions
d'OpenSky excluent l'interrogation depuis chaque téléphone, et le relais qui
la remplacerait (`tools/relais_vol`) n'est pas en ligne
(`PUBLICATION_PLAY_STORE.md` § 3.1). Le site, sans relais configuré à la
construction, ne fait lui aussi que la requête adsbdb. `OnboardingTest` tient
la phrase de l'accueil de chaque édition à son manifeste, et
`ConfidentialiteTest` les règles de confidentialité au code.

Ce que l'utilisateur fait sortir lui-même : le fichier d'export, le partage
d'une journée en image, et l'e-mail de dédicace écrit dans sa propre
messagerie. La sauvegarde d'Android, si elle est activée, emporte les réglages
mais pas le journal (`web/src/confidentialite.html`).

### Construire

Le plus simple, sans rien installer : le workflow GitHub Actions `Android`
compile à chaque envoi sur `main` et publie l'APK dans la release `latest`.

Lien de téléchargement direct, dépôt privé donc connexion GitHub nécessaire :
<https://github.com/myhitbo/MyHitbodedut/releases/latest/download/MyHitbodedut.apk>

L'APK est signé par la clé stable de `android/keystore`, et n'est pas déboguable.
Android demandera d'autoriser l'installation depuis une source inconnue pour le
navigateur utilisé.

En local, avec Android Studio ou le SDK en ligne de commande :

```bash
cd android && ./gradlew assembleDebug
# → app/build/outputs/apk/debug/app-debug.apk
```

Pré-requis : JDK 17 et le SDK Android, plateforme 35.

### Deux éditions

| Édition | Contenu | Permissions sensibles |
| --- | --- | --- |
| `MyHitbodedut.apk` | Tout, barrière du matin comprise | Affichage par-dessus les autres applications, accès aux données d'utilisation |
| `MyHitbodedut-Light.apk` | Tout sauf la barrière et le vol en ligne | Position (zmanim, GPS en vol), Ne pas déranger |

L'édition légère existe pour une raison précise. Le couple affichage par-dessus
les autres applications et accès aux données d'utilisation est exactement celui
des logiciels de surveillance, et Play Protect refuse volontiers une application
hors boutique qui le demande. Sans la barrière, ce motif disparaît, et
l'installation passe sans discussion.

Elle sert aussi de test : si la légère s'installe et l'autre non, le blocage
vient bien des permissions, et pas du fichier ni du téléphone.

Les deux portent un identifiant différent et peuvent coexister sur le même
téléphone. Leurs données ne sont pas partagées ; l'export JSON permet de passer
de l'une à l'autre.

### Mettre à jour

Une application installée hors boutique ne se met pas à jour toute seule.
Android n'a aucun moyen de savoir d'où elle vient ni où chercher la suite.

**Le préalable technique.** Chaque compilation porte désormais un numéro de
version croissant, tiré du numéro d'exécution de l'intégration continue, et
chaque version reçoit son étiquette, `v1.12`, `v1.13`, et ainsi de suite. Sans
ce numéro, aucun outil ne peut voir qu'une version est plus récente que celle
installée. Le lien `releases/latest/download/MyHitbodedut.apk` continue de
pointer vers la dernière.

**Automatiser, en pratique.** [Obtainium](https://github.com/ImranR98/Obtainium)
surveille les pages de publication et installe les nouvelles versions. Il
interroge la source toutes les six heures par défaut. Pour un dépôt privé, il
faut lui donner un jeton GitHub à portée restreinte, dans ses réglages, section
des sources externes.

Marche à suivre : installer Obtainium, ajouter une application, coller
`https://github.com/myhitbo/MyHitbodedut`, choisir l'archive voulue, complète ou
Light, et laisser la vérification automatique active.

**Les autres voies.** Un mécanisme de mise à jour intégré à l'application
exigerait la permission d'installer des paquets et des connexions que
l'utilisateur n'a pas demandées. Ce serait aggraver la ressemblance de
l'application avec un logiciel de surveillance aux yeux de Play Protect. Une publication sur le Play Store donnerait de vraies
mises à jour automatiques, mais demande un compte développeur et le passage en
revue.

### Si l'installation échoue

Deux causes distinctes, souvent confondues.

**Une version antérieure est déjà installée.** Jusqu'au 19 septembre 2026, chaque
compilation était signée par une clé de débogage régénérée à neuf, donc une
identité différente à chaque fois. Android refuse d'installer une application
par-dessus une autre signée différemment. Le dépôt utilise désormais une clé
fixe, mais il faut désinstaller une fois les versions posées avant ce changement.

**Play Protect bloque l'installation.** Une application installée hors du Play
Store, qui demande l'affichage par-dessus les autres applications et l'accès aux
données d'utilisation, présente exactement le profil d'un logiciel de
surveillance. Le blocage est attendu. Sur l'avertissement, ouvrir « Plus de
détails » puis « Installer quand même ». Le blocage disparaît avec une
publication signée sur le Play Store, pas avant.

**Après l'installation, sur Android 13 et au-delà**, le système interdit
d'accorder l'accès aux données d'utilisation à une application installée hors
boutique tant que l'on n'a pas levé la restriction : informations sur
l'application, menu à trois points, « Autoriser les paramètres restreints ».

### Publier sur Google Play

Le cahier des charges complet est dans `PUBLICATION_PLAY_STORE.md`.

Ce que le dépôt fournit et ce qui reste à faire :

- [x] Code source complet et compilable
- [x] `applicationId`, icône, nom, traductions français, hébreu, anglais
- [ ] Compte développeur Google Play, frais uniques de 25 dollars
- [x] `targetSdk 36`, AAB Play : `./gradlew -Pplay=true bundleFullRelease`,
      ou le flux GitHub Actions `Play` (29/10)
- [ ] Clé d'envoi Play et ses quatre secrets `PLAY_*` (voir
      `PUBLICATION_PLAY_STORE.md`, § 5)
- [ ] Politique de confidentialité en ligne, obligatoire dès qu'une
      autorisation sensible est demandée :
      <https://myhitbodedut.pages.dev/confidentialite.html> (Cloudflare Pages,
      déployée par le flux `Web` ; secrets `CLOUDFLARE_API_TOKEN` et
      `CLOUDFLARE_ACCOUNT_ID`, voir `PUBLICATION_PLAY_STORE.md` § 6.1)
- [ ] Formulaire Sécurité des données : une seule donnée, le numéro de vol
      recherché, facultative (`PUBLICATION_PLAY_STORE.md` § 6.2)
- [ ] Déclaration des services au premier plan (`specialUse`,
      `mediaPlayback`) et de la position exacte (§ 6.6, § 6.7)
- [x] Textes de la fiche en anglais et en hébreu (`play/fiche/`), et
      pas-à-pas de la saisie dans la Play Console : `play/CONSOLE.md`
- [ ] Visuels de la fiche, à refaire sur la construction Play
      (`play/visuels/legendes.json`, § 7.2)

À savoir avant de soumettre : l'affichage par-dessus les autres applications et
l'accès aux données d'utilisation attirent l'attention de la revue. Décrire
honnêtement la fonction, une barrière volontaire que l'utilisateur installe et
configure lui-même, est la meilleure approche.

### Limites connues

- **Contournable, et c'est voulu.** L'écran de garde est un ralentisseur, pas un
  verrou. Passer par les applications récentes, redémarrer, ou désactiver
  l'application dans les Réglages permet de l'éviter. Comme pour l'app de
  référence, l'objectif est de rompre l'automatisme du matin, pas d'enfermer.
- **Détection à environ une seconde.** La surveillance interroge le système
  toutes les 900 ms. L'application bloquée peut donc rester visible un instant
  avant que l'écran n'apparaisse.
- **Non testée sur un appareil physique** à ce stade. Le code compile en
  intégration continue, mais le comportement de l'overlay varie selon les
  surcouches constructeur, en particulier Xiaomi, Huawei et Samsung, qui
  ajoutent leurs propres restrictions d'arrière-plan.
- **La barrière n'existe que sur Android.** iOS n'autorise pas ce type de
  blocage par une application tierce ; le site et la version Nokia ont le
  reste (minuteur, journal, textes), pas la barrière.

## `index.html` à la racine

Ce fichier n'est pas la version web de l'application (elle est dans `web/`).
C'est un ancien prototype autonome, sans lien avec le reste du dépôt ; s'il
n'a plus d'usage, il peut être supprimé avec cette section : au propriétaire
d'en décider. Pour l'ouvrir :

```bash
python3 -m http.server 8080
```

Suivi d'habitudes générique, stockage dans le `localStorage`, Tailwind et Lucide
chargés depuis un CDN, donc connexion nécessaire au chargement.
