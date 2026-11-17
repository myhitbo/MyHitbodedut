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
          "birkot_hachahar"]

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
# seulement. Edot, « בשנה מעוברת » : toute l'année ; Sfard, Ashkenaz, « עד חודש ניסן » : jusqu'à
# Roch 'Hodech Adar II inclus. Les deux usages : Michna beroura 423:6. Rend (condition, passage
# brut à retirer hors du jour : la consigne et le mot, avec l'espace qui les précède).
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
    return ("embolismique" if nusah == "edot" else "embolismique_avant_nissan"), brut[debut:fin]


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
            cond = "motsae_chabbat"
        elif titre == "ספירת העומר":
            cond = "omer"
        # La lecture de la Torah (15/10) : un seul groupe, replié les jours sans lecture ;
        # dedans, ce qui ne se dit qu'avec Ta'hanoun, ou que lundi et jeudi, en variante.
        elif titre == "קריאת התורה" and office == "chaharit":
            mode, reste = "kriat_hatorah", None
            for bi, b in enumerate(sec["blocs"]):
                x = nu(b.get("t") or b.get("c"))
                if "c" in b:
                    if "ביום שיש בו תחנון" in x or x.startswith("אין אומרים אא״א"):
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
            if am is not None and txt[0].startswith("טעם נכון למה נתקן הוידוי"):
                for k in range(0, am):
                    prend(k, "tahanoun_" + office)
            if lj is not None and dd is not None and lj < dd:
                prend(lj, "tahanoun_" + office)
                for k in range(lj + 1, dd):
                    prend(k, "lundi_jeudi")
            if dd is not None and kd is not None:
                for k in range(dd, kd):
                    prend(k, "tahanoun_" + office)

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
            if cons[bi] and bi not in pris and OUBLI.search(x):
                prend(bi, "oubli")
                bi += 1
                continue
            # « שעשה לי כל צרכי » (Edot) : pas le 9 Av ni à Kippour, la consigne le dit (Ben Ich 'Haï,
            # Vayechev 9). Les autres jours en clair, sans étiquette (12/11).
            if cons[bi] and re.match(r"בתשעה באב ויום הכי?פורים אין אומרים ברכה זו", x) and bi + 1 < n and not cons[bi + 1]:
                prend_discret(bi, "!ticha_beav_kippour", "ajout_sauf_ticha_beav_kippour")
                prend_discret(bi + 1, "!ticha_beav_kippour", "ajout_sauf_ticha_beav_kippour")
                bi += 2
                continue
            # Après le Hallel, la fin du Kaddich (תתקבל, יהא שלמא, עושה שלום) : pas à 'Hanouka, où l'on
            # s'arrête au demi-Kaddich (« עד כאן אומרים בחנוכה », « ובחנוכה אומר רק חצי קדיש », 12/11).
            if texte_id == "hallel" and not cons[bi] and commence(x, "תתקבל") and any(
                    cons[k] and ("עד כאן אומרים בחנוכה" in txt[k] or "ובחנוכה אומר רק חצי קדיש" in txt[k])
                    for k in range(max(0, bi - 3), bi)):
                j = bi
                while j < n and not cons[j] and any(commence(txt[j], m) for m in ("תתקבל", "יהא שלמא", "יפסע", "עושה שלום", "עשה שלום")):
                    prend_discret(j, "!hanouka", "ajout_sauf_hanouka")
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
            # « אתה חוננתנו » (Edot) : le seul bloc annoncé ; « וחננו מאתך » suit tous les soirs.
            if cons[bi] and x.startswith("במוצאי שבת ויום טוב אומרים") and bi + 1 < n and not cons[bi + 1]:
                prend(bi, "motsae_chabbat_yt")
                prend(bi + 1, "motsae_chabbat_yt")
                bi += 2
                continue
            # La fin d'Arvit du motsaé Chabbat (Edot) : jusqu'au Kaddich titkabal des autres soirs.
            if cons[bi] and x.startswith("בכל לילות החול מלבד מוצאי שבת מדלגים"):
                j = bi
                while j < n and not (cons[j] and "קדיש תתקבל" in txt[j] and j > bi):
                    prend(j, "motsae_chabbat")
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
                        if re.fullmatch(r"בתענית ציבור:?", y):
                            sous = "jeune"
                        elif re.fullmatch(r"(בעשי״ת|בעשרת ימי תשובה)( (אומרים|מוסיפים))?:?", y):
                            sous = "asseret_yemei_techouva"
                        else:
                            break
                        souche = None
                        prend(j, sous)
                    elif y.startswith("בתענית ציבור:"):
                        prend(j, "jeune")
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
                prend(bi, "asseret_yemei_techouva")
                j = bi + 1
                prend(j, "asseret_yemei_techouva")
                ordinaire(bi, txt[j])
                # Avinou malkénou annoncé par la consigne (Edot) : toute la suite.
                while commence(txt[j], "אבינו מלכנו") and j + 1 < n and not cons[j + 1] \
                        and commence(txt[j + 1], "אבינו מלכנו"):
                    j += 1
                    prend(j, "asseret_yemei_techouva")
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
            elif cons[bi] and "אומרים כאן הלל" in x:
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
        if office or texte_id in ("arvit", "moussaf_rosh_hodech"):
            minyan(txt, cons, pris, prend)
    if texte_id == "birkat_hamazon":
        facultatif(sections, sortie, note)
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
BAREKHOU = re.compile(r"^(ואומר החזן: (\(רבנן\) )?|חזן: |קהל וחזן: |ועונים הקהל: |אומרים: )?(ברכו את יהוה המברך|ברוך יהוה המברך לעולם ועד)")
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
        elif (cons[bi] and (soude(x).startswith(("בחזרתהש״ץכשהחזןאומרמודים", "מודיםדרבנן")))) \
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

