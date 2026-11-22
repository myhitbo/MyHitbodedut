# -*- coding: utf-8 -*-
"""
Construit android/app/src/main/res/raw/siddur_annotations.json (10/10/2026) :
ce qui, dans les trois siddourim, dépend du jour. Les textes eux-mêmes ne
sont pas touchés ; ce fichier les désigne par (texte, section, bloc), avec le
début du bloc comme empreinte, pour qu'un siddour reconstruit qui aurait
bougé fasse échouer les tests au lieu de mettre en évidence le mauvais bloc.

Trois sortes d'annotations :
  - « bloc »    : un ajout entier. S'il s'applique ce jour-là, il est mis en
                  évidence ; sinon il est replié, et une flèche le rouvre.
  - « section » : une section entière (Ta'hanoun, omer, motsaé Chabbat…),
                  même traitement.
  - « indice »  : un bloc qui mêle le texte de tous les jours et une
                  variante (« בעשרת ימי תשובה אומרים: המלך הקדוש »). Rien
                  n'est replié : quand la variante s'applique, un repère
                  « Aujourd'hui : המלך הקדוש » s'affiche sous le bloc.

Un bloc dont le libellé est « ajout_autres_jours » (audit du 12/11, TSIDDUR-06) est le texte
ordinaire qu'une formule du jour remplace (« האל הקדוש » pendant les dix jours, « בונה
ירושלים » à Min'ha du 9 Av) : sa condition est niée ; quand il se dit, il s'affiche tel quel,
sans étiquette ; le jour où il est remplacé, il est replié. Un bloc « discret » (12/11 : « שעשה
לי כל צרכי », la fin du Kaddich après le Hallel) se dit presque tous les jours : même traitement,
mais sous son libellé propre (« Sauf à 'Hanouka »).

Aucune règle de calendrier n'est écrite ici. Chaque annotation renvoie à une
clé de condition (CalendrierJuif.C), calculée par KosherJava ; l'outil ne
fait que reconnaître, dans le texte, la consigne du siddour qui dit quand
l'ajout se dit (« בקיץ », « בחנוכה ופורים אומרים », « בעשי״ת »…). Une
condition précédée de « ! » s'applique quand la clé est fausse (« בימים שאין
בהם תחנון »). Ce qui ne se laisse pas reconnaître sûrement reste tel quel,
déplié comme avant : Avinou malkénou (coutumes diverses), le Ta'hanoun du
siddour ashkénaze (mêlé au Vidouï sans frontière nette), le Chir chel yom.

  python3 tools/siddur_annotations.py
"""
import json
import os
import re
import sys

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RAW = os.path.join(RACINE, "android", "app", "src", "main", "res", "raw")
TEXTES = ["chaharit", "minha", "arvit", "birkat_hamazon", "meen_chaloch", "moussaf_rosh_hodech", "havdala", "hallel",
          "birkot_hachahar", "chema_coucher", "megila", "birkat_halevana"]

# Les consignes d'oubli (12/11) : « טעה ולא אמר… », « אם שכח… », « אם לא אמר… », ce qu'on fait si l'on
# s'est trompé. « כל שלא אמר אמת ויציב… לא יצא » n'en est pas une : c'est l'obligation même.
OUBLI = re.compile(r"^\(?(?:טעה|שכח|אם שכח|אם טעה|ואם טעה|אם לא אמר|ואם לא אמר)\b"
                   r"|^בכל השנה אם אמר המלך המשפט|^בעשי״ת אומרים בספר חיים\. ואם לא אמר")
OFFICE = {"chaharit": "chaharit", "minha": "minha"}


def nu(s):
    """Le texte sans balises, sans voyelles ni cantillation, espaces réduits."""
    s = re.sub(r"<[^>]+>", " ", s)
    s = re.sub(r"[֑-ׇ]", "", s)
    return re.sub(r"\s+", " ", s).strip()


def mots(s):
    """Sans ponctuation, pour comparer des débuts de prière."""
    return re.sub(r"[^א-ת ]", "", s.replace("־", " ")).split()


def commence(s, debut):
    return mots(s)[: len(debut.split())] == debut.split()


ETE = ("בקיץ:", "בימות החמה:")
HIVER = ("בחורף:", "בימות הגשמים:")

# Les variantes de Ya'alé véyavo : le préfixe de la ligne, et la fête.
VARIANTES_YAALE = [
    (r"^(ב|ל)(ראש חדש|ראש חודש|ר״ח)\b", "roch_hodech"),
    (r"^(ב|ל)(חוה״מ )?פסח\b", "pessah"),
    (r"^(ב|ל)(חוה״מ )?(סוכות|סכות)\b", "soukkot"),
    (r"^(ב|ל)שבועות\b", "chavouot"),
    (r"^(ב|ל)(ראש השנה|ר״ה)\b", "roch_hachana"),
    (r"^(ב|ל)(שמיני עצרת|שמ״ע|ש״ע)", "chemini_atseret"),
    (r"^ילדים האוכלים ביו״כ", "kippour"),
    # Edot : qui mange à Kippour (audit du 16/11 ; Kitsour Yalkut Yosef 618:12, tools/siddur_audit_berakhot.py).
    (r"^(ב|ל)(יום הכפורים|יוה״כ|יו״כ)\b", "kippour"),
]

# Méèn chaloch : le début d'un bloc d'ajout (sans voyelles), et sa condition. Edot : « בשבת ורצה »,
# « בפסח ושמחנו » ; Sfard : « (בשבת:) ורצה », « (ביו״ט:) ושמחנו » ; Ashkenaz : « בשבת: ורצה »,
# « ביום טוב ובחוה״מ: ושמחנו ביום », « בפסח: חג המצות », puis « ביום (טוב) מקרא קדש הזה. ».
MEEN_CHALOCH = [
    (r"^\(?בשבת:?\)? ?ורצה", "chabbat"),
    (r"^\(?(בראש ?חודש|בר״ח):?\)? ?וזכרנו", "roch_hodech"),
    (r"^\(?(בראש ?השנה|בר״ה):?\)? ?וזכרנו", "roch_hachana"),
    (r"^\(?(ביו״ט|ביום טוב ובחוה״מ):?\)? ?ושמחנו", "moed"),
    (r"^ביום \(טוב\) מקרא קדש", "moed"),
    (r"^בפסח:? (ושמחנו|חג המצות)", "pessah"),
    (r"^בשבועות:? (ושמחנו|חג השבועות)", "chavouot"),
    (r"^בסוכות:? (ושמחנו|חג הסכות)", "soukkot"),
    (r"^בשמיני עצרת:? (ושמחנו|שמיני)", "chemini_atseret"),
]

# Les variantes enchâssées dans un bloc, après leur annonce.
# Les mêmes variantes dans le texte brut : ce qu'on retire du bloc hors du jour (28/10).
RETIRE = [
    r"<small>\s*<small>\s*בעשרת ימי תשובה[^<]*</small>[^<]*</small>",
    r"<small>בעשרת ימי תשובה [^<:]*: [^<]+</small> ?",
    r" ?\(<small>בעשי״ת</small>[^)]*\)",
    r" ?<small>\(בעשי״ת [^)]*\)</small>",
    r"<small>בעשי״ת הַמֶּלֶךְ</small> ?",
]
INDICES = [
    (r"בעשרת ימי תשובה (?:אומרים|אומר|מסיימים)?:? ?([^:()]+)", "asseret_yemei_techouva"),
    (r"\( ?בעשי״ת:? ([^)]+)\)", "asseret_yemei_techouva"),
    (r"(?<!\()\bבעשי״ת (המלך)(?= הקדוש)", "asseret_yemei_techouva"),
]


# « וּלְכַפָּרַת פָּשַׁע » au Moussaf de Roch 'Hodech (vérification du 28/10) : année embolismique
# seulement, jusqu'à Roch 'Hodech Adar II inclus ; plus à partir de Nissan. Sfard, Ashkenaz : la
# consigne de leur siddour, « עד חודש ניסן ». Edot (audit du 16/11) : le Yalkut Yosef, référence
# de l'application pour ce rite (Kitsour Yalkut Yosef 423:14, « מראש חודש ניסן ואילך אין צריך
# להוסיף ») ; la consigne de leur siddour, « בשנה מעוברת », le dit toute l'année, avec le Ben Ich
# 'Haï et le Kaf ha'Haïm 423:18. Michna Beroura 423:6 rapporte trois usages (tous les mois, l'année
# embolismique, ou celle-ci jusqu'à la fin d'Adar II). Rend (condition, passage brut à retirer hors
# du jour : la consigne et le mot, avec l'espace qui les précède).
def kapparat_pecha(brut, nusah):
    m = re.search(r"(בשנת העיבור|בשנה מעוברת)", brut)
    if not m:
        return None
    debut = brut.rfind("<small>", 0, m.start())
    while brut.startswith("<small>", debut - 7):
        debut -= 7
    fin = brut.index("שַׁע", m.end()) + len("שַׁע")
    suite = re.match(r"(\.?(</b>|</small>))*", brut[fin:])
    fin += suite.end()
    if brut[fin:fin + 1] == "." and brut[:debut].rstrip().endswith("."):
        fin += 1
    while debut > 0 and brut[debut - 1] == " ":
        debut -= 1
    if brut[fin:fin + 1] == ")" and brut[debut - 1:debut] == ",":
        debut -= 1
    return "embolismique_avant_nissan", brut[debut:fin]


def motif_brut(mots_):
    """Des mots sans voyelles, cherchés dans le texte brut (voyelles, cantillation, maqaf, balises)."""
    diacritiques = "[֑-ׇ]*"
    return r"(?:<[^>]+>|[\s|])*".join("".join(re.escape(l) + diacritiques for l in m) for m in mots_.split())


def passage(brut, debut, fin):
    """Le passage brut de [debut] à [fin] compris, avec sa ponctuation et l'espace qui suit (audit du 16/11)."""
    m = re.search(motif_brut(debut) + r".*?" + motif_brut(fin) + r"[׃:.]?\s*", brut)
    return m.group(0) if m else None


# Repères du jour (audit du 16/11, Structure des offices) : des renvois et des précisions, jamais un
# texte liturgique. Le texte de la lecture se lit dans un Houmach ; ses bénédictions, à Cha'harit.
TEFILIN_SANS_BERAKHA = "בחול המועד מניחים תפילין בלי ברכה (משנה ברורה ל״א:ח)"
HAMAPIL_APRES_AUBE = ("אחר עלות השחר אומרים „המפיל“ בלי שם ומלכות; ואם מסתפק שמא לא יישן – לא יברך "
                      "(ביאור הלכה רל״ט)")
KRIAT_TAANIT = "בתענית ציבור, אחר חצי קדיש: הוצאת ספר תורה – „ויחל“ (שמות ל״ב:י״א–י״ד; ל״ד:א׳–י׳), שלושה עולים"
# Ashkenaz, haftara « דרשו » aussi à Min'ha du 9 Av (Rema O.H. 566:1 ; Kitsour Choul'han Aroukh 124:19) :
# l'audit du 16/11 proposait « שובה ישראל » dans les trois rites, ce qui n'est l'usage que des Edot ; écarté.
KRIAT_TAANIT_ACHKENAZ = KRIAT_TAANIT + ", והמפטיר מפטיר „דרשו“ (ישעיה נ״ה:ו׳–נ״ו:ח׳). הברכות – בקריאת התורה של שחרית"
KRIAT_TAANIT_EDOT = KRIAT_TAANIT + ". הברכות – בקריאת התורה של שחרית; בשאר התעניות אין מפטירים (ילקוט יוסף תק״נ:מ)"
HAFTARA_TICHA_BEAV_EDOT = "בתשעה באב מפטירים במנחה „שובה ישראל“ (הושע י״ד:ב׳)"
KADDICH_MOTSAE_ACHKENAZ = "כאן אומר החזן סוף הקדיש השלם: „תתקבל“, „יהא שלמא“, „עושה שלום“ (לעיל, אחר העמידה)"
KADDICH_TICHA_BEAV_ACHKENAZ = "כאן אומר החזן קדיש שלם בלא „תתקבל“ (רמ״א תקנ״ט:ד)"
TEFILIN_MINHA_TICHA_BEAV = "בתשעה באב מתעטפים בטלית ומניחים תפילין במנחה (שולחן ערוך תקנ״ה:א)"
LEDAVID_MINHA = "„לדוד ה׳ אורי“: לפי המשנה ברורה (תקפ״א:ב) אומרים אותו בערב אחר מנחה; בסידור זה – בסוף ערבית"
TEHILIM_22_POURIM = "בליל פורים אומרים קודם ערבית מזמור „למנצח על אילת השחר“ (תהלים כ״ב), שבשיר של יום של שחרית (ילקוט יוסף תרצ״ג:א)"
SEFER_TORAH_EDOT = ("ילקוט יוסף (תכ״ג:ו): מנהגנו להחזיר את ספר התורה למקומו מיד אחר הקדיש, ואחר כך אשרי ובא לציון; "
                    "בסידור זה ההחזרה אחר ובא לציון")


def reperes(texte_id, sections, nusah, sortie, note):
    """Les repères du jour qu'aucune consigne du siddour ne porte (audit du 16/11) : sous le dernier bloc
    libre avant l'endroit voulu. Un repère sous un bloc replié ne se verrait pas."""
    pris = {(e["s"], e["b"]) for e in sortie if e["sorte"] == "bloc"}

    def libre(si, avant):
        """Le dernier bloc de prière non annoté de la section si avant le bloc [avant]."""
        blocs = sections[si]["blocs"]
        return next((k for k in range(min(avant, len(blocs)) - 1, -1, -1) if "t" in blocs[k] and (si, k) not in pris), None)

    def premier_annote(si):
        return min((b for s, b in pris if s == si), default=len(sections[si]["blocs"]))

    titres = [nu(s["titre"]) for s in sections]
    if texte_id == "minha":
        # La lecture de la Torah des jeûnes publics, entre Achré (et le demi-Kaddich) et l'Amida (Choul'han
        # Aroukh O.H. 566:1 et Rema ; Kitsour Yalkut Yosef 550:39-40).
        k = libre(0, premier_annote(0))
        if k is not None:
            if nusah == "edot":
                note("indice", 0, k, "jeune", {"texte": KRIAT_TAANIT_EDOT})
                note("indice", 0, k, "ticha_beav", {"texte": HAFTARA_TICHA_BEAV_EDOT})
            else:
                note("indice", 0, k, "jeune", {"texte": KRIAT_TAANIT_ACHKENAZ})
            if nusah == "ashkenaz":
                note("indice", 0, k, "ticha_beav", {"texte": TEFILIN_MINHA_TICHA_BEAV})
        # Ashkenaz : le second לדוד ה׳ אורי, après Min'ha selon la Michna Beroura (581:2, Maté Efraïm 581:6).
        if nusah == "ashkenaz" and "סיום תפילה" in titres:
            si = titres.index("סיום תפילה")
            k = libre(si, premier_annote(si))
            if k is not None:
                note("indice", si, k, "ledavid", {"texte": LEDAVID_MINHA})
    if texte_id == "arvit" and nusah == "edot":
        # Le psaume 22 la nuit de Pourim, avant Arvit (Kitsour Yalkut Yosef 693:1).
        k = next((b for b, x in enumerate(sections[0]["blocs"]) if "t" in x and (0, b) not in pris), None)
        if k is not None:
            note("indice", 0, k, "pourim", {"texte": TEHILIM_22_POURIM})
            # Pourim triple à Jérusalem : la Méguila se lit le jeudi soir, nuit du 14 (Kitsour Yalkut Yosef 688).
            note("indice", 0, k, "pourim_triple_vendredi", {"texte": TEHILIM_22_POURIM})
    if texte_id == "arvit" and nusah == "ashkenaz" and any("מוצאי שבת" in t for t in titres):
        si = next(i for i, t in enumerate(titres) if "מוצאי שבת" in t)
        b = len(sections[si]["blocs"]) - 1
        note("indice", si, b, "vihi_noam", {"texte": KADDICH_MOTSAE_ACHKENAZ})
        note("indice", si, b, "ticha_beav", {"texte": KADDICH_TICHA_BEAV_ACHKENAZ})
    if texte_id == "chaharit" and nusah == "edot" and "אשרי" in titres:
        # Le Sefer Torah rendu à l'arche aussitôt après le Kaddich (Kitsour Yalkut Yosef 423:6).
        si = titres.index("אשרי")
        k = next((b for b, x in enumerate(sections[si]["blocs"]) if "t" in x and (si, b) not in pris), None)
        if k is not None:
            note("indice", si, k, "kriat_hatorah", {"texte": SEFER_TORAH_EDOT})
    if texte_id == "arvit" and nusah == "sefard":
        # Motsaé Chabbat (Sfard) : la section « ערבית למוצאי שבת » a son עלינו ; celui de la fin d'Arvit
        # de semaine se replie les soirs où l'on dit ואתה קדוש (sinon il paraissait deux fois).
        if any("מוצאי שבת" in t for t in titres):
            fin = next(i for i, t in enumerate(titres) if "מוצאי שבת" in t)
            for si in range(fin):
                blocs = sections[si]["blocs"]
                for b, x in enumerate(blocs):
                    y = nu(x.get("t") or x.get("c"))
                    if "t" in x and (si, b) not in pris and any(commence(y, m) for m in ("עלינו לשבח", "על כן נקוה", "אל תירא")):
                        note("bloc", si, b, "!veata_kadoch", {"libelle": AUTRES_JOURS})


