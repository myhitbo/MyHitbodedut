# -*- coding: utf-8 -*-
"""
Construit la lecture de la Torah des offices de semaine (demande du 26/11/2026 : « le texte de la paracha
concordant le jour de lecture de la Torah ») :

  android/app/src/main/res/raw/lecture_torah.json        les lectures : montées et titres
  android/app/src/main/res/raw/lecture_torah_texte.json  le texte des chapitres lus

Le périmètre est celui du siddour de l'application, qui n'a que les offices de semaine : Cha'harit le lundi et
le jeudi, à Roch 'Hodech, à 'Hol hamoèd, à 'Hanouka, à Pourim et aux jeûnes publics (9 Av compris), Min'ha des
jeûnes publics ; jamais Chabbat ni Yom tov. Le calcul du jour (quelle lecture, quel office) est dans
LectureTorah.kt et son jumeau web/src/js/lecture-torah.js ; ce script ne fait que les données.

Sources
-------
- Découpage des montées : @hebcal/leyning 10.1.0 (npm, licence BSD-2-Clause, Copyright (c) 2020, hebcal ;
  la notice est recopiée dans _meta.licences). Fichiers dist/esm/aliyot.json.js (« weekday » : lundi et
  jeudi) et dist/esm/holiday-readings.json.js de l'archive publiée, dont l'empreinte sha512 est vérifiée
  contre celle du registre npm.
- Texte : « Tanach with Ta'amei Hamikra » (tanach.us, Westminster Leningrad Codex, domaine public), par
  l'export public de Sefaria, comme les Tehilim de l'application (qui prennent la version « with Nikkud »,
  sans les teamim) ; ici les teamim sont gardés, pour lire. Seuls les chapitres d'une lecture de semaine
  sont gardés.
  Le qere est retenu (forme lue), comme pour les Tehilim (tools/tehilim_conversion.py), avec un
  traitement qui connaît les ketiv de plusieurs mots (qere ci-dessous) ; le Nom reste en toutes
  lettres, tel que dans l'édition (décision du 04/10 pour les versets, tools/noms_abreges.py) ;
  les marques de paragraphe « (פ) » et « (ס) » sont retirées du texte et gardées à part.
- Contrôle du texte : chaque verset gardé est confronté, lettres seules, à « Miqra according to the
  Masorah » (Codex d'Alep, CC-BY-SA, export Sefaria) ; rien n'en est repris, les écarts sont classés
  dans _meta.verification.

Coutumes (Edot = Choul'han Aroukh et Kitsour Yalkout Yossef, le livre de l'application ;
Sfard = Ashkenaz pour les lectures, voir NOTE_SFARD). Chaque écart avec hebcal est écrit plus bas,
avec sa source.

  python3 tools/lecture_torah_construction.py <dossier de cache>
  python3 tools/lecture_torah_construction.py --test     (contrôles du qere, sans réseau)

Le dossier reçoit ce qui est téléchargé (archive npm, exports Sefaria) ; relancé, le script
ne télécharge que ce qui manque.
"""
import base64, hashlib, json, os, re, sys, tarfile, time, unicodedata, urllib.parse, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

NFC = lambda s: unicodedata.normalize("NFC", s)
RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RAW = os.path.join(RACINE, "android", "app", "src", "main", "res", "raw")

LEYNING_VERSION = "10.1.0"
LEYNING_TGZ = f"https://registry.npmjs.org/@hebcal/leyning/-/leyning-{LEYNING_VERSION}.tgz"
EXPORT = "https://storage.googleapis.com/sefaria-export/json/Tanakh/Torah/{livre}/Hebrew/{version}.json"
TAAMIM = "Tanach with Ta'amei Hamikra"
ALEP = "Miqra according to the Masorah"

TORAH = ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy"]

# Relu le 26/11 : les écarts restants ne sont pas des erreurs de conversion.
NOTES_ALEP = {
    "Numbers 25:19": "Bamidbar 25:19 et 26:1, la numérotation (un seul verset dans les deux codex)",
    "Numbers 26:1": None,
}

NOTE_SFARD = (
    "Noussa'h Sfard : les lectures d'Ashkenaz. Le noussa'h Sfard (Siddour Sefard, Metsoudah et Torat Emet, "
    "celui de l'application) est le siddour des communautés 'hassidiques, ashkénazes de coutume : il change le "
    "texte des prières, pas l'usage de la lecture (Encyclopédie Daat, « נוסח ספרד בתפילה » : « נוסח הוצאת ספר "
    "תורה והכנסת ספר תורה כמו בנוסח אשכנז »)."
)


# --------------------------------------------------------------------------------------
# Téléchargements
# --------------------------------------------------------------------------------------

def telecharge(url, chemin):
    if os.path.exists(chemin) and os.path.getsize(chemin) > 0:
        return
    for essai in range(5):
        try:
            with urllib.request.urlopen(url, timeout=120) as r:
                donnees = r.read()
            with open(chemin, "wb") as f:
                f.write(donnees)
            return
        except Exception as e:  # réseau : on réessaie
            print("nouvel essai", url, e, file=sys.stderr)
            time.sleep(2 ** essai)
    raise SystemExit(f"téléchargement impossible : {url}")


