#!/usr/bin/env python3
"""
TEFILA-02 (audit du 12/11) : les seize blocs « c » de Tefila LiChlomo (tefila_lishlomo dans
livres.json) — dix lignes d'auteur et de droits, six consignes (« à dire sept fois de suite »,
« chaque jour et à l'allumage des bougies »…) — restaient en hébreu seul en français et en
anglais. Ce script leur ajoute c_fr et c_en, que les deux lecteurs montrent selon les langues
de lecture choisies (SiddurLoader, SiddurLectureActivity ; LanguesTexte.bloc sur le site).

Traductions relues une à une sur l'hébreu (15/11) : en français, l'espace insécable avant le
deux-points, comme dans le reste du livre ; ה׳ rendu « Hachem » / « Hashem », comme le corps du
texte ; זיע״א, « que son mérite nous protège, amen ».

Idempotent : un second passage ne change rien. Puis tools/livres_decoupe.py.
Usage : python3 tools/traductions_14-11/trad-TEFILA-consignes.py <racine du dépôt>
"""
import json, os, subprocess, sys

racine = os.path.abspath(sys.argv[1])
src = os.path.join(racine, "android/app/src/main/livres/livres.json")
d = json.load(open(src, encoding="utf-8"))
NB = " "  # insécable : « jour : »
FIN_FR = " · Tous droits réservés à l’Institut Yam Chlomo"
FIN_EN = " · All rights reserved by the Yam Shlomo Institute"
CRED = " · כל הזכויות שמורות למכון ׳ים שלמה׳"
T = {
 "מאת גאון ישראל רבנו שלמה יהודה בארי שליט״א הינוקא"+CRED:
  ("Par le Gaon d’Israël, notre maître Rabbi Chlomo Yehouda Beeri chlita, le Yanouka"+FIN_FR,
   "By the Gaon of Israel, our teacher Rabbi Shlomo Yehuda Be’eri shlita, the Yanuka"+FIN_EN),
 "מאת הגאון הינוקא רבנו שלמה יהודה שליט״א"+CRED:
  ("Par le Gaon, le Yanouka, notre maître Rabbi Chlomo Yehouda chlita"+FIN_FR,
   "By the Gaon, the Yanuka, our teacher Rabbi Shlomo Yehuda shlita"+FIN_EN),
 "מאת גאון ישראל הינוקא רבנו שלמה יהודה בארי שליט״א"+CRED:
  ("Par le Gaon d’Israël, le Yanouka, notre maître Rabbi Chlomo Yehouda Beeri chlita"+FIN_FR,
   "By the Gaon of Israel, the Yanuka, our teacher Rabbi Shlomo Yehuda Be’eri shlita"+FIN_EN),
 "מאת הגאון הינוקא רבנו שלמה יהודה בארי שליט״א"+CRED:
  ("Par le Gaon, le Yanouka, notre maître Rabbi Chlomo Yehouda Beeri chlita"+FIN_FR,
   "By the Gaon, the Yanuka, our teacher Rabbi Shlomo Yehuda Be’eri shlita"+FIN_EN),
 "לאיש": ("Pour un homme", "For a man"),
 "יש לומר בכל יום:": ("À dire chaque jour"+NB+":", "To be said every day:"),
 "יש לומר בכל יום ובערב שבת בהדלקת נרות":
  ("À dire chaque jour, et la veille de Chabbat à l’allumage des bougies",
   "To be said every day, and on Shabbat eve at candle lighting"),
 "סדר לימוד קריאה ותפילה לפני ה׳ יתברך שתימשך רפואה שלימה עלינו ועל כל ישראל":
  ("Ordre d’étude, de lecture et de prière devant Hachem, béni soit-Il, pour qu’une guérison complète soit attirée sur nous et sur tout Israël",
   "Order of study, reading and prayer before Hashem, blessed be He, that complete healing be drawn upon us and upon all Israel"),
 "יאמר 7 פעמים ברציפות הלחש מדרבי פנחס מקוריץ זיע״א:":
  ("On dit sept fois de suite le la’hach de Rabbi Pin’has de Korets, que son mérite nous protège, amen"+NB+":",
   "One says seven times in a row the lachash of Rabbi Pinchas of Koretz, may his merit protect us, amen:"),
 "ואחר כך יתפלל תפילת חזקיהו בקומו מחליו:":
  ("Ensuite, on dit la prière de ’Hizkiyahou lorsqu’il se releva de sa maladie"+NB+":",
   "Then one says the prayer of Hezekiah when he rose from his illness:"),
}
vus, n = 0, 0
for t in d["textes"]:
    if t["id"] != "tefila_lishlomo":
        continue
    for s in t["sections"]:
        for b in s["blocs"]:
            if "c" in b and "t" not in b and "fr" not in b and "en" not in b:
                fr, en = T[b["c"]]  # une consigne inconnue arrête tout : rien n'est écrit
                vus += 1
                if b.get("c_fr") != fr or b.get("c_en") != en:
                    b["c_fr"], b["c_en"] = fr, en
                    n += 1
if vus != 16:
    sys.exit(f"{vus} consignes trouvées au lieu de 16 : rien n'est écrit")
if n:
    with open(src, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, separators=(",", ":"))
    subprocess.check_call([sys.executable, os.path.join(racine, "tools/livres_decoupe.py")])
print(n, "blocs modifiés")
