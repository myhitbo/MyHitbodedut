"""L'index de recherche d'iOS (ios/PORTAGE.md § 4.2, étape 8 ; ROADMAP.md tâche 6).

Le texte y entre passé par la normalisation de RechercheGlobale.nu. Une liste de cas communs, écrite
par le Kotlin d'Android (ios/Paquets/Coeur/Tests/Vecteurs/normalisation.json), tient les trois écritures
ensemble : celle-ci, celle d'Android et celle de RechercheGlobale.swift. Un écart arrête l'export.

Ce qui est indexé : chaque bloc de prière des trois siddourim (les consignes en sont exclues, comme
RechercheGlobale.dansRecueil), chaque halakha du Yalkout Yossef et du Ben Ich Haï, chaque hilloula, et le
titre de chaque texte des douze livres. Le texte des livres (28 Mo) reste cherché en mémoire, comme sur
Android : l'indexer triplerait le poids des ressources (§ 4.3).

Le fichier SQLite n'est pas identique d'une version de SQLite à l'autre : le manifeste retient donc
l'empreinte de ses lignes (`empreinte`), pas celle de ses octets.
"""

import hashlib
import json
import re
import sqlite3
import unicodedata
from pathlib import Path

_DIACRITIQUES = re.compile("[̀-ͯ’‘]")
_BALISES = re.compile("<[^>]+>")
_SEPARATEURS = re.compile("[־׀]")
_VOYELLES = re.compile("[֑-ׇ\"'״׳]")
# \s de Java : les six blancs ASCII seulement.
_BLANCS = re.compile("[ \t\n\u000B\f\r]+")
# trim() de Kotlin : Char.isWhitespace (Kotlin.estEspace côté Swift).
_ESPACES = set(range(0x09, 0x0E)) | set(range(0x1C, 0x20)) | {0x20, 0xA0, 0x1680} | set(range(0x2000, 0x200B)) \
    | {0x2028, 0x2029, 0x202F, 0x205F, 0x3000}


def nu(t: str) -> str:
    """RechercheGlobale.nu : sans voyelles ni accents, balises et séparateurs en blancs, en minuscules."""
    t = unicodedata.normalize("NFD", t)
    t = _DIACRITIQUES.sub("", t)
    t = _BALISES.sub(" ", t)
    t = _SEPARATEURS.sub(" ", t)
    t = _VOYELLES.sub("", t)
    t = _BLANCS.sub(" ", t)
    debut, fin = 0, len(t)
    while debut < fin and ord(t[debut]) in _ESPACES:
        debut += 1
    while fin > debut and ord(t[fin - 1]) in _ESPACES:
        fin -= 1
    return t[debut:fin].lower()


def verifier(cas: Path):
    """Les cas communs, rendus par Android : la même chaîne ici, sinon l'export s'arrête."""
    ecarts = [(a, b, nu(a)) for a, b in json.loads(cas.read_text(encoding="utf-8"))["cas"] if nu(a) != b]
    if ecarts:
        raise SystemExit("normalisation : " + "; ".join(f"{a!r} → {c!r} au lieu de {b!r}" for a, b, c in ecarts))


def _lignes(raw: Path):
    """(sorte, id, titre, texte normalisé), dans un ordre fixe."""
    lit = lambda n: json.loads((raw / n).read_text(encoding="utf-8"))
    for rite in ("edot", "sefard", "ashkenaz"):
        for t in lit(f"siddur_{rite}.json")["textes"]:
            titre = t["titre"]["he"]
            for i, section in enumerate(t["sections"]):
                for j, bloc in enumerate(section["blocs"]):
                    if "c" in bloc:  # une consigne, pas une prière (Siddur.kt)
                        continue
                    yield "siddour", f"{rite}:{t['id']}:{i}:{j}", titre, nu(bloc["t"])
    for t in lit("livres_titres.json")["textes"]:
        yield "livre", t["id"], t["titre"]["he"], nu(" ".join(t["titre"].get(k, "") for k in ("he", "fr", "en")))
    for periode, liste in lit("yalkut_yosef.json")["periodes"].items():
        for k, h in enumerate(liste):
            yield "halakha", f"yalkut:{periode}:{k}", h.get("s", ""), nu(h.get("t", ""))
    bih = lit("ben_ish_hai.json")
    sections = [(f"{annee}:{paracha}", s) for annee, parachiot in bih["annees"].items() for paracha, s in parachiot.items()]
    for cle, s in sections + [("hanouka", bih["hanouka"])]:
        for n, texte in enumerate(s["h"]):
            yield "halakha", f"ben_ish_hai:{cle}:{n}", s["he"], nu(texte)
    for jour, liste in lit("hilloulot.json")["jours"].items():
        for k, h in enumerate(liste):
            yield "hilloula", f"{jour}:{k}", h.get("he", ""), nu(" ".join([h.get("he", ""), h.get("d", "")]))


def construire(raw: Path, cible: Path) -> str:
    """Écrit l'index et rend l'empreinte de ses lignes."""
    cible.parent.mkdir(parents=True, exist_ok=True)
    cible.unlink(missing_ok=True)
    empreinte = hashlib.sha256()
    with sqlite3.connect(cible) as base:
        base.execute("PRAGMA page_size = 4096")
        base.execute("CREATE TABLE entrees (sorte TEXT NOT NULL, id TEXT NOT NULL PRIMARY KEY, titre TEXT NOT NULL, "
                     "nu TEXT NOT NULL)")
        for ligne in _lignes(raw):
            base.execute("INSERT INTO entrees VALUES (?, ?, ?, ?)", ligne)
            empreinte.update("\u0000".join(ligne).encode("utf-8") + b"\n")
        base.execute("CREATE INDEX entrees_sorte ON entrees (sorte)")
    with sqlite3.connect(cible) as base:
        base.execute("VACUUM")
    return empreinte.hexdigest()