def charge_leyning(cache):
    """aliyot.json, holiday-readings.json et numverses.json de l'archive npm, empreinte vérifiée."""
    chemin = os.path.join(cache, f"leyning-{LEYNING_VERSION}.tgz")
    telecharge(LEYNING_TGZ, chemin)
    meta = os.path.join(cache, "leyning-registre.json")
    telecharge("https://registry.npmjs.org/@hebcal/leyning", meta)
    attendu = json.load(open(meta, encoding="utf-8"))["versions"][LEYNING_VERSION]["dist"]["integrity"]
    obtenu = "sha512-" + base64.b64encode(hashlib.sha512(open(chemin, "rb").read()).digest()).decode()
    if obtenu != attendu:
        raise SystemExit(f"empreinte de l'archive hebcal inattendue : {obtenu}")
    sortie = {}
    with tarfile.open(chemin, "r:gz") as tgz:
        for nom in ("aliyot", "holiday-readings", "numverses"):
            js = tgz.extractfile(f"package/dist/esm/{nom}.json.js").read().decode("utf-8")
            js = re.sub(r"//# sourceMappingURL=.*$", "", js.strip()).strip()
            if not js.startswith("export default"):
                raise SystemExit(f"{nom}.json.js : forme inattendue")
            sortie[nom] = json.loads(js[len("export default"):].strip().rstrip(";"))
        licence = tgz.extractfile("package/LICENSE").read().decode("utf-8")
    return sortie["aliyot"], sortie["holiday-readings"], sortie["numverses"], licence, attendu


def charge_livre(cache, livre, version):
    nom = f"{livre.replace(' ', '_')}__{version.replace(' ', '_').replace(chr(39), '')}.json"
    chemin = os.path.join(cache, nom)
    url = EXPORT.format(livre=urllib.parse.quote(livre), version=urllib.parse.quote(version))
    telecharge(url, chemin)
    d = json.load(open(chemin, encoding="utf-8"))
    if d.get("license") not in ("Public Domain", "CC-BY-SA"):
        raise SystemExit(f"{livre} ({version}) : licence {d.get('license')}")
    return d


# --------------------------------------------------------------------------------------
# Le texte
# --------------------------------------------------------------------------------------

VOYELLE = re.compile("[\u05B0-\u05BC\u05C1\u05C2\u05C7]")


def qere(v):
    """
    Le qere à la place du ketiv. Dans l'édition, le ketiv est écrit sans voyelles et suivi du qere
    entre crochets : « הוצא [הַיְצֵ֣א] ». tools/tehilim_conversion.py ne connaît qu'un mot de chaque
    côté ; ici le ketiv est la suite des mots sans voyelles qui précède, et le qere la suite des
    crochets qui suit : « לו־עשה [לֹֽא־] [יַעֲשֶׂ֨ה] » (Chemouel I 20:2) donne « לֹֽא־יַעֲשֶׂ֨ה ». Un
    ketiv sans qere (« מות [] ») n'est pas lu ; un qere sans ketiv l'est.
    """
    # Les mots et les groupes entre crochets ; un ketiv collé à son qere (« לך־[לְכָה־] », Bamidbar
    # 23:13) en est séparé, un qere peut contenir une espace (« [הַמֵּא֣וֹת ׀] », Melakhim II 11:15).
    mots = re.findall(r"\[[^\]]*\]|[^\s\[]+", v)
    if "".join(mots).count("[") != v.count("["):
        raise SystemExit(f"crochets inattendus : {v}")
    sortie = []
    i = 0
    while i < len(mots):
        if not mots[i].startswith("["):
            sortie.append(mots[i])
            i += 1
            continue
        lus = []
        while i < len(mots) and mots[i].startswith("["):
            lus.append(mots[i][1:-1])
            i += 1
        # Le ketiv : les mots sans voyelles juste avant ; un préfixe vocalisé lié par maqaf reste.
        prefixe = ""
        while sortie and sortie[-1] and not VOYELLE.search(sortie[-1]):
            sortie.pop()
        if sortie and "\u05BE" in sortie[-1]:
            avant, _, apres = sortie[-1].rpartition("\u05BE")
            if apres and not VOYELLE.search(apres):
                sortie.pop()
                prefixe = avant + "\u05BE"
        lu = " ".join(x for x in lus if x).replace("\u05BE ", "\u05BE")
        if lu or prefixe:
            sortie.append(prefixe + lu)
    return re.sub(r"\s{2,}", " ", " ".join(sortie).replace("\u05BE ", "\u05BE")).strip()


KETIV_SEUL = []


def sans_ketiv(v):
    """
    Un mot écrit sans voyelles et sans crochets est un ketiv qui ne se lit pas (כתיב ולא קרי, « (נא) »
    dans Miqra al pi ha-Massora, Melakhim II 5:18) : retiré, comme « mot [] » chez les Tehilim. Lié par
    maqaf, le mot d'avant se lie au suivant (« יִסְלַח־נא יְהוָ֥ה » → « יִסְלַח־יְהוָ֥ה »).
    """
    mots, n = v.split(" "), 0
    sortie = []
    for mot in mots:
        parts = mot.split("\u05BE")
        gardes = [x for x in parts if not (HEBREU.search(x) and not VOYELLE.search(x) and x != "׀")]
        n += len(parts) - len(gardes)
        if not gardes:
            continue
        neuf = "\u05BE".join(gardes)
        if parts[-1] not in gardes and len(gardes) < len(parts):
            neuf += "\u05BE"
        if sortie and sortie[-1].endswith("\u05BE"):
            sortie[-1] += neuf
        else:
            sortie.append(neuf)
    return " ".join(sortie), n


MARQUE = re.compile(r"\s*\((פ|ס)\)\s*$")
HEBREU = re.compile("[א-ת]")


