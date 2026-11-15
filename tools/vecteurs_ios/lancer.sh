#!/bin/sh
# Lance les générateurs de vecteurs sur la JVM (projet Gradle tools/vecteurs_ios/oracle).
#
#   tools/vecteurs_ios/lancer.sh                    tous, écrits dans ios/Paquets/Coeur/Tests/Vecteurs
#   tools/vecteurs_ios/lancer.sh VecteursSocle      celui-là seul, compilé à part des autres
#   tools/vecteurs_ios/lancer.sh VecteursSocle /tmp/essai    idem, écrit ailleurs que dans le dépôt
#
# android.jar (plateforme 36) est pris dans ANDROID_JAR, sinon dans ANDROID_HOME, sinon téléchargé.
set -e
ici=$(cd "$(dirname "$0")" && pwd)
depot=$(cd "$ici/../.." && pwd)
projet="$ici/oracle"
if [ -n "$1" ]; then
    exec "$depot/android/gradlew" -p "$projet" --project-cache-dir "$projet/build/seul-$1/.gradle" -q vecteurs \
        -PseulVecteur="$1" ${2:+-Psortie="$2"}
fi
exec "$depot/android/gradlew" -p "$projet" -q vecteurs
