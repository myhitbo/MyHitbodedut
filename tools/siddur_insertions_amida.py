# -*- coding: utf-8 -*-
"""
Insertions de la Amida : les corrections de texte de l'audit halakhique du 16/11/2026.

1. Edot, Na'hem le 9 Av à Arvit et à Cha'harit, pas seulement à Min'ha : « וכן מנהג ירושלים לומר
   נחם בכל התפלות, ערבית שחרית ומנחה » (Yalkut Yosef, Kitsour 557:1). Le bloc « תשכון… בונה
   ירושלים » est coupé avant son sceau, et Na'hem s'insère entre les deux, repris mot pour mot de
   la Min'ha du même siddour (le bloc et son sceau « מנחם ציון בבנין ירושלים »).
2. Edot, consignes d'oubli de la Amida (le siddour n'en imprime aucune) : משיב הרוח et מוריד הטל,
   המלך הקדוש, טל ומטר, המלך המשפט, יעלה ויבא, על הנסים ; abrégées du Kitsour Yalkut Yosef de
   l'application (livre_yalkut_yosef_kitsour.json), avec leur renvoi. Puis le voyageur entre
   Israël et la diaspora pour טל ומטר (Kitsour 117:15-17).
3. Sfard, Ashkenaz : la consigne d'oubli de משיב הרוח (Kitsour Choul'han Aroukh 19) suppose qu'on ne dit
   pas מוריד הטל en été ; qui le dit ne recommence pas (Choul'han Aroukh 114:5 ; Michna Beroura
   114:35 ; Choul'han Aroukh haRav 114:6). Une consigne à côté, le texte du siddour n'est pas réécrit.
   Ashkenaz : le voyageur, Michna Beroura 117:5.
4. « ועל הנסים », avec le ו (Yalkut Yosef, Kitsour 682:4 ; Michna Beroura 682:1) : Edot et Ashkenaz,
   dont les Amidot portaient « על הנסים » (le Birkat ashkénaze avait déjà le ו).
5. Ashkenaz, dix jours de pénitence : « עושה השלום » n'était donné qu'à Arvit ; la chatima reste
   « המברך את עמו ישראל בשלום », « ויש נוהגין לומר עושה השלום » (Maté Efraïm 582:22) : une même
   note aux trois offices.

Idempotent. Puis : python3 tools/siddur_annotations.py

  python3 tools/siddur_insertions_amida.py
"""
import json
import os
import re

ICI = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(ICI, "..", "android", "app", "src", "main", "res", "raw")


def plat(t):
    t = re.sub(r"[֑-ׇ]", "", re.sub(r"<[^>]+>", " ", t))
    return re.sub(r"\s+", " ", t).strip()


def texte(b):
    return b.get("t") or b.get("c") or ""


def amida(d, office):
    """Les blocs de la section de la Amida (la première dont un bloc commence par « רפאנו »)."""
    t = next(t for t in d["textes"] if t["id"] == office)
    return next(s["blocs"] for s in t["sections"] if any(plat(texte(b)).startswith("רפאנו") for b in s["blocs"]))


def apres(blocs, k, *nouveaux):
    """Insère les blocs après k, sauf ceux déjà là (idempotent) ; rend le nombre inséré."""
    n = 0
    for b in nouveaux:
        if any(x == b for x in blocs):
            k = blocs.index(b)
            continue
        blocs.insert(k + 1, b)
        k += 1
        n += 1
    return n


def indice(blocs, debut, depuis=0):
    return next(k for k in range(depuis, len(blocs)) if plat(texte(blocs[k])).startswith(debut))


# --- Edot ------------------------------------------------------------------------------------
YY = "(ילקוט יוסף, קיצור שו״ע {})"
EDOT_MORID = {"c": "אם טעה בחורף ולא אמר משיב הרוח ומוריד הגשם, אלא אמר מוריד הטל כמנהגנו בקיץ: אם נזכר באמצע הברכה, "
              "טוב שיחזור לומר מוריד הגשם; ואם אמר ברוך אתה ה' מחיה המתים, ימשיך כסדר ואינו חוזר. ואם טעה בקיץ ואמר "
              "מוריד הגשם: אם נזכר קודם שסיים מחיה המתים, חוזר לאתה גבור (ואם כבר אמר ברוך אתה ה', יאמר למדני חקיך "
              "ויחזור); ואם סיים מחיה המתים, חוזר לראש התפלה. ואם נסתפק בקיץ מה אמר, בתוך שלשים יום מפסח חוזר, "
              "ולאחר שלשים יום אינו חוזר. " + YY.format("קיד:ב, ד, ח")}
