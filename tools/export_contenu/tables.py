"""Étape 3 de l'export (ios/PORTAGE.md § 4.2) : les tables écrites dans le Kotlin d'Android.

Le projet Gradle `tables/` compile les fichiers purs de l'app sur la JVM, avec des bouchons, et
`Tables.kt` écrit les tables en JSON. Ce module génère le bouchon `R` (chaque ressource reçoit un
entier, que `Tables.kt` retraduit en son nom), lance Gradle hors du dépôt, et relit les deux tables
prises dans des fichiers liés à Android (`Personnage.kt`, `PoliceHebraique.kt`) par expression
régulière, avec arrêt si rien n'est trouvé.
"""

import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ICI = Path(__file__).resolve().parent
PROJET = ICI / "tables"

# Les types de ressources que le bouchon R déclare, et où les trouver sous res/.
TYPES = ("string", "plurals", "array", "drawable", "raw", "font", "color")


def ressources(res: Path) -> dict:
    """Les noms de ressources d'Android, par type, triés (les entiers en dépendent)."""
    noms = {t: set() for t in TYPES}
    for valeurs in sorted(res.glob("values*/*.xml")):
        xml = re.sub(r"<!--.*?-->", "", valeurs.read_text(encoding="utf-8"), flags=re.S)
        for balise, type_ in (("string", "string"), ("plurals", "plurals"), ("string-array", "array"),
                              ("color", "color")):
            noms[type_] |= set(re.findall(rf'<{balise}\b[^>]*\bname="([A-Za-z0-9_]+)"', xml))
    for dossier, type_ in (("drawable*", "drawable"), ("raw", "raw"), ("font", "font"), ("color", "color")):
        for f in res.glob(f"{dossier}/*"):
            if f.is_file():
                noms[type_].add(f.name.split(".")[0])
    return {t: sorted(n) for t, n in noms.items()}


def bouchon_r(res: Path) -> str:
    """R.kt : un objet par type, un entier par nom, uniques entre les types (comme aapt, 0x7fTT….)."""
    lignes = ["// Généré par tools/export_contenu/tables.py d'après res/ : ne pas modifier.",
              "@file:Suppress(\"ClassName\", \"ObjectPropertyName\")", "package com.myhitbodedut", "", "object R {"]
    for t, (type_, noms) in enumerate(ressources(res).items(), start=1):
        lignes.append(f"    object {type_} {{")
        lignes += [f"        const val {n} = 0x7f{t:02x}{i:04x}" for i, n in enumerate(noms)]
        lignes.append("    }")
    lignes.append("}")
    return "\n".join(lignes) + "\n"


def gradle() -> list:
    """Gradle : celui du PATH, sinon le wrapper d'Android (qui télécharge la même version)."""
    if os.environ.get("GRADLE"):
        return [os.environ["GRADLE"]]
    if shutil.which("gradle"):
        return ["gradle"]
    return [str(ICI.parents[1] / "android" / "gradlew")]


def construction() -> Path:
    """Le dossier de construction, hors du dépôt : l'export n'écrit sous le dépôt que dans ios/."""
    base = os.environ.get("EXPORT_CONSTRUCTION") or os.environ.get("XDG_CACHE_HOME") \
        or str(Path.home() / ".cache")
    return Path(base) / "myhitbodedut-export"


def executer(java: Path, res: Path, sortie: Path, vecteurs: Path, cas: Path) -> None:
    """Compile le projet et lance Tables.kt : les tables dans [sortie], les vecteurs de la recherche
    (Recherche.kt, d'après les cas de [cas] et les contenus de res/raw) dans [vecteurs]."""
    base = construction()
    # Une construction par dossier de sources : la copie de la garde (CI) ne gâte pas l'autre.
    cle = re.sub(r"[^A-Za-z0-9]+", "_", str(java.resolve()))[-80:]
    dossier = base / cle
    genere = dossier / "genere"
    genere.mkdir(parents=True, exist_ok=True)
    r = genere / "R.kt"
    texte = bouchon_r(res)
    if not r.exists() or r.read_text(encoding="utf-8") != texte:
        r.write_text(texte, encoding="utf-8")
    commande = gradle() + [
        "--quiet", "--console=plain", "--no-configuration-cache",
        "-p", str(PROJET),
        "--project-cache-dir", str(dossier / "gradle"),
        f"-Pconstruction={dossier / 'build'}",
        f"-Pgenere={genere}",
        f"-Pjava={java}",
        f"-Pkotlin.project.persistent.dir={dossier / 'kotlin'}",
        # Les chemins en propriétés, une par argument : --args les découperait (une apostrophe,
        # « Projets d'été », y ferme une citation).
        f"-PsortieTables={sortie}", f"-PsortieVecteurs={vecteurs}", f"-Pcas={cas}", f"-Praw={res / 'raw'}",
        "run",
    ]
    try:
        subprocess.run(commande, check=True)
    except FileNotFoundError:
        raise SystemExit("tables : Gradle introuvable (PATH, $GRADLE ou android/gradlew)")
    except subprocess.CalledProcessError as e:
        raise SystemExit(f"tables : Gradle a échoué ({e.returncode})")


