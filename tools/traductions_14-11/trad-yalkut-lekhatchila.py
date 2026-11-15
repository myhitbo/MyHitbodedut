#!/usr/bin/env python3
"""YALKUT-03 : « de prime abord » -> « a priori » (לכתחלה) dans yalkut_yosef_kitsour (fr). Idempotent.
Usage : trad-yalkut-lekhatchila.py <racine du dépôt>"""
import json, os, re, subprocess, sys
racine = os.path.abspath(sys.argv[1])
src = os.path.join(racine, "android", "app", "src", "main", "livres", "livres.json")
d = json.load(open(src, encoding="utf-8"))
n = 0
for t in d["textes"]:
    if t.get("id") != "yalkut_yosef_kitsour":
        continue
    for s in t["sections"]:
        for b in s["blocs"]:
            f = b.get("fr")
            if f and "prime abord" in f:
                g = f.replace("De prime abord", "A priori").replace("de prime abord", "a priori")
                n += f.count("prime abord")
                b["fr"] = g
print(n, "occurrences remplacées")
if n:
    with open(src, "w", encoding="utf-8") as fh:
        json.dump(d, fh, ensure_ascii=False, separators=(",", ":"))
    subprocess.check_call([sys.executable, os.path.join(racine, "tools", "livres_decoupe.py")])