def annoter(texte_id, sections, nusah):
    sortie = []

    def note(sorte, si, bi, cond, extra=None):
        extra = dict(extra or {})
        bloc = sections[si]["blocs"][bi] if bi is not None else None
        e = {"sorte": sorte, "s": si, "si": cond}
        if bi is not None:
            e["b"] = bi
            e["empreinte"] = nu(bloc.get("t") or bloc.get("c"))[:40]
        else:
            e["empreinte"] = nu(sections[si]["titre"])
        if extra:
            e.update(extra)
        sortie.append(e)

    office = OFFICE.get(texte_id)
    for si, sec in enumerate(sections):
        titre = nu(sec["titre"])
        # --- Sections entières -------------------------------------------------
        cond = None
        # Une section « תחנון » ou « וידוי » qui porte aussi la suite de l'office (Edot : Kaddich,
        # psaumes ; audit du 12/11, TSIDDUR-03 et -07) n'est pas repliée d'un bloc, ce qui cachait
        # la fin de Min'ha les jours sans Ta'hanoun : seul le Ta'hanoun l'est, jusqu'aux consignes
        # qui précèdent le premier Kaddich ; le reste suit les règles des blocs. De même « לשני
        # וחמישי » (Sfard), qui contient « שומר ישראל » des autres jours de Ta'hanoun.
        fin_tahanoun = 0
        if titre in ("תחנון", "וידוי") and office:
            fin_tahanoun = next((k for k, b in enumerate(sec["blocs"]) if "t" in b and commence(nu(b["t"]), "יתגדל")), None)
            if fin_tahanoun is None:
                cond, fin_tahanoun = "tahanoun_" + office, 0
            else:
                while fin_tahanoun > 0 and "c" in sec["blocs"][fin_tahanoun - 1]:
                    fin_tahanoun -= 1
        elif "מוצאי שבת" in titre:
            # Audit du 16/11 (Structure des offices) : la section n'est plus repliée d'un bloc sous
            # « motsae_chabbat ». ויהי נועם et ישב בסתר, jusqu'à « ואתה קדוש », sous « vihi_noam » : pas
            # quand un Yom tov ou 'Hol hamoed tombe dans la semaine (Sfard, Ashkenaz : Rema O.H. 295:1,
            # Michna Beroura 295:3, Choul'han Aroukh haRav 295:3), ni quand le 9 Av commence au motsaé
            # Chabbat (Choul'han Aroukh O.H. 559:2). « ואתה קדוש » et la suite sous « veata_kadoch » :
            # les mêmes soirs, et le soir du 9 Av, après Ekha (Michna Beroura 559:7) ; « תתקבל » ne s'y dit
            # pas ce soir-là (Rema O.H. 559:4) : variante estompée. Conditions : SiddurJour.conditionsPour.
            blocs_ms = sec["blocs"]
            txt_ms = [nu(b.get("t") or b.get("c")) for b in blocs_ms]
            kadoch = next((k for k, y in enumerate(txt_ms) if commence(y, "ואתה קדוש")), len(blocs_ms))
            for k in range(len(blocs_ms)):
                c = "vihi_noam" if k < kadoch else ("!ticha_beav" if commence(txt_ms[k], "תתקבל") else "veata_kadoch")
                note("bloc", si, k, c)
            continue
        # Les téfilin (Edot ; audit du 16/11) : pas le Chabbat ni le Yom tov, ni à 'Hol hamoed
        # (Kitsour Yalkut Yosef 31:6, « המנהג פשוט שאין מניחין תפילין בחול המועד ») ; le talit
        # (section précédente) reste. Le 9 Av, l'usage Edot est conforme (Yalkut Yosef 555:1).
        elif titre == "סדר הנחת תפילין" and office == "chaharit":
            for k in range(len(sec["blocs"])):
                note("bloc", si, k, "tefilin", {"libelle": "ajout_sauf_tefilin", "discret": True})
            continue
        elif titre == "ספירת העומר":
            cond = "omer"
        # La lecture de la Torah (15/10) : un seul groupe, replié les jours sans lecture ;
        # dedans, ce qui ne se dit qu'avec Ta'hanoun, ou que lundi et jeudi, en variante.
        elif titre == "קריאת התורה" and office == "chaharit":
            mode, reste = "kriat_hatorah", None
            for bi, b in enumerate(sec["blocs"]):
                x = nu(b.get("t") or b.get("c"))
                if "c" in b:
                    # אל ארך אפים (Ashkenaz, Sfard) suit למנצח, pas le Ta'hanoun : « דאל ארך אפים ולמנצח
                    # דינם שוה » (Michna Beroura 131:35 ; consigne Sfard d'Achré, Dérekh ha'Haïm ; Choul'han
                    # Aroukh haRav 429:12). Il se dit donc les lundis et jeudis sans Ta'hanoun (Nissan, Tou
                    # biChvat…) ; « ויש נוהגים » qui le lient au Ta'hanoun restent un usage cité (audit du 16/11).
                    # Le lundi et le jeudi seulement, pas un jeûne d'un autre jour : « ובשני וחמישי אומרים אל ארך
                    # אפים » (Choul'han Aroukh haRav 429:12 ; Matté Efraïm 602:12) : clé el_erekh_apayim.
                    if x.startswith("אין אומרים אא״א") and nusah != "edot":
                        mode, reste = "el_erekh_apayim", None
                    elif "ביום שיש בו תחנון" in x or x.startswith("אין אומרים אא״א"):
                        mode, reste = "tahanoun_chaharit", None
                    elif "ביום שאין בו תחנון" in x:
                        mode, reste = "!tahanoun_chaharit", 1
                    elif "בשני וחמישי כשאומרים תחנון" in x:
                        mode, reste = "lundi_jeudi", None
                    else:
                        mode, reste = "kriat_hatorah", None
                    note("bloc", si, bi, mode, {"force": "kriat_hatorah"})
                    continue
                note("bloc", si, bi, mode, {"force": "kriat_hatorah"})
                if reste is not None:
                    reste -= 1
                    if reste == 0:
                        mode, reste = "kriat_hatorah", None
            continue
        elif titre == "ברכי נפשי" and "בראש חדש" in nu(sec["blocs"][0].get("c", "")):
            cond = "roch_hodech"
        if cond:
            note("section", si, None, cond)
            continue

        blocs = sec["blocs"]
        # Les guillemets doubles ASCII du siddour Edot (« ברה''ש », « ביו''ט ») lus comme gershayim.
        txt = [nu(b.get("t") or b.get("c")).replace("''", "״") for b in blocs]
        cons = ["c" in b for b in blocs]
        pris = set()

        def prend(bi, c, libelle=None):
            if bi not in pris:
                pris.add(bi)
                note("bloc", si, bi, c, {"libelle": libelle} if libelle else None)

        def sceau(bi, c, motif, libelle=None):
            """Le sceau d'un ajout, quand le siddour le met dans le bloc suivant (Edot : « ברוך אתה
            יהוה מנחם ציון », « … העונה בעת צרה »), suit le sort de l'ajout : sans cela il restait
            affiché tous les jours, avant le sceau ordinaire (audit du 12/11, TSIDDUR-01)."""
            if bi + 1 < len(txt) and not cons[bi + 1] and re.match(motif, txt[bi + 1]):
                prend(bi + 1, c, libelle)

        def ordinaire(bi, du_jour):
            """Le sceau ordinaire, dans le bloc juste avant celui des dix jours (Sfard, Ashkenaz :
            « ברוך אתה יהוה האל הקדוש », puis « בעשי״ת מסיים: ברוך אתה יהוה המלך הקדוש »), ne se
            dit pas ces jours-là : il est replié quand celui du jour, bénédiction entière, le
            remplace (audit du 12/11, TSIDDUR-06). Là où le siddour ne donne que les deux mots
            (« בעשי״ת יסיים: המלך המשפט »), rien n'est replié : il ne resterait pas de bénédiction."""
            if bi > 0 and bi - 1 not in pris and not cons[bi - 1] and SCEAU_DIX_JOURS.search(du_jour) \
                    and SCEAU_ORDINAIRE.fullmatch(txt[bi - 1]):
                prend(bi - 1, "!asseret_yemei_techouva", AUTRES_JOURS)

        def nahem(bi):
            """Na'hem, le 9 Av : avec lui son sceau quand il est dans le bloc suivant (Edot), et le
            renvoi « (את צמח וגו׳) » (Sfard). Le sceau ordinaire « בונה ירושלים », que celui de
            Na'hem remplace ce jour-là, est alors replié (audit du 12/11, TSIDDUR-01 et -06)."""
            prend(bi, "ticha_beav")
            sceau(bi, "ticha_beav", r"ברוך אתה \S+,? מנחם ציון")
            j = bi + 2 if bi + 1 in pris else bi + 1
            if j < len(txt) and not cons[j] and re.fullmatch(r"\(את צמח[^()]*\)", txt[j]):
                prend(j, "ticha_beav")
                j += 1
            if j < len(txt) and not cons[j] and j not in pris and "מנחם ציון" in " ".join(txt[bi:j]) \
                    and re.fullmatch(r"ברוך אתה \S+,? בונה ירושלים:?", txt[j]):
                prend(j, "!ticha_beav", AUTRES_JOURS)

        def prend_discret(bi, c, libelle):
            """Presque tous les jours : en clair le jour dit, sans étiquette ; replié les autres (12/11)."""
            if bi not in pris:
                pris.add(bi)
                note("bloc", si, bi, c, {"libelle": libelle, "discret": True})

        def en_tete(bi, c, *mots_cles, libelle=None):
            """La consigne juste avant un ajout, si elle l'annonce, en suit le sort."""
            if bi > 0 and cons[bi - 1] and all(m in txt[bi - 1] for m in mots_cles):
                prend(bi - 1, c, libelle)

        # Ta'hanoun du siddour ashkénaze (audit du 16/10) : il n'a pas de section à lui, il est
        # dans « אחר העמידה » autour d'Avinou malkénou. Le Vidouï et les treize attributs avant ;
        # après, la consigne « בשני וחמישי יאמר והוא רחום », le long והוא רחום (lundi et jeudi),
        # puis la chute sur la face (« ויאמר דוד ») jusqu'au demi-Kaddich, qui se dit toujours.
        if nusah == "ashkenaz" and office and titre == "אחר העמידה":
            am = next((k for k, y in enumerate(txt) if cons[k] and "אומרים כאן אבינו מלכנו" in y), None)
            lj = next((k for k, y in enumerate(txt) if cons[k] and y.startswith("בשני וחמישי יאמר והוא רחום")), None)
            dd = next((k for k, y in enumerate(txt) if not cons[k] and y.startswith("ויאמר דוד")), None)
            # La fin : la consigne du demi-Kaddich (Cha'harit) ou le Kaddich lui-même (Min'ha).
            kd = next((k for k, y in enumerate(txt) if dd is not None and k > dd
                       and ((cons[k] and "קדיש" in y) or (not cons[k] and commence(y, "יתגדל")))), None)
            # Le Vidouï et les treize attributs d'avant Avinou malkénou : « יש מקומות שנוהגין לומר קודם
            # והוא רחום י"ג מדות של רחמים ווידוי » (Michna Beroura 134:1), donc le lundi et le jeudi, et
            # selon l'usage ; ils étaient mis en évidence chaque jour de Ta'hanoun (audit du 16/11).
            if am is not None and txt[0].startswith("טעם נכון למה נתקן הוידוי"):
                for k in range(0, am):
                    prend(k, "lundi_jeudi", "ajout_lundi_jeudi_usage")
            if lj is not None and dd is not None and lj < dd:
                prend(lj, "tahanoun_" + office)
                for k in range(lj + 1, dd):
                    prend(k, "lundi_jeudi")
            if dd is not None and kd is not None:
                # « ה׳ אלהי ישראל שוב », הבט משמים, זרים, חוסה, קולנו, עזרנו : le piyout qui suit והוא רחום
                # le lundi et le jeudi, jusqu'à « שומר ישראל » (Aroukh haChoul'han O.H. 134:1-2 ; le siddour
                # Sfard de l'app le range de même ; audit du 16/11). Le Ps 6 et שומר ישראל : tous les jours.
                pj = next((k for k in range(dd, kd) if not cons[k] and commence(txt[k], "יהוה אלהי ישראל שוב")), None)
                sh = next((k for k in range(dd, kd) if not cons[k] and commence(txt[k], "שומר ישראל")), None)
                for k in range(dd, kd):
                    prend(k, "lundi_jeudi" if pj is not None and sh is not None and pj <= k < sh else "tahanoun_" + office)

        # Talit et téfilin du siddour ashkénaze (audit du 16/11) : ni l'un ni l'autre le matin du 9 Av
        # (Choul'han Aroukh O.H. 555:1, à Min'ha) ; les téfilin, pas le Chabbat ni le Yom tov, ni à
        # 'Hol hamoed en Israël (« tefilin », SiddurJour.conditionsPour). En diaspora, à 'Hol hamoed,
        # on les met : sans bénédiction, dit la Michna Beroura (31:8), qu'un repère rappelle.
        if nusah == "ashkenaz" and office == "chaharit":
            talit = next((k for k, y in enumerate(txt) if cons[k] and "להתעטף בו" in y), None)
            tef = next((k for k, y in enumerate(txt) if cons[k] and y.startswith("יניח התפילין של יד")), None)
            fin_tef = next((k for k, y in enumerate(txt) if tef is not None and k > tef and not cons[k] and commence(y, "וארשתיך")), None)
            par = next((k for k, y in enumerate(txt) if cons[k] and y.startswith("אחר שיניח תפילין יאמר פרשיות")), None)
            if None not in (talit, tef, fin_tef, par):
                debut_talit = talit - 1 if talit > 0 and txt[talit - 1].startswith("לשם יחוד") else talit
                debut_tef = tef - 1 if txt[tef - 1].startswith("לשם יחוד") else tef
                for k in range(debut_talit, debut_tef):
                    prend_discret(k, "!ticha_beav", "ajout_sauf_ticha_beav_matin")
                for k in range(debut_tef, fin_tef + 1):
                    prend_discret(k, "tefilin", "ajout_sauf_tefilin")
                k = par
                while k < len(txt) and (k == par or (not cons[k] and (txt[k].startswith("וידבר") or txt[k].startswith("והיה כי")))):
                    prend_discret(k, "!ticha_beav", "ajout_sauf_ticha_beav_matin")
                    k += 1
                if debut_talit > 0 and not cons[debut_talit - 1]:
                    note("indice", si, debut_talit - 1, "tefilin_sans_berakha", {"texte": TEFILIN_SANS_BERAKHA})

        # Anénou : l'officiant le dit dans sa répétition, bénédiction à part
        # entre « גואל ישראל » et « רפאנו » ; le particulier, dans « שומע
        # תפלה ». On les distingue par leur place : avant ou après « רפאנו ».
        rofe = next((k for k, y in enumerate(txt) if not cons[k] and commence(y, "רפאנו")), None)

        def anenou(bi):
            """(condition, libellé) d'un Anénou à la place bi."""
            if rofe is not None and bi < rofe:
                return "jeune", "ajout_anenou_officiant"
            # Le particulier : Edot le dit à Cha'harit et à Min'ha, et le 9 Av à
            # Arvit (« בתשעה באב יש אומרים עננו ») ; Ashkenaz et Sfard, à Min'ha
            # seulement (Rema, OC 565:3), et leur siddour ne le donne qu'à Min'ha.
            # Edot, Arvit : la version des trois autres jeûnes n'est pas celle du 9 Av ; elle ne
            # se dit pas ce soir-là, elle reste repliée (TSIDDUR-17).
            if texte_id == "arvit" and "בג׳ צומות" in txt[bi]:
                return "facultatif", "ajout_anenou_particulier"
            return ("ticha_beav" if texte_id == "arvit" else "jeune"), "ajout_anenou_particulier"

        n = len(blocs)
        if texte_id == "havdala":
            havdala(txt, cons, prend_discret)
        for k in range(fin_tahanoun):
            prend(k, "tahanoun_" + office)
        bi = fin_tahanoun
        while bi < n:
            x = txt[bi]
            # --- Audit du 12/11 (TSIDDUR-03, -05, -07) : la suite du Ta'hanoun, le Hallel Edot ---
            # Lundi et jeudi (Sfard) : « בשני וחמישי יאמר והוא רחום. בשאר ימים שאומרים בהם תחנון
            # יאמר שומר ישראל » ; la consigne vaut tous les jours de Ta'hanoun, « והוא רחום » et
            # ce qui le suit les lundis et jeudis, jusqu'à « שומר ישראל ».
            if office and cons[bi] and bi not in pris and x.startswith("בשני וחמישי יאמר והוא רחום"):
                chomer = next((k for k in range(bi + 1, n) if not cons[k] and commence(txt[k], "שומר ישראל")), None)
                if chomer is not None:
                    prend(bi, "tahanoun_" + office)
                    for k in range(bi + 1, chomer):
                        prend(k, "lundi_jeudi")
                    bi = chomer
                    continue
            # « שומר ישראל » jusqu'à « ואנחנו לא נדע » (Sfard) : tous les jours de Ta'hanoun.
            if office and not cons[bi] and bi not in pris and commence(x, "שומר ישראל שמור שארית ישראל"):
                fin = next((k for k in range(bi, n) if not cons[k] and commence(txt[k], "ואנחנו לא נדע")), None)
                if fin is not None:
                    for k in range(bi, fin + 1):
                        prend(k, "tahanoun_" + office)
                    bi = fin + 1
                    continue
            # Lundi et jeudi (Edot) : de « בימי שני וחמישי מוסיפים » au Kaddich qui clôt ces
            # supplications ; un groupe à lui, replié les autres jours de Ta'hanoun.
            if office and cons[bi] and re.fullmatch(r"בימי שני וחמישי מוסיפים:?", x):
                j = bi
                while j < n and (cons[j] or not commence(txt[j], "יתגדל")):
                    prend(j, "lundi_jeudi")
                    j += 1
                bi = j
                continue
            # Le Kaddich d'après le Ta'hanoun, que sa consigne écarte les lundis et jeudis (Edot) :
            # la consigne suit le Kaddich, replié avec lui (passe « minyan »).
            if office and cons[bi] and x.startswith("בימים שני וחמישי אין אומרים את הקדיש הזה"):
                prend(bi, "minyan")
                bi += 1
                continue
            # Le renvoi aux supplications des jeûnes publics (Edot).
            if office and cons[bi] and x.startswith("בתעניות ציבור אומרים כאן תחנונים"):
                prend(bi, "jeune", JEUNE)
                bi += 1
                continue
            # La veille de Chabbat à Min'ha (Edot) : le psaume 93 à la place du 67. Le psaume 67
            # est le texte des autres jours ; sa consigne, qui parle aussi de 'Hol hamoèd, reste.
            if office and cons[bi] and x.startswith("בערב שבת אין אומרים") and bi + 1 < n and not cons[bi + 1] \
                    and "למנצח בנגינת" in txt[bi + 1][:40]:
                prend(bi + 1, "!jour_6", AUTRES_JOURS)
                bi += 2
                continue
            if office and cons[bi] and x.startswith("בערב שבת אומרים מזמור") and bi + 1 < n and not cons[bi + 1]:
                prend(bi, "jour_6")
                prend(bi + 1, "jour_6")
                bi += 2
                continue
            # Le Hallel Edot : l'appel de l'officiant et la bénédiction « לגמור את ההלל », les jours
            # de Hallel complet seulement. Le Hallel partiel de Roch 'Hodech se dit sans
            # bénédiction (Choul'han Aroukh, OC 422:2 ; ZMANIM.md), comme « יהללוך » plus bas.
            if texte_id == "hallel" and cons[bi] and x.startswith("בימים שגומרים את ההלל"):
                fin = next((k for k in range(bi, n) if not cons[k] and "לגמור את ההלל" in txt[k]), None)
                if fin is not None:
                    for k in range(bi, fin + 1):
                        prend(k, "hallel_complet")
                    bi = fin + 1
                    continue
            # --- Relevé du 19/10 : ce qui restait ouvert tous les jours ---------------------
            # Les bénédictions de qui a oublié רצה ou יעלה ויבא : jamais du jour, toujours repliées.
            # Ashkenaz, Sfard : « דיני שכחה: » jusqu'à la fin de la section ; Edot : « אם שכח לומר
            # "רצה"… » jusqu'à la bénédiction הטוב והמטיב, qui se dit toujours.
            if cons[bi] and x.startswith("דיני שכחה"):
                for j in range(bi, n):
                    prend(j, "oubli")
                bi = n
                continue
            if cons[bi] and x.startswith('אם שכח לומר "רצה"'):
                j = bi
                while j < n and (j == bi or not commence(txt[j], "ברוך אתה יהוה אלהינו מלך העולם לעד")):
                    prend(j, "oubli")
                    j += 1
                bi = j
                continue
            # Les consignes d'oubli de la Amida et du Birkat (12/11) : repliées sous « En cas d'oubli »,
            # comme les bénédictions de qui a oublié רצה ; elles s'affichaient chaque jour.
            # Le voyageur entre Israël et la diaspora, pour טל ומטר (audit du 16/11 ; Yalkut Yosef, Kitsour 117:15-17 ;
            # Michna Beroura 117:5) : une consigne qui n'est d'aucun jour, repliée sous son libellé.
            if cons[bi] and bi not in pris and x.startswith("בן ארץ ישראל בחוץ לארץ"):
                prend(bi, "facultatif", "ajout_voyageur_tal_oumatar")
                bi += 1
                continue
            if cons[bi] and bi not in pris and OUBLI.search(x):
                prend(bi, "oubli")
                bi += 1
                continue
            # « שעשה לי כל צרכי » (Edot) : pas le 9 Av ni à Kippour, la consigne le dit (Ben Ich 'Haï,
            # Vayechev 9). Les autres jours en clair, sans étiquette (12/11).
            # Audit du 16/11 : les Edot suivent le Yalkut Yosef, qui la fait dire ces deux jours (Kitsour
            # Yalkut Yosef 46:12, 559:8, 620:2, « אפשר לברך ברכה זו גם בתשעה באב וביום הכפורים »). La
            # bénédiction reste en clair ; la consigne du siddour (Ben Ich 'Haï) ne paraît que ces
            # jours-là, sous une étiquette qui donne l'avis du Yalkut Yosef, repliée les autres jours.
            if cons[bi] and re.match(r"בתשעה באב ויום הכי?פורים אין אומרים ברכה זו", x) and bi + 1 < n and not cons[bi + 1]:
                prend(bi, "ticha_beav_kippour", "ajout_chaasa_li_yalkut")
                bi += 2
                continue
            # Sfard (audit du 16/11) : la consigne de son siddour, « בט׳ אב ויוה״כ אין אומרים ברכה זו »,
            # fait foi ; la bénédiction est repliée ces deux jours, en clair les autres. La Michna
            # Beroura 554:31 la permet, et l'usage 'hassidique est partagé (Breslev la dit le 9 Av).
            if cons[bi] and re.match(r"בט׳ אב ויוה״כ אין אומרים ברכה זו", x) and bi + 1 < n and not cons[bi + 1]:
                prend_discret(bi, "!ticha_beav_kippour", "ajout_sauf_ticha_beav_kippour")
                prend_discret(bi + 1, "!ticha_beav_kippour", "ajout_sauf_ticha_beav_kippour")
                bi += 2
                continue
            # Mizmor letoda (Sfard, Ashkenaz ; audit du 16/11) : pas le Chabbat, le Yom tov, pendant
            # Pessa'h, la veille de Pessa'h ni la veille de Kippour (Rema O.H. 51:9 ; Michna Beroura 51:22
            # et 604:4 ; Choul'han Aroukh haRav 51:1). La consigne du siddour s'arrête à « ולא בערב פסח ».
            # Les Edot ont leurs consignes à eux (Kitsour Yalkut Yosef 51:32) : rien n'y change.
            if nusah != "edot" and office == "chaharit" and cons[bi] and x.startswith("מזמור לתודה יש לאומרו") \
                    and bi + 1 < n and not cons[bi + 1] and commence(txt[bi + 1], "מזמור לתודה"):
                prend_discret(bi, "mizmor_letoda", "ajout_sauf_mizmor_letoda")
                prend_discret(bi + 1, "mizmor_letoda", "ajout_sauf_mizmor_letoda")
                bi += 2
                continue
            # Après le Hallel, la fin du Kaddich (תתקבל, יהא שלמא, עושה שלום) : pas à 'Hanouka, où l'on
            # s'arrête au demi-Kaddich (« עד כאן אומרים בחנוכה », « ובחנוכה אומר רק חצי קדיש », 12/11).
            # Sauf à Roch 'Hodech Tévèt et le Chabbat de 'Hanouka, où le Moussaf suit : « כל יום שיש בו מוסף
            # אומרים קדיש תתקבל אחר ההלל » (Kitsour Yalkout Yossef 423:1 ; Kaf ha'Haïm 683:2 ; Michna Beroura
            # 423:1 ; consigne Sfard, « בראש חודש וביום טוב ובחול המועד אומר החזן קדיש שלם » ; audit du 16/11) :
            # kaddich_complet_hallel, le contraire de hanouka_sans_moussaf.
            if texte_id == "hallel" and not cons[bi] and commence(x, "תתקבל") and any(
                    cons[k] and ("עד כאן אומרים בחנוכה" in txt[k] or "ובחנוכה אומר רק חצי קדיש" in txt[k])
                    for k in range(max(0, bi - 3), bi)):
                j = bi
                while j < n and not cons[j] and any(commence(txt[j], m) for m in ("תתקבל", "יהא שלמא", "יפסע", "עושה שלום", "עשה שלום")):
                    prend_discret(j, "kaddich_complet_hallel", "ajout_sauf_hanouka")
                    j += 1
                bi = j
                continue
            # Barekhi nafchi la veille de Roch 'Hodech (Edot, Arvit : « בליל ראש חודש יש הנוהגים
            # לומר ») : la consigne et le psaume ; Arvit relève déjà du jour hébreu suivant.
            if cons[bi] and x.startswith("בליל ראש חודש") and bi + 1 < n and not cons[bi + 1]:
                prend(bi, "roch_hodech")
                prend(bi + 1, "roch_hodech")
                bi += 2
                continue
            # Barekhi nafchi après Moussaf (Edot, tools/siddur_barchi_nafchi.py ; audit du 16/11, Kitsour
            # Yalkut Yosef 423:5) : la consigne et le psaume ; son Kaddich suit la passe « minyan ».
            if texte_id == "moussaf_rosh_hodech" and cons[bi] and x.startswith("אומרים ברכי נפשי") and bi + 1 < n and not cons[bi + 1]:
                prend(bi, "roch_hodech")
                prend(bi + 1, "roch_hodech")
                bi += 2
                continue
            # « אתה חוננתנו » (Edot) : le seul bloc annoncé ; « וחננו מאתך » suit tous les soirs.
            if cons[bi] and x.startswith("במוצאי שבת ויום טוב אומרים") and bi + 1 < n and not cons[bi + 1]:
                prend(bi, "motsae_chabbat_yt")
                prend(bi + 1, "motsae_chabbat_yt")
                bi += 2
                continue
            # La fin d'Arvit du motsaé Chabbat (Edot) : jusqu'au Kaddich titkabal des autres soirs.
            # Audit du 16/11 : ויהי נועם, שובה, ישב בסתר sous « vihi_noam » (pas le soir du 9 Av ; Kitsour
            # Yalkut Yosef 556:3) ; « ואתה קדוש » et la suite sous « veata_kadoch », dits aussi ce soir-là.
            # Les Edot les disent même quand un Yom tov tombe dans la semaine (Kitsour Yalkut Yosef 294:7).
            if cons[bi] and x.startswith("בכל לילות החול מלבד מוצאי שבת מדלגים"):
                j = bi
                c = "vihi_noam"
                while j < n and not (cons[j] and "קדיש תתקבל" in txt[j] and j > bi):
                    if not cons[j] and commence(txt[j], "ואתה קדוש"):
                        c = "veata_kadoch"
                    prend(j, c)
                    j += 1
                bi = j
                continue
            # « ה׳ הוא האלהים » des dix jours et de Hochaana Rabba (Edot, Hodou).
            if cons[bi] and x.startswith("בעשרת ימי תשובה והושענא רבה") and bi + 1 < n and not cons[bi + 1]:
                prend(bi, "techouva_hochaana")
                prend(bi + 1, "techouva_hochaana")
                bi += 2
                continue
            # Ce que le siddour fait sauter les jours sans Ta'hanoun : למנצח (Edot), תפלה לדוד
            # (Edot, Sfard ; Sfard ajoute : sans אל ארך אפים, pas de בית יעקב non plus), le
            # « רבונו של עולם » après la Akéda (Sfard).
            if office and cons[bi] and bi + 1 < n and not cons[bi + 1] and (
                    x.startswith("ביום שאין אומרים בו תחנון מדלגים למנצח")
                    or x.startswith("בימים שאין אומרים תחנון אין אומרים תפלה לדוד")
                    or x.startswith("ביום שאין אומרים תחנון אין אומרים זה")):
                prend(bi, "tahanoun_" + office)
                prend(bi + 1, "tahanoun_" + office)
                j = bi + 2
                if "גם בית יעקב אין אומרים" in x and j < n and not cons[j] and commence(txt[j], "בית יעקב"):
                    prend(j, "lamnatseah")
                    j += 1
                bi = j
                continue
            # למנצח (Ashkenaz, Sfard) : pas les jours que le siddour énumère (Sfard, Achré :
            # « ר״ח חנוכה ופורים ערב פסח וערב יו״כ ותשעה באב… י״ד וט״ו באדר ראשון ») ; avec lui,
            # les consignes qui le précèdent.
            if nusah != "edot" and office == "chaharit" and not cons[bi] and commence(x, "למנצח מזמור לדוד יענך"):
                k = bi
                while k > 0 and cons[k - 1] and k - 1 not in pris:
                    k -= 1
                for m in range(k, bi + 1):
                    prend(m, "lamnatseah")
                bi += 1
                continue
            # « לדוד ה׳ אורי » des Edot (audit du 16/11), imprimé chaque jour après עלינו sans consigne :
            # « מנהג יפה… מראש חודש אלול עד הושענא רבא » (Kitsour Yalkut Yosef, après le siman 581, §2) ;
            # en clair ces jours-là, replié les autres (le 'Hida le dit toute l'année : dépliable).
            if nusah == "edot" and office == "chaharit" and not cons[bi] and bi not in pris \
                    and commence(x, "לדוד") and "יהוה אורי" in x[:40]:
                prend_discret(bi, "ledavid", "ajout_ledavid")
                bi += 1
                continue
            # Le Vidouï du Chema du coucher (Edot ; audit du 16/11) : pas le Chabbat, les jours sans
            # Ta'hanoun, au motsaé Chabbat, de Yom tov ni de Roch 'Hodech (consigne du siddour ; Kitsour
            # Yalkut Yosef, ק״ש שעל המטה בליל שבת §ב). La consigne et le Vidouï, sous « vidui_coucher ».
            if texte_id == "chema_coucher" and cons[bi] and x.startswith("יעמוד ויאמר וידוי") and bi + 1 < n and not cons[bi + 1]:
                prend_discret(bi, "vidui_coucher", "ajout_vidui_coucher")
                prend_discret(bi + 1, "vidui_coucher", "ajout_vidui_coucher")
                bi += 2
                continue
            # La nuit du Séder (Ashkenaz, Sfard ; audit du 16/11) : on ne dit que la section du Chema et
            # המפיל, « ולא שאר דברים שקורין בשאר הלילות » (Rema O.H. 481:2), les deux nuits en diaspora ;
            # de ויהי נועם à la fin, replié. Les Edot sont conformes (Yalkut Yosef 480 §10).
            if texte_id == "chema_coucher" and nusah != "edot" and not cons[bi] and commence(x, "ויהי נעם"):
                for k in range(bi, n):
                    prend_discret(k, "!leil_haseder", "ajout_sauf_leil_haseder")
                bi = n
                continue
            # La Méguila (audit du 16/11) : les Edot ne refont pas שהחיינו le jour (Kitsour Yalkut Yosef 692:1,
            # « וביום אינו חוזר לברך שהחיינו ») ; la consigne et la bénédiction, la nuit seulement. Sfard et
            # Ashkenaz la redisent le jour (Rema O.H. 692:1, consigne de leur siddour), mais « אשר הניא » ne se dit
            # que la nuit (Rema ; « בשחרית מתחילין שושנת יעקב ») : de « אשר הניא » à « שושנת יעקב », la nuit.
            if texte_id == "megila" and nusah == "edot" and cons[bi] and x.startswith("בליל פורים") and bi + 1 < n \
                    and not cons[bi + 1] and "שהחינו" in txt[bi + 1]:
                prend_discret(bi, "nuit", "ajout_nuit_megila")
                prend_discret(bi + 1, "nuit", "ajout_nuit_megila")
                bi += 2
                continue
            if texte_id == "megila" and nusah != "edot" and not cons[bi] and txt[bi].startswith("א שר הניא"):
                j = bi
                while j < n and not cons[j] and not txt[j].startswith("ש ושנת יעקב"):
                    prend_discret(j, "nuit", "ajout_nuit_megila")
                    j += 1
                bi = j
                continue
            # La fin de Cha'harit du 9 Av (Ashkenaz ; audit du 16/11) : pas de פטום הקטורת (Rema O.H.
            # 559:4) ; celui des korbanot reste (différence entre poskim).
            if nusah == "ashkenaz" and office == "chaharit" and titre == "סיום תפילה" and not cons[bi] and bi not in pris \
                    and commence(x, "אתה הוא") and "קטרת" in x:
                j = bi
                while j < n and not cons[j] and (j == bi or commence(txt[j], "פטום הקטרת") or commence(txt[j], "רבן שמעון")):
                    prend_discret(j, "!ticha_beav", "ajout_sauf_ticha_beav")
                    j += 1
                bi = j
                continue
            # « לדוד ה׳ אורי » : « ובפרט מר״ח אלול עד הושענא רבא » dit la consigne ; le psaume et
            # son Kaddich, repliés le reste de l'année.
            if cons[bi] and x.startswith("מנהג טוב לומר אחר כל תפלה מזמור לדוד"):
                prend(bi, "ledavid")
                j = bi + 1
                if j < n and not cons[j] and commence(txt[j], "לדוד יהוה אורי"):
                    prend(j, "ledavid")
                    j += 1
                    while j < n and ((cons[j] and txt[j] == "(קדיש יתום)") or
                                     (not cons[j] and any(commence(txt[j], k) for k in KADDICH))):
                        prend(j, "ledavid")
                        j += 1
                bi = j
                continue
            # Le zimoun (29/10, « fais en sorte que le zimun se replie ») : seulement à trois
            # convives ou plus, jamais du jour, toujours replié (dépliable). De sa consigne
            # (« שלושה שאכלו כאחד חייבין בזימון », Edot « אם המסובים שלושה ») jusqu'à la
            # première bénédiction, « ברוך אתה… הזן », qui se dit toujours ; le zimoun des
            # noces (Sfard) est dedans.
            if texte_id == "birkat_hamazon" and cons[bi] and (
                    x.startswith("שלושה שאכלו כאחד חייבין בזימון") or x.startswith("אם המסובים שלושה")):
                fin = bi
                while fin < n and not (not cons[fin] and commence(txt[fin], "ברוך אתה")):
                    fin += 1
                # La consigne qui annonce la première bénédiction (Ashkenaz : « ברכה זו משה
                # רבינו… תקנה ») est à elle, pas au zimoun.
                while fin - 1 > bi and cons[fin - 1]:
                    fin -= 1
                for j in range(bi, fin):
                    prend(j, "zimun")
                bi = fin
                continue
            # Les Chéva bérakhot de la table (28/10, tools/siddur_cheva_berakhot.py) : à la fin de
            # Birkat haMazon, jamais un jour du calendrier, toujours repliées (dépliables).
            if cons[bi] and x.startswith("בסעודת שבע ברכות"):
                j = bi
                while j < n and not (cons[j] and txt[j].startswith("דיני שכחה")):
                    prend(j, "cheva_berakhot")
                    j += 1
                bi = j
                continue
            # La maison endeuillée : jamais un jour du calendrier, toujours replié (dépliable).
            if cons[bi] and x.startswith("בבית האבל"):
                j = bi
                while j < n and (j == bi or not cons[j] or txt[j] == "(קדיש יתום)"
                                 or txt[j].startswith("ובימים שאין בהם תחנון")):
                    prend(j, "beit_avel")
                    j += 1
                bi = j
                continue
            # La bénédiction des Cohanim à Min'ha, les jeûnes publics seulement, jusqu'à « שים שלום ».
            if cons[bi] and re.search(r"בתענית ציבור.*ברכת כהנים", x):
                if bi > 0 and cons[bi - 1] and txt[bi - 1] == "ברכת כהנים" and bi - 1 not in pris:
                    prend(bi - 1, "jeune", JEUNE)
                j = bi
                while j < n and (j == bi or not (
                        (not cons[j] and (commence(txt[j], "שים שלום") or commence(txt[j], "שלום רב")
                                          or txt[j].startswith("לתענית ציבור")))
                        or (cons[j] and (txt[j] in ("שלום", "שים שלום") or txt[j].startswith("בעשי״ת"))))):
                    prend(j, "jeune", JEUNE)
                    j += 1
                # « שלום רב », quand le siddour donne ensuite « לתענית ציבור: שים שלום » (Ashkenaz, Min'ha) :
                # pas les jours de jeûne public, où l'on dit שים שלום avec ברכת כהנים ; en clair les autres
                # jours (audit du 16/11 ; Rema 127:2, Michna Beroura 127:12).
                if j + 1 < n and not cons[j] and commence(txt[j], "שלום רב") and txt[j + 1].startswith("לתענית ציבור"):
                    prend_discret(j, "!jeune", "ajout_hors_jeune_public")
                    j += 1
                bi = j
                continue
            # Les versets ajoutés après le Hallel de Roch 'Hodech (Sfard).
            if cons[bi] and x.startswith("יש נוהגין לומר בר״ח אחר הלל"):
                j = bi
                while j < n and (j == bi or not cons[j]):
                    prend(j, "roch_hodech")
                    j += 1
                bi = j
                continue
            # Ya'alé véyavo, ses variantes, jusqu'à « חנון ורחום אתה ».
            if not cons[bi] and commence(x, "אלהינו ואלהי אבותינו יעלה ויבא"):
                en_tete(bi, "yaale_veyavo", "אומרים")
                j = bi
                while j < n:
                    var = next((c for r, c in VARIANTES_YAALE if re.search(r, txt[j])), None)
                    prend(j, var or "yaale_veyavo")
                    if "חנון ורחום אתה" in txt[j] or (j > bi and cons[j] and var is None):
                        break
                    j += 1
                bi = j + 1
                continue
            # Al hanissim, puis ses parties de 'Hanouka et de Pourim.
            if not cons[bi] and (commence(x, "על הנסים ועל הפרקן") or commence(x, "ועל הנסים ועל הפרקן")):
                en_tete(bi, "al_hanissim", "חנוכה")
                # Birkat haMazon (Sfard, Ashkenaz) : la note « בחנוכה ופורים אומרים כאן על הניסים… »
                # est un paragraphe, pas une consigne ; elle suit Al hanissim (12/11).
                if bi > 0 and not cons[bi - 1] and txt[bi - 1].startswith("בחנוכה ופורים אומרים כאן על הניסים"):
                    prend(bi - 1, "al_hanissim")
                prend(bi, "al_hanissim")
                j = bi + 1
                while j < n:
                    y = txt[j]
                    if y.startswith("בחנוכה") or commence(y, "בימי מתתיהו") or commence(y, "בימי מתתיה"):
                        prend(j, "hanouka")
                    elif y.startswith("בפורים") or commence(y, "בימי מרדכי"):
                        prend(j, "pourim")
                    else:
                        break
                    j += 1
                bi = j
                continue
            # Anénou, les jours de jeûne.
            if not cons[bi] and (re.search(r"עננו (אבינו|יהוה) עננו ביום צום", x)):
                c, libelle = anenou(bi)
                en_tete(bi, c, "תענית", libelle=libelle)
                prend(bi, c, libelle)
                if libelle == "ajout_anenou_officiant":
                    sceau(bi, c, r"ברוך אתה \S+,? העונה (לעמו ישראל )?בעת צרה", libelle)
            elif cons[bi] and re.fullmatch(r"\(?בתענית ציבור אומר כאן הש״ץ עננו ?\)?:?", x):
                prend(bi, "jeune", "ajout_anenou_officiant")
            # Avinou malkénou des jeûnes et des dix jours (Ashkenaz, Sfard) : la consigne
            # « … אומרים כאן אבינו מלכנו » et toute la suite, en un seul groupe ; ses lignes
            # propres à un seul des deux en sont des variantes, estompées l'autre jour
            # (SOUS ; relevé du 14/10).
            elif cons[bi] and "אומרים כאן אבינו מלכנו" in x:
                # À Min'ha, seulement si Ta'hanoun s'y dit (audit du 12/11, TSIDDUR-09) : pas la veille de Pourim,
                # le vendredi, ni à Min'ha de la veille de Kippour un vendredi ; Roch Hachana et Kippour gardent
                # le leur (SiddurJour.conditionsPour).
                am = "avinou_malkenou_minha" if office == "minha" else "avinou_malkenou"
                prend(bi, am)
                j = bi + 1
                sous = None
                souche = None
                while j < n:
                    y = txt[j]
                    if cons[j]:
                        # Les lignes des jeûnes (« ברך עלינו », « זכרנו ») : pas à Tsom Guedalia, où l'on
                        # dit celles des dix jours (Matté Efraïm 602:13 ; audit du 16/11).
                        if re.fullmatch(r"בתענית ציבור:?", y):
                            sous = "avinou_malkenou_jeune"
                        elif re.fullmatch(r"(בעשי״ת|בעשרת ימי תשובה)( (אומרים|מוסיפים))?:?", y):
                            sous = "asseret_yemei_techouva"
                        else:
                            break
                        souche = None
                        prend(j, sous)
                    elif y.startswith("בתענית ציבור:"):
                        prend(j, "avinou_malkenou_jeune")
                    elif re.match(r"בעשי״ת:", y):
                        prend(j, "asseret_yemei_techouva")
                    elif commence(y, "אבינו מלכנו"):
                        # Une variante ne couvre que ses lignes sœurs (« … כתבנו בספר », « … זכרנו ל ») :
                        # « בטל מעלינו », « הצמח לנו »… se disent dans les deux cas.
                        mots = " ".join(y.split()[:3])
                        if sous and souche is not None and mots != souche:
                            sous = None
                        if sous and souche is None:
                            souche = mots
                        prend(j, sous or am)
                    else:
                        break
                    j += 1
                bi = j
                continue
            # Une consigne courte (« בחנוכה אומרים », « בראש חודש: », « בשבת אומר: »…) et ses blocs.
            elif cons[bi] and any(re.fullmatch(m, x) for m, _ in CONSIGNES_COURTES) and bi + 1 < n and not cons[bi + 1]:
                c = next(c for m, c in CONSIGNES_COURTES if re.fullmatch(m, x))
                # Le psaume de 'Hanouka (Edot, Chir chel yom) : à Roch 'Hodech Tévèt, après Moussaf et ברכי
                # נפשי (audit du 16/11 ; Kitsour Yalkut Yosef 683:11) ; un rappel l'y annonce (RENVOIS).
                if c == "hanouka" and nusah == "edot" and office == "chaharit" and titre == "שיר של יום":
                    c = "hanouka_hors_roch_hodech"
                lib = LIBELLES_CONSIGNE.get(c)
                prend(bi, c, lib)
                j = bi + 1
                # Le Hallel partiel ne saute que le premier bloc annoncé (Ps 115:1-11, 116:1-11) :
                # « יהוה זכרנו » et « מה אשיב » se disent tous les jours de Hallel ; de même,
                # un « הרחמן » de fête n'annonce que sa ligne (12/11 : « בסוכות: » prenait aussi,
                # en Ashkenaz, « הרחמן הוא יזכנו », « עושה שלום » et « יראו », dits chaque jour).
                une_ligne = c in UNE_LIGNE or c == "hallel_complet" or commence(txt[bi + 1], "הרחמן")
                while j < n and not cons[j] and (not une_ligne or j == bi + 1):
                    # « בחנוכה אומרים » annonce Al hanissim, pas la fin de Modim (12/11 : « ועל כלם »
                    # et « הטוב שמך » du Moussaf de Roch 'Hodech étaient repliés hors de 'Hanouka).
                    if j > bi + 1 and (commence(txt[j], "ועל כלם") or commence(txt[j], "ועל כולם")):
                        break
                    prend(j, c, lib)
                    j += 1
                bi = j
                continue
            # Le psaume du jour (16/10) : seul celui du jour reste ouvert. Ashkenaz et Sfard :
            # « בראשון בשבת: », son en-tête et son psaume, et le renvoi « (הושיענו וכו׳…) » qui
            # suit ; Edot : « מזמור ליום ראשון … » et son psaume.
            elif cons[bi] and re.fullmatch(r"ב(ראשון|שני|שלישי|רביעי|חמישי|שישי|ששי) בשבת:?", x):
                c = JOURS_SEMAINE[re.fullmatch(r"ב(\S+) בשבת:?", x).group(1)]
                prend(bi, c)
                j = bi + 1
                while j < n and not cons[j] and j <= bi + 2:
                    prend(j, c)
                    j += 1
                if j < n and cons[j] and txt[j].startswith("(הושיענו"):
                    prend(j, c)
                    j += 1
                bi = j
                continue
            elif not cons[bi] and re.match(r"מזמור ליום (ראשון|שני|שלישי|רביעי|חמישי|שישי|ששי)\b", x) and bi + 1 < n and not cons[bi + 1]:
                c = JOURS_SEMAINE[re.match(r"מזמור ליום (\S+)", x).group(1)]
                prend(bi, c)
                prend(bi + 1, c)
                bi += 2
                continue
            # Le retour du Sefer Torah (12/11) : « יהללו », « הודו », « לדוד מזמור », « ובנחה יאמר »
            # ne se disent que les jours de lecture ; Edot et Sfard les ont après Achré ou Ouva
            # létsion, hors de la section de lecture (Ashkenaz les y a déjà).
            elif cons[bi] and office == "chaharit" and re.search(r"(מחזירין את ספר התורה|כשמחזירים הס״ת|שמוציאין ספר תורה אומרים יהללו)", x):
                prend(bi, "kriat_hatorah")
                j = bi + 1
                while j < n and (cons[j] or any(commence(txt[j], m) for m in ("יהללו", "הודו", "לדוד מזמור", "ובנחה יאמר"))):
                    prend(j, "kriat_hatorah")
                    j += 1
                bi = j
                continue
            # Barekhi nafchi à Roch 'Hodech, dans la même section que le psaume du jour (Ashkenaz).
            elif cons[bi] and "ברכי נפשי בראש חדש" in x:
                prend(bi, "roch_hodech")
                j = bi + 1
                while j < n and not cons[j]:
                    prend(j, "roch_hodech")
                    j += 1
                bi = j
                continue
            # Ashkenaz : Na'hem au Birkat pour qui mange le 9 Av (audit du 16/11 ; Rema O.H. 557:1).
            elif cons[bi] and texte_id == "birkat_hamazon" and x.startswith("מי שאוכל בתשעה באב"):
                prend(bi, "ticha_beav")
            # Na'hem, le 9 Av.
            elif not cons[bi] and commence(x, "נחם יהוה אלהינו"):
                en_tete(bi, "ticha_beav", "באב")
                nahem(bi)
            # Na'hem annoncé dans son propre bloc (Edot, Min'ha : « בתשעה באב אומרים: נחם » ; relevé le 14/10).
            elif not cons[bi] and re.match(r"בתשעה באב (יש )?אומרים:? ?נחם", x):
                nahem(bi)
            # Avinou malkénou des jeûnes (Ashkenaz : « בתענית ציבור: אבינו מלכנו ברך עלינו » ; relevé le 14/10).
            elif not cons[bi] and (x.startswith("בתענית ציבור:") or x.startswith("לתענית ציבור:")):
                prend(bi, "jeune", JEUNE)
            # Les ajouts du jour annoncés dans leur bloc (Méèn chaloch, relevés le 14/10 et le 29/10 :
            # « il y a des choses qui ne sont pas repliées ») : Chabbat, Roch 'Hodech, Roch haChana,
            # les fêtes ; Ashkenaz en lignes (tools/siddur_meen_chaloch.py), où « ושמחנו ביום » ouvre le
            # groupe des fêtes et chacune y est une variante (SOUS).
            elif not cons[bi] and texte_id == "meen_chaloch" and any(re.match(r, x) for r, _ in MEEN_CHALOCH):
                prend(bi, next(c for r, c in MEEN_CHALOCH if re.match(r, x)))
            elif not cons[bi] and re.match(r"בשבת ורצה", x):
                prend(bi, "chabbat")
            elif not cons[bi] and re.match(r"בראש ?חודש וזכרנו", x):
                prend(bi, "roch_hodech")
            # Edot, Havdala : les lignes de 'Hol hamoèd, comme celle de Roch 'Hodech (TSIDDUR-17).
            elif not cons[bi] and texte_id == "havdala" and re.match(r"חוה[\"'״׳]*מ פסח ושמחנו", x):
                prend(bi, "pessah")
            elif not cons[bi] and texte_id == "havdala" and re.match(r"חוה[\"'״׳]*מ סוכות ושמחנו", x):
                prend(bi, "soukkot")
            # Edot, Min'ha : la formule d'acceptation d'un jeûne individuel, qui n'est pas du jour (TSIDDUR-17).
            elif not cons[bi] and re.match(r"הרוצה להתענות תענית יחיד", x):
                prend(bi, "facultatif", "ajout_avant_jeune_individuel")
            # La prière de Rav Chéchèt, « ביום תענית יאמר רבון העולמים » (Edot, Min'ha ; relevé le 14/10).
            elif not cons[bi] and re.match(r"ביום תענית (יאמר|אומרים)", x):
                prend(bi, "jeune", JEUNE)
            # Été, hiver : la consigne seule, puis son bloc.
            elif cons[bi] and x in ETE + HIVER and bi + 1 < n and not cons[bi + 1]:
                y = txt[bi + 1]
                if x in ETE:
                    c = "morid_hatal" if "מוריד הטל" in y else "berakha"
                else:
                    c = "machiv_harouah" if "משיב הרוח" in y else "tal_oumatar"
                prend(bi, c)
                prend(bi + 1, c)
                bi += 2
                continue
            # Été, hiver : la consigne et sa variante dans le même bloc (Arvit
            # ashkénaze, « בימות החמה: ברכה » ; relevé le 14/10).
            # Aussi « בקיץ - מוריד הטל: » (Moussaf ashkénaze ; vérification de Roch 'Hodech, 28/10).
            elif not cons[bi] and any(x.startswith(e + " ") or x.startswith(e.rstrip(":") + " - ") for e in ETE + HIVER) \
                    and not (any(e.rstrip(":") in x for e in ETE) and any(h.rstrip(":") in x for h in HIVER)):
                if any(x.startswith(e.rstrip(":")) for e in ETE):
                    c = "morid_hatal" if "מוריד הטל" in x else "berakha"
                else:
                    c = "machiv_harouah" if "משיב הרוח" in x else "tal_oumatar"
                prend(bi, c)
            # Les dix jours : la consigne courte, puis son bloc ; ou le bloc qui
            # s'annonce lui-même (« בעשי״ת: זכרנו לחיים »).
            elif cons[bi] and re.fullmatch(r"(בעשי״ת|בעשרת ימי תשובה)( (מסיים|יסיים|אומרים|מוסיפים|מוסיפין))?:?", x) \
                    and bi + 1 < n and not cons[bi + 1]:
                # ממעמקים (Edot, Cha'harit) : aussi à Hochaana Rabba (Kitsour Yalkut Yosef 664 §6 ; audit
                # du 16/11) ; Ashkenaz et Sfard s'en tiennent aux dix jours (Michna Beroura 54:4).
                dix = "techouva_hochaana" if nusah == "edot" and office == "chaharit" and "ממעמקים" in txt[bi + 1][:50] \
                    else "asseret_yemei_techouva"
                prend(bi, dix)
                j = bi + 1
                # Avinou malkénou des Edot le Chabbat (Roch Hachana, Chabbat Chouva) : « מדלגים חטא ועון,
                # כגון אבינו מלכנו חטאנו לפניך, וכן מחול וסלח לכל עוונותינו » (Kitsour Yalkout Yossef 582/602:24 ;
                # audit du 16/11). Ces lignes, estompées le Chabbat (variante « !chabbat »).
                faute = lambda k: nusah == "edot" and FAUTES.match(txt[k])
                prend(j, "!chabbat" if faute(j) else dix)
                ordinaire(bi, txt[j])
                # Avinou malkénou annoncé par la consigne (Edot) : toute la suite.
                while commence(txt[j], "אבינו מלכנו") and j + 1 < n and not cons[j + 1] \
                        and commence(txt[j + 1], "אבינו מלכנו"):
                    j += 1
                    prend(j, "!chabbat" if faute(j) else "asseret_yemei_techouva")
                bi = j + 1
                continue
            elif not cons[bi] and re.match(r"בעשי״ת( (מסיים|יסיים))?:", x):
                prend(bi, "asseret_yemei_techouva")
                ordinaire(bi, x)
            # Retsé, le Chabbat (Birkat hamazone).
            elif not cons[bi] and commence(x, "רצה והחליצנו"):
                en_tete(bi, "chabbat", "בשבת")
                prend(bi, "chabbat")
            # « אתה חוננתנו » en bloc à part (Sefard, Ashkenaz), sans consigne : motsaé Chabbat
            # et Yom Tov (28/10 ; les Edot ont la consigne « במוצאי שבת ויום טוב אומרים »).
            elif not cons[bi] and re.match(r"\(?אתה חוננתנו", x) and bi not in pris:
                prend(bi, "motsae_chabbat_yt")
            # Le Hallel annoncé après l'Amida.
            # Ashkenaz (audit du 16/11) : la consigne qui annonce aussi les Seli'hot des jeûnes et le
            # demi-Kaddich des jours sans Ta'hanoun (« … בת״צ אומרים סליחות ») reste en clair.
            elif cons[bi] and "אומרים כאן הלל" in x and "סליחות" not in x:
                prend(bi, "hallel")
            # « Les jours sans Ta'hanoun » : la consigne et le bloc qui suit.
            elif cons[bi] and x.startswith("בימים שאין בהם תחנון") and office and bi + 1 < n:
                prend(bi, "!tahanoun_" + office)
                prend(bi + 1, "!tahanoun_" + office)
                bi += 2
                continue
            # Les variantes enchâssées : un repère, rien de replié.
            if bi not in pris and not cons[bi]:
                brut = sec["blocs"][bi].get("t", "")
                # Le 9 Av, on saute « ואני זאת בריתי » (Kitsour Yalkut Yosef 559:14 ; Kitsour Choul'han
                # Aroukh 124:3 ; audit du 16/11) : le verset est retiré ce jour-là, une ligne le rend.
                if office == "chaharit" and commence(x, "ובא לציון"):
                    verset = passage(brut, "ואני זאת בריתי", "ועד עולם")
                    if verset:
                        note("indice", si, bi, "!ticha_beav", {"texte": "וַאֲנִי זֹאת בְּרִיתִי", "retire": verset,
                                                               "libelle": "ajout_sauf_ticha_beav"})
                # « יהי רצון… וחולאים רעים » après « רבונו של עולם » (Edot, Chema du coucher ; audit du
                # 16/11) : pas le Chabbat ni le Yom tov, dit la consigne (« באותיות הקטנות », que le texte
                # source n'a pas). Le découpage n'est pas vérifié sur une édition imprimée.
                if texte_id == "chema_coucher" and commence(x, "רבונו של עולם הריני מוחל וסולח"):
                    yehi = passage(brut, "יהי רצון", "וחולאים רעים")
                    if yehi:
                        note("indice", si, bi, "!chome", {"texte": "יְהִי רָצוֹן", "retire": yehi,
                                                         "libelle": "ajout_sauf_chabbat_yom_tov"})
                # המפיל après l'aube (Sfard, Ashkenaz ; Biour Halakha 239, « סמוך למטתו ») : un repère
                # permanent sous la bénédiction ; l'heure n'est pas une condition du jour.
                if texte_id == "chema_coucher" and nusah != "edot" and commence(x, "ברוך אתה יהוה אלהינו מלך העולם המפיל"):
                    note("indice", si, bi, "!minyan", {"texte": HAMAPIL_APRES_AUBE})
                retraits = sorted((m.start(), m.group(0)) for r in RETIRE for m in re.finditer(r, brut))
                trouves = sorted((m.start(), c, m.group(1).strip(" ,.")) for motif, c in INDICES
                                 for m in re.finditer(motif, x) if m.group(1).strip(" ,."))
                # Le passage brut à replier hors du jour (demande du 28/10) : apparié dans
                # l'ordre du texte, et seulement si les deux comptes s'accordent.
                apparie = len(retraits) == len(trouves)
                for k, (_, c, variante) in enumerate(trouves):
                    extra = {"texte": variante}
                    if apparie:
                        extra["retire"] = retraits[k][1]
                        # La variante exacte est dans le brut (« הַשָּׁלוֹם » seul, pas la suite).
                        interne = re.match(r"<small>\s*(?:<small>[^<]*</small>|בעשרת ימי תשובה [^<:]*:)([^<]*)</small>", extra["retire"])
                        if interne and nu(interne.group(1)).strip(" ,.:"):
                            extra["texte"] = nu(interne.group(1)).strip(" ,.:")
                    note("indice", si, bi, c, extra)
                # « מגדול » pour « מגדיל » à la fin du Birkat (12/11) : Edot, « ביום שמתפללים מוסף » ;
                # Ashkenaz, « בשבת וביו״ט ». Un repère du jour, rien de replié ; une condition par jour
                # de Moussaf (Chabbat, Roch 'Hodech, fêtes et 'Hol hamoed, Yom tov). Motsaé Chabbat,
                # que les Edot nomment aussi, n'est pas un jour du calendrier : il n'est pas repéré.
                if texte_id == "birkat_hamazon" and re.search(r"\( ?(ביום שמתפללים מוסף|בשבת וביו״ט)[^:]*: ?מגדול", x):
                    # Ashkenaz et Sfard, aussi Roch 'Hodech (audit du 16/11 : Michna Beroura 189:5 ; Choul'han
                    # Aroukh haRav 189:7), que la consigne imprimée ne nomme pas : une note le dit (NOTES).
                    jours = ("chabbat", "roch_hodech", "moed", "yom_tov") if "מוסף" in x else ("chabbat", "yom_tov", "roch_hodech")
                    for c in jours:
                        note("indice", si, bi, c, {"texte": "מִגְדּוֹל"})
                if re.fullmatch(r"בקיץ: מוריד הטל\. בחורף: משיב הרוח ומוריד הגשם\.?", x):
                    brut = sec["blocs"][bi]["t"]
                    k = brut.index("<small>בחורף")
                    note("indice", si, bi, "morid_hatal", {"texte": "מוריד הטל", "retire": brut[:k]})
                    note("indice", si, bi, "machiv_harouah", {"texte": "משיב הרוח ומוריד הגשם", "retire": brut[k:]})
                if texte_id == "moussaf_rosh_hodech" and "t" in sec["blocs"][bi]:
                    kapara = kapparat_pecha(sec["blocs"][bi]["t"], nusah)
                    if kapara:
                        note("indice", si, bi, kapara[0], {"texte": "וּלְכַפָּרַת פֶּשַׁע", "retire": kapara[1]})
            bi += 1
        if office or texte_id in TEXTES_MINYAN:
            minyan(txt, cons, pris, prend)
    if texte_id == "birkat_hamazon":
        facultatif(sections, sortie, note)
    reperes(texte_id, sections, nusah, sortie, note)
    if office or texte_id in TEXTES_MINYAN:
        double_annotation(texte_id, sections, nusah, sortie)
    # La passe « minyan » ajoute ses blocs après les autres : grouper veut l'ordre du texte.
    sortie.sort(key=lambda e: (e["s"], e.get("b", -1)))
    grouper(sortie)
    sortie += seul(texte_id, sections, sortie)
    for e in sortie:
        e.pop("_force", None)
    return sortie


