#!/usr/bin/env python3
"""
Recette visuelle avant Google Play (14/11, PUBLICATION_PLAY_STORE.md § 2.1 et § 8).

Le parcours de captures.py suit des gestes ; celui-ci passe chaque ecran de
l'application, un par un, sur la version d'Android de l'emulateur (13 a 16),
et regarde ce qu'Android 15 et 16 ont change : l'affichage bord a bord impose.
Pour chaque ecran : le haut, puis le bas apres defilement, et le clavier la ou
l'on ecrit. Chaque capture est aussi controlee par l'arbre de l'ecran :

  - SOUS-BARRE : un texte ou un bouton de l'application sous la barre d'etat
    ou sous la barre de navigation ;
  - SOUS-CLAVIER : le champ de saisie cache par le clavier ;
  - COLLE : un texte colle au bord de l'ecran ;
  - BARRIERE : l'ecran de garde ne s'est pas pose sur l'application choisie.

Les fautes vont dans fautes.txt, a cote des captures. Comme captures.py, rien
ne fait echouer le job : on lit le bilan.

Variables : RECETTE_PASSES (« fr-gestes,he-boutons,nuit,seance,barriere,presentation,tablette,redemarrage » ; toutes par defaut).
"""
import os
import re
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
            haut = max(haut, y2)
        elif genre in ("navigationBars", "ITYPE_NAVIGATION_BAR") and (x2 - x1) > (y2 - y1):  # en bas, pas sur le cote
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


def prise(nom, attente=1.0, **kw):
    """Une capture, avec le controle des barres et l'audit d'accessibilite sur le meme arbre."""
    c.pause(attente)
    racine = None
    try:
        racine = c.fermer_anr(c.dump())
        c.accessibilite(racine, nom)
        controle(racine, nom, **kw)
    except Exception as e:  # le controle ne doit jamais empecher la capture
        c.log("  controle:", repr(e))
    png = c.adb("exec-out", "screencap", "-p", binary=True)
    with open(os.path.join(c.OUT, nom + ".png"), "wb") as f:
        f.write(png)
    c.log(f"  capture {nom} ({len(png)} octets)")
    return racine


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


# --- Les ecrans ----------------------------------------------------------------

