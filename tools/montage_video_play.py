#!/usr/bin/env python3
"""Montage de la video des services de premier plan (play/CONSOLE.md § 3.9).

  montage.py <dossier des films> <sortie.mp4>

Lit journal.txt (les reperes « film <nom> t=… : … » poses par recette.py), pose chaque sequence
sous un bandeau de legendes en anglais, intercale trois cartons, et assemble le tout.
"""
import os
import re
import subprocess
import sys
import textwrap

POLICE = "/usr/share/fonts/opentype/inter/Inter-SemiBold.otf"
POLICE_TITRE = "/usr/share/fonts/opentype/inter/Inter-Bold.otf"
L, H_FILM, BANDEAU = 720, 1600, 232
FOND = "0x143d31"

# Par film : (debut du repere, legende, avance). Le repere est note apres l'attente qui suit le
# geste ; l'avance (en secondes) ramene la legende au moment du geste.
LEGENDES = {
    "video-seance-1": [
        ("accueil", "1 · SESSION TIMER\nThe Today screen of the app.", 9),
        ("volet", "The user opens the start panel: length, topic, music.", 2.8),
        ("musique", "Music screen: the user picks the track that will play during the session.", 3.2),
        ("retour au volet", "Back to the start panel, with the chosen track.", 2.5),
        ("seance lancee", "The user taps Start. A foreground service runs the countdown and plays the chosen track.", 3.2),
        ("notification", "Its notification shows the time left.", 0.3),
    ],
    "video-seance-2": [
        ("ecran rallume", "The screen was turned off for 30 seconds, phone put down, and is turned on again.", 9),
        ("seance toujours en cours", "The session kept running with the screen off: the countdown has moved on.", 3.5),
        ("notification apres l'ecran eteint", "The notification is still there, with the time left.", 0.3),
    ],
    "video-barriere-1": [
        ("accueil", "2 · MORNING GATE\nA self-discipline tool the user sets up for themselves.", 9),
        ("reglages", "Settings. The card “Permissions” is at the bottom.", 3.2),
        ("carte des autorisations", "Card “Permissions”: the user taps Grant for “Display over other apps”.", 0.5),
        ("divulgation", "An in-app disclosure comes first: what is used, why, and how to turn it off.", 3.2),
        ("ecran d'Android", "Then the user allows it in the Android screen.", 3.2),
        ("retour dans l'application", "Back in the app: granted.", 1.5),
    ],
    "video-barriere-2": [
        ("carte des autorisations", "Same for “Usage access”: the user taps Grant.", 9),
        ("divulgation", "The in-app disclosure: only the app in the foreground is read; nothing is recorded or sent.", 3.2),
        ("ecran d'Android", "The user allows it in the Android screen.", 3.2),
        ("retour dans l'application", "Back in the app: both accesses are granted.", 1.5),
    ],
    "video-barriere-3": [
        ("cherche", "Up to the card “I am with Hashem”.", 9),
        ("carte du mode", "Card “I am with Hashem”: the user turns the gate on.", 0.5),
        ("mode allume", "The gate is on.", 2.7),
        ("notification du mode", "Its service keeps a permanent notification while it runs.", 0.3),
        ("liste des applications", "The user picks the apps the gate applies to.", 4.2),
        ("application choisie", "One app is picked: Chrome.", 2.7),
        ("etat", "Status card: the gate acts during the hours the user set, until the practice of the day is done.", 0.5),
    ],
    "video-barriere-4": [
        ("application ouverte", "The user opens the app they picked…", 9),
        ("ecran de garde", "…and the gate appears in front of it.", 6.5),
        ("fait sans le telephone", "“Done without the phone”: the gate goes away and the app is there.", 4.2),
        ("retour dans MyHitbodedut", "Back in MyHitbodedut, Settings.", 4.0),
        ("carte du mode, pour couper", "The user can switch the gate off at any time.", 0.5),
        ("mode coupe", "The gate is off.", 2.7),
        ("plus de notification", "Its service has stopped: the notification is gone.", 0.3),
    ],
}

CARTONS = {
    "debut": ("MyHitbodedut", "Foreground services demo\n\n1 · Session timer\n(special use + media playback)\n\n2 · Morning gate\n(special use)\n\nRecorded on an Android emulator,\nwithout sound."),
    "barriere": ("2 · Morning gate", "The user turns it on for themselves,\npicks the apps it applies to,\nand can switch it off at any time.\n\nBoth accesses are requested\nafter an in-app disclosure."),
    "fin": ("MyHitbodedut", "Both services start from a user action,\nshow a notification while they run,\nand stop when the user says so.\n\nNo usage data leaves the device."),
}


