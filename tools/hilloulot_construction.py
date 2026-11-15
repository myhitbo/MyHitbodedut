# -*- coding: utf-8 -*-
"""
Construit android/app/src/main/res/raw/hilloulot.json (demande du 11/10/2026) :
les hilloulot (jours de décès de tsadikim et de 'hakhamim), par jour hébreu.

Sources, lues le 11/10/2026 et gardées dans tools/hilloulot/ (lots 1 à 4) :
  - Wikipédia hébreu, section « נפטרו » des pages de date (CC BY-SA 4.0) ;
  - החכם היומי (hyomi.org.il, Kol Israël 'Haverim), pages par mois.
De החכם היומי, seuls des faits : nom, jour, année. De Wikipédia, en plus,
la première phrase de l'article (CC BY-SA 4.0, attribution à l'écran).
Les figures non rabbiniques ont été écartées à la lecture ; les cas
douteux gardent leur raison dans « d ».

Règle du propriétaire (11/10) : quand les deux sources divergent pour une
même personne, החכם היומי l'emporte (lots 2 et 3 dès la lecture ; lots 1 et
4 ci-dessous, cas relevés à la main).

Clé des jours : « <mois>-<jour> », mois de KosherJava (1 Nissan … 6 Eloul,
7 Tichri … 11 Chevat), « adar », « adar1 », « adar2 » pour Adar : un
« adar » sans précision se dit en Adar II les années embolismiques
(Choul'han Aroukh OH 568:7, usage séfarade, celui de החכם היומי).

  python3 tools/hilloulot_construction.py
"""
import collections, json, os, re

ICI = os.path.dirname(os.path.abspath(__file__))
MOIS = {"ניסן": "1", "אייר": "2", "סיוון": "3", "סיון": "3", "תמוז": "4", "אב": "5", "אלול": "6",
        "תשרי": "7", "חשוון": "8", "חשון": "8", "מרחשוון": "8", "כסלו": "9", "טבת": "10", "שבט": "11",
        "אדר": "adar", "אדר א׳": "adar1", "אדר א'": "adar1", "אדר א": "adar1",
        "אדר ב׳": "adar2", "אדר ב'": "adar2", "אדר ב": "adar2"}

# Désaccords des lots 1 et 4 : (mois, jour, début du nom) des entrées
# Wikipédia retirées au profit de החכם היומי, et années corrigées.
RETIRES = [("תשרי", 10, "שמואל דוד לוצאטו"), ("תשרי", 11, "הרב פרץ מימון"),
           ("חשוון", 28, "הרב חיים רחמים יוסף פרנקו"), ("כסלו", 1, "הרב יוסף כנאפו"),
           ("אלול", 4, "הרב משה עידאן"), ("אלול", 19, "רבי חיים בנבנישתי")]
ANNEES = {("תשרי", 20, "רבי אליעזר פאפו"): 'תקפ"ח', ("אלול", 6, "רבי ישועה שמעון חיים עובדיה"): "1952",
          ("אלול", 9, "רבי רפאל טריוויש"): 'תקל"ג', ("אלול", 23, "הרב רחמים אריה אברהם ארייאש"): "1893"}


G = {c: i for i, c in enumerate("אבגדהוזחט", 1)} | {"י": 10, "כ": 20, "ל": 30}


# Dates et années démenties par la notice de Wikipédia affichée juste en dessous (audit du 12/11/2026,
# THILLOULOT-05) : (clé du jour, début du nom, nouvelle clé ou None, nouvelle année ou None). Appliquées
# après la lecture des notices, avant le rapprochement avec MyTzadik et המאיר לארץ.
CORRECTIONS = [
    ("10-22", "הרב ברוך מנדלבאום", "2-17", 'ה\'תרס"ה'),      # commémoré à sa naissance (22 Tevet 5594) ; mort le 17 Iyar 5665
    ("1-27", "הרב משה דב וולנר", "5-21", None),
    ("10-9", "הרב אברהם חיים שור", "10-19", None),
    ("11-1", "הרב שלום עמנואל מויאל", "adar2-1", None),
    ("4-10", "הרב יהושע קניאל", "4-11", None),
    ("5-7", "רבי אלעזר רוזנפלד", "4-27", None),
    ("4-29", "רבי אליהו בעל שם מוורמייזא", "4-21", None),
    ("3-21", "הרב נחום אש", "3-19", None),
    ("5-11", "רבי חיים מקרסנה", "5-14", None),
    ("2-25", "שבע ברכה ארנסטר", "2-26", None),
    ("1-15", "הרב שלמה מיידנצ'יק", None, 'ה\'תשס"ד'),
    ("adar1-7", "הרב צבי הירש למפרט", None, 'ה\'תרס"ה'),
    ("adar1-2", "רבי יוסף דוב הלוי סולובייצ'יק", None, 'ה\'תשמ"א'),
    ("9-21", "הרב צבי פסח פרנק", None, 'ה\'תשכ"א'),
    ("4-20", "חכם אברהם חיים נאה", None, 'ה\'תשי"ד'),
    ("adar-25", "רבי בצלאל יאיר דנציגר", None, 'ה\'תרצ"ד'),
    ("3-30", "רבי יחיאל יעקב הופשטיין", None, 'ה\'תרכ"ו'),
    # THILLOULOT-12 : 5690 n'est pas embolismique (la notice dit « י״ג באדר ») ; un 30 Adar n'existe qu'en Adar I.
    ("adar1-13", "הרב חיים יעקב נפתלי זילברברג", "adar-13", None),
    ("adar-30", "חכם ד\"ר דוד פראטו", "adar1-30", None),
]
# Gardé tel quel, avec raison : « רבי יחיאל מיכל מנמירוב » (20 Sivan), date traditionnellement liée au massacre.

