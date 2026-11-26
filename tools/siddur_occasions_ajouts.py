# -*- coding: utf-8 -*-
"""
Les textes d'occasion absents du siddour (demande du 26/11/2026, Q15 : « ajouter הרחמן de la brit mila,
Birkat haMazon de la maison endeuillée (נחם), Mi chébérakh ; et rajoute d'autres sans exagérer, c'est-à-dire
les plus fréquents — tous repliés comme ajouts d'occasion »).

Rien n'est retapé ni écrit de mémoire : chaque passage est repris tel quel de l'export public de Sefaria, par
les fonctions de tools/siddur_construction.py (bloc : balises, Nom en toutes lettres, guershayim). Seules les
consignes d'en-tête, qui disent l'occasion (« בבית האבל… », « מי שברך לחולה: »), sont de l'application.
tools/siddur_annotations.py les replie ensuite (conditions d'occasion, jamais vraies) :

  - Edot, Birkat haMazon de la maison endeuillée : Siddur Edot HaMizrach, « Fast Days and Mourning, Mourning »,
    ברכת המזון לאבלים (Shaliehsaboo Edition, CC0) : le zimoun « מנחם אבלים », « נחם » à la place de « ותבנה
    ירושלים… בונה ירושלים », la quatrième bénédiction de la maison endeuillée ; trois replis « בבית האבל ».
    Sfard et Ashkenaz : aucune source libre (Sefaria n'a ni le Metsudah ni Torat Emet pour ce texte) ; rien.
  - Sfard, les הרחמן du repas de brit mila : Siddur Sefard, « Birchat HaMazon, Brit Milah » (Torat Emet 357,
    domaine public), avant les הרחמן des jours. Ashkenaz : le même texte, emprunté au Sfard et marqué (la
    convention des textes empruntés, tools/siddur_occasions.py) ; ces הרחמן sont d'origine ashkénaze. Edot :
    leur usage n'est pas celui-là, et leurs sources libres n'en ont pas ; rien.
  - Mi chébérakh dans la lecture de la Torah de Cha'harit, après la bénédiction finale de l'oleh : pour qui monte,
    pour un malade, et pour une accouchée (le plus fréquent après eux : la naissance d'un fils, d'une fille et son
    nom). Sfard : « Shabbat Morning Services, Prayer for Oleh / Prayer for Sick / Prayer for Mother after
    Chilbirth » (Torat Emet 357, domaine public). Ashkenaz : « Shabbat, Shacharit, Torah Reading, Reading from
    Sefer, Mi Sheberach, For an Oleh / For Sickness / For Birth » (Daat Siddur Ashkenaz, domaine public). Edot :
    Sefaria n'a que « מי שברך לקהל » ; rien.

Entrée : le dossier des réponses de l'API de Sefaria (https://www.sefaria.org/api/v3/texts/<réf>?version=hebrew|all),
enregistrées telles quelles, une par fichier, nommées par la référence (« Siddur_Sefard,_Birchat_HaMazon,_Brit_Milah »,
les caractères hors [A-Za-z0-9_] remplacés par « _ », suivis de « .json »). Idempotent : chaque ajout, repéré par
sa consigne d'en-tête, est retiré puis remis. Sans dossier, rien n'est fait si tout est déjà en place.

  python3 tools/siddur_occasions_ajouts.py <dossier> && python3 tools/siddur_annotations.py
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import siddur_construction as sc  # noqa: E402

RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "android", "app", "src", "main", "res", "raw")

# Les consignes d'en-tête (de l'application) : elles repèrent les ajouts, pour les retirer avant de les remettre.
AVEL_ZIMOUN = "בבית האבל, הזימון:"
AVEL_NAHEM = "בבית האבל, במקום „ותבנה ירושלים“:"
AVEL_HATOV = "בבית האבל, במקום ברכת „הטוב והמטיב“:"
BRIT = "סדר הרחמן לסעודת ברית מילה:"
BRIT_EMPRUNT = "סדר הרחמן לסעודת ברית מילה (נוסח סידור ספרד, תורת אמת):"
MS_OLEH = "מי שברך לעולה לתורה:"
MS_MALADE = "מי שברך לחולה:"
MS_YOLEDET = "מי שברך ליולדת:"
EN_TETES = (AVEL_ZIMOUN, AVEL_NAHEM, AVEL_HATOV, BRIT, BRIT_EMPRUNT, MS_OLEH, MS_MALADE, MS_YOLEDET)

SOURCES = {
    "edot": "Siddur Edot HaMizrach, Fast Days and Mourning, Mourning — ברכת המזון לאבלים (Shaliehsaboo Edition, CC0)",
    "sefard": ("Siddur Sefard, Birchat HaMazon, Brit Milah ; Shabbat Morning Services, Prayer for Oleh, Prayer for Sick, "
               "Prayer for Mother after Chilbirth (Torat Emet 357, Public Domain)"),
    "ashkenaz": ("Siddur Ashkenaz, Shabbat, Shacharit, Torah Reading, Mi Sheberach (Daat Siddur Ashkenaz, Public Domain) ; "
                 "Siddur Sefard, Birchat HaMazon, Brit Milah (Torat Emet 357, Public Domain), emprunté"),
}


def fichier(dossier, ref):
    return os.path.join(dossier, re.sub(r"[^A-Za-z0-9_\n]", "_", ref) + ".json")


def segments(dossier, ref, version):
    """Les segments de [ref] dans la version [version] (titre exact), dans l'ordre."""
    api = json.load(open(fichier(dossier, ref), encoding="utf-8"))
    v = next(v for v in api["versions"] if v["versionTitle"].strip() == version)
    return list(sc.aplatit(v["text"]))


