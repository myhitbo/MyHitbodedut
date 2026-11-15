# Corrections de traduction du 14/11/2026

Constats graves de l'audit du 12/11 (`audit/2026-11-12` sur la branche
`ccr-8ad556f8-krod4j`) : contresens et faux sens dans les traductions
françaises et anglaises, corrigés sur l'hébreu.

- `patchs-A.json` (63) et `patchs-B.json` (81) : un remplacement de texte par
  passage et par langue, chacun avec l'identifiant du constat et sa raison.
  Préparés par un premier agent, puis contre-lus un à un sur l'hébreu par un
  second, qui a pu améliorer le texte ou rejeter le patch.
- Trois scripts, eux aussi contre-lus et éprouvés sur une copie (idempotents) :
  `trad-yalkut-lekhatchila.py` (YALKUT-03), `trad-guide-citations.py`
  (BIBLIO-02, TLIVRES-07), `trad-HICHT-tiret.py` (partie sûre de TLIVRES-04).
- `patchtrad` : l'outil qui vérifie (`check`) et applique (`apply`) les patchs.
- `trad-TEFILA-consignes.py` (TEFILA-02, 15/11) : `c_fr` et `c_en` des seize consignes et crédits de Tefila LiChlomo, relus sur l'hébreu, éprouvés sur une copie (idempotent) ; il lance lui-même `livres_decoupe.py`.

Ordre d'application : `patchtrad apply <racine> patchs-A.json patchs-B.json`,
puis les trois scripts (argument : la racine du dépôt), puis
`python3 tools/livres_decoupe.py`.

Rejetés à la contre-lecture, donc non appliqués : l'harmonisation du
vocabulaire de Hichtapkhout et Kokhvei Or (HICHT-04), règles trop larges ; la
nouvelle référence d'un 'hizouk (CHIZUK-01), qui demande aussi un changement
de code et la confirmation du propriétaire. Restent à relire par un relecteur
breslev : LM2-01 et HICHT-03 (monstres marins, Kokhvei Or IV).

Attention : `tools/livres_textes_proprietaire.py` filtre encore les lignes du
guide qui commencent par « > » ; toute reconstruction du guide fera
disparaître de nouveau les deux citations rétablies.