# Les mêmes tsadikim en double (THILLOULOT-04) : l'entrée de MyTzadik ou de המאיר לארץ (« m », « l ») seule,
# d'orthographe voisine, est absorbée par l'entrée du même jour (ou du 29/30) : sa source et sa biographie
# vont à l'entrée gardée. Liste relue paire par paire : le rapprochement automatique ne retire jamais י, ו, א.
# Exclus : « הרב משה הגר » (2 Adar, rosh yeshiva mort en 5759), distinct de « רבי משה הגר » (1863-1926) ;
# la paire du 25 Sivan (חכם חיים הכהן / רבי חיים כהן), sans source.
DOUBLONS = [
    ("7-15", "יעקב אבינו", "7-15", "יעקב אבינו"),
    ("7-29", "שמעון הצדיק", "7-29", "שמעון הצדיק"),
    ("adar-7", "משה רבנו", "adar-7", "משה רבנו"),
    ("1-17", "רבי מאיר אבוחצירא", "1-17", "בבא מאיר - רבי מאיר אביחצירא"),
    ("1-22", "הרב כומס יאמין", "1-22", "רבי כמוס ימין"),
    ("1-30", "רבי נתנאל וייל", "1-30", "רבי יעקב נתנאל ווייל בעל קרבן נתנאל"),
    ("1-8", "רבי אליהו שפירא", "1-8", "רבי אליה שפירא"),
    ("10-12", "רבי משה מרגלית", "10-12", "רבי משה מרגליות"),
    ("10-20", "רבי יעקב אבוחצירא", "10-20", "רבי יעקב אביחצירא"),
    ("10-23", "רבי אברהם פלאג'י", "10-23", "רבי אברהם פאלאג'י"),
    ("10-28", "רבי אברהם ענתיבי", "10-28", "המקובל רבי אברהם ענתבי"),
    ("11-14", "רבי יצחק אבוחצירא (הראשון)", "11-14", "רבי יצחק אביחצירא"),
    ("11-16", "חכם יוסף בן נאים", "11-16", "רבי יוסף בן נאיים"),
    ("11-28", "חכם אפרים לניאדו", "11-28", "רבי אפרים לנייאדו"),
    ("11-5", "חכם שמואל שאול סרירו", "11-5", "רבי שאול סירירו"),
    ("2-12", "רבי זרח איידליץ", "2-12", "רבי משה זרח אידליץ"),
    ("2-12", "רבי מסעוד אבוחצירא", "2-12", "רבי מסעוד אביחצירא"),
    ("2-9", "רבי משה הגר", "2-9", "אדמו\"ר רבי משה האגר משאץ-ויז'ניץ"),
    ("3-3", "רבי יוסף בן עמנואל אירגאס", "3-3", "המקובל רבי יוסף אירגס"),
    ("3-4", "חכם שלמה אוליוירה", "3-4", "רבי שלמה די אוליוורה"),
    ("4-20", "רבי אליעזר הגר", "4-20", "אדמו\"ר רבי אליעזר האגר מסערט ויז'ניץ"),
    ("4-23", "רבי יחזקאל קצינאלפוגין", "4-23", "רבי יחזקאל קצנאלפוגן בעל ''כנסת יחזקאל''"),
    ("5-17", "רבי שמשון ורטהיימר", "5-17", "רבי שמשון וורטהיימר"),
    ("5-19", "חכם יעקב כאלפון", "5-19", "רבי יעקב כלפון"),
    ("5-2", "הרב יוסף צובירי", "5-2", "רבי יוסף צוברי"),
    ("5-21", "רבי דוד הגר", "5-21", "אדמו\"ר רבי דוד האגר מזבלטוב"),
    ("5-23", "חכם חזקיה שבתי", "5-23", "רבי חזקיה שבתאי"),
    ("5-27", "ר' יהודה פתייה", "5-27", "חכם רבי יהודה פתיה"),
    ("5-6", "רבי נתן מז", "5-6", "רבי נתן מאז"),
    ("5-7", "הרב שמואל ינקוביץ'", "5-7", "רבי שמואל הכהן יאנקוביץ"),
    ("5-8", "חכם ברוך קאלומיטי", "5-8", "רבי ברוך קלומיטי"),
    ("6-2", "רבי אליעזר הגר", "6-2", "אדמו\"ר רבי אליעזר האגר מויז'ניץ"),
    ("6-20", "רבי אליהו לאפיאן", "6-20", "רבי אליהו לופיאן"),
    ("6-4", "חכם אברהם חכם", "6-4", "רבי אברהם חכם"),
    ("7-17", "חכם יצחק אליהו לניאדו", "7-17", "המקובל רבי יצחק לנייאדו"),
    ("7-19", "הגר\"א מווילנא", "7-19", "רבי אליהו הגאון מוילנא – הגר\"א"),
    ("7-2", "הרב סלמאן אליהו", "7-2", "המקובל רבי סלימאן אליהו"),
    ("7-23", "חכם נסים יצחק אלגרנטי", "7-23", "רבי ניסים יצחק אלגראנאטי"),
    ("8-10", "הרב דוב בעריש ויידנפלד", "8-10", "רבי דב בעריש ווידנפלד - הגאון מטשבין"),
    ("8-13", "רבי שמואל יצחק מודילינו", "8-13", "המקובל רבי שמואל מודילייאנו"),
    ("8-15", "רבי לייב בעל הייסורים", "8-15", "רבי אריה לייב בעל היסורים"),
    ("8-16", "הרב עמרם רוזנבוים", "8-16", "רבי עמרם רוזנבאום - חסידא"),
    ("8-18", "חכם אברהם פנסו", "8-18", "רבי אברהם פינסו"),
    ("8-2", "רבי ברוך הגר", "8-2", "אדמו\"ר רבי ברוך האגר מסערעט-ויז'ניץ"),
    ("8-29", "רבי נתן עמרם", "8-30", "רבי נתן עמרם"),
    ("8-8", "הרב ד\"ר שלמה טאג'ר", "8-8", "רבי שלמה טאג'יר"),
    ("8-9", "הרב ישראל קרדונר", "8-9", "רבי ישראל הלוי היילפרין קורדונר ברסלבר"),
    ("9-1", "הרב אפרים אנקווה", "9-1", "רבי אפרים אנקאווה"),
    ("9-1", "רבי משה הגר", "9-1", "אדמו\"ר רבי משה האגר מראדוביץ"),
    ("9-12", "רבי יצחק למפרונטי", "9-12", "רבי יצחק חזקיה לאמפרונטי"),
    ("9-14", "רבי דוד אבוחצירא", "9-14", "בבא דאו - רבי דוד אביחצירא"),
    ("9-20", "רבי ברוך הגר", "9-20", "אדמו\"ר רבי ברוך האגר מוויז'ניץ"),
    ("9-5", "רבי ברוך בר ליבוביץ", "9-5", "רבי ברוך דב לייבוביץ"),
    ("adar-11", "חכם מרדכי סבעוני (סיבוני)", "adar-11", "רבי מרדכי אסבעוני"),
    ("adar-19", "חכם שמעון חיררי", "adar-19", "המקובל רבי שמעון יהושע חירארי"),
    ("adar-20", "רבי דוד מג'אר", "adar-20", "המקובל רבי דוד מאג'אר"),
    ("adar-27", "רבי שלמה אלישיב", "adar-27", "המקובל רבי שלמה אלישוב"),
    ("adar1-29", "הרב יעקב קמינצקי", "adar1-29", "רבי יעקב קמנצקי"),
    ("adar2-12", "רבי יעקב קאשטרו (מהריק\"ש)", "adar2-12", "רבי יעקב קשטרו"),
    ("1-20", "רבי יחזקאל פנט", "1-20", "אדמו\"ר רבי יחזקאל פאנעט [הראשון] מדעש"),
    ("1-21", "מהריא\"ז ענזיל", "1-21", "רבי יקותיאל זלמן ענזל"),
    ("11-9", "חכם נתנאל חבובה", "11-9", "המקובל רבי נתנאל שחאדיה חבובא"),
    ("2-19", "הרב עזרא עטייה", "2-19", "רבי עזרא עטיא"),
    ("3-25", "רבי דוב בעריש מביאלה", "3-25", "אדמו\"ר רבי דב בעריש לנדא מביאלא"),
    ("3-27", "הרב מאיר איזנשטט (מהר\"ם אש)", "3-27", "רבי מאיר אייזנשטאט – ה'פנים מאירות'"),
    ("4-2", "רבי נחמן מהורדנקא", "4-2", "רבי נחמן מהורודנקה"),
    ("4-21", "רבי תנחום הירושלמי", "4-21", "רבי תנחום ירושלמי"),
    ("5-11", "רבי הלל מפאריץ'", "5-11", "רבי הלל הלוי מפאריטש"),
    ("5-7", "הרב שמחה בונים עהרנפלד", "5-7", "רבי שמחה בונם ארנפלד"),
    ("6-12", "רבי שמחה בונם מפשיסחה", "6-12", "אדמו\"ר רבי שמחה בונים בונהרד מפשיסחא"),
    ("7-30", "חכם כלפא גיג'", "7-30", "המקובל רבי כלפא גדג'"),
    ("9-22", "רבי יחזקאל פנט", "9-22", "אדמו\"ר רבי יחזקאל פאנעט [השני] מדעש"),
    ("adar-28", "חכם אברהם הכהן פימינטיל", "adar-28", "רבי אברהם כהן פימנטל"),
    ("adar-4", "חכם מכלוף פדידא", "adar-4", "רבי מכלוף פדידה [השני] – בבא עז'יז'י"),
    ("adar1-2", "רבי גבריאל אסקלס", "adar1-2", "רבי גבריאל עשקלס"),
    ("4-5", "חכם כליפה הכהן", "4-5", "המקובל רבי כליפה כהן"),
    ("7-5", "נפתלי", "7-5", "נפתלי בן יעקב ובלהה"),
    ("10-10", "רבי נתן מברסלב", "10-10", "רבי נתן שטרנהרץ - מוהרנ\"ת"),
    ("5-1", "הרב שמואל עהרנפעלד", "5-1", "רבי שמואל ארנפלד"),
    ("7-15", "רבי מרדכי לייפער", "7-15", "אדמו\"ר רבי מרדכי לייפר מנדבורנה"),
    ("4-27", "הרב אלעזר אבוחצירה", "4-27", "הבבא אלעזר – רבי אלעזר אבוחצירא"),
    ("4-27", "הרב אלעזר אבוחצירה", "4-27", "בבא אלעזר - רבי אלעזר אביחצירא"),
]

