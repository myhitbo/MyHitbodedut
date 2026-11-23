#!/usr/bin/env bash
# Les captures de l'app iOS sur le simulateur (.github/workflows/ios-captures.yml ; ios/ECRANS.md, « Les captures »).
#
# L'app est lancée une fois par langue et par écran, avec « -capture <écran> -captureDemo » (ios/App/Captures.swift :
# l'écran s'ouvre de lui-même, sur le journal de démonstration tenu en mémoire), puis l'écran est photographié. Une
# app qui s'arrête est un plantage : son rapport (~/Library/Logs/DiagnosticReports), sa sortie d'erreur et son
# journal système vont dans le résumé, et le script finit en échec une fois toutes les captures faites.
#
# Variables : APP (le .app compilé pour le simulateur), SORTIE (le dossier des captures), LANGUES, ECRANS (vide :
# tous), PASSES (iphone, sombre, grand, ipad ; « paysage » : l'iPad noté pour les captures couchées du test
# d'interface), RESUME (le fichier du résumé, $GITHUB_STEP_SUMMARY dans la CI).
set -uo pipefail

APP=${APP:?le .app à installer}
SORTIE=${SORTIE:-captures}
LANGUES=${LANGUES:-"fr en he es ar-TN"}
ECRANS=${ECRANS:-}
PASSES=${PASSES:-"iphone sombre grand ipad"}
RESUME=${RESUME:-/dev/stdout}
ATTENTE=${ATTENTE:-2}
ID_APP=com.myhitbodedut
ICI=$(cd "$(dirname "$0")" && pwd)

# Les écrans de Captures.swift, dans l'ordre ; les passes secondaires n'en prennent qu'une partie.
ECRANS_TOUS="presentation jour depart seance bravo note livres siddour lecteur livre tehilim tikkun tefilot bibliotheque
halakha hilloulot recherche chizuk conseils chemin journal parcours trophees reglages version zmanim vol musique apercu
applications dedicace journal-barriere serenite bento pile fete bilan calendrier boussole rappels ajout-temps"
ECRANS_COURTS="jour depart seance bravo livres lecteur tehilim recherche chemin journal trophees reglages zmanim vol musique
calendrier boussole rappels serenite apercu"
test -n "$ECRANS" || ECRANS=$ECRANS_TOUS

mkdir -p "$SORTIE/png" "$SORTIE/jpg" "$SORTIE/journaux"
# Un chemin absolu : simctl ouvre --stdout et --stderr pour l'app, ailleurs que dans ce dossier.
SORTIE=$(cd "$SORTIE" && pwd)
PLANTAGES=()
FAITES=0

# L'identifiant du premier simulateur disponible d'iOS 26.5 dont le nom commence par $1, en préférant les noms qui
# suivent dans l'ordre donné.
appareil() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
genre, preferes = sys.argv[1], sys.argv[2:]
appareils = [a for runtime, liste in sorted(json.load(sys.stdin)["devices"].items()) if "iOS-26-5" in runtime
             for a in liste if a["name"].startswith(genre)]
for nom in preferes:
    for a in appareils:
        if a["name"] == nom:
            print(a["udid"], a["name"], sep="\t"); sys.exit()
if appareils:
    print(appareils[0]["udid"], appareils[0]["name"], sep="\t")
' "$@"
}

# La barre d'état propre : 9:41, pleine charge, tout le réseau.
barre() {
  xcrun simctl status_bar "$1" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 >/dev/null 2>&1 || true
}

demarrer() {
  local udid=$1
  xcrun simctl boot "$udid" 2>/dev/null || true
  echo "démarrage de ${udid}…"
  xcrun simctl bootstatus "$udid" -b >/dev/null
  echo "démarré"
  xcrun simctl ui "$udid" appearance light || true
  xcrun simctl ui "$udid" content_size large || true
  # Sans la présentation du clavier glissé (« Speed up your typing… »), qui couvrait la recherche.
  xcrun simctl spawn "$udid" defaults write com.apple.Preferences DidShowContinuousPathIntroduction -bool true || true
  xcrun simctl spawn "$udid" defaults write com.apple.keyboard.preferences KeyboardDidShowContinuousPathIntroduction \
    -bool true || true
  xcrun simctl install "$udid" "$APP" || echo "::error::installation refusée"
  xcrun simctl get_app_container "$udid" "$ID_APP" || echo "::error::l'app n'est pas installée"
  barre "$udid"
  # Un premier lancement, à blanc : le premier est lent (caches du simulateur). Sur la recherche, pour que la
  # présentation du clavier glissé, qu'iOS montre au premier clavier ouvert, passe là et pas sur une capture.
  echo "premier lancement : $(xcrun simctl launch "$udid" "$ID_APP" -capture recherche -captureDemo 2>&1)"
  sleep 20
  xcrun simctl terminate "$udid" "$ID_APP" >/dev/null 2>&1 || true
}

