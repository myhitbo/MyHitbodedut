#!/usr/bin/env python3
"""Exporte les contenus d'Android pour iOS (ios/PORTAGE.md § 4.2, ROADMAP.md tâche 5).

Android reste la source : l'outil lit android/, web/ et tools/, et n'écrit que sous ios/.
Python 3, bibliothèque standard, hors ligne, déterministe : deux exports de suite donnent
le même manifeste. Étapes faites ici : 1 (textes), 2 (chaînes), 4 (palettes), 5 (images et
icônes), 6 (polices), 7 (musique), 9 (vecteurs de test), 10 (manifeste). Les étapes 3 (tables
du Kotlin) et 8 (index de recherche) sont celles de la tâche 6.

Usage : python3 tools/export_contenu/export.py [--verifier]
  --verifier : exporte, puis échoue si ios/Ressources/MANIFESTE.json a changé (garde de dérive).
"""

import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parents[2]
ANDROID = RACINE / "android" / "app" / "src" / "main"
RES = ANDROID / "res"
RAW = RES / "raw"
IOS = RACINE / "ios"
SORTIE = IOS / "Ressources"
TESTS = IOS / "Paquets" / "Coeur" / "Tests" / "Ressources"
MANIFESTE = SORTIE / "MANIFESTE.json"

SEUIL_DECOUPE = 2_000_000  # octets : au-delà, un livre est servi chapitre par chapitre
LANGUES = [("fr", "values"), ("en", "values-en"), ("he", "values-iw")]
# Chaînes propres à Android (divulgations Play, batterie, superposition) : sans objet sur iOS.
EXCLUES = re.compile(r"^(divulgation_|permission_battery|permission_overlay)")

# Ce que l'export doit trouver (critère de la tâche 5) : un écart arrête tout.
COMPTES = {
    "textes par rite": 38, "psaumes": 150, "versets": 2527, "psaumes du Tikoun": 10,
    "textes de 'hizouk": 171, "livres": 12, "hilloulot": 4049, "villes": 51,
    "aéroports": 3226, "morceaux": 26,
}

# Licence et mention de chaque fichier produit (PORTAGE.md § 4.1 et § 6) : un fichier sans
# règle arrête l'export, il n'y a pas de licence « inconnue ».
LICENCES = [
    (r"Contenu/siddur_(edot|sefard|ashkenaz)\.json",
     "domaine public, CC0, CC-BY, CC BY-SA",
     "Torat Emet 357 et Daat (domaine public), Shaliehsaboo (CC0), Metsudah 1981 (CC-BY), "
     "Wikipédia hébreu (CC BY-SA)"),
    (r"Contenu/siddur_annotations\.json", "dérivé des siddourim", "dérivé des trois siddourim"),
    (r"Contenu/tehilim\.json", "domaine public", "tanach.us, Bible du Rabbinat 1899, JPS 1917"),
    (r"Contenu/tikkun_haklali\.json", "domaine public ; liturgie fournie par le propriétaire",
     "psaumes du domaine public ; liturgie fournie par le propriétaire"),
    (r"Contenu/chizuk\.json", "domaine public ; extraits sous droits",
     "éditions du domaine public via Sefaria ; extraits de « Bisdei Yaar » (Rav Shalom Arush), texte de l'éditeur"),
    (r"Contenu/bibliotheque\.json", "domaine public", "sources du domaine public ; articles en fiche seulement"),
    (r"Contenu/guide_sujets\.json", "propre à l'app", ""),
    (r"Contenu/yalkut_yosef\.json", "droits réservés, accord déclaré ; CC BY-NC-SA 2.5",
     "Yalkout Yossef, droits réservés à l'auteur ; saisie Torat Emet (CC BY-NC-SA 2.5)"),
    (r"Contenu/ben_ish_hai\.json", "domaine public", "Wikisource via Sefaria"),
    (r"Contenu/hilloulot\.json", "CC BY-SA 4.0 ; CC BY-NC-SA 2.5",
     "Wikipédia hébreu (CC BY-SA 4.0), hyomi, Hidabroot, Torat Emet (CC BY-NC-SA 2.5)"),
    (r"Contenu/hilloulot_bios/[a-z0-9]+\.json", "reprise avec mention, accord déclaré",
     "MyTzadik et המאיר לארץ"),
    (r"Contenu/(livres_titres\.json|livre_[a-z0-9_]+\.json|livres/.+\.json)",
     "par livre (PORTAGE.md § 6.3)", "sources dans livres_titres.json, _meta.sources"),
    (r"Contenu/villes\.json", "CC-BY 4.0", "GeoNames"),
    (r"Contenu/aeroports(_noms)?\.json", "domaine public ; ODbL ; CC0",
     "OurAirports, timezone-boundary-builder (ODbL), Wikidata"),
    (r"Contenu/(trophees_formes|palettes)\.json", "propre à l'app", ""),
    (r"Contenu/musique\.json", "accord écrit (PORTAGE.md § 6.1)", "voir chaque morceau"),
    (r"Chaines/(Localizable\.xcstrings|Tableaux\.json)", "propre à l'app", ""),
    (r"Catalogue/Localizable\.xcstrings", "propre à l'app", ""),
    (r"Images/[a-z0-9_]+\.webp", "fournies par le propriétaire", ""),
    (r"Icones/[a-z0-9_]+\.svg", "propre à l'app", ""),
    (r"Polices/[a-z0-9_]+\.ttf", "SIL OFL 1.1", "voir Polices/licences"),
    (r"Polices/licences/OFL-[A-Za-z]+\.txt", "SIL OFL 1.1", ""),
    (r"Musique/[a-z0-9_]+\.m4a", "accord écrit (PORTAGE.md § 6.1)", "voir Contenu/musique.json"),
    (r"Paquets/Coeur/Tests/Ressources/.+", "données de test", "produites par le dépôt"),
]