# --- Audit du 16/11, « Birkat haMazon et bénédictions » -------------------------------------
# La Havdala (Choul'han Aroukh O.H. 556:1, 491:1 et 624:3-5 ; Michna Beroura 556:1-5 ; Kitsour
# Yalkut Yosef 556:6-8 et 624:4-6) : au samedi soir du 9 Av, la flamme seule ; à la sortie du jeûne
# (un dimanche), la coupe seule ; à la sortie d'un Yom tov de semaine, ni flamme ni bessamim. Tout
# est « discret » : en clair, sans étiquette, les soirs où il se dit ; replié les autres.
def havdala(txt, cons, prend_discret):
    for k, x in enumerate(txt):
        # La consigne du siddour Edot (« במוצאי יו״ט שאינו מוצ״ש אין מברכים… ») vaut toujours ; Roch
        # 'Hodech et 'Hol hamoed dans la bénédiction finale ont leurs règles plus bas (TSIDDUR-17).
        if (cons[k] and x.startswith("במוצאי יו״ט שאינו מוצ״ש")) or re.match(r"(חוה״מ (פסח|סוכות)|בראש חודש) ", x):
            continue
        if "מאורי האש" in x or (cons[k] and x.startswith("כשיברך על הנר")):
            prend_discret(k, "havdala_ner", "ajout_havdala_ner")
        elif not cons[k] and "בשמים" in x:
            prend_discret(k, "havdala_bessamim", "ajout_havdala_bessamim")
        else:
            prend_discret(k, "!ticha_beav", "ajout_havdala_coupe")


