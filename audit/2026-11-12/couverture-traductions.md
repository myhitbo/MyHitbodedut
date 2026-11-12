# Couverture des traductions — tout texte visible est-il traduit ?

État audité : dépôt `MyHitbodedut`, branche courante (commit `0274b05`, 05/11/2026), site construit `myhitbodedut-web` (version `10227679bb4f`).
Méthode : inventaire par scripts (dossier `scripts-couverture/` à côté de ce fichier), sans rien modifier. Une « unité » est un bloc de livre, un verset, un paragraphe, une halakha ou une notice. Le « volume » est compté en lettres hébraïques de la source (sans voyelles ni balises).

## Réponse courte

**Non, tous les textes ne sont pas traduits.**

| Périmètre | Entrées | Hébreu | Français | Anglais |
| --- | ---: | ---: | ---: | ---: |
| Interface (chaînes traduisibles de `strings.xml`) | 1 177 | 100 % | 100 % | 100 % |
| Textes à lire (livres, siddourim, Tehilim, Tikoun, bibliothèque, 'hizouk, halakha du jour, hilloulot), en unités | 41 792 | 100 % | **40,3 %** (16 846) | **40,3 %** (16 846) |
| Les mêmes textes, en volume (10,45 millions de lettres hébraïques) | — | 100 % | **23,4 %** | **23,4 %** |
| Toutes les entrées affichables des fichiers de données (textes, titres, noms, libellés) | 52 600 | 95,2 % | **42,5 %** | **42,9 %** |

L'interface est complète dans les trois langues. Les contenus ne le sont qu'à 40 % en nombre et à moins d'un quart en volume, en français comme en anglais (les deux langues ont toujours été traduites ensemble : aucun bloc n'a l'une sans l'autre, hors 50 noms de hilloulot). Le déficit de l'hébreu (4,8 %) tient entièrement aux noms d'aéroports.

Ce qui est traduit à 100 % : Tehilim, Tikoun haKlali, onze des douze livres, la bibliothèque (sources et résumés), le 'hizouk, les invitations de la hitbodedout guidée.
Ce qui ne l'est pas : les trois siddourim (0 %), la halakha du jour (0 %), les notices et biographies des hilloulot (0 %), 89,6 % du Yalkout Yossef – Kitsour Choul'han Aroukh, les noms de 95 % des tsadikim.

**L'utilisateur est-il prévenu ?** Une seule lacune est annoncée à l'écran (la halakha du jour : « Texte original en hébreu, verbatim. »). Partout ailleurs, l'hébreu remplace la traduction manquante sans un mot, et le menu des langues de lecture « אA » propose « Français » et « English » même pour un texte qui n'a ni l'un ni l'autre.

---

## (a) Chaînes d'interface

Fichiers : `android/app/src/main/res/values/strings.xml` (français, défaut), `values-en/strings.xml`, `values-iw/strings.xml`.

| Mesure | Français | Anglais | Hébreu |
| --- | ---: | ---: | ---: |
| Entrées du fichier | 1 222 | 1 177 | 1 177 |
| dont `string` | 1 184 | 1 139 | 1 139 |
| dont `plurals` | 36 | 36 | 36 |
| dont `string-array` | 2 (4 et 8 éléments) | 2 | 2 |
| Entrées traduisibles | 1 177 | 1 177 | 1 177 |
| Clés manquantes | — | **0** | **0** |
| Clés en trop | — | 0 | 0 |
| Valeurs vides | 0 | 0 | 0 |
| Marqueurs de format (`%1$s`…) différents du français | — | 0 | 0 |
| Formes de pluriel | one, other | one, other | one, two, other |
| Valeurs identiques au français | — | 59 | 14 |
| Pourcentage traduit | 100 % | 100 % | 100 % |

**Les 45 entrées `translatable="false"`** (une seule valeur pour les trois langues) :