def reperes(journal, nom):
    sortie = []
    for ligne in open(journal, encoding="utf-8"):
        m = re.match(rf"\s+film {re.escape(nom)} t=([\d.]+) : (.*)", ligne)
        if m:
            sortie.append((float(m.group(1)), m.group(2).strip()))
    return sortie


def duree(fichier):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", fichier],
                       capture_output=True, text=True)
    return float(r.stdout.strip() or 0)


def echappe(chemin):
    return chemin.replace("\\", "\\\\").replace(":", "\\:").replace("'", "\\'")


COMPTEUR = [0]


def lignes_centrees(lignes, y0, taille, pas, police, couleur, travail, quand=None):
    """Un filtre drawtext par ligne, chacune centree (drawtext aligne a gauche un bloc de lignes)."""
    filtres = []
    for i, ligne in enumerate(lignes):
        if not ligne.strip():
            continue
        COMPTEUR[0] += 1
        fichier = os.path.join(travail, f"texte-{COMPTEUR[0]:04d}.txt")
        with open(fichier, "w", encoding="utf-8") as f:
            f.write(ligne)
        filtre = (f"drawtext=fontfile={echappe(police)}:textfile={echappe(fichier)}:fontcolor={couleur}:"
                  f"fontsize={taille}:x=(w-text_w)/2:y={y0 + i * pas}")
        if quand:
            filtre += f":enable='between(t,{quand[0]:.2f},{quand[1]:.2f})'"
        filtres.append(filtre)
    return filtres


VITE = 4.0


def sequence(dossier, nom, travail, decalage=-0.8):
    """Une sequence sous son bandeau. decalage : screenrecord demarre un peu apres le repere « debut ».
    Les recherches dans la page (reperes « cherche » … « trouve ») passent en accelere."""
    source = os.path.join(dossier, nom + ".mp4")
    if not os.path.exists(source) or os.path.getsize(source) < 20000:
        print("  absente :", nom)
        return None
    total = duree(source)
    marques = [(max(0.0, t + decalage), texte) for t, texte in reperes(os.path.join(dossier, "journal.txt"), nom)]
    fin_film = min(total, next((t for t, texte in marques if texte == "fin"), total) + 0.5)
    # Les plages a accelerer : une recherche de plus de 5 s, moins une seconde a chaque bout.
    rapides, depuis = [], None
    for t, texte in marques:
        if texte == "cherche" and depuis is None:
            depuis = t
        elif texte == "trouve" and depuis is not None:
            if t - depuis > 5.0 and t < fin_film:
                rapides.append((depuis + 1.0, t - 1.0))
            depuis = None
    # Les morceaux : (debut, fin, vitesse), et la conversion du temps du film en temps du montage.
    morceaux, curseur = [], 0.0
    for a, b in rapides:
        if a > curseur:
            morceaux.append((curseur, a, 1.0))
        morceaux.append((a, b, VITE))
        curseur = b
    if fin_film > curseur:
        morceaux.append((curseur, fin_film, 1.0))

    def monte(t):
        sortie = 0.0
        for a, b, v in morceaux:
            if t >= b:
                sortie += (b - a) / v
            elif t > a:
                sortie += (t - a) / v
        return sortie

    chaines = []
    for i, (a, b, v) in enumerate(morceaux):
        chaines.append(f"[0:v]trim=start={a:.3f}:end={b:.3f},setpts=(PTS-STARTPTS)/{v:.1f},fps=30[m{i}]")
    chaines.append("".join(f"[m{i}]" for i in range(len(morceaux))) + f"concat=n={len(morceaux)}:v=1:a=0[film]")

    plages = []
    for cle, legende, avance in LEGENDES.get(nom, []):
        t = next((t for t, texte in marques if texte.startswith(cle)), None)
        if t is not None:
            plages.append([max(0.0, t - avance), legende])
    plages.sort()
    filtres = [f"scale={L}:{H_FILM}:flags=lanczos", f"pad={L}:{H_FILM + BANDEAU}:0:{BANDEAU}:color={FOND}"]
    for i, (debut, legende) in enumerate(plages):
        fin = monte(plages[i + 1][0]) if i + 1 < len(plages) else monte(fin_film) + 1
        debut = 0.0 if i == 0 else monte(debut)
        lignes = []
        for bloc in legende.split("\n"):
            lignes += textwrap.wrap(bloc, 40) or [""]
        y = (BANDEAU - len(lignes) * 44) // 2 + 2
        filtres += lignes_centrees(lignes, y, 31, 44, POLICE, "white", travail, quand=(debut, fin))
    for a, b in rapides:
        COMPTEUR[0] += 1
        fichier = os.path.join(travail, f"texte-{COMPTEUR[0]:04d}.txt")
        open(fichier, "w", encoding="utf-8").write(f"fast forward ×{VITE:.0f}")
        filtres.append(f"drawtext=fontfile={echappe(POLICE)}:textfile={echappe(fichier)}:fontcolor=0x9fd8b8:fontsize=22:"
                       f"x=w-text_w-18:y={BANDEAU - 34}:enable='between(t,{monte(a):.2f},{monte(b):.2f})'")
    chaines.append("[film]" + ",".join(filtres) + "[sortie]")
    sortie = os.path.join(travail, nom + ".mp4")
    script = os.path.join(travail, nom + "-filtres.txt")
    open(script, "w", encoding="utf-8").write(";\n".join(chaines))
    commande = ["ffmpeg", "-y", "-v", "error", "-i", source, "-filter_complex_script", script, "-map", "[sortie]",
                "-r", "30", "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p", sortie]
    r = subprocess.run(commande, capture_output=True, text=True)
    if r.returncode != 0:
        print("  ffmpeg :", r.stderr[-900:])
        return None
    print(f"  {nom} : {duree(source):.0f} s -> {duree(sortie):.1f} s, {len(plages)} legendes, {len(rapides)} accelerees")
    return sortie