# Entrées dont la clé diffère de la dernière date de leur notice, constatées le 14/11/2026 et non tranchées
# (la notice peut citer une autre date que celle du décès) : à relire ; toute autre divergence fait échouer la construction.
ACCEPTEES = {
    ("10-29", "רבי ישראל חריף מסטנוב"),
    ("11-17", "הרב אליקים שלזינגר"),
    ("2-29", "רבי שמואל שלמה ליינר"),
    ("3-20", "רבי יחיאל מיכל מנמירוב"),
    ("3-8", "הרב אריה ליב פרומקין"),
    ("4-17", "הרב משה שמואל שפירא (בוברויסק)"),
    ("4-3", "רבי מנחם מנדל שניאורסון"),
    ("6-12", "הרב זאב נחום בורנשטיין"),
    ("6-5", "רבי ישעיה יעקב פורטוגל"),
    ("7-10", "הרב משה בּוֹצ'קוֹ"),
    ("7-13", "רבי שלום שכנא מפראהביטש"),
    ("7-14", "הרב גרשון פוזן"),
    ("7-19", "רבי אבי עזרא זליג שפירא"),
    ("7-19", "רבי יעקב יפה אשכנזי"),
    ("7-24", "רבי יהודה מינץ"),
    ("8-2", "רבי ברוך הגר"),
    ("8-24", "רבי אברהם אזולאי"),
    ("8-25", "רבי יצחק יואל רבינוביץ מליניץ"),
    ("8-3", "רבי יוסף יוזל הורוביץ"),
    ("8-5", "הרב אלכסנדר זושא פרידמן"),
    ("8-5", "רבי אברהם אבן מוסה"),
    ("9-10", "הרב אברהם הכהן יצחקי"),
    ("9-2", "הרב יהודה אבר"),
    ("adar-14", "הרב יוסף צבי הלוי"),
    ("adar-26", "הרב משה נחום ולנשטיין"),
}