def verset(brut):
    """Le verset lu : qere retenu, teamim gardés, marque de paragraphe à part."""
    v = NFC(brut).replace("‍", "")
    # Les nun inversés de Bamidbar 10:35-36, « (׆) » dans l'édition : gardés sans parenthèses, comme les
    # 'houmachim imprimés les montrent.
    v = v.replace("(׆)", "׆")
    m = MARQUE.search(v)
    fin = m.group(1) if m else None
    v = MARQUE.sub("", v)
    # Une « פסקא באמצע פסוק » (Berèchit 35:22…) : la marque est retirée, le verset reste d'un tenant.
    milieu = bool(re.search(r"\((פ|ס)\)", v))
    v = re.sub(r"\s*\((פ|ס)\)\s*", " ", v)
    v = NFC(qere(v))
    v, n = sans_ketiv(v)
    if n:
        KETIV_SEUL.append(v)
    if "[" in v or "]" in v or "<" in v or "{" in v:
        raise SystemExit(f"reste de balisage : {v}")
    # Aucun mot sans voyelles ne doit rester (ketiv non résolu).
    for mot in re.split(r"[\s־]+", v):
        if HEBREU.search(mot) and not re.search("[ְ-ׇּ]", mot) and mot not in ("׀",):
            raise SystemExit(f"mot sans voyelles (ketiv ?) : {mot} dans {v}")
    return v, fin, milieu


def aligne(livre, texte, nv, decoupes):
    """
    La numérotation d'hebcal, celle des 'houmachim imprimés : quand un chapitre de l'édition a un verset
    de moins et que le premier verset du chapitre suivant porte une marque de paragraphe en son milieu,
    la première moitié est le dernier verset du chapitre (Bamidbar 25:19, « ויהי אחרי המגפה », que le
    codex de Leningrad joint à 26:1). Rien d'autre n'est déplacé.
    """
    texte = [list(c) for c in texte]
    for c in range(1, len(texte)):
        if len(texte[c - 1]) == nv[c] - 1 and len(texte[c]) == nv[c + 1]:
            m = re.search(r"\s*\((פ|ס)\)\s*", texte[c][0])
            if m:
                texte[c - 1].append(texte[c][0][:m.end()].strip())
                texte[c][0] = texte[c][0][m.end():]
                decoupes.append(f"{livre} {c}:{nv[c]} / {c + 1}:1")
    return texte


def lettres(s):
    """Les seules lettres, pour comparer deux éditions."""
    s = re.sub(r"\[[^\]]*\]", "", s)  # qere de l'édition d'Alep, entre crochets dans l'export
    return re.sub("[^א-ת]", "", s)


# --------------------------------------------------------------------------------------
# Libellés
# --------------------------------------------------------------------------------------

def T(he, fr, en):
    return {"he": NFC(he), "fr": fr, "en": en}


# Les noms des livres : les noms hébreux, écrits à la manière de chaque langue (demande du 26/11 : « Mets les noms en
# hébreu écrits en français, en anglais en fonction du mode ») ; en français comme ailleurs dans l'application (ש « ch »,
# ח « ’h » : Berèchit, Chemot… des parachiot), en anglais comme les parachiot d'hebcal (Bereshit, Shemot, Vayishlach).
# L'espagnol et l'arabe tunisien prennent l'hébreu, comme les noms des parachiot (LocalizedText.forLanguage).
LIVRES = {
    "Genesis": T("בראשית", "Berèchit", "Bereshit"), "Exodus": T("שמות", "Chemot", "Shemot"),
    "Leviticus": T("ויקרא", "Vayikra", "Vayikra"), "Numbers": T("במדבר", "Bamidbar", "Bamidbar"),
    "Deuteronomy": T("דברים", "Devarim", "Devarim"),
}


# Les montées. « 3_israel » : le troisième d'une lecture de trois (lundi, jeudi, jeûnes…) ; « M » : le troisième
# monté de Min'ha d'un jeûne, maftir chez Ashkenaz et Sfard, et le 9 Av chez les Edot.
MONTEES = {
    "1": T("כהן", "Cohen", "Kohen"),
    "2": T("לוי", "Lévi", "Levi"),
    "3": T("שלישי", "Chelichi", "Shlishi"),
    "3_israel": T("ישראל", "Israël", "Yisrael"),
    "4": T("רביעי", "Revi’i", "Revi'i"),
    "M": T("מפטיר", "Maftir", "Maftir"),
}

