# -*- coding: utf-8 -*-
"""
« Chnayim mikra : les halakhot » (demande du propriétaire, 26/11/2026 : « Fais un recueil
d'halachot pour shnem mikra »), un petit livre de la bibliothèque, groupe « halakha ».

Chaque halakha repose sur des sources lues le 26/11/2026, citées mot pour mot en hébreu :
  - Choul'han Aroukh O.H. 285 avec les gloses du Rema — « Maginei Eretz: Shulchan Aruch Orach
    Chaim, Lemberg, 1893 » (API Sefaria), Public Domain ;
  - Michna Beroura 285 — « On Your Way » (API Sefaria), Public Domain ;
  - Kaf ha'Haïm O.H. 285 — « Kaf Hachayim, Orach Chayim vol. I-IV, Jerusalem 1910-1933 »
    (API Sefaria), Public Domain ;
  - Kitsour Choul'han Aroukh 72 — « Torat Emet 357 » (API Sefaria), Public Domain ;
  - Ben Ich 'Haï — « Ben Ish Hai -- Wikisource » (API Sefaria), Public Domain, l'édition du
    Ben Ich 'Haï déjà dans l'application (tools/ben_ish_hai_construction.py) ;
  - Rambam, Hilkhot Tefila 13:25 — « Torat Emet 370 » (API Sefaria), Public Domain ;
  - Choul'han Aroukh haRav O.H. 285 — « Kehot Publication Society » (API Sefaria), CC-BY-NC :
    citations courtes, sans la vocalisation, créditées dans le livre (application gratuite) ;
  - Kitsour Choul'han Aroukh Yalkout Yossef, siman 285 — la même édition que l'application
    (livre_yalkut_yosef_kitsour.json : Torat Emet, mahadoura 5767, CC BY-NC-SA 2.5, licence
    reçue par le propriétaire le 19/10/2026, crédit « הרב יצחק יוסף שליט״א »).

Sources d'aujourd'hui (demande du propriétaire transmise le 26/11/2026) : réponses de
Hidabroot (« שאל את הרב »), de Kav haHalakha haSefaradi (kavhalacha.co.il) et du beit hora'a
« Halakha lema'assé » du Rav Ofir Malka (hl5047.co.il). Œuvres protégées : rien n'en est
recopié ; chaque réponse est résumée, attribuée (auteur, titre, date, adresse), avec au plus
une courte phrase citée. Le Rav Binyamin 'Hota n'a pas de réponse écrite en ligne sur le sujet
(vidéos et enregistrements seulement) : rien n'en est tiré.

Pas de psak : chaque halakha dit qui tient quoi ; « rite » dit à qui elle s'adresse
(tous, sefarade = rite Edot, ashkenaze = rites Ashkenaz et Sfard).

Sorties :
  - le livre « chnayim_mikra » dans android/app/src/main/livres/livres.json (remplacé s'il
    existe), ses sources et licences dans son « _meta », puis tools/livres_decoupe.py
    (res/raw/livre_chnayim_mikra.json, dont le _meta reçoit ces sources ; livres_titres.json) ;
  - tools/chnayim_mikra/sources.json : la table de vérification (référence, adresse lue,
    citation hébraïque exacte ou passage résumé), pour le relecteur.

  python3 tools/chnayim_mikra/construction.py            # écrit le livre et la table
  python3 tools/chnayim_mikra/construction.py --verifie  # relit chaque citation à sa source
"""
import html
import json
import os
import re
import sys
import unicodedata
import urllib.parse
import urllib.request

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.normpath(os.path.join(ICI, "..", ".."))
LIVRES = os.path.join(RACINE, "android", "app", "src", "main", "livres", "livres.json")
YALKUT = os.path.join(RACINE, "android", "app", "src", "main", "res", "raw", "livre_yalkut_yosef_kitsour.json")
TABLE = os.path.join(ICI, "sources.json")
DATE = "26/11/2026"

# --- Les éditions -----------------------------------------------------------------------------

EDITIONS = {
    "ber": {"titre": "Talmud Bavli, Berakhot 8a-b (texte cité par le Kaf ha'Haïm 285:1)",
            "edition": "Kaf Hachayim, Orach Chayim vol. I-IV, Jerusalem 1910-1933", "licence": "Public Domain",
            "verifie_aussi": "Wikisource Talmud Bavli (Sefaria, CC-BY-SA), Berakhot 8a:30 et 8b:1, lu le 26/11/2026"},
    "sa": {"titre": "Choul'han Aroukh, Ora'h 'Haïm", "edition": "Maginei Eretz: Shulchan Aruch Orach Chaim, Lemberg, 1893", "licence": "Public Domain"},
    "rema": {"titre": "Rema (gloses du Choul'han Aroukh), Ora'h 'Haïm", "edition": "Maginei Eretz: Shulchan Aruch Orach Chaim, Lemberg, 1893", "licence": "Public Domain"},
    "mb": {"titre": "Michna Beroura", "edition": "On Your Way", "licence": "Public Domain"},
    "kh": {"titre": "Kaf ha'Haïm, Ora'h 'Haïm", "edition": "Kaf Hachayim, Orach Chayim vol. I-IV, Jerusalem 1910-1933", "licence": "Public Domain"},
    "ksa": {"titre": "Kitsour Choul'han Aroukh", "edition": "Torat Emet 357", "licence": "Public Domain"},
    "bih": {"titre": "Ben Ich 'Haï, Halakhot", "edition": "Ben Ish Hai -- Wikisource", "licence": "Public Domain"},
    "rambam": {"titre": "Rambam, Michné Torah, Hilkhot Tefila", "edition": "Torat Emet 370", "licence": "Public Domain"},
    "sahr": {"titre": "Choul'han Aroukh haRav, Ora'h 'Haïm", "edition": "Kehot Publication Society", "licence": "CC-BY-NC",
             "note": "Texte de 1814 ; saisie de Kehot sous CC-BY-NC : courtes citations sans vocalisation, créditées en tête du livre ; application gratuite, sans publicité ni achat."},
    "kyy": {"titre": "Kitsour Choul'han Aroukh Yalkout Yossef, Rav Yitzhak Yosef chlita",
            "edition": "Torat Emet, mahadoura 5767 — la copie de l'application (livre_yalkut_yosef_kitsour.json, section « סימן רפה »)",
            "licence": "CC BY-NC-SA 2.5 ; licence reçue par le propriétaire, crédit « הרב יצחק יוסף שליט״א » (19/10/2026)"},
    "hid": {"titre": "Hidabroot, « שאל את הרב »", "edition": "hidabroot.org", "licence": "Tous droits réservés : résumé et référence, au plus une courte phrase citée"},
    "kav": {"titre": "Kav haHalakha haSefaradi (קו ההלכה הספרדי)", "edition": "kavhalacha.co.il", "licence": "Tous droits réservés : résumé et référence, au plus une courte phrase citée"},
    "malka": {"titre": "Beit hora'a « Halakha lema'assé » du Rav Ofir Malka (הלכה למעשה)", "edition": "hl5047.co.il", "licence": "Tous droits réservés : résumé et référence, au plus une courte phrase citée"},
}

SEFARIA = {
    "ber": ("Kaf HaChayim on Shulchan Arukh, Orach Chayim 285:{}", "Kaf Hachayim, Orach Chayim vol. I-IV, Jerusalem 1910-1933"),
    "sa": ("Shulchan Arukh, Orach Chayim 285:{}", "Maginei Eretz: Shulchan Aruch Orach Chaim, Lemberg, 1893"),
    "rema": ("Shulchan Arukh, Orach Chayim 285:{}", "Maginei Eretz: Shulchan Aruch Orach Chaim, Lemberg, 1893"),
    "mb": ("Mishnah Berurah 285:{}", "On Your Way"),
    "kh": ("Kaf HaChayim on Shulchan Arukh, Orach Chayim 285:{}", "Kaf Hachayim, Orach Chayim vol. I-IV, Jerusalem 1910-1933"),
    "ksa": ("Kitzur Shulchan Arukh 72:{}", "Torat Emet 357"),
    "bih": ("Ben Ish Hai, Halachot {}", "Ben Ish Hai -- Wikisource"),
    "rambam": ("Mishneh Torah, Prayer and the Priestly Blessing 13:{}", "Torat Emet 370"),
    "sahr": ("Shulchan Arukh HaRav, Orach Chayim 285:{}", "Kehot Publication Society"),
}

# Les réponses d'aujourd'hui : auteur, titre, date, adresse.
MODERNES = {
    ("hid", "221007"): {"auteur": "Hillel Meirs", "auteur_he": "הרב הלל מאירס", "titre": "הלכה לגבי קריאת שניים מקרא ואחד תרגום", "date": "23/01/2017", "date_he": "כ״ה טבת התשע״ז"},
    ("hid", "262007"): {"auteur": "Hillel Meirs", "auteur_he": "הרב הלל מאירס", "titre": "הלכות שניים מקרא ואחד תרגום", "date": "14/03/2019", "date_he": "ז׳ אדר ב׳ התשע״ט"},
    ("hid", "262097"): {"auteur": "Hillel Meirs", "auteur_he": "הרב הלל מאירס", "titre": "האם גם נשים חייבות בשניים מקרא ואחד תרגום?", "date": "17/03/2019", "date_he": "י׳ אדר ב׳ התשע״ט"},
    ("hid", "253987"): {"auteur": "Hillel Meirs", "auteur_he": "הרב הלל מאירס", "titre": "האם חולה יכול לשמוע שניים מקרא ואחד תרגום מאשתו?", "date": "01/10/2018", "date_he": "כ״ב תשרי התשע״ט"},
    ("hid", "299490"): {"auteur": "Binyamin Chmouéli", "auteur_he": "הרב בנימין שמואלי", "titre": "איך לקרוא שניים מקרא אחד תרגום?", "date": "13/12/2021", "date_he": "ט׳ טבת התשפ״ב"},
    ("hid", "301252"): {"auteur": "Binyamin Chmouéli", "auteur_he": "הרב בנימין שמואלי", "titre": "לגבי שניים מקרא ואחד תרגום", "date": "11/02/2022", "date_he": "י׳ אדר א׳ התשפ״ב"},
    ("hid", "303250"): {"auteur": "Binyamin Chmouéli", "auteur_he": "הרב בנימין שמואלי", "titre": "פרשות השבוע, שניים מקרא ואחד תרגום", "date": "11/04/2022", "date_he": "י׳ ניסן התשפ״ב"},
    ("hid", "354076"): {"auteur": "Binyamin Chmouéli", "auteur_he": "הרב בנימין שמואלי", "titre": "קריאת שניים מקרא ואחד תרגום", "date": "08/08/2025", "date_he": "י״ד אב התשפ״ה"},
    ("hid", "354260"): {"auteur": "Binyamin Chmouéli", "auteur_he": "הרב בנימין שמואלי", "titre": "שניים מקרא", "date": "21/08/2025", "date_he": "כ״ז אב התשפ״ה"},
    ("hid", "15385"): {"auteur": "Binyamin Chmouéli", "auteur_he": "הרב בנימין שמואלי", "titre": "שניים מקרא ואחד תרגום וטעמים", "date": "25/02/2014", "date_he": "כ״ה אדר א׳ התשע״ד"},
    ("kav", "yaron1"): {"auteur": "Rav Yaron Achkenazi", "auteur_court": "Rav Y. Achkenazi", "auteur_he": "הרב ירון אשכנזי", "titre": "הלכה יומית - הרב ירון אשכנזי - שנים מקרא ואחד תרגום", "date": "13/07/2017", "date_he": "י״ט תמוז התשע״ז",
                        "url": "https://kavhalacha.co.il/%D7%90%D7%A7%D7%98%D7%95%D7%90%D7%9C%D7%99%D7%94-%D7%91%D7%94%D7%9C%D7%9B%D7%94/%D7%9E%D7%90%D7%92%D7%A8-%D7%94%D7%94%D7%9C%D7%9B%D7%95%D7%AA/%D7%A7%D7%A8%D7%99%D7%90%D7%AA-%D7%94%D7%AA%D7%95%D7%A8%D7%94/2017-05-30-05-42-86"},
    ("kav", "yaron2"): {"auteur": "Rav Yaron Achkenazi", "auteur_court": "Rav Y. Achkenazi", "auteur_he": "הרב ירון אשכנזי", "titre": "הלכה יומית - הרב ירון אשכנזי - המשך דיני הפטרה וחיוב לומר שניים מקרא", "date": "07/06/2017", "date_he": "י״ג סיון התשע״ז",
                        "url": "https://kavhalacha.co.il/%D7%90%D7%A7%D7%98%D7%95%D7%90%D7%9C%D7%99%D7%94-%D7%91%D7%94%D7%9C%D7%9B%D7%94/%D7%9E%D7%90%D7%92%D7%A8-%D7%94%D7%94%D7%9C%D7%9B%D7%95%D7%AA/%D7%A7%D7%A8%D7%99%D7%90%D7%AA-%D7%94%D7%AA%D7%95%D7%A8%D7%94/2017-05-30-05-42-81"},
    ("kav", "azoulay"): {"auteur": "Rav Ochri Azoulay", "auteur_court": "Rav O. Azoulay", "auteur_he": "הרב אושרי אזולאי", "titre": "האם מותר לקרוא שניים מקרא ואחד תרגום בלילה?", "date": "13/01/2023", "date_he": "כ׳ טבת התשפ״ג",
                         "url": "https://kavhalacha.co.il/%D7%90%D7%A7%D7%98%D7%95%D7%90%D7%9C%D7%99%D7%94-%D7%91%D7%94%D7%9C%D7%9B%D7%94/%D7%94%D7%9C%D7%9B%D7%95%D7%AA-%D7%9E%D7%A2%D7%A0%D7%99%D7%99%D7%A0%D7%95%D7%AA/%D7%9E%D7%94-%D7%93%D7%99%D7%A0%D7%94-%D7%A9%D7%9C-%D7%97%D7%9C%D7%94-%D7%97%D7%AA%D7%95%D7%9B%D7%94-%D7%A9%D7%94%D7%99%D7%AA%D7%94-%D7%A2%D7%9C-%D7%A9%D7%95%D7%9C%D7%97%D7%9F-%D7%A9%D7%A0%D7%90%D7%9B%D7%9C-%D7%91%D7%95-%D7%91%D7%A9%D7%A8%D7%99,-%D7%94%D7%90%D7%9D-%D7%A0%D7%99%D7%AA%D7%9F-%D7%9C%D7%90%D7%9B%D7%95%D7%9C-%D7%9E%D7%9E%D7%A0%D7%94-%D7%A2%D7%9D-%D7%97%D7%9C%D7%91%D7%99-2"},
    ("malka", "142"): {"auteur": "Rav Menaché Moreno", "auteur_he": "הרב מנשה מורנו", "titre": "פרשת וזאת הברכה בתיקון קורא אחד", "date": "12/10/2025", "date_he": "12.10.2025"},
    ("malka", "484"): {"auteur": "Rav Emmanuel Molkandov", "auteur_he": "הרב עמנואל מולקנדוב", "titre": "מכשיר אלקטרוני עם ספרי קודש", "date": "22/09/2026", "date_he": "22.09.2026"},
}


