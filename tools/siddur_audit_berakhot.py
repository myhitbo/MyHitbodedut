# -*- coding: utf-8 -*-
"""
Audit halakhique du 16/11/2026, « Birkat haMazon et bénédictions » : les retouches du texte des
trois siddourim (android/app/src/main/res/raw/siddur_*.json) que le rapport demande
(AUDIT_HALAKHOT_2026-11-16.md). Ce qui ne demande qu'une note, sans toucher au texte imprimé,
est dans tools/siddur_annotations.py (NOTES) ; ici, seulement :

  - une formule fautive du siddour source, alignée sur la source de référence du rite
    (Edot : Yalkut Yosef ; Ashkenaz : Michna Beroura, Rema ; Sfard : Choul'han Aroukh haRav) ;
  - une ligne qui manque (יעלה ויבוא de Kippour en Edot, l'oubli à 'Hol hamoed, les bougies de
    Kippour en Edot, המוציא, מזונות et הגפן dans les bénédictions des plaisirs) ;
  - une consigne du siddour réécrite quand le rapport le demande (Edot : la mer, les éclairs,
    Acher yatsar ; Ashkenaz : la 'hala, les psaumes d'avant le Birkat) ;
  - une précision propre à l'application dans un passage déjà replié (« En cas d'oubli »),
    commencée par « הערה: » pour qu'on ne la prenne pas pour le texte du siddour.

Aucune formule n'est inventée : chacune est citée par le rapport (Choul'han Aroukh, Michna
Beroura, Kitsour Yalkut Yosef, Choul'han Aroukh haRav), ou recopiée d'un bloc du même siddour
(« בורא מיני מזונות », « בורא פרי הגפן », « על נטילת ידים », la formule des bougies). Seule
« הַמּוֹצִיא לֶחֶם מִן הָאָרֶץ », absente des trois siddourim, est écrite d'après le Choul'han
Aroukh O.H. 167:2.

Idempotent : chaque retouche vérifie qu'elle n'est pas déjà faite. À relancer après
tools/siddur_construction.py et tools/siddur_occasions.py (qui l'appelle à la fin), puis :
  python3 tools/siddur_annotations.py

  python3 tools/siddur_audit_berakhot.py
"""
import json
import os
import re

ICI = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(ICI, "..", "android", "app", "src", "main", "res", "raw")
NIKKOUD = re.compile(r"[֑-ׇ]")


def plat(t):
    """Sans balises, voyelles ni espaces en trop."""
    return re.sub(r"\s+", " ", NIKKOUD.sub("", re.sub(r"<[^>]+>", " ", t))).strip()


def contenu(b):
    return b.get("t") if "t" in b else b.get("c", "")


def trouve(blocs, debut, consigne=None):
    """L'index du premier bloc dont le texte plat commence par [debut]."""
    for k, b in enumerate(blocs):
        if consigne is not None and ("c" in b) != consigne:
            continue
        if plat(contenu(b)).replace("''", "״").startswith(debut):
            return k
    raise KeyError(debut)


def deja(blocs, debut):
    return any(plat(contenu(b)).startswith(debut) for b in blocs)


def texte(siddur, id_):
    return next(t for t in siddur["textes"] if t["id"] == id_)


# --- Birkat haMazon -------------------------------------------------------------------------

# Edot, יעלה ויבוא de Kippour pour qui mange ce jour-là (Kitsour Yalkut Yosef 618:12 ; Choul'han
# Aroukh O.H. 618:10) : « ביום הכפורים הזה, ביום סליחת העון הזה ». Le bloc qui précède finit
# par « בְּיוֹם » : la ligne commence au nom du jour, comme ses voisines.
KIPPOUR_YAALE = "<small><small>ביום הכפורים:</small> הַכִּפֻּרִים הַזֶּה, בְּיוֹם סְלִיחַת הֶעָוֹן הַזֶּה, </small>"

