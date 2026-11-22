#!/usr/bin/env python3
"""
Recette avant Google Play (22/11, PUBLICATION_PLAY_STORE.md § 2.1 et § 8).

Le parcours de captures.py suit des gestes, sur une edition debogable. Celui-ci passe
l'edition publiee (release, R8, -Pplay=true) ecran par ecran, sur la version d'Android de
l'emulateur (13 a 16), et regarde ce qu'aucun autre parcours ne regarde :

  - examinateur : le chemin de la note remise a Google (play/CONSOLE.md § 3.2), au mot pres,
    depuis une application neuve, en anglais : presentation, choix de la version, roue des
    reglages, apercu de l'ecran « Je suis avec Hachem », puis les deux acces accordes par les
    ecrans d'Android, une application choisie, l'ecran devant elle ;
  - video : les deux sequences demandees pour la declaration des services de premier plan
    (play/CONSOLE.md § 3.9), filmees sur l'emulateur ;
  - ecrans : chaque ecran, le haut puis le bas apres defilement, et le clavier la ou l'on
    ecrit, en francais (navigation par gestes), en hebreu (trois boutons), en arabe, en espagnol ;
  - versions : l'accueil de chacune des cinq versions de l'application ;
  - nuit, seance, barriere, presentation, tablette, redemarrage.

Chaque capture est controlee sur l'arbre de l'ecran :

  - SOUS-BARRE : un texte ou un bouton sous la barre d'etat ou la barre de navigation
    (Android 15 et 16 imposent l'affichage bord a bord) ;
  - SOUS-CLAVIER : le champ de saisie cache par le clavier ;
  - COLLE : un texte colle au bord de l'ecran ;
  - EXAMINATEUR : un libelle de la note introuvable a l'ecran ;
  - BARRIERE, SEANCE, SERVICE : le service ne tourne pas, ou l'ecran ne se pose pas.

Les fautes vont dans fautes.txt, a cote des captures. Comme captures.py, rien ne fait echouer
le job : on lit le bilan.

Variables : RECETTE_PASSES (les noms ci-dessus, separes par des virgules ; toutes par defaut).
"""
import datetime
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import captures as c  # noqa: E402

FAUTES = []


def faute(texte):
    FAUTES.append(texte)
    c.log("  FAUTE : " + texte)
    with open(os.path.join(c.OUT, "fautes.txt"), "a", encoding="utf-8") as f:
        f.write(texte + "\n")


# --- Barres du systeme ---------------------------------------------------------

def cadres():
    """Les cadres de la barre d'etat, de la barre de navigation et du clavier : (haut, bas, clavier).
    haut : bas de la barre d'etat ; bas : haut de la barre de navigation ; clavier : son haut ou None."""
    texte = c.sh("dumpsys window displays")
    haut, bas, clavier = 0, c.H, None
    # Android 14 et plus : « type=statusBars » ; Android 13 : « type=ITYPE_STATUS_BAR ».
    motif = r"type=(statusBars|navigationBars|ime|ITYPE_STATUS_BAR|ITYPE_NAVIGATION_BAR|ITYPE_IME)\s+frame=\[(\d+),(\d+)\]\[(\d+),(\d+)\]\s+visible=(true|false)"
    for m in re.finditer(motif, texte):
        genre, x1, y1, x2, y2, visible = m.group(1), *map(int, m.groups()[1:5]), m.group(6) == "true"
        if not visible or y2 <= y1:
            continue
        if genre in ("statusBars", "ITYPE_STATUS_BAR"):
            if y2 < c.H // 3:
                haut = max(haut, y2)
        elif genre in ("navigationBars", "ITYPE_NAVIGATION_BAR") and (x2 - x1) > (y2 - y1):  # en bas, pas sur le cote
            if y1 > c.H // 2:
                bas = min(bas, y1)
        elif genre in ("ime", "ITYPE_IME"):
            clavier = y1 if clavier is None else min(clavier, y1)
    return haut, bas, clavier


def controle(racine, nom, en_haut=True, en_bas=True):
    """Aucun texte ni bouton de l'application sous une barre du systeme, ni colle au bord."""
    if racine is None:
        return
    haut, bas, _ = cadres()
    for n in racine.iter("node"):
        if n.get("package") != c.PKG:
            continue
        b = c.bornes(n)
        if not b:
            continue
        texte = (n.get("text") or n.get("content-desc") or "").strip()
        touchable = n.get("clickable") == "true"
        classe = n.get("class", "").rsplit(".", 1)[-1]
        feuille = len(list(n)) == 0
        if not ((texte and feuille) or (touchable and feuille)):
            continue
        rid = n.get("resource-id", "").rsplit("/", 1)[-1]
        quoi = f"{classe} {rid} «{texte[:28]}» {b}"
        # Deux pixels de tolerance : les arrondis de densite.
        if en_haut and haut and b[1] < haut - 2 and b[3] > 0:
            faute(f"{nom} : SOUS-BARRE d'etat (barre jusqu'a {haut}) {quoi}")
        if en_bas and bas < c.H and b[3] > bas + 2 and b[1] < c.H:
            faute(f"{nom} : SOUS-BARRE de navigation (barre a partir de {bas}) {quoi}")
        if texte and feuille and "TextView" in n.get("class", "") and (b[0] <= 0 or b[2] >= c.W) and (b[2] - b[0]) < c.W:
            faute(f"{nom} : COLLE au bord {quoi}")


def prise(nom, attente=1.0, verifier=True, **kw):
    """Une capture, avec le controle des barres et l'audit d'accessibilite sur le meme arbre."""
    c.pause(attente)
    racine = None
    try:
        racine = c.fermer_anr(c.dump())
        if verifier:
            c.accessibilite(racine, nom)
            controle(racine, nom, **kw)
    except Exception as e:  # le controle ne doit jamais empecher la capture
        c.log("  controle:", repr(e))
    png = c.adb("exec-out", "screencap", "-p", binary=True)
    with open(os.path.join(c.OUT, nom + ".png"), "wb") as f:
        f.write(png)
    c.log(f"  capture {nom} ({len(png)} octets)")
    return racine


def photo(nom):
    """Une capture seule, sans lire l'arbre : pendant un film, ou sur un ecran du systeme."""
    png = c.adb("exec-out", "screencap", "-p", binary=True)
    with open(os.path.join(c.OUT, nom + ".png"), "wb") as f:
        f.write(png)
    c.log(f"  photo {nom} ({len(png)} octets)")