def blocs(segs):
    return [b for b in (sc.bloc(s) for s in segs) if b]


def plat(b):
    return re.sub(r"[֑-ׇ]", "", re.sub(r"<[^>]+>", "", b.get("t") or b.get("c") or ""))


def sans_ajouts(blocs_):
    """Les blocs sans les ajouts de cet outil : chaque consigne d'en-tête et les blocs qui la suivent (TAILLES)."""
    sortie, k = [], 0
    while k < len(blocs_):
        b = blocs_[k]
        if b.get("c") in EN_TETES:
            # Le nombre de blocs de chaque ajout est rangé à part (TAILLES) : la donnée ne garde que le texte.
            k += 1 + TAILLES[b["c"]]
            continue
        sortie.append(b)
        k += 1
    return sortie


# Combien de blocs suivent chaque consigne d'en-tête (posé par chaque noussa'h avant d'enlever ses ajouts).
TAILLES = {}


def inserer(blocs_, apres, ajout):
    """[ajout] juste après le premier bloc dont le texte (sans voyelles) commence par [apres]."""
    i = next(k for k, b in enumerate(blocs_) if plat(b).startswith(apres))
    blocs_[i + 1:i + 1] = ajout


def inserer_avant(blocs_, avant, ajout):
    i = next(k for k, b in enumerate(blocs_) if plat(b).startswith(avant))
    blocs_[i:i] = ajout


def texte(d, id_):
    return next(t for t in d["textes"] if t["id"] == id_)


def edot(d, dossier):
    seg = segments(dossier, "Siddur_Edot_HaMizrach,_Fast_Days_and_Mourning,_Mourning", "Shaliehsaboo Edition")
    debut = next(k for k, s in enumerate(seg) if "ברכת המזון לאבלים" in s)
    # « קַדִּישָׁא:צ<small> » : une lettre égarée de l'export Shaliehsaboo (la version Torat Emet du même passage ne
    # l'a pas) ; seule correction apportée au texte.
    zimoun = blocs([seg[debut + 1].replace(":צ<small>", ": <small>")] + seg[debut + 2:debut + 4])
    nahem = blocs([next(s for s in seg[debut:] if plat({"t": s}).startswith("נחם"))])
    hatov = blocs([next(s for s in seg[debut:] if "המלך החי הטוב והמטיב" in plat({"t": s}))])
    assert len(zimoun) == 3 and "מנחם אבלים" in plat(zimoun[0]), zimoun
    assert len(nahem) == 1 and "מנחם ציון בבנין ירושלים" in plat(nahem[0]), nahem
    assert len(hatov) == 1 and "גודר פרצות" in plat(hatov[0]), hatov
    TAILLES.update({AVEL_ZIMOUN: 3, AVEL_NAHEM: 1, AVEL_HATOV: 1})
    bm = texte(d, "birkat_hamazon")["sections"][0]
    b = sans_ajouts(bm["blocs"])
    inserer_avant(b, "ברוך אתה יהוה, אלהינו מלך העולם, האל הזן", [{"c": AVEL_ZIMOUN}] + zimoun)
    inserer_avant(b, "ותבנה ירושלים עירך", [{"c": AVEL_NAHEM}] + nahem)
    inserer_avant(b, "ברוך אתה יהוה, אלהינו מלך העולם, (לעד) האל אבינו", [{"c": AVEL_HATOV}] + hatov)
    bm["blocs"] = b


