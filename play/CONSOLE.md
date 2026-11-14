# Play Console — pas-à-pas de la saisie

Rédigé le 14/11/2026 pour la version Play de `com.myhitbodedut` (édition
complète, `-Pplay=true`). Ce fichier dit **quoi saisir ou cocher**, formulaire
par formulaire ; le pourquoi est dans `PUBLICATION_PLAY_STORE.md` (les numéros
de § y renvoient). Les textes à coller sont en anglais, tels quels, dans les
blocs de code.

La Play Console change souvent ses intitulés (« App access » s'appelle
« Sign-in details » depuis octobre 2026, par exemple). Les intitulés ci-dessous
sont ceux de la console en anglais, relus dans l'aide de Google le 14/11/2026 ;
si un écran diffère, répondre selon le sens indiqué ici.

**État de l'application à déclarer (ne rien écrire qui le contredise) :**

- ni compte, ni publicité, ni achat, ni outil d'analyse, ni rapport d'erreur ;
- la version Play n'a **pas de suivi de vol en direct** : elle n'interroge
  jamais OpenSky et il n'y a pas de relais ;
- seule donnée qui sort du téléphone par l'application : le **numéro de vol**
  que l'utilisateur recherche, envoyé à `api.adsbdb.com` après son accord,
  derrière un interrupteur éteint par défaut ;