# Les notes de l'application (sorte « note », SiddurJour.Sorte.NOTE) : sous un bloc, quand leur
# condition vaut ; le texte du siddour n'est pas touché. TOUJOURS : « minyan » n'est jamais une
# condition du jour, sa négation vaut toujours (comme les cartes « seul »).
TOUJOURS = "!minyan"
E, S, A = ("edot",), ("sefard",), ("ashkenaz",)
SA = S + A

HAVDALA_TICHA_BEAV = ("במוצאי שבת שחל בו תשעה באב (או שנדחה ליום ראשון): כשרואה הנר מברך ״בורא מאורי האש״ בלבד, בלי כוס "
                      "ובלי בשמים; ומבדילים על הכוס במוצאי התענית, בלי נר ובלי בשמים (שו״ע תקנו, א; מ״ב שם; ילקוט יוסף תקנו, ו-ח).")
HAVDALA_DIMANCHE = ("במוצאי תשעה באב שחל (או שנדחה) ביום ראשון: מבדילים על הכוס בלבד, בלי נר ובלי בשמים "
                    "(שו״ע תקנו, א; מ״ב שם ס״ק ה; ילקוט יוסף תקנו, ח).")
HAVDALA_KIPPOUR = ("במוצאי יום הכפורים אין מברכים על הבשמים בהבדלה, אפילו כשחל בשבת, וטוב לברך עליהם אחר הטעימה; "
                   "ועל הנר מברכים רק על נר ששבת (וכשחל בשבת, אם אין, על נר שהודלק עתה) (שו״ע תרכד, ג-ה; ילקוט יוסף תרכד, ד-ו).")