SOUS = {
    "yaale_veyavo": {"roch_hodech", "pessah", "soukkot", "chavouot", "roch_hachana", "chemini_atseret", "kippour"},
    "al_hanissim": {"hanouka", "pourim"},
    "moed": {"pessah", "chavouot", "soukkot", "chemini_atseret"},
    "avinou_malkenou": {"jeune", "asseret_yemei_techouva"},
    "avinou_malkenou_minha": {"jeune", "asseret_yemei_techouva"},
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
        déplient ce jour-là et se replient les autres, comme tout ajout du jour.
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
# avant le Kaddich titkabal. (section, début du bloc après lequel renvoyer ou None, condition, cible)
RENVOIS = {
    "edot": [("עמידה", None, "hallel", "hallel"), ("שיר של יום", None, "roch_hodech", "moussaf_rosh_hodech")],
    "sefard": [("עמידה", None, "hallel", "hallel"), ("אשרי", None, "roch_hodech", "moussaf_rosh_hodech")],
    "ashkenaz": [("עמידה", None, "hallel", "hallel"),
                 ("סיום תפילה", "יהי רצון מלפניך יהוה אלהינו ואלהי אבותינו שנשמר", "roch_hodech", "moussaf_rosh_hodech")],
}


def renvois(sections, nusah):
    sortie = []
    for titre, debut, cond, cible in RENVOIS[nusah]:
        si = next(i for i, s in enumerate(sections) if nu(s["titre"]) == titre)
        e = {"sorte": "renvoi", "s": si, "si": cond, "cible": cible}
        if debut is None:
            e["empreinte"] = nu(sections[si]["titre"])
        else:
            bi = next(i for i, b in enumerate(sections[si]["blocs"]) if commence(nu(b.get("t") or b.get("c")), debut))
            e["b"], e["empreinte"] = bi, nu(sections[si]["blocs"][bi].get("t"))[:40]
        sortie.append(e)
    return sortie


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
                if t["id"] == "chaharit":
                    a += renvois(t["sections"], nusah)
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