def jour_hebreu(s):
    """« כ''ח » → 28 ; None si ce n'est pas un jour."""
    s = re.sub("[\"'״׳]", "", s)
    return sum(G[c] for c in s) if s and all(c in G for c in s) and 1 <= sum(G[c] for c in s) <= 30 else None


def complements(jours):
    """Hidabroot et תורת אמת (12/10) : les liens, les ajouts confirmés, une date corrigée."""
    # Hidabroot (hidabroot.org/article/1132443) : des faits seuls (nom, jour), et le
    # lien vers son article. Rapprochement fait à la lecture : tools/hilloulot/hidabroot.json.
    hida = json.load(open(os.path.join(ICI, "hilloulot", "hidabroot.json"), encoding="utf-8"))
    liens = 0
    for c in hida["correspondances"]:
        item = jours[c["notre_cle"]][c["notre_index"]]
        assert item["he"] == c["notre_he"], c
        if c.get("url"):
            item["i"] = c["url"]
            liens += 1
        if "i" not in item["s"]:
            item["s"] += "i"
    # Ajouts : absents de notre table, date confirmée par Wikipédia hébreu (deux sources).
    fichier = os.path.join(ICI, "hilloulot", "extraits_wiki_ajouts.json")
    extraits = json.load(open(fichier, encoding="utf-8")) if os.path.exists(fichier) else {}
    ajouts = 0
    for a in hida["absents"]:
        if a["statut"] != "confirmé":
            continue
        item = {"he": a["hida_nom"], "a": (a.get("annee") or "").replace(" (hewiki)", ""), "s": "iw", "w": a["wiki_article"]}
        if a["wiki_article"] in extraits:
            item["t"] = extraits[a["wiki_article"]]["texte"].strip()
        if a.get("url"):
            item["i"] = a["url"]
        jours.setdefault(a["cle"], []).append(item)
        ajouts += 1
    # Rav Shmouel Birnbaum : 28 Tevet (Wikipédia « כ"ח בטבת תשס"ח, 6 בינואר 2008 » ;
    # Hidabroot 29 Tevet) ; la page de date l'avait rangé au 28 Chevat.
    for i, item in enumerate(jours.get("11-28", [])):
        if item["he"] == "הרב שמואל ברנבוים":
            item["d"] = "date corrigée le 12/10 : 28 Tevet selon son article (la page du 28 Chevat le donnait)"
            jours.setdefault("10-28", []).append(jours["11-28"].pop(i))
            break
    # תורת אמת, « סדר הדורות המקוצר » (CC BY-NC-SA 2.5) : les fils de Jacob, datés.
    # Confirme nos entrées, ou ajoute celles que Hidabroot donne aussi au même jour.
    te = 0
    hida_jour = {(a["hida_nom"], a["cle"]) for a in hida["absents"]}
    for e in json.load(open(os.path.join(ICI, "hilloulot", "toratemet.json"), encoding="utf-8")):
        parties = e["date"].replace("ב", "", 1).split() if e["date"].startswith("ב") else e["date"].split()
        if len(parties) != 2 or parties[1] not in MOIS or jour_hebreu(parties[0]) is None:
            continue
        cle = f"{MOIS[parties[1]]}-{jour_hebreu(parties[0])}"
        nom = e["nom"]
        trouve = [x for x in jours.get(cle, []) if nom.split()[0] in x["he"]]
        for x in trouve:
            if "e" not in x["s"]:
                x["s"] += "e"
                te += 1
        if not trouve and any(n.startswith(nom.split()[0]) and k == cle for n, k in hida_jour):
            jours.setdefault(cle, []).append({"he": nom, "a": "", "s": "ie", "d": "figure biblique ; date de תורת אמת et de Hidabroot"})
            te += 1
    print(f"Hidabroot : {liens} liens, {ajouts} ajouts ; תורת אמת : {te} ;", end=" ")