class Export:
    def __init__(self):
        self.produits = {}  # chemin relatif à ios/ → source relative au dépôt

    # --- écriture, sous ios/ seulement --------------------------------------
    def _cible(self, chemin: Path) -> Path:
        chemin = chemin.resolve()
        if IOS.resolve() not in chemin.parents:
            raise SystemExit(f"écriture hors de ios/ refusée : {chemin}")
        chemin.parent.mkdir(parents=True, exist_ok=True)
        return chemin

    def _note(self, cible: Path, source):
        cle = cible.resolve().relative_to(IOS.resolve()).as_posix()
        self.produits[cle] = source if isinstance(source, str) else source.relative_to(RACINE).as_posix()

    def copier(self, source: Path, cible: Path):
        shutil.copyfile(source, self._cible(cible))
        self._note(cible, source)

    def json(self, cible: Path, valeur, source, indent=None):
        texte = json.dumps(valeur, ensure_ascii=False, indent=indent,
                           separators=None if indent else (",", ":"))
        self._cible(cible).write_text(texte + ("\n" if indent else ""), encoding="utf-8")
        self._note(cible, source)

    # --- 1. Textes ----------------------------------------------------------
    def textes(self):
        contenu = SORTIE / "Contenu"
        for source in sorted(RAW.glob("*.json")):
            nom = source.name
            if nom == "hilloulot_bios.json":
                self._bios(source, contenu / "hilloulot_bios")
            elif nom.startswith("livre_") and source.stat().st_size > SEUIL_DECOUPE:
                self._livre_decoupe(source, contenu / "livres" / nom[len("livre_"):-len(".json")])
            else:
                self.copier(source, contenu / nom)

    def _bios(self, source, dossier):
        # Clés « mois-jour » (mois de KosherJava, adar, adar1, adar2) : un fichier par mois, comme le site.
        bios = json.loads(source.read_text(encoding="utf-8"))
        par_mois = {}
        for cle, ligne in bios.items():
            mois = cle.split("-")[0]
            if not re.fullmatch(r"[a-z0-9]+", mois):
                raise SystemExit(f"clé de hilloula inattendue : {cle}")
            par_mois.setdefault(mois, {})[cle] = ligne
        recompose = {}
        for mois in sorted(par_mois):
            self.json(dossier / f"{mois}.json", par_mois[mois], source)
            recompose.update(par_mois[mois])
        if recompose != bios:
            raise SystemExit("hilloulot_bios : la découpe par mois ne redonne pas l'original")

    def _livre_decoupe(self, source, dossier):
        # index.json : l'en-tête et le nombre de chapitres ; puis un fichier par chapitre.
        livre = json.loads(source.read_text(encoding="utf-8"))
        index = {k: v for k, v in livre.items() if k != "textes"}
        index["textes"] = []
        recompose = {k: v for k, v in livre.items() if k != "textes"}
        recompose["textes"] = []
        for t, texte in enumerate(livre["textes"]):
            sections = texte["sections"]
            entete = {k: v for k, v in texte.items() if k != "sections"}
            index["textes"].append({**entete, "chapitres": len(sections)})
            for c, section in enumerate(sections, start=1):
                self.json(dossier / f"{t:02d}-{c:04d}.json", section, source)
            recompose["textes"].append({**entete, "sections": sections})
        self.json(dossier / "index.json", index, source)
        if json.dumps(recompose, sort_keys=True) != json.dumps(livre, sort_keys=True):
            raise SystemExit(f"{source.name} : la découpe ne redonne pas l'original")

    # --- 2. Chaînes ---------------------------------------------------------
    def chaines(self):
        brutes = {langue: lit_chaines((RES / dossier / "strings.xml").read_text(encoding="utf-8"))
                  for langue, dossier in LANGUES}
        verifier_chaines(brutes)
        fr = brutes["fr"]
        cles = sorted(k for k in fr["chaines"] if not EXCLUES.match(k))
        doc = {"sourceLanguage": "fr", "strings": {}, "version": "1.0"}
        for cle in cles:
            loc = {}
            for langue, _ in LANGUES:
                valeur = brutes[langue]["chaines"].get(cle, fr["chaines"][cle])  # le défaut sous chaque langue
                loc[langue] = {"stringUnit": {"state": "translated", "value": format_ios(valeur)}}
            doc["strings"][cle] = {"localizations": loc}
        for cle in sorted(k for k in fr["pluriels"] if not EXCLUES.match(k)):
            loc = {}
            for langue, _ in LANGUES:
                formes = brutes[langue]["pluriels"].get(cle, fr["pluriels"][cle])
                loc[langue] = {"variations": {"plural": {
                    q: {"stringUnit": {"state": "translated", "value": format_ios(v)}}
                    for q, v in sorted(formes.items())}}}
            doc["strings"][cle] = {"localizations": loc}
        source = "android/app/src/main/res/values*/strings.xml"
        self.json(SORTIE / "Chaines" / "Localizable.xcstrings", doc, source, indent=2)
        # La copie que compile Xcode (Catalogue/, pour Text("clé")) : son compilateur refuse un pluriel dont
        # aucune forme ne cite le nombre (« jour » / « jours ») ; un tel pluriel y devient une chaîne simple,
        # sa forme « other ». Le Traducteur lit Chaines/Localizable.xcstrings, fidèle à Android.
        compile = json.loads(json.dumps(doc))
        for cle, entree in compile["strings"].items():
            locs = entree["localizations"]
            pluriels = [l["variations"]["plural"] for l in locs.values() if "variations" in l]
            if pluriels and not any("%" in f["stringUnit"]["value"] for pl in pluriels for f in pl.values()):
                entree["localizations"] = {lg: {"stringUnit": l["variations"]["plural"]["other"]["stringUnit"]}
                                           for lg, l in locs.items()}
        self.json(SORTIE / "Catalogue" / "Localizable.xcstrings", compile, source, indent=2)
        tableaux = {langue: {**fr["tableaux"], **brutes[langue]["tableaux"]} for langue, _ in LANGUES}
        self.json(SORTIE / "Chaines" / "Tableaux.json", tableaux, source)

    # --- 4. Palettes --------------------------------------------------------
    def palettes(self):
        jetons = ["brand", "brand_dark", "mint", "on_brand", "on_plate", "stage_soft", "day_done",
                  "paper", "card", "line", "ink", "muted", "day_todo"]
        camel = {f"mh{''.join(p.capitalize() for p in j.split('_'))}": j for j in jetons}
        # Comme Android et le site : la nuit recouvre le jour, couche par couche
        # (vert de jour < vert de nuit < fond de jour < fond de nuit < accent de jour < accent de nuit).
        lire = lambda d, f: (RES / d / f).read_text(encoding="utf-8")
        couches = {"jour": [("values", couleurs(lire("values", "colors.xml")),
                             styles(lire("values", "palettes.xml"), camel))]}
        couches["nuit"] = couches["jour"] + [("values-night", couleurs(lire("values-night", "colors.xml")),
                                              styles(lire("values-night", "palettes.xml"), camel))]
        noms = lambda genre: ["vert"] + sorted({n for (g, n) in couches["jour"][0][2] if g == genre})
        modes = {}
        for mode, liste in couches.items():
            combinaisons = {}
            for fond in noms("fond"):
                for accent in noms("accent"):
                    valeurs = {}
                    for _, base, _ in liste:
                        valeurs.update({j: base[j] for j in jetons if j in base})
                    for genre, nom in (("fond", fond), ("accent", accent)):
                        for _, _, st in liste:
                            valeurs.update(st.get((genre, nom), {}))
                    if set(valeurs) != set(jetons):
                        raise SystemExit(f"palettes {mode} {fond}/{accent} : jetons manquants {set(jetons) - set(valeurs)}")
                    combinaisons[f"{fond}/{accent}"] = {j: valeurs[j] for j in jetons}
            modes[mode] = combinaisons
        if any(len(m) != 36 for m in modes.values()):
            raise SystemExit(f"palettes : {[len(m) for m in modes.values()]} combinaisons au lieu de 36")
        self.json(SORTIE / "Contenu" / "palettes.json", {"jetons": jetons, "modes": modes},
                  "android/app/src/main/res/values*/colors.xml, palettes.xml")

    # --- 5. Images et icônes ------------------------------------------------
    def images(self):
        for source in sorted((RES / "drawable-nodpi").glob("*.webp")):
            self.copier(source, SORTIE / "Images" / source.name)
        for source in sorted((RES / "drawable").glob("*.xml")):
            xml = source.read_text(encoding="utf-8")
            if "<vector" in xml:
                svg = vecteur_en_svg(xml, source.name)
                cible = self._cible(SORTIE / "Icones" / (source.stem + ".svg"))
                cible.write_text(svg, encoding="utf-8")
                self._note(cible, source)

    # --- 6. Polices ---------------------------------------------------------
    def polices(self):
        for source in sorted((RES / "font").glob("*.ttf")):
            self.copier(source, SORTIE / "Polices" / source.name)
        for source in sorted((ANDROID / "assets" / "licences").glob("*.txt")):
            self.copier(source, SORTIE / "Polices" / "licences" / source.name)

    # --- 7. Musique ---------------------------------------------------------
    def musique(self):
        kt = ANDROID / "java" / "com" / "myhitbodedut" / "MusiquePlay.kt"
        motif = re.compile(r'Bundled\("([a-z0-9_]+)", R\.raw\.\1, R\.string\.(track_[a-z0-9_]+)\)')
        morceaux = [{"id": i, "titre": t} for i, t in motif.findall(kt.read_text(encoding="utf-8"))]
        if not morceaux:
            raise SystemExit("aucun morceau trouvé dans MusiquePlay.kt")
        for m in morceaux:
            source = RAW / f"{m['id']}.m4a"  # jamais src/musique_hors_play
            if not source.exists():
                raise SystemExit(f"morceau manquant : {source}")
            self.copier(source, SORTIE / "Musique" / source.name)
            m["fichier"] = f"Musique/{source.name}"
            m["octets"] = source.stat().st_size
        self.json(SORTIE / "Contenu" / "musique.json", morceaux, kt)
        return len(morceaux)

    # --- 9. Vecteurs de test ------------------------------------------------
    def vecteurs(self):
        sources = [RACINE / "web" / "test" / n for n in
                   ("vecteurs_kosherjava.json", "vecteurs_vol.json", "vecteurs_wmm2025.txt")]
        sources += sorted((RACINE / "android" / "app" / "src" / "test" / "resources").glob("zmanim_reference_*.json"))
        for source in sources:
            self.copier(source, TESTS / source.name)

    # --- 10. Manifeste ------------------------------------------------------
    def manifeste(self):
        fichiers = []
        for chemin in sorted(self.produits):
            relatif = chemin[len("Ressources/"):] if chemin.startswith("Ressources/") else chemin
            regle = next((r for r in LICENCES if re.fullmatch(r[0], relatif)), None)
            if regle is None:
                raise SystemExit(f"aucune licence pour {chemin}")
            donnees = (IOS / chemin).read_bytes()
            fichiers.append({
                "chemin": chemin, "source": self.produits[chemin], "octets": len(donnees),
                "sha256": hashlib.sha256(donnees).hexdigest(), "licence": regle[1], "mention": regle[2],
            })
        texte = json.dumps({"outil": "tools/export_contenu/export.py", "fichiers": fichiers},
                           ensure_ascii=False, indent=1) + "\n"
        self._cible(MANIFESTE).write_text(texte, encoding="utf-8")
        return texte


