# -*- coding: utf-8 -*-
"""
Le Targoum Onkelos de la paracha de la semaine (demande du 26/11/2026 : « Chnayim mikra véé'had
targoum » dans le texte « Lecture de la Torah ») :

  android/app/src/main/res/raw/lecture_torah_targoum.json   le Targoum, livre par livre, verset par verset

Source
------
Sefaria, export public, version hébraïque « Onkelos <Livre> » (Torat Emet, toratemetfreeware.com),
vocalisée, licence « Public Domain » (champ license de chaque fichier, vérifié ici). Les autres versions
vocalisées de Sefaria ne conviennent pas : « vocalized according to the Yemenite Taj » est CC-BY-SA,
celle des 'houmachim Metsudah CC-BY-NC.

Mise en forme (rien d'autre n'est changé ; chaque règle est contrôlée) :
- les notes de l'éditeur entre parenthèses, qui portent une abréviation (« (נ''א …) », « (ס''א …) »,
  « (נ''י …) », « (גי' רמב''ן …) », « (לפרש״י …) », « (בכל הס' …) ») sont retirées ; les mots entre
  parenthèses vocalisés, qui sont du texte de l'édition (« (מִן) », « (לָא) »), restent ;
- les marques « ססס » (fin de section) et les deux-points de fin de verset sont retirés ; chaque verset
  finit par le sof passouq « ׃ », comme le texte hébreu de l'application ;
- cinq deux-points égarés au milieu d'un mot (un chva ou une espace perdus) sont corrigés un à un
  (CORRECTIONS) ;
- Bamidbar 25:19 : l'édition joint « וַהֲוָה בָּתַר מוֹתָנָא » (25:19) au verset 26:1 ; il est rendu à 25:19,
  comme dans le texte hébreu (versification de la Bible de Leningrad, tanach.us).
Le nombre de versets de chaque chapitre est ensuite comparé à celui du texte hébreu
(lecture_torah_texte.json, tools/lecture_torah_construction.py) : identique pour les cinq livres.

  python3 tools/lecture_torah_targoum.py <dossier de cache>
  python3 tools/lecture_torah_targoum.py --test     (contrôles de la mise en forme, sans réseau)
"""
import json, os, re, sys, time, unicodedata, urllib.parse, urllib.request

NFC = lambda s: unicodedata.normalize("NFC", s)
RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RAW = os.path.join(RACINE, "android", "app", "src", "main", "res", "raw")
TORAH = ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy"]
EXPORT = "https://storage.googleapis.com/sefaria-export/json/Tanakh/Targum/Onkelos/Torah/Onkelos%20{livre}/Hebrew/Onkelos%20{livre}.json"
LICENCES = ("Public Domain", "CC0")
SOF_PASOUQ = "׃"

# Les deux-points égarés dans un mot (un chva ou une espace perdus), corrigés d'après les éditions imprimées.
CORRECTIONS = {
    ("Genesis", 32, 8): ("לִ:תרֵין", "לִתְרֵין"),
    ("Genesis", 34, 12): ("עוּלֶמְתָּא:לאִנְתּוּ", "עוּלֶמְתָּא לְאִנְתּוּ"),
    ("Leviticus", 11, 25): ("דְיִטוֹל:מִנְבִלְתְּהוֹן", "דְיִטוֹל מִנְבִלְתְּהוֹן"),
    ("Deuteronomy", 12, 3): ("אַ:תרָא", "אַתְרָא"),
    ("Deuteronomy", 23, 21): ("עָלֵל:לתַמָן", "עָלֵל לְתַמָן"),
}
# Bamidbar 25:19 : le début du verset 26:1 de l'édition.
DEBUT_26_1 = "וַהֲוָה בָּתַר מוֹתָנָא"


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


def verset(livre, c, v, brut):
    """Un verset de l'édition, mis en forme (voir l'en-tête)."""
    t = NFC(brut).replace("‎", "").replace("‏", "")
    # Les notes de l'éditeur : une parenthèse qui porte une abréviation (' ou ״).
    t = re.sub(r"\s*\([^)]*['׳״\"][^)]*\)", "", t)
    t = re.sub(r"\s*:?\s*ססס\s*:?", "", t)
    if (livre, c, v) in CORRECTIONS:
        avant, apres = CORRECTIONS[(livre, c, v)]
        if avant not in t:
            raise SystemExit(f"{livre} {c}:{v} : correction introuvable ({avant})")
        t = t.replace(avant, apres)
    t = re.sub(r"[\s:]+$", "", t)
    t = re.sub(r"\s+", " ", t).strip()
    if ":" in t or "'" in t or "״" in t:
        raise SystemExit(f"{livre} {c}:{v} : signe inattendu : {t}")
    if not t:
        raise SystemExit(f"{livre} {c}:{v} : verset vide")
    return t + SOF_PASOUQ