APRES_NUIT = {
    "edot": ("סעודה שהתחילה ביום (שבת, ראש חודש, יום טוב, חול המועד, חנוכה או פורים) ונמשכה אחר צאת הכוכבים: אם לא התפלל "
             "ערבית באמצע הסעודה, מזכיר בברכת המזון מעין המאורע של אותו יום, אף שהוא מקופל כאן הערב. ובמוצאי שבת שהוא ראש "
             "חודש, אומר ״רצה״ בלבד (ילקוט יוסף קפח, טז, יט; תכד, ג)."),
    "ashkenaz": ("סעודה שהתחילה ביום (שבת, ראש חודש, יום טוב, חול המועד, חנוכה או פורים) ונמשכה אחר צאת הכוכבים: אם לא התפלל "
                 "ערבית, מזכיר מעין המאורע של אותו יום, אף שהוא מקופל כאן הערב (שו״ע קפח, י; מ״ב שם ס״ק לב-לד). ובמוצאי שבת "
                 "שהוא ראש חודש: אם אכל פת בלילה, ״יעלה ויבוא״ בלבד; ואם לאו, ״רצה״ בלבד (מ״ב קפח ס״ק לג)."),
    "sefard": ("סעודה שהתחילה ביום (שבת, ראש חודש, יום טוב, חול המועד, חנוכה או פורים) ונמשכה אחר צאת הכוכבים: אם לא התפלל "
               "ערבית, מזכיר מעין המאורע של אותו יום, אף שהוא מקופל כאן הערב. ובמוצאי שבת שהוא ראש חודש, אם אכל כזית פת "
               "בלילה, אומר שניהם (שו״ע הרב קפח, יז)."),
}

MEKOM_GIDOUL = ("הולכים אחר מקום גידול הפרי: פרי ארץ ישראל, אף כשאוכלו בחו״ל — ״פרותיה״ / ״פרי גפנה״; פרי חו״ל, אף "
                "כשאוכלו בארץ, או כשאינו יודע — ״הפרות״ / ״פרי הגפן״ (שו״ע רח, י; מ״ב שם ס״ק נב-נד).")

YY_PERAS = ("לדעת הילקוט יוסף (רז, א-ב), שיעור ״כדי אכילת פרס״ לברכה אחרונה הוא כ־7.5 דקות; ובדברים שמן התורה טוב להחמיר "
            "לאכול כזית בארבע דקות.")