# --- Comptes ----------------------------------------------------------------
def compter(nombre_morceaux):
    lit = lambda n: json.loads((RAW / n).read_text(encoding="utf-8"))
    tehilim = lit("tehilim.json")
    trouves = {
        "textes par rite": {len(lit(f"siddur_{r}.json")["textes"]) for r in ("edot", "sefard", "ashkenaz")},
        "psaumes": len(tehilim["psaumes"]),
        "versets": sum(len(p) for p in tehilim["psaumes"]),
        "psaumes du Tikoun": len(lit("tikkun_haklali.json")["psaumes"]),
        "textes de 'hizouk": len(lit("chizuk.json")["items"]),
        "livres": len(lit("livres_titres.json")["textes"]),
        "hilloulot": sum(len(v) for v in lit("hilloulot.json")["jours"].values()),
        "villes": len(lit("villes.json")["villes"]),
        "aéroports": len(lit("aeroports.json")["aeroports"]),
        "morceaux": nombre_morceaux,
    }
    trouves["textes par rite"] = trouves["textes par rite"].pop() if len(trouves["textes par rite"]) == 1 else -1
    ecarts = {k: (v, trouves[k]) for k, v in COMPTES.items() if trouves[k] != v}
    if ecarts:
        raise SystemExit("comptes : " + ", ".join(f"{k} attendu {a}, trouvé {t}" for k, (a, t) in ecarts.items()))
    livres_fichiers = len(list(RAW.glob("livre_*.json")))
    if livres_fichiers != COMPTES["livres"]:
        raise SystemExit(f"livres : {livres_fichiers} fichiers livre_*.json au lieu de {COMPTES['livres']}")