def brit(dossier):
    seg = segments(dossier, "Siddur_Sefard,_Birchat_HaMazon,_Brit_Milah", "Torat Emet 357")
    b = blocs(seg[1:8])
    assert b[0].get("c") == BRIT and len(b) == 7 and all(plat(x).startswith("הרחמן") for x in b[1:]), b
    return b


def sfard(d, dossier):
    TAILLES.update({BRIT: 6})
    bm = texte(d, "birkat_hamazon")["sections"][0]
    b = sans_ajouts(bm["blocs"])
    inserer(b, "במרום ילמדו עליהם", brit(dossier))
    bm["blocs"] = b
    oleh = blocs(segments(dossier, "Siddur_Sefard,_Shabbat_Morning_Services,_Prayer_for_Oleh", "Torat Emet 357"))
    malade = blocs(segments(dossier, "Siddur_Sefard,_Shabbat_Morning_Services,_Prayer_for_Sick", "Torat Emet 357"))
    yoledet = blocs(segments(dossier, "Siddur_Sefard,_Shabbat_Morning_Services,_Prayer_for_Mother_after_Chilbirth", "Torat Emet 357"))
    assert oleh[0].get("c") == MS_OLEH and len(oleh) == 2, oleh
    assert [list(x)[0] for x in malade] == ["c", "t", "c", "t"] and [list(x)[0] for x in yoledet] == ["c", "t", "c", "t"]
    lecture(d, oleh + [{"c": MS_MALADE}] + malade + [{"c": MS_YOLEDET}] + yoledet, {MS_OLEH: 1, MS_MALADE: 4, MS_YOLEDET: 4})


def ashkenaz(d, dossier):
    TAILLES.update({BRIT_EMPRUNT: 6})
    bm = texte(d, "birkat_hamazon")["sections"][0]
    b = sans_ajouts(bm["blocs"])
    emprunt = brit(dossier)
    inserer(b, "במרום ילמדו עליהם", [{"c": BRIT_EMPRUNT}] + emprunt[1:])
    bm["blocs"] = b
    base = "Siddur_Ashkenaz,_Shabbat,_Shacharit,_Torah_Reading,_Reading_from_Sefer,_Mi_Sheberach,_"
    oleh = blocs(segments(dossier, base + "For_an_Oleh", "Daat Siddur Ashkenaz"))
    malade = blocs(segments(dossier, base + "For_Sickness_(includes_man_and_woman)", "Daat Siddur Ashkenaz"))
    fils = blocs(segments(dossier, base + "For_Birth,_Birth_of_a_Son", "Daat Siddur Ashkenaz"))
    fille = blocs(segments(dossier, base + "For_Birth,_Birth_of_Daughter", "Daat Siddur Ashkenaz"))
    assert len(oleh) == 1 and len(malade) == 2 and len(fils) == 1 and len(fille) == 1
    assert all("t" in x for x in oleh + malade + fils + fille)
    lecture(d, [{"c": MS_OLEH}] + oleh + [{"c": MS_MALADE}] + malade + [{"c": MS_YOLEDET}] + fils + fille,
            {MS_OLEH: 1, MS_MALADE: 2, MS_YOLEDET: 2})


def lecture(d, ajout, tailles):
    """Les Mi chébérakh, après la bénédiction de l'oleh après la lecture (« אשר נתן לנו תורת אמת »)."""
    TAILLES.update(tailles)
    sec = next(s for s in texte(d, "chaharit")["sections"] if plat({"c": s["titre"]}).strip() == "קריאת התורה")
    b = sans_ajouts(sec["blocs"])
    inserer(b, "ברוך אתה יהוה אלהינו מלך העולם אשר נתן לנו תורת", ajout)
    sec["blocs"] = b


def main(dossier):
    for nusah, fn in (("edot", edot), ("sefard", sfard), ("ashkenaz", ashkenaz)):
        nom = os.path.join(RAW, f"siddur_{nusah}.json")
        d = json.load(open(nom, encoding="utf-8"))
        if not dossier or not os.path.isdir(dossier):
            presents = [b.get("c") for t in d["textes"] for s in t["sections"] for b in s["blocs"] if b.get("c") in EN_TETES]
            if not presents:
                sys.exit(f"Réponses de Sefaria introuvables ({dossier}) et ajouts absents de {nom}")
            print(nusah, ": ajouts déjà présents, rien à faire")
            continue
        fn(d, dossier)
        if SOURCES[nusah] not in d["_meta"]["sources"]:
            d["_meta"]["sources"] = sorted(d["_meta"]["sources"] + [SOURCES[nusah]])
        json.dump(d, open(nom, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
        print(nusah, ": ajouts d'occasion insérés")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