# Edot, l'oubli d'על הנסים (Kitsour Yalkut Yosef 188:18, 682:11, 695:6) : on ne reprend pas ; il est
# bon de le dire dans les הרחמן. Commence par « אם שכח » : replié sous « En cas d'oubli ».
OUBLI_AL_HANISSIM = (
    "אם שכח ״על הנסים״ ונזכר אחר שאמר ״ברוך אתה ה׳״ בסוף ברכת ״על הארץ ועל המזון״, אינו חוזר. "
    "וטוב שיאמר בהרחמן: ״הרחמן הוא יעשה לנו נסים ונפלאות כמו שעשה לאבותינו בימים ההם בזמן הזה״, "
    "ובחנוכה ממשיך ״בימי מתתיה וכו׳״, ובפורים ״בימי מרדכי ואסתר וכו׳ ועשית עמהם נסים ונפלאות "
    "ונודה לשמך הגדול סלה״ (ילקוט יוסף קפח, יח; תרצה, ו).")

# Edot, dans le repli d'oubli : la reprise après הטוב והמטיב (Kitsour Yalkut Yosef 188:6, 10, 12)
# et la formule « אשר נתן » de Yom tov selon le Yalkut Yosef (188:9-10 ; 529:7 ; 597:2).
OUBLI_EDOT = [
    "הערה: לדעת הילקוט יוסף (קפח, י; תקכט, ז; תקצז, ב) אומרים ״אשר נתן״ בשם ומלכות בכל סעודות יום טוב "
    "ובראש השנה, ולא רק בליל ראשון; ובראש חודש בלי שם ומלכות (קפח, ט).",
    "הערה: אם לא נזכר עד שהתחיל ברכת הטוב והמטיב, חוזר לראש ברכת המזון בשבת (בסעודה ראשונה ושנייה), "
    "ובליל ראשון של פסח ושל סוכות (ובחו״ל גם בליל שני, להרחבה); בראש חודש, בחול המועד ובסעודה שלישית "
    "אינו חוזר (ילקוט יוסף קפח, ו-יב).",
]

# Ashkenaz et Sfard, au début des « דיני שכחה » : la reprise après הטוב והמטיב.
OUBLI_REPRISE = {
    "ashkenaz": "הערה: אם לא נזכר עד שהתחיל הטוב והמטיב, חוזר לראש ברכת המזון בשבת וביום טוב; בראש חודש, "
                "בחול המועד ובסעודה שלישית אינו חוזר (שו״ע קפח, ו-ח; מ״ב קפח ס״ק כו). בראש השנה נחלקו "
                "האחרונים (מ״ב קפח ס״ק יט).",
    "sefard": "הערה: אם לא נזכר עד שהתחיל הטוב והמטיב, חוזר לראש ברכת המזון בשבת וביום טוב; בראש חודש, "
              "בחול המועד ובסעודה שלישית אינו חוזר (שו״ע קפח, ו-ח; שו״ע הרב קפח, ט-יא).",
}

# 'Hol hamoed (Choul'han Aroukh O.H. 188:7 ; Michna Beroura 188:27 ; Choul'han Aroukh haRav 188:11) :
# « אשר נתן מועדים… », sans חתימה ; libellé du Choul'han Aroukh haRav.
HOL_HAMOED_CONSIGNE = "בחול המועד (בלי חתימה; ״ביו״ט אומר״ אינו לחול המועד):"
HOL_HAMOED = ("בָּרוּךְ אַתָּה יְהֹוָה אֱלֹהֵינוּ מֶלֶךְ הָעוֹלָם אֲשֶׁר נָתַן מוֹעֲדִים לְעַמּוֹ יִשְׂרָאֵל "
              "לְשָׂשׂוֹן וּלְשִׂמְחָה אֶת חַג <small>(פלוני)</small> הַזֶּה:")

# Ashkenaz, Na'hem pour qui mange le 9 Av (Rema O.H. 557:1 ; Michna Beroura 557:5).
NAHEM_ASHKENAZ = ("מי שאוכל בתשעה באב אומר כאן ״נחם״, כבתפלת מנחה (״נחם ה׳ אלהינו את אבלי ציון…״), "
                  "ואם שכח אינו חוזר (רמ״א תקנז, א; מ״ב שם ס״ק ה).")

# Ashkenaz, le psaume d'avant le Birkat (Michna Beroura 1:11) : שיר המעלות le Chabbat et les jours
# sans Ta'hanoun, Yom tov compris ; על נהרות בבל les jours de Ta'hanoun.
PSAUMES_ASHKENAZ = {
    "בחול קודם ברכת המזון אומרים:": "בימים שאומרים בהם תחנון קודם ברכת המזון אומרים:",
    "בשבת קודם ברכת המזון אומרים:": "בשבת, ביו״ט ובימים שאין אומרים בהם תחנון קודם ברכת המזון אומרים (מ״ב א ס״ק יא):",
}


