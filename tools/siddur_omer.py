# -*- coding: utf-8 -*-
"""
La page du compte de l'Omer dans le noussa'h de chaque siddour (audit du 16/11, « Page du compte de
l'Omer : texte Edot servi aussi en Sfard et en Ashkenaz ») : tools/siddur_occasions.py y mettait le
texte des Edot (לשם יחוד, « לעמר »), faute de source libre. Les siddourim Sfard et Ashkenaz de l'app
(Metsudah 1981, CC-BY) ont pourtant leur propre compte, dans Arvit (section « ספירת העומר ») : le
Sfard « לעמר » avec les sefirot, l'Ashkenaz « בעמר » comme le Rema (O.H. 489:1). Cet outil recopie
cette section dans la page « sefirat_haomer » de ces deux siddourim, avec sa source, et retire la
mention d'emprunt. À relancer après tools/siddur_occasions.py, qui remet le texte emprunté.

  python3 tools/siddur_omer.py
"""
import copy
import json
import os
import re

RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "android", "app", "src", "main", "res", "raw")


def nu(s):
    return re.sub(r"\s+", " ", re.sub(r"[֑-ׇ]", "", re.sub(r"<[^>]+>", " ", s))).strip()


def main():
    for nusah in ("sefard", "ashkenaz"):
        chemin = os.path.join(RAW, f"siddur_{nusah}.json")
        siddur = json.load(open(chemin, encoding="utf-8"))
        textes = {t["id"]: t for t in siddur["textes"]}
        arvit = textes["arvit"]
        section = next(s for s in arvit["sections"] if nu(s["titre"]) == "ספירת העומר")
        page = textes["sefirat_haomer"]
        page["sections"] = [copy.deepcopy(section)]
        page["source"] = arvit["source"]
        page.pop("nusah", None)
        with open(chemin, "w", encoding="utf-8") as f:
            f.write(json.dumps(siddur, ensure_ascii=False, separators=(",", ":")))
        print(nusah, len(section["blocs"]), "paragraphes")


if __name__ == "__main__":
    main()