TITRES = set('רבי הרב ר רב חכם האדמו"ר אדמו"ר האדמור אדמור המקובל מקובל התנא רבנו רבינו מרן הגאון הצדיק '
             'הרה"ק הרבנית רבנית בעל ה בן בר זצ"ל זיע"א זצוק"ל מוהר"ר הקדוש החכם השר אבינו אמנו הנביא'.split())


def mots(nom):
    """Les mots qui distinguent un nom : sans niqqoud, ponctuation ni titres ; les
    sigles gardent leurs lettres (הגר"א → הגרא)."""
    nom = re.sub("[\u0591-\u05C7]", "", nom)
    nom = re.sub("[\"'׳״`]", "", nom)
    nom = re.sub("[,.()\\[\\]\\-–:;]", " ", nom)
    return [w for w in nom.split() if w not in TITRES and len(w) > 1]


def cle_de(date):
    """« כ"ו אייר », « ט' בסיוון », « אדר ב' » … → la clé du jour, ou None."""
    p = re.sub("מנחם[ -]אב", "אב", date).replace("מרחשון", "מרחשוון").replace("־", " ").split()
    if len(p) < 2 or jour_hebreu(p[0]) is None:
        return None
    m = " ".join(p[1:])
    m = m[1:] if m.startswith("ב") and m[1:].split()[0] in MOIS else m
    m = {"אדר א'": "adar1", "אדר ב'": "adar2", "אדר א׳": "adar1", "אדר ב׳": "adar2"}.get(m) or MOIS.get(m.split()[0])
    return f"{m}-{jour_hebreu(p[0])}" if m else None


def sans_balisage(texte):
    """Ôte la mise en forme Markdown laissée par l'extraction (« ## », « ** », liens),
    sans toucher aux mots ; trois lignes vides au plus deviennent une seule."""
    texte = re.sub(r"(?m)^\s*#+\s*", "", texte)
    texte = texte.replace("**", "").replace("__", "")
    texte = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", texte)
    return espaces(re.sub(r"\n{3,}", "\n\n", texte).strip())


# La ponctuation collée au mot suivant (« משאץ.בשנת », 3 444 cas, capture du 28/10) : les
# sauts de ligne de la source se sont perdus à l'extraction. Une espace après . , ; : ! ?
# suivis d'une lettre hébraïque ; pas dans un nom de domaine (« קברים.קום »), pas dans
# un nombre (« 3.5 »), pas entre deux guillemets d'abréviation.
PONCTUATION_COLLEE = re.compile(r"(?<=[\u05D0-\u05EA\"'״׳)\]])([.,;:!?])(?=[\u05D0-\u05EA(])(?!קום\b|קו\.)")


def espaces(texte):
    return PONCTUATION_COLLEE.sub(r"\1 ", texte)


# Résidus des biographies MyTzadik / המאיר לארץ (audit du 12/11/2026, THILLOULOT-06, -08, -11) : marqueurs
# de liens « (ק1/ק2) », « [להאזנה] », crédits de photos qui n'apparaissent pas dans l'application,
# dédicaces, et coordonnées personnelles de tiers (courriel, téléphone, adresse) : on coupe du
# marqueur à la fin de la ligne, au lieu de supprimer la ligne entière.
# Relecture du 15/11 : la prose reste. « באדיבות » seul n'est pas un crédit dans « באדיבותו » ni dans
# « התייחס באדיבות ובמאור פנים » ; « לעילוי נשמת » n'est une dédicace qu'en tête de ligne, après
# « תמונת הציון מפורסמת », ou suivi de près d'un « ז"ל » (« להדליק נר לעילוי נשמתו » reste) ; la tête
# du crédit (« תמונת הציון », « התמונה »), seule sur la ligne d'avant, et la suite d'une dédicace sur
# plusieurs lignes partent avec lui ; seules les lignes coupées perdent leur ponctuation finale.
LIENS_SOURCE = re.compile(r"\s*\(ק\d*(?:/ק\d*)*\)|\s*\[ל(?:האזנה|צפייה|קריאה)\]")
TETE_CREDIT = r"(?:ה?תמונ(?:ה|ות|ת)|הצילומ(?:ים)?|צילום|המידע)"
ADIVOUT = r"באדיבות(?!ו)(?!\s+וב)"
CREDIT = re.compile(rf"{TETE_CREDIT}[^\n.!?]{{0,80}}?{ADIVOUT}|{ADIVOUT}")
TNTSBH = r"ת\. ?נ\. ?צ\. ?ב\. ?ה"
# « לזכות » : seul sur sa ligne (« לזכות ולהצלחת »), ou collé au nom (« לזכותישראל ינון בן דוד ») ;
# « לזכותו של מרן », « לזכותי » restent.
DEDICACE = re.compile(rf"{TETE_CREDIT}[^\n.]{{0,40}}?לעילוי נשמת|^\s*לעילוי נשמת"
                      rf"|לעילוי נשמת(?=[^\n.]{{0,50}}?(?:ז\"ל|ע\"ה|{TNTSBH}))"
                      r"|^\s*לזכות(?:\s+ול[א-ת]+)?\s*$|לזכות(?=[א-ת][^\n.]{0,30}?\s(?:בן|בת)[\s-])")