def au_bout(vers_le_bas=True, elans=7):
    x = c.W // 2
    for _ in range(elans):
        if vers_le_bas:
            c.sh(f"input swipe {x} {int(c.H * 0.80)} {x} {int(c.H * 0.22)} 70")
        else:
            c.sh(f"input swipe {x} {int(c.H * 0.22)} {x} {int(c.H * 0.80)} 70")
    c.pause(1.2)


def navigation(mode):
    """La barre de navigation : « gestes » (la languette) ou « boutons » (les trois boutons)."""
    cat = "com.android.internal.systemui.navbar." + ("gestural" if mode == "gestes" else "threebutton")
    c.sh(f"cmd overlay enable-exclusive --category {cat}")
    c.pause(3.0)
    c.log("  navigation :", mode, "| cadres :", cadres())


def devant():
    return c.sh("dumpsys activity activities | grep -E 'topResumedActivity|mResumedActivity' | head -2").strip()


def textes(racine=None):
    """Tout ce qui est ecrit a l'ecran (textes et descriptions), toutes applications confondues."""
    racine = racine if racine is not None else c.dump()
    if racine is None:
        return []
    return [t for n in racine.iter("node") for t in ((n.get("text") or "").strip(), (n.get("content-desc") or "").strip()) if t]


def mardi_matin():
    """Un mardi ordinaire a 9 h 30 : ni Chabbat ni fete, et dans la plage par defaut de la
    barriere (6 h - 11 h). L'horloge de la barre d'etat, en mode demo, affiche deja 9:30."""
    c.sh("settings put global auto_time 0")
    c.log("  date :", c.sh("date 111709302026.00").strip())
    c.pause(6.0)


def journal_de_demonstration():
    """Quelques jours faits avant aujourd'hui : une pratique en cours, pas un compteur a zero."""
    c.arreter()
    jour = c.sh("date +%Y-%m-%d").strip()
    try:
        auj = datetime.date.fromisoformat(jour)
    except ValueError:
        auj = datetime.date.today()
    jours = {(auj - datetime.timedelta(days=d)).isoformat(): {"minutes": m}
             for d, m in ((1, 20), (2, 15), (3, 30), (5, 15), (6, 20))}
    brut = json.dumps(jours).replace("&", "&amp;").replace('"', "&quot;").replace("<", "&lt;")
    xml = ("<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n<map>\n"
           f"    <string name=\"days\">{brut}</string>\n</map>\n")
    c.ecrire_prefs(xml, c.JOURNAL)


def fermer_trophees(libelles=("Continue", "Continuer", "להמשיך", "Continuar", "متابعة")):
    """Le journal de demonstration fait gagner des trophees : leurs fenetres s'ouvrent sur l'accueil."""
    for _ in range(10):
        racine = c.dump()
        cible = None
        if racine is not None:
            for n in racine.iter("node"):
                if n.get("package") == c.PKG and (n.get("text") or "").strip() in libelles and n.get("clickable") == "true" and c.bornes(n):
                    cible = c.bornes(n)
                    break
        if cible is None:
            return
        toucher_bornes(cible, attente=1.2)


# --- Films ---------------------------------------------------------------------

FILM = None


def film_debut(nom, limite=175):
    """Filme l'ecran (screenrecord, 3 min au plus). L'image seule : ni son, ni fenetres protegees."""
    global FILM
    c.sh("rm -f /sdcard/film.mp4")
    p = subprocess.Popen(["adb", "shell", "screenrecord", "--time-limit", str(limite), "--size", "720x1600",
                          "--bit-rate", "4000000", "/sdcard/film.mp4"])
    FILM = (nom, p)
    c.pause(1.5)


def film_fin():
    global FILM
    if FILM is None:
        return
    nom, p = FILM
    FILM = None
    # SIGINT : screenrecord ferme proprement son fichier.
    c.sh("kill -2 $(pidof screenrecord) 2>/dev/null")
    try:
        p.wait(timeout=25)
    except subprocess.TimeoutExpired:
        p.kill()
    c.pause(2.5)
    video = c.adb("exec-out", "cat", "/sdcard/film.mp4", binary=True, timeout=240)
    with open(os.path.join(c.OUT, nom + ".mp4"), "wb") as f:
        f.write(video)
    c.log(f"  film {nom}.mp4 ({len(video)} octets)")


# --- Les ecrans du systeme ou l'on accorde un acces ------------------------------

def accorder_dans_android(nom_app="MyHitbodedut", avant=None):
    """Dans l'ecran d'Android ouvert par l'application : trouver l'application dans la liste,
    l'ouvrir, basculer l'interrupteur, revenir. Rend True si un interrupteur a ete bascule."""
    c.pause(2.0)
    if avant:
        photo(avant + "-liste")
    # Depuis Android 11, l'ecran s'ouvre sur la liste de toutes les applications.
    ligne = c.trouver(text=nom_app, defilements=14)
    if ligne is not None:
        c.toucher(text=nom_app, attente=2.0)
    racine = c.dump()
    bascule = None
    if racine is not None:
        for n in racine.iter("node"):
            if n.get("checkable") == "true" and c.bornes(n):
                bascule = n
                break
    if avant:
        photo(avant + "-interrupteur")
    if bascule is None:
        c.log("  aucun interrupteur dans l'ecran d'Android :", textes(racine)[:12])
        c.retour(2)
        return False
    if bascule.get("checked") != "true":
        b = c.bornes(bascule)
        c.sh(f"input tap {(b[0] + b[2]) // 2} {(b[1] + b[3]) // 2}")
        c.pause(1.5)
    if avant:
        photo(avant + "-accorde")
    # Revenir a l'application : un retour par ecran d'Android traverse.
    for _ in range(4):
        if c.PKG in devant():
            break
        c.sh("input keyevent KEYCODE_BACK")
        c.pause(1.2)
    return True


def bouton_de_la_ligne(titre, rid_bouton="permission_grant"):
    """Le bouton d'une ligne d'autorisation, repere par le titre de la ligne (le plus proche dessous)."""
    racine = c.dump()
    if racine is None:
        return None
    cible = None
    boutons = []
    for n in racine.iter("node"):
        b = c.bornes(n)
        if not b:
            continue
        if (n.get("text") or "").strip() == titre and cible is None:
            cible = b
        if n.get("resource-id", "").endswith("/" + rid_bouton):
            boutons.append(b)
    if cible is None or not boutons:
        return None
    apres = [b for b in boutons if b[1] >= cible[1] - 10]
    return min(apres, key=lambda b: b[1]) if apres else None


