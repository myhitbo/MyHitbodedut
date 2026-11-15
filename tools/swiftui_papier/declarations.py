#!/usr/bin/env python3
"""Les déclarations exactes d'un symbole de SwiftUI (ou d'un autre cadre d'Apple) et de ses membres, lues
dans le JSON de la documentation d'Apple (developer.apple.com/tutorials/data/documentation/…). C'est la
source de ios/Paquets/Coeur/Sources/SwiftUIDePapier : chaque signature du papier se recopie d'ici.

  declarations.py swiftui/text                 le type et tous ses membres (constructeurs, méthodes…)
  declarations.py swiftui/view --membres font  seulement les membres dont le nom commence par « font »
  declarations.py swiftui/text --profondeur 0  le type seul
  declarations.py swiftui/view --profondeur 3 --membres navigationTitle   descend dans les pages de regroupement

Le JSON est gardé en cache (TMPDIR, ou /tmp) : une seconde lecture ne refait pas la requête."""
import argparse, hashlib, json, os, sys, urllib.request

BASE = "https://developer.apple.com/tutorials/data/documentation/"
CACHE = os.path.join(os.environ.get("TMPDIR", "/tmp"), "swiftui_papier_cache")


def lire(chemin):
    chemin = chemin.strip("/").lower()
    os.makedirs(CACHE, exist_ok=True)
    fichier = os.path.join(CACHE, hashlib.sha1(chemin.encode()).hexdigest() + ".json")
    if os.path.exists(fichier):
        with open(fichier, encoding="utf-8") as f:
            return json.load(f)
    try:
        with urllib.request.urlopen(BASE + chemin + ".json", timeout=30) as r:
            donnees = json.load(r)
    except Exception as e:  # symbole absent, chemin mal formé
        return {"erreur": str(e)}
    with open(fichier, "w", encoding="utf-8") as f:
        json.dump(donnees, f)
    return donnees


def declaration(d):
    for s in d.get("primaryContentSections", []):
        if s.get("kind") == "declarations":
            return ["".join(t["text"] for t in decl["tokens"]) for decl in s["declarations"]]
    return []


def chemin_de(reference):
    url = reference.get("url", "")
    return url.replace("/documentation/", "", 1) if url.startswith("/documentation/") else None


def main():
    p = argparse.ArgumentParser()
    p.add_argument("symbole")
    p.add_argument("--membres", default="", help="préfixe du nom des membres à garder")
    p.add_argument("--profondeur", type=int, default=1)
    a = p.parse_args()
    d = lire(a.symbole)
    if "erreur" in d:
        print(f"// {a.symbole} : {d['erreur']}")
        sys.exit(1)
    print(f"// {BASE}{a.symbole.lower()}.json")
    for ligne in declaration(d):
        print(ligne)
    vus = set()

    def membres(d, profondeur, prefixe_titre):
        refs = d.get("references", {})
        for section in d.get("topicSections", []):
            titre = prefixe_titre + section.get("title", "")
            for ident in section.get("identifiers", []):
                ref = refs.get(ident, {})
                chemin = chemin_de(ref)
                if not chemin or chemin in vus:
                    continue
                vus.add(chemin)
                sous = lire(chemin)
                decls = declaration(sous) if "erreur" not in sous else []
                if not decls:
                    # Une page de regroupement (« View modifiers », « Creating a text view ») : on y descend.
                    if profondeur > 1:
                        membres(sous, profondeur - 1, titre + " / ")
                    continue
                nom = ref.get("title", "")
                if a.membres and not nom.startswith(a.membres):
                    continue
                print(f"\n// [{titre}] {chemin}")
                for ligne in decls:
                    print(ligne)

    if a.profondeur >= 1:
        membres(d, a.profondeur, "")


if __name__ == "__main__":
    main()