SUITE_DEDICACE = re.compile(rf"^\s*(?:ש?נפטר|שיום|ו?נטמנ|באדיבות|{TNTSBH}|[^\n]{{0,40}}ז\"ל"
                            r"|ובני ביתו|לשפע|להצלחת|[^\n]{0,40}\s(?:בן|בת)[\s-])")
SUITE_CREDIT = re.compile(r"^\s*(?:מחבר הספר|הרב הראשי ל)")
TETE_SEULE = re.compile(rf"^\s*{TETE_CREDIT}(?:\s+\S+){{0,4}}\s*$")
CONTACT = re.compile(r"(?<![א-ת])(?:דוא\"ל|דוא״ל|טלפון|טל['׳]|טל/פקס|טל-פקס|סלולר|סלולאר)\s*[:.]?\s*(?=[\d+@A-Za-z-])"
                     r"|WhatsApp|וואטסאפ|סלולאר|להעברת שמות|חייגו|ת\. ?ד\. ?\d")
COURRIEL = re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+")
TELEPHONE = re.compile(r"(?<![\d-])(?:\+?972|0\d{1,2})[- ]?\d[\d -]{5,}\d")
COLLES = re.compile(r"(?<=ז\"ל)(?=[א-ת])")


def nettoie_bio(texte):
    sortie, suite = [], None
    for ligne in COLLES.sub(" ", LIENS_SOURCE.sub("", texte)).split("\n"):
        if suite is not None and suite.match(ligne):
            continue
        suite, coupe, avant = None, None, ligne
        for motif in (CREDIT, DEDICACE, CONTACT):
            m = motif.search(ligne)
            if m and (coupe is None or m.start() < coupe[0]):
                coupe = (m.start(), motif)
        if coupe:
            suite = SUITE_DEDICACE if coupe[1] is DEDICACE else SUITE_CREDIT
            ligne = ligne[:coupe[0]]
            if not ligne.strip() and sortie and TETE_SEULE.match(sortie[-1]):
                sortie.pop()
        ligne = TELEPHONE.sub("", COURRIEL.sub("", ligne))
        if ligne != avant:
            ligne = ligne.rstrip(" ,;:-–")
        sortie.append(ligne if ligne.strip() else "")
    return re.sub(r"\n{3,}", "\n\n", "\n".join(sortie)).strip()


def annee_normalisee(a):
    """Formes fautives des années hébraïques (audit du 12/11/2026, THILLOULOT-18) : « התר"ץ » → « ה'תר"ץ »,
    « הש"ס » → « ה'ש"ס », « תרח"ץ » → « תרצ"ח ». Les autres formes sont laissées telles quelles."""
    a = a.strip()
    if a == 'תרח"ץ':
        return 'תרצ"ח'
    if a == 'הש"ס':
        return "ה'ש\"ס"
    return re.sub(r"^ה(ת[א-ת]*\"[א-ת])$", r"ה'\1", a)