def toucher_bornes(b, attente=1.5):
    c.sh(f"input tap {(b[0] + b[2]) // 2} {(b[1] + b[3]) // 2}")
    c.pause(attente)


def amener(rid=None, text=None, defilements=16):
    """Amene un element vers le milieu de l'ecran, pour qu'il se voie sur le film."""
    b = c.trouver(rid=rid, text=text, defilements=defilements)
    if b is None:
        return None
    milieu = (b[1] + b[3]) // 2
    if milieu > int(c.H * 0.70):
        x = c.W // 2
        c.sh(f"input swipe {x} {int(c.H * 0.70)} {x} {int(c.H * 0.42)} 500")
        c.pause(1.0)
        b = c.trouver(rid=rid, text=text) or b
    return b


def neuve():
    """L'application comme a sa premiere ouverture : donnees effacees, acces retires, langue du telephone."""
    c.sh(f"pm clear {c.PKG}")
    c.sh(f"cmd locale set-app-locales {c.PKG} --locales ''")
    for op in ("SYSTEM_ALERT_WINDOW", "GET_USAGE_STATS"):
        c.sh(f"appops set {c.PKG} {op} default")
    c.pause(1.5)


# --- Le chemin de l'examinateur --------------------------------------------------

def examinateur():
    """La note de play/CONSOLE.md § 3.2, au mot pres, sur une application neuve en anglais.
    Chaque libelle entre crochets dans la note est cherche a l'ecran ; s'il manque, c'est une faute."""
    etapes = []

    def voir(n, *libelles, racine=None):
        vus = textes(racine)
        for l in libelles:
            if not any(l == t or l in t for t in vus):
                faute(f"EXAMINATEUR etape {n} : « {l} » introuvable a l'ecran ({' | '.join(vus[:10])[:300]})")
        etapes.append(n)

    navigation("gestes")
    neuve()
    mardi_matin()
    c.sh(f"am start -W -n {c.PKG}/com.myhitbodedut.MainActivity", timeout=60)
    c.pause(6.0)
    # « On first launch a short welcome appears: tap [Skip]. »
    r = prise("exam-01-bienvenue")
    voir("1 (bienvenue)", "Skip", racine=r)
    c.toucher(text="Skip", attente=3.0)
    # Une demande de notifications peut arriver ici : on la capture telle quelle, puis on l'accepte.
    r = prise("exam-02-apres-bienvenue", verifier=False)
    for libelle in ("Allow", "ALLOW"):
        if c.trouver(text=libelle) is not None:
            c.toucher(text=libelle, attente=2.0)
            break
    # « On the next screen, [Choose your version], pick [Classic]. »
    r = prise("exam-03-choix-version")
    voir("2 (choix de la version)", "Choose your version", "Classic", racine=r)
    if not c.toucher(text="Classic", contains=True, attente=5.0):
        c.toucher(desc="Classic", contains=True, attente=5.0)
    fermer_trophees()
    r = prise("exam-04-today")
    voir("3 (accueil)", "Today", "Settings", racine=r)
    # « On the [Today] screen, tap the gear icon at the top (Settings). »
    c.toucher(desc="Settings", attente=2.5)
    r = prise("exam-05-settings")
    # « Card [Where “I am with Hashem” stands]: tap [Preview the “I am with Hashem” screen now]. »
    b = c.trouver(text="Preview the “I am with Hashem” screen now", defilements=16)
    r = prise("exam-06-carte-etat")
    voir("4 (carte d'etat)", "Where “I am with Hashem” stands", "Preview the “I am with Hashem” screen now", racine=r)
    c.toucher(text="Preview the “I am with Hashem” screen now", attente=2.5)
    # « The first time, a dialog titled [Display over other apps] explains the access. Tap [Continue]… »
    r = prise("exam-07-divulgation-affichage", verifier=False)
    voir("5 (divulgation)", "Display over other apps", "Continue", racine=r)
    c.toucher(text="Continue", attente=2.5)
    ok = accorder_dans_android(avant="exam-08-android-affichage")
    if not ok:
        faute("EXAMINATEUR etape 6 : l'ecran d'Android « Display over other apps » n'offre pas d'interrupteur pour MyHitbodedut")
    r = prise("exam-09-retour-reglages")
    if c.PKG not in devant():
        faute(f"EXAMINATEUR etape 6 : apres l'accord, on ne revient pas dans l'application ({devant()[:160]})")
    # « …go back, and tap the button again. »
    if c.trouver(text="PREVIEW, NO EFFECT") is None:
        c.trouver(text="Preview the “I am with Hashem” screen now", defilements=16)
        c.toucher(text="Preview the “I am with Hashem” screen now", attente=3.5)
    # « The gate appears over the home screen with the badge [PREVIEW, NO EFFECT]. [Close the preview] dismisses it. »
    r = prise("exam-10-apercu")
    voir("7 (apercu)", "PREVIEW, NO EFFECT", "Did you do your hitbodedut?", racine=r)
    au_bout(True, 2)
    r = prise("exam-11-apercu-bas")
    voir("7 (apercu, bas)", "Close the preview", racine=r)
    c.toucher(text="Close the preview", attente=2.5)
    if c.trouver(text="PREVIEW, NO EFFECT") is not None:
        faute("EXAMINATEUR etape 7 : [Close the preview] ne ferme pas l'apercu")
    prise("exam-12-apres-apercu", verifier=False)

    # --- « To see it act for real » ---
    c.lancer(attente=4)
    fermer_trophees()
    c.toucher(desc="Settings", attente=2.5)
    # « card [Permissions]: tap [Grant] for [Display over other apps] and for [Usage access]. »
    c.trouver(text="Usage access", defilements=18)
    r = prise("exam-13-carte-autorisations")
    voir("8 (autorisations)", "Permissions", "Usage access", "Grant", racine=r)
    b = bouton_de_la_ligne("Usage access")
    if b is None:
        faute("EXAMINATEUR etape 8 : pas de bouton [Grant] sur la ligne [Usage access]")
    else:
        toucher_bornes(b, attente=2.5)
        r = prise("exam-14-divulgation-usage", verifier=False)
        voir("9 (divulgation de l'acces a l'utilisation)", "Usage access", "Continue", racine=r)
        c.toucher(text="Continue", attente=2.5)
        if not accorder_dans_android(avant="exam-15-android-usage"):
            faute("EXAMINATEUR etape 9 : l'ecran d'Android « Usage access » n'offre pas d'interrupteur pour MyHitbodedut")
    r = prise("exam-16-autorisations-accordees")
    # « Card [I am with Hashem]: turn the switch on, tap [Choose apps] and pick one app… »
    c.trouver(rid="enable_switch", defilements=18)
    c.trouver(text="Choose apps", defilements=4)
    r = prise("exam-17-carte-mode")
    voir("10 (carte du mode)", "I am with Hashem", "Choose apps", "“I am with Hashem” hours", racine=r)
    c.toucher(rid="enable_switch", attente=1.5)
    c.toucher(text="Choose apps", attente=4.0)
    r = prise("exam-18-liste-applications")
    choisie, paquet = None, None
    for libelle, p in (("YouTube", "com.google.android.youtube"), ("Chrome", "com.android.chrome"),
                       ("Messages", "com.google.android.apps.messaging"), ("Photos", "com.google.android.apps.photos"),
                       ("Maps", "com.google.android.apps.maps"), ("Gmail", "com.google.android.gm"),
                       ("Calendar", "com.google.android.calendar"), ("Camera", "com.android.camera2")):
        if c.trouver(text=libelle, defilements=6) is not None:
            c.toucher(text=libelle, attente=1.2)
            choisie, paquet = libelle, p
            break
        au_bout(False, 3)
    if choisie is None:
        faute("EXAMINATEUR etape 10 : aucune application connue dans la liste [Choose apps]")
    # Les applications protegees ne doivent pas etre proposees.
    visibles_liste = textes()
    for interdit in ("Settings", "Phone"):
        if interdit in visibles_liste:
            faute(f"EXAMINATEUR etape 10 : « {interdit} » est propose dans la liste des applications a retenir")
    prise("exam-19-application-choisie")
    c.retour()
    c.pause(1.5)
    # « …and set [“I am with Hashem” hours] around the current time. » L'horloge est a 9 h 30, dans la plage par defaut.
    c.trouver(rid="window_start", defilements=6)
    r = prise("exam-20-plage")
    c.trouver(text="Where “I am with Hashem” stands", defilements=10) or au_bout(False, 4)
    r = prise("exam-21-etat-arme")
    if not any("is on" in t for t in textes(r)):
        faute("EXAMINATEUR etape 11 : la carte d'etat ne dit pas « “I am with Hashem” is on » une fois tout regle (" + " | ".join(textes(r)[:8])[:240] + ")")
    c.log("  services :", services_app()[:300])
    if "GateService" not in services_app():
        faute("EXAMINATEUR etape 11 : GateService ne tourne pas une fois tout regle")
    # « Open the app you picked: the gate appears in front of it. »
    if paquet:
        c.sh("input keyevent KEYCODE_HOME")
        c.pause(1.5)
        c.sh(f"monkey -p {paquet} -c android.intent.category.LAUNCHER 1")
        c.pause(7.0)
        r = prise("exam-22-barriere-reelle")
        voir("12 (barriere)", "Did you do your hitbodedut?", "Done without the phone", racine=r)
        if c.trouver(text="PREVIEW, NO EFFECT") is not None:
            faute("EXAMINATEUR etape 12 : la vraie barriere porte le badge de l'apercu")
        au_bout(True, 2)
        prise("exam-23-barriere-reelle-bas")
        c.toucher(text="Done without the phone", defilements=2, attente=3.0)
        r = prise("exam-24-apres-fait", verifier=False)
        if c.trouver(text="Did you do your hitbodedut?") is not None:
            faute("EXAMINATEUR etape 12 : [Done without the phone] ne retire pas l'ecran")
    # « …can switch off at any time (Settings, [I am with Hashem] switch). »
    c.lancer(attente=4)
    fermer_trophees()
    c.toucher(desc="Settings", attente=2.5)
    c.trouver(rid="enable_switch", defilements=18)
    c.toucher(rid="enable_switch", attente=1.5)
    prise("exam-25-mode-coupe")
    c.pause(2.0)
    if "GateService" in services_app():
        faute("EXAMINATEUR etape 13 : GateService tourne encore apres l'interrupteur coupe")
    c.log("  etapes de l'examinateur passees :", etapes)