def carton(cle, travail, secondes=5.0):
    titre, corps = CARTONS[cle]
    sortie = os.path.join(travail, f"carton-{cle}.mp4")
    lignes = corps.split("\n")
    haut = (H_FILM + BANDEAU - (150 + len(lignes) * 52)) // 2
    vf = ",".join(lignes_centrees([titre], haut, 60, 0, POLICE_TITRE, "white", travail)
                  + lignes_centrees(lignes, haut + 150, 33, 52, POLICE, "0xdff3e6", travail))
    r = subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i", f"color=c={FOND}:s={L}x{H_FILM + BANDEAU}:r=30:d={secondes}",
                        "-vf", vf, "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p", sortie],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print("  ffmpeg carton :", r.stderr[-600:])
        return None
    return sortie


def assembler(morceaux, sortie, travail):
    liste = os.path.join(travail, "liste.txt")
    with open(liste, "w", encoding="utf-8") as f:
        for m in morceaux:
            f.write(f"file '{m}'\n")
    r = subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", liste, "-c:v", "libx264",
                        "-preset", "medium", "-crf", "21", "-pix_fmt", "yuv420p", "-r", "30", "-movflags", "+faststart", sortie],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print("  ffmpeg assemblage :", r.stderr[-800:])
        return False
    print(f"{sortie} : {duree(sortie):.1f} s, {os.path.getsize(sortie) / 1e6:.1f} Mo")
    return True


def main():
    dossier, sortie = sys.argv[1], sys.argv[2]
    parties = sys.argv[3:] or ["seance", "barriere"]
    travail = os.path.join(os.path.dirname(os.path.abspath(sortie)), "montage-" + os.path.splitext(os.path.basename(sortie))[0])
    os.makedirs(travail, exist_ok=True)
    morceaux = [carton("debut", travail, 6.0)] if len(parties) > 1 else []
    if "seance" in parties:
        morceaux += [sequence(dossier, n, travail) for n in ("video-seance-1", "video-seance-2")]
    if "barriere" in parties:
        if len(parties) > 1:
            morceaux.append(carton("barriere", travail, 5.0))
        morceaux += [sequence(dossier, n, travail) for n in ("video-barriere-1", "video-barriere-2", "video-barriere-3", "video-barriere-4")]
    if len(parties) > 1:
        morceaux.append(carton("fin", travail, 5.0))
    morceaux = [m for m in morceaux if m]
    assembler(morceaux, sortie, travail)


if __name__ == "__main__":
    main()