# --- strings.xml (comme web/tools/chaines.mjs) -------------------------------
ENTITES = {"amp": "&", "lt": "<", "gt": ">", "quot": '"', "apos": "'"}


def _entites(s):
    def remplace(m):
        e = m.group(1)
        if e.startswith("#"):
            return chr(int(e[2:], 16) if e[1] == "x" else int(e[1:]))
        if e not in ENTITES:
            raise SystemExit(f"entité inconnue : {m.group(0)}")
        return ENTITES[e]
    return re.sub(r"&(#x[0-9a-fA-F]+|#\d+|\w+);", remplace, s)


def valeur_android(brute):
    """Ce qu'aapt fait d'une valeur : guillemets, échappements, espaces ASCII ramenés à un seul."""
    s = _entites(brute)
    if re.search(r"<[a-zA-Z/]", s):
        raise SystemExit(f"balise dans une chaîne : {brute}")
    sortie, entre = [], False
    i = 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            i += 1
            n = s[i]
            sortie.append(("\n" if n == "n" else "\t" if n == "t" else n, False))
        elif c == '"':
            entre = not entre
        elif c in " \t\n\r\f\v" and not entre:
            if not (sortie and sortie[-1][1]):
                sortie.append((" ", True))
        else:
            sortie.append((c, False))
        i += 1
    while sortie and sortie[0][1]:
        sortie.pop(0)
    while sortie and sortie[-1][1]:
        sortie.pop()
    return "".join(c for c, _ in sortie)


