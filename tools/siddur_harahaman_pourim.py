# -*- coding: utf-8 -*-
"""
« הרחמן » de Pourim au Birkat haMazon Edot (demande du 14/11/2026).

Pourim triple (15 Adar un Chabbat) : à Jérusalem, le festin est le dimanche 16 ;
on n'y dit pas « ועל הנסים » à sa place, « ונכון לנהוג לומר ועל הנסים באמצע הרחמן »
(Kitsour Yalkut Yosef 688:6, § 15 ; Yalkut Yosef Moadim p. 308 ; Yehavé Daat I, 90).

Le siddour Edot n'a pas ce « הרחמן » : une consigne et un bloc, insérés après les
« הרחמן » des jours (« במועדים »). La formule est celle que les siddourim Sfard et
Ashkenaz de l'application donnent déjà dans leur consigne (« ויאמר הָרַחֲמָן הוּא
יַעֲשֶׂה־לָּנוּ… ») ; « בִּימֵי מָרְדְּכַי… » est repris mot pour mot du « על הנסים » de
Pourim du même Birkat Edot. Rien n'est retapé. Idempotent. Puis :
python3 tools/siddur_annotations.py

  python3 tools/siddur_harahaman_pourim.py
"""
import json, os, re

ICI = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(ICI, "..", "android", "app", "src", "main", "res", "raw")
CONSIGNE = ("בסעודת פורים ביום ראשון ט״ז באדר בירושלים, כשחל ט״ו באדר בשבת (פורים המשולש), "
            "אין אומרים על הנסים במקומו, אלא כאן, בתוך הרחמן (ילקוט יוסף):")
NIKKOUD = re.compile(r"[֑-ׇ]")


def plat(t):
    return NIKKOUD.sub("", re.sub(r"<[^>]+>", "", t))


def birkat(nusah):
    d = json.load(open(os.path.join(RAW, f"siddur_{nusah}.json"), encoding="utf-8"))
    t = next(t for t in d["textes"] if t["id"] == "birkat_hamazon")
    return d, t["sections"][0]["blocs"]


def main():
    nom = os.path.join(RAW, "siddur_edot.json")
    d, blocs = birkat("edot")
    if any(b.get("c") == CONSIGNE for b in blocs):
        print("déjà là")
        return
    # La formule du « הרחמן », vocalisée, dans la consigne Sfard.
    _, sfard = birkat("sefard")
    cons = next(b.get("c") or b["t"] for b in sfard if "יוכל לאמרו בתוך שאר הרחמן" in (b.get("c") or b.get("t") or ""))
    formule = re.search(r"הָרַחֲמָן הוּא יַעֲשֶׂה.*?בַּזְּמַן הַזֶּה", cons).group(0)
    # « בִּימֵי מָרְדְּכַי… » du « על הנסים » de Pourim, sans « בפורים אומרים ».
    pourim = next(b["t"] for b in blocs if "t" in b and plat(b["t"]).startswith("בפורים אומרים בימי מרדכי"))
    recit = re.sub(r"^בפורים אומרים\s*", "", pourim)
    # Après le « הרחמן » des fêtes (« במועדים »).
    i = next(k for k, b in enumerate(blocs) if "t" in b and plat(b["t"]).startswith("הרחמן הוא יגיענו למועדים"))
    blocs[i + 1:i + 1] = [{"c": CONSIGNE}, {"t": f"{formule}. {recit}"}]
    json.dump(d, open(nom, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    print("inséré après le bloc", i)


if __name__ == "__main__":
    main()