# Les parachiot, par l'énumération Parsha de KosherJava (celle de l'application, web/src/js/halakha.js) ;
# l'hébreu est celui de KosherJava (HebrewDateFormatter, ce que l'application affiche déjà).
PARACHIOT = [
    ("BERESHIS", "Bereshit", "בראשית", "Berèchit"), ("NOACH", "Noach", "נח", "Noa’h"),
    ("LECH_LECHA", "Lech-Lecha", "לך לך", "Lekh lekha"), ("VAYERA", "Vayera", "וירא", "Vayéra"),
    ("CHAYEI_SARA", "Chayei Sara", "חיי שרה", "’Hayé Sarah"), ("TOLDOS", "Toldot", "תולדות", "Toledot"),
    ("VAYETZEI", "Vayetzei", "ויצא", "Vayétsé"), ("VAYISHLACH", "Vayishlach", "וישלח", "Vayichla’h"),
    ("VAYESHEV", "Vayeshev", "וישב", "Vayéchev"), ("MIKETZ", "Miketz", "מקץ", "Mikets"),
    ("VAYIGASH", "Vayigash", "ויגש", "Vayigach"), ("VAYECHI", "Vayechi", "ויחי", "Vay’hi"),
    ("SHEMOS", "Shemot", "שמות", "Chemot"), ("VAERA", "Vaera", "וארא", "Vaéra"), ("BO", "Bo", "בא", "Bo"),
    ("BESHALACH", "Beshalach", "בשלח", "Bechala’h"), ("YISRO", "Yitro", "יתרו", "Yitro"),
    ("MISHPATIM", "Mishpatim", "משפטים", "Michpatim"), ("TERUMAH", "Terumah", "תרומה", "Terouma"),
    ("TETZAVEH", "Tetzaveh", "תצוה", "Tetsavé"), ("KI_SISA", "Ki Tisa", "כי תשא", "Ki tissa"),
    ("VAYAKHEL", "Vayakhel", "ויקהל", "Vayakhel"), ("PEKUDEI", "Pekudei", "פקודי", "Pekoudé"),
    ("VAYIKRA", "Vayikra", "ויקרא", "Vayikra"), ("TZAV", "Tzav", "צו", "Tsav"),
    ("SHMINI", "Shmini", "שמיני", "Chemini"), ("TAZRIA", "Tazria", "תזריע", "Tazria"),
    ("METZORA", "Metzora", "מצרע", "Metsora"), ("ACHREI_MOS", "Achrei Mot", "אחרי מות", "A’haré mot"),
    ("KEDOSHIM", "Kedoshim", "קדושים", "Kedochim"), ("EMOR", "Emor", "אמור", "Emor"),
    ("BEHAR", "Behar", "בהר", "Behar"), ("BECHUKOSAI", "Bechukotai", "בחקתי", "Be’houkotaï"),
    ("BAMIDBAR", "Bamidbar", "במדבר", "Bamidbar"), ("NASSO", "Nasso", "נשא", "Nasso"),
    ("BEHAALOSCHA", "Beha'alotcha", "בהעלתך", "Beha’alotekha"), ("SHLACH", "Sh'lach", "שלח לך", "Chela’h lekha"),
    ("KORACH", "Korach", "קרח", "Kora’h"), ("CHUKAS", "Chukat", "חוקת", "’Houkat"),
    ("BALAK", "Balak", "בלק", "Balak"), ("PINCHAS", "Pinchas", "פינחס", "Pin’has"),
    ("MATOS", "Matot", "מטות", "Matot"), ("MASEI", "Masei", "מסעי", "Masé"),
    ("DEVARIM", "Devarim", "דברים", "Devarim"), ("VAESCHANAN", "Vaetchanan", "ואתחנן", "Vaèt’hanane"),
    ("EIKEV", "Eikev", "עקב", "Ékev"), ("REEH", "Re'eh", "ראה", "Reé"), ("SHOFTIM", "Shoftim", "שופטים", "Choftim"),
    ("KI_SEITZEI", "Ki Teitzei", "כי תצא", "Ki tétsé"), ("KI_SAVO", "Ki Tavo", "כי תבוא", "Ki tavo"),
    ("NITZAVIM", "Nitzavim", "נצבים", "Nitsavim"), ("VAYEILECH", "Vayeilech", "וילך", "Vayélekh"),
    ("HAAZINU", "Ha'azinu", "האזינו", "Haazinou"), ("VZOS_HABERACHA", "Vezot Haberakhah", "וזאת הברכה", "Vézot haBérakha"),
]
JOINTES = [
    ("VAYAKHEL_PEKUDEI", "VAYAKHEL", "PEKUDEI"), ("TAZRIA_METZORA", "TAZRIA", "METZORA"),
    ("ACHREI_MOS_KEDOSHIM", "ACHREI_MOS", "KEDOSHIM"), ("BEHAR_BECHUKOSAI", "BEHAR", "BECHUKOSAI"),
    ("CHUKAS_BALAK", "CHUKAS", "BALAK"), ("MATOS_MASEI", "MATOS", "MASEI"), ("NITZAVIM_VAYEILECH", "NITZAVIM", "VAYEILECH"),
]

# Les lectures des jours de semaine, par la clé de holiday-readings.json (le calcul les nomme ainsi).
TITRES = {
    "Rosh Chodesh": T("ראש חודש", "Roch ’Hodech", "Rosh Chodesh"),
    "Pesach Chol ha-Moed": T("חול המועד פסח", "’Hol hamoèd Pessa’h", "Chol HaMoed Pesach"),
    "Tzom Gedaliah": T("צום גדליה", "Jeûne de Guedalia", "Tzom Gedaliah"),
    "Asara B'Tevet": T("עשרה בטבת", "Jeûne du 10 Tévet", "Asara B'Tevet"),
    "Ta'anit Esther": T("תענית אסתר", "Jeûne d’Esther", "Ta'anit Esther"),
    "Tzom Tammuz": T("שבעה עשר בתמוז", "Jeûne du 17 Tamouz", "Tzom Tammuz"),
    "Tish'a B'Av": T("תשעה באב", "Ticha bèAv", "Tish'a B'Av"),
    "Sukkot Chol ha-Moed": T("חול המועד סוכות", "’Hol hamoèd Souccot", "Chol HaMoed Sukkot"),
    "Hoshana Raba": T("הושענא רבה", "Hochaana Rabba", "Hoshana Raba"),
    "Chanukah": T("חנוכה", "’Hanouka", "Chanukah"),
    "Purim": T("פורים", "Pourim", "Purim"),
    "Shushan Purim": T("פורים בירושלים (שושן פורים)", "Pourim à Jérusalem (Chouchan Pourim)", "Purim in Jerusalem (Shushan Purim)"),
}


# --------------------------------------------------------------------------------------
# Les lectures
# --------------------------------------------------------------------------------------

BOOK = ["", "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy"]


def montees_fete(fk):
    out = []
    for k, a in fk.items():
        livre = BOOK[a["k"]] if isinstance(a["k"], int) else a["k"]
        out.append([k, livre, a["b"], a["e"]])
    return out