# Le relevé d'un plantage : le rapport du système (le fil fautif, symbolisé), la sortie d'erreur, le journal.
plantage() {
  local udid=$1 nom=$2 depuis=$3
  PLANTAGES+=("$nom")
  echo "::error::plantage : $nom"
  # Dans le résumé, et dans le journal du travail (que l'on lit sans compte).
  {
    echo "### Plantage : $nom"
    echo '```'
    tail -30 "$SORTIE/journaux/$nom.err" 2>/dev/null
    local rapport
    rapport=$(find ~/Library/Logs/DiagnosticReports -name 'MyHitbodedut*' -newer "$depuis" 2>/dev/null | head -1)
    if [ -n "$rapport" ]; then
      cp "$rapport" "$SORTIE/journaux/$nom.ips"
      python3 "$ICI/rapport.py" "$rapport" || head -c 4000 "$rapport"
    else
      echo "(aucun rapport de plantage)"
    fi
    echo '--- journal'
    xcrun simctl spawn "$udid" log show --predicate 'process == "MyHitbodedut"' --last 2m --style compact 2>/dev/null \
      | grep -vE "^Timestamp|^Filtering" | tail -40
    echo '```'
  } | tee -a "$RESUME"
}

# L'app tourne encore (un processus du simulateur est un processus du Mac).
vivant() {
  [ -n "$1" ] && kill -0 "$1" 2>/dev/null
}

# Lance l'app sur un écran dans une langue, attend, photographie. $4 : le nom de la capture.
capturer() {
  local udid=$1 langue=$2 ecran=$3 nom=$4 locale fuseau
  case $langue in
    fr) locale=fr_FR; fuseau=Europe/Paris ;;
    he) locale=he_IL; fuseau=Asia/Jerusalem ;;
    es) locale=es_AR; fuseau=America/Argentina/Buenos_Aires ;;
    ar*) locale=ar_TN; fuseau=Europe/Paris ;;
    *) locale=en_US; fuseau=America/New_York ;;
  esac
  local depuis="$SORTIE/journaux/.depuis"
  touch "$depuis"
  xcrun simctl terminate "$udid" "$ID_APP" >/dev/null 2>&1 || true
  local lance pid
  # Le fuseau de la ville de la démonstration (Demonstration.ville) : SIMCTL_CHILD_ passe la variable à l'app.
  lance=$(SIMCTL_CHILD_TZ=$fuseau xcrun simctl launch --stdout="$SORTIE/journaux/$nom.out" \
    --stderr="$SORTIE/journaux/$nom.err" "$udid" "$ID_APP" \
    -AppleLanguages "($langue)" -AppleLocale "$locale" -capture "$ecran" -captureDemo 2>&1)
  pid=${lance##*: }
  case $pid in
    ''|*[!0-9]*) echo "lancement refusé ($nom) : $lance"; pid="" ;;
  esac
  # L'app dit quand l'écran est ouvert (« CAPTURE PRETE », Captures.ouvrir) ; 60 s au plus, le simulateur de la CI
  # est lent. Puis le temps que les dernières images se posent.
  local n=0
  while vivant "$pid" && ! grep -q "CAPTURE PRETE" "$SORTIE/journaux/$nom.err" 2>/dev/null && [ $n -lt 120 ]; do
    sleep 0.5
    n=$((n + 1))
  done
  [ $n -ge 120 ] && echo "::warning::$nom : l'écran n'a pas dit qu'il était prêt"
  sleep "$ATTENTE"
  if ! vivant "$pid"; then
    plantage "$udid" "$nom" "$depuis"
    return
  fi
  barre "$udid"
  xcrun simctl io "$udid" screenshot --type=png "$SORTIE/png/$nom.png" >/dev/null 2>&1
  if ! vivant "$pid"; then
    plantage "$udid" "$nom" "$depuis"
  fi
  if [ -f "$SORTIE/png/$nom.png" ]; then
    sips -Z 1400 -s format jpeg -s formatOptions 70 "$SORTIE/png/$nom.png" --out "$SORTIE/jpg/$nom.jpg" >/dev/null
    FAITES=$((FAITES + 1))
  fi
}