def birkat(sid, nusah):
    blocs = texte(sid, "birkat_hamazon")["sections"][0]["blocs"]
    fait = []
    if nusah == "edot":
        if not deja(blocs, "ביום הכפורים:"):
            k = trouve(blocs, "בשמיני עצרת:")
            blocs.insert(k + 1, {"t": KIPPOUR_YAALE})
            fait.append("יעלה ויבוא de Kippour")
        if not deja(blocs, "אם שכח ״על הנסים״"):
            k = trouve(blocs, "בפורים אומרים בימי מרדכי")
            blocs.insert(k + 1, {"c": OUBLI_AL_HANISSIM})
            fait.append("oubli d'על הנסים")
        # « נס ופלא » → « נסים ונפלאות » (Kitsour Yalkut Yosef 695:7 ; 682:21).
        for b in blocs:
            if "t" in b and "נֵס וָפֶֽלֶא" in b["t"]:
                b["t"] = b["t"].replace("נֵס וָפֶֽלֶא", "נִסִּים וְנִפְלָאוֹת")
                fait.append("נסים ונפלאות")
        if not deja(blocs, OUBLI_EDOT[0][:20]):
            k = trouve(blocs, 'אם שכח לומר "רצה"', consigne=True)
            blocs[k + 1:k + 1] = [{"c": x} for x in OUBLI_EDOT]
            fait.append("notes d'oubli")
    else:
        regle = trouve(blocs, "דיני שכחה", consigne=True)
        if not deja(blocs, OUBLI_REPRISE[nusah][:20]):
            blocs.insert(regle + 1, {"c": OUBLI_REPRISE[nusah]})
            fait.append("reprise après הטוב והמטיב")
        if not deja(blocs, "בחול המועד (בלי חתימה"):
            k = next(i for i in range(regle, len(blocs)) if "c" in blocs[i] and plat(blocs[i]["c"]) == "ביו״ט אומר:")
            blocs[k + 2:k + 2] = [{"c": HOL_HAMOED_CONSIGNE}, {"t": HOL_HAMOED}]
            fait.append("oubli à 'Hol hamoed")
        if nusah == "sefard":
            # Roch 'Hodech sans חתימה (Choul'han Aroukh 188:7 ; Choul'han Aroukh haRav 188:10, 13).
            k = trouve(blocs, "ברוך אתה יהוה אלהינו מלך העולם אשר נתן ראשי חדשים")
            t = blocs[k]["t"]
            if "מְקַדֵּשׁ יִשְׂרָאֵל וְרָאשֵׁי חֳדָשִׁים" in t:
                blocs[k]["t"] = t[:t.index("לְזִכָּרוֹן:") + len("לְזִכָּרוֹן:")]
                fait.append("Roch 'Hodech sans חתימה")
        else:
            # Roch haChana avec la חתימה (Michna Beroura 188:19 ; Kitsour Choul'han Aroukh 44:14).
            k = next((i for i in range(regle, len(blocs)) if "t" in blocs[i]
                     and plat(blocs[i]["t"]).endswith("אשר נתן ימים טובים לעמו ישראל לזכרון:")), None)
            if k is not None:
                blocs[k]["t"] = blocs[k]["t"].replace(
                    "לְזִכָּרוֹן:", "אֶת יוֹם הַזִּכָּרוֹן הַזֶּה: בָּרוּךְ אַתָּה יְהֹוָה מְקַדֵּשׁ יִשְׂרָאֵל וְיוֹם הַזִּכָּרוֹן:")
                fait.append("Roch haChana avec חתימה")
            if not deja(blocs, "מי שאוכל בתשעה באב"):
                k = trouve(blocs, "ובנה ירושלים")
                blocs.insert(k, {"c": NAHEM_ASHKENAZ})
                fait.append("Na'hem")
            for b in blocs:
                if "c" in b and b["c"] in PSAUMES_ASHKENAZ:
                    b["c"] = PSAUMES_ASHKENAZ[b["c"]]
                    fait.append("psaume d'avant le Birkat")
    return fait


# --- Bénédictions des occasions (tools/siddur_occasions.py) ---------------------------------

# Edot, la mer (Kitsour Yalkut Yosef 228:1) : « מנהגינו שלא לברך… בשם ומלכות ».
YAM_EDOT = "הרואה את הים הגדול, מנהגנו לברך בלי שם ומלכות, ואינו מברך אלא אחת לשלושים יום (ילקוט יוסף רכח, א):"