# Les sacrifices du jour à Souccot (Bamidbar 29) : le jour k de la fête (2 à 7).
def korban_souccot(k):
    d = 17 + 3 * (k - 2)
    return ("Numbers", f"29:{d}", f"29:{d + 2}")


def construit(aliyot, fetes, numverses):
    # Lundi et jeudi : le début de la paracha du Chabbat qui vient (« weekday » d'hebcal) ; avant deux parachiot lues
    # ensemble, celui de la première.
    parachiot = {}
    for cle, nom, he, fr in PARACHIOT:
        p = aliyot[nom]
        parachiot[cle] = {"hebcal": nom, "titre": T(he, fr, nom),
                          "semaine": [[k, BOOK[p["book"]], v[0], v[1]] for k, v in p["weekday"].items()]}
    for cle, a, b in JOINTES:
        nom = f"{parachiot[a]['hebcal']}-{parachiot[b]['hebcal']}"
        if nom not in aliyot:
            raise SystemExit(f"parachiot jointes inconnues d'hebcal : {nom}")
        parachiot[cle] = {"hebcal": nom, "titre": T(f"{parachiot[a]['titre']['he']} {parachiot[b]['titre']['he']}",
                                                     f"{parachiot[a]['titre']['fr']}-{parachiot[b]['titre']['fr']}", nom),
                          "semaine": parachiot[a]["semaine"]}

    lectures = {}

    def fete(cle, titre, **extra):
        src = fetes[cle]
        if src.get("alias"):
            src = fetes[src["key"]]
        e = {"titre": titre, "alyot": montees_fete(src["fullkriyah"])}
        e.update(extra)
        lectures[cle] = e
        return e

    def alias(cle, titre, vers, **extra):
        e = {"titre": titre, "alias": vers}
        e.update(extra)
        lectures[cle] = e
        return e

    # Roch 'Hodech.
    fete("Rosh Chodesh", TITRES["Rosh Chodesh"])
    # 'Hol hamoèd Pessa'h ; en Israël le 16 Nissan en est le premier jour.
    fete("Pesach II (CH''M)", TITRES["Pesach Chol ha-Moed"])
    for n in range(1, 5):
        fete(f"Pesach Chol ha-Moed Day {n}", TITRES["Pesach Chol ha-Moed"])
    # Les jeûnes : « ויחל », le matin et à Min'ha. À Min'ha, le troisième monté est maftir chez Ashkenaz et Sfard
    # (Rema O.H. 566:1 ; Kitsour Choul'han Aroukh 124:19) ; chez les Edot « שלישי », sauf le 9 Av (Kitsour Yalkout
    # Yossef 550:40, « ומנהג בני ספרד שלא להפטיר בשום תענית צבור, חוץ מתשעה באב » ; Yé'havé Daat 5:40).
    fete("Fast Day (Morning)", TITRES["Tzom Gedaliah"])
    e = fete("Fast Day (Afternoon)", TITRES["Tzom Gedaliah"])
    e["alyot_edot"] = [m if m[0] != "M" else ["3"] + m[1:] for m in e["alyot"]]
    for c in ("Tzom Gedaliah", "Asara B'Tevet", "Ta'anit Esther", "Tzom Tammuz"):
        alias(c, TITRES[c], "Fast Day (Morning)")
        alias(f"{c} (Mincha)", TITRES[c], "Fast Day (Afternoon)")
    fete("Tish'a B'Av", TITRES["Tish'a B'Av"])
    # Min'ha du 9 Av, Edot : maftir (Kitsour Yalkout Yossef 550:40 et 559:10, « והמנהג להפטיר בתשעה באב גם בשחרית
    # וגם במנחה ») ; Ashkenaz de même, comme aux autres jeûnes.
    alias("Tish'a B'Av (Mincha)", TITRES["Tish'a B'Av"], "Fast Day (Afternoon)",
          alyot_edot=[["1", "Exodus", "32:11", "32:14"], ["2", "Exodus", "34:1", "34:3"], ["M", "Exodus", "34:4", "34:10"]])
    # 'Hol hamoèd Souccot en diaspora (le doute du jour, ספיקא דיומא), du 17 au 20 Tichri, puis Hochaana Rabba.
    # Ashkenaz (et Sfard) : les deux premiers les deux jours du doute, le troisième le lendemain, le quatrième les
    # deux jours (Rema O.H. 663:1, « וכן אנו נוהגין » ; hebcal). Edot : le cohen le premier jour du doute, le lévi
    # le second, le troisième « חוזר וקורא » le second, le quatrième les deux (Choul'han Aroukh O.H. 663:1 ; Michna
    # Beroura 663:2).
    for n in range(1, 5):
        e = fete(f"Sukkot Chol ha-Moed Day {n}", TITRES["Sukkot Chol ha-Moed"])
        a, b = korban_souccot(n + 1), korban_souccot(n + 2)
        e["alyot_edot"] = [["1", *a], ["2", *b], ["3", *b], ["4", a[0], a[1], b[2]]]
    e = fete("Sukkot Final Day (Hoshana Raba)", TITRES["Hoshana Raba"])
    a, b = korban_souccot(6), korban_souccot(7)
    e["alyot_edot"] = [["1", *a], ["2", *b], ["3", *b], ["4", a[0], a[1], b[2]]]
    # En Israël, sans doute du jour : les quatre lisent le sacrifice du jour (Rema O.H. 663:1, « ובארץ
    # ישראל ... העולים אחריו חוזרים וקורים אותה פרשה עצמה » ; Kitsour Yalkout Yossef 662:1, « וקוראים
    # ד' גברי במוסף היום »). hebcal y donne la lecture de la diaspora : écart voulu.
    for n in range(1, 6):
        k = korban_souccot(n + 1)
        lectures[f"Sukkot Chol ha-Moed Day {n} (Israel)"] = {
            "titre": TITRES["Sukkot Chol ha-Moed"], "alyot": [[str(i), *k] for i in range(1, 5)]}
    k = korban_souccot(7)
    lectures["Sukkot Final Day (Hoshana Raba) (Israel)"] = {
        "titre": TITRES["Hoshana Raba"], "alyot": [[str(i), *k] for i in range(1, 5)]}
    # 'Hanouka. Ashkenaz (et Sfard), hebcal : le premier jour depuis « ויהי ביום כלות משה » (7:1), le cohen
    # jusqu'à « ביום הראשון », lévi et israël le premier nassi ; les autres jours, le troisième lit le nassi
    # du lendemain (Rema O.H. 684:1, « וכן נוהגין »). Edot (Kitsour Yalkout Yossef 684:1-3 ; Choul'han
    # Aroukh O.H. 684:1) : le premier jour depuis la bénédiction des cohanim (6:22) jusqu'à « לפני המשכן »
    # (7:3), le lévi jusqu'à « ביום הראשון » (7:11), le troisième le premier nassi ; les autres jours, le
    # troisième relit le nassi du jour ; le huitième, il relit depuis « ביום השמיני » jusqu'à « כן עשה את
    # המנורה » (8:4).
    N = "Numbers"
    nassi = {1: ("7:12", "7:17")}
    for j in range(2, 8):
        d = 18 + 6 * (j - 2)
        nassi[j] = (f"7:{d}", f"7:{d + 5}")
    for j in range(1, 9):
        e = fete(f"Chanukah Day {j}", TITRES["Chanukah"])
        if j == 1:
            e["alyot_edot"] = [["1", N, "6:22", "7:3"], ["2", N, "7:4", "7:11"], ["3", N, "7:12", "7:17"]]
        elif j == 8:
            e["alyot_edot"] = [["1", N, "7:54", "7:56"], ["2", N, "7:57", "7:59"], ["3", N, "7:54", "8:4"]]
        elif all(m[0] != "4" for m in e["alyot"]):
            # Les jours 2 à 5, et le septième hors de Roch 'Hodech (Kislev court) ; à Roch 'Hodech, trois montées
            # de Roch 'Hodech et le nassi du jour en quatrième, pour tous (Kitsour Yalkout Yossef 684:8).
            b, f = nassi[j]
            c0 = int(b.split(":")[1])
            e["alyot_edot"] = [["1", N, b, f"7:{c0 + 2}"], ["2", N, f"7:{c0 + 3}", f], ["3", N, b, f]]
    fete("Chanukah Day 7 (on Rosh Chodesh)", TITRES["Chanukah"])
    # Pourim : le 14, ou le 15 à Jérusalem (Chouchan Pourim).
    fete("Purim", TITRES["Purim"])
    fete("Shushan Purim", TITRES["Shushan Purim"])

    # Contrôles : chaque passage existe, dans l'ordre, dans la numérotation d'hebcal, dans la Torah ; chaque montée
    # a son libellé.
    def verifie(livre, debut, fin, ou):
        if livre not in TORAH:
            raise SystemExit(f"{ou} : {livre} hors de la Torah")
        nv = numverses[livre]
        c1, v1 = map(int, debut.split(":"))
        c2, v2 = map(int, fin.split(":"))
        if not (1 <= c1 < len(nv) and 1 <= c2 < len(nv) and 1 <= v1 <= nv[c1] and 1 <= v2 <= nv[c2] and (c1, v1) <= (c2, v2)):
            raise SystemExit(f"passage impossible {livre} {debut}-{fin} ({ou})")

    def passages():
        for cle, e in list(parachiot.items()) + list(lectures.items()):
            for champ, v in e.items():
                if champ.startswith(("alyot", "semaine")):
                    for m in v:
                        if m[0] not in MONTEES:
                            raise SystemExit(f"{cle} : montée sans libellé {m[0]}")
                        yield cle, m[1], m[2], m[3]

    for cle, livre, d, f in passages():
        verifie(livre, d, f, cle)
    return parachiot, lectures, passages