# --- Les deux films de la declaration des services --------------------------------

def preparer_film():
    """En anglais, version Classique, presentation passee, un peu de journal, notifications accordees."""
    neuve()
    mardi_matin()
    c.sh(f"pm grant {c.PKG} android.permission.POST_NOTIFICATIONS")
    c.regler({"onboarded_version": ("int", 2), "langue_app": ("string", "en"), "version_app": ("string", "classique"),
              "lieu_nom": ("string", "New York"), "lieu_latitude": ("string", "40.71427"),
              "lieu_longitude": ("string", "-74.00597"), "lieu_altitude": ("string", "0.0"),
              "lieu_fuseau": ("string", "America/New_York"), "lieu_ville": ("long", 5128581),
              "lieu_t": ("long", 1794800000000), "in_israel": ("boolean", "false")})
    journal_de_demonstration()
    c.langue("en")
    c.sh("settings put system show_touches 1")
    c.lancer(attente=6)
    fermer_trophees()
    c.arreter()


def video_seance():
    """Sequence 1 : une hitbodedout lancee avec un morceau, l'ecran eteint puis rallume, la notification."""
    navigation("gestes")
    preparer_film()
    c.lancer(attente=5)
    film_debut("video-seance-1")
    c.pause(2.5)
    # Le volet de depart : la duree, le sujet, la musique.
    c.toucher(rid="depart_regler", attente=2.0)
    c.toucher(rid="music_button", attente=2.5)
    # « Play during the hitbodedut », puis un morceau.
    r = c.dump()
    bascule = None
    if r is not None:
        for n in r.iter("node"):
            if n.get("resource-id", "").endswith("/music_switch"):
                bascule = n
    if bascule is not None and bascule.get("checked") != "true":
        c.toucher(rid="music_switch", attente=1.5)
    c.toucher(rid="track_title", index=1, attente=2.0)
    c.pause(1.0)
    c.retour()
    c.pause(1.5)
    if c.trouver(rid="start_session") is None:
        c.toucher(rid="depart_regler", attente=1.0)
    c.toucher(rid="start_session", attente=5.0)
    c.pause(5.0)
    services = c.sh(f"dumpsys activity services {c.PKG} | grep -E 'ServiceRecord|isForeground|foregroundServiceType|types=' | head -8")
    c.log("  services :", services.strip().replace("\n", " | ")[:700])
    if "SessionService" not in services:
        faute("VIDEO seance : le service de seance ne tourne pas")
    film_fin()
    photo("video-seance-a-en-cours")
    # L'ecran s'eteint : le telephone est pose. Une demi-minute, pour que le decompte ait avance.
    c.sh("input keyevent KEYCODE_SLEEP")
    c.pause(30.0)
    c.sh("input keyevent KEYCODE_WAKEUP")
    film_debut("video-seance-2")
    c.pause(3.5)
    photo("video-seance-b-rallume")
    c.sh("wm dismiss-keyguard")
    c.pause(3.5)
    c.sh("cmd statusbar expand-notifications")
    c.pause(5.0)
    photo("video-seance-c-notification")
    c.sh("cmd statusbar collapse")
    c.pause(2.5)
    # La seance tourne toujours : on reveille son ecran, le decompte a avance.
    c.sh(f"input tap {c.W // 2} {int(c.H * 0.14)}")
    c.pause(4.0)
    photo("video-seance-d-toujours-en-cours")
    film_fin()
    # Hors film : le bravo et sa page de carnet sont proteges des captures (FLAG_SECURE).
    services = c.sh(f"dumpsys activity services {c.PKG} | grep -E 'ServiceRecord|isForeground|foregroundServiceType|types=' | head -8")
    if "SessionService" not in services:
        faute("VIDEO seance : le service de seance ne tourne plus apres l'ecran eteint")
    if c.toucher(rid="session_secondary", defilements=2, attente=1.5):
        c.toucher(rid="button1", attente=4.0)
    c.retour(2)
    c.arreter()