def livre(cache, nom):
    chemin = os.path.join(cache, f"Onkelos_{nom}.json")
    telecharge(EXPORT.format(livre=urllib.parse.quote(nom)), chemin)
    d = json.load(open(chemin, encoding="utf-8"))
    if d.get("license") not in LICENCES:
        raise SystemExit(f"Onkelos {nom} : licence {d.get('license')!r}, ni domaine public ni CC0")
    if d.get("versionTitle") != f"Onkelos {nom}" or d.get("language") != "he":
        raise SystemExit(f"Onkelos {nom} : version inattendue {d.get('versionTitle')!r}")
    chapitres = [[verset(nom, c + 1, v + 1, x) for v, x in enumerate(ch)] for c, ch in enumerate(d["text"])]
    if nom == "Numbers":
        # 25:19 joint à 26:1 dans l'édition (voir l'en-tête).
        premier = chapitres[25][0]
        if len(chapitres[24]) != 18 or not premier.startswith(DEBUT_26_1 + " "):
            raise SystemExit("Bamidbar 25:19 / 26:1 : forme inattendue")
        chapitres[24].append(DEBUT_26_1 + SOF_PASOUQ)
        chapitres[25][0] = premier[len(DEBUT_26_1):].strip()
    return chapitres, {"version": d["versionTitle"], "source": d.get("versionSource"), "licence": d["license"]}


def compare(targoum, texte):
    """Les écarts de versification avec le texte hébreu : [(livre, chapitre, versets du Targoum, versets hébreux)]."""
    ecarts = []
    for nom in TORAH:
        heb = texte["livres"][nom]
        if len(targoum[nom]) != len(heb):
            ecarts.append((nom, None, len(targoum[nom]), len(heb)))
        for c, ch in enumerate(targoum[nom]):
            n = len(heb.get(str(c + 1), []))
            if len(ch) != n:
                ecarts.append((nom, c + 1, len(ch), n))
    return ecarts


def test():
    assert verset("Genesis", 10, 11, "מִן אַרְעָא (ס''א עֵיצָה) הַהִיא נְפַק") == "מִן אַרְעָא הַהִיא נְפַק׃"
    assert verset("Genesis", 4, 1, "קָנִיתִי גַּבְרָא (מִן) קֳדָם יְיָ") == "קָנִיתִי גַּבְרָא (מִן) קֳדָם יְיָ׃"
    assert verset("Exodus", 19, 4, "וּנְטָלִית (נ״‎א וְאַטְּלִית) יָתְכוֹן:") == "וּנְטָלִית יָתְכוֹן׃"
    assert verset("Exodus", 6, 1, "מֵאַרְעֵהּ: ססס:") == "מֵאַרְעֵהּ׃"
    assert verset("Genesis", 32, 8, "וְגַמְלַיָּא לִ:תרֵין מַשִּׁירְיָן") == "וְגַמְלַיָּא לִתְרֵין מַשִּׁירְיָן׃"
    try:
        verset("Genesis", 1, 1, "אַ:בָּא")
        raise AssertionError("deux-points non relevé")
    except SystemExit:
        pass
    print("tests de la mise en forme : ok")


def main(cache):
    os.makedirs(cache, exist_ok=True)
    texte = json.load(open(os.path.join(RAW, "lecture_torah_texte.json"), encoding="utf-8"))
    targoum, sources = {}, {}
    for nom in TORAH:
        targoum[nom], sources[nom] = livre(cache, nom)
    ecarts = compare(targoum, texte)
    if ecarts:
        raise SystemExit(f"versification différente du texte hébreu : {ecarts}")
    sortie = {
        "_meta": {
            "titre": "Targoum Onkelos",
            "source": "Sefaria, export public (storage.googleapis.com/sefaria-export), versions « Onkelos <Livre> »",
            "edition": "Torat Emet (toratemetfreeware.com), vocalisée",
            "licence": "Public Domain",
            "versions": sources,
            "mise_en_forme": "notes de l'éditeur entre parenthèses retirées, « ססס » retiré, sof passouq ajouté, "
                             "5 deux-points égarés corrigés, Bamidbar 25:19 rendu à son verset (tools/lecture_torah_targoum.py)",
            "versification": "identique au texte hébreu (lecture_torah_texte.json) pour les cinq livres, après 25:19",
        },
        "livres": {nom: {str(c + 1): ch for c, ch in enumerate(targoum[nom])} for nom in TORAH},
    }
    chemin = os.path.join(RAW, "lecture_torah_targoum.json")
    with open(chemin, "w", encoding="utf-8") as f:
        json.dump(sortie, f, ensure_ascii=False, separators=(",", ":"))
        f.write("\n")
    print(chemin, os.path.getsize(chemin), "octets ;",
          sum(len(ch) for nom in TORAH for ch in targoum[nom]), "versets")


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--test":
        test()
    elif len(sys.argv) == 2:
        main(sys.argv[1])
    else:
        raise SystemExit(__doc__)