def lit_chaines(xml):
    xml = re.sub(r"<!--.*?-->", "", xml, flags=re.S)
    nom = lambda attrs: re.search(r'name="([^"]*)"', attrs).group(1)
    chaines, pluriels, tableaux, fixes = {}, {}, {}, set()
    for attrs, corps in re.findall(r"<string\b(?!-)([^>]*)>(.*?)</string>", xml, flags=re.S):
        chaines[nom(attrs)] = valeur_android(corps)
        if 'translatable="false"' in attrs:
            fixes.add(nom(attrs))
    for attrs in re.findall(r"<string\b(?!-)([^>]*)/>", xml):
        chaines[nom(attrs)] = ""
    for attrs, corps in re.findall(r"<plurals\b([^>]*)>(.*?)</plurals>", xml, flags=re.S):
        pluriels[nom(attrs)] = {q: valeur_android(v) for q, v in
                                re.findall(r'<item\b[^>]*quantity="([^"]*)"[^>]*>(.*?)</item>', corps, flags=re.S)}
    for attrs, corps in re.findall(r"<string-array\b([^>]*)>(.*?)</string-array>", xml, flags=re.S):
        tableaux[nom(attrs)] = [valeur_android(v) for v in re.findall(r"<item\b[^>]*>(.*?)</item>", corps, flags=re.S)]
    return {"chaines": chaines, "pluriels": pluriels, "tableaux": tableaux, "fixes": fixes}