def video_barriere():
    """Sequence 2 : les deux acces accordes apres leur divulgation, une application choisie, l'ecran
    devant elle, « Done without the phone », puis l'interrupteur qui coupe le mode."""
    navigation("gestes")
    preparer_film()
    c.lancer(attente=5)
    film_debut("video-barriere-1")
    c.pause(2.0)
    c.toucher(desc="Settings", attente=2.5)
    for titre, nom in (("Display over other apps", "affichage"), ("Usage access", "usage")):
        amener(text=titre, defilements=18)
        b = bouton_de_la_ligne(titre)
        if b is None:
            faute(f"VIDEO barriere : pas de bouton [Grant] pour [{titre}]")
            continue
        toucher_bornes(b, attente=3.5)   # la divulgation dans l'application
        c.pause(2.5)
        c.toucher(text="Continue", attente=2.5)
        accorder_dans_android()
        c.pause(1.5)
    film_fin()
    film_debut("video-barriere-2")
    amener(rid="enable_switch", defilements=18)
    c.toucher(rid="enable_switch", attente=2.0)
    c.toucher(text="Choose apps", defilements=4, attente=4.0)
    paquet = None
    for libelle, p in (("YouTube", "com.google.android.youtube"), ("Chrome", "com.android.chrome"),
                       ("Messages", "com.google.android.apps.messaging"), ("Photos", "com.google.android.apps.photos")):
        if c.trouver(text=libelle, defilements=6) is not None:
            c.toucher(text=libelle, attente=2.0)
            paquet = p
            break
        au_bout(False, 3)
    c.retour()
    c.pause(2.0)
    amener(rid="window_start", defilements=6)
    c.pause(2.5)
    if paquet:
        c.sh("input keyevent KEYCODE_HOME")
        c.pause(1.5)
        c.sh(f"monkey -p {paquet} -c android.intent.category.LAUNCHER 1")
        c.pause(8.0)
        if c.trouver(text="Did you do your hitbodedut?") is None:
            faute(f"VIDEO barriere : l'ecran ne se pose pas sur {paquet}")
        photo("video-barriere-a-ecran")
        c.pause(2.0)
        c.toucher(text="Done without the phone", defilements=2, attente=3.5)
        photo("video-barriere-b-apres")
    c.lancer(attente=4)
    fermer_trophees()
    c.toucher(desc="Settings", attente=2.5)
    amener(rid="enable_switch", defilements=18)
    c.toucher(rid="enable_switch", attente=2.5)
    c.pause(1.5)
    photo("video-barriere-c-coupe")
    film_fin()
    c.sh("settings put system show_touches 0")
    c.arreter()


# --- Les ecrans ----------------------------------------------------------------

# nom, classe, extras, saisie a essayer.
ECRANS = [
    ("reglages", "SettingsActivity", "", False),
    ("choix-version", "ChoixVersionActivity", "", False),
    ("seance", "SessionActivity", "", False),
    ("bravo", "CelebrationActivity", "--ei minutes 20", False),
    ("journal", "JournalActivity", "", False),
    ("parcours", "ParcoursActivity", "", False),
    ("hizouk", "ChizukActivity", "", False),
    ("conseils", "TipsActivity", "", False),
    ("rappels", "RemindersActivity", "", False),
    ("musique", "MusicActivity", "", False),
    ("siddour", "SiddurActivity", "", False),
    ("siddour-lecture", "SiddurLectureActivity", "--es id chaharit", False),
    ("tefilot", "TefilotActivity", "", False),
    ("tehilim", "TehilimActivity", "", False),
    ("tehilim-lecture", "TehilimLectureActivity", "--ei debut 1 --ei fin 1", False),
    ("tikkun", "TikkunFlowActivity", "", False),
    ("bibliotheque", "LibraryActivity", "", False),
    ("livres", "LibraryActivity", "--ez livres true", False),
    ("source", "LibraryEntryActivity", "--es entry_id src-lm2-25", False),
    ("zmanim", "ZmanimActivity", "", False),
    ("vol", "VolActivity", "", True),
    ("boussole", "BoussoleActivity", "", False),
    ("calendrier", "CalendrierActivity", "", False),
    ("halakha", "HalakhaActivity", "", False),
    ("hilloulot", "HilloulotActivity", "", True),
    ("recherche", "RechercheActivity", "", True),
    ("paliers", "PaliersActivity", "", False),
    ("applications", "AppPickerActivity", "", False),
]


