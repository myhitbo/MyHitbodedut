// Bouchon : le BuildConfig qu'Android Gradle Plugin engendre (android/app/build.gradle.kts). Les
// valeurs sont celles de la construction Play complète (« full », -Pplay=true, sans relais), celle
// qu'iOS reprend : barrière présente, route du vol sans suivi en direct (décision D10).
// Onboarding.kt en décide de ses pages.
package com.myhitbodedut

object BuildConfig {
    const val HAS_GATE = true
    const val SUIVI_VOL = true
    const val OPENSKY_DIRECT = false
    const val RELAIS_VOL = ""
}