NOTES = [
    # (noussa'h, texte, début du bloc sans voyelles (None : le premier ; « …$ » devant : le dernier qui commence
    # ainsi), condition, note)
    # La Havdala.
    (E, "havdala", "ברוך אתה יהוה, אלהינו מלך העולם, בורא מאורי האש", "ticha_beav", HAVDALA_TICHA_BEAV),
    (SA, "havdala", "על הנר:", "ticha_beav", HAVDALA_TICHA_BEAV),
    (E, "havdala", "ברוך אתה יהוה, אלהינו מלך העולם, בורא עצי", "lendemain_ticha_beav_dimanche", HAVDALA_DIMANCHE),
    (SA, "havdala", "על הבשמים:", "lendemain_ticha_beav_dimanche", HAVDALA_DIMANCHE),
    (E, "havdala", "ברוך אתה יהוה, אלהינו מלך העולם, בורא עצי", "lendemain_kippour", HAVDALA_KIPPOUR),
    (SA, "havdala", "על הבשמים:", "lendemain_kippour", HAVDALA_KIPPOUR),
    # Birkat haMazon : le soir qui suit un jour d'ajouts, sous les consignes d'oubli.
    (E, "birkat_hamazon", 'אם שכח לומר "רצה"', "lendemain_ajouts", APRES_NUIT["edot"]),
    (S, "birkat_hamazon", "שכח לומר רצה בשבת", "lendemain_ajouts", APRES_NUIT["sefard"]),
    (A, "birkat_hamazon", "שכח לומר רצה בשבת", "lendemain_ajouts", APRES_NUIT["ashkenaz"]),
    # « מגדול » à Roch 'Hodech, que la consigne imprimée ne nomme pas.
    (A, "birkat_hamazon", "הרחמן הוא יזכנו לימות המשיח", "roch_hodech",
     "גם בראש חודש אומרים ״מגדול״ (מ״ב קפט ס״ק ה: ״נוהגים לומר בשבת ויו״ט ור״ח מגדול ובחול מגדיל״)."),
    (S, "birkat_hamazon", "הרחמן הוא יזכנו לימות המשיח", "roch_hodech",
     "גם בראש חודש אומרים ״מגדול״ (שו״ע הרב קפט, ז), אף שהוראת הסידור מזכירה רק שבת ויום טוב."),
    # Ashkenaz, le psaume d'avant le Birkat (Michna Beroura 1:11).
    (A, "birkat_hamazon", "שיר המעלות בשוב", "!tahanoun_chaharit", "היום אומרים ״שיר המעלות בשוב״ לפני ברכת המזון (מ״ב א ס״ק יא)."),
    (A, "birkat_hamazon", "שיר המעלות בשוב", "tahanoun_chaharit", "היום אומרים ״על נהרות בבל״ לפני ברכת המזון (מ״ב א ס״ק יא)."),
    # Méèn chaloch : l'origine du fruit, pas le lieu où on le mange.
    (S, "meen_chaloch", "(על מזונות ויין ביחד:)", TOUJOURS, MEKOM_GIDOUL),
    (A, "meen_chaloch", "…$על פירות משבעת המינים", TOUJOURS, MEKOM_GIDOUL),
    # Edot, le délai de la bénédiction finale (Kitsour Yalkut Yosef 207:1-2).
    (E, "bore_nefachot", "לאחר האכילה אם אכל כזית", TOUJOURS, YY_PERAS),
    (E, "nehenin", "לאחר האכילה אם אכל כזית", TOUJOURS, YY_PERAS),
    # Bein hamétsarim : שהחיינו.
    (E, "nehenin", "ברוך אתה יהוה, אלהינו מלך העולם, שהחינו", "bein_hametsarim",
     "בין המצרים נוהגים להיזהר שלא לאכול פרי חדש ושלא ללבוש בגד חדש שצריך לברך עליהם ״שהחיינו״, עד אחר תשעה באב (ונוהגים עד "
     "י׳ באב); ובשבתות שבינתיים מותר. ולחולה, או לפרי שלא יימצא אחר תשעה באב, מותר (ילקוט יוסף תקנא, ט, יג)."),
    (SA, "nehenin", "ברוך אתה יהוה אלהינו מלך העולם שהחינו", "bein_hametsarim",
     "מי״ז בתמוז עד אחר תשעה באב נוהגים להיזהר שלא לאכול פרי חדש ושלא ללבוש בגד חדש שצריך לברך עליהם ״שהחיינו״; ובשבתות "
     "שבינתיים מותר (אך לא בגד חדש מראש חודש אב). ואין זה אלא מנהג זהירות, ולחולה מותר (שו״ע תקנא, יז; מ״ב שם ס״ק צח-צט)."),
    # Les bougies.
    (E, "nerot_chabbat", None, TOUJOURS,
     "הוראת הסידור לברך בשבת אחר ההדלקה היא כמנהג הבן איש חי (נח, שנה ב, ח, י). לדעת הילקוט יוסף (רסג, לג-לה; תרי, ב; תקיד, "
     "הערה כז) מברכים קודם ההדלקה, בשבת כביום טוב; ומי שהדליקה ולא בירכה, אינה מברכת אחר כך."),
    (E, "nerot_chabbat", "ביום טוב שאומרים שהחיינו בקידוש", TOUJOURS,
     "לדעת הילקוט יוסף (תקיד, ג; תמד, מא) עדיף לצאת ידי ״שהחיינו״ בקידוש; והנוהגות לברך בהדלקה, יברכו אותו אחר שהדליקו לפחות "
     "נר אחד, שלא יהיה הפסק בין ברכת ההדלקה להדלקה."),
    (A, "nerot_chabbat", None, TOUJOURS,
     "נוהגים להדליק, לשים את הידיים לפני הנרות, לברך ואחר כך להסיר את הידיים (רמ״א רסג, ה). ביום טוב יש מברכות קודם ההדלקה "
     "(מ״ב רסג ס״ק כז), ויש שאינן מחלקות בין שבת ליום טוב (מגן אברהם). וכן ביום הכפורים."),
    (S, "nerot_chabbat", None, TOUJOURS,
     "לדעת שו״ע הרב (רסג, ח) מדליקים תחילה ואחר כך מברכים, אף ביום טוב, שלא לחלק בברכה אחת; והמנהג חלוק. וכן ביום הכפורים."),
    (A, "nerot_chabbat", "ליו״ט (חוץ מז׳ וח׳ של פסח)", TOUJOURS,
     "אין חובה לברך ״שהחיינו״ בהדלקה, ובמקום שנהגו אין למחות (מ״ב רסג ס״ק כג)."),
    # La mer, les éclairs, l'arc-en-ciel.
    (SA, "yam", "ברוך אתה יהוה", TOUJOURS,
     "על ים אוקינוס; ויש אומרים אף על הים התיכון (שו״ע רכח, א). ולדעת הרבה אחרונים על הים התיכון מברך ״עושה מעשה בראשית״ "
     "(מ״ב רכח ס״ק ב). ואינו מברך אלא משלשים יום לשלשים יום."),
    (SA, "barakim", "…$ברוך אתה יהוה", TOUJOURS,
     "מברכים תוך כדי דיבור לראיית הברק או לשמיעת הרעם. ראה ברק ושמע רעם יחד — מברך על שניהם ברכה אחת, ״עושה מעשה בראשית״; "
     "ואם לא היו תכופים — על הברק ״עושה מעשה בראשית״ ועל הרעם ״שכחו וגבורתו מלא עולם״ (מ״ב רכז ס״ק ה). ואין מברכים יותר "
     "מפעם אחת ביום, אלא אם כן נתפזרו העבים בינתיים."),
    (SA, "keshet", None, TOUJOURS, "ואסור להסתכל בה ביותר (שו״ע רכט, א)."),
    (A, "keshet", None, TOUJOURS, "ואין כדאי להגיד לחבירו שיש קשת, מטעם מוציא דיבה (מ״ב רכט ס״ק א)."),
    # Le Chema du coucher (Edot).
    (E, "chema_coucher", "בברכה זו לא יאמר בשם ומלכות", TOUJOURS,
     "לדעת הילקוט יוסף (רלט, א, ו) ההולך לישון קודם חצות מברך ״המפיל״ בשם ומלכות, וכן הנשים; אחר חצות — בלי שם ומלכות, "
     "כהוראת הסידור. הוראת הסידור כמנהג הבן איש חי (פקודי, שנה א, יב)."),
    # Le loulav et la soukka.
    (E, "loulav", "בפעם הראשו", TOUJOURS,
     "נשים נוטלות את הלולב בלא ברכה, ונכון שלא יברכו אף ״שהחיינו״ (ילקוט יוסף, דין נשים בנטילת לולב, א)."),
    (SA, "loulav", "בפעם הראשו", TOUJOURS, "נשים מברכות על הלולב, כמנהג לברך על מצות עשה שהזמן גרמא (רמ״א תקפט, ו; יז, ב)."),
    (E, "soukka", "כתוב, בסכת תשבו", TOUJOURS,
     "נשים אינן רשאות לברך ״לישב בסוכה״ (ילקוט יוסף תרמ, א). ולדעת הילקוט יוסף (דיני ישיבה בסוכה, כז) עדיף לברך ״לישב "
     "בסוכה״ מעומד קודם המוציא (ובימים שיש קידוש — בקידוש); והמברכים אחר המוציא, כהוראת הסידור, יש להם על מה שיסמוכו."),
    (S, "soukka", "כתוב, בסכת תשבו", TOUJOURS, "נשים מברכות ״לישב בסוכה״, כמנהג לברך על מצות עשה שהזמן גרמא (רמ״א תקפט, ו)."),
    (A, "soukka", None, TOUJOURS, "נשים מברכות ״לישב בסוכה״, כמנהג לברך על מצות עשה שהזמן גרמא (רמ״א תקפט, ו)."),
    # HaGomel.
    (E, "hagomel", "צריך לברך בפני עשרה", TOUJOURS,
     "נשים חייבות לברך ״הגומל״ לאחר שנתרפאו ממחלה או לאחר לידה, בפני עשרה אנשים (ילקוט יוסף ריט, ז-ח). והטס במטוס שעה "
     "ושתים עשרה דקות ויותר מברך ״הגומל״ כשהגיע לשלום, אף מעל מקום ישוב (שם, כ-כא); מברכים תוך שלושה ימים, ולכתחילה "
     "בקריאת התורה."),
    (A, "hagomel", None, TOUJOURS,
     "נשים: מנהג העולם שאין מברכות; ויש שכתבו שנכון שתברך בפני עשרה, או לפחות בפני נשים ואיש אחד (מ״ב ריט ס״ק ג). "
     "ולענין טיסה במטוס — לפי מנהגו (באשכנז לא נהגו לברך בהולך מעיר לעיר, שו״ע ריט, ז; ויש מחייבים בטיסה)."),
    (S, "hagomel", None, TOUJOURS,
     "ולענין טיסה במטוס — לפי מנהגו (שו״ע ריט, ז: באשכנז לא נהגו לברך בהולך מעיר לעיר; ויש מחייבים בטיסה)."),
    # Birkat haIlanot.
    (E, "birkat_hailanot", None, TOUJOURS,
     "אין מברכים אלא על אילני מאכל כשיש בהם פרחים; די בשני אילנות; ומברכים פעם אחת בשנה (ילקוט יוסף רכו, א, ה, ו). ולדעת "
     "הילקוט יוסף (שם, ד) אומרים ״מזמור בשוב ה׳ את שיבת ציון״ ו״הללויה הללו את ה׳ מן השמים״ אחר הברכה, ומסיימים בקדיש. "
     "ואם לא בירך בניסן, רשאי בדיעבד לברך באייר, כל זמן שהאילנות בפריחתם (שם, י)."),
    (E, "birkat_hailanot", None, "chabbat",
     "מותר לברך ברכת האילנות בשבת, אך לכתחילה עדיף בימות החול, אלא אם כן הוא סוף ניסן (ילקוט יוסף רכו, יג); ויש נמנעים "
     "בשבת (כף החיים רכו, ד)."),
    (E, "birkat_hailanot", None, "yom_tov",
     "מותר לברך ברכת האילנות ביום טוב, אך לכתחילה עדיף בימות החול, אלא אם כן הוא סוף ניסן (ילקוט יוסף רכו, יג); ויש נמנעים "
     "(כף החיים רכו, ד)."),
    (A, "birkat_hailanot", None, TOUJOURS, "אם לא בירך בניסן, יכול לברך אחר כך כל זמן שלא גדלו הפירות (מ״ב רכו ס״ק ה)."),
    # 'Hanouka : l'ordre d'allumage.
    (E, "nerot_hanouka", "אחר שידליק נר אחד", TOUJOURS,
     "בלילה הראשון מדליק את הנר הקיצוני שמימין, ובכל לילה מדליק תחילה את הנר הנוסף, ואחר כך את הנרות שמשמאלו; ואם אין "
     "מזוזה מימין, להפך (ילקוט יוסף תרעו, יט-כ)."),
    (A, "nerot_hanouka", None, TOUJOURS,
     "סדר ההדלקה: מתחיל בנר הנוסף — יש מסדרים את הנרות מימין ויש משמאל, ודעביד כמר עביד ודעביד כמר עביד (מ״ב תרעו ס״ק ט)."),
]


def notes(nusah, texte, annotations):
    """Les notes de [texte] pour [nusah], sous leur bloc ; sous le dernier bloc du groupe s'il est dans un groupe."""
    sortie = []
    for noussah, id_, debut, cond, contenu in NOTES:
        if nusah not in noussah or id_ != texte["id"]:
            continue
        cherche = (debut or "").removeprefix("…$")
        places = [(si, bi) for si, s in enumerate(texte["sections"]) for bi, b in enumerate(s["blocs"])
                  if debut is None or nu(b.get("t") or b.get("c")).replace("''", "״").startswith(cherche)]
        if not places:
            raise ValueError(f"{nusah}/{id_} : pas de bloc « {debut} »")
        si, bi = places[-1] if debut and debut.startswith("…$") else places[0]
        a = next((e for e in annotations if e["sorte"] == "bloc" and e["s"] == si and e["b"] == bi), None)
        if a is not None:
            bi = max(e["b"] for e in annotations if e["sorte"] == "bloc" and e["s"] == si and e.get("g") == a["g"])
        bloc = texte["sections"][si]["blocs"][bi]
        sortie.append({"sorte": "note", "s": si, "b": bi, "si": cond, "empreinte": nu(bloc.get("t") or bloc.get("c"))[:40],
                       "texte": contenu})
    return sortie


# Ce qui ne se dit qu'avec un minyan (demande du 19/10) : « כל דבר שבקדושה, כגון קדיש וברכו
# וקדושה, אין אומרים אותו בפחות מי׳ » (Choul'han Aroukh OC 55:1 ; Berakhot 21b) ; la
# bénédiction des Cohanim et Modim derabanan n'existent que dans la répétition de l'officiant.
# « minyan » n'est jamais une condition du jour : ces passages restent repliés, dépliables.
CONSIGNES_MINYAN = ("קהל וחזן:", "שליח ציבור:", "קהל:", "חזן:", "קדושה", "ברכת כהנים", "מודים דרבנן",
                    "ואומר שליח צבור:", "ואומר שליח ציבור:", "ועונין הקהל:", "ועונים הקהל:")
KEDOUCHA = ["נקדש", "נקדישך", "נעריצך", "כתר יתנו", "קדוש קדוש קדוש", "לעמתם", "ברוך כבוד",
            "ובדברי קדשך", "ימלך יהוה לעולם", "לדור ודור נגיד"]
# « והקהל עונים: », « וחוזרים: » (Edot, fin d'Arvit ; audit du 16/11) : la réponse à Barekhou.
BAREKHOU = re.compile(r"^(ואומר החזן: (\(רבנן\) )?|חזן: |קהל וחזן: |ועונים הקהל: |והקהל עונים: |וחוזרים: |אומרים: )?(ברכו את יהוה המברך|ברוך יהוה המברך לעולם ועד)")
FIN_COHANIM = ("שים שלום", "שלום רב")


def colle(s, debut):
    """Comme commence, sans tenir compte des mots soudés du siddour (« כבודיהוה », « אתשמך »),
    ni du « חזן: » / « לש״ץ - » qui précède la part de l'officiant."""
    s = re.sub(r"^(חזן:|לש״ץ\s*-)\s*", "", s)
    return "".join(mots(s)).startswith(debut.replace(" ", ""))


def soude(s):
    """Le texte sans espaces : « מודים דרבנןבחזרת » et « מודים דרבנן בחזרת » se rejoignent."""
    return re.sub(r"\s+", "", s)


def minyan(txt, cons, pris, prend):
    n = len(txt)

    def debut(bi):
        """Les consignes d'officiant juste avant (« שליח ציבור: », « קדושה »…) suivent le passage."""
        k = bi
        while k > 0 and k - 1 not in pris and cons[k - 1] and (
                txt[k - 1] in CONSIGNES_MINYAN or txt[k - 1].startswith(("בחזרת הש״ץ", "קדושה"))
                or (len(txt[k - 1]) < 40 and "בחזרתהש״ץ" in soude(txt[k - 1]))
                or re.fullmatch(r"\(?[^()]{0,30}קדיש[^()]{0,25}\)?:?", txt[k - 1])):
            k -= 1
        return k

    bi = 0
    while bi < n:
        x = txt[bi]
        if bi in pris:
            bi += 1
            continue
        fin = None
        # La Kedoucha de la répétition, de « נקדש / נקדישך » à « ימלך » (et « לדור ודור » ashkénaze).
        if not cons[bi] and any(colle(x, k) for k in KEDOUCHA[:4]):
            fin = bi + 1
            while fin < n and fin not in pris and (
                    (cons[fin] and txt[fin] in CONSIGNES_MINYAN[:4])
                    or (not cons[fin] and any(colle(txt[fin], k) for k in KEDOUCHA))):
                fin += 1
            # Le sceau de l'officiant dans un bloc à part, après « לדור ודור » (Moussaf ashkénaze) :
            # il suit la Kedoucha, pourvu que le particulier ait le sien après « אתה קדוש » ; sinon
            # on replierait le seul sceau du texte (audit du 12/11, TSIDDUR-04).
            if colle(txt[fin - 1], "לדור ודור נגיד") and fin + 1 < n and fin not in pris and not cons[fin] \
                    and commence(txt[fin], "ברוך אתה יהוה האל") and not cons[fin + 1] and commence(txt[fin + 1], "אתה קדוש"):
                fin += 1
        # Barekhou et sa réponse.
        elif not cons[bi] and BAREKHOU.match(x):
            fin = bi + 1
            while fin < n and fin not in pris and (BAREKHOU.match(txt[fin]) if not cons[fin]
                                                   else txt[fin] in ("ועונין הקהל:", "ועונים הקהל:")):
                fin += 1
        # Le Kaddich : du « יתגדל » à sa dernière partie.
        elif not cons[bi] and (commence(x, "יתגדל") or commence(x, "קדיש יתום יתגדל")):
            fin = bi + 1
            # Edot : « יפסע שלש פסיעות לאחור » ouvre le dernier paragraphe, « עושה שלום ».
            while fin < n and fin not in pris and not cons[fin] and any(
                    commence(re.sub(r"^יפסע שלש פסיעות לאחור ", "", txt[fin]), k) for k in KADDICH[1:]):
                fin += 1
        # Modim derabanan, que l'assemblée dit pendant le « מודים » de l'officiant.
        # « כשיגיע שליח צבור למודים… » (Sfard, Ashkenaz ; audit du 16/11) : la consigne de Modim derabanan.
        elif (cons[bi] and (soude(x).startswith(("בחזרתהש״ץכשהחזןאומרמודים", "מודיםדרבנן", "כשיגיעשליחצבורלמודים")))) \
                or soude(x).startswith("מודיםדרבנןבחזרת"):
            fin = bi + 1
            if cons[bi] and fin < n and not cons[fin] and commence(txt[fin], "מודים אנחנו לך"):
                fin += 1
        # L'officiant répète ce que l'assemblée a dit (« וחוזר החזן: יהוה אלהיכם אמת »).
        elif not cons[bi] and x.startswith("וחוזר החזן"):
            fin = bi + 1
        # La bénédiction des Cohanim de la répétition, jusqu'à « שים שלום ».
        elif (cons[bi] and (x.rstrip(":") == "ברכת כהנים" or x.startswith("הטעם שתקנו לברך את ישראל"))) or \
                (not cons[bi] and commence(x, "אלהינו ואלהי אבותינו ברכנו בברכה")):
            fin = bi + 1
            while fin < n and fin not in pris and not (
                    (not cons[fin] and any(commence(txt[fin], k) for k in FIN_COHANIM))
                    or (cons[fin] and txt[fin] in ("שלום", "שים שלום"))):
                fin += 1
        if fin is None:
            bi += 1
            continue
        for j in range(debut(bi), fin):
            prend(j, "minyan")
        bi = fin