def sources_autorisees(jours):
    """MyTzadik et המאיר לארץ (12/10) : reprise autorisée avec mention, accord reçu par le
    propriétaire de l'app. Leur biographie, mot pour mot, s'ajoute au tsaddik du même jour
    quand les noms concordent ; sinon le tsaddik est ajouté, avec cette seule source."""
    communs = collections.Counter(w for v in jours.values() for x in v for w in mots(x["he"]))

    def candidats(cle):
        if cle.startswith("adar"):
            return [x for k in ("adar", "adar1", "adar2") for x in jours.get(f"{k}-{cle.split('-')[1]}", [])]
        return jours.get(cle, [])

    def score(a, x):
        m = mots(x["he"])
        c = a & set(m)
        rares = [w for w in c if communs[w] < 15]
        # Un seul mot commun ne suffit que s'il est rare et que c'est le dernier de notre nom
        # (un nom de famille, un lieu, un sigle) : « דניאל » seul ne fait pas la même personne.
        return len(c) + len(rares) if len(c) >= 2 or (rares and m and m[-1] in rares) else 0

    def apparier(nom, cle):
        """Le même jour seulement. Un rapprochement d'un jour à l'autre confondait des
        homonymes d'une même dynastie (12/10) : un tsaddik dont la date diffère de la
        nôtre est ajouté à sa date, avec sa source."""
        a = set(mots(nom))
        meilleur = max(((score(a, x), x) for x in candidats(cle)), key=lambda t: t[0], default=(0, None))
        return (meilleur[1], False) if meilleur[0] else (None, False)

    for code, fichier in (("l", "hameir.json"), ("m", "mytzadik.json")):
        chemin = os.path.join(ICI, "hilloulot", fichier)
        if not os.path.exists(chemin):
            continue
        lies = ajoutes = 0
        for e in json.load(open(chemin, encoding="utf-8")):
            cle = cle_de(e.get("date") or "")
            if not cle:
                continue
            bio = nettoie_bio(sans_balisage(e.get("bio") or ""))
            x, _ = apparier(e["nom"], cle)
            if x is None:
                x = {"he": e["nom"].strip(), "a": "", "s": ""}
                jours.setdefault(cle, []).append(x)
                ajoutes += 1
            else:
                lies += 1
            if code not in x["s"]:
                x["s"] += code
            if bio and not any(b[0] == code for b in x.get("b", [])):
                x.setdefault("b", []).append([code, bio, e.get("url") or ""])
        print(f"{fichier} : {lies} rapprochés, {ajoutes} ajoutés ;", end=" ")

MOIS_NOTICE = ("ניסן|אייר|סיוון|סיון|תמוז|מנחם[ -]אב|אב|אלול|תשרי|חשוון|מרחשוון|מרחשון|חשון|כסלו|טבת|שבט|"
               "אדר(?:\\s*[אב]['׳])?")
DATE_NOTICE = re.compile(r"((?:[א-ת][\"'״׳]?){1,4})\s+ב(" + MOIS_NOTICE + ")")


def derniere_date(texte):
    """La clé « mois-jour » de la dernière date hébraïque (« כ״ו באייר ») d'une notice, ou None."""
    cle = None
    for m in DATE_NOTICE.finditer(texte):
        jour = m.group(1)
        sans = re.sub("[\"'״׳]", "", jour)
        if len(sans) > 1 and sans[0] == "ב" and jour_hebreu(sans[1:]) is not None:
            jour = jour[1:]  # « בכ"ג » : le ב est la préposition
        if jour_hebreu(jour) is None:
            continue
        cle = cle_de(f"{jour} {m.group(2)}") or cle
    return cle


def verifier_notices(jours):
    """THILLOULOT-05 : la clé d'une entrée doit être celle de la dernière date de sa notice, sauf doute
    consigné (« d ») ou entrée de ACCEPTEES. « adar », « adar1 » et « adar2 » sont un même mois ici."""
    famille = lambda c: "adar-" + c.split("-")[1] if c.startswith("adar") else c
    ecarts = [(cle, x["he"]) for cle, liste in jours.items() for x in liste
              if x.get("t") and not x.get("d") and (notice := derniere_date(x["t"])) and famille(notice) != famille(cle)
              and (cle, x["he"]) not in ACCEPTEES]
    assert not ecarts, f"clé différente de la date de la notice, sans doute consigné : {ecarts}"


def corriger(jours):
    """CORRECTIONS : l'entrée change de jour et/ou d'année ; elle garde ses notices et son rang de lecture."""
    for cle, nom, nouvelle, annee in CORRECTIONS:
        trouves = [x for x in jours.get(cle, []) if x["he"].startswith(nom)]
        assert len(trouves) == 1, (cle, nom, len(trouves))
        x = trouves[0]
        if annee:
            x["a"] = annee
        if nouvelle:
            jours[cle].remove(x)
            jours.setdefault(nouvelle, []).append(x)


def fusionner(jours):
    """DOUBLONS : voir plus haut."""
    def trouve(cle, nom, seule):
        # seule : l'entrée de MyTzadik / המאיר לארץ seule ; None : une entrée d'une autre source (même nom).
        l = [x for x in jours.get(cle, []) if x["he"].strip() == nom
             and (seule is None or seule == (set(x["s"]) <= set("ml")))]
        assert len(l) == 1, (cle, nom, len(l))
        return l[0]
    for cle, nom, cle2, nom2 in DOUBLONS:
        garde, autre = trouve(cle, nom, False if nom == nom2 and cle == cle2 else None), trouve(cle2, nom2, True)
        assert garde is not autre
        for c in autre["s"]:
            if c not in garde["s"]:
                garde["s"] += c
        for b in autre.get("b", []):
            if not any(g[0] == b[0] for g in garde.get("b", [])):
                garde.setdefault("b", []).append(b)
        jours[cle2].remove(autre)
    return len(DOUBLONS)