# Edot, éclairs et tonnerre (Kitsour Yalkut Yosef 227-229:1-3).
BARAKIM_EDOT = ("מברכים בשם ומלכות, תוך כדי דיבור לראיית הברק או לשמיעת הרעם; ואין לברך יותר מפעם אחת ביום, "
                "אלא אם כן נתפזרו העננים לגמרי. ואם ראה ברק, עדיף להמתין עד שישמע את הרעם ולברך ״שכחו וגבורתו מלא "
                "עולם״ בלבד, ויפטור את הברק (ילקוט יוסף רכז-רכט, א-ג). ומנהג בגדאד לברך בלי שם ומלכות (בן איש חי, עקב טז).")

# Edot, Acher yatsar (Kitsour Yalkut Yosef 6:4).
ACHER_YATSAR = ("אם הטיל מים או עשה צרכיו ושכח לברך, מברך עד שיעור פרסה (72 דקות) – ילקוט יוסף סי׳ ו ס״ד; "
                "ולבן איש חי (ויצא הי״ב) רק תוך חצי שעה")

# Ashkenaz, le seuil de la 'hala (Michna Beroura 456:3 ; le Rav 'Haïm Naé).
HALA_ASHKENAZ = ("ה. שעור הפרשת חלה: בלי ברכה מ־1.2 ק״ג קמח; בברכה מכ־1.666 ק״ג (שיטת הגר״ח נאה); "
                 "ולשיטת החזו״א מכ־2.25 ק״ג — וינהג כמנהג רבותיו (מ״ב תנו ס״ק ג).")

# Edot, les bougies de Kippour (Kitsour Yalkut Yosef 610:1-2, 4) ; formule du Ben Ich 'Haï, Vayélekh 8.
KIPPOUR_NEROT_CONSIGNE = ("ליום הכפורים, קודם ההדלקה, תברך (ילקוט יוסף תרי, א-ב), ואין מברכים שהחיינו בשעת "
                          "ההדלקה (שם, ד); הנוסח כבן איש חי (וילך, שנה א, ח):")

HAMOTSI = "<b>בָּרוּךְ</b> אַתָּה יְהֹוָה אֱלֹהֵינוּ מֶלֶךְ הָעוֹלָם, הַמּוֹצִיא לֶחֶם מִן הָאָרֶץ:"