# Les textes où ce qui demande un minyan est replié : les offices, Arvit, Moussaf ; le Hallel et Birkat
# halevana depuis l'audit du 16/11 (leurs Kaddich).
TEXTES_MINYAN = ("arvit", "moussaf_rosh_hodech", "hallel", "birkat_halevana")


def double_annotation(texte_id, sections, nusah, sortie):
    """
    Audit du 16/11 : un bloc d'un groupe du jour peut aussi demander autre chose (« et ») : le
    minyan, pour les Kaddich, Barekhou et Kedoucha à l'intérieur d'un ajout du jour (לדוד ה׳ אורי, Vidouï,
    motsaé Chabbat, fin du Kaddich après le Hallel…), que la passe « minyan » ne voyait pas ; ou un jour,
    pour un fragment d'un groupe « minyan » (« תתקבל », pas le 9 Av : Rema O.H. 559:4 ; Kitsour Yalkut
    Yosef 559:7, la nuit). Le groupe se lit selon sa condition ; dedans, un bloc dont le « et » est faux
    se replie à part (SiddurJour.lignes, siddur-jour.js segments). La lecture de la Torah (groupe imposé)
    n'est pas découpée : elle suppose le minyan tout entière.
    """
    for si, sec in enumerate(sections):
        blocs = sec["blocs"]
        txt = [nu(b.get("t") or b.get("c")).replace("''", "״") for b in blocs]
        cons = ["c" in b for b in blocs]
        deja = {e["b"]: e for e in sortie if e["sorte"] == "bloc" and e["s"] == si}

        def marque(j, _c):
            e = deja.get(j)
            if e is not None and e["si"] != "minyan" and "force" not in e and "_force" not in e:
                e["et"] = "minyan"

        minyan(txt, cons, set(), marque)
        # La fin d'un Kaddich séparée de son début par une consigne (« עד כאן אומרים בחנוכה ») : « תתקבל »,
        # « יהא שלמא », et « עושה שלום » qui les suit.
        for j in sorted(deja):
            e = deja[j]
            if cons[j] or e["si"] == "minyan" or "et" in e or "force" in e or "_force" in e:
                continue
            avant = deja.get(j - 1)
            if any(commence(txt[j], k) for k in ("תתקבל", "יהא שלמא")) or (
                    any(commence(re.sub(r"^יפסע שלש פסיעות לאחור ", "", txt[j]), k) for k in ("עושה שלום", "עשה שלום"))
                    and avant is not None and avant.get("et") == "minyan"):
                e["et"] = "minyan"
        titre = nu(sec["titre"])
        for j, e in deja.items():
            # « תתקבל » : pas le 9 Av (Ashkenaz, Cha'harit ; Edot, Arvit, la nuit seulement).
            if e["si"] == "minyan" and commence(txt[j], "תתקבל") and (
                    (nusah == "ashkenaz" and texte_id == "chaharit" and titre == "סיום תפילה")
                    or (nusah == "edot" and texte_id == "arvit")):
                e["et"], e["et_libelle"] = "!ticha_beav", "ajout_sauf_ticha_beav"
            # Ashkenaz, Arvit : la fin du Kaddich complet (« תתקבל », « יהא שלמא », « עושה שלום ») ne se dit
            # pas avant ויהי נועם ou ואתה קדוש, mais après (consigne du siddour, Rema O.H. 295:1) : repliée
            # ces soirs-là ; un repère, après la section du motsaé Chabbat, dit de la reprendre.
            if nusah == "ashkenaz" and texte_id == "arvit" and titre == "קדיש שלם" and e["si"] == "minyan" \
                    and any(commence(txt[j], k) for k in ("תתקבל", "יהא שלמא", "עושה שלום")):
                e["et"], e["et_libelle"] = "!veata_kadoch", AUTRES_JOURS


# Qui prie seul, à la place de Barekhou (demande du 19/10) : la braïta « חיה אחת ». Texte du
# Ben Ich 'Haï, Vayigach, 1re année, 18 (Wikisource, « ברכו ») ; le même chez le 'Hida (Tsipporen
# Chamir) cité par Halakha Yomit, et dans Torat Eliyahou (Hekhalot Rabbati 31). Rav Ovadia Yossef :
# sans prononcer le Nom (« ה׳ ») ; pas entre ישתבח et יוצר, mais avant עלינו, et avant Arvit.
BARAITA = ("אמר רבי עקיבא: חיה אחת עומדת ברקיע ושמה ישראל, וחקוק על מצחה ישראל, עומדת באמצע הרקיע "
           "ואומרת: ברכו את ה׳ המבורך; וכל גדודי מעלה עונים ואומרים: ברוך ה׳ המבורך לעולם ועד.")
BARAITA_CONSIGNE = "המתפלל ביחיד אומר במקום ברכו, בלי להזכיר את השם (בן איש חי, ויגש י״ח; חיד״א, צפורן שמיר):"
BARAITA_RENVOI = ("המתפלל ביחיד אינו אומר כאן את הברייתא „חיה אחת“, שאין להפסיק בין ישתבח ליוצר; "
                  "אומרה לפני עלינו לשבח (בן איש חי, ויגש י״ח; הרב עובדיה יוסף).")


def seul(texte_id, sections, annotations):
    """Les cartes « seul » : après les groupes « minyan » de Barekhou, ou avant עלינו."""
    if texte_id not in ("chaharit", "arvit"):
        return []
    groupes = {}
    for e in annotations:
        if e["sorte"] == "bloc" and e["si"] == "minyan":
            groupes.setdefault((e["s"], e["g"]), []).append(e)
    barekhou = [max(g, key=lambda e: e["b"]) for g in groupes.values()
                if any(BAREKHOU.match(e["empreinte"]) and "ברכו" in e["empreinte"] for e in g)]
    barekhou.sort(key=lambda e: (e["s"], e["b"]))

    def carte(e, texte, consigne=None):
        c = {"sorte": "seul", "s": e["s"], "b": e["b"], "si": "!minyan", "empreinte": e["empreinte"], "texte": texte}
        if consigne:
            c["consigne"] = consigne
        return c

    if texte_id == "arvit":
        return [carte(barekhou[0], BARAITA, BARAITA_CONSIGNE)] if barekhou else []
    sortie = []
    if barekhou:
        sortie.append(carte(barekhou[0], BARAITA_RENVOI))
    if len(barekhou) > 1:
        sortie.append(carte(barekhou[-1], BARAITA, BARAITA_CONSIGNE))
    else:
        # Pas de Barekhou à la fin (Sfard) : la braïta juste avant la section עלינו.
        k = next((i for i, x in enumerate(sections) if nu(x["titre"]) == "עלינו"), None)
        if k:
            b = len(sections[k - 1]["blocs"]) - 1
            bloc = sections[k - 1]["blocs"][b]
            sortie.append({"sorte": "seul", "s": k - 1, "b": b, "si": "!minyan",
                           "empreinte": nu(bloc.get("t") or bloc.get("c"))[:40],
                           "texte": BARAITA, "consigne": BARAITA_CONSIGNE})
    return sortie


# Les variantes qui suivent leur ajout : repliées avec lui quand il est replié.
# « jeune » seul se lit « Anénou » (SiddurJour.libelle) : les autres ajouts du jeûne
# public portent ce libellé-ci.
JEUNE = "ajout_jeune_public"

# Le texte ordinaire qu'une formule du jour remplace (audit du 12/11, TSIDDUR-06) : condition
# niée ; SiddurJour (Kotlin, web) l'affiche tel quel quand il se dit, et le replie sinon.
AUTRES_JOURS = "ajout_autres_jours"
SCEAU_ORDINAIRE = re.compile(r"ברוך אתה \S+ (האל הקדוש|מלך או?הב צדקה ומשפט):?")
SCEAU_DIX_JOURS = re.compile(r"ברוך אתה \S+ המלך (הקדוש|המשפט)")

# Les lignes d'Avinou malkénou qui demandent pardon d'une faute, que les Edot sautent le Chabbat
# (Kitsour Yalkout Yossef 582/602:24) : חטאנו לפניך, מחול וסלח, מחה והעבר פשעינו, מחוק… שטרי חובותינו.
FAUTES = re.compile(r"אבינו מלכנו (חטאנו לפניך|מחול וסלח|מחה והעבר פשעינו|מחוק ברחמיך הרבים כל שטרי חובותינו)")

SOUS = {
    "yaale_veyavo": {"roch_hodech", "pessah", "soukkot", "chavouot", "roch_hachana", "chemini_atseret", "kippour"},
    "al_hanissim": {"hanouka", "pourim"},
    "moed": {"pessah", "chavouot", "soukkot", "chemini_atseret"},
    "avinou_malkenou": {"avinou_malkenou_jeune", "asseret_yemei_techouva"},
    "avinou_malkenou_minha": {"avinou_malkenou_jeune", "asseret_yemei_techouva"},
    # Avinou malkénou des dix jours (Edot) : les lignes de faute, sautées le Chabbat.
    "asseret_yemei_techouva": {"!chabbat"},
    # Le soir du 9 Av, pas de « תתקבל » après ואתה קדוש (Rema O.H. 559:4 ; audit du 16/11).
    "veata_kadoch": {"!ticha_beav"},
}

# Une consigne courte annonce les blocs de prière qui la suivent, jusqu'à la
# consigne suivante (relevé du 14/10 : ces passages restaient ouverts tous les jours).
# Le psaume du jour (16/10) : le nom du jour, en hébreu, et sa condition (CalendrierJuif.C.JOURS_SEMAINE).
JOURS_SEMAINE = {"ראשון": "jour_1", "שני": "jour_2", "שלישי": "jour_3", "רביעי": "jour_4", "חמישי": "jour_5",
                 "שישי": "jour_6", "ששי": "jour_6"}

# Les fragments du Kaddich, pour le replier avec le psaume qu'il clôt.
# « תתקבל » (13/11) : sans lui, la fin du Kaddich titkabal restait affichée sous son début replié.
KADDICH = ["יתגדל", "בעלמא", "יהא שמה", "יתברך", "לעלא", "תתקבל", "יהא שלמא", "עושה שלום", "עשה שלום", "על ישראל", "קדיש יתום"]

# Les consignes dont un seul bloc suit (les « הרחמן » et les bénédictions d'oubli des fêtes).
UNE_LIGNE = {"yom_tov", "moed", "roch_hachana", "yom_tov_chabbat", "chabbat_roch_hodech", "roch_hachana_chabbat"}

LIBELLES_CONSIGNE = {"jeune": JEUNE, "!chabbat": "ajout_chol"}

CONSIGNES_COURTES = [
    # Le Birkat hamazone (relevé du 19/10) : les psaumes d'avant, les « הרחמן » des fêtes,
    # les bénédictions de qui a oublié רצה ou יעלה ויבא.
    # Le festin du dimanche 16 Adar à Jérusalem, Pourim triple (14/11, tools/siddur_harahaman_pourim.py).
    (r"בסעודת פורים ביום ראשון ט״ז באדר בירושלים.*", "pourim_triple_festin"),
    (r"בחול קודם ברכת המזון אומרים:?", "!chabbat"),
    # Ashkenaz (audit du 16/11 ; Michna Beroura 1:11) : le psaume selon Ta'hanoun, Yom tov compris.
    (r"בימים שאומרים בהם תחנון קודם ברכת המזון אומרים:?", "tahanoun_chaharit"),
    (r"בשבת, ביו״ט ובימים שאין אומרים בהם תחנון קודם ברכת המזון אומרים.*", "!tahanoun_chaharit"),
    (r"בשבת קודם ברכת המזון אומרים:?", "chabbat"),
    (r"(בראש חודש|בר״ח) שחל בשבת:?", "chabbat_roch_hodech"),
    (r"(ביו״ט|ביום טוב) שחל בשבת:?", "yom_tov_chabbat"),
    (r"(בראש השנה|ברה״ש) שחל בשבת:?", "roch_hachana_chabbat"),
    (r"(בראש השנה|ברה״ש):?", "roch_hachana"),
    (r"(ביו״ט|ביום טוב)( אומר)?:?", "yom_tov"),
    (r"במועדים:?", "moed"),
    (r"לחנוכה:?", "hanouka"),
    # Les psaumes ajoutés certains jours (Edot, 16/10) : seulement le jour dit.
    (r"בצום גדליה ובעשרה בטבת אומרים:?", "tsom_guedalia_tevet"),
    (r"למחרת יום הכיפורים אומרים:?", "lendemain_kippour"),
    (r"בתענית אסתר ובפורים אומרים:?", "esther_pourim"),
    (r"בשבעה עשר בתמוז אומרים:?", "chiva_assar_tamouz"),
    (r"בחנוכה( (אומרים|אומר|מוסיפים))?( זה)?:?", "hanouka"),
    (r"(בראש חודש|בראש חדש|בר״ח)( (אומרים|אומר|מוסיפים|מוסיפין))?:?", "roch_hodech"),
    (r"בשבת( (אומרים|אומר))?:?", "chabbat"),
    (r"בסוכות:?", "soukkot"),
    (r"בתענית ציבור( אומרים)?:?", "jeune"),
    # Le Hallel : les passages sautés les jours de Hallel partiel.
    (r"(בימים שאין גומרים את ההלל (מדלגים|אין אומרים)|בראש חודש מדלגים זה|בר״ח ובחוה״מ פסח .*מדלגין זה):?", "hallel_complet"),
]