def url_moderne(src, n):
    if src == "hid":
        return f"https://www.hidabroot.org/question/{n}"
    if src == "malka":
        return f"https://hl5047.co.il/questions/{n}"
    return MODERNES[(src, n)]["url"]


# --- Les nombres en lettres (Reference.lettres, sans le tour de 15 et 16 oublié) -------------

def lettres(n, geresh=True):
    u, d, c = " אבגדהוזחט", " יכלמנסעפצ", " קרשת"
    b, r = "", n
    while r >= 400:
        b += "ת"; r -= 400
    if r >= 100:
        b += c[r // 100]; r %= 100
    if r == 15:
        b += "טו"
    elif r == 16:
        b += "טז"
    else:
        if r >= 10:
            b += d[r // 10]
        if r % 10:
            b += u[r % 10]
    if not geresh:
        return b
    return b + "׳" if len(b) == 1 else b[:-1] + "״" + b[-1]


# --- Une référence ------------------------------------------------------------------------------
# R(source, numéro, cite=…) : numéro du se'if, de l'os ou de la question ; pour le Ben Ich 'Haï,
# (année, paracha anglaise de Sefaria, paracha française, paracha hébraïque, paragraphe).

def R(src, num, cite=None, passage=None):
    return {"src": src, "num": num, "cite": cite, "passage": passage}


BIH_ANNEE = {1: ("1st Year", "1re", "1st", "שנה א׳"), 2: ("2nd Year", "2e", "2nd", "שנה ב׳")}


def ref_texte(r, langue):
    """La référence d'une source, seule, dans la langue voulue."""
    s, n = r["src"], r["num"]
    if s == "bih":
        annee, _, par_fr, par_en, par_he, para = n
        a = BIH_ANNEE[annee]
        return {"fr": f"Ben Ich ’Haï, {a[1]} année, {par_fr} §{para}",
                "en": f"Ben Ish Chai, Year {annee}, {par_en} §{para}",
                "he": f"בן איש חי, {a[3]}, {par_he}, אות {lettres(para)}"}[langue]
    if s in ("hid", "kav", "malka"):
        m = MODERNES[(s, n)]
        if s == "hid":
            return {"fr": f"Hidabroot, question {n}", "en": f"Hidabroot, question {n}",
                    "he": f"הידברות, ״{m['titre']}״, {m['auteur_he']}, {m['date_he']}, hidabroot.org/question/{n}"}[langue]
        if s == "kav":
            return {"fr": f"Kav haHalakha haSefaradi ({m['auteur_court']}, {m['date']})",
                    "en": f"Kav HaHalacha HaSefaradi ({m['auteur_court'].replace('Achkenazi', 'Ashkenazi').replace('Ochri', 'Oshri')}, {m['date']})",
                    "he": f"קו ההלכה הספרדי, ״{m['titre']}״, {m['auteur_he']}, {m['date_he']} (kavhalacha.co.il)"}[langue]
        return {"fr": f"Halakha lema’assé (Rav O. Malka), question {n}", "en": f"Halacha LeMaaseh (Rav O. Malka), question {n}",
                "he": f"בית ההוראה ״הלכה למעשה״ של הרב אופיר מלכא, ״{m['titre']}״, {m['auteur_he']}, {m['date_he']}, hl5047.co.il/questions/{n}"}[langue]
    if s == "ber":
        return {"fr": "Berakhot 8a-b", "en": "Berakhot 8a-b", "he": "ברכות ח ע״א–ע״ב, בלשון כף החיים רפ״ה, אות א׳"}[langue]
    he_n = lettres(n) if isinstance(n, int) else n
    return {
        "sa": {"fr": f"Choul’han Aroukh O.H. 285:{n}", "en": f"Shulchan Aruch O.C. 285:{n}", "he": f"שולחן ערוך או״ח רפ״ה, {he_n}"},
        "rema": {"fr": f"Rema O.H. 285:{n}", "en": f"Rema O.C. 285:{n}", "he": f"רמ״א או״ח רפ״ה, {he_n}"},
        "mb": {"fr": f"Michna Beroura 285:{n}", "en": f"Mishnah Berurah 285:{n}", "he": f"משנה ברורה רפ״ה, ס״ק {he_n}"},
        "kh": {"fr": f"Kaf ha’Haïm 285:{n}", "en": f"Kaf HaChaim 285:{n}", "he": f"כף החיים רפ״ה, אות {he_n}"},
        "ksa": {"fr": f"Kitsour Choul’han Aroukh 72:{n}", "en": f"Kitzur Shulchan Aruch 72:{n}", "he": f"קיצור שולחן ערוך ע״ב, {he_n}"},
        "rambam": {"fr": f"Rambam, Hilkhot Tefila 13:{n}", "en": f"Rambam, Hilchot Tefillah 13:{n}", "he": f"רמב״ם, הלכות תפילה י״ג, {he_n}"},
        "sahr": {"fr": f"Choul’han Aroukh haRav O.H. 285:{n}", "en": f"Shulchan Aruch HaRav O.C. 285:{n}", "he": f"שולחן ערוך הרב או״ח רפ״ה, {he_n}"},
        "kyy": {"fr": f"Kitsour Yalkout Yossef 285:{n}", "en": f"Kitzur Yalkut Yosef 285:{n}", "he": f"ילקוט יוסף, קיצור שולחן ערוך רפ״ה, {he_n}"},
    }[s][langue]


def crochets(refs, langue):
    """Les références en fin de halakha, regroupées par livre : « Michna Beroura 285:1, 7 »."""
    groupes = []
    for r in refs:
        s = r["src"]
        cle = (s, r["num"][1]) if s == "bih" else s
        for g in groupes:
            if g[0] == cle:
                g[1].append(r)
                break
        else:
            groupes.append((cle, [r]))
    sortie = []
    for cle, rs in groupes:
        # Deux citations du même se'if ne le nomment qu'une fois.
        uniques = []
        for x in rs:
            if x["num"] not in [u["num"] for u in uniques]:
                uniques.append(x)
        rs = uniques
        s = rs[0]["src"]
        if s in ("hid", "malka") and len(rs) > 1:
            et = {"fr": " et ", "en": " and "}[langue]
            nums = et.join(str(x["num"]) for x in rs)
            base = ref_texte(rs[0], langue).rsplit(" ", 1)[0].replace("question", "questions")
            sortie.append(f"{base} {nums}")
        elif s == "bih" and len(rs) > 1:
            base = ref_texte(rs[0], langue).rsplit("§", 1)[0]
            et = {"fr": " et ", "en": " and "}[langue]
            sortie.append(base + et.join(f"§{x['num'][5]}" for x in rs))
        elif s in ("kav", "ber") or len(rs) == 1:
            vus = []
            for x in rs:
                t = ref_texte(x, langue)
                if t not in vus:
                    vus.append(t)
            sortie.extend(vus)
        else:
            base = ref_texte(rs[0], langue).rsplit(":", 1)[0]
            sortie.append(base + ":" + ", ".join(str(x["num"]) for x in rs))
    sep = {"fr": " ; ", "en": "; "}[langue]
    return sep.join(sortie)


# --- La typographie ------------------------------------------------------------------------------

def typo_fr(t):
    t = t.replace("'", "’")
    t = re.sub(r" ([:;?!»])", " \\1", t)
    t = t.replace("« ", "« ")
    return t


def typo_en(t):
    return t.replace("'", "’")


ETIQUETTES = {
    "sefarade": {"he": "[ספרדים – עדות המזרח]", "fr": "[Séfarades – rite Edot]", "en": "[Sephardim – Edot rite]"},
    "ashkenaze": {"he": "[אשכנזים – נוסח אשכנז ונוסח ספרד]", "fr": "[Ashkénazes – rites Ashkenaz et Sfard]", "en": "[Ashkenazim – Ashkenaz and Sfard rites]"},
}
RITES = {"tous": ["edot", "sefard", "ashkenaz"], "sefarade": ["edot"], "ashkenaze": ["ashkenaz", "sefard"]}

# --- Les halakhot -------------------------------------------------------------------------------
# H(rite, refs, fr, en) : le français et l'anglais sans numéro ni références (ajoutés ici).

def H(rite, refs, fr, en):
    return {"rite": rite, "refs": refs, "fr": fr, "en": en}


SECTIONS = [
    {"titre": "חיוב המצוה", "titre_fr": "L'obligation", "titre_en": "The obligation", "halakhot": [
        H("tous", [
            R("ber", 1, cite="לעולם ישלים אדם פרשיותיו עם הצבור שנים מקרא ואחד תרגום ואפי' עטרות ודיבון שכל המשלים פרשיותיו עם הצבור מאריכין לו ימיו ושנותיו"),
            R("sa", 1, cite='אע"פ שאדם שומע כל התורה כולה כל שבת בצבור חייב לקרות לעצמו בכל שבוע פרשת אותו שבוע שנים מקרא ואחד תרגום אפילו עטרות ודיבון'),
        ],
            "Même si l'on entend chaque Chabbat toute la paracha lue en public, on doit lire soi-même, chaque semaine, la paracha de cette semaine : deux fois le texte hébreu (mikra) et une fois la traduction araméenne (targoum), et cela même pour le verset « Atarot et Divon » (Bamidbar 32:3). Le Talmud enseigne que celui qui « achève ses parachiot avec la communauté » voit ses jours et ses années prolongés.",
            "Even though one hears the whole parasha read in public every Shabbat, one must read the parasha of each week by oneself: twice in the Hebrew original (mikra) and once in the Aramaic translation (targum), even the verse “Atarot and Divon” (Numbers 32:3). The Talmud teaches that whoever “completes his portions with the congregation” has his days and years lengthened."),
        H("tous", [
            R("kyy", 12, cite="אשה פטורה מלקרוא בכל שבת שנים מקרא ואחד תרגום"),
            R("hid", "262097", cite="לא חייבות", passage='לא חייבות. מקורות: שו"ת משנה הלכות חלק ו\' (סימן ס) וספר חזון עובדיה שבת חלק א\' (עמוד שכח).'),
            R("hid", "253987", passage='נראה שאשתו לא יכולה להוציא אותו ידי חובת שניים מקרא ואחד תרגום כיוון שהיא לא חייבת בזה כלל'),
        ],
            "Une femme est dispensée de lire chaque Chabbat Chnayim mikra véé'had targoum (Kitsour Yalkout Yossef). Le Rav Hillel Meirs (Hidabroot) répond de même que les femmes n'y sont pas obligées, en renvoyant au Mishné Halakhot (t. 6, siman 60) et au 'Hazon Ovadia (Chabbat, t. 1, p. 228) ; il en déduit, dans une autre réponse, qu'une épouse ne peut pas acquitter son mari malade en lisant pour lui, puisqu'elle-même n'y est pas obligée.",
            "A woman is exempt from reading Shnayim mikra ve-echad targum every week (Kitzur Yalkut Yosef). Rav Hillel Meirs (Hidabroot) likewise answers that women are not obligated, citing Mishneh Halachot (vol. 6, siman 60) and Chazon Ovadia (Shabbat, vol. 1, p. 228); in another answer he concludes that a wife cannot discharge her sick husband by reading for him, since she herself is not obligated."),
    ]},
    {"titre": "זמן הקריאה", "titre_fr": "Quand lire", "titre_en": "When to read", "halakhot": [
        H("tous", [
            R("sa", 3, cite="מיום ראשון ואילך חשיב עם הצבור"),
            R("mb", 1, cite="היינו שלא יקדים לקרות קודם אותו שבוע וגם לא יאחר"),
            R("mb", 7, cite='כיון שמתחילין במנחתא דשבתא לקרות פרשת שבוע הבא נחשב שוב הקורא כקורא עם הציבור וא"כ מה שכתב המחבר מיום ראשון ואילך לאו דוקא הוא'),
            R("mb", 8, cite='וכן בספר מעשה רב כתב בהנהגת הגר"א שהיה נוהג תיכף אחר התפלה בכל יום לקרוא מקצת מהסדרה שנים מקרא ואחד תרגום ומסיים בע"ש'),
            R("sahr", 6, cite="אבל מן הדין אין צריך לקרות כל הפרשה שנים מקרא ואחד תרגום בפעם אחת"),
            R("hid", "221007", cite="אפשר להתחיל לקרוא שניים מקרא ואחד תרגום ממנחה של שבת",
              passage="אפשר להתחיל לקרוא שניים מקרא ואחד תרגום ממנחה של שבת (ראה שלחן ערוך אורח חיים סימן רפה סעיף ג ומשנה ברורה סק\"ז). וניתן גם לחלק את הקריאה לימי השבוע, ולקרוא כל יום חלק מפרשת השבוע"),
            R("hid", "354260", cite="אפשר לומר את התרגום בנפרד מקריאת החומש"),
        ],
            "On peut lire la paracha de la semaine à partir du dimanche : on la lit déjà « avec la communauté » (Choul'han Aroukh). La Michna Beroura précise que ce « dimanche » n'est pas strict : dès la Min'ha de Chabbat, où l'on commence en public la paracha suivante, la lire compte déjà ; mais on ne la lit pas avant cette semaine-là, et on ne tarde pas non plus. Il n'est pas nécessaire de tout lire d'une traite : selon la loi, on peut répartir la paracha sur les jours de la semaine (Choul'han Aroukh haRav), et la Michna Beroura rapporte que le Gaon de Vilna en lisait chaque jour une partie après la prière, pour finir le vendredi. Le Rav Hillel Meirs (Hidabroot) répond dans le même sens : on peut commencer dès la Min'ha de Chabbat et répartir la lecture sur la semaine ; le Rav Binyamin Chmouéli (Hidabroot) ajoute qu'on peut dire le targoum séparément de la lecture du 'Houmach.",
            "One may read the weekly parasha from Sunday on: it already counts as reading “with the congregation” (Shulchan Aruch). The Mishnah Berurah explains that “Sunday” is not exact: from Minchah of Shabbat, when the next parasha is begun in public, reading it already counts; but one should neither read it before that week nor delay it. It need not be read at one sitting: by law one may spread the parasha over the days of the week (Shulchan Aruch HaRav), and the Mishnah Berurah reports that the Vilna Gaon read part of it each day after prayers, finishing on Friday. Rav Hillel Meirs (Hidabroot) answers in the same way: one may begin from Minchah of Shabbat and spread the reading over the week; Rav Binyamin Shmueli (Hidabroot) adds that the targum may be said separately from the reading of the Chumash."),
        H("ashkenaze", [
            R("ksa", 11, cite="אֲבָל הַמִּצְוָה מִן הַמֻּבְחָר הִיא לִקְרֹתָהּ בְּעֶרֶב שַׁבָּת אַחַר חֲצוֹת הַיּוֹם"),
            R("mb", 8, cite='כמה אחרונים כתבו דמן המובחר הוא לקרותה בע"ש ועיין בשע"ת ובספר מטה יהודה כתב דאם הוא קורא מתחלת השבוע והלאה הוא ג"כ בכלל מצוה מן המובחר'),
        ],
            "Le Kitsour Choul'han Aroukh écrit que le mieux est de lire la paracha la veille de Chabbat, après midi ('hatsot). La Michna Beroura rapporte que plusieurs A'haronim placent le meilleur moment la veille de Chabbat, mais que, selon le Maté Yehouda, celui qui lit dès le début de la semaine accomplit lui aussi la mitsva de la meilleure façon.",
            "The Kitzur Shulchan Aruch writes that it is best to read the parasha on Friday, after midday (chatzot). The Mishnah Berurah reports that several Acharonim hold Friday to be the best time, but that according to the Mateh Yehudah one who reads from the beginning of the week also fulfils the mitzvah in the best way."),
        H("sefarade", [
            R("kh", 24, cite='רבינו האר"י ז"ל יום הששי תכף ומיד אחר תפלת שחרית היה הולך למקום שיש ס"ת וקורא שמו"ת'),
            R("kh", 24, cite="ומנהג החסידים ואנשי מעשה לקרות אותה בבוקר אחר סיום תפלת שחרית בעודנו מעוטף בציצית ותפילין"),
            R("bih", (2, "Lech Lecha", "Lekh Lekha", "Lech Lecha", "לך לך", 11), cite="גם צריך עוד הכנה בדיבור ביום הששי בעצמו - לקרות הפרשה כולה שנים מקרא ואחד תרגום"),
            R("bih", (2, "Lech Lecha", "Lekh Lekha", "Lech Lecha", "לך לך", 1), cite='ואם ירצה לצאת קודם שיקרא שניים מקרא ואחד תרגום, כדי שילך לקנות במהרה, רשאי, ואח"כ יקרא בביתו'),
            R("kyy", 8, cite="ומכל מקום, מי ששעתו דחוקה לו ואינו יכול לנהוג כן, בודאי שיכול לקרוא שמו״ת החל מיום ראשון, וכפסק מרן השלחן ערוך"),
            R("hid", "354076", passage="האם יש מניעה ללמוד שנים מקרא ללא תפילין [...] שני הדברים אפשריים ללא כל חשש."),
        ],
            "Le Ari lisait la paracha le vendredi, aussitôt après la prière du matin, et le Kaf ha'Haïm rapporte que tel est l'usage des 'hassidim et des hommes d'action : la lire le matin, après Cha'harit, encore enveloppés du talith et des tefilines. Le Ben Ich 'Haï compte la lecture de toute la paracha, le vendredi, parmi les préparatifs du Chabbat « par la parole » ; celui qui a l'habitude d'étudier chaque matin après la prière lira plutôt, le vendredi, Chnayim mikra, puis ira faire les achats du Chabbat, et s'il veut d'abord sortir acheter rapidement, il le peut et lira ensuite chez lui. Le Kitsour Yalkout Yossef conclut que celui dont le temps est compté peut de toute façon lire dès le dimanche, comme le tranche le Choul'han Aroukh. Le Rav Binyamin Chmouéli (Hidabroot) répond qu'on peut lire Chnayim mikra sans porter les tefilines.",
            "The Ari read the parasha on Friday, right after the morning prayer, and the Kaf HaChaim reports that this is the custom of the chassidim and men of deeds: to read it in the morning after Shacharit, still wrapped in tallit and tefillin. The Ben Ish Chai counts reading the whole parasha on Friday among the preparations for Shabbat “by speech”; one who usually studies every morning after prayers should rather read Shnayim mikra on Friday and then go shopping for Shabbat, and if he wants to go out shopping quickly first, he may, and read at home afterwards. The Kitzur Yalkut Yosef concludes that one whose time is short may in any case read from Sunday on, as the Shulchan Aruch rules. Rav Binyamin Shmueli (Hidabroot) answers that one may read Shnayim mikra without wearing tefillin."),
        H("tous", [
            R("sa", 4, cite='מצוה מן המובחר שישלים אותה קודם שיאכל בשבת ואם לא השלים קודם אכילה ישלים אחר אכילה עד המנחה וי"א עד רביעי בשבת וי"א עד שמיני עצרת'),
            R("rema", 4, cite="(דהיינו בשמחת תורה שאז משלימים הצבור)"),
            R("mb", 11, cite="דג' ימים הראשונים שייכין עדיין קצת לשבת שעבר"),
            R("mb", 13, cite="ויש לו לקרות אז שנים מקרא ואחד תרגום ודלא כאותן שקורין מקרא לחוד"),
            R("kh", 28, cite='ובאבודרהם כתב דטוב להשלימה שמו"ת בעשרת ימי תשובה'),
            R("hid", "301252", passage='בדיעבד אפשר להשלים גם ביום ראשון ולהרבה דיעות גם עד יום שלישי. בדיעבד ישלים עד לשמחתת ורה.'),
        ],
            "Le mieux est d'achever la paracha avant de manger le Chabbat ; sinon, on l'achève après le repas, jusqu'à Min'ha. Certains permettent de l'achever jusqu'au mercredi – c'est-à-dire pendant les trois premiers jours de la semaine, qui tiennent encore un peu du Chabbat passé, explique la Michna Beroura –, d'autres jusqu'à Chemini Atseret – c'est-à-dire, précise le Rema, jusqu'à Sim'hat Torah, quand la communauté achève la Torah. Selon ce dernier avis, celui qui a laissé passer une semaine peut encore la rattraper jusque-là ; il la lit alors avec le targoum, et non le seul texte (Michna Beroura), et le Kaf ha'Haïm cite l'Abudarham : il est bon de la rattraper pendant les dix jours de pénitence. Le Rav Binyamin Chmouéli (Hidabroot) résume : a posteriori jusqu'au dimanche, selon beaucoup jusqu'au mardi, et a posteriori jusqu'à Sim'hat Torah.",
            "It is best to finish the parasha before eating on Shabbat; if not, one finishes it after the meal, until Minchah. Some allow finishing it until Wednesday – that is, during the first three days of the week, which still belong somewhat to the past Shabbat, the Mishnah Berurah explains –, others until Shemini Atzeret – that is, the Rema specifies, until Simchat Torah, when the congregation completes the Torah. According to this last view, one who missed a week may still make it up until then; he then reads it with the targum, not the text alone (Mishnah Berurah), and the Kaf HaChaim cites Abudarham: it is good to make it up during the ten days of repentance. Rav Binyamin Shmueli (Hidabroot) sums up: after the fact until Sunday, according to many until Tuesday, and after the fact until Simchat Torah."),
        H("ashkenaze", [
            R("mb", 9, cite='ומ"מ פשוט דאין לעכב מחמת זה האכילה עד אחר חצות'),
            R("mb", 9, cite='ולכתחלה מהנכון אם לא קרא שנים מקרא ואחד תרגום בע"ש להשכים בשבת בבקר ולקרא השמו"ת קודם הליכתו לבהכ"נ'),
            R("mb", 12, cite='אבל לכתחלה לכו"ע לא יאחר יותר מיום השבת'),
            R("sahr", 5, cite="וטוב לחוש לדבריהם שמי שעבר ולא השלים בזמנה ישלים עד סוף יום ג' ואם לא השלים יש לו להשלים עד שמחת תורה"),
        ],
            "La Michna Beroura précise qu'on ne retarde pas pour cela le repas du Chabbat au-delà de midi ('hatsot) ; mais celui qui n'a pas lu la veille fera bien de se lever tôt le Chabbat matin pour lire avant d'aller à la synagogue ; et a priori, tous s'accordent à ne pas dépasser le Chabbat. Le Choul'han Aroukh haRav conseille, à qui a laissé passer le temps, d'achever jusqu'à la fin du mardi, et sinon jusqu'à Sim'hat Torah.",
            "The Mishnah Berurah specifies that one does not delay the Shabbat meal past midday (chatzot) for this; but one who did not read on Friday should rise early on Shabbat morning and read before going to the synagogue; and ideally all agree not to go beyond Shabbat. The Shulchan Aruch HaRav advises one who let the time pass to finish by the end of Tuesday, and otherwise by Simchat Torah."),
        H("sefarade", [
            R("kyy", 5, cite="ומכל מקום פשוט שאין לעכב מחמת זה האכילה עד חצות. ואם לא השלים קודם האכילה, ישלים אחר האכילה עד זמן מנחה. ובדיעבד עד רביעי בשבת, ויש אומרים עד שמיני עצרת"),
            R("bih", (2, "Lech Lecha", "Lekh Lekha", "Lech Lecha", "לך לך", 11), cite="ואם נאנס ולא קרא הפרשה שנים מקרא ואחד תרגום ביום ששי, יקראנה שנים מקרא ואחד תרגום ביום שבת אחר התפילה קודם קידוש שבת"),
            R("kh", 3, cite="זולת אם אירע לו שום אונס גדול מאד שאז היה קורא הפ' שמו\"ת אחר סיום תפלת שחרית דיום שבת קודם סעודת שחרית כמו שצוה רבינו הקדוש לבנו ולא כמו אותם הקורים אותה באמצע תפלת שחרית דשבת"),
        ],
            "Le Kitsour Yalkout Yossef reprend l'ordre du Choul'han Aroukh : achever avant le repas du Chabbat, sans pour autant retarder le repas jusqu'à midi ; sinon après le repas, jusqu'à Min'ha ; a posteriori jusqu'au mercredi (« רביעי בשבת »), et certains disent jusqu'à Chemini Atseret. Le Ben Ich 'Haï écrit que celui qui a été empêché de lire le vendredi lira le Chabbat après la prière, avant le Kiddouch. Le Kaf ha'Haïm rapporte que le Ari, en cas de grand empêchement, lisait le Chabbat après la prière du matin, avant le repas, et non pendant l'office comme certains le font.",
            "The Kitzur Yalkut Yosef follows the order of the Shulchan Aruch: finish before the Shabbat meal, without delaying the meal until midday; if not, after the meal until Minchah; after the fact until Wednesday, and some say until Shemini Atzeret. The Ben Ish Chai writes that one who was prevented from reading on Friday should read on Shabbat after prayers, before Kiddush. The Kaf HaChaim reports that the Ari, when greatly prevented, read on Shabbat after the morning prayer, before the meal, and not during the service as some do."),
        H("sefarade", [
            R("kyy", 9, cite="מי שזמנו דחוק, מותר לו לקרוא שנים מקרא ואחד תרגום בליל שבת"),
            R("kyy", 1, cite="ואם עוסק בתורה שיש עמה כתיבת חידושי תורה ופסקי הלכה, יכול לקרוא בליל שבת שנים מקרא ואחד תרגום"),
            R("kh", 14, cite='אין לקרות הפ\' שמו"ת באשמורת אור הששי קודם שיאיר היום כ"י כתבו גורי האר"י ז"ל שאין לקרות תרגום בלילה'),
            R("kav", "azoulay", cite='וכל זה הוא ע"פ הקבלה אבל ע"פ הפשט אין מניעה ללמוד מקרא בלילה',
              passage='ולכן להלכה, אפשר לקרוא ב\' מקרא ואחד תרגום בלילה כאשר קוראים יחד עם זה מעט מדברי המפרשים כרש"י וכדו\'. ואם ממילא אדם לא ילמד אם לא יקרא שניים מקרא, ואינו יודע ללמוד רש"י או אחד ממפרשי התורה, יש להורות לו לכתחילה שיכול לקרוא אף ללא מפרשים'),
            R("malka", "142", cite='ותו דיותר נכון לקרא שמו"ת ביום ולא בלילה'),
            R("hid", "303250", cite="אין קוראים מתחילת הלילה עד חצות"),
        ],
            "La nuit. Le Kitsour Yalkout Yossef permet à qui manque de temps de lire Chnayim mikra la nuit du Chabbat (le vendredi soir), ainsi qu'à celui qui étudie la Torah en écrivant des 'hidouchim et des décisions de halakha. Le Kaf ha'Haïm rapporte, au nom des disciples du Ari, qu'on ne lit pas la paracha à la fin de la nuit de jeudi à vendredi, avant qu'il fasse jour, car on ne lit pas le targoum la nuit. Pour le Rav Ochri Azoulay (Kav haHalakha haSefaradi), c'est une règle de la Kabbale, alors que selon le sens simple rien n'empêche de lire la Torah écrite la nuit ; il conclut qu'on peut lire Chnayim mikra la nuit en y joignant un peu de commentaire, comme Rachi, et que celui qui sinon n'étudierait pas du tout peut lire même sans commentaire. Le Rav Menaché Moreno (beit hora'a « Halakha lema'assé » du Rav Ofir Malka) juge plus juste de lire le jour que la nuit, et le Rav Binyamin Chmouéli (Hidabroot) écrit qu'on ne lit pas depuis le début de la nuit jusqu'à minuit.",
            "At night. The Kitzur Yalkut Yosef allows one who is short of time to read Shnayim mikra on Friday night, as well as one who studies Torah while writing chiddushim and halachic rulings. The Kaf HaChaim reports in the name of the Ari’s disciples that one does not read the parasha at the end of Thursday night, before daybreak, since the targum is not read at night. Rav Oshri Azoulay (Kav HaHalacha HaSefaradi) explains that this is a kabbalistic rule, whereas by the plain law nothing prevents reading the Written Torah at night; he concludes that one may read Shnayim mikra at night while adding a little commentary such as Rashi, and that one who would otherwise not study at all may read even without commentary. Rav Menashe Moreno (the “Halacha LeMaaseh” beit hora’ah of Rav Ofir Malka) considers it more correct to read by day than by night, and Rav Binyamin Shmueli (Hidabroot) writes that one does not read from nightfall until midnight."),
    ]},
    {"titre": "סדר הקריאה", "titre_fr": "L'ordre de la lecture", "titre_en": "The order of reading", "halakhot": [
        H("tous", [
            R("mb", 6, cite='לא יקרא פסוק המאוחר קודם המוקדם אלא יקרא כסדר. לא יקרא התרגום תחלה ואח"כ מקרא אלא יקרא לכתחלה שנים מקרא מקודם ואח"כ תרגום'),
            R("kh", 6, cite='לא יקרא אחד מקרא ואח"כ תרגום ואח"כ מקרא אלא שנים מקרא וא\' תרגום'),
            R("kh", 15, cite='אם טעה ודילג פסוק אחר וקרא איזה פסוקים ואח"כ נזכר צריך לחזור ולקרות פסוק המדולג וגם מה שקרא אחריו כדי שיהיו כסדר'),
            R("bih", (2, "Lech Lecha", "Lekh Lekha", "Lech Lecha", "לך לך", 11), cite="ואחר שסיים הפרשה יכפול פסוק האחרון, ואין צריך לכפול גם התרגום שלו"),
            R("ksa", 11, cite="וּבַגְּמָר יֵשׁ לוֹמַר אַחַר הַתַּרְגּוּם פָּסוּק אֶחָד בַּתּוֹרָה, כְּדֵי לְסַיֵּם בַּתּוֹרָה"),
            R("sahr", 3, cite="ופסוק האחרון טוב לכופלו ולחזור ולאמרו כדי לסיים בתורה"),
            R("kh", 33, cite='אחר שגמר כל הפ\' שמו"ת יקרא פסוק אחרון פ"ג מקרא לבד כדי להשלים במקרא'),
            R("hid", "299490", cite="יכול", passage="רציתי לשאול אם אני יכול לקרוא פעם אחת את הפרשה, ואז לקרוא פסוק אחד ואז תרגום,עוד פסוק ותרגום וככה הלאה? [...] 1. יכול."),
        ],
            "On lit les versets dans l'ordre, sans lire un verset avant celui qui le précède ; on dit d'abord deux fois le texte, puis le targoum, et non le targoum en premier ni au milieu (Michna Beroura, Kaf ha'Haïm). Celui qui a sauté un verset et s'en aperçoit plus loin revient lire le verset oublié, puis ce qu'il avait lu après, pour garder l'ordre (Kaf ha'Haïm). À la fin de la paracha, on répète le dernier verset, pour finir par le texte de la Torah, sans avoir à en répéter le targoum (Ben Ich 'Haï ; de même le Kitsour Choul'han Aroukh, le Choul'han Aroukh haRav et le Kaf ha'Haïm). À qui demande s'il peut lire d'abord toute la paracha une fois, puis chaque verset une seconde fois suivi de son targoum, le Rav Binyamin Chmouéli (Hidabroot) répond que c'est possible.",
            "One reads the verses in order, never a verse before the one that precedes it; one says the text twice first, then the targum, not the targum first or in between (Mishnah Berurah, Kaf HaChaim). One who skipped a verse and notices later goes back to read the skipped verse and then what he had read after it, to keep the order (Kaf HaChaim). At the end of the parasha one repeats the last verse, so as to finish with the text of the Torah, without repeating its targum (Ben Ish Chai; likewise the Kitzur Shulchan Aruch, the Shulchan Aruch HaRav and the Kaf HaChaim). To one who asks whether he may first read the whole parasha once and then each verse a second time followed by its targum, Rav Binyamin Shmueli (Hidabroot) answers that he may."),
        H("ashkenaze", [
            R("mb", 2, cite='י"א שיקרא כל פסוק ב"פ ותרגום עליו וי"א שיקרא כל פרשה ב"פ ואח"כ התרגום'),
            R("mb", 2, cite="ודעביד כמר עביד ודעביד כמר עביד"),
            R("ksa", 11, cite="וְיֵשׁ לִקְרוֹת כָּל פָּרָשָׁה, דְּהַיְנוּ פְּתוּחָה אוֹ סְתוּמָה, שְׁנֵי פְּעָמִים, וְאַחַר כָּךְ הַתַּרְגּוּם עָלֶיהָ, (כֵּן הִסְכִּים הַגָּאוֹן הָרַב רַבִּי אֵלִיָהוּ מִוִילְנָא זֵכֶר צַדִּיק לִבְרָכָה) וַאֲפִלּוּ הַפָּרָשָׁה מְסַיֶּמֶת בְּאֶמְצַע פָּסוּק, יַפְסִיק שָׁם"),
            R("sahr", 3, cite="ויש נוהגין לקרות כל פסוק ב' פעמים והתרגום עליו מיד ומנהג זה נכון יותר"),
            R("sahr", 3, cite="(אבל מן הדין יכול לקרות שנים מקרא ואחד תרגום בכל ענין שירצה)"),
        ],
            "Verset par verset, ou section par section ? La Michna Beroura rapporte les deux avis : lire chaque verset deux fois puis son targoum, ou chaque section (ouverte ou fermée) deux fois puis son targoum ; le Maguen Avraham et les Cha'arei Techouva penchent pour le premier, le Gaon de Vilna disait le targoum après chaque section, et chacun peut suivre l'une ou l'autre façon. Le Kitsour Choul'han Aroukh retient la lecture par section, selon le Gaon de Vilna, en s'arrêtant à la fin de la section même au milieu d'un verset. Le Choul'han Aroukh haRav juge la lecture verset par verset plus juste, tout en notant que, selon la loi, on peut lire de la façon que l'on veut.",
            "Verse by verse, or section by section? The Mishnah Berurah reports both views: read each verse twice and then its targum, or each section (open or closed) twice and then its targum; the Magen Avraham and the Shaarei Teshuvah lean to the first, the Vilna Gaon said the targum after each section, and one may follow either way. The Kitzur Shulchan Aruch adopts reading by section, following the Vilna Gaon, stopping at the end of the section even in the middle of a verse. The Shulchan Aruch HaRav considers reading verse by verse more correct, while noting that by law one may read in whatever way one wishes."),
        H("sefarade", [
            R("kh", 3, cite='וכן היה עושה בכל פסוק ופסוק עד שמשלים הפרשה'),
            R("kyy", 4, cite="על פי דברי המקובלים צריך לקרוא את הפרשה כל פסוק ופסוק שנים מקרא ואחד תרגום, עד סיום כל הפרשה, בהמשך אחד"),
            R("kyy", 4, cite="ובאופן כזה גם כשמגיע לפסוק שמע ישראל, רשאי לקרוא שנים מקרא ואחד תרגום"),
            R("kav", "yaron1", cite="ומכל מקום אין זה מעכב להלכה",
              passage='הנה על פי דברי רבינו האר"י ז"ל, יש לקרות שנים מקרא ואחד תרגום כל פסוק עם תרגומו בפני עצמו, ולא להניח התרגום עד סיום הפרשה כולה, וכן הוא בספר האשכול (הלכות שני וחמישי סימן ב\'), ומכל מקום אין זה מעכב להלכה'),
            R("hid", "354076", cite="שני הדברים אפשריים ללא כל חשש",
              passage="האם יש מניעה לחזור על פרשת שמע פעמיים הן לאלו שקוראים פרשה פרשה והן לאלו שקוראים פסוק פסוק [...] שני הדברים אפשריים ללא כל חשש."),
        ],
            "Selon les kabbalistes, on lit chaque verset deux fois puis son targoum, verset après verset, jusqu'à la fin de la paracha, d'une seule traite : ainsi faisait le Ari, et ainsi font les 'hassidim et les hommes d'action (Kaf ha'Haïm ; Kitsour Yalkout Yossef). Le Rav Yaron Achkenazi (Kav haHalakha haSefaradi) précise que cela n'est pas indispensable selon la halakha. Lu ainsi, le verset « Chema Israël » peut être dit deux fois, car on voit bien qu'on le répète pour Chnayim mikra (Kitsour Yalkout Yossef) ; le Rav Binyamin Chmouéli (Hidabroot) répond aussi qu'on peut sans crainte répéter le Chema, que l'on lise par section ou verset par verset.",
            "According to the kabbalists, one reads each verse twice and then its targum, verse after verse, to the end of the parasha, at one sitting: so did the Ari, and so do the chassidim and men of deeds (Kaf HaChaim; Kitzur Yalkut Yosef). Rav Yaron Ashkenazi (Kav HaHalacha HaSefaradi) specifies that this is not indispensable by halachah. Read this way, the verse “Shema Yisrael” may be said twice, since it is clear that it is repeated for Shnayim mikra (Kitzur Yalkut Yosef); Rav Binyamin Shmueli (Hidabroot) also answers that one may repeat the Shema without concern, whether reading by section or verse by verse."),
        H("tous", [
            R("rambam", 25, cite="וּפָסוּק שֶׁאֵין בּוֹ תַּרְגּוּם קוֹרְאֵהוּ שָׁלֹשׁ פְּעָמִים"),
            R("mb", 3, cite='ר"ל אע"פ שאין בו תרגום וה"ה ראובן ושמעון וכי"ב צריך לקרותו ג"פ ויש מחמירין דבעטרות ודיבן שיש בו תרגום ירושלמי צריך לקרות שם התרגום'),
            R("kh", 18, cite='וכן הוא מנהג העולם שאין קורין ג"פ מקרא רק לפסוק שאין בו תרגום כלל כמו ראובן ושמעון וכדומה אבל לפסוק שיש בו תרגום כגון ברכת כהנים ועטרות ודיבון אין קורין כ"א שמו"ת לבד'),
            R("kav", "yaron2", passage='ומרן השלחן ערוך פסק כדעת הרמב,,ם שיקרא ג\' פעמים עטרות ודיבון ואינו צריך לקרוא בפעם השלישית את התרגום ירושלמי.'),
        ],
            "Un verset qui n'a pas de targoum se lit trois fois (Rambam). La Michna Beroura l'applique à « Atarot et Divon », lu trois fois parce qu'il n'a pas de targoum, et de même à « Réouven et Chimon » et aux versets semblables ; certains, plus stricts, lisent pour « Atarot et Divon » le targoum Yerouchalmi. Le Kaf ha'Haïm rapporte l'usage répandu : on ne lit trois fois que le verset qui n'a aucun targoum, comme « Réouven et Chimon », tandis que la bénédiction des Cohanim et « Atarot et Divon », qui ont un targoum, se lisent seulement deux fois avec leur targoum. Le Rav Yaron Achkenazi (Kav haHalakha haSefaradi) comprend, lui, que le Choul'han Aroukh suit le Rambam : « Atarot et Divon » trois fois, sans le targoum Yerouchalmi.",
            "A verse that has no targum is read three times (Rambam). The Mishnah Berurah applies this to “Atarot and Divon”, read three times because it has no targum, and likewise to “Reuven and Shimon” and similar verses; some, more stringent, read the Targum Yerushalmi for “Atarot and Divon”. The Kaf HaChaim reports the widespread custom: only a verse with no targum at all, such as “Reuven and Shimon”, is read three times, whereas the Priestly Blessing and “Atarot and Divon”, which have a targum, are read only twice with their targum. Rav Yaron Ashkenazi (Kav HaHalacha HaSefaradi), for his part, understands that the Shulchan Aruch follows the Rambam: “Atarot and Divon” three times, without the Targum Yerushalmi."),
        H("ashkenaze", [
            R("mb", 6, cite='אם אפשר לו שלא יפסיק בשמו"ת על שום דבר הוא טוב ויפה מאד וכן ראיתי מהמדקדקים עושין כן וכן ראוי לבעל נפש לעשות'),
            R("ksa", 11, cite="וְטוֹב שֶׁלֹּא יַפְסִיק בְּשִׂיחָה בֵּין הַקְּרִיאָה"),
            R("sahr", 6, cite="ויש נוהגין לגמור כולה ערב שבת שחרית אחר התפלה ושלא להפסיק כלל באמצע שנים מקרא ואחד תרגום אפילו בדבור"),
        ],
            "Il est très bien, si possible, de ne s'interrompre pour rien pendant Chnayim mikra : les gens scrupuleux le font, et il convient à qui tient à son âme de faire ainsi (Michna Beroura). Il est bon de ne pas s'interrompre par une conversation au milieu de la lecture (Kitsour Choul'han Aroukh). Le Choul'han Aroukh haRav rapporte l'usage de certains d'achever toute la paracha le vendredi matin après la prière, sans s'interrompre du tout, même par la parole.",
            "It is very good, if possible, not to interrupt Shnayim mikra for anything: careful people do so, and it befits one who cares for his soul (Mishnah Berurah). It is good not to interrupt the reading with conversation (Kitzur Shulchan Aruch). The Shulchan Aruch HaRav reports the custom of some to finish the whole parasha on Friday morning after prayers without any interruption, even by speech."),
        H("sefarade", [
            R("kyy", 6, cite="אף על פי שמדין התלמוד אין איסור להפסיק בדברים באמצע קריאת שנים מקרא ואחד תרגום, מכל מקום כבר נתבאר שעל פי הקבלה אין להפסיק כלל באמצע קריאתם"),
            R("kyy", 6, cite="זולת אם הוא צמא למים, שרשאי לברך ולשתות, וכן לברך ברכת בורא נפשות רבות"),
            R("kyy", 7, cite="מותר לו להפסיק בין פסוק לפסוק להשיב לשואלו דבר הלכה"),
            R("kh", 15, cite='וכתבו חכמי המקובלים שלא להפסיק בקריאת שמו"ת בשום דבר רק יקרא הכל בפעם אחת במעמד אחד'),
            R("kav", "yaron1", passage="מי שהתחיל לקרוא שנים מקרא ואחד תרגום אחר תפלת שחרית, ובאמצע קריאתו נתבקש לקרוא לפני הקהל איזה דבר הלכה, רשאי להפסיק מקריאתו, ולזכות את הרבים בקריאת דבר הלכה."),
        ],
            "Selon le Talmud, il n'est pas interdit de parler au milieu de Chnayim mikra ; mais selon la Kabbale on ne s'interrompt pas du tout, et l'on lit tout d'une traite (Kitsour Yalkout Yossef ; Kaf ha'Haïm). Celui qui a soif peut s'interrompre pour boire, avec la bénédiction avant et Boré nefachot après. Celui à qui l'on demande, au milieu de sa lecture du matin, de lire au public une halakha ou un enseignement sur la paracha peut s'interrompre pour en faire profiter le public (Kitsour Yalkout Yossef ; de même le Rav Yaron Achkenazi, Kav haHalakha haSefaradi) ; un érudit à qui l'on pose une question de halakha peut y répondre entre deux versets.",
            "By the Talmud it is not forbidden to talk in the middle of Shnayim mikra; but according to Kabbalah one does not interrupt at all, and reads everything at one sitting (Kitzur Yalkut Yosef; Kaf HaChaim). One who is thirsty may stop to drink, with the blessing before and Borei nefashot after. One who is asked, in the middle of his morning reading, to read a halachah or a teaching on the parasha to the public may stop to benefit the public (Kitzur Yalkut Yosef; likewise Rav Yaron Ashkenazi, Kav HaHalacha HaSefaradi); a Torah scholar asked a question of halachah may answer it between two verses."),
    ]},
    {"titre": "תרגום ופירוש רש״י", "titre_fr": "Targoum et Rachi", "titre_en": "Targum and Rashi", "halakhot": [
        H("tous", [
            R("sa", 2, cite='אם למד הפרשה בפירוש רש"י חשוב כמו תרגום וירא שמים יקרא תרגום וגם פרש"י'),
            R("hid", "299490", cite="מעיקר הדין יוצאים אבל מבואר בשולחן ערוך שיש לעשות את שניהם",
              passage='2. מעיקר הדין יוצאים אבל מבואר בשולחן ערוך שיש לעשות את שניהם. בפסוקים שאין רש"י יש לחזור על הפסוק שלושה פעמים.'),
            R("hid", "262007", passage='והסביר המשנה ברורה (סק"ו) כי התרגום יש לו מעלה שניתן בסיני וגם הוא מפרש כל מילה ומילה. ופירוש רש"י יש לו מעלה שהוא מפרש את העניין על פי מדרשי חז"ל יותר מהתרגום.'),
        ],
            "Celui qui a étudié la paracha avec le commentaire de Rachi est considéré comme ayant lu le targoum ; mais celui qui craint le Ciel lit le targoum et aussi Rachi (Choul'han Aroukh). Le Rav Binyamin Chmouéli (Hidabroot) le résume ainsi : on est quitte selon le strict droit, mais le Choul'han Aroukh demande les deux ; et un verset que Rachi ne commente pas se lit trois fois. Le Rav Hillel Meirs (Hidabroot) explique, avec la Michna Beroura, que le targoum a la qualité d'avoir été donné au Sinaï et de traduire chaque mot, et Rachi celle d'expliquer le sujet selon les midrachim des Sages.",
            "One who studied the parasha with Rashi’s commentary is considered to have read the targum; but one who fears Heaven reads the targum and Rashi as well (Shulchan Aruch). Rav Binyamin Shmueli (Hidabroot) sums it up: by strict law one fulfils the obligation, but the Shulchan Aruch calls for both; and a verse on which Rashi does not comment is read three times. Rav Hillel Meirs (Hidabroot) explains, with the Mishnah Berurah, that the targum has the merit of having been given at Sinai and of translating every word, and Rashi that of explaining the matter according to the midrashim of the Sages."),
        H("ashkenaze", [
            R("mb", 4, cite='אבל אם קראה בשאר לעז שהוא מפרש רק את המלות לחוד לא יצא י"ח במקום תרגום לפי שהתרגום מפרש כמה דברים שאין להבין מתוך המקרא'),
            R("mb", 5, cite='ואותן פסוקים שאין עליהם פירש"י יקרא אותן ג"פ. מי שאינו בר הכי שיבין את פירש"י ראוי לקרות בפירוש התורה שיש בלשון אשכנז בזמנינו כגון ספר צאינה וראינה וכיוצא בו המבארים את הפרשה ע"פ פירש"י ושאר חכמינו ז"ל הבנוים על יסוד התלמוד'),
            R("mb", 6, cite='ובאמת כן ראוי לנהוג לכל אדם שילמוד בכל שבוע הסדרה עם פירש"י לבד התרגום'),
            R("ksa", 11, cite='גַּם יֵשׁ לוֹ לְכָל יְרֵא שָׁמַיִם, לִלְמוֹד פֵּרוּשׁ רַשִׁ"י עַל הַסִּדְרָה, וְאִם לָאו בַּר הָכִי הוּא יִלְמַד פֵּרוּשׁ אַשְׁכְּנַזִי (לוֹעֲזִי) עַל הַסִּדְרָה, כְּגוֹן סֵפֶר "צְאֶינָה וּרְאֶינָה" וְכַדּוֹמֶה, שֶׁיָּבִין עִנְיַן הַסִּדְרָה'),
            R("sahr", 2, cite='ומכל מקום כל ירא שמים יש לו לקרות התרגום וגם פירוש רש"י ומי שאינו מבין פירוש רש"י יש לו לקרות בפירוש התורה שבלשון לע"ז שמבין'),
        ],
            "Rachi tient lieu de targoum parce qu'il explique le texte comme le targoum, et davantage ; en revanche, une traduction dans une autre langue qui ne rend que les mots ne remplace pas le targoum, car le targoum explique des choses que le texte seul ne laisse pas comprendre. Celui qui lit Rachi à la place du targoum lit trois fois les versets que Rachi ne commente pas. La Michna Beroura écrit qu'il convient en vérité que chacun étudie chaque semaine la paracha avec Rachi, en plus du targoum ; celui qui ne peut pas comprendre Rachi lira un commentaire de la Torah dans une langue qu'il comprend, qui explique la paracha selon Rachi et les Sages – la Michna Beroura et le Kitsour Choul'han Aroukh donnent en exemple le Tseéna ourééna, en yiddish ; de même le Choul'han Aroukh haRav. Le Choul'han Aroukh haRav tient Rachi pour plus utile que le targoum, et dit lui aussi que celui qui craint le Ciel lit les deux.",
            "Rashi takes the place of the targum because he explains the text as the targum does, and more; but a translation into another language that renders only the words does not replace the targum, since the targum explains things that cannot be understood from the text alone. One who reads Rashi instead of the targum reads three times the verses on which Rashi does not comment. The Mishnah Berurah writes that it is truly fitting for everyone to study the parasha each week with Rashi, besides the targum; one who cannot understand Rashi should read a commentary on the Torah in a language he understands, explaining the parasha according to Rashi and the Sages – the Mishnah Berurah and the Kitzur Shulchan Aruch give the Yiddish Tze’enah U-re’enah as an example; likewise the Shulchan Aruch HaRav. The Shulchan Aruch HaRav considers Rashi more useful than the targum, and also says that one who fears Heaven reads both."),
        H("sefarade", [
            R("kyy", 3, cite="אף מי שאינו מבין כל כך את שפת התרגום, עליו לקרוא את הפרשה שנים מקרא ואחד תרגום. וירא שמים יקרא גם תרגום וגם פירוש רש״י על הפרשה"),
            R("kh", 22, cite='אבל לפי מ"ש חכמי האמת יש קפידא בתרגום ולכן אם אין לו שהות ללמוד שניהם ילמוד תרגום'),
            R("kh", 22, cite='ומיהו אם הולך בדרך ואין לו כ"א מקרא ורש"י אז יש לסמוך על המתירין ויקרא ב"פ מקרא ואחד פרש"י'),
            R("kav", "yaron1", passage='אף מי שאינו מבין כל כך את שפת התרגום, עליו לקרוא את הפרשה שנים מקרא ואחד תרגום. וירא שמים יקרא גם תרגום וגם פירוש רש"י על הפרשה.'),
        ],
            "Même celui qui ne comprend pas bien la langue du targoum doit lire la paracha deux fois avec le targoum, et celui qui craint le Ciel lit aussi Rachi (Kitsour Yalkout Yossef ; de même le Rav Yaron Achkenazi, Kav haHalakha haSefaradi). Celui qui n'a pas le temps d'étudier les deux étudie le targoum, auquel les kabbalistes tiennent ; mais en voyage, s'il n'a que le texte et Rachi, il peut s'appuyer sur ceux qui permettent de lire deux fois le texte et une fois Rachi (Kaf ha'Haïm).",
            "Even one who does not understand the language of the targum well must read the parasha twice with the targum, and one who fears Heaven reads Rashi as well (Kitzur Yalkut Yosef; likewise Rav Yaron Ashkenazi, Kav HaHalacha HaSefaradi). One who has no time to study both studies the targum, to which the kabbalists attach importance; but when travelling, if he has only the text and Rashi, he may rely on those who allow reading the text twice and Rashi once (Kaf HaChaim)."),
        H("tous", [
            R("mb", 6, cite='מי שאין בידו תרגום רק החומש לבד יש לו יקרא שני פעמים מקרא ואח"כ כשיזדמן לו תרגום יאמר'),
            R("ksa", 11, cite="וּמִי שֶׁהוּא בַּדֶּרֶךְ וְאֵין לוֹ רַק חֻמָּשׁ בְּלִי תַּרְגּוּם, יִקְרָא שְׁתֵּי פְּעָמִים מִקְרָא. וּכְשֶׁיָּבוֹא לְמָקוֹם שֶׁיִּהְיֶה לוֹ תַּרְגּוּם, יִקְרָא הַתַּרְגּוּם"),
            R("sahr", 6, cite="ואם אין לו תרגום יקרא מקרא ב' פעמים ואח\"כ כשיהיה לו תרגום יקראנו"),
            R("kh", 16, cite='ול"נ דכדי להשלים פרשיותיו עם הצבור יש לקרות ג"פ מקרא כמו הפסוקים שאין להם תרגום כיון דלא אפשר ליה בענין אחר ואח"כ כשיגיע לישוב אם אפשר חוזר לקרות שמו"ת'),
        ],
            "En voyage, celui qui n'a qu'un 'Houmach sans targoum lit le texte deux fois, puis le targoum quand il en trouve un (Michna Beroura ; Kitsour Choul'han Aroukh ; Choul'han Aroukh haRav). Le Kaf ha'Haïm propose, pour achever malgré tout la paracha avec la communauté, de lire alors le texte trois fois, comme un verset sans targoum, puis, une fois arrivé, de relire si possible Chnayim mikra véé'had targoum.",
            "When travelling, one who has only a Chumash without targum reads the text twice, and the targum when he finds one (Mishnah Berurah; Kitzur Shulchan Aruch; Shulchan Aruch HaRav). The Kaf HaChaim suggests that, in order to complete the parasha with the congregation all the same, he should then read the text three times, like a verse without targum, and once he arrives, read Shnayim mikra ve-echad targum again if possible."),
    ]},
    {"titre": "טעמים, ספר תורה וחומש", "titre_fr": "Te'amim, séfer Torah, 'Houmach", "titre_en": "Cantillation, Torah scroll, Chumash", "halakhot": [
        H("tous", [
            R("kyy", 14, cite="אולם גם מי שאינו יודע לקרוא את הפרשה עם הטעמים, חייב בקריאת הפרשה שנים מקרא ואחד תרגום. וחובה קדושה על ההורים והמלמדים ללמד את בני ישראל בטעמי המקרא"),
            R("mb", 17, cite='מכאן שניגון הטעמים אינו מעכב לגבי שמו"ת'),
            R("hid", "15385", cite="ולכתחילה יש לקראה בטעמיה, אבל מי שאינו בקי בטעמים יקראנה ללא טעמים"),
        ],
            "On lit les versets avec la cantillation (te'amim) ; mais celui qui ne la connaît pas reste obligé de lire Chnayim mikra, et la mélodie des te'amim n'est pas indispensable (Kitsour Yalkout Yossef ; Michna Beroura, d'après le Pri Megadim). Le Kitsour Yalkout Yossef ajoute que parents et maîtres ont le devoir sacré d'enseigner les te'amim aux enfants. Le Rav Binyamin Chmouéli (Hidabroot) répond de même : a priori avec les te'amim, et sans eux pour qui ne les connaît pas.",
            "The verses are read with the cantillation (te’amim); but one who does not know it is still obligated to read Shnayim mikra, and the melody of the te’amim is not indispensable (Kitzur Yalkut Yosef; Mishnah Berurah, after the Pri Megadim). The Kitzur Yalkut Yosef adds that parents and teachers have a sacred duty to teach children the te’amim. Rav Binyamin Shmueli (Hidabroot) answers likewise: ideally with the te’amim, and without them for one who does not know them."),
        H("sefarade", [
            R("kyy", 14, cite="פסוקי המקרא צריך לקוראם בטעמי המקרא, והתרגום בלי טעמים, בדוקא"),
            R("bih", (2, "Lech Lecha", "Lekh Lekha", "Lech Lecha", "לך לך", 11), cite="ואין קוראים התרגום בטעמים, כנזכר בשער טעמי המצוות"),
            R("kh", 12, cite='התרגום א"צ לקרות בטעמים. כ"כ רבינו מהרח"ו ז"ל שקבל מרבינו האר"י ז"ל'),
            R("kh", 12, cite="ושם מפורש דהתרגום צריך לקרותו בלא טעמים דוקא ויש קפידא בזה"),
        ],
            "Le targoum se lit sans les te'amim : le Kitsour Yalkout Yossef écrit que c'est « précisément » ainsi, le Ben Ich 'Haï le rapporte d'après le Cha'ar Ta'amei haMitsvot, et le Kaf ha'Haïm le tient de Rabbi 'Haïm Vital, qui l'avait reçu du Ari, et cite le Korban Chabbat : on y tient.",
            "The targum is read without the te’amim: the Kitzur Yalkut Yosef writes that this is “precisely” so, the Ben Ish Chai reports it from the Shaar Taamei HaMitzvot, and the Kaf HaChaim has it from Rabbi Chaim Vital, who received it from the Ari, and cites the Korban Shabbat: it is insisted upon."),
        H("tous", [
            R("mb", 2, cite='מי שהוא בקי בטעם ובנקודות בע"פ טוב להדר לקרות בס"ת גופא'),
            R("sahr", 4, cite="מי שהוא רגיל בפסקי טעמים בעל פה טוב שיקרא שנים מקרא בספר תורה כשר"),
            R("kyy", 17, cite="מי שבקי בקריאת הפרשה בטעמי המקרא והנקודות כראוי, מצוה מן המובחר לקרוא שנים מקרא מתוך ספר תורה, ויקרא התרגום מתוך החומש"),
            R("kyy", 17, cite="אולם אם אינו בקי מוטב שיקראנה מתוך חומש שיש בו הטעמים והנקודות, ולא יקראנה קריאה משובשת בספר תורה. ופשוט שאין לו לברך על קריאתה"),
            R("kh", 7, cite='ואם אינו בקי יותר טוב שיקרא בחומש שמו"ת ממה שיקרא בס"ת קריאה משובשת'),
            R("kh", 7, cite='ואף אם הוא בקי וקורא בס"ת אין לברך בה"ת שלא נתקנה אלא בצבור'),
            R("malka", "484", cite="זה נקרא כלומד מספר לענין זה",
              passage='2) כהמשך לשאלה הקודמת האם מותר ללמוד במכשיר תורה שבכתב ולהעביר שניים מקרא ואחד תרגום? [...] לגבי 1 ו 2 אין כ"כ נ"מ בשאלות הנ"ל. אבל אם חשוב לך - זה נקרא כלומד מספר לענין זה.'),
        ],
            "Celui qui connaît par cœur la vocalisation et les te'amim fait bien de lire le texte dans un séfer Torah (Michna Beroura ; Choul'han Aroukh haRav), le targoum se lisant alors dans un 'Houmach (Kitsour Yalkout Yossef). Celui qui ne les connaît pas lit plutôt dans un 'Houmach vocalisé, avec les te'amim, que de lire de façon fautive dans le séfer Torah ; et l'on ne récite pas de bénédiction sur cette lecture (Kitsour Yalkout Yossef ; Kaf ha'Haïm). À la question de lire Chnayim mikra sur un appareil électronique, le Rav Emmanuel Molkandov (beit hora'a « Halakha lema'assé » du Rav Ofir Malka) répond que la question a peu de conséquence pratique, mais que, si l'on y tient, cela compte comme lire dans un livre.",
            "One who knows the vowels and te’amim by heart does well to read the text from a Torah scroll (Mishnah Berurah; Shulchan Aruch HaRav), the targum then being read from a Chumash (Kitzur Yalkut Yosef). One who does not know them should rather read from a Chumash with vowels and te’amim than read wrongly from the Torah scroll; and no blessing is said over this reading (Kitzur Yalkut Yosef; Kaf HaChaim). Asked about reading Shnayim mikra on an electronic device, Rav Emmanuel Molkandov (the “Halacha LeMaaseh” beit hora’ah of Rav Ofir Malka) answers that the question has little practical consequence, but that, if it matters to the asker, it counts as reading from a book."),
    ]},
    {"titre": "קריאת הציבור", "titre_fr": "La lecture à la synagogue", "titre_en": "The public reading", "halakhot": [
        H("ashkenaze", [
            R("mb", 2, cite='אבל לא יקרא אחד מקרא ואחד תרגום ויכוין לשמוע מהש"ץ אלא צריך לקרות ב"פ מקרא חוץ ממה ששמע מהש"ץ אם לא שקרא אז ג"כ בפיו'),
            R("sahr", 8, cite="ויש אומרים שיוצא ידי חובתו בשמיעת הקריאה מהש\"ץ אם שמע כל הפרשה בבירור ודי שיקרא עוד פעם אחת עם תרגום"),
            R("sahr", 8, cite="ובשעת הדחק יש לסמוך על סברא הראשונה"),
            R("hid", "262007", cite="אם הוא קורא בפיו עם הבעל קורא זה עולה לו"),
        ],
            "On ne se contente pas de lire une fois le texte et le targoum en comptant sur la lecture entendue de l'officiant : il faut lire soi-même deux fois le texte, en plus de ce qu'on a entendu, à moins d'avoir lu alors avec lui, de sa propre bouche. A posteriori, selon le Maguen Avraham au nom du Le'hem 'Hamoudot, l'écoute compte pour une fois ; d'autres A'haronim sont stricts même a posteriori (Michna Beroura). Le Choul'han Aroukh haRav rapporte ces avis et permet, en cas de nécessité, de s'appuyer sur l'avis selon lequel celui qui a bien entendu toute la paracha n'a plus qu'à la lire une fois avec le targoum. Le Rav Hillel Meirs (Hidabroot) répond, avec la Michna Beroura, que lire de sa bouche avec le lecteur compte pour une fois.",
            "One may not read the text once with the targum and rely on hearing the reader: one must read the text twice oneself, besides what one heard, unless one read along with him at the time, with one’s own mouth. After the fact, according to the Magen Avraham citing the Lechem Chamudot, hearing counts as one reading; other Acharonim are strict even after the fact (Mishnah Berurah). The Shulchan Aruch HaRav reports these views and, in case of need, allows relying on the view that one who heard the whole parasha clearly need only read it once more with the targum. Rav Hillel Meirs (Hidabroot) answers, with the Mishnah Berurah, that reading along with one’s mouth with the reader counts as one reading."),
        H("sefarade", [
            R("kyy", 10, cite="נכון להורות לו שיקרא בלחש את כל הפרשה עם השליח צבור הקורא בתורה, פסוק בפסוק, ושוב יחזור ויקראנה פעם שניה בביתו, ואחר כך יקרא פעם אחת את כל התרגום, ויצא ידי חובתו"),
            R("kyy", 10, cite="וכן השליח צבור הקורא בתורה, רשאי לקרות הפרשה בהכנתה לפחות פעם אחת מתחלתה ועד סופה, ופעם שניה כשקורא אותה בצבור, ואחר כך יקרא התרגום של כל הפרשה פעם אחת ויוצא ידי חובה"),
            R("kyy", 10, cite="אבל אין לסמוך על מה ששומע קריאת הפרשה מהשליח צבור"),
        ],
            "On ne s'appuie pas sur la lecture entendue de l'officiant. Mais celui qui est vraiment pressé et n'a pas le temps de lire seul la paracha lit à voix basse toute la paracha avec l'officiant, verset par verset, puis la relit une seconde fois chez lui, puis lit une fois tout le targoum : il est quitte. De même, l'officiant qui lit la Torah en public peut compter sa préparation, au moins une lecture complète, et sa lecture publique, puis lire une fois le targoum.",
            "One does not rely on hearing the reader. But one who is truly pressed and has no time to read the parasha by himself reads the whole parasha in a whisper with the reader, verse by verse, then reads it a second time at home, then reads the whole targum once: he has fulfilled his obligation. Likewise, the reader who reads the Torah in public may count his preparation, at least one complete reading, and his public reading, then read the targum once."),
        H("ashkenaze", [
            R("sa", 5, cite="יכול לקרות הפרשה שנים מקרא ואחד תרגום בשעת קריאת התורה"),
            R("mb", 14, cite='הביא בשם השל"ה שמחמיר בזה אלא הכל צריכין לשמוע הקריאה מפי הש"ץ וכן הוא דעת הגר"א'),
            R("mb", 14, cite='ומ"מ נראה דלקרוא בלחש מלה במלה עם הש"ץ אין להחמיר בזה כיון שמכוין אז גם לשמוע כל תיבה מפי הש"ץ'),
        ],
            "Le Choul'han Aroukh permet de lire Chnayim mikra pendant la lecture publique de la Torah. La Michna Beroura rapporte que le Chla et le Gaon de Vilna sont stricts : chacun doit écouter la lecture de la bouche du lecteur, chaque mot, en suivant dans un 'Houmach ; mais lire à voix basse, mot à mot, avec le lecteur, en écoutant chaque mot, n'est pas à proscrire, et plusieurs A'haronim le recommandent.",
            "The Shulchan Aruch allows reading Shnayim mikra during the public Torah reading. The Mishnah Berurah reports that the Shelah and the Vilna Gaon are strict: everyone must hear the reading from the reader’s mouth, every word, following in a Chumash; but reading in a whisper, word for word, with the reader, while listening to every word, need not be avoided, and several Acharonim recommend it."),
        H("sefarade", [
            R("kh", 31, cite='ובקשל"ה דף פ"א ע"ב כתב דהעושים כן לא יפה עושין כי מן הראוי לשמוע מן הש"ץ'),
            R("kh", 31, cite='והכי נקטינן ודלא כמ"ש בב"י ובד"מ. יפ"ל או\' ז\''),
            R("kyy", 11, cite="אם השליח צבור מאריך בטעמים בקריאתו בתורה באופן שיכול היחיד להספיק לקרוא אז שנים מקרא ואחד תרגום, בעת קריאת התורה, רשאי לעשות כן, ויוצא ידי חובה"),
            R("kyy", 11, cite="ומכל מקום הנכון הוא שבכל הפרשיות ראוי למדקדק בדרכיו לכוין דעתו ולשמוע קריאת התורה מפי השליח צבור"),
        ],
            "Le Kaf ha'Haïm cite le Chla : ceux qui lisent Chnayim mikra pendant la lecture publique n'agissent pas bien, car il faut écouter l'officiant ; et il cite le Yafé laLev : « c'est ainsi que nous tenons », contre le Beit Yossef et le Darkhei Moché. Le Kitsour Yalkout Yossef permet, si l'officiant s'attarde sur les te'amim au point qu'on ait le temps de lire Chnayim mikra pendant la lecture, de le faire et d'être quitte – sauf pour Zakhor et Para, qu'il faut écouter –, à condition de lire à voix basse et que dix autres écoutent, ou de s'être tourné de côté avant le début de la lecture ; il conclut cependant que celui qui est scrupuleux écoute, dans toutes les parachiot, la lecture de l'officiant.",
            "The Kaf HaChaim cites the Shelah: those who read Shnayim mikra during the public reading do not act well, since one should listen to the reader; and he cites the Yafeh LaLev: “this is how we hold”, against the Beit Yosef and the Darkei Moshe. The Kitzur Yalkut Yosef allows it, if the reader lingers over the te’amim so that one has time to read Shnayim mikra during the reading, and one fulfils the obligation – except for Zachor and Parah, which must be heard – provided one reads in a whisper and ten others are listening, or one turned aside before the reading began; he concludes, however, that a careful person listens to the reader in all the parashiyot."),
    ]},
    {"titre": "הפטרה וימים טובים", "titre_fr": "Haftara et fêtes", "titre_en": "Haftarah and festivals", "halakhot": [
        H("tous", [
            R("rema", 7, cite="וכן אין צריך לקרות ההפטרות (מרדכי ה\"ק) ומכל מקום נהגו לקרות ההפטרה"),
            R("mb", 19, cite="טעם המנהג שמא יקראוהו למחר למפטיר ויהא בקי ורגיל בה"),
            R("ksa", 11, cite="וְנוֹהֲגִין לִקְרוֹת גַּם הַהַפְטָרָה"),
            R("kyy", 2, cite="הקורא את הפרשה שנים מקרא ואחד תרגום, מן הדין אין צריך לקרוא את ההפטרה. ומכל מקום נהגו לקרוא גם את ההפטרה [פעם אחת]"),
            R("kav", "yaron1", passage="הקורא את הפרשה שנים מקרא ואחד תרגום, מן הדין אינו צריך לקרוא את ההפטרה. ומכל מקום נהגו לקרוא גם את ההפטרה [פעם אחת]."),
        ],
            "Selon la loi, celui qui lit Chnayim mikra n'a pas à lire la haftara ; mais l'usage est de la lire (Rema ; Kitsour Choul'han Aroukh), une fois (Kitsour Yalkout Yossef ; Rav Yaron Achkenazi, Kav haHalakha haSefaradi). La Michna Beroura en donne la raison, d'après le Maguen Avraham : on pourrait être appelé le lendemain pour la lire comme maftir, et il faut la connaître.",
            "By law, one who reads Shnayim mikra need not read the haftarah; but the custom is to read it (Rema; Kitzur Shulchan Aruch), once (Kitzur Yalkut Yosef; Rav Yaron Ashkenazi, Kav HaHalacha HaSefaradi). The Mishnah Berurah gives the reason, after the Magen Avraham: one might be called up the next day to read it as maftir, and should know it."),
        H("sefarade", [
            R("bih", (2, "Lech Lecha", "Lekh Lekha", "Lech Lecha", "לך לך", 11), cite='ואם חל שבת בראש חודש, או "שקלים" ו"זכור" ו"פרה" ו"החודש", צריך לומר ההפטרה של שנים מקרא ואחד תרגום, הפטרת השבוע הן אם קורא השנים מקרא ואחד תרגום ביום ששי, הן אם קוראה ביום שבת עצמו'),
            R("kh", 36, cite='ואני נוהג בשבת שיש הפטרה מחודשת כגון הפטרת שבת של ר"ח או שבת שלפני ר"ח או של חנוכה ושל ד\' פרשיות לחזור עם הפרשה הפטרת השבוע וביום שבת לקרוא המחודשת עם המפטיר'),
            R("kh", 36, cite="וכן עמא דבר"),
        ],
            "Quand le Chabbat tombe à Roch 'Hodech, ou que c'est Chabbat Chekalim, Zakhor, Para ou Ha'Hodech, la haftara que l'on lit avec Chnayim mikra est celle de la paracha de la semaine, qu'on lise le vendredi ou le Chabbat même (Ben Ich 'Haï). Le Kaf ha'Haïm, citant la Knesset haGuedola, l'étend au Chabbat veille de Roch 'Hodech et à celui de 'Hanouka – la haftara propre au jour, on la lit le Chabbat avec le maftir – et conclut : « et tel est l'usage ».",
            "When Shabbat falls on Rosh Chodesh, or it is Shabbat Shekalim, Zachor, Parah or HaChodesh, the haftarah read with Shnayim mikra is that of the weekly parasha, whether one reads on Friday or on Shabbat itself (Ben Ish Chai). The Kaf HaChaim, citing the Knesset HaGedolah, extends this to the Shabbat before Rosh Chodesh and to Shabbat Chanukah – the special haftarah is read on Shabbat along with the maftir – and concludes: “and this is the custom”."),
        H("ashkenaze", [
            R("mb", 20, cite="ובד' פרשיות יקרא הפטרה דד' פרשיות"),
            R("sahr", 10, cite="ובד' פרשיות יש לו לקרות הפטרה של ד' פרשיות שמפטירין אותה בבית הכנסת ולא הפטרה של פרשת השבוע וכן בשבת ראש חודש ומחר חדש ושבת חנוכה"),
        ],
            "Pour les quatre parachiot (Chekalim, Zakhor, Para, Ha'Hodech), on lit la haftara des quatre parachiot (Michna Beroura). Le Choul'han Aroukh haRav précise : celle qu'on lira à la synagogue, et non celle de la paracha de la semaine ; de même pour Chabbat Roch 'Hodech, la veille de Roch 'Hodech (Ma'har 'Hodech) et Chabbat 'Hanouka.",
            "For the four parashiyot (Shekalim, Zachor, Parah, HaChodesh), one reads the haftarah of the four parashiyot (Mishnah Berurah). The Shulchan Aruch HaRav specifies: the one that will be read in the synagogue, and not that of the weekly parasha; likewise on Shabbat Rosh Chodesh, the day before Rosh Chodesh (Machar Chodesh) and Shabbat Chanukah."),
        H("tous", [
            R("sa", 7, cite='אין צריך לקרות פרשת יו"ט'),
            R("mb", 18, cite="ר\"ל שאין צריך לקרות לעצמו שמו\"ת דהא כבר קרא כל התורה מדי שבת בשבתו"),
            R("kyy", 13, cite="אין צריך לקרוא את הפרשה שנים מקרא ואחד תרגום בימים טובים"),
            R("sahr", 9, cite="אין צריך לקרות פרשת יו\"ט לעצמו בערב יו\"ט שהרי כבר קרא או יקרא פרשה זו בשבתה"),
            R("kh", 35, cite='וה"ה פרשת של חו"ה א"צ להשלים. כנה"ג בהגב"י. וכללא נקטינן בכל מקום שקוראין מה שכבר קראו בסדר הפרשיות א"צ לחזור ולקרות'),
        ],
            "On n'a pas à lire Chnayim mikra pour la lecture de Yom Tov, puisqu'on lit de toute façon toute la Torah, Chabbat après Chabbat (Choul'han Aroukh ; Michna Beroura ; Kitsour Yalkout Yossef ; Choul'han Aroukh haRav). Le Kaf ha'Haïm ajoute qu'il en va de même pour la lecture de 'Hol haMoed : partout où l'on lit ce qui a déjà été lu dans l'ordre des parachiot, on n'a pas à le relire.",
            "One need not read Shnayim mikra for the Yom Tov reading, since one reads the whole Torah in any case, Shabbat after Shabbat (Shulchan Aruch; Mishnah Berurah; Kitzur Yalkut Yosef; Shulchan Aruch HaRav). The Kaf HaChaim adds that the same holds for the Chol HaMoed reading: wherever what is read was already read in the order of the parashiyot, one need not read it again."),
        H("tous", [
            R("mb", 18, cite='וביום הו"ר יקרא שמו"ת פרשת וזאת הברכה ואם קרא ביום שמ"ע לא הפסיד'),
            R("kh", 29, cite='ביום הו"ר יקרא פ\' וזאת הברכה שמו"ת'),
            R("sahr", 9, cite="ומכל מקום בערב שמחת תורה יקרא פרשת וזאת הברכה שנים מקרא ואחד תרגום שעכשיו הוא זמנה"),
            R("bih", (1, "V'Zot HaBerachah", "Vezot haBerakha", "VeZot HaBerachah", "וזאת הברכה", 15), cite='שנים מקרא ואחד תרגום של פרשת וזאת הברכה יקראנה ביום הו"ר ולא ביום ש"ע מפני התרגום, ואם שכח ולא קראה ביום הו"ר יקראנה ביום ש"ע אחר מנחה'),
            R("kyy", 19, cite="פרשת ״וזאת הברכה״ יש לקרוא שנים מקרא ואחד תרגום ביום הושענא רבה, ואם שכח לקרוא בהושענא רבה, יקרא בשמיני עצרת קודם שחרית, או יחד עם השליח צבור"),
            R("kyy", 9, cite="וכן מותר לקרוא פרשת וזאת הברכה בליל שמחת תורה"),
            R("malka", "142", cite='אפשר, אך יותר טוב לקרא כל פסוק שמו"ת',
              passage='האם אפשר לכתחילה להחשיב פרשת וזאת הברכה שקורים בתוך התיקון לאחד מקרא ? [...] אפשר, אך יותר טוב לקרא כל פסוק שמו"ת כמש"כ כה"ח בסימן רפה\' ע"פ האר"י, וכ"ה בברכ"י. ותו דיותר נכון לקרא שמו"ת ביום ולא בלילה, כמש"כ מחב"ר וכה"ח הנ"ל.'),
        ],
            "La paracha Vezot haBerakha se lit en Chnayim mikra le jour de Hochaana Rabba (Michna Beroura ; Kaf ha'Haïm ; Ben Ich 'Haï ; Kitsour Yalkout Yossef) ; le Choul'han Aroukh haRav dit : la veille de Sim'hat Torah, qui est son moment. Celui qui l'a lue le jour de Chemini Atseret n'a rien perdu (Michna Beroura). Le Ben Ich 'Haï veut qu'on ne la lise pas le jour de Chemini Atseret, à cause du targoum, et, si l'on a oublié, qu'on la lise ce jour-là après Min'ha ; le Kitsour Yalkout Yossef dit de la lire alors à Chemini Atseret avant Cha'harit, ou avec l'officiant, et permet à qui manque de temps de la lire la nuit de Sim'hat Torah. Le Rav Menaché Moreno (beit hora'a « Halakha lema'assé » du Rav Ofir Malka) répond que la lecture de Vezot haBerakha faite dans le Tikoun peut compter pour l'une des deux lectures du texte, mais qu'il vaut mieux lire chaque verset en Chnayim mikra, et de jour plutôt que de nuit.",
            "The parasha Vezot HaBerachah is read as Shnayim mikra on the day of Hoshana Rabbah (Mishnah Berurah; Kaf HaChaim; Ben Ish Chai; Kitzur Yalkut Yosef); the Shulchan Aruch HaRav says: on the eve of Simchat Torah, which is its time. One who read it on the day of Shemini Atzeret has lost nothing (Mishnah Berurah). The Ben Ish Chai wants it not read on the day of Shemini Atzeret, because of the targum, and, if one forgot, read that day after Minchah; the Kitzur Yalkut Yosef says to read it then on Shemini Atzeret before Shacharit, or with the reader, and allows one who is short of time to read it on the night of Simchat Torah. Rav Menashe Moreno (the “Halacha LeMaaseh” beit hora’ah of Rav Ofir Malka) answers that reading Vezot HaBerachah in the Tikkun may count as one of the two readings of the text, but that it is better to read each verse as Shnayim mikra, and by day rather than by night."),
    ]},
]

INTRO = {
    "t": ("<b>מבוא</b> הלכות שנים מקרא ואחד תרגום, מלוקטות מן הפוסקים: כל הלכה עם מקורה ובלשונו. "
          "<small>[ספרדים – עדות המזרח]</small> – לבני עדות המזרח; <small>[אשכנזים – נוסח אשכנז ונוסח ספרד]</small> – לנוסח אשכנז ולנוסח ספרד; "
          "הלכה בלי ציון – לכל העדות. אין כאן הכרעה: כל שאלה למעשה תישאל לרב."
          "<br><small>מקורות: שולחן ערוך עם הגהות הרמ״א (מגיני ארץ, למברג תרנ״ג), משנה ברורה, קיצור שולחן ערוך (תורת אמת), "
          "כף החיים (ירושלים תר״ע–תרצ״ג), בן איש חי (ויקיטקסט), רמב״ם (תורת אמת) – נחלת הכלל, דרך ספריא; "
          "שולחן ערוך הרב – הוצאת קה״ת (Kehot Publication Society), CC BY-NC, דרך ספריא; "
          "ילקוט יוסף – קיצור שולחן ערוך, מאת הרב יצחק יוסף שליט״א, מהדורת התשס״ז, הוכן מתוכנת תורת אמת (CC BY-NC-SA 2.5); "
          "תשובות הידברות, קו ההלכה הספרדי ובית ההוראה ״הלכה למעשה״ של הרב אופיר מלכא – בתמצית ובציון מקומן, לא בהעתקה.</small>"),
    "fr": ("<b>Introduction</b> Les lois de Chnayim mikra véé'had targoum – lire chaque semaine la paracha deux fois dans le texte hébreu et une fois dans la traduction araméenne d'Onkelos –, réunies d'après les décisionnaires : chaque halakha cite sa source en hébreu. "
           "<small>[Séfarades – rite Edot]</small> : pour qui suit les décisionnaires séfarades ; <small>[Ashkénazes – rites Ashkenaz et Sfard]</small> : pour les rites Ashkenaz et Sfard ; sans indication : pour tous. "
           "Ce recueil ne tranche rien : pour une question pratique, on interroge un rav."
           "<br><small>Sources : Choul'han Aroukh avec les gloses du Rema (Maginei Eretz, Lemberg 1893), Michna Beroura, Kitsour Choul'han Aroukh (Torat Emet), Kaf ha'Haïm (Jérusalem 1910-1933), Ben Ich 'Haï (Wikisource), Rambam (Torat Emet) : domaine public, via Sefaria. "
           "Choul'han Aroukh haRav : Kehot Publication Society, CC BY-NC, via Sefaria. "
           "Kitsour Choul'han Aroukh Yalkout Yossef, du Rav Yitzhak Yosef : édition 5767, Torat Emet, CC BY-NC-SA 2.5. "
           "Réponses de Hidabroot, de Kav haHalakha haSefaradi et du beit hora'a « Halakha lema'assé » du Rav Ofir Malka : résumées et référencées, non reproduites. "
           "Français et anglais rédigés par ordinateur d'après les sources, non relus : l'hébreu fait foi.</small>"),
    "en": ("<b>Introduction</b> The laws of Shnayim mikra ve-echad targum – reading the weekly parasha twice in the Hebrew text and once in Onkelos’ Aramaic translation –, gathered from the halachic authorities: each law quotes its source in Hebrew. "
           "<small>[Sephardim – Edot rite]</small>: for those who follow the Sephardi authorities; <small>[Ashkenazim – Ashkenaz and Sfard rites]</small>: for the Ashkenaz and Sfard rites; unmarked: for everyone. "
           "This collection decides nothing: for a practical question, ask a rabbi."
           "<br><small>Sources: Shulchan Aruch with the Rema’s glosses (Maginei Eretz, Lemberg 1893), Mishnah Berurah, Kitzur Shulchan Aruch (Torat Emet), Kaf HaChaim (Jerusalem 1910-1933), Ben Ish Chai (Wikisource), Rambam (Torat Emet): public domain, via Sefaria. "
           "Shulchan Aruch HaRav: Kehot Publication Society, CC BY-NC, via Sefaria. "
           "Kitzur Shulchan Aruch Yalkut Yosef, by Rav Yitzchak Yosef: 5767 edition, Torat Emet, CC BY-NC-SA 2.5. "
           "Answers from Hidabroot, Kav HaHalacha HaSefaradi and Rav Ofir Malka’s “Halacha LeMaaseh” beit hora’ah: summarised with references, not reproduced. "
           "French and English written by computer from the sources, unreviewed: the Hebrew prevails.</small>"),
}

TITRE = {"he": "הלכות שנים מקרא ואחד תרגום", "fr": "Chnayim mikra : les halakhot", "en": "Shnayim mikra: the laws"}

SOURCES_META = [
    "Choul'han Aroukh O.H. 285 et Rema — Maginei Eretz, Lemberg 1893 (via API Sefaria), Public Domain",
    "Michna Beroura 285 — On Your Way (via API Sefaria), Public Domain",
    "Kaf ha'Haïm O.H. 285 — Jérusalem 1910-1933 (via API Sefaria), Public Domain",
    "Kitsour Choul'han Aroukh 72 — Torat Emet 357 (via API Sefaria), Public Domain",
    "Ben Ich 'Haï — Wikisource (via API Sefaria), Public Domain",
    "Rambam, Hilkhot Tefila 13:25 — Torat Emet 370 (via API Sefaria), Public Domain",
    "Choul'han Aroukh haRav O.H. 285 — Kehot Publication Society (via API Sefaria), CC-BY-NC : courtes citations sans vocalisation, créditées en tête du livre",
    "Kitsour Yalkout Yossef 285 — même édition que le livre de l'application (Torat Emet, CC BY-NC-SA 2.5, licence reçue par le propriétaire)",
    "réponses de Hidabroot, Kav haHalakha haSefaradi et du beit hora'a Halakha lema'assé (Rav Ofir Malka) — résumées avec leur référence, non reproduites (une courte phrase citée au plus) ; table de vérification : tools/chnayim_mikra/sources.json",
]


def blocs_halakha(n, h):
    """Le paragraphe affiché : hébreu (citations et références), français, anglais."""
    lignes = []
    for r in h["refs"]:
        ref = ref_texte(r, "he")
        if r["cite"]:
            lignes.append(f"{r['cite']} <small>({ref})</small>")
        elif r["src"] in ("hid", "kav", "malka"):
            lignes.append(f"<small>({ref})</small>")
        else:
            raise ValueError(f"halakha {n} : source classique sans citation {r}")
    # Deux citations successives de la même référence ne la répètent pas.
    fusion = []
    for r, l in zip(h["refs"], lignes):
        if fusion and fusion[-1][0] == ref_texte(r, "he") and r["cite"]:
            prec = fusion[-1][1].rsplit(" <small>", 1)[0]
            fusion[-1] = (fusion[-1][0], f"{prec} … {r['cite']} <small>({fusion[-1][0]})</small>")
        else:
            fusion.append((ref_texte(r, "he"), l))
    he_tag = f" <small>{ETIQUETTES[h['rite']]['he']}</small>" if h["rite"] in ETIQUETTES else ""
    fr_tag = f" <small>{ETIQUETTES[h['rite']]['fr']}</small>" if h["rite"] in ETIQUETTES else ""
    en_tag = f" <small>{ETIQUETTES[h['rite']]['en']}</small>" if h["rite"] in ETIQUETTES else ""
    t = f"<b>{lettres(n, geresh=False)}</b>{he_tag} " + "<br>".join(l for _, l in fusion)
    fr = typo_fr(f"<b>{n}</b>{fr_tag} {h['fr']} <small>[{crochets(h['refs'], 'fr')}]</small>")
    en = typo_en(f"<b>{n}</b>{en_tag} {h['en']} <small>[{crochets(h['refs'], 'en')}]</small>")
    refs = []
    for r in h["refs"]:
        if ref_texte(r, "fr") not in refs:
            refs.append(ref_texte(r, "fr"))
    return {"id": f"chm-{n:02d}", "rite": h["rite"], "refs": refs,
            "t": t, "fr": fr, "en": en}


def livre():
    sections = [{"titre": "מבוא", "titre_fr": "Introduction", "titre_en": "Introduction",
                 "blocs": [{"t": INTRO["t"], "fr": typo_fr(INTRO["fr"]), "en": typo_en(INTRO["en"])}]}]
    n = 0
    for s in SECTIONS:
        blocs = []
        for h in s["halakhot"]:
            n += 1
            blocs.append(blocs_halakha(n, h))
        sections.append({"titre": s["titre"], "titre_fr": typo_fr(s["titre_fr"]), "titre_en": typo_en(s["titre_en"]), "blocs": blocs})
    return {
        "id": "chnayim_mikra",
        "groupe": "halakha",
        "titre": TITRE,
        "source": "Choul'han Aroukh et Rema, Michna Beroura, Kitsour Choul'han Aroukh, Choul'han Aroukh haRav (Kehot, CC-BY-NC), Kaf ha'Haïm, Ben Ich 'Haï, Rambam ; Kitsour Yalkout Yossef (Torat Emet, CC BY-NC-SA 2.5) ; réponses de Hidabroot, Kav haHalakha haSefaradi et Halakha lema'assé, résumées — tools/chnayim_mikra/sources.json",
        "traduction": f"FR et EN rédigées par Claude ({DATE}) d'après les sources citées, chaque halakha avec sa référence ; relecture humaine souhaitable.",
        "rites": RITES,
        # Les sources et licences du livre : tools/livres_decoupe.py les ajoute au _meta de son fichier.
        "_meta": {"sources": SOURCES_META, "verification": "tools/chnayim_mikra/sources.json",
                  "nature": "Recueil : citations hébraïques exactes des sources ; français et anglais rédigés d'après elles ; réponses d'aujourd'hui résumées avec leur référence, non reproduites."},
        "sections": sections,
    }


# --- La table de vérification -----------------------------------------------------------------

def sefaria(r):
    s, n = r["src"], r["num"]
    if s == "bih":
        annee, par_sefaria = n[0], n[1]
        ref = f"Ben Ish Hai, Halachot {BIH_ANNEE[annee][0]}, {par_sefaria} {n[5]}"
        version = SEFARIA["bih"][1]
    else:
        gabarit, version = SEFARIA[s]
        ref = gabarit.format(n)
    api = ("https://www.sefaria.org/api/v3/texts/" + urllib.parse.quote(ref)
           + "?version=" + urllib.parse.quote("hebrew|" + version) + "&return_format=text_only")
    page = "https://www.sefaria.org/" + urllib.parse.quote(ref.replace(" ", "_").replace(",_", ",_")) + "?lang=he"
    return ref, version, api, page


def table():
    lignes = []
    n = 0
    for si, s in enumerate(SECTIONS, start=1):
        for h in s["halakhot"]:
            n += 1
            refs = []
            for r in h["refs"]:
                e = {"source": r["src"], "reference": ref_texte(r, "fr"), "reference_he": ref_texte(r, "he"),
                     "edition": EDITIONS[r["src"]]["edition"], "licence": EDITIONS[r["src"]]["licence"]}
                if r["src"] in SEFARIA:
                    ref, version, api, page = sefaria(r)
                    e.update({"sefaria_ref": ref, "sefaria_version": version, "lu_via": api, "page": page})
                elif r["src"] == "kyy":
                    e.update({"lu_via": "android/app/src/main/res/raw/livre_yalkut_yosef_kitsour.json, section « סימן רפה - לקרוא הפרשה ב' מקרא וא' תרגום », se'if " + lettres(r["num"], geresh=False)})
                else:
                    m = MODERNES[(r["src"], r["num"])]
                    e.update({"url": url_moderne(r["src"], r["num"]), "auteur": m["auteur"], "titre": m["titre"], "date": m["date"],
                              "nature": "paraphrase avec référence (œuvre protégée)"})
                if r["cite"]:
                    e["citation"] = r["cite"]
                if r["passage"]:
                    e["passage_resume"] = r["passage"]
                refs.append(e)
            lignes.append({"id": f"chm-{n:02d}", "section": si, "rite": h["rite"], "rites_app": RITES[h["rite"]], "references": refs})
    return {
        "_meta": {
            "livre": "chnayim_mikra (android/app/src/main/livres/livres.json → res/raw/livre_chnayim_mikra.json ; site : data/livres/chnayim_mikra.json)",
            "date": DATE,
            "outil": "tools/chnayim_mikra/construction.py (--verifie relit chaque citation à sa source)",
            "regle": "Chaque « citation » est le texte exact de la source lue (sans balises) ; « passage_resume » est le passage sur lequel repose un résumé, pour les œuvres protégées, qui ne sont pas reproduites dans l'application.",
            "rites": RITES,
            "editions": EDITIONS,
            "non_retenus": NON_RETENUS,
        },
        "halakhot": lignes,
    }


NON_RETENUS = [
    "Garçons (mineurs) : aucune source lue ne traite de leur obligation ou de leur éducation à Chnayim mikra.",
    "Parachiot jumelées : aucune source lue n'en parle pour Chnayim mikra (le Choul'han Aroukh 284:7 ne traite que de la haftara publique).",
    "Chabbat qui tombe un Yom Tov : quelle paracha lire cette semaine-là n'est dit explicitement par aucune source lue ; seule la règle « pas de Chnayim mikra pour la lecture de Yom Tov » (285:7) est retenue.",
    "Rav Binyamin 'Hota : ses réponses sur Chnayim mikra sont en vidéo (Kikar haChabbat) et en enregistrements (podcast) ; aucune réponse écrite trouvée, rien n'en est tiré.",
    "Rav Ofir Malka lui-même : aucune réponse écrite de sa main trouvée ; les deux réponses retenues sont celles des rabbanim de son beit hora'a (hl5047.co.il).",
]


# --- La vérification ----------------------------------------------------------------------------

def plat(t):
    t = html.unescape(t)
    t = re.sub(r"<[^>]+>", " ", t)
    t = unicodedata.normalize("NFC", t).replace(" ", " ")
    return re.sub(r"\s+", " ", t).strip()


def lire_url(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (verification chnayim_mikra)"})
    with urllib.request.urlopen(req, timeout=60) as f:
        return f.read().decode("utf-8", errors="replace")


def texte_sefaria(api):
    d = json.loads(lire_url(api))
    morceaux = []

    def tout(x):
        if isinstance(x, list):
            for y in x:
                tout(y)
        elif isinstance(x, str):
            morceaux.append(x)
    for v in d.get("versions", []):
        tout(v.get("text"))
    return plat(" ".join(morceaux))


def texte_yalkut(num):
    y = json.load(open(YALKUT, encoding="utf-8"))
    siman = next(s for s in y["textes"][0]["sections"] if s["titre"].startswith("סימן רפה "))
    lettre = lettres(num, geresh=False)
    bloc = next(b for b in siman["blocs"] if b.get("t", "").startswith(f"<b>{lettre}</b>"))
    return plat(bloc["t"])


def verifie():
    fautes, vus = [], {}
    for h in table()["halakhot"]:
        for e in h["references"]:
            if "lu_via" in e and e["lu_via"].startswith("http"):
                cle = e["lu_via"]
                if cle not in vus:
                    vus[cle] = texte_sefaria(cle)
                source = vus[cle]
            elif e["source"] == "kyy":
                source = texte_yalkut(int(re.search(r"285:(\d+)", e["reference"]).group(1)))
            else:
                cle = e["url"]
                if cle not in vus:
                    vus[cle] = plat(lire_url(cle))
                source = vus[cle]
            for champ in ("citation", "passage_resume"):
                if champ in e:
                    attendu = plat(e[champ]).replace(" [...] ", " ")
                    morceaux = [m.strip() for m in plat(e[champ]).split("[...]")]
                    if not all(m and m in source for m in morceaux):
                        fautes.append(f"{h['id']} {e['reference']} ({champ}) : « {attendu[:90]} »")
            print(f"{h['id']} {e['reference']} : lu")
    print()
    if fautes:
        print(f"{len(fautes)} citation(s) introuvable(s) :")
        print("\n".join(fautes))
        sys.exit(1)
    print("toutes les citations sont dans leurs sources")


# --- L'écriture ---------------------------------------------------------------------------------

def ecrire():
    livres = json.load(open(LIVRES, encoding="utf-8"))
    nouveau = livre()
    textes = [t for t in livres["textes"] if t["id"] != nouveau["id"]]
    textes.append(nouveau)
    livres["textes"] = textes
    with open(LIVRES, "w", encoding="utf-8") as f:
        json.dump(livres, f, ensure_ascii=False, separators=(",", ":"))
    with open(TABLE, "w", encoding="utf-8") as f:
        json.dump(table(), f, ensure_ascii=False, indent=1)
        f.write("\n")
    sys.path.insert(0, os.path.join(RACINE, "tools"))
    import livres_decoupe
    livres_decoupe.decoupe()
    n = sum(1 for s in nouveau["sections"] for b in s["blocs"] if "id" in b)
    print(f"chnayim_mikra : {n} halakhot en {len(nouveau['sections'])} chapitres ; table : {os.path.relpath(TABLE, RACINE)}")


if __name__ == "__main__":
    if "--verifie" in sys.argv:
        verifie()
    else:
        ecrire()
