#!/usr/bin/env python3
"""BIBLIO-02 / TLIVRES-07 : rétablit les deux citations en hébreu du guide de la hitbodedout
(sections 0 et 17), jetées par le constructeur, avec leurs traductions FR et EN. Idempotent.
Usage : python3 trad-guide-citations.py <racine du dépôt>"""
import json, os, subprocess, sys

racine = os.path.abspath(sys.argv[1])
src = os.path.join(racine, "android", "app", "src", "main", "livres", "livres.json")
NB = " "
AJOUTS = {
    0: {
        "t": "<b>התבודדות אינה רק \"עוד תפילה\". מטרתה לבנות קשר אישי, חי ומתמשך עם הקב״ה.</b>",
        "fr": "<b>La hitbodedout n’est pas seulement «" + NB + "une prière de plus" + NB + "». Son but est de construire un lien personnel, vivant et durable avec le Saint, béni soit-Il.</b>",
        "en": "<b>Hitbodedut is not just “one more prayer.” Its purpose is to build a personal, living and lasting relationship with the Holy One, blessed be He.</b>",
    },
    17: {
        "t": "<b>עצור. התרחק לרגע מהרעש. דבר עם הקב״ה באמת. ספר לו מה עובר עליך. תודה, בקש, התבונן בעצמך, ובחר צעד קטן להמשך.</b>",
        "fr": "<b>Arrête-toi. Éloigne-toi un instant du bruit. Parle au Saint, béni soit-Il, en vérité. Raconte-Lui ce que tu traverses. Remercie, demande, regarde en toi-même, et choisis un petit pas pour la suite.</b>",
        "en": "<b>Stop. Step away from the noise for a moment. Speak to the Holy One, blessed be He, in truth. Tell Him what you are going through. Give thanks, ask, look within yourself, and choose one small step forward.</b>",
    },
}
ATTENDU = {0: "הנקודה שעליה בנוי כל התוכן היא:", 17: "בסופו של דבר, כל התורה של הסדרה יכולה להפוך למשפט אחד :"}

with open(src, encoding="utf-8") as f:
    d = json.load(f)
livre = next(x for x in d["textes"] if x["id"] == "guide_hitbodedut")
change = False
for i, bloc in AJOUTS.items():
    blocs = livre["sections"][i]["blocs"]
    assert blocs[0]["t"] == ATTENDU[i], (i, blocs[0]["t"])
    if blocs[1]["t"] == bloc["t"]:
        continue
    blocs.insert(1, dict(bloc))
    change = True
if change:
    with open(src, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, separators=(",", ":"))
    subprocess.check_call([sys.executable, os.path.join(racine, "tools", "livres_decoupe.py")])
    print("guide : 2 citations rétablies")
else:
    print("guide : déjà à jour")