def clavier(nom):
    """Touche le premier champ de saisie : il doit rester au-dessus du clavier."""
    racine = c.dump()
    if racine is None:
        return
    champs = [n for n in racine.iter("node") if n.get("package") == c.PKG and n.get("class", "").endswith("EditText") and c.bornes(n)]
    if not champs:
        return
    b = c.bornes(champs[0])
    c.sh(f"input tap {(b[0] + b[2]) // 2} {(b[1] + b[3]) // 2}")
    c.pause(2.5)
    racine = prise(nom + "-clavier", attente=0.5, en_bas=False)
    _, _, haut_clavier = cadres()
    if racine is not None and haut_clavier:
        for n in racine.iter("node"):
            if n.get("package") == c.PKG and n.get("focused") == "true" and c.bornes(n):
                fb = c.bornes(n)
                if fb[3] > haut_clavier + 2:
                    faute(f"{nom} : SOUS-CLAVIER (clavier a partir de {haut_clavier}) champ {fb}")
    c.sh("input keyevent KEYCODE_BACK")
    c.pause(0.8)


def passe(prefixe, ecrans=ECRANS, bas=True, saisie=True):
    """L'accueil et ses trois lieux, puis tous les ecrans : le haut, le bas, le clavier."""
    c.lancer(attente=5)
    fermer_trophees()
    prise(f"{prefixe}-accueil")
    if bas:
        au_bout(True)
        prise(f"{prefixe}-accueil-bas")
        au_bout(False)
    # Le volet de depart : la duree, le sujet, la musique, la barriere.
    if c.toucher(rid="depart_regler", attente=1.5):
        prise(f"{prefixe}-accueil-volet")
        c.toucher(rid="depart_regler", attente=1.0)
    if c.toucher(rid="nav_texts", attente=1.5):
        prise(f"{prefixe}-livres")
        if bas:
            au_bout(True)
            prise(f"{prefixe}-livres-bas")
    if c.toucher(rid="nav_journal", attente=1.5):
        prise(f"{prefixe}-chemin")
        if bas:
            au_bout(True)
            prise(f"{prefixe}-chemin-bas")
    for nom, classe, extras, champ in ecrans:
        c.arreter()
        if not c.activite(classe, extras):
            continue
        if classe not in devant():
            c.log(f"  {classe} : pas au premier plan ({devant()[:160]})")
        prise(f"{prefixe}-{nom}")
        if champ and saisie:
            clavier(f"{prefixe}-{nom}")
        if bas:
            au_bout(True)
            prise(f"{prefixe}-{nom}-bas")


def parler(etiquette):
    """La langue de l'application : la preference et la langue par application d'Android."""
    c.regler({"langue_app": ("string", etiquette)})
    c.langue(etiquette)


def versions(prefixe, bas=True):
    """L'accueil de chaque version de l'application (VersionApp)."""
    for version in ("pile", "bento", "instant", "serenite"):
        c.regler({"version_app": ("string", version)})
        c.lancer(attente=6)
        fermer_trophees()
        prise(f"{prefixe}-version-{version}")
        if version == "pile":
            for i in range(2, 5):
                c.sh(f"input swipe {int(c.W * 0.88)} {int(c.H * 0.45)} {int(c.W * 0.08)} {int(c.H * 0.45)} 450")
                prise(f"{prefixe}-version-pile-{i}", attente=1.5)
        elif bas:
            au_bout(True, 4)
            prise(f"{prefixe}-version-{version}-bas")
    c.regler({"version_app": ("string", "classique")})


def presentation(prefixe, etiquette):
    parler(etiquette)
    c.regler({"onboarded_version": ("int", 0)})
    c.sh(f"am start -W -n {c.PKG}/com.myhitbodedut.MainActivity", timeout=60)
    c.pause(4.0)
    for i in range(1, 11):
        racine = prise(f"{prefixe}-presentation-{i}", attente=0.4)
        voulus = {"onboarding_title", "onboarding_body", "onboarding_next"}
        vus = c.visibles(racine, voulus)
        if "onboarding_title" not in vus and "onboarding_next" not in vus:
            break  # la presentation est finie
        manque = sorted(voulus - vus)
        if manque:
            faute(f"{prefixe} presentation {i} : {', '.join(manque)} hors de l'ecran")
        if not c.toucher(rid="onboarding_next", attente=1.2):
            break
    c.regler({"onboarded_version": ("int", 2)})


def services_app():
    return c.sh(f"dumpsys activity services {c.PKG} | grep -E 'ServiceRecord' | head -5").strip().replace("\n", " | ")


def seance_en_cours(prefixe):
    """La seance qui tourne : l'ecran, la notification du service de premier plan, l'ecran calme."""
    c.arreter()
    ok = c.activite("SessionActivity", "--ez start_now true")
    prise(f"{prefixe}-seance-en-cours", attente=2.0)
    services = c.sh(f"dumpsys activity services {c.PKG} | grep -E 'ServiceRecord|isForeground|foregroundServiceType' | head -8")
    c.log("  services :", services.strip().replace("\n", " | ")[:600])
    if "SessionService" not in services:
        faute(f"{prefixe} : SEANCE le service de seance ne tourne pas")
    c.sh("cmd statusbar expand-notifications")
    c.pause(2.0)
    photo(f"{prefixe}-seance-notification")
    c.sh("cmd statusbar collapse")
    c.pause(1.0)
    prise(f"{prefixe}-seance-calme", attente=7.5)
    c.sh(f"input tap {c.W // 2} {int(c.H * 0.14)}")
    c.pause(1.0)
    if ok and c.toucher(rid="session_secondary", defilements=2, attente=1.0):
        prise(f"{prefixe}-seance-terminer-dialogue", attente=0.5, verifier=False)
        c.toucher(rid="button1", attente=2.0)
    prise(f"{prefixe}-seance-apres", attente=1.5)
    c.retour(2)