# Position, puis largeur éventuelle (« %2$02d », des minutes sur deux chiffres), puis le type.
FORMAT = re.compile(r"%(\d+\$)?(0?\d*)([sd])")


def format_ios(valeur):
    """%1$s → %1$@, %d → %lld, %2$02d → %2$02lld ; %% reste tel quel."""
    return FORMAT.sub(lambda m: "%" + (m.group(1) or "") + m.group(2) + ("@" if m.group(3) == "s" else "lld"), valeur)


def marqueurs(valeur):
    return sorted(m.group(0) for m in FORMAT.finditer(valeur))


def verifier_chaines(brutes):
    fr = brutes["fr"]
    for langue in ("en", "he"):
        b = brutes[langue]
        inconnues = (set(b["chaines"]) - set(fr["chaines"])) | (set(b["pluriels"]) - set(fr["pluriels"]))
        if inconnues:
            raise SystemExit(f"{langue} : clés absentes du français : {sorted(inconnues)[:5]}")
        manquantes = set(fr["chaines"]) - set(b["chaines"]) - fr["fixes"]
        if manquantes:
            raise SystemExit(f"{langue} : chaînes traduisibles non traduites : {sorted(manquantes)[:5]}")
        for cle, valeur in b["chaines"].items():
            if marqueurs(valeur) != marqueurs(fr["chaines"][cle]):
                raise SystemExit(f"{langue} : marqueurs de format discordants pour {cle}")
        for cle, formes in b["pluriels"].items():
            # « other » porte tous les marqueurs ; les autres formes peuvent en taire, comme
            # l'hébreu qui écrit le nombre en toutes lettres au singulier et au duel.
            tous = set().union(*(marqueurs(v) for v in fr["pluriels"][cle].values()))
            if marqueurs(formes.get("other", "")) != marqueurs(fr["pluriels"][cle].get("other", "")) \
                    or any(not set(marqueurs(v)) <= tous for v in formes.values()):
                raise SystemExit(f"{langue} : marqueurs de format discordants pour le pluriel {cle}")


