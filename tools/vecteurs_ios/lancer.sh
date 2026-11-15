#!/bin/sh
# Refait les vecteurs des tests Swift de ios/Paquets/Coeur : d'abord le fichier d'or du site
# (site/sauvegarde-site.mjs, sur le vrai store.js), que l'oracle importe aussi ; puis le Kotlin
# d'Android sur la JVM (generateurs/, tâche Gradle « vecteurs »).
#
#   tools/vecteurs_ios/lancer.sh                          tous, écrits dans ios/Paquets/Coeur/Tests/Vecteurs
#   tools/vecteurs_ios/lancer.sh VecteursSocle            celui-là seul, compilé à part des autres
#   tools/vecteurs_ios/lancer.sh VecteursSocle /tmp/essai idem, écrit ailleurs que dans le dépôt
#
# Gradle : celui du PATH, $GRADLE, sinon android/gradlew. android.jar (plateforme 36) est pris dans
# ANDROID_JAR, sinon dans ANDROID_HOME, sinon téléchargé et vérifié par son empreinte.
set -e
ici=$(cd "$(dirname "$0")" && pwd)
depot=$(cd "$ici/../.." && pwd)
gradle=${GRADLE:-gradle}
command -v "$gradle" >/dev/null 2>&1 || gradle="$depot/android/gradlew"
if [ -n "$1" ]; then
    exec "$gradle" -p "$ici" --project-cache-dir "$ici/build/seul-$1/.gradle" -q vecteurs -PseulVecteur="$1" ${2:+-Psortie="$2"}
fi
node "$ici/site/sauvegarde-site.mjs"
exec "$gradle" -p "$ici" -q vecteurs
