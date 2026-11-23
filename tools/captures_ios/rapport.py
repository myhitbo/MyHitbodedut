#!/usr/bin/env python3
"""Le résumé d'un rapport de plantage d'iOS (.ips) pour le journal de la CI (capturer.sh) : l'exception, la raison de
l'arrêt, le message d'erreur de Swift (« Fatal error: … ») et les premières lignes du fil fautif, symbolisées.

Un .ips tient deux objets JSON : l'en-tête sur la première ligne, puis le corps."""

import json
import sys


def main(chemin: str) -> None:
    with open(chemin, encoding="utf-8", errors="replace") as f:
        texte = f.read()
    entete, _, corps = texte.partition("\n")
    try:
        tete = json.loads(entete)
        rapport = json.loads(corps)
    except json.JSONDecodeError:
        print(texte[:4000])
        return
    print(f"{tete.get('app_name', '?')} {tete.get('app_version', '')} — {tete.get('bug_type', '')}")
    exception = rapport.get("exception", {})
    print("exception :", exception.get("type"), exception.get("signal"), exception.get("subtype", ""))
    terminaison = rapport.get("termination", {})
    if terminaison:
        print("arrêt :", terminaison.get("namespace"), terminaison.get("indicator"), terminaison.get("reasons", ""))
    for image, messages in (rapport.get("asi") or {}).items():
        for message in messages:
            print(f"{image} : {message}")
    images = rapport.get("usedImages", [])
    fils = rapport.get("threads", [])
    fautif = rapport.get("faultingThread", 0)
    if 0 <= fautif < len(fils):
        fil = fils[fautif]
        print(f"fil {fautif} {fil.get('name', '')} {fil.get('queue', '')}")
        for i, cadre in enumerate(fil.get("frames", [])[:30]):
            image = images[cadre["imageIndex"]].get("name", "?") if cadre.get("imageIndex", -1) < len(images) else "?"
            symbole = cadre.get("symbol", hex(cadre.get("imageOffset", 0)))
            lieu = f" ({cadre['sourceFile']}:{cadre.get('sourceLine', '')})" if "sourceFile" in cadre else ""
            print(f"{i:2} {image:28} {symbole}{lieu}")


if __name__ == "__main__":
    main(sys.argv[1])