EDOT_KADOCH = {"c": "אם טעה בין ראש השנה ליום הכפורים וחתם האל הקדוש: אם נזכר תוך כדי דיבור, אומר מיד המלך הקדוש; ואם לאו, "
               "חוזר לראש התפלה. וכן אם נסתפק אם אמר המלך הקדוש, חוזר לראש התפלה. " + YY.format("תקפב:ב-ג")}
EDOT_TAL = {"c": "אם טעה בחורף ולא שאל טל ומטר: אם נזכר קודם שחתם מברך השנים, חוזר ואומר ותן טל ומטר לברכה; אם חתם, אומר "
            "ותן טל ומטר לברכה קודם תקע בשופר; אם התחיל תקע בשופר, אומרו בשמע קולנו קודם כי אתה שומע; אם חתם שומע "
            "תפלה, אומרו קודם רצה; אם התחיל רצה, חוזר לברך עלינו וממשיך על הסדר; ואם סיים יהיו לרצון האחרון, חוזר "
            "לראש התפלה. ואם נסתפק לאחר שלשים יום, אינו חוזר. ומי שטעה ושאל טל ומטר קודם זמנו, בעונת הגשמים, אינו "
            "חוזר. " + YY.format("קיז:ג, ה-ו, י")}
EDOT_VOYAGEUR = {"c": "בן ארץ ישראל בחוץ לארץ, שדעתו לחזור לארץ ישראל במשך השנה, או שהשאיר אשה ובנים בארץ ישראל: אם יצא קודם "
                 "שבעה בחשון, שואל טל ומטר בשמע קולנו; ואם כבר התחיל לשאול בשבעה בחשון, ממשיך לשאול בברכת השנים (וכשהוא "
                 "שליח צבור אומר ברכנו, ובשמע קולנו ותן טל ומטר לברכה בלחש). ותייר בארץ ישראל שדעתו לחזור לחוץ לארץ, שואל "
                 "בשבעה בחשון כמנהג המקום, וכשיחזור מפסיק עד ששים לתקופה, וטוב שימשיך לשאול בשמע קולנו. "
                 + YY.format("קיז:טו-יז")}
EDOT_MICHPAT = {"c": "אם טעה בין ראש השנה ליום הכפורים וחתם מלך אוהב צדקה ומשפט: אם נזכר תוך כדי דיבור, מסיים המלך המשפט; "
                "ואם לאו, חוזר לברכת השיבה וממשיך על הסדר, אפילו נזכר בשים שלום או באלהי נצור; ואם סיים יהיו לרצון "
                "האחרון, חוזר לראש התפלה. ואם נזכר רק לאחר שסיים תפלתו, חוזר ומתפלל ומתנה: אם אני חייב, הריני מתפלל "
                "לחובתי, ואם לאו, תהיה תפלתי נדבה. " + YY.format("קז:ח; תקפב:י-יא")}
EDOT_YAALE = {"c": "אם שכח יעלה ויבא בראש חודש או בחול המועד: אם נזכר אחר שאמר ברוך אתה ה' שבסוף רצה, אומר למדני חקיך וחוזר "
              "ליעלה ויבא; אם סיים המחזיר שכינתו לציון ולא התחיל מודים, אומר שם יעלה ויבא בלי חתימה; אם התחיל מודים, "
              "חוזר לרצה; ואם סיים יהיו לרצון האחרון, חוזר לראש התפלה. " + YY.format("קז:טז, כא")}
EDOT_YAALE_ARVIT = {"c": "אם שכח יעלה ויבא בערבית של ראש חודש, אינו חוזר, לפי שאין מקדשין את החודש בלילה; ואפילו נזכר קודם "
                    "מודים, לא יאמרנו שם, אבל רשאי לאומרו בסוף אלהי נצור דרך בקשת רחמים. " + YY.format("קז:טז")}
EDOT_NISSIM = {"c": "אם שכח ועל הנסים: אם נזכר קודם שהזכיר השם בחתימת הטוב שמך, חוזר ואומרו וממשיך ועל כלם; ואם הזכיר השם, "
               "אינו חוזר, ונכון שיאמרנו בסוף אלהי נצור: מודים אנחנו לך על הנסים וכו'. " + YY.format("תרפב:ה, ז; תרצג:ב")}


def edot_nahem(minha, blocs):
    """Coupe « תשכון… בונה ירושלים » avant le sceau, et y met Na'hem et son sceau (ceux de Min'ha)."""
    k = indice(blocs, "תשכון בתוך ירושלים")
    if plat(texte(blocs[k + 1])).startswith("בתשעה באב אומרים"):
        return 0
    m = indice(minha, "בתשעה באב אומרים: נחם")
    nahem, sceau = dict(minha[m]), dict(minha[m + 1])
    brut = blocs[k]["t"]
    i = brut.index("בָּרוּךְ")
    blocs[k] = {"t": brut[:i].rstrip()}
    blocs[k + 1:k + 1] = [nahem, sceau, {"t": brut[i:]}]
    return 2