def armer():
    """Le mode allume, deux ou trois applications choisies, les deux acces accordes, la plage autour de maintenant."""
    presentes = [l.split(":", 1)[1].strip() for l in c.sh("pm list packages").splitlines() if ":" in l]
    voulues = [a for a in ("com.android.chrome", "com.google.android.youtube", "com.google.android.apps.messaging",
                           "com.google.android.gm", "com.google.android.apps.photos", "com.google.android.apps.maps",
                           "com.android.messaging", "com.android.camera2", "com.android.contacts", "com.android.calendar",
                           "com.google.android.calendar", "com.google.android.contacts", "com.google.android.deskclock")
               if a in presentes][:3] or ["com.android.settings"]
    c.log("  applications bloquees :", voulues)
    maintenant = c.sh("date +%H:%M").strip()
    m = re.match(r"(\d+):(\d+)", maintenant)
    minutes = int(m.group(1)) * 60 + int(m.group(2)) if m else 600
    c.regler({"enabled": ("boolean", "true"), "window_start": ("int", max(0, minutes - 30)),
              "window_end": ("int", min(1439, minutes + 120)), "snooze_minutes": ("int", 15),
              "snoozed_until": ("long", 0)})
    xml = re.sub(r'\s*<set name="blocked_apps">.*?</set>|\s*<set name="blocked_apps"\s*/>', "", c.lire_prefs(), flags=re.S)
    ensemble = '    <set name="blocked_apps">' + "".join(f"<string>{a}</string>" for a in voulues) + "</set>"
    c.ecrire_prefs(xml.replace("</map>", ensemble + "\n</map>"))
    for op in ("SYSTEM_ALERT_WINDOW", "GET_USAGE_STATS"):
        c.sh(f"appops set {c.PKG} {op} allow")
    return voulues


def barriere(prefixe):
    """Je suis avec Hachem : l'apercu depuis les reglages, puis pour de vrai sur une application choisie."""
    voulues = armer()
    c.arreter()
    ok = c.activite("SettingsActivity")
    ok = ok and c.trouver(rid="preview_gate", defilements=16) is not None
    prise(f"{prefixe}-barriere-etat")
    ok = ok and c.toucher(rid="preview_gate", attente=3.0)
    if ok and c.trouver(rid="blocker_title") is None:
        # La divulgation d'abord, si l'acces n'etait pas vu comme accorde.
        prise(f"{prefixe}-barriere-divulgation", verifier=False)
        c.toucher(rid="button1", attente=2.0)
    vu = c.trouver(rid="blocker_title") is not None
    prise(f"{prefixe}-barriere-apercu")
    if not vu:
        faute(f"{prefixe} : BARRIERE l'apercu de l'ecran de garde ne s'affiche pas")
    else:
        au_bout(True, 3)
        prise(f"{prefixe}-barriere-apercu-bas")
        c.toucher(rid="blocker_primary", defilements=2, attente=1.5)
    c.retour()
    c.arreter()
    # Pour de vrai.
    c.lancer()
    fermer_trophees()
    c.log("  services :", services_app()[:400])
    if "GateService" not in services_app():
        faute(f"{prefixe} : BARRIERE GateService ne tourne pas apres l'ouverture de l'accueil")
    c.sh("input keyevent KEYCODE_HOME")
    c.pause(1.5)
    c.sh(f"monkey -p {voulues[0]} -c android.intent.category.LAUNCHER 1")
    c.pause(7.0)
    vu = c.trouver(rid="blocker_title") is not None
    prise(f"{prefixe}-barriere-reelle", attente=0.5)
    if not vu:
        faute(f"{prefixe} : BARRIERE l'ecran de garde ne se pose pas sur {voulues[0]}")
    else:
        au_bout(True, 3)
        prise(f"{prefixe}-barriere-reelle-bas")
        # Le retour ne doit pas la contourner.
        c.sh("input keyevent KEYCODE_BACK")
        c.pause(1.5)
        if c.trouver(rid="blocker_title") is None:
            faute(f"{prefixe} : BARRIERE la touche retour ferme l'ecran de garde")
        # « Plus tard » : l'application choisie revient.
        if c.toucher(rid="blocker_snooze", defilements=2, attente=2.5):
            prise(f"{prefixe}-barriere-reportee", attente=0.5, verifier=False)
            if c.trouver(rid="blocker_title") is not None:
                faute(f"{prefixe} : BARRIERE le report ne retire pas l'ecran de garde")
    # Les applications protegees : l'ecran ne se pose ni sur les reglages d'Android ni sur le telephone.
    c.regler({"snoozed_until": ("long", 0)})
    xml = re.sub(r'\s*<set name="blocked_apps">.*?</set>', "", c.lire_prefs(), flags=re.S)
    protegees = ["com.android.settings", "com.google.android.dialer", "com.android.dialer"]
    ensemble = '    <set name="blocked_apps">' + "".join(f"<string>{a}</string>" for a in voulues + protegees) + "</set>"
    c.ecrire_prefs(xml.replace("</map>", ensemble + "\n</map>"))
    c.lancer()
    fermer_trophees()
    c.sh("input keyevent KEYCODE_HOME")
    c.pause(1.5)
    c.sh("am start -a android.settings.SETTINGS")
    c.pause(6.0)
    if c.trouver(rid="blocker_title") is not None:
        faute(f"{prefixe} : BARRIERE l'ecran de garde se pose sur les reglages d'Android")
    prise(f"{prefixe}-barriere-reglages-android", attente=0.5, verifier=False)
    c.sh("am start -a android.intent.action.DIAL")
    c.pause(6.0)
    if c.trouver(rid="blocker_title") is not None:
        faute(f"{prefixe} : BARRIERE l'ecran de garde se pose sur le telephone")
    prise(f"{prefixe}-barriere-telephone", attente=0.5, verifier=False)
    c.sh("input keyevent KEYCODE_HOME")
    c.arreter()
    c.regler({"enabled": ("boolean", "false")})