| Groupe | Nombre | Valeur | Ce que voit l'utilisateur |
| --- | ---: | --- | --- |
| Nom de l'application (`app_name`, `app_name_light`) | 2 | MyHitbodedut | identique partout : normal |
| Aperçus de vignette (`widget_apercu_*`) | 2 | « 15 / 20 », « 7 » | chiffres : normal |
| Marques (`week_shabbat_mark` « ש », `status_separator` « · ») | 2 | signes | normal |
| Titres hébreux posés au-dessus de leur traduction (`siddur_tehilim_he`, `siddur_tikkun_he`) | 2 | hébreu vocalisé | voulu |
| Titre d'un article cité (`boussole_source_titre`) | 1 | anglais | titre d'origine : normal |
| Titres de morceaux en hébreu (`track_hamelech_basade`, `track_yanuka_nigoun_3`) | 2 | « המלך בשדה », « ניגון — הינוקא (3) » | hébreu seul en français et en anglais |
| **Titres de morceaux rédigés en français** | **9** | « Niggoun du Baal Chem Tov — Ianir », « Zemer bichva'hin (titre incertain) — Ianir », « Niggoun de Berditchev », « Kol baYa'ar (Niggoun du Saba de Chpola) », « Niggoun de Rabbi Yo'hanan HaSandlar », « Niggoun de 'Houppa », « Niggoun de Kabbalat Chabbat (live) », « Niggoun de Bessarabie », « Niggoun « Ki hiné ka'homer » » | **français affiché tel quel en anglais et en hébreu** (lacune non annoncée) |
| Titres de morceaux en anglais ou translittérés | 25 | « Beyond — Noam Shpayer », « The King Will Return — The Yanuka's Melodies »… | titre d'origine |

Les 31 autres titres de morceaux (`track_niggoun_NN`) sont traduits : « Niggoun 01 » / « Niggun 01 » / « ניגון 01 ».

**Valeurs anglaises identiques au français (59)** — toutes légitimes : formats (`%1$d / %2$d`, `%1$s · %2$s`, `%1$d min`, `%1$s° N`…), mots communs aux deux langues (Notifications, Journal, Volume, Pause, Source, Article, Sections, Records, Bronze, Silence, Gratitude, Diaspora, Version, « 1 minute », « %1$s minutes »), noms propres et termes hébreux (Ashkenaz, Sfard (Arizal), Zmanim, Hallel, Arvit, Al hanissim, Morid hatal, Yom HaZikaron, Yalkut Yosef, MyTzadik, Torat Emet, David), noms des langues écrits dans leur langue (`langues_*`), et la chaîne hébraïque `tikkun_psalm_he` (« תהילים %1$s »). Quatre seulement sont des graphies françaises laissées en anglais : `theme_parnassa` et `tefila_parnassa` (« Parnassa »), `adresse_tsadik` (« Tsadik »), `adresse_tsadeket` (« Tsadeket »).

**Valeurs hébraïques identiques au français (14)** : 8 formats, `proofread_line_fr/en` (écran de relecture), `hilloula_source_mytzadik`, `tikkun_psalm_he`, et les noms des langues. Aucune phrase française n'est restée dans le fichier hébreu ; 39 valeurs hébraïques contiennent des mots latins, tous des noms propres ou techniques (MyHitbodedut, adsbdb.com, OpenSky, GPS, GeoNames, PDF, ICAO).

