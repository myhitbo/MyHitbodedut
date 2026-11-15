"""Étape 8 de l'export (ios/PORTAGE.md § 2.2.10, § 4.2) : l'index de la recherche, recherche.sqlite.

Android relit et normalise tout à chaque frappe (RechercheGlobale.kt). L'index garde, pour chaque
bloc, le texte déjà passé par la même normalisation, et ce que les règles de résultat demandent :
un résultat par prière ou par livre (le titre, sinon le premier bloc qui contient la recherche),
30 par sorte, le même extrait. L'app l'ouvre en lecture seule (Coeur, RechercheGlobale.swift).

Les deux normalisations d'Android sont reprises ici à la lettre, telles que l'appareil les exécute
(java.util.regex sur ICU) : nu() (RechercheGlobale.nu) et celle, plus courte, de la halakha
(YalkutYosef.recherche, Halakha.recherche). Une liste de cas communs (cas_normalisation.json),
passée par le Kotlin dans tables/, les tient ensemble : un écart arrête l'export.

Le fichier est déterministe à version de SQLite égale ; deux versions peuvent ranger les pages
autrement. Son empreinte au manifeste est donc celle de son contenu (empreinte()), pas de ses
octets.
"""

import hashlib
import json
import re
import sqlite3
import unicodedata
from pathlib import Path

VERSION = 1

# --- Les normalisations d'Android -------------------------------------------------------------

# Kotlin Char.isWhitespace : Character.isWhitespace ou Character.isSpaceChar.
_CONTROLES = set("\t\n\x0b\x0c\r\x1c\x1d\x1e\x1f")


def _blanc(c: str) -> bool:
    return c in _CONTROLES or unicodedata.category(c) in ("Zs", "Zl", "Zp")


def trim(t: str) -> str:
    """String.trim() de Kotlin (pas str.strip() : les deux ne tiennent pas les mêmes caractères pour blancs)."""
    debut, fin = 0, len(t)
    while debut < fin and _blanc(t[debut]):
        debut += 1
    while fin > debut and _blanc(t[fin - 1]):
        fin -= 1
    return t[debut:fin]


def vide(t: str) -> bool:
    """String.isBlank() de Kotlin."""
    return all(_blanc(c) for c in t)


_ACCENTS = re.compile("[̀-ͯ’‘]")
_BALISES = re.compile(r"<[^>]+>")
_MAQAF = re.compile("[־׀]")
_POINTS = re.compile("[֑-ׇ\"'״׳]")
# \s d'Android : java.util.regex y tourne sur ICU, où \s est la propriété White_Space (l'insécable,
# l'espace fine… ; pas U+001C à U+001F). Pas le \s de la JVM (l'ASCII), ni celui de Python (isspace).
_ESPACES = re.compile("[\t\n\x0b\x0c\r \x85\xa0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]+")


def nu(t: str) -> str:
    """RechercheGlobale.nu : sans accents, balises, voyelles, te'amim ni guillemets, en minuscules."""
    t = _ACCENTS.sub("", unicodedata.normalize("NFD", t))
    t = _POINTS.sub("", _MAQAF.sub(" ", _BALISES.sub(" ", t)))
    return trim(_ESPACES.sub(" ", t)).lower()


def nu_halakha(t: str) -> str:
    """La normalisation de YalkutYosef.recherche et de Halakha.recherche : voyelles et guillemets seulement."""
    return _POINTS.sub("", _MAQAF.sub(" ", t))


def verifier_cas(vecteurs: dict) -> int:
    """Les cas communs : nu() ici doit rendre ce que le Kotlin d'Android a rendu."""
    ecarts = [(e, s, nu(e)) for e, s in vecteurs["normalisation"] if nu(e) != s]
    if ecarts:
        e, s, p = ecarts[0]
        raise SystemExit(f"recherche : normalisation discordante pour {e!r} : Kotlin {s!r}, Python {p!r}"
                         f" ({len(ecarts)} cas)")
    return len(vecteurs["normalisation"])


# --- org.json d'Android -----------------------------------------------------------------------

def opt_string(o: dict, cle: str, defaut: str = "") -> str:
    """JSONObject.optString d'Android : absent → défaut, null → « null », sinon la valeur en texte."""
    if cle not in o:
        return defaut
    v = o[cle]
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (str, int)):
        return str(v)
    raise SystemExit(f"recherche : valeur inattendue pour {cle} : {v!r}")