# --- colors.xml, palettes.xml (comme web/tools/palettes.mjs) -----------------
def couleurs(xml):
    xml = re.sub(r"<!--.*?-->", "", xml, flags=re.S)
    return dict(re.findall(r'<color name="([a-z_]+)">(#[0-9A-Fa-f]{6,8})</color>', xml))


def styles(xml, camel):
    xml = re.sub(r"<!--.*?-->", "", xml, flags=re.S)
    sortie = {}
    for genre, nom, corps in re.findall(r'<style name="(Fond|Accent)\.(\w+)"[^>]*>(.*?)</style>', xml, flags=re.S):
        sortie[(genre.lower(), nom.lower())] = {camel[k]: v for k, v in
                                                re.findall(r'<item name="(mh\w+)">(#[0-9A-Fa-f]{6})</item>', corps)}
    return sortie


# --- VectorDrawable → SVG (comme web/build.mjs) ------------------------------
def vecteur_en_svg(xml, nom):
    vue = re.search(r'android:viewportWidth="([\d.]+)".*?android:viewportHeight="([\d.]+)"', xml, flags=re.S)
    if not vue:
        raise SystemExit(f"{nom} : viewport introuvable")
    chemins = []
    for attrs in re.findall(r"<path\b(.*?)/>", xml, flags=re.S):
        a = lambda n: (re.search(rf'android:{n}="([^"]*)"', attrs) or [None, None])[1]
        if a("fillColor"):
            chemins.append(f'<path d="{a("pathData")}" fill="currentColor" fill-opacity="{a("fillAlpha") or 1}"'
                           f' fill-rule="{"evenodd" if a("fillType") == "evenOdd" else "nonzero"}"/>')
        else:
            chemins.append(f'<path d="{a("pathData")}" fill="none" stroke="currentColor"'
                           f' stroke-width="{a("strokeWidth")}" stroke-opacity="{a("strokeAlpha") or 1}"'
                           f' stroke-linecap="{a("strokeLineCap") or "butt"}"'
                           f' stroke-linejoin="{a("strokeLineJoin") or "miter"}"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {vue.group(1)} {vue.group(2)}">'
            + "".join(chemins) + "</svg>\n")


def main():
    verifier = "--verifier" in sys.argv[1:]
    avant = MANIFESTE.read_text(encoding="utf-8") if MANIFESTE.exists() else None
    for dossier in ("Contenu", "Images", "Icones", "Polices", "Musique", "Catalogue"):
        shutil.rmtree(SORTIE / dossier, ignore_errors=True)
    for fichier in ("Localizable.xcstrings", "Tableaux.json"):
        (SORTIE / "Chaines" / fichier).unlink(missing_ok=True)
    shutil.rmtree(TESTS, ignore_errors=True)

    e = Export()
    e.textes()
    e.chaines()
    e.palettes()
    e.images()
    e.polices()
    compter(e.musique())
    e.vecteurs()
    apres = e.manifeste()
    total = sum(f.stat().st_size for f in SORTIE.rglob("*") if f.is_file())
    print(f"{len(e.produits)} fichiers, {total / 1e6:.1f} Mo sous ios/Ressources ; comptes conformes")

    if verifier and apres != avant:
        anciens = {f["chemin"]: f["sha256"] for f in json.loads(avant)["fichiers"]} if avant else {}
        nouveaux = {f["chemin"]: f["sha256"] for f in json.loads(apres)["fichiers"]}
        for chemin in sorted(set(anciens) | set(nouveaux)):
            if anciens.get(chemin) != nouveaux.get(chemin):
                etat = "nouveau" if chemin not in anciens else "disparu" if chemin not in nouveaux else "modifié"
                print(f"  {etat} : {chemin}")
        raise SystemExit("le contenu d'Android a changé sans que ios/Ressources/MANIFESTE.json suive : "
                         "relancer l'export et versionner le manifeste")


if __name__ == "__main__":
    main()