def facultatif(sections, sortie, note):
    """
    Birkat haMazon (03/11, « replie tout ce qui n'est pas obligatoire ») : n'est
    déplié que ce qui fait le devoir. Les quatre bénédictions, de « הזן » à « אל
    יחסרנו » (Berakhot 48b ; Choul'han Aroukh OC 187-189), avec leurs ajouts du jour,
    que les règles plus haut replient déjà selon le jour, ainsi que le zimoun et les
    consignes, dont celle des mayim a'haronim (OC 181).
    Le reste est d'usage, replié, dépliable, sous « facultatif », qui n'est jamais du
    jour :
      - avant : les psaumes d'avant le Birkat (למנצח, אברכה, על נהרות בבל, שיר המעלות)
        et « הנני מוכן » ;
      - après (03/11) : de la première ligne « הרחמן » jusqu'aux Chéva bérakhot ou aux
        règles d'oubli. Ce n'est plus replié depuis le 12/11 (« corrige הרחמן replié ») :
        les הרחמן de chaque jour, la bénédiction de l'hôte, « מגדיל », « עושה שלום » et
        « יראו » se lisent en clair ; ceux d'un jour (« בשבת », « בר״ח », « בסוכות »…) se
        déplient ce jour-là et se replient les autres, comme tout ajout du jour. Depuis le
        22/11, ceux de la table (la sienne, celle de son père, celle d'un hôte) sont repliés.
    Les annotations du jour qui portaient sur les psaumes d'avant (Chabbat, semaine) en
    deviennent les variantes. Le groupe est imposé (« force ») : les jours ne le coupent pas.
    """
    for si, sec in enumerate(sections):
        blocs = sec["blocs"]
        n = len(blocs)
        txt = [nu(b.get("t") or b.get("c")).replace("''", "״") for b in blocs]
        cons = ["c" in b for b in blocs]
        deja = {e["b"]: e for e in sortie if e["sorte"] == "bloc" and e["s"] == si}
        # Avant : jusqu'au zimoun, ou à la première bénédiction quand le zimoun manque.
        debut = next((j for j in range(n) if deja.get(j, {}).get("si") == "zimun"
                      or (not cons[j] and commence(txt[j], "ברוך אתה"))), n)
        avant = [j for j in range(debut) if not (cons[j] and "מים אחרונים" in txt[j])]
        # Après : la première « הרחמן » qui suit la première bénédiction.
        premier = next((j for j in range(debut, n) if not cons[j] and commence(txt[j], "ברוך אתה")), n)
        harahaman = next((j for j in range(premier, n) if not cons[j] and commence(txt[j], "הרחמן")), n)
        fin = next((j for j in range(harahaman, n) if deja.get(j, {}).get("si") in ("cheva_berakhot", "oubli")), n)
        apres = list(range(harahaman, fin))
        # La consigne juste avant la première « הרחמן » (« בשבת », « אורח אומר ») va avec elle.
        while apres and apres[0] - 1 > premier and cons[apres[0] - 1] and apres[0] - 1 not in avant:
            apres.insert(0, apres[0] - 1)
        # Les « הרחמן » et la fin (« מגדיל », « עושה שלום », « יראו ») ne sont plus repliés
        # (demande du 12/11) : seuls ceux d'un jour (Chabbat, Roch 'Hodech, fêtes) suivent leur
        # jour, par les consignes courtes ; « apres » ne sert plus qu'à le vérifier.
        for liste, libelle in ((avant, "ajout_facultatif_avant"),):
            for j in liste:
                ancien = deja.get(j)
                if ancien is not None:
                    sortie.remove(ancien)
                cond = ancien["si"] if ancien is not None else "facultatif"
                note("bloc", si, j, cond, {"force": "facultatif", "libelle": libelle})
        # Les הרחמן particuliers (demande du 22/11) : ceux qui dépendent de la table où l'on
        # mange, et non du jour, se replient sous « facultatif », jamais du jour : à la table de
        # son père ou à la sienne (Sfard, Ashkenaz), ce que l'invité dit pour son hôte (les trois ;
        # Edot : « אורח אומר »). « אותנו ואת כל אשר לנו », que chacun dit à la suite, reste en clair.
        particuliers = []
        for j in apres:
            if cons[j] and re.match(r"^\(?ו?אם סמוך על שלחן (אביו|עצמו)", txt[j]):
                particuliers += [(j, "ajout_harahaman_maison"), (j + 1, "ajout_harahaman_maison")]
                assert commence(txt[j + 1], "הרחמן הוא יברך"), txt[j + 1][:40]
            elif cons[j] and txt[j].startswith("אם אוכל על שלחן אחרים"):
                particuliers += [(j, "ajout_harahaman_invite"), (j + 1, "ajout_harahaman_invite")]
                assert re.match(r"^(לזכר: ?)?יהי רצון שלא", txt[j + 1]), txt[j + 1][:40]
            elif not cons[j] and txt[j].startswith("אורח אומר"):
                particuliers.append((j, "ajout_harahaman_invite"))
        if apres:
            assert any(l == "ajout_harahaman_invite" for _, l in particuliers), "Birkat : la bénédiction de l'invité est introuvable"
        for j, libelle in particuliers:
            assert j not in deja, f"Birkat : bloc {j} déjà annoté"
            note("bloc", si, j, "facultatif", {"libelle": libelle})


def grouper(annotations):
    """
    Un groupe : des blocs consécutifs d'une même section, de même condition
    ou variantes de la première (« racine »). Replié, un groupe tient en une
    ligne ; la racine dit s'il s'applique.
    """
    g = -1
    precedent = None
    for e in annotations:
        if e["sorte"] != "bloc":
            continue
        force = e.pop("force", None)
        if force:
            # Un groupe imposé (la lecture de la Torah) : une seule racine, ses variantes dedans.
            if precedent and precedent.get("_force") == force and precedent["s"] == e["s"] and precedent["b"] + 1 == e["b"]:
                e["g"], e["racine"] = precedent["g"], force
            else:
                g += 1
                e["g"], e["racine"] = g, force
            e["_force"] = force
            precedent = e
            continue
        if precedent and precedent["s"] == e["s"] and precedent["b"] + 1 == e["b"] \
                and e.get("libelle") == precedent.get("libelle") \
                and (e["si"] == precedent["racine"] or e["si"] in SOUS.get(precedent["racine"], ())):
            e["g"], e["racine"] = precedent["g"], precedent["racine"]
        else:
            g += 1
            e["g"], e["racine"] = g, e["si"]
        precedent = e


# Les renvois de Cha'harit (demande du 12/10) : les jours de Hallel, le Hallel
# après la Amida ; à Roch 'Hodech, le Moussaf à sa place dans l'office. La
# place suit l'ordre de chaque siddour à Roch 'Hodech (export Sefaria) :
# Edot, Hallel · Ouva léTsion · Chir chel yom · Moussaf ; Sfard, Hallel ·
# Chir chel yom · Barkhi nafchi · lecture · Achré-Ouva léTsion · Moussaf ;
# Ashkenaz (Metsudah), Hallel · lecture · Achré · Ouva léTsion · Moussaf,
# avant le Kaddich titkabal.
# Audit du 16/11 (Hallel et Moussaf) : le Moussaf de l'application est celui de Roch 'Hodech en
# semaine (« roch_hodech_chol ») ; le Chabbat, on dit « אתה יצרת », qui n'y est pas (Kitsour Yalkut
# Yosef 423:10 ; Choul'han Aroukh O.H. 425:3). Un renvoi sans cible est un rappel (« libelle » : la
# chaîne), « Aujourd'hui · … », pour ce que le siddour n'a pas, ou pas à cette place : le Moussaf de
# Chabbat Roch 'Hodech et celui de 'Hol hamoed (Kitsour Yalkut Yosef 490:2 ; Choul'han Aroukh O.H.
# 490:2), le demi-Kaddich avant Moussaf (Kitsour Yalkut Yosef 423:2 et 5 ; Michna Beroura 423:4 et 8),
# le Hallel du soir du Séder (Kitsour Yalkut Yosef 487:5 ; Choul'han Aroukh O.H. 487:4).
# Dans l'ordre d'affichage : (texte, section, début du bloc après lequel renvoyer ou None, condition,
# cible ou None, libellé du rappel ou None).
APRES_AMIDA_EDOT = "יהי רצון מלפניך יהוה אלהינו ואלהי אבותינו שתבנה"
APRES_AMIDA_SEFARD = "יהי רצון מלפניך יהוה אלהינו ואלהי אבותינו שיבנה"
AVANT_MOUSSAF_ASHKENAZ = "יהי רצון מלפניך יהוה אלהינו ואלהי אבותינו שנשמר"
RENVOIS = {
    "edot": [
        ("chaharit", "עמידה", None, "hallel", "hallel", None),
        # Ni תתקבל après ובא לציון à Roch 'Hodech : il a été dit après le Hallel ; demi-Kaddich avant Moussaf.
        ("chaharit", "ובא לציון", "ברוך אלהינו שבראנו", "roch_hodech_chol", None, "ajout_rappel_sans_titkabal"),
        ("chaharit", "שיר של יום", None, "roch_hodech_chol", None, "ajout_rappel_demi_kaddich_moussaf_edot"),
        ("chaharit", "שיר של יום", None, "chabbat_roch_hodech", None, "ajout_rappel_moussaf_chabbat_roch_hodech"),
        ("chaharit", "שיר של יום", None, "hol_hamoed", None, "ajout_rappel_moussaf_hol_hamoed"),
        ("chaharit", "שיר של יום", None, "roch_hodech_chol", "moussaf_rosh_hodech", None),
        # Le soir du Séder, après l'Amida (Kitsour Yalkut Yosef 487:5 ; le Chabbat, après ויכולו, 487:11).
        ("arvit", "עמידה", APRES_AMIDA_EDOT, "leil_pessah", None, "ajout_rappel_hallel_leil_pessah_edot"),
        ("arvit", "עמידה", APRES_AMIDA_EDOT, "leil_pessah", "hallel", None),
        # À Roch 'Hodech Tévèt, le psaume de 'Hanouka après Moussaf et ברכי נפשי (Kitsour Yalkut Yosef 683:11) :
        # il est dans Cha'harit (Chir chel yom), replié ce jour-là.
        ("moussaf_rosh_hodech", "ברכי נפשי", None, "hanouka", None, "ajout_rappel_psaume_hanouka_apres_moussaf"),
        # Arvit (audit du 16/11, structure des offices) : les Edot comptent l'Omer après עלינו, selon l'usage de
        # Jérusalem (Kitsour Yalkut Yosef 489 §21) ; leur Arvit n'a pas de section de l'Omer, il renvoie à la page du compte.
        ("arvit", "עלינו", None, "omer", "sefirat_haomer", None),
    ],
    "sefard": [
        ("chaharit", "עמידה", None, "hallel", "hallel", None),
        ("chaharit", "אשרי", None, "chabbat_roch_hodech", None, "ajout_rappel_moussaf_chabbat_roch_hodech"),
        ("chaharit", "אשרי", None, "roch_hodech_chol", "moussaf_rosh_hodech", None),
        # Usage 'hassidique répandu, que le Choul'han Aroukh haRav (487:8) écarte : présenté comme tel.
        ("arvit", "עמידה", APRES_AMIDA_SEFARD, "leil_pessah", None, "ajout_rappel_hallel_leil_pessah_sefard"),
        ("arvit", "עמידה", APRES_AMIDA_SEFARD, "leil_pessah", "hallel", None),
        # La bénédiction du Hallel partiel en minyan (Rema O.H. 422:2 ; Choul'han Aroukh haRav 619:8).
        ("hallel", "סדר הלל", "ברוך אתה יהוה אלהינו מלך העולם אשר קדשנו", "hallel_partiel", None, "ajout_rappel_berakha_hallel_sefard"),
    ],
    "ashkenaz": [
        ("chaharit", "עמידה", None, "hallel", "hallel", None),
        ("chaharit", "סיום תפילה", AVANT_MOUSSAF_ASHKENAZ, "roch_hodech_chol", None, "ajout_rappel_demi_kaddich_moussaf"),
        ("chaharit", "סיום תפילה", AVANT_MOUSSAF_ASHKENAZ, "chabbat_roch_hodech", None, "ajout_rappel_moussaf_chabbat_roch_hodech"),
        ("chaharit", "סיום תפילה", AVANT_MOUSSAF_ASHKENAZ, "hol_hamoed", None, "ajout_rappel_moussaf_hol_hamoed"),
        ("chaharit", "סיום תפילה", AVANT_MOUSSAF_ASHKENAZ, "roch_hodech_chol", "moussaf_rosh_hodech", None),
    ],
}


def renvois(texte_id, sections, nusah):
    sortie = []
    for texte, titre, debut, cond, cible, libelle in RENVOIS[nusah]:
        if texte != texte_id:
            continue
        si = next(i for i, s in enumerate(sections) if nu(s["titre"]) == titre)
        e = {"sorte": "renvoi", "s": si, "si": cond}
        if cible:
            e["cible"] = cible
        if libelle:
            e["libelle"] = libelle
        if debut is None:
            e["empreinte"] = nu(sections[si]["titre"])
        else:
            bi = next(i for i, b in enumerate(sections[si]["blocs"]) if commence(nu(b.get("t") or b.get("c")), debut))
            e["b"], e["empreinte"] = bi, nu(sections[si]["blocs"][bi].get("t") or sections[si]["blocs"][bi].get("c"))[:40]
        sortie.append(e)
    return sortie


def _repere(sections, si, bi, cond, extra=None):
    """Une annotation à la main, avec son empreinte, comme note() dans annoter()."""
    b = sections[si]["blocs"][bi]
    e = {"sorte": "bloc", "s": si, "si": cond, "b": bi, "empreinte": nu(b.get("t") or b.get("c"))[:40]}
    e.update(extra or {})
    return e


def tikoun_hatsot(sections, nusah):
    """
    Tikoun 'hatsot (audit du 16/11) ; le texte, emprunté à l'Edot, est le même dans les trois siddourim.
      - Tikoun Ra'hel (section 1) : pas à Roch 'Hodech, de Roch Hachana à Chemini Atseret, à 'Hanouka,
        aux jours de Pourim, en Nissan, pendant l'omer (Kitsour Yalkut Yosef, דיני תיקון חצות §נה ;
        Ben Ich 'Haï, Vayichla'h ה) : condition « tikoun_rahel », discrète (en clair les autres jours).
      - Tikoun Léa (section 2) : pas la nuit du 9 Av, où l'on ne dit que Tikoun Ra'hel (YY §נו) ;
        les psaumes « בימים שאין אומרים תחנון לא יאמר » (יענך, עד אנה) : les jours de Ta'hanoun
        (consigne du siddour 2:2 et 2:8), le jour hébreu de la nuit (jourDeLaPriere).
      - Indications fixes, en Edot : le vidui d'avant le Tikoun ne se répète pas (YY §נח) ; les
        femmes qui veulent le dire (YY §נא).
    La section se repère par son titre et ses consignes, pour qu'un siddour reconstruit échoue ici.
    """
    titres = [nu(s["titre"]) for s in sections]
    assert titres == ["לשם יחוד", "תיקון רחל", "תיקון לאה"], titres
    sortie = []
    rahel = sections[1]["blocs"]
    for bi in range(len(rahel)):
        sortie.append(_repere(sections, 1, bi, "tikoun_rahel", {"libelle": "ajout_tikoun_rahel", "discret": True}))
    lea = sections[2]["blocs"]
    cons = [nu(b.get("c") or "") for b in lea]
    assert cons[2].startswith("בימים שאין אומרים תחנון") and cons[8].startswith("בימים שאין אומרים תחנון"), cons
    tahanoun = {2, 3, 8, 9, 10}
    for bi in range(len(lea)):
        if bi in tahanoun:
            sortie.append(_repere(sections, 2, bi, "tahanoun_chaharit", {"discret": True}))
        else:
            sortie.append(_repere(sections, 2, bi, "!ticha_beav", {"libelle": "ajout_tikoun_lea", "discret": True}))
    if nusah == "edot":
        assert nu(sections[0]["blocs"][0]["t"]).startswith("אין אומרים תיקון חצות"), "consigne 0:0"
        assert commence(nu(sections[0]["blocs"][1]["t"]), "אנא יהוה"), "vidui 0:1"
        for bi, texte in ((0, "וכל אשה יראת ה׳ הרוצה לומר תיקון חצות, תבוא עליה ברכה, ואין למונעה מכך"
                              " (ילקוט יוסף, דיני תיקון חצות, נא)"),
                          (1, "אין חוזרים על הוידוי אם אומרים את התיקון סמוך לוידוי שבקריאת שמע שעל המטה,"
                               " או סמוך למנחה, או באלול ובעשרת ימי תשובה סמוך לסליחות"
                               " (ילקוט יוסף, דיני תיקון חצות, נח)")):
            e = _repere(sections, 0, bi, "toujours", {"texte": texte, "fixe": True})
            e["sorte"] = "indice"
            sortie.append(e)
    grouper(sortie)
    for e in sortie:
        e.pop("_force", None)
    return sortie


def chema_coucher_sfard(sections, nusah):
    """
    Chema du coucher Sfard (audit du 16/11) : l'usage 'Habad (Tehillat Hachem), signalé sans rien
    replier : « רבונו של עולם » (0:0) omis le Chabbat et le Yom tov ; le vidui (les jours de
    Ta'hanoun) et « אנא בכח », que ce siddour n'a pas.
    """
    if nusah != "sefard":
        return []
    assert commence(nu(sections[0]["blocs"][0]["t"]), "רבונו של עולם הריני מוחל"), "chema_coucher sefard 0:0"
    e = _repere(sections, 0, 0, "toujours", {
        "texte": "מנהג חב״ד: אין אומרים ״רבונו של עולם״ בשבת וביום טוב; ומוסיפים וידוי (בימים שאומרים בהם תחנון) ו״אנא בכח״",
        "fixe": True})
    e["sorte"] = "indice"
    return [e]


# Les textes annotés à la main, hors des règles générales d'annoter() (audit du 16/11).
SPECIAUX = {"tikoun_hatsot": tikoun_hatsot, "chema_coucher": chema_coucher_sfard}


def main():
    racine = {"_meta": {
        "outil": "tools/siddur_annotations.py",
        "conditions": "clés de CalendrierJuif.C (KosherJava) ; « ! » : la clé fausse",
        "regle": "les textes ne sont pas modifiés ; un ajout hors du jour est replié, jamais retiré",
        "a_valider": "indicatif : le texte et ses consignes font foi",
    }}
    for nusah in ("edot", "sefard", "ashkenaz"):
        siddur = json.load(open(os.path.join(RAW, f"siddur_{nusah}.json"), encoding="utf-8"))
        racine[nusah] = {}
        for t in siddur["textes"]:
            a = []
            if t["id"] in TEXTES:
                a = annoter(t["id"], t["sections"], nusah)
                a += renvois(t["id"], t["sections"], nusah)
            if t["id"] in SPECIAUX:
                a += SPECIAUX[t["id"]](t["sections"], nusah)
            # Les notes de l'application (audit du 16/11), dans tout texte.
            a += notes(nusah, t, a)
            if a:
                racine[nusah][t["id"]] = a
    cible = os.path.join(RAW, "siddur_annotations.json")
    json.dump(racine, open(cible, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    for nusah in ("edot", "sefard", "ashkenaz"):
        print(nusah, {k: len(v) for k, v in racine[nusah].items()})


if __name__ == "__main__":
    main()