def nullable(o: dict, cle: str):
    """Json.nullable de l'app : absent, null ou blanc → None."""
    if cle not in o or o[cle] is None:
        return None
    v = opt_string(o, cle)
    return None if vide(v) else v


def pour_langue(titre: dict, langue: str) -> str:
    """LocalizedText.forLanguage : le français ou l'anglais s'ils sont remplis, sinon l'hébreu."""
    he = opt_string(titre, "he")
    if langue in ("fr", "en"):
        v = opt_string(titre, langue)
        return he if vide(v) else v
    return he


def rang_dans_l_annee(cle: str) -> int:
    """Hilloulot.rangDansLAnnee : de Tichri à Eloul, les Adar à leur place."""
    m, j = cle.split("-")[:2]
    entier = lambda s: int(s) if re.fullmatch(r"[+-]?\d+", s) else None
    mois = {"adar1": 6, "adar": 7, "adar2": 8}.get(m)
    if mois is None:
        n = entier(m)
        mois = 20 if n is None else (n - 6 if n >= 7 else n + 8)
    return mois * 100 + (entier(j) or 0)


# --- L'index ----------------------------------------------------------------------------------

SCHEMA = """
CREATE TABLE meta (cle TEXT PRIMARY KEY, valeur TEXT NOT NULL) WITHOUT ROWID;
-- Une ligne par prière (recueil edot, sefard, ashkenaz) ou par livre (recueil livres), dans l'ordre
-- du recueil ; ses blocs à chercher (hors consignes) sont les lignes debut..fin de blocs.
CREATE TABLE textes (
  recueil TEXT NOT NULL, rang INTEGER NOT NULL, id TEXT NOT NULL,
  titre_he TEXT NOT NULL, titre_fr TEXT NOT NULL, titre_en TEXT NOT NULL,
  nu_he TEXT NOT NULL, nu_fr TEXT NOT NULL, nu_en TEXT NOT NULL,
  debut INTEGER NOT NULL, fin INTEGER NOT NULL,
  PRIMARY KEY (recueil, rang)) WITHOUT ROWID;
CREATE TABLE blocs (nu TEXT NOT NULL);
-- Le Yalkout Yossef et le Ben Ich Haï, dans l'ordre de leur recherche sur Android.
CREATE TABLE yalkut (siman TEXT NOT NULL, lettre TEXT NOT NULL,
  nu2_texte TEXT NOT NULL, nu2_siman TEXT NOT NULL, nu_texte TEXT NOT NULL);
CREATE TABLE ben_ish_hai (annee INTEGER NOT NULL, numero INTEGER NOT NULL, section TEXT NOT NULL,
  nu2_texte TEXT NOT NULL, nu_texte TEXT NOT NULL);
-- Les hilloulot, dans l'ordre du fichier ; la recherche les range par rang dans l'année.
CREATE TABLE hilloulot (cle TEXT NOT NULL, rang INTEGER NOT NULL,
  he TEXT NOT NULL, fr TEXT, en TEXT, annee TEXT NOT NULL,
  nu_he TEXT NOT NULL, nu_fr TEXT, nu_en TEXT);
"""


def _recueil(base, recueil: str, textes: list, rangs: list):
    """Les textes d'un recueil (SiddurLoader.parse) : titre en trois langues, blocs hors consignes."""
    for rang, t in enumerate(textes):
        titre = t["titre"]
        debut = None
        fin = 0
        for section in t["sections"]:
            for b in section["blocs"]:
                if "c" in b:
                    continue
                if "t" not in b:
                    raise SystemExit(f"recherche : bloc sans texte dans {recueil}/{t['id']}")
                fin = base.execute("INSERT INTO blocs (nu) VALUES (?)", (nu(opt_string(b, "t")),)).lastrowid
                debut = debut or fin
        he, fr, en = (opt_string(titre, "he"), pour_langue(titre, "fr"), pour_langue(titre, "en"))
        base.execute("INSERT INTO textes VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                     (recueil, rang, t["id"], he, opt_string(titre, "fr"), opt_string(titre, "en"),
                      nu(he), nu(fr), nu(en), debut or 1, fin if debut else 0))
        rangs.append(rang)