def redemarrage(prefixe):
    """Un vrai redemarrage de l'emulateur, mode arme : le service repart-il seul, et retient-il encore ?
    A lancer en dernier : l'emulateur met une a deux minutes a revenir."""
    voulues = armer()
    c.lancer()
    fermer_trophees()
    c.sh("input keyevent KEYCODE_HOME")
    c.pause(2.0)
    c.log("  avant :", services_app()[:300])
    c.adb("reboot")
    c.pause(25)
    c.adb("wait-for-device", timeout=420)
    for _ in range(150):
        if c.sh("getprop sys.boot_completed").strip() == "1":
            break
        c.pause(2)
    c.pause(45)  # BOOT_COMPLETED arrive aux applications apres l'ecran d'accueil
    c.adb("root")
    c.pause(4)
    c.adb("wait-for-device", timeout=120)
    c.sh("input keyevent KEYCODE_WAKEUP")
    c.sh("wm dismiss-keyguard")
    c.sh("settings put global hide_error_dialogs 1")
    refus = c.sh("logcat -d | grep -E 'ForegroundServiceStartNotAllowed|BackgroundServiceStartNotAllowed|MissingForegroundServiceType|ForegroundServiceTypeException|InvalidForegroundServiceType' | grep -i myhitbodedut | head -5").strip()
    services = services_app()
    c.log("  apres :", services[:300], "| refus :", refus[:500])
    # La plage a pu passer pendant le redemarrage si l'horloge est revenue a l'heure du runner.
    etat = c.sh("date '+%F %H:%M %u'").strip()
    c.log("  horloge :", etat)
    if "GateService" not in services:
        faute(f"{prefixe} : BARRIERE GateService ne repart pas apres un redemarrage ({refus[:300]}) [horloge {etat}]")
    if refus:
        faute(f"{prefixe} : SERVICE refus d'Android au demarrage : {refus[:400]}")
    c.sh(f"monkey -p {voulues[0]} -c android.intent.category.LAUNCHER 1")
    c.pause(9.0)
    vu = c.trouver(rid="blocker_title") is not None
    prise(f"{prefixe}-barriere-apres-redemarrage", attente=0.5)
    if not vu:
        faute(f"{prefixe} : BARRIERE apres un redemarrage, l'ecran de garde ne se pose pas sur {voulues[0]} [horloge {etat}]")
    c.sh("input keyevent KEYCODE_HOME")
    c.arreter()
    c.regler({"enabled": ("boolean", "false")})


def tablette(prefixe):
    """Grand ecran (800 dp de large) : debout puis couche, et un pliant ouvert. Android 16 n'y
    respecte plus aucun verrou d'orientation."""
    for nom, taille, densite, couche in (("tablette", "1600x2560", 320, False), ("tablette-couchee", "1600x2560", 320, True),
                                         ("pliant", "1812x2176", 420, False)):
        c.appliquer_taille(taille, densite, couche)
        passe(f"{prefixe}-{nom}", bas=False, saisie=False)
        versions(f"{prefixe}-{nom}", bas=False)
    c.appliquer_taille(None, None, False)


def lieu(nom, lat, lon, fuseau, ville, israel="false"):
    c.regler({"lieu_nom": ("string", nom), "lieu_latitude": ("string", lat), "lieu_longitude": ("string", lon),
              "lieu_altitude": ("string", "0.0"), "lieu_fuseau": ("string", fuseau), "lieu_ville": ("long", ville),
              "lieu_t": ("long", 1794800000000), "in_israel": ("boolean", israel)})


def main():
    c.racine_adb()
    toutes = ["examinateur", "video", "ecrans-fr", "ecrans-he", "ecrans-ar", "ecrans-es", "versions", "nuit", "seance",
              "barriere", "presentation", "tablette", "ciel-de-nuit", "redemarrage"]
    passes = [p.strip() for p in os.environ.get("RECETTE_PASSES", "").split(",") if p.strip()] or toutes
    c.log("passes :", passes, "| Android", c.sh("getprop ro.build.version.release").strip(),
          "API", c.sh("getprop ro.build.version.sdk").strip())

    # D'abord ce qui part d'une application neuve.
    if "examinateur" in passes:
        c.etape("examinateur", examinateur)
    if "video" in passes:
        c.etape("video seance", video_seance)
        c.etape("video barriere", video_barriere)

    # Puis l'etat de depart commun : presentation passee, version Classique, un lieu, un peu de journal.
    neuve()
    mardi_matin()
    c.initialiser("fr")
    lieu("Paris", "48.85341", "2.3488", "Europe/Paris", 2988507)
    journal_de_demonstration()

    def p_fr():
        navigation("gestes")
        parler("fr")
        passe("fr-gestes")

    def p_he():
        navigation("boutons")
        parler("he")
        passe("he-boutons")
        versions("he-boutons", bas=False)
        parler("fr")
        navigation("gestes")

    def p_ar():
        navigation("gestes")
        parler("ar-TN")
        passe("ar-gestes")
        versions("ar-gestes", bas=False)
        parler("fr")

    def p_es():
        navigation("gestes")
        parler("es")
        passe("es-gestes", saisie=False)
        versions("es-gestes", bas=False)
        parler("fr")

    def p_versions():
        navigation("gestes")
        parler("fr")
        versions("fr-gestes")
        navigation("boutons")
        versions("fr-boutons", bas=False)
        navigation("gestes")

    def p_nuit():
        navigation("gestes")
        c.regler({"apparence_mode": ("string", "sombre")})
        passe("nuit", bas=False, saisie=False)
        versions("nuit", bas=False)
        c.regler({"apparence_mode": ("string", "auto")})

    def p_seance():
        navigation("gestes")
        seance_en_cours("gestes")
        navigation("boutons")
        seance_en_cours("boutons")
        navigation("gestes")

    def p_barriere():
        navigation("gestes")
        barriere("gestes")
        navigation("boutons")
        barriere("boutons")
        navigation("gestes")

    def p_presentation():
        navigation("gestes")
        for code in ("fr", "en", "he", "es", "ar-TN"):
            presentation(code.split("-")[0], code)
        parler("fr")

    def p_tablette():
        navigation("gestes")
        tablette("fr")

    def p_ciel():
        # Le soir : les accueils au ciel dessine (Instant, Serenite). L'emulateur s'y est
        # arrete deux fois le 17/11 : en dernier, pour ne rien perdre d'autre.
        c.log("  date :", c.sh("date 111721302026.00").strip())
        c.pause(5)
        versions("soir", bas=False)
        c.lancer(attente=5)
        prise("soir-accueil")
        mardi_matin()

    def p_redemarrage():
        redemarrage("gestes")

    table = {"ecrans-fr": p_fr, "ecrans-he": p_he, "ecrans-ar": p_ar, "ecrans-es": p_es, "versions": p_versions,
             "nuit": p_nuit, "seance": p_seance, "barriere": p_barriere, "presentation": p_presentation,
             "tablette": p_tablette, "ciel-de-nuit": p_ciel, "redemarrage": p_redemarrage}
    for nom in passes:
        if nom in table:
            c.etape(nom, table[nom])
    c.log("\n=== bilan de la recette ===")
    c.log("\n".join(FAUTES) if FAUTES else "aucune faute relevee par les controles automatiques")
    c.log("\ncaptures :", len(os.listdir(c.OUT)))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        c.log("ERREUR generale :", repr(e))
    sys.exit(0)
