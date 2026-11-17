# -*- coding: utf-8 -*-
"""
Birkat haMazon Sfard complété (demande du 12/11/2026).

Le Birkat Sfard vient de Torat Emet 357, dont l'export Sefaria laisse vides les
douze paragraphes qui suivent « בַּמָּרוֹם » : les הרחמן de Chabbat, Roch 'Hodech,
Yom tov, Roch Hachana et Souccot (chacun après sa consigne), puis « הָרַחֲמָן הוּא
יְזַכֵּנוּ… מַגְדִּיל… עֹשֶׂה שָׁלוֹם » et « יִרְאוּ ». Ils sont repris du Metsudah 1981
(CC-BY, déjà la source des offices Sfard et déjà mentionné), au même rang, mot pour
mot, par la même découpe que tools/siddur_construction.py (completer_birkat_sefard),
qui les reprend aussi lors d'une reconstruction.

Insérés après « בַּמָּרוֹם », avant les Chéva bérakhot. Idempotent : relancé, l'outil
ne change rien. Puis : python3 tools/siddur_annotations.py

  python3 tools/siddur_birkat_sefard.py <dossier de l'export Sefaria>
  (Siddur_Sefard__Hebrew__Torat_Emet_357.json et
   Siddur_Sefard__Hebrew__The_Metsudah_siddur,_1981.json, comme siddur_construction.py)
"""
import json, os, sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
from siddur_construction import NFC, Source, bloc, charge, completer_birkat_sefard  # noqa: E402

RAW = os.path.join(ICI, "..", "android", "app", "src", "main", "res", "raw")


def main(dossier):
    st = Source(charge(dossier, "Siddur_Sefard__Hebrew__Torat_Emet_357.json")["text"], None, "")
    sm = Source(charge(dossier, "Siddur_Sefard__Hebrew__The_Metsudah_siddur,_1981.json")["text"], None, "")
    chemin = ["Birchat HaMazon", "Birchat HaMazon"]
    avant = list(st.noeud(chemin))
    completer_birkat_sefard(st, sm)
    nouveaux = [bloc(x) for k, x in enumerate(st.noeud(chemin)) if x != avant[k]]
    nouveaux = [b for b in nouveaux if b]
    if not nouveaux:
        raise SystemExit("rien à reprendre : l'export a changé ?")

    fichier = os.path.join(RAW, "siddur_sefard.json")
    siddur = json.load(open(fichier, encoding="utf-8"))
    texte = next(t for t in siddur["textes"] if t["id"] == "birkat_hamazon")
    blocs = texte["sections"][0]["blocs"]
    i = next(k for k, b in enumerate(blocs) if NFC(b.get("t", "")).startswith(NFC("<b>בַּמָּרוֹם</b>"))) + 1
    # « בשבת אומר: » existe déjà plus bas (règles d'oubli) : on compare la place même.
    if blocs[i:i + len(nouveaux)] == nouveaux:
        print("déjà complété : rien à faire")
        return
    blocs[i:i] = nouveaux
    json.dump(siddur, open(fichier, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    print(f"{len(nouveaux)} paragraphes insérés après « בַּמָּרוֹם » (rang {i})")


if __name__ == "__main__":
    main(sys.argv[1])
