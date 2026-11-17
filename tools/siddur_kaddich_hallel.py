# -*- coding: utf-8 -*-
"""
Le Kaddich après le Hallel ashkénaze (audit du 16/11, « Hallel et Moussaf ») : le Hallel du
siddour Daat s'arrête à « מלך מהלל בתשבחות », sans Kaddich ; l'officiant dit pourtant le Kaddich
complet, תתקבל compris, tout jour de Moussaf, et le demi-Kaddich à 'Hanouka, sans Moussaf
(Choul'han Aroukh O.H. 423:1, « אומר קדיש תתקבל וכו' ומוציאין ס"ת » ; Michna Beroura 423:1,
« וכלל הוא דכל יום שיש בו מוסף אומרים קדיש תתקבל אחר הלל דהוא סיומא דתפלת שחרית »).

Aucun texte n'est écrit ici : le Kaddich est celui que le même siddour donne après ובא לציון
(Cha'harit, « סיום תפילה », Metsudah 1981), recopié dans une section « קדיש שלם » à la fin du
Hallel, avec deux consignes : celle qui l'annonce, et « עד כאן אומרים בחנוכה » avant תתקבל, comme
dans le Hallel Sfard (tools/siddur_annotations.py replie la suite à 'Hanouka sans Moussaf).
Idempotent : la section est remplacée si elle existe déjà.

  python3 tools/siddur_kaddich_hallel.py && python3 tools/siddur_annotations.py
"""
import json
import os
import re

ICI = os.path.dirname(os.path.abspath(__file__))
CIBLE = os.path.join(ICI, "..", "android", "app", "src", "main", "res", "raw", "siddur_ashkenaz.json")
TITRE = "קדיש שלם"
ANNONCE = "אחר ההלל אומר ש״ץ קדיש שלם, שבכל יום שיש בו מוסף אומרים קדיש תתקבל אחר ההלל (שו״ע ומ״ב או״ח תכ״ג:א׳). ובחנוכה חצי קדיש:"
HANOUKA = "עד כאן אומרים בחנוכה"
# Le premier bloc du Kaddich à recopier : celui qui suit ce bloc-ci, dans « סיום תפילה ».
APRES = "יהי רצון מלפניך"


def nu(s):
    return re.sub(r"\s+", " ", re.sub(r"[֑-ׇ]", "", re.sub(r"<[^>]+>", " ", s))).strip()


def main():
    d = json.load(open(CIBLE, encoding="utf-8"))
    textes = {t["id"]: t for t in d["textes"]}
    fin = next(s for s in textes["chaharit"]["sections"] if nu(s["titre"]) == "סיום תפילה")["blocs"]
    k = next(i for i, b in enumerate(fin) if nu(b.get("t", "")).startswith(APRES)) + 1
    kaddich = []
    for b in fin[k:]:
        x = nu(b.get("t", ""))
        if "c" in b or not x or (kaddich and x.startswith("עלינו")):
            break
        kaddich.append(dict(b))
    assert [nu(b["t"]).split()[0] for b in kaddich] == ["יתגדל", "בעלמא", "יהא", "יתברך", "לעלא", "תתקבל", "יהא", "עושה"], kaddich
    blocs = [{"c": ANNONCE}] + kaddich[:5] + [{"c": HANOUKA}] + kaddich[5:]
    hallel = textes["hallel"]["sections"]
    hallel[:] = [s for s in hallel if s["titre"] != TITRE] + [{"titre": TITRE, "blocs": blocs}]
    json.dump(d, open(CIBLE, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    print(f"Hallel ashkénaze : {len(blocs)} paragraphes de Kaddich")


if __name__ == "__main__":
    main()
