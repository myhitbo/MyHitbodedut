#!/usr/bin/env python3
"""
Captures d'ecran reelles de l'application, sur l'emulateur du flux Android
(job « captures », declenche a la main avec captures=true).

Chaque etape est independante : un element introuvable donne une capture
de ce qui est a l'ecran, nommee « NN-nom-INTROUVABLE », et l'arbre
uiautomator de l'ecran est imprime dans le journal. Le job n'echoue jamais
a cause d'une etape.
"""
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

OUT = os.environ.get("CAPTURES_OUT", "out")
os.makedirs(OUT, exist_ok=True)

PKG = None
ROOT = False
PREFS = "shared_prefs/myhitbodedut.xml"


def log(*a):
    print(*a, flush=True)
    # Le meme journal a cote des captures (14/11) : lisible avec git, la ou le journal du job
    # ne se telecharge pas.
    try:
        with open(os.path.join(OUT, "journal.txt"), "a", encoding="utf-8") as f:
            f.write(" ".join(str(x) for x in a) + "\n")
    except OSError:
        pass


def adb(*args, input=None, timeout=90, binary=False):
    try:
        r = subprocess.run(["adb", *args], input=input, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        log("  adb timeout:", " ".join(args))
        return b"" if binary else ""
    if binary:
        return r.stdout
    out = r.stdout.decode("utf-8", "replace")
    if r.returncode != 0:
        log("  adb", " ".join(args), "->", r.returncode, r.stderr.decode("utf-8", "replace").strip()[:400])
    return out


def sh(cmd, **kw):
    return adb("shell", cmd, **kw)


def pause(s):
    time.sleep(s)


# --- Ecran -----------------------------------------------------------------

def dump():
    """L'arbre de l'ecran, ou None. uiautomator echoue parfois sur un ecran
    qui ne se pose pas : on reessaie."""
    for essai in range(4):
        sh("rm -f /sdcard/ui.xml")
        sh("uiautomator dump /sdcard/ui.xml", timeout=40)
        brut = adb("exec-out", "cat", "/sdcard/ui.xml", binary=True)
        if brut and brut.strip().startswith(b"<?xml"):
            try:
                return ET.fromstring(brut)
            except ET.ParseError as e:
                log("  xml illisible:", e)
        pause(1.0)
    return None


def bornes(n):
    m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", n.get("bounds", ""))
    if not m:
        return None
    x1, y1, x2, y2 = map(int, m.groups())
    if x2 <= x1 or y2 <= y1:
        return None
    return x1, y1, x2, y2


def correspond(n, text=None, desc=None, rid=None, contains=False):
    def eq(valeur, attendu):
        if attendu is None:
            return True
        valeur = valeur or ""
        if contains:
            return attendu.lower() in valeur.lower()
        return valeur == attendu

    if rid is not None and not (n.get("resource-id", "") or "").endswith(":id/" + rid):
        return False
    if text is not None and not eq(n.get("text"), text):
        return False
    if desc is not None and not eq(n.get("content-desc"), desc):
        return False
    return True


def ecran_texte(racine):
    """L'ecran en clair pour le journal : une ligne par noeud parlant."""
    if racine is None:
        return "(aucun arbre)"
    lignes = []
    for n in racine.iter("node"):
        t, d, r = n.get("text", ""), n.get("content-desc", ""), n.get("resource-id", "")
        if t or d or r:
            lignes.append(f"  [{n.get('class','').split('.')[-1]}] id={r.split('/')[-1]!s} text={t!r} desc={d!r} {n.get('bounds')}"
                          + (" clickable" if n.get("clickable") == "true" else ""))
    return "\n".join(lignes)


def journal_ecran(pourquoi):
    racine = dump()
    log(f"---- ecran ({pourquoi}) ----")
    log(ecran_texte(racine))
    if racine is not None:
        log("---- xml brut ----")
        log(ET.tostring(racine, encoding="unicode")[:20000])
    log("---- fin ----")


def taille_ecran():
    m = re.search(r"(\d+)x(\d+)", sh("wm size"))
    return (int(m.group(1)), int(m.group(2))) if m else (1080, 2400)


W, H = 1080, 2400


def defiler(vers_le_bas=True):
    x = W // 2
    if vers_le_bas:
        sh(f"input swipe {x} {int(H*0.72)} {x} {int(H*0.32)} 350")
    else:
        sh(f"input swipe {x} {int(H*0.32)} {x} {int(H*0.72)} 350")
    pause(0.8)


def fermer_anr(racine):
    """Une fenetre « ... isn't responding » (lanceur de l'emulateur) : on touche « Wait »."""
    if racine is None:
        return racine
    if not any("responding" in (n.get("text") or "") or "ne répond pas" in (n.get("text") or "")
               for n in racine.iter("node")):
        return racine
    for n in racine.iter("node"):
        if (n.get("text") or "") in ("Wait", "Attendre", "Close app", "Fermer l'application") and bornes(n):
            b = bornes(n)
            log("  fenetre ANR fermee")
            sh(f"input tap {(b[0] + b[2]) // 2} {(b[1] + b[3]) // 2}")
            pause(1.0)
            return dump()
    return racine


def trouver(text=None, desc=None, rid=None, contains=False, defilements=0, index=0):
    for tour in range(defilements + 1):
        racine = fermer_anr(dump())
        if racine is not None:
            trouves = [n for n in racine.iter("node")
                       if correspond(n, text, desc, rid, contains) and bornes(n)]
            if len(trouves) > index:
                return bornes(trouves[index])
        if tour < defilements:
            defiler(True)
    return None


def toucher(text=None, desc=None, rid=None, contains=False, defilements=0, index=0, attente=1.5):
    quoi = " ".join(f"{k}={v!r}" for k, v in (("text", text), ("desc", desc), ("id", rid)) if v is not None)
    # Depuis la refonte du 13/11, Reglages (la roue) et Zmanim (la date hebraique) sont en tete du
    # Jour, plus dans les onglets : depuis Les Livres ou Le Chemin, on revient d'abord au Jour.
    if rid in ("nav_settings", "nav_zmanim") and trouver(rid=rid) is None and trouver(rid="nav_today") is not None:
        toucher(rid="nav_today", attente=1.0)
    b = trouver(text, desc, rid, contains, defilements, index)
    if b is None:
        log(f"  INTROUVABLE : {quoi}")
        journal_ecran(f"recherche de {quoi}")
        return False
    x, y = (b[0] + b[2]) // 2, (b[1] + b[3]) // 2
    log(f"  toucher {quoi} -> ({x},{y})")
    sh(f"input tap {x} {y}")
    pause(attente)
    return True


def retour(n=1):
    for _ in range(n):
        sh("input keyevent KEYCODE_BACK")
        pause(1.0)


DENSITE = None


def accessibilite(racine, nom):
    """Audit d'accessibilite (16/10, point 9) : cibles touchables de moins de
    48 dp, et elements touchables sans texte ni description (muets pour
    TalkBack). Note dans accessibilite.txt, sans jamais faire echouer."""
    global DENSITE
    if racine is None:
        return
    if DENSITE is None:
        m = re.search(r"(\d+)\s*$", sh("wm density").strip())
        DENSITE = (int(m.group(1)) / 160.0) if m else 2.625
    lignes = []
    for n in racine.iter("node"):
        if n.get("clickable") != "true" and n.get("long-clickable") != "true" and n.get("checkable") != "true":
            continue
        b = bornes(n)
        if not b:
            continue
        l, h = (b[2] - b[0]) / DENSITE, (b[3] - b[1]) / DENSITE
        etiquette = (n.get("text") or n.get("content-desc") or "").strip()
        if not etiquette:
            etiquette = " ".join((c.get("text") or c.get("content-desc") or "").strip() for c in n.iter("node") if c is not n).strip()
        cls = n.get("class", "").rsplit(".", 1)[-1]
        rid = n.get("resource-id", "").rsplit("/", 1)[-1]
        if l < 47.5 or h < 47.5:
            lignes.append(f"PETIT {round(l)}x{round(h)}dp {cls} {rid} «{etiquette[:30]}»")
        if not etiquette:
            lignes.append(f"MUET {cls} {rid} {b}")
    with open(os.path.join(OUT, "accessibilite.txt"), "a") as f:
        f.write(f"== {nom}\n" + "".join(x + "\n" for x in lignes))


def capture(nom, attente=1.2, ok=True):
    pause(attente)
    try:
        racine = fermer_anr(dump())
        accessibilite(racine, nom)
    except Exception as e:
        log("  audit:", e)
    if not ok:
        nom += "-INTROUVABLE"
    chemin = os.path.join(OUT, nom + ".png")
    png = adb("exec-out", "screencap", "-p", binary=True)
    with open(chemin, "wb") as f:
        f.write(png)
    log(f"  capture {chemin} ({len(png)} octets)")


# --- Application -----------------------------------------------------------

def paquet():
    paquets = [l.split(":", 1)[1].strip() for l in sh("pm list packages myhitbodedut").splitlines() if ":" in l]
    log("paquets installes :", paquets)
    for p in ("com.myhitbodedut.debug", "com.myhitbodedut"):
        if p in paquets:
            return p
    return paquets[0] if paquets else "com.myhitbodedut.debug"


def arreter():
    sh(f"am force-stop {PKG}")
    pause(1.0)


def lancer(attente=4.0):
    # --activity-clear-top : l'accueil lui-meme, pas l'ecran reste devant (une priere, la vitrine
    # des vignettes...). Depuis la refonte, Reglages et Zmanim ne s'atteignent que depuis le Jour.
    sh(f"am start -W --activity-clear-top -n {PKG}/com.myhitbodedut.MainActivity", timeout=60)
    pause(attente)
    # Si la presentation est la malgre la preference, on la passe.
    if trouver(rid="onboarding_skip"):
        log("  presentation affichee : on la passe")
        toucher(rid="onboarding_skip")


DEBOGABLE = True
JOURNAL = "shared_prefs/myhitbodedut-journal.xml"


def dossier_app():
    return f"/data/data/{PKG}"


def lire_prefs(fichier=None):
    fichier = fichier or PREFS
    if DEBOGABLE:
        return adb("exec-out", "run-as", PKG, "cat", fichier, binary=True).decode("utf-8", "replace")
    return adb("exec-out", "cat", f"{dossier_app()}/{fichier}", binary=True).decode("utf-8", "replace")


def ecrire_prefs(contenu, fichier=None):
    """Sur l'edition publiee (release, non debogable : recette du 22/11), run-as est refuse.
    On ecrit alors en root, puis on rend le fichier a l'application (proprietaire et contexte
    SELinux), sans quoi elle ne le lit pas."""
    fichier = fichier or PREFS
    if DEBOGABLE:
        sh(f"run-as {PKG} mkdir -p shared_prefs")
        adb("shell", f"run-as {PKG} sh -c 'cat > {fichier}'", input=contenu.encode("utf-8"))
        return
    d = dossier_app()
    sh(f"mkdir -p {d}/shared_prefs")
    adb("shell", f"cat > {d}/{fichier}", input=contenu.encode("utf-8"))
    proprio = sh(f"stat -c %u:%g {d}").strip()
    sh(f"chown -R {proprio} {d}/shared_prefs && chmod 771 {d}/shared_prefs && chmod 660 {d}/{fichier} && restorecon -R {d}/shared_prefs")


def regler(valeurs, fichier=None):
    """Ecrit des preferences (application arretee). valeurs : nom -> (type, valeur)."""
    arreter()
    xml = lire_prefs(fichier)
    if "<map" not in xml:
        xml = "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n<map>\n</map>\n"
    for nom, (typ, val) in valeurs.items():
        xml = re.sub(rf'\s*<[^>]+name="{re.escape(nom)}"[^>]*/>', "", xml)
        xml = re.sub(rf'\s*<string name="{re.escape(nom)}">.*?</string>', "", xml, flags=re.S)
        if typ == "string":
            ligne = f'    <string name="{nom}">{val}</string>'
        else:
            ligne = f'    <{typ} name="{nom}" value="{val}" />'
        xml = xml.replace("</map>", ligne + "\n</map>")
    ecrire_prefs(xml, fichier)
    log("  preferences :", lire_prefs(fichier).replace("\n", " ")[:600])


def langue(etiquette):
    arreter()
    sh(f"cmd locale set-app-locales {PKG} --locales {etiquette}")
    log("  langue :", sh(f"cmd locale get-app-locales {PKG}").strip())


def activite(classe, extras=""):
    """Ouvre une activite non exportee : il faut adb root (images google_apis)."""
    if not ROOT:
        return False
    sh(f"am start -W -n {PKG}/com.myhitbodedut.{classe} {extras}", timeout=60)
    pause(2.5)
    return True


def etape(titre, fonction):
    # Sur demande (CAPTURES_ETAPES=« 17,22 ») : seulement ces etapes, par leur numero.
    voulues = [e.strip() for e in os.environ.get("CAPTURES_ETAPES", "").split(",") if e.strip()]
    if voulues and not any(titre.split(" ")[0].startswith(v) for v in voulues):
        return
    log(f"\n=== {titre} ===")
    try:
        fonction()
    except Exception as e:  # une etape ratee ne doit pas arreter les suivantes
        log(f"  ERREUR dans {titre} : {e!r}")
        try:
            journal_ecran("erreur")
            capture(re.sub(r"\W+", "-", titre).strip("-") + "-ERREUR", attente=0.2)
        except Exception:
            pass


def onglet_textes():
    ok = toucher(rid="nav_texts", attente=1.5)
    return ok


def ouvrir_siddour():
    lancer()
    onglet_textes()
    return toucher(rid="siddur_button", defilements=2, attente=2.0)


def ouvrir_priere(fr=True):
    if fr:
        ok = toucher(text="Cha’harit", defilements=3, attente=3.0)
        if not ok:
            ok = toucher(text="harit", contains=True, defilements=2, attente=3.0)
    else:
        ok = toucher(text="שַׁחֲרִית", contains=True, defilements=3, attente=3.0)
    if not ok:
        ok = activite("SiddurLectureActivity", "--es id chaharit")
    return ok


# --- Le parcours -----------------------------------------------------------

def racine_adb():
    """Le paquet, l'ecran, root : avant tout parcours."""
    global PKG, ROOT, W, H, DEBOGABLE
    PKG = paquet()
    log("paquet :", PKG)
    W, H = taille_ecran()
    log("ecran :", W, H)
    r = adb("root")
    log("adb root :", r.strip())
    pause(3)
    adb("wait-for-device")
    ROOT = sh("id -u").strip() == "0"
    log("root :", ROOT)
    DEBOGABLE = "uid=" in sh(f"run-as {PKG} id")
    log("debogable :", DEBOGABLE)


def initialiser(langue_app="fr"):
    """La presentation passee, la version Classique, la langue : l'etat de depart des parcours."""
    for perm in ("android.permission.POST_NOTIFICATIONS",):
        sh(f"pm grant {PKG} {perm}")
    # Pas de presentation au premier lancement (Store.KEY_ONBOARDED, Onboarding.VERSION = 2).
    # La version Classique (VersionApp, 17/11) : sans elle, l'ecran du choix de la version couvre l'accueil.
    regler({"onboarded_version": ("int", 2), "langue_app": ("string", langue_app), "version_app": ("string", "classique")})
    # Un premier lancement, puis la langue : posee avant, elle n'etait pas
    # gardee et l'application s'ouvrait en anglais.
    lancer()
    langue(langue_app)


def main():
    racine_adb()
    initialiser()

    # Sur demande (CAPTURES_TAILLES_SEULES=1) : le seul passage des tailles,
    # deux fois plus court que le parcours entier.
    # L'ecran d'ouverture (15/10) : le 'hassid devant le tziyoun, saisi pendant sa
    # seconde et demie, au demarrage a froid.
    def s00():
        sh(f"am force-stop {PKG}")
        pause(1.0)
        sh(f"am start -n {PKG}/com.myhitbodedut.MainActivity")
        for i, t in enumerate((1.2, 1.3, 1.0)):
            pause(t)
            png = adb("exec-out", "screencap", "-p", binary=True)
            with open(os.path.join(OUT, f"00-ouverture-{i + 1}.png"), "wb") as f:
                f.write(png)
        pause(2.0)
    etape("00 ouverture", s00)

    if os.environ.get("CAPTURES_TAILLES_SEULES") == "1":
        etape("20 tailles d'ecran", lambda: tailles())
        return

    def s01():
        lancer(attente=6)
        capture("01-accueil")
        defiler(True)
        capture("01b-accueil-suite")
    etape("01 accueil", s01)

    def s02():
        ok = onglet_textes()
        defiler(False)
        capture("02-onglet-textes", ok=ok)
    etape("02 onglet textes", s02)

    def s03():
        ok = toucher(rid="siddur_button", defilements=2, attente=2.5)
        capture("03-siddour-liste", ok=ok)
        defiler(True)
        capture("03b-siddour-liste-suite", ok=ok)
        defiler(False)
        defiler(False)
    etape("03 siddour", s03)

    def s04():
        ok = toucher(rid="siddur_heading_nusah", attente=1.5)
        capture("04-choix-nusah", ok=ok)
        if ok:
            retour()
    etape("04 nusah", s04)

    def s05():
        ok = ouvrir_priere()
        capture("05-priere-pastille", attente=2.0, ok=ok)
    etape("05 priere", s05)

    def s06():
        ok = toucher(desc="Réglages de lecture", attente=1.2)
        capture("06-barre-depliee", ok=ok)
    etape("06 barre", s06)

    def s07():
        ok = toucher(desc="Lettres plus grandes", attente=0.8)
        ok = toucher(desc="Lettres plus grandes", attente=1.2) and ok
        capture("07-lettres-plus-grandes", ok=ok)
    etape("07 lettres", s07)

    def s08():
        ok = toucher(desc="Lecture sur fond noir", attente=1.5)
        capture("08-lecture-nuit", ok=ok)
    etape("08 nuit", s08)

    def s09():
        ok = toucher(desc="Masquer le bouton", attente=0.5)
        capture("09-bouton-masque-snackbar", attente=0.3, ok=ok)
    etape("09 masquer", s09)

    def s10():
        pause(4.5)  # la barre d'information s'en va
        capture("10a-texte-sans-bouton", attente=0.2)
        x, y = W // 2, int(H * 0.45)
        sh(f"input swipe {x} {y} {x} {y} 900")
        capture("10-appui-long-barre-revenue", attente=1.2)
    etape("10 appui long", s10)

    def remise_a_zero():
        # Lecture de jour, 100 %, bouton visible : les ecrans suivants
        # montrent l'etat ordinaire.
        regler({"lecture_sombre": ("boolean", "false"),
                "lecture_masquee": ("boolean", "false"),
                "lecture_echelle": ("float", "1.0")})
    etape("remise a zero de la lecture", remise_a_zero)

    def s11():
        lancer()
        onglet_textes()
        ok = toucher(rid="tehilim_button", defilements=2, attente=2.0)
        capture("11a-tehilim", ok=ok)
        ok2 = toucher(rid="tehilim_month_button", attente=3.0)
        if not ok2:
            ok2 = activite("TehilimLectureActivity", "--ei debut 1 --ei fin 1")
        capture("11-tehilim-lecture", ok=ok2)
    etape("11 tehilim", s11)

    def s12():
        lancer()
        onglet_textes()
        # Le Tikoun s'ouvre sur le texte entier (04/11) : plus de liste des dix psaumes.
        ok = toucher(rid="tikkun_button", defilements=2, attente=3.0)
        if not ok:
            ok = activite("TikkunFlowActivity")
        capture("12-tikkun-d-un-trait", ok=ok)
    etape("12 tikkun d'un trait", s12)

    def s13():
        lancer()
        onglet_textes()
        ok = toucher(rid="tikkun_button", defilements=2, attente=3.0)
        if not ok:
            ok = activite("TikkunFlowActivity")
        # La fin : la clôture, la kavana, la prière de Rabbi Natan, le bouton « dit en entier ».
        for _ in range(20):
            sh(f"input swipe {W // 2} {int(H * 0.8)} {W // 2} {int(H * 0.2)} 60")
        pause(2.0)
        capture("13-tikkun-fin", ok=ok)
    etape("13 fin du tikkun", s13)

    def s14():
        lancer()
        onglet_textes()
        ok = toucher(rid="library_button", defilements=3, attente=2.0)
        capture("14a-bibliotheque", ok=ok)
        ok = toucher(rid="subsection_he", defilements=1, attente=2.0)
        capture("14b-bibliotheque-sous-section", ok=ok)
        ok = toucher(rid="entry_title", defilements=1, attente=2.5)
        if not ok:
            ok = activite("LibraryEntryActivity", "--es entry_id src-lm2-25")
        capture("14-bibliotheque-source", ok=ok)
    etape("14 bibliotheque", s14)

    def vitrine(nom):
        # On l'ouvre, et c'est l'ecran au premier plan qui dit si elle existe :
        # le controle par « pm dump » la disait absente alors qu'elle etait la (19/10).
        sortie = sh(f"am start -W -n {PKG}/com.myhitbodedut.VitrineWidgetActivity", timeout=60)
        pause(1.5)
        devant = sh("dumpsys activity activities | grep -E 'mResumedActivity|topResumedActivity'")
        log("  vitrine :", sortie.strip()[:200], "|", devant.strip()[:200])
        if "VitrineWidgetActivity" not in devant and "Error" in sortie:
            log("  VitrineWidgetActivity absente : etape sautee")
            return
        capture(nom, attente=3.0)
        defiler(True)
        capture(nom + "-suite", attente=1.0)
        defiler(True)
        capture(nom + "-fin", attente=1.0)
    etape("17 vitrine des vignettes", lambda: vitrine("17-vitrine-vignettes"))

    def s15():
        lancer()
        ok = toucher(rid="nav_settings", attente=2.0)
        ok = ok and toucher(rid="accent_button", defilements=4, attente=1.5)
        capture("15a-choix-couleur", ok=ok)
        ok = ok and toucher(text="Violet", attente=2.5)
        capture("15b-reglages-violet", ok=ok)
        if not ok:
            regler({"apparence_accent": ("string", "violet")})
        ouvrir_siddour()
        capture("15c-siddour-violet")
        ok = ouvrir_priere()
        capture("15d-priere-pastille-violet", ok=ok)
        ok = toucher(desc="Réglages de lecture", attente=1.2)
        capture("15e-priere-barre-violet", ok=ok)
    etape("15 couleur violette", s15)

    etape("17b vitrine en violet", lambda: vitrine("17b-vitrine-vignettes-violet"))

    def s18():
        # Calendrier hébraïque (10/10) : un lieu connu, Paris, sans passer par le dialogue.
        regler({
            "lieu_nom": ("string", "Paris"), "lieu_latitude": ("string", "48.85341"),
            "lieu_longitude": ("string", "2.3488"), "lieu_altitude": ("string", "0.0"),
            "lieu_fuseau": ("string", "Europe/Paris"), "lieu_ville": ("long", "2988507"),
            "in_israel": ("boolean", "false"),
        })
        lancer()
        ok = toucher(rid="nav_zmanim", attente=2.5)
        capture("18a-zmanim", ok=ok)
        defiler(True)
        capture("18b-zmanim-horaires", ok=ok)
        defiler(True)
        capture("18c-zmanim-fin", ok=ok)
        ok2 = toucher(text="Calendrier", defilements=0, attente=2.5) or activite("CalendrierActivity")
        if not ok2:
            defiler(False)
            defiler(False)
            ok2 = toucher(text="Calendrier", attente=2.5)
        capture("18d-calendrier", ok=ok2)
        defiler(True)
        capture("18e-calendrier-jour", ok=ok2)
        # Le calendrier reste au-dessus de l'accueil : on en sort avant d'ouvrir le siddour.
        retour(2)
        ok4 = ouvrir_siddour()
        capture("18f-siddour-pour-cette-heure", ok=ok4)
        # Le soir de la CI (heure de Paris), c'est Arvit qui porte les ajouts du jour.
        ok3 = toucher(text="Arvit", defilements=3, attente=3.0) or activite("SiddurLectureActivity", "--es id arvit")
        for i in range(12):
            defiler(True)
        capture("18g-priere-ajouts", ok=ok3)
        for i in range(4):
            defiler(True)
        capture("18h-priere-ajouts-suite", ok=ok3)
    etape("18 zmanim, calendrier, ajouts", s18)

    def s19():
        # Les écrans du 11 au 14/10 : halakha (livre au choix), hilloulot, livres, siddour des occasions,
        # paliers, réglages (personnalisation, écran Zmanim). Lieu : Paris, réglé par s18.
        lancer()
        ok = activite("HalakhaActivity")
        capture("19a-halakha", ok=ok)
        defiler(True)
        capture("19b-halakha-suite", ok=ok)
        retour()
        ok = activite("HilloulotActivity")
        capture("19c-hilloulot", ok=ok)
        # Réorganisé (04/11) : un nom touché déplie sa fiche ; la recherche range par date.
        ok2 = toucher(desc="Lire la suite", contains=True, attente=1.5)
        capture("19d-hilloulot-fiche", ok=ok2)
        ok3 = toucher(text="Rechercher un tsadik", attente=1.0)
        if ok3:
            sh("input text Nahman")
            pause(1.5)
            sh("input keyevent 4")
            pause(0.8)
        capture("19d2-hilloulot-recherche", ok=ok3)
        retour()
        ok = activite("LibraryActivity", "--ez livres true")
        capture("19e-livres", ok=ok)
        retour()
        ok = ouvrir_siddour()
        for i in range(10):
            defiler(True)
        capture("19f-siddour-occasions", ok=ok)
        retour(2)
        ok = activite("PaliersActivity")
        capture("19g-paliers-trophees", ok=ok)
        retour()
        lancer()
        ok = toucher(rid="nav_settings", attente=2.5)
        capture("19h-reglages", ok=ok)
        for i in range(2):
            defiler(True)
        capture("19i-reglages-apparence", ok=ok)
        defiler(True)
        capture("19j-reglages-ecran-zmanim", ok=ok)
    etape("19 halakha, hilloulot, livres, occasions, reglages", s19)

    def s16():
        regler({"apparence_accent": ("string", "vert")})
        langue("he")
        lancer(attente=5)
        capture("16a-he-accueil")
        onglet_textes()
        capture("16b-he-onglet-textes")
        ok = toucher(rid="siddur_button", defilements=2, attente=2.5)
        capture("16c-he-siddour-liste", ok=ok)
        ok = ouvrir_priere(fr=False)
        capture("16d-he-priere-pastille", attente=1.5, ok=ok)
        ok = toucher(desc="הגדרות קריאה", attente=1.2)
        capture("16e-he-priere-barre-depliee", ok=ok)
        lancer()
        ok = toucher(rid="nav_zmanim", attente=2.5)
        capture("16f-he-zmanim", ok=ok)
        defiler(True)
        capture("16g-he-zmanim-suite", ok=ok)
        ok = activite("HalakhaActivity")
        capture("16h-he-halakha", ok=ok)
        ok = activite("HilloulotActivity")
        capture("16i-he-hilloulot", ok=ok)
    etape("16 passage en hebreu", s16)

    etape("20 tailles d'ecran", lambda: tailles())

    # Les nouveautes du 16/10 : la ligne des trophees (en-tete, detail), puis la pratique
    # calme (la lueur, puis tout efface apres six secondes), en francais.
    def s21():
        langue("fr")
        lancer()
        capture("21a-accueil-grade-prochain")
        ok = activite("PaliersActivity")
        capture("21b-trophees-ici", ok=ok, attente=2.5)
        ok = ok and toucher(text="TU ES ICI", contains=True, attente=2.0)
        capture("21c-trophee-detail", ok=ok)
        retour(2)
        ok = activite("PaliersActivity")
        for i in range(12):
            defiler(False)
        capture("21d-trophees-tete", ok=ok)
        retour()
        ok = activite("SessionActivity", "--ez start_now true")
        capture("21e-pratique-debut", ok=ok, attente=2.0)
        capture("21f-pratique-calme", ok=ok, attente=7.5)
        sh("input tap 540 300")
        capture("21g-pratique-reveil", ok=ok, attente=0.8)
        if ok and toucher(rid="session_secondary", attente=1.0):
            toucher(rid="button1", attente=1.5)
        retour()
    etape("21 trophees et pratique calme", s21)

    # Les nouveautes du 19/10 : la source du jour, « J'ai besoin de 'hizouk »,
    # « Mon parcours », les ambiances, les questions une a une, « Commencer
    # simplement », le guide et les prieres du Yanuka, « Je suis avec Hachem ».
    def s22():
        langue("fr")
        # Une seance laissee en cours par l'etape 21 cacherait « Commencer simplement ».
        if activite("SessionActivity") and toucher(rid="session_secondary", defilements=3, attente=1.0):
            toucher(rid="button1", attente=1.5)
        lancer()
        defiler(True)
        defiler(True)
        capture("22a-accueil-moment-source-du-jour")
        defiler(True)
        capture("22a2-accueil-parcours")
        ok = activite("ChizukActivity")
        capture("22b-hizouk", ok=ok, attente=2.0)
        ok = ok and toucher(rid="chizuk_garder", attente=1.0)
        defiler(True)
        capture("22c-hizouk-garde", ok=ok)
        retour()
        ok = activite("ParcoursActivity")
        capture("22d-parcours", ok=ok, attente=2.0)
        retour()
        ok = activite("MusicActivity")
        ok = ok and toucher(rid="music_ambiance", attente=1.5)
        capture("22e-ambiance-choix", ok=ok)
        ok = ok and toucher(text="Pluie", attente=1.5)
        capture("22f-ambiance-pluie", ok=ok)
        retour()
        ok = activite("SessionActivity")
        defiler(True)
        defiler(True)
        capture("22g-seance-commencer-simplement", ok=ok, attente=1.5)
        ok = ok and toucher(rid="simplement_question", defilements=3, attente=2.5)
        defiler(True)
        defiler(True)
        capture("22h-seance-question", ok=ok)
        ok = ok and toucher(rid="session_question_suivante", attente=1.0)
        capture("22i-seance-question-suivante", ok=ok)
        for i in range(4):
            defiler(False)
        if toucher(rid="session_secondary", attente=1.0):
            toucher(rid="button1", attente=1.5)
        retour()
        ok = activite("LibraryActivity", "--ez livres true")
        capture("22j-livres", ok=ok, attente=2.0)
        ok = ok and toucher(text="המדריך המקיף", contains=True, attente=2.5)
        capture("22k-guide", ok=ok)
        retour()
        ok = toucher(text="תפילה לשלמה", contains=True, defilements=3, attente=2.5)
        capture("22l-tefila-lishlomo", ok=ok)
        retour(2)
        lancer()
        ok = toucher(rid="nav_settings", attente=2.0)
        ok = ok and trouver(text="Je suis avec Hachem", defilements=8) is not None
        capture("22m-reglages-avec-hachem", ok=ok)
    etape("22 nouveautes du 19/10", s22)

    # Le 02/11 : « Je suis avec Hachem » (le blocage), ses heures et la duree du report,
    # puis l'ecran lui-meme : en apercu, puis pour de vrai sur une application choisie.
    def s23():
        presentes = [l.split(":", 1)[1].strip() for l in sh("pm list packages").splitlines() if ":" in l]
        voulues = [a for a in ("com.android.chrome", "com.google.android.youtube", "com.google.android.apps.messaging",
                               "com.google.android.gm", "com.google.android.apps.photos", "com.google.android.apps.maps",
                               "com.android.messaging", "com.android.camera2", "com.android.contacts", "com.android.calendar")
                   if a in presentes][:3] or ["com.android.settings"]
        log("  applications bloquees :", voulues)
        regler({"enabled": ("boolean", "true"), "window_start": ("int", 360), "window_end": ("int", 660),
                "snooze_minutes": ("int", 15), "langue_app": ("string", "fr"), "apparence_accent": ("string", "vert")})
        xml = re.sub(r'\s*<set name="blocked_apps">.*?</set>|\s*<set name="blocked_apps"\s*/>', "", lire_prefs(), flags=re.S)
        ensemble = '    <set name="blocked_apps">' + "".join(f"<string>{a}</string>" for a in voulues) + "</set>"
        ecrire_prefs(xml.replace("</map>", ensemble + "\n</map>"))
        for op in ("SYSTEM_ALERT_WINDOW", "GET_USAGE_STATS"):
            sh(f"appops set {PKG} {op} allow")
        langue("fr")
        lancer()
        ok = toucher(rid="nav_settings", attente=2.0)
        ok = ok and trouver(rid="apps_summary", defilements=12) is not None
        defiler(True)
        ok = ok and trouver(text="Je suis avec Hachem") is not None
        capture("23a-je-suis-avec-hachem-reglages", ok=ok)
        ok2 = toucher(rid="window_start", attente=2.0)
        capture("23b-heures-du-mode", ok=ok2)
        retour()
        ok3 = toucher(rid="snooze_length", attente=2.0)
        capture("23c-duree-du-report", ok=ok3)
        retour()
        ok4 = trouver(rid="preview_gate") is not None
        if not ok4:
            for _ in range(3):
                defiler(False)
                if trouver(rid="preview_gate") is not None:
                    ok4 = True
                    break
        capture("23d-etat-du-mode", ok=ok4)
        ok4 = ok4 and toucher(rid="preview_gate", attente=3.0) and trouver(rid="blocker_title") is not None
        capture("23e-ecran-je-suis-avec-hachem-apercu", ok=ok4)
        retour()
        arreter()
        # Pour de vrai : la fenetre couvre l'heure de l'emulateur, et une application choisie s'ouvre.
        maintenant = sh("date +%H:%M").strip()
        m = re.match(r"(\d+):(\d+)", maintenant)
        if m:
            minutes = int(m.group(1)) * 60 + int(m.group(2))
            regler({"window_start": ("int", max(0, minutes - 30)), "window_end": ("int", min(1439, minutes + 120))})
            lancer()
            sh(f"monkey -p {voulues[0]} -c android.intent.category.LAUNCHER 1")
            pause(6.0)
            ok5 = trouver(rid="blocker_title") is not None
            capture("23f-ecran-je-suis-avec-hachem", ok=ok5, attente=0.5)
            sh("input keyevent KEYCODE_HOME")
            arreter()
            regler({"window_start": ("int", 360), "window_end": ("int", 660)})
    etape("23 je suis avec Hachem", s23)

    # 24 (03/11) : la banderole d'un texte court (Acher Yatsar) et d'un long (Cha'harit),
    # en faisant defiler doucement : filmee, pour voir qu'elle ne clignote plus.
    def s24():
        # Comme le telephone de la video du 03/11 : 480x854, densite 240.
        sh("wm size 480x854"); sh("wm density 240"); pause(3.0)
        global W, H
        W0, H0 = W, H
        W, H = 480, 854
        try:
            s24_textes()
        finally:
            sh("wm size reset"); sh("wm density reset"); pause(3.0)
            W, H = W0, H0

    def s24_textes():
        for nom, ident in (("24a-acher-yatsar", "acher_yatsar"), ("24b-chaharit", "chaharit")):
            activite("SiddurLectureActivity", f"--es id {ident}")
            pause(2.0)
            sh("rm -f /sdcard/film.mp4")
            film = subprocess.Popen(["adb", "shell", "screenrecord", "--time-limit", "40", "/sdcard/film.mp4"])
            pause(1.0)
            x = W // 2
            bas, haut = (6, 8) if ident == "acher_yatsar" else (14, 22)
            for i in range(bas):  # doucement vers le bas, par petits pas
                sh(f"input swipe {x} {int(H*0.60)} {x} {int(H*0.52)} 900")
                pause(0.5)
                if i == 2:
                    capture(f"{nom}-bas", attente=0.3)
            for i in range(haut):  # puis doucement vers le haut, jusqu'en haut
                sh(f"input swipe {x} {int(H*0.52)} {x} {int(H*0.60)} 900")
                pause(0.5)
            capture(f"{nom}-haut", attente=0.3)
            try:
                film.wait(timeout=50)
            except subprocess.TimeoutExpired:
                film.kill()
            pause(1.5)
            video = adb("exec-out", "cat", "/sdcard/film.mp4", binary=True)
            with open(os.path.join(OUT, nom + ".mp4"), "wb") as f:
                f.write(video)
            log(f"  film {nom}.mp4 ({len(video)} octets)")
            sh("input keyevent KEYCODE_BACK")
    etape("24 banderole en defilant doucement", s24)

    def s25():
        # Signalé le 03/11 (captures du téléphone) : de nuit, en hébreu, pour צדקת, les boutons
        # Material de l'accueil en rose et « Commencer » gris ; l'avatar de l'anneau détouré de blanc.
        for nom, fond, accent in (("25a-nuit-bleu-turquoise", "bleu", "turquoise"), ("25b-nuit-vert", "vert", "vert")):
            regler({"apparence_mode": ("string", "sombre"), "apparence_fond": ("string", fond),
                    "apparence_accent": ("string", accent), "adresse": ("string", "f")})
            langue("he")
            lancer(attente=5)
            capture(nom + "-haut")
            for i in range(2):
                defiler(True)
            capture(nom + "-milieu")
            for i in range(3):
                defiler(True)
            capture(nom + "-bas")
        regler({"apparence_mode": ("string", "auto"), "apparence_fond": ("string", "vert"),
                "apparence_accent": ("string", "vert"), "adresse": ("string", "m")})
        langue("fr")
    etape("25 nuit, hébreu, צדקת", s25)

    def s26():
        # La fluidité des passages (03/11) : les animations, coupées pour toutes les autres étapes,
        # sont rétablies ; on filme et on compte les images en retard (dumpsys gfxinfo). Le rendu
        # de l'émulateur est logiciel (swiftshader) : les chiffres sont pessimistes, la vidéo dit
        # surtout si chaque passage se déroule ou saute.
        for k in ("window_animation_scale", "transition_animation_scale", "animator_duration_scale"):
            sh(f"settings put global {k} 1")
        try:
            lancer(attente=5)
            sh(f"dumpsys gfxinfo {PKG} reset")
            sh("rm -f /sdcard/film.mp4")
            film = subprocess.Popen(["adb", "shell", "screenrecord", "--time-limit", "60", "/sdcard/film.mp4"])
            pause(1.5)
            # Trois lieux depuis la refonte du 13/11 (Le Jour, Les Livres, Le Chemin) ; Zmanim et
            # Réglages s'ouvrent en tête du Jour, sous les mêmes identifiants, sur leur propre écran.
            for onglet in ("nav_texts", "nav_journal", "nav_today", "nav_zmanim", "nav_settings"):
                toucher(rid=onglet, attente=1.6)
                if onglet in ("nav_zmanim", "nav_settings"):
                    retour(); pause(1.2)
            # Le volet de la séance, ouvert puis refermé par la flèche de la barre de départ.
            toucher(rid="depart_regler", attente=1.2)
            toucher(rid="depart_regler", attente=1.0)
            toucher(rid="nav_journal", attente=1.2)
            toucher(rid="trophees_paliers", defilements=2, attente=2.0)
            retour(); pause(1.5)
            onglet_textes()
            toucher(rid="siddur_button", defilements=2, attente=2.0)
            retour(); pause(1.5)
            activite("SiddurLectureActivity", "--es id chaharit")
            pause(2.0)
            x = W // 2
            for i in range(3):  # élans vers le bas : la banderole part, le texte glisse
                sh(f"input swipe {x} {int(H*0.75)} {x} {int(H*0.30)} 120"); pause(1.4)
            for i in range(5):  # puis vers le haut, jusqu'en haut : elle revient
                sh(f"input swipe {x} {int(H*0.30)} {x} {int(H*0.75)} 120"); pause(1.4)
            retour(); pause(2.0)
            try:
                film.wait(timeout=70)
            except subprocess.TimeoutExpired:
                film.kill()
            pause(1.5)
            video = adb("exec-out", "cat", "/sdcard/film.mp4", binary=True)
            with open(os.path.join(OUT, "26-passages.mp4"), "wb") as f:
                f.write(video)
            stats = sh(f"dumpsys gfxinfo {PKG}")
            garde = [l for l in stats.splitlines() if any(m in l for m in (
                "Total frames", "Janky frames", "percentile", "Number Missed", "Number High", "Number Slow", "Number Frame deadline"))]
            with open(os.path.join(OUT, "26-gfxinfo.txt"), "w") as f:
                f.write("\n".join(garde) + "\n\n" + stats)
            log("  gfxinfo :", " | ".join(l.strip() for l in garde))
        finally:
            for k in ("window_animation_scale", "transition_animation_scale", "animator_duration_scale"):
                sh(f"settings put global {k} 0")
    etape("26 fluidité des passages", s26)

    # 27 (13/11) : les captures brutes de la fiche Google Play, en anglais et en hebreu,
    # prises sur l'application elle-meme et non sur le site (audit du 12/11, TPLAYDOCS-06).
    # tools/visuels_play.mjs les compose ensuite avec les legendes de
    # play/visuels/legendes.json. Huit ecrans par langue : play-<langue>-<cle>.png.
    def s27():
        import datetime
        import json as _json

        def sans_points(t):
            return re.sub(r"[֑-ׇ]", "", t)

        def nom_en_toutes_lettres():
            # Pas de Tetragramme sur une image de fiche (demande du proprietaire, 04/11).
            try:
                return "יהוה" in sans_points(ecran_texte(dump()))
            except Exception:
                return False

        def journal_de_demonstration():
            # Quelques jours faits avant aujourd'hui : l'accueil et le journal montrent une
            # pratique en cours, pas un compteur a zero. Application arretee.
            jour = sh("date +%Y-%m-%d").strip()
            try:
                auj = datetime.date.fromisoformat(jour)
            except ValueError:
                auj = datetime.date.today()
            jours = {(auj - datetime.timedelta(days=d)).isoformat(): {"minutes": m}
                     for d, m in ((1, 20), (2, 15), (3, 30), (5, 15), (6, 20))}
            brut = _json.dumps(jours).replace("&", "&amp;").replace('"', "&quot;").replace("<", "&lt;")
            xml = ("<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n<map>\n"
                   f"    <string name=\"days\">{brut}</string>\n</map>\n")
            ecrire_prefs(xml, JOURNAL)

        def fermer_trophees(code):
            # Le journal de demonstration fait gagner des trophees : leurs fenetres s'ouvrent
            # l'une apres l'autre sur l'accueil.
            libelle = {"en": "Continue", "he": "להמשיך"}.get(code, "Continuer")
            for _ in range(10):
                if trouver(text=libelle) is None:
                    return
                toucher(text=libelle, attente=1.2)

        def apercu_de_la_barriere(code):
            # L'apercu passe l'application a l'arriere-plan : on la rouvre avant chaque essai.
            lancer(attente=3)
            fermer_trophees(code)
            # Depuis la refonte, la roue est en tete du Jour : apres la capture des Livres,
            # l'accueil y est encore. Aux essais suivants, c'est Reglages qui revient devant
            # (pas de nav_today) : la recherche de preview_gate plus bas s'en charge.
            if trouver(rid="nav_today") is not None:
                toucher(rid="nav_today", attente=1.0)
            ok = toucher(rid="nav_settings", attente=2.0)
            ok = ok and trouver(rid="preview_gate", defilements=14) is not None
            if not ok:
                for _ in range(6):
                    defiler(False)
                    if trouver(rid="preview_gate") is not None:
                        ok = True
                        break
            return ok and toucher(rid="preview_gate", attente=3.0) and trouver(rid="blocker_title") is not None

        presentes = [l.split(":", 1)[1].strip() for l in sh("pm list packages").splitlines() if ":" in l]
        voulues = [a for a in ("com.android.chrome", "com.google.android.youtube", "com.google.android.apps.messaging",
                               "com.google.android.gm", "com.google.android.apps.photos", "com.google.android.apps.maps")
                   if a in presentes][:3] or ["com.android.settings"]
        for op in ("SYSTEM_ALERT_WINDOW", "GET_USAGE_STATS"):
            sh(f"appops set {PKG} {op} allow")
        # Un mardi ordinaire a 9 h 30 : ni Chabbat ni fete, pour que l'accueil propose la
        # hitbodedout du jour (le 14/11 etait un Chabbat : « pas de hitbodedout attendue »).
        sh("settings put global auto_time 0")
        log("  date :", sh("date 111709302026.00").strip())
        pause(10.0)

        for code in ("en", "he"):
            log(f"  --- fiche Play, {code}")
            # Une seance laissee en cours par une etape precedente fausserait l'accueil.
            if activite("SessionActivity") and toucher(rid="session_secondary", defilements=2, attente=1.0):
                toucher(rid="button1", attente=1.5)
            # Un lieu choisi (villes.json), pour que les zmanim et la boussole aient de quoi montrer.
            nom, lat, lon, fuseau, ville, israel = {
                "en": ("New York", "40.71427", "-74.00597", "America/New_York", 5128581, "false"),
                "he": ("ירושלים", "31.76904", "35.21633", "Asia/Jerusalem", 281184, "true"),
            }[code]
            regler({"onboarded_version": ("int", 2), "langue_app": ("string", code),
                    "enabled": ("boolean", "true"), "window_start": ("int", 360), "window_end": ("int", 660),
                    "snooze_minutes": ("int", 15), "apparence_accent": ("string", "vert"),
                    "lecture_sombre": ("boolean", "false"),
                    "lieu_nom": ("string", nom), "lieu_latitude": ("string", lat), "lieu_longitude": ("string", lon),
                    "lieu_altitude": ("string", "0.0"), "lieu_fuseau": ("string", fuseau),
                    "lieu_ville": ("long", ville), "lieu_t": ("long", 1794800000000), "in_israel": ("boolean", israel)})
            xml = re.sub(r'\s*<set name="blocked_apps">.*?</set>|\s*<set name="blocked_apps"\s*/>', "", lire_prefs(), flags=re.S)
            ensemble = '    <set name="blocked_apps">' + "".join(f"<string>{a}</string>" for a in voulues) + "</set>"
            ecrire_prefs(xml.replace("</map>", ensemble + "\n</map>"))
            journal_de_demonstration()
            langue(code)

            # Apres le changement de date, l'ecran d'attente du systeme (« Pixel is starting… »)
            # peut repasser devant : on attend que l'accueil soit vraiment la.
            for essai in range(5):
                lancer(attente=6)
                if trouver(rid="nav_texts") is not None or trouver(text={"en": "Continue", "he": "להמשיך"}[code]) is not None:
                    break
                log("  l'application n'est pas au premier plan : nouvel essai")
                pause(6.0)
            fermer_trophees(code)
            defiler(False)
            capture(f"play-{code}-accueil", attente=2.0)

            ok = toucher(rid="nav_texts", attente=2.0)
            defiler(False)
            capture(f"play-{code}-textes", ok=ok)

            # Le parcours (les trophees) et non le journal : JournalActivity porte FLAG_SECURE,
            # sa capture sort noire.
            ok = activite("PaliersActivity")
            capture(f"play-{code}-parcours", ok=ok, attente=2.5)
            retour()

            # L'ecran « Je suis avec Hachem », par son apercu des Reglages : sans effet, a toute
            # heure. Sa citation change a chaque ouverture : on en veut une sans le Nom.
            vu = False
            for essai in range(8):
                if not apercu_de_la_barriere(code):
                    break
                if not nom_en_toutes_lettres():
                    vu = True
                    break
                log("  le Nom en toutes lettres dans la citation : autre tirage")
                toucher(rid="blocker_primary", attente=1.5)
            capture(f"play-{code}-barriere", ok=vu)
            toucher(rid="blocker_primary", attente=1.5)

            ok = activite("SiddurLectureActivity", "--es id chaharit")
            capture(f"play-{code}-siddour", ok=ok, attente=3.0)
            retour()

            ok = activite("ZmanimActivity")
            capture(f"play-{code}-zmanim", ok=ok, attente=3.0)
            retour()

            ok = activite("BoussoleActivity")
            capture(f"play-{code}-boussole", ok=ok, attente=4.0)
            retour()

            # Le choix de la duree, avant de commencer : la seance en cours n'est qu'un
            # decompte sur fond sombre (la pratique calme efface le reste).
            ok = activite("SessionActivity")
            capture(f"play-{code}-seance", ok=ok, attente=2.5)
            retour()
            arreter()

        regler({"enabled": ("boolean", "false"), "langue_app": ("string", "fr")})
        langue("fr")
        sh("settings put global auto_time 1")
    etape("27 visuels Play", s27)

    # Les versions de l'application (VersionApp, 17/11) : l'ecran du choix, puis chaque accueil,
    # en faisant glisser ses cartes ; on revient a Classique pour la suite.
    def balayer():
        pause(1.0)
        sh(f"input swipe {int(W * 0.88)} {int(H * 0.45)} {int(W * 0.08)} {int(H * 0.45)} 450")
        pause(1.5)

    def s28():
        # En plein jour d'abord (17/11) : deux fois, l'emulateur s'est arrete le soir en ouvrant
        # un accueil au ciel dessine ; le ciel de nuit est essaye a part, en dernier (s28 nuit).
        sh("settings put global auto_time 0")
        log("  date :", sh("date 111712002026.00").strip())
        activite("ChoixVersionActivity")
        capture("28-choix-version")
        retour()
        regler({"version_app": ("string", "pile")})
        lancer(attente=6)
        capture("28-pile-1-hitbodedout")
        balayer()
        capture("28-pile-2-hizouk")
        if toucher(text="Voir la traduction", defilements=1, attente=1.5):
            capture("28-pile-2b-traduction")
        balayer()
        capture("28-pile-3-zmanim")
        balayer()
        capture("28-pile-4-journal")
        regler({"version_app": ("string", "bento")})
        lancer(attente=6)
        capture("28-bento-1")
        defiler(True)
        capture("28-bento-2-bas")
        regler({"version_app": ("string", "instant")})
        lancer(attente=6)
        capture("28-instant-1")
        defiler(True)
        capture("28-instant-2-bas")
        regler({"version_app": ("string", "serenite")})
        lancer(attente=6)
        capture("28-serenite-1")
        defiler(True)
        capture("28-serenite-2-bas")
        regler({"version_app": ("string", "classique")})
    etape("28 versions de l'app", s28)


    # Les versions sur un petit telephone (480x854, 240 dpi), puis avec le texte du systeme
    # agrandi (17/11) : chaque accueil, sans texte ecrase, et son bouton principal entier a l'ecran.
    def s29():
        for nom, echelle in (("petit", "1.0"), ("petit-gros-texte", "1.3")):
            sh("settings put system font_scale " + echelle)
            appliquer_taille("480x854", 240, False)
            sh("date 111712002026.00")
            pause(4)
            activite("ChoixVersionActivity")
            serre(nom, "choix-version")
            capture(f"29-{nom}-choix-version")
            retour()
            for version, bouton in (("serenite", "Modifier"), ("bento", "Commencer"), ("instant", "Commencer"), ("pile", "Commencer")):
                regler({"version_app": ("string", version)})
                lancer(attente=6)
                serre(nom, version)
                b = trouver(text=bouton, contains=True)
                if not b or b[3] > H or b[1] < 0:
                    faute(f"{nom} {version} : « {bouton} » pas entierement a l'ecran ({b}, ecran {W}x{H})")
                capture(f"29-{nom}-{version}")
                # Pas de geste ici : deux fois, l'emulateur s'est arrete au premier defilement
                # apres le changement de taille et de densite (17/11). Le haut de chaque accueil,
                # avec son bouton principal, est ce qui compte sur un petit ecran.
        sh("settings put system font_scale 1.0")
        appliquer_taille(None, None, False)
        regler({"version_app": ("string", "classique")})
        log("  fautes des petits ecrans :", [f for f in FAUTES if f.startswith("petit")])
    etape("29 versions sur petit ecran", s29)

    def s28n():
        log("  date :", sh("date 111721302026.00").strip())
        for version in ("instant", "serenite"):
            regler({"version_app": ("string", version)})
            lancer(attente=6)
            capture(f"28n-{version}-nuit")
        regler({"version_app": ("string", "classique")})
    etape("30 ciel de nuit", s28n)

    # Le defilement automatique des textes (verification du 24/11) : il part de la barre de lecture,
    # monte a la vitesse choisie (mesuree sur deux captures), change de vitesse en marche, garde la
    # vitesse d'un ecran et d'un lancement a l'autre, attend quand une autre fenetre passe devant,
    # garde l'ecran allume, et s'arrete au bouton, au toucher du texte (meme sur une carte qui prend
    # le toucher pour elle) et au bout du texte ; la barre et la commande en hebreu.
    def s31():
        regler({"lecture_sombre": ("boolean", "false"), "lecture_masquee": ("boolean", "false"),
                "lecture_echelle": ("float", "1.0"), "lecture_defilement_vitesse": ("int", 3),
                "langue_app": ("string", "fr")})
        langue("fr")
        log("  densite :", densite_ecran())

        # Le siddour (une liste recyclee) : vitesse 3, puis 10, puis 1 ; le bouton d'arret.
        activite("SiddurLectureActivity", "--es id chaharit")
        pause(2.0)
        icone = preparer_defilement("Réglages de lecture", "Défilement automatique")
        capture("31a-siddour-barre", ok=icone is not None)
        if icone is None:
            return
        touches = touches_commande(icone)
        log("  commande :", touches)
        lancer_defilement(icone)
        photo("31b-siddour-commande-vitesse-3")
        comparer_vitesse("siddour, vitesse 3", vitesse_mesuree(4.0), vitesse_attendue(3))
        taper(touches["plus"], 7)
        photo("31c-siddour-vitesse-10")
        comparer_vitesse("siddour, vitesse 10", vitesse_mesuree(1.5), vitesse_attendue(10))
        taper(touches["moins"], 12)
        photo("31d-siddour-vitesse-1")
        comparer_vitesse("siddour, vitesse 1 (douze fois moins)", vitesse_mesuree(4.0), vitesse_attendue(1))
        taper(touches["arret"])
        pause(1.0)
        if not immobile():
            faute("defilement siddour : le bouton d'arret ne l'arrete pas")
        if trouver(desc="Réglages de lecture") is None or trouver(desc="Arrêter le défilement") is not None:
            faute("defilement siddour : la pastille n'est pas revenue a l'arret")
        capture("31e-siddour-arrete")
        gardee = vitesse_gardee()
        log("  vitesse gardee :", gardee)
        if gardee != 1:
            faute(f"defilement : vitesse gardee {gardee} au lieu de 1")

        # Les Tehilim, application relancee : la vitesse 1 est restee ; une fenetre devant le met en
        # attente ; un doigt sur un verset (qui garde l'appui long des marque-pages) l'arrete.
        arreter()
        activite("TehilimLectureActivity", "--ei debut 119 --ei fin 119")
        pause(2.0)
        icone = preparer_defilement("Réglages de lecture", "Défilement automatique")
        if icone is None:
            capture("31f-tehilim", ok=False)
            return
        touches = touches_commande(icone)
        lancer_defilement(icone)
        photo("31f-tehilim-vitesse-1-gardee")
        comparer_vitesse("Tehilim, vitesse 1 gardee", vitesse_mesuree(3.0), vitesse_attendue(1))
        taper(touches["plus"], 2)
        comparer_vitesse("Tehilim, vitesse 3", vitesse_mesuree(3.0), vitesse_attendue(3))
        # Le volet des notifications devant : rien ne bouge tant qu'il est la, puis le texte repart.
        avant = ecran_brut()
        sh("cmd statusbar expand-notifications")
        pause(4.0)
        sh("cmd statusbar collapse")
        pause(0.3)
        apres = ecran_brut()
        if avant and apres:
            d = montee(avant, apres, int(H * 0.35))
            attendu = vitesse_attendue(3) * (apres[0] - avant[0])
            log(f"  volet ouvert {apres[0] - avant[0]:.1f} s : le texte a monte de {d} px ({attendu:.0f} sans attente)")
            if d is None or d > attendu * 0.5:
                faute(f"defilement Tehilim : il a continue derriere le volet ({d} px)")
        comparer_vitesse("Tehilim, reprise apres le volet", vitesse_mesuree(3.0), vitesse_attendue(3))
        sh(f"input tap {W // 2} {int(H * 0.40)}")
        pause(1.0)
        if not immobile():
            faute("defilement Tehilim : un doigt sur un verset ne l'arrete pas")
        capture("31g-tehilim-arrete-au-toucher")
        if trouver(desc="Arrêter le défilement") is not None:
            faute("defilement Tehilim : la commande reste apres le toucher")

        # Le bout du texte : presque en bas, a la vitesse 10, il s'arrete seul ; la fin se lit au-dessus
        # de la pastille revenue.
        for _ in range(30):
            sh(f"input swipe {W // 2} {int(H * 0.8)} {W // 2} {int(H * 0.2)} 60")
        pause(1.5)
        sh(f"input swipe {W // 2} {int(H * 0.35)} {W // 2} {int(H * 0.75)} 300")
        pause(1.5)
        icone = preparer_defilement("Réglages de lecture", "Défilement automatique")
        if icone is not None:
            touches = touches_commande(icone)
            lancer_defilement(icone)
            taper(touches["plus"], 7)
            if not attendre_arret(25):
                faute("defilement Tehilim : il ne s'arrete pas au bout du texte")
            pause(1.0)
            capture("31h-tehilim-fin-du-texte")
            if trouver(desc="Réglages de lecture") is None:
                faute("defilement Tehilim : pas de pastille au bout du texte")
            # Revenu a 3 pour la suite.
            regler({"lecture_defilement_vitesse": ("int", 3)})

        # Les hilloulot : pas de VeilleLecture, et des cartes qui prennent le toucher.
        activite("HilloulotActivity")
        pause(2.5)
        # Deux cartes depliees : le texte depasse alors l'ecran.
        for _ in range(2):
            toucher(desc="Lire la suite", contains=True, attente=1.5)
        sh(f"input swipe {W // 2} {int(H * 0.30)} {W // 2} {int(H * 0.75)} 200")
        pause(1.0)
        allume_avant = ecran_garde_allume()
        icone = preparer_defilement("Réglages de lecture", "Défilement automatique")
        racine = dump()
        carte = None
        for n in (racine.iter("node") if racine is not None else []):
            b = bornes(n)
            if b and n.get("clickable") == "true" and H * 0.30 < (b[1] + b[3]) / 2 < H * 0.60 \
                    and (b[3] - b[1]) > 120 and ("Lire la suite" in (n.get("content-desc") or "")
                                                 or "Réduire" in (n.get("content-desc") or "")):
                carte = b
                break
        log("  carte a toucher :", carte, "| ecran allume avant :", allume_avant)
        if icone is None or carte is None:
            capture("31i-hilloulot", ok=False)
            return
        lancer_defilement(icone)
        t0 = time.time()
        allume = ecran_garde_allume()
        photo("31i-hilloulot-defile")
        if not allume:
            faute("defilement hilloulot : l'ecran n'est pas garde allume pendant qu'il defile")
        # La carte a monte depuis le depart (une seconde avant t0) : on la suit, le temps du toucher compris.
        y = int((carte[1] + carte[3]) / 2 - vitesse_attendue(3) * (time.time() - t0 + 1.4))
        log(f"  toucher de la carte a y={y}")
        sh(f"input tap {W // 2} {y}")
        pause(1.0)
        if not immobile():
            faute("defilement hilloulot : un doigt sur une carte ne l'arrete pas")
        capture("31j-hilloulot-arrete-sur-une-carte")
        log("  ecran allume apres l'arret :", ecran_garde_allume())

        # En hebreu, lettres a 150 % : la barre, la commande, la vitesse en lignes ; le bouton d'arret.
        regler({"lecture_echelle": ("float", "1.5")})
        langue("he")
        activite("SiddurLectureActivity", "--es id chaharit")
        pause(2.0)
        icone = preparer_defilement("הגדרות קריאה", "גלילה אוטומטית")
        capture("31k-he-barre", ok=icone is not None)
        if icone is not None:
            touches = touches_commande(icone)
            lancer_defilement(icone)
            photo("31l-he-commande")
            comparer_vitesse("hebreu, vitesse 3 a 150 %", vitesse_mesuree(4.0), vitesse_attendue(3, 1.5))
            taper(touches["arret"])
            pause(1.0)
            if not immobile():
                faute("defilement hebreu : le bouton d'arret ne l'arrete pas")
            if trouver(desc="הגדרות קריאה") is None:
                faute("defilement hebreu : la pastille n'est pas revenue a l'arret")
        regler({"lecture_echelle": ("float", "1.0"), "lecture_defilement_vitesse": ("int", 3)})
        langue("fr")
    etape("31 defilement automatique", s31)

    log("\ncaptures :", sorted(os.listdir(OUT)))


# --- Tailles d'ecran -----------------------------------------------------------
# Le parcours ci-dessus ne voit qu'un Pixel 6. La presentation s'est revelee
# illisible sur un 480x854 (titre, texte et boutons sous le bord) : chaque
# taille parcourt ici les sept ecrans de la presentation, en verifiant que
# titre, texte et « Suivant » se voient sans defiler, puis capture l'accueil,
# l'onglet des textes et la seance. Un ecran fautif est marque « HORS-ECRAN »
# dans son nom et compte dans le bilan du journal.

TAILLES = [
    # nom, taille physique forcee (ou None), densite (ou None), couche.
    # Les ecrans couches d'abord : ce sont ceux qui ont le plus change, et
    # l'emulateur finit parfois par se figer (« QEMU2 main loop ») sur la
    # grande tablette apres une demi-heure.
    ("petit-couche", "480x854", 240, True),
    ("tablette-couchee", "1600x2560", 320, True),
    # Taille forcee, comme les autres : apres un « wm size reset », le
    # Pixel 6 restait couche et ses captures debout sortaient en paysage.
    ("pixel6-couche", "1080x2400", 420, True),
    ("petit", "480x854", 240, False),
    # Le petit telephone avec le texte agrandi du systeme (15/10, « responsive
    # sur petite taille ») : la combinaison qui casse le plus de lignes.
    ("petit-gros-texte", "480x854", 240, False),
    ("pixel6", "1080x2400", 420, False),
    ("tablette", "1600x2560", 320, False),
]


def appliquer_taille(taille, densite, couche):
    global W, H
    sh("settings put system accelerometer_rotation 0")
    sh(f"settings put system user_rotation {1 if couche else 0}")
    sh("wm size " + (taille or "reset"))
    sh("wm density " + (str(densite) if densite else "reset"))
    pause(2.5)
    # Apres un ecran couche, le retour debout ne prenait pas toujours : les
    # captures « debout » du petit telephone et du Pixel 6 sortaient en
    # paysage. On regarde l'ecran lui-meme, et on insiste.
    for essai in range(4):
        png = adb("exec-out", "screencap", "-p", binary=True)
        if len(png) > 24 and png[:8] == b"\x89PNG\r\n\x1a\n":
            larg, haut = int.from_bytes(png[16:20], "big"), int.from_bytes(png[20:24], "big")
            if (larg > haut) == couche:
                break
            log(f"  orientation {larg}x{haut} inattendue, essai {essai + 1}")
        sh(f"settings put system user_rotation {0 if couche else 1}")
        pause(1.5)
        sh(f"settings put system user_rotation {1 if couche else 0}")
        pause(2.5)
    m = re.search(r"Override size: (\d+)x(\d+)", sh("wm size")) or re.search(r"(\d+)x(\d+)", sh("wm size"))
    w, h = (int(m.group(1)), int(m.group(2))) if m else (1080, 2400)
    W, H = (max(w, h), min(w, h)) if couche else (min(w, h), max(w, h))
    log(f"  ecran : {W}x{H}, densite {sh('wm density').strip()}")


FAUTES = []


def faute(texte):
    """Une faute de mise en page : dans le bilan, et tout de suite au journal."""
    FAUTES.append(texte)
    log("  FAUTE : " + texte)


# --- Le defilement automatique (verification du 24/11) ---------------------------------
# Pendant que le texte defile, uiautomator ne lit pas l'ecran : il attend un ecran immobile (une
# seconde sans evenement d'accessibilite), et chaque pas en envoie un. On mesure donc sur des
# captures brutes, et on touche la commande a des places deduites de la barre depliee, lue avant.

def ecran_brut():
    """L'instant, puis l'ecran en pixels : screencap sans -p (un en-tete de 12 ou 16 octets, puis RGBA)."""
    t = time.time()
    b = adb("exec-out", "screencap", binary=True, timeout=60)
    if len(b) < 16:
        return None
    w, h = int.from_bytes(b[0:4], "little"), int.from_bytes(b[4:8], "little")
    entete = len(b) - w * h * 4
    if w <= 0 or h <= 0 or entete not in (12, 16):
        log(f"  screencap brut illisible ({len(b)} octets, {w}x{h})")
        return None
    return t, w, h, b[entete:]


def empreintes(image):
    """Une empreinte par ligne de pixels, prise entre 10 et 80 % de la largeur (ni les marges, ni le
    niveau de lecture du bord droit) ; None pour une ligne presque unie, qui irait avec toute autre."""
    _, w, h, px = image
    x0, x1 = int(w * 0.10), int(w * 0.80)
    lignes = []
    for y in range(h):
        rangee = px[(y * w + x0) * 4:(y * w + x1) * 4:12]  # le rouge d'un pixel sur trois
        lignes.append(hash(rangee) if len(set(rangee)) > 2 else None)
    return lignes


def montee(avant, apres, plus_loin):
    """De combien de pixels le texte est monte entre deux images : l'ecart d pour lequel le plus de
    lignes de « apres » (entre 25 et 60 % de la hauteur) valent celles de « avant » d plus bas.
    None si rien ne s'accorde assez."""
    a, b = empreintes(avant), empreintes(apres)
    h = len(a)
    bas = int(h * 0.60)
    lignes = [y for y in range(int(h * 0.25), bas) if b[y] is not None]
    if len(lignes) < 20:
        log(f"  trop peu de lignes de texte pour mesurer ({len(lignes)})")
        return None
    meilleur, score = None, 0
    for d in range(0, max(1, min(plus_loin, h - bas))):
        n = sum(1 for y in lignes if a[y + d] == b[y])
        if n > score:
            meilleur, score = d, n
    if score < len(lignes) * 0.5:
        log(f"  ecart incertain : {score}/{len(lignes)} lignes pour {meilleur} px")
        return None
    return meilleur


def vitesse_mesuree(duree):
    """Les pixels par seconde dont le texte monte, sur deux captures brutes a « duree » secondes."""
    a = ecran_brut()
    pause(duree)
    b = ecran_brut()
    if not a or not b:
        return None
    d = montee(a, b, int(a[2] * 0.35))
    return None if d is None else d / max(0.1, b[0] - a[0])


def densite_ecran():
    m = re.search(r"(\d+)\s*$", sh("wm density").strip())
    return int(m.group(1)) / 160.0 if m else 2.625


def vitesse_attendue(niveau, echelle=1.0):
    """DefilementAuto.vitesse : 6 dp par seconde fois 1,4^(n-1), fois la taille des lettres, en pixels."""
    return 6 * 1.4 ** (niveau - 1) * echelle * densite_ecran()


def comparer_vitesse(quoi, mesuree, attendue):
    if mesuree is None:
        faute(f"defilement {quoi} : vitesse non mesuree")
        return
    ecart = abs(mesuree - attendue) / attendue
    log(f"  vitesse {quoi} : {mesuree:.1f} px/s mesures, {attendue:.1f} attendus ({ecart:.0%} d'ecart)")
    if ecart > 0.35:
        faute(f"defilement {quoi} : {mesuree:.1f} px/s au lieu de {attendue:.1f}")


def immobile(duree=1.5):
    """Vrai si le texte n'a pas bouge pendant « duree » secondes."""
    a = ecran_brut()
    pause(duree)
    b = ecran_brut()
    if not a or not b:
        return None
    return montee(a, b, 80) == 0


def attendre_arret(au_plus):
    fin = time.time() + au_plus
    while time.time() < fin:
        if immobile(1.0):
            return True
    return False


def photo(nom):
    """Une capture sans lire l'ecran (uiautomator ne le lit pas pendant le defilement)."""
    png = adb("exec-out", "screencap", "-p", binary=True)
    chemin = os.path.join(OUT, nom + ".png")
    with open(chemin, "wb") as f:
        f.write(png)
    log(f"  capture {chemin} ({len(png)} octets)")


def touches_commande(icone_defiler):
    """Les centres de « moins vite », « plus vite » et « arreter » de la commande du defilement, d'apres
    le bouton du defilement dans la barre depliee (ReglagesLecture) : la commande a le bas et la hauteur
    de la barre, elle est centree, et elle aligne 4 dp, « − » (48), la vitesse (40), « + » (48), un filet
    (1 + 2 x 4), l'icone d'arret (de la largeur de celles de la barre), 4 dp."""
    x1, y1, x2, y2 = icone_defiler
    d = densite_ecran()

    def dp(v):
        return int(v * d + 0.5)
    icone = x2 - x1
    largeur = dp(4) + dp(48) + dp(40) + dp(48) + dp(1) + 2 * dp(4) + icone + dp(4)
    gauche = (W - largeur) // 2
    y = (y1 + y2) // 2
    return {
        "moins": (gauche + dp(4) + dp(48) // 2, y),
        "plus": (gauche + dp(4) + dp(48) + dp(40) + dp(48) // 2, y),
        "arret": (gauche + dp(4) + dp(48) + dp(40) + dp(48) + dp(1) + 2 * dp(4) + icone // 2, y),
    }


def taper(xy, fois=1, attente=0.35):
    for _ in range(fois):
        sh(f"input tap {xy[0]} {xy[1]}")
        pause(attente)


def vitesse_gardee():
    m = re.search(r'name="lecture_defilement_vitesse" value="(-?\d+)"', lire_prefs())
    return int(m.group(1)) if m else None


def ecran_garde_allume():
    """Le drapeau KEEP_SCREEN_ON de la fenetre au premier plan (dumpsys window), None si introuvable."""
    sortie = sh("dumpsys window windows", timeout=60)
    m = re.search(r"mCurrentFocus=Window\{(\w+) ", sortie)
    if not m:
        log("  fenetre au premier plan introuvable")
        return None
    i = sortie.find("Window{" + m.group(1))
    fin = sortie.find("Window #", i + 10)
    bloc = sortie[i:fin if fin > 0 else i + 4000]
    fl = re.search(r"\bfl=([A-Z_0-9 ]+)", bloc)
    log("  fenetre", bloc.split("\n", 1)[0][:120], "| fl=", fl.group(1).strip() if fl else "?")
    return "KEEP_SCREEN_ON" in bloc


def preparer_defilement(desc_reglages, desc_defiler):
    """Deplie la barre et rend la place du bouton du defilement, sans le toucher encore."""
    if not toucher(desc=desc_reglages, attente=1.2):
        return None
    b = trouver(desc=desc_defiler)
    if b is None:
        journal_ecran("bouton du defilement introuvable")
    return b


def lancer_defilement(icone):
    x, y = (icone[0] + icone[2]) // 2, (icone[1] + icone[3]) // 2
    log(f"  defilement lance ({x},{y})")
    sh(f"input tap {x} {y}")
    pause(1.0)

# Chaque activite de l'application (AndroidManifest.xml), avec ce qu'il lui
# faut pour s'ouvrir sur un contenu reel.
ECRANS_APP = [
    ("SettingsActivity", ""),
    ("SessionActivity", ""),
    ("CelebrationActivity", "--ei minutes 20"),
    ("JournalActivity", ""),
    ("TipsActivity", ""),
    ("RemindersActivity", ""),
    ("MusicActivity", ""),
    ("SiddurActivity", ""),
    ("SiddurLectureActivity", "--es id chaharit"),
    ("TefilotActivity", ""),
    ("TehilimActivity", ""),
    ("TehilimLectureActivity", "--ei debut 1 --ei fin 1"),
    ("TikkunFlowActivity", ""),
    ("LibraryActivity", ""),
    ("LibraryEntryActivity", "--es entry_id src-lm2-25"),
    ("ZmanimActivity", ""),
    ("CalendrierActivity", ""),
    ("HalakhaActivity", ""),
    ("HilloulotActivity", ""),
    ("RechercheActivity", ""),
    ("PaliersActivity", ""),
]


def serre(nom, ecran):
    """Les textes ecrases (une lettre par ligne) ou colles au bord de l'ecran."""
    racine = dump()
    if racine is None:
        return
    for n in racine.iter("node"):
        b = bornes(n)
        texte = (n.get("text", "") or "").strip()
        if not b or len(texte) < 6 or "TextView" not in n.get("class", "") and "Button" not in n.get("class", ""):
            continue
        larg = b[2] - b[0]
        if larg < W * 0.14 and len(texte) > 10:
            faute(f"{nom} {ecran} : texte ecrase ({larg}px) « {texte[:30]} »")
        elif b[0] <= 0 or b[2] >= W:
            faute(f"{nom} {ecran} : texte colle au bord {b} « {texte[:30]} »")


def visibles(racine, rids):
    """Les identifiants dont le noeud est entierement a l'ecran."""
    vus = set()
    if racine is None:
        return vus
    for n in racine.iter("node"):
        b = bornes(n)
        rid = (n.get("resource-id", "") or "").split("/")[-1]
        if rid in rids and b and b[3] <= H and b[1] >= 0 and (b[3] - b[1]) > 8:
            vus.add(rid)
    return vus


def presentation(nom, langue_app="fr"):
    regler({"onboarded_version": ("int", 0), "langue_app": ("string", langue_app)})
    langue(langue_app)
    sh(f"am start -W -n {PKG}/com.myhitbodedut.MainActivity", timeout=60)
    pause(4.0)
    for i in range(1, 8):
        racine = dump()
        voulus = {"onboarding_title", "onboarding_body", "onboarding_next"}
        vus = visibles(racine, voulus)
        manque = sorted(voulus - vus)
        suffixe = "" if not manque else "-HORS-ECRAN"
        if manque:
            faute(f"{nom} ecran {i} : {', '.join(manque)} hors de l'ecran")
        capture(f"20-{nom}-presentation-{i}{suffixe}", attente=0.3)
        if not toucher(rid="onboarding_next", attente=1.2):
            faute(f"{nom} ecran {i} : « Suivant » introuvable")
            break


def tailles():
    for nom, taille, densite, couche in TAILLES:
        log(f"\n--- taille {nom} ---")
        sh("settings put system font_scale " + ("1.3" if nom.endswith("gros-texte") else "1.0"))
        appliquer_taille(taille, densite, couche)
        presentation(nom)
        lancer()
        # « Commencer » doit finir au-dessus des onglets, pas seulement de l'ecran.
        racine = dump()
        bouton = onglets = None
        for n in (racine.iter("node") if racine is not None else []):
            rid = (n.get("resource-id", "") or "").split("/")[-1]
            if rid == "start_session":
                bouton = bornes(n)
            elif rid == "bottom_nav":
                onglets = bornes(n)
        # uiautomator rogne les bornes a la partie visible : un bouton coupe
        # par les onglets finit pile sur leur bord. On exige un peu d'air.
        limite = onglets[1] if onglets else H
        if not bouton or bouton[3] >= limite - 2 or bouton[1] < 0:
            faute(f"{nom} accueil : « Commencer » cache (bouton {bouton}, onglets a {limite})")
        serre(nom, "accueil")
        capture(f"20-{nom}-accueil")
        defiler(True)
        serre(nom, "accueil-suite")
        capture(f"20-{nom}-accueil-suite")
        onglet_textes()
        capture(f"20-{nom}-textes")
        # Tous les autres ecrans de l'application, ouverts directement. Sur
        # tablette, en passage court, seulement la seance et les reglages :
        # l'emulateur et le runner lachent apres une demi-heure de grandes
        # captures, et rien n'est alors publie.
        ecrans = ECRANS_APP
        if nom.startswith("tablette") and os.environ.get("CAPTURES_TAILLES_SEULES") == "1":
            ecrans = [e for e in ECRANS_APP if e[0] in ("SettingsActivity", "SessionActivity")]
        for classe, extras in ecrans:
            arreter()
            if activite(classe, extras):
                # Debout comme couchee, « Commencer » se voit sans defiler.
                if classe == "SessionActivity" and "session_primary" not in visibles(dump(), {"session_primary"}):
                    faute(f"{nom} seance : « Commencer » hors de l'ecran")
                serre(nom, classe)
                capture(f"20-{nom}-{classe.replace('Activity', '').lower()}", attente=0.8)
        if nom in ("petit", "petit-couche", "pixel6-couche"):
            presentation(nom + "-he", "he")
    sh("settings put system font_scale 1.0")
    appliquer_taille(None, None, False)
    regler({"langue_app": ("string", "fr")})
    langue("fr")
    log("\n=== bilan des tailles ===")
    log("\n".join(FAUTES) if FAUTES else
        "presentation (titre, texte, « Suivant »), accueil et seance (« Commencer ») visibles a toutes les tailles")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log("ERREUR generale :", repr(e))
    sys.exit(0)