def edot(d):
    n = 0
    minha = amida(d, "minha")
    for office in ("chaharit", "arvit"):
        n += edot_nahem(minha, amida(d, office))
    for office in ("chaharit", "minha", "arvit"):
        b = amida(d, office)
        n += apres(b, indice(b, "בקיץ: מוריד הטל"), EDOT_MORID)
        n += apres(b, indice(b, "אתה קדוש ושמך"), EDOT_KADOCH)
        n += apres(b, indice(b, "ברך עלינו יהוה אלהינו"), EDOT_TAL, EDOT_VOYAGEUR)
        n += apres(b, indice(b, "השיבה שופטינו"), EDOT_MICHPAT)
        n += apres(b, indice(b, "לרחם בו עלינו"), EDOT_YAALE_ARVIT if office == "arvit" else EDOT_YAALE)
        n += apres(b, indice(b, "בפורים אומרים"), EDOT_NISSIM)
    return n


# --- Sfard, Ashkenaz -------------------------------------------------------------------------
REFS_TAL = "(שו״ע קיד:ה; משנה ברורה קיד:לה; שו״ע הרב קיד:ו)"
MORID_SFARD = {"c": "ואם לא אמר משיב הרוח ומוריד הגשם אבל אמר מוריד הטל, שאומרים בנוסח ספרד בקיץ, אינו חוזר, כיון שהזכיר טל; "
               "וכן אם נסתפק, אפילו בתוך שלושים יום, אינו חוזר. " + REFS_TAL}
MORID_ASHKENAZ = {"c": "ואם לא אמר משיב הרוח ומוריד הגשם אבל אמר מוריד הטל, למי שאומר מוריד הטל בקיץ (בארץ ישראל), אינו חוזר, "
                  "כיון שהזכיר טל; וכן אם נסתפק, אפילו בתוך שלושים יום, אינו חוזר. " + REFS_TAL}
VOYAGEUR_ASHKENAZ = {"c": "בן ארץ ישראל בחוץ לארץ, או בן חוץ לארץ בארץ ישראל: אם דעתו לחזור למקומו בתוך השנה, שואל טל ומטר "
                     "כמקומו; ויש אומרים שכל אחד ישאל כבני המקום שהוא נמצא בו. (משנה ברורה קיז:ה)"}
OUSE_HACHALOM = "<small>(יש נוהגין לחתום: בָּרוּךְ אַתָּה יְהֹוָה עֹשֶׂה הַשָּׁלוֹם. מטה אפרים תקפב:כב)</small>"


def ashkenaz_sfard(d, nusah):
    n = 0
    for office in ("chaharit", "minha", "arvit"):
        b = amida(d, office)
        n += apres(b, indice(b, "טעה ולא אמר בחורף משיב הרוח"), MORID_SFARD if nusah == "sefard" else MORID_ASHKENAZ)
        if nusah != "ashkenaz":
            continue
        n += apres(b, indice(b, "אם שכח לומר טל ומטר"), VOYAGEUR_ASHKENAZ)
        k = indice(b, "בעשי״ת: בספר חיים")
        t = b[k]["t"]
        if OUSE_HACHALOM not in t:
            t = t.replace(" (בָּרוּךְ אַתָּה יְהֹוָה עֹשֶׂה הַשָּׁלוֹם:)", "")
            b[k]["t"] = t + " " + OUSE_HACHALOM
            n += 1
    return n


def vav_al_hanissim(d, textes):
    n = 0
    for t in d["textes"]:
        if t["id"] not in textes:
            continue
        for s in t["sections"]:
            for b in s["blocs"]:
                if "t" in b and re.match(r"^\(?על הנסים ועל הפרקן", plat(b["t"])):
                    b["t"], k = re.subn(r"^((?:<[^>]+>)*)עַל(?=[\s<])", r"\1וְעַל", b["t"], count=1)
                    n += k
    return n


def main():
    for nusah in ("edot", "sefard", "ashkenaz"):
        nom = os.path.join(RAW, f"siddur_{nusah}.json")
        d = json.load(open(nom, encoding="utf-8"))
        if nusah == "edot":
            n = edot(d) + vav_al_hanissim(d, ("chaharit", "minha", "arvit", "birkat_hamazon", "moussaf_rosh_hodech"))
        else:
            n = ashkenaz_sfard(d, nusah)
            if nusah == "ashkenaz":
                n += vav_al_hanissim(d, ("chaharit", "minha", "arvit", "moussaf_rosh_hodech"))
        if n:
            with open(nom, "w", encoding="utf-8") as f:
                json.dump(d, f, ensure_ascii=False, separators=(",", ":"))
        print(nusah, n, "changement(s)")


if __name__ == "__main__":
    main()
