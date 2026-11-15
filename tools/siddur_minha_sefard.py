# -*- coding: utf-8 -*-
"""
Min'ha Sfard, la fin de l'office à sa place (audit du 12/11/2026, TSIDDUR-03) :
dans siddur_sefard.json, la section « תחנון » de Min'ha contenait aussi « שומר
ישראל », le Kaddich, « עלינו » et « לדוד ה׳ אורי », et « אבינו מלכנו » venait
après eux. Les sections sont recoupées dans l'ordre que le même siddour suit à
Cha'harit : תחנון (jusqu'à « ה׳ אל באפך »), אבינו מלכנו, שומר ישראל (jusqu'au
Kaddich), עלינו. Aucun paragraphe n'est modifié ; les autres textes ne sont pas
reconstruits. La découpe est celle de tools/siddur_construction.py
(minha_sefard), qui la produit aussi. Idempotent.

  python3 tools/siddur_minha_sefard.py && python3 tools/siddur_annotations.py
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import siddur_construction as sc

CIBLE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "android", "app", "src", "main", "res", "raw", "siddur_sefard.json")


def main():
    d = json.load(open(CIBLE, encoding="utf-8"))
    t = next(t for t in d["textes"] if t["id"] == "minha")
    avant = [(s["titre"], len(s["blocs"])) for s in t["sections"]]
    sc.minha_sefard(t["sections"])
    apres = [(s["titre"], len(s["blocs"])) for s in t["sections"]]
    if apres == avant:
        print("déjà recoupé")
        return
    assert sum(n for _, n in avant) == sum(n for _, n in apres), "des paragraphes se sont perdus"
    json.dump(d, open(CIBLE, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    print(" · ".join(f"{titre} ({n})" for titre, n in apres))


if __name__ == "__main__":
    main()