**Mots hébreux dans les chaînes françaises (20) et anglaises (19)** : 4 intentions de dédicace (translittération + hébreu entre parenthèses), 8 rappels liturgiques qui citent la formule en hébreu seul (« וְתֵן טַל וּמָטָר לִבְרָכָה », « מַשִּׁיב הָרוּחַ »…), 2 légendes de la boussole (« ירושלים »), `ajout_embolismique`, `tikkun_psalm_he`, 3 noms de langues. Une seule différence entre les deux langues : `ajout_facultatif_apres` garde « הרחמן » en français (« הרחמן et fin : d'usage ») alors que l'anglais translittère (« HaRachaman and closing »).

Autres ressources : aucun texte en dur dans les gabarits (`res/layout*`, `res/menu`, `res/xml`), ni dans le manifeste (tous les libellés d'activités et de vignettes passent par `@string`). `res/xml/locales_config.xml` déclare bien fr, en, iw.

---

## (b) Fichiers de contenu (`res/raw/*.json`, 27 fichiers)

### Livres (12 fichiers `livre_*.json`, index `livres_titres.json`)

| Livre | Blocs de texte (`t`) | Hébreu | Français | Anglais | % traduit (blocs) | Titres de chapitres traduits | Intertitres `c` (hébreu seul) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Likoutei Moharan | 7 057 | 7 057 | 7 057 | 7 057 | 100 % | 411 / 411 | 0 |
| Likoutei Etsot | 1 308 | 1 308 | 1 308 | 1 308 | 100 % | 55 / 55 | 0 |
| Sefer HaMiddot | 2 688 | 2 688 | 2 688 | 2 688 | 100 % | 108 / 108 | 53 (« חלק שני ») |
| Hichtapkhout HaNefech | 399 | 399 | 399 | 399 | 100 % | 105 / 105 | 35 (« אות א »…) |
| Kokhvei Or | 211 | 211 | 211 | 211 | 100 % | 16 / 16 | 195 (numéros « א », « ב »…) |
| Le guide complet de la hitbodedout | 143 | 143 | 143 | 143 | 100 % | 18 / 18 | 0 |
| Tefila LiChlomo (Yanouka) | 147 | 147 | 147 | 147 | 100 % | 10 / 10 | 16 (mention d'auteur et de droits) |
| Méguilat Esther | 167 | 167 | 167 | 167 | 100 % | **0 / 10** (« פרק א ») | 0 |
| Chir HaChirim | 117 | 117 | 117 | 117 | 100 % | **0 / 8** (« פרק א ») | 0 |
| Nichmat kol 'haï | 9 | 9 | 9 | 9 | 100 % | 1 / 1 | 0 |
| Perek Chira | 99 | 99 | 99 | 99 | 100 % | 7 / 7 | 0 |
| **Yalkout Yossef – Kitsour Choul'han Aroukh** | **14 303** | 14 303 | **1 489** | **1 489** | **10,4 %** (11,2 % du volume) | **92 / 1 048** | 87 (titres de parties, mention de droits) |
| **Total** | **26 648** | 26 648 | **13 834** | **13 834** | **51,9 %** (40,8 % du volume) | 823 / 1 797 | 386, 0 traduit |

- Titres des 12 livres et des 3 groupes (`livres_titres.json`) : hébreu, français, anglais, 100 %.
- **Yalkout Yossef** : 91 chapitres entièrement traduits, 1 en partie (chapitre d'indice 139, 20 blocs sur 111, la traduction s'arrête au bloc 19), 956 sans rien. Les chapitres traduits sont tous dans les 140 premiers, avec des trous (indices 61, 69-71, 83-84, 88-93, 102-107, 109-138). Rien sur Chabbat, Roch 'Hodech, Pessa'h, les fêtes, la cacherout. Le fichier porte pourtant la note « FR et EN originales (Claude, 04/11/2026)… », comme les livres entièrement traduits.
- Ce que voit l'utilisateur quand la traduction manque : l'hébreu du bloc, seul, à la place de la traduction, **sans message**. Le message prévu (« Ce texte n'a pas encore de traduction : il reste en hébreu. ») ne s'affiche que si le livre entier n'a aucun bloc traduit (`SiddurLectureActivity.kt` lignes 253-254 ; `web/src/js/app.js` ligne 1473) : aucun des 12 livres n'est dans ce cas, il ne s'affiche donc jamais.
- Les intertitres `c` ne sont jamais traduits, par construction (`if (consigne) emptyList()`, `SiddurLectureActivity.kt` ligne 509).
- Avant d'ouvrir un livre, la liste n'affiche que le titre et le nombre de chapitres : rien sur l'état de la traduction. Les champs `traduction` et `traductions` (origine, licence) des fichiers ne sont lus par aucun écran.

### Siddourim (`siddur_edot.json`, `siddur_sefard.json`, `siddur_ashkenaz.json`, `siddur_annotations.json`)

| Champ | Edot HaMizra'h | Sfard | Ashkenaz | Total | Hébreu | Français | Anglais | Ce que voit l'utilisateur |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Titres des textes (Cha'harit, Min'ha…) | 38 | 38 | 38 | 114 | 100 % | 100 % | 100 % | titre traduit sous le titre hébreu |
| Titres des groupes | 4 | 4 | 4 | 12 | 100 % | 100 % | 100 % | traduit |
| Nom du noussa'h | 1 | 1 | 1 | 3 | 100 % | 100 % | 100 % | traduit |
| Titres de sections (bande de signets) | 66 | 76 | 92 | 234 | 100 % | **0 %** | **0 %** | hébreu seul |
| Prières (`t`) | 967 | 1 296 | 1 310 | 3 573 | 100 % | **0 %** | **0 %** | hébreu seul, sans message |
| Consignes (`c`) | 354 | 557 | 425 | 1 336 | 100 % | **0 %** | **0 %** | hébreu seul, sans message |
| Annotations du jour : libellés (`libelle`, `si`) | 398 | 556 | 618 | 1 572 | 100 % | 100 % | 100 % | libellé traduit (passe par `Libelles.kt` → `strings.xml`) |
| Annotations : textes insérés (`texte`) et consignes | 33 + 2 | 25 + 2 | 30 + 2 | 94 | 100 % | 0 % | 0 % | hébreu seul |

Les consignes ne sont pas de la liturgie : ce sont des indications pratiques, parfois des règles (« בתשעה באב ויום הכיפורים אין אומרים ברכה זו », « האשה מברכת בלי שם ומלכות », 41 consignes de plus de 80 caractères dans le seul noussa'h Edot). Lacune non annoncée ; le menu « אA » propose pourtant les six modes de langue sur cet écran.

### Tehilim, Tikoun

| Fichier | Champ | Entrées | Hébreu | Français | Anglais | % traduit | Si la traduction manque |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| `tehilim.json` | versets (150 psaumes) | 2 527 | 2 527 | 2 527 (Rabbinat 1899) | 2 527 (JPS 1917) | 100 % | — |
| `tikkun_haklali.json` | versets des dix psaumes | 164 | 164 | 164 | 164 | 100 % | — |
| `tikkun_haklali.json` | ouverture, clôture, kavana, prière de Rabbi Natan (paragraphes) | 26 | 26 | 26 | 26 | 100 % | — |
| `tikkun_haklali.json` | titres des parties, notes, mention de continuité | 7 | 7 | 7 | 7 | 100 % | — |
| les deux | titre de chaque psaume (`tikkun_psalm_he`) | 150 + 10 | « תהילים קי״ט » | **identique** | **identique** | 0 % | numéro en lettres hébraïques, même en mode « Français » ou « English » seul |

Le nombre de versets concorde psaume par psaume entre l'hébreu et les deux traductions (aucun écart, aucun verset vide). L'édition de la traduction (« Bible du Rabbinat 1899 », « JPS 1917 ») est dans le fichier mais n'est affichée nulle part.

### Bibliothèque (`bibliotheque.json`)

| Champ | Entrées | Hébreu | Français | Anglais | Affiché ? | Ce que voit l'utilisateur |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| Titres des sections et sous-sections | 4 | 4 | 4 | 4 | oui | traduit |
| Sources : paragraphes | 124 (29 sources) | 124 | 124 | 124 | oui | 100 % traduit |
| Sources : titre (`titre_he`) | 29 | 29 | — | — | oui | **hébreu seul** |
| Sources : `titre_fr` | 21 | — | 21 | **0** (`titre_en` n'existe pas) | **non** (aucun code ne le lit) | titres français écrits et inutilisés |
| Sources : référence (`ref`) | 29 | calculée | 29 | calculée | oui | traduite par `Reference.kt` (18 livres connus, 0 référence hors table) |
| Sources : `note`, `sujet`, `sur_la_torah`, `lecon_mesure` | 26 / 21 / 21 / 21 | — | français d'atelier | — | non | sans objet |
| Articles : titre, site, date | 24 | 24 | — | — | oui | hébreu seul (choix consigné le 22/09) |
| Articles : résumé | 24 | 24 | 24 | 24 | oui | 100 % traduit |
| Articles : droits, erreurs relevées | 24 / 1 | 24 / 1 | 24 / 1 | 24 / 1 | non (retirés le 19/10) | sans objet |

« La source du jour », sur l'accueil, n'affiche que le paragraphe hébreu (`SourceDuJour.kt` lignes 63-72 ; `app.js` ligne 742), alors que les 124 paragraphes ont leur traduction.

### 'Hizouk, hitbodedout guidée

| Fichier | Champ | Entrées | Hébreu | Français | Anglais | % traduit |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `chizuk.json` | texte (`he`, `fr`, `en`) | 171 | 171 | 171 | 171 | 100 % |
| `chizuk.json` | référence (`ref`) | 171 | calculée | 171 | calculée | 100 % (aucune hors table) |
| `chizuk.json` | `theme` (38 clés), `moments`, `note` (126), `tags` | — | — | français ou clés | — | non affichés |
| `guide_sujets.json` | invitations (9 sujets × 5 temps) | 45 | 45 | 45 | 45 | 100 % |

### Halakha du jour (`yalkut_yosef.json`, `ben_ish_hai.json`)

| Fichier | Entrées | Hébreu | Français | Anglais | % traduit | Ce que voit l'utilisateur |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `yalkut_yosef.json` (sélection de se'ifim, 12 périodes) | 788 | 788 | 0 | 0 | 0 % | hébreu, avec la note « Texte original en hébreu, verbatim. » — **seule lacune annoncée** |
| `ben_ish_hai.json` (98 parachiot + 'Hanouka) | 2 002 | 2 002 | 0 | 0 | 0 % | idem |
| Source affichée (« ילקוט יוסף · סימן… · סעיף ב », « בן איש חי · שנה ראשונה · לך לך · אות א ») | — | en dur dans le code | 0 | 0 | 0 % | hébreu seul |

Les 788 se'ifim de la sélection se retrouvent tous dans le livre `livre_yalkut_yosef_kitsour.json` ; **333 d'entre eux y sont déjà traduits en français et en anglais** (332 des 346 du cycle ordinaire, 1 de Roch 'Hodech). L'écran de la halakha du jour ne s'en sert pas.

### Hilloulot (`hilloulot.json`, `hilloulot_bios.json`)

| Champ | Entrées | Hébreu | Français | Anglais | % traduit | Affiché ? | Ce que voit l'utilisateur |
| --- | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Nom du tsadik (`he`, `fr`, `en`) | 4 049 | 4 049 | 179 | 229 | fr 4,4 % · en 5,7 % | oui | nom hébreu seul pour 3 820 tsadikim ; en français, 50 noms s'affichent en anglais (repli fr → en) |
| Année du décès (`a`) | 2 549 | lettres hébraïques | — | — | — | oui | « Décès : ה'של"ה » |
| Notice Wikipédia (`t`) | 1 701 | 1 701 | 0 | 0 | 0 % | oui | hébreu seul |
| Biographies MyTzadik / HaMéir LaArets | 2 346 (2 248 tsadikim) | 2 346 | 0 | 0 | 0 % | oui | hébreu seul ; l'invite « Touchez un nom pour lire sa biographie. » ne le dit pas |
| Raison d'un doute (`d`) | 526 | — | français d'atelier | — | — | non (sert au tri) | sans objet |
| Date de la hilloula dans les résultats (`Hilloulot.MOIS`) | 14 mois | en dur | 0 | 0 | 0 % | oui | « ל׳ תשרי » |

### Lieux, vols, trophées

| Fichier | Champ | Entrées | Hébreu | Français | Anglais | Ce que voit l'utilisateur |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `villes.json` | nom de la ville | 51 | 51 | 51 | 51 | traduit |
| `aeroports.json` + `aeroports_noms.json` | nom de l'aéroport | 3 226 | **699 (21,7 %)** | 3 074 (95,3 %) | 3 226 (source OurAirports) | nom anglais quand la langue manque |
| `aeroports.json` | ville de l'aéroport | 3 226 | recherche seulement | recherche seulement | 3 226 | ville affichée en anglais (« Geneva », « Colombier-Saugnieu, Rhône ») |
| `trophees_formes.json` | — | 9 formes | — | — | — | aucun texte (géométrie) ; noms des trophées dans `strings.xml` |
| `livres_titres.json` | voir Livres | | | | | |

### Musique

| Édition | Morceaux | Titres traduits en 3 langues | Titres en hébreu seul | Titres rédigés en français | Titres en anglais ou translittérés |
| --- | ---: | ---: | ---: | ---: | ---: |
| Édition Play (`MusiquePlay.kt`) | 26 | 0 | 2 | 9 | 15 |
| Hors Play (`MusiqueHorsPlay.kt`) | 30 | 30 | 0 | 0 | 0 |
| Site web (`data/musique.json`) | 56 | 30 | 2 | 9 | 15 |

---

## (c) Textes portés par le code

| Fichier | Contenu | Trois langues ? |
| --- | --- | --- |
| `Libelles.kt` | 124 clés (ajouts du siddour, fêtes, zmanim) → `R.string` | oui, via `strings.xml` |
| `Reference.kt` (et `regles.js`) | 18 noms de livres en fr / en / he ; nombres en lettres hébraïques | oui ; 200 références de données, 0 hors table |
| `QuestionsBlocage.kt`, `Tips.kt`, `Salutation.kt`, `Onboarding.kt`, `Tefilot.kt`, `Theme.kt`, `Notifications.kt`, `Reminder.kt`, `RappelsTefila.kt`, `ChabbatAlerte.kt`, `LevanaAlerte.kt`, `VolAlerte.kt`, `Divulgation.kt`, `Ambiance.kt` | clés `R.string` seulement | oui |
| `GuideSujets.kt` | lit `guide_sujets.json` | oui |
| `Trophees.kt`, `Paliers.kt`, `Holidays.kt`, `Zmanim.kt` | aucun texte ; noms passés par clés | oui |
| `CalendrierJuif.kt` | date hébraïque et paracha par `HebrewDateFormatter` (`isHebrewFormat = true`) | **hébreu seul** : « כ״ט תשרי תשפ״ז », « Paracha לך לך » |
| `Hilloulot.kt` | 14 noms de mois hébreux en dur (`MOIS`) | hébreu seul |
| `HalakhaActivity.kt`, `YalkutYosef.kt` | « בן איש חי », « שנה ראשונה », « ילקוט יוסף », « סעיף », « אות » | hébreu seul |
| `Hitbodedut.kt` | les cinq temps en hébreu (« לְפָרֵשׁ שִׂיחָתוֹ »…) au-dessus du libellé traduit | voulu |
| `Dedicace.kt` | quatre formules hébraïques du courriel | voulu |
| `Langues.kt` | « עברית », « English », « Français » | noms des langues dans leur langue : voulu |
| `Aeroports.SOURCE`, `Villes.SOURCE`, `MusicPlayer.kt`, `Zmanim.kt` (messages d'erreur) | français, non affichés (journaux, exceptions) | sans objet |

Aucun littéral français, anglais ou hébreu affiché à l'écran n'a été trouvé hors de ces tables (balayage des 152 fichiers Kotlin, commentaires retirés). Les formats de date prennent tous la langue de l'application.

---

## (d) Ce que fait le code quand une traduction manque

| Situation | Comportement | Annoncé ? |
| --- | --- | --- |
| Chaîne d'interface | impossible : les trois fichiers ont les mêmes clés (test `TraductionTest`) | — |
| Téléphone dans une autre langue | anglais (`LangueApp.repli`) | — |
| Titre de livre, de prière, de ville (`LocalizedText.forLanguage`) | repli sur l'hébreu | non |
| Bloc de livre sans `fr`/`en` (`LanguesTexte.textes`) | la langue manquante est sautée ; s'il ne reste rien, l'hébreu seul | **non**, sauf si le livre entier n'a aucune traduction (cas inexistant aujourd'hui) |
| Siddour | hébreu seul | **non** (la note n'existe que pour `livre`) |
| Halakha du jour | hébreu seul | oui (« Texte original en hébreu, verbatim. ») |
| Hilloulot : nom | fr → anglais → rien ; en → rien | non |
| Hilloulot : notice, biographie | hébreu seul | non |
| 'Hizouk, bibliothèque, Tikoun, Tehilim | traduction présente à 100 % | — |
| Recherche globale | ne cherche que dans les titres et dans le texte **hébreu** des blocs (`RechercheGlobale.dansRecueil`, `app.js` ligne 1580) : un mot français ou anglais ne trouve rien dans les 13 834 blocs traduits | non |

Le réglage « Langues du texte » (`ReglagesLecture.kt` lignes 139-150, six modes : hébreu, français, anglais, hébreu + français, hébreu + anglais, français + anglais) est posé sans condition sur tous les écrans de lecture : siddour (0 % traduit), halakha du jour (0 %), hilloulot (0 %), livres (51,9 %), bibliothèque, Tehilim, Tikoun (100 %). Le choix est unique pour toute l'application. **Il propose donc une langue que le contenu n'a pas**, et la choisir ne change rien à l'écran, sans explication.

Avant d'ouvrir un livre, l'utilisateur ne peut pas savoir s'il est traduit : la liste (`LibraryActivity.bindLivre`, `app.js` ligne 2099) montre le titre et le nombre de chapitres.

Tests : `TraductionTest` (clés, pluriels, marqueurs, textes en dur) et `TraductionAffichageTest` (références, services) couvrent l'interface. **Aucun test ne mesure la couverture des contenus** : rien n'échoue quand un livre déclaré traduit ne l'est qu'à 10 %. Le test « aucun titre de morceau ne reste en français » ne cherche que la chaîne « titre à préciser » et laisse passer les neuf titres français.

---

## (e) Web (iPhone)

| Élément | Constat |
| --- | --- |
| 15 fichiers de `data/` communs avec `res/raw` | identiques à l'octet près (empreintes SHA-256) |
| `data/livres/*.json` (12 livres) | sections identiques à celles de `livre_*.json` (même décompte, mêmes traductions) ; enveloppe réduite à `{id, sections}` |
| `data/livres/table.json` | identique à `livres_titres.json`, sans la clé `sections` vide |
| `data/hilloulot_bios/` (14 fichiers par mois) | 406 jours, contenu identique à `hilloulot_bios.json` |
| `trophees_formes.json` | absent de `data/` (porté par `js/trophees-formes.js`) |
| `data/strings.fr/en/he.json` | 1 184 chaînes, 36 pluriels, 2 tableaux par langue ; identiques aux `strings.xml` (seul écart : une double espace réduite dans `trophees_paliers`) |
| Clés employées par le JavaScript | 473 clés `t()` et 18 pluriels, toutes présentes dans les trois langues |
| Textes en dur de `web/src/js` | aucun texte d'interface, sauf une table de repli française de 9 chaînes (`CHAINES_LECTURE`, `app.js` lignes 1021-1031), morte aujourd'hui (les 9 clés existent) mais qui servirait du français aux trois langues si une clé venait à manquer |
| Comportement quand la traduction manque | le même que sur Android (mêmes règles recopiées dans `regles.js`) : repli silencieux, même menu des six modes, même recherche limitée à l'hébreu |
| `confidentialite.html` | trois langues complètes et parallèles : 9 titres, 11 paragraphes, 13 points de liste dans chacune ; `<html lang="fr">`, titre trilingue ; identique dans le site construit |
| `index.html` | `<html lang="fr">` au chargement, corrigé par le script (`racine.lang = tr.langue`) ; titre « MyHitbodedut » |
| `manifest.webmanifest` | nom seul (« MyHitbodedut »), ni `lang`, ni `dir`, ni description |

---

## (f) Nokia et Google Play

| Élément | Hébreu | Français | Anglais | Remarque |
| --- | --- | --- | --- | --- |
| Application Java ME (`nokia/`) | non | oui | **non** | 88 textes en dur dans le code Java, 4 chaînes relues dans `strings.xml`, 'hizouk en français seul ; limite assumée dans `nokia/README.md` (pour l'hébreu : la police ; rien n'est dit de l'anglais) |
| Fiche Play : titre (§ 7.1) | « MyHitbodedut – התבודדות » | **pas de fiche** (tranché le 29/10) | « MyHitbodedut – Hitbodedut » | un téléphone français voit la fiche anglaise |
| Fiche Play : description courte | à rédiger | — | à rédiger | non écrite |
| Fiche Play : description complète | plan seulement | — | plan seulement | non écrite |
| Visuels `play/visuels/` | 11 fichiers (10 captures + 1 aperçu) | 32 fichiers (14 captures, 3 aperçus, 15 captures brutes) | 11 fichiers (10 captures + 1 aperçu) | les 4 captures de la barrière du matin (11 à 14) n'existent qu'en français, la langue sans fiche |

Les visuels anglais et hébreux sont bien dans leur langue (bandeaux et interface vérifiés à l'œil sur 5 captures par langue).

---

## (g) Notifications, vignettes, nom, raccourcis, accessibilité

| Élément | Trois langues ? |
| --- | --- |
| Nom de l'application | « MyHitbodedut » partout (`appLabel` → `@string/app_name`) |
| Libellés des activités (26) et des vignettes (5) dans le manifeste | oui (`@string`) |
| Descriptions des vignettes (`widget_*_info.xml`) | oui |
| Canaux de notification (4 : noms et descriptions) | oui |
| Notifications (rappel, hitbodedout en cours et finie, barrière, Chabbat, Levana, vol, trophée) | oui ; les services et receveurs appliquent la langue choisie dans l'application avant Android 13 (`LangueApp.envelopper`, 10 fichiers) |
| Raccourcis d'application | aucun déclaré |
| Descriptions d'accessibilité (`contentDescription`) | toutes par `getString` ; aucune en dur |
| Contenu des vignettes zmanim | interface traduite ; **date hébraïque et paracha en lettres hébraïques** dans les trois langues |

---

## (h) Images contenant du texte

| Images | Texte incrusté | Langue |
| --- | --- | --- |
| `drawable-nodpi/char_tehilim`, `char_f_tehilim`, `char_f_tehilim_hug`, `char_f_reading`, `char_torah` | « תהלים » sur la couverture du livre | hébreu (convient aux trois langues) |
| `scene_ouverture_tombe` | plaques du tsiyoun | hébreu (photo) |
| `char_purim`, `scene_hanukkah` | rouleau à l'écriture illisible ; lettres de la toupie | hébreu |
| 42 autres personnages et scènes (les 50 images ont été regardées) | aucun | — |
| Icônes vectorielles (`drawable/*.xml`) | aucune balise de texte | — |
| `play/visuels/en`, `he`, `fr` | bandeaux et captures | chacune dans sa langue |

Aucune image de l'application ne porte de texte français ou anglais incrusté.

---

## Liste des lacunes, de la plus lourde à la plus légère

| # | Lacune | Chiffres | Langues | Annoncée ? |
| ---: | --- | --- | --- | --- |
| 1 | Yalkout Yossef – Kitsour Choul'han Aroukh non traduit | 12 814 blocs sur 14 303 ; 956 chapitres sur 1 048 | fr, en | non |
| 2 | Trois siddourim non traduits, consignes comprises | 3 573 prières, 1 336 consignes, 234 titres de sections | fr, en | non |
| 3 | Biographies et notices des hilloulot | 2 346 + 1 701 | fr, en | non |
| 4 | Noms des tsadikim | 3 870 sans nom français, 3 820 sans nom anglais, sur 4 049 | fr, en | non |
| 5 | Halakha du jour | 2 790 halakhot (dont 333 déjà traduites ailleurs) | fr, en | **oui** |
| 6 | Menu des langues offert sur des contenus à 0 % ; repli silencieux | siddour, halakha, hilloulot, 9/10 du Yalkout | fr, en | non |
| 7 | Recherche limitée à l'hébreu | 13 834 blocs traduits non cherchables | fr, en | non |
| 8 | Origine des traductions jamais affichée (Rabbinat 1899, JPS 1917, traduction automatique non relue) | 16 846 unités traduites | fr, en | non |
| 9 | « La source du jour » en hébreu seul sur l'accueil | 124 paragraphes pourtant traduits | fr, en | non |
| 10 | Date hébraïque, paracha, mois, sources de la halakha en lettres hébraïques | accueil, zmanim, calendrier, vignettes | fr, en | non |
| 11 | Intertitres des livres, chapitres d'Esther et de Chir HaChirim, titres des psaumes | 386 + 18 + 160 | fr, en | non |
| 12 | Titres des sources de la bibliothèque et des Tefilot | 29 en hébreu seul ; 21 titres français inutilisés, 0 anglais | fr, en | non |
| 13 | Titres de morceaux figés en français (et 2 en hébreu) | 9 (+ 2) sur 26 de l'édition Play | en, he (fr) | non |
| 14 | Noms d'aéroports en hébreu | 699 sur 3 226 | he | non |
| 15 | Fiche Play : descriptions non rédigées ; captures de la barrière en français seulement | 0 description sur 2 langues ; 4 captures | en, he | — |
| 16 | Application Nokia en français seulement | 88 textes en dur | en, he | oui (README) |