- le reste ne sort que par un geste de l'utilisateur dans une autre application
  (e-mail de dédicace écrit dans sa messagerie, partage, fichier d'export) ;
- la position (approximative ou exacte) sert au calcul sur le téléphone et
  n'est jamais envoyée.

Le jour où un relais de suivi de vol est mis en ligne (§ 3.1), ce fichier, les
règles de confidentialité et la fiche sont à reprendre **avant** d'envoyer
l'AAB : voir « Si le relais arrive » à la fin.

---

## 0. À avoir sous la main

| Quoi | Où |
| --- | --- |
| AAB signé et `mapping.txt` | artefact `play-N` du flux `play.yml` (§ 5.2) |
| Règles de confidentialité en ligne | https://myhitbodedut.pages.dev/confidentialite.html — **l'ouvrir depuis un téléphone**, dans un navigateur sans session, avant de la saisir |
| Textes de la fiche | `play/fiche/en-US/` et `play/fiche/iw-IL/` (`title.txt`, `short_description.txt`, `full_description.txt`) |
| Icône 512 × 512 | `play/icone-512.png` |
| Image de présentation 1024 × 500 | `play/fiche/<langue>/images/featureGraphic.png` |
| Captures (8 par langue) | prises sur la construction Play, puis composées avec les légendes de `play/visuels/legendes.json` (dossiers `en-US` et `iw-IL`) |
| Deux vidéos YouTube « non répertoriées » | à tourner : voir 3.9 |
| Adresse de contact | `myhitbodedut26@gmail.com` |
| 12 testeurs (adresses Gmail) | pour le test fermé de 14 jours (§ 4, § 9) |

---

## 1. Compte développeur

Création, frais, vérifications : § 4. Deux saisies demandent une décision.

**Nom du développeur** (public) : `MyHitbodedut Team` — c'est le nom que citent
les règles de confidentialité.

**Statut de commerçant** (*Trader status*, exigé à la création du compte depuis
novembre 2026 ; *Manage account → Account details → About you*). Google demande
si le compte agit comme commerçant au sens du droit européen. C'est une
déclaration juridique du propriétaire, pas un choix technique :

- application gratuite, sans publicité ni achat, publiée à titre non
  professionnel : **Non-trader** ;
- si le propriétaire publie dans le cadre d'une activité professionnelle :
  **Trader** — sur un compte personnel, l'adresse et un numéro de téléphone
  deviennent alors publics sur la fiche.

---

## 2. Créer l'application

*All apps → Create app.*

| Champ | Saisir |
| --- | --- |
| App name | `MyHitbodedut – Hitbodedut` |
| Default language | **English (United States) – en-US** |
| App or game | **App** |
| Free or paid | **Free** (définitif : une application gratuite ne peut plus devenir payante) |
| Declarations | cocher *Developer Program Policies* et *US export laws* |

---

## 3. Contenu de l'application

*Monitor and improve → Policy and programs → App content.* Tout est à remplir
avant le premier envoi en test fermé.

### 3.1 Privacy policy

```
https://myhitbodedut.pages.dev/confidentialite.html
```

### 3.2 Sign-in details (ex-« App access »)

L'application n'a ni compte ni contenu réservé : choisir *All functionality in
my app is available without any access restrictions* si la console le propose.

Google n'a pas de champ « note aux examinateurs » ; c'est ici qu'on peut leur
dire comment voir la barrière à n'importe quelle heure. Ajouter des
instructions (*Add new instructions*). Si la console ne les accepte qu'avec
l'option *All or some functionality is restricted*, choisir cette option : la
barrière n'agit que dans une plage horaire, et l'examinateur a besoin du
chemin ci-dessous pour la voir. Créer une entrée :

- *Instruction name* : `Morning gate preview (no login needed)`
- *Username* et *Password* : laisser vides (ou `none` si la console les exige)
- *Any other instructions* : le texte ci-dessous. Les crochets entourent les
  libellés exacts de l'interface anglaise.

```
No account or login is needed, and nothing is restricted. On first launch a short welcome appears: tap [Skip].

To see the morning gate at any time of day:
1. Bottom bar: [Settings].
2. Card [Mode status]: tap [Preview the “I am with Hashem” screen now].
3. The first time, a dialog titled [Display over other apps] explains the access. Tap [Continue], allow MyHitbodedut in the Android screen that opens, go back, and tap the button again.
4. The gate appears over the home screen with the badge [PREVIEW, NO EFFECT]. [Close the preview] dismisses it.

To see it act for real:
1. [Settings], card [Required permissions]: tap [Grant] for [Display over other apps] and for [Usage access]. Each shows an in-app disclosure first.
2. Card [I am with Hashem]: turn the switch on, tap [Choose apps] and pick one app, and set [Mode hours] around the current time.
3. Open the app you picked: the gate appears in front of it.
On Saturdays and Jewish festivals the gate is silent by default (card [Rhythm], [Shabbat and Yom Tov]).

The gate is a self-discipline tool that users set up on their own phone, for themselves, and can switch off at any time (Settings, [I am with Hashem] switch). It monitors no one else, has a permanent notification and never hides. No usage data leaves the device.
```

Le même texte sert de description aux deux vidéos (3.9).

### 3.3 Ads

**No, my app does not contain ads.**

### 3.4 Content rating

- *Email address* : `myhitbodedut26@gmail.com`
- *Category* : **All Other App Types** (ni jeu, ni réseau social)
- Questionnaire : **No** à toutes les questions — violence, sexualité,
  langage grossier, drogues, alcool et tabac, jeux d'argent, promotion de
  produits réservés aux adultes, échanges entre utilisateurs, partage de la
  position avec d'autres utilisateurs, achats numériques, navigateur ou moteur
  de recherche, application d'actualités.

Classement attendu : tout public (*Everyone*, PEGI 3).

### 3.5 Target audience and content

- *Target age* : cocher **18 and over** seulement (§ 6.4). Une tranche sous
  13 ans ferait entrer l'application dans le programme Familles.
- *Appeal to children* (« la fiche pourrait-elle attirer des enfants sans le
  vouloir ? ») : **No**.

### 3.6 Data safety

Raisonnement (§ 6.2) : pour Google, « collecter » veut dire faire sortir une
donnée du téléphone, même vers un tiers et même si le développeur ne la reçoit
jamais. Le numéro de vol envoyé à adsbdb est donc une donnée **collectée**.
Elle n'est pas **partagée** au sens du formulaire : l'envoi suit un geste de
l'utilisateur, qui en est averti et l'a accepté.

Page *Data collection and security* :

| Question | Réponse |
| --- | --- |
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (HTTPS seulement, trafic en clair interdit) |
| Which of the following methods of account creation does your app support? | **My app does not allow users to create an account** |
| Do you provide a way for users to request that their data is deleted? (si la question est posée) | **No** — le développeur ne détient aucune donnée venue de l'application, il n'a rien à effacer ; ce que le téléphone garde s'efface par Réglages → « Réinitialiser l'application » |

Page *Data types* : cocher **une seule** ligne.

- *App activity* → **In-app search history**

Ne **pas** cocher : *Location* (la position ne quitte pas le téléphone),
*Personal info* (le prénom et le journal restent sur le téléphone ; l'e-mail
de dédicace est écrit et envoyé par l'utilisateur dans sa propre messagerie,
l'application ne transmet rien), *Installed apps* (la liste des applications
de la barrière reste sur le téléphone), *Device or other IDs*, *Diagnostics*.

Page *Data usage and handling*, pour *In-app search history* :

| Question | Réponse |
| --- | --- |
| Is this data collected, shared, or both? | **Collected** seulement |
| Is this data processed ephemerally? | **No** (adsbdb est un tiers dont on ne maîtrise pas la conservation) |
| Is this data required for your app, or can users choose whether it's collected? | **Users can choose whether this data is collected** |
| Why is this user data collected? | **App functionality** seulement |

L'aperçu final doit afficher : *No data shared with third parties* ; *Data
collected: App activity (In-app search history), optional* ; *Data is encrypted
in transit*.

### 3.7 Advertising ID

**No** — l'application n'utilise pas l'identifiant publicitaire (aucune
bibliothèque de publicité ni d'analyse ; le manifeste ne déclare pas `AD_ID`).

### 3.8 Autres déclarations

| Déclaration | Réponse |
| --- | --- |
| Government apps | **No** |
| Financial features | **My app doesn't provide any financial features** |
| News apps | **No** |
| Health apps | **My app doesn't provide any health features** — voir la réserve |

**Réserve sur « Health apps » (décision du propriétaire).** L'application est
un outil de prière : elle ne donne aucun conseil de santé et ne promet aucun
bienfait. Mais Google range sous *Stress management, relaxation, mental
acuity* les applications de « mindfulness, meditation », et l'application
parle de « meditation session » dans sa déclaration de service (3.9) et note
l'humeur avant et après. Deux réponses défendables :

- *My app doesn't provide any health features* (recommandée), en gardant la
  fiche sans aucune promesse de bien-être et en évitant le tag « Meditation » ;
- si Google conteste : cocher *Stress management, relaxation, mental acuity*
  (catégorie « Health and fitness », sans exigence médicale).

### 3.9 Foreground service permissions

Trois lignes, à remplir une par une (§ 6.6). Les descriptions reprennent mot
pour mot celles du manifeste : ne pas les reformuler.

**A. Special use — le minuteur (`SessionService`)**

- *Use case* : **Other**, puis :

```
Runs the countdown of a user-started meditation session and shows the remaining time, so the phone can be put down.
```

- *User impact if the task is deferred or interrupted* :

```
The user starts a timed prayer session (5 to 90 minutes) and puts the phone down, screen off. If the task is deferred, the countdown the user just started does not begin. If it is interrupted, the countdown stops silently: the user is never told the time is over and the time spent is not added to their journal.
```

- *Video* : vidéo 1.

**B. Media playback — la musique de la séance (`SessionService`)**

- *Use case* : **Media Playback**
- *Description* :

```
Plays the track the user chose for their session (a niggun, a wordless melody), with the screen off, until the session ends. Playback starts only when the user starts a session with music turned on.
```

- *User impact* :

```
If the task is deferred or interrupted, the music the user started does not play, or stops, as soon as the screen turns off.
```

- *Video* : vidéo 1.

**C. Special use — la barrière (`GateService`)**

- *Use case* : **Other**, puis :

```
Interposes a confirmation screen over user-selected apps during a user-defined morning window, until the user confirms their daily practice, and during any user-started session until it ends.
```

- *User impact* :

```
The user turns this gate on for themselves and picks the apps it applies to. If the task is deferred or interrupted, the screen does not appear when one of these apps is opened: the feature the user switched on silently stops working. While it runs it shows a permanent notification, and the user can switch it off at any time in Settings.
```

- *Video* : vidéo 2.

**Les deux vidéos** (YouTube, *Unlisted*, moins de deux minutes, téléphone en
anglais, construction Play) :

1. *Session* — onglet [Today] ; choisir une durée et un morceau ; lancer la
   hitbodedout ; éteindre l'écran ; le rallumer : la notification montre le
   temps restant et la musique continue.
2. *Morning gate* — le parcours « To see it act for real » de 3.2, en montrant
   les deux fenêtres de divulgation, l'écran de garde devant l'application
   choisie, puis [I already did it] et l'interrupteur qui coupe la barrière.

### 3.10 Position exacte (`ACCESS_FINE_LOCATION`)

Formulaire ouvert par Google en novembre 2026, **obligatoire à compter du
27/01/2027** (§ 6.7). S'il est proposé, le remplir tout de suite.

- *Which user-facing features in your app require ACCESS_FINE_LOCATION?* :
  **Other**
- *Explain why ACCESS_COARSE_LOCATION or LocationButton is not sufficient* :

```
One feature only: “Zmanim in flight”. The user enters a flight and the app computes the prayer times along the route. When the user taps “Real position (GPS)”, the app takes a single GPS fix to correct the aircraft’s position on that route. In flight there is no network, so only the satellite (GPS) provider can give a position, and on Android 8 to 11, which the app supports, that provider is available only with ACCESS_FINE_LOCATION. The fix is taken once per tap, in the foreground, processed on the device and never sent anywhere. Everywhere else (prayer times on the ground, compass to Jerusalem) the app requests ACCESS_COARSE_LOCATION only. The app targets API 36; when it targets API 37, this one-time request will move to the Android location button.
```

### 3.11 Les deux accès spéciaux de la barrière

`SYSTEM_ALERT_WINDOW` et `PACKAGE_USAGE_STATS` n'ont pas de formulaire : ils
sont examinés à la revue. Ce qui les défend est déjà en place, à ne pas
affaiblir : la divulgation dans l'application avant chaque accès, le paragraphe
« THE MORNING GATE » de la fiche, la note de 3.2 et la vidéo 2. L'argument, le
même partout : une barrière que l'utilisateur installe sur son propre
téléphone, contre ses propres habitudes, et qu'il coupe quand il veut.

---

## 4. Fiche

*Grow users → Store presence → Main store listing.*

### 4.1 English (United States) — langue par défaut

| Champ | Coller |
| --- | --- |
| App name | le contenu de `play/fiche/en-US/title.txt` |
| Short description | `play/fiche/en-US/short_description.txt` |
| Full description | `play/fiche/en-US/full_description.txt` |
| App icon | `play/icone-512.png` |
| Feature graphic | `play/fiche/en-US/images/featureGraphic.png` |
| Phone screenshots | les 8 visuels composés pour `en-US`, dans l'ordre de `play/visuels/legendes.json` : accueil, séance, barrière, siddour, zmanim, textes, boussole, journal |
| Tablet screenshots | facultatif ; ne rien mettre plutôt que des captures de téléphone étirées |
| Video | laisser vide |

### 4.2 Hebrew — iw-IL

*Add translation → Hebrew – iw-IL*, puis les mêmes champs avec
`play/fiche/iw-IL/`. Ne pas laisser Google traduire automatiquement.

**Pas de fiche en français** (§ 7.1) : un téléphone en français voit la fiche
anglaise.

Avant d'envoyer, regarder chaque capture hébraïque : aucun Nom divin écrit en
toutes lettres hors d'un verset, et aucun écran qui montre un morceau ou une
fonction absents de la version Play (pas de suivi de vol en direct).

---

## 5. Paramètres de la fiche

*Grow users → Store presence → Store settings.*

| Champ | Saisir |
| --- | --- |
| App category | **App**, catégorie **Lifestyle** |
| Tags | choisir dans la liste de Google les plus proches de : religion, prière, calendrier. Éviter « Meditation » tant que la réponse « Health apps » est « aucune fonction de santé » (3.8) |
| Email address | `myhitbodedut26@gmail.com` (public) |
| Phone number | laisser vide |
| Website | laisser vide tant que le site public livre des morceaux dont les droits ne sont pas établis (§ 3.2) ; ensuite `https://myhitbodedut.pages.dev/` |

---

## 6. Envoi et tests

1. *Test and release → Testing → Internal testing → Create new release* :
   accepter **Play App Signing**, envoyer `MyHitbodedut-N.aab`. Nom de la
   version : laisser celui que propose la console. Notes de version :

   ```
   First release.
   ```

2. *App bundle explorer* : envoyer `mapping-N.txt` avec le même numéro (§ 5.4).
3. Passer la recette du § 8 sur l'application **installée depuis Play**.
4. *Closed testing* : créer la piste, y inscrire les 12 testeurs, choisir les
   pays, envoyer la même version. Les 14 jours comptent à partir du moment où
   les 12 sont inscrits ; aucun ne doit se désinscrire.
5. Après 14 jours : *Dashboard → Apply for production access*. Le
   questionnaire porte sur le test (qui a testé, ce qui a été corrigé) : y
   répondre avec ce qui s'est réellement passé.
6. *Production → Countries/regions* : tous les pays, puis déploiement
   progressif (§ 9).

---

## 7. À revérifier avant chaque envoi

- [ ] La page des règles de confidentialité s'ouvre et porte la date de la
      dernière modification.
- [ ] La fiche ne promet rien que la version Play n'a pas (suivi en direct,
      morceaux hors Play).
- [ ] Les réponses de 3.6 décrivent toujours ce que fait l'AAB : chercher une
      nouvelle adresse réseau dans le code avant d'envoyer.
- [ ] Les descriptions de 3.9 sont identiques aux
      `PROPERTY_SPECIAL_USE_FOREGROUND_SERVICE_SUBTYPE` des manifestes.

---

## Si le relais arrive

Le jour où `RELAIS_VOL` est renseigné dans `play.yml`, la version Play retrouve
le suivi en direct, et le téléphone envoie au relais du développeur
l'indicatif du vol et la position estimée de l'avion. Avant d'envoyer cet AAB :

1. règles de confidentialité : « En bref » (le développeur a un serveur) et
   « Les vols », dans les trois langues (texte prêt : § 3.1) ;
2. 3.6 : ajouter *Location → Approximate location* (collectée, facultative,
   *App functionality*) ;
3. fiche, deux langues : ajouter la ligne d'attribution exigée par OpenSky
   (§ 7.1) ;
4. état de l'application, en tête de ce fichier.