def ecrit(chemin, donnees, compact_texte=False):
    with open(chemin, "w", encoding="utf-8") as f:
        if not compact_texte:
            json.dump(donnees, f, ensure_ascii=False, indent=1)
            f.write("\n")
            return
        # Le texte : un chapitre par ligne, pour des différences lisibles.
        f.write("{\n\"_meta\": " + json.dumps(donnees["_meta"], ensure_ascii=False) + ",\n\"livres\": {\n")
        livres = list(donnees["livres"].items())
        for i, (livre, chapitres) in enumerate(livres):
            f.write(json.dumps(livre) + ": {\n")
            items = list(chapitres.items())
            for j, (c, versets) in enumerate(items):
                f.write(json.dumps(c) + ": " + json.dumps(versets, ensure_ascii=False, separators=(",", ":")))
                f.write(",\n" if j < len(items) - 1 else "\n")
            f.write("}" + (",\n" if i < len(livres) - 1 else "\n"))
        f.write("},\n\"paragraphes\": " + json.dumps(donnees["paragraphes"], ensure_ascii=False, separators=(",", ":")) + "\n}\n")


def main(cache):
    os.makedirs(cache, exist_ok=True)
    aliyot, fetes, numverses, licence, integrite = charge_leyning(cache)
    parachiot, lectures, passages = construit(aliyot, fetes, numverses)

    # Les chapitres lus un jour de semaine, et eux seuls.
    chapitres = {}
    for _, livre, d, f in passages():
        c1, c2 = int(d.split(":")[0]), int(f.split(":")[0])
        chapitres.setdefault(livre, set()).update(range(c1, c2 + 1))

    livres, paragraphes, compte, milieux, decoupes = {}, {}, {"versets": 0}, [], []
    for livre in [x for x in TORAH if x in chapitres]:
        src = charge_livre(cache, livre, TAAMIM)
        texte = aligne(livre, src["text"], numverses[livre], decoupes)
        if len(texte) != len(numverses[livre]) - 1:
            raise SystemExit(f"{livre} : {len(texte)} chapitres contre {len(numverses[livre]) - 1} chez hebcal")
        livres[livre], paragraphes[livre] = {}, {}
        for c in sorted(chapitres[livre]):
            versets = texte[c - 1]
            if len(versets) != numverses[livre][c]:
                raise SystemExit(f"{livre} {c} : {len(versets)} versets contre {numverses[livre][c]} chez hebcal")
            sortie = []
            for v, brut in enumerate(versets, 1):
                t, fin, milieu = verset(brut)
                if milieu:
                    milieux.append(f"{livre} {c}:{v}")
                sortie.append(t)
                if fin:
                    paragraphes[livre][f"{c}:{v}"] = fin
            livres[livre][str(c)] = sortie
            compte["versets"] += len(sortie)

    # Seconde édition : les lettres de chaque verset de la Torah contre le Codex d'Alep.
    ecarts, pleines, triviaux, total = [], [], [], 0
    for livre in livres:
        alep = charge_livre(cache, livre, ALEP)["text"]
        for c, versets in livres[livre].items():
            for v, t in enumerate(versets, 1):
                total += 1
                a = alep[int(c) - 1][v - 1] if int(c) - 1 < len(alep) and v - 1 < len(alep[int(c) - 1]) else ""
                trivial = "mam-kq-trivial" in a
                # Le ketiv de l'édition d'Alep entre parenthèses, le qere entre crochets, dans un ordre ou
                # l'autre ; un « ketiv trivial » y garde ses lettres sous les voyelles du qere.
                a = re.sub(r'<span class="mam-kq-k">[^<]*</span>', "", a)
                a = re.sub(r"<(i|sup)[^>]*>.*?</\1>", "", a)
                a = re.sub(r"<[^>]+>", "", a)
                a = re.sub(r"\{[^}]*\}", "", a)
                a = re.sub(r"\[([^\]]*)\]", r"\1", a)
                x, y = lettres(t), lettres(a)
                if x != y:
                    # Graphie pleine ou défective : seuls des ו et des י changent.
                    if re.sub("[וי]", "", x) == re.sub("[וי]", "", y):
                        pleines.append(f"{livre} {c}:{v}")
                    elif trivial:
                        triviaux.append(f"{livre} {c}:{v}")
                    else:
                        ecarts.append(f"{livre} {c}:{v}")
    print(f"{total} versets ; {len(pleines)} ne diffèrent du Codex d'Alep que par un ו ou un י ; {len(triviaux)} par un ketiv que l'édition d'Alep garde sous les voyelles du qere ; autres : {ecarts}")
    inexpliques = [x for x in ecarts if x not in NOTES_ALEP]
    if inexpliques:
        raise SystemExit(f"écarts avec le Codex d'Alep à relire : {inexpliques}")
    note_alep = " ; ".join(NOTES_ALEP[x] for x in ecarts if NOTES_ALEP[x]) + "."

    meta_commun = {
        "version": "1.0",
        "date": "2026-11-26",
        "outil": "tools/lecture_torah_construction.py",
        "sources": {
            "lectures": f"@hebcal/leyning {LEYNING_VERSION} (npm, BSD-2-Clause), aliyot.json et holiday-readings.json ; "
                        f"archive vérifiée ({integrite[:23]}…)",
            "texte": f"{TAAMIM} — tanach.us, Westminster Leningrad Codex (via l'export Sefaria), Public Domain",
            "controle": f"{ALEP} — Codex d'Alep (export Sefaria), CC-BY-SA, comparaison seulement, rien n'est repris",
        },
    }
    definitions = {
        "_meta": dict(meta_commun, **{
            "licences": {"@hebcal/leyning": licence.strip()},
            "perimetre": "Les offices de semaine : Cha'harit le lundi et le jeudi, à Roch 'Hodech, à 'Hol hamoèd, à 'Hanouka, "
                         "à Pourim et aux jeûnes publics (9 Av compris) ; Min'ha des jeûnes publics. Jamais Chabbat ni Yom tov.",
            "coutumes": {
                "edot": "Choul'han Aroukh et Kitsour Yalkout Yossef : les écarts écrits dans l'outil, chacun avec sa source "
                        "(alyot_edot).",
                "sefard": NOTE_SFARD,
                "ashkenaz": "hebcal, sauf Israël à 'Hol hamoèd Souccot (les quatre montées lisent le sacrifice du jour) et "
                            "Pessa'h commençant un jeudi en Israël (קדש, בכספא, במדברא du dimanche au mardi).",
            },
            "forme": "parachiot : clés de l'énumération Parsha de KosherJava, semaine : la lecture du lundi et du jeudi ; "
                     "lectures : clés d'hebcal (holiday-readings.json) ; alyot/semaine : [montée, livre, début, fin] "
                     "(Ashkenaz et Sfard), alyot_edot quand elle diffère ; alias : une autre lecture dont on reprend les "
                     "montées.",
        }),
        "livres": {k: LIVRES[k] for k in livres},
        "montees": MONTEES,
        "parachiot": parachiot,
        "lectures": lectures,
    }
    texte = {
        "_meta": dict(meta_commun, **{
            "conventions": "Seuls les chapitres d'une lecture de semaine sont donnés, entiers. "
                           "Le qere est retenu (forme lue) ; teamim, maqaf, paseq et sof passouq gardés ; le Nom tel que dans "
                           "l'édition, en toutes lettres (versets, décision du 04/10/2026) ; marques פ et ס de fin de "
                           "paragraphe retirées du texte, données dans « paragraphes » (livre → « chapitre:verset »). "
                           "Marques au milieu d'un verset (פסקא באמצע פסוק), retirées sans plus : " + (", ".join(milieux) or "aucune")
                           + ". Mots écrits et non lus (כתיב ולא קרי), retirés : " + str(len(KETIV_SEUL)) + " versets. "
                           "Versets coupés pour suivre la numérotation d'hebcal (un verset de Leningrad en deux) : "
                           + (", ".join(decoupes) or "aucun") + ".",
            "verification": {
                "versets": compte["versets"],
                "numerotation": "Nombre de versets de chaque chapitre identique à numverses.json d'hebcal.",
                "seconde_edition": f"{total} versets confrontés, lettres seules, à {ALEP} : "
                                   f"{len(pleines)} ne diffèrent que par un ו ou un י (graphie pleine ou défective, variantes "
                                   f"connues des codex d'Alep et de Leningrad) ; {len(triviaux)} par un ketiv que l'édition d'Alep "
                                   f"écrit sous les voyelles du qere (« ketiv trivial »), ici remplacé par le "
                                   f"qere ; {len(ecarts)} autres, relus un par un (ecarts_alep_autres) : " + note_alep,
                "ecarts_alep_ketiv_trivial": triviaux,
                "ecarts_alep_pleine_defective": pleines,
                "ecarts_alep_autres": ecarts,
                "relecture": "Extraction automatique ; une lecture humaine de quelques passages reste souhaitable.",
            },
        }),
        "livres": livres,
        "paragraphes": paragraphes,
    }
    ecrit(os.path.join(RAW, "lecture_torah.json"), definitions)
    ecrit(os.path.join(RAW, "lecture_torah_texte.json"), texte, compact_texte=True)
    for nom in ("lecture_torah.json", "lecture_torah_texte.json"):
        print(nom, os.path.getsize(os.path.join(RAW, nom)), "octets")