def construire(raw: Path, cible: Path) -> dict:
    """Écrit l'index dans [cible] et rend ses comptes."""
    lit = lambda nom: json.loads((raw / nom).read_text(encoding="utf-8"))
    cible.unlink(missing_ok=True)
    base = sqlite3.connect(cible)
    base.execute("PRAGMA page_size = 4096")
    base.execute("PRAGMA journal_mode = OFF")
    base.executescript(SCHEMA)
    comptes = {}
    with base:
        base.executemany("INSERT INTO meta VALUES (?, ?)", [
            ("version", str(VERSION)), ("par_sorte", "30"),
            ("normalisation", "RechercheGlobale.nu (Android), tools/export_contenu/recherche.py"),
        ])
        for rite in ("edot", "sefard", "ashkenaz"):
            rangs = []
            _recueil(base, rite, lit(f"siddur_{rite}.json")["textes"], rangs)
            comptes[f"siddour {rite}"] = len(rangs)
        # Data.livres : chaque livre entier, dans l'ordre de l'index, le texte qui porte son identifiant.
        livres = []
        for e in lit("livres_titres.json")["textes"]:
            chemin = raw / f"livre_{e['id']}.json"
            if chemin.exists():
                livres += [t for t in json.loads(chemin.read_text(encoding="utf-8"))["textes"] if t["id"] == e["id"]][:1]
        rangs = []
        _recueil(base, "livres", livres, rangs)
        comptes["livres"] = len(rangs)

        # YalkutYosef.recherche : les se'ifim de toutes les périodes, sans doublon.
        vus, lignes = set(), []
        for seifs in lit("yalkut_yosef.json")["periodes"].values():
            for o in seifs:
                s = (o["s"], o["l"], o["t"])
                if s not in vus:
                    vus.add(s)
                    lignes.append((s[0], s[1], nu_halakha(s[2]), nu_halakha(s[0]), nu(s[2])))
        base.executemany("INSERT INTO yalkut VALUES (?,?,?,?,?)", lignes)
        comptes["yalkut"] = len(lignes)

        # Halakha.recherche : les années dans l'ordre de leur clé, puis 'Hanouka (année 1).
        bih = lit("ben_ish_hai.json")
        lignes = []
        for annee in sorted(bih["annees"]):
            for section in bih["annees"][annee].values():
                lignes += [(int(annee), i + 1, section["he"], nu_halakha(h), nu(h)) for i, h in enumerate(section["h"])]
        if bih.get("hanouka"):
            h = bih["hanouka"]
            lignes += [(1, i + 1, h["he"], nu_halakha(x), nu(x)) for i, x in enumerate(h["h"])]
        base.executemany("INSERT INTO ben_ish_hai VALUES (?,?,?,?,?)", lignes)
        comptes["ben ich hai"] = len(lignes)

        lignes = []
        for cle, liste in lit("hilloulot.json")["jours"].items():
            for o in liste:
                fr, en = nullable(o, "fr"), nullable(o, "en")
                he = o["he"]
                lignes.append((cle, rang_dans_l_annee(cle), he, fr, en, opt_string(o, "a"),
                               nu(he), None if fr is None else nu(fr), None if en is None else nu(en)))
        base.executemany("INSERT INTO hilloulot VALUES (?,?,?,?,?,?,?,?,?)", lignes)
        comptes["hilloulot"] = len(lignes)
    base.close()
    return comptes


def empreinte(chemin: Path) -> tuple:
    """L'empreinte du contenu de l'index (schéma et lignes, dans l'ordre) et sa taille : la même
    quelle que soit la version de SQLite qui l'a écrit, contrairement aux octets du fichier."""
    # as_uri() encode « # », « ? » et « % » : un chemin brut dans l'URI ouvrirait un autre fichier.
    base = sqlite3.connect(Path(chemin).resolve().as_uri() + "?mode=ro", uri=True)
    h = hashlib.sha256()
    taille = 0
    for (nom, sql) in base.execute("SELECT name, sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY name"):
        h.update(f"{nom}\0{sql}\0".encode())
        ordre = {"meta": "cle", "textes": "recueil, rang"}.get(nom, "rowid")
        if sql.upper().startswith("CREATE TABLE"):
            for ligne in base.execute(f'SELECT * FROM "{nom}" ORDER BY {ordre}'):
                texte = json.dumps(ligne, ensure_ascii=False)
                h.update(texte.encode() + b"\n")
                taille += len(texte) + 1
    base.close()
    return h.hexdigest(), taille