def main():
    jours, total, retires = {}, 0, 0
    for lot in (1, 2, 3, 4):
        for e in json.load(open(os.path.join(ICI, "hilloulot", f"hilloulot_{lot}.json"), encoding="utf-8")):
            if any(e["mois"] == m and e["jour"] == j and e["he"].startswith(n) for m, j, n in RETIRES):
                retires += 1
                continue
            for (m, j, n), a in ANNEES.items():
                if e["mois"] == m and e["jour"] == j and e["he"].startswith(n):
                    e["doute"] = (e.get("doute") or "") + f" ; année de החכם היומי retenue ({a}) au lieu de {e['annee']}"
                    e["annee"] = a
            cle = f"{MOIS[e['mois'].strip()]}-{int(e['jour'])}"
            sources = sorted({"w" if "wikipedia" in s else "h" for s in e["sources"]})
            item = {"he": e["he"].strip(), "a": e.get("annee") or "", "s": "".join(sources)}
            for k in ("fr", "en"):
                if e.get(k):
                    item[k] = e[k]
            if e.get("doute"):
                item["d"] = e["doute"].strip(" ;")
            jours.setdefault(cle, []).append(item)
            total += 1
    # La première phrase de l'article de Wikipédia hébreu (CC BY-SA 4.0), relevée
    # mot pour mot le 11/10/2026 (tools/hilloulot/descriptions.json : la raison
    # de chaque absence, de chaque coupe ou retouche est dans « note »).
    decrits = 0
    for e in json.load(open(os.path.join(ICI, "hilloulot", "descriptions.json"), encoding="utf-8")):
        item = jours[e["cle"]][e["index"]]
        assert item["he"] == e["he"], (e["cle"], e["index"], e["he"])
        if e.get("article") and e.get("description"):
            item["t"], item["w"] = e["description"], e["article"]
            decrits += 1
    # Plus de détails (12/10) : le début de l'article, jusqu'à six phrases de son
    # introduction, mot pour mot (API de Wikipédia hébreu, prop=extracts, exintro,
    # exsentences=6, relevé le 12/10/2026 : tools/hilloulot/extraits_wiki.json).
    # Il remplace la première phrase quand il en dit plus.
    fichier = os.path.join(ICI, "hilloulot", "extraits_wiki.json")
    extraits = json.load(open(fichier, encoding="utf-8")) if os.path.exists(fichier) else {}
    allonges = 0
    for liste in jours.values():
        for item in liste:
            x = extraits.get(item.get("w") or "")
            if x and len(x["texte"].strip()) > len(item.get("t", "")):
                item["t"] = x["texte"].strip()
                allonges += 1
    print(f"{allonges} descriptions allongées ;", end=" ")
    complements(jours)
    corriger(jours)
    sources_autorisees(jours)
    fusionnes = fusionner(jours)
    verifier_notices(jours)
    print(f"{fusionnes} doublons fusionnés ;", end=" ")
    sortie = {
        "_meta": {
            "date": "2026-10-12",
            "sources": ["Wikipédia hébreu, pages de date, section נפטרו (CC BY-SA 4.0)",
                        "החכם היומי, hyomi.org.il (Kol Israël 'Haverim) : faits seuls (nom, date)",
                        "Hidabroot, hidabroot.org/article/1132443 : faits seuls (nom, date) et lien vers ses articles",
                        "תורת אמת, סדר הדורות המקוצר (CC BY-NC-SA 2.5)",
                        "MyTzadik, mytzadik.com (YETEV 4 LTD) : reprise autorisée avec mention, accord reçu par le propriétaire de l'app le 12/10/2026",
                        "המאיר לארץ, hameir-laarets.org.il : reprise autorisée avec mention, accord reçu par le propriétaire de l'app le 12/10/2026"],
            "s": "w = Wikipédia, h = החכם היומי, i = Hidabroot, e = תורת אמת, m = MyTzadik, l = המאיר לארץ",
            "i": "lien vers l'article de Hidabroot",
            "b": "hilloulot_bios.json : par jour et dans le même ordre, les biographies d'autres sources, mot pour mot : [source, texte, lien], ou 0",
            "regles": "Désaccord : החכם היומי l'emporte. « adar » : Adar II les années embolismiques (OH 568:7). "
                      "Un 30 absent cette année se dit le 29.",
            "d": "raison d'un doute (personne, date ou année) relevée à la lecture",
            "t": "début de l'article de Wikipédia hébreu (CC BY-SA 4.0), jusqu'à six phrases ; w : son titre",
        },
        "jours": dict(sorted(jours.items())),
    }
    # Les biographies longues (MyTzadik, המאיר לארץ) à part : hilloulot.json reste léger pour la
    # carte du jour ; hilloulot_bios.json n'est lu qu'à l'écran des hilloulot. Par jour, une
    # entrée par hilloula, dans le même ordre : ses biographies, ou 0.
    bios = {}
    for cle, liste in sortie["jours"].items():
        for x in liste:
            if x.get("a"):
                x["a"] = annee_normalisee(x["a"])
        ligne = [x.pop("b", 0) for x in liste]
        if any(ligne):
            bios[cle] = ligne
    raw = os.path.join(ICI, "..", "android", "app", "src", "main", "res", "raw")
    json.dump(bios, open(os.path.join(raw, "hilloulot_bios.json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    chemin = os.path.join(raw, "hilloulot.json")
    json.dump(sortie, open(chemin, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    print(f"{decrits} descriptions ;", end=" ")
    total = sum(len(v) for v in jours.values())
    print(f"{total} hilloulot, {len(jours)} jours, {retires} entrées Wikipédia retirées ; {os.path.getsize(chemin)//1024} Ko")


if __name__ == "__main__":
    main()