def occasions(sid, nusah, edot):
    fait = []
    if nusah == "edot":
        blocs = texte(sid, "yam")["sections"][0]["blocs"]
        if plat(blocs[0]["c"]) == "הרואה את הים הגדול מברך:":
            blocs[0]["c"] = YAM_EDOT
            blocs[1]["t"] = blocs[1]["t"].replace("אַתָּה יְהֹוָה אֱלֹהֵינוּ מֶלֶךְ הָעוֹלָם,", "(אַתָּה יְהֹוָה אֱלֹהֵינוּ מֶלֶךְ הָעוֹלָם),")
            fait.append("la mer")
        blocs = texte(sid, "barakim")["sections"][0]["blocs"]
        if plat(blocs[0]["c"]) == "המנהג לברך בלי שם ומלכות":
            blocs[0]["c"] = BARAKIM_EDOT
            for b in blocs:
                if "t" in b:
                    b["t"] = re.sub(r"\((אַתָּה יְהֹוָה, אֱלֹהֵֽינוּ מֶלֶךְ הָעוֹלָם)\)", r"\1,", b["t"])
            fait.append("éclairs et tonnerre")
        for id_, si in (("acher_yatsar", 0), ("birkot_hachahar", 1)):
            for b in texte(sid, id_)["sections"][si]["blocs"]:
                if "c" in b and b["c"] == "אם הטיל מים או עשה צרכיו יברך תוך חצי שעה (בא״ח ויצא הי״ב)":
                    b["c"] = ACHER_YATSAR
                    fait.append("Acher yatsar " + id_)
        blocs = texte(sid, "nerot_chabbat")["sections"][0]["blocs"]
        if not deja(blocs, "ליום הכפורים, קודם ההדלקה"):
            yt = blocs[trouve(blocs, "ברוך אתה יהוה, אלהינו מלך העולם, אשר קדשנו במצותיו, וצונו להדליק נר של אם חל")]["t"]
            k = trouve(blocs, "ברוך אתה יהוה, אלהינו מלך העולם, שהחינו")
            blocs[k + 1:k + 1] = [{"c": KIPPOUR_NEROT_CONSIGNE}, {"t": yt.replace("יוֹם טוֹב", "יוֹם הַכִּפֻּרִים")}]
            fait.append("bougies de Kippour")
        # המוציא et la נטילת ידים avant le repas, en tête des bénédictions des plaisirs.
        blocs = texte(sid, "nehenin")["sections"][0]["blocs"]
        if not deja(blocs, "לפני אכילת פת"):
            netila = next(b["t"] for b in texte(sid, "birkot_hachahar")["sections"][1]["blocs"]
                          if "t" in b and "נְטִילַת יָדָיִם" in b["t"])
            blocs[0:0] = [{"c": "לפני אכילת פת נוטל ידיו ומברך"}, {"t": netila}, {"c": "על הפת מברך"}, {"t": HAMOTSI}]
            fait.append("נטילת ידים et המוציא")
    else:
        if nusah == "ashkenaz":
            for b in texte(sid, "hala")["sections"][0]["blocs"]:
                if "c" in b and "שו״ת חזו״ע" in b["c"]:
                    b["c"] = HALA_ASHKENAZ
                    fait.append("'hala")
        # המוציא, מזונות et הגפן (Choul'han Aroukh O.H. 167:2, 208:2, 202:1) : formules du même
        # siddour (נטילת ידים) ou des bénédictions des plaisirs Edot (מזונות, הגפן).
        t = texte(sid, "nehenin")
        if not any(plat(s["titre"]) == "ברכת המוציא" for s in t["sections"]):
            netila = next(b["t"] for b in texte(sid, "birkot_hachahar")["sections"][1]["blocs"]
                          if "t" in b and "נְטִילַת יָדָֽיִם" in b["t"])
            en = texte(edot, "nehenin")["sections"][0]["blocs"]
            mezonot = en[trouve(en, "ברוך אתה יהוה, אלהינו מלך העולם, בורא מיני מזונות")]["t"]
            gefen = en[trouve(en, "ברוך אתה יהוה, אלהינו מלך העולם, בורא פרי הגפן")]["t"]
            t["sections"][0:0] = [
                {"titre": "ברכת המוציא", "blocs": [{"c": "לפני אכילת פת נוטל ידיו ומברך:"}, {"t": netila},
                                                   {"c": "על הפת מברך:"}, {"t": HAMOTSI}]},
                {"titre": "בורא מיני מזונות", "blocs": [{"c": "על מאפה ותבשיל מחמשת מיני דגן (חוץ מן הפת) מברך:"}, {"t": mezonot}]},
                {"titre": "בורא פרי הגפן", "blocs": [{"c": "על היין מברך:"}, {"t": gefen}]},
            ]
            fait.append("המוציא, מזונות, הגפן")
    return fait


def amida(sid, nusah):
    """
    Edot, על הנסים de Pourim dans l'Amida de Cha'harit, Min'ha et Arvit : « נסים ונפלאות » au lieu de
    « נס ופלא », comme dans le Birkat (Kitsour Yalkut Yosef 695:7 ; 682:21).
    """
    fait = []
    if nusah != "edot":
        return fait
    for office in ("chaharit", "minha", "arvit"):
        for s in texte(sid, office)["sections"]:
            for b in s["blocs"]:
                if "t" in b and "וְעָשִֽׂיתָ עִמָּהֶם נֵס וָפֶֽלֶא" in b["t"] and "בימי מרדכי" in plat(b["t"]):
                    b["t"] = b["t"].replace("נֵס וָפֶֽלֶא", "נִסִּים וְנִפְלָאוֹת")
                    fait.append(f"נסים ונפלאות ({office})")
    return fait


def main():
    chemins = {n: os.path.join(RAW, f"siddur_{n}.json") for n in ("edot", "sefard", "ashkenaz")}
    siddurs = {n: json.load(open(c, encoding="utf-8")) for n, c in chemins.items()}
    for n, sid in siddurs.items():
        fait = birkat(sid, n) + amida(sid, n) + occasions(sid, n, siddurs["edot"])
        json.dump(sid, open(chemins[n], "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
        print(n, ":", ", ".join(fait) if fait else "rien à faire")


if __name__ == "__main__":
    main()
