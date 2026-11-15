#!/usr/bin/env python3
"""TLIVRES-04 (partie sûre) : recolle les mots composés de Hichtapkhout HaNefech coupés par une
espace après le maqaf ASCII (« בָּרוּךְ- הוּא » devient « בָּרוּךְ-הוּא »). Seul le champ hébreu « t » de
livre hichtapkhout est touché (138 occurrences, 108 blocs) ; « אחים- מיד » est laissé (tiret de phrase).
Idempotent. Usage : trad-HICHT-tiret.py <racine du dépôt>. Appelle tools/livres_decoupe.py."""
import json, os, re, subprocess, sys

racine = sys.argv[1]
SRC = os.path.join(racine, "android/app/src/main/livres/livres.json")
d = json.load(open(SRC, encoding="utf-8"))
pat = re.compile("(?<=[א-תְ-ׇ])- (?=[א-ת])")
n = 0
for t in d["textes"]:
    if t["id"] != "hichtapkhout":
        continue
    for s in t["sections"]:
        for b in s["blocs"]:
            x = b.get("t")
            if not x:
                continue
            y = pat.sub("-", x)
            # exception : « אחים- מיד »
            if "אחים-" in re.sub("[ְ-ׇ]", "", x) and "אחים-מיד" in re.sub("[ְ-ׇ]", "", y):
                y = re.sub("(א[ְ-ׇ]*ח[ְ-ׇ]*י[ְ-ׇ]*ם[ְ-ׇ]*)-(?=מ)", r"\1- ", y)
            if y != x:
                n += len(pat.findall(x))
                b["t"] = y
with open(SRC, "w", encoding="utf-8") as f:
    json.dump(d, f, ensure_ascii=False, separators=(",", ":"))
print("tirets recollés :", n)
subprocess.check_call([sys.executable, os.path.join(racine, "tools/livres_decoupe.py")])