def auto_test():
    """Les cas du qere et du ketiv rencontrés dans l'édition, sans réseau."""
    cas = {
        "עַל־הָאָ֖רֶץ הוצא [הַיְצֵ֣א] אִתָּ֑ךְ": "עַל־הָאָ֖רֶץ הַיְצֵ֣א אִתָּ֑ךְ",                      # Berèchit 8:17
        "הִנֵּ֡ה לו־עשה [לֹֽא־] [יַעֲשֶׂ֨ה] אָבִ֜י": "הִנֵּ֡ה לֹֽא־יַעֲשֶׂ֨ה אָבִ֜י",                   # Chemouel I 20:2
        "בָּלָ֗ק לך־[לְכָה־] נָּ֨א אִתִּ֜י": "בָּלָ֗ק לְכָה־נָּ֨א אִתִּ֜י",                             # Bamidbar 23:13
        "אֶת־שָׂרֵ֥י המיאות [הַמֵּא֣וֹת ׀] פְּקֻדֵ֣י": "אֶת־שָׂרֵ֥י הַמֵּא֣וֹת ׀ פְּקֻדֵ֣י",             # Melakhim II 11:15
        "הַיָּמִ֖ים [בָּאִ֖ים] נְאֻם־יְהוָ֑ה": "הַיָּמִ֖ים בָּאִ֖ים נְאֻם־יְהוָ֑ה",                     # Yirmiyahou 31:38
    }
    for brut, attendu in cas.items():
        assert qere(brut) == attendu, (brut, qere(brut))
    assert sans_ketiv("יִסְלַח־נא יְהוָ֥ה לְעַבְדְּךָ֖") == ("יִסְלַח־יְהוָ֥ה לְעַבְדְּךָ֖", 1)  # Melakhim II 5:18
    t, fin, milieu = verset("וַיְכֻלּ֛וּ הַשָּׁמַ֥יִם וְהָאָ֖רֶץ וְכָל־צְבָאָֽם׃ (פ)")
    assert (t, fin, milieu) == ("וַיְכֻלּ֛וּ הַשָּׁמַ֥יִם וְהָאָ֖רֶץ וְכָל־צְבָאָֽם׃", "פ", False)
    assert verset("א֑וֹ בָּ֥א (ס) גּ֖וֹ׃") == ("א֑וֹ בָּ֥א גּ֖וֹ׃", None, True)
    texte = aligne("Numbers", [["א"] * 18, ["וַיְהִ֖י אַחֲרֵ֣י הַמַּגֵּפָ֑ה (פ) וַיֹּ֤אמֶר"] + ["ב"] * 64], [0, 19, 65], [])
    assert len(texte[0]) == 19 and texte[0][-1] == "וַיְהִ֖י אַחֲרֵ֣י הַמַּגֵּפָ֑ה (פ)" and texte[1][0] == "וַיֹּ֤אמֶר"
    print("qere, ketiv, paragraphes, numérotation : bon")


if __name__ == "__main__":
    if sys.argv[1:] == ["--test"]:
        auto_test()
    elif len(sys.argv) != 2:
        raise SystemExit(__doc__)
    else:
        main(sys.argv[1])
