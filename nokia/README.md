# MyHitbodedut pour téléphone à touches

Un produit à part de l'application Android : construit et testé par `.github/workflows/nokia.yml`, puis publié dans son propre dépôt, [myhitbo/Nokia-my-hitbodedut-app](https://github.com/myhitbo/Nokia-my-hitbodedut-app) (fichier `depot/README.md`), comme le site iPhone l'est dans myhitbo/myhitbodedut-web.

Une vraie application, en un seul fichier : `MyHitbodedut.jar` (environ 720 Ko, dont 510 Ko pour le niggoun d'essai), en français, en anglais ou en hébreu, sans Internet, dans les couleurs de l'application et avec son personnage. Elle s'installe sur les téléphones à touches qui acceptent les applications Java (Java ME : MIDP 2.0, CLDC 1.1), dont le Nokia 3310 3G de 2017.

| Dans l'application Android | Dans MyHitbodedut.jar |
| --- | --- |
| Hitbodedout minutée : 5, 10, 15, 30 min, 1 h, 1 h 30, au choix | pareil ; pause à la touche centrale, sonnerie et vibration à la fin |
| Texte « Pour commencer », « Je n'arrive pas à parler », texte « Pour finir » | pareil |
| ’Hizouk par moment | les textes publiés (171 au 17/11, relus à chaque construction) : l'hébreu et sa traduction ; en hébreu, l'hébreu seul |
| Accueil | le personnage du jour, « À faire » ou « Faite : 20 min », la série et la semaine en carrés |
| Journal | minutes du jour, série, 7 derniers jours en barres, total |
| Musique | un niggoun d'essai (Niggoun 33), en boucle, qui continue pendant la hitbodedout |
| Rappels | un rappel quotidien, si le téléphone l'autorise (PushRegistry) ; sinon, l'alarme du téléphone |
| Langue (français, anglais, hébreu) | « Langue » : d'abord celle du téléphone (`microedition.locale` ; une autre langue donne l'anglais), puis le choix fait dans l'application, gardé dans son propre RecordStore `langue` |
| Défilement automatique des textes, vitesse 1 à 10 (3 par défaut, gardée) | touche 0 : lancer ou arrêter ; * et # (ou gauche et droite) : plus lent, plus vite ; haut ou bas le suspend ; « Défil. 3/10 » dans le bandeau (« Scroll 3/10 », « גלילה 3/10 » à gauche en hébreu) ; vitesse gardée dans le journal (version 3), comme `lecture_defilement_vitesse` |
| Comment vous appeler (צדיק / צדקת) | « Vous appeler » : Tsadik, Tsadeket ou pas choisi ; avec Tsadeket, le personnage est une femme et la fin dit « Bravo, Tsadeket ! » |

Les écrans sont dessinés (couleurs de `values/colors.xml`) ; le personnage change avec le moment, comme `Character.kt`. Les illustrations viennent de `drawable-nodpi/char_*.webp`, converties en PNG de 80 px par `app/genere-personnages.mjs` (un téléphone Java ne lit que le PNG) et gardées dans `app/res/p`. Pour qui a choisi Tsadeket, chaque pose devient celle de la planche féminine (`char_f_*.webp`, même table que `Personnage.kt` et `web/src/js/personnage.js`), gardée en `app/res/p/f_*.png` ; sans choix, ou Tsadik, rien ne change.

Absents : le Tikoun HaKlali, les autres morceaux, la bibliothèque.

## Les langues

L'interface est en français, en anglais ou en hébreu (`app/src/myhitbodedut/Mots.java` : un tableau par mot, traductions reprises de `values-en` et `values-iw` quand la phrase existe). Les textes de ’hizouk suivent la règle de l'application Android (`RegleLangue`) : en hébreu, l'hébreu seul ; en anglais, l'hébreu et l'anglais ; en français, l'hébreu et le français. Jamais une autre langue.

En hébreu, les écrans se retournent : titre du bandeau, chiffre des cartes, personnage et semaine de droite à gauche ; l'hébreu est aligné à droite, coupé aux espaces comme le reste. Le téléphone dessine chaque ligne dans le bon sens (bidi de `drawString`) : l'application ne fait que placer. L'hébreu s'affiche sans nikkoud (une police de téléphone le dessine rarement) ; un téléphone sans police hébraïque montrera des carrés à la place de l'hébreu, y compris au-dessus des traductions.

## La musique : un essai

Les 146 Mo de musique de l'application ne tiennent pas dans un .jar. Le niggoun 33 (1 min 51) y est en deux versions, produites par `app/genere-musique.sh` et gardées dans `app/res/m` : MP3 mono 24 kb/s (334 Ko) et AMR-NB 12,2 kb/s (178 Ko). L'écran « Musique » essaie le MP3, puis l'AMR, et affiche celle qui joue, ou pourquoi aucune ne joue, avec la liste des formats audio que le téléphone déclare. Selon le résultat sur le 3310, on ajoute d'autres niggounim dans le format qui passe, ou on les laisse au lecteur de musique du téléphone.

## Téléphones

- **Nokia 3310 3G de 2017** (Smart Feature OS) : accepte les applications Java (Wikipédia, et un développeur l'a testé sur Stack Overflow).
- **Nokia 3310 de 2017 (2G)** : sources contradictoires.
- **Nokia 3310 3G de 2019** (Series 30+ sur Mocor) : pas d'applications Java.

## Installer

Envoyer `MyHitbodedut.jar` au téléphone par Bluetooth (ou le copier sur la carte microSD), l'ouvrir dans le gestionnaire de fichiers, accepter l'installation (« application non signée » : c'est normal).

## D'où viennent les textes

Rien n'est recopié : `app/genere-textes.mjs` relit `res/raw/chizuk.json` et `values/strings.xml` et `values-en`, `values-iw`, et applique les règles de l'application (`web/src/js`) : seul passe un ’hizouk relevé de la source et relu, avec son hébreu et ses traductions française et anglaise ; le téléphone ne lit que l'hébreu et la langue de l'interface. Le français et l'anglais sont ramenés à Latin-1 (« œ » devient « oe », « … » devient « ... ») ; l'hébreu garde ses lettres, sans nikkoud ni cantillation. Les trois langues coûtent environ 50 Ko de plus dans le .jar.

## Construire et tester

```sh
nokia/app/build.sh   # nokia/dist/MyHitbodedut.jar
nokia/app/test.sh    # règles (Java), textes (Node), parcours à l'écran 240×320
```

Il faut Node, un JDK 8 (le dernier dont `javac` vise encore Java 1.3, ce qu'exige CLDC) et Java 11 ou plus pour ProGuard, qui fait la pré-vérification sans laquelle le téléphone refuse le fichier. Les API MIDP/CLDC, ProGuard et MicroEmulator sont téléchargés dans `nokia/app/outils`.

Le parcours à l'écran joue l'application dans MicroEmulator, sur un appareil 240×320 (`app/test/appareil240`), touche par touche, et garde une capture de chaque étape dans `nokia/app/build/captures` : en français (dont le défilement automatique, touche 0), puis l'écran Langue, l'accueil et un texte en anglais et en hébreu (avec son défilement automatique), et le journal en hébreu.