# Une passe : un appareil, des langues, des écrans ; $1 le préfixe des noms (vide pour la passe principale).
passe() {
  local udid=$1 prefixe=$2 langues=$3 ecrans=$4
  for langue in $langues; do
    for ecran in $ecrans; do
      capturer "$udid" "$langue" "$ecran" "$prefixe$langue-$ecran"
    done
  done
}

# Les langues et les écrans d'une passe secondaire, parmi ceux demandés.
parmi() {
  local voulus=$1 demandes=$2 r=""
  for x in $voulus; do
    for y in $demandes; do [ "$x" = "$y" ] && r="$r $x"; done
  done
  echo "$r"
}

IPHONE=$(appareil iPhone "iPhone 17 Pro" "iPhone 16 Pro" "iPhone 17" | cut -f1)
test -n "$IPHONE" || { echo "::error::aucun iPhone simulé d'iOS 26.5"; exit 1; }
echo "iPhone : $(appareil iPhone "iPhone 17 Pro" "iPhone 16 Pro" "iPhone 17" | cut -f2)"
echo "$IPHONE" > "$SORTIE/iphone.txt"
demarrer "$IPHONE"

for p in $PASSES; do
  case $p in
    iphone)
      passe "$IPHONE" "" "$LANGUES" "$ECRANS" ;;
    sombre)
      xcrun simctl ui "$IPHONE" appearance dark
      passe "$IPHONE" "sombre-" "$(parmi "fr he" "$LANGUES")" "$(parmi "$ECRANS_COURTS" "$ECRANS")"
      xcrun simctl ui "$IPHONE" appearance light ;;
    grand)
      # Dynamic Type aux tailles d'accessibilité.
      xcrun simctl ui "$IPHONE" content_size accessibility-extra-large
      passe "$IPHONE" "grand-" "$(parmi "fr ar-TN" "$LANGUES")" "$(parmi "$ECRANS_COURTS" "$ECRANS")"
      xcrun simctl ui "$IPHONE" content_size large ;;
  esac
done

case " $PASSES " in
  *" ipad "*|*" paysage "*)
    xcrun simctl shutdown "$IPHONE" || true
    IPAD=$(appareil iPad "iPad Pro 13-inch (M5)" "iPad Pro 13-inch (M4)" "iPad Air 13-inch (M3)" | cut -f1)
    if [ -n "$IPAD" ]; then
      echo "iPad : $(appareil iPad "iPad Pro 13-inch (M5)" "iPad Pro 13-inch (M4)" "iPad Air 13-inch (M3)" | cut -f2)"
      demarrer "$IPAD"
      case " $PASSES " in
        *" ipad "*) passe "$IPAD" "ipad-" "$(parmi "fr he" "$LANGUES")" "$(parmi "$ECRANS_COURTS" "$ECRANS")" ;;
      esac
      # L'iPad couché : simctl ne sait pas tourner l'appareil ; le test d'interface le fait (XCUIDevice), dans
      # l'étape qui suit ce script (ios-captures.yml), sur cet iPad.
      echo "$IPAD" > "$SORTIE/ipad.txt"
    else
      echo "::warning::aucun iPad simulé d'iOS 26.5"
    fi ;;
esac

{
  echo "## Captures : $FAITES"
  if [ ${#PLANTAGES[@]} -gt 0 ]; then
    echo "**${#PLANTAGES[@]} plantage(s)** : ${PLANTAGES[*]}"
  else
    echo "Aucun plantage."
  fi
} >> "$RESUME"
test ${#PLANTAGES[@]} -eq 0