# nom, classe, extras, champ de saisie a essayer (identifiant) ou None.
ECRANS = [
    ("reglages", "SettingsActivity", "", None),
    ("seance", "SessionActivity", "", None),
    ("bravo", "CelebrationActivity", "--ei minutes 20", None),
    ("journal", "JournalActivity", "", None),
    ("parcours", "ParcoursActivity", "", None),
    ("hizouk", "ChizukActivity", "", None),
    ("conseils", "TipsActivity", "", None),
    ("rappels", "RemindersActivity", "", None),
    ("musique", "MusicActivity", "", None),
    ("siddour", "SiddurActivity", "", None),
    ("siddour-lecture", "SiddurLectureActivity", "--es id chaharit", None),
    ("tefilot", "TefilotActivity", "", None),
    ("tehilim", "TehilimActivity", "", None),
    ("tehilim-lecture", "TehilimLectureActivity", "--ei debut 1 --ei fin 1", None),
    ("tikkun", "TikkunFlowActivity", "", None),
    ("bibliotheque", "LibraryActivity", "", None),
    ("livres", "LibraryActivity", "--ez livres true", None),
    ("source", "LibraryEntryActivity", "--es entry_id src-lm2-25", None),
    ("zmanim", "ZmanimActivity", "", None),
    ("vol", "VolActivity", "", "EditText"),
    ("boussole", "BoussoleActivity", "", None),
    ("calendrier", "CalendrierActivity", "", None),
    ("halakha", "HalakhaActivity", "", None),
    ("hilloulot", "HilloulotActivity", "", "EditText"),
    ("recherche", "RechercheActivity", "", "EditText"),
    ("paliers", "PaliersActivity", "", None),
    ("applications", "AppPickerActivity", "", None),
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
    """Tous les ecrans : le haut, le bas, le clavier."""
    # L'accueil et ses onglets d'abord.
    c.lancer(attente=5)
    prise(f"{prefixe}-accueil")
    if bas:
        au_bout(True)
        prise(f"{prefixe}-accueil-bas")
        au_bout(False)
    if c.toucher(rid="nav_texts", attente=1.5):
        prise(f"{prefixe}-textes")
        if bas:
            au_bout(True)
            prise(f"{prefixe}-textes-bas")
    if c.toucher(rid="nav_zmanim", attente=2.5):
        prise(f"{prefixe}-onglet-zmanim")
        if bas:
            au_bout(True)
            prise(f"{prefixe}-onglet-zmanim-bas")
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


def presentation(prefixe, langue_app):
    c.regler({"onboarded_version": ("int", 0), "langue_app": ("string", langue_app)})
    c.langue(langue_app)
    c.sh(f"am start -W -n {c.PKG}/com.myhitbodedut.MainActivity", timeout=60)
    c.pause(4.0)
    for i in range(1, 10):
        racine = prise(f"{prefixe}-presentation-{i}", attente=0.4)
        voulus = {"onboarding_title", "onboarding_body", "onboarding_next"}
        manque = sorted(voulus - c.visibles(racine, voulus))
        if manque:
            faute(f"{prefixe} presentation {i} : {', '.join(manque)} hors de l'ecran")
        if not c.toucher(rid="onboarding_next", attente=1.2):
            break
        if c.trouver(rid="onboarding_title") is None:
            break
    c.regler({"onboarded_version": ("int", 2)})


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
    png = c.adb("exec-out", "screencap", "-p", binary=True)
    with open(os.path.join(c.OUT, f"{prefixe}-seance-notification.png"), "wb") as f:
        f.write(png)
    c.sh("cmd statusbar collapse")
    c.pause(1.0)
    prise(f"{prefixe}-seance-calme", attente=7.5)
    c.sh(f"input tap {c.W // 2} {int(c.H * 0.14)}")
    c.pause(1.0)
    if ok and c.toucher(rid="session_secondary", defilements=2, attente=1.0):
        prise(f"{prefixe}-seance-terminer-dialogue", attente=0.5)
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


def services_app():
    return c.sh(f"dumpsys activity services {c.PKG} | grep -E 'ServiceRecord' | head -5").strip().replace("\n", " | ")


def barriere(prefixe):
    """Je suis avec Hachem : l'apercu depuis les reglages, puis pour de vrai sur une application choisie."""
    voulues = armer()
    c.lancer()
    ok = c.toucher(rid="nav_settings", attente=2.0)
    ok = ok and c.trouver(rid="preview_gate", defilements=12) is not None
    prise(f"{prefixe}-barriere-etat")
    ok = ok and c.toucher(rid="preview_gate", attente=3.0)
    if ok and c.trouver(rid="blocker_title") is None:
        # La divulgation d'abord, si l'acces n'etait pas vu comme accorde.
        prise(f"{prefixe}-barriere-divulgation")
        c.toucher(rid="button1", attente=2.0)
    vu = c.trouver(rid="blocker_title") is not None
    prise(f"{prefixe}-barriere-apercu")
    if not vu:
        faute(f"{prefixe} : BARRIERE l'apercu de l'ecran de garde ne s'affiche pas")
    else:
        au_bout(True, 3)
        prise(f"{prefixe}-barriere-apercu-bas")
    c.retour()
    c.arreter()
    # Pour de vrai.
    c.lancer()
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
            prise(f"{prefixe}-barriere-reportee", attente=0.5)
            if c.trouver(rid="blocker_title") is not None:
                faute(f"{prefixe} : BARRIERE le report ne retire pas l'ecran de garde")
    c.sh("input keyevent KEYCODE_HOME")
    c.arreter()
    c.regler({"enabled": ("boolean", "false")})


def redemarrage(prefixe):
    """Un vrai redemarrage de l'emulateur, mode arme : le service repart-il seul, et retient-il encore ?
    A lancer en dernier : l'emulateur met une a deux minutes a revenir."""
    voulues = armer()
    c.lancer()
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
    c.pause(40)  # BOOT_COMPLETED arrive aux applications apres l'ecran d'accueil
    c.adb("root")
    c.pause(4)
    c.adb("wait-for-device", timeout=120)
    c.sh("input keyevent KEYCODE_WAKEUP")
    c.sh("wm dismiss-keyguard")
    c.sh("settings put global hide_error_dialogs 1")
    refus = c.sh("logcat -d | grep -E 'ForegroundServiceStartNotAllowed|BackgroundServiceStartNotAllowed|MissingForegroundServiceType|ForegroundServiceTypeException|InvalidForegroundServiceType' | grep -i myhitbodedut | head -5").strip()
    services = services_app()
    c.log("  apres :", services[:300], "| refus :", refus[:500])
    if "GateService" not in services:
        faute(f"{prefixe} : BARRIERE GateService ne repart pas apres un redemarrage ({refus[:300]})")
    if refus:
        faute(f"{prefixe} : SERVICE refus d'Android au demarrage : {refus[:400]}")
    c.sh(f"monkey -p {voulues[0]} -c android.intent.category.LAUNCHER 1")
    c.pause(9.0)
    vu = c.trouver(rid="blocker_title") is not None
    prise(f"{prefixe}-barriere-apres-redemarrage", attente=0.5)
    if not vu:
        faute(f"{prefixe} : BARRIERE apres un redemarrage, l'ecran de garde ne se pose pas sur {voulues[0]}")
    c.sh("input keyevent KEYCODE_HOME")
    c.arreter()
    c.regler({"enabled": ("boolean", "false")})


def tablette(prefixe):
    """Grand ecran (800 dp de large) : debout puis couche. Android 16 n'y respecte plus aucun verrou d'orientation."""
    for nom, taille, densite, couche in (("tablette", "1600x2560", 320, False), ("tablette-couchee", "1600x2560", 320, True),
                                         ("pliant", "1812x2176", 420, False)):
        c.appliquer_taille(taille, densite, couche)
        passe(f"{prefixe}-{nom}", bas=False, saisie=False)
    c.appliquer_taille(None, None, False)


def main():
    c.initialiser("fr")
    passes = [p.strip() for p in os.environ.get("RECETTE_PASSES", "").split(",") if p.strip()] or \
        ["fr-gestes", "he-boutons", "nuit", "seance", "barriere", "presentation", "tablette", "redemarrage"]
    c.log("passes :", passes, "| Android", c.sh("getprop ro.build.version.release").strip(),
          "API", c.sh("getprop ro.build.version.sdk").strip())
    # Un lieu connu pour les zmanim, et un peu de journal : des ecrans remplis, pas des etats vides.
    c.regler({
        "lieu_nom": ("string", "Paris"), "lieu_latitude": ("string", "48.85341"),
        "lieu_longitude": ("string", "2.3488"), "lieu_altitude": ("string", "0.0"),
        "lieu_fuseau": ("string", "Europe/Paris"), "lieu_ville": ("long", "2988507"),
        "in_israel": ("boolean", "false"),
    })

    def p_fr():
        navigation("gestes")
        c.langue("fr")
        passe("fr-gestes")
    def p_he():
        navigation("boutons")
        c.regler({"langue_app": ("string", "he")})
        c.langue("he")
        passe("he-boutons")
        c.regler({"langue_app": ("string", "fr")})
        c.langue("fr")
    def p_nuit():
        navigation("gestes")
        c.regler({"apparence_mode": ("string", "sombre")})
        passe("nuit", bas=False, saisie=False)
        c.regler({"apparence_mode": ("string", "auto")})
    def p_seance():
        navigation("gestes")
        seance_en_cours("gestes")
        navigation("boutons")
        seance_en_cours("boutons")
    def p_barriere():
        navigation("gestes")
        barriere("gestes")
        navigation("boutons")
        barriere("boutons")
    def p_presentation():
        navigation("gestes")
        presentation("fr", "fr")
        presentation("he", "he")
        presentation("en", "en")
        c.regler({"langue_app": ("string", "fr")})
        c.langue("fr")
    def p_tablette():
        navigation("gestes")
        tablette("fr")

    def p_redemarrage():
        redemarrage("gestes")

    table = {"fr-gestes": p_fr, "he-boutons": p_he, "nuit": p_nuit, "seance": p_seance,
             "barriere": p_barriere, "presentation": p_presentation, "tablette": p_tablette,
             "redemarrage": p_redemarrage}
    for nom in passes:
        if nom in table:
            c.etape(nom, table[nom])
    navigation("gestes")
    c.log("\n=== bilan de la recette ===")
    c.log("\n".join(FAUTES) if FAUTES else "aucune faute relevee par les controles automatiques")
    c.log("\ncaptures :", len(os.listdir(c.OUT)))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        c.log("ERREUR generale :", repr(e))
    sys.exit(0)