# --- Les deux tables prises dans des fichiers liés à Android -----------------
def entrees(bloc: str, motif: str, quoi: str) -> list:
    """Les entrées d'une table Kotlin, une par ligne : toute autre ligne qu'un commentaire ou une
    ligne vide arrête l'export, plutôt que de laisser tomber une entrée sans le dire (une dernière
    entrée sans virgule, deux entrées sur une ligne…)."""
    trouvees = []
    for ligne in bloc.split("\n"):
        ligne = ligne.strip()
        if not ligne or ligne.startswith("//"):
            continue
        m = re.fullmatch(motif + r"\s*,?", ligne)
        if not m:
            raise SystemExit(f"tables : ligne inattendue dans {quoi} : {ligne}")
        trouvees.append(m.groups())
    if not trouvees:
        raise SystemExit(f"tables : {quoi} est vide")
    return trouvees


def poses_feminines(kt: str) -> list:
    """Personnage.FEMININ : l'illustration masculine → la féminine."""
    bloc = re.search(r"FEMININ: Map<Int, Int> = mapOf\((.*?)\n    \)", kt, flags=re.S)
    if not bloc:
        raise SystemExit("tables : la table FEMININ est introuvable dans Personnage.kt")
    paires = entrees(bloc.group(1), r"R\.drawable\.([a-z0-9_]+) to R\.drawable\.([a-z0-9_]+)", "FEMININ (Personnage.kt)")
    return [{"masculin": m, "feminin": f} for m, f in paires]


def signes_absents(kt: str, polices_res: Path) -> list:
    """PoliceHebraique : pour chaque police, ses fichiers (la famille R.font dépliée ; aucun pour
    celle du téléphone) et les signes qu'elle n'a pas, masqués à l'affichage (ABSENTS), en points de code."""
    def lire(motif, quoi, drapeaux=0):
        trouve = re.findall(motif, kt, flags=drapeaux)
        if not trouve:
            raise SystemExit(f"tables : {quoi} introuvable dans PoliceHebraique.kt")
        return trouve
    polices = lire(r'^\s*([A-Z]+)\("([a-z]+)", R\.string\.([a-z0-9_]+)\)', "l'énumération Police", re.M)
    fichiers = dict(lire(r"Police\.([A-Z]+) -> ResourcesCompat\.getFont\(vue\.context, R\.font\.([a-z0-9_]+)\)",
                         "le choix des fichiers de police"))
    (de, a), = lire(r"TEAMIM = \(0x([0-9A-Fa-f]{4})\.\.0x([0-9A-Fa-f]{4})\)", "la plage des te'amim")
    teamim = list(range(int(de, 16), int(a, 16) + 1))
    bloc, = lire(r"ABSENTS: Map<Police, Masque> = mapOf\((.*?)\n    \)", "la table ABSENTS", re.S)
    absents = {}
    for police, expression in entrees(bloc, r"Police\.([A-Z]+) to Masque\(([^()]*)\)", "ABSENTS (PoliceHebraique.kt)"):
        points = []
        for terme in (t.strip() for t in expression.split("+")):
            if terme == "TEAMIM":
                points += teamim
            elif re.fullmatch(r'"(\\u[0-9A-Fa-f]{4})+"', terme):
                points += [int(h, 16) for h in re.findall(r"\\u([0-9A-Fa-f]{4})", terme)]
            else:
                raise SystemExit(f"tables : terme inattendu dans ABSENTS ({police}) : {terme}")
        if police in absents:
            raise SystemExit(f"tables : {police} paraît deux fois dans ABSENTS")
        absents[police] = points
    if set(absents) - {p for p, _, _ in polices}:
        raise SystemExit("tables : ABSENTS nomme une police inconnue")
    def deplie(police):
        # res/font/<nom>.xml : une famille (font-family), ses fichiers dans l'ordre ; sinon <nom>.ttf.
        famille = polices_res / f"{police}.xml"
        if famille.exists():
            membres = re.findall(r'android:font="@font/([a-z0-9_]+)"', famille.read_text(encoding="utf-8"))
        else:
            membres = [police]
        if not membres or any(not (polices_res / f"{m}.ttf").exists() for m in membres):
            raise SystemExit(f"tables : police introuvable sous res/font : {police}")
        return membres
    return [{"cle": cle, "libelle": libelle, "fichiers": deplie(fichiers[nom]) if nom in fichiers else [],
             "absents": [f"{p:04X}" for p in absents.get(nom, [])]} for nom, cle, libelle in polices]
