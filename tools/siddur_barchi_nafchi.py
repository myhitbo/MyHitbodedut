# -*- coding: utf-8 -*-
"""
Barekhi nafchi au matin de Roch 'Hodech, siddour Edot (audit du 16/11, « Hallel et Moussaf ») :
après la répétition de Moussaf et le Kaddich titkabal, on dit le psaume 104, puis le Kaddich
« יהא שלמא » (Kitsour Yalkut Yosef 423:5 ; Choul'han Aroukh O.H. 423:3). Le siddour source de
l'application (Siddur Edot HaMizrach, Shaliehsaboo Edition, CC0) l'a, sous « Rosh Hodesh,
Barchi Nafshi » ; l'import (tools/siddur_moussaf_rosh_hodech.py) ne prenait que « Mussaf ».

Le passage est ajouté tel quel, en section « ברכי נפשי » à la fin du Moussaf de Roch 'Hodech
Edot, par les fonctions de tools/siddur_construction.py (bloc, sans_renvois). Idempotent : la
section est remplacée si elle existe déjà.

Entrée : la réponse de l'API de Sefaria, enregistrée telle quelle :
  https://www.sefaria.org/api/v3/texts/Siddur_Edot_HaMizrach,_Rosh_Hodesh,_Barchi_Nafshi

  python3 tools/siddur_barchi_nafchi.py <fichier.json> && python3 tools/siddur_annotations.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import siddur_construction as sc

ICI = os.path.dirname(os.path.abspath(__file__))
CIBLE = os.path.join(ICI, "..", "android", "app", "src", "main", "res", "raw", "siddur_edot.json")
TITRE = "ברכי נפשי"
SOURCE = "Siddur Edot HaMizrach (Torat Emet 357, Public Domain; Shaliehsaboo Edition, CC0)"


def main(chemin):
    api = json.load(open(chemin, encoding="utf-8"))
    version = next(v for v in api["versions"] if v.get("language") == "he" and v.get("license") == "CC0")
    blocs = sc.sans_renvois([{"titre": TITRE, "blocs": sc.blocs(list(sc.aplatit(version["text"])))}])[0]["blocs"]
    assert [list(b)[0] for b in blocs] == ["c", "t", "c", "t", "t"], blocs
    assert blocs[0]["c"] == "אומרים ברכי נפשי" and "קדיש" in blocs[2]["c"], blocs
    d = json.load(open(CIBLE, encoding="utf-8"))
    moussaf = next(t for t in d["textes"] if t["id"] == "moussaf_rosh_hodech")
    assert moussaf["source"] == SOURCE
    moussaf["sections"] = [s for s in moussaf["sections"] if s["titre"] != TITRE] + [{"titre": TITRE, "blocs": blocs}]
    json.dump(d, open(CIBLE, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    print(f"Moussaf de Roch 'Hodech Edot : {len(blocs)} paragraphes de ברכי נפשי")


if __name__ == "__main__":
    main(sys.argv[1])
